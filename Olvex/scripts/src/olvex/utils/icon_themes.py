import os
import json
import subprocess
import sys
import shutil

def get_current_theme():
    # 1. First check ~/.config/olvex/theme.json
    try:
        theme_json = os.path.expanduser("~/.config/olvex/theme.json")
        if os.path.isfile(theme_json):
            with open(theme_json, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                th = cfg.get("theme", {}).get("iconTheme")
                if th:
                    return th
    except Exception:
        pass

    # 2. Check ~/.config/olvex/cli.json
    try:
        cli_json = os.path.expanduser("~/.config/olvex/cli.json")
        if os.path.isfile(cli_json):
            with open(cli_json, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                th = cfg.get("theme", {}).get("iconTheme")
                if th:
                    return th
    except Exception:
        pass

    # 4. Check gsettings
    try:
        res = subprocess.check_output(
            ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
        if res.startswith("'") and res.endswith("'"):
            res = res[1:-1]
        if res and res != "Adwaita":
            return res
    except Exception:
        pass

    # 5. Fallback to ~/.config/gtk-3.0/settings.ini
    ini = os.path.expanduser("~/.config/gtk-3.0/settings.ini")
    if os.path.isfile(ini):
        try:
            with open(ini, "r", encoding="utf-8") as f:
                for line in f:
                    if line.startswith("gtk-icon-theme-name="):
                        val = line.split("=", 1)[1].strip()
                        if val:
                            return val
        except Exception:
            pass

    return "Adwaita"

def set_theme(theme_id):
    # 1. Update gsettings
    try:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", theme_id], check=False)
    except Exception:
        pass

    # 2. Update dconf
    try:
        subprocess.run(["dconf", "write", "/org/gnome/desktop/interface/icon-theme", f"'{theme_id}'"], check=False)
    except Exception:
        pass

    # 3. Update gtk-3.0 & gtk-4.0 settings.ini
    for gtk_dir in [os.path.expanduser("~/.config/gtk-3.0"), os.path.expanduser("~/.config/gtk-4.0")]:
        os.makedirs(gtk_dir, exist_ok=True)
        ini_path = os.path.join(gtk_dir, "settings.ini")
        lines = []
        found = False
        if os.path.isfile(ini_path):
            try:
                with open(ini_path, "r", encoding="utf-8") as f:
                    for line in f:
                        if line.strip().startswith("gtk-icon-theme-name="):
                            lines.append(f"gtk-icon-theme-name={theme_id}\n")
                            found = True
                        else:
                            lines.append(line)
            except Exception:
                pass
        if not found:
            if not lines:
                lines = ["[Settings]\n"]
            lines.append(f"gtk-icon-theme-name={theme_id}\n")
        try:
            with open(ini_path, "w", encoding="utf-8") as f:
                f.writelines(lines)
        except Exception:
            pass

    # 4. Update xsettings if running
    try:
        subprocess.run(["xsettingsd", "-c", "/dev/null"], check=False, stderr=subprocess.DEVNULL)
    except Exception:
        pass

    # 5. Persist to ~/.config/olvex/theme.json
    try:
        theme_json = os.path.expanduser("~/.config/olvex/theme.json")
        cfg = {}
        if os.path.isfile(theme_json):
            with open(theme_json, "r", encoding="utf-8") as f:
                cfg = json.load(f)
        if "theme" not in cfg or not isinstance(cfg["theme"], dict):
            cfg["theme"] = {}
        cfg["theme"]["iconTheme"] = theme_id
        with open(theme_json, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception:
        pass

    # 6. Persist to ~/.config/olvex/cli.json
    try:
        cli_json = os.path.expanduser("~/.config/olvex/cli.json")
        if os.path.isfile(cli_json):
            with open(cli_json, "r", encoding="utf-8") as f:
                ccfg = json.load(f)
            if "theme" not in ccfg or not isinstance(ccfg["theme"], dict):
                ccfg["theme"] = {}
            ccfg["theme"]["iconTheme"] = theme_id
            with open(cli_json, "w", encoding="utf-8") as f:
                json.dump(ccfg, f, indent=2)
    except Exception:
        pass

def scan_themes():
    dirs = [
        os.path.expanduser("~/.local/share/icons"),
        os.path.expanduser("~/.icons"),
        "/usr/local/share/icons",
        "/usr/share/icons"
    ]

    current_theme = get_current_theme()
    results = []
    seen = set()

    priority_icons = [
        "folder", "user-home", "system-file-manager", "utilities-terminal",
        "web-browser", "preferences-system", "firefox", "org.gnome.Nautilus",
        "accessories-calculator", "text-editor"
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
            index_path = os.path.join(theme_dir, "index.theme")
            if not (os.path.isdir(theme_dir) and os.path.isfile(index_path)):
                continue
            if name in seen or name == "default":
                continue

            # Detect and ignore pure cursor themes
            cursors_dir = os.path.join(theme_dir, "cursors")
            cursor_theme_file = os.path.join(theme_dir, "cursor.theme")
            has_cursors = os.path.isdir(cursors_dir) or os.path.isfile(cursor_theme_file)

            display_name = name
            comment = ""
            icon_dirs = []
            try:
                with open(index_path, "r", encoding="utf-8", errors="ignore") as f:
                    in_theme = False
                    for line in f:
                        line = line.strip()
                        if line == "[Icon Theme]":
                            in_theme = True
                            continue
                        elif line.startswith("[") and in_theme:
                            break
                        if in_theme:
                            if line.startswith("Name="):
                                display_name = line.split("=", 1)[1]
                            elif line.startswith("Comment="):
                                comment = line.split("=", 1)[1]
                            elif line.startswith("Directories="):
                                dirs_str = line.split("=", 1)[1].strip()
                                icon_dirs = [d.strip() for d in dirs_str.split(",") if d.strip() and d.strip() != "cursors"]
            except Exception:
                pass

            # If theme only has cursors and no icon directories declared, skip it
            if has_cursors and not icon_dirs:
                continue

            def is_clean_svg(fpath):
                if not fpath.lower().endswith(".svg"):
                    return True
                try:
                    with open(fpath, "r", encoding="utf-8", errors="ignore") as sf:
                        chunk = sf.read(16384)
                    if "pattern5614" in chunk or "pattern5626" in chunk or "#sand_bitmap" in chunk:
                        return False
                except Exception:
                    return False
                return True

            previews = {}
            # Walk directory looking for preview icons (skip tiny 16x16/22x22 sizes)
            for root, _, files in os.walk(theme_dir):
                if "/16x16" in root or "/22x22" in root or "/16/" in root or "/22/" in root:
                    continue
                for file in files:
                    stem, ext = os.path.splitext(file)
                    if ext.lower() in (".svg", ".png") and not stem.endswith("-symbolic"):
                        if stem in priority_icons:
                            candidate = os.path.join(root, file)
                            if (stem not in previews or ("scalable" in root or "48x48" in root or "64x64" in root or "128x128" in root)) and is_clean_svg(candidate):
                                previews[stem] = candidate

            # If not enough full-color priority icons, look for any image files
            if len(previews) < 3:
                for root, _, files in os.walk(theme_dir):
                    if "/16x16" in root or "/22x22" in root or "/16/" in root or "/22/" in root:
                        continue
                    for file in files:
                        stem, ext = os.path.splitext(file)
                        if ext.lower() in (".svg", ".png"):
                            candidate = os.path.join(root, file)
                            if stem not in previews and is_clean_svg(candidate):
                                previews[stem] = candidate
                                if len(previews) >= 4:
                                    break
                    if len(previews) >= 4:
                        break

            preview_list = list(previews.values())[:4]
            if not preview_list:
                continue

            seen.add(name)

            results.append({
                "id": name,
                "name": display_name,
                "comment": comment,
                "path": theme_dir,
                "previews": preview_list,
                "isCurrent": (name == current_theme),
                "isDeletable": not (theme_dir.startswith("/usr") or name in ("hicolor", "Adwaita", "default"))
            })

    # Sort: current first, then alphabetical by name
    results.sort(key=lambda t: (not t["isCurrent"], t["name"].lower()))
    return results

def delete_theme(theme_id):
    if not theme_id:
        return {"success": False, "error": "No theme specified"}

    user_dirs = [
        os.path.expanduser("~/.local/share/icons"),
        os.path.expanduser("~/.icons")
    ]

    deleted_paths = []
    current = get_current_theme()
    fallback_used = False

    # 1. Exact directory match
    for base in user_dirs:
        target = os.path.join(base, theme_id)
        if os.path.isdir(target):
            try:
                shutil.rmtree(target, ignore_errors=True)
                deleted_paths.append(target)
            except Exception:
                pass

    # 2. If not matched, try matching theme name loosely inside index.theme
    if not deleted_paths:
        name_clean = theme_id.lower().replace(" ", "").replace("-", "").replace("_", "")
        for base in user_dirs:
            if not os.path.isdir(base):
                continue
            for entry in os.listdir(base):
                entry_clean = entry.lower().replace(" ", "").replace("-", "").replace("_", "")
                if entry_clean in name_clean or name_clean in entry_clean:
                    target = os.path.join(base, entry)
                    if os.path.isdir(target):
                        try:
                            shutil.rmtree(target, ignore_errors=True)
                            deleted_paths.append(target)
                        except Exception:
                            pass

    if not deleted_paths:
        return {"success": False, "error": f"Theme '{theme_id}' not found in user directories"}

    # If active theme was deleted, fallback to Adwaita
    if any(os.path.basename(p) == current for p in deleted_paths) or current == theme_id:
        set_theme("Adwaita")
        fallback_used = True

    return {
        "success": True,
        "deleted": deleted_paths,
        "themeId": theme_id,
        "fallbackUsed": fallback_used
    }

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "set":
        set_theme(sys.argv[2])
        print(f"ok:{sys.argv[2]}")
    elif len(sys.argv) > 2 and sys.argv[1] == "delete":
        res = delete_theme(sys.argv[2])
        print(json.dumps(res))
    else:
        themes = scan_themes()
        print(json.dumps(themes))

