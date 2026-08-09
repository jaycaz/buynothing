import Foundation
import CoreGraphics

/// "Perspective correction" for flat-lay objects photographed from directly above/in front:
/// there's no real 3D perspective to undo, but every object still comes in at an arbitrary
/// in-plane rotation. This finds that rotation via PCA on the segmentation mask (the object's
/// principal axis) and normalizes every item to point the same way, so the collage reads as
/// a tidy row of identically-oriented tools rather than a jumble of angles.
enum ObjectOrientationAligner {

    /// Rotates `cutout` so its principal (longest) axis is vertical, then flips it if needed
    /// so the heavier/wider end (e.g. a screwdriver's handle) sits at the bottom, and tight-crops.
    static func align(_ cutout: ForegroundSegmenter.Cutout) -> CGImage {
        let angle = principalAxisAngle(ofMask: cutout.alphaMask)

        // Guard: skip rotation for blobby objects (circular/blob-shaped items like mugs, bottles)
        let eigenvalueRatio = principalElongationRatio(ofMask: cutout.alphaMask)
        guard eigenvalueRatio > 1.8 else {
            return ImageGeometry.tightCropAlpha(cutout.image) ?? cutout.image
        }

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

    /// Eigenvalue ratio for the object's covariance matrix.
    /// Returns λ1/λ2 where λ1 ≥ λ2, computed directly from the second-order moments
    /// without re-scanning the image. Ratio near 1 means blobby/circular; higher values
    /// indicate elongated shapes.
    private static func principalElongationRatio(ofMask maskImage: CGImage) -> Double {
        guard let bytes = ImageGeometry.topDownGrayscaleBytes(from: maskImage) else { return 0.0 }
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
        guard weightSum > 0 else { return 0.0 }

        let ixx = sumXX - sumX * sumX / weightSum
        let iyy = sumYY - sumY * sumY / weightSum
        let ixy = sumXY - sumX * sumY / weightSum

        // Eigenvalues from the 2×2 covariance matrix:
        // λ = (trace ± sqrt(trace² - 4·det)) / 2
        // where trace = ixx + iyy, det = ixx·iyy - ixy²
        // Closed form equivalent: λ = ((ixx+iyy) ± sqrt((ixx-iyy)² + 4·ixy²)) / 2
        let trace = ixx + iyy
        let discriminant = sqrt(pow(ixx - iyy, 2) + 4 * pow(ixy, 2))
        let lambda1 = (trace + discriminant) / 2.0
        let lambda2 = (trace - discriminant) / 2.0
        
        return lambda1 / lambda2
    }

    /// Angle (radians, UIKit y-down convention) of the mask's dominant eigenvector, i.e. the
    /// long axis of the object, computed from the mask's second-order pixel moments (PCA).
    private static func principalAxisAngle(ofMask maskImage: CGImage) -> CGFloat {
        guard let bytes = ImageGeometry.topDownGrayscaleBytes(from: maskImage) else { return 0 }
        let width = maskImage.width
        let height = maskImage.height

        // Single-pass raw moments; central moments (needed for the covariance matrix) are
        // derived from these afterward instead of re-scanning the image a second time.
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

        // Angle of the dominant eigenvector of the 2x2 covariance matrix [[ixx, ixy], [ixy, iyy]].
        let angle = 0.5 * atan2(2 * ixy, ixx - iyy)
        return CGFloat(angle)
    }

    /// Elongation ratio = λ₁ / λ₂ where λ₁ ≥ λ₂ are the eigenvalues of the 2×2 covariance matrix.
    /// Values near 1 indicate blobby/circular objects; higher values indicate elongation.
    /// Computed in closed form from the existing covariance terms to avoid a second image pass.
    private static func principalElongationRatio(ofMask maskImage: CGImage) -> Double {
        guard let bytes = ImageGeometry.topDownGrayscaleBytes(from: maskImage) else { return 1.0 }
        let width = maskImage.width
        let height = maskImage.height

        // Single-pass raw moments (same as in principalAxisAngle).
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
        guard weightSum > 0 else { return 1.0 }

        let ixx = sumXX - sumX * sumX / weightSum
        let iyy = sumYY - sumY * sumY / weightSum
        let ixy = sumXY - sumX * sumY / weightSum

        // Eigenvalues of the covariance matrix [[ixx, ixy], [ixy, iyy]]:
        // λ = (trace ± sqrt(trace² - 4·det)) / 2
        let trace = ixx + iyy
        let determinant = ixx * iyy - ixy * ixy
        
        // degenerate cases
        if trace == 0 { return 1.0 }
        let discriminant = trace * trace - 4 * determinant
        guard discriminant >= 0 else { return 1.0 } // numerical noise
        
        let sqrtDisc = sqrt(discriminant)
        let lambda1 = (trace + sqrtDisc) / 2.0
        let lambda2 = (trace - sqrtDisc) / 2.0

        // Return ratio of larger to smaller eigenvalue
        return lambda1 >= lambda2 ? lambda1 / lambda2 : 1.0
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

        // If the top band is meaningfully wider than the bottom band, the "handle" is
        // currently pointing up — flip it down.
        return topWidth > bottomWidth * 1.15
    }
}
