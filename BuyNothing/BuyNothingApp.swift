import SwiftUI

@main
struct BuyNothingApp: App {
    init() {
        #if DEBUG
        CollageDebugDump.runIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

#if DEBUG
/// Headless verification hook: when launched with the `COLLAGE_DUMP_DIR` environment
/// variable set (e.g. `SIMCTL_CHILD_COLLAGE_DUMP_DIR=/some/path xcrun simctl launch ...`),
/// runs the full collage pipeline and writes every stage plus the final collage to disk as
/// PNGs, so the result can be inspected without needing a rendered simulator screen.
enum CollageDebugDump {
    static func runIfRequested() {
        guard let dumpDir = ProcessInfo.processInfo.environment["COLLAGE_DUMP_DIR"] else { return }
        let directoryURL = URL(fileURLWithPath: dumpDir)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        // Snapshot-pipeline mode: run the streaming sourced-items flow on a real photo and
        // write the collage after each item lands (visible evidence of arrival-order packing).
        if let testImagePath = ProcessInfo.processInfo.environment["COLLAGE_SNAPSHOT_TEST_IMAGE"] {
            Task.detached(priority: .userInitiated) {
                await dumpSnapshot(to: directoryURL, testImagePath: testImagePath)
            }
            return
        }

        let useGroundTruth = ProcessInfo.processInfo.environment["COLLAGE_USE_GROUND_TRUTH_MASK"] == "1"

        Task.detached(priority: .userInitiated) {
            await dumpPipeline(to: directoryURL, useGroundTruth: useGroundTruth)
        }
    }

    private static func dumpPipeline(to directoryURL: URL, useGroundTruth: Bool) async {
        let output = await CollageDemoModel.runPipeline(
            count: 6,
            seedBase: 0,
            useGroundTruthMask: useGroundTruth
        )

        for (index, stage) in output.stages.enumerated() {
            write(stage.original, to: directoryURL.appendingPathComponent("stage\(index)_original.png"))
            if let mask = stage.mask {
                write(mask, to: directoryURL.appendingPathComponent("stage\(index)_mask.png"))
            }
            if let aligned = stage.aligned {
                write(aligned, to: directoryURL.appendingPathComponent("stage\(index)_aligned.png"))
            }
        }
        if let collage = output.collageImage {
            try? collage.pngData()?.write(to: directoryURL.appendingPathComponent("collage.png"))
        }
        let errorsText = output.stages.enumerated().map { "\($0): \($1.error ?? "ok")" }.joined(separator: "\n")
        try? errorsText.write(to: directoryURL.appendingPathComponent("errors.txt"), atomically: true, encoding: .utf8)
        print("COLLAGE_DUMP_DONE status=\(output.statusMessage ?? "ok") stages=\(output.stages.count)")
    }

    private static func write(_ cgImage: CGImage, to url: URL) {
        let image = UIImage(cgImage: cgImage)
        try? image.pngData()?.write(to: url)
    }

    /// Appends a status line to status.txt in the dump directory (and prints it). File-based
    /// because `print` output from a live app is pipe-buffered and can be lost when the
    /// launch console is killed; the file survives either way.
    private static func note(_ line: String, in directoryURL: URL) {
        print("SNAPSHOT_DUMP \(line)")
        let statusURL = directoryURL.appendingPathComponent("status.txt")
        let handle = try? FileHandle(forWritingTo: statusURL)
        if let handle {
            handle.seekToEndOfFile()
            handle.write((line + "\n").data(using: .utf8)!)
            try? handle.close()
        } else {
            try? (line + "\n").write(to: statusURL, atomically: true, encoding: .utf8)
        }
    }

    /// Headless verification of the streaming sourced-items pipeline: segments the given
    /// test photo (COLLAGE_SNAPSHOT_SKIP_SEGMENTATION=1 disables it), identifies it
    /// (COLLAGE_SNAPSHOT_QUERY overrides the Claude call), then consumes the streaming
    /// search results, writing the collage after each item lands plus a stream log.
    /// Every terminal state is recorded in status.txt.
    private static func dumpSnapshot(to directoryURL: URL, testImagePath: String) async {
        note("start test_image=\(testImagePath)", in: directoryURL)

        guard let photo = UIImage(contentsOfFile: testImagePath), let cgImage = photo.cgImage else {
            note("FAILED reason=cannot-load-image", in: directoryURL)
            return
        }
        note("loaded \(cgImage.width)x\(cgImage.height)", in: directoryURL)

        let env = ProcessInfo.processInfo.environment
        let segmentationEnabled = env["COLLAGE_SNAPSHOT_SKIP_SEGMENTATION"] != "1"
        var aligned = cgImage
        if segmentationEnabled {
            guard #available(iOS 17.0, *) else {
                note("FAILED reason=segmentation-unavailable", in: directoryURL)
                return
            }
            do {
                let cutout = try ForegroundSegmenter.cutoutForegroundObject(from: cgImage)
                aligned = ObjectOrientationAligner.align(cutout)
            } catch {
                note("FAILED reason=segmentation-failed: \(error)", in: directoryURL)
                return
            }
        }
        note("aligned \(aligned.width)x\(aligned.height) segmentation=\(segmentationEnabled ? "on" : "off")", in: directoryURL)

        var sourceStream: AsyncThrowingStream<CGImage, Error>
        if let localImages = env["COLLAGE_SNAPSHOT_LOCAL_IMAGES"], !localImages.isEmpty {
            // DEBUG mechanism test: serve local files in place of the image search API, so the
            // stream→process→pack loop can be verified without network or API keys. Each
            // file goes through the same processSourcedImageData pipeline as downloaded
            // results; staggerMs spreads the starts so items arrive one by one.
            let staggerMs = Int(env["COLLAGE_SNAPSHOT_STAGGER_MS"] ?? "300") ?? 300
            let paths = localImages.split(whereSeparator: { ",:".contains($0) }).map(String.init)
            let segment = segmentationEnabled
            note("local-images n=\(paths.count) stagger_ms=\(staggerMs)", in: directoryURL)
            sourceStream = AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
                let producer = Task.detached(priority: .userInitiated) {
                    await withTaskGroup(of: Void.self) { group in
                        for (index, path) in paths.prefix(10).enumerated() {
                            group.addTask {
                                if staggerMs > 0 {
                                    try? await Task.sleep(nanoseconds: UInt64(index) * UInt64(staggerMs) * 1_000_000)
                                }
                                guard !Task.isCancelled else { return }
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                                   let image = SimilarImageSearch.processSourcedImageData(data, segment: segment) {
                                    continuation.yield(image)
                                }
                            }
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { @Sendable _ in producer.cancel() }
            }
        } else {
            var query: String?
            if let overrideQuery = env["COLLAGE_SNAPSHOT_QUERY"], !overrideQuery.isEmpty {
                query = overrideQuery
            } else {
                do {
                    query = try await ItemIdentifier.identify(aligned).searchQuery
                } catch {
                    note("FAILED reason=identify-failed: \(error)", in: directoryURL)
                    return
                }
            }
            note("query=\(query ?? "nil")", in: directoryURL)
            sourceStream = SimilarImageSearch.fetchSegmentedStreaming(query: query!, maxImages: 10, segment: segmentationEnabled)
        }

        var items: [CGImage] = [aligned]
        var logLines: [String] = ["user-item \(aligned.width)x\(aligned.height)"]
        let start = Date()
        do {
            for try await image in sourceStream {
                items.append(image)
                let n = items.count - 1
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                logLines.append("\(n) \(image.width)x\(image.height) \(ms)ms")
                note("item \(n) \(image.width)x\(image.height) \(ms)ms", in: directoryURL)

                let sizes = items.map { CGSize(width: $0.width, height: $0.height) }
                let layout = CollageJustifiedPacker.pack(itemSizes: sizes, canvasWidth: 900, targetRowHeight: 220)
                let rendered = SnapshotCollageModel.renderCollage(images: items, layout: layout)
                if let renderedCG = rendered.cgImage {
                    write(renderedCG, to: directoryURL.appendingPathComponent("stream_after_\(n).png"))
                }
            }
            try logLines.joined(separator: "\n").write(to: directoryURL.appendingPathComponent("stream_log.txt"), atomically: true, encoding: .utf8)
            note("DONE items=\(items.count)", in: directoryURL)
        } catch {
            try? logLines.joined(separator: "\n").write(to: directoryURL.appendingPathComponent("stream_log.txt"), atomically: true, encoding: .utf8)
            note("FAILED reason=stream-error: \(error)", in: directoryURL)
        }
    }
}
#endif
