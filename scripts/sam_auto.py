#!/usr/bin/env python3
"""Strategy: SAM automatic masks + per-mask distractor scoring (no prompts).

Fully automatic and general:
  1. SAM automatic mask generator splits the photo into candidate segments.
  2. Each segment is scored:
       skin_frac    — fraction of pixels with warm skin chroma (distractor: hand)
       product_frac — fraction that are saturated (handles) or textured (metal text)
  3. Keep segments that are product, not hand; union them -> final mask.

Extensible: `skin_frac` is the "distractor" score. Add other distractor
detectors (e.g. a second person, a phone) by OR-ing their masks into the
same score. See SEGMENTATION_RESEARCH.md.
"""
import sys, os
import numpy as np
from PIL import Image
import segment_anything as sam
from scipy import ndimage as ndi

import argparse
ap = argparse.ArgumentParser()
ap.add_argument("image")
ap.add_argument("--out", default=".")
ap.add_argument("--region", default=None, help="foreground region mask PNG (e.g. Vision subject-lift) to gate segments against")
args = ap.parse_args()
SRC = args.image
OUT = args.out
os.makedirs(OUT, exist_ok=True)
CKPT = "/tmp/sam_vit_b_01ec64.pth"

im = Image.open(SRC).convert("RGB")
scale = min(1.0, 1500.0 / max(im.size))
if scale < 1.0:
    im = im.resize((int(im.size[0]*scale), int(im.size[1]*scale)), Image.LANCZOS)
a = np.asarray(im)
H, W, _ = a.shape

REGION = None
if args.region:
    rm = Image.open(args.region).convert("L")
    if rm.size != (W, H):
        rm = rm.resize((W, H), Image.NEAREST)
    REGION = np.asarray(rm) > 127
    print(f"region prior: {REGION.mean():.3f}")

r = a[...,0].astype(float)/255; g = a[...,1].astype(float)/255; b = a[...,2].astype(float)/255
mx, mn = a.max(-1)/255, a.min(-1)/255
sat = (mx-mn)/np.maximum(mx,1e-6)
L = a.mean(-1)
mag = np.hypot(ndi.sobel(L,axis=1), ndi.sobel(L,axis=0))
tex = ndi.uniform_filter(mag, size=21)

def is_skin():
    warm = (r>g)&(g>b)&((r-g)>0.03)&((g-b)>0.015)
    return warm & (sat<0.80) & (mx>0.12) & (mx<0.98)
def is_product():
    satc = sat>0.30
    texc = tex>12
    return satc|texc
SKIN, PROD = is_skin(), is_product()

model = sam.build_sam_vit_b(checkpoint=CKPT)
gen = sam.SamAutomaticMaskGenerator(model, points_per_side=32, min_mask_region_area=2000)
masks = gen.generate(a)
print(f"candidate masks: {len(masks)}")

keep = np.zeros((H,W), bool)
log = []
for m in masks:
    mm = m["segmentation"]; area = mm.sum()
    if area < 4000: continue
    sf = float(SKIN[mm].mean()); pf = float(PROD[mm].mean())
    inreg = float((mm & REGION).sum() / area) if REGION is not None else 1.0
    # product, not hand, inside the salient region
    good = (sf < 0.35) and (pf > 0.15) and (inreg > 0.5)
    log.append((area, round(sf,2), round(pf,2), round(inreg,2), good))
    if good: keep |= mm
log.sort(reverse=True)
print("kept segments (area, skin, product):")
for x in log:
    print(f"  area={x[0]:6d} skin={x[1]:.2f} prod={x[2]:.2f} inreg={x[3]:.2f} keep={x[4]}")

# cleanup: close gaps between tool sub-parts, drop specks, fill holes
keep = ndi.binary_closing(keep, iterations=4)
lab, n = ndi.label(keep, structure=np.ones((3,3),bool))
if n:
    sz = np.bincount(lab.ravel())[1:]
    keep = np.isin(lab, np.where(sz>1500)[0]+1)
keep = ndi.binary_fill_holes(keep)

alpha = ndi.gaussian_filter((keep*255).astype(float), 1.0)
out = np.dstack([a, np.clip(alpha,0,255).astype(np.uint8)])
Image.fromarray(out).save(f"{OUT}/sam_auto_cutout.png")
Image.fromarray((keep*255).astype("uint8")).save(f"{OUT}/sam_auto_mask.png")
print(f"final_frac={keep.mean():.3f}  saved {OUT}/sam_auto_cutout.png")
