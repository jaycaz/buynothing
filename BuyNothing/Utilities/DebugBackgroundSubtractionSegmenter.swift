import Foundation
import CoreImage
import CoreGraphics

#if DEBUG
/// CPU-only, non-ML fallback for `ForegroundSegmenter`. Vision's on-device subject-lifting
/// model (`VNGenerateForegroundInstanceMaskRequest`) needs a GPU-backed inference context;
/// in a headless/sandboxed Simulator session without a real window-server session it can
/// fail with "Could not create inference context" even though the same code works fine on
/// a real device or a normal desktop session. This background-subtraction segmenter exists
/// solely so the rest of the pipeline (alignment, packing, compositing) stays exercisable
/// in that situation — it is never used outside DEBUG dumps, and production always goes
/// through the real Vision path in `ForegroundSegmenter`.
enum DebugBackgroundSubtractionSegmenter {
    static func cutoutForegroundObject(from cgImage: CGImage) throws -> ForegroundSegmenter.Cutout {
        let width = cgImage.width
        let height = cgImage.height
        let ciContext = CIContext()
        let original = CIImage(cgImage: cgImage)

        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else {
            throw ForegroundSegmenter.SegmentationError.maskRenderingFailed
        }
        blurFilter.setValue(original.clampedToExtent(), forKey: kCIInputImageKey)
        blurFilter.setValue(45.0, forKey: kCIInputRadiusKey)
        guard let blurred = blurFilter.outputImage?.cropped(to: original.extent),
              let origCG = ciContext.createCGImage(original, from: original.extent),
              let blurCG = ciContext.createCGImage(blurred, from: original.extent),
              let origPixels = topDownRGBABytes(from: origCG, width: width, height: height),
              let blurPixels = topDownRGBABytes(from: blurCG, width: width, height: height) else {
            throw ForegroundSegmenter.SegmentationError.maskRenderingFailed
        }

        // The synthetic backgrounds are smooth gradients; the object is a hard local
        // deviation from that slowly-varying signal, so original-minus-blurred isolates it.
        // For a thick shape this mainly lights up at the edges (the blur still carries most
        // of the interior's own color), so it comes out as an outline rather than a fill.
        var maskBytes = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let o = i * 4
            let dr = Int(origPixels[o]) - Int(blurPixels[o])
            let dg = Int(origPixels[o + 1]) - Int(blurPixels[o + 1])
            let db = Int(origPixels[o + 2]) - Int(blurPixels[o + 2])
            maskBytes[i] = (abs(dr) + abs(dg) + abs(db)) > 55 ? 255 : 0
        }
        fillRowSpans(&maskBytes, width: width, height: height)

        guard let maskCGImage = grayscaleCGImage(fromTopDownBytes: maskBytes, width: width, height: height) else {
            throw ForegroundSegmenter.SegmentationError.maskRenderingFailed
        }

        let maskCI = CIImage(cgImage: maskCGImage)

        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            throw ForegroundSegmenter.SegmentationError.maskRenderingFailed
        }
        blend.setValue(original, forKey: kCIInputImageKey)
        blend.setValue(maskCI, forKey: kCIInputMaskImageKey)
        blend.setValue(CIImage(color: .clear).cropped(to: original.extent), forKey: kCIInputBackgroundImageKey)

        guard let composited = blend.value(forKey: kCIOutputImageKey) as? CIImage,
              let compositedCGImage = ciContext.createCGImage(composited, from: original.extent) else {
            throw ForegroundSegmenter.SegmentationError.maskRenderingFailed
        }

        return try ForegroundSegmenter.tightCutout(image: compositedCGImage, mask: maskCGImage)
    }

    /// Turns an edge outline into a solid silhouette by filling, on each row independently,
    /// everything between the first and last lit pixel. Good enough for the roughly-convex
    /// per-row cross-sections of a hand tool; not a general-purpose fill algorithm.
    private static func fillRowSpans(_ bytes: inout [UInt8], width: Int, height: Int) {
        for y in 0..<height {
            let rowOffset = y * width
            var first = -1
            var last = -1
            for x in 0..<width where bytes[rowOffset + x] == 255 {
                if first == -1 { first = x }
                last = x
            }
            guard first != -1 else { continue }
            for x in first...last {
                bytes[rowOffset + x] = 255
            }
        }
    }

    /// Row-major, top-to-bottom RGBA bytes (row 0 = top of image), matching the convention
    /// used throughout `ImageGeometry`.
    private static func topDownRGBABytes(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    /// Builds a CGImage directly from a top-down (row 0 = top) grayscale buffer.
    /// `CGContext.makeImage()` wraps its backing store as-is with no transform, and every
    /// consumer in this codebase that reads a CGImage back out (`.cropping(to:)`, and the
    /// flip-compensated `ImageGeometry.topDown*Bytes` readers) uniformly treats raw row 0 as
    /// the image's visual top — so a top-down buffer can be handed to `makeImage()` unchanged.
    private static func grayscaleCGImage(fromTopDownBytes bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        var bytes = bytes
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        return context.makeImage()
    }
}
#endif
