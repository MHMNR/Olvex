#!/usr/bin/env sh

cat ~/.local/state/olvex/sequences.txt 2>/dev/null

exec "$@"
