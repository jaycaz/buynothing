import SwiftUI

@main
struct BuyNothingApp: App {
    init() {
        #if DEBUG
        CollageDebugDump.runIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if DEBUG
/// Headless verification hook: when launched with the `COLLAGE_DUMP_DIR` environment
/// variable set (e.g. `SIMCTL_CHILD_COLLAGE_DUMP_DIR=/some/path xcrun simctl launch ...`),
/// runs the full collage pipeline and writes every stage plus the final collage to disk as
/// PNGs, so the result can be inspected without needing a rendered simulator screen.
enum CollageDebugDump {
    static func runIfRequested() {
        guard let dumpDir = ProcessInfo.processInfo.environment["COLLAGE_DUMP_DIR"] else { return }
        let directoryURL = URL(fileURLWithPath: dumpDir)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let useFallback = ProcessInfo.processInfo.environment["COLLAGE_USE_FALLBACK_SEGMENTER"] == "1"
        let useGroundTruth = ProcessInfo.processInfo.environment["COLLAGE_USE_GROUND_TRUTH_MASK"] == "1"

        Task.detached(priority: .userInitiated) {
            await dumpPipeline(to: directoryURL, useFallback: useFallback, useGroundTruth: useGroundTruth)
        }
    }

    private static func dumpPipeline(to directoryURL: URL, useFallback: Bool, useGroundTruth: Bool) async {
        var segmenter: (@Sendable (CGImage) throws -> ForegroundSegmenter.Cutout)?
        if useFallback {
            segmenter = { try DebugBackgroundSubtractionSegmenter.cutoutForegroundObject(from: $0) }
        }
        let output = await CollageDemoModel.runPipeline(
            count: 6,
            seedBase: 0,
            segmenter: segmenter,
            useGroundTruthMask: useGroundTruth
        )

        for (index, stage) in output.stages.enumerated() {
            write(stage.original, to: directoryURL.appendingPathComponent("stage\(index)_original.png"))
            if let mask = stage.mask {
                write(mask, to: directoryURL.appendingPathComponent("stage\(index)_mask.png"))
            }
            if let aligned = stage.aligned {
                write(aligned, to: directoryURL.appendingPathComponent("stage\(index)_aligned.png"))
            }
        }
        if let collage = output.collageImage {
            try? collage.pngData()?.write(to: directoryURL.appendingPathComponent("collage.png"))
        }
        let errorsText = output.stages.enumerated().map { "\($0): \($1.error ?? "ok")" }.joined(separator: "\n")
        try? errorsText.write(to: directoryURL.appendingPathComponent("errors.txt"), atomically: true, encoding: .utf8)
        print("COLLAGE_DUMP_DONE status=\(output.statusMessage ?? "ok") stages=\(output.stages.count)")
    }

    private static func write(_ cgImage: CGImage, to url: URL) {
        let image = UIImage(cgImage: cgImage)
        try? image.pngData()?.write(to: url)
    }
}
#endif