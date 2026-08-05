import Foundation
import CoreGraphics

#if DEBUG
/// Uses the synthetic generator's own exact silhouette instead of detecting one, isolating
/// the alignment/packing stages from segmentation quality entirely. Useful for verifying
/// the rest of the pipeline in an environment where Vision itself can't run; never used
/// outside DEBUG dumps.
enum DebugGroundTruthSegmenter {
    static func cutout(for photo: SyntheticToolImageGenerator.GeneratedPhoto) throws -> ForegroundSegmenter.Cutout {
        let composited = try ForegroundSegmenter.compositeMasked(image: photo.cgImage, mask: photo.groundTruthMask)
        return try ForegroundSegmenter.tightCutout(image: composited, mask: photo.groundTruthMask)
    }
}
#endif
