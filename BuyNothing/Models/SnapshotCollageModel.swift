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

    /// Full pipeline for a captured photo: segment→align, identify, search, pack all.
    private func addPhoto(_ photo: UIImage, fromCamera: Bool) async {
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
                // If we can't identify, still include the aligned item but no AI items
                await MainActor.run { self.userAlignedItem = aligned }
            }

            pipelineStage = "Searching..."
            onMessageUpdate("Searching for similar items...")

            // 3️⃣ Search (Google Custom Search)
            if let query = identification?.searchQuery {
                do {
                    let allImages = try await SimilarImageSearch.fetch(query: query, count: 6)
                    onMessageUpdate("Found \(allImages.count) similar items")

                    // Add user item + sourced items
                    await MainActor.run {
                        self.userAlignedItem = aligned
                        self.collageItems = [aligned] + allImages
                    }
                } catch {
                    onError("Search failed: \(error)")
                    // Fallback: just the user item
                    await MainActor.run {
                        self.userAlignedItem = aligned
                        self.collageItems = [aligned]
                    }
                }
            } else {
                // No identification available, just use the user item
                await MainActor.run {
                    self.userAlignedItem = aligned
                    self.collageItems = [aligned]
                }
            }

            pipelineStage = "Packing..."
            onMessageUpdate("Packing collage...")

            // 4️⃣ Pack and render
            await MainActor.run {
                if !self.collageItems.isEmpty {
                    let sizes = self.collageItems.map { CGSize(width: $0.width, height: $0.height) }
                    let layout = CollageJustifiedPacker.pack(itemSizes: sizes, canvasWidth: 900, targetRowHeight: 220)
                    let rendered = Self.renderCollage(images: self.collageItems, layout: layout)

                    self.collageImage = rendered
                    self.showResult = true
                }

                self.pipelineStage = nil
                onMessageUpdate("Done! You have \(self.collageItems.count) item(s).")
            }
        } catch {
            onError("Processing failed: \(error)")
            isAlerting = true
        }
        isProcessing = false
    }

    /// Renders a collage from aligned images using the justified packer layout.
    nonisolated private static func renderCollage(images: [CGImage], layout: CollageJustifiedPacker.Layout) -> UIImage {
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
