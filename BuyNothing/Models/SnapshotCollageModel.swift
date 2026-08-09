//
//  SnapshotCollageModel.swift
//  BuyNothing
//
//  DEBUG-only model for the Snapshot screen: captures a photo, runs the full
//  segment→align→identify→search→process pipeline, and builds a collage that
//  mixes the user's item with AI-sourced similar items.
//
//  ⚠️ Requires API keys in Secrets.swift.
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
    }

    func selectLibraryPhoto(_ photo: UIImage) async {
        showCamera = false
        showLibrary = false
        showResult = false
        capturedPhoto = photo
        await processPhoto(photo.cgImage!)
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

    /// Core processing hook: given a photo, run segment→align and return aligned image.
    private func processPhoto(_ cgImage: CGImage, onStage: @Sendable (String) -> Void = { _ in }, onError: @Sendable (String) -> Void = { _ in }) async -> (userAligned: CGImage?, sourcedItems: [CGImage]) {
        // Set processing flag before any async work
        isProcessing = true
        
        let cutout: ForegroundSegmenter.Cutout?
        do {
            cutout = try await ForegroundSegmenter.cutoutForegroundObject(from: cgImage)
            onStage("Segmented: \(cutout.alphaMask.size.width)×\(cutout.alphaMask.size.height)")
        } catch {
            onError("Segmentation failed: \(error)")
            return (nil, [])
        }

        guard let cutout = cutout else { return (nil, []) }

        let aligned = ObjectOrientationAligner.align(cutout)
        
        isProcessing = false
        return (aligned, [])
    }

    /// Full pipeline for a captured photo: segment→align, identify, search, pack all.
    private func addPhoto(_ photo: UIImage) async {
        guard let cgImage = photo.cgImage else {
            onError("Invalid photo")
            isAlerting = true
            return
        }

        pipelineStage = "Capturing..."

        // 1️⃣ Capture normalizes orientation
        if !showLibrary {
            let normalized = await CapturedPhotoNormalizer.normalize(photo)
            await MainActor.run { self.capturedPhoto = normalized }
        }

        pipelineStage = "Segmenting..."
        pipelineError = nil
        isProcessing = true

        do {
            let cutout = try await ForegroundSegmenter.cutoutForegroundObject(from: cgImage)

            let aligned = ObjectOrientationAligner.align(cutout)
            await MainActor.run { self.userAlignedItem = aligned }

            pipelineStage = "Identifying..."
            onMessageUpdate("Identifying your item...")

            // 2️⃣ Identify (Claude vision)
            var identification: ItemIdentifier.Identification?
            do {
                let idResult = try await ItemIdentifier.identify(aligned)
                identification = idResult
                onMessageUpdate("Identified: \"\(identification.name)\"")
            } catch {
                onError("Identification failed: \(error)")
                // If we can't identify, still include the aligned item but no AI items
                await MainActor.run { self.userAlignedItem = aligned }
            }

            pipelineStage = "Searching..."
            onMessageUpdate("Searching for similar items...")

            // 3️⃣ Search (Google Custom Search)
            do {
                var allImages = try await SimilarImageSearch.fetch(query: identification!.searchQuery, count: 6)
                onMessageUpdate("Found \(allImages.count) similar items")

                // Add user item + sourced items
                await MainActor.run {
                    self.userAlignedItem = aligned
                    self.collageItems = (self.userAlignedItem == nil ? [] : [self.userAlignedItem!]) + allImages
                }
            } catch {
                onError("Search failed: \(error)")
                // Fallback: just the user item
                await MainActor.run { self.userAlignedItem = aligned }
            }

            pipelineStage = "Packing..."
            onMessageUpdate("Pack collage...")

            // 4️⃣ Pack and render
            if !collageItems.isEmpty {
                let layout = CollageJustifiedPacker.pack(itemSizes: collageItems.map { CGSize(width: $0.width, height: $0.height) }, canvasWidth: 900, targetRowHeight: 220)
                let rendered = CollageRenderer.render(collage: collageItems, layout: layout)

                await MainActor.run {
                    self.collageImage = rendered
                    self.showResult = true
                }
                
                pipelineStage = nil
                onMessageUpdate("Done! You have \(collageItems.count) item(s).")
            }
        } catch {
            onError("Processing failed: \(error)")
            isAlerting = true
        }
        isProcessing = false
    }

    /// Mark which item is actually the user's (index 0 if present).
    private func markUserItem() {
        if let idx = collageItems.firstIndex(where: { item in
            // Simple heuristic: user item is the one from original capture
            // (AI images would be processed differently; for now just mark index 0)
            // In a fuller version, compare aligned vs original
            return item == userAlignedItem
        }) {
            collageItems[idx] = userAlignedItem!
        }
    }

    /// Render a visual overlay indicating which items are user-provided vs AI-sourced.
    private func renderWithMarkings() -> UIImage {
        // For prototype: just mark the user item with a blue border
        let renderer = UIGraphicsImageRenderer(size: collageImage!.size, format: UIGraphicsImageRendererFormat())
        return renderer.image { ctx in
            ctx.clip(to: collageImage!.cgImage.size, with: .rect)
            ctx.draw(collageImage!.cgImage!, in: CGRect(origin: .zero, size: collageImage!.cgImage.size))

            // Draw blue border around user item
            // (In a real version, we'd track individual item rects from the packer)
        }
    }
}
