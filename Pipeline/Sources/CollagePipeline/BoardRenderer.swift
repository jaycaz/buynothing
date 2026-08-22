import Foundation
import CoreGraphics

/// Renders a single pipeline run into one composite PNG ("board") that shows the whole journey:
/// each input → its cutout → its aligned result, the final collage, and the aggregate metrics.
/// This is the primary artifact for quick visual inspection and for sending screenshots.
public enum BoardRenderer {

    public static func render(output: PipelineOutput) -> CGImage {
        let stages = output.stages
        let margin: CGFloat = 28
        let headerH: CGFloat = 64
        let tile: CGFloat = 200
        let gap: CGFloat = 16
        let labelH: CGFloat = 22
        let cols = 3
        let gridW = CGFloat(cols) * tile + CGFloat(cols - 1) * gap
        let boardW = margin * 2 + gridW

        let collage = output.collage
        let collageW: CGFloat = gridW
        let collageH: CGFloat = (collage != nil) ? CGFloat(collage!.height) * (gridW / CGFloat(collage!.width)) : 0

        // Vertical layout (top-down), computed so the board is exactly as tall as it needs to be.
        var y = margin
        y += headerH
        for _ in stages { y += labelH + tile + gap }
        if let _ = collage { y += labelH + collageH + gap }
        let metricsLines = 6
        y += labelH + CGFloat(metricsLines) * 20 + margin
        let boardH = y

        let ctx = Canvas.begin(width: Int(boardW), height: Int(boardH))

        // Background
        ctx.setFillColor(CGColor(gray: 0.985, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: boardW, height: boardH))

        // Header
        let configStr = output.configDescription
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "   ")
        ImageIOHelpers.drawText("Collage Pipeline — screwdriver", topDownX: margin, topDownY: margin, boardHeight: boardH, ctx: ctx, size: 22, color: CGColor(gray: 0.05, alpha: 1))
        ImageIOHelpers.drawText(configStr, topDownX: margin, topDownY: margin + 30, boardHeight: boardH, ctx: ctx, size: 13, color: CGColor(gray: 0.45, alpha: 1))

        // Column titles
        let colTitles = ["input", "cutout (seg)", "aligned"]
        for c in 0..<cols {
            let x = margin + CGFloat(c) * (tile + gap)
            ImageIOHelpers.drawText(colTitles[c], topDownX: x, topDownY: margin + headerH, boardHeight: boardH, ctx: ctx, size: 13, color: CGColor(gray: 0.5, alpha: 1))
        }

        // Per-seed rows
        var rowTop = margin + headerH + labelH
        for stage in stages {
            let iouStr = stage.metrics?.segmentationIoU.map { String(format: "IoU %.2f", $0) } ?? "—"
            let resStr = stage.metrics.map { String(format: "residual %.0f°", $0.alignedResidualDegrees) } ?? "—"
            ImageIOHelpers.drawText("seed \(stage.seed)   ·   \(iouStr)   ·   \(resStr)", topDownX: margin, topDownY: rowTop, boardHeight: boardH, ctx: ctx, size: 12, color: CGColor(gray: 0.35, alpha: 1))
            rowTop += labelH

            let tiles: [(label: String, image: CGImage?, checkerboard: Bool)] = [
                ("input", stage.input, false),
                ("cutout", stage.cutout, true),
                ("aligned", stage.aligned, true)
            ]
            for (c, t) in tiles.enumerated() {
                let x = margin + CGFloat(c) * (tile + gap)
                let rectTopDown = CGRect(x: x, y: rowTop, width: tile, height: tile)
                let rect = ImageIOHelpers.toBottomLeft(rectTopDown, boardHeight: boardH)
                if t.checkerboard {
                    ImageIOHelpers.fillCheckerboard(rect, cell: 16, a: CGColor(gray: 0.86, alpha: 1), b: CGColor(gray: 0.96, alpha: 1), ctx: ctx)
                } else {
                    ctx.setFillColor(CGColor(gray: 0.9, alpha: 1))
                    ctx.fill(rect)
                }
                if let img = t.image {
                    ImageIOHelpers.drawContained(img, in: rect.insetBy(dx: 6, dy: 6), ctx: ctx)
                } else {
                    ImageIOHelpers.drawText("n/a", topDownX: x + tile / 2 - 12, topDownY: rowTop + tile / 2, boardHeight: boardH, ctx: ctx, size: 14, color: CGColor(gray: 0.5, alpha: 1))
                }
            }
            rowTop += tile + gap
        }

        // Collage
        if let collage {
            ImageIOHelpers.drawText("collage", topDownX: margin, topDownY: rowTop, boardHeight: boardH, ctx: ctx, size: 14, color: CGColor(gray: 0.35, alpha: 1))
            rowTop += labelH
            let rectTopDown = CGRect(x: margin, y: rowTop, width: collageW, height: collageH)
            let rect = ImageIOHelpers.toBottomLeft(rectTopDown, boardHeight: boardH)
            ctx.setFillColor(CGColor(gray: 0.96, alpha: 1))
            ctx.fill(rect)
            ImageIOHelpers.drawContained(collage, in: rect, ctx: ctx)
            rowTop += collageH + gap
        }

        // Summary metrics
        ImageIOHelpers.drawText("summary", topDownX: margin, topDownY: rowTop, boardHeight: boardH, ctx: ctx, size: 14, color: CGColor(gray: 0.35, alpha: 1))
        rowTop += labelH
        let a = output.aggregate
        let p = output.packing
        let fmt = { (v: Double?) in v.map { String(format: "%.3f", $0) } ?? "n/a" }
        let lines = [
            "segmentation IoU  mean \(fmt(a.segmentationIoUMean))  med \(fmt(a.segmentationIoUMedian))  min \(fmt(a.segmentationIoUMin))  max \(fmt(a.segmentationIoUMax))",
            "alignment  success \(String(format: "%.0f%%", a.alignmentSuccessRate * 100))   rows \(p.rows)   items/row \(p.itemsPerRow.map(String.init).joined(separator: ","))   canvas \(Int(p.canvasWidth))x\(Int(p.canvasHeight))",
            "timing  seg \(String(format: "%.0fms", a.meanSegmentationMs))   align \(String(format: "%.0fms", a.meanAlignmentMs))   total \(String(format: "%.0fms", a.totalMs))"
        ]
        for (i, line) in lines.enumerated() {
            ImageIOHelpers.drawText(line, topDownX: margin, topDownY: rowTop + CGFloat(i) * 20, boardHeight: boardH, ctx: ctx, size: 12, color: CGColor(gray: 0.25, alpha: 1))
        }

        guard let image = ctx.makeImage() else {
            fatalError("Failed to render board image")
        }
        return image
    }
}
