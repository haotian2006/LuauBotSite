// luau-lsp.worker.js — uses the luau-lsp WASM for full Roblox type inference

importScripts("wasm/luau-lsp.js");

let mod = null;

// Start WASM download+compile immediately on worker creation.
// This runs in parallel with the main thread fetching definition files,
// saving ~1-2s of wall-clock time vs waiting for the init message.
const wasmReady = (async () => {
  console.log("[lsp-worker] loading WASM...");
  const t0 = performance.now();
  mod = await createLuauModule({
    locateFile: (path) => "wasm/" + path,
    print: (s) => console.log("[lsp]", s),
    printErr: (s) => console.warn("[lsp-err]", s),
  });
  console.log(
    "[lsp-worker] WASM loaded in " +
      ((performance.now() - t0) / 1000).toFixed(1) +
      "s",
  );
})();

self.onmessage = async (e) => {
  const { requestId, ...msg } = e.data;
  try {
    switch (msg.type) {
      case "init": {
        await wasmReady; // usually already done by the time definitions arrive
        self.postMessage({ requestId, type: "ready" });

        const t0 = performance.now();
        if (msg.definitions) {
          console.log(
            "[lsp-worker] loading definitions (" +
              msg.definitions.length +
              " chars)...",
          );
          const ptr = mod.stringToNewUTF8(msg.definitions);
          mod._luau_set_definitions(ptr);
          mod._free(ptr);
        }
        if (msg.extraDefinitions) {
          for (const { name, source } of msg.extraDefinitions) {
            const namePtr = mod.stringToNewUTF8(name);
            const srcPtr = mod.stringToNewUTF8(source);
            mod._luau_add_definitions(namePtr, srcPtr);
            mod._free(namePtr);
            mod._free(srcPtr);
          }
        }
        console.log(
          "[lsp-worker] definitions ready in " +
            ((performance.now() - t0) / 1000).toFixed(1) +
            "s",
        );
        self.postMessage({ requestId: 0, type: "definitions_ready" });

        if (msg.solver !== undefined) {
          mod._luau_set_solver(msg.solver);
        }
        break;
      }

      case "autocomplete": {
        const raw = mod.ccall(
          "luau_autocomplete",
          "string",
          ["string", "number", "number"],
          [msg.code, msg.line, msg.col],
        );
        self.postMessage({
          requestId,
          type: "autocomplete",
          result: raw ? JSON.parse(raw) : null,
        });
        break;
      }

      case "hover": {
        const raw = mod.ccall(
          "luau_hover",
          "string",
          ["string", "number", "number"],
          [msg.code, msg.line, msg.col],
        );
        self.postMessage({
          requestId,
          type: "hover",
          result: raw ? JSON.parse(raw) : null,
        });
        break;
      }

      case "signature_help": {
        const raw = mod.ccall(
          "luau_signature_help",
          "string",
          ["string", "number", "number"],
          [msg.code, msg.line, msg.col],
        );
        self.postMessage({
          requestId,
          type: "signature_help",
          result: raw ? JSON.parse(raw) : null,
        });
        break;
      }

      case "set_solver": {
        if (mod) mod._luau_set_solver(msg.solver);
        self.postMessage({ requestId, type: "set_solver" });
        break;
      }

      case "set_sourcemap": {
        if (msg.json) {
          const ptr = mod.stringToNewUTF8(msg.json);
          mod._luau_set_sourcemap(ptr);
          mod._free(ptr);
        } else {
          // empty string = clear
          const ptr = mod.stringToNewUTF8("");
          mod._luau_set_sourcemap(ptr);
          mod._free(ptr);
        }
        self.postMessage({ requestId, type: "set_sourcemap" });
        break;
      }

      case "add_definitions": {
        const namePtr = mod.stringToNewUTF8(msg.name);
        const srcPtr = mod.stringToNewUTF8(msg.source);
        mod._luau_add_definitions(namePtr, srcPtr);
        mod._free(namePtr);
        mod._free(srcPtr);
        self.postMessage({ requestId, type: "add_definitions" });
        break;
      }

      case "set_source": {
        const namePtr = mod.stringToNewUTF8(msg.name);
        const codePtr = mod.stringToNewUTF8(msg.code);
        mod._luau_set_source(namePtr, codePtr);
        mod._free(namePtr);
        mod._free(codePtr);
        self.postMessage({ requestId, type: "set_source" });
        break;
      }

      case "clear_sources": {
        mod._luau_clear_sources();
        self.postMessage({ requestId, type: "clear_sources" });
        break;
      }

      case "run": {
        const raw = mod.ccall("luau_run", "string", ["string"], [msg.code]);
        self.postMessage({
          requestId,
          type: "run",
          result: raw ? JSON.parse(raw) : null,
        });
        break;
      }

      case "diagnostics": {
        const raw = mod.ccall(
          "luau_get_diagnostics",
          "string",
          ["string"],
          [msg.code],
        );
        self.postMessage({
          requestId,
          type: "diagnostics",
          result: raw ? JSON.parse(raw) : [],
        });
        break;
      }

      default:
        self.postMessage({
          requestId,
          type: "error",
          error: `Unknown: ${msg.type}`,
        });
    }
  } catch (err) {
    console.error("[lsp-worker] error in", msg.type, err);
    self.postMessage({ requestId, type: "error", error: String(err) });
  }
};
