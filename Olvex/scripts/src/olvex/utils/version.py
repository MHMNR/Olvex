import json
import shutil
import subprocess
from pathlib import Path
from typing import Any, Dict

from olvex.utils.paths import config_dir


def find_olvex_root() -> Path | None:
    """Find the root directory of the Olvex repository/installation."""
    # 1. Search up from this file
    p = Path(__file__).resolve()
    for parent in [p] + list(p.parents):
        if (parent / "version.json").exists() or (parent / "shell.qml").exists():
            return parent

    # 2. Check standard config / share dirs
    candidates = [
        config_dir / "quickshell" / "olvex",
        Path("/usr/share/quickshell/olvex"),
        Path("/usr/lib/olvex"),
    ]
    for c in candidates:
        if c.exists() and ((c / "version.json").exists() or (c / "shell.qml").exists()):
            return c

    return None


def get_version_info() -> Dict[str, Any]:
    """Return dictionary of all Olvex and system component versions."""
    info: Dict[str, Any] = {
        "name": "Olvex Shell",
        "version": "1.1.0",
        "major": 1,
        "minor": 1,
        "patch": 0,
        "channel": "Rolling",
        "releaseType": "",
        "buildId": "2026.09.06",
        "commit": None,
        "branch": None,
        "commitDate": None,
        "dirty": False,
        "quickshell": None,
        "hyprland": None,
    }

    root = find_olvex_root()
    if root:
        manifest_file = root / "version.json"
        if manifest_file.exists():
            try:
                with open(manifest_file, "r", encoding="utf-8") as f:
                    manifest = json.load(f)
                    info.update(manifest)
            except Exception:
                pass

        # Check git if available
        try:
            git_log = subprocess.run(
                ["git", "-C", str(root), "log", "-1", "--format=%h|%cd|%D", "--date=short"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                check=False,
            ).stdout.strip()
            if git_log:
                parts = git_log.split("|")
                if len(parts) > 0 and parts[0]:
                    info["commit"] = parts[0].strip()
                if len(parts) > 1 and parts[1]:
                    info["commitDate"] = parts[1].strip()
                if len(parts) > 2 and parts[2]:
                    ref = parts[2]
                    if "HEAD -> " in ref:
                        info["branch"] = ref.split("HEAD -> ")[1].split(",")[0].strip()
                    elif "HEAD" in ref:
                        info["branch"] = "HEAD"

            status = subprocess.run(
                ["git", "-C", str(root), "status", "--porcelain"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                check=False,
            ).stdout.strip()
            info["dirty"] = len(status) > 0
        except Exception:
            pass

    if shutil.which("qs"):
        try:
            qs_ver = subprocess.run(
                ["qs", "--version"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                check=False,
            ).stdout.strip()
            if qs_ver:
                info["quickshell"] = qs_ver
        except Exception:
            pass

    if shutil.which("hyprctl"):
        try:
            hypr_ver = subprocess.run(
                ["hyprctl", "version"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                check=False,
            ).stdout
            for line in hypr_ver.splitlines():
                if "Tag:" in line or "tag:" in line or "branch" in line:
                    info["hyprland"] = line.strip()
                    break
        except Exception:
            pass

    return info


def print_version() -> None:
    info = get_version_info()

    ver_str = f"v{info['version']}"
    if info.get("releaseType"):
        ver_str += f"-{info['releaseType']}"

    git_str = ""
    if info.get("commit"):
        git_str = f" (git: {info['commit']}"
        if info.get("branch"):
            git_str += f"@{info['branch']}"
        if info.get("dirty"):
            git_str += " [modified]"
        git_str += ")"

    print(f"\033[1m{info['name']}\033[0m {ver_str}{git_str}")
    if info.get("channel"):
        print(f"  Channel:    {info['channel']}")
    if info.get("commitDate"):
        print(f"  Date:       {info['commitDate']}")

    if info.get("quickshell"):
        print(f"  Engine:     {info['quickshell']}")
    if info.get("hyprland"):
        print(f"  Compositor: {info['hyprland']}")

    if shutil.which("pacman"):
        pkgs = ["olvex-shell", "olvex-cli", "olvex-meta"]
        res = subprocess.run(
            ["pacman", "-Q", *pkgs],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=False,
        ).stdout.strip()
        if res:
            print("\nInstalled Packages:")
            for line in res.splitlines():
                print(f"  {line}")
