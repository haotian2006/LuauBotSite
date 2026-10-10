

### `write(...any)`
Does not add spaces between args and does not output tables expanded.If `TIMESTAMP` is false, then it will not create a new line.

### `read():string`
yields the thread until `/input` is given. Unlike lua this does not have any args.

You can also provide inputs in the code using `--@<input>` comments.
```lua
--@Hello, World!
local input = io.read()
print(input) --> Hello, World!
```

### `writefile(content: string|buffer, filename: string): boolean`
This function makes it so the log file will output the content instead of the log history along with the file type specified. If file type is not supported then it will default to `ansi`. This will also trigger the file to be sent.

Supported file types:
```js
  "png",
  "jpg",
  "jpeg",
  "gif",
  "webp",
  "svg",

  "txt",
  "ansi",
  "lua",
  "luau",
  "json",
  "xml",
  "rbxm",
  "html",
  "css",
  "js",
  "md",
  "csv",

  "mp3",
  "wav",
  "ogg",
  "mp4",
  "webm"
```

### `writeimage(value: Image | {Image} | Instance, filename: string?, options: {}?): string`
Writes an image file without converting it yourself, and returns the file name used.

- An `Image` is written as a `.png`.
- A list of Images is written as a `.gif`. Options: `Delay` (seconds per frame, or a list of them; default `0.1`), `Loop` (`0` loops forever).
- An Instance (`workspace`, a model, a ScreenGui, ...) is rendered with [`Image.fromInstance`](Image.md) first; `options` are passed to it.

The extension is added if `filename` doesn't have one; the default name is `image`.

```lua
io.writeimage(workspace, "scene", { Size = Vector2.new(320, 180) })
```

### `import(url:string):Instance`
Builds a GitHub repository into an Instance, following Rojo's file rules.

- `github.com/<owner>/<repo>`: builds `default.project.json`, or `src/` if there isn't one.
- `.../tree/<branch>/<path>` or `.../blob/<branch>/<path>`: builds that folder or file.
- `.../releases/download/<tag>/<file>.rbxm`: loads the release model.

!!!warning
    Scripts don't run when imported
```lua
local Chrono = io.import("https://github.com/Parihsz/Chrono")
local api = require(Chrono)
```

### `readfile(file:string): (string,string)`
reads a loaded file with write file and returns the content and the file type. If the file does not exist or is not loaded then it will return nil.


### `getoutput(): string`
returns the current output log as a string

```lua
print("Hello, World!")
local output = io.getoutput()
print(output) --> "Hello, World!\n"
```

### `clearoutput()`
Clears the output.
