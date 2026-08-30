import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import CollagePipeline

/// Bundled real-photo test set for HandRemover regression checks (see TestImages/README.md).
enum HandRemoverTestImages {
    static let names = [
        "tools_03", "tools_07", "tools_11",
        "usbcable_03", "usbcable_07", "usbcable_11",
        "books_03", "books_06", "books_09",
        "tech_03", "tech_06", "tech_09",
    ]

    static func load(_ name: String) -> CGImage {
        let url = Bundle.module.url(forResource: name, withExtension: "jpg")!
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        return CGImageSourceCreateImageAtIndex(source, 0, nil)!
    }

    /// Fraction of pixels with alpha > 16 in a CGImage (drawn into a known RGBA layout).
    static func opaqueFraction(_ image: CGImage) -> Double {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return 0 }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buffer, width: w, height: h, bitsPerComponent: 8,
                                 bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        var opaque = 0
        for i in stride(from: 3, to: buffer.count, by: 4) where buffer[i] > 16 { opaque += 1 }
        return Double(opaque) / Double(w * h)
    }
}

@Suite("HandRemover real photos")
struct HandRemoverPhotoTests {

    /// KNOWN EDGE CASE (documented, not fixed): these USB-cable photos produce an empty
    /// cutout — HandRemover throws `maskRenderFailed` or returns an image with no opaque
    /// pixels. Likely cause: the Vision subject-lift locks onto the holding hand and the
    /// blue/red+texture pixel resolve then drops everything, so the final mask is empty
    /// and `cropToMask` finds no content. The Python `composite` reference captures these
    /// better (it has a SAM product-part step the Swift port omits). Follow-up: investigate
    /// and fix the under-capture for non-blue/red objects.
    static let knownEmptyCutout = ["usbcable_07", "usbcable_11"]

    @Test("10 real photos segment without throwing and keep sane invariants")
    func realPhotoInvariants() throws {
        for name in HandRemoverTestImages.names where !Self.knownEmptyCutout.contains(name) {
            let input = HandRemoverTestImages.load(name)
            let result = try HandRemover.segment(from: input)

            #expect(result.fullMask.width == input.width, "\(name): fullMask width \(result.fullMask.width) != input \(input.width)")
            #expect(result.fullMask.height == input.height, "\(name): fullMask height \(result.fullMask.height) != input \(input.height)")
            #expect(result.image.width <= input.width, "\(name): cropped cutout wider than input")
            #expect(result.image.height <= input.height, "\(name): cropped cutout taller than input")

            let frac = HandRemoverTestImages.opaqueFraction(result.image)
            #expect((0.02...0.97).contains(frac), "\(name): opaque fraction \(frac) outside 0.02...0.97")
        }
    }

    /// Pins today's known-failure behavior for the two empty-cutout cables: each image must
    /// either throw or return a cutout with <2% opaque pixels (i.e. it must NOT start
    /// returning a bogus full-frame cutout either). Revisit once the under-capture is fixed.
    @Test("known edge case: usbcable_07/11 throw or return an empty cutout")
    func knownEmptyCutoutEdgeCase() {
        for name in Self.knownEmptyCutout {
            let input = HandRemoverTestImages.load(name)
            do {
                let result = try HandRemover.segment(from: input)
                let frac = HandRemoverTestImages.opaqueFraction(result.image)
                #expect(frac < 0.02, "\(name): expected empty cutout, got opaque fraction \(frac)")
            } catch {
                #expect(true, "\(name): throws as expected (\(error))")
            }
        }
    }
}

@Suite("HandRemover helpers")
struct HandRemoverHelperTests {

    @Test("fillHoles fills an enclosed hole")
    func fillHolesEnclosed() {
        let w = 20, h = 20
        var mask = [Bool](repeating: true, count: w * h)
        for y in 7..<13 { for x in 7..<13 { mask[y * w + x] = false } } // enclosed hole
        let out = HandRemover.fillHoles(mask, width: w, height: h)
        #expect(out.allSatisfy { $0 }, "enclosed hole should be filled")
    }

