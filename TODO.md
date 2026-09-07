# BuyNothing — Prototype

## Vision
An AI-assisted tool for community engagement, starting with making bartering and
free-sharing effortless. Catalog what you'd give away with near-zero friction;
connections and trade suggestions surface on their own. AI is an invisible helper,
not the point of the product. See `GOAL.md` for the full statement.

---

## Done 2026-09-07: segmentation-strategies plan landed (b40f76c)

All five phases of `docs/segmentation-strategies-plan.md` are in `main` (pushed):
`visionMinusSkin` (Vision subject mask minus confident-skin pixels, no colour gate),
the `Segmentation.run` contract over `raw`/`vision`/`handRemover` with five shared
params, `SegmentationComparison` + `pipeline-cli --batch`, and PipelineViewer's
strategy picker, live reprocess, and side-by-side compare view. 42 tests / 6 suites
green; 12-photo batch 48/48 OK. Ran via the new `/implement` skill
(`~/.claude/skills/implement/`) — orchestrator + subagent delegation, resumed the
runner's outstanding phases and landed them. Follow-up still open: re-point the
stashed app-layer picker work (`git stash list` → "segmentation Strategy work")
at `Segmentation.run` and add `visionMinusSkin` to the app debug sheet.

## PipelineViewer — Live Review/Tuning Tool (added 2026-09-06)

Added a SwiftUI Mac app (`Pipeline/Sources/PipelineViewer`, new `PipelineViewer` product
in `Pipeline/Package.swift`) for interactively reviewing HandRemover output against real
test photos and tuning `HandRemover.Params` live via sliders. Opens as an Xcode scheme
automatically when `Pipeline/Package.swift` (or a workspace containing it) is open in
Xcode — select "PipelineViewer", run on My Mac. "Choose Folder…" points it at any folder
of test images; it processes all of them and lets you drill into one, adjust params, and
watch the cutout reprocess (debounced ~150ms). It calls the exact same
`HandRemover.segment(from:params:)` entry point `pipeline-cli --handremover` uses — no
separate reimplementation, so GUI and CLI output can't drift apart by construction.

Structured so future pipeline steps (delighting/relighting, shadow removal, perspective
correction) can each get their own section in `ParamsPanel.swift` alongside Hand &
Distraction Removal, once those stages exist in `CollagePipeline`.

### First pass over `~/Downloads/test-images/` (36 photos, default params)
Ran all 36 through `pipeline-cli --handremover` as a smoke test before building the GUI.
All loaded and processed without errors, including AVIF/WEBP inputs (native ImageIO
support, no format-conversion step needed). Two real segmentation failures spotted by eye:
- **`00A0A_1xoZOBOCrlq...jpg`** (coral-pink dresser on a rug): cutout kept only a thin
  sliver of the frame — the dresser's coral color reads as skin tone, so almost the
  whole object got classified as skin and removed. Worth a test case: HandRemover's
  skin heuristic is a false-positive risk on warm/pink furniture, not just actual skin.
- **`leatherman-bond-opening.avif`** (hand opening a multitool): hand mostly removed, but
  the tool itself came out fragmented with jagged bites taken out of the metal/plastic
  edges rather than a clean silhouette — a rougher, more mixed result than most others in
  the set (most non-hand photos kept 50-95% of frame area with a clean silhouette).

Next: use PipelineViewer to tune params against these two cases specifically (skin
threshold looks like the lever for the dresser; texture/morphology params for the
leatherman fragmentation) without regressing the clean cases.

Context: `composite` / `composite_swift` strategies won the 50-photo benchmark (Swift port in
`wt/composite-swift`, benchmark harness in `wt/tool-segmentation`, results in iCloud
`BN-Cutout-TestSet/`).

### Done 2026-08-30 (both branches pushed)
- [x] **Fixed a vertical-flip bug in the Swift port** (`HandRemover`) — `topDownRGBA`'s
  context flip made the pixel array bottom-up while consumers assumed top-down. Effects:
  mirrored cutouts (invisible on symmetric objects) and off-center crops grabbing an empty
  region → tools_05/usbcable_07/11 came out fully transparent. Now: **0/50 lost** (was 8),
  all 26 tests green incl. a new orientation regression test.
