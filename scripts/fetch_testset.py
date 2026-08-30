#!/usr/bin/env python3
"""fetch_testset.py — pull 50 hand-held product photos from DuckDuckGo images,
normalize to JPEG, write MANIFEST.tsv, and sync to iCloud Drive."""
import json, re, subprocess, sys, time, urllib.parse
from pathlib import Path
from PIL import Image

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
OUT = Path("/tmp/buynothing-wt-tool-seg/testset")
ICLOUD = Path("/Users/jordan/Library/Mobile Documents/com~apple~CloudDocs/BN-Cutout-TestSet")
BAD_HOSTS = ("wikipedia", "wikimedia", "facebook", "instagram", "pinterest")

CATEGORIES = [
    ("tools", 13, [
        "hand holding wire stripper", "hand holding wrench", "hands holding hammer",
        "hand holding screwdriver", "hand holding pliers", "hand holding tape measure",
    ]),
    ("usbcable", 13, [
        "hand holding usb cable", "hand holding charging cable",
        "hands holding laptop charger", "hand holding hdmi cable",
    ]),
    ("books", 12, [
        "hand holding open book", "hand holding book", "person holding book in hand",
    ]),
    ("tech", 12, [
        "hand holding laptop", "hands holding tablet", "hand holding camera",
        "hand holding smartphone",
    ]),
]


def curl(url, out=None, timeout=30):
    cmd = ["curl", "-sL", "-m", str(timeout), "-A", UA, url]
    if out:
        cmd += ["-o", str(out)]
    return subprocess.run(cmd, capture_output=True)


def get_vqd(query):
    r = curl("https://duckduckgo.com/?" + urllib.parse.urlencode({"q": query, "iax": "images", "ia": "images"}), timeout=20)
    m = re.search(rb'vqd="([^"]+)"', r.stdout)
    return m.group(1).decode() if m else None


def candidates(query):
    t = get_vqd(query)
    if not t:
        return []
    url = "https://duckduckgo.com/i.js?" + urllib.parse.urlencode(
        {"l": "us-en", "o": "json", "q": query, "vqd": t, "p": 1})
    r = curl(url, timeout=25)
    try:
        data = json.loads(r.stdout)
    except Exception:
        return []
    out = []
    for item in data.get("results", []):
        w = item.get("width") or 0
        h = item.get("height") or 0
        if max(w, h) < 800:
            continue
        blob = (item.get("image", "") + " " + item.get("url", "")).lower()
        if any(b in blob for b in BAD_HOSTS):
            continue
        out.append(item)
    return out


def download(item, path):
    if curl(item["image"], out=path, timeout=40).returncode != 0:
        return None
    if not path.exists() or path.stat().st_size < 20000:
        return None
    try:
        im = Image.open(path)
        im.verify()
    except Exception:
        return None
    im2 = Image.open(path)
    if im2.format != "JPEG" or im2.mode not in ("RGB", "L"):
        Image.open(path).convert("RGB").save(path, "JPEG", quality=90)
    im3 = Image.open(path)
    return (im3.size[0], im3.size[1])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = []
    for cat, target, queries in CATEGORIES:
        have = 0
        seen = set()
        for q in queries:
            if have >= target:
                break
            print(f"[{cat}] query: {q}", flush=True)
            try:
                cands = candidates(q)
            except Exception as e:
                print(f"  candidate fetch error: {e}", flush=True)
                cands = []
            print(f"  candidates: {len(cands)}", flush=True)
            for item in cands:
                if have >= target:
                    break
                url = item.get("image")
                if not url or url in seen:
                    continue
                seen.add(url)
                fn = f"{cat}_{have + 1:02d}.jpg"
                size = download(item, OUT / fn)
                if size:
                    have += 1
                    manifest.append([fn, cat, q, url, size[0], size[1]])
                    print(f"  ok {fn} {size[0]}x{size[1]}", flush=True)
                time.sleep(0.4)
            print(f"[{cat}] have {have}/{target}", flush=True)
            time.sleep(1.5)

    with open(OUT / "MANIFEST.tsv", "w") as f:
        f.write("file\tcategory\tquery\tsource_url\twidth\theight\n")
        for row in manifest:
            f.write("\t".join(str(x) for x in row) + "\n")

    # iCloud sync
    ICLOUD.mkdir(parents=True, exist_ok=True)
    subprocess.run(["cp", "-R", str(OUT), str(ICLOUD)], check=False)
    n = len(list(OUT.glob("*.jpg")))
    print(f"DONE: {n} images in {OUT}; manifest={len(manifest)} rows; icloud={ICLOUD}")


if __name__ == "__main__":
    main()
