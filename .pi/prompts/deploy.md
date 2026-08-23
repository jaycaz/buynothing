---
description: Build & launch BuyNothing — simulator (default) or physical iPhone over WiFi
argument-hint: "[simulator|device]"
---
Deploy the BuyNothing app to **${1:-simulator}** and verify it is running.

## Target: simulator

1. Pick a simulator: `xcrun simctl list devices available | grep -i iphone` (prefer one already booted).
2. Build:
   ```bash
   xcodebuild -project BuyNothing.xcodeproj -scheme BuyNothing \
     -destination "platform=iOS Simulator,id=$UDID" \
     -configuration Debug -derivedDataPath /tmp/buynothing-dd build
   ```
3. Install + launch (bundle id `com.byno.app`):
   ```bash
   xcrun simctl install $UDID /tmp/buynothing-dd/Build/Products/Debug-iphonesimulator/BuyNothing.app
   xcrun simctl launch $UDID com.byno.app
   open -a Simulator
   ```
4. **Verify visually**: get the Simulator window rect via System Events
   (`tell process "Simulator"` → position/size of window 1; split output on whitespace),
   then `screencapture -o -R X,Y,W,H ~/Desktop/Sim-deploy-check.png`,
   and read the image to confirm the app UI is rendered (not a crash/blank screen).
   If another window covers it, tell the user and recapture.

## Target: device (physical iPhone over WiFi)

1. Get both identifiers:
   - `xcrun devicectl list devices` → **CoreDevice UUID** (for devicectl)
   - `xcrun xctrace list devices` → **hardware UDID** like `00008140-…` (for xcodebuild)
   - If state is `unavailable`, ask the user to check the iPhone is awake/trusted, then retry.
2. Build (automatic signing; let Xcode fetch the provisioning profile):
   ```bash
   xcodebuild -project BuyNothing.xcodeproj -scheme BuyNothing \
     -destination "platform=iOS,id=$HARDWARE_UDID" \
     -configuration Debug -allowProvisioningUpdates \
     -derivedDataPath /tmp/buynothing-device-dd build
   ```
3. Install + launch:
   ```bash
   xcrun devicectl device install app --device $COREDEVICE_UUID \
     /tmp/buynothing-device-dd/Build/Products/Debug-iphoneos/BuyNothing.app
   xcrun devicectl device process launch --device $COREDEVICE_UUID com.byno.app
   ```

## Rules

- **Do NOT pass the CoreDevice UUID to xcodebuild** (it silently falls back to simulators)
  and do NOT pass the hardware UDID to devicectl.
- After a device launch, the device flipping to `unavailable` is the tunnel dropping — normal,
  not a failure. `devicectl device info processes` may resolve the wrong ECID; don't use its
  failure as evidence of a crash.
- macOS has no `timeout` binary; use `cmd & PID=$!; sleep N; kill $PID`.
- Success = **BUILD SUCCEEDED** + launch reported OK (device) or verified screenshot (simulator).
- Report back: which target, commands used, build warnings worth noting, and any verification evidence.
