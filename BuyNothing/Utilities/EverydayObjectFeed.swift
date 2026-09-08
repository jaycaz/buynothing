import Foundation
import CoreGraphics

/// The segmentation behaviors the debug panel can switch between.
/// `.raw` does not add a second Vision-based algorithm -- it reuses the
/// `segment: Bool` parameter `SimilarImageSearch` already has, which skips
/// `ForegroundSegmenter` entirely and keeps the full rectangular photo.
enum CollageSegmentationMode: String, CaseIterable, Identifiable {
    case visionCutout
    /// Composite hand-removal cutout (`HandRemover`): Vision region prior + color/texture
    /// classification that strips confidently skin-toned pixels, so held items come out
    /// without the gripping hand. Falls back to a plain Vision cutout if no subject.
    case handRemoval
    /// Vision subject mask minus confident-skin pixels (no colour/texture gate) — the
    /// middle ground between `.visionCutout` (keeps the hand) and `.handRemoval`
    /// (whose blue/red gate mangles general objects). Mirrors CollagePipeline's
    /// `Segmentation.run(.visionMinusSkin)`.
    case visionMinusSkin
    case raw

    var id: String { rawValue }

    var segmentFlag: Bool {
        switch self {
        case .visionCutout, .handRemoval, .visionMinusSkin: return true
        case .raw: return false
        }
    }

    var displayName: String {
        switch self {
        case .visionCutout: return "Vision Cutout"
        case .handRemoval: return "Hand Removal (Composite)"
        case .visionMinusSkin: return "Vision − Skin"
        case .raw: return "Raw (No Segmentation)"
        }
    }
}

/// Sources the collage browser's randomly-chosen-object feed: draws a page
/// of distinct queries from `EverydayObjectQueries`, then streams one
/// (segmented or raw, per `mode`) image per query in completion order.
/// A query that yields no usable image (search failure, no segmentable
/// subject, etc.) is silently dropped -- a partial page is fine, matching
/// the existing `SimilarImageSearch.fetchSegmentedStreaming` failure policy.
enum EverydayObjectFeed {

    static func streamPage(
        count: Int,
        mode: CollageSegmentationMode,
        usedQueries: inout Set<String>,
        rng: inout some RandomNumberGenerator
    ) -> AsyncStream<CGImage> {
        let queries = EverydayObjectQueries.randomPage(count: count, avoiding: usedQueries, using: &rng)
        usedQueries.formUnion(queries)

        return AsyncStream { continuation in
            let producer = Task.detached(priority: .userInitiated) {
                await withTaskGroup(of: Void.self) { group in
                    for query in queries {
                        group.addTask {
                            guard !Task.isCancelled else { return }
                            if let image = await Self.fetchOne(query: query, mode: mode) {
                                continuation.yield(image)
                            }
                        }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in producer.cancel() }
        }
    }

    /// Tries up to 3 search results for `query` and returns the first one that
    /// downloads and (when the mode segments) processes successfully.
    private static func fetchOne(query: String, mode: CollageSegmentationMode) async -> CGImage? {
        guard let urls = try? await SimilarImageSearch.searchImageURLs(query: query, maxResults: 3) else {
            return nil
        }
        for url in urls {
            if let image = try? await SimilarImageSearch.processSourcedImage(from: url, mode: mode) {
                return image
            }
        }
        return nil
    }
}
