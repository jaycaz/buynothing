import Foundation
import CoreGraphics

/// One item in the collage browser's feed: either sourced from the random
/// everyday-object search, or captured by the user via the camera button.
struct CollageBrowserItem: Identifiable {
    let id: UUID
    let image: CGImage
    let isUserCaptured: Bool

    init(id: UUID = UUID(), image: CGImage, isUserCaptured: Bool) {
        self.id = id
        self.image = image
        self.isUserCaptured = isUserCaptured
    }
}

/// The two packing algorithms the debug panel can switch between.
enum CollagePackingAlgorithm: String, CaseIterable, Identifiable {
    case justifiedRows
    case scatter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .justifiedRows: return "Justified Rows"
        case .scatter: return "Scatter"
        }
    }
}

/// Drives the collage browser screen: holds the live feed of items, the
/// current packed layout, paging state, and the two debug toggles
/// (segmentation mode, packing algorithm). Every state mutation happens on
/// the main actor; page loads run detached and stream results back in.
@MainActor
final class CollageBrowserModel: ObservableObject {

    static let pageSize = 6
    static let prefetchThreshold = 3

    @Published private(set) var items: [CollageBrowserItem] = []
    @Published private(set) var layout: CollageLayout = CollageLayout(placements: [], canvasSize: .zero)
    @Published private(set) var isLoadingPage = false

    @Published var segmentationMode: CollageSegmentationMode = .visionCutout
    @Published var packingAlgorithm: CollagePackingAlgorithm = .justifiedRows {
        didSet { repack() }
    }
    @Published var canvasWidth: CGFloat = 390 {
        didSet { if oldValue != canvasWidth { repack() } }
    }
    @Published var viewportCenterY: CGFloat = 0

    /// Sheet-presentation flags. Owned here (rather than as `@State` in a view) so both the
    /// header buttons (Phase 09, in `ContentView`) and the screen that presents the actual
    /// sheets (Phase 07/08) can read and write the same source of truth via `$model.<flag>`.
    @Published var isPresentingCamera = false
    @Published var isPresentingDebugConfig = false

    private var usedQueries: Set<String> = []
    private var rng = SplitMix64(seed: UInt64(Date().timeIntervalSince1970))
    private var loadTask: Task<Void, Never>?

    func start() {
        guard items.isEmpty, !isLoadingPage else { return }
        loadNextPage()
    }

    /// Called from the canvas view's `.onAppear` for each rendered item; triggers the next
    /// page once the user has scrolled within `prefetchThreshold` items of the feed's end.
    func itemDidAppear(id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        if idx >= items.count - Self.prefetchThreshold {
            loadNextPage()
        }
    }

    func loadNextPage() {
        guard !isLoadingPage else { return }
        isLoadingPage = true
        let mode = segmentationMode
        loadTask = Task { [weak self] in
            guard let self else { return }
            let stream = EverydayObjectFeed.streamPage(
                count: Self.pageSize, mode: mode, usedQueries: &self.usedQueries, rng: &self.rng
            )
            for await image in stream {
                guard !Task.isCancelled else { break }
                self.items.append(CollageBrowserItem(image: image, isUserCaptured: false))
                self.repack()
            }
            self.isLoadingPage = false
        }
    }

    /// Segments (if the current mode calls for it) and inserts a user-captured photo at the
    /// array index nearest the current scroll-center, then repacks. Silently drops the photo
    /// if segmentation is on and finds no subject (same failure policy as the rest of the app).
    func insertCapturedItem(_ cgImage: CGImage) {
        let segment = segmentationMode.segmentFlag
        Task { [weak self] in
            guard let self else { return }
            var processed: CGImage? = cgImage
            if segment, #available(iOS 17.0, *) {
                do {
                    let cutout = try ForegroundSegmenter.cutoutForegroundObject(from: cgImage)
                    processed = ObjectOrientationAligner.align(cutout)
                } catch {
                    processed = nil
                }
            }
            guard let processed else { return }
            let insertAt = Self.insertionIndex(
                nearestToY: self.viewportCenterY, placements: self.layout.placements, itemCount: self.items.count
            )
            self.items.insert(CollageBrowserItem(image: processed, isUserCaptured: true), at: insertAt)
            self.repack()
        }
    }

    func resetFeed() {
        loadTask?.cancel()
        loadTask = nil
        items = []
        layout = CollageLayout(placements: [], canvasSize: .zero)
        usedQueries = []
        isLoadingPage = false
        start()
    }

    private func repack() {
        guard !items.isEmpty, canvasWidth > 0 else {
            layout = CollageLayout(placements: [], canvasSize: .zero)
            return
        }
        let sizes = items.map { CGSize(width: $0.image.width, height: $0.image.height) }
        switch packingAlgorithm {
        case .justifiedRows:
            layout = CollageJustifiedPacker.pack(itemSizes: sizes, canvasWidth: canvasWidth, targetRowHeight: 180)
        case .scatter:
            layout = CollageScatterPacker.pack(itemSizes: sizes, canvasWidth: canvasWidth)
        }
    }

    /// Pure helper: the array index at which to insert a new item so it lands nearest the
    /// placement whose vertical center is closest to `y`. Returns `itemCount` (append) when
    /// there are no placements yet.
    static func insertionIndex(nearestToY y: CGFloat, placements: [CollagePlacement], itemCount: Int) -> Int {
        guard let nearest = placements.min(by: { abs($0.rect.midY - y) < abs($1.rect.midY - y) }) else {
            return itemCount
        }
        return min(nearest.index + 1, itemCount)
    }
}

#if DEBUG
extension CollageBrowserModel {
    /// Test-only seam: replaces the current items directly and repacks, bypassing the
    /// network-backed paging flow, so packing-algorithm/canvas-resize behavior can be
    /// exercised in unit tests without hitting the network. Declared in this same file so it
    /// can still assign the `private(set)` `items` property.
    func seedForTesting(items: [CollageBrowserItem], canvasWidth: CGFloat) {
        self.canvasWidth = canvasWidth
        self.items = items
        repack()
    }
}
#endif
