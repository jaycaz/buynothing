#!/usr/bin/env python3
"""benchmark.py — run every cutout strategy on each test image and build:
  - per-image comparison strips (all strategies side by side)
  - GALLERY.png/.jpg (all strips stacked, for iPhone review)
  - REPORT.tsv (per-strategy ok/ms/dimensions/opaque fraction)
and sync the results to the iCloud BN-Cutout-TestSet/results/ folder.

Usage:
  python3 scripts/benchmark.py [--testset testset] [--out out/bench] [--workers 4]
                               [--segsuite tools/segsuite/segsuite]
"""
import argparse
import concurrent.futures as cf
import os
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent  # worktree root
ICLOUD = Path("/Users/jordan/Library/Mobile Documents/com~apple~CloudDocs/BN-Cutout-TestSet")

# (label, source-file in the per-image dir)
PANELS = [
    ("vision", "s1_allinstances.png"),
    ("handpose", "s3_handpose.png"),
    ("skincolor", "s4_skincolor.png"),
    ("sam_auto", "sam_auto_cutout.png"),
    ("composite", "composite_cutout.png"),
    ("composite_swift", "composite_swift.png"),  # optional
]


def run(cmd, timeout=600):
    t0 = time.time()
    r = subprocess.run(cmd, capture_output=True, timeout=timeout, cwd=str(ROOT))
    ms = int((time.time() - t0) * 1000)
    return (r.returncode == 0), ms, (r.stderr.decode(errors="replace")[-300:] if r.returncode else "")


def process_image(img: Path, outdir: Path, segsuite: str, handremover: str = ""):
    stem = img.stem
    d = outdir / stem
    d.mkdir(parents=True, exist_ok=True)
    rows = []

    def rec(strategy, ok, ms, err="", fn=None):
        w = h = 0
        op = 0.0
        if ok and fn and (d / fn).exists():
            im = Image.open(d / fn)
            w, h = im.size
            a = im.convert("RGBA")
            alpha = a.getchannel("A")
            hist = alpha.histogram()
            op = sum(hist[16:]) / max(1, sum(hist))
        rows.append([stem, img.name.split("_")[0], strategy, "1" if ok else "0", ms, w, h, round(op, 3), err.replace("\t", " ")])

    # 1) Swift harness: vision / handpose / skincolor
    ok, ms, err = run([segsuite, str(img), str(d)])
    rec("segsuite(all)", ok, ms, err)
    for label, fn in PANELS[:3]:  # vision, handpose, skincolor
        rec(label, (d / fn).exists(), 0, "" if (d / fn).exists() else "missing", fn)

    # 2) sam_auto
    ok, ms, err = run([sys.executable, "scripts/sam_auto.py", str(img), "--out", str(d), "--region", str(d / "s1_mask.png")], timeout=900)
    rec("sam_auto", (d / "sam_auto_cutout.png").exists(), ms, "" if (d / "sam_auto_cutout.png").exists() else (err or "missing"), "sam_auto_cutout.png")

    # 3) composite (best)
    ok, ms, err = run([sys.executable, "scripts/composite.py", str(img), "--out", str(d), "--region", str(d / "s1_mask.png")], timeout=900)
    rec("composite", (d / "composite_cutout.png").exists(), ms, "" if (d / "composite_cutout.png").exists() else (err or "missing"), "composite_cutout.png")

    # 4) composite_swift (native Swift HandRemover port)
    if handremover:
        ok, ms, err = run([handremover, "--handremover", str(img), "--handremover-out", str(d / "composite_swift.png")], timeout=600)
        rec("composite_swift", (d / "composite_swift.png").exists(), ms, "" if (d / "composite_swift.png").exists() else (err or "missing"), "composite_swift.png")

    make_strip(img, d)
    return rows


