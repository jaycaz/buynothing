#!/usr/bin/env bash
# Full pipeline verification — the single command to prove the cutout/collage
# pipeline works end-to-end in an environment where Vision runs (iOS simulator/VM
# or device). Three layers, cheapest first:
#
#   1. Package unit tests (host, no Vision dependency beyond one test)
#   2. App test suite on an iOS simulator — includes PipelineProductionPathTests,
#      whose environment gate FAILS LOUDLY if Vision can't create inference contexts
#   3. Headless E2E dump: launches the app with the COLLAGE_SNAPSHOT_* harness and
#      checks the one-shot capture pipeline (handRemoval segment -> align -> feed ->
#      pack) completes and writes real output PNGs
#
# Usage:
#   scripts/test-pipeline.sh                  # all three layers
#   scripts/test-pipeline.sh --skip-e2e       # skip the headless app launch
#   SIM_DEST="platform=iOS Simulator,name=iPhone 17 Pro" scripts/test-pipeline.sh
#
# If layer 2 fails with a "deployment target" mismatch, the auto-picked simulator's
# runtime is older than the app target — point SIM_DEST at a newer simulator.
#
# Exit code 0 only if every layer passes. In a broken-Vision simulator the suite
# fails at layer 2 with a diagnostic — that is the intended signal.
set -uo pipefail
cd "$(dirname "$0")/.."

SKIP_E2E=0
[[ "${1:-}" == "--skip-e2e" ]] && SKIP_E2E=1

# --- pick a simulator ---------------------------------------------------------
SIM_DEST="${SIM_DEST:-}"
UDID=""
if [[ -z "$SIM_DEST" ]]; then
    # Available iPhone simulator with the NEWEST runtime (the app target's deployment
    # target rules out older runtimes — picking the first match would fail the build).
    UDID=$(/usr/bin/python3 - <<'PYEOF'
import json, subprocess
out = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
d = json.loads(out)
best = None
for runtime, devs in d["devices"].items():
    suffix = runtime.rsplit("iOS-", 1)[-1]  # e.g. "26-4"
    parts = suffix.split("-")
    try:
        ver = tuple(int(p) for p in parts[:2])
    except ValueError:
        continue
    for dev in devs:
        if "iPhone" in dev["name"] and (best is None or ver > best[0]):
            best = (ver, dev["udid"])
print(best[1] if best else "")
PYEOF
)
    if [[ -z "$UDID" ]]; then
        echo "error: no available iPhone simulator found; set SIM_DEST explicitly" >&2
        exit 2
    fi
    SIM_DEST="platform=iOS Simulator,id=$UDID"
fi
echo "==> simulator: $SIM_DEST"

# --- layer 1: package tests ---------------------------------------------------
echo ""
echo "==> [1/3] CollagePipeline package tests (host, release)"
if (cd Pipeline && swift test -c release 2>&1 | tail -2); then :; else
    echo "FAIL: package tests failed" >&2
    exit 1
fi

# --- layer 2: app tests on the simulator (production path, real photos) -------
echo ""
echo "==> [2/3] App test suite incl. PipelineProductionPathTests ($SIM_DEST)"
DD=/tmp/buynothing-dd
if ! xcodebuild -project BuyNothing.xcodeproj -scheme BuyNothing \
        -destination "$SIM_DEST" -configuration Debug \
        -derivedDataPath "$DD" test 2>&1 | grep -E "Test Suite|TEST (SUCCEEDED|FAILED)|error:|✘.*failed" | tail -12; then
    echo "FAIL: app test suite failed (see output above; check status of the Vision environment gate)" >&2
    exit 1
fi

# --- layer 3: headless E2E dump of the one-shot capture pipeline --------------
if [[ "$SKIP_E2E" == "1" ]]; then
    echo ""
    echo "==> [3/3] skipped (--skip-e2e)"
    echo ""
    echo "PIPELINE OK (layers 1-2; E2E skipped)"
    exit 0
fi

echo ""
echo "==> [3/3] Headless E2E: one-shot capture pipeline with handRemoval"
APP_PATH="$DD/Build/Products/Debug-iphonesimulator/BuyNothing.app"
IMG_DIR="Pipeline/Tests/CollagePipelineTests/TestImages"
DUMP=/tmp/bn_pipeline_e2e
rm -rf "$DUMP"

xcrun simctl boot "$UDID" 2>/dev/null
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" com.byno.app 2>/dev/null
sleep 1

SIMCTL_CHILD_COLLAGE_DUMP_DIR="$DUMP" \
SIMCTL_CHILD_COLLAGE_SNAPSHOT_TEST_IMAGE="$PWD/$IMG_DIR/tools_03.jpg" \
SIMCTL_CHILD_COLLAGE_SNAPSHOT_QUERY=stapler \
SIMCTL_CHILD_COLLAGE_SNAPSHOT_LOCAL_IMAGES="$PWD/$IMG_DIR/tools_07.jpg:$PWD/$IMG_DIR/usbcable_03.jpg" \
SIMCTL_CHILD_COLLAGE_SNAPSHOT_STAGGER_MS=300 \
xcrun simctl launch "$UDID" com.byno.app

echo "    polling for completion (up to 5 min)..."
for _ in $(seq 1 60); do
    if [[ -f "$DUMP/status.txt" ]] && grep -qE "DONE|FAILED" "$DUMP/status.txt" 2>/dev/null; then
        break
    fi
    sleep 5
done

echo "---- status.txt ----"
cat "$DUMP/status.txt" 2>/dev/null || echo "(no status.txt — app never started the dump)"
echo "---- dump dir ----"
ls "$DUMP" 2>/dev/null

if grep -q "FAILED" "$DUMP/status.txt" 2>/dev/null; then
    echo "FAIL: E2E dump reported FAILED" >&2
    exit 1
fi
if ! grep -q "DONE" "$DUMP/status.txt" 2>/dev/null; then
    echo "FAIL: E2E dump did not complete in time" >&2
    exit 1
fi
if ! ls "$DUMP"/stream_after_*.png >/dev/null 2>&1; then
    echo "FAIL: no collage PNGs written" >&2
    exit 1
fi

echo ""
echo "PIPELINE OK (all 3 layers: package tests, app production-path tests, headless E2E)"
