# Playground wasm

Sources for the two WebAssembly modules the playground loads from `docs/playground/wasm/`:

| Module | Source | Used by |
| --- | --- | --- |
| `luau-lsp.js` / `.wasm` | [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) + `src/LspWasm.cpp` | `docs/playground/lsp.worker.js` (autocomplete, hover, signature help, lint) |
| `luau-run.js` / `.wasm` | Luau VM + `src/RunWasm.cpp` | `docs/playground/run.worker.js` (Run Local) |

`LspWasm.cpp` runs the real luau-lsp `LanguageServer` in-process: the worker passes each JSON-RPC
message to `lsp_send` and gets back a JSON array of everything the server sent. Wasm has no
threads, so `include/Thread.hpp` replaces luau-lsp's thread wrapper and the server's message
thread never starts.

`lsp_set_imports` maps `io.import("<spec>")` to packages the page downloaded itself
(`docs/playground/imports.js`): the worker writes their scripts to the in-memory workspace and adds
them to `sourcemap.json`, and an `ImportResolver` in front of luau-lsp's file resolver points the
call at that sourcemap node, so `script.Parent` requires inside the package resolve normally. A magic
function on `io.import` returns the same node's instance type, so `io.import(...)` itself has children.

`require("@lune/<lib>")` resolves through a `.luaurc` alias the worker writes into the workspace,
pointing at `docs/playground/lune/`: Lune's own typedefs, copied from
`crates/lune-std-<lib>/types.d.luau` at the Lune tag the bot runs (v0.11.0).

`build.sh` also refreshes `docs/playground/globalTypes.d.luau` (the `None` security variant) and
`docs/playground/api-docs.json` from the same luau-lsp release, so types and docs match the server.

## Building

Needs [emsdk](https://emscripten.org/docs/getting_started/downloads.html), CMake 3.19+ and Ninja on
Linux, macOS or WSL:

```sh
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
~/emsdk/emsdk install latest && ~/emsdk/emsdk activate latest
source ~/emsdk/emsdk_env.sh

./lsp/build.sh                    # luau-lsp release pinned in build.sh (LSP_TAG)
LSP_TAG=1.71.0 ./lsp/build.sh     # or another release tag
```

The first build clones luau-lsp into `~/.cache/playground-wasm` and takes a few minutes; later
builds are incremental. Commit the changed files under `docs/playground/`.

## Upgrading luau-lsp

1. Bump `LSP_TAG` in `build.sh` and run it.
2. If the build breaks, check what luau-lsp changed in `src/include/Thread.hpp`, `LSPClient`,
   `LanguageServer::handleMessage` or `parseDocumentation`; those are the only APIs the glue uses.
3. Load `docs/playground.html` from a local server (`python -m http.server` in `docs/`) and check
   the console for `[lsp]` errors, especially failed definitions files: `botTypes.d.luau` is
   written by hand and has to keep up with luau-lsp's definition syntax (`declare extern type`,
   `Enum.X` enum types).
