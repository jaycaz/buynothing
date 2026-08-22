import Foundation
import CoreGraphics

/// A minimal cross-platform RGBA color so the synthetic generator compiles on macOS and iOS
/// alike (the app's version uses `UIColor`). Values map 1:1 to `UIColor(red:green:blue:alpha:)`.
public struct ToolColor {
    public let r, g, b, a: CGFloat
    public init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    public static let black = ToolColor(0, 0, 0)
    public static let white = ToolColor(1, 1, 1)
    public static func gray(_ w: CGFloat, _ a: CGFloat = 1) -> ToolColor { ToolColor(w, w, w, a) }
    public func withAlpha(_ a: CGFloat) -> ToolColor { ToolColor(r, g, b, a) }
    public var cgColor: CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
    public func setFill(_ ctx: CGContext) { ctx.setFillColor(cgColor) }
    public func setStroke(_ ctx: CGContext) { ctx.setStrokeColor(cgColor) }
}

/// Renders a `CGImage` of a given size by drawing into a fresh `CGContext`. Cross-platform
/// replacement for the app's `UIGraphicsImageRenderer`.
public enum Canvas {
    /// Creates a cleared, premultiplied-RGB context of the given size (for multi-step renderers
    /// like the board that need to draw many elements and then call `makeImage()`).
    public static func begin(width: Int, height: Int) -> CGContext {
        guard let context = makeContext(width: width, height: height) else {
            fatalError("Failed to create render context")
        }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        return context
    }

    public static func render(width: Int, height: Int, opaque: Bool = false, _ draw: (CGContext) -> Void) -> CGImage {
        let context = begin(width: width, height: height)
        if opaque {
            context.setFillColor(ToolColor.gray(1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        draw(context)
        guard let image = context.makeImage() else { fatalError("Failed to make image from context") }
        return image
    }

    private static func makeContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: max(1, width),
            height: max(1, height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}

/// Generates synthetic "photo" images of a screwdriver lying on a surface, at a random
/// position, rotation, and scale, so the collage pipeline (segmentation -> alignment ->
/// packing) has varied input to chew on without needing a real camera roll.
///
/// Cross-platform: this is the app's DEBUG generator with its UIKit dependencies
/// (`UIColor`, `UIGraphicsImageRenderer`) replaced by the CG-only `ToolColor`/`Canvas`
/// helpers, so the same synthetic photos can be produced by the Mac test harness.
public enum SyntheticToolImageGenerator {

    public struct GeneratedPhoto {
        public let cgImage: CGImage
        public let rotationDegrees: Double
        public let handleColor: ToolColor
        /// Exact silhouette of the drawn screwdriver (solid white on transparent), rendered
        /// with the identical transform as `cgImage`. Stands in for a real segmentation model
        /// when verifying the alignment/packing stages in isolation.
        public let groundTruthMask: CGImage
    }

    public static func generateScrewdriverPhoto(
        canvasSize: CGSize = CGSize(width: 640, height: 640),
        seed: Int
    ) -> GeneratedPhoto {
        var rng = SeededGenerator(seed: seed)

        let surfaces: [(top: ToolColor, bottom: ToolColor)] = [
            (ToolColor(0.62, 0.47, 0.32), ToolColor(0.42, 0.30, 0.19)), // wood
            (ToolColor(0.55, 0.55, 0.57), ToolColor(0.35, 0.35, 0.37)), // concrete
            (ToolColor(0.85, 0.83, 0.78), ToolColor(0.70, 0.68, 0.62))  // canvas cloth
        ]
        let handleColors: [ToolColor] = [
            ToolColor(0.86, 0.16, 0.14),
            ToolColor(0.98, 0.75, 0.09),
            ToolColor(0.10, 0.35, 0.85),
            ToolColor(0.12, 0.55, 0.25),
            ToolColor(0.15, 0.15, 0.17)
        ]

        let surface = surfaces[Int(rng.nextUniform() * Double(surfaces.count)) % surfaces.count]
        let handleColor = handleColors[Int(rng.nextUniform() * Double(handleColors.count)) % handleColors.count]
        let rotation = rng.nextUniform() * 360.0
        let scale = 0.55 + rng.nextUniform() * 0.35
        let cx = canvasSize.width * (0.32 + rng.nextUniform() * 0.36)
        let cy = canvasSize.height * (0.32 + rng.nextUniform() * 0.36)

        let w = Int(canvasSize.width), h = Int(canvasSize.height)

        let image = Canvas.render(width: w, height: h, opaque: false) { ctx in
            drawSurface(top: surface.top, bottom: surface.bottom, size: canvasSize, context: ctx, rng: &rng)
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: rotation * .pi / 180)
            ctx.scaleBy(x: scale, y: scale)
            drawScrewdriver(handleColor: handleColor, context: ctx)
            ctx.restoreGState()
        }

        let maskImage = Canvas.render(width: w, height: h, opaque: false) { ctx in
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: rotation * .pi / 180)
            ctx.scaleBy(x: scale, y: scale)
            drawScrewdriverSilhouette(context: ctx)
            ctx.restoreGState()
        }

        return GeneratedPhoto(cgImage: image, rotationDegrees: rotation, handleColor: handleColor, groundTruthMask: maskImage)
    }

    // MARK: - Surface (background)

    private static func drawSurface(top: ToolColor, bottom: ToolColor, size: CGSize, context: CGContext, rng: inout SeededGenerator) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )

        context.saveGState()
        for _ in 0..<140 {
            let x = rng.nextUniform() * size.width
            let y = rng.nextUniform() * size.height
            let r = 1 + rng.nextUniform() * 2.5
            let shade = rng.nextUniform() > 0.5
            (shade ? ToolColor.black : ToolColor.white).withAlpha(0.04).setFill(context)
            context.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
        }
        context.restoreGState()
    }

