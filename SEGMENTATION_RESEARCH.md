# Interactive & Reliable Foreground Segmentation — Research

## What's already in place
`ForegroundSegmenter.swift` wraps `VNGenerateForegroundInstanceMaskRequest` (iOS 17+ subject-lift), takes **all** detected instances, composites them onto a transparent background, then crops to bounding box. `Pipeline/Metrics.swift` has an IoU harness against `SyntheticToolImageGenerator`'s exact ground-truth silhouette, and `segtest` runs the real pipeline natively on Apple Silicon (simulator has no Neural Engine).

**The core gap**: this is fully automatic and saliency-based, not semantic or interactive. Vision's subject-lift groups connected salient regions — it doesn't "know" what a hand is, so when skin touches the object it's very likely to merge hand + object into one instance (or, less often, split them arbitrarily). `allInstances` also has no way to say "give me the mug, not the mug plus the person behind it." That's exactly the failure mode described (hands holding the object, other distractors).

## Strategies, roughly cheapest → most robust

### 1. Tap-to-pick among Vision's own instances (near-zero new code)
`result.allInstances` is an `IndexSet` — instead of always unioning all of them, generate a mask per-instance and let the user tap the blob they want (`generateScaledMaskForImage(forInstances:)` takes any subset). Cheap to try, but only helps when the hand happens to land in a *separate* instance from the object — worth testing on real "holding an item" photos to see how often that's true before investing further.

### 2. Hand-aware subtraction using `VNDetectHumanHandPoseRequest`
Run hand-pose detection alongside subject-lift, take the landmark convex hull (dilated a bit, since fingers wrap around objects), and subtract that region from the instance mask. This directly targets the "hands holding the object" case rather than relying on saliency segmentation to separate them on its own. Needs morphological closing afterward to fill the hole where fingers actually occluded part of the object, or you get bite marks in the cutout.

### 3. Promptable interactive segmentation — SAM2 on-device (the "reliable + interactive" answer)
Apple has published official Core ML conversions of SAM2 on Hugging Face (`apple/coreml-sam2-tiny`, `-small`, `-baseplus`, `-large`), plus a reference SwiftUI/Core ML demo app pattern (encode the image once into an embedding, then run cheap point/box-prompted decodes repeatedly). This gives an actual interactive loop: user taps the object → mask appears → user taps a spot on the hand as a *negative* point → mask retracts. That iterative positive/negative point refinement is the standard UX for "get it exactly right" segmentation (same idea Photoshop's object-selection and research tools like RITM/SimpleClick use), and it's the most direct way to guarantee reliability regardless of what's touching the object. `-tiny` or `-small` are the ones worth prototyping first for on-device latency.

### 4. Edge-quality pass for the actual cutout
Once you have a good binary mask, feeding it through a matting/edge-refinement step (guided filter, or a small dedicated matting model) will matter for compositing quality in `BoardRenderer` — coarse instance/SAM masks tend to have jagged edges on hair-thin or reflective object boundaries. Lower priority than fixing the hand problem, but worth a pass before this feeds real collages.

### 5. Classical fallback (GrabCut-style)
Worth keeping only as a last resort for devices/paths without Neural Engine access — lower quality, but it's the one approach where the existing "draw a box, refine" interaction model transfers directly without any ML model at all.

## Suggested order of experiments
1. Quick test: on real hand-holding photos, check whether Vision already splits hand vs. object into separate instances (strategy 1) — if it does more often than expected, interactivity is nearly free.
2. Add hand-pose-based subtraction (strategy 2) as an automatic cleanup layer regardless — cheap, no new model weights, directly addresses the stated distractor.
3. Prototype SAM2-tiny Core ML with a minimal point-tap UI as the "when automatic isn't enough" refinement mode — this is what actually gets to *reliable* per user control, not just automatic guessing.
4. Extend `Metrics.swift`'s IoU harness with a small set of *real* photos (hand-held, cluttered background) rather than only synthetic ground truth, so strategies 1–3 can be compared on the case that actually matters, using the same `segtest`-style CLI workflow already in place.

## Sources
- [VNGenerateForegroundInstanceMaskRequest docs](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest)
- [Lift subjects from images in your app – WWDC23 notes](https://wwdcnotes.com/documentation/wwdc23-10176-lift-subjects-from-images-in-your-app/)
- [apple/coreml-sam2-tiny](https://huggingface.co/apple/coreml-sam2-tiny) · [coreml-sam2-small](https://huggingface.co/apple/coreml-sam2-small) · [coreml-sam2-baseplus](https://huggingface.co/apple/coreml-sam2-baseplus) · [coreml-sam2-large](https://huggingface.co/apple/coreml-sam2-large)
- [SAM 2 overview – Ultralytics docs](https://docs.ultralytics.com/models/sam-2)
- [I Built a Swift Library to Run Segment Anything Natively on iPhone (SAMKit)](https://rockyshikoku.medium.com/i-built-a-swift-library-to-run-segment-anything-natively-on-iphone-2a1444aba825)
- [Detecting hand pose with the Vision framework](https://www.createwithswift.com/detecting-hand-pose-with-the-vision-framework/)
- [VNDetectHumanHandPoseRequest docs](https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest)
