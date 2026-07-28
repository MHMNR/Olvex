#!/usr/bin/env python3
"""Olvex CLI backend — wraps the upstream Python CLI with Olvex-specific fixes."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

VIDEO_SUFFIXES = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".m4v"}


def _xdg_state_home() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))


def _wallpaper_path_file() -> Path:
    for name in ("olvex", "caelestia"):
        path = _xdg_state_home() / name / "wallpaper" / "path.txt"
        if path.is_file():
            return path
    return _xdg_state_home() / "olvex" / "wallpaper" / "path.txt"


def _live_thumb_dir() -> Path:
    for name in ("olvex", "caelestia"):
        directory = _xdg_state_home() / name / "wallpaper" / "live-thumbnails"
        if directory.is_dir():
            return directory
    return _xdg_state_home() / "olvex" / "wallpaper" / "live-thumbnails"


def _safe_name(path: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]", "_", path)


def _is_video(path: Path) -> bool:
    return path.suffix.lower() in VIDEO_SUFFIXES


def _thumb_for_video(video: Path) -> Path:
    return _live_thumb_dir() / f"{_safe_name(str(video))}.jpg"


def _generate_thumb(video: Path, thumb: Path) -> bool:
    thumb.parent.mkdir(parents=True, exist_ok=True)
    base_cmd = [
        "ffmpeg",
        "-y",
        "-loglevel",
        "error",
        "-i",
        str(video),
        "-frames:v",
        "1",
        "-vf",
        "scale=640:-1:force_original_aspect_ratio=decrease",
        str(thumb),
    ]

    for seek in ("1", "0"):
        cmd = base_cmd[:]
        cmd[4:4] = ["-ss", seek]
        if subprocess.run(cmd, check=False).returncode == 0 and thumb.is_file() and thumb.stat().st_size > 0:
            return True
    return False


def resolve_image_source(path: Path) -> Path:
    if not _is_video(path):
        return path

    thumb = _thumb_for_video(path)
    if thumb.is_file() and thumb.stat().st_size > 0:
        return thumb

    if _generate_thumb(path, thumb):
        return thumb

    return path


def _current_wallpaper() -> str | None:
    path_file = _wallpaper_path_file()
    try:
        value = path_file.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return value or None


def _patch_wallpaper_print(argv: list[str]) -> list[str]:
    if not argv or argv[0] != "wallpaper":
        return argv

    patched = argv[:]
    index = 1
    while index < len(patched):
        token = patched[index]
        if token not in ("-p", "--print"):
            index += 1
            continue

        next_index = index + 1
        if next_index < len(patched) and not patched[next_index].startswith("-"):
            patched[next_index] = str(resolve_image_source(Path(patched[next_index])))
        else:
            current = _current_wallpaper()
            if current:
                patched.insert(next_index, str(resolve_image_source(Path(current))))
        break

    return patched


def _allow_truncated_images() -> None:
    try:
        from PIL import ImageFile

        ImageFile.LOAD_TRUNCATED_IMAGES = True
    except ImportError:
        pass


def main() -> None:
    _allow_truncated_images()
    argv = _patch_wallpaper_print(sys.argv[1:])
    sys.argv = ["caelestia", *argv]

    from caelestia import main as backend_main

    backend_main()


if __name__ == "__main__":
    main()