# BuyNothing — Toss & Whisper Prototype

## Vision
A communal commons where things flow between neighbors naturally.
No marketplace, no pricing, no grid. Just toss things in, whisper what you need,
and let gentle nudges connect the dots.

---

## Cutout / Hand-Removal — Next Steps (added 2026-07-26, updated 2026-08-30)

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
- [ ] Integrate `HandRemover` (Swift port) into the app `Pipeline` for production use

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

## Phase 1: Toss & Whisper Loop (Current Focus)

### Data Models
- [ ] `TossedItem` — photo, AI-generated description, tags, category, date
- [ ] `Wish` — natural language want, parsed keywords
- [ ] `Neighbor` — mock person with inventory and wishes
- [ ] `Nudge` — a match connecting a toss to a wish with a warm message

### Toss (Camera → AI → Confirm → Done)
- [ ] Camera capture screen (photo library fallback for simulator)
- [ ] Send photo to Claude vision API for item identification
- [ ] Show confirmation card with detected name, description, tags
- [ ] User confirms or tweaks, item enters the commons
- [ ] Target: under 10 seconds from camera to listed

### Whisper (Say What You Need)
- [ ] Simple text input — "I could use a bookshelf"
- [ ] Store locally as a Wish
- [ ] No categories, no filters, just natural language

### Nudge (Gentle Matches)
- [ ] Match engine: compare user's tosses/wishes against neighbor data
- [ ] Generate warm, contextual nudge messages (not "1 match found")
- [ ] Display as a feed of human-readable suggestions
- [ ] Example: "Priya nearby has a bread maker she's not using. She mentioned wanting yoga gear — you just tossed in a yoga mat."

### Mock Neighbor Data
- [ ] Seed 4-5 fictional neighbors with realistic inventories and wants:
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
