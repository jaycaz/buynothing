import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import BuyNothing

/// Regression photos for the production segmentation path. The bundle mirrors
/// `Pipeline/Tests/CollagePipelineTests/TestImages/` (all 12 photos are present); keep
/// the two image sets in sync when refreshing.
enum ProductionPathTestImages {
    /// The 3 photos the app-level suite runs. The simulator's on-device ML pool can't
    /// sustain the full 12-photo load (a burst of subject-lift requests fails with Vision
    /// code 9 "Could not create inference context"), while the macOS host runs all 12 fine
    /// — so full 12-photo coverage lives in the package tests
    /// (Pipeline/Tests/CollagePipelineTests) and the app suite verifies the same production
    /// path on a lighter, representative spread: low (tools_07, ~0.10), mid (books_03,
    /// ~0.38), high (usbcable_07, ~0.76) confident-skin fraction in the Vision cutout.
    static let appSuiteNames = ["tools_07", "books_03", "usbcable_07"]

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

    /// The simulator's on-device ML pool is shared and slow to drain: this suite makes
    /// ~48 subject-lift requests, and a long burst can fail with "Could not create
    /// inference context" (Vision code 9) even though isolated requests succeed. So:
    /// space per-call work out (settle between photos) and retry code-9 with growing
    /// backoff to let the pool drain. A GENUINE environment break still fails, just slower.
    static func settle() { usleep(400_000) }

    static func visionCall<T>(_ what: () throws -> T) throws -> T {
        var lastError: Error?
        for attempt in 1...6 {
            do { return try what() }
            catch let error as NSError where error.domain == "com.apple.Vision" && error.code == 9 {
                lastError = error
                usleep(500_000 * UInt32(attempt))  // 0.5s, 1s, 1.5s, 2s, 2.5s, 3s
            }
            // any other error is a real failure — propagate immediately
        }
        throw lastError!
    }

    @Test("environment gate: Vision subject-lift works in this environment")
    func visionEnvironmentGate() {
        let input = ProductionPathTestImages.load("tools_03")
        do {
            _ = try Self.visionCall { try ForegroundSegmenter.cutoutForegroundObject(from: input) }
        } catch {
            Issue.record("Vision subject-lift failed even after retries: \(error). If this says 'Could not create inference context', the simulator/VM's on-device ML pool is unavailable or oversubscribed — re-run in a quieter environment (see AGENTS.md → Pipeline test runbook) or on a physical device.")
        }
    }

    @Test("handRemoval mode produces sane cutouts on the regression subset")
    func handRemovalInvariants() throws {
        for name in ProductionPathTestImages.appSuiteNames {
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
            Self.settle()
        }
    }

    @Test("visionCutout mode still works on the regression subset")
    func visionCutoutInvariants() throws {
        for name in ProductionPathTestImages.appSuiteNames {
            let input = ProductionPathTestImages.load(name)
            let output = try Self.visionCall { try segmentObject(input, mode: .visionCutout) }
            let frac = ProductionPathTestImages.opaqueFraction(output)
            #expect((0.02...0.97).contains(frac),
                    "\(name): opaque fraction \(frac) outside 0.02...0.97")
            Self.settle()
        }
    }

    @Test("handRemoval does not leave MORE confident-skin pixels than visionCutout")
    func handRemovalReducesSkin() throws {
        // Conditional per photo: only asserted where the Vision cutout actually contains
        // confident skin (i.e. the hand survived the plain cutout). Where Vision already
        // excluded skin, there is nothing to remove. A handRemoval result that fell back to
        // Vision is equal to the visionCutout result, so the inequality still holds.
        var assertedOn = 0
        for name in ProductionPathTestImages.appSuiteNames {
            let input = ProductionPathTestImages.load(name)
            let vision = try Self.visionCall { try segmentObject(input, mode: .visionCutout) }
            let handRemoved = try Self.visionCall { try segmentObject(input, mode: .handRemoval) }

            let visionSkin = ProductionPathTestImages.skinFraction(vision)
            let removedSkin = ProductionPathTestImages.skinFraction(handRemoved)
            if visionSkin > 0.05 {
                assertedOn += 1
                #expect(removedSkin <= visionSkin, "\(name): handRemoval left \(removedSkin) confident-skin fraction but visionCutout left \(visionSkin) — hand-removal is regressing")
            }
            Self.settle()
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
