// Runs luau-lsp (wasm/luau-lsp.wasm, built from ../../lsp) and speaks plain LSP JSON-RPC with the page.
//
// page → worker  { type: "start", options }            once, as early as possible
//                { type: "rpc", message }               any LSP request or notification
//                { type: "sourcemap", json }            replaces sourcemap.json (null clears it)
//                { type: "imports", imports }           downloaded io.import packages (see imports.js)
// worker → page  { type: "rpc", messages }              responses and server notifications
//                { type: "ready", ms }                  definitions are loaded
//                { type: "failed" | "crashed", error }  startup failed / the wasm trapped

importScripts("wasm/luau-lsp.js");

const WORKSPACE = "/workspace";
const ROOT_URI = "file:///workspace";
// Requests where only the newest one per document matters; older queued copies are cancelled.
const SUPERSEDABLE = new Set([
  "textDocument/completion",
  "textDocument/hover",
  "textDocument/signatureHelp",
  "textDocument/diagnostic",
]);
const REQUEST_CANCELLED = -32800;

const t0 = performance.now();
const fetchText = url => fetch(url).then(r => {
  if (!r.ok) throw new Error(`${url}: ${r.status}`);
  return r.text();
});

const moduleReady = createLuauLsp({
  locateFile: path => "wasm/" + path,
  print: text => console.log("[lsp]", text),
  printErr: text => console.warn("[lsp]", text),
});

let mod = null; // set once the server has been started
const queue = [];

function call(name, text) {
  const ptr = mod.stringToNewUTF8(text);
  try {
    return JSON.parse(mod.UTF8ToString(mod[name](ptr)));
  } finally {
    mod._free(ptr);
  }
}

function forward(messages) {
  const out = [];
  for (const message of messages) {
    if (message.method === "window/logMessage" || message.method === "window/showMessage") {
      const { type, message: text } = message.params;
      if (type === 1) console.error("[lsp]", text);
      else if (type === 2) console.warn("[lsp]", text);
      else console.debug("[lsp]", text);
    } else if (message.method !== "$/logTrace") {
      out.push(message);
    }
  }
  if (out.length) self.postMessage({ type: "rpc", messages: out });
}

// The bot has Lune runs turned off, so --!lune is a no-op: say so instead of luau-lsp's unknown-directive warning.
const LUNE_DIRECTIVE = /Unknown comment directive 'lune'/;
const markLuneDirective = list => list?.map(d => LUNE_DIRECTIVE.test(d.message)
  ? { ...d, severity: 3, message: "--!lune does nothing: Lune runs are turned off, so this runs on Roblox" }
  : d);

function patchReply(message, request) {
  if (message.method === "textDocument/publishDiagnostics") {
    message.params.diagnostics = markLuneDirective(message.params.diagnostics);
  } else if (message.id === request?.id && request.method === "textDocument/diagnostic" && message.result) {
    message.result.items = markLuneDirective(message.result.items);
  }
  return message;
}

function send(message) {
  const replies = call("_lsp_send", JSON.stringify({ jsonrpc: "2.0", ...message }));
  forward(replies.map(reply => patchReply(reply, message)));
}

// String requires only resolve to files that exist, so every open document gets a placeholder on disk.
function trackFile(message) {
  const uri = message.params?.textDocument?.uri;
  if (!uri?.startsWith(ROOT_URI + "/")) return;
  const path = WORKSPACE + decodeURIComponent(uri.slice(ROOT_URI.length));
  if (message.method === "textDocument/didOpen") {
    mod.FS.mkdirTree(path.slice(0, path.lastIndexOf("/")));
    mod.FS.writeFile(path, "");
  } else if (message.method === "textDocument/didClose") {
    try { mod.FS.unlink(path); } catch { }
  }
}

// sourcemap.json is the user's sourcemap plus a folder holding downloaded io.import packages.
// Without a user sourcemap an empty DataModel stands in, which also clears the old one's types.
const IMPORTS_FOLDER = "PlaygroundImports";
let userSourcemap = null;
let importNodes = [];

function sourcemapRoot() {
  let root = null;
  try { root = userSourcemap && JSON.parse(userSourcemap); } catch { }
  root ||= { name: "Default", className: "DataModel", children: [] };
  if (importNodes.length) {
    const children = (root.children || []).filter(child => child.name !== IMPORTS_FOLDER);
    root = { ...root, children: [...children, { name: IMPORTS_FOLDER, className: "Folder", children: importNodes }] };
  }
  return root;
}

