// segsuite — multi-strategy segmentation harness (see SEGMENTATION_RESEARCH.md)
//
// Runs several hand-removal strategies on one photo and writes a labeled PNG
// per strategy so they can be compared/swapped:
//
//   s1_allinstances.png   baseline: Vision subject-lift, all instances unioned
//   s2_inst{i}.png        per-instance: does Vision split hand vs object?
//   s3_handpose.png       subject-lift − hand-pose convex hull (dilated) + close
//   s4_skincolor.png      subject-lift − skin-color region + close
//   (s5 = Python SAM two-pass, copied in from scripts output)
//
// Build & run:
//   swiftc -O -o segsuite main.swift <pipeline sources>
//   ./segsuite /path/to/photo.png outDir

import Foundation
import Vision
import CoreImage
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: segsuite <photo> [outDir]\n".utf8))
    exit(2)
}
let inputPath = args[1]
let outDir = args.count >= 3 ? args[2] : "."
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: inputPath) as CFURL, nil),
      let photo = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("FAILED reason=cannot-load-image")
    exit(1)
}
let W = photo.width, H = photo.height
print("loaded \(W)x\(H)")

func writePNG(_ img: CGImage, _ name: String) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(name)")
}

func maskPreview(mask: CGImage, name: String) {
    guard let mImg = try? ForegroundSegmenter.compositeMasked(image: photo, mask: mask) else { return }
    writePNG(mImg, name)
}

// ---------- pixel helpers ----------
func maskToBytes(_ mask: CGImage) -> [UInt8]? {
    let w = mask.width, h = mask.height
    var data = [UInt8](repeating: 0, count: w * h)
    let cs = CGColorSpaceCreateDeviceGray()
    guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w, space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
    ctx.draw(mask, in: CGRect(x: 0, y: 0, width: w, height: h))
    return data
}

func bytesToMask(_ dataIn: [UInt8], w: Int, h: Int) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceGray()
    var data = dataIn
    guard let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w, space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
    return ctx.makeImage()
}

/// 1D sliding-window max, window half-width r (out[i] = max(a[i-r...i+r])). O(n) via deque.
func winMax(_ a: [UInt8], r: Int) -> [UInt8] {
    let n = a.count
    guard n > 0 else { return a }
    var out = [UInt8](repeating: 0, count: n)
    var dq: [Int] = []
    var next = 0
    for i in 0..<n {
        while next <= i + r && next < n {
            while !dq.isEmpty && a[dq[dq.count - 1]] <= a[next] { dq.removeLast() }
            dq.append(next)
            next += 1
        }
        while !dq.isEmpty && dq[0] < i - r { dq.removeFirst() }
        out[i] = a[dq[0]]
    }
    return out
}
/// Separable square dilation (box max) / erosion (box min). r = radius in px.
func dilate(_ m: [UInt8], w: Int, h: Int, r: Int) -> [UInt8] {
    var rows = [UInt8](repeating: 0, count: w * h)
    for y in 0..<h {
        var row = Array(m[y * w..<(y + 1) * w])
        row = winMax(row, r: r)
        rows.replaceSubrange(y * w..<(y + 1) * w, with: row)
    }
    var out = [UInt8](repeating: 0, count: w * h)
    for x in 0..<w {
        var col = [UInt8](repeating: 0, count: h)
        for y in 0..<h { col[y] = rows[y * w + x] }
        col = winMax(col, r: r)
        for y in 0..<h { out[y * w + x] = col[y] }
    }
    return out
}
func erode(_ m: [UInt8], w: Int, h: Int, r: Int) -> [UInt8] {
    let inv = m.map { 255 - $0 }
    let d = dilate(inv, w: w, h: h, r: r)
    return d.map { 255 - $0 }
}
func close(_ m: [UInt8], w: Int, h: Int, r: Int) -> [UInt8] {
    dilate(erode(m, w: w, h: h, r: r), w: w, h: h, r: r)
}
func subtract(_ a: [UInt8], _ b: [UInt8]) -> [UInt8] {
    a.indices.map { b[$0] > 20 ? 0 : a[$0] }
}

