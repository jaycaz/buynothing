import Foundation
import Vision
import CoreImage
import CoreGraphics

/// Cuts the salient object out of a photo using Vision's built-in subject-lifting model,
/// the same on-device technology behind "lift subject from background" in Photos.
/// No custom ML model needed and no photo data leaves the device.
enum ForegroundSegmenter {

    struct Cutout {
        /// The object on a transparent background, cropped to its own bounding box.
        let image: CGImage
        /// Alpha-only mask matching `image`'s dimensions (255 = object, 0 = background).
        let alphaMask: CGImage
    }

    enum SegmentationError: Error {
        case noSubjectFound
        case maskRenderingFailed
    }

    @available(iOS 17.0, *)
    static func cutoutForegroundObject(from cgImage: CGImage) throws -> Cutout {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw SegmentationError.noSubjectFound
        }

        let maskPixelBuffer = try result.generateScaledMaskForImage(
            forInstances: result.allInstances,
            from: handler
        )

        guard let maskCGImage = CIContext().createCGImage(CIImage(cvPixelBuffer: maskPixelBuffer), from: CIImage(cgImage: cgImage).extent) else {
            throw SegmentationError.maskRenderingFailed
        }

        let compositedCGImage = try compositeMasked(image: cgImage, mask: maskCGImage)
        return try tightCutout(image: compositedCGImage, mask: maskCGImage)
    }

    /// Composites `image` onto a transparent background using `mask` as alpha, keeping only the
    /// foreground object. Shared by the real Vision segmenter and the DEBUG-only ground-truth one.
    static func compositeMasked(image: CGImage, mask: CGImage) throws -> CGImage {
        let ciContext = CIContext()
        let imageCI = CIImage(cgImage: image)
        let maskCI = CIImage(cgImage: mask)

        guard let blend = CIFilter(name: "CIBlendWithMask") else {
            throw SegmentationError.maskRenderingFailed
        }
        blend.setValue(imageCI, forKey: kCIInputImageKey)
        blend.setValue(maskCI, forKey: kCIInputMaskImageKey)
        blend.setValue(CIImage(color: .clear).cropped(to: imageCI.extent), forKey: kCIInputBackgroundImageKey)

        guard let composited = blend.value(forKey: kCIOutputImageKey) as? CIImage,
              let compositedCGImage = ciContext.createCGImage(composited, from: imageCI.extent) else {
            throw SegmentationError.maskRenderingFailed
        }
        return compositedCGImage
    }

    /// Crops both `image` and `mask` (which must share dimensions) to the tight bounding box
    /// of the mask's non-zero pixels, so downstream alignment/packing isn't wasting space on
    /// transparent padding.
    static func tightCutout(image: CGImage, mask: CGImage) throws -> Cutout {
        let bounds = try boundingBox(ofMask: mask)
        guard let croppedImage = image.cropping(to: bounds),
              let croppedMask = mask.cropping(to: bounds) else {
            throw SegmentationError.maskRenderingFailed
        }
        return Cutout(image: croppedImage, alphaMask: croppedMask)
    }

    /// Finds the tight CGRect enclosing all non-zero pixels of a single-channel mask, already
    /// converted to the lower-left-origin coordinates `CGImage.cropping(to:)` expects.
    static func boundingBox(ofMask maskCGImage: CGImage) throws -> CGRect {
        let width = maskCGImage.width
        let height = maskCGImage.height
        // Top-down rows (row 0 = top of image), matching how the mask is conventionally displayed.
        guard let data = ImageGeometry.topDownGrayscaleBytes(from: maskCGImage) else {
            throw SegmentationError.maskRenderingFailed
        }

        var minX = width, maxX = -1, minRowTopDown = height, maxRowTopDown = -1
        for row in 0..<height {
            let rowOffset = row * width
            for x in 0..<width where data[rowOffset + x] > 20 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if row < minRowTopDown { minRowTopDown = row }
                if row > maxRowTopDown { maxRowTopDown = row }
            }
        }
        guard maxX >= minX, maxRowTopDown >= minRowTopDown else { throw SegmentationError.noSubjectFound }

        return ImageGeometry.croppingRect(
            topDownX: minX,
            topDownY: minRowTopDown,
            width: maxX - minX + 1,
            height: maxRowTopDown - minRowTopDown + 1,
            imageHeight: height
        )
    }
}
