#!/usr/bin/env bash
# Internal Olvex Python CLI backend.
# User-facing entry point is `olvex`; this script invokes the Python module only.

set -euo pipefail

_olvex_home="${HOME:?}"

_olvex_ensure_path_link() {
    local base="$1"
    local name="$2"
    local target="${base}/${name}"
    local link="${base}/olvex"

    [ -e "$base" ] || mkdir -p "$base"

    if [ -L "$link" ]; then
        return 0
    fi

    if [ -d "$target" ] || [ -f "$target" ]; then
        ln -sfn "$target" "$link"
    fi
}

_olvex_ensure_xdg_links() {
    local state_base="${XDG_STATE_HOME:-${_olvex_home}/.local/state}"
    local config_base="${XDG_CONFIG_HOME:-${_olvex_home}/.config}"
    local cache_base="${XDG_CACHE_HOME:-${_olvex_home}/.cache}"
    local data_base="${XDG_DATA_HOME:-${_olvex_home}/.local/share}"

    _olvex_ensure_path_link "$state_base" "caelestia"
    _olvex_ensure_path_link "$config_base" "caelestia"
    _olvex_ensure_path_link "$cache_base" "caelestia"
    _olvex_ensure_path_link "$data_base" "caelestia"
}

if ! python3 -c "import caelestia" >/dev/null 2>&1; then
    echo "Olvex Python backend unavailable. Install olvex-cli." >&2
    exit 1
fi

_olvex_ensure_xdg_links

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
exec python3 "${SCRIPT_DIR}/olvex-backend.py" "$@"