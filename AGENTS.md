# Agent Guidelines

## Meeting context (check first)
Before starting work, check `.meeting/STATUS.md` and `.meeting/OPEN_QUESTIONS.md` for
context from a recent voice/chat meeting that hasn't made it into `TODO.md` yet, and
check `.meeting/briefs/` for a ready-made brief for the task at hand. This folder is
gitignored/ephemeral — see `.meeting/README.md` for the full schema.

## Workflow defaults (user preference, 2026-08-29)
- Default to the most efficient workflow available. Prefer parallelism and speed.
- Use `/subagents` (the `subagent` tool) for parallelizable or heavy workstreams; if a child
  stalls/dies, fall back to doing the work in-session rather than re-spawning repeatedly.
- Use `/wt` for new work in a git worktree (one branch/worktree per workstream, e.g.
  `wt/composite-swift` for the Swift port).
- Known skills to keep in mind: `xcode-build`, `catch-me-up`, `breakdown`, `council-mode`,
  `pi-subagents` (plus whatever else appears in the session's available-skills list).
- When the user is traveling, sync review artifacts to
  `~/Library/Mobile Documents/com~apple~CloudDocs/` (e.g. `BN-Cutout-TestSet/`) so they
  land on the iPhone automatically.

## Simulator Screenshot + Screen-Operation Runbook

Verified workflow for driving the BuyNothing app in the iOS Simulator from the CLI
(build, capture, tap). Use this instead of ad-hoc attempts.

### 1. Build & launch

```bash
# Find a booted (or any available) simulator
xcrun simctl list devices available | grep -i iphone
UDID=<udid>

xcodebuild -project BuyNothing.xcodeproj -scheme BuyNothing \
  -destination "platform=iOS Simulator,id=$UDID" \
  -configuration Debug -derivedDataPath /tmp/buynothing-dd build

APP=/tmp/buynothing-dd/Build/Products/Debug-iphonesimulator/BuyNothing.app
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.byno.app   # bundle id: com.byno.app
open -a Simulator   # make sure the window is visible on screen
```

### 2. Get the Simulator window rect (points, screen-global)

Simulator's own AppleScript dictionary cannot report windows — use System Events
(needs Accessibility permission for the terminal; if it errors with
"not allowed assistive access", ask the user to approve and retry):

```bash
osascript -e 'tell application "System Events" to tell process "Simulator"
  set p to position of window 1
  set s to size of window 1
  return (item 1 of p) & " " & (item 2 of p) & " " & (item 1 of s) & " " & (item 2 of s)
end tell'
# -> "X Y W H" (note: AppleScript may emit ", ," separators — split on whitespace, take 4 numbers)
```

### 3. Region-scoped screenshot (do NOT capture the whole desktop)

```bash
screencapture -o -R "$X,$Y,$W,$H" /path/to/out.png
```

- `-R` takes **points** (not pixels); output is @2x on Retina (e.g. 456×972 pt → 912×1944 px).
- `-o` omits the window shadow (same flag the `/ss-capture` pi command uses).
- The pi `/ss-capture` slash command itself is interactive (mouse-drag region select via
  `screencapture -i`) and cannot be driven headlessly — use the `screencapture -o -R` above.
- "could not create image from rect" usually means permissions just changed — reload and retry.
- Make sure no other window covers the Simulator before capturing (verify by reading the image).

### 4. Tapping / operating the UI

```bash
swift scripts/tap.swift <screenX> <screenY>
```

- `scripts/tap.swift` posts real CGEvent mouse events (move → down → up).
  System Events `click at` does NOT work against the Simulator (error -25204) — don't waste time on it.
- Coordinate math: `screenPoint = windowOrigin + windowPoint`;
  a feature at pixel `(px, py)` in the screenshot is at window point `(px/2, py/2)`.
  Example: share button at ~px (800, 350) in a 912×1944 shot, window at (1372, 89)
  → tap `1372+400, 89+176` = `(1772, 265)`.
- After a tap: `sleep 2`, then re-capture and read the image to verify the transition
  before deciding the next step (capture → inspect → tap → capture loop).

### 5. Gotchas learned the hard way

- Read every screenshot back with the image reader before assuming a tap landed — a miss
  looks identical to "nothing happened" in the log.
- Window position can change between steps; re-fetch the rect if a capture looks wrong.
- Keep derived data in `/tmp/buynothing-dd` so repeated builds are incremental.

## Physical iPhone over WiFi (verified working)

No USB needed — the iPhone pairs over the network and CoreDevice provides the tunnel.

```bash
# 1. Find the device (CoreDevice UUID + state)
xcrun devicectl list devices
# 2. Find its HARDWARE UDID (needed for xcodebuild, NOT the CoreDevice UUID!)
xcrun xctrace list devices | grep -i iphone
# 3. Build (automatic signing + let Xcode fetch the provisioning profile)
xcodebuild -project BuyNothing.xcodeproj -scheme BuyNothing \
  -destination "platform=iOS,id=<HARDWARE_UDID e.g. 00008140-...>" \
  -configuration Debug -allowProvisioningUpdates \
  -derivedDataPath /tmp/buynothing-device-dd build
# 4. Install + launch (these DO use the CoreDevice UUID)
xcrun devicectl device install app --device <COREDEVICE_UUID> \
  /tmp/buynothing-device-dd/Build/Products/Debug-iphoneos/BuyNothing.app
xcrun devicectl device process launch --device <COREDEVICE_UUID> com.byno.app
```

Gotchas:
- `xcodebuild -destination id=` wants the **hardware UDID** from `xctrace list devices`;
  passing the CoreDevice UUID silently falls back to listing simulators.
- `devicectl install`/`launch` want the **CoreDevice UUID** from `devicectl list devices`.
- After launch the device often flips to `unavailable` (tunnel drops) — that's normal and
  does NOT mean the app failed; the user should see it on the home screen.
- `devicectl device info processes` can resolve the UUID to the wrong ECID; don't treat
  its failure as evidence of a crash.
- macOS has no `timeout` binary — use `cmd & PID=$!; sleep N; kill $PID`.

## Pipeline test runbook (cutout / hand-removal regression)

Single command that proves the whole pipeline works in an environment where Vision runs
(simulator/VM or physical device):

    scripts/test-pipeline.sh             # 3 layers, cheapest first
    scripts/test-pipeline.sh --skip-e2e  # skip the headless app launch
    SIM_DEST="platform=iOS Simulator,name=iPhone 17 Pro" scripts/test-pipeline.sh

Layers:
1. `Pipeline/` package tests (host, `swift test`) — includes the 12-photo HandRemover suite.
2. App test suite on an iOS simulator — includes `PipelineProductionPathTests`, whose
   `visionEnvironmentGate` test FAILS WITH A DIAGNOSTIC when Vision can't create inference
   contexts (a broken simulator/VM is a red test, not a silent pass).
3. Headless E2E: launches the app with the `COLLAGE_SNAPSHOT_*` dump harness on a real
   held-object photo and asserts the one-shot capture pipeline (handRemoval segment →
   align → feed → pack) completes (`DONE items=N` + collage PNGs in `/tmp/bn_pipeline_e2e/`).

Gotchas learned the hard way:
- Simulator Vision is flaky or absent depending on the machine: on 2026-09-02 this
  host's iOS simulator failed EVERY real Vision call (code 9 "Could not create
  inference context") while the same code ran all 12 photos fine on macOS. The suite
  retries code-9 with growing backoff (6×, 0.5s→3s) and settles ~400ms between calls,
  then fails loudly. On a machine where the simulator's ML pool works, it passes.
- The app suite runs a 3-PHOTO subset (`appSuiteNames`: tools_07/books_03/usbcable_07,
  chosen to span low/mid/high hand coverage) to stay under the simulator's load limit;
  full 12-photo coverage lives in the host-side package tests.
- ⚠️ xcodebuild `-only-testing` at the swift-testing TEST level (Struct/testName())
  silently matches 0 tests and still prints ** TEST SUCCEEDED ** (verified via
  xcresult `totalTestCount: 0`). Select at the SUITE level and confirm tests actually
  ran (per-test lines, or `xcresulttool get test-results summary`).
- The 12 regression photos exist in BOTH `Pipeline/Tests/CollagePipelineTests/TestImages/`
  and `BuyNothingTests/TestImages/` — keep the two sets in sync when refreshing.
- Swift 6.2 quirk: a trailing closure passed to a throwing-closure parameter does NOT
  inherit the throwing context — write the inner `try` explicitly:
  `try helper { try throwingCall() }` (a plain `try helper { throwingCall() }` is a
  "call can throw, but it is not marked with 'try'" error).
- `Bundle.module` does not exist in the app test target; use the
  `Bundle.allBundles` lookup in `ProductionPathTestImages.bundle` instead.
