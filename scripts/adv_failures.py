#!/usr/bin/env python3
"""adv_failures.py — measure failure modes per strategy on the adversarial set.

Per (image, strategy) cutout:
  opaque_frac   alpha>16 fraction of the cutout canvas (< 0.01 = object lost)
  hand_residue  confident-skin fraction among opaque pixels (composite.py heuristic)
  n_comp        8-connected components > 1200px (>= 2 = split)
Writes out/bench_adv/FAILURES.md.
"""
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "out" / "bench_adv"
MANIFEST = (ROOT / "testset_adversarial" / "MANIFEST.tsv").read_text().strip().splitlines()[1:]
STRATS = [
    ("vision", "s1_allinstances.png"),
    ("handpose", "s3_handpose.png"),
    ("skincolor", "s4_skincolor.png"),
    ("sam_auto", "sam_auto_cutout.png"),
    ("composite", "composite_cutout.png"),
    ("composite_swift", "composite_swift.png"),
]

def confident_skin(a: np.ndarray) -> np.ndarray:
    r, g, b = a[..., 0] / 255, a[..., 1] / 255, a[..., 2] / 255
    mx = a.max(-1) / 255
    return (r - b > 0.18) & (r > g) & (mx > 0.25)

rows = []
for line in MANIFEST:
    src, cls, fname, size = line.split("\t")
    stem = fname.replace(".jpg", "")
    for label, fn in STRATS:
        p = D / stem / fn
        if not p.exists():
            rows.append([stem, cls, label, "MISSING"])
            continue
        im = Image.open(p).convert("RGBA")
        a = np.asarray(im)
        alpha = a[..., 3]
        opaque = alpha > 16
        of = float(opaque.mean())
        if opaque.any():
            hr = float(confident_skin(a)[opaque].mean())
        else:
            hr = 0.0
        lab, n = ndi.label(opaque, structure=np.ones((3, 3), bool))
        ncomp = 0
        if n:
            sz = np.bincount(lab.ravel())[1:]
            ncomp = int((sz > 1200).sum())
        flags = []
        if of < 0.01: flags.append("OBJECT_LOST")
        if hr > 0.15: flags.append("HAND_KEPT")
        if ncomp >= 2: flags.append("SPLIT")
        rows.append([stem, cls, label, round(of, 3), round(hr, 3), ncomp, ",".join(flags) or "-"])

hdr = ["image", "class", "strategy", "opaque_frac", "hand_residue", "n_comp", "flags"]
with open(D / "FAILURES.md", "w") as f:
    f.write("# Adversarial set — per-strategy measurements\n\n")
    f.write("opaque_frac = alpha>16 fraction of cutout canvas; hand_residue = confident-skin "
            "fraction of opaque pixels; n_comp = components >1200px.\n\n")
    f.write("| " + " | ".join(hdr) + " |\n")
    f.write("|" + "---|" * len(hdr) + "\n")
    for r in rows:
        f.write("| " + " | ".join(str(x) for x in r) + " |\n")

# per-class rollup: which strategy has the most flags
from collections import defaultdict
by_class = defaultdict(list)
for r in rows:
    if len(r) == 7 and r[6] != "-":
        by_class[r[1]].append((r[0], r[2], r[6]))
f = open(D / "FAILURES.md", "a")
f.write("\n## Flagged cases by perturbation class\n\n")
for cls in sorted(by_class):
    f.write(f"### {cls}\n\n")
    for img, strat, flags in by_class[cls]:
        f.write(f"- **{img}** / {strat} — {flags}\n")
    f.write("\n")
f.close()
print(f"rows={len(rows)} flagged={sum(1 for r in rows if len(r)==7 and r[6]!='-')}")
print(f"-> {D/'FAILURES.md'}")
