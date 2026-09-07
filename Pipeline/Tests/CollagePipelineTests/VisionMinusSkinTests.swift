import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CollagePipeline

@Suite("Vision minus skin")
struct VisionMinusSkinTests {

    // MARK: - isConfidentSkin classifier

    @Test("isConfidentSkin returns true for a typical skin tone")
    func skinToneIsSkin() {
        #expect(Segmentation.isConfidentSkin(r: 0.80, g: 0.60, b: 0.50, params: SegmentationParams()))
    }

    @Test("isConfidentSkin returns false for a saturated red (product handle)")
    func saturatedRedIsNotSkin() {
        // saturation = (0.90 - 0.10) / 0.90 ≈ 0.89, far above the 0.75 cap
        #expect(!Segmentation.isConfidentSkin(r: 0.90, g: 0.10, b: 0.10, params: SegmentationParams()))
    }

    @Test("isConfidentSkin returns false for a neutral grey")
    func neutralGreyIsNotSkin() {
        #expect(!Segmentation.isConfidentSkin(r: 0.50, g: 0.50, b: 0.50, params: SegmentationParams()))
    }

    @Test("isConfidentSkin returns false for a blue")
    func blueIsNotSkin() {
        #expect(!Segmentation.isConfidentSkin(r: 0.20, g: 0.30, b: 0.80, params: SegmentationParams()))
    }

    // MARK: - strategy registration

    @Test("strategy enum exposes four strategies including visionMinusSkin")
    func allCasesContainsVisionMinusSkin() {
        #expect(SegmentationStrategy.allCases.count == 4)
        #expect(SegmentationStrategy.allCases.contains(.visionMinusSkin))
    }

    // MARK: - real photos

    @Test("12 real photos segment through visionMinusSkin without throwing")
    func realPhotoInvariants() throws {
        let names = [
            "tools_03", "tools_07", "tools_11",
            "usbcable_03", "usbcable_07", "usbcable_11",
            "books_03", "books_06", "books_09",
            "tech_03", "tech_06", "tech_09",
        ]
        for name in names {
            let url = Bundle.module.url(forResource: name, withExtension: "jpg")!
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
            let input = CGImageSourceCreateImageAtIndex(source, 0, nil)!

            let output = try Segmentation.run(input, strategy: .visionMinusSkin)

            #expect(output.image.width > 0, "\(name): zero-width cutout")
            #expect(output.image.height > 0, "\(name): zero-height cutout")
            #expect(output.fullMask.width == input.width, "\(name): fullMask width \(output.fullMask.width) != input \(input.width)")
            #expect(output.fullMask.height == input.height, "\(name): fullMask height \(output.fullMask.height) != input \(input.height)")
            #expect(output.milliseconds > 0, "\(name): non-positive milliseconds")
        }
    }
}
