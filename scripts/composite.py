#!/usr/bin/env python3
"""Strategy: composite (subject-lift region + SAM product parts + pixel resolve).

General, no per-image points:
  1. region   — Vision subject-lift (or rembg): the hand+tool blob.
  2. product  — SAM automatic masks inside the region that are NOT skin
                (cleanly grabs saturated/textured parts like the handles).
  3. resolve  — inside region minus product, keep pixels that are product-like
                (saturated OR textured) and not confident skin; drop the rest
                (the palm). This recovers the metal head that SAM merged with
                the palm.
  4. cleanup + feather -> RGBA cutout.

Extensible: the "not skin" test is the hand distractor. OR in other
distractor masks (second person, phone) to generalize.
"""
import argparse
import numpy as np
from PIL import Image
import segment_anything as sam
from scipy import ndimage as ndi

ap = argparse.ArgumentParser()
ap.add_argument("image")
ap.add_argument("--out", default=".")
ap.add_argument("--region", required=True, help="subject-lift region mask PNG (full-res)")
args = ap.parse_args()

import os
os.makedirs(args.out, exist_ok=True)
CKPT = "/tmp/sam_vit_b_01ec64.pth"

im = Image.open(args.image).convert("RGB")
scale = min(1.0, 1500.0 / max(im.size))
if scale < 1.0:
    im = im.resize((int(im.size[0]*scale), int(im.size[1]*scale)), Image.LANCZOS)
a = np.asarray(im); H, W, _ = a.shape
rm = Image.open(args.region).convert("L")
if rm.size != (W, H): rm = rm.resize((W, H), Image.NEAREST)
region = np.asarray(rm) > 127
print(f"region frac={region.mean():.3f}")

r = a[...,0]/255.; g = a[...,1]/255.; b = a[...,2]/255.
mx, mn = a.max(-1)/255, a.min(-1)/255
sat = (mx-mn)/np.maximum(mx, 1e-6)
L = a.mean(-1)
mag = np.hypot(ndi.sobel(L, axis=1), ndi.sobel(L, axis=0))
tex = ndi.uniform_filter(mag, size=21)

def skin_mask():
    warm = (r > g) & (g > b) & ((r - g) > 0.03) & ((g - b) > 0.015)
    return warm & (sat < 0.80) & (mx > 0.12) & (mx < 0.98)
def confident_skin():
    # bright warm skin: palm/fingers. Head (gray) has low r-b, so this is safe.
    return (r - b > 0.18) & (r > g) & (mx > 0.25)
def product_color():
    blue = (b > r*1.15) & (b > 0.25) & (sat > 0.15)
    red = (r > g*1.5) & (r > b*1.3) & (sat > 0.25) & (r - g > 0.15)
    return blue | red

SKIN = skin_mask(); CSKIN = confident_skin(); PROD = product_color()

# 2. SAM product parts (low-skin masks inside region)
model = sam.build_sam_vit_b(checkpoint=CKPT)
gen = sam.SamAutomaticMaskGenerator(model, points_per_side=32, min_mask_region_area=2000)
masks = gen.generate(a)
product = np.zeros((H, W), bool)
for m in masks:
    mm = m["segmentation"]; area = mm.sum()
    if area < 4000: continue
    inreg = (mm & region).sum() / area
    if inreg < 0.5: continue
    sf = SKIN[mm].mean()
    if sf < 0.30:
        product |= mm & region
print(f"sam product frac={product.mean():.3f}")

# 3. resolve the rest of the region
rest = region & ~product
keep_rest = rest & (PROD | (tex > 12)) & ~CSKIN
final = product | keep_rest
print(f"rest={rest.mean():.3f} keep_rest={keep_rest.mean():.3f}")

# 4. cleanup
final = ndi.binary_closing(final, iterations=3)
lab, n = ndi.label(final, structure=np.ones((3,3), bool))
if n:
    sz = np.bincount(lab.ravel())[1:]
    final = np.isin(lab, np.where(sz > 1200)[0] + 1)
final = ndi.binary_fill_holes(final)
# drop residual confident-skin specks
final &= ~ndi.binary_erosion(CSKIN, iterations=6)

alpha = ndi.gaussian_filter((final*255).astype(float), 1.0)
out = np.dstack([a, np.clip(alpha, 0, 255).astype(np.uint8)])
Image.fromarray(out).save(f"{args.out}/composite_cutout.png")
Image.fromarray((final*255).astype("uint8")).save(f"{args.out}/composite_mask.png")
print(f"final_frac={final.mean():.3f}  saved {args.out}/composite_cutout.png")