// ---------- S1: all instances ----------
do {
    let t0 = Date()
    let (cutout, fullMask) = try ForegroundSegmenter.segment(from: photo)
    writePNG(cutout.image, "s1_allinstances.png")
    writePNG(fullMask, "s1_mask.png")
    maskPreview(mask: fullMask, name: "s1_mask_preview.png")
    print("s1 done ms=\(Int(Date().timeIntervalSince(t0) * 1000))")
} catch {
    print("s1 FAILED: \(error)")
}

// ---------- S2: per-instance ----------
do {
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: photo, options: [:])
    try handler.perform([request])
    let obs = request.results ?? []
    print("s2 instances=\(obs.count)")
    for (i, o) in obs.enumerated() {
        guard let m = try? o.generateScaledMaskForImage(forInstances: IndexSet(integer: i), from: handler),
              let mCG = CIContext().createCGImage(CIImage(cvPixelBuffer: m), from: CIImage(cgImage: photo).extent) else { continue }
        if let comp = try? ForegroundSegmenter.compositeMasked(image: photo, mask: mCG),
           let cut = try? ForegroundSegmenter.tightCutout(image: comp, mask: mCG) {
            writePNG(cut.image, "s2_inst\(i).png")
        }
        if let b = maskToBytes(mCG) {
            let frac = Double(b.filter { $0 > 20 }.count) / Double(b.count)
            print("  inst\(i) frac=\(String(format: "%.3f", frac))")
        }
    }
} catch {
    print("s2 FAILED: \(error)")
}

// ---------- S3: hand-pose subtraction ----------
do {
    let segRequest = VNGenerateForegroundInstanceMaskRequest()
    let handRequest = VNDetectHumanHandPoseRequest()
    let handler = VNImageRequestHandler(cgImage: photo, options: [:])
    let t0 = Date()
    try handler.perform([segRequest, handRequest])

    guard let segObs = segRequest.results?.first else {
        print("s3 FAILED: no subject observation"); exit(0)
    }
    let segMask = try segObs.generateScaledMaskForImage(forInstances: segObs.allInstances, from: handler)
    guard let mCG = CIContext().createCGImage(CIImage(cvPixelBuffer: segMask), from: CIImage(cgImage: photo).extent),
          let mb0 = maskToBytes(mCG) else {
        print("s3 FAILED: no subject mask"); exit(0)
    }

    let hands = handRequest.results ?? []
    print("s3 hands=\(hands.count)")
    var handMask = [UInt8](repeating: 0, count: W * H)

    // Rasterize a bone segment as a capsule: all pixels within `r` of segment AB.
    func capsule(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat), r: CGFloat) {
        let minX = max(0, Int(min(a.0, b.0) - r))
        let maxX = min(W - 1, Int(max(a.0, b.0) + r))
        let minY = max(0, Int(min(a.1, b.1) - r))
        let maxY = min(H - 1, Int(max(a.1, b.1) + r))
        let abx = b.0 - a.0, aby = b.1 - a.1
        let len2 = abx * abx + aby * aby
        let r2 = r * r
        for y in minY...maxY {
            for x in minX...maxX {
                let px = CGFloat(x) - a.0, py = CGFloat(y) - a.1
                let t = len2 > 0 ? max(0, min(1, (px * abx + py * aby) / len2)) : 0
                let dx = px - t * abx, dy = py - t * aby
                if dx * dx + dy * dy <= r2 { handMask[y * W + x] = 255 }
            }
        }
    }

    for hand in hands {
        func pt(_ name: VNHumanHandPoseObservation.JointName) -> (CGFloat, CGFloat)? {
            guard let p = try? hand.recognizedPoint(name), p.confidence > 0.3 else { return nil }
            return (p.location.x * CGFloat(W), (1 - p.location.y) * CGFloat(H))
        }
        let joints: [VNHumanHandPoseObservation.JointName] = [
            .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
            .indexMCP, .indexPIP, .indexDIP, .indexTip,
            .middleMCP, .middlePIP, .middleDIP, .middleTip,
            .ringMCP, .ringPIP, .ringDIP, .ringTip,
            .littleMCP, .littlePIP, .littleDIP, .littleTip
        ]
        let P: [(CGFloat, CGFloat)?] = joints.map { pt($0) }
        guard let wrist = P[0], let middleTip = P[12] else {
            print("  hand: missing core joints"); continue
        }
        // scale hand radius from wrist->middleFinger length
        let handLen = hypot(middleTip.0 - wrist.0, middleTip.1 - wrist.1)
        let fingerR = handLen * 0.22
        let palmR = handLen * 0.42
        func bone(_ i: Int, _ j: Int, r: CGFloat) {
            guard let a = P[i], let b = P[j] else { return }
            capsule(a, b, r: r)
        }
        // finger chains: thumb 1-4, index 5-8, middle 9-12, ring 13-16, little 17-20
        for base in stride(from: 1, to: 20, by: 4) {
            bone(base, base + 1, r: fingerR)
            bone(base + 1, base + 2, r: fingerR)
            bone(base + 2, base + 3, r: fingerR)
        }
        // palm spokes + web line
        bone(0, 5, r: palmR); bone(0, 9, r: palmR); bone(0, 13, r: palmR); bone(0, 17, r: palmR)
        bone(5, 9, r: palmR); bone(9, 13, r: palmR); bone(13, 17, r: palmR)
        print("  hand bones drawn, fingerR=\(Int(fingerR))px")
    }
    handMask = dilate(handMask, w: W, h: H, r: 10)
    var mb = subtract(mb0, handMask)
    mb = close(mb, w: W, h: H, r: 8)

    guard let outMask = bytesToMask(mb, w: W, h: H) else { print("s3 FAILED: mask rebuild"); exit(0) }
    if let comp = try? ForegroundSegmenter.compositeMasked(image: photo, mask: outMask),
       let cut = try? ForegroundSegmenter.tightCutout(image: comp, mask: outMask) {
        writePNG(cut.image, "s3_handpose.png")
    }
    maskPreview(mask: outMask, name: "s3_mask_preview.png")
    print("s3 done ms=\(Int(Date().timeIntervalSince(t0) * 1000))")
} catch {
    print("s3 FAILED: \(error)")
}

