"""Conflict resolution via color clustering.

Within the product region (tool + hand blob):
  1. k-means over RGB on region pixels (~k=10)
  2. A cluster is PRODUCT if it holds saturated product color
     (blue/red handles, ferrules) OR has high texture (head text/seams)
  3. Conflict (skin-colored) pixels in product clusters are kept;
     conflict pixels in smooth skin clusters (palm, fingers) are dropped.

Generalizes: no per-image points, no hand detector. Assumptions:
  - product has saturated color or surface texture (text, seams, serrations)
  - the holding hand is bare skin (a skin-colored GLOVE would leak in)
"""
import numpy as np
from scipy import ndimage as ndi
from .colors import broad_skin, texture_map, strong_product_color

NEIGHBOR = np.ones((3, 3), bool)
_RNG = np.random.RandomState(0)


def _kmeans(x, k, iters=12):
    n = x.shape[0]
    idx = _RNG.choice(n, min(k, n), replace=False)
    c = x[idx].copy()
    assign = np.zeros(n, np.int32)
    for _ in range(iters):
        d = ((x[:, None, :] - c[None, :, :]) ** 2).sum(-1)
        assign = d.argmin(1)
        for j in range(k):
            m = assign == j
            if m.any():
                c[j] = x[m].mean(0)
    d = ((x[:, None, :] - c[None, :, :]) ** 2).sum(-1)
    return d.argmin(1), c


def resolve(region, rgb, k=10, tex_threshold=12.0,
            definite_frac=0.05, bridge=2, min_comp=400):
    skin = ndi.binary_closing(broad_skin(rgb), iterations=2)
    conflict = ndi.binary_dilation(region & skin, iterations=bridge) & region
    definite = region & ~skin

    pix = rgb[region]
    assign, _ = _kmeans(pix, k)

    tex = texture_map(rgb)[region]
    sat_prod = strong_product_color(rgb)[region]

    is_product = np.zeros(k, bool)
    for j in range(k):
        m = assign == j
        if not m.any():
            continue
        frac_def = float((definite[region] & (assign == j)).sum() / m.sum())
        tex_mean = float(tex[m].mean())
        is_product[j] = (frac_def > definite_frac) or (tex_mean > tex_threshold)

    prod2 = np.zeros_like(region)
    prod2[region] = is_product[assign]
    final = prod2
    # drop small components (skin specks that landed in product clusters)
    lab, n = ndi.label(final, structure=NEIGHBOR)
    if n:
        sz = np.bincount(lab.ravel())[1:]
        final = final & np.isin(lab, np.where(sz > min_comp)[0] + 1)
    final = ndi.binary_closing(final, iterations=3)
    final = ndi.binary_fill_holes(final)

    stats = {
        "region": round(float(region.mean()), 4),
        "conflict": round(float(conflict.mean()), 4),
        "dropped_conflict": round(float((conflict & ~final).mean()), 4),
        "kept_conflict": round(float((conflict & final).mean()), 4),
        "final": round(float(final.mean()), 4),
        "product_clusters": int(is_product.sum()),
    }
    return final, stats


def cleanup(final, min_comp=400):
    lab, n = ndi.label(final, structure=NEIGHBOR)
    if not n:
        return final
    sz = np.bincount(lab.ravel())[1:]
    final = np.isin(lab, np.where(sz > min_comp)[0] + 1)
    final = ndi.binary_closing(final, iterations=3)
    final = ndi.binary_fill_holes(final)
    return final
