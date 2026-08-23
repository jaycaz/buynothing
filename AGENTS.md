# Agent Guidelines

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
