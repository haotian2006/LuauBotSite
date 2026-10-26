// io.import in the browser: downloads a Wally package or GitHub folder straight from Wally's
// registry / GitHub's API (both allow cross-origin reads), builds the instance tree the bot's
// src/github/build.luau would, and writes it as an .rbxm. Mirrors RluauRunnerV3's src/github/*.
// Roblox assets need the bot's Open Cloud key, so the bot downloads those (/import/roblox).
//
// A node is { name, className, source?, value?, contents?, children: [] }.
(function () {
  const WALLY_API = "https://api.wally.run/v1";
  const WALLY_VERSION = "0.3.2";
  const SYNCED = /\.(luau?|json|txt|csv)$/i;
  const MAX_FILES = 800;
  const MAX_PACKAGES = 50;
  const NAME = /^[A-Za-z0-9_.-]{1,100}$/;
  const ASSET_ID = /^\d{1,20}$/;
  const ROBLOX_HOSTS = /^(www\.|create\.)?roblox\.com$/i;
  const PART = /^[a-z0-9_-]{1,64}$/;

  class ImportError extends Error {}

  //// targets (same forms as the bot: wally:, wally.run/package, github.com, Roblox assets)

  // 123, rbxassetid://123, roblox.com/library/123, create.roblox.com/store/asset/123, roblox.com/asset/?id=123
  function parseRobloxTarget(text, url) {
    if (ASSET_ID.test(text)) return { mode: "roblox", id: text };
    const scheme = /^rbxassetid:\/\/(\d{1,20})$/i.exec(text);
    if (scheme) return { mode: "roblox", id: scheme[1] };
    if (!url || !ROBLOX_HOSTS.test(url.hostname)) return null;
    const segs = url.pathname.split("/").filter(Boolean).map(s => s.toLowerCase());
    const after = name => segs[segs.indexOf(name) + 1];
    const id = segs.includes("library") ? after("library")
      : segs.includes("catalog") ? after("catalog")
      : segs.includes("store") && after("store") === "asset" ? segs[segs.indexOf("store") + 2]
      : segs.includes("asset") ? url.searchParams.get("id") : null;
    if (!ASSET_ID.test(id ?? "")) throw new ImportError("expected a roblox.com asset link with an asset id");
    return { mode: "roblox", id };
  }

  function parseTarget(raw) {
    const text = String(raw).trim();
    let wallySpec = null;
    if (/^wally:/i.test(text)) wallySpec = text.slice(6);
    let url = null;
    try { url = new URL(text); } catch { }
    if (url && /^(www\.)?wally\.run$/i.test(url.hostname)) {
      const segs = url.pathname.split("/").filter(Boolean);
      if (segs[0] !== "package" || segs.length !== 3) throw new ImportError("expected wally.run/package/<scope>/<name>");
      const version = url.searchParams.get("version");
      wallySpec = `${segs[1]}/${segs[2]}${version ? `@=${version}` : ""}`;
    }
    if (wallySpec !== null) {
      const at = wallySpec.indexOf("@");
      const id = (at < 0 ? wallySpec : wallySpec.slice(0, at)).trim().toLowerCase();
      const req = at < 0 ? "*" : wallySpec.slice(at + 1).trim() || "*";
      const [scope, name, extra] = id.split("/");
      if (!PART.test(scope ?? "") || !PART.test(name ?? "") || extra !== undefined) {
        throw new ImportError("expected wally:<scope>/<name>@<version>");
      }
      parseRequirement(req);
      return { mode: "wally", scope, name, req };
    }
    const roblox = parseRobloxTarget(text, url);
    if (roblox) return roblox;
    if (!url) throw new ImportError("not a valid URL");
    const host = url.hostname.toLowerCase();
    const segs = url.pathname.split("/").filter(Boolean).map(decodeURIComponent);
    if (segs.some(s => s === "." || s === "..")) throw new ImportError("not a valid URL");
    const refCandidates = rest => rest.slice(0, 4).map((_, i) => ({ ref: rest.slice(0, i + 1).join("/"), path: rest.slice(i + 1).join("/") }));
    if (host === "raw.githubusercontent.com") {
      const [owner, repo, ...rest] = segs;
      if (!NAME.test(owner ?? "") || !NAME.test(repo ?? "") || rest.length < 2) {
        throw new ImportError("expected raw.githubusercontent.com/<owner>/<repo>/<ref>/<path>");
      }
      return { mode: "path", owner, repo, candidates: refCandidates(rest).filter(c => c.path) };
    }
    if (host !== "github.com" && host !== "www.github.com") throw new ImportError("only github.com, Wally and Roblox asset URLs are supported");
    const [owner, repoRaw, kind, ...rest] = segs;
    const repo = (repoRaw ?? "").replace(/\.git$/i, "");
    if (!NAME.test(owner ?? "") || !NAME.test(repo)) throw new ImportError("expected github.com/<owner>/<repo>");
    if (!kind) return { mode: "repo", owner, repo, candidates: [{ ref: "HEAD", path: "" }] };
    if (kind === "tree" || kind === "blob" || kind === "raw") {
      if (!rest.length) throw new ImportError(`missing branch after /${kind}/`);
      return { mode: "path", owner, repo, candidates: refCandidates(rest) };
    }
    if (kind === "releases") throw new ImportError("release models can only be imported by the bot");
    throw new ImportError(`unsupported GitHub URL (/${kind}/)`);
  }

  //// Wally versions (Cargo-style requirements, like wally install)

  function parseVersion(text) {
    const m = /^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/.exec(String(text).trim());
    return m ? { major: +m[1], minor: +m[2], patch: +m[3], pre: m[4] ?? null, text: String(text).trim() } : null;
  }

  function comparePre(a, b) {
    const x = a.split("."), y = b.split(".");
    for (let i = 0; i < Math.max(x.length, y.length); i++) {
      if (x[i] === undefined) return -1;
      if (y[i] === undefined) return 1;
      const nx = /^\d+$/.test(x[i]), ny = /^\d+$/.test(y[i]);
      if (nx && ny && +x[i] !== +y[i]) return +x[i] - +y[i];
      if (nx !== ny) return nx ? -1 : 1;
      if (x[i] !== y[i]) return x[i] < y[i] ? -1 : 1;
    }
    return 0;
  }

  function compare(a, b) {
    return a.major - b.major || a.minor - b.minor || a.patch - b.patch ||
      (a.pre === b.pre ? 0 : a.pre === null ? 1 : b.pre === null ? -1 : comparePre(a.pre, b.pre));
  }

  const v = (major, minor, patch, pre = null) => ({ major, minor, patch, pre });

  function parseRequirement(req) {
    const text = String(req).trim();
    if (text === "" || text === "*") return { tests: [() => true], pre: false };
    const tests = [];
    let pre = false;
    for (const part of text.split(",")) {
      const m = /^(\^|~|>=|<=|>|<|=)?\s*v?(\d+)(?:\.(\d+|\*|x))?(?:\.(\d+|\*|x))?(?:-([0-9A-Za-z.-]+))?$/i.exec(part.trim());
      if (!m) throw new ImportError(`can't read the version requirement "${text}"`);
      const op = m[1] ?? "^";
      const major = +m[2];
      const minor = m[3] === undefined || /[*x]/i.test(m[3]) ? null : +m[3];
      const patch = m[4] === undefined || /[*x]/i.test(m[4]) ? null : +m[4];
      if (m[5]) pre = true;
      const low = v(major, minor ?? 0, patch ?? 0, m[5] ?? null);
      const next = minor === null ? v(major + 1, 0, 0) : patch === null ? v(major, minor + 1, 0) : null;
      const ge = x => compare(x, low) >= 0;
      const lt = b => x => compare(x, b) < 0;
      if (op === "=") tests.push(next ? x => ge(x) && lt(next)(x) : x => compare(x, low) === 0);
      else if (op === ">=") tests.push(ge);
      else if (op === ">") tests.push(next ? x => compare(x, next) >= 0 : x => compare(x, low) > 0);
      else if (op === "<") tests.push(lt(low));
      else if (op === "<=") tests.push(next ? lt(next) : x => compare(x, low) <= 0);
      else if (op === "~") {
        const upper = minor === null ? v(major + 1, 0, 0) : v(major, minor + 1, 0);
        tests.push(x => ge(x) && lt(upper)(x));
      } else {
        const upper = major > 0 || minor === null ? v(major + 1, 0, 0) : minor > 0 || patch === null ? v(0, minor + 1, 0) : v(0, 0, patch + 1);
        tests.push(x => ge(x) && lt(upper)(x));
      }
    }
    return { tests, pre };
  }

  function pickVersion(versions, req) {
    const { tests, pre } = parseRequirement(req);
    let best = null;
    for (const entry of versions) {
      const ver = parseVersion(entry.package?.version);
      if (!ver || (ver.pre && !pre) || !tests.every(t => t(ver))) continue;
      if (!best || compare(ver, best.ver) > 0) best = { ver, entry };
    }
    return best;
  }

  //// downloads

  async function fetchOk(url, init) {
    const res = await fetch(url, init);
    if (res.ok) return res;
    if (res.status === 403 && /api\.github\.com/.test(url)) {
      throw new ImportError("GitHub's API limit for this network is used up; try again later");
    }
    throw new ImportError(`${new URL(url).hostname} returned ${res.status}`);
  }

  async function inflateRaw(bytes) {
    const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
    return new Uint8Array(await new Response(stream).arrayBuffer());
  }

  // Regular files Rojo can sync from a zip; stored and deflated entries only.
  async function readZip(buf) {
    const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
    let eocd = -1;
    for (let i = buf.length - 22; i >= Math.max(0, buf.length - 65557); i--) {
      if (view.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
    }
    if (eocd < 0) throw new ImportError("a package download isn't a zip archive");
    const count = view.getUint16(eocd + 10, true);
    let p = view.getUint32(eocd + 16, true);
    const decoder = new TextDecoder();
    const files = new Map();
    for (let n = 0; n < count; n++) {
      if (view.getUint32(p, true) !== 0x02014b50) throw new ImportError("a package download is a damaged zip");
      const method = view.getUint16(p + 10, true);
      const csize = view.getUint32(p + 20, true);
      const nameLen = view.getUint16(p + 28, true);
      const extraLen = view.getUint16(p + 30, true);
      const commentLen = view.getUint16(p + 32, true);
      const local = view.getUint32(p + 42, true);
      const name = decoder.decode(buf.subarray(p + 46, p + 46 + nameLen));
      p += 46 + nameLen + extraLen + commentLen;
      const segs = name.split("/");
      if (name.endsWith("/") || name.includes("\\") || segs.some(s => s === "" || s === "." || s === "..")) continue;
      if (!SYNCED.test(name) || (method !== 0 && method !== 8)) continue;
      const start = local + 30 + view.getUint16(local + 26, true) + view.getUint16(local + 28, true);
      const raw = buf.subarray(start, start + csize);
      files.set(name, decoder.decode(method === 0 ? raw : await inflateRaw(raw)));
    }
    return files;
  }

  const wallyHeaders = { "Wally-Version": WALLY_VERSION };
  const metadataCache = new Map();

  function wallyVersions(scope, name) {
    const key = `${scope}/${name}`;
    if (!metadataCache.has(key)) {
      metadataCache.set(key, fetch(`${WALLY_API}/package-metadata/${scope}/${name}`, { headers: wallyHeaders }).then(async res => {
        // the registry answers 500, not 404, for a package that doesn't exist
        if (res.status === 404 || res.status === 500) throw new ImportError(`Wally package ${key} not found`);
        if (!res.ok) throw new ImportError(`the Wally registry returned ${res.status}`);
        const versions = (await res.json())?.versions;
        if (!Array.isArray(versions)) throw new ImportError(`the Wally registry sent no versions for ${key}`);
        return versions;
      }).catch(err => { metadataCache.delete(key); throw err; }));
    }
    return metadataCache.get(key);
  }

  async function buildWally(target) {
    const packages = new Map();
    const indexKey = (scope, name, version) => `${scope}_${name}@${version}`;
    const visit = async (scope, name, req) => {
      const best = pickVersion(await wallyVersions(scope, name), req);
      if (!best) throw new ImportError(`no version of ${scope}/${name} matches "${req}"`);
      const key = indexKey(scope, name, best.ver.text);
      if (packages.has(key)) return key;
      if (packages.size >= MAX_PACKAGES) throw new ImportError(`more than ${MAX_PACKAGES} packages in the dependency tree`);
      const pkg = { key, scope, name, version: best.ver.text, deps: {} };
      packages.set(key, pkg);
      // a server runs the code, so shared and server dependencies both apply
      const deps = { ...(best.entry["server-dependencies"] ?? {}), ...(best.entry.dependencies ?? {}) };
      for (const [alias, spec] of Object.entries(deps)) {
        const at = String(spec).indexOf("@");
        const [depScope, depName] = (at < 0 ? spec : spec.slice(0, at)).trim().toLowerCase().split("/");
        pkg.deps[alias] = await visit(depScope, depName, at < 0 ? "*" : spec.slice(at + 1).trim() || "*");
      }
      return key;
    };
    const rootKey = await visit(target.scope, target.name, target.req);

    const files = new Map();
    await Promise.all([...packages.values()].map(async pkg => {
      const res = await fetchOk(`${WALLY_API}/package-contents/${pkg.scope}/${pkg.name}/${pkg.version}`, { headers: wallyHeaders });
      for (const [p, text] of await readZip(new Uint8Array(await res.arrayBuffer()))) files.set(`${pkg.key}/${p}`, text);
    }));
    const tree = new Tree(files);

    // Wally's layout: _Index/<scope>_<name>@<version>/<name> beside one link module per
    // dependency, so a package's require(script.Parent.Dep) resolves as installed.
    const quote = s => JSON.stringify(s);
    const index = node("_Index", "Folder");
    for (const pkg of packages.values()) {
      const folder = node(pkg.key, "Folder");
      const inst = tree.buildDir(pkg.key, pkg.name);
      inst.name = pkg.name;
      folder.children.push(inst);
      for (const [alias, depKey] of Object.entries(pkg.deps)) {
        folder.children.push(node(alias, "ModuleScript", {
          source: `return require(script.Parent.Parent[${quote(depKey)}][${quote(packages.get(depKey).name)}])\n`,
        }));
      }
      index.children.push(folder);
    }
    const root = node(target.name, "ModuleScript", {
      source: `return require(script._Index[${quote(rootKey)}][${quote(packages.get(rootKey).name)}])\n`,
    });
    root.children.push(index);
    return root;
  }

  async function githubTree(owner, repo, ref) {
    const res = await fetch(`https://api.github.com/repos/${owner}/${repo}/git/trees/${encodeURIComponent(ref)}?recursive=1`);
    if (res.status === 404 || res.status === 409 || res.status === 422) return null;
    if (res.status === 403) throw new ImportError("GitHub's API limit for this network is used up; try again later");
    if (!res.ok) throw new ImportError(`GitHub returned ${res.status}`);
    return (await res.json()).tree.filter(e => e.type === "blob" && SYNCED.test(e.path)).map(e => e.path);
  }

  async function githubFiles(owner, repo, ref, paths) {
    if (paths.length > MAX_FILES) throw new ImportError(`more than ${MAX_FILES} files to download`);
    const files = new Map();
    const queue = [...paths];
    const encodedRef = ref.split("/").map(encodeURIComponent).join("/");
    const worker = async () => {
      for (let path; (path = queue.shift()) !== undefined;) {
        const url = `https://raw.githubusercontent.com/${owner}/${repo}/${encodedRef}/${path.split("/").map(encodeURIComponent).join("/")}`;
        files.set(path, await (await fetchOk(url)).text());
      }
    };
    await Promise.all(Array.from({ length: 8 }, worker));
    return files;
  }

  // Folders a project's $paths point at, so only those files are downloaded.
  function projectRoots(project, base) {
    const roots = [];
    const walk = item => {
      if (!item || typeof item !== "object") return;
      if (typeof item.$path === "string") roots.push(joinPath(base, item.$path));
      for (const [key, child] of Object.entries(item)) if (!key.startsWith("$")) walk(child);
    };
    walk(project?.tree);
    return roots;
  }

  async function buildGithub(target) {
    for (const { ref, path } of target.candidates) {
      const all = await githubTree(target.owner, target.repo, ref);
      if (!all) continue;
      const under = prefix => all.filter(p => !prefix || p === prefix || p.startsWith(prefix + "/"));
      let wanted;
      const dir = path.replace(/\/+$/, "");
      const projectPath = dir ? `${dir}/default.project.json` : "default.project.json";
      if (target.mode === "path" && !all.includes(projectPath)) {
        wanted = under(dir);
      } else if (all.includes(projectPath)) {
        const project = JSON.parse((await githubFiles(target.owner, target.repo, ref, [projectPath])).get(projectPath));
        wanted = [projectPath, ...projectRoots(project, dir).flatMap(under)];
      } else {
        wanted = under("src");
      }
      const tree = new Tree(await githubFiles(target.owner, target.repo, ref, [...new Set(wanted)]));
      if (target.mode === "repo") {
        if (tree.files.has("default.project.json")) return tree.buildProject("default.project.json");
        if (tree.dirs.has("src")) return tree.buildDir("src", target.repo);
        throw new ImportError("the repository has no default.project.json or src folder");
      }
      const leaf = dir.split("/").pop() || target.repo;
      if (tree.dirs.has(dir)) return tree.buildDir(dir, leaf);
      if (tree.files.has(dir)) {
        const built = tree.buildFile(dir, leaf);
        if (!built) throw new ImportError(`"${dir}" isn't a file Rojo can sync`);
        return built;
      }
      throw new ImportError(`"${dir}" not found in the repository`);
    }
    throw new ImportError(target.mode === "repo" ? "repository not found (or it's private)" : "branch, tag or commit not found");
  }

  //// Rojo's sync rules (build.luau), minus properties and binary models

  function node(name, className, extra = {}) {
    return { name, className, children: [], ...extra };
  }

  function joinPath(base, rel) {
    const parts = base ? base.split("/") : [];
    for (const seg of rel.replace(/\\/g, "/").split("/")) {
      if (seg === "..") {
        if (!parts.length) throw new ImportError(`$path "${rel}" leaves the repository`);
        parts.pop();
      } else if (seg && seg !== ".") {
        parts.push(seg);
      }
    }
    return parts.join("/");
  }

  const RULES = [
    [/\.server\.luau?$/i, "Script"],
    [/\.client\.luau?$/i, "LocalScript"],
    [/\.model\.json$/i, "model"],
    [/\.project\.json$/i, "project"],
    [/\.meta\.json$/i, "meta"],
    [/\.luau?$/i, "ModuleScript"],
    [/\.json$/i, "json"],
    [/\.txt$/i, "txt"],
    [/\.csv$/i, "csv"],
  ];
  const INIT = {
    "init.luau": "ModuleScript", "init.lua": "ModuleScript",
    "init.server.luau": "Script", "init.server.lua": "Script",
    "init.client.luau": "LocalScript", "init.client.lua": "LocalScript",
  };
  const KEYWORDS = new Set("and break continue do else elseif end false for function if in local nil not or repeat return then true until while".split(" "));

  function luauLiteral(value, depth = 0) {
    if (typeof value === "string") return JSON.stringify(value);
    if (typeof value === "number") return Number.isInteger(value) ? String(value) : String(value);
    if (typeof value === "boolean") return String(value);
    if (value === null || typeof value !== "object") return "nil";
    const pad = "\t".repeat(depth + 1);
    const out = Array.isArray(value)
      ? value.map(item => pad + luauLiteral(item, depth + 1))
      : Object.keys(value).sort().map(key => {
        const k = /^[A-Za-z_]\w*$/.test(key) && !KEYWORDS.has(key) ? key : `[${JSON.stringify(key)}]`;
        return `${pad}${k} = ${luauLiteral(value[key], depth + 1)}`;
      });
    return out.length ? `{\n${out.join(",\n")},\n${"\t".repeat(depth)}}` : "{}";
  }

  function parseCsv(text) {
    const rows = [];
    let row = [], field = "", quoted = false;
    for (let i = 0; i < text.length; i++) {
      const c = text[i];
      if (quoted) {
        if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
        else if (c === '"') quoted = false;
        else field += c;
      } else if (c === '"') quoted = true;
      else if (c === ",") { row.push(field); field = ""; }
      else if (c === "\n" || c === "\r") {
        if (c === "\r" && text[i + 1] === "\n") i++;
        row.push(field); rows.push(row); row = []; field = "";
      } else field += c;
    }
    if (field || row.length) { row.push(field); rows.push(row); }
    return rows;
  }

  // Rojo's localization CSV: Key, Context, Example, Source and one column per locale.
  function localizationContents(text) {
    const [header = [], ...rows] = parseCsv(text);
    const named = { Key: "key", Context: "context", Example: "examples", Source: "source" };
    const entries = [];
    for (const row of rows) {
      const entry = { key: "", context: "", examples: "", source: "", values: {} };
      let any = false;
      header.forEach((col, c) => {
        const value = row[c] || "";
        if (value) any = true;
        if (named[col]) entry[named[col]] = value;
        else if (value) entry.values[col] = value;
      });
      if (any) entries.push(entry);
    }
    return JSON.stringify(entries);
  }

  const SERVICES = new Set(["DataModel", "Workspace", "Players", "Lighting", "ReplicatedFirst", "ReplicatedStorage",
    "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer", "Teams", "SoundService",
    "Chat", "TextChatService", "LocalizationService", "TestService", "VoiceChatService"]);

  class Tree {
    constructor(files) {
      this.files = files;
      this.dirs = new Map([["", new Set()]]);
      for (const path of files.keys()) {
        let child = path;
        for (let i = path.lastIndexOf("/"); ; i = child.lastIndexOf("/")) {
          const parent = i < 0 ? "" : child.slice(0, i);
          const name = i < 0 ? child : child.slice(i + 1);
          const known = this.dirs.has(parent);
          if (!known) this.dirs.set(parent, new Set());
          this.dirs.get(parent).add(name);
          if (known || parent === "") break;
          child = parent;
        }
      }
    }

    readJson(path) {
      try { return JSON.parse(this.files.get(path)); }
      catch (err) { throw new ImportError(`${path}: ${err.message}`); }
    }

    buildFile(path, fileName) {
      const rule = RULES.find(([re]) => re.test(fileName));
      if (!rule || rule[1] === "meta") return null;
      const [re, kind] = rule;
      const stem = fileName.slice(0, fileName.search(re));
      const data = this.files.get(path);
      if (kind === "project") return this.buildProject(path);
      if (kind === "model") return this.buildModel(this.readJson(path), stem);
      if (kind === "json") return node(stem, "ModuleScript", { source: `return ${luauLiteral(this.readJson(path))}\n` });
      if (kind === "txt") return node(stem, "StringValue", { value: data });
      if (kind === "csv") return node(stem, "LocalizationTable", { contents: localizationContents(data) });
      return node(stem, kind, { source: data });
    }

    buildModel(item, name) {
      const className = item.ClassName ?? item.className;
      if (typeof className !== "string") throw new ImportError("model.json entries need a ClassName");
      const built = node(name ?? item.Name ?? item.name ?? className, className);
      for (const child of item.Children ?? item.children ?? []) built.children.push(this.buildModel(child));
      return built;
    }

    buildDir(path, name, asProject = false) {
      const entries = this.dirs.get(path);
      if (!entries) throw new ImportError(`folder "${path}" not found`);
      const join = entry => (path ? `${path}/${entry}` : entry);
      if (!asProject && entries.has("default.project.json")) return this.buildProject(join("default.project.json"), name);
      const inits = Object.keys(INIT).filter(file => entries.has(file) && this.files.has(join(file)));
      if (inits.length > 1) throw new ImportError(`${path} has more than one init script`);
      let className = inits.length ? INIT[inits[0]] : "Folder";
      const meta = this.files.has(join("init.meta.json")) ? this.readJson(join("init.meta.json")) : null;
      if (!inits.length && typeof meta?.className === "string") className = meta.className;
      const built = node(name, className, inits.length ? { source: this.files.get(join(inits[0])) } : {});
      for (const entry of [...entries].sort()) {
        if (INIT[entry] || entry === "init.meta.json") continue;
        const child = join(entry);
        const result = this.dirs.has(child) ? this.buildDir(child, entry) : this.files.has(child) ? this.buildFile(child, entry) : null;
        if (result) built.children.push(result);
      }
      return built;
    }

    buildNode(item, name, base) {
      if (!item || typeof item !== "object") throw new ImportError(`project node "${name}" must be an object`);
      let built;
      if (typeof item.$path === "string") {
        const p = joinPath(base, item.$path);
        if (this.dirs.has(p)) built = this.buildDir(p, name);
        else if (this.files.has(p)) built = this.buildFile(p, p.split("/").pop());
        if (!built) throw new ImportError(`$path "${item.$path}" not found`);
        built.name = name;
      } else {
        const className = item.$className ?? "Folder";
        built = node(name, SERVICES.has(className) ? "Folder" : className);
      }
      for (const [key, child] of Object.entries(item)) {
        if (!key.startsWith("$")) built.children.push(this.buildNode(child, key, base));
      }
      return built;
    }

    buildProject(path, name) {
      const project = this.readJson(path);
      if (!project || typeof project.tree !== "object") throw new ImportError(`${path} isn't a valid project file`);
      const base = path.includes("/") ? path.slice(0, path.lastIndexOf("/")) : "";
      return this.buildNode(project.tree, name ?? project.name ?? "Project", base);
    }
  }

  //// .rbxm (Roblox binary model) writer: INST, PROP, PRNT and END chunks, uncompressed

  const encoder = new TextEncoder();
  const PROPERTIES = { source: "Source", value: "Value", contents: "Contents" };

  function toRbxm(root) {
    const instances = [];
    const parents = [];
    const walk = (item, parent) => {
      const ref = instances.length;
      instances.push(item);
      parents.push(parent);
      for (const child of item.children) walk(child, ref);
    };
    walk(root, -1);

    const classes = [...new Set(instances.map(i => i.className))].sort();
    const refsOf = className => instances.flatMap((item, ref) => (item.className === className ? [ref] : []));

    const chunks = [];
    classes.forEach((className, classId) => {
      const refs = refsOf(className);
      chunks.push(chunk("INST", [i32(classId), str(className), new Uint8Array([0]), i32(refs.length), refArray(refs)]));
      chunks.push(chunk("PROP", [i32(classId), str("Name"), new Uint8Array([0x01]), ...refs.map(r => str(instances[r].name))]));
      for (const [key, prop] of Object.entries(PROPERTIES)) {
        if (refs.some(r => instances[r][key] !== undefined)) {
          chunks.push(chunk("PROP", [i32(classId), str(prop), new Uint8Array([0x01]), ...refs.map(r => str(instances[r][key] ?? ""))]));
        }
      }
    });
    const all = instances.map((_, ref) => ref);
    chunks.push(chunk("PRNT", [new Uint8Array([0]), i32(all.length), refArray(all), refArray(parents)]));
    chunks.push(chunk("END\0", [encoder.encode("</roblox>")]));

    const header = concat([
      encoder.encode("<roblox!"), new Uint8Array([0x89, 0xff, 0x0d, 0x0a, 0x1a, 0x0a]),
      new Uint8Array([0, 0]), i32(classes.length), i32(instances.length), new Uint8Array(8),
    ]);
    return concat([header, ...chunks]);
  }

  function concat(parts) {
    const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
    let offset = 0;
    for (const part of parts) { out.set(part, offset); offset += part.length; }
    return out;
  }

  function i32(n) {
    const b = new Uint8Array(4);
    new DataView(b.buffer).setInt32(0, n, true);
    return b;
  }

  function str(text) {
    const bytes = encoder.encode(text);
    return concat([i32(bytes.length), bytes]);
  }

  // Referent arrays are delta-encoded, zigzagged, then byte-interleaved big-endian.
  function refArray(refs) {
    const out = new Uint8Array(refs.length * 4);
    let previous = 0;
    refs.forEach((ref, i) => {
      const value = ref - previous;
      previous = ref;
      const zigzag = ((value << 1) ^ (value >> 31)) >>> 0;
      for (let b = 0; b < 4; b++) out[b * refs.length + i] = (zigzag >>> (24 - 8 * b)) & 0xff;
    });
    return out;
  }

  function chunk(name, parts) {
    const data = concat(parts);
    const head = new Uint8Array(16);
    head.set(encoder.encode(name));
    const view = new DataView(head.buffer);
    view.setUint32(4, 0, true); // compressed length: 0 means stored as-is
    view.setUint32(8, data.length, true);
    return concat([head, data]);
  }

  //// Roblox assets (through the bot)

  const api = { server: "https://api.rluwa.com" };

  async function fetchRoblox(id, format) {
    const res = await fetch(`${api.server}/import/roblox/${id}${format ? `?format=${format}` : ""}`);
    if (res.ok) return res;
    const message = await res.json().then(body => body?.message, () => null);
    throw new ImportError(message || `the bot returned ${res.status}`);
  }

  function normalizeTree(item) {
    return {
      name: String(item.name), className: String(item.className), source: item.source, value: item.value,
      children: Array.isArray(item.children) ? item.children.map(normalizeTree) : [],
    };
  }

  async function buildRoblox(target) {
    return normalizeTree(await (await fetchRoblox(target.id, "tree")).json());
  }

  // The .rbxm for a spec: Roblox assets as the bot downloaded them (parts, meshes and all),
  // everything else written from the built tree.
  async function modelFile(spec) {
    const target = parseTarget(spec);
    if (target.mode === "roblox") {
      const bytes = new Uint8Array(await (await fetchRoblox(target.id)).arrayBuffer());
      return { name: `Asset${target.id}`, bytes };
    }
    const tree = await build(spec);
    return { name: tree.name, bytes: toRbxm(tree) };
  }

  //// entry

  const builds = new Map();

  // Downloads and builds a spec once per page load.
  function build(spec) {
    if (!builds.has(spec)) {
      const target = Promise.resolve().then(() => parseTarget(spec));
      builds.set(spec, target
        .then(t => (t.mode === "wally" ? buildWally(t) : t.mode === "roblox" ? buildRoblox(t) : buildGithub(t)))
        .catch(err => {
          builds.delete(spec);
          throw err instanceof ImportError ? err : new ImportError(err.message || String(err));
        }));
    }
    return builds.get(spec);
  }

  // io.import("...") or io.import(<asset id>) calls with a literal spec, as { spec, start, end } offsets into code.
  function findCalls(code) {
    return [...code.matchAll(/\bio\.import\s*\(\s*(?:(["'`])([^"'`\n]+)\1|(\d{1,20}))\s*\)/g)]
      .map(m => ({ spec: m[2] ?? m[3], start: m.index, end: m.index + m[0].length }));
  }

  function findSpecs(code) {
    return [...new Set(findCalls(code).map(call => call.spec))];
  }

  window.LuauImports = { api, build, modelFile, toRbxm, findCalls, findSpecs, parseTarget, ImportError };
})();
