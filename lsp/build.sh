#!/usr/bin/env bash
# Builds the playground's wasm (luau-lsp + Run Local VM) and refreshes the type files it loads.
# Needs emsdk activated (emcmake on PATH), cmake >= 3.19 and ninja. See README.md.
set -euo pipefail

# luau-lsp 1.70.1 bundles Luau 0.740; the playground runs luau-lsp main with Luau 0.747 (Studio 0.747),
# plus patches/ for Luau API changes. LSP_REF is a luau-lsp tag or branch; LUAU_TAG overrides its Luau
# (empty keeps the one luau-lsp pins).
LSP_REF="${LSP_REF:-main}"
LUAU_TAG="${LUAU_TAG-0.747}"
LSP_TAG="${LSP_TAG:-$LSP_REF-${LUAU_TAG:-pinned}}"
WORK="${WORK:-$HOME/.cache/playground-wasm}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PLAYGROUND="$HERE/../docs/playground"
SRC="$WORK/luau-lsp-$LSP_TAG"
BUILD="$WORK/build-$LSP_TAG"

command -v emcmake >/dev/null || { echo "emcmake not found: source <emsdk>/emsdk_env.sh first" >&2; exit 1; }

if [ ! -d "$SRC" ]; then
    git clone --depth 1 --branch "$LSP_REF" --recurse-submodules --shallow-submodules \
        https://github.com/JohnnyMorganz/luau-lsp.git "$SRC"
    if [ -n "$LUAU_TAG" ]; then
        git -C "$SRC/luau" fetch --depth 1 origin tag "$LUAU_TAG"
        git -C "$SRC/luau" checkout -q "$LUAU_TAG"
        for patch in "$HERE"/patches/*.patch; do
            [ -e "$patch" ] && git -C "$SRC" apply "$patch"
        done
        # patches/luau/ applies to Luau itself (the luau submodule).
        for patch in "$HERE"/patches/luau/*.patch; do
            [ -e "$patch" ] && git -C "$SRC/luau" apply "$patch"
        done
    fi
fi

emcmake cmake -S "$HERE" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release -DLUAU_LSP_SOURCE="$SRC"
cmake --build "$BUILD" --target luau-lsp luau-run

mkdir -p "$PLAYGROUND/wasm"
cp "$BUILD"/luau-lsp.js "$BUILD"/luau-lsp.wasm "$BUILD"/luau-run.js "$BUILD"/luau-run.wasm "$PLAYGROUND/wasm/"
# Scripts the bot runs have normal script security, so skip plugin/Roblox-only members (also loads ~35% faster).
cp "$SRC/scripts/globalTypes.None.d.luau" "$PLAYGROUND/globalTypes.d.luau"
cp "$SRC/scripts/api-docs/en-us.json" "$PLAYGROUND/api-docs.json"

ls -l "$PLAYGROUND"/wasm "$PLAYGROUND/globalTypes.d.luau" "$PLAYGROUND/api-docs.json"
