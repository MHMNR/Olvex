#!/usr/bin/env python3
"""
Olvex Universal Dynamic Shortcuts Discoverer & Parser
Discovers active keybinds dynamically from:
1. Dotfiles Lua config: ~/.config/hypr/variables.lua & hyprland/*.lua
2. Native Hyprland IPC: `hyprctl binds -j`
3. Standard hyprland.conf files (bind, bindd, bindm, binde, bindl)
Categorizes items into: olvex (Shell), window (Windows), workspace (Workspaces), apps (Apps), media (Media)
"""

import os
import sys
import json
import re
import subprocess
from pathlib import Path

HOME = os.path.expanduser("~")
HYPR_DIR = os.path.join(HOME, ".config", "hypr")

KEY_MAP = {
    "SUPER_L": "Super",
    "SUPER_R": "Super",
    "CONTROL_L": "Ctrl",
    "CONTROL_R": "Ctrl",
    "ALT_L": "Alt",
    "ALT_R": "Alt",
    "SHIFT_L": "Shift",
    "SHIFT_R": "Shift",
    "slash": "/",
    "question": "?",
    "backslash": "\\",
    "Backslash": "\\",
    "minus": "-",
    "Minus": "-",
    "equal": "=",
    "Equal": "=",
    "plus": "+",
    "period": ".",
    "Period": ".",
    "comma": ",",
    "Comma": ",",
    "space": "Space",
    "Escape": "Esc",
    "Return": "Enter",
    "Delete": "Del",
    "mouse_down": "Scroll Down",
    "mouse_up": "Scroll Up",
    "mouse:272": "LMB",
    "mouse:273": "RMB",
    "Page_Down": "PgDn",
    "Page_Up": "PgUp",
    "left": "←",
    "right": "→",
    "up": "↑",
    "down": "↓",
    "Left": "←",
    "Right": "→",
    "Up": "↑",
    "Down": "↓",
    "XF86AudioRaiseVolume": "Vol Up",
    "XF86AudioLowerVolume": "Vol Down",
    "XF86AudioMute": "Mute",
    "XF86AudioMicMute": "Mic Mute",
    "XF86AudioPlay": "Play",
    "XF86AudioPause": "Pause",
    "XF86AudioNext": "Next",
    "XF86AudioPrev": "Prev",
    "XF86AudioStop": "Stop",
    "XF86MonBrightnessUp": "Brightness Up",
    "XF86MonBrightnessDown": "Brightness Down"
}

def normalize_key(k):
    return KEY_MAP.get(k, k)

def parse_combo(combo_str):
    parts = [p.strip() for p in combo_str.split("+")]
    mods = []
    key = ""
    for p in parts:
        p_up = p.upper()
        if p_up in ["SUPER", "MOD4"]:
            if "Super" not in mods: mods.append("Super")
        elif p_up in ["CTRL", "CONTROL"]:
            if "Ctrl" not in mods: mods.append("Ctrl")
        elif p_up in ["ALT", "MOD1"]:
            if "Alt" not in mods: mods.append("Alt")
        elif p_up in ["SHIFT"]:
            if "Shift" not in mods: mods.append("Shift")
        else:
            key = normalize_key(p)
    if not key and mods:
        key = mods.pop()
    # Special case: Super tap release (kbLauncher = "SUPER + SUPER_L")
    if key == "Super" and mods == ["Super"]:
        mods = []
    return mods, key

def decode_modmask(modmask):
    mods = []
    if modmask & 4:
        mods.append("Ctrl")
    if modmask & 64:
        mods.append("Super")
    if modmask & 8:
        mods.append("Alt")
    if modmask & 1:
        mods.append("Shift")
    return mods

def load_variables_lua():
    vars_file = os.path.join(HYPR_DIR, "variables.lua")
    if not os.path.isfile(vars_file):
        return {}, {}
    try:
        with open(vars_file, "r", encoding="utf-8") as f:
            text = f.read()
        
        # Extract variables
        pattern = re.compile(r'([a-zA-Z0-9_]+)\s*=\s*(\{[^}]+\}|"[^"]+"|\'[^\']+\'|[0-9]+)')
        matches = pattern.findall(text)
        bind_vars = {}
        app_vars = {}
        
        for k, v in matches:
            v = v.strip()
            if k.startswith("kb"):
                if v.startswith("{"):
                    items = re.findall(r'["\']([^"\']+)["\']', v)
                    bind_vars[k] = items
                else:
                    bind_vars[k] = [v.strip('"\'')]
            else:
                app_vars[k] = v.strip('"\'')
                
        return bind_vars, app_vars
    except Exception:
        return {}, {}

