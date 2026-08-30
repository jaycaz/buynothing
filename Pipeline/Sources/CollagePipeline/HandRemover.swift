import CoreGraphics
import Foundation

/// Composite hand-removal cutout, ported 1:1 from `scripts/composite.py`.
///
/// Strategy (no SAM, no hand pose — pure image signals):
///  1. region  = Vision subject-lift full mask (product + hand + everything salient)
///  2. keep    = inside region, pixels that are product-colored (saturated blue/red)
///               OR textured (Sobel energy), and NOT confidently skin-toned
///  3. cleanup = morphological closing, small-component removal, hole fill
///  4. finish  = 1px Gaussian feather, tight crop
///
/// Cross-platform (macOS + iOS), CoreGraphics only.
public enum HandRemover {
    public struct Result {
        public let image: CGImage
        public let fullMask: CGImage
    }

    public enum HandRemoverError: Error {
        case noSubject
        case pixelAccessFailed
        case maskRenderFailed
    }

    // MARK: - Tunables (kept in sync with scripts/composite.py)

    private enum Tuning {
        static let skinRBGap: Float = 0.18   // (r-b) threshold for confident skin
        static let skinValMin: Float = 0.25
        static let blueSatMin: Float = 0.15
        static let blueBMin: Float = 0.25
        static let redSatMin: Float = 0.25
        static let redRGBap: Float = 0.15
        static let textureRadius = 10         // 21px uniform window
        static let textureThreshold: Float = 12
        static let closingIterations = 3
        static let openingIterations = 3   // removes thin stray wires/arcs (<=6px)
        static let minComponentPixels = 1000
        static let minFillRatio: Float = 0.10  // area/bbox-area; kills thin spiky wires
    }

    /// Cut out the product, removing the holding hand.
    public static func segment(from cgImage: CGImage) throws -> Result {
        // 1) region prior from Vision
        let region = try ForegroundSegmenter.segment(from: cgImage).fullMask
        let w = cgImage.width
        let h = cgImage.height
        guard let regionBytes = ImageGeometry.topDownGrayscaleBytes(from: region),
              regionBytes.count == w * h else {
            throw HandRemoverError.pixelAccessFailed
        }

        // 2) pixels
        guard let rgba = topDownRGBA(from: cgImage) else {
            throw HandRemoverError.pixelAccessFailed
        }
        let n = w * h

        // 3) per-pixel classification
        var keep = [Bool](repeating: false, count: n)
        for i in 0..<n {
            guard regionBytes[i] > 127 else { continue }
            let r = Float(rgba[4 * i]) / 255
            let g = Float(rgba[4 * i + 1]) / 255
            let b = Float(rgba[4 * i + 2]) / 255
            let mx = max(r, max(g, b))
            let mn = min(r, min(g, b))
            guard mx > 0 else { continue }
            let sat = (mx - mn) / mx

            let confidentSkin = (r - b > Tuning.skinRBGap) && r > g && mx > Tuning.skinValMin
            guard !confidentSkin else { continue }

            let blue = b > r * 1.15 && b > Tuning.blueBMin && sat > Tuning.blueSatMin
            let red = r > g * 1.5 && r > b * 1.3 && sat > Tuning.redSatMin && r - g > Tuning.redRGBap
            guard blue || red else { continue }
            keep[i] = true
        }

        // 4) texture channel: 21px uniform mean of Sobel magnitude on 0-255 luminance
        var lum = [Float](repeating: 0, count: n)
        for i in 0..<n {
            lum[i] = (Float(rgba[4 * i]) + Float(rgba[4 * i + 1]) + Float(rgba[4 * i + 2])) * (1.0 / 3.0)
        }
        let mag = sobelMagnitude(lum, width: w, height: h)
        let tex = boxFilter(mag, width: w, height: h, radius: Tuning.textureRadius)

        for i in 0..<n {
            if regionBytes[i] > 127 && !keep[i] && tex[i] > Tuning.textureThreshold {
                let r = Float(rgba[4 * i]) / 255
                let g = Float(rgba[4 * i + 1]) / 255
                let b = Float(rgba[4 * i + 2]) / 255
                let mx = max(r, max(g, b))
                let confidentSkin = (r - b > Tuning.skinRBGap) && r > g && mx > Tuning.skinValMin
                if !confidentSkin { keep[i] = true }
            }
        }

        // 5) cleanup: connect parts, kill thin wires, drop small blobs, fill holes
        keep = close(keep, width: w, height: h, iterations: Tuning.closingIterations)
        keep = open(keep, width: w, height: h, iterations: Tuning.openingIterations)
        keep = removeSmallComponents(keep, width: w, height: h, minSize: Tuning.minComponentPixels)
        keep = fillHoles(keep, width: w, height: h)

        // 6) feather (1px gaussian, separable)
        var alpha = [UInt8](repeating: 0, count: n)
        for i in 0..<n { alpha[i] = keep[i] ? 255 : 0 }
        alpha = gaussianBlur1(alpha, width: w, height: h)

        guard let mask = makeMaskImage(mask: alpha, width: w, height: h) else {
            throw HandRemoverError.maskRenderFailed
        }
        // Composite the photo with the mask as alpha, done manually (CoreGraphics) rather
        // than via CIBlendWithMask — the latter fades single-source masks in practice.
        // The source photo is opaque, so premultiply RGB by the alpha channel.
        guard let composited = compositeWithAlpha(rgba: rgba, alpha: alpha, width: w, height: h) else {
            throw HandRemoverError.maskRenderFailed
        }
        // Crop to the tight bounding box. My CGImages are top-down (row 0 = top) and
        // CGImage.cropping uses top-left origin, so I crop with a top-down rect directly.
        // (ForegroundSegmenter.tightCutout assumes the bottom-up Vision-mask convention and
        // would vertically flip a top-down image.)
        guard let cropped = cropToMask(composited, alpha: alpha, width: w, height: h) else {
            throw HandRemoverError.maskRenderFailed
        }
        return Result(image: cropped, fullMask: mask)
    }

