import Testing
import Foundation
import CoreGraphics
import ImageIO
import CollagePipeline

@Suite("Segmentation comparison")
struct SegmentationComparisonTests {

    /// Loads a bundled fixture photo (see TestImages/).
    private static func load(_ name: String) -> CGImage {
        let url = Bundle.module.url(forResource: name, withExtension: "jpg")!
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        return CGImageSourceCreateImageAtIndex(source, 0, nil)!
    }

    /// A solid 10x10 8-bit grayscale mask with every pixel set to `value`.
    private static func solidMask(_ value: UInt8, width: Int = 10, height: Int = 10) -> CGImage {
        var bytes = [UInt8](repeating: value, count: width * height)
        let ctx = CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                            bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        return ctx.makeImage()!
    }

    @Test("keptFraction of an all-opaque 10x10 mask is 1.0")
    func keptFractionAllOpaque() {
        let frac = SegmentationComparison.keptFraction(ofMask: Self.solidMask(255))
        #expect(abs(frac - 1.0) < 0.01, "expected ~1.0, got \(frac)")
    }

    @Test("keptFraction of an all-zero 10x10 mask is 0.0")
    func keptFractionAllZero() {
        let frac = SegmentationComparison.keptFraction(ofMask: Self.solidMask(0))
        #expect(abs(frac - 0.0) < 0.01, "expected ~0.0, got \(frac)")
    }

    @Test("compare over all strategies returns one measurement per strategy, in order")
    func compareAllStrategies() throws {
        let image = Self.load("tools_03")
        let measurements = SegmentationComparison.compare(image: image)
        #expect(measurements.count == SegmentationStrategy.allCases.count,
                "expected \(SegmentationStrategy.allCases.count) measurements, got \(measurements.count)")
        #expect(measurements.map(\.strategy) == SegmentationStrategy.allCases,
                "measurements out of order: \(measurements.map(\.strategy))")
    }

    @Test("compare restricted to .raw returns a single full-frame measurement")
    func compareRawKeepsEverything() throws {
        let image = Self.load("tools_03")
        let measurements = SegmentationComparison.compare(image: image, strategies: [.raw])
        #expect(measurements.count == 1, "expected 1 measurement, got \(measurements.count)")
        #expect(measurements[0].strategy == .raw)
        #expect(measurements[0].error == nil, "raw strategy failed: \(measurements[0].error ?? "nil")")
        #expect(abs(measurements[0].keptFraction - 1.0) < 0.01,
                "raw should keep everything; keptFraction \(measurements[0].keptFraction)")
    }

    @Test("compare never throws; .vision and .visionMinusSkin succeed on tools_03")
    func compareNeverThrows() throws {
        let image = Self.load("tools_03")
        let measurements = SegmentationComparison.compare(
            image: image,
            strategies: [.vision, .visionMinusSkin]
        )
        #expect(measurements.count == 2)
        for m in measurements {
            #expect(m.error == nil, "\(m.strategy) failed: \(m.error ?? "nil")")
        }
    }
}