def scan_lua_extra_binds():
    """Scans all hyprland/*.lua for explicit binds"""
    extra_items = []
    for root, _, files in os.walk(HYPR_DIR):
        for file in files:
            if not file.endswith(".lua") or file == "variables.lua":
                continue
            path = os.path.join(root, file)
            try:
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()

                # App bindings: create_bind("COMBO", hl.dsp.exec_cmd("app2unit -- APP"))
                for combo, app in re.findall(r'create_bind\(\s*["\']([^"\']+)["\'],\s*hl\.dsp\.exec_cmd\(["\']app2unit\s*--\s*([^"\']+)["\']\)', content):
                    name = app.strip()
                    title = name.title()
                    if name == "github-desktop":
                        title = "GitHub Desktop"
                    elif name == "qps":
                        title = "Task Manager (Qps)"
                    elif name == "nemo":
                        title = "Secondary File Explorer (Nemo)"
                    extra_items.append((title, combo, "apps"))

                # Standalone hl.bind("SUPER + j", hl.dsp.exec_cmd("xed"))
                for combo, cmd in re.findall(r'hl\.bind\(\s*["\']([^"\']+)["\'],\s*hl\.dsp\.exec_cmd\(["\']([^"\']+)["\']\)\)', content):
                    bin_name = cmd.split()[-1].strip()
                    title = f"Text Editor ({bin_name.title()})" if bin_name == "xed" else bin_name.title()
                    extra_items.append((title, combo, "apps"))

                # Shell lifecycle
                if "olvex shell restart" in content:
                    m = re.search(r'create_bind\(["\']([^"\']+)["\'],\s*hl\.dsp\.exec_cmd\(["\']olvex shell restart["\']\)', content)
                    if m:
                        extra_items.append(("Restart Olvex Shell", m.group(1), "apps"))
                if "olvex shell kill" in content:
                    m = re.search(r'create_bind\(["\']([^"\']+)["\'],\s*hl\.dsp\.exec_cmd\(["\']olvex shell kill["\']\)', content)
                    if m:
                        extra_items.append(("Terminate Olvex Shell", m.group(1), "apps"))

                # Test notification
                if "Test notification" in content:
                    m = re.search(r'create_bind\(\s*["\']([^"\']+)["\'],\s*hl\.dsp\.exec_cmd\(["\']notify-send', content)
                    if m:
                        extra_items.append(("Test Notification", m.group(1), "apps"))
            except Exception:
                pass
    return extra_items