    // MARK: - Pixel access

    /// Row-major, top-to-bottom RGBA8888 (premultiplied — source photos are opaque, so identical).
    private static func topDownRGBA(from cgImage: CGImage) -> [UInt8]? {
        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(
            data: &buffer,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.translateBy(x: 0, y: CGFloat(h))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buffer
    }

    /// Row-major, top-to-bottom (row 0 = top) 8-bit mask rendered as an RGB CGImage
    /// (R = G = B = mask value). `CIBlendWithMask` (used by
    /// `ForegroundSegmenter.compositeMasked`) interprets RGB masks faithfully; a raw
    /// single-channel gray mask comes out faded, so we match the exact format of the
    /// Vision subject-lift mask (DeviceRGB, 32bpp, noneSkipLast).
    private static func makeMaskImage(mask: [UInt8], width: Int, height: Int) -> CGImage? {
        guard mask.count == width * height else { return nil }
        // Bottom-up buffer (row 0 = bottom) so the CGImage is oriented correctly.
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let srcRow = (height - 1 - y) * width
            let dstRow = y * width
            for x in 0..<width {
                let v = mask[srcRow + x]
                let di = (dstRow + x) * 4
                rgba[di] = v
                rgba[di + 1] = v
                rgba[di + 2] = v
                rgba[di + 3] = 0
            }
        }
        let data = Data(rgba)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // MARK: - Image operators

    /// Crop a top-down RGBA CGImage to the bounding box of a top-down alpha mask,
    /// returning a new top-down CGImage (cropping with a top-left-origin rect).
    internal static func cropToMask(_ image: CGImage, alpha: [UInt8], width: Int, height: Int) -> CGImage? {
        var minX = width, maxX = -1, minY = height, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where alpha[row + x] > 20 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        return image.cropping(to: rect)
    }

    /// Build a premultipliedLast RGBA CGImage: color from `rgba`, alpha from `alpha`.
    private static func compositeWithAlpha(rgba: [UInt8], alpha: [UInt8], width: Int, height: Int) -> CGImage? {
        let n = width * height
        guard rgba.count == n * 4, alpha.count == n else { return nil }
        // A CGImage built from a raw buffer treats row 0 of the buffer as the BOTTOM of the
        // image, so we emit a bottom-up buffer: buffer row y <- top-down row (height-1-y).
        var out = [UInt8](repeating: 0, count: n * 4)
        for y in 0..<height {
            let srcRow = (height - 1 - y) * width
            let dstRow = y * width
            for x in 0..<width {
                let si = srcRow + x
                let di = (dstRow + x) * 4
                let a = Float(alpha[si]) / 255.0
                out[di] = UInt8(Float(rgba[4 * si]) * a)
                out[di + 1] = UInt8(Float(rgba[4 * si + 1]) * a)
                out[di + 2] = UInt8(Float(rgba[4 * si + 2]) * a)
                out[di + 3] = alpha[si]
            }
        }
        let data = Data(out)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    /// Sobel gradient magnitude (float, ~0...2900) on a 0-255 luminance field.
    internal static func sobelMagnitude(_ l: [Float], width: Int, height: Int) -> [Float] {
        var out = [Float](repeating: 0, count: l.count)
        func at(_ y: Int, _ x: Int) -> Float {
            let yy = min(max(y, 0), height - 1)
            let xx = min(max(x, 0), width - 1)
            return l[yy * width + xx]
        }
        for y in 0..<height {
            for x in 0..<width {
                let gx = -at(y - 1, x - 1) - 2 * at(y, x - 1) - at(y + 1, x - 1)
                        + at(y - 1, x + 1) + 2 * at(y, x + 1) + at(y + 1, x + 1)
                let gy = -at(y - 1, x - 1) - 2 * at(y - 1, x) - at(y - 1, x + 1)
                        + at(y + 1, x - 1) + 2 * at(y + 1, x) + at(y + 1, x + 1)
                out[y * width + x] = (gx * gx + gy * gy).squareRoot()
            }
        }
        return out
    }

    /// Separable uniform (box) filter with clamped borders.
    internal static func boxFilter(_ v: [Float], width: Int, height: Int, radius: Int) -> [Float] {
        let span = 2 * radius + 1
        let invSpan = 1.0 / Float(span)
        var hPass = [Float](repeating: 0, count: v.count)
        for y in 0..<height {
            var sum: Float = 0
            let row = y * width
            // seed with clamped left border
            for k in -radius...radius { sum += v[row + min(max(k, 0), width - 1)] }
            for x in 0..<width {
                hPass[row + x] = sum * invSpan
                let addX = min(x + radius + 1, width - 1)
                let subX = max(x - radius - 1, 0)
                sum += v[row + addX] - v[row + subX]
            }
        }
        var out = [Float](repeating: 0, count: v.count)
        for x in 0..<width {
            var sum: Float = 0
            for k in -radius...radius { sum += hPass[(min(max(k, 0), height - 1)) * width + x] }
            for y in 0..<height {
                out[y * width + x] = sum * invSpan
                let addY = min(y + radius + 1, height - 1)
                let subY = max(y - radius - 1, 0)
                sum += hPass[addY * width + x] - hPass[subY * width + x]
            }
        }
        return out
    }

    private static func dilate(_ m: [Bool], width: Int, height: Int) -> [Bool] {
        var out = m
        for y in 0..<height {
            for x in 0..<width {
                var hit = m[y * width + x]
                if !hit {
                    for dy in -1...1 {
                        for dx in -1...1 {
                            let yy = y + dy
                            let xx = x + dx
                            if yy < 0 || yy >= height || xx < 0 || xx >= width { continue }
                            if m[yy * width + xx] { hit = true; break }
                        }
                        if hit { break }
                    }
                }
                out[y * width + x] = hit
            }
        }
        return out
    }

    private static func erode(_ m: [Bool], width: Int, height: Int) -> [Bool] {
        var out = m
        for y in 0..<height {
            for x in 0..<width {
                var all = true
                for dy in -1...1 where all {
                    for dx in -1...1 {
                        let yy = y + dy
                        let xx = x + dx
                        if yy < 0 || yy >= height || xx < 0 || xx >= width { all = false; break }
                        if !m[yy * width + xx] { all = false; break }
                    }
                }
                out[y * width + x] = all
            }
        }
        return out
    }

    /// Morphological closing (dilate → erode), N iterations — matches scipy binary_closing.
    private static func close(_ m: [Bool], width: Int, height: Int, iterations: Int) -> [Bool] {
        var cur = m
        for _ in 0..<iterations {
            cur = erode(dilate(cur, width: width, height: height), width: width, height: height)
        }
        return cur
    }

    /// Morphological opening (erode → dilate), N iterations — removes thin/spiky
    /// foreground structures (stray wires, edges) thinner than ~2N px while preserving
    /// the solid body of the object.
    internal static func open(_ m: [Bool], width: Int, height: Int, iterations: Int) -> [Bool] {
        var cur = m
        for _ in 0..<iterations {
            cur = dilate(erode(cur, width: width, height: height), width: width, height: height)
        }
        return cur
    }

    /// Drop 8-connected components smaller than `minSize` pixels.
    internal static func removeSmallComponents(_ m: [Bool], width: Int, height: Int, minSize: Int) -> [Bool] {
        var out = m
        var visited = [Bool](repeating: false, count: m.count)
        var stack = [Int]()
        for start in 0..<m.count where m[start] && !visited[start] {
            var component: [Int] = []
            stack.append(start)
            visited[start] = true
            while let i = stack.popLast() {
                component.append(i)
                let y = i / width
                let x = i % width
                for dy in -1...1 {
                    for dx in -1...1 {
                        if dx == 0 && dy == 0 { continue }
                        let yy = y + dy
                        let xx = x + dx
                        if yy < 0 || yy >= height || xx < 0 || xx >= width { continue }
                        let j = yy * width + xx
                        if m[j] && !visited[j] {
                            visited[j] = true
                            stack.append(j)
                        }
                    }
                }
            }
            let area = component.count
            var minX = width, maxX = -1, minY = height, maxY = -1
            for i in component {
                let y = i / width
                let x = i % width
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
            let bboxArea = (maxX - minX + 1) * (maxY - minY + 1)
            let fill = Float(area) / Float(max(1, bboxArea))
            if area < minSize || fill < Tuning.minFillRatio {
                for i in component { out[i] = false }
            }
        }
        return out
    }

    /// Fill background holes (background regions not connected to the border).
    internal static func fillHoles(_ m: [Bool], width: Int, height: Int) -> [Bool] {
        var out = m
        var visited = [Bool](repeating: false, count: m.count)
        var stack = [Int]()
        // seed all border background pixels
        for x in 0..<width {
            for y in [0, height - 1] where !m[y * width + x] && !visited[y * width + x] {
                visited[y * width + x] = true
                stack.append(y * width + x)
            }
        }
        for y in 0..<height {
            for x in [0, width - 1] where !m[y * width + x] && !visited[y * width + x] {
                visited[y * width + x] = true
                stack.append(y * width + x)
            }
        }
        while let i = stack.popLast() {
            let y = i / width
            let x = i % width
            for dy in -1...1 {
                for dx in -1...1 {
                    if dx == 0 && dy == 0 { continue }
                    let yy = y + dy
                    let xx = x + dx
                    if yy < 0 || yy >= height || xx < 0 || xx >= width { continue }
                    let j = yy * width + xx
                    if !m[j] && !visited[j] {
                        visited[j] = true
                        stack.append(j)
                    }
                }
            }
        }
        for i in 0..<m.count where !m[i] && !visited[i] {
            out[i] = true
        }
        return out
    }

    /// Separable ~1px gaussian (5-tap [0.208,0.607,1,0.607,0.208]/2.630) on 0-255 mask.
    /// The weights sum to 1.0, so constant regions are preserved (a "feather", not a fade).
    internal static func gaussianBlur1(_ v: [UInt8], width: Int, height: Int) -> [UInt8] {
        let k: [Float] = [0.0791, 0.2308, 0.3802, 0.2308, 0.0791] // normalized sigma≈1
        var hPass = [Float](repeating: 0, count: v.count)
        for y in 0..<height {
            let row = y * width
            for x in 0..<width {
                var s: Float = 0
                for t in -2...2 {
                    let xx = min(max(x + t, 0), width - 1)
                    s += Float(v[row + xx]) * k[t + 2]
                }
                hPass[row + x] = s
            }
        }
        var out = [UInt8](repeating: 0, count: v.count)
        for x in 0..<width {
            for y in 0..<height {
                var s: Float = 0
                for t in -2...2 {
                    let yy = min(max(y + t, 0), height - 1)
                    s += hPass[yy * width + x] * k[t + 2]
                }
                out[y * width + x] = UInt8(min(max(s, 0), 255).rounded())
            }
        }
        return out
    }
}
