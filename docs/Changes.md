# Updates

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