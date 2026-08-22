import Foundation
import CoreGraphics
import ImageIO
import CoreText

/// Cross-platform image output + drawing helpers for the report/board renderers.
/// Uses ImageIO (PNG) and CoreText (text) so it compiles for macOS and iOS alike — no AppKit/UIKit.
public enum ImageIOHelpers {

    /// Encodes a `CGImage` to PNG data (cross-platform, via ImageIO).
    public static func pngData(from image: CGImage) -> Data {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data as CFMutableData, "public.png" as CFString, 1, nil) else {
            fatalError("Failed to create PNG destination")
        }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        return data as Data
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        try pngData(from: image).write(to: url)
    }

    public static func base64PNG(from image: CGImage) -> String {
        pngData(from: image).base64EncodedString()
    }

    /// Fills `rect` with a two-color checkerboard (used behind transparent cutouts so
    /// transparency reads clearly in screenshots).
    public static func fillCheckerboard(_ rect: CGRect, cell: CGFloat, a: CGColor, b: CGColor, ctx: CGContext) {
        let cols = max(1, Int(ceil(rect.width / cell)))
        let rows = max(1, Int(ceil(rect.height / cell)))
        for cy in 0..<rows {
            for cx in 0..<cols {
                ctx.setFillColor((cx + cy) % 2 == 0 ? a : b)
                let x = rect.minX + CGFloat(cx) * cell
                let y = rect.minY + CGFloat(cy) * cell
                let w = min(cell, rect.maxX - x)
                let h = min(cell, rect.maxY - y)
                ctx.fill(CGRect(x: x, y: y, width: w, height: h))
            }
        }
    }

    /// Draws `image` scaled to fit inside `rect` while preserving aspect ratio, centered.
    public static func drawContained(_ image: CGImage, in rect: CGRect, ctx: CGContext) {
        guard image.width > 0, image.height > 0, rect.width > 0, rect.height > 0 else { return }
        let imgAspect = CGFloat(image.width) / CGFloat(image.height)
        let rectAspect = rect.width / rect.height
        var w = rect.width, h = rect.height
        if imgAspect > rectAspect {
            h = rect.width / imgAspect
        } else {
            w = rect.height * imgAspect
        }
        let dx = rect.minX + (rect.width - w) / 2
        let dy = rect.minY + (rect.height - h) / 2
        ctx.draw(image, in: CGRect(x: dx, y: dy, width: w, height: h))
    }

    /// Draws a single line of text with its top at a top-down coordinate `(topDownX, topDownY)`,
    /// right-side up, inside a standard (bottom-left origin) context.
    ///
    /// CoreText draws upright in a plain bottom-left context, so no y-flip is applied here —
    /// flipping the context is what produces the classic upside-down/mirrored text artifact.
    ///
    /// Note the font attribute key: `kCTFontAttributeName` is "NSFont" (for compatibility
    /// with NSAttributedString), **not** "CTFont". Using the wrong key silently falls back
    /// to the default 12pt font — the exact bug this helper shipped with.
    public static func drawText(
        _ string: String,
        topDownX: CGFloat,
        topDownY: CGFloat,
        boardHeight: CGFloat,
        ctx: CGContext,
        size: CGFloat = 16,
        color: CGColor = CGColor(gray: 0.15, alpha: 1)
    ) {
        ctx.saveGState()
        let attrs: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attrs))
        // Position so the top of the text sits exactly at topDownY: the line's origin is its
        // lower-left, so offset the baseline up by the ascent.
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        ctx.translateBy(x: topDownX, y: boardHeight - topDownY - ascent)
        ctx.textMatrix = .identity
        ctx.textPosition = .zero
        CTLineDraw(line, ctx)
        ctx.restoreGState()
    }

    /// Converts a rect expressed in top-down coordinates (y measured from the top) into the
    /// bottom-left-origin rect a raw CGContext expects.
    public static func toBottomLeft(_ rect: CGRect, boardHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: boardHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
