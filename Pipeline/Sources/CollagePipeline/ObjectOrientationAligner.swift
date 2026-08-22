import Foundation
import CoreGraphics

/// "Perspective correction" for flat-lay objects photographed from directly above/in front:
/// there's no real 3D perspective to undo, but every object still comes in at an arbitrary
/// in-plane rotation. This finds that rotation via PCA on the segmentation mask (the object's
/// principal axis) and normalizes every item to point the same way, so the collage reads as
/// a tidy row of identically-oriented tools rather than a jumble of angles.
///
/// Cross-platform: pure CoreGraphics, so it compiles for macOS and iOS alike.
public enum ObjectOrientationAligner {

    /// Rotates `cutout` so its principal (longest) axis is vertical, then flips it if needed
    /// so the heavier/wider end (e.g. a screwdriver's handle) sits at the bottom, and tight-crops.
    public static func align(_ cutout: ForegroundSegmenter.Cutout) -> CGImage {
        let angle = principalAxisAngle(ofMask: cutout.alphaMask)

        // Rotate so the axis points straight up (target angle = -pi/2 in UIKit's y-down
        // convention, since that's "up" on screen). The axis has a 180-degree ambiguity
        // (an eigenvector and its negation are the same axis) — resolved below.
        let rotation = (-CGFloat.pi / 2) - angle
        let rotated = ImageGeometry.rotate(cutout.image, by: rotation)
        guard let cropped = ImageGeometry.tightCropAlpha(rotated) else { return cutout.image }

        if shouldFlip(cropped) {
            let flipped = ImageGeometry.rotate(cropped, by: .pi)
            return ImageGeometry.tightCropAlpha(flipped) ?? flipped
        }
        return cropped
    }

    /// Angle (radians, UIKit y-down convention) of the mask's dominant eigenvector, i.e. the
    /// long axis of the object, computed from the mask's second-order pixel moments (PCA).
    private static func principalAxisAngle(ofMask maskImage: CGImage) -> CGFloat {
        guard let bytes = ImageGeometry.topDownGrayscaleBytes(from: maskImage) else { return 0 }
        let width = maskImage.width
        let height = maskImage.height

        var weightSum = 0.0
        var sumX = 0.0, sumY = 0.0
        var sumXX = 0.0, sumYY = 0.0, sumXY = 0.0
        for y in 0..<height {
            let rowOffset = y * width
            for x in 0..<width {
                let w = Double(bytes[rowOffset + x]) / 255.0
                guard w > 0 else { continue }
                let dx = Double(x), dy = Double(y)
                weightSum += w
                sumX += w * dx
                sumY += w * dy
                sumXX += w * dx * dx
                sumYY += w * dy * dy
                sumXY += w * dx * dy
            }
        }
        guard weightSum > 0 else { return 0 }

        let ixx = sumXX - sumX * sumX / weightSum
        let iyy = sumYY - sumY * sumY / weightSum
        let ixy = sumXY - sumX * sumY / weightSum

        let angle = 0.5 * atan2(2 * ixy, ixx - iyy)
        return CGFloat(angle)
    }

    /// Public measurement hook for the test harness: principal-axis angle of an RGBA image's
    /// alpha channel, so we can score how close "vertical" the aligned result is.
    public static func measurePrincipalAxisAngle(ofAlpha cgImage: CGImage) -> Double {
        guard let bytes = ImageGeometry.topDownAlphaBytes(from: cgImage) else { return 0 }
        let width = cgImage.width
        let height = cgImage.height

        var weightSum = 0.0
        var sumX = 0.0, sumY = 0.0
        var sumXX = 0.0, sumYY = 0.0, sumXY = 0.0
        for y in 0..<height {
            let rowOffset = y * width
            for x in 0..<width {
                let w = Double(bytes[rowOffset + x]) / 255.0
                guard w > 0 else { continue }
                let dx = Double(x), dy = Double(y)
                weightSum += w
                sumX += w * dx
                sumY += w * dy
                sumXX += w * dx * dx
                sumYY += w * dy * dy
                sumXY += w * dx * dy
            }
        }
        guard weightSum > 0 else { return 0 }

        let ixx = sumXX - sumX * sumX / weightSum
        let iyy = sumYY - sumY * sumY / weightSum
        let ixy = sumXY - sumX * sumY / weightSum

        return 0.5 * atan2(2 * ixy, ixx - iyy)
    }

    /// After vertical alignment, decides whether the object needs a 180-degree flip so its
    /// wider end (the "handle") lands at the bottom. Compares average row-width in the top
    /// third of the image against the bottom third.
    private static func shouldFlip(_ cgImage: CGImage) -> Bool {
        guard let alpha = ImageGeometry.topDownAlphaBytes(from: cgImage) else { return false }
        let width = cgImage.width
        let height = cgImage.height
        guard height >= 6 else { return false }

        let bandHeight = max(1, height / 3)

        func averageRowWidth(fromRow start: Int, toRow end: Int) -> Double {
            var totalWidth = 0
            var rowsCounted = 0
            for y in stride(from: start, to: end, by: 1) {
                let rowOffset = y * width
                var count = 0
                for x in 0..<width where alpha[rowOffset + x] > 10 {
                    count += 1
                }
                if count > 0 {
                    totalWidth += count
                    rowsCounted += 1
                }
            }
            return rowsCounted > 0 ? Double(totalWidth) / Double(rowsCounted) : 0
        }

        let topWidth = averageRowWidth(fromRow: 0, toRow: bandHeight)
        let bottomWidth = averageRowWidth(fromRow: height - bandHeight, toRow: height)

        return topWidth > bottomWidth * 1.15
    }
}
