#!/usr/bin/env python3
"""sweep.py — one-at-a-time parameter sweep of HandRemover over the 50-photo set.

Runs the pipeline-cli sweep mode (one invocation per image, all configs in one JSON —
the Vision region prior is computed once per image, isolating the pixel/cleanup pass).
Metrics per (config, image):
  opaque_frac        fraction of cutout alpha > 16 (object-lost if < 0.01)
  iou_vs_baseline    IoU of the full-frame mask vs the shipped-default config (c0)
  iou_vs_sam         IoU vs the SAM auto mask (external reference)
Aggregate per config: means, lost_count, mean ms. Ranks configs and renders
COMPARE.jpg (original | baseline | best) for ~10 images.

Outputs under out/sweep/: SWEEP_GRID.json, SWEEP_REPORT.tsv, SWEEP_SUMMARY.md,
COMPARE.jpg, per-image masks/cutouts in out/sweep/imgs/<stem>/.
"""
import json
import subprocess
import concurrent.futures as cf
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BINARY = ROOT / "Pipeline" / ".build" / "arm64-apple-macosx" / "release" / "pipeline-cli"
TESTSET = Path("/private/tmp/buynothing-wt-tool-seg/testset")
SAM = Path("/private/tmp/buynothing-wt-tool-seg/out/bench")
OUT = ROOT / "out" / "sweep"
IMG = OUT / "imgs"
OUT.mkdir(parents=True, exist_ok=True)
IMG.mkdir(parents=True, exist_ok=True)
WORKERS = 4

DEFAULTS = dict(
    skinRBGap=0.18, skinValMin=0.25, blueSatMin=0.15, blueBMin=0.25,
    redSatMin=0.25, redRGBap=0.15, textureRadius=10, textureThreshold=12,
    closingIterations=3, openingIterations=3, minComponentPixels=1000, minFillRatio=0.10,
)

GRID = [
    {},                                   # c0: shipped defaults (baseline)
    {"textureThreshold": 8}, {"textureThreshold": 16}, {"textureThreshold": 20},
    {"closingIterations": 1}, {"closingIterations": 2}, {"closingIterations": 5},
    {"openingIterations": 0}, {"openingIterations": 2}, {"openingIterations": 4},
    {"minComponentPixels": 500}, {"minComponentPixels": 2500},
    {"minFillRatio": 0.05}, {"minFillRatio": 0.20},
    {"skinRBGap": 0.12}, {"skinRBGap": 0.24},
]

def label(c):
    if not c:
        return "baseline"
    k, v = next(iter(c.items()))
    return f"{k}={v}"

def iou(a: np.ndarray, b: np.ndarray) -> float:
    inter = (a & b).sum()
    union = (a | b).sum()
    return float(inter) / max(1, union)

def run_image(img: Path):
    d = IMG / img.stem
    d.mkdir(parents=True, exist_ok=True)
    grid_path = d / "grid.json"
    grid_path.write_text(json.dumps(GRID))
    r = subprocess.run(
        [str(BINARY), "--handremover-sweep", str(img),
         "--sweep-params", str(grid_path), "--sweep-outdir", str(d)],
        capture_output=True, timeout=600)
    rows = {}
    for line in r.stdout.decode(errors="replace").splitlines():
        line = line.strip()
        if line.startswith("{"):
            try:
                j = json.loads(line)
                rows[j["i"]] = j
            except Exception:
                pass
    # baseline mask
    m0 = np.asarray(Image.open(d / f"{img.stem}_c0_mask.png").convert("L")) > 127
    sam_path = SAM / img.stem / "sam_auto_mask.png"
    sam = None
    if sam_path.exists():
        sm = np.asarray(Image.open(sam_path).convert("L"))
        if sm.shape != m0.shape:
            sm = np.asarray(Image.fromarray(sm).resize((m0.shape[1], m0.shape[0]), Image.NEAREST))
        sam = sm > 127
    out = {}
    for i in range(len(GRID)):
        j = rows.get(i)
        if not j or not j.get("ok"):
            out[i] = dict(ok=False, opaque=None, iou_b=None, iou_s=None, ms=j.get("ms") if j else None)
            continue
        cut = Image.open(d / f"{img.stem}_c{i}.png").convert("RGBA")
        alpha = np.asarray(cut.getchannel("A"))
        opaque = float((alpha > 16).mean())
        mi = np.asarray(Image.open(d / f"{img.stem}_c{i}_mask.png").convert("L")) > 127
        if mi.shape != m0.shape:
            mi = np.asarray(Image.fromarray(mi.astype("uint8") * 255).resize(
                (m0.shape[1], m0.shape[0]), Image.NEAREST)) > 127
        out[i] = dict(ok=True, opaque=round(opaque, 4),
                      iou_b=round(iou(mi, m0), 4),
                      iou_s=round(iou(mi, sam), 4) if sam is not None else None,
                      ms=j.get("ms"))
    return img.stem, out

