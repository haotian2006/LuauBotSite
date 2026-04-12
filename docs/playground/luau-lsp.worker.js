// luau-lsp.worker.js — uses the luau-lsp WASM for full Roblox type inference

importScripts('wasm/luau-lsp.js');

let mod = null;

self.onmessage = async (e) => {
  const { requestId, ...msg } = e.data;
  try {
    switch (msg.type) {

      case 'init': {
        console.log('[lsp-worker] init: loading WASM...');
        mod = await createLuauModule({
          locateFile: path => 'wasm/' + path,
          print:    s => console.log('[lsp]', s),
          printErr: s => console.warn('[lsp-err]', s),
        });
        console.log('[lsp-worker] WASM loaded');

        // Signal ready immediately — static maps handle completions while definitions load
        self.postMessage({ requestId, type: 'ready' });

        // Load definitions in background (synchronous WASM call, takes a few seconds)
        if (msg.definitions) {
          console.log('[lsp-worker] loading definitions (' + msg.definitions.length + ' chars)...');
          const enc = new TextEncoder().encode(msg.definitions);
          const ptr = mod._malloc(enc.length + 1);
          const heap = new Uint8Array(mod.wasmMemory.buffer, ptr, enc.length + 1);
          heap.set(enc);
          heap[enc.length] = 0;
          mod._luau_set_definitions(ptr);
          mod._free(ptr);
          console.log('[lsp-worker] definitions ready');
          self.postMessage({ requestId: 0, type: 'definitions_ready' });
        }
        break;
      }

      case 'autocomplete': {
        const raw = mod.ccall('luau_autocomplete', 'string',
          ['string', 'number', 'number'], [msg.code, msg.line, msg.col]);
        self.postMessage({ requestId, type: 'autocomplete', result: raw ? JSON.parse(raw) : null });
        break;
      }

      case 'hover': {
        const raw = mod.ccall('luau_hover', 'string',
          ['string', 'number', 'number'], [msg.code, msg.line, msg.col]);
        self.postMessage({ requestId, type: 'hover', result: raw ? JSON.parse(raw) : null });
        break;
      }

      default:
        self.postMessage({ requestId, type: 'error', error: `Unknown: ${msg.type}` });
    }
  } catch(err) {
    console.error('[lsp-worker] error in', msg.type, err);
    self.postMessage({ requestId, type: 'error', error: String(err) });
  }
};