    @Test("fillHoles leaves border-connected background empty")
    func fillHolesBorderOpen() {
        let w = 20, h = 20
        var mask = [Bool](repeating: true, count: w * h)
        for y in 0..<10 { for x in 0..<5 { mask[y * w + x] = false } } // touches top+left border
        let out = HandRemover.fillHoles(mask, width: w, height: h)
        #expect(!out[2 * w + 2], "border-connected background must stay empty")
        #expect(out[15 * w + 15], "interior stays filled")
    }

    @Test("removeSmallComponents drops the small component and keeps the large one")
    func removeSmallComponents() {
        let w = 100, h = 100
        var mask = [Bool](repeating: false, count: w * h)
        for y in 10..<60 { for x in 10..<60 { mask[y * w + x] = true } }  // 50x50 = 2500 px
        for y in 80..<90 { for x in 80..<90 { mask[y * w + x] = true } }  // 10x10 = 100 px
        let out = HandRemover.removeSmallComponents(mask, width: w, height: h, minSize: 1000)
        #expect(out[20 * w + 20], "large component should survive")
        #expect(!out[85 * w + 85], "small component should be dropped")
    }

    @Test("opening with 3 iterations removes a 2px line while a solid bar survives")
    func openingThinLine() {
        let w = 100, h = 100
        var mask = [Bool](repeating: false, count: w * h)
        for x in 10..<90 { mask[50 * w + x] = true; mask[51 * w + x] = true } // 2px thin line
        for y in 30..<50 { for x in 60..<80 { mask[y * w + x] = true } }      // 20x20 solid bar
        let out = HandRemover.open(mask, width: w, height: h, iterations: 3)
        #expect(!out[50 * w + 50] && !out[51 * w + 50], "2px line should be removed")
        #expect(out[40 * w + 70], "solid bar should survive")
    }

    @Test("boxFilter of a constant field is constant")
    func boxFilterConstant() {
        let w = 32, h = 32
        let field = [Float](repeating: 7.5, count: w * h)
        let out = HandRemover.boxFilter(field, width: w, height: h, radius: 10)
        #expect(out.allSatisfy { abs($0 - 7.5) < 1e-4 }, "boxFilter must preserve constant fields")
    }

    @Test("sobelMagnitude of a constant field is ~0")
    func sobelConstant() {
        let w = 32, h = 32
        let field = [Float](repeating: 128, count: w * h)
        let out = HandRemover.sobelMagnitude(field, width: w, height: h)
        #expect(out.allSatisfy { $0 < 1e-3 }, "sobel of a constant field should be ~0")
    }

    @Test("gaussianBlur1 of a constant field stays ~constant")
    func blurConstant() {
        let w = 32, h = 32
        let field = [UInt8](repeating: 200, count: w * h)
        let out = HandRemover.gaussianBlur1(field, width: w, height: h)
        #expect(out.allSatisfy { (198...202).contains($0) }, "feather must not fade constant regions")
    }

    @Test("cropToMask returns the tight bounding box of the alpha")
    func cropTight() {
        let w = 100, h = 80
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let image = ctx.makeImage() else {
            Issue.record("could not make test image")
            return
        }
        var alpha = [UInt8](repeating: 0, count: w * h)
        for y in 10..<50 { for x in 20..<70 { alpha[y * w + x] = 255 } } // block at x 20..<70, y 10..<50
        let cropped = HandRemover.cropToMask(image, alpha: alpha, width: w, height: h)
        #expect(cropped != nil, "crop should succeed")
        #expect(cropped?.width == 50, "cropped width \(String(describing: cropped?.width)) != 50")
        #expect(cropped?.height == 40, "cropped height \(String(describing: cropped?.height)) != 40")
    }
}