def build_from_variables_lua(var_dict, app_dict, extra_binds):
    sections = {
        "olvex": {"id": "olvex", "title": "Olvex Shell", "items": []},
        "window": {"id": "window", "title": "Window Management", "items": []},
        "workspace": {"id": "workspace", "title": "Workspaces", "items": []},
        "apps": {"id": "apps", "title": "Applications", "items": []},
        "media": {"id": "media", "title": "Media & System", "items": []}
    }

    seen_titles = set()

    def add_item(sec_id, title, mods, key):
        if (sec_id, title) in seen_titles:
            return
        seen_titles.add((sec_id, title))
        sections[sec_id]["items"].append({
            "title": title,
            "mods": mods,
            "key": key
        })

    def get_first_combo(var_name):
        lst = var_dict.get(var_name, [])
        return lst[0] if lst else None

    # --- 1. Olvex Shell ---
    add_item("olvex", "Application Launcher", [], "Super")
    if "kbShowSidebar" in var_dict:
        m, k = parse_combo(get_first_combo("kbShowSidebar"))
        add_item("olvex", "Shell Sidebar", m, k)
    if "kbShowPanels" in var_dict:
        m, k = parse_combo(get_first_combo("kbShowPanels"))
        add_item("olvex", "Toggle All Drawers", m, k)
    if "kbHelp" in var_dict:
        m, k = parse_combo(get_first_combo("kbHelp"))
        add_item("olvex", "Shortcuts Cheatsheet", m, k)
    if "kbWallpapers" in var_dict:
        m, k = parse_combo(get_first_combo("kbWallpapers"))
        add_item("olvex", "Wallpaper Selector", m, k)
    if "kbLock" in var_dict:
        m, k = parse_combo(get_first_combo("kbLock"))
        add_item("olvex", "Lock Screen", m, k)
    if "kbRestoreLock" in var_dict:
        m, k = parse_combo(get_first_combo("kbRestoreLock"))
        add_item("olvex", "Restore Lock Screen", m, k)
    if "kbSleep" in var_dict:
        m, k = parse_combo(get_first_combo("kbSleep"))
        add_item("olvex", "Suspend / Sleep", m, k)
    if "kbSession" in var_dict:
        m, k = parse_combo(get_first_combo("kbSession"))
        add_item("olvex", "Power & Session", m, k)
    if "kbClipboard" in var_dict:
        m, k = parse_combo(get_first_combo("kbClipboard"))
        add_item("olvex", "Clipboard History", m, k)
    if "kbClipboardDel" in var_dict:
        m, k = parse_combo(get_first_combo("kbClipboardDel"))
        add_item("olvex", "Clear Clipboard Item", m, k)
    if "kbClipboardPasteLatest" in var_dict:
        m, k = parse_combo(get_first_combo("kbClipboardPasteLatest"))
        add_item("olvex", "Paste Latest Clip", m, k)
    if "kbEmoji" in var_dict:
        m, k = parse_combo(get_first_combo("kbEmoji"))
        add_item("olvex", "Emoji Picker", m, k)
    if "kbClearNotifs" in var_dict:
        m, k = parse_combo(get_first_combo("kbClearNotifs"))
        add_item("olvex", "Clear Notifications", m, k)

    # --- 2. Window Management ---
    if "kbCloseWindow" in var_dict:
        m, k = parse_combo(get_first_combo("kbCloseWindow"))
        add_item("window", "Close Focused Window", m, k)
    if "kbWindowFullscreen" in var_dict:
        m, k = parse_combo(get_first_combo("kbWindowFullscreen"))
        add_item("window", "Toggle Fullscreen", m, k)
    if "kbWindowBorderedFullscreen" in var_dict:
        m, k = parse_combo(get_first_combo("kbWindowBorderedFullscreen"))
        add_item("window", "Bordered Fullscreen", m, k)
    if "kbToggleWindowFloating" in var_dict:
        m, k = parse_combo(get_first_combo("kbToggleWindowFloating"))
        add_item("window", "Toggle Floating", m, k)
    if "kbCenterWindow" in var_dict:
        m, k = parse_combo(get_first_combo("kbCenterWindow"))
        add_item("window", "Center Window", m, k)
    if "kbNormalizeWindow" in var_dict:
        m, k = parse_combo(get_first_combo("kbNormalizeWindow"))
        add_item("window", "Normalize Window (55×70)", m, k)
    if "kbWindowPip" in var_dict:
        m, k = parse_combo(get_first_combo("kbWindowPip"))
        add_item("window", "Picture-in-Picture (PiP)", m, k)
    if "kbPinWindow" in var_dict:
        m, k = parse_combo(get_first_combo("kbPinWindow"))
        add_item("window", "Pin to All Desktops", m, k)
    if "kbWindowCycleNext" in var_dict:
        m, k = parse_combo(get_first_combo("kbWindowCycleNext"))
        add_item("window", "Cycle Windows", m, k)
    if "kbWindowCyclePrev" in var_dict:
        m, k = parse_combo(get_first_combo("kbWindowCyclePrev"))
        add_item("window", "Reverse Cycle Windows", m, k)
    add_item("window", "Focus Window (Left / Right)", ["Super"], "← / →")
    add_item("window", "Focus Window (Up / Down)", ["Super"], "↑ / ↓")
    add_item("window", "Swap Window Direction", ["Super", "Shift"], "Arrows")
    add_item("window", "Resize Window Width", ["Super"], "- / =")
    add_item("window", "Resize Window Height", ["Super", "Shift"], "- / =")
    add_item("window", "Interactive Move Window", ["Super"], "Z / LMB")
    add_item("window", "Interactive Resize Window", ["Super"], "X / RMB")
    if "kbToggleGroup" in var_dict:
        m, k = parse_combo(get_first_combo("kbToggleGroup"))
        add_item("window", "Toggle Window Group", m, k)
    if "kbUngroup" in var_dict:
        m, k = parse_combo(get_first_combo("kbUngroup"))
        add_item("window", "Ungroup Window", m, k)
    if "kbGroupLockActive" in var_dict:
        m, k = parse_combo(get_first_combo("kbGroupLockActive"))
        add_item("window", "Lock Window Group", m, k)
    if "kbWindowGroupCycleNext" in var_dict:
        m, k = parse_combo(get_first_combo("kbWindowGroupCycleNext"))
        add_item("window", "Cycle Group Windows", m, k)

    # --- 3. Workspaces ---
    add_item("workspace", "Switch Workspace 1–10", ["Super"], "1 – 9, 0")
    add_item("workspace", "Move Window to Workspace", ["Super", "Shift"], "1 – 9, 0")
    add_item("workspace", "Switch Workspace Group", ["Ctrl", "Super"], "1 – 9, 0")
    add_item("workspace", "Move to Workspace Group", ["Ctrl", "Super", "Alt"], "1 – 9, 0")
    add_item("workspace", "Next / Prev Workspace", ["Super"], "Scroll / Arrows")
    add_item("workspace", "Next / Prev Group (+10)", ["Ctrl", "Super"], "Scroll")
    add_item("workspace", "Move Window to Adjacent", ["Super", "Alt"], "Scroll / Arrows")
    if "kbSpecialWs" in var_dict:
        m, k = parse_combo(get_first_combo("kbSpecialWs"))
        add_item("workspace", "Toggle Special Scratchpad", m, k)
    if "kbMoveWinToWsSpecial" in var_dict:
        m, k = parse_combo(get_first_combo("kbMoveWinToWsSpecial"))
        add_item("workspace", "Move Window to Scratchpad", m, k)
    if "kbMoveWinFromWsSpecial" in var_dict:
        m, k = parse_combo(get_first_combo("kbMoveWinFromWsSpecial"))
        add_item("workspace", "Restore from Scratchpad", m, k)
    if "kbMusicWs" in var_dict:
        m, k = parse_combo(get_first_combo("kbMusicWs"))
        add_item("workspace", "Music Workspace", m, k)
    if "kbCommunicationWs" in var_dict:
        m, k = parse_combo(get_first_combo("kbCommunicationWs"))
        add_item("workspace", "Communication Workspace", m, k)
    if "kbTodoWs" in var_dict:
        m, k = parse_combo(get_first_combo("kbTodoWs"))
        add_item("workspace", "Tasks & Todo Workspace", m, k)

    # --- 4. Applications ---
    term_name = app_dict.get("terminal", "Terminal").capitalize()
    browser_name = app_dict.get("browser", "Browser").capitalize()
    editor_name = app_dict.get("editor", "Editor").capitalize()
    file_name = app_dict.get("fileExplorer", "Files").capitalize()
    mixer_name = app_dict.get("audioSettings", "Audio").capitalize()

    if "kbTerminal" in var_dict:
        m, k = parse_combo(get_first_combo("kbTerminal"))
        add_item("apps", f"Terminal Emulator ({term_name})", m, k)
    if "kbBrowser" in var_dict:
        m, k = parse_combo(get_first_combo("kbBrowser"))
        add_item("apps", f"Web Browser ({browser_name})", m, k)
    if "kbEditor" in var_dict:
        m, k = parse_combo(get_first_combo("kbEditor"))
        add_item("apps", f"Code Editor ({editor_name})", m, k)
    if "kbFileExplorer" in var_dict:
        m, k = parse_combo(get_first_combo("kbFileExplorer"))
        add_item("apps", f"File Manager ({file_name})", m, k)
    
    # Extra discovered apps
    for title, combo, sec in extra_binds:
        if sec == "apps":
            m, k = parse_combo(combo)
            add_item("apps", title, m, k)

    if "kbSystemMonitorWs" in var_dict:
        m, k = parse_combo(get_first_combo("kbSystemMonitorWs"))
        add_item("apps", "System Monitor (Btop)", m, k)
    if "kbAudioSettings" in var_dict:
        m, k = parse_combo(get_first_combo("kbAudioSettings"))
        add_item("apps", f"Audio Volume Mixer ({mixer_name})", m, k)

    # --- 5. Media & System ---
    vol_step = app_dict.get("volumeStep", "10")
    if "kbScreenshot" in var_dict:
        m, k = parse_combo(get_first_combo("kbScreenshot"))
        add_item("media", "Screenshot Fullscreen", m, k)
    if "kbScreenshotFreeze" in var_dict:
        m, k = parse_combo(get_first_combo("kbScreenshotFreeze"))
        add_item("media", "Screenshot Region", m, k)
    if "kbScreenshotRegion" in var_dict:
        m, k = parse_combo(get_first_combo("kbScreenshotRegion"))
        add_item("media", "Direct Snip Region", m, k)
    if "kbRecordSound" in var_dict:
        m, k = parse_combo(get_first_combo("kbRecordSound"))
        add_item("media", "Screen Recording (Sound)", m, k)
    if "kbRecordRegion" in var_dict:
        m, k = parse_combo(get_first_combo("kbRecordRegion"))
        add_item("media", "Screen Recording (Region)", m, k)
    if "kbRecord" in var_dict:
        m, k = parse_combo(get_first_combo("kbRecord"))
        add_item("media", "Toggle Screen Recording", m, k)
    if "kbColorPicker" in var_dict:
        m, k = parse_combo(get_first_combo("kbColorPicker"))
        add_item("media", "Color Picker (Hyprpicker)", m, k)
    add_item("media", f"Volume Raise (+{vol_step}%)", [], "Vol Up")
    add_item("media", f"Volume Lower (-{vol_step}%)", [], "Vol Down")
    if "kbVolumeMute" in var_dict:
        m, k = parse_combo(get_first_combo("kbVolumeMute"))
        add_item("media", "Volume Mute Toggle", m, k)
    add_item("media", "Microphone Mute", [], "Mic Mute")
    if "kbMediaToggle" in var_dict:
        m, k = parse_combo(get_first_combo("kbMediaToggle"))
        add_item("media", "Media Play / Pause", m, k)
    if "kbMediaNext" in var_dict:
        m, k = parse_combo(get_first_combo("kbMediaNext"))
        add_item("media", "Media Next Track", m, k)
    if "kbMediaPrev" in var_dict:
        m, k = parse_combo(get_first_combo("kbMediaPrev"))
        add_item("media", "Media Previous Track", m, k)
    if "kbMediaStop" in var_dict:
        m, k = parse_combo(get_first_combo("kbMediaStop"))
        add_item("media", "Media Stop", m, k)
    add_item("media", "Brightness Up / Down", [], "Brightness")

    return list(sections.values())

