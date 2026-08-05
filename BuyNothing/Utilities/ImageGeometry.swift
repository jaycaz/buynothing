import Foundation
import UIKit
import CoreGraphics

/// Low-level CGImage rotate/crop helpers shared by the orientation-alignment step.
/// The `topDown*Bytes` readers report positions with row 0 = the image's visual top (the
/// natural way to reason about "where is this pixel"), but `CGImage.cropping(to:)` — like
/// most CoreGraphics APIs — expects its rect in lower-left-origin coordinates. Every crop in
/// this file goes through `croppingRect(topDownX:topDownY:width:height:imageHeight:)` to make
/// that conversion once, in one place, rather than re-deriving it (and re-risking getting it
/// backwards) at each call site.
enum ImageGeometry {

    /// Converts a rect expressed in top-down coordinates (y measured down from the image's
    /// visual top, matching `topDown*Bytes`) into the lower-left-origin rect `CGImage.cropping(to:)`
    /// expects.
    static func croppingRect(topDownX: Int, topDownY: Int, width: Int, height: Int, imageHeight: Int) -> CGRect {
        CGRect(x: topDownX, y: imageHeight - topDownY - height, width: width, height: height)
    }

    /// Rotates an image by `angle` radians (UIKit convention) onto a transparent canvas
    /// large enough to contain the whole rotated result. The image is not cropped afterward.
    static func rotate(_ cgImage: CGImage, by angle: CGFloat) -> CGImage {
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        let newW = abs(w * cos(angle)) + abs(h * sin(angle))
        let newH = abs(w * sin(angle)) + abs(h * cos(angle))
        let newSize = CGSize(width: ceil(newW), height: ceil(newH))

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)

        let image = renderer.image { ctx in
            ctx.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            ctx.cgContext.rotate(by: angle)
            let drawRect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
            ctx.cgContext.draw(cgImage, in: drawRect)
        }
        return image.cgImage ?? cgImage
    }

    /// Crops an RGBA image to the tight bounding box of its non-transparent pixels.
    static func tightCropAlpha(_ cgImage: CGImage) -> CGImage? {
        guard let alphaBytes = topDownAlphaBytes(from: cgImage) else { return nil }
        let width = cgImage.width
        let height = cgImage.height

        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            let rowOffset = y * width
            for x in 0..<width where alphaBytes[rowOffset + x] > 10 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        let rect = croppingRect(topDownX: minX, topDownY: minY, width: maxX - minX + 1, height: maxY - minY + 1, imageHeight: height)
        return cgImage.cropping(to: rect)
    }

    /// Row-major, top-to-bottom (row 0 = top of image) alpha channel bytes.
    static func topDownAlphaBytes(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return nil }

        // UIGraphicsImageRenderer/UIKit-style contexts are already top-left origin for `draw`,
        // but a raw CGContext(data:) is bottom-up by default, so flip to keep row 0 == top.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    /// Row-major, top-to-bottom grayscale bytes (used for the Vision mask, which has no alpha channel).
    static func topDownGrayscaleBytes(from cgImage: CGImage) -> [UInt8]? {
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
