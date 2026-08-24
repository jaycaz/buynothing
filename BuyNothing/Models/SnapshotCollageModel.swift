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

    /// True when the collage is filled with fallback everyday objects (identification
    /// unavailable) rather than items similar to the user's.
    @Published private(set) var isPreviewMode: Bool = false

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
        isPreviewMode = false
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
        isPreviewMode = false
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
                onMessageUpdate("Identification unavailable: \(error.localizedDescription)")
            }

            // 3️⃣ Pack + show the user's item immediately, then stream in items to pack
            // alongside it as each one finishes downloading + segmenting (completion order).
            // When identification gave us a query, search for that item type; otherwise
            // fall back to everyday objects so the preview collage always shows how the
            // user's item packs in next to items other users would post.
            onMessageUpdate("Packing your item...")
            userAlignedItem = aligned
            collageItems = [aligned]
            repackAndRender()
            pipelineStage = nil
            isProcessing = false
            showResult = true
            isStreaming = true
            sourcedCount = 0
            pipelineError = nil

            let plan = Self.previewPlan(for: identification)
            isPreviewMode = plan.previewMode
            onMessageUpdate(plan.previewMode
                ? "Packing sample everyday objects alongside yours..."
                : "Streaming similar items in...")
            streamTask = Task {
                await withTaskGroup(of: Void.self) { group in
                    for query in plan.queries {
                        group.addTask {
                            do {
                                let stream = SimilarImageSearch.fetchSegmentedStreaming(query: query, maxImages: plan.perQuery)
                                for try await image in stream {
                                    guard await self.packNextSourcedItem(image) else { break }
                                }
                            } catch {
                                // A failed query just means fewer items; the partial collage is fine.
                            }
                        }
                    }
                }
                await self.finishStreaming()
            }
        } catch {
            onError("Processing failed: \(error)")
            isAlerting = true
        }
        isProcessing = false
    }

    /// Everyday objects used to fill the preview collage when identification is
    /// unavailable, so it still shows how the user's item packs alongside items
    /// other users would post.
    nonisolated static let fallbackPreviewQueries = [
        "ceramic mug", "sneakers", "backpack", "potted houseplant", "wireless headphones", "notebook",
    ]

    /// Cap on sourced items in the preview collage (the user's own item is extra).
    nonisolated static let maxSourcedItems = 8

    struct PreviewPlan {
        let queries: [String]
        let perQuery: Int
        let previewMode: Bool
    }

    /// Chooses the search queries for the preview collage: the identified item type when
    /// available, otherwise a spread of everyday objects.
    nonisolated static func previewPlan(for identification: ItemIdentifier.Identification?) -> PreviewPlan {
        if let query = identification?.searchQuery, !query.trimmingCharacters(in: .whitespaces).isEmpty {
            return PreviewPlan(queries: [query], perQuery: maxSourcedItems, previewMode: false)
        }
        return PreviewPlan(queries: fallbackPreviewQueries, perQuery: 2, previewMode: true)
    }

    /// Packs one more sourced item into the collage (main actor). Returns false once the
    /// collage is full so callers stop pulling from their stream.
    @discardableResult
    private func packNextSourcedItem(_ image: CGImage) -> Bool {
        guard sourcedCount < Self.maxSourcedItems else { return false }
        collageItems.append(image)
        sourcedCount += 1
        onMessageUpdate("Packed item \(sourcedCount)")
        repackAndRender()
        return true
    }

    private func finishStreaming() {
        isStreaming = false
        onMessageUpdate("Done! You have \(collageItems.count) item(s).")
    }

    /// Caption for the "found N items" line, aware of preview mode.
    func itemsCaption(streaming: Bool) -> String {
        if isPreviewMode {
            return streaming
                ? "\(sourcedCount) sample item(s) packed alongside yours — more streaming in…"
                : "\(sourcedCount) everyday item(s) packed alongside yours (sample preview)"
        }
        return streaming
            ? "Found \(sourcedCount) similar items — more streaming in…"
            : "Found \(sourcedCount) similar items"
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
