"""Main pipeline + CLI.

Usage:
  python -m product_cutout IMAGE --out OUT.png [--no-sam] [--debug DIR]
"""
import argparse
import os
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

from .colors import broad_skin
from .resolve import resolve, cleanup


def product_region(rgb_uint8, model="u2net"):
    from rembg import new_session, remove
    session = new_session(model)
    m = np.asarray(remove(rgb_uint8, session=session, only_mask=True))
    m = m[..., 0] if m.ndim == 3 else m
    return m > 127


def sam_refine(rgb, mask, ckpt):
    """Optional: let SAM re-snap the boundary of our composite mask."""
    import segment_anything as sam
    model = sam.build_sam_vit_b(checkpoint=ckpt)
    pred = sam.SamPredictor(model)
    pred.set_image(rgb)
    masks, scores, _ = pred.predict(mask_input=mask.astype("uint8"), multimask_output=False)
    return masks[0]


def run(image_path, out_path, use_sam=True, sam_ckpt=None, debug=None, max_dim=1500):
    im0 = Image.open(image_path).convert("RGB")
    scale = min(1.0, max_dim / max(im0.size))
    im = im0.resize((int(im0.size[0]*scale), int(im0.size[1]*scale)), Image.LANCZOS) if scale < 1 else im0
    rgb = np.asarray(im, dtype=np.float64) / 255.0
    H, W, _ = rgb.shape

    region = product_region(np.asarray(im))
    if debug:
        os.makedirs(debug, exist_ok=True)
        Image.fromarray((region*255).astype("uint8")).save(f"{debug}/1_region.png")
        Image.fromarray((broad_skin(rgb)*255).astype("uint8")).save(f"{debug}/2_skin.png")

    final, stats = resolve(region, rgb)
    if debug:
        Image.fromarray((final*255).astype("uint8")).save(f"{debug}/3_resolved.png")
    final = cleanup(final)

    if use_sam and sam_ckpt:
        try:
            refined = sam_refine(rgb, final, sam_ckpt)
            if refined.sum() > 0.25 * final.sum():  # sanity: don't accept a collapse
                final = cleanup(refined & (ndi.binary_dilation(final, iterations=6) | final))
        except Exception as e:
            print(f"sam refine skipped: {e}")

    alpha = ndi.gaussian_filter((final*255).astype(float), 1.0)
    out = np.dstack([np.asarray(im), np.clip(alpha, 0, 255).astype(np.uint8)])
    Image.fromarray(out).save(out_path)
    if debug:
        vis = np.asarray(im).copy().astype(float)
        vis[~final] *= 0.25
        Image.fromarray(vis.astype("uint8")).save(f"{debug}/4_final_check.png")
    print({k: round(v, 4) for k, v in stats.items()})
    print(f"final={final.mean():.3f}")
    return out_path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--out", default="out/cutout.png")
    ap.add_argument("--no-sam", action="store_true")
    ap.add_argument("--sam-ckpt", default="/tmp/sam_vit_b_01ec64.pth")
    ap.add_argument("--debug", default=None)
    args = ap.parse_args()
    run(args.image, args.out, use_sam=not args.no_sam, sam_ckpt=args.sam_ckpt, debug=args.debug)


if __name__ == "__main__":
    main()
