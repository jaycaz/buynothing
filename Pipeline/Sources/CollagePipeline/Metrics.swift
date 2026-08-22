import Foundation
import CoreGraphics

/// Quality metrics the harness computes to score each stage. These are the numbers that turn
/// "it looks about right" into "IoU 0.87, alignment residual 3.2°, 4/4 vertical" — the data you
/// need to make model/param decisions.
public enum Metrics {

    /// Intersection-over-union between two masks. Both are thresholded to binary; 1.0 = perfect
    /// overlap. Used to score segmentation quality by comparing the predicted mask to the
    /// synthetic generator's exact silhouette.
    public static func iou(predictedMask: CGImage, groundTruthMask: CGImage, threshold: UInt8 = 127) -> Double? {
        let gw = groundTruthMask.width, gh = groundTruthMask.height
        guard let gt = ImageGeometry.topDownGrayscaleBytes(from: groundTruthMask), gw > 0, gh > 0 else { return nil }
        let scaled = resize(predictedMask, to: gw, height: gh)
        guard let pred = ImageGeometry.topDownGrayscaleBytes(from: scaled) else { return nil }

        var inter = 0, union = 0
        for i in 0..<(gw * gh) {
            let a = pred[i] > threshold
            let b = gt[i] > threshold
            if a && b { inter += 1 }
            if a || b { union += 1 }
        }
        guard union > 0 else { return 0 }
        return Double(inter) / Double(union)
    }

    /// Degrees the object's principal axis is away from perfectly vertical (0 = perfect).
    /// Accounts for the 180° ambiguity of an axis (a line and its negation are the same axis).
    public static func alignmentResidualDegrees(ofAlpha cgImage: CGImage) -> Double {
        let angle = ObjectOrientationAligner.measurePrincipalAxisAngle(ofAlpha: cgImage)
        let a = fmod(abs(angle), .pi)      // line orientation in [0, π)
        let residual = abs(a - .pi / 2)    // distance to vertical
        return residual * 180 / .pi
    }

    // MARK: - helpers

    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let s = values.sorted()
        let mid = s.count / 2
        return s.count.isMultiple(of: 2) ? (s[mid - 1] + s[mid]) / 2 : s[mid]
    }

    static func resize(_ image: CGImage, to width: Int, height: Int) -> CGImage {
        if image.width == width && image.height == height { return image }
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage() ?? image
    }
}