function writeSourcemap() {
  const path = WORKSPACE + "/sourcemap.json";
  const existed = mod.FS.analyzePath(path).exists;
  mod.FS.writeFile(path, JSON.stringify(sourcemapRoot()));
  // FileChangeType: 1 created, 2 changed
  send({
    method: "workspace/didChangeWatchedFiles",
    params: { changes: [{ uri: ROOT_URI + "/sourcemap.json", type: existed ? 2 : 1 }] },
  });
}

function setSourcemap(json) {
  userSourcemap = json;
  writeSourcemap();
}

// imports: [{ spec, tree }] from imports.js. Scripts become files the sourcemap points at, so
// require(script.Parent.X) inside a package resolves like it does in Studio.
function setImports(imports) {
  const dir = WORKSPACE + "/.imports";
  if (mod.FS.analyzePath(dir).exists) {
    for (const name of mod.FS.readdir(dir)) if (name !== "." && name !== "..") mod.FS.unlink(`${dir}/${name}`);
  } else {
    mod.FS.mkdir(dir);
  }
  let files = 0;
  const toNode = (item, name = item.name) => {
    const sourcemapNode = { name, className: item.className, children: item.children.map(child => toNode(child)) };
    if (item.source !== undefined) {
      const file = `.imports/${files++}.luau`;
      mod.FS.writeFile(`${WORKSPACE}/${file}`, item.source);
      sourcemapNode.filePaths = [file];
    }
    return sourcemapNode;
  };
  importNodes = imports.map(({ tree }, i) => toNode(tree, `import${i}`));
  const root = sourcemapRoot();
  writeSourcemap();
  const prefix = root.className === "DataModel" ? "game" : "ProjectRoot";
  const paths = Object.fromEntries(imports.map(({ spec }, i) => [spec, `${prefix}/${IMPORTS_FOLDER}/import${i}`]));
  forward(call("_lsp_set_imports", JSON.stringify(paths)));
}

function loadDocumentation(json) {
  mod.FS.writeFile("/defs/api-docs.json", json);
  forward(call("_lsp_load_documentation", "/defs/api-docs.json"));
  mod.FS.unlink("/defs/api-docs.json");
}

function isStale(message) {
  if (message.id === undefined || !SUPERSEDABLE.has(message.method)) return false;
  const uri = message.params?.textDocument?.uri;
  return queue.some((later, i) => i > 0 && later.type === "rpc" &&
    later.message.method === message.method && later.message.params?.textDocument?.uri === uri);
}

function handle(item) {
  if (item.type === "sourcemap") return setSourcemap(item.json);
  if (item.type === "imports") return setImports(item.imports);
  if (item.type === "docs") return loadDocumentation(item.json);
  const { message } = item;
  if (isStale(message)) {
    self.postMessage({ type: "rpc", messages: [{ jsonrpc: "2.0", id: message.id, error: { code: REQUEST_CANCELLED, message: "superseded" } }] });
    return;
  }
  trackFile(message);
  send(message);
}

// One message per task, so newer requests can arrive and cancel stale ones in between.
const tick = new MessageChannel();
let pumping = false;
tick.port1.onmessage = () => {
  pumping = false;
  if (!mod || !queue.length) return;
  const item = queue[0];
  try {
    handle(item);
  } catch (err) {
    console.error("[lsp] failed to handle", item, err);
    if (item.message?.id !== undefined) {
      self.postMessage({ type: "rpc", messages: [{ jsonrpc: "2.0", id: item.message.id, error: { code: -32603, message: String(err) } }] });
    }
    // A wasm trap leaves the module unusable; the page starts a fresh worker.
    if (err instanceof WebAssembly.RuntimeError) {
      self.postMessage({ type: "crashed", error: String(err) });
      mod = null;
      return;
    }
  }
  queue.shift();
  pump();
};
function pump() {
  if (pumping || !mod || !queue.length) return;
  pumping = true;
  tick.port2.postMessage(null);
}

function enqueue(item) {
  queue.push(item);
  pump();
}

// Lune's own typedefs (lune-org/lune v0.11.0, crates/lune-std-*/types.d.luau), behind a .luaurc alias.
const LUNE_LIBS = ["datetime", "fs", "luau", "net", "process", "regex", "roblox", "serde", "stdio", "task"];

