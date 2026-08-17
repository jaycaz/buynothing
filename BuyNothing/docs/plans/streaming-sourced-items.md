# Streaming Sourced Items — Plan

## What's changing

The Snapshot collage currently:

1. Downloads **all** Google-sourced images before doing anything,
2. Pastes them in **with their backgrounds** (never segmented),
3. Packs + renders **once**, at the very end.

New behavior:

1. Each sourced image is downloaded, **segmented** (Vision subject-lift, the same
   on-device `VNGenerateForegroundInstanceMaskRequest` used for the user's photo),
   and **aligned** (PCA via `ObjectOrientationAligner`) — the exact same treatment
   as the user's item, so the collage reads as a coherent set.
2. Items **stream into the collage in completion order** — whichever sourced image
   finishes downloading + segmenting first gets packed in first, and the collage is
   re-rendered immediately. The screen shows the collage growing live instead of
   one spinner-to-end state.

Test photo (user's screwdriver):
`/Users/jordan/Pictures/Photos Library.photoslibrary/resources/derivatives/masters/3/318A95E6-E3F9-4ABD-963D-E7A9E88EFFCB_4_5005_c.jpeg`

## Files (NO new files → no pbxproj surgery)

1. **`BuyNothing/Utilities/SimilarImageSearch.swift`**
   - Keep the existing Google Custom Search request shape (it works).
   - Extract the single Google call into `searchImageURLs(query:maxResults:) async throws -> [String]`.
   - Add the streaming API:
     ```swift
     static func fetchSegmentedStreaming(
         query: String,
         maxImages: Int = 10,
         segment: Bool = true
     ) -> AsyncThrowingStream<CGImage, Error>
     ```
     Producer runs in `Task.detached` (must not inherit MainActor), iterates the URL
     list in a `TaskGroup(of: Void.self)`; each child does
     `processSourcedImage(from:segment:)` and `continuation.yield(image)` on success.
     `continuation.onTermination` cancels the producer task. Search-call failure →
     `continuation.finish(throwing:)`; per-item failure → skipped (partial collage is fine).
   - Add `processSourcedImage(from urlString: String, segment: Bool) async throws -> CGImage?`:
     download (15s timeout, ≤12MB) → sanity filter (both dims ≥ 64, aspect ≤ 5 —
     drops banners/text junk) → if `segment`: `ForegroundSegmenter.cutoutForegroundObject`
     (behind `#available(iOS 17.0, *)`) → `ObjectOrientationAligner.align(cutout)`.
     Segmentation failure → `nil` (drop; keeps the collage organic).

2. **`BuyNothing/Models/SnapshotCollageModel.swift`**
   - New state: `@Published isStreaming`, `@Published sourcedCount`, `streamTask: Task<Void, Never>?`.
   - After the user item is segmented + aligned + (optionally) identified:
     set `collageItems = [aligned]`, call `repackAndRender()`, flip `showResult = true`
     **immediately** (the result view becomes a live view), `isStreaming = true`.
   - If there's a search query: consume the stream in a stored `Task { @MainActor in ... }`:
     per item → `collageItems.append(image)`, `sourcedCount += 1`, `repackAndRender()`;
     on completion/error → `isStreaming = false` + message.
   - Extract `repackAndRender()` from the existing pack+render block.
   - `reset()` / new capture / `addPhoto` start: cancel `streamTask`, clear stream state.
   - No-query path (identification failed): user-only collage, `isStreaming` never set.

3. **`BuyNothing/Views/SnapshotCollageView.swift`**
   - Result view: live count — while `isStreaming`, show
     "Found N similar items — more streaming in…" (plus a small `ProgressView`);
     otherwise the final count. The existing collage `Image` re-renders as
     `collageImage` updates (it's `@Published`).

4. **`BuyNothing/BuyNothingApp.swift`** (DEBUG dump hook, already exists)
   - Extend `CollageDebugDump` with a snapshot-pipeline mode, env-gated:
     - `COLLAGE_SNAPSHOT_TEST_IMAGE=<path>` — run the new streaming pipeline on this photo.
     - `COLLAGE_SNAPSHOT_QUERY=<text>` — skip the Claude identify call, use this query.
     - `COLLAGE_SNAPSHOT_SKIP_SEGMENTATION=1` — DEBUG fallback for environments where
       the Vision subject-lift model can't run; yields raw images so the streaming +
       packing mechanism is still verifiable.
   - Output per item: `stream_after_N.png` (the growing collage) + a line in
     `stream_log.txt` (`N width height elapsed_ms`), then `SNAPSHOT_DUMP_DONE items=N`
     printed to the console.

## Constraints

- Deployment target is **iOS 16** — keep `#available(iOS 17.0, *)` around the
  Vision segmentation call (existing code already does this in the model).
- `SnapshotCollageModel` is `@MainActor`. The stream **producer** must not run on the
  main actor (CPU-bound Vision calls would hitch the UI): `Task.detached` for the
  producer task. The **consumer** loop runs on MainActor and is cheap (O(n) pack +
  one ~900px render pass per item — fine).
- Cancellation chain: model cancels its consumer task → `for try await` ends →
  stream `onTermination` fires → producer task + its in-flight downloads cancel.
- Google Custom Search `num` caps at 10; request 10 so we tolerate per-item drops.
- `Secrets.swift` in this worktree currently has **placeholder** keys — live/headless
  testing needs real `claudeAPIKey` / `googleSearchKey` / `googleSearchEngineID`
  pasted in (file is gitignored).

## Validation

1. Build clean:
   ```
   xcodebuild -project BuyNothing.xcodeproj -scheme BuyNothing -configuration Debug \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath ./build-sim build
   ```
2. Headless streaming dump (boots the visible evidence: a growing PNG sequence):
   ```
   SIMCTL_CHILD_COLLAGE_DUMP_DIR=/tmp/snapshot-dump \
   SIMCTL_CHILD_COLLAGE_SNAPSHOT_TEST_IMAGE="<screwdriver photo path>" \
   SIMCTL_CHILD_COLLAGE_SNAPSHOT_QUERY="screwdriver" \
   xcrun simctl launch --console <udid> com.byno.app
   ```
   Expect `SNAPSHOT_DUMP_DONE items=N`, `stream_after_1.png … stream_after_N.png`
   in increasing collage size, and `stream_log.txt` with arrival order + timing.
3. On-device: open Snapshot → "Choose from Library" → pick the screwdriver photo →
   watch the collage grow item by item, all with backgrounds removed.
