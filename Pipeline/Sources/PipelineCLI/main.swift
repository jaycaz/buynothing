import Foundation
import CoreGraphics
import ImageIO
import Vision
import CoreImage
import CollagePipeline

// pipeline-cli — run the collage pipeline headlessly on Mac and emit screenshots + metrics.
//
//   pipeline-cli [options]
//     --count N          number of synthetic photos (default 6)
//     --seed-base N      starting seed (default 0)
//     --segmenter S      vision | handremover | ground-truth (default vision)
//     --canvas-width W   collage canvas width (default 900)
//     --row-height H     target row height (default 220)
//     --spacing S        gutter between items (default 6)
//     --input-size WxH   synthetic photo size (default 640x640)
//     --outdir PATH      output directory (default harness-output)
//     --compare          run BOTH vision and ground-truth and emit a comparison report
//     -h, --help         show this help

struct Args {
    var count = 6
    var seedBase = 0
    var segmenter = "vision"
    var canvasWidth = 900.0
    var rowHeight = 220.0
    var spacing = 6.0
    var inputSize = (640, 640)
    var outdir = "harness-output"
    var compare = false
    var showHelp = false
    var handremoverInput: String? = nil
    var handremoverOutput: String? = nil
    var handremoverSweep = false
    var sweepParams: String? = nil
    var sweepOutdir: String? = nil
    var batchInput: String? = nil
    var batchOut = "batch-output"
    var batchStrategies: String? = nil
}

func usage() -> String {
    """
    pipeline-cli — run the screwdriver collage pipeline headlessly on Mac.

    Options:
      --count N          number of synthetic photos (default 6)
      --seed-base N      starting seed (default 0)
      --segmenter S      vision | handremover | ground-truth (default vision;
                          'hand-remover'/'composite'/'ground_truth'/'groundTruth' also accepted)
      --canvas-width W   collage canvas width (default 900)
      --row-height H     target row height (default 220)
      --spacing S        gutter between items (default 6)
      --input-size WxH   synthetic photo size (default 640x640)
      --outdir PATH      output directory (default harness-output)
      --compare          run BOTH vision and ground-truth and emit a comparison report
      --batch DIR        run every photo in DIR through the segmentation strategies
      --batch-out DIR    batch output directory (default batch-output)
      --batch-strategies CSV   comma-separated strategies (default all)
      -h, --help         show this help

    Output (under --outdir):
      <tag>/00_seedN_input.png, _cutout.png, _aligned.png   per-stage screenshots
      <tag>/collage.png                                      final collage
      <tag>/board.png                                        composite overview
      <tag>/report.json                                      metrics (machine-readable)
      report.html                                            self-contained visual report

    Examples:
      pipeline-cli --count 8 --segmenter vision --compare
      pipeline-cli --count 10 --canvas-width 1200 --row-height 260 --spacing 10
    """
}

func parseArgs(_ argv: [String]) -> Args {
    var a = Args()
    var i = 1
    while i < argv.count {
        let key = argv[i]
        func next() -> String? { i += 1; return i < argv.count ? argv[i] : nil }
        switch key {
        case "--help", "-h": a.showHelp = true
        case "--compare": a.compare = true
        case "--handremover": if let v = next() { a.handremoverInput = v }
        case "--handremover-out": if let v = next() { a.handremoverOutput = v }
        case "--handremover-sweep": if let v = next() { a.handremoverInput = v; a.handremoverSweep = true }
        case "--sweep-params": if let v = next() { a.sweepParams = v }
        case "--sweep-outdir": if let v = next() { a.sweepOutdir = v }
        case "--batch": if let v = next() { a.batchInput = v }
        case "--batch-out": if let v = next() { a.batchOut = v }
        case "--batch-strategies": if let v = next() { a.batchStrategies = v }
        case "--count": if let v = next().flatMap(Int.init) { a.count = v }
        case "--seed-base": if let v = next().flatMap(Int.init) { a.seedBase = v }
        case "--segmenter": if let v = next() { a.segmenter = v }
        case "--canvas-width": if let v = next().flatMap(Double.init) { a.canvasWidth = v }
        case "--row-height": if let v = next().flatMap(Double.init) { a.rowHeight = v }
        case "--spacing": if let v = next().flatMap(Double.init) { a.spacing = v }
        case "--input-size":
            if let v = next() {
                let parts = v.lowercased().split(separator: "x").compactMap { Int($0) }
                if parts.count == 2 { a.inputSize = (parts[0], parts[1]) }
            }
        case "--outdir": if let v = next() { a.outdir = v }
        default:
            FileHandle.standardError.write(Data("warning: ignoring unknown argument \(key)\n".utf8))
        }
        i += 1
    }
    return a
}

