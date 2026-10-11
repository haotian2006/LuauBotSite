#!/usr/bin/env bash
# Builds the playground's wasm (luau-lsp + Run Local VM) and refreshes the type files it loads.
# Needs emsdk activated (emcmake on PATH), cmake >= 3.19 and ninja. See README.md.
set -euo pipefail

LSP_TAG="${LSP_TAG:-1.70.1}"
WORK="${WORK:-$HOME/.cache/playground-wasm}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PLAYGROUND="$HERE/../docs/playground"
SRC="$WORK/luau-lsp-$LSP_TAG"
BUILD="$WORK/build-$LSP_TAG"

command -v emcmake >/dev/null || { echo "emcmake not found: source <emsdk>/emsdk_env.sh first" >&2; exit 1; }

if [ ! -d "$SRC" ]; then
    git clone --depth 1 --branch "$LSP_TAG" --recurse-submodules --shallow-submodules \
        https://github.com/JohnnyMorganz/luau-lsp.git "$SRC"
fi

emcmake cmake -S "$HERE" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release -DLUAU_LSP_SOURCE="$SRC"
cmake --build "$BUILD" --target luau-lsp luau-run

mkdir -p "$PLAYGROUND/wasm"
cp "$BUILD"/luau-lsp.js "$BUILD"/luau-lsp.wasm "$BUILD"/luau-run.js "$BUILD"/luau-run.wasm "$PLAYGROUND/wasm/"
# Scripts the bot runs have normal script security, so skip plugin/Roblox-only members (also loads ~35% faster).
cp "$SRC/scripts/globalTypes.None.d.luau" "$PLAYGROUND/globalTypes.d.luau"
cp "$SRC/scripts/api-docs/en-us.json" "$PLAYGROUND/api-docs.json"

ls -l "$PLAYGROUND"/wasm "$PLAYGROUND/globalTypes.d.luau" "$PLAYGROUND/api-docs.json"
