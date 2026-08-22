import Foundation
import CoreGraphics

/// Which segmentation model the pipeline uses. Swapping this is the primary "try different
/// models" knob for the harness: `vision` runs the real on-device subject-lifting model,
/// `groundTruth` bypasses detection and uses the synthetic generator's exact silhouette, so we
/// can measure the alignment/packing stages in isolation (and validate them independently of
/// segmentation quality).
public enum SegmenterChoice: String, Codable, CaseIterable {
    case vision
    case groundTruth

    /// Human/CLI-friendly name used for output directory tags (keeps `--compare` and
    /// single-run output dirs consistent: `vision`, `ground_truth`).
    public var displayName: String {
        switch self {
        case .vision: return "vision"
        case .groundTruth: return "ground_truth"
        }
    }

    /// Resolves a CLI-supplied name, accepting `vision`, `ground-truth`, `ground_truth`,
    /// and `groundTruth` (case-insensitive).
    public static func fromCLIString(_ raw: String) -> SegmenterChoice? {
        let normalized = raw.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "vision": return .vision
        case "ground_truth", "groundtruth": return .groundTruth
        default: return nil
        }
    }
}

/// All the tunable parameters for a single pipeline run. This is the "try parameters" knob:
/// the CLI maps its flags onto this struct, so every experiment is reproducible from a config.
public struct PipelineConfig: Codable {
    public var segmenter: SegmenterChoice
    public var count: Int
    public var seedBase: Int
    public var canvasSize: CGSize
    public var canvasWidth: CGFloat
    public var targetRowHeight: CGFloat
    public var spacing: CGFloat
    public var maxRowHeightScale: CGFloat

    public init(
        segmenter: SegmenterChoice = .vision,
        count: Int = 6,
        seedBase: Int = 0,
        canvasSize: CGSize = CGSize(width: 640, height: 640),
        canvasWidth: CGFloat = 900,
        targetRowHeight: CGFloat = 220,
        spacing: CGFloat = 6,
        maxRowHeightScale: CGFloat = 1.35
    ) {
        self.segmenter = segmenter
        self.count = count
        self.seedBase = seedBase
        self.canvasSize = canvasSize
        self.canvasWidth = canvasWidth
        self.targetRowHeight = targetRowHeight
        self.spacing = spacing
        self.maxRowHeightScale = maxRowHeightScale
    }

    public func descriptionDictionary() -> [String: String] {
        [
            "segmenter": segmenter.rawValue,
            "count": "\(count)",
            "seedBase": "\(seedBase)",
            "inputSize": "\(Int(canvasSize.width))x\(Int(canvasSize.height))",
            "canvasWidth": "\(canvasWidth)",
            "targetRowHeight": "\(targetRowHeight)",
            "spacing": "\(spacing)",
            "maxRowHeightScale": "\(maxRowHeightScale)"
        ]
    }
}

/// Per-image metrics the harness measures to score each stage.
public struct StageMetrics: Codable {
    /// IoU between the predicted mask and the synthetic generator's exact silhouette
    /// (nil for real photos without ground truth). 1.0 = perfect segmentation.
    public var segmentationIoU: Double?
    public var inputRotationDegrees: Double?
    /// height/width of the aligned cutout. A vertically-aligned screwdriver should be > 1.
    public var alignedAspectRatio: Double
    /// Degrees away from perfectly vertical after alignment (0 = perfect).
    public var alignedResidualDegrees: Double
    public var cutoutWidth: Int
    public var cutoutHeight: Int
    public var segmentationMs: Double
    public var alignmentMs: Double
}

/// A single image's journey through the pipeline (input -> cutout -> aligned), with its metrics.
public struct PipelineStage {
    public var seed: Int
    public var input: CGImage
    public var cutout: CGImage?
    public var aligned: CGImage?
    public var error: String?
    public var metrics: StageMetrics?
}

public struct PackingMetrics: Codable {
    public var canvasWidth: CGFloat
    public var canvasHeight: CGFloat
    public var rows: Int
    public var itemsPerRow: [Int]
    public var itemCount: Int
}

public struct AggregateMetrics: Codable {
    public var segmentationIoUMean: Double?
    public var segmentationIoUMedian: Double?
    public var segmentationIoUMin: Double?
    public var segmentationIoUMax: Double?
    public var alignmentSuccessRate: Double
    public var meanSegmentationMs: Double
    public var meanAlignmentMs: Double
    public var totalMs: Double
}

/// The full result of a pipeline run. Images live here for rendering; the JSON report is a
/// separate Codable snapshot (see `ReportWriter`).
public struct PipelineOutput {
    public var stages: [PipelineStage]
    public var collage: CGImage?
    public var packing: PackingMetrics
    public var aggregate: AggregateMetrics
    public var configDescription: [String: String]
}
