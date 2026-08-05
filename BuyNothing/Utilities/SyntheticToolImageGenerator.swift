import Foundation
import UIKit
import CoreGraphics

/// Generates synthetic "photo" images of a screwdriver lying on a surface, at a random
/// position, rotation, and scale, so the collage pipeline (segmentation -> alignment ->
/// packing) has varied input to chew on without needing a real camera roll.
#if DEBUG
enum SyntheticToolImageGenerator {

    struct GeneratedPhoto {
        let cgImage: CGImage
        let rotationDegrees: Double
        let handleColor: UIColor
        /// Exact silhouette of the drawn screwdriver (solid white on transparent), rendered
        /// with the identical transform as `cgImage`. Stands in for a real segmentation model
        /// when verifying the alignment/packing stages in isolation.
        let groundTruthMask: CGImage
    }

    static func generateScrewdriverPhoto(
        canvasSize: CGSize = CGSize(width: 640, height: 640),
        seed: Int
    ) -> GeneratedPhoto {
        var rng = SeededGenerator(seed: seed)

        let surfaces: [(top: UIColor, bottom: UIColor)] = [
            (UIColor(red: 0.62, green: 0.47, blue: 0.32, alpha: 1), UIColor(red: 0.42, green: 0.30, blue: 0.19, alpha: 1)), // wood
            (UIColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1), UIColor(red: 0.35, green: 0.35, blue: 0.37, alpha: 1)), // concrete
            (UIColor(red: 0.85, green: 0.83, blue: 0.78, alpha: 1), UIColor(red: 0.70, green: 0.68, blue: 0.62, alpha: 1))  // canvas cloth
        ]
        let handleColors: [UIColor] = [
            UIColor(red: 0.86, green: 0.16, blue: 0.14, alpha: 1),
            UIColor(red: 0.98, green: 0.75, blue: 0.09, alpha: 1),
            UIColor(red: 0.10, green: 0.35, blue: 0.85, alpha: 1),
            UIColor(red: 0.12, green: 0.55, blue: 0.25, alpha: 1),
            UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1)
        ]

        let surface = surfaces[Int(rng.nextUniform() * Double(surfaces.count)) % surfaces.count]
        let handleColor = handleColors[Int(rng.nextUniform() * Double(handleColors.count)) % handleColors.count]
        let rotation = rng.nextUniform() * 360.0
        let scale = 0.55 + rng.nextUniform() * 0.35
        let cx = canvasSize.width * (0.32 + rng.nextUniform() * 0.36)
        let cy = canvasSize.height * (0.32 + rng.nextUniform() * 0.36)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let image = renderer.image { ctx in
            drawSurface(top: surface.top, bottom: surface.bottom, size: canvasSize, context: ctx.cgContext, rng: &rng)

            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: cx, y: cy)
            ctx.cgContext.rotate(by: rotation * .pi / 180)
            ctx.cgContext.scaleBy(x: scale, y: scale)
            drawScrewdriver(handleColor: handleColor, context: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }

        guard let cgImage = image.cgImage else {
            fatalError("Failed to render synthetic screwdriver photo")
        }

        let maskImage = renderer.image { ctx in
            ctx.cgContext.saveGState()
            ctx.cgContext.translateBy(x: cx, y: cy)
            ctx.cgContext.rotate(by: rotation * .pi / 180)
            ctx.cgContext.scaleBy(x: scale, y: scale)
            drawScrewdriverSilhouette(context: ctx.cgContext)
            ctx.cgContext.restoreGState()
        }
        guard let maskCGImage = maskImage.cgImage else {
            fatalError("Failed to render synthetic screwdriver mask")
        }

        return GeneratedPhoto(cgImage: cgImage, rotationDegrees: rotation, handleColor: handleColor, groundTruthMask: maskCGImage)
    }

    // MARK: - Surface (background)

    private static func drawSurface(top: UIColor, bottom: UIColor, size: CGSize, context: CGContext, rng: inout SeededGenerator) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: size.width, y: size.height),
            options: []
        )

        // A little grain so the surface doesn't look perfectly flat.
        context.saveGState()
        for _ in 0..<140 {
            let x = rng.nextUniform() * size.width
            let y = rng.nextUniform() * size.height
            let r = 1 + rng.nextUniform() * 2.5
            let shade = rng.nextUniform() > 0.5
            (shade ? UIColor.black : UIColor.white).withAlphaComponent(0.04).setFill()
            context.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
        }
        context.restoreGState()
    }

    // MARK: - Screwdriver (drawn vertically: handle at bottom, tip at top, centered at origin)

    private static func drawScrewdriver(handleColor: UIColor, context: CGContext) {
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

        // Handle body
        let handleRect = CGRect(x: -handleWidth / 2, y: handleTopY, width: handleWidth, height: handleHeight)
        let handlePath = CGPath(roundedRect: handleRect, cornerWidth: handleWidth / 2.4, cornerHeight: handleWidth / 2.4, transform: nil)
        let handleColors = [handleColor.withAlphaComponent(1).cgColor, handleColor.withAlphaComponent(0.6).cgColor]
        context.saveGState()
        context.addPath(handlePath)
        context.clip()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: handleColors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: handleRect.minX, y: 0),
                end: CGPoint(x: handleRect.maxX, y: 0),
                options: []
            )
        }
        context.restoreGState()

        // Grip ridges
        context.saveGState()
        context.addPath(handlePath)
        context.clip()
        UIColor.black.withAlphaComponent(0.15).setStroke()
        context.setLineWidth(4)
        var ridgeY = handleTopY + 18
        while ridgeY < handleBottomY - 10 {
            context.move(to: CGPoint(x: handleRect.minX + 6, y: ridgeY))
            context.addLine(to: CGPoint(x: handleRect.maxX - 6, y: ridgeY))
            context.strokePath()
            ridgeY += 16
        }
        context.restoreGState()

        // Ferrule (metal collar joining handle to shaft)
        let ferruleRect = CGRect(x: -handleWidth / 2 + 8, y: ferruleTopY, width: handleWidth - 16, height: ferruleHeight)
        drawMetalRect(ferruleRect, context: context)

        // Shaft
        let shaftRect = CGRect(x: -shaftWidth / 2, y: shaftTopY, width: shaftWidth, height: shaftLength)
        drawMetalRect(shaftRect, context: context)

        // Tip (flat-blade wedge)
        context.saveGState()
        let tip = CGMutablePath()
        tip.move(to: CGPoint(x: -shaftWidth / 2, y: tipTopY + tipLength))
        tip.addLine(to: CGPoint(x: shaftWidth / 2, y: tipTopY + tipLength))
        tip.addLine(to: CGPoint(x: shaftWidth / 4, y: tipTopY))
        tip.addLine(to: CGPoint(x: -shaftWidth / 4, y: tipTopY))
        tip.closeSubpath()
        context.addPath(tip)
        UIColor(white: 0.85, alpha: 1).setFill()
        context.fillPath()
        context.restoreGState()

        // Soft drop shadow under the whole tool for grounding.
        context.saveGState()
        context.setShadow(offset: CGSize(width: 4, height: 6), blur: 10, color: UIColor.black.withAlphaComponent(0.35).cgColor)
        context.setFillColor(UIColor.clear.cgColor)
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

        UIColor.white.setFill()

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
            UIColor(white: 0.55, alpha: 1).cgColor,
            UIColor(white: 0.92, alpha: 1).cgColor,
            UIColor(white: 0.5, alpha: 1).cgColor
        ]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: 0),
                end: CGPoint(x: rect.maxX, y: 0),
                options: []
            )
        }
        context.restoreGState()
    }
}

/// Small deterministic PRNG so a given seed always produces the same synthetic photo.
struct SeededGenerator {
    private var state: UInt64
    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15 }
    mutating func nextUniform() -> Double {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        let value = state &* 2685821657736338717
        return Double(value >> 11) / Double(1 << 53)
    }
}
#endif