func makeConfig(_ a: Args, segmenter: SegmenterChoice) -> PipelineConfig {
    PipelineConfig(
        segmenter: segmenter,
        count: max(1, a.count),
        seedBase: a.seedBase,
        canvasSize: CGSize(width: a.inputSize.0, height: a.inputSize.1),
        canvasWidth: a.canvasWidth,
        targetRowHeight: a.rowHeight,
        spacing: a.spacing
    )
}

func printSummary(_ tag: String, _ out: PipelineOutput) {
    let a = out.aggregate
    let p = out.packing
    func d(_ v: Double?) -> String { v.map { String(format: "%.3f", $0) } ?? "n/a" }
    print("")
    print("── \(tag) ─────────────────────────────────────────")
    print("  items: \(out.stages.count)  (failed: \(out.stages.filter { $0.error != nil }.count))")
    print("  segmentation IoU  mean \(d(a.segmentationIoUMean))  median \(d(a.segmentationIoUMedian))  min \(d(a.segmentationIoUMin))  max \(d(a.segmentationIoUMax))")
    print("  alignment success  \(String(format: "%.0f%%", a.alignmentSuccessRate * 100))")
    print("  collage            \(Int(p.canvasWidth))x\(Int(p.canvasHeight))  rows \(p.rows)  items/row [\(p.itemsPerRow.map(String.init).joined(separator: ","))]")
    print("  timing             seg \(String(format: "%.0fms", a.meanSegmentationMs))  align \(String(format: "%.0fms", a.meanAlignmentMs))  total \(String(format: "%.0fms", a.totalMs))")
}

// MARK: - main

/// File extensions the batch mode recognizes (compared lowercased).
let batchImageExtensions: Set<String> = [
    "jpg", "jpeg", "png", "heic", "heif", "webp", "avif", "tiff", "tif", "bmp", "gif"
]

let argv = CommandLine.arguments
let args = parseArgs(argv)

if args.showHelp {
    print(usage())
    exit(0)
}

if let input = args.batchInput {
    runBatch(input: input, outdir: args.batchOut, strategiesCSV: args.batchStrategies)
}

if let input = args.handremoverInput {
    if args.handremoverSweep {
        runHandRemoverSweep(input: input, paramsJSON: args.sweepParams, outdir: args.sweepOutdir)
    } else {
        runHandRemover(input: input, output: args.handremoverOutput)
    }
}
func runHandRemover(input: String, output: String?) {
    let inURL = URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
    guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        FileHandle.standardError.write(Data("error: could not load \(input)\n".utf8))
        exit(1)
    }
    do {
        let t0 = Date()
        let result = try HandRemover.segment(from: cg)
        let ms = Date().timeIntervalSince(t0) * 1000
        let base = inURL.deletingPathExtension().path
        let outPath = output ?? (base + "_handremoved.png")
        try ImageIOHelpers.writePNG(result.image, to: URL(fileURLWithPath: outPath))
        let maskPath = base + "_handremoved_mask.png"
        try ImageIOHelpers.writePNG(result.fullMask, to: URL(fileURLWithPath: maskPath))
        print(String(format: "handremover: %dx%d -> %dx%d  %.0fms", cg.width, cg.height, result.image.width, result.image.height, ms))
        print("  cutout: \(outPath)")
        print("  mask:   \(maskPath)")
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("handremover error: \(error)\n".utf8))
        exit(1)
    }
}

// MARK: - batch segmentation comparison

/// One row of <outdir>/results.json. `error` is always present (null on success),
/// so rows have a stable shape for downstream tooling.
struct BatchResultRow: Encodable {
    let file: String
    let strategy: String
    let ok: Bool
    let keptFraction: Double
    let width: Int
    let height: Int
    let ms: Double
    let error: String?

