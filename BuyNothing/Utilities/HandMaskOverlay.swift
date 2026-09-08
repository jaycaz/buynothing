import CoreGraphics
import Foundation

/// Debug helpers for the "what did the strategy remove" preview in the collage debug sheet.
/// Both inputs/outputs are full-resolution (input-photo-sized) top-down images, so the
/// hand mask and the photo align 1:1 without any cropping or alignment math.
enum HandMaskOverlay {
    /// A red (255, 64, 64) image with alpha proportional to the mask value — the standard
    /// "removed pixels" tint. Same dimensions as `mask`.
    static func redTint(mask: CGImage) -> CGImage? {
        let w = mask.width, h = mask.height
        guard let bytes = ImageGeometry.topDownGrayscaleBytes(from: mask),
              bytes.count == w * h else { return nil }
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<bytes.count {
            let a = Float(bytes[i]) / 255.0
            // premultipliedLast: multiply RGB by alpha
            rgba[4 * i] = UInt8(255 * a)
            rgba[4 * i + 1] = UInt8(64 * a)
            rgba[4 * i + 2] = UInt8(64 * a)
            rgba[4 * i + 3] = bytes[i]
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(
            width: w, height: h,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    /// Draws `over` on top of `under` (both must share dimensions) into a new opaque
    /// photo-sized image — the annotated "photo with hand tinted red" preview.
    static func composite(under photo: CGImage, over overlay: CGImage) -> CGImage? {
        guard photo.width == overlay.width, photo.height == overlay.height else { return nil }
        let w = photo.width, h = photo.height
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(
            data: &buffer, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(photo, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(overlay, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
}