- [x] **Parameter sweep** (`scripts/sweep.py` + `pipeline-cli --handremover-sweep`,
  `out/sweep/`): 16-config grid over 50 photos. Morphology params on a flat plateau;
  no clear win → shipped defaults kept. `lost` is the metric that matters (iou-vs-SAM
  understates: Swift and SAM capture complementary parts).
- [x] **Split-bridge prototype** (`scripts/split_bridge.py` in wt/tool-segmentation,
  report in iCloud `results/split_bridge/`): 3/50 split cases, all books (fan-spread /
  open-book grips). Heuristic works (2+ large components, gap <35% of smaller piece
  diagonal, ratio 0.15–6.5, collinear). Naive square-closing bridge merges all 3 but
  over-fills 117–169% → stopgap only. Next: capsule bridge + color/texture consistency
  across the gap; same detection can run on `HandRemover.fullMask` as a cheap guard.
- [x] **Adversarial mini-set** (`testset_adversarial/`, 15 images, 6 hard classes,
  `out/bench_adv/FAILURES.md` + iCloud `results/adversarial/`): sam_auto is
  appearance-fragile (OBJECT_LOST on skin_tone/white_on_white/low_contrast/glossy);
  composite_swift is appearance-robust (object survives all classes) but shows the
  split/strand weakness → split-bridge territory.
- [x] **HandRemover test suite** — 12 real-photo invariants + helper unit tests +
  orientation regression test (26 tests green).
- [x] Pushed `wt/composite-swift` (370abc6) + `wt/tool-segmentation` (836c5ef).

### Open
- [ ] **Update the dataset** — the 50-photo test set is pretty extreme cases; Jordan is
  providing a new, more representative set. Re-run `scripts/benchmark.py` (all 6 strategies)
  against it, plus `scripts/sweep.py`, `scripts/split_bridge.py`, and the gap probe
  (`out/run_full.py`); reconsider `textureRadius=80` and the `skinSatMax` value there.
- [ ] **Split-object mitigation v2** (see prototype findings): capsule bridging +
  color/texture consistency check across the gap; wire the detection into HandRemover
  as a guard before the final crop; test on deliberately hand-grip-heavy photos from
  the new dataset.
- [x] Integrate `HandRemover` (Swift port) into the app `Pipeline` for production use (2026-09-02)

### Done 2026-09-02 (HandRemover production integration)
- [x] **Merged `wt/composite-swift` into main** (HandRemover + 12-photo regression suite + CLI
      `--handremover`/`--handremover-sweep` + sweep infra). `HandRemover.Result` now also carries a
      `croppedMask` (mask cropped to the cutout rect) so it satisfies the `Cutout` invariant.
- [x] **Package strategy**: `SegmenterChoice.handRemover` wired into `Pipeline.run()` + CLI
      (`--segmenter handremover` / `composite`). 25/25 package tests green; CLI e2e verified on
      real photos (tools_03: stapler kept, correctly oriented, ~310ms).
- [x] **App integration**: `BuyNothing/Utilities/HandRemover.swift` (app-side copy, keep in sync
      with the package); `ForegroundSegmenter.segment(from:)` full-mask API; new
      `CollageSegmentationMode.handRemoval` ("Hand Removal (Composite)" in the debug panel);
      shared `segmentObject(_:mode:)` helper (hand-removal first, Vision fallback, PCA align).
      Wired into: one-shot capture (`SnapshotCollageModel.addPhoto` now defaults to hand removal —
      the item is usually held in hand), collage-browser capture + web feed (per-mode), and the
      `COLLAGE_SNAPSHOT_*` headless dump harness (`COLLAGE_SNAPSHOT_MODE=handremoval|visioncutout`).
- [x] **Verification**: app builds + all app tests pass (iOS 26.4 sim). iOS runtime check blocked
      by THIS machine's environment (per-machine ANE/GPU pool issue, not a simulator limitation
      in general — the macOS host runs all 12 photos through Vision fine): every REAL Vision call
      in the iOS simulator fails code 9 "Could not create inference context", even a single call
      with 6× growing-backoff retries; the physical iPhone (iOS 27.0 beta) dev session won't mount
      with Xcode 26.3. HandRemover's CoreGraphics path is macOS-verified on the same photo set;
      re-run `scripts/test-pipeline.sh` on the iOS VM (or any machine where sim Vision works) to
      confirm the app-level layer. NOTE: earlier "single test passes" evidence was a false
      positive — xcodebuild test-level `-only-testing` matches 0 swift-testing tests and still
      prints TEST SUCCEEDED (verified via xcresult totalTestCount=0).
