#!/usr/bin/env python3
"""
Olvex Online Icon Pack Market API
Connects to KDE Store / OpenDesktop OCS API to browse, search, and 1-click install icon packs.
"""

import os
import sys
import json
import shutil
import re
import html
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET
import subprocess
import tempfile

def clean_description(raw_text):
    if not raw_text:
        return ""
    text = html.unescape(raw_text)
    text = re.sub(r'<br\s*/?>', '\n', text, flags=re.I)
    text = re.sub(r'</p>', '\n\n', text, flags=re.I)
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'\n{3,}', '\n\n', text)
    return text.strip()

OCS_BASE_URL = "https://api.kde-look.org/ocs/v1/content/data"
DEFAULT_CATEGORY = "132"  # Full Icon Themes
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) OlvexShell/1.0"

THUMB_CACHE_DIR = os.path.expanduser("~/.cache/olvex/market_thumbs")
os.makedirs(THUMB_CACHE_DIR, exist_ok=True)

def get_cached_thumb(cid, idx=0):
    if not cid:
        return ""
    suffix = f"_{idx}" if idx > 0 else ""
    for ext in [".png", ".jpg", ".jpeg", ".webp"]:
        p = os.path.join(THUMB_CACHE_DIR, f"{cid}{suffix}{ext}")
        if os.path.exists(p) and os.path.getsize(p) > 200:
            return p
    return ""

def get_target_thumb_path(cid, url, idx=0):
    if not cid or not url:
        return ""
    suffix = f"_{idx}" if idx > 0 else ""
    ext = ".png"
    if ".jpg" in url.lower() or ".jpeg" in url.lower():
        ext = ".jpg"
    return os.path.join(THUMB_CACHE_DIR, f"{cid}{suffix}{ext}")

def download_thumb_worker(cid, url, idx=0):
    if not url or not cid or url.startswith("/"):
        return
    suffix = f"_{idx}" if idx > 0 else ""
    ext = ".png"
    if ".jpg" in url.lower() or ".jpeg" in url.lower():
        ext = ".jpg"
    dest = os.path.join(THUMB_CACHE_DIR, f"{cid}{suffix}{ext}")
    if os.path.exists(dest) and os.path.getsize(dest) > 200:
        return
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=6) as r:
            data = r.read()
            if len(data) > 200:
                tmp = dest + ".tmp"
                with open(tmp, "wb") as f:
                    f.write(data)
                os.replace(tmp, dest)
    except Exception:
        pass

def get_installed_theme_names():
    installed = set()
    dirs = [
        os.path.expanduser("~/.local/share/icons"),
        os.path.expanduser("~/.icons"),
        "/usr/local/share/icons",
        "/usr/share/icons"
    ]
    for d in dirs:
        if not os.path.isdir(d):
            continue
        try:
            for entry in os.listdir(d):
                p = os.path.join(d, entry)
                if os.path.isdir(p) and os.path.isfile(os.path.join(p, "index.theme")):
                    installed.add(entry.lower())
        except Exception:
            pass
    return installed

