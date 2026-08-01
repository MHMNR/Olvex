#!/usr/bin/env bash
# Install the olvex CLI system-wide (/usr/local/bin) so every terminal finds it.
# Usage:
#   sudo ./scripts/install-cli.sh
#   sudo ./scripts/install-cli.sh --user   # only ~/.local/bin (no root)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SRC="${SCRIPT_DIR}/olvex"

if [ ! -x "$SRC" ]; then
    echo "Missing executable: $SRC" >&2
    exit 1
fi

install_link() {
    local dest_dir="$1"
    mkdir -p "$dest_dir"
    ln -sfn "$SRC" "${dest_dir}/olvex"
    # Follow symlink for chmod on the real script when we own it
    if [ -w "$SRC" ]; then
        chmod 755 "$SRC"
    fi
    echo "Installed: ${dest_dir}/olvex -> ${SRC}"
}

MODE="${1:-}"
if [ "$MODE" = "--user" ]; then
    install_link "${HOME}/.local/bin"
else
    if [ "$(id -u)" -ne 0 ]; then
        echo "System-wide install needs root. Re-run:" >&2
        echo "  sudo $0" >&2
        echo "Or user-only:" >&2
        echo "  $0 --user" >&2
        exit 1
    fi
    install_link /usr/local/bin
    # Mirror into invoking user's ~/.local/bin when sudo -H isn't wiping HOME oddly
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ]; then
        user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
        if [ -n "$user_home" ]; then
            install_link "${user_home}/.local/bin"
            chown -h "${SUDO_USER}:${SUDO_USER}" "${user_home}/.local/bin/olvex" 2>/dev/null || true
        fi
    fi
fi

echo
if command -v olvex >/dev/null 2>&1; then
    echo "which: $(command -v olvex)"
    olvex -h 2>&1 | head -12 || true
else
    echo "olvex not on current PATH yet; open a new terminal or: hash -r"
    echo "Expected: /usr/local/bin/olvex"
fi
