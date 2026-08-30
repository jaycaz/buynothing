#!/usr/bin/env python3
"""montage.py — lay out strategy cutouts in a labeled grid over a checkerboard
(so transparency reads clearly) for side-by-side comparison.

  python3 montage.py <outDir> [label=filename ...]
"""
import sys, os
from PIL import Image, ImageDraw, ImageFont

def checker(w, h, cell=24):
    base = Image.new("RGB", (w, h), (210, 210, 210))
    d = ImageDraw.Draw(base)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if (x // cell + y // cell) % 2 == 0:
                d.rectangle([x, y, x + cell, y + cell], fill=(170, 170, 170))
    return base

def main():
    args = sys.argv[1:]
    outdir = args[0]
    items = []
    for spec in args[1:]:
        if "=" in spec:
            label, fn = spec.split("=", 1)
        else:
            label, fn = os.path.splitext(os.path.basename(spec))[0], spec
        items.append((label, fn))
    if not items:
        # default set
        for label, fn in [
            ("vision (baseline)", "s1_allinstances.png"),
            ("handpose", "s3_handpose.png"),
            ("skincolor", "s4_skincolor.png"),
            ("sam_auto", "sam_auto_cutout.png"),
            ("composite", "composite_cutout.png"),
        ]:
            p = os.path.join(outdir, fn)
            if os.path.exists(p):
                items.append((label, p))

    cell = 560
    cols = min(3, len(items))
    rows = (len(items) + cols - 1) // cols
    W = cols * cell
    H = rows * (cell + 30)
    canvas = checker(W, H)
    d = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 20)
    except Exception:
        font = ImageFont.load_default()

    for i, (label, fn) in enumerate(items):
        if os.path.exists(fn):
            p = fn
        elif os.path.isabs(fn):
            p = fn
        else:
            p = os.path.join(outdir, fn)
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGBA")
        im.thumbnail((cell - 20, cell - 50), Image.LANCZOS)
        cx = (i % cols) * cell
        cy = (i // cols) * (cell + 30)
        d.text((cx + 8, cy + 2), label, fill=(20, 20, 20), font=font)
        canvas.paste(im, (cx + 10, cy + 26), im)
    outp = os.path.join(outdir, "MONTAGE.png")
    canvas.save(outp)
    print("saved", outp)

if __name__ == "__main__":
    main()
