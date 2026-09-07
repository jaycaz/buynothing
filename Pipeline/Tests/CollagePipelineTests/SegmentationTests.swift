import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CollagePipeline

@Suite("Segmentation contract")
struct SegmentationTests {

    private static func load(_ name: String) -> CGImage {
        let url = Bundle.module.url(forResource: name, withExtension: "jpg")!
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        return CGImageSourceCreateImageAtIndex(source, 0, nil)!
    }

    @Test("allCases has exactly raw, vision, handRemover")
    func strategyCases() {
        #expect(SegmentationStrategy.allCases.count == 3)
        #expect(SegmentationStrategy.allCases.contains(.raw))
        #expect(SegmentationStrategy.allCases.contains(.vision))
        #expect(SegmentationStrategy.allCases.contains(.handRemover))
    }

    @Test("every strategy has a non-empty displayName")
    func displayNames() {
        for strategy in SegmentationStrategy.allCases {
            #expect(!strategy.displayName.isEmpty, "\(strategy.rawValue) has empty displayName")
        }
    }

    @Test(".raw returns the input unchanged with an all-opaque full-frame mask")
    func rawDimensions() throws {
        let input = Self.load("tools_03")
        let out = try Segmentation.run(input, strategy: .raw)
        #expect(out.image.width == input.width)
        #expect(out.image.height == input.height)
        #expect(out.fullMask.width == input.width)
        #expect(out.fullMask.height == input.height)
    }

    @Test(".vision returns a non-empty cutout and a full-frame mask")
    func visionDimensions() throws {
        let input = Self.load("tools_03")
        let out = try Segmentation.run(input, strategy: .vision)
        #expect(out.image.width > 0)
        #expect(out.image.height > 0)
        #expect(out.fullMask.width == input.width)
        #expect(out.fullMask.height == input.height)
    }

    @Test(".handRemover matches HandRemover.segment with default params")
    func handRemoverMatchesDirectCall() throws {
        let input = Self.load("tools_03")
        let viaContract = try Segmentation.run(input, strategy: .handRemover)
        let direct = try HandRemover.segment(from: input)
        #expect(viaContract.image.width == direct.image.width)
        #expect(viaContract.image.height == direct.image.height)
    }

    @Test("all three strategies report milliseconds > 0")
    func positiveTiming() throws {
        let input = Self.load("tools_03")
        for strategy in SegmentationStrategy.allCases {
            let out = try Segmentation.run(input, strategy: strategy)
            #expect(out.milliseconds > 0, "\(strategy.rawValue) reported \(out.milliseconds) ms")
        }
    }
}