def checker(w, h, cell=20):
    im = Image.new("RGB", (w, h), (215, 215, 215))
    d = ImageDraw.Draw(im)
    for y in range(0, h, cell):
        for x in range(0, w, cell):
            if (x // cell + y // cell) % 2 == 0:
                d.rectangle([x, y, x + cell, y + cell], fill=(175, 175, 175))
    return im


def make_strip(img: Path, d: Path):
    pw, ph = 620, 480
    panels = []
    for label, fn in PANELS:
        p = d / fn
        if not p.exists():
            panels.append((label, None))
            continue
        im = Image.open(p).convert("RGBA")
        im.thumbnail((pw - 24, ph - 40), Image.LANCZOS)
        panels.append((label, im))

    n = len(panels)
    W = n * pw
    H = ph + 34
    canvas = checker(W, H)
    d2 = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 18)
    except Exception:
        font = ImageFont.load_default()

    d2.text((8, 6), img.stem, fill=(15, 15, 15), font=font)
    for i, (label, im) in enumerate(panels):
        x0 = i * pw
        d2.text((x0 + 8, 6), label, fill=(15, 15, 15), font=font)
        if im is None:
            d2.rectangle([x0 + 8, 30, x0 + pw - 8, H - 8], outline=(200, 60, 60), width=2)
            d2.text((x0 + 16, 40), "FAILED", fill=(200, 40, 40), font=font)
            continue
        px = x0 + (pw - im.width) // 2
        py = 34 + (ph - 40 - im.height) // 2
        canvas.paste(im, (px, py), im)
    canvas.save(d / "strip.png")
    canvas.convert("RGB").save(d / "strip.jpg", quality=85)


def build_gallery(outdir: Path):
    strips = sorted(outdir.glob("*/strip.jpg"), key=lambda p: p.parent.name)
    if not strips:
        print("no strips found; skipping gallery")
        return
    ims = [Image.open(s) for s in strips]
    W = max(i.width for i in ims)
    H = sum(i.height for i in ims) + 6 * (len(ims) - 1)
    canvas = Image.new("RGB", (W, H), (240, 240, 240))
    y = 0
    for im in ims:
        canvas.paste(im, (0, y))
        y += im.height + 6
    canvas.save(outdir / "GALLERY.png")
    canvas.save(outdir / "GALLERY.jpg", quality=82)
    print(f"gallery: {W}x{H} -> {outdir/'GALLERY.jpg'}")

    if ICLOUD.exists():
        res = ICLOUD / "results"
        res.mkdir(exist_ok=True)
        import shutil
        for f in ["GALLERY.jpg", "GALLERY.png", "REPORT.tsv"]:
            src = outdir / f
            if src.exists():
                shutil.copy(src, res / f)
        print(f"synced results -> {res}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--testset", default=str(ROOT / "testset"))
    ap.add_argument("--out", default=str(ROOT / "out" / "bench"))
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--segsuite", default=str(ROOT / "tools" / "segsuite" / "segsuite"))
    ap.add_argument("--handremover", default="", help="pipeline-cli with --handremover (composite_swift panel)")
    args = ap.parse_args()

    testset = Path(args.testset)
    outdir = Path(args.out)
    outdir.mkdir(parents=True, exist_ok=True)
    imgs = sorted(p for p in testset.iterdir() if p.suffix.lower() in (".jpg", ".jpeg", ".png"))
    if not imgs:
        print(f"no images in {testset} — nothing to benchmark (exit 0)")
        return

    report = outdir / "REPORT.tsv"
    all_rows = []
    with cf.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(process_image, img, outdir, args.segsuite, args.handremover): img for img in imgs}
        for i, f in enumerate(cf.as_completed(futs), 1):
            img = futs[f]
            try:
                rows = f.result()
                all_rows.append((img.name, rows))
                print(f"[{i}/{len(imgs)}] {img.stem} done", flush=True)
            except Exception as e:
                print(f"[{i}/{len(imgs)}] {img.stem} ERROR: {e}", flush=True)
                all_rows.append((img.name, [[img.stem, img.name.split('_')[0], "all", "0", 0, 0, 0, 0, str(e)[:200]]]))

    all_rows.sort(key=lambda x: x[0])
    with open(report, "w") as f:
        f.write("stem\tcategory\tstrategy\tok\tms\tw\th\topaque_frac\terror\n")
        for _, rows in all_rows:
            for r in rows:
                f.write("\t".join(str(x) for x in r) + "\n")
    print(f"report -> {report}")

    build_gallery(outdir)


if __name__ == "__main__":
    main()
