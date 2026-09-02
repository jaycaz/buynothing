import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import BuyNothing

/// Regression photos for the production segmentation path. Mirrored from
/// `Pipeline/Tests/CollagePipelineTests/TestImages/` (keep the two sets in sync).
enum ProductionPathTestImages {
    static let names = [
        "tools_03", "tools_07", "tools_11",
        "usbcable_03", "usbcable_07", "usbcable_11",
        "books_03", "books_06", "books_09",
        "tech_03", "tech_06", "tech_09",
    ]

    /// The test bundle (this target's resources live in `BuyNothingTests.bundle`; the
    /// app test target has no generated `Bundle.module`).
    static let bundle: Bundle = {
        for b in Bundle.allBundles where b.bundleIdentifier?.hasSuffix(".BuyNothingTests") == true || b.bundlePath.hasSuffix("BuyNothingTests.bundle") {
            return b
        }
        fatalError("BuyNothingTests resource bundle not found")
    }()

    static func load(_ name: String) -> CGImage {
        guard let url = bundle.url(forResource: name, withExtension: "jpg") else {
            fatalError("missing test image \(name).jpg in \(bundle.bundlePath) — is BuyNothingTests/TestImages/ in the target?")
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("could not decode \(name).jpg")
        }
        return image
    }

    /// Fraction of pixels with alpha > 16 (drawn into a known RGBA layout).
    static func opaqueFraction(_ image: CGImage) -> Double {
        guard let rgba = rgba8888(image) else { return 0 }
        var opaque = 0
        for i in stride(from: 3, to: rgba.count, by: 4) where rgba[i] > 16 { opaque += 1 }
        return Double(opaque) / Double(image.width * image.height)
    }

    /// Fraction of OPAQUE pixels that are "confidently skin-toned", using the exact
    /// classifier the HandRemover strategy removes: (r-b > 0.18) && r > g &&
    /// value > 0.25 && saturation < 0.75. This is the signal of a held hand surviving
    /// a cutout, so comparing it across strategies measures hand-removal effectiveness.
    static func skinFraction(_ image: CGImage) -> Double {
        guard let rgba = rgba8888(image) else { return 0 }
        var opaque = 0, skin = 0
        for i in stride(from: 0, to: rgba.count, by: 4) where rgba[i + 3] > 16 {
            opaque += 1
            let r = Double(rgba[i]) / 255
            let g = Double(rgba[i + 1]) / 255
            let b = Double(rgba[i + 2]) / 255
            let mx = max(r, max(g, b))
            let mn = min(r, min(g, b))
            let sat = mx > 0 ? (mx - mn) / mx : 0
            if (r - b > 0.18) && r > g && mx > 0.25 && sat < 0.75 { skin += 1 }
        }
        guard opaque > 0 else { return 0 }
        return Double(skin) / Double(opaque)
    }

    private static func rgba8888(_ image: CGImage) -> [UInt8]? {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buffer, width: w, height: h, bitsPerComponent: 8,
                                 bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buffer
    }
}

/// End-to-end regression tests for the app's PRODUCTION segmentation path
/// (`segmentObject(_:mode:)` — the same entry point `SnapshotCollageModel.addPhoto`,
/// `CollageBrowserModel.insertCapturedItem`, and the sourced-image feed all use).
///
/// These require a working on-device Vision stack (simulator/VM or device). In
/// environments where Vision can't create inference contexts, the suite fails
/// LOUDLY with a diagnostic instead of silently passing — that is the point.
@Suite("Pipeline production path (real photos)", .serialized)
struct PipelineProductionPathTests {

    /// Constrained simulators fail a burst of concurrent Vision requests with
    /// "Could not create inference context" (Vision code 9). Retry a few times with a
    /// short pause before declaring the environment broken — the .serialized trait
    /// above already removes the parallel-burst cause.
    static func visionCall<T>(_ what: () throws -> T) throws -> T {
        var lastError: Error?
        for _ in 1...3 {
            do { return try what() }
            catch let error as NSError where error.domain == "com.apple.Vision" && error.code == 9 {
                lastError = error
                usleep(500_000)
            }
        }
        throw lastError!
    }

    @Test("environment gate: Vision subject-lift works in this environment")
    func visionEnvironmentGate() {
        let input = ProductionPathTestImages.load("tools_03")
        do {
            _ = try Self.visionCall { try ForegroundSegmenter.cutoutForegroundObject(from: input) }
        } catch {
            Issue.record("Vision segmentation failed in this environment: \(error). If this says 'Could not create inference context', this simulator/VM cannot run on-device ML — run the pipeline tests in an environment where Vision works (see AGENTS.md → Pipeline test runbook), or on a physical device.")
        }
    }

    @Test("handRemoval mode produces sane cutouts on all 12 regression photos")
    func handRemovalInvariants() throws {
        for name in ProductionPathTestImages.names {
            let input = ProductionPathTestImages.load(name)
            let output = try Self.visionCall { try segmentObject(input, mode: .handRemoval) }

            #expect(output.width >= 16 && output.height >= 16,
                    "\(name): cutout \(output.width)x\(output.height) implausibly small")
            let maxDim = Double(max(input.width, input.height))
            #expect(Double(max(output.width, output.height)) <= maxDim * 1.05,
                    "\(name): cutout bigger than input (rotation overflow?)")
            let frac = ProductionPathTestImages.opaqueFraction(output)
            #expect((0.02...0.97).contains(frac),
                    "\(name): opaque fraction \(frac) outside 0.02...0.97 (lost or fully-opaque)")
        }
    }

    @Test("visionCutout mode still works on all 12 regression photos")
    func visionCutoutInvariants() throws {
        for name in ProductionPathTestImages.names {
            let input = ProductionPathTestImages.load(name)
            let output = try Self.visionCall { try segmentObject(input, mode: .visionCutout) }
            let frac = ProductionPathTestImages.opaqueFraction(output)
            #expect((0.02...0.97).contains(frac),
                    "\(name): opaque fraction \(frac) outside 0.02...0.97")
        }
    }

    @Test("handRemoval does not leave MORE confident-skin pixels than visionCutout")
    func handRemovalReducesSkin() throws {
        // Conditional per photo: only asserted where the Vision cutout actually contains
        // confident skin (i.e. the hand survived the plain cutout). Where Vision already
        // excluded skin, there is nothing to remove. A handRemoval result that fell back to
        // Vision is equal to the visionCutout result, so the inequality still holds.
        var assertedOn = 0
        for name in ProductionPathTestImages.names {
            let input = ProductionPathTestImages.load(name)
            let vision = try Self.visionCall { try segmentObject(input, mode: .visionCutout) }
            let handRemoved = try Self.visionCall { try segmentObject(input, mode: .handRemoval) }

            let visionSkin = ProductionPathTestImages.skinFraction(vision)
            let removedSkin = ProductionPathTestImages.skinFraction(handRemoved)
            if visionSkin > 0.05 {
                assertedOn += 1
                #expect(removedSkin <= visionSkin, "\(name): handRemoval left \(removedSkin) confident-skin fraction but visionCutout left \(visionSkin) — hand-removal is regressing")
            }
        }
        #expect(assertedOn >= 1, "no regression photo had a confident-skin region in the Vision cutout — the test set can no longer prove hand removal; refresh TestImages with a held photo")
    }

    @Test("raw mode passes the image through untouched")
    func rawPassthrough() throws {
        let input = ProductionPathTestImages.load("tools_03")
        let output = try segmentObject(input, mode: .raw)
        #expect(output.width == input.width && output.height == input.height,
                "raw mode must not change dimensions")
    }
}
