#!/bin/bash
# Developer cheat: give a Reel Rush save slot one of everything.
#   tools/grant-all.sh 2                 # supercharge slot 2 (keeps its name and progress, backs it up first)
#   tools/grant-all.sh 3 --name TESTER   # fresh/renamed save in slot 3
#   tools/grant-all.sh --restore 2 build/slot2-backup-<time>.json
set -euo pipefail
cd "$(dirname "$0")/.."

#   REELRUSH_PREFS_DOMAIN=some.test.domain overrides where saves are read/written (for testing).
WRITES=1
case "${1:-}" in ""|-h|--help) WRITES=0 ;; esac
if [ "$WRITES" = 1 ] && [ -z "${REELRUSH_PREFS_DOMAIN:-}" ] && pgrep -x ReelRush >/dev/null; then
    echo "Quit Reel Rush first - it would overwrite the save when it closes." >&2
    exit 1
fi

BIN=build/grant-all
SRCS=$(ls Sources/ReelRush/*.swift | grep -v '/main.swift$')
mkdir -p build
# Rebuild only when the game or the tool has changed.
if [ ! -x "$BIN" ] || [ -n "$(find Sources/ReelRush tools/grant-all -name '*.swift' -newer "$BIN")" ]; then
    echo "▸ Compiling grant-all…"
    # shellcheck disable=SC2086
    swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
        -framework AppKit -framework SpriteKit \
        $SRCS tools/grant-all/main.swift -o "$BIN"
fi
"$BIN" "$@"
