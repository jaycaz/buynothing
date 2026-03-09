# BuyNothing — Toss & Whisper Prototype

## Vision
A communal commons where things flow between neighbors naturally.
No marketplace, no pricing, no grid. Just toss things in, whisper what you need,
and let gentle nudges connect the dots.

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