    enum CodingKeys: String, CodingKey {
        case file, strategy, ok, keptFraction, width, height, ms, error
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(file, forKey: .file)
        try c.encode(strategy, forKey: .strategy)
        try c.encode(ok, forKey: .ok)
        try c.encode(keptFraction, forKey: .keptFraction)
        try c.encode(width, forKey: .width)
        try c.encode(height, forKey: .height)
        try c.encode(ms, forKey: .ms)
        if let error { try c.encode(error, forKey: .error) } else { try c.encodeNil(forKey: .error) }
    }
}

func htmlEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
     .replacingOccurrences(of: "\"", with: "&quot;")
}

/// Run every photo in a folder through the requested segmentation strategies.
///
/// Writes, under `outdir`:
///   <stem>_<strategy>.png   one cutout PNG per (image, strategy) pair
///   results.json            machine-readable per-pair results
///   report.html             self-contained visual report (checkerboard behind cutouts)
/// and prints one TSV line per (image, strategy) pair plus a final summary line:
///   batch: <N> images, <M> ok, <K> failed
func runBatch(input: String, outdir: String, strategiesCSV: String?) {
    // Resolve the strategy list (CSV of raw values; default: all cases).
    let strategies: [SegmentationStrategy]
    if let csv = strategiesCSV, !csv.isEmpty {
        let requested = csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        strategies = requested.compactMap { raw in
            SegmentationStrategy.allCases.first { $0.rawValue.lowercased() == raw }
        }
        if strategies.isEmpty {
            let known = SegmentationStrategy.allCases.map(\.rawValue).joined(separator: ", ")
            FileHandle.standardError.write(Data("error: --batch-strategies matched no known strategy (known: \(known))\n".utf8))
            exit(1)
        }
    } else {
        strategies = SegmentationStrategy.allCases
    }

    // Collect image files (non-recursive, sorted by filename).
    let inDir = URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
    let files: [URL]
    do {
        let entries = try FileManager.default.contentsOfDirectory(at: inDir, includingPropertiesForKeys: nil)
        files = entries
            .filter { batchImageExtensions.contains(($0.pathExtension as NSString).lowercased) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    } catch {
        FileHandle.standardError.write(Data("error: cannot read input directory \(inDir.path): \(error)\n".utf8))
        exit(1)
    }
    guard !files.isEmpty else {
        let exts = batchImageExtensions.sorted().joined(separator: " ")
        FileHandle.standardError.write(Data("error: no matching images in \(inDir.path) (extensions: \(exts))\n".utf8))
        exit(1)
    }

    let outDir = URL(fileURLWithPath: (outdir as NSString).expandingTildeInPath)
    do { try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true) }
    catch {
        FileHandle.standardError.write(Data("error: cannot create output directory \(outDir.path): \(error)\n".utf8))
        exit(1)
    }

    // Per-image rows, in file order.
    struct ImageRow {
        let name: String
        let measurements: [SegmentationMeasurement]
    }
    var imageRows: [ImageRow] = []
    var okPairs = 0, failedPairs = 0

    for file in files {
        let name = file.lastPathComponent
        guard let src = CGImageSourceCreateWithURL(file as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            // Unloadable image: report every strategy as a failure.
            for s in strategies {
                print([name, s.rawValue, "0.000", "0", "ERROR"].joined(separator: "\t"))
                failedPairs += 1
            }
            imageRows.append(ImageRow(name: name, measurements: strategies.map {
                SegmentationMeasurement(strategy: $0, keptFraction: 0, cutoutWidth: 0,
                                        cutoutHeight: 0, milliseconds: 0, error: "could not decode image")
            }))
            continue
        }

        // Measurements via the shared library (never throws per strategy).
        var measurements = SegmentationComparison.compare(image: cg, strategies: strategies)

        // Write each successful cutout; a write failure downgrades that pair to an error.
        for i in measurements.indices {
            let m = measurements[i]
            guard m.error == nil else { continue }
            let pngURL = outDir.appendingPathComponent("\(file.deletingPathExtension().lastPathComponent)_\(m.strategy.rawValue).png")
            do {
                let cutout = try Segmentation.run(cg, strategy: m.strategy).image
                try ImageIOHelpers.writePNG(cutout, to: pngURL)
            } catch {
                measurements[i] = SegmentationMeasurement(strategy: m.strategy, keptFraction: m.keptFraction,
                                                           cutoutWidth: m.cutoutWidth, cutoutHeight: m.cutoutHeight,
                                                           milliseconds: m.milliseconds,
                                                           error: String(describing: error))
            }
        }

        for m in measurements {
            if m.error == nil { okPairs += 1 } else { failedPairs += 1 }
            let status = m.error == nil ? "OK" : "ERROR"
            print([
                name,
                m.strategy.rawValue,
                String(format: "%.3f", m.keptFraction),
                String(Int(m.milliseconds.rounded())),
                status
            ].joined(separator: "\t"))
        }
        imageRows.append(ImageRow(name: name, measurements: measurements))
    }

    // results.json
    let rows: [BatchResultRow] = imageRows.flatMap { row in
        row.measurements.map { m in
            BatchResultRow(file: row.name, strategy: m.strategy.rawValue, ok: m.error == nil,
                           keptFraction: m.keptFraction, width: m.cutoutWidth, height: m.cutoutHeight,
                           ms: m.milliseconds, error: m.error)
        }
    }
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(rows).write(to: outDir.appendingPathComponent("results.json"))
    } catch {
        FileHandle.standardError.write(Data("error: failed to write results.json: \(error)\n".utf8))
        exit(1)
    }

    // report.html — self-contained, one row per image, one cell per strategy.
    var html = "<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\">\n"
    html += "<title>Segmentation batch report</title>\n<style>\n"
    html += "body { font-family: -apple-system, 'Helvetica Neue', Arial, sans-serif; margin: 24px; }\n"
    html += "table { border-collapse: collapse; width: 100%; }\n"
    html += "th, td { border: 1px solid #ccc; padding: 8px; text-align: center; vertical-align: top; }\n"
    html += "th { background: #f4f4f4; }\n"
    html += "td.cell { background: repeating-conic-gradient(#d4d4d4 0% 25%, #ffffff 0% 50%) 0 0 / 16px 16px; }\n"
    html += "td img { max-width: 300px; max-height: 300px; display: block; margin: 0 auto; }\n"
    html += ".meta { font-size: 12px; color: #333; margin-top: 6px; }\n"
    html += ".err { color: #b00000; font-size: 12px; }\n"
    html += "</style></head><body>\n"
    html += "<h1>Segmentation batch report</h1>\n"
    html += "<table>\n<tr><th>Image</th>"
    for s in strategies { html += "<th>\(htmlEscape(s.displayName))</th>" }
    html += "</tr>\n"
    for row in imageRows {
        html += "<tr><td>\(htmlEscape(row.name))</td>"
        for m in row.measurements {
            if m.error == nil {
                let dot = row.name.lastIndex(of: ".")
                let stem = dot.map { String(row.name[..<$0]) } ?? row.name
                let imgName = "\(stem)_\(m.strategy.rawValue).png"
                html += "<td class=\"cell\"><img src=\"\(htmlEscape(imgName))\">"
                let keptText = String(format: "%.3f", m.keptFraction)
                let msText = String(Int(m.milliseconds.rounded()))
                html += "<div class=\"meta\">kept \(keptText) &middot; \(msText)ms</div></td>"
            } else {
                html += "<td><div class=\"err\">ERROR<br>\(htmlEscape(m.error ?? "unknown"))</div></td>"
            }
        }
        html += "</tr>\n"
    }
    html += "</table>\n</body></html>\n"
    do {
        try html.data(using: .utf8)!.write(to: outDir.appendingPathComponent("report.html"))
    } catch {
        FileHandle.standardError.write(Data("error: failed to write report.html: \(error)\n".utf8))
        exit(1)
    }

    print("batch: \(files.count) images, \(okPairs) ok, \(failedPairs) failed")
    exit(0)
}

