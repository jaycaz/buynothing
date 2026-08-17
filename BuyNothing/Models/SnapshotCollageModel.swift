//
//  SnapshotCollageModel.swift
//  BuyNothing
//
//  DEBUG-only model for the Snapshot screen: captures a photo, runs the full
//  segment→align→identify→search→process pipeline, and builds a collage that
//  mixes the user's item with AI-sourced similar items.
//
//  ⚠️ Requires API keys in Secrets.swift and iOS 17+ for on-device segmentation.
//

import Foundation
import UIKit
import AVFoundation

@MainActor
final class SnapshotCollageModel: ObservableObject {

    @Published private(set) var showCamera = true
    @Published private(set) var showLibrary = false
    @Published private(set) var showResult = false

    @Published private(set) var capturedPhoto: UIImage?

    @Published private(set) var pipelineStage: String?
    @Published private(set) var pipelineError: String?

    /// The user's aligned item (segmented + aligned)
    @Published private(set) var userAlignedItem: CGImage?

    /// All aligned images going into the collage (user item + AI-sourced items)
    @Published private(set) var collageItems: [CGImage] = []

    /// Final rendered collage
    @Published private(set) var collageImage: UIImage?

    @Published private(set) var isProcessing: Bool = false

    @Published private(set) var isAlerting: Bool = false

    /// True while sourced items are still streaming in (the collage is growing live)
    @Published private(set) var isStreaming: Bool = false

    /// How many sourced items have been packed in so far
    @Published private(set) var sourcedCount: Int = 0

    /// The task consuming the sourced-item stream; canceled when a new capture starts
    private var streamTask: Task<Void, Never>?

    /// Progress messages for each stage
    @Published private(set) var messages: [String] = []

    func startCapture() {
        showCamera = true
        showLibrary = false
        showResult = false
        capturedPhoto = nil
        pipelineStage = nil
        pipelineError = nil
        messages.removeAll()
        isProcessing = false
        isAlerting = false
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        sourcedCount = 0
    }

    func reset() {
        showCamera = true
        showLibrary = false
        showResult = false
        capturedPhoto = nil
        pipelineStage = nil
        pipelineError = nil
        messages.removeAll()
        collageItems = []
        userAlignedItem = nil
        collageImage = nil
        isProcessing = false
        isAlerting = false
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        sourcedCount = 0
    }

    func capturePhoto(_ photo: UIImage) async {
        showCamera = false
        showLibrary = false
        showResult = false
        capturedPhoto = photo
        await addPhoto(photo, fromCamera: true)
    }

    func selectLibraryPhoto(_ photo: UIImage) async {
        showCamera = false
        showLibrary = false
        showResult = false
        capturedPhoto = photo
        await addPhoto(photo, fromCamera: false)
    }

    private func onMessageUpdate(_ msg: String) {
        Task { @MainActor in
            self.messages.append(msg)
        }
    }

    private func onError(_ msg: String) {
        Task { @MainActor in
            self.pipelineError = msg
        }
    }

    /// Full pipeline for a captured photo: segment→align, identify, then stream similar
    /// items in and pack each one as it lands (whichever finishes first goes in first).
    private func addPhoto(_ photo: UIImage, fromCamera: Bool) async {
        // Start fresh: stop any stream still in flight from a previous capture
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        sourcedCount = 0

        guard let cgImage = photo.cgImage else {
            onError("Invalid photo")
            isAlerting = true
            return
        }

        pipelineStage = "Capturing..."

        // 1️⃣ Capture normalizes orientation (only needed for camera captures)
        if fromCamera {
            let normalized = CapturedPhotoNormalizer.normalize(photo)
            await MainActor.run { self.capturedPhoto = normalized }
        }

        pipelineStage = "Segmenting..."
        pipelineError = nil
        isProcessing = true

        guard #available(iOS 17.0, *) else {
            onError("On-device segmentation requires iOS 17 or later.")
            isAlerting = true
            isProcessing = false
            return
        }

        do {
            let cutout = try ForegroundSegmenter.cutoutForegroundObject(from: cgImage)

            let aligned = ObjectOrientationAligner.align(cutout)
            await MainActor.run { self.userAlignedItem = aligned }

            pipelineStage = "Identifying..."
            onMessageUpdate("Identifying your item...")

            // 2️⃣ Identify (Claude vision)
            var identification: ItemIdentifier.Identification?
            do {
                let idResult = try await ItemIdentifier.identify(aligned)
                identification = idResult
                onMessageUpdate("Identified: \"\(idResult.name)\"")
            } catch {
                onError("Identification failed: \(error)")
            }

            // 3️⃣ Pack + show the user's item immediately, then stream similar items in as
            // each one finishes downloading + segmenting (completion order).
            onMessageUpdate("Packing your item...")
            userAlignedItem = aligned
            collageItems = [aligned]
            repackAndRender()
            pipelineStage = nil
            isProcessing = false
            showResult = true
            isStreaming = true
            sourcedCount = 0

            if let query = identification?.searchQuery {
                onMessageUpdate("Streaming similar items in...")
                streamTask = Task {
                    do {
                        let stream = SimilarImageSearch.fetchSegmentedStreaming(query: query, maxImages: 10)
                        for try await image in stream {
                            self.collageItems.append(image)
                            self.sourcedCount += 1
                            self.onMessageUpdate("Packed item \(self.sourcedCount)")
                            self.repackAndRender()
                        }
                        self.onMessageUpdate("Done! You have \(self.collageItems.count) item(s).")
                    } catch {
                        self.onError("Stream stopped: \(error.localizedDescription)")
                    }
                    self.isStreaming = false
                }
            } else {
                // No identification available: user-only collage, nothing to stream
                isStreaming = false
                onMessageUpdate("Done! Showing just your item (identification unavailable).")
            }
        } catch {
            onError("Processing failed: \(error)")
            isAlerting = true
        }
        isProcessing = false
    }

    /// Packs the current collage items and re-renders the collage image. Cheap enough to
    /// run on the main actor after every streamed item (O(n) pack + one render pass).
    private func repackAndRender() {
        guard !collageItems.isEmpty else { return }
        let sizes = collageItems.map { CGSize(width: $0.width, height: $0.height) }
        let layout = CollageJustifiedPacker.pack(itemSizes: sizes, canvasWidth: 900, targetRowHeight: 220)
        collageImage = Self.renderCollage(images: collageItems, layout: layout)
    }

    /// Renders a collage from aligned images using the justified packer layout.
    /// (Internal so the DEBUG dump hook in BuyNothingApp.swift can reuse it.)
    nonisolated static func renderCollage(images: [CGImage], layout: CollageJustifiedPacker.Layout) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: layout.canvasSize, format: format)
        return renderer.image { ctx in
            UIColor(white: 0.96, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: layout.canvasSize))
            for placement in layout.placements {
                let image = images[placement.index]
                ctx.cgContext.draw(image, in: placement.rect)
            }
        }
    }
}
