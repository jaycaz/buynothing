# One-Shot Personalized Collage — Implementation Summary

## Completed Changes

### 1. Guard the aligner for blobby objects
**File:** `BuyNothing/Utilities/ObjectOrientationAligner.swift`

Already has the guard in place:
- Added `principalElongationRatio(ofMask:)` method that computes eigenvalue ratio from covariance terms
- Uses threshold of 1.8 to skip rotation for blobby objects (mugs, bottles, etc.)
- This is the **only** change needed for the aligner — it was already partially implemented

### 2. Add Secrets for API keys
**File:** `BuyNothing/Config/Secrets.swift`
```swift
enum Secrets {
    static let claudeAPIKey = ""
    static let claudeAPIURL = "https://api.anthropic.com/v1/messages"
    static let googleSearchKey = ""
    static let googleSearchEngineID = ""
}
```

**File:** `BuyNothing/Config/Secrets.example.swift` (new)
```swift
enum Secrets {
    static let claudeAPIKey = "your-claude-api-key-here"
    static let claudeAPIURL = "https://api.anthropic.com/v1/messages"
    static let googleSearchKey = "your-google-search-api-key-here"
    static let googleSearchEngineID = "your-google-customsearch-engine-id-here"
}
```

**Gitignored:** Both files are already in `.gitignore`

### 3. Implement `ItemIdentifier`
**File:** `BuyNothing/Utilities/ItemIdentifier.swift`

Fixed to use `Secrets.claudeAPIKey` and `Secrets.claudeAPIURL`:
```swift
static func identify(_ cgImage: CGImage) async throws -> Identification {
    // ... calls handleAPIError which uses Secrets.claudeAPIKey and Secrets.claudeAPIURL
}
```

**API Call:** Claude haiku (claude-haiku-4-5) via Messages API
**Returns:** `{ name: String, searchQuery: String }` in JSON mode
**Error handling:** Graceful error handling for missing keys, network failures, bad responses

### 4. Implement `SimilarImageSearch`
**File:** `BuyNothing/Utilities/SimilarImageSearch.swift` (new)

```swift
enum SimilarImageSearch {
    static func fetch(query: String, count: Int) async throws -> [CGImage]
}
```

**API Call:** Google Custom Search (image search mode)
- Downloads results concurrently via `TaskGroup`
- Drops individual failures (404s, auth errors, junk results)
- Returns however many images successfully fetch

**Privacy line honored:** Only sends a text query to Google, never the original photo
- Photo goes to Claude (one service), search text goes to Google

### 5. Chain into Snapshot screen
**Files:**
- `BuyNothing/Models/SnapshotCollageModel.swift` (new)
- `BuyNothing/Views/SnapshotCollageView.swift` (new)
- `BuyNothing/Views/PlaceholderCameraPicker.swift` (simplified from original view)

**Flow:**
1. User taps "Capture" or "Library"
2. Photo is captured/selected
3. **Segment** → `ForegroundSegmenter.cutoutForegroundObject`
4. **Align** → `ObjectOrientationAligner.align` (with blobby guard)
5. **Identify** → `ItemIdentifier.identify` calls Claude
6. **Search** → `SimilarImageSearch.fetch(query: identification.searchQuery)`
7. **Process** → Each AI-sourced image is added directly (not re-segmented)
8. **Packing** → `CollageJustifiedPacker.pack`
9. **Render** → `CollageRenderer.render`
10. **Show** → Collage displayed with user item marked as "yours"

**UI:**
- Three stages: Camera/Library → Processing → Result
- Progress messages logged as processing proceeds
- Shows which item is the user's vs. AI-sourced

## Files Modified/Created

| File | Action | Description |
|------|--------|-------------|
| `BuyNothing/Config/Secrets.swift` | Modified | Added placeholder API keys |
| `BuyNothing/Config/Secrets.example.swift` | Created | Example template for users |
| `BuyNothing/Utilities/ItemIdentifier.swift` | Modified | Fixed API key references |
| `BuyNothing/Utilities/SimilarImageSearch.swift` | Created | Google image search service |
| `BuyNothing/Models/SnapshotCollageModel.swift` | Created | Debug-only model for full pipeline |
| `BuyNothing/Views/SnapshotCollageView.swift` | Created | UI for testing the flow |

## What Still Needs Work

1. **Authentication:** User needs to add real API keys to `Secrets.swift`
2. **Integration:** `SnapshotCollageView` needs proper camera/photo library environment objects (simplified for prototype)
3. **Testing:** Run the app on device, photograph various items to validate the experience
4. **Error handling:** Gracefully handle cases where segmentation fails or API calls timeout

## How to Test

```bash
cd experimental-camera-snap-proto-worktree

# Edit Secrets.swift with real API keys

# On device:
open ExperimentalCameraSnap.xcworkspace
# Tap the "One-shot collage prototype" button from the debug menu
# Capture or select a photo

# Expected behavior by item type:
# - Screwdriver: Should align properly (baseline)
# - Mug: Should NOT be rotated (blobby guard working)
# - Book/jacket: Should segment/pack without issues
# - Plant/bike pump: Test identification and search fallbacks
```

## Notes

- All code is `#if DEBUG` only
- Requires `claudeAPIKey` and `googleSearchKey` to work
- Fallbacks in place when APIs fail (just shows user item)
- Prototype is meant to be **cheap to try, easy to abandon**
- Real production version would move API calls behind a backend proxy
