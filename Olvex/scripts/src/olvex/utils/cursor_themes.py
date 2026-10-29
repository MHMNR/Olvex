#!/usr/bin/env python3
"""
Olvex Cursor Themes Manager
Lists installed cursor themes, extracts previews to cache, applies cursor themes and settings,
and synchronizes with Hyprland, GNOME/GTK, and Olvex configuration.
"""

import os
import sys
import json
import struct
import subprocess
import shutil

CACHE_PREVIEW_DIR = os.path.expanduser("~/.cache/olvex/cursor_previews")
os.makedirs(CACHE_PREVIEW_DIR, exist_ok=True)

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

def extract_cursor_png(cursor_file, out_png):
    if not HAS_PIL or not os.path.isfile(cursor_file):
        return False
    if os.path.isfile(out_png) and os.path.getsize(out_png) > 100:
        return True
    try:
        with open(cursor_file, "rb") as f:
            header_bytes = f.read(16)
            if len(header_bytes) < 16:
                return False
            magic, header, ver, ntoc = struct.unpack("<IIII", header_bytes)
            if magic != 0x72756358:  # "Xcur"
                return False
            
            best_chunk_offset = None
            best_diff = 999
            for _ in range(ntoc):
                toc_entry = f.read(12)
                if len(toc_entry) < 12:
                    break
                ctype, subtype, pos = struct.unpack("<III", toc_entry)
                if ctype == 0xfffd0002:  # Image chunk
                    diff = abs(int(subtype) - 32)
                    if diff < best_diff:
                        best_diff = diff
                        best_chunk_offset = pos

            if not best_chunk_offset:
                return False

            f.seek(best_chunk_offset)
            meta = f.read(36)
            if len(meta) < 36:
                return False
            h, t, s, v, w, hgt, xh, yh, d = struct.unpack("<IIIIIIIII", meta)
            if w <= 0 or hgt <= 0 or w > 256 or hgt > 256:
                return False

            raw_bytes = f.read(w * hgt * 4)
            if len(raw_bytes) < w * hgt * 4:
                return False

            # Xcursor is little-endian ARGB -> BGRA in byte order
            img = Image.frombytes("RGBA", (w, hgt), raw_bytes, "raw", "BGRA")
            os.makedirs(os.path.dirname(out_png), exist_ok=True)
            img.save(out_png, "PNG")
            return True
    except Exception:
        return False

