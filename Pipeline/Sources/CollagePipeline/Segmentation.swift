import CoreGraphics
import Foundation

/// The selectable segmentation strategies, kept deliberately small (five shared
/// knobs, three strategies) so the viewer and CLI can expose a single parameter
/// set for every strategy. New strategies (e.g. `visionMinusSkin`) are added as
/// cases here; future pipeline stages (delighting, shadow removal) follow the
/// same enum + params-struct + `run` shape with their own types.
public enum SegmentationStrategy: String, CaseIterable, Codable, Sendable {
    case raw
    case vision
    case handRemover

    /// Human-facing label for pickers and reports.
    public var displayName: String {
        switch self {
        case .raw: "Raw"
        case .vision: "Vision Subject"
        case .handRemover: "Hand Remover"
        }
    }
}

/// The deliberately small shared parameter set for the strategy picker.
/// `.raw` and `.vision` ignore it; `.handRemover` maps the skin/component
/// knobs onto `HandRemover.Params` (which feathers and fills holes itself,
/// so `featherRadius` and `fillHoles` are not forwarded).
public struct SegmentationParams: Codable, Sendable, Equatable {
    public var skinRBGap: Float = 0.18
    public var skinValMin: Float = 0.25
    public var featherRadius: Int = 1
    public var minComponentPixels: Int = 1000
    public var fillHoles: Bool = true
    public init() {}
}

/// Uniform result envelope so every strategy is consumed the same way by the
/// viewer, CLI, and tests, regardless of how each strategy is implemented.
/// `CGImage` is not `Sendable`, hence the `@unchecked` opt-in (immutable lets).
public struct SegmentationOutput: @unchecked Sendable {
    /// The cutout, cropped to the mask bounding box.
    public let image: CGImage
    /// Full-frame 8-bit mask, same WxH as the input.
    public let fullMask: CGImage
    /// Wall-clock segmentation duration in milliseconds (always > 0).
    public let milliseconds: Double
}

public enum Segmentation {

    /// Runs one segmentation strategy over `image`.
    ///
    /// Parameter handling per strategy:
    /// - `.raw` — ignores `params`; returns the input unchanged with an all-opaque full-frame mask.
    /// - `.vision` — ignores `params`; Vision subject-lift as-is.
    /// - `.handRemover` — honors `skinRBGap`, `skinValMin`, and `minComponentPixels`
    ///   (mapped onto `HandRemover.Params`; `featherRadius` and `fillHoles` are NOT
    ///   mapped because HandRemover always feathers and fills holes internally).
    ///
    /// `output.milliseconds` is the measured wall-clock duration of the
    /// segmentation call, always greater than zero.
    public static func run(
        _ image: CGImage,
        strategy: SegmentationStrategy,
        params: SegmentationParams = SegmentationParams()
    ) throws -> SegmentationOutput {
        let start = Date()

        switch strategy {
        case .raw:
            let fullMask = Self.allOpaqueMask(width: image.width, height: image.height)
            return SegmentationOutput(image: image, fullMask: fullMask, milliseconds: elapsedMs(from: start))

        case .vision:
            let (cutout, fullMask) = try ForegroundSegmenter.segment(from: image)
            return SegmentationOutput(image: cutout.image, fullMask: fullMask, milliseconds: elapsedMs(from: start))

        case .handRemover:
            var p = HandRemover.Params()
            p.skinRBGap = params.skinRBGap
            p.skinValMin = params.skinValMin
            p.minComponentPixels = params.minComponentPixels
            let result = try HandRemover.segment(from: image, params: p)
            return SegmentationOutput(image: result.image, fullMask: result.fullMask, milliseconds: elapsedMs(from: start))
        }
    }

    /// Wall-clock ms since `start`, clamped to at least 1 so the contract
    /// ("milliseconds > 0") holds even for sub-millisecond work like `.raw`.
    private static func elapsedMs(from start: Date) -> Double {
        max(1.0, Date().timeIntervalSince(start) * 1000)
    }

    /// All-255 grayscale mask at the input's dimensions.
    private static func allOpaqueMask(width: Int, height: Int) -> CGImage {
        let bytesPerRow = width
        var bytes = [UInt8](repeating: 255, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(data: &bytes, width: width, height: height,
                                 bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                 space: colorSpace,
                                 bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            fatalError("Segmentation: could not create all-opaque mask context")
        }
        return ctx.makeImage()!
    }
}