def get_featured_fallback(sort="downloads", search="", installed=None, order="desc"):
    if installed is None:
        installed = get_installed_theme_names()

    featured = [
        {
            "id": "2379193",
            "name": "Crystalline Icon Theme",
            "author": "Crystalline",
            "rating": 92,
            "downloads": 12540,
            "preview": "https://images.pling.com/cache/770x540-4/img/00/00/87/30/70/2379193/crystalline-thumbnail.png",
            "summary": "Modern, sleek icon theme for Linux desktop",
            "downloadUrl": "https://files06.pling.com/api/files/download/j/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZCI6MTc5MzAxMDkwMiwidSI6bnVsbCwicyI6IjdhMmJkYThjZTY0NTMzNTBjM2Y2M2RmMTA0MDA5OGE3ZWRhMzk3NWI1OTliNjM4MjkxNWU4NTNhMzg1NWE2M2M3N2QwNWY4MzMyYTUxN2JmNjA1ZWZjNjk0NDFkMzYxMjA0YWEyOTRlZmQ5YzQyODgxMzFhOTEwNzI0NzRiYjY5IiwidCI6MTc5MzIwMzQyMCwibyI6MSwibHQiOiJkb3dubG9hZCIsImp0aSI6ImI5MDVkNGYwMjg3OWRjOTA4NjhlYjUzODQ2ZGE2NThlIiwiaWF0IjoxNzkzMTk5ODIwLCJleHAiOjE3OTMzNzI2MjAsInN0aXAiOiIxMC4xMzUuMjQ2LjE5In0.ButiGVt3ZjzwOsl3gKw9QpxZt0ikNiA9nIxMKdOelEg/Crystalline-20261026.tar.gz",
            "downloadName": "Crystalline-20261026.tar.gz"
        },
        {
            "id": "2378240",
            "name": "Nordic Slot Dark Icons",
            "author": "EliverLara",
            "rating": 90,
            "downloads": 9850,
            "preview": "https://images.pling.com/cache/770x540-4/img/00/00/49/90/47/2378240/logo-0-1.png",
            "summary": "Dark nordic-inspired theme for clean desktop aesthetics",
            "downloadUrl": "https://files06.pling.com/api/files/download/j/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZCI6MTc5MzA1MTMyMSwidSI6bnVsbCwicyI6ImNjMDNlOTk2YTc3MDM5NjA2NzdhYTE4Y2Q2NTU0MzI5OWVhMGViMzc2NDA2ZGQ5ZmEyYjNhMjY0Y2U2NzY2MzU5OGM0YjRlZmVjZTM5MjhmMzUwNjM3N2QxOWRkM2JmOTkwYTIyNjQ0ZDIyZGE5NTk3YzEzOWIzNTBkOGU1OWIzIiwidCI6MTc5MzIwMzQyMCwibyI6MSwibHQiOiJkb3dubG9hZCIsImp0aSI6IjVjZjZlYWI5MWUyMGE0MTVmYzY3MzE4ZTljZjI0MWQyIiwiaWF0IjoxNzkzMTk5ODIwLCJleHAiOjE3OTMzNzI2MjAsInN0aXAiOiIxMC4xMzUuMjQ2LjE5In0.XzOWc5iC0CjDvnsjLX_ouMulQoHLGH3KzIHbBdzZ4_E/Nordic-Slot-Dark-Icons.tar.xz",
            "downloadName": "Nordic-Slot-Dark-Icons.tar.xz"
        },
        {
            "id": "2379533",
            "name": "KDE Modern Classic",
            "author": "KDE Community",
            "rating": 88,
            "downloads": 7430,
            "preview": "https://images.pling.com/cache/770x540-4/img/00/00/87/30/70/2379533/kde-modern-classic-gallery-123.png",
            "summary": "Classic KDE styling refreshed with modern vibrant colors",
            "downloadUrl": "https://files06.pling.com/api/files/download/j/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZCI6MTc5MzA1OTkzNywidSI6bnVsbCwicyI6ImQwYzEzNTVhMWZjODUxYmM4NTg5ZjY1M2I1MmE1NDVmYjFiZDYwNGNjYWI2YmViNjA3NThlMWRkMGEzMGNmM2I0MTJiNDdjMGRkYTllOWM4NzkyYTA3MzA0NWRmNjU1MDc0NWVhMjkyNGQwNDczYWMyY2ZiODNjM2I3ZWEwNmJjIiwidCI6MTc5MzIwMzQyMCwibyI6MSwibHQiOiJkb3dubG9hZCIsImp0aSI6IjI1NTE3NjFjNTAxNTVjMjkzMTBkN2ZkZThhY2NiMGE2IiwiaWF0IjoxNzkzMTk5ODIwLCJleHAiOjE3OTMzNzI2MjAsInN0aXAiOiIxMC4xMzUuMjQ2LjE5In0.9qv-Y8H9kbUlxg_88hQhXlCYe1FPyXtO1tN4__25qzU/KDE-Modern-Classic-20261027.tar.gz",
            "downloadName": "KDE-Modern-Classic-20261027.tar.gz"
        },
        {
            "id": "2379187",
            "name": "Nuvola Icons",
            "author": "Nuvola",
            "rating": 85,
            "downloads": 5210,
            "preview": "https://images.pling.com/cache/770x540-4/img/00/00/87/30/70/2379187/nuvola-thumbnail.png",
            "summary": "Soft and rounded colorful icon collection",
            "downloadUrl": "https://files06.pling.com/api/files/download/j/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZCI6MTc5MzAxMTM4OCwidSI6bnVsbCwicyI6IjkxMjdiMjJkODQxZDRhYjk1YWU3NzQ0OTUyNTFjYjkxY2JiOGJmNjhiNzQzZGY3ZjJkMzBiMjAxOWU4OWExN2I5YWMzYTFhNmU1OTY1ZDU0Nzc5NjYzNTdlMTFmYWEwOTIwYzIzYjIxMTI0YzYzZjJlOGU5MjhmZmM2NmFhNTRiIiwidCI6MTc5MzIwMzQyMCwibyI6MSwibHQiOiJkb3dubG9hZCIsImp0aSI6IjhiOGQ3ZmYwODQxYzJhZDZmNDNjZmI2MjkyNWFkZGNjIiwiaWF0IjoxNzkzMTk5ODIwLCJleHAiOjE3OTMzNzI2MjAsInN0aXAiOiIxMC4xMzUuMjQ2LjE5In0.OH1pBuedOSHQSdy3FBKPIwlx8XfA-X6Ey-5QgxiPzh8/Nuvola-20261026.tar.gz",
            "downloadName": "Nuvola-20261026.tar.gz"
        },
        {
            "id": "2378748",
            "name": "Oxygen Accent Icons",
            "author": "Oxygen Team",
            "rating": 82,
            "downloads": 4320,
            "preview": "https://images.pling.com/cache/770x540-4/img/00/00/49/51/24/2378748/purple.png",
            "summary": "Crisp Oxygen icons with accent color highlights",
            "downloadUrl": "https://files06.pling.com/api/files/download/j/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpZCI6MTc5MjA0ODk5NiwidSI6bnVsbCwicyI6ImFmYjExN2IzYWI3MTZkNjM5ZDM1OTViNDViNzA2YzIxOTFmY2FiMWIxYWNlNTU2OTRiZmI1NDc0NTEzMTY4NTUxNWFiOTg5N2JmYTVkNTMzYmNhZGY5MTNlN2Q4ZTQ3ZmQ2NzlmNjFiMzNmMTllM2Q2MzM1OWYzNzEyNTQ0NTg5IiwidCI6MTc5MzIwMzQyMCwibyI6MSwibHQiOiJkb3dubG9hZCIsImp0aSI6ImJmOWNiNGQ4NDVkZDJjN2M5ZjMzOWM5MjRjMzEzNDA2IiwiaWF0IjoxNzkzMTk5ODIwLCJleHAiOjE3OTMzNzI2MjAsInN0aXAiOiIxMC4xMzUuMjQ2LjE5In0.vYMNLmP7iw8cAH2g9rMM50H9inDa1glSUUCVlBHf9o0/oxygen-accent-icons.tar.gz",
            "downloadName": "oxygen-accent-icons.tar.gz"
        }
    ]

    for item in featured:
        name_clean = item["name"].lower().replace(" ", "").replace("-", "").replace("_", "")
        item["isInstalled"] = any(inst.replace(" ", "").replace("-", "").replace("_", "") in name_clean or name_clean in inst.replace(" ", "").replace("-", "").replace("_", "") for inst in installed)
        item["description"] = clean_description(item.get("description") or item.get("summary") or "")
        cid = item["id"]
        cached = get_cached_thumb(cid)
        item["remotePreview"] = item["preview"].replace("cache/770x540-4/", "cache/350x250-0/")
        item["preview"] = cached if cached else get_target_thumb_path(cid, item["remotePreview"])
        item["previews"] = [item["preview"]]

    if search and search.strip():
        q = search.strip().lower()
        featured = [it for it in featured if q in it["name"].lower() or q in it["summary"].lower()]

    if order == "asc":
        featured.reverse()

    return {"error": None, "items": featured}

