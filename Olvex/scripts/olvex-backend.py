#!/usr/bin/env python3
"""Olvex CLI backend — wraps the upstream Python CLI with Olvex-specific fixes."""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Sequence

VIDEO_SUFFIXES = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".m4v"}
OLVEX_NAME = "olvex"


def _home() -> Path:
    return Path.home()


def _xdg_config_home() -> Path:
    return Path(os.environ.get("XDG_CONFIG_HOME", _home() / ".config"))


def _xdg_data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME", _home() / ".local" / "share"))


def _xdg_state_home() -> Path:
    return Path(os.environ.get("XDG_STATE_HOME", _home() / ".local" / "state"))


def _xdg_cache_home() -> Path:
    return Path(os.environ.get("XDG_CACHE_HOME", _home() / ".cache"))


def _olvex_config_dir() -> Path:
    return _xdg_config_home() / OLVEX_NAME


def _olvex_state_dir() -> Path:
    return _xdg_state_home() / OLVEX_NAME


def _olvex_cache_dir() -> Path:
    return _xdg_cache_home() / OLVEX_NAME


def _olvex_data_dir() -> Path:
    return _xdg_data_home() / OLVEX_NAME


def _wallpaper_path_file() -> Path:
    return _olvex_state_dir() / "wallpaper" / "path.txt"


def _live_thumb_dir() -> Path:
    return _olvex_state_dir() / "wallpaper" / "live-thumbnails"


def _ensure_olvex_dirs() -> None:
    for directory in (
        _olvex_config_dir(),
        _olvex_state_dir(),
        _olvex_cache_dir(),
        _olvex_data_dir(),
        _olvex_state_dir() / "wallpaper",
        _live_thumb_dir(),
        _olvex_config_dir() / "templates",
        _olvex_state_dir() / "theme",
        _olvex_state_dir() / "record",
        _olvex_cache_dir() / "schemes",
        _olvex_cache_dir() / "wallpapers",
        _olvex_cache_dir() / "screenshots",
    ):
        directory.mkdir(parents=True, exist_ok=True)


def _ensure_cli_json() -> None:
    cli_path = _olvex_config_dir() / "cli.json"
    if cli_path.is_file():
        return
    payload = {"toggles": {}}
    cli_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


_SCHEME_REQUIRED_KEYS = ("name", "flavour", "mode", "variant", "colours")


def _scheme_payload_is_valid(data: Any) -> bool:
    return isinstance(data, dict) and all(key in data for key in _SCHEME_REQUIRED_KEYS)


def _propagate_olvex_paths() -> None:
    """Re-sync path objects imported via `from caelestia.utils.paths import …`."""
    import sys

    import caelestia.utils.paths as paths

    path_names = [
        name
        for name in vars(paths)
        if not name.startswith("_") and isinstance(getattr(paths, name), Path)
    ]

    for module in list(sys.modules.values()):
        if module is None:
            continue
        qualname = getattr(module, "__name__", "")
        if not qualname.startswith("caelestia"):
            continue
        for name in path_names:
            if hasattr(module, name):
                setattr(module, name, getattr(paths, name))

    try:
        import caelestia.utils.scheme as scheme_mod

        scheme_mod.scheme = None
    except ImportError:
        pass


def _ensure_scheme_json() -> None:
    scheme_path = _olvex_state_dir() / "scheme.json"
    if scheme_path.is_file():
        try:
            payload = json.loads(scheme_path.read_text(encoding="utf-8"))
            if _scheme_payload_is_valid(payload):
                return
        except (OSError, json.JSONDecodeError):
            pass

    from caelestia.utils.scheme import Scheme

    scheme_path.parent.mkdir(parents=True, exist_ok=True)
    Scheme(None).save()


