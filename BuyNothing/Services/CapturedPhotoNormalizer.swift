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
        // UIGraphicsImageRenderer automatically applies the image's orientation transform,
        // producing a .up image with correct pixel data regardless of EXIF orientation
        let format = UIGraphicsImageRendererFormat()
        format.scale = photo.scale
        let renderer = UIGraphicsImageRenderer(size: photo.size, format: format)
        return renderer.image { ctx in
            photo.draw(in: CGRect(origin: .zero, size: photo.size))
        }
    }
}