def fetch_market_icons(sort="downloads", page=0, pagesize=24, search="", order="desc"):
    installed = get_installed_theme_names()
    params = {
        "categories": DEFAULT_CATEGORY,
        "pagesize": str(pagesize),
        "page": str(page)
    }

    if sort == "rating":
        params["sortmode"] = "high"
    elif sort == "new":
        params["sortmode"] = "new"
    elif sort == "alpha":
        params["sortmode"] = "alpha"
    else:
        params["sortmode"] = "down"

    if search and search.strip():
        params["search"] = search.strip()

    query_str = urllib.parse.urlencode(params)
    url = f"{OCS_BASE_URL}?{query_str}"

    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    content = None
    for attempt in range(2):
        try:
            with urllib.request.urlopen(req, timeout=12) as resp:
                content = resp.read()
                if content:
                    break
        except Exception:
            pass

    if not content:
        return get_featured_fallback(sort, search, installed, order)

    items = []

    try:
        tree = ET.fromstring(content)
        for item_node in tree.findall(".//content"):
            cid = item_node.findtext("id", "")
            name = item_node.findtext("name", "")
            if not name:
                continue

            author = item_node.findtext("personid", "") or item_node.findtext("author", "")
            rating_raw = item_node.findtext("score", "0")
            dl_raw = item_node.findtext("downloads", "0")
            preview = (
                item_node.findtext("previewpic1", "") or
                item_node.findtext("smallpic", "") or
                item_node.findtext("preview1", "")
            )
            # Use 350x250-0 cache URL from pling for 70% smaller download & faster load
            if preview and "cache/770x540-4/" in preview:
                preview = preview.replace("cache/770x540-4/", "cache/350x250-0/")

            # Use local cached thumbnail if available, otherwise target cache path
            cached_thumb = get_cached_thumb(cid)
            local_thumb = cached_thumb if cached_thumb else get_target_thumb_path(cid, preview)

            # Collect all gallery previews (previewpic1..previewpic9, smallpreviewpic1..9)
            raw_previews = []
            for p_idx in range(1, 10):
                pic = item_node.findtext(f"previewpic{p_idx}", "")
                if not pic:
                    pic = item_node.findtext(f"smallpreviewpic{p_idx}", "")
                if pic and pic.startswith("http"):
                    if "cache/770x540-4/" in pic:
                        pic = pic.replace("cache/770x540-4/", "cache/350x250-0/")
                    if pic not in raw_previews:
                        raw_previews.append(pic)

            if not raw_previews and preview:
                raw_previews.append(preview)

            resolved_previews = []
            for idx, r_url in enumerate(raw_previews):
                c_thumb = get_cached_thumb(cid, idx)
                if c_thumb:
                    resolved_previews.append(c_thumb)
                else:
                    target_p = get_target_thumb_path(cid, r_url, idx)
                    resolved_previews.append(target_p if os.path.exists(target_p) else r_url)

            if not resolved_previews and local_thumb:
                resolved_previews = [local_thumb]

            raw_desc = item_node.findtext("description", "") or item_node.findtext("summary", "") or ""
            desc = clean_description(raw_desc)
            summary = item_node.findtext("summary", "") or (desc[:157] + "..." if len(desc) > 160 else desc)
            if summary and len(summary) > 160:
                summary = summary[:157] + "..."

            # Find best download link (prefer .tar.xz, .tar.gz, .zip)
            dl_url = ""
            dl_name = ""
            for i in range(1, 10):
                link = item_node.findtext(f"downloadlink{i}", "")
                fname = item_node.findtext(f"downloadname{i}", "")
                if link:
                    dl_url = link
                    dl_name = fname or f"{name}.tar.gz"
                    # Prefer archive formats
                    lower_name = dl_name.lower()
                    if any(lower_name.endswith(ext) for ext in [".tar.xz", ".tar.gz", ".zip", ".tar.bz2"]):
                        break

            # Check if name loosely matches an installed theme
            name_clean = name.lower().replace(" ", "").replace("-", "").replace("_", "")
            is_installed = False
            installed_id = ""
            for inst in installed:
                inst_clean = inst.replace(" ", "").replace("-", "").replace("_", "")
                if inst_clean in name_clean or name_clean in inst_clean:
                    is_installed = True
                    installed_id = inst
                    break

            try:
                downloads = int(dl_raw)
            except Exception:
                downloads = 0

            try:
                rating = int(rating_raw)
            except Exception:
                rating = 0

            items.append({
                "id": cid,
                "name": name,
                "author": author,
                "rating": rating,
                "downloads": downloads,
                "preview": local_thumb,
                "previews": resolved_previews,
                "rawPreviews": raw_previews,
                "remotePreview": preview,
                "summary": summary,
                "description": desc or summary,
                "downloadUrl": dl_url,
                "downloadName": dl_name,
                "isInstalled": is_installed,
                "installedThemeId": installed_id
            })

    except Exception as e:
        return {"error": f"Failed to parse XML: {e}", "items": []}

    # Asynchronously pre-cache uncached previews in background
    uncached = []
    for it in items:
        raw_list = it.get("rawPreviews", [])
        for idx, r_url in enumerate(raw_list):
            if r_url and r_url.startswith("http"):
                c_p = get_cached_thumb(it["id"], idx)
                if not c_p:
                    uncached.append((it["id"], r_url, idx))
    if uncached:
        try:
            subprocess.Popen(
                [sys.executable, __file__, "cache-batch", json.dumps(uncached)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                close_fds=True,
                start_new_session=True
            )
        except Exception:
            pass

    if order == "asc":
        items.reverse()

    return {"error": None, "items": items}

def extract_theme_name_from_index(index_path, fallback=""):
    try:
        with open(index_path, "r", encoding="utf-8", errors="ignore") as f:
            in_section = False
            for line in f:
                line = line.strip()
                if line == "[Icon Theme]":
                    in_section = True
                    continue
                elif line.startswith("[") and in_section:
                    break
                if in_section and line.startswith("Name="):
                    name_val = line.split("=", 1)[1].strip()
                    cleaned = "".join(c for c in name_val if c.isalnum() or c in ("-", "_", ".", " ")).strip()
                    if cleaned:
                        return cleaned
    except Exception:
        pass
    if fallback:
        clean_fallback = fallback
        for ext in (".tar.xz", ".tar.gz", ".tar.bz2", ".tar.zst", ".tar", ".zip", ".7z"):
            if clean_fallback.lower().endswith(ext):
                clean_fallback = clean_fallback[:-len(ext)]
                break
        return clean_fallback.strip()
    return "Custom-Theme"

def install_archive(download_url, download_name=""):
    if not download_url:
        return {"success": False, "error": "No download URL provided"}

    print("PROGRESS:5", flush=True)
    target_dir = os.path.expanduser("~/.local/share/icons")
    os.makedirs(target_dir, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="olvex_icon_pkg_") as tmpdir:
        archive_path = os.path.join(tmpdir, download_name or "theme_pkg.archive")
        
        # 1. Download
        try:
            req = urllib.request.Request(download_url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=90) as resp, open(archive_path, "wb") as f:
                content_len = resp.headers.get("Content-Length")
                total_bytes = int(content_len) if content_len and content_len.isdigit() else 0
                downloaded = 0
                chunk_size = 131072
                last_pct = 5
                while True:
                    chunk = resp.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    if total_bytes > 0:
                        pct = 5 + int((downloaded / total_bytes) * 70)
                        pct = min(75, max(5, pct))
                        if pct > last_pct:
                            print(f"PROGRESS:{pct}", flush=True)
                            last_pct = pct
                    else:
                        last_pct = min(70, last_pct + 5)
                        print(f"PROGRESS:{last_pct}", flush=True)
        except Exception as e:
            return {"success": False, "error": f"Download failed: {e}"}

        # 2. Extract
        print("PROGRESS:80", flush=True)
        extract_dir = os.path.join(tmpdir, "extracted")
        os.makedirs(extract_dir, exist_ok=True)

        extracted = False
        # Try bsdtar first (handles tar.xz, tar.gz, zip, 7z)
        if shutil.which("bsdtar"):
            res = subprocess.run(["bsdtar", "-xf", archive_path, "-C", extract_dir], capture_output=True)
            if res.returncode == 0:
                extracted = True

        if not extracted and shutil.which("tar"):
            res = subprocess.run(["tar", "-xf", archive_path, "-C", extract_dir], capture_output=True)
            if res.returncode == 0:
                extracted = True

        if not extracted and shutil.which("unzip"):
            res = subprocess.run(["unzip", "-q", "-o", archive_path, "-d", extract_dir], capture_output=True)
            if res.returncode == 0:
                extracted = True

        if not extracted and shutil.which("7z"):
            res = subprocess.run(["7z", "x", "-y", f"-o{extract_dir}", archive_path], capture_output=True)
            if res.returncode == 0:
                extracted = True

        if not extracted:
            return {"success": False, "error": "Failed to extract archive"}

        print("PROGRESS:90", flush=True)

        # 3. Locate directories with index.theme
        installed_themes = []
        for root, dirs, files in os.walk(extract_dir):
            if "index.theme" in files:
                theme_folder_name = os.path.basename(root)
                if not theme_folder_name or root == extract_dir or theme_folder_name in ("extracted", "tmp", "dist"):
                    theme_folder_name = extract_theme_name_from_index(os.path.join(root, "index.theme"), download_name)

                dest = os.path.join(target_dir, theme_folder_name)
                # If already exists, overwrite
                if os.path.exists(dest):
                    shutil.rmtree(dest, ignore_errors=True)

                try:
                    shutil.copytree(root, dest, symlinks=True, ignore_dangling_symlinks=True, dirs_exist_ok=True)
                except Exception:
                    # Fallback to system cp -a if copytree encounters unsupported filesystem traits
                    os.makedirs(dest, exist_ok=True)
                    subprocess.run(["cp", "-a", root + "/.", dest], check=False)

                installed_themes.append(theme_folder_name)
                dirs.clear()  # Do not recurse into nested directories of an installed theme

        if not installed_themes:
            # If no index.theme found directly, maybe archive root is the theme
            return {"success": False, "error": "No valid icon theme (index.theme) found inside archive"}

        print("PROGRESS:100", flush=True)
        return {"success": True, "installedThemes": installed_themes}

def main():
    if len(sys.argv) < 2:
        print(json.dumps(fetch_market_icons()))
        return

    cmd = sys.argv[1]
    if cmd == "list":
        sort = "downloads"
        page = 0
        pagesize = 24
        search = ""
        order = "desc"
        i = 2
        while i < len(sys.argv):
            if sys.argv[i] == "--sort" and i + 1 < len(sys.argv):
                sort = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--order" and i + 1 < len(sys.argv):
                order = sys.argv[i + 1]
                i += 2
            elif sys.argv[i] == "--page" and i + 1 < len(sys.argv):
                page = int(sys.argv[i + 1])
                i += 2
            elif sys.argv[i] == "--pagesize" and i + 1 < len(sys.argv):
                pagesize = int(sys.argv[i + 1])
                i += 2
            elif sys.argv[i] == "--search" and i + 1 < len(sys.argv):
                search = sys.argv[i + 1]
                i += 2
            else:
                i += 1
        res = fetch_market_icons(sort=sort, page=page, pagesize=pagesize, search=search, order=order)
        print(json.dumps(res))

    elif cmd == "install":
        if len(sys.argv) < 3:
            print(json.dumps({"success": False, "error": "Missing download URL"}))
            return
        url = sys.argv[2]
        name = sys.argv[3] if len(sys.argv) > 3 else ""
        res = install_archive(url, name)
        print(json.dumps(res))

    elif cmd == "cache-batch":
        if len(sys.argv) < 3:
            return
        try:
            from concurrent.futures import ThreadPoolExecutor
            batch = json.loads(sys.argv[2])
            with ThreadPoolExecutor(max_workers=8) as ex:
                for entry in batch:
                    if len(entry) == 3:
                        cid, url, idx = entry
                        ex.submit(download_thumb_worker, cid, url, idx)
                    else:
                        cid, url = entry
                        ex.submit(download_thumb_worker, cid, url, 0)
        except Exception:
            pass

if __name__ == "__main__":
    main()

