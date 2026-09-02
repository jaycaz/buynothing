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
//     --segmenter S      vision | ground-truth (default vision)
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
}

func usage() -> String {
    """
    pipeline-cli — run the screwdriver collage pipeline headlessly on Mac.

    Options:
      --count N          number of synthetic photos (default 6)
      --seed-base N      starting seed (default 0)
      --segmenter S      vision | ground-truth (default vision; 'ground_truth'/'groundTruth' also accepted)
      --canvas-width W   collage canvas width (default 900)
      --row-height H     target row height (default 220)
      --spacing S        gutter between items (default 6)
      --input-size WxH   synthetic photo size (default 640x640)
      --outdir PATH      output directory (default harness-output)
      --compare          run BOTH vision and ground-truth and emit a comparison report
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

let argv = CommandLine.arguments
let args = parseArgs(argv)

if args.showHelp {
    print(usage())
    exit(0)
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
        FileHandle.standardError.write(Data("error: unknown --segmenter '\(args.segmenter)' (expected 'vision' or 'ground-truth')\n".utf8))
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
