# Tool Cutout — Strategy Harness

Removes a holding hand (and other distractors) from a product photo, leaving a
clean transparent cutout of the tool. Built to be **general** (no per-image
points) and **extensible** (add distractor classes beyond hands).

Driven by `SEGMENTATION_RESEARCH.md`. Tested on `IMG_2995` (Klein wire
stripper held in an open hand).

## Results on IMG_2995 (see `out/seg/MONTAGE.png`)

| strategy      | what it does                                   | result on this image |
|---------------|------------------------------------------------|----------------------|
| `vision`      | Vision subject-lift, all instances             | hand + tool merged (the baseline failure) |
| `handpose`    | subject-lift − hand-pose skeleton (capsules)   | eats the head (tool is *between* the fingers) |
| `skincolor`   | subject-lift − warm-skin pixels                | eats the gray head, misses shadowed palm |
| `sam_auto`    | SAM auto-masks, keep low-skin ones in region   | handles only (head merged with palm → dropped) |
| **`composite`** | region + SAM product parts + pixel resolve   | **full tool, hand gone — best** |

**`composite` wins** for this case. The key insight: the tool head is *inside*
the hand and touches the palm, so no 2D hand-geometry subtraction (handpose) or
pure color test (skincolor) can separate them. You need a **product signal**
(SAM mask + saturation/texture) to keep the head, and a **confident-skin** test
to drop the palm.

## How it works (composite)

1. **region** — Vision subject-lift (`VNGenerateForegroundInstanceMaskRequest`)
   gives the hand+tool blob. (rembg/u2net works too.)
2. **product parts** — SAM automatic mask generator splits the blob; keep masks
   that are mostly inside the region and have low skin fraction. This grabs the
   blue handles cleanly.
3. **resolve** — in the rest of the region (head + palm merged), keep pixels
   that are product-like (saturated color OR local texture like text/serrations)
   and *not* confident skin; drop the rest (the palm).
4. **cleanup** — close gaps, drop small components, fill holes, feather alpha.

## Running

```bash
# 1) Swift harness: vision + handpose + skincolor (native, fast)
cd tools/segsuite
swiftc -O -o segsuite main.swift \
  ../../Pipeline/Sources/CollagePipeline/ForegroundSegmenter.swift \
  ../../Pipeline/Sources/CollagePipeline/ImageGeometry.swift
./segsuite /path/to/photo.png out/seg        # writes s1_*, s3_*, s4_*, s1_mask.png

# 2) Python: sam_auto (needs region mask)
python3 scripts/sam_auto.py /path/to/photo.png --out out/seg --region out/seg/s1_mask.png

# 3) Python: composite (the best one)
python3 scripts/composite.py /path/to/photo.png --out out/seg --region out/seg/s1_mask.png

# 4) Compare
python3 scripts/montage.py out/seg            # -> out/seg/MONTAGE.png
```

One-shot: `scripts/run_all.sh photo.png outDir`.

## Extending to other distractors

The hand is just the first distractor class. The pipeline is structured so each
distractor contributes a *mask* that gets subtracted (or scored against):

- `composite.py` — `confident_skin()` is the hand mask. To also remove, say, a
  second person's arm or a phone in the background, OR another detector's mask
  into the drop-set (e.g. a face/body detector, or a second SAM "person" mask).
- `sam_auto.py` — the `skin` fraction is the per-mask distractor score; add more
  distractor scores the same way.
- Swift `segsuite` — `VNDetectHumanHandPoseRequest` is the hand; Vision also has
  face/body requests you can subtract the same way.

## Files

- `tools/segsuite/main.swift` — Swift: vision / handpose / skincolor strategies
- `scripts/composite.py` — Python: the winning composite strategy
- `scripts/sam_auto.py` — Python: SAM auto-mask scoring strategy
- `scripts/montage.py` — comparison grid
- `scripts/run_all.sh` — runs everything + montage

## Caveats

- `composite` leaves thin skin slivers where the head meets the palm; a matting
  pass (research doc strategy 4) would clean those.
- Relies on the tool having *some* product signal (saturation or texture). A
  completely smooth, skin-colored object in a hand would leak — that's the
  fundamental limit of appearance-based separation and is what the research doc's
  interactive SAM2 point-tap (strategy 3) is for.
- Needs the Neural Engine / on-device Vision for subject-lift, so test on macOS
  or a real device (the simulator has no ANE).
