#!/usr/bin/env python3
"""adversarial_set.py — synthesize a small adversarial cutout test set from the
existing 50-photo benchmark by perturbing the OBJECT region (using each photo's
composite_mask.png as the object prior) into the hard classes:

  skin_tone     object recolored to skin tone (wood/tan-object failure class)
  white_on_white object + background both near-white
  dark_object   object crushed to near-black
  glossy        diagonal white highlight gradient over the object
  hand_below    whole photo flipped vertically (hand grips from below)
  low_contrast  object blended 60% toward the mean background color

Output: testset_adversarial/<src_stem>_<class>.jpg + MANIFEST.tsv
"""
import numpy as np
from PIL import Image, ImageFilter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BENCH = ROOT / "out" / "bench"
OUT = ROOT / "testset_adversarial"
OUT.mkdir(parents=True, exist_ok=True)

# (source photo, class)
PLAN = [
    ("tools_07", "skin_tone"), ("tools_07", "dark_object"), ("tools_07", "glossy"),
    ("usbcable_03", "skin_tone"), ("usbcable_03", "white_on_white"), ("usbcable_03", "low_contrast"),
    ("books_03", "skin_tone"), ("books_03", "hand_below"), ("books_03", "glossy"),
    ("tech_06", "dark_object"), ("tech_06", "white_on_white"), ("tech_06", "low_contrast"),
    ("tools_03", "hand_below"), ("tools_03", "glossy"), ("tools_03", "skin_tone"),
]

def load(stem):
    im = Image.open(BENCH / stem / "composite_cutout.png").convert("RGB")
    # photo = original source photo (full frame); cutout only exists cropped, so
    # rebuild: use the testset photo directly.
    photo = Image.open(ROOT / "testset" / f"{stem}.jpg").convert("RGB")
    m = np.asarray(Image.open(BENCH / stem / "composite_mask.png").convert("L")) > 127
    if m.shape != (photo.height, photo.width):
        m = np.asarray(Image.fromarray(m.astype("uint8") * 255).resize(photo.size, Image.NEAREST)) > 127
    # feather the mask edge for smooth blends
    mf = Image.fromarray((m * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(2))
    mf = (np.asarray(mf).astype(float) / 255.0)[..., None]
    return photo, m, mf

def hsv_photo(im: Image.Image):
    return im.convert("HSV"), [im.convert("HSV").split()[i] for i in range(3)]

def put_hsv(h, s, v):
    return Image.merge("HSV", (h, s, v)).convert("RGB")

def transform(src, cls):
    photo, m, mf = load(src)
    a = np.asarray(photo).astype(float)
    W, H = photo.size
    if cls == "hand_below":
        return photo.transpose(Image.FLIP_TOP_BOTTOM)
    h, s, v = [np.asarray(c).astype(float) for c in photo.convert("HSV").split()]
    if cls == "skin_tone":
        # H -> ~20deg, S -> 0.35, keep relative shading in V
        h = np.full_like(h, 20.0 / 360.0 * 255.0)
        s = np.clip(0.35 * 255.0 + 0.12 * (v - v.mean()), 55, 120)
        v = np.clip((v - v.mean()) * 0.5 + 0.72 * 255.0, 95, 215)
    elif cls == "white_on_white":
        h = np.full_like(h, 25.0)
        s = np.clip(13.0 + 0.15 * (v - v.mean()) * 0.5, 4, 24)
        v = np.clip(235.0 + 0.20 * (v - v.mean()), 210, 252)
        bg = (1 - mf) * (255.0 - a) * 0.55  # lighten background toward white
        a = a + bg
    elif cls == "dark_object":
        v = np.clip(30.0 + 0.35 * (v - v.mean()), 12, 55)
    elif cls == "glossy":
        yy, xx = np.mgrid[0:H, 0:W]
        t = (xx / W + yy / H) / 2.0 - 0.5            # -0.5..0.5 diagonal
        gain = np.clip(t, 0, 1) * 0.55
        a = a + (255.0 - a) * (gain[..., None]) * mf
    elif cls == "low_contrast":
        bgm = a[~m].mean(axis=0) if m.any() and not m.all() else a.mean(axis=0)
        a = a * (1 - 0.60 * mf) + bgm * (0.60 * mf)
    else:
        raise ValueError(cls)
    return Image.fromarray(np.clip(a, 0, 255).astype("uint8"))

def main():
    rows = []
    for src, cls in PLAN:
        out = OUT / f"{src}_{cls}.jpg"
        im = transform(src, cls)
        im.save(out, quality=88)
        rows.append([src, cls, out.name, f"{im.size[0]}x{im.size[1]}"])
        print(f"{out.name}  {im.size}")
    with open(OUT / "MANIFEST.tsv", "w") as f:
        f.write("src\tclass\tfile\tsize\n")
        for r in rows:
            f.write("\t".join(r) + "\n")
    print(f"MANIFEST -> {OUT/'MANIFEST.tsv'}  ({len(rows)} images)")

if __name__ == "__main__":
    main()
