# One-Shot Personalized Collage — Prototype Plan

## The experience

Snap a photo of one thing you own. It gets cut out of its background, we figure out what it is, we pull in a handful of similar-looking items, and everything packs into one tight collage — your item sitting among its kin. One photo in, one collage out.

The point is to *feel* whether this is delightful, and to make it cheap to try across a whole range of items (mug, lamp, book, jacket, bike pump) so we learn where it breaks.

## What already works today

The Snapshot screen (`SnapshotCollageView` → `SnapshotCollageModel`, DEBUG-only) already does:

- **Capture** — camera or photo library, orientation-normalized (`CameraCapturePicker`, `CapturedPhotoNormalizer`)
- **Segment** — Vision subject lifting, on-device (`ForegroundSegmenter`)
- **Align** — PCA rotation to a shared orientation (`ObjectOrientationAligner`)
- **Pack + render** — justified rows, tight (`CollageJustifiedPacker`, `CollageRenderer`)
- **Show it** — per-item stage cards + the final collage, accumulating across a session

Verified working on a real device. So the pipeline is done — what's missing is everything that makes the collage *populated by similar items* rather than only by things you personally photographed.

## The actual delta — three things

1. **Identify the item** — one Claude vision call, photo in, `{ name, searchQuery }` out.
2. **Find similar items** — one image-search call using that text, then download the results.
3. **Fix alignment for non-tool shapes** — the current flip heuristic assumes a screwdriver-like silhouette. On a mug or a book it will rotate things to nonsense, which will wreck the feel the moment you point this at anything round.

Everything else is reuse.

## Build order

Each step is independently visible — you can run and feel the app after every one.

**1. Guard the aligner** (`ObjectOrientationAligner.swift`, no API keys needed)

`principalAxisAngle` already computes the covariance terms `ixx/iyy/ixy`. Also derive the eigenvalue ratio from them (closed form, no extra image pass) and skip rotation entirely for blobby objects:

```swift
// eigenvalues: ((ixx+iyy) ± sqrt((ixx-iyy)² + 4·ixy²)) / 2
guard elongationRatio > 1.8 else {
    return ImageGeometry.tightCropAlpha(cutout.image) ?? cutout.image  // no meaningful "long axis"
}
// ...existing rotate + shouldFlip path unchanged...
```

Threshold is a guess — tune it by pointing the Snapshot screen at a mug, a book, and a bottle. Do this first: it's the only step that improves what's already on screen today.

**2. Keys** (`BuyNothing/Config/Secrets.swift`, gitignored)

```swift
enum Secrets {
    static let claudeAPIKey = "..."
    static let googleSearchKey = "..."
    static let googleSearchEngineID = "..."
}
```

Commit a `Secrets.example.swift` next to it and add the real one to `.gitignore`. Plain constants in a gitignored file — no xcconfig, no Info.plist plumbing, no build-setting archaeology. It's a prototype; the key is on your machine only. (Real hardening later = move these calls behind a backend proxy that holds the key.)

**3. Identify** (`BuyNothing/Utilities/ItemIdentifier.swift`)

```swift
enum ItemIdentifier {
    struct Identification { let name: String; let searchQuery: String }
    static func identify(_ cgImage: CGImage) async throws -> Identification
}
```

One `URLSession` call to the Messages API. `claude-haiku-4-5` (fast, cheap, vision-capable). Encode the image as JPEG, ask for JSON back via structured output. A plain `enum` with a static func matches how `ForegroundSegmenter`/`CollageRenderer` are already written — no protocol or actor ceremony until something actually needs to swap implementations.

**4. Find similar** (`BuyNothing/Utilities/SimilarImageSearch.swift`)

```swift
enum SimilarImageSearch {
    static func fetch(query: String, count: Int) async throws -> [CGImage]
}
```

Google Custom Search (`searchType=image`), then download the hits concurrently in a `TaskGroup`. **Drop individual failures rather than throwing** — some URLs will 404 or return junk, and a partial collage is fine. Returning fewer than `count` is normal, not an error.

> **Privacy line worth holding:** this takes a `String`, never the photo. Your image goes to exactly one place (Claude, to identify it) and never to the search provider. Cheap to honor now, annoying to retrofit later.

**5. Chain it into the Snapshot screen** (`SnapshotCollageModel.swift`)

`addPhoto` currently does segment → align → append → repack. Extend it: after adding your item, kick off identify → search → run each sourced image through the same `processPhoto` → append those too → repack.

Add a `isYours: Bool` to `PipelineStageResult` so the UI can mark which one is actually yours (a border or a small caption in the collage/stage cards). Seeing *your* item among the others is most of the payoff — without that marker it's just a grid of stock photos.

## Deliberately skipped

Called out so it's a choice, not an oversight — all of this is easy to add once the experience proves worth it:

- **Unit test target + Swift Testing suites.** The repo has no test target at all right now (`Tests/` isn't wired into any build target). Standing one up is real work and proves nothing about whether the feature feels good. Verify by running it.
- **Mock services.** Their job is testing offline; we're testing by looking at the screen.
- **Protocol + actor per service.** Two static funcs. Wrap them in protocols when there's a second implementation to swap in (e.g. AI-generated items instead of search) — the call sites are one line each, so this is a cheap change later.
- **Persisting a `TossedItem`.** No persistence layer exists in the repo yet. Render and share; don't invent storage.
- **Promoting this out of `#if DEBUG`.** It stays an experimentation screen until we like it.
- **The dead USB-cable code** (`ImageAnalysisProtocol`, `CableDetectionResult`) — unrelated leftovers, unrelated cleanup.

## How you'll know it works

Run the app on your device, open the Snapshot screen, and photograph:

- **a screwdriver** — the known-good case, should still look like it does today (regression check on step 1)
- **a mug** — round; step 1 is working if it *isn't* rotated to some arbitrary angle
- **a book** and **a jacket** — flat/soft; checks segmentation and packing on non-rigid shapes
- **something odd** — a plant, a bike pump — to find where identification or search falls down

For each: does the collage read as one coherent set of objects, or as a jumble? Does the sourced set actually look like your item? That's the whole evaluation.

The existing headless dump pattern (`COLLAGE_DUMP_DIR` env var, see `BuyNothingApp.swift`) still works for inspecting stage-by-stage PNGs without a screen if something looks wrong and you want to see which stage broke it.
