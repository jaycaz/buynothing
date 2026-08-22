import Testing
import Foundation
import CoreGraphics
@testable import CollagePipeline

/// Simple binary masks for validating the metric and geometry helpers in isolation.
enum TestMask {
    static func solid(w: Int, h: Int) -> CGImage {
        let ctx = makeContext(w, h)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }
    static func withRect(_ rect: CGRect, in w: Int, _ h: Int) -> CGImage {
        let ctx = makeContext(w, h)!
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(rect)
        return ctx.makeImage()!
    }
    private static func makeContext(_ w: Int, _ h: Int) -> CGContext? {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    }
}

@Suite("CollagePipeline core")
struct CollagePipelineTests {

    // MARK: - IoU metric

    @Test("IoU of a mask with itself is 1.0")
    func iouSelf() {
        let m = TestMask.solid(w: 120, h: 80)
        let v = Metrics.iou(predictedMask: m, groundTruthMask: m)!
        #expect(abs(v - 1.0) < 0.001)
    }

    @Test("IoU of disjoint masks is ~0")
    func iouDisjoint() {
        let a = TestMask.withRect(CGRect(x: 0, y: 0, width: 30, height: 30), in: 100, 100)
        let b = TestMask.withRect(CGRect(x: 70, y: 70, width: 30, height: 30), in: 100, 100)
        let v = Metrics.iou(predictedMask: a, groundTruthMask: b)!
        #expect(v < 0.01)
    }

    @Test("IoU is computed exactly (50% overlap case)\n")
    func iouPartial() {
        // Two 60x60 squares offset by 20px: overlap 40x60=2400, union 3600+3600-2400=4800, IoU=0.5
        let a = TestMask.withRect(CGRect(x: 0, y: 0, width: 60, height: 60), in: 100, 100)
        let b = TestMask.withRect(CGRect(x: 20, y: 0, width: 60, height: 60), in: 100, 100)
        let v = Metrics.iou(predictedMask: a, groundTruthMask: b)!
        #expect(abs(v - 0.5) < 0.02)
    }

    // MARK: - packing invariants

    @Test("justified full rows span the canvas width")
    func packingJustified() {
        let sizes = (0..<6).map { CGSize(width: CGFloat(90 + $0 * 12), height: 200) }
        let layout = CollageJustifiedPacker.pack(itemSizes: sizes, canvasWidth: 900, targetRowHeight: 200, spacing: 6)
        #expect(!layout.placements.isEmpty)
        let rows = Dictionary(grouping: layout.placements) { Int(round($0.rect.minY)) }
        for (_, row) in rows where row.count > 1 {
            let total = row.reduce(CGFloat(0)) { $0 + $1.rect.width }
            let gutters = CGFloat(row.count - 1) * 6
            #expect(abs(total + gutters - 900) < 2)
        }
    }

    @Test("placements never overlap and stay inside the canvas")
    func packingNoOverlap() {
        let sizes = (0..<9).map { CGSize(width: CGFloat(70 + ($0 % 5) * 25), height: CGFloat(160)) }
        let layout = CollageJustifiedPacker.pack(itemSizes: sizes, canvasWidth: 800, targetRowHeight: 160, spacing: 4)
        #expect(layout.placements.count == sizes.count)
        for pl in layout.placements {
            #expect(pl.rect.minX >= 0)
            #expect(pl.rect.maxX <= 800 + 1)
            #expect(pl.rect.minY >= 0)
            #expect(pl.rect.maxY <= layout.canvasSize.height + 1)
        }
        for i in 0..<layout.placements.count {
            for j in (i + 1)..<layout.placements.count {
                let overlap = layout.placements[i].rect.intersection(layout.placements[j].rect)
                #expect(overlap.width < 0.01 && overlap.height < 0.01)
            }
        }
    }

    @Test("empty input yields an empty layout")
    func packingEmpty() {
        let layout = CollageJustifiedPacker.pack(itemSizes: [], canvasWidth: 900, targetRowHeight: 200)
        #expect(layout.placements.isEmpty)
        #expect(layout.canvasSize == .zero)
    }

    // MARK: - alignment

    @Test("aligning a rotated screwdriver yields a tall, near-vertical cutout")
    func alignmentVertical() {
        let photo = SyntheticToolImageGenerator.generateScrewdriverPhoto(seed: 42)
        let composited = try! ForegroundSegmenter.compositeMasked(image: photo.cgImage, mask: photo.groundTruthMask)
        let cutout = try! ForegroundSegmenter.tightCutout(image: composited, mask: photo.groundTruthMask)
        let aligned = ObjectOrientationAligner.align(cutout)
        #expect(Double(aligned.height) > Double(aligned.width))   // tall
        #expect(Metrics.alignmentResidualDegrees(ofAlpha: aligned) < 15)
    }

    // MARK: - segmentation

    @Test("vision segmentation runs and produces a valid cutout (no crash)")
    func visionRuns() {
        let photo = SyntheticToolImageGenerator.generateScrewdriverPhoto(seed: 3)
        do {
            let cutout = try ForegroundSegmenter.cutoutForegroundObject(from: photo.cgImage)
            #expect(cutout.image.width > 0 && cutout.image.height > 0)
        } catch {
            #expect(Bool(false), "unexpected: vision segmentation threw: \(error)")
        }
    }

    @Test("bounding box of a known mask is tight")
    func boundingBoxTight() throws {
        let m = TestMask.withRect(CGRect(x: 10, y: 20, width: 40, height: 50), in: 100, 100)
        let bb = try ForegroundSegmenter.boundingBox(ofMask: m)
        #expect(Int(bb.width) == 40)
        #expect(Int(bb.height) == 50)
    }