def get_current_theme_info():
    theme = ""
    size = 24

    # 1. ~/.config/olvex/theme.json
    try:
        theme_json = os.path.expanduser("~/.config/olvex/theme.json")
        if os.path.isfile(theme_json):
            with open(theme_json, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                th = cfg.get("theme", {}).get("cursorTheme")
                if th:
                    theme = th
                sz = cfg.get("theme", {}).get("cursorSize")
                if sz:
                    size = int(sz)
    except Exception:
        pass

    # 2. Check gsettings
    if not theme:
        try:
            res = subprocess.check_output(
                ["gsettings", "get", "org.gnome.desktop.interface", "cursor-theme"],
                text=True, stderr=subprocess.DEVNULL
            ).strip()
            if res.startswith("'") and res.endswith("'"):
                res = res[1:-1]
            if res:
                theme = res
        except Exception:
            pass

    try:
        res_sz = subprocess.check_output(
            ["gsettings", "get", "org.gnome.desktop.interface", "cursor-size"],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
        if res_sz.isdigit():
            size = int(res_sz)
    except Exception:
        pass

    # 3. Fallback to Hyprland variables.lua
    if not theme:
        try:
            vars_lua = os.path.expanduser("~/.config/hypr/variables.lua")
            if os.path.isfile(vars_lua):
                with open(vars_lua, "r", encoding="utf-8") as f:
                    for line in f:
                        if "cursorTheme" in line and "=" in line:
                            val = line.split("=", 1)[1].strip().strip(",").strip('"').strip("'")
                            if val:
                                theme = val
                                break
        except Exception:
            pass

    if not theme:
        theme = "Adwaita"

    return theme, size

def get_cursor_settings():
    theme, size = get_current_theme_info()
    inactive_timeout = 0
    no_warps = False
    zoom_factor = 1.0

    # Read from hyprctl
    try:
        out = subprocess.check_output(["hyprctl", "getoption", "cursor:inactive_timeout", "-j"], text=True, stderr=subprocess.DEVNULL)
        d = json.loads(out)
        if "float" in d:
            inactive_timeout = int(d["float"])
        elif "int" in d:
            inactive_timeout = int(d["int"])
    except Exception:
        pass

    try:
        out = subprocess.check_output(["hyprctl", "getoption", "cursor:no_warps", "-j"], text=True, stderr=subprocess.DEVNULL)
        d = json.loads(out)
        if "bool" in d:
            no_warps = bool(d["bool"])
    except Exception:
        pass

    try:
        out = subprocess.check_output(["hyprctl", "getoption", "cursor:zoom_factor", "-j"], text=True, stderr=subprocess.DEVNULL)
        d = json.loads(out)
        if "float" in d:
            zoom_factor = float(d["float"])
    except Exception:
        pass

    # Read persistent overrides from ~/.config/olvex/theme.json
    try:
        theme_json = os.path.expanduser("~/.config/olvex/theme.json")
        if os.path.isfile(theme_json):
            with open(theme_json, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                cs = cfg.get("cursorSettings", {})
                if "size" in cs:
                    size = int(cs["size"])
                if "inactiveTimeout" in cs:
                    inactive_timeout = int(cs["inactiveTimeout"])
                if "noWarps" in cs:
                    no_warps = bool(cs["noWarps"])
                if "zoomFactor" in cs:
                    zoom_factor = float(cs["zoomFactor"])
    except Exception:
        pass

    return {
        "theme": theme,
        "size": size,
        "inactiveTimeout": inactive_timeout,
        "noWarps": no_warps,
        "zoomFactor": zoom_factor
    }

def set_cursor_theme(theme_id, size=None):
    if not theme_id:
        return {"success": False, "error": "No theme specified"}

    current_theme, current_size = get_current_theme_info()
    target_size = size if size is not None else current_size

    # 1. hyprctl setcursor
    try:
        subprocess.run(["hyprctl", "setcursor", theme_id, str(target_size)], check=False, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # 2. gsettings
    try:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", theme_id], check=False)
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-size", str(target_size)], check=False)
    except Exception:
        pass

    # 3. dconf
    try:
        subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/cursor-theme", f"'{theme_id}'"], check=False)
        subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/cursor-size", str(target_size)], check=False)
    except Exception:
        pass

    # 4. ~/.icons/default/index.theme
    try:
        os.makedirs(os.path.expanduser("~/.icons/default"), exist_ok=True)
        idx_path = os.path.expanduser("~/.icons/default/index.theme")
        with open(idx_path, "w", encoding="utf-8") as f:
            f.write(f"[Icon Theme]\nInherits={theme_id}\n")
    except Exception:
        pass

    # 5. GTK 3 & 4 settings.ini
    for gtk_dir in [os.path.expanduser("~/.config/gtk-3.0"), os.path.expanduser("~/.config/gtk-4.0")]:
        os.makedirs(gtk_dir, exist_ok=True)
        ini_path = os.path.join(gtk_dir, "settings.ini")
        lines = []
        theme_found = False
        size_found = False
        if os.path.isfile(ini_path):
            try:
                with open(ini_path, "r", encoding="utf-8") as f:
                    for line in f:
                        if line.strip().startswith("gtk-cursor-theme-name="):
                            lines.append(f"gtk-cursor-theme-name={theme_id}\n")
                            theme_found = True
                        elif line.strip().startswith("gtk-cursor-theme-size="):
                            lines.append(f"gtk-cursor-theme-size={target_size}\n")
                            size_found = True
                        else:
                            lines.append(line)
            except Exception:
                pass
        if not lines:
            lines = ["[Settings]\n"]
        if not theme_found:
            lines.append(f"gtk-cursor-theme-name={theme_id}\n")
        if not size_found:
            lines.append(f"gtk-cursor-theme-size={target_size}\n")
        try:
            with open(ini_path, "w", encoding="utf-8") as f:
                f.writelines(lines)
        except Exception:
            pass

    # 6. ~/.config/hypr/variables.lua update if exists
    try:
        vars_lua = os.path.expanduser("~/.config/hypr/variables.lua")
        if os.path.isfile(vars_lua):
            with open(vars_lua, "r", encoding="utf-8") as f:
                content = f.read()
            import re
            content = re.sub(r'cursorTheme\s*=\s*["\'][^"\']*["\']', f'cursorTheme = "{theme_id}"', content)
            content = re.sub(r'cursorSize\s*=\s*\d+', f'cursorSize = {target_size}', content)
            with open(vars_lua, "w", encoding="utf-8") as f:
                f.write(content)
    except Exception:
        pass

    # 7. ~/.config/olvex/theme.json
    try:
        theme_json = os.path.expanduser("~/.config/olvex/theme.json")
        cfg = {}
        if os.path.isfile(theme_json):
            with open(theme_json, "r", encoding="utf-8") as f:
                cfg = json.load(f)
        if "theme" not in cfg or not isinstance(cfg["theme"], dict):
            cfg["theme"] = {}
        cfg["theme"]["cursorTheme"] = theme_id
        cfg["theme"]["cursorSize"] = target_size
        with open(theme_json, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception:
        pass

    return {"success": True, "theme": theme_id, "size": target_size}

def set_setting(key, value):
    try:
        theme_json = os.path.expanduser("~/.config/olvex/theme.json")
        cfg = {}
        if os.path.isfile(theme_json):
            with open(theme_json, "r", encoding="utf-8") as f:
                cfg = json.load(f)
        if "cursorSettings" not in cfg or not isinstance(cfg["cursorSettings"], dict):
            cfg["cursorSettings"] = {}

        if key == "size":
            sz = int(value)
            cfg["cursorSettings"]["size"] = sz
            current_theme, _ = get_current_theme_info()
            set_cursor_theme(current_theme, sz)
        elif key == "inactive_timeout":
            sec = int(value)
            cfg["cursorSettings"]["inactiveTimeout"] = sec
            subprocess.run(["hyprctl", "keyword", "cursor:inactive_timeout", str(sec)], check=False, stderr=subprocess.DEVNULL)
        elif key == "no_warps":
            nw = bool(value in (True, 1, "true", "1"))
            cfg["cursorSettings"]["noWarps"] = nw
            subprocess.run(["hyprctl", "keyword", "cursor:no_warps", "1" if nw else "0"], check=False, stderr=subprocess.DEVNULL)
        elif key == "zoom_factor":
            zf = float(value)
            cfg["cursorSettings"]["zoomFactor"] = zf
            subprocess.run(["hyprctl", "keyword", "cursor:zoom_factor", str(zf)], check=False, stderr=subprocess.DEVNULL)

        with open(theme_json, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)

        return {"success": True, "key": key, "value": value}
    except Exception as e:
        return {"success": False, "error": str(e)}

def scan_cursor_themes():
    dirs = [
        os.path.expanduser("~/.cursor"),
        os.path.expanduser("~/.local/share/icons"),
        os.path.expanduser("~/.icons"),
        "/usr/local/share/icons",
        "/usr/share/icons"
    ]

    current_theme, _ = get_current_theme_info()
    results = []
    seen = set()

    # Cursors to search for preview thumbnails
    target_cursor_keys = [
        ("default", ["default", "left_ptr", "arrow", "top_left_arrow"]),
        ("pointer", ["pointer", "hand2", "pointing_hand", "hand1"]),
        ("text", ["text", "xterm", "ibeam"]),
        ("crosshair", ["crosshair", "cross", "diamond_cross", "wait", "watch", "progress"])
    ]

    for base in dirs:
        if not os.path.isdir(base):
            continue
        try:
            entries = sorted(os.listdir(base))
        except Exception:
            continue

        for name in entries:
            theme_dir = os.path.join(base, name)
            cursors_dir = os.path.join(theme_dir, "cursors")
            cursor_theme_file = os.path.join(theme_dir, "cursor.theme")
            index_path = os.path.join(theme_dir, "index.theme")

            has_cursors = os.path.isdir(cursors_dir) or os.path.isfile(cursor_theme_file)
            if not has_cursors or name in seen or name == "default":
                continue
            seen.add(name)

            display_name = name
            comment = ""
            if os.path.isfile(index_path):
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
                            if in_section:
                                if line.startswith("Name="):
                                    display_name = line.split("=", 1)[1]
                                elif line.startswith("Comment="):
                                    comment = line.split("=", 1)[1]
                except Exception:
                    pass

            # Extract or find previews
            previews = []
            theme_cache_dir = os.path.join(CACHE_PREVIEW_DIR, name)
            os.makedirs(theme_cache_dir, exist_ok=True)

            if os.path.isdir(cursors_dir):
                available_cursors = set(os.listdir(cursors_dir))
                for key_name, aliases in target_cursor_keys:
                    found_file = None
                    for alias in aliases:
                        if alias in available_cursors:
                            found_file = os.path.join(cursors_dir, alias)
                            break
                    if found_file:
                        out_png = os.path.join(theme_cache_dir, f"{key_name}.png")
                        if extract_cursor_png(found_file, out_png):
                            previews.append(out_png)

                # If fewer than 4, fill with any other valid cursor files
                if len(previews) < 4:
                    for cf in available_cursors:
                        full_cf = os.path.join(cursors_dir, cf)
                        out_png = os.path.join(theme_cache_dir, f"{cf}.png")
                        if out_png not in previews and extract_cursor_png(full_cf, out_png):
                            previews.append(out_png)
                            if len(previews) >= 4:
                                break

            results.append({
                "id": name,
                "name": display_name,
                "comment": comment if comment else (qsTr_system if theme_dir.startswith("/usr") else ""),
                "path": theme_dir,
                "previews": previews[:4],
                "isCurrent": (name.lower() == current_theme.lower()),
                "isDeletable": not (theme_dir.startswith("/usr") or name in ("Adwaita", "default"))
            })

    has_current = any(t["isCurrent"] for t in results)
    if not has_current and results:
        results[0]["isCurrent"] = True

    results.sort(key=lambda t: (not t["isCurrent"], t["name"].lower()))
    return results

def delete_cursor_theme(theme_id):
    if not theme_id or theme_id.lower() in ("adwaita", "default", "hicolor"):
        return {"success": False, "error": "Cannot delete default/system cursor theme"}

    user_base_dirs = [
        os.path.expanduser("~/.cursor"),
        os.path.expanduser("~/.local/share/icons"),
        os.path.expanduser("~/.icons")
    ]

    clean_id = theme_id.lower().replace(" ", "").replace("-", "").replace("_", "")
    deleted = False

    for base_dir in user_base_dirs:
        if not os.path.isdir(base_dir):
            continue

        # 1. Exact match
        direct = os.path.join(base_dir, theme_id)
        if os.path.exists(direct) or os.path.islink(direct):
            try:
                if os.path.islink(direct):
                    os.unlink(direct)
                else:
                    shutil.rmtree(direct)
                deleted = True
            except Exception as e:
                return {"success": False, "error": f"Failed to delete {direct}: {e}"}

        # 2. Case-insensitive / normalized match
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

    # Clean preview cache
    if os.path.isdir(CACHE_PREVIEW_DIR):
        for entry in os.listdir(CACHE_PREVIEW_DIR):
            entry_clean = entry.lower().replace(" ", "").replace("-", "").replace("_", "")
            if entry.lower() == theme_id.lower() or entry_clean == clean_id:
                try:
                    shutil.rmtree(os.path.join(CACHE_PREVIEW_DIR, entry))
                except Exception:
                    pass

    if not deleted:
        sys.exit(1)

    return {"success": True, "id": theme_id}

if __name__ == "__main__":
    qsTr_system = "System Cursor"
    args = sys.argv[1:]
    if not args:
        print(json.dumps(scan_cursor_themes(), indent=2))
    elif args[0] == "set":
        theme = args[1] if len(args) > 1 else ""
        size = int(args[2]) if len(args) > 2 and args[2].isdigit() else None
        print(json.dumps(set_cursor_theme(theme, size)))
    elif args[0] == "delete":
        theme = args[1] if len(args) > 1 else ""
        print(json.dumps(delete_cursor_theme(theme)))
    elif args[0] == "settings":
        print(json.dumps(get_cursor_settings(), indent=2))
    elif args[0] == "set_setting" and len(args) >= 3:
        print(json.dumps(set_setting(args[1], args[2])))
    else:
        print(json.dumps({"error": f"Unknown command {args[0]}"}))

