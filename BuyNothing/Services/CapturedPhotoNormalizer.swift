//
//  CapturedPhotoNormalizer.swift
//  BuyNothing
//
//  Normalizes captured photos to a consistent orientation for the collage pipeline.
//
//  ⚠️ Prototype-only.
//

import Foundation
import UIKit
import AVFoundation

enum CapturedPhotoNormalizer {

    /// Normalizes a photo's orientation by rotating it to match its EXIF orientation.
    static func normalize(_ photo: UIImage) -> UIImage {
        guard let exif = photo.imageOrientation,
              let original = photo.cgImage else {
            // No EXIF or no CGImage: return as-is
            return photo
        }

        // Rotate to correct orientation (EXIF defines how image is stored vs. how it should be displayed)
        switch exif {
        case .up:
            return UIImage(cgImage: original)
        case .upMirrored:
            // Flip horizontally (mirror)
            return UIImage(cgImage: original, transform: CGAffineTransform.makeHorizontalFlip())
        case .left:
            // Rotate 90° clockwise
            return UIImage(cgImage: original, transform: CGAffineTransform.rotation90CW)
        case .leftMirrored:
            // Rotate 90° CW + mirror = rotate 270° CW
            return UIImage(cgImage: original, transform: CGAffineTransform.rotation90CW)
            // Actually: mirror then rotate90CW = rotate 270 CW
        case .right:
            // Rotate 90° CCW (or 270° CW)
            return UIImage(cgImage: original, transform: CGAffineTransform.rotation90CCW)
        case .rightMirrored:
            // Rotate 270° CW
            return UIImage(cgImage: original, transform: CGAffineTransform.rotation90CW)
        @unknown default:
            return UIImage(cgImage: original)
        }
    }
}

private extension CGAffineTransform {
    static func makeHorizontalFlip() -> CGAffineTransform {
        return CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
    }

    static let rotation90CW = CGAffineTransform(rotationAngle: .pi / 2)
    static let rotation90CCW = CGAffineTransform(rotationAngle: -.pi / 2)
}
