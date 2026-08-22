import Foundation
import CoreGraphics

/// Builds a single self-contained `report.html` (images embedded as base64 data URIs) so it can
/// be opened in any browser and shared without its PNG sidecar files. When multiple runs are
/// provided (e.g. `--compare`), it adds a side-by-side metric comparison table.
public enum HTMLRenderer {

    public static func render(runs: [ReportWriter.Run]) -> String {
        var s = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Collage Pipeline Report</title>
        <style>
        body{font-family:-apple-system,Helvetica,Arial,sans-serif;background:#f3f4f6;color:#1f2937;margin:0;padding:24px}
        h1{font-size:24px;margin:0 0 4px} h2{font-size:18px;margin:28px 0 8px}
        .meta{color:#64748b;font-size:13px;margin-bottom:8px}
        .run{background:#fff;border:1px solid #e5e7eb;border-radius:12px;padding:16px;margin:16px 0;box-shadow:0 1px 2px rgba(0,0,0,.04)}
        .runhead{display:flex;justify-content:space-between;align-items:baseline;flex-wrap:wrap;gap:6px}
        .grid{display:flex;flex-wrap:wrap;gap:12px}
        .stage{width:206px;border:1px solid #e5e7eb;border-radius:8px;padding:8px}
        .tiles{display:flex;gap:6px;margin-top:6px}
        .tile{width:96px;height:96px;border-radius:6px;overflow:hidden;background:#e9e9ee;display:flex;align-items:center;justify-content:center}
        .tile.chk{background:repeating-conic-gradient(#d9d9de 0% 25%, #f2f2f4 0% 50%) 50% / 18px 18px}
        .tile img{max-width:100%;max-height:100%;object-fit:contain}
        .metrics{font-size:11px;color:#475569;margin-top:8px;line-height:1.5}
        table{border-collapse:collapse;margin:12px 0}
        th,td{border:1px solid #e5e7eb;padding:6px 10px;text-align:right;font-size:13px}
        th:first-child,td:first-child{text-align:left}
        th{background:#f8fafc}
        .collage{width:100%;max-width:900px;border:1px solid #e5e7eb;border-radius:8px;margin-top:8px;display:block}
        .kv{font-size:12px;color:#475569;margin:4px 0;font-family:ui-monospace,Menlo,monospace}
        .na{color:#9ca3af;font-size:11px}
        </style></head><body>
        <h1>Collage Pipeline Report</h1>
        <p class="meta">screwdriver segmentation → alignment → packing · generated \(timestamp())</p>
        """

        if runs.count > 1 { s += comparisonTable(runs) }
        for run in runs { s += runSection(run) }

        s += "</body></html>"
        return s
    }

    // MARK: - pieces

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: Date())
    }

    private static func img(_ cg: CGImage?, chk: Bool = false) -> String {
        guard let cg else { return "<div class='tile \(chk ? "chk" : "")'><span class='na'>n/a</span></div>" }
        let b64 = ImageIOHelpers.base64PNG(from: cg)
        return "<div class='tile \(chk ? "chk" : "")'><img src='data:image/png;base64,\(b64)'></div>"
    }

    private static func runSection(_ run: ReportWriter.Run) -> String {
        let configKv = run.output.configDescription
            .sorted { $0.key < $1.key }
            .map { "<span class='kv'>\($0.key) = <b>\($0.value)</b></span>" }
            .joined(separator: " &nbsp; ")

        var stages = ""
        for st in run.output.stages {
            let m = st.metrics
            let iou = m?.segmentationIoU.map { String(format: "%.3f", $0) } ?? "—"
            let res = m.map { String(format: "%.1f°", $0.alignedResidualDegrees) } ?? "—"
            let aspect = m.map { String(format: "%.2f", $0.alignedAspectRatio) } ?? "—"
            let err = st.error.map { "<div class='metrics' style='color:#b91c1c'>⚠ \($0)</div>" } ?? ""
            stages += """
            <div class='stage'>
              <div>seed <b>\(st.seed)</b> &nbsp; <span class='na'>in \(Int(st.input.width))x\(Int(st.input.height))</span></div>
              <div class='tiles'>\(img(st.input))\(img(st.cutout, chk: true))\(img(st.aligned, chk: true))</div>
              <div class='metrics'>IoU <b>\(iou)</b> · residual <b>\(res)</b> · aspect(h/w) \(aspect)<br>
              seg \(fmtMs(m?.segmentationMs)) · align \(fmtMs(m?.alignmentMs))</div>\(err)
            </div>
            """
        }

        let collage = run.output.collage
            .map { "<img class='collage' src='data:image/png;base64,\(ImageIOHelpers.base64PNG(from: $0))'>" }
            ?? "<p class='na'>no collage (no items survived the pipeline)</p>"

        let a = run.output.aggregate
        let p = run.output.packing
        let summary = """
        <h3>summary</h3>
        <table>
        <tr><th>segmentation IoU</th><td>mean \(f(a.segmentationIoUMean))</td><td>median \(f(a.segmentationIoUMedian))</td><td>min \(f(a.segmentationIoUMin))</td><td>max \(f(a.segmentationIoUMax))</td></tr>
        <tr><th>alignment</th><td>success \(String(format: "%.0f%%", a.alignmentSuccessRate * 100))</td><td>rows \(p.rows)</td><td>items/row \(p.itemsPerRow.map(String.init).joined(separator: ","))</td><td>canvas \(Int(p.canvasWidth))x\(Int(p.canvasHeight))</td></tr>
        <tr><th>timing</th><td>seg \(fmtMs(a.meanSegmentationMs))</td><td>align \(fmtMs(a.meanAlignmentMs))</td><td colspan="2">total \(fmtMs(a.totalMs))</td></tr>
        </table>
        """

        return """
        <div class='run'>
          <div class='runhead'><h2>\(run.tag)</h2><div>\(configKv)</div></div>
          <div class='grid'>\(stages)</div>
          <h3>collage</h3>\(collage)
          \(summary)
        </div>
        """
    }

    private static func comparisonTable(_ runs: [ReportWriter.Run]) -> String {
        var rows: [(label: String, values: [String])] = []
        func row(_ label: String, _ f: (AggregateMetrics) -> String?) {
            rows.append((label, runs.map { f($0.output.aggregate) ?? "—" }))
        }
        row("IoU mean") { f($0.segmentationIoUMean) }
        row("IoU median") { f($0.segmentationIoUMedian) }
        row("IoU min") { f($0.segmentationIoUMin) }
        row("IoU max") { f($0.segmentationIoUMax) }
        row("alignment success") { String(format: "%.0f%%", $0.alignmentSuccessRate * 100) }
        row("mean seg ms") { fmtMs($0.meanSegmentationMs) }
        row("mean align ms") { fmtMs($0.meanAlignmentMs) }
        row("total ms") { fmtMs($0.totalMs) }

        let header = "<th>metric</th>" + runs.map { "<th>\($0.tag)</th>" }.joined()
        let body = rows.map { r in "<tr><td>\(r.label)</td>" + r.values.map { "<td>\($0)</td>" }.joined() + "</tr>" }.joined()
        return "<h2>comparison</h2><table><tr>\(header)</tr>\(body)</table>"
    }

    // MARK: - formatting

    private static func f(_ v: Double?) -> String { v.map { String(format: "%.3f", $0) } ?? "—" }
    private static func fmtMs(_ v: Double?) -> String { v.map { String(format: "%.0fms", $0) } ?? "—" }
}