// MARK: - handremover sweep

func loadSweepParams(_ path: String) -> [HandRemover.Params] {
    let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    guard let data = try? Data(contentsOf: url),
          let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else {
        FileHandle.standardError.write(Data("error: cannot parse sweep params JSON at \(path)\n".utf8))
        exit(1)
    }
    return arr.map { obj in
        var p = HandRemover.Params()
        func f(_ k: String) -> Float? { (obj[k] as? Double).map(Float.init) ?? (obj[k] as? Float) }
        func i(_ k: String) -> Int? { obj[k] as? Int }
        if let v = f("skinRBGap") { p.skinRBGap = v }
        if let v = f("skinValMin") { p.skinValMin = v }
        if let v = f("blueSatMin") { p.blueSatMin = v }
        if let v = f("blueBMin") { p.blueBMin = v }
        if let v = f("redSatMin") { p.redSatMin = v }
        if let v = f("redRGBap") { p.redRGBap = v }
        if let v = i("textureRadius") { p.textureRadius = v }
        if let v = f("textureThreshold") { p.textureThreshold = v }
        if let v = i("closingIterations") { p.closingIterations = v }
        if let v = i("openingIterations") { p.openingIterations = v }
        if let v = i("minComponentPixels") { p.minComponentPixels = v }
        if let v = f("minFillRatio") { p.minFillRatio = v }
        return p
    }
}

