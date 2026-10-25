# Updates

## 10/25/26

- Renamed from luau runner to luwa.
- Code now runs in Roblox Studio on the bot's own server.
- Code no longer runs on Lune.
- `DataStoreService` and `MemoryStoreService` now keep your data between runs in Discord.
- Added memory and CPU limits for each run, and code cut off when its session ends stops with `Session ended.`
- Added `Image.record` to record an Instance into a gif.
- Lune libraries like `@lune/fs` and `@lune/serde` can be required.
- Faster png and gif encoding.


## 10/9/26

- Added `Image.fromInstance` to render workspace, models, ViewportFrames and UI into an image.
- Added `Image.fromAsset` to download Roblox image assets.
- Added `io.writeimage` to write an Image (png), a list of Images (gif) or a rendered Instance in one call.
- `DrawText` now draws anti-aliased text in any size, with fonts, wrapping, alignment and outlines.
- Added `io.import` to build GitHub repositories (Rojo rules) and release `.rbxm` files into instances.
- `require` now works on modules that return `nil`, and waits for modules still loading in another thread.

## 8/25/26

- Refactored code base to be a proper project rather then a single file.
- Added `Discord.button` that supports button creation and click events.
- Lune will now be used for simple code execution instead of a luau session.


## 4/3/26

- Added multi-file support

## 4/1/26

- Added analyze and ast

## 2/14/26

- Added `Image.plotFunction`.

## 1/19/26

- You can send up to 2 MB of input data to the bot for code execution.
- Added a footer to show if code execution finished and the total execution time. Color is also light blue for running and dark blue for finished.
- Added a check for `Connect` or `Once` in the code to prevent the task from ending early if those functions were used as they run asynchronously.

## 1/2/26 

- Bot can now upload files as outputs during runtime instead of after execution finishes.
- added `Image` library to creates images and encode them as png or gifs.
- Made `io.writefile` lowercase and also made it so it outputs files during runtime, and allowed it to give a name to the file.
- Added `io.followupnext` to allow sending followup files for the output.

## 1/1/26

- io.writeFile for allowing the users to output files like png instead of plain txts.
- Other io functions like readFile, getOutput, clear.
- Larger output limit for files
- Better compression for transferring inputs/outputs.
- `TIMEOUT` only applies if output had been spammed. Normal code executions can now last till session timeout (~5 minutes).
- Code lines are now only offset by 2 lines instead of some large amt.
- Documentation Changes.
