import Foundation
import CoreGraphics

/// Orchestrates the full pipeline: for each input photo, segment → align → collect, then pack
/// the aligned cutouts into a justified-row collage and compute aggregate metrics.
///
/// This is the single source of truth for "how a photo becomes a collage item," so the iOS
/// app and the Mac test harness drive the exact same code.
public struct Pipeline {
    public var config: PipelineConfig

    public init(config: PipelineConfig) {
        self.config = config
    }

    public func run() -> PipelineOutput {
        var stages: [PipelineStage] = []
        var alignedImages: [CGImage] = []
        var ious: [Double] = []
        var segTimes: [Double] = []
        var alignTimes: [Double] = []
        var alignmentSuccesses = 0
        let totalStart = Date()

        for offset in 0..<config.count {
            let seed = config.seedBase + offset
            let photo = SyntheticToolImageGenerator.generateScrewdriverPhoto(
                canvasSize: config.canvasSize,
                seed: seed
            )

            var metrics = StageMetrics(
                segmentationIoU: nil,
                inputRotationDegrees: photo.rotationDegrees,
                alignedAspectRatio: 0,
                alignedResidualDegrees: 0,
                cutoutWidth: 0,
                cutoutHeight: 0,
                segmentationMs: 0,
                alignmentMs: 0
            )
            var cutoutImage: CGImage?
            var alignedImage: CGImage?
            var stageError: String?

            do {
                // 1) Segment
                let segStart = Date()
                let cutout: ForegroundSegmenter.Cutout
                let predictedFullMask: CGImage
                switch config.segmenter {
                case .vision:
                    let seg = try ForegroundSegmenter.segment(from: photo.cgImage)
                    cutout = seg.cutout
                    predictedFullMask = seg.fullMask
                case .groundTruth:
                    let composited = try ForegroundSegmenter.compositeMasked(image: photo.cgImage, mask: photo.groundTruthMask)
                    cutout = try ForegroundSegmenter.tightCutout(image: composited, mask: photo.groundTruthMask)
                    predictedFullMask = photo.groundTruthMask
                }
                metrics.segmentationMs = Date().timeIntervalSince(segStart) * 1000
                segTimes.append(metrics.segmentationMs)

                // Position-sensitive IoU: both masks are at full input resolution in the same
                // coordinate space, so the number is a meaningful overlap measure.
                let iou = Metrics.iou(predictedMask: predictedFullMask, groundTruthMask: photo.groundTruthMask)
                metrics.segmentationIoU = iou
                if let iou { ious.append(iou) }

                // 2) Align
                let alignStart = Date()
                let aligned = ObjectOrientationAligner.align(cutout)
                metrics.alignmentMs = Date().timeIntervalSince(alignStart) * 1000
                alignTimes.append(metrics.alignmentMs)

                alignedImage = aligned
                cutoutImage = cutout.image
                metrics.cutoutWidth = aligned.width
                metrics.cutoutHeight = aligned.height
                metrics.alignedAspectRatio = Double(aligned.height) / Double(max(1, aligned.width))
                let residual = Metrics.alignmentResidualDegrees(ofAlpha: aligned)
                metrics.alignedResidualDegrees = residual
                if residual <= 10 { alignmentSuccesses += 1 }
                alignedImages.append(aligned)
            } catch let caught {
                stageError = "\(caught)"
            }

            stages.append(PipelineStage(
                seed: seed,
                input: photo.cgImage,
                cutout: cutoutImage,
                aligned: alignedImage,
                error: stageError,
                metrics: metrics
            ))
        }

        // 3) Pack + render collage
        var packing = PackingMetrics(canvasWidth: config.canvasWidth, canvasHeight: 0, rows: 0, itemsPerRow: [], itemCount: alignedImages.count)
        var collage: CGImage?
        if !alignedImages.isEmpty {
            let sizes = alignedImages.map { CGSize(width: $0.width, height: $0.height) }
            let layout = CollageJustifiedPacker.pack(
                itemSizes: sizes,
                canvasWidth: config.canvasWidth,
                targetRowHeight: config.targetRowHeight,
                spacing: config.spacing,
                maxRowHeightScale: config.maxRowHeightScale
            )
            collage = Self.renderCollage(images: alignedImages, layout: layout)
            packing.canvasHeight = layout.canvasSize.height
            packing.rows = Self.countRows(layout)
            packing.itemsPerRow = Self.itemsPerRow(layout)
        }

        let totalMs = Date().timeIntervalSince(totalStart) * 1000
        let aggregate = AggregateMetrics(
            segmentationIoUMean: Metrics.mean(ious),
            segmentationIoUMedian: Metrics.median(ious),
            segmentationIoUMin: ious.min(),
            segmentationIoUMax: ious.max(),
            alignmentSuccessRate: alignedImages.isEmpty ? 0 : Double(alignmentSuccesses) / Double(alignedImages.count),
            meanSegmentationMs: Metrics.mean(segTimes) ?? 0,
            meanAlignmentMs: Metrics.mean(alignTimes) ?? 0,
            totalMs: totalMs
        )

        return PipelineOutput(
            stages: stages,
            collage: collage,
            packing: packing,
            aggregate: aggregate,
            configDescription: config.descriptionDictionary()
        )
    }

    // MARK: - rendering

    static func renderCollage(images: [CGImage], layout: CollageJustifiedPacker.Layout) -> CGImage {
        Canvas.render(
            width: max(1, Int(ceil(layout.canvasSize.width))),
            height: max(1, Int(ceil(layout.canvasSize.height))),
            opaque: true
        ) { ctx in
            ToolColor.gray(0.96).setFill(ctx)
            ctx.fill(CGRect(origin: .zero, size: layout.canvasSize))
            for placement in layout.placements {
                ctx.draw(images[placement.index], in: placement.rect)
            }
        }
    }

    // MARK: - packing stats

    static func countRows(_ layout: CollageJustifiedPacker.Layout) -> Int {
        Set(layout.placements.map { Int(round($0.rect.minY)) }).count
    }

    static func itemsPerRow(_ layout: CollageJustifiedPacker.Layout) -> [Int] {
        let grouped = Dictionary(grouping: layout.placements) { Int(round($0.rect.minY)) }
        return grouped.keys.sorted().map { grouped[$0]!.count }
    }
}
