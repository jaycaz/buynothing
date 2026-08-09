# BuyNothing — Toss & Whisper Prototype

## Vision
A communal commons where things flow between neighbors naturally.
No marketplace, no pricing, no grid. Just toss things in, whisper what you need,
and let gentle nudges connect the dots.

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
