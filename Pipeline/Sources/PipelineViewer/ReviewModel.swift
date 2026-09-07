import Foundation
import CoreGraphics
import ImageIO
import CollagePipeline

// HandRemover.Params is a plain value struct (Float/Int fields only) — safe to hand across
// the Task.detached boundary below.
extension HandRemover.Params: @unchecked Sendable {}

struct ReviewItem: Identifiable {
    let url: URL
    var inputImage: CGImage?
    var inputSize: CGSize = .zero
    var cutoutImage: CGImage?
    var outputSize: CGSize = .zero
    var ms: Double?
    var error: String?

    var id: URL { url }

    /// Fraction of the original frame's area kept in the cutout's bounding box. Not a
    /// correctness signal by itself (a small object in a big photo legitimately crops small)
    /// — just a cheap hint to look closer.
    var areaRatio: Double? {
        guard inputSize.width > 0, inputSize.height > 0, outputSize.width > 0, outputSize.height > 0 else { return nil }
        return Double(outputSize.width * outputSize.height) / Double(inputSize.width * inputSize.height)
    }

    var flagged: Bool {
        if error != nil { return true }
        if let r = areaRatio, r < 0.15 { return true }
        return false
    }
}

@MainActor
final class ReviewModel: ObservableObject {
    @Published private(set) var items: [ReviewItem] = []
    @Published var selectedID: URL?
    @Published var params = HandRemover.Params()
    @Published private(set) var isBatchProcessing = false
    @Published private(set) var sourceDescription: String = ""

    private var reprocessTask: Task<Void, Never>?

    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "avif", "tiff", "tif", "bmp", "gif"
    ]

    var selected: ReviewItem? {
        items.first { $0.id == selectedID }
    }

    func load(urls: [URL]) {
        var fileURLs: [URL] = []
        for url in urls {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let contents = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
                fileURLs.append(contentsOf: contents)
            } else {
                fileURLs.append(url)
            }
        }
        fileURLs = fileURLs
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        sourceDescription = urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) items"
        items = fileURLs.map { ReviewItem(url: $0) }
        selectedID = items.first?.id
        Task { await reprocessAll() }
    }

    func reprocessAll() async {
        guard !items.isEmpty else { return }
        isBatchProcessing = true
        defer { isBatchProcessing = false }
        let currentParams = params
        for index in items.indices {
            await process(index: index, params: currentParams)
        }
    }

    /// Debounced single-image reprocess, used while a param slider is being dragged.
    func scheduleReprocessSelected() {
        reprocessTask?.cancel()
        let currentParams = params
        reprocessTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled, let self else { return }
            if let idx = self.items.firstIndex(where: { $0.id == self.selectedID }) {
                await self.process(index: idx, params: currentParams)
            }
        }
    }

    func select(_ id: URL) {
        selectedID = id
        if let idx = items.firstIndex(where: { $0.id == id }), items[idx].cutoutImage == nil, items[idx].error == nil {
            Task { await process(index: idx, params: params) }
        }
    }

    func resetParams() {
        params = HandRemover.Params()
        scheduleReprocessSelected()
    }

    private struct ProcessFailure: Error, Sendable {
        let message: String
    }

    private struct ProcessOutcome: @unchecked Sendable {
        var input: CGImage
        var cutout: CGImage
        var inSize: CGSize
        var outSize: CGSize
        var ms: Double
    }

    private func process(index: Int, params: HandRemover.Params) async {
        let url = items[index].url
        let outcome: Swift.Result<ProcessOutcome, ProcessFailure> = await Task.detached(priority: .userInitiated) {
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                return .failure(ProcessFailure(message: "could not load image"))
            }
            let t0 = Date()
            do {
                // The one and only call site for segmentation — identical to pipeline-cli's
                // `--handremover` path, so GUI output can never drift from CLI output.
                let r = try HandRemover.segment(from: cg, params: params)
                let ms = Date().timeIntervalSince(t0) * 1000
                return .success(ProcessOutcome(
                    input: cg,
                    cutout: r.image,
                    inSize: CGSize(width: cg.width, height: cg.height),
                    outSize: CGSize(width: r.image.width, height: r.image.height),
                    ms: ms
                ))
            } catch {
                return .failure(ProcessFailure(message: String(describing: error)))
            }
        }.value

        guard items.indices.contains(index), items[index].url == url else { return }
        switch outcome {
        case .success(let o):
            items[index].inputImage = o.input
            items[index].inputSize = o.inSize
            items[index].cutoutImage = o.cutout
            items[index].outputSize = o.outSize
            items[index].ms = o.ms
            items[index].error = nil
        case .failure(let failure):
            items[index].error = failure.message
        }
    }
}
