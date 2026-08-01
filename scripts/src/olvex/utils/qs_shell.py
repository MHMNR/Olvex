"""Resolve how to talk to the running Olvex Quickshell instance.

Development typically launches::

    qs -p /path/to/Olvex/

while older CLI code always used ``qs -c olvex`` (installed config under
``~/.config/quickshell/olvex``). Those are different instances — IPC to the
wrong one fails with "No running instances".

Resolution order:
1. ``OLVEX_SHELL`` / ``QS_CONFIG_PATH`` env (explicit shell.qml or config dir)
2. Running instance whose config path looks like Olvex (prefer project tree)
3. Project ``shell.qml`` next to this repo (``scripts/../shell.qml``)
4. ``qs -c $OLVEX_QS_INSTANCE`` (default ``olvex``) for packaged installs
"""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path


def _project_shell_qml() -> Path:
    # .../Olvex/scripts/src/olvex/utils/qs_shell.py → parents[4] = Olvex/
    return Path(__file__).resolve().parents[4] / "shell.qml"


def _installed_shell_qml() -> Path:
    xdg = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return xdg / "quickshell" / "olvex" / "shell.qml"


def _list_running_config_paths() -> list[Path]:
    try:
        out = subprocess.check_output(
            ["qs", "list", "--all"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

    paths: list[Path] = []
    for line in out.splitlines():
        line = line.strip()
        if not line.lower().startswith("config path:"):
            continue
        raw = line.split(":", 1)[1].strip()
        if not raw:
            continue
        paths.append(Path(raw).expanduser())
    return paths


def _score_path(path: Path, project: Path) -> int:
    """Higher = better match for the live Olvex shell."""
    try:
        resolved = path.resolve()
    except OSError:
        resolved = path

    score = 0
    s = str(resolved)
    low = s.lower()

    if resolved == project.resolve() if project.is_file() else Path():
        score += 100
    if project.is_file() and resolved == project.parent.resolve():
        score += 95
    if "qs-config" in low and "olvex" in low:
        score += 50
    if "/olvex/" in low or low.endswith("/olvex"):
        score += 30
    if "shell.qml" in low:
        score += 10
    if "quickshell/olvex" in low:
        score += 20  # installed copy — valid but prefer project when both run
    return score


def resolve_shell_target() -> tuple[str, str]:
    """Return (mode, value) where mode is ``-p`` or ``-c``."""
    env = os.environ.get("OLVEX_SHELL") or os.environ.get("QS_CONFIG_PATH")
    if env:
        p = Path(env).expanduser()
        if p.exists():
            return "-p", str(p.resolve())

    project = _project_shell_qml()
    running = _list_running_config_paths()
    if running:
        best = max(running, key=lambda p: _score_path(p, project))
        if _score_path(best, project) > 0:
            # qs -p accepts file or directory
            return "-p", str(best.resolve())

    if project.is_file():
        return "-p", str(project.resolve())

    installed = _installed_shell_qml()
    if installed.is_file():
        return "-p", str(installed.resolve())

    name = os.environ.get("OLVEX_QS_INSTANCE", os.environ.get("QS_CONFIG_NAME", "olvex"))
    return "-c", name


def qs_prefix() -> list[str]:
    """Args to select the Olvex shell: ``['qs', '-p', path]`` or ``['qs', '-c', name]``."""
    mode, value = resolve_shell_target()
    return ["qs", mode, value]


def qs_run(args: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run([*qs_prefix(), *args], **kwargs)


def qs_check_output(args: list[str], **kwargs) -> str:
    return subprocess.check_output([*qs_prefix(), *args], text=True, **kwargs)


def qs_popen(args: list[str], **kwargs) -> subprocess.Popen:
    return subprocess.Popen([*qs_prefix(), *args], **kwargs)
