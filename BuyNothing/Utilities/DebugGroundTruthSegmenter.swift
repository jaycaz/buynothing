import Foundation
import CoreImage
import CoreGraphics

#if DEBUG
/// Uses the synthetic generator's own exact silhouette instead of detecting one, isolating
/// the alignment/packing stages from segmentation quality entirely. Useful for verifying
/// the rest of the pipeline in an environment where Vision itself can't run (see
/// `DebugBackgroundSubtractionSegmenter`); never used outside DEBUG dumps.
enum DebugGroundTruthSegmenter {
    static func cutout(for photo: SyntheticToolImageGenerator.GeneratedPhoto) throws -> ForegroundSegmenter.Cutout {
        let ciContext = CIContext()
        let original = CIImage(cgImage: photo.cgImage)
        let maskCI = CIImage(cgImage: photo.groundTruthMask)

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

        return try ForegroundSegmenter.tightCutout(image: compositedCGImage, mask: photo.groundTruthMask)
    }
}
#endif