- [x] **Automated pipeline test harness** (so a working iOS VM is a one-command check):
      `scripts/test-pipeline.sh` — 3 layers: package tests → app tests incl. the new
      `PipelineProductionPathTests` (environment gate that FAILS LOUDLY when Vision is broken,
      3-photo handRemoval/visionCutout invariants — full 12-photo coverage is in the package
      tests —, conditional skin-removal effectiveness test, serialized + Vision code-9 retry)
      → headless E2E dump of the one-shot capture pipeline. Runbook + gotchas (0-test
      false positive, Swift-6.2 trailing-closure `try`) documented in AGENTS.md.

### Done 2026-08-30 (gap probe; commit c906285, not yet pushed)
- [x] **Red-hand gap fixed** — the confident-skin test was eating highly saturated reds
  (tools_01 handles). Added `Params.skinSatMax` (0.75) gating the skin test on
  `sat < skinSatMax`; recovered red-product coverage on 13/50 (tools_01 red_cov
  0.04→0.27, tools_11 0.01→0.45).
- [x] **Thin-object / full-res gap improved** — `textureRadius` 10→40 (81px window):
  usbcable_07 0.12→0.20, usbcable_11 0.04→0.06, mean opacity +21%, 0 lost, all
  invariants green. r=80 tested marginally better; 40 committed as conservative default.
- [x] Gap probe report + reusable measurement harness: `out/gap_report.md`,
  `out/measure.py`, `out/run_full.py`, `out/runs/` (gitignored, on disk in the
  composite-swift worktree).

---

## Queued Next (added 2026-08-17)
- [ ] **In-app collage (iPhone)** — Wire the real iPhone capture flow to actually *produce* the collage end-to-end. Today the in-app flow only segments the photo and shows the test UI; **no collage is rendered**. Target: capture → segment → align → pack → display the final collage, reusing the shared `CollagePipeline` package so the app and the Mac harness drive the *same* pipeline core.
  - Depends on: landing the Mac test harness first — it validates the pipeline and surfaces the model/param decisions to feed back into the in-app flow.

---

## New: One-Shot Personalized Collage (Prototype)

### The Experience
Snap a photo of one thing you own. It gets cut out of its background, we figure out what it is, we pull in a handful of similar-looking items, and everything packs into one tight collage — your item sitting among its kin. One photo in, one collage out.

### The Delta (vs. Current Snapshot Collage)
The existing Snapshot screen does capture → segment → align → pack. What's missing is:
1. **Identify the item** — one Claude vision call, `{ name, searchQuery }` out.
2. **Find similar items** — one image-search call using that text.
3. **Fix alignment for non-tool shapes** — guard against rotating blobby objects (mugs, bottles).

### Build Progress
✅ **Step 1: Guard aligner** — eigenvalue ratio from covariance terms, skip rotation for blobby objects
✅ **Step 2: Keys** — Secrets.swift with claudeAPIKey, googleSearchKey, googleSearchEngineID
✅ **Step 3: Identify** — ItemIdentifier.swift calling Claude vision API
✅ **Step 4: Find similar** — SimilarImageSearch.swift using Google Custom Search
✅ **Step 5: Chain into Snapshot** — SnapshotCollageModel and SnapshotCollageView wired up

### Files Created/Modified
- `BuyNothing/Utilities/ItemIdentifier.swift` — fixed API references
- `BuyNothing/Utilities/SimilarImageSearch.swift` — new, fetches similar images
- `BuyNothing/Models/SnapshotCollageModel.swift` — new, full pipeline model
- `BuyNothing/Views/SnapshotCollageView.swift` — new, UI for testing
- `BuyNothing/Services/CapturedPhotoNormalizer.swift` — new, normalize camera photos
- `BuyNothing/Config/Secrets.swift` — added placeholder API keys
- `BuyNothing/Config/Secrets.example.swift` — example template
- `.gitignore` — Secrets.swift and Secrets.example.swift already ignored

