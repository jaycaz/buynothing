import CoreGraphics
import Foundation

/// One strategy's result over a single image, as measured by
/// `SegmentationComparison.compare`. Never throws: failures are reported
/// inside the measurement itself (`error != nil`).
public struct SegmentationMeasurement: Sendable {
    public let strategy: SegmentationStrategy
    /// Opaque pixels in fullMask / total pixels, 0...1. 0 on failure.
    public let keptFraction: Double
    public let cutoutWidth: Int
    public let cutoutHeight: Int
    public let milliseconds: Double
    /// nil on success; `String(describing:)` of the thrown error otherwise.
    public let error: String?

    public init(
        strategy: SegmentationStrategy,
        keptFraction: Double,
        cutoutWidth: Int,
        cutoutHeight: Int,
        milliseconds: Double,
        error: String?
    ) {
        self.strategy = strategy
        self.keptFraction = keptFraction
        self.cutoutWidth = cutoutWidth
        self.cutoutHeight = cutoutHeight
        self.milliseconds = milliseconds
        self.error = error
    }
}

/// Runs multiple segmentation strategies over the same image and reports the
/// results side by side. This is the primitive behind the CLI `--batch` mode
/// and the viewer comparison view.
public enum SegmentationComparison {

    /// Runs every strategy in `strategies` over `image`, never throwing: a
    /// strategy that fails is reported as a measurement carrying `error`,
    /// `keptFraction` 0 and zero cutout sizes.
    ///
    /// Returns one measurement per requested strategy, in the same order.
    public static func compare(
        image: CGImage,
        strategies: [SegmentationStrategy] = SegmentationStrategy.allCases,
        params: SegmentationParams = SegmentationParams()
    ) -> [SegmentationMeasurement] {
        strategies.map { strategy in
            do {
                let output = try Segmentation.run(image, strategy: strategy, params: params)
                return SegmentationMeasurement(
                    strategy: strategy,
                    keptFraction: keptFraction(ofMask: output.fullMask),
                    cutoutWidth: output.image.width,
                    cutoutHeight: output.image.height,
                    milliseconds: output.milliseconds,
                    error: nil
                )
            } catch {
                return SegmentationMeasurement(
                    strategy: strategy,
                    keptFraction: 0,
                    cutoutWidth: 0,
                    cutoutHeight: 0,
                    milliseconds: 0,
                    error: String(describing: error)
                )
            }
        }
    }

    /// Fraction of pixels in an 8-bit mask that are "kept" (value > 127).
    ///
    /// Handles the mask conventions used in this package: `ForegroundSegmenter`
    /// and `HandRemover` both store the mask in the RGB channels of an opaque
    /// (no-alpha) image — the alpha channel is 255 everywhere and carries no
    /// information — and plain luminance grayscale masks draw into RGB
    /// identically. Only a true alpha-only mask (`.alphaOnly`) is read from
    /// the alpha channel.
    public static func keptFraction(ofMask mask: CGImage) -> Double {
        let w = mask.width, h = mask.height
        guard w > 0, h > 0 else { return 0 }
        let alphaOnly = mask.alphaInfo == .alphaOnly
        let bytesPerPixel: Int = 4
        var buffer = [UInt8](repeating: 0, count: w * h * bytesPerPixel)
        guard let ctx = CGContext(data: &buffer, width: w, height: h, bitsPerComponent: 8,
                                 bytesPerRow: w * bytesPerPixel, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(mask, in: CGRect(x: 0, y: 0, width: w, height: h))
        var kept = 0
        for i in stride(from: 0, to: buffer.count, by: 4) {
            let pixelKept = alphaOnly
                ? buffer[i + 3] > 127
                : buffer[i] > 127 || buffer[i + 1] > 127 || buffer[i + 2] > 127
            if pixelKept { kept += 1 }
        }
        return Double(kept) / Double(w * h)
    }
}