def main():
    # .jpg only: testset/ also contains leftover *_handremoved_mask.png artifacts
    imgs = sorted(p for p in TESTSET.iterdir() if p.suffix.lower() == ".jpg")
    results = {}
    with cf.ThreadPoolExecutor(max_workers=WORKERS) as ex:
        futs = {ex.submit(run_image, p): p for p in imgs}
        for n, f in enumerate(cf.as_completed(futs), 1):
            stem, out = f.result()
            results[stem] = out
            print(f"[{n}/{len(imgs)}] {stem} done", flush=True)

    # aggregate
    agg = []
    for i, c in enumerate(GRID):
        vals = [results[s][i] for s in results if i in results[s]]
        ok = [v for v in vals if v["ok"]]
        opaque = [v["opaque"] for v in ok]
        iou_b = [v["iou_b"] for v in ok if v["iou_b"] is not None]
        iou_s = [v["iou_s"] for v in ok if v["iou_s"] is not None]
        ms = [v["ms"] for v in ok if v["ms"]]
        agg.append(dict(
            i=i, config=label(c),
            n_ok=len(ok), n_total=len(vals),
            lost=sum(1 for o in opaque if o < 0.01),
            mean_opaque=round(float(np.mean(opaque)), 4) if opaque else None,
            mean_iou_b=round(float(np.mean(iou_b)), 4) if iou_b else None,
            mean_iou_s=round(float(np.mean(iou_s)), 4) if iou_s else None,
            min_iou_s=round(float(np.min(iou_s)), 4) if iou_s else None,
            mean_ms=int(np.mean(ms)) if ms else None,
            regressions=sum(1 for x in iou_b if x < 0.8),
        ))
    agg.sort(key=lambda r: (-(r["mean_iou_s"] or 0), r["lost"], r["regressions"]))
    with open(OUT / "SWEEP_GRID.json", "w") as f:
        json.dump(GRID, f, indent=1)
    with open(OUT / "SWEEP_REPORT.tsv", "w") as f:
        cols = ["i", "config", "n_ok", "n_total", "lost", "mean_opaque",
                "mean_iou_b", "mean_iou_s", "min_iou_s", "mean_ms", "regressions"]
        f.write("\t".join(cols) + "\n")
        for r in sorted(agg, key=lambda x: x["i"]):
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    with open(OUT / "SWEEP_RESULTS.json", "w") as f:
        json.dump({s: results[s] for s in sorted(results)}, f)

    base = next(r for r in agg if r["config"] == "baseline")
    best = next(r for r in agg if r["config"] != "baseline")
    better = (best["mean_iou_s"] or 0) >= (base["mean_iou_s"] or 0) + 0.02
    safe = best["lost"] <= base["lost"] and best["regressions"] <= 3
    rec = (f"UPDATE DEFAULTS to {label(GRID[best['i']])}" if (better and safe)
           else f"KEEP SHIPPED DEFAULTS (best alternative {label(GRID[best['i']])} "
                f"does not clearly beat baseline: iou_s {base['mean_iou_s']} -> {best['mean_iou_s']})")

    lines = [
        "# HandRemover parameter sweep (50-photo set)",
        "",
        f"Configs: {len(GRID)} (one-at-a-time around shipped defaults) x {len(imgs)} images, "
        f"{WORKERS} workers. c0 = shipped defaults (baseline).",
        f"Vision region prior is computed once per image (shared across configs), so this "
        f"isolates the pixel-classification + cleanup pass.",
        "",
        f"## Ranking (by mean IoU vs SAM reference)",
        "",
        "| # | config | lost | mean IoU vs baseline | mean IoU vs SAM | min IoU vs SAM | mean ms | regressions(<0.8) |",
        "|---|--------|------|----------------------|-----------------|----------------|---------|-------------------|",
    ]
    for n, r in enumerate(agg, 1):
        lines.append(f"| {n} | {r['config']} | {r['lost']} | {r['mean_iou_b']} | {r['mean_iou_s']} "
                     f"| {r['min_iou_s']} | {r['mean_ms']} | {r['regressions']} |")
    lines += [
        "",
        "## Recommendation",
        "",
        f"**{rec}**",
        "",
        f"Baseline: lost={base['lost']}, mean IoU vs SAM={base['mean_iou_s']}, "
        f"regressions={base['regressions']}",
        f"Best alt: {label(GRID[best['i']])}: lost={best['lost']}, mean IoU vs SAM={best['mean_iou_s']}, "
        f"regressions={best['regressions']}, mean ms={best['mean_ms']}",
        "",
    ]
    (OUT / "SWEEP_SUMMARY.md").write_text("\n".join(lines))

    # COMPARE.jpg: original | baseline | best for ~10 images (2-3 per category)
    per_cat, picks = {}, []
    for s in sorted(results):
        cat = s.split("_")[0]
        if len(per_cat.get(cat, [])) < 3:
            per_cat.setdefault(cat, []).append(s)
            picks.append(s)
    picks = picks[:10]
    pw = 420
    strips = []
    for s in picks:
        orig = Image.open(TESTSET / f"{s}.jpg").convert("RGB")
        b = Image.open(IMG / s / f"{s}_c0.png").convert("RGBA")
        b2 = Image.open(IMG / s / f"{s}_c{best['i']}.png").convert("RGBA")
        cells = []
        for im, tag in [(orig, "original"), (b, "baseline"), (b2, f"best:{label(GRID[best['i']])}")]:
            c2 = im.copy()
            c2.thumbnail((pw - 12, 380), Image.LANCZOS)
            bg = Image.new("RGBA", (pw, 400), (225, 225, 225, 255))
            bg.alpha_composite(c2.resize(c2.size)) if im.mode == "RGBA" else bg.paste(c2, (0, 0))
            d = ImageDraw.Draw(bg)
            d.text((8, 8), f"{s} — {tag}", fill=(0, 0, 0))
            cells.append(bg.convert("RGB"))
        strips.append(_hstack(cells))
    W = max(s.width for s in strips)
    H = sum(s.height for s in strips) + 8 * (len(strips) - 1)
    canvas = Image.new("RGB", (W, H), (245, 245, 245))
    y = 0
    for s in strips:
        canvas.paste(s, (0, y))
        y += s.height + 8
    canvas.save(OUT / "COMPARE.jpg", quality=85)
    print(f"summary -> {OUT/'SWEEP_SUMMARY.md'}")
    print(f"RECOMMENDATION: {rec}")

def _hstack(cells):
    W = sum(c.width for c in cells)
    H = max(c.height for c in cells)
    out = Image.new("RGB", (W, H), (250, 250, 250))
    x = 0
    for c in cells:
        out.paste(c, (x, 0))
        x += c.width
    return out

if __name__ == "__main__":
    main()