### How to Test
1. Edit `BuyNothing/Config/Secrets.swift` with real API keys
2. Open app, tap "One-shot collage prototype" (debug button)
3. Capture or select a photo
4. Watch: segment → align → identify → search → pack → show
5. Try various items:
   - Screwdriver: should align properly (baseline)
   - Mug: should NOT rotate (blobby guard working)
   - Book/jacket: checks segmentation/packing
   - Plant/bike pump: tests fallbacks

### How to Run Locally
```bash
cd BuyNothing
# Edit Secrets.swift with your keys
cd ../../
xcodebuild -scheme BuyNothing -sdk iphonesimulator -destination 'platform=iOS Simulator' build
open Build/Products/.../BuyNothing.app
```

### Deliberately Skipped
- Unit test target (repo has no test target yet)
- Mock services (testing by looking at screen)
- Protocol + actor per service (two static funcs, cheap to refactor later)
- Persistence layer (no storage in repo yet)
- Promoting out of `#if DEBUG` (stays experimental)

### Backlog (Phase 2+)
- [ ] Make the collage feel organic (backgrounds, shadows)
- [ ] Warm, unhurried visual design
- [ ] Nudge timing/cadence experimentation
- [ ] Toss history
- [ ] Real neighbor connections (privacy-first)

---

## Phase 1: Toss & Whisper Loop (split 2026-09-06 — see `.meeting/DECISIONS.md`)

**Decision (2026-09-06):** split Toss from Whisper. Whisper needs more design work and is
shelved for now — not being worked on. Toss is treated as effectively already in flight: it's
the same work as the image-capture → dashboard-placement pipeline (HandRemover + Pipeline), and
the under-10-second target lines up with that existing effort. Nudge is blocked on Whisper
(needs both sides of the match), so it's on hold too. Priority right now is the new 50-photo
dataset + repo hygiene, not new Phase 1 code — see `.meeting/STATUS.md`.

### Toss (folded into the image pipeline — not a separate build)
- [x] Camera capture → segment (HandRemover) → collage placement — this *is* Toss, already shipped
      as the one-shot capture flow (see "HandRemover production integration" above)
- [ ] **Placed-item detail view** — once an item lands on the dashboard, what does it look like?
      Does it need a title/description, or is the photo alone enough? (next concrete design step)
- [ ] **HCI question: labeling better than Craigslist** — explore voice input where you speak
      about the item and an LLM formats it into a clean listing (title, description, tags),
      instead of typing. Open design thread from 2026-09-06 meeting, not started.
- [ ] `TossedItem` data model — photo, AI-generated description, tags, category, date

### Whisper (shelved — needs more design before resuming)
- [ ] Simple text input — "I could use a bookshelf"
- [ ] Store locally as a `Wish` — natural language want, parsed keywords
- [ ] No categories, no filters, just natural language
- Open question carried over: how casual should this be — voice too, or just text?

### Nudge (blocked on Whisper)
- [ ] `Neighbor` — mock person with inventory and wishes
- [ ] `Nudge` — a match connecting a toss to a wish with a warm message
- [ ] Match engine: compare user's tosses/wishes against neighbor data
- [ ] Generate warm, contextual nudge messages (not "1 match found")
- [ ] Display as a feed of human-readable suggestions
- [ ] Example: "Priya nearby has a bread maker she's not using. She mentioned wanting yoga gear — you just tossed in a yoga mat."
- [ ] Mock neighbor data (seed 4-5 fictional neighbors), once this is picked back up:
  - Maria: has standing desk lamp, wants kids' books
  - James: has HDMI/USB cables, wants small kitchen appliances
  - Priya: has bread maker, wants yoga gear
  - David: has box of novels, wants electronics cables
  - Lena: has extra kitchen utensils, wants desk/office stuff

---

## Phase 2: Feel & Polish
- [ ] Organic collage feel for items (background removal, floating objects)
- [ ] Warm, unhurried visual design — not a marketplace
- [ ] Nudge timing/cadence experimentation
- [ ] Toss history — things you've contributed to the commons

---

## Phase 3: Real Connections
- [ ] Replace mock neighbors with real local discovery
- [ ] On-device matching (privacy-first)
- [ ] Peer-to-peer item list exchange
- [ ] Trust signals without accounts

---

## Open Questions
- What does the nudge notification actually look like? Toast? Card? Ambient?
- How casual should the whisper input be? Voice too?
- Does the commons need a "browse" view at all, or is it purely nudge-driven?
- Karma/balance tracking — visible to the user or invisible?