    // MARK: - text rendering orientation

    /// Returns the vertical ink extent (top/bottom pixel rows; row 0 = image top) of dark
    /// pixels within the given horizontal half of the image, or nil if no ink is present.
    private static func inkBounds(in image: CGImage, leftHalf: Bool) -> (top: Int, bottom: Int)? {
        guard let provider = image.dataProvider, let data = provider.data else { return nil }
        let ptr = CFDataGetBytePtr(data)!
        let w = image.width, h = image.height, bpr = image.bytesPerRow
        let bytesPerPx = image.bitsPerPixel / 8
        let xRange = leftHalf ? 0..<(w / 2) : (w / 2)..<w
        var top = Int.max, bottom = Int.min
        for y in 0..<h {
            for x in xRange {
                if ptr[y * bpr + x * bytesPerPx] < 128 {  // dark ink on a light background
                    top = min(top, y); bottom = max(bottom, y)
                }
            }
        }
        return top == Int.max ? nil : (top, bottom)
    }

    @Test("drawText renders upright, not vertically flipped")
    func drawTextUpright() {
        // 'p' (left) has a descender; 'b' (right) has an ascender. In upright text the
        // ink of 'p' must sit LOWER than the ink of 'b' at the top, and extend LOWER at
        // the bottom. A vertically-flipped (mirrored) rendering inverts both relations —
        // this is the exact board.png bug the harness caught on 2026-08-18.
        let W: CGFloat = 240, H: CGFloat = 160
        let image = Canvas.render(width: Int(W), height: Int(H)) { ctx in
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
            ImageIOHelpers.drawText("p", topDownX: 20, topDownY: 40, boardHeight: H, ctx: ctx, size: 64, color: CGColor(gray: 0, alpha: 1))
            ImageIOHelpers.drawText("b", topDownX: 140, topDownY: 40, boardHeight: H, ctx: ctx, size: 64, color: CGColor(gray: 0, alpha: 1))
        }
        let p = Self.inkBounds(in: image, leftHalf: true)
        let b = Self.inkBounds(in: image, leftHalf: false)
        #expect(p != nil, "no ink rendered for 'p'")
        #expect(b != nil, "no ink rendered for 'b'")
        #expect(p!.top > b!.top + 5, "text looks vertically flipped: 'p' top \(p!.top) should be below 'b' ascender top \(b!.top)")
        #expect(p!.bottom > b!.bottom, "text looks vertically flipped: 'p' descender should extend below 'b' baseline (\(p!.bottom) vs \(b!.bottom))")
    }

    @Test("drawText places the top of the text at topDownY")
    func drawTextTopPosition() {
        let W: CGFloat = 200, H: CGFloat = 120
        let ytd: CGFloat = 30
        let image = Canvas.render(width: Int(W), height: Int(H)) { ctx in
            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
            ImageIOHelpers.drawText("T", topDownX: 20, topDownY: ytd, boardHeight: H, ctx: ctx, size: 40, color: CGColor(gray: 0, alpha: 1))
        }
        let bounds = Self.inkBounds(in: image, leftHalf: true)
        #expect(bounds != nil, "no ink rendered")
        // Top of the 'T' ink should land near topDownY (within a fraction of the font size).
        #expect(abs(bounds!.top - Int(ytd)) <= 20, "ink top \(bounds!.top) should be near topDownY \(ytd)")
    }

    // MARK: - end-to-end

    @Test("full pipeline (ground truth) produces a collage with all items")
    func fullPipeline() {
        let config = PipelineConfig(segmenter: .groundTruth, count: 5, seedBase: 0,
                                    canvasSize: CGSize(width: 480, height: 480),
                                    canvasWidth: 800, targetRowHeight: 180, spacing: 6)
        let output = Pipeline(config: config).run()
        #expect(output.stages.count == 5)
        #expect(output.stages.allSatisfy { $0.error == nil })
        #expect(output.collage != nil)
        #expect(output.packing.itemCount == 5)
        #expect((output.aggregate.segmentationIoUMean ?? 0) > 0.99)  // ground truth ≈ perfect
    }

    @Test("rotate 90° swaps a tall mask to a wide one")
    func rotate90() {
        let m = TestMask.solid(w: 60, h: 120)
        let r = ImageGeometry.rotate(m, by: .pi / 2)
        #expect(r.width > r.height)
    }

    @Test("board renders to a PNG (visual sanity check)")
    func boardRenders() throws {
        let input = TestMask.solid(w: 120, h: 120)
        let cutout = TestMask.withRect(CGRect(x: 20, y: 20, width: 80, height: 80), in: 120, 120)
        let aligned = TestMask.solid(w: 30, h: 140)
        let collage = TestMask.solid(w: 240, h: 100)
        let stage = PipelineStage(seed: 0, input: input, cutout: cutout, aligned: aligned, error: nil, metrics: nil)
        let output = PipelineOutput(
            stages: [stage],
            collage: collage,
            packing: PackingMetrics(canvasWidth: 240, canvasHeight: 100, rows: 1, itemsPerRow: [1], itemCount: 1),
            aggregate: AggregateMetrics(segmentationIoUMean: 0.9, segmentationIoUMedian: 0.9, segmentationIoUMin: 0.9, segmentationIoUMax: 0.9, alignmentSuccessRate: 1.0, meanSegmentationMs: 10, meanAlignmentMs: 5, totalMs: 100),
            configDescription: ["segmenter": "vision"]
        )
        let board = BoardRenderer.render(output: output)
        try ImageIOHelpers.writePNG(board, to: URL(fileURLWithPath: "/tmp/boardtest.png"))
        #expect(board.width > 0 && board.height > 0)
    }
}
