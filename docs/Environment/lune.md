
# Lune libraries

Code can `require` some [Lune](https://lune-org.github.io/docs) libraries. They are mocked on top of Roblox, so code written for Lune can run here.

```lua
local fs = require("@lune/fs")
fs.writeFile("hello.txt", "hi")
print(fs.readFile("hello.txt")) --> hi
```

| Library | What works |
| --- | --- |
| `@lune/fs` | A file system that only lasts for the run: `readFile`, `writeFile`, `readDir`, `writeDir`, `removeFile`, `removeDir`, `isFile`, `isDir`, `copy`, `move`, `metadata`. Up to 16 MB and 1024 files. |
| `@lune/task` | `spawn`, `defer`, `delay`, `wait`, `cancel` |
| `@lune/roblox` | `Instance.new`, `serializeModel` (binary only), `deserializeModel`, `getReflectionDatabase`, `implementMethod`, `implementProperty` |
| `@lune/serde` | `encode` and `decode` for json, yaml and toml, `compress` and `decompress` for gzip and zlib, `hash` and `hmac` with md5, sha1, sha256, sha384 and sha512 |
| `@lune/regex` | `new`, with `isMatch`, `find`, `captures`, `split`, `replace` and `replaceAll` |
| `@lune/luau` | `compile`, `disassemble` and `load`. `load` only takes source or bytecode compiled in the same run. |

Other libraries like `@lune/net`, `@lune/process` and `@lune/stdio` don't work: `library @lune/net is unavailable on this worker`.

???+ info
    `@lune/serde`, `@lune/regex` and `@lune/luau` only work when the code runs in Studio.
