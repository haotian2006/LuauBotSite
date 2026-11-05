// Page side of the language server in lsp.worker.js: owns the worker, mirrors CodeMirror docs
// into it as LSP text documents, and wraps the requests the editor makes.
(function () {
  const ROOT_URI = "file:///workspace";
  const WORKER_URL = "playground/lsp.worker.js";
  // Luau features the bot runs with; Run Local turns on the same flags.
  const FFLAGS = { DebugLuauUserDefinedClasses: "true", DebugLuauUserDefinedClassesRuntime: "true" };

  function readSetting(key) {
    try { return localStorage.getItem(key); } catch { return null; }
  }

  // Server options from saved settings. The new solver is the default; "0" means it was turned off.
  function savedOptions() {
    const roblox = readSetting("luau_no_roblox") !== "1";
    return {
      newSolver: readSetting("luau_solver") !== "0",
      roblox,
      bot: roblox && readSetting("luau_no_bot") !== "1",
      customDefs: readSetting("luau_custom_defs") || null,
      sourcemap: readSetting("luau_sourcemap") || null,
      fflags: FFLAGS,
    };
  }

  const toLsp = pos => ({ line: pos.line, character: pos.ch });
  const fromLsp = pos => ({ line: pos.line, ch: pos.character });

  class LuauLspClient {
    constructor(options = savedOptions()) {
      this.ready = false;
      this.onReady = null; // called whenever a (re)started server has loaded its types
      this.docs = new Map(); // CodeMirror.Doc → { uri, version, changes, listener }
      this.pending = new Map(); // request id → { resolve, reject }
      this.nextId = 1;
      this.spawn(options);
    }

    spawn(options) {
      this.options = options;
      this.ready = false;
      this.worker = new Worker(WORKER_URL);
      this.worker.onmessage = event => this.receive(event.data);
      this.worker.onerror = event => console.warn("[lsp] worker error:", event.message);
      this.worker.postMessage({ type: "start", options });
    }

    // Definitions and the solver are fixed once a server starts, so changing them means a new one.
    restart(options = savedOptions()) {
      this.worker.terminate();
      for (const { reject } of this.pending.values()) reject(new Error("restarted"));
      this.pending.clear();
      this.spawn(options);
      for (const [doc, state] of this.docs) {
        state.version = 1;
        state.changes = [];
        this.open(doc, state);
      }
      if (this.imports?.length) this.setImports(this.imports);
    }

    receive(data) {
      if (data.type === "ready") {
        this.ready = true;
        console.debug(`[lsp] types loaded in ${data.ms}ms`);
        this.onReady?.();
      } else if (data.type === "failed") {
        console.warn("[lsp] unavailable:", data.error);
      } else if (data.type === "crashed") {
        console.warn("[lsp] crashed:", data.error);
        // Restart, but not in a loop if the same document keeps crashing it.
        if (Date.now() - (this.lastCrash || 0) > 10000) {
          this.lastCrash = Date.now();
          this.restart(this.options);
        }
      } else if (data.type === "rpc") {
        for (const message of data.messages) this.dispatch(message);
      }
    }

    dispatch(message) {
      if (message.method !== undefined) {
        // Server-to-client requests (progress tokens and the like) only need an answer.
        if (message.id !== undefined) this.post({ id: message.id, result: null });
        return;
      }
      const waiter = this.pending.get(message.id);
      if (!waiter) return;
      this.pending.delete(message.id);
      if (message.error) waiter.reject(Object.assign(new Error(message.error.message), { code: message.error.code }));
      else waiter.resolve(message.result);
    }

    post(message) {
      this.worker.postMessage({ type: "rpc", message });
    }

    notify(method, params) {
      this.post({ method, params });
    }

    request(method, params) {
      this.flushChanges();
      const id = this.nextId++;
      return new Promise((resolve, reject) => {
        this.pending.set(id, { resolve, reject });
        this.post({ id, method, params });
      });
    }

    uriFor(name) {
      return `${ROOT_URI}/${encodeURIComponent(name)}${/\.luau?$/i.test(name) ? "" : ".luau"}`;
    }

    uriOf(doc) {
      return this.docs.get(doc)?.uri;
    }

    // Opens, renames and closes documents so the server sees exactly these files.
    // Names are what scripts pass to require(), e.g. { name: "main", doc }.
    syncDocuments(files) {
      const wanted = new Map(files.map(file => [file.doc, this.uriFor(file.name)]));
      for (const [doc, state] of this.docs) {
        if (wanted.get(doc) === state.uri) continue;
        this.flushChanges();
        doc.off("change", state.listener);
        this.docs.delete(doc);
        this.notify("textDocument/didClose", { textDocument: { uri: state.uri } });
      }
      for (const [doc, uri] of wanted) {
        if (this.docs.has(doc)) continue;
        const state = { uri, version: 1, changes: [], listener: null };
        state.listener = (_, change) => this.queueChange(state, change);
        doc.on("change", state.listener);
        this.docs.set(doc, state);
        this.open(doc, state);
      }
    }

    open(doc, state) {
      this.notify("textDocument/didOpen", {
        textDocument: { uri: state.uri, languageId: "luau", version: state.version, text: doc.getValue() },
      });
    }

    // CodeMirror reports each change against the text left by the previous one, which is
    // also how LSP applies a list of content changes, so they can be forwarded as they are.
    queueChange(state, change) {
      state.changes.push({ range: { start: toLsp(change.from), end: toLsp(change.to) }, text: change.text.join("\n") });
      if (!this.flushQueued) {
        this.flushQueued = true;
        queueMicrotask(() => this.flushChanges());
      }
    }

    flushChanges() {
      this.flushQueued = false;
      for (const state of this.docs.values()) {
        if (!state.changes.length) continue;
        this.notify("textDocument/didChange", {
          textDocument: { uri: state.uri, version: ++state.version },
          contentChanges: state.changes,
        });
        state.changes = [];
      }
    }

    setSourcemap(json) {
      this.worker.postMessage({ type: "sourcemap", json: json || null });
    }

    // [{ spec, tree }] built by imports.js; replaces the previous set.
    setImports(imports) {
      this.imports = imports;
      this.worker.postMessage({ type: "imports", imports });
    }

    async completion(doc, pos) {
      const result = await this.request("textDocument/completion", { textDocument: { uri: this.uriOf(doc) }, position: toLsp(pos) });
      return Array.isArray(result) ? result : result?.items || [];
    }

    hover(doc, pos) {
      return this.request("textDocument/hover", { textDocument: { uri: this.uriOf(doc) }, position: toLsp(pos) });
    }

    signatureHelp(doc, pos) {
      return this.request("textDocument/signatureHelp", { textDocument: { uri: this.uriOf(doc) }, position: toLsp(pos) });
    }

    async diagnostics(doc) {
      const report = await this.request("textDocument/diagnostic", { textDocument: { uri: this.uriOf(doc) } });
      return report?.items || [];
    }
  }

  // Snippet text → plain text plus the [start, end) offsets to select ($1 first, else $0, else the end).
  function expandSnippet(snippet) {
    let text = "";
    let i = 0;
    const stops = new Map();
    const stop = (n, start) => { if (!stops.has(n)) stops.set(n, [start, text.length]); };
    (function parse(inPlaceholder) {
      while (i < snippet.length) {
        const c = snippet[i];
        if (inPlaceholder && c === "}") { i++; return; }
        if (c === "\\" && i + 1 < snippet.length) { text += snippet[i + 1]; i += 2; continue; }
        if (c === "$") {
          const rest = snippet.slice(i);
          let m;
          if ((m = /^\$(\d+)/.exec(rest)) || (m = /^\$\{(\d+)\}/.exec(rest))) {
            i += m[0].length;
            stop(+m[1], text.length);
            continue;
          }
          if ((m = /^\$\{(\d+)\|([^|]*)\|\}/.exec(rest))) {
            i += m[0].length;
            const start = text.length;
            text += m[2].split(",")[0];
            stop(+m[1], start);
            continue;
          }
          if ((m = /^\$\{(\d+):/.exec(rest))) {
            i += m[0].length;
            const start = text.length;
            parse(true);
            stop(+m[1], start);
            continue;
          }
        }
        text += c;
        i++;
      }
    })(false);
    const first = [...stops.keys()].filter(n => n > 0).sort((a, b) => a - b)[0] ?? 0;
    return { text, select: stops.get(first) || [text.length, text.length] };
  }

  const escapeHtml = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

  // The small slice of markdown luau-lsp writes: fenced code, rules, paragraphs, `code`, links,
  // emphasis and the odd <code> tag from Roblox's docs. Tooltips can't be clicked, so link-only
  // paragraphs ("Learn More") are dropped; maxCode caps how many code blocks are kept.
  function renderMarkdown(markdown, maxCode = Infinity) {
    const blocks = [];
    const lines = markdown.replace(/\r/g, "").split("\n");
    let paragraph = [];
    let codeBlocks = 0;
    const flush = () => {
      const text = paragraph.join(" ");
      if (text && !/^\[[^\]]*\]\([^)]*\)$/.test(text)) blocks.push(`<p>${inline(text)}</p>`);
      paragraph = [];
    };
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (/^```/.test(line)) {
        flush();
        const code = [];
        while (++i < lines.length && !/^```/.test(lines[i])) code.push(lines[i]);
        const text = code.join("\n").trim();
        if (text && codeBlocks++ < maxCode) blocks.push(`<pre class="lsp-code">${escapeHtml(text)}</pre>`);
      } else if (/^\s*(?:-{3,}|\*{3,}|_{3,})\s*$/.test(line)) {
        flush();
        blocks.push("<hr>");
      } else if (!line.trim()) {
        flush();
      } else {
        paragraph.push(line.trim());
      }
    }
    flush();
    while (blocks[0] === "<hr>") blocks.shift();
    while (blocks[blocks.length - 1] === "<hr>") blocks.pop();
    return blocks.join("");
  }

  function inline(text) {
    return escapeHtml(text)
      .replace(/&lt;(\/?)code&gt;/g, "<$1code>")
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\[([^\]]+)\]\((?:[^)]+)\)/g, "$1")
      .replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>")
      .replace(/(^|\W)\*([^*\s][^*]*)\*(?=\W|$)/g, "$1<i>$2</i>");
  }

  LuauLspClient.savedOptions = savedOptions;
  LuauLspClient.fflags = FFLAGS;
  LuauLspClient.fromLsp = fromLsp;
  LuauLspClient.expandSnippet = expandSnippet;
  LuauLspClient.renderMarkdown = renderMarkdown;
  window.LuauLspClient = LuauLspClient;
})();
