# Segmentation strategies — findings & implementation plan

**Date:** 2026-09-06
**Plan directory:** `.breakdown/segmentation-strategies/`
**Status:** planned, not yet executed

---

## Why this work exists

The cutout pipeline was built and tuned against one kind of photo: a hand holding
a tool against a plain background. A new, more general 36-photo test set
(`~/Downloads/test-images`) broke it badly — furniture, animals, and everyday
objects came out as unrecognisable fragments.

This document records what we measured, what explains it, and the plan that follows.

## What we measured

All 36 photos were run through both the existing `HandRemover` strategy and
Vision's `VNGenerateForegroundInstanceMaskRequest` on the macOS host.

| | General objects (dresser, chicken) | Held objects (hand gripping item) | Speed | Failures |
|---|---|---|---|---|
| **Vision subject lift** | Near-perfect silhouettes | Clean cut — but **keeps the hand** | 22–75 ms | **0 / 36** |
| **HandRemover** | Mangled — fragments and debris | Removes the hand, rough edges | 220–1400 ms | 0 crashes, many bad cutouts |

Vision found a subject in **all 36 images with zero failures**.

### The root cause

`HandRemover` is not a general segmenter. It uses the Vision mask only as a
*region prior*, then keeps a pixel only if it is **blue or red** (or highly
textured) AND not confidently skin-toned — see `HandRemover.swift:102-108`.

That colour gate explains both failures precisely:

- **Coral-pink dresser** (`00A0A_...jpg`) — the coral reads as skin under the
  `r - b > 0.18` test, so the whole dresser was classified as hand and removed,
  leaving a thin sliver.
- **White chicken** (`00a0a_...jpg`) — neither blue nor red, so only high-texture
  scraps survived: a swath of bird mixed with ground debris.

The strategy was correct for blue/red hand tools and is simply mis-applied to
general listing photos.

### Conclusions drawn

1. **Vision and HandRemover are complementary, not competing.** Vision isolates
   subjects; HandRemover strips hands. Neither does both.
2. **The obvious middle ground is `visionMinusSkin`** — keep Vision's mask,
   subtract only confident-skin pixels, drop the blue/red gate entirely.
3. **SAM is unnecessary.** Vision succeeded 36/36; there is no accuracy gap for a
   heavy model dependency to close.
4. **Testing must happen on the macOS host, not the iOS simulator.** On this
   machine every Vision call inside the simulator fails with code 9 "Could not
   create inference context" (`TODO.md:98-107`); the Mac host runs Vision fine.

## Decisions

| Decision | Rationale |
|---|---|
| Add `visionMinusSkin`; keep `vision` and `handRemover` selectable | The user wants to judge the differences by eye, not be given one answer |
| Drop SAM | No measured accuracy gap to justify it |
| Harness runs on the macOS host CLI | Simulator Vision is broken on this machine |
| Five tunable parameters, not fourteen | HandRemover's fourteen knobs are unusable as a review surface |
| `SegmentationStrategy` is an enum, not a protocol | Keeps future stages simple and additive; a 27B executor handles it reliably |
| Touch only `Pipeline/`; leave the iOS app alone | The app default is a decision to make *after* reviewing results |

### Explicitly out of scope

- The iOS app under `BuyNothing/`, including its hand-maintained duplicate
  `BuyNothing/Utilities/HandRemover.swift`
- SAM or any new model dependency
- Delighting / relighting / shadow removal / perspective correction — the design
  leaves room for them as sibling stages, but this plan does not implement them
- Changing HandRemover's algorithm or its default parameter values

## The plan

Five phases, each leaving the tree green, verified by 14 proof checks and 8
regression guards. Contracts land first; the UI lands last.

| # | Phase | What it delivers | Verified by |
|---|---|---|---|
| 01 | `segmentation-contract` | `Segmentation.run(_:strategy:params:)` over `raw` / `vision` / `handRemover`, plus `SegmentationParams` (5 knobs) and `SegmentationOutput` | 6 new tests; enum cases present |
| 02 | `vision-minus-skin` | The `visionMinusSkin` strategy + an `isConfidentSkin` classifier | 6 new tests; negative grep proving the blue/red gate wasn't reintroduced; diff guard on HandRemover |
| 03 | `batch-harness` | `SegmentationComparison.compare` + `pipeline-cli --batch <dir>` emitting `results.json`, cutout PNGs and `report.html` | 5 new tests; a real batch run over the 12 fixtures |
| 04 | `viewer-strategy-picker` | PipelineViewer: strategy picker, the 5 sliders, live debounced reprocess, all routed through `Segmentation.run` | Build + greps proving it no longer calls `HandRemover` directly |
| 05 | `viewer-compare-view` | PipelineViewer: all strategies side by side for one photo | Build + greps; the comparison logic itself is covered by phase 03's tests |

### A trap worth knowing about

`swift test --filter Foo` matches zero tests and **still exits 0**, printing
`Test run with 0 tests in 0 suites passed` — the same class of false positive
`AGENTS.md` documents for `xcodebuild`. Every test check in this plan therefore
also asserts the output matches `Test run with [1-9]`. Don't remove that guard.

### Test-fixture caveat

The 12 package fixtures show a **gloved** hand (`tools_03.jpg`), so there is
almost no bare skin to subtract. Any test asserting "skin subtraction shrinks the
mask" on those photos would be flaky. Phase 02 therefore unit-tests the skin
classifier on known RGB values instead.

## Running it

```bash
python3 ~/.claude/skills/breakdown/runner/run.py \
  /Users/jordan/Dev/buynothing/.breakdown/segmentation-strategies
```

Useful variants:

```bash
run.py <plan-dir> --status        # where things stand
run.py <plan-dir> --phase 02-vision-minus-skin
run.py <plan-dir> --keep-going    # don't halt on first failure
```

Executor: `qwen/qwen3.8-27b` via LM Studio, each phase in its own git worktree,
squash-merged into `main` on pass. No phase is gated — the whole plan is scoped
to `Pipeline/` and touches nothing that ships.

## What to look at when it's done

Run PipelineViewer, point it at `~/Downloads/test-images`, and turn on Compare
mode. The two photos that tell you the most:

- **`00A0A_...jpg`** (coral dresser) — `handRemover` destroys it, `vision` and
  `visionMinusSkin` should both be clean. Confirms the colour-gate diagnosis.
- **`leatherman-bond-opening.avif`** (hand opening a multitool) — `vision` keeps
  the hands, `visionMinusSkin` should drop them while keeping the tool intact.
  This is the case the new strategy exists for.