// ---------- S4: skin-color subtraction ----------
do {
    let segRequest = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: photo, options: [:])
    try handler.perform([segRequest])
    guard let segObs = segRequest.results?.first else {
        print("s4 FAILED: no subject observation"); exit(0)
    }
    let segMask = try segObs.generateScaledMaskForImage(forInstances: segObs.allInstances, from: handler)
    guard let mCG = CIContext().createCGImage(CIImage(cvPixelBuffer: segMask), from: CIImage(cgImage: photo).extent),
          let mb0 = maskToBytes(mCG) else {
        print("s4 FAILED: no subject mask"); exit(0)
    }
    var rgba = [UInt8](repeating: 0, count: W * H * 4)
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: &rgba, width: W, height: H, bitsPerComponent: 8,
                              bytesPerRow: W * 4, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        print("s4 FAILED: ctx"); exit(0)
    }
    ctx.draw(photo, in: CGRect(x: 0, y: 0, width: W, height: H))
    var skin = [UInt8](repeating: 0, count: W * H)
    for y in 0..<H {
        for x in 0..<W {
            let i = (y * W + x) * 4
            let r = Double(rgba[i]) / 255, g = Double(rgba[i + 1]) / 255, b = Double(rgba[i + 2]) / 255
            let mx = max(r, g, b), mn = min(r, g, b)
            let sat = (mx - mn) / max(mx, 0.001)
            let warm = r > g && g > b && (r - g) > 0.03 && (g - b) > 0.015
            if warm && sat < 0.80 && mx > 0.12 && mx < 0.98 { skin[y * W + x] = 255 }
        }
    }
    // keep only "solid" skin (erode-dilate drops the thin rim that hugs tool edges)
    let solidSkin = dilate(erode(skin, w: W, h: H, r: 6), w: W, h: H, r: 10)
    var mb = subtract(mb0, solidSkin)
    mb = close(mb, w: W, h: H, r: 8)

    guard let outMask = bytesToMask(mb, w: W, h: H) else { print("s4 FAILED: mask rebuild"); exit(0) }
    if let comp = try? ForegroundSegmenter.compositeMasked(image: photo, mask: outMask),
       let cut = try? ForegroundSegmenter.tightCutout(image: comp, mask: outMask) {
        writePNG(cut.image, "s4_skincolor.png")
    }
    maskPreview(mask: outMask, name: "s4_mask_preview.png")
    print("s4 done")
} catch {
    print("s4 FAILED: \(error)")
}

print("ALL DONE")