async function start(options) {
  const [module, roblox, bot, lune] = await Promise.all([
    moduleReady,
    options.roblox ? fetchText("globalTypes.d.luau") : null,
    options.bot ? fetchText("botTypes.d.luau") : null,
    Promise.all(LUNE_LIBS.map(name => fetchText(`lune/${name}.luau`).catch(err => {
      console.warn("[lsp] lune types unavailable:", err);
      return null;
    }))),
  ]);
  const { FS } = module;
  FS.mkdirTree("/defs");
  FS.mkdirTree(WORKSPACE + "/.lune");
  LUNE_LIBS.forEach((name, i) => lune[i] !== null && FS.writeFile(`${WORKSPACE}/.lune/${name}.luau`, lune[i]));
  FS.writeFile(WORKSPACE + "/.luaurc", JSON.stringify({ aliases: { lune: "./.lune" } }));
  const definitions = {};
  for (const [name, source] of [["@roblox", roblox], ["@bot", bot], ["@custom", options.customDefs]]) {
    if (!source) continue;
    const path = `/defs/${name.slice(1)}.d.luau`;
    FS.writeFile(path, source);
    definitions[name] = path;
  }
  userSourcemap = options.sourcemap;
  if (userSourcemap) FS.writeFile(WORKSPACE + "/sourcemap.json", userSourcemap);

  const ptr = module.stringToNewUTF8(JSON.stringify({
    fflags: { ...options.fflags, LuauSolverV2: options.newSolver ? "true" : "false" },
    definitions,
    settings: {
      platform: { type: options.roblox ? "roblox" : "standard" },
      sourcemap: { enabled: !!options.sourcemap, autogenerate: false },
      diagnostics: { includeDependents: false },
      index: { enabled: false },
      completion: {
        // Fragment autocomplete reuses the last full check, so a require added since then stays
        // `any` (even for later hovers). Full checks of playground-sized files are just as fast.
        enableFragmentAutocomplete: false,
        fillCallArguments: false,
        imports: { enabled: true, suggestServices: true, suggestRequires: false },
        anonymousAutofilledFunction: { addTabstopForParameters: false },
      },
    },
  }));
  module._lsp_start(ptr);
  module._free(ptr);
  mod = module;

  send({
    id: 0,
    method: "initialize",
    params: {
      processId: null,
      rootUri: ROOT_URI,
      workspaceFolders: [{ uri: ROOT_URI, name: "playground" }],
      capabilities: {
        general: { positionEncodings: ["utf-16"] },
        textDocument: {
          completion: {
            completionItem: {
              snippetSupport: true,
              documentationFormat: ["markdown", "plaintext"],
              deprecatedSupport: true,
              tagSupport: { valueSet: [1] },
              labelDetailsSupport: true,
            },
          },
          hover: { contentFormat: ["markdown", "plaintext"] },
          signatureHelp: {
            signatureInformation: {
              documentationFormat: ["markdown", "plaintext"],
              parameterInformation: { labelOffsetSupport: true },
              activeParameterSupport: true,
            },
          },
          diagnostic: {},
        },
        // Sourcemap edits arrive as watched-file changes (see setSourcemap).
        workspace: { didChangeWatchedFiles: { dynamicRegistration: true } },
      },
    },
  });
  send({ method: "initialized", params: {} });

  // The workspace loads its definitions when it first sees a document, so open a throwaway
  // one now instead of waiting for the page to finish loading the editor.
  const scratch = { uri: ROOT_URI + "/.playground-init.luau" };
  send({ method: "textDocument/didOpen", params: { textDocument: { ...scratch, languageId: "luau", version: 1, text: "" } } });
  send({ method: "textDocument/didClose", params: { textDocument: scratch } });
  self.postMessage({ type: "ready", ms: Math.round(performance.now() - t0) });
  pump();

  // Docs only feed hovers and completion details, so they load after everything else.
  if (options.roblox) {
    fetchText("api-docs.json")
      .then(json => enqueue({ type: "docs", json }))
      .catch(err => console.warn("[lsp] docs unavailable:", err));
  }
}

self.onmessage = ({ data }) => {
  if (data.type !== "start") return enqueue(data);
  start(data.options).catch(err => {
    console.error("[lsp] failed to start", err);
    self.postMessage({ type: "failed", error: String(err) });
  });
};