def _apply_olvex_paths() -> None:
    import caelestia.utils.paths as paths

    config_dir = _xdg_config_home()
    data_dir = _xdg_data_home()
    state_dir = _xdg_state_home()
    cache_dir = _xdg_cache_home()
    pictures_dir = Path(os.environ.get("XDG_PICTURES_DIR", _home() / "Pictures"))
    videos_dir = Path(os.environ.get("XDG_VIDEOS_DIR", _home() / "Videos"))

    paths.config_dir = config_dir
    paths.data_dir = data_dir
    paths.state_dir = state_dir
    paths.cache_dir = cache_dir
    paths.pictures_dir = pictures_dir
    paths.videos_dir = videos_dir

    paths.c_config_dir = config_dir / OLVEX_NAME
    paths.c_data_dir = data_dir / OLVEX_NAME
    paths.c_state_dir = state_dir / OLVEX_NAME
    paths.c_cache_dir = cache_dir / OLVEX_NAME

    paths.user_config_path = paths.c_config_dir / "cli.json"
    paths.user_templates_dir = paths.c_config_dir / "templates"
    paths.theme_dir = paths.c_state_dir / "theme"

    paths.scheme_path = paths.c_state_dir / "scheme.json"
    paths.scheme_cache_dir = paths.c_cache_dir / "schemes"

    wallpapers_env = os.environ.get("OLVEX_WALLPAPERS_DIR") or os.environ.get("CAELESTIA_WALLPAPERS_DIR")
    paths.wallpapers_dir = Path(wallpapers_env) if wallpapers_env else pictures_dir / "Wallpapers"
    paths.wallpaper_path_path = paths.c_state_dir / "wallpaper" / "path.txt"
    paths.wallpaper_link_path = paths.c_state_dir / "wallpaper" / "current"
    paths.wallpaper_thumbnail_path = paths.c_state_dir / "wallpaper" / "thumbnail.jpg"
    paths.wallpapers_cache_dir = paths.c_cache_dir / "wallpapers"

    screenshots_env = os.environ.get("OLVEX_SCREENSHOTS_DIR") or os.environ.get("CAELESTIA_SCREENSHOTS_DIR")
    paths.screenshots_dir = Path(screenshots_env) if screenshots_env else pictures_dir / "Screenshots"
    paths.screenshots_cache_dir = paths.c_cache_dir / "screenshots"

    recordings_env = os.environ.get("OLVEX_RECORDINGS_DIR") or os.environ.get("CAELESTIA_RECORDINGS_DIR")
    paths.recordings_dir = Path(recordings_env) if recordings_env else videos_dir / "Recordings"
    paths.recording_path = paths.c_state_dir / "record" / "recording.mp4"
    paths.recording_notif_path = paths.c_state_dir / "record" / "notifid.txt"


def _rewrite_qs_cmd(cmd: Sequence[Any]) -> list[Any]:
    seq = list(cmd)
    qs_instance = os.environ.get("OLVEX_QS_INSTANCE", OLVEX_NAME)
    i = 0
    while i < len(seq):
        if (
            seq[i] == "qs"
            and i + 2 < len(seq)
            and seq[i + 1] == "-c"
            and seq[i + 2] == "caelestia"
        ):
            seq[i + 2] = qs_instance
        i += 1
    return seq


_KONSOLE_COLOUR_KEYS = (
    "klink",
    "klinkSelection",
    "kvisited",
    "kvisitedSelection",
    "knegative",
    "knegativeSelection",
    "kneutral",
    "kneutralSelection",
    "kpositive",
    "kpositiveSelection",
)


def _patch_apply_colours() -> None:
    """Ensure Konsole/Qt templates always receive resolved k* colours."""
    import caelestia.utils.theme as theme_mod
    from caelestia.utils.scheme import get_scheme

    original = theme_mod.apply_colours

    def apply_colours_proxy(colours: dict[str, str], mode: str) -> None:
        merged = dict(colours)
        if not all(key in merged for key in _KONSOLE_COLOUR_KEYS):
            scheme = get_scheme()
            try:
                scheme._update_colours()
                full = dict(scheme.colours)
                for key, value in merged.items():
                    full[key] = value
                merged = full
            except (ValueError, OSError, KeyError):
                pass
        return original(merged, mode)

    theme_mod.apply_colours = apply_colours_proxy  # type: ignore[assignment]


def _patch_subprocess_qs() -> None:
    run = subprocess.run
    check_output = subprocess.check_output
    popen = subprocess.Popen

    def run_proxy(*args: Any, **kwargs: Any):
        if args:
            args = (_rewrite_qs_cmd(args[0]), *args[1:])
        return run(*args, **kwargs)

    def check_output_proxy(*args: Any, **kwargs: Any):
        if args:
            args = (_rewrite_qs_cmd(args[0]), *args[1:])
        return check_output(*args, **kwargs)

    def popen_proxy(*args: Any, **kwargs: Any):
        if args:
            args = (_rewrite_qs_cmd(args[0]), *args[1:])
        return popen(*args, **kwargs)

    subprocess.run = run_proxy  # type: ignore[assignment]
    subprocess.check_output = check_output_proxy  # type: ignore[assignment]
    subprocess.Popen = popen_proxy  # type: ignore[assignment]


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
    _ensure_olvex_dirs()
    _ensure_cli_json()
    _apply_olvex_paths()
    _propagate_olvex_paths()
    _ensure_scheme_json()
    _patch_apply_colours()
    _patch_subprocess_qs()
    _allow_truncated_images()
    argv = _patch_wallpaper_print(sys.argv[1:])
    sys.argv = ["olvex", *argv]

    from caelestia import main as backend_main

    backend_main()


if __name__ == "__main__":
    main()