    // MARK: - Screwdriver (drawn vertically: handle at bottom, tip at top, centered at origin)

    private static func drawScrewdriver(handleColor: ToolColor, context: CGContext) {
        let handleWidth: CGFloat = 70
        let handleHeight: CGFloat = 190
        let ferruleHeight: CGFloat = 22
        let shaftWidth: CGFloat = 14
        let shaftLength: CGFloat = 210
        let tipLength: CGFloat = 26

        let handleBottomY: CGFloat = 130
        let handleTopY = handleBottomY - handleHeight
        let ferruleTopY = handleTopY - ferruleHeight
        let shaftTopY = ferruleTopY - shaftLength
        let tipTopY = shaftTopY - tipLength

        let handleRect = CGRect(x: -handleWidth / 2, y: handleTopY, width: handleWidth, height: handleHeight)
        let handlePath = CGPath(roundedRect: handleRect, cornerWidth: handleWidth / 2.4, cornerHeight: handleWidth / 2.4, transform: nil)
        let handleColors = [handleColor.withAlpha(1).cgColor, handleColor.withAlpha(0.6).cgColor]
        context.saveGState()
        context.addPath(handlePath)
        context.clip()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: handleColors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: handleRect.minX, y: 0), end: CGPoint(x: handleRect.maxX, y: 0), options: [])
        }
        context.restoreGState()

        context.saveGState()
        context.addPath(handlePath)
        context.clip()
        ToolColor.black.withAlpha(0.15).setStroke(context)
        context.setLineWidth(4)
        var ridgeY = handleTopY + 18
        while ridgeY < handleBottomY - 10 {
            context.move(to: CGPoint(x: handleRect.minX + 6, y: ridgeY))
            context.addLine(to: CGPoint(x: handleRect.maxX - 6, y: ridgeY))
            context.strokePath()
            ridgeY += 16
        }
        context.restoreGState()

        let ferruleRect = CGRect(x: -handleWidth / 2 + 8, y: ferruleTopY, width: handleWidth - 16, height: ferruleHeight)
        drawMetalRect(ferruleRect, context: context)

        let shaftRect = CGRect(x: -shaftWidth / 2, y: shaftTopY, width: shaftWidth, height: shaftLength)
        drawMetalRect(shaftRect, context: context)

        context.saveGState()
        let tip = CGMutablePath()
        tip.move(to: CGPoint(x: -shaftWidth / 2, y: tipTopY + tipLength))
        tip.addLine(to: CGPoint(x: shaftWidth / 2, y: tipTopY + tipLength))
        tip.addLine(to: CGPoint(x: shaftWidth / 4, y: tipTopY))
        tip.addLine(to: CGPoint(x: -shaftWidth / 4, y: tipTopY))
        tip.closeSubpath()
        context.addPath(tip)
        ToolColor.gray(0.85).setFill(context)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.setShadow(offset: CGSize(width: 4, height: 6), blur: 10, color: ToolColor.black.withAlpha(0.35).cgColor)
        context.setFillColor(ToolColor(0, 0, 0, 0).cgColor)
        context.addPath(handlePath)
        context.fillPath()
        context.restoreGState()
    }

    /// Same silhouette geometry as `drawScrewdriver`, filled solid white with no gradients —
    /// a ground-truth alpha mask for the tool this function draws.
    private static func drawScrewdriverSilhouette(context: CGContext) {
        let handleWidth: CGFloat = 70
        let handleHeight: CGFloat = 190
        let ferruleHeight: CGFloat = 22
        let shaftWidth: CGFloat = 14
        let shaftLength: CGFloat = 210
        let tipLength: CGFloat = 26

        let handleBottomY: CGFloat = 130
        let handleTopY = handleBottomY - handleHeight
        let ferruleTopY = handleTopY - ferruleHeight
        let shaftTopY = ferruleTopY - shaftLength
        let tipTopY = shaftTopY - tipLength

        ToolColor.white.setFill(context)

        let handleRect = CGRect(x: -handleWidth / 2, y: handleTopY, width: handleWidth, height: handleHeight)
        context.addPath(CGPath(roundedRect: handleRect, cornerWidth: handleWidth / 2.4, cornerHeight: handleWidth / 2.4, transform: nil))
        context.fillPath()

        let ferruleRect = CGRect(x: -handleWidth / 2 + 8, y: ferruleTopY, width: handleWidth - 16, height: ferruleHeight)
        context.fill(ferruleRect)

        let shaftRect = CGRect(x: -shaftWidth / 2, y: shaftTopY, width: shaftWidth, height: shaftLength)
        context.fill(shaftRect)

        let tip = CGMutablePath()
        tip.move(to: CGPoint(x: -shaftWidth / 2, y: tipTopY + tipLength))
        tip.addLine(to: CGPoint(x: shaftWidth / 2, y: tipTopY + tipLength))
        tip.addLine(to: CGPoint(x: shaftWidth / 4, y: tipTopY))
        tip.addLine(to: CGPoint(x: -shaftWidth / 4, y: tipTopY))
        tip.closeSubpath()
        context.addPath(tip)
        context.fillPath()
    }

    private static func drawMetalRect(_ rect: CGRect, context: CGContext) {
        context.saveGState()
        context.addRect(rect)
        context.clip()
        let colors = [
            ToolColor.gray(0.55).cgColor,
            ToolColor.gray(0.92).cgColor,
            ToolColor.gray(0.5).cgColor
        ]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
        }
        context.restoreGState()
    }
}

/// Small deterministic PRNG so a given seed always produces the same synthetic photo.
public struct SeededGenerator {
    private var state: UInt64
    public init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15 }
    public mutating func nextUniform() -> Double {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        let value = state &* 2685821657736338717
        return Double(value >> 11) / Double(1 << 53)
    }
}
