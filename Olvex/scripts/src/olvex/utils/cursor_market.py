#!/usr/bin/env python3
"""
Olvex Online Cursor Pack Market API
Connects to KDE Store / OpenDesktop OCS API to browse, search, and 1-click install cursor themes.
Category: 107 (X11 Mouse Theme)
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

def score_download_candidate(fname, url):
    if not url or not url.startswith("http"):
        return -100
    name = (fname or "").lower()
    score = 0
    # Heavily penalize windows-only packages (.cur, .ani, .bat, .inf, .exe, .msi)
    if any(k in name for k in ("windows", "win32", "win64", ".exe", ".msi", ".bat", ".inf")):
        return -50
    if name.endswith(".tar.xz"):
        score += 100
    elif name.endswith(".tar.gz") or name.endswith(".tgz"):
        score += 90
    elif name.endswith(".tar.bz2"):
        score += 85
    elif name.endswith(".tar.zst"):
        score += 80
    elif name.endswith(".tar"):
        score += 70
    elif name.endswith(".zip"):
        score += 40
    elif name.endswith(".7z"):
        score += 30
    else:
        score += 10

    if "linux" in name:
        score += 20
    if "x11" in name or "xcursor" in name:
        score += 20
    return score

OCS_BASE_URL = "https://api.kde-look.org/ocs/v1/content/data"
DEFAULT_CATEGORY = "107"  # X11 Mouse Theme (Cursors)
USER_AGENT = "Mozilla/5.0 (X11; Linux x86_64) OlvexShell/1.0"

THUMB_CACHE_DIR = os.path.expanduser("~/.cache/olvex/cursor_market_thumbs")
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

def get_installed_cursor_names():
    installed = {}
    dirs = [
        os.path.expanduser("~/.cursors"),
        os.path.expanduser("~/.cursor"),
        os.path.expanduser("~/.icons"),
        os.path.expanduser("~/.local/share/icons"),
        "/usr/local/share/icons",
        "/usr/share/icons"
    ]
    for d in dirs:
        if not os.path.isdir(d):
            continue
        try:
            for entry in os.listdir(d):
                p = os.path.join(d, entry)
                if os.path.isdir(p) and (os.path.isdir(os.path.join(p, "cursors")) or os.path.isfile(os.path.join(p, "cursor.theme"))):
                    clean = entry.lower().replace(" ", "").replace("-", "").replace("_", "")
                    if clean not in installed:
                        installed[clean] = entry
        except Exception:
            pass
    return installed

def get_featured_fallback(sort="downloads", search="", installed=None, order="desc"):
    if installed is None:
        installed = get_installed_cursor_names()

    featured = [
        {
            "id": "1197198",
            "name": "Bibata Modern Classic",
            "author": "KaizK",
            "rating": 98,
            "downloads": 482000,
            "preview": "https://images.pling.com/cache/350x250-0/img/00/00/61/08/93/1197198/bibata.png",
            "summary": "Crisp and sharp rounded edge cursor theme for Linux and Windows",
            "downloadUrl": "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz",
            "downloadName": "Bibata-Modern-Classic.tar.xz"
        },
        {
            "id": "1393004",
            "name": "Sweet Cursors",
            "author": "EliverLara",
            "rating": 96,
            "downloads": 312000,
            "preview": "https://images.pling.com/cache/350x250-0/img/00/00/50/20/85/1393004/sweet-cursors.png",
            "summary": "Colorful modern cursor theme matching Sweet GTK / Plasma theme",
            "downloadUrl": "https://github.com/EliverLara/Sweet-cursors/archive/refs/tags/v1.0.tar.gz",
            "downloadName": "Sweet-cursors.tar.gz"
        },
        {
            "id": "1738722",
            "name": "Catppuccin Mocha Dark Cursors",
            "author": "Catppuccin",
            "rating": 95,
            "downloads": 245000,
            "preview": "https://images.pling.com/cache/350x250-0/img/00/00/77/80/15/1738722/catppuccin.png",
            "summary": "Soothing pastel cursor theme designed for the Catppuccin Mocha palette",
            "downloadUrl": "https://github.com/catppuccin/cursors/releases/download/v1.0.0/Catppuccin-Mocha-Dark-Cursors.zip",
            "downloadName": "Catppuccin-Mocha-Dark-Cursors.zip"
        },
        {
            "id": "1360254",
            "name": "Volantes Cursors",
            "author": "Varlesh",
            "rating": 93,
            "downloads": 182000,
            "preview": "https://images.pling.com/cache/350x250-0/img/00/00/52/62/11/1360254/volantes.png",
            "summary": "Geometric stylized cursors inspired by classic aerodynamic flight indicators",
            "downloadUrl": "https://github.com/varlesh/volantes-cursors/archive/refs/heads/master.tar.gz",
            "downloadName": "volantes-cursors.tar.gz"
        },
        {
            "id": "1197199",
            "name": "Capitaine Cursors",
            "author": "keeferrourke",
            "rating": 94,
            "downloads": 298000,
            "preview": "https://images.pling.com/cache/350x250-0/img/00/00/46/78/33/1197199/capitaine.png",
            "summary": "Clean, xcursor theme inspired by macOS with vector precision styling",
            "downloadUrl": "https://github.com/keeferrourke/capitaine-cursors/releases/download/r4/capitaine-cursors-r4.tar.gz",
            "downloadName": "capitaine-cursors-r4.tar.gz"
        },
        {
            "id": "1360822",
            "name": "Oreo Cursors",
            "author": "Varlesh",
            "rating": 91,
            "downloads": 164000,
            "preview": "https://images.pling.com/cache/350x250-0/img/00/00/55/90/44/1360822/oreo.png",
            "summary": "Crisp material design cursor theme with playful fluid animations",
            "downloadUrl": "https://github.com/varlesh/oreo-cursors/archive/refs/heads/master.tar.gz",
            "downloadName": "oreo-cursors.tar.gz"
        }
    ]

    items = []
    q = (search or "").lower().strip()
    for f in featured:
        if q and q not in f["name"].lower() and q not in f["summary"].lower() and q not in f["author"].lower():
            continue

        cid = f["id"]
        remote_prev = f["preview"]
        cached = get_cached_thumb(cid)
        local_thumb = cached if cached else get_target_thumb_path(cid, remote_prev)

        name_clean = f["name"].lower().replace(" ", "").replace("-", "").replace("_", "")
        is_inst = False
        inst_id = ""
        for clean_inst, real_name in installed.items():
            if clean_inst in name_clean or name_clean in clean_inst:
                is_inst = True
                inst_id = real_name
                break

        items.append({
            "id": cid,
            "name": f["name"],
            "author": f["author"],
            "rating": f["rating"],
            "downloads": f["downloads"],
            "preview": local_thumb,
            "previews": [local_thumb],
            "remotePreview": remote_prev,
            "summary": f["summary"],
            "description": clean_description(f.get("description") or f.get("summary") or ""),
            "downloadUrl": f["downloadUrl"],
            "downloadName": f["downloadName"],
            "isInstalled": is_inst,
            "installedThemeId": inst_id
        })

    # Sort
    if sort == "rating":
        items.sort(key=lambda x: x["rating"], reverse=(order == "desc"))
    elif sort == "newest":
        items.sort(key=lambda x: x["id"], reverse=(order == "desc"))
    else:  # downloads
        items.sort(key=lambda x: x["downloads"], reverse=(order == "desc"))

    # Trigger pre-caching
    uncached = [(it["id"], it["remotePreview"]) for it in items if it.get("remotePreview") and (not it["preview"] or not os.path.exists(it["preview"]))]
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

    return {"error": None, "items": items}

def fetch_cursor_market(sort="downloads", page=0, search="", order="desc"):
    sort_map = {
        "downloads": "down",
        "rating": "high",
        "newest": "new",
        "new": "new",
        "down": "down",
        "high": "high"
    }
    sort_param = sort_map.get(sort, "down")

    params = {
        "categories": DEFAULT_CATEGORY,
        "sortmode": sort_param,
        "page": str(page),
        "pagesize": "30"
    }
    if search:
        params["search"] = search

    query_str = urllib.parse.urlencode(params)
    url = f"{OCS_BASE_URL}?{query_str}"

    installed = get_installed_cursor_names()

    content = None
    for attempt in range(2):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=10) as resp:
                content = resp.read()
                if content:
                    break
        except Exception:
            pass

    if not content:
        return get_featured_fallback(sort=sort, search=search, installed=installed, order=order)

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
            if preview and "cache/770x540-4/" in preview:
                preview = preview.replace("cache/770x540-4/", "cache/350x250-0/")

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

            candidates = []
            for i in range(1, 15):
                link = item_node.findtext(f"downloadlink{i}", "")
                fname = item_node.findtext(f"downloadname{i}", "")
                if link:
                    s = score_download_candidate(fname, link)
                    candidates.append((s, link, fname or f"{name}.tar.gz"))

            dl_url = ""
            dl_name = ""
            if candidates:
                candidates.sort(key=lambda c: c[0], reverse=True)
                dl_url = candidates[0][1]
                dl_name = candidates[0][2]

            name_clean = name.lower().replace(" ", "").replace("-", "").replace("_", "")
            is_installed = False
            installed_id = ""
            for clean_inst, real_name in installed.items():
                if clean_inst in name_clean or name_clean in clean_inst:
                    is_installed = True
                    installed_id = real_name
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

    except Exception:
        return get_featured_fallback(sort=sort, search=search, installed=installed, order=order)

    if not items:
        return get_featured_fallback(sort=sort, search=search, installed=installed, order=order)

    # Sort items accurately according to requested sort & order
    if sort == "rating":
        items.sort(key=lambda x: (x["rating"], x["downloads"]), reverse=(order == "desc"))
    elif sort in ("newest", "new"):
        items.sort(key=lambda x: int(x["id"]) if str(x["id"]).isdigit() else 0, reverse=(order == "desc"))
    else:  # downloads
        items.sort(key=lambda x: (x["downloads"], x["rating"]), reverse=(order == "desc"))

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

def extract_cursor_theme_name_from_index(index_path, fallback=""):
    try:
        with open(index_path, "r", encoding="utf-8", errors="ignore") as f:
            in_section = False
            for line in f:
                line = line.strip()
                if line.lower() in ("[icon theme]", "[cursor theme]"):
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
    return "Custom-Cursor"

def install_archive(download_url, download_name=""):
    if not download_url:
        return {"success": False, "error": "No download URL provided"}

    print("PROGRESS:5", flush=True)
    target_dir = os.path.expanduser("~/.cursors")
    os.makedirs(target_dir, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="olvex_cursor_pkg_") as tmpdir:
        archive_path = os.path.join(tmpdir, download_name or "cursor_pkg.archive")

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
                        pct = 5 + int((downloaded / total_bytes) * 65)
                        if pct - last_pct >= 5 and pct <= 70:
                            print(f"PROGRESS:{pct}", flush=True)
                            last_pct = pct
        except Exception as e:
            return {"success": False, "error": f"Download failed: {e}"}

        print("PROGRESS:75", flush=True)

        # 2. Extract into tmp unpack directory
        extract_dir = os.path.join(tmpdir, "unpacked")
        os.makedirs(extract_dir, exist_ok=True)

        try:
            shutil.unpack_archive(archive_path, extract_dir)
        except Exception:
            # Fallback to tar or unzip
            lower_name = archive_path.lower()
            if any(lower_name.endswith(ext) for ext in [".tar.xz", ".tar.gz", ".tar.bz2", ".tar", ".tgz"]):
                res = subprocess.run(["tar", "-xf", archive_path, "-C", extract_dir], check=False)
                if res.returncode != 0:
                    return {"success": False, "error": "Extraction failed"}
            elif lower_name.endswith(".zip"):
                res = subprocess.run(["unzip", "-q", "-o", archive_path, "-d", extract_dir], check=False)
                if res.returncode != 0:
                    return {"success": False, "error": "Extraction failed"}
            else:
                return {"success": False, "error": "Unsupported archive format"}

        print("PROGRESS:85", flush=True)

        # 3. Locate cursor root directories
        cursor_roots = []
        for root_dir, dirs, files in os.walk(extract_dir):
            if "cursors" in dirs or "cursor.theme" in files:
                cursors_path = os.path.join(root_dir, "cursors")
                if os.path.isdir(cursors_path) or "cursor.theme" in files:
                    cursor_roots.append(root_dir)

        if not cursor_roots:
            # Check if any directory directly contains cursor files without a 'cursors' folder
            known_cursors = {"default", "left_ptr", "pointer", "arrow", "xterm", "ibeam", "crosshair"}
            for root_dir, dirs, files in os.walk(extract_dir):
                if known_cursors.intersection(files):
                    cursors_sub = os.path.join(root_dir, "cursors")
                    os.makedirs(cursors_sub, exist_ok=True)
                    for f in list(files):
                        try:
                            shutil.move(os.path.join(root_dir, f), os.path.join(cursors_sub, f))
                        except Exception:
                            pass
                    cursor_roots.append(root_dir)
                    break

        if not cursor_roots:
            return {"success": False, "error": "No valid Linux cursor theme found in archive"}

        installed_ids = []
        for cr in cursor_roots:
            idx = os.path.join(cr, "index.theme")
            base_cand = os.path.basename(cr.rstrip("/"))
            theme_name = extract_cursor_theme_name_from_index(idx, fallback=base_cand or download_name)

            if base_cand and base_cand not in ("unpacked", "extract", "out") and any(c.isalnum() for c in base_cand):
                safe_dest_name = "".join(c for c in base_cand if c.isalnum() or c in ("-", "_", ".")).strip()
            else:
                safe_dest_name = "".join(c for c in theme_name.replace(" ", "-") if c.isalnum() or c in ("-", "_", ".")).strip()

            if not safe_dest_name:
                safe_dest_name = "Custom-Cursor"

            final_dest = os.path.join(target_dir, safe_dest_name)
            if os.path.exists(final_dest) or os.path.islink(final_dest):
                if os.path.islink(final_dest):
                    os.unlink(final_dest)
                else:
                    shutil.rmtree(final_dest)

            if cr == extract_dir:
                shutil.copytree(cr, final_dest, dirs_exist_ok=True)
            else:
                shutil.move(cr, final_dest)

            installed_ids.append(safe_dest_name)

        print("PROGRESS:100", flush=True)
        primary_id = installed_ids[0] if installed_ids else download_name
        return {"success": True, "installedId": primary_id, "allInstalled": installed_ids}

def uninstall_cursor(theme_id):
    if not theme_id or theme_id.lower() in ("adwaita", "default", "hicolor"):
        return {"success": False, "error": "Cannot uninstall system/default cursor theme"}

    user_base_dirs = [
        os.path.expanduser("~/.cursors"),
        os.path.expanduser("~/.cursor"),
        os.path.expanduser("~/.icons"),
        os.path.expanduser("~/.local/share/icons")
    ]

    clean_id = theme_id.lower().replace(" ", "").replace("-", "").replace("_", "")
    deleted = False

    for base_dir in user_base_dirs:
        if not os.path.isdir(base_dir):
            continue

        # 1. Direct path
        direct = os.path.join(base_dir, theme_id)
        if os.path.exists(direct) or os.path.islink(direct):
            try:
                if os.path.islink(direct):
                    os.unlink(direct)
                else:
                    shutil.rmtree(direct)
                deleted = True
            except Exception as e:
                return {"success": False, "error": str(e)}

        # 2. Case-insensitive / normalized search
        try:
            for entry in os.listdir(base_dir):
                entry_clean = entry.lower().replace(" ", "").replace("-", "").replace("_", "")
                if entry.lower() == theme_id.lower() or entry_clean == clean_id or (clean_id and clean_id in entry_clean):
                    target = os.path.join(base_dir, entry)
                    if os.path.exists(target) or os.path.islink(target):
                        try:
                            if os.path.islink(target):
                                os.unlink(target)
                            else:
                                shutil.rmtree(target)
                            deleted = True
                        except Exception:
                            pass
        except Exception:
            pass

    # Remove thumbnail cache if any
    for ext in [".png", ".jpg", ".jpeg", ".webp"]:
        thumb_p = os.path.join(THUMB_CACHE_DIR, f"{theme_id}{ext}")
        if os.path.exists(thumb_p):
            try:
                os.remove(thumb_p)
            except Exception:
                pass

    if not deleted:
        sys.exit(1)

    return {"success": True, "id": theme_id}

if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(json.dumps(fetch_cursor_market(), indent=2))
    elif args[0] == "browse":
        sort = args[1] if len(args) > 1 else "downloads"
        page = int(args[2]) if len(args) > 2 and args[2].isdigit() else 0
        search = args[3] if len(args) > 3 else ""
        order = args[4] if len(args) > 4 else "desc"
        print(json.dumps(fetch_cursor_market(sort=sort, page=page, search=search, order=order), indent=2))
    elif args[0] == "install":
        url = args[1] if len(args) > 1 else ""
        name = args[2] if len(args) > 2 else ""
        res = install_archive(url, name)
        print(json.dumps(res))
        if not res.get("success", False):
            sys.exit(1)
    elif args[0] == "uninstall":
        theme_id = args[1] if len(args) > 1 else ""
        print(json.dumps(uninstall_cursor(theme_id)))
    elif args[0] == "cache-batch":
        try:
            pairs = json.loads(args[1]) if len(args) > 1 else []
            for entry in pairs:
                if len(entry) == 3:
                    cid, url, idx = entry
                    download_thumb_worker(cid, url, idx)
                else:
                    cid, url = entry
                    download_thumb_worker(cid, url, 0)
        except Exception:
            pass
    else:
        print(json.dumps({"error": f"Unknown command {args[0]}"}))