def load_from_hyprctl_binds():
    """Fallback / Universal mode: reads directly from hyprctl binds -j"""
    try:
        output = subprocess.check_output(["hyprctl", "binds", "-j"], timeout=2)
        binds = json.loads(output)
    except Exception:
        return []

    sections = {
        "olvex": {"id": "olvex", "title": "Olvex Shell", "items": []},
        "window": {"id": "window", "title": "Window Management", "items": []},
        "workspace": {"id": "workspace", "title": "Workspaces", "items": []},
        "apps": {"id": "apps", "title": "Applications", "items": []},
        "media": {"id": "media", "title": "Media & System", "items": []}
    }

    seen = set()

    for b in binds:
        key = normalize_key(b.get("key", ""))
        modmask = b.get("modmask", 0)
        mods = decode_modmask(modmask)
        dsp = b.get("dispatcher", "")
        arg = b.get("arg", "")
        desc = b.get("description", "").strip()

        title = desc
        sec_id = "window"

        if not title:
            if dsp == "killactive":
                title = "Close Focused Window"
                sec_id = "window"
            elif dsp == "fullscreen":
                title = "Toggle Fullscreen"
                sec_id = "window"
            elif dsp == "togglefloating":
                title = "Toggle Floating"
                sec_id = "window"
            elif "workspace" in dsp:
                title = f"Workspace {arg}" if arg else "Workspace Action"
                sec_id = "workspace"
            elif dsp == "exec":
                cmd_parts = arg.split()
                bin_name = os.path.basename(cmd_parts[0]) if cmd_parts else "App"
                title = f"Launch {bin_name.capitalize()}"
                sec_id = "apps"
            else:
                title = f"{dsp.replace('_', ' ').title()}"

        dedup_key = (sec_id, title)
        if dedup_key in seen:
            continue
        seen.add(dedup_key)

        sections[sec_id]["items"].append({
            "title": title,
            "mods": mods,
            "key": key
        })

    return [s for s in sections.values() if s["items"]]

def get_shortcuts():
    # Tier 1: Check variables.lua and dotfiles lua
    var_dict, app_dict = load_variables_lua()
    extra_binds = scan_lua_extra_binds()
    if var_dict:
        result = build_from_variables_lua(var_dict, app_dict, extra_binds)
        total_items = sum(len(s["items"]) for s in result)
        if total_items > 10:
            return result

    # Tier 2: Read from native hyprctl binds -j
    hyprctl_result = load_from_hyprctl_binds()
    total_items = sum(len(s["items"]) for s in hyprctl_result)
    if total_items > 5:
        return hyprctl_result

    # Tier 3: Hardcoded safe baseline fallback
    return []

if __name__ == "__main__":
    shortcuts = get_shortcuts()
    print(json.dumps(shortcuts, indent=2))
