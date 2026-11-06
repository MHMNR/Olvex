#!/usr/bin/env python3
"""
Olvex Online Wallpaper Market API (Wallhaven Backend)
Connects to Wallhaven.cc v1 REST API to browse, search, filter, preview,
and 1-click download/apply high-resolution wallpapers.
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.parse
import shutil
import time

USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) OlvexShell/1.0"
API_BASE = "https://wallhaven.cc/api/v1"
THUMB_CACHE_DIR = os.path.expanduser("~/.cache/olvex/wallpaper_thumbs")
WALLPAPER_DIR = os.path.expanduser("~/Pictures/Wallpapers")

os.makedirs(THUMB_CACHE_DIR, exist_ok=True)
os.makedirs(WALLPAPER_DIR, exist_ok=True)

def get_cached_thumb(wid):
    if not wid:
        return ""
    for ext in [".jpg", ".png", ".webp", ".jpeg"]:
        p = os.path.join(THUMB_CACHE_DIR, f"{wid}{ext}")
        if os.path.exists(p) and os.path.getsize(p) > 200:
            return p
    return ""

def download_thumb_worker(wid, thumb_url):
    if not wid or not thumb_url or thumb_url.startswith("/"):
        return ""
    dest = os.path.join(THUMB_CACHE_DIR, f"{wid}.jpg")
    if os.path.exists(dest) and os.path.getsize(dest) > 200:
        return dest
    try:
        req = urllib.request.Request(thumb_url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=8) as r:
            data = r.read()
            if len(data) > 200:
                tmp = dest + ".tmp"
                with open(tmp, "wb") as f:
                    f.write(data)
                os.replace(tmp, dest)
                return dest
    except Exception:
        pass
    return ""

def get_installed_wallpaper_files():
    installed = {}
    if not os.path.isdir(WALLPAPER_DIR):
        return installed
    try:
        for entry in os.listdir(WALLPAPER_DIR):
            full_path = os.path.join(WALLPAPER_DIR, entry)
            if os.path.isfile(full_path):
                name_lower = entry.lower()
                installed[name_lower] = full_path
                # Check for wallhaven id pattern like wallhaven-yqkl97.jpg or yqkl97.jpg
                if "wallhaven-" in name_lower:
                    wid = name_lower.split("wallhaven-")[-1].split(".")[0].split("_")[0]
                    installed[wid] = full_path
                else:
                    wid = name_lower.split(".")[0].split("_")[0]
                    installed[wid] = full_path
    except Exception:
        pass
    return installed

def cmd_list(args):
    # Parameters
    # categories: 3-digit binary [General][Anime][People] e.g. 111, 100, 010, 001
    categories = args.categories or "111"
    # purity: 100 for SFW
    purity = args.purity or "100"
    # sorting: toplist, views, favorites, date_added, random, relevance
    sorting = args.sort or "toplist"
    # order: desc, asc
    order = args.order or "desc"
    # topRange: 1d, 3d, 1w, 1M, 3M, 6M, 1y (only if sorting == toplist)
    top_range = args.top_range or "1M"
    # ratios: e.g. 16x9,16x10,21x9
    ratios = args.ratios or ""
    # atleast: e.g. 1920x1080
    atleast = args.atleast or ""
    page = args.page or 1
    query = (args.search or "").strip()

    params = {
        "categories": categories,
        "purity": purity,
        "sorting": sorting,
        "order": order,
        "page": str(page)
    }
    if sorting == "toplist":
        params["topRange"] = top_range
    if query:
        params["q"] = query
    if ratios:
        params["ratios"] = ratios
    if atleast:
        params["atleast"] = atleast

    url = f"{API_BASE}/search?" + urllib.parse.urlencode(params)
    
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = json.loads(resp.read().decode())
    except Exception as e:
        print(json.dumps({"error": str(e), "items": [], "meta": {}}))
        return

    wallpapers = data.get("data", [])
    meta = data.get("meta", {})
    installed_map = get_installed_wallpaper_files()

    items = []
    for w in wallpapers:
        wid = w.get("id", "")
        if not wid:
            continue
        
        thumbs = w.get("thumbs", {})
        thumb_small = thumbs.get("small", "")
        thumb_large = thumbs.get("large", thumbs.get("original", thumb_small))
        full_path = w.get("path", "")
        res = w.get("resolution", "")
        ratio = w.get("ratio", "")
        category = w.get("category", "")
        file_size = w.get("file_size", 0)
        views = w.get("views", 0)
        favs = w.get("favorites", 0)
        colors = w.get("colors", [])

        # Check local cache or prefetch small thumb
        cached = get_cached_thumb(wid)
        local_thumb = cached if cached else ""

        # Check if already downloaded/installed
        is_installed = False
        installed_local_path = ""
        filename_pattern = f"wallhaven-{wid}"
        for k, p in installed_map.items():
            if wid.lower() in k or filename_pattern.lower() in k:
                is_installed = True
                installed_local_path = p
                break

        items.append({
            "id": wid,
            "name": f"Wallhaven {wid}",
            "resolution": res,
            "ratio": ratio,
            "category": category.capitalize() if category else "General",
            "purity": (w.get("purity", "") or "").upper(),
            "fileSize": file_size,
            "views": views,
            "favorites": favs,
            "colors": colors,
            "thumbUrl": thumb_large or thumb_small,
            "thumbSmallUrl": thumb_small,
            "localThumb": local_thumb,
            "fullUrl": full_path,
            "isInstalled": is_installed,
            "localPath": installed_local_path
        })

    # Start background caching of thumbs if not yet cached
    for item in items[:12]:
        if not item["localThumb"] and item["thumbSmallUrl"]:
            download_thumb_worker(item["id"], item["thumbSmallUrl"])

    print(json.dumps({
        "items": items,
        "meta": meta
    }))

def cmd_download(args):
    wid = args.id
    full_url = args.url
    if not wid or not full_url:
        print(json.dumps({"error": "Missing wallpaper ID or URL", "success": False}))
        return

    ext = ".jpg"
    if ".png" in full_url.lower():
        ext = ".png"
    elif ".webp" in full_url.lower():
        ext = ".webp"

    dest_filename = f"wallhaven-{wid}{ext}"
    dest_path = os.path.join(WALLPAPER_DIR, dest_filename)

    if os.path.exists(dest_path) and os.path.getsize(dest_path) > 1000:
        print(f"PROGRESS: 100", flush=True)
        print(json.dumps({
            "success": True,
            "id": wid,
            "path": dest_path,
            "filename": dest_filename,
            "alreadyExists": True
        }), flush=True)
        return

    try:
        req = urllib.request.Request(full_url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=25) as resp:
            total_size = int(resp.headers.get("content-length", 0))
            downloaded = 0
            block_size = 65536
            tmp_path = dest_path + ".tmp"
            
            with open(tmp_path, "wb") as f:
                while True:
                    chunk = resp.read(block_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_size > 0:
                        percent = int((downloaded / total_size) * 100)
                        print(f"PROGRESS: {min(99, percent)}", flush=True)
                    else:
                        print("PROGRESS: 50", flush=True)

            os.replace(tmp_path, dest_path)
            print("PROGRESS: 100", flush=True)
            print(json.dumps({
                "success": True,
                "id": wid,
                "path": dest_path,
                "filename": dest_filename
            }), flush=True)

    except Exception as e:
        print(json.dumps({"error": str(e), "success": False}), flush=True)

def cmd_info(args):
    wid = args.id
    try:
        req = urllib.request.Request(f"{API_BASE}/w/{wid}", headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=10) as resp:
            w = json.loads(resp.read().decode()).get("data", {})
        print(json.dumps({
            "id": wid,
            "tags": [t.get("name", "") for t in w.get("tags", [])][:12],
            "uploader": (w.get("uploader") or {}).get("username", ""),
            "source": w.get("source", ""),
            "createdAt": w.get("created_at", ""),
            "views": w.get("views", 0),
            "favorites": w.get("favorites", 0),
            "purity": w.get("purity", ""),
            "url": w.get("url", "")
        }))
    except Exception as e:
        print(json.dumps({"id": wid, "error": str(e), "tags": []}))

def cmd_thumb(args):
    wid = args.id
    url = args.url
    if not wid or not url:
        print("")
        return
    cached = get_cached_thumb(wid)
    if cached:
        print(cached)
        return
    res = download_thumb_worker(wid, url)
    print(res)

def main():
    parser = argparse.ArgumentParser(description="Olvex Wallpaper Market Wallhaven Backend")
    sub = parser.add_subparsers(dest="command")

    # list
    p_list = sub.add_parser("list")
    p_list.add_argument("--categories", default="111")
    p_list.add_argument("--purity", default="100")
    p_list.add_argument("--sort", default="toplist")
    p_list.add_argument("--order", default="desc")
    p_list.add_argument("--top_range", default="1M")
    p_list.add_argument("--ratios", default="")
    p_list.add_argument("--atleast", default="")
    p_list.add_argument("--page", type=int, default=1)
    p_list.add_argument("--search", default="")

    # download
    p_down = sub.add_parser("download")
    p_down.add_argument("id")
    p_down.add_argument("url")

    # thumb
    p_thumb = sub.add_parser("thumb")
    p_thumb.add_argument("id")
    p_thumb.add_argument("url")

    # info
    p_info = sub.add_parser("info")
    p_info.add_argument("id")

    args = parser.parse_args()
    if args.command == "info":
        cmd_info(args)
    elif args.command == "list":
        cmd_list(args)
    elif args.command == "download":
        cmd_download(args)
    elif args.command == "thumb":
        cmd_thumb(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()

