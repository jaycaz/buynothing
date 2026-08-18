# segtest — segmentation test harness

Runs the app's real `ForegroundSegmenter` (Vision subject-lift) + `ObjectOrientationAligner`
— the exact source files the iOS app compiles — natively on macOS, so the snap-a-pic
segmentation step can be tested and automated without a device.

**Why not the simulator?** The subject-lift model (`VNGenerateForegroundInstanceMaskRequest`)
requires the Neural Engine. The iOS simulator does not emulate it and fails with
`com.apple.Vision Code=9 "Could not create inference context"`. An Apple silicon Mac has the
ANE, so the same code runs fine here (needs macOS 14+ on Apple silicon).

## Build & run

```bash
cd tools/segtest
swiftc -O -o segtest main.swift \
    ../../BuyNothing/Utilities/ImageGeometry.swift \
    ../../BuyNothing/Utilities/ForegroundSegmenter.swift \
    ../../BuyNothing/Utilities/ObjectOrientationAligner.swift
./segtest /path/to/photo.jpg /tmp/segtest-out
```

Output contract (machine-parseable, one line):

- Success: `DONE ms=<elapsed> cutout=<WxH> aligned=<WxH> out=<png path>` (exit 0)
- Failure: `FAILED reason=<why>` (exit 1)

The output PNG is the segmented, background-removed, PCA-aligned cutout — the same item the
app packs into the collage.
