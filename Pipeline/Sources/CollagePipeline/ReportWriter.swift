import Foundation
import CoreGraphics

/// Writes all harness artifacts to disk: per-run stage PNGs, a composite `board.png`, a
/// machine-readable `report.json`, and one combined self-contained `report.html`.
public enum ReportWriter {

    /// A named pipeline run (name = the "model/param" label, e.g. `vision`, `ground_truth`).
    public struct Run {
        public let tag: String
        public let output: PipelineOutput
        public init(tag: String, output: PipelineOutput) {
            self.tag = tag
            self.output = output
        }
    }

    /// Writes per-run artifacts under `outdir/<tag>/` and a combined `report.html` at `outdir/`.
    /// Returns the output directory.
    @discardableResult
    public static func write(runs: [Run], to outdir: String) throws -> URL {
        let base = URL(fileURLWithPath: outdir, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        for run in runs {
            let dir = base.appendingPathComponent(sanitize(run.tag), isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            for (i, stage) in run.output.stages.enumerated() {
                let name = String(format: "%02d_seed%d", i, stage.seed)
                try ImageIOHelpers.writePNG(stage.input, to: dir.appendingPathComponent("\(name)_input.png"))
                if let cutout = stage.cutout {
                    try ImageIOHelpers.writePNG(cutout, to: dir.appendingPathComponent("\(name)_cutout.png"))
                }
                if let aligned = stage.aligned {
                    try ImageIOHelpers.writePNG(aligned, to: dir.appendingPathComponent("\(name)_aligned.png"))
                }
            }
            if let collage = run.output.collage {
                try ImageIOHelpers.writePNG(collage, to: dir.appendingPathComponent("collage.png"))
            }
            let board = BoardRenderer.render(output: run.output)
            try ImageIOHelpers.writePNG(board, to: dir.appendingPathComponent("board.png"))

            let json = try makeJSON(run)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(json).write(to: dir.appendingPathComponent("report.json"))
        }

        let html = HTMLRenderer.render(runs: runs)
        try html.write(to: base.appendingPathComponent("report.html"), atomically: true, encoding: .utf8)

        return base
    }

    // MARK: - JSON report

    static func makeJSON(_ run: Run) throws -> RunReport {
        let stages = run.output.stages.map { st in
            StageReport(
                seed: st.seed,
                inputSize: "\(st.input.width)x\(st.input.height)",
                segmentationIoU: st.metrics?.segmentationIoU,
                inputRotationDegrees: st.metrics?.inputRotationDegrees,
                alignedAspectRatio: st.metrics?.alignedAspectRatio ?? 0,
                alignedResidualDegrees: st.metrics?.alignedResidualDegrees ?? 0,
                cutoutSize: st.metrics.map { "\($0.cutoutWidth)x\($0.cutoutHeight)" },
                segmentationMs: st.metrics?.segmentationMs ?? 0,
                alignmentMs: st.metrics?.alignmentMs ?? 0,
                error: st.error
            )
        }
        return RunReport(
            tag: run.tag,
            config: run.output.configDescription,
            stages: stages,
            packing: run.output.packing,
            aggregate: run.output.aggregate
        )
    }

    struct StageReport: Codable {
        let seed: Int
        let inputSize: String
        let segmentationIoU: Double?
        let inputRotationDegrees: Double?
        let alignedAspectRatio: Double
        let alignedResidualDegrees: Double
        let cutoutSize: String?
        let segmentationMs: Double
        let alignmentMs: Double
        let error: String?
    }

    struct RunReport: Codable {
        let tag: String
        let config: [String: String]
        let stages: [StageReport]
        let packing: PackingMetrics
        let aggregate: AggregateMetrics
    }

    // MARK: -

    static func sanitize(_ s: String) -> String {
        s.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
    }
}