func jsonEscape(_ s: String) -> String {
    var out = ""
    for c in s.unicodeScalars where c != "\n" && c != "\r" {
        if c == "\"" || c == "\\" { out.append("\\"); out.append(Character(c)) }
        else if c.value >= 0x20 { out.append(Character(c)) }
    }
    return out
}

/// Run HandRemover over a JSON array of (partial) parameter sets; writes
/// <stem>_c<i>.png (cutout) + <stem>_c<i>_mask.png (full-frame mask) per config
/// and prints one JSON line per config: {"i":0,"ok":true,"ms":1234}
func runHandRemoverSweep(input: String, paramsJSON: String?, outdir: String?) {
    guard let pjson = paramsJSON else {
        FileHandle.standardError.write(Data("error: --handremover-sweep requires --sweep-params <jsonfile>\n".utf8))
        exit(1)
    }
    let params = loadSweepParams(pjson)
    let inURL = URL(fileURLWithPath: (input as NSString).expandingTildeInPath)
    guard let src = CGImageSourceCreateWithURL(inURL as CFURL, nil),
          let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
        FileHandle.standardError.write(Data("error: could not load \(input)\n".utf8))
        exit(1)
    }
    let stem = inURL.deletingPathExtension().lastPathComponent
    let dir = URL(fileURLWithPath: outdir ?? ".")
    do { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
    catch { FileHandle.standardError.write(Data("error: mkdir \(dir.path): \(error)\n".utf8)); exit(1) }
    for (i, p) in params.enumerated() {
        let t0 = Date()
        do {
            let result = try HandRemover.segment(from: cg, params: p)
            let ms = Date().timeIntervalSince(t0) * 1000
            try ImageIOHelpers.writePNG(result.image, to: dir.appendingPathComponent("\(stem)_c\(i).png"))
            try ImageIOHelpers.writePNG(result.fullMask, to: dir.appendingPathComponent("\(stem)_c\(i)_mask.png"))
            print("{\"i\":\(i),\"ok\":true,\"ms\":\(Int(ms))}")
        } catch {
            print("{\"i\":\(i),\"ok\":false,\"error\":\"\(jsonEscape(String(describing: error)))\"}")
        }
    }
    exit(0)
}

let baseSegmenter: SegmenterChoice
if args.compare {
    baseSegmenter = .vision
} else {
    guard let resolved = SegmenterChoice.fromCLIString(args.segmenter) else {
        FileHandle.standardError.write(Data("error: unknown --segmenter '\(args.segmenter)' (expected 'vision', 'handremover', or 'ground-truth')\n".utf8))
        exit(1)
    }
    baseSegmenter = resolved
}
let baseConfig = makeConfig(args, segmenter: baseSegmenter)

var runs: [ReportWriter.Run] = []
do {
    if args.compare {
        let vision = Pipeline(config: makeConfig(args, segmenter: .vision)).run()
        let ground = Pipeline(config: makeConfig(args, segmenter: .groundTruth)).run()
        runs = [
            ReportWriter.Run(tag: "vision", output: vision),
            ReportWriter.Run(tag: "ground_truth", output: ground)
        ]
    } else {
        let output = Pipeline(config: baseConfig).run()
        runs = [ReportWriter.Run(tag: baseConfig.segmenter.displayName, output: output)]
    }
}

do {
    let outdir = try ReportWriter.write(runs: runs, to: args.outdir)
    for run in runs {
        printSummary(run.tag, run.output)
    }
    print("")
    let resolved = outdir.resolvingSymlinksInPath().absoluteURL
    print("Output written to: \(resolved.path)")
    print("  board:    \(resolved.appendingPathComponent(runs[0].tag).appendingPathComponent("board.png").path)")
    print("  collage:  \(resolved.appendingPathComponent(runs[0].tag).appendingPathComponent("collage.png").path)")
    print("  html:     \(resolved.appendingPathComponent("report.html").path)")
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
