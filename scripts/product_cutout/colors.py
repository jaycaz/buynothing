"""Color-space and texture utilities (all in [0,1] RGB, numpy)."""
import numpy as np
from scipy import ndimage as ndi


def rgb_stats(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    return r, g, b, sat, mx


def broad_skin(rgb):
    """Warm-chroma skin test, tone-agnostic. Deliberately broad: it also
    flags warm-gray metal and red accents — those are resolved by the
    texture/connectivity stage, not by color alone."""
    r, g, b, sat, val = rgb_stats(rgb)
    warm = (r > g) & (g > b) & ((r - g) > 0.03) & ((g - b) > 0.015)
    return warm & (sat < 0.80) & (val > 0.12) & (val < 0.98)


def strong_product_color(rgb, sat_min=0.35):
    """Saturated non-skin color: the reliable 'this is product' anchor
    (blue handles, red ferrules, colored plastic...)."""
    r, g, b, sat, val = rgb_stats(rgb)
    blue = (b > r * 1.2) & (b > g * 1.1)
    red = (r > g * 1.6) & (r > b * 1.4) & (r - g > 0.25)
    green = (g > r * 1.2) & (g > b * 1.1)
    return (blue | red | green) & (sat > sat_min) & (val > 0.25)


def texture_map(rgb, window=21, scale=255.0):
    """Local edge energy (Sobel magnitude, area-averaged over `window`).
    Products carry text/seams/serrations (high); bare palm is smooth (low).
    Computed on 0-255 luminance so thresholds are image-scale stable."""
    L = rgb.mean(-1) * scale
    mag = np.hypot(ndi.sobel(L, axis=1), ndi.sobel(L, axis=0))
    return ndi.uniform_filter(mag, size=window)
