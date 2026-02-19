

### `followupnext()`
Marks the next output as a followup message. This message will also have `ephemeral` marked as true.

```lua
print("This is the first message.")
io.followupnext()
print("This is a followup message.") -- this will be sent as a followup and the original compiler embed will also be updated
```

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

### `readfile(): (string,string)`
returns the currently loaded file's content and file type

### `getoutput(): string`
returns the current output log as a string

```lua
print("Hello, World!")
local output = io.getoutput()
print(output) --> "Hello, World!\n"
```

### `clearoutput()`
Clears the output.