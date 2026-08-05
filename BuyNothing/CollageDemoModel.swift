import Foundation
import UIKit

// This prototype sources its photos from `SyntheticToolImageGenerator` (DEBUG-only, since
// there's no real camera pipeline wired up yet), so the whole demo is DEBUG-only too.
#if DEBUG
@MainActor
final class CollageDemoModel: ObservableObject {
    struct PipelineResult: Identifiable {
        let id = UUID()
        let original: CGImage
        let mask: CGImage?
        let aligned: CGImage?
        let error: String?
    }

    struct PipelineOutput {
        var stages: [PipelineResult] = []
        var collageImage: UIImage?
        var statusMessage: String?
    }

    @Published private(set) var stages: [PipelineResult] = []
    @Published private(set) var collageImage: UIImage?
    @Published private(set) var isProcessing = false
    @Published private(set) var statusMessage: String?

    private var nextSeedBase = 0

    func regenerate(count: Int = 6) {
        guard !isProcessing else { return }
        isProcessing = true
        stages = []
        collageImage = nil
        statusMessage = nil
        let seedBase = nextSeedBase
        nextSeedBase += count

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let onStage: @Sendable (PipelineResult) -> Void = { result in
                Task { @MainActor in self.stages.append(result) }
            }
            let output = await Self.runPipeline(count: count, seedBase: seedBase, onStage: onStage)
            await MainActor.run {
                self.collageImage = output.collageImage
                self.statusMessage = output.statusMessage
                self.isProcessing = false
            }
        }
    }

    /// Runs the full toss -> segment -> align -> pack pipeline independent of any SwiftUI
    /// state, so it can also be driven headlessly (e.g. for on-disk verification dumps)
    /// without needing a rendered UI.
    nonisolated static func runPipeline(
        count: Int,
        seedBase: Int,
        useGroundTruthMask: Bool = false,
        onStage: (@Sendable (PipelineResult) -> Void)? = nil
    ) async -> PipelineOutput {
        guard #available(iOS 17.0, *) else {
            return PipelineOutput(statusMessage: "On-device subject segmentation needs iOS 17 or later.")
        }

        var output = PipelineOutput()
        var alignedImages: [CGImage] = []

        for offset in 0..<count {
            let photo = SyntheticToolImageGenerator.generateScrewdriverPhoto(seed: seedBase + offset)
            let result: PipelineResult
            do {
                let cutout = useGroundTruthMask
                    ? try DebugGroundTruthSegmenter.cutout(for: photo)
                    : try ForegroundSegmenter.cutoutForegroundObject(from: photo.cgImage)
                let aligned = ObjectOrientationAligner.align(cutout)
                alignedImages.append(aligned)
                result = PipelineResult(original: photo.cgImage, mask: cutout.alphaMask, aligned: aligned, error: nil)
            } catch {
                result = PipelineResult(original: photo.cgImage, mask: nil, aligned: nil, error: "Segmentation failed: \(error)")
            }
            output.stages.append(result)
            onStage?(result)
        }

        guard !alignedImages.isEmpty else {
            output.statusMessage = "No screwdrivers made it through segmentation — try again."
            return output
        }

        let sizes = alignedImages.map { CGSize(width: $0.width, height: $0.height) }
        let layout = CollageJustifiedPacker.pack(itemSizes: sizes, canvasWidth: 900, targetRowHeight: 220)
        output.collageImage = renderCollage(images: alignedImages, layout: layout)
        return output
    }

    nonisolated private static func renderCollage(images: [CGImage], layout: CollageJustifiedPacker.Layout) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: layout.canvasSize, format: format)
        return renderer.image { ctx in
            UIColor(white: 0.96, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: layout.canvasSize))
            for placement in layout.placements {
                let image = images[placement.index]
                ctx.cgContext.draw(image, in: placement.rect)
            }
        }
    }
}
#endif
