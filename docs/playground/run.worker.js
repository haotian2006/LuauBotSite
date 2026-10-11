// Run Local: runs a script on the Luau VM in wasm/luau-run.wasm (built from ../../lsp).
// The page terminates this worker to stop a run, so the language server never has to restart.
//
// page → worker  { type: "run", name, code, modules: [{ name, code }], fflags }
// worker → page  { type: "output", kind: "print" | "warn" | "error", text }, then { type: "done" }

importScripts("wasm/luau-run.js");

const KINDS = ["print", "warn", "error"];

const moduleReady = createLuauRun({
  locateFile: path => "wasm/" + path,
  onOutput: (kind, text) => self.postMessage({ type: "output", kind: KINDS[kind], text }),
});

function withStrings(mod, strings, fn) {
  const ptrs = strings.map(s => mod.stringToNewUTF8(s));
  try {
    return fn(...ptrs);
  } finally {
    ptrs.forEach(ptr => mod._free(ptr));
  }
}

async function run({ name, code, modules, fflags }) {
  const mod = await moduleReady;
  for (const [flag, value] of Object.entries(fflags || {})) {
    withStrings(mod, [flag], ptr => mod._run_set_flag(ptr, value === "true" ? 1 : 0));
  }
  mod._run_reset();
  for (const module of modules) {
    withStrings(mod, [module.name, module.code], (n, c) => mod._run_add_module(n, c));
  }
  withStrings(mod, [name, code], (n, c) => mod._run_start(n, c));
  // run_step resumes whatever is due and says how long until the next task wakes up.
  for (let wait = mod._run_step(); wait >= 0; wait = mod._run_step()) {
    await new Promise(resolve => setTimeout(resolve, wait));
  }
  self.postMessage({ type: "done" });
}

self.onmessage = ({ data }) => {
  if (data.type === "run") {
    run(data).catch(err => {
      self.postMessage({ type: "output", kind: "error", text: String(err) });
      self.postMessage({ type: "done" });
    });
  }
};
