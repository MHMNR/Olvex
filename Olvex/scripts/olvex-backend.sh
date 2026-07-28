#!/usr/bin/env bash
# Internal Olvex Python CLI backend.
# User-facing entry point is `olvex`; this script invokes the Python module only.

set -euo pipefail

_olvex_home="${HOME:?}"

# Olvex uses native XDG dirs (~/.config/olvex, ~/.local/state/olvex, …).
# Never symlink olvex → caelestia; break stale migration symlinks from older builds.
_olvex_ensure_native_tree() {
    local base="$1"
    local link="${base}/olvex"

    [ -e "$base" ] || mkdir -p "$base"

    if [ -L "$link" ]; then
        echo "[olvex] Removing stale symlink: ${link}" >&2
        rm -f "$link"
    fi

    mkdir -p "$link"
}

# Drop nested caelestia symlinks inside ~/.cache/olvex (legacy split-cache layout).
_olvex_prune_caelestia_links() {
    local root="$1"
    [ -d "$root" ] || return 0

    local entry target
    for entry in "$root"/*; do
        [ -e "$entry" ] || continue
        [ -L "$entry" ] || continue
        target="$(readlink -f "$entry" 2>/dev/null || readlink "$entry")"
        case "$target" in
            *caelestia*)
                echo "[olvex] Removing nested caelestia symlink: ${entry}" >&2
                rm -f "$entry"
                ;;
        esac
    done
}

_olvex_ensure_xdg_dirs() {
    local state_base="${XDG_STATE_HOME:-${_olvex_home}/.local/state}"
    local config_base="${XDG_CONFIG_HOME:-${_olvex_home}/.config}"
    local cache_base="${XDG_CACHE_HOME:-${_olvex_home}/.cache}"
    local data_base="${XDG_DATA_HOME:-${_olvex_home}/.local/share}"

    _olvex_ensure_native_tree "$state_base"
    _olvex_ensure_native_tree "$config_base"
    _olvex_ensure_native_tree "$cache_base"
    _olvex_ensure_native_tree "$data_base"
    _olvex_prune_caelestia_links "${cache_base}/olvex"
}

if ! python3 -c "import caelestia" >/dev/null 2>&1; then
    echo "Olvex Python backend unavailable. Install olvex-cli." >&2
    exit 1
fi

_olvex_ensure_xdg_dirs

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
export OLVEX_QS_INSTANCE="${OLVEX_QS_INSTANCE:-olvex}"
exec python3 "${SCRIPT_DIR}/olvex-backend.py" "$@"