# Executing code

???+ warning
    Because Luau Runner uses the execute code cloud api to run code, this means physics will not be simulated. Also do not trust benches ran from this bot as this is using `loadstring` which may not accurately represent the final execution environment.

Luau Runner has a few custom globals that you can use.


### `TIMEOUT: number`
The maximum time (in seconds) that a code execution is allowed to run before terminated. Defaults to 15 seconds. 

```lua
TIMEOUT = 3 -- make sure it's not a local
while task.wait(.5) do
    print('hello') -- will stop after 3 seconds
end 
```

???+ info
    The maximum time a session can run for is 5 minutes before it shuts down.


### `OUTPUT_LOGS: boolean|"LOG"`
Should a file be attached once the code execution finishes, containing all the outputs, defaults to false. If set to "LOG" then headers will not be included.

### `TIMESTAMP: boolean`
Should the time stamp be included when logging. If false it will not give a timeout warning and does not apply to errors. Defaults to false. 

### `io.write(...any)`
Does not add spaces between args and does not output tables expanded.If `TIMESTAMP` is false, then do not create a new line.

### `io.read():string`
yields the thread until `/input` is given. Unlike lua this does not have any args.

???+ warning
    `/input` will only send it for the latest session started by the user. It will not process inputs from other users.

### `log(text:string,color:string,newLine:boolean?)`
Logs text to the console with a specified color. If newLine is true, it will add a new line after the text.

Valid colors are (casing does not matter):

- `black`
- `red`
- `green`
- `yellow`
- `blue`
- `purple`
- `white`
- `cyan`

### `table: table`

The default table library has extended functions provided by Akari <3. 
These just provide a few gimmicky functions on top of the default table library.
Check [ExtendedTableLibrary](./ExtendedTableLibrary.md) for more information.

```lua
local t = {1,2,3,4,5,6,7,8,9}
print(table.getAllocatedArraySize(t)) --> 9
t[10] = 10
print(table.getAllocatedArraySize(t)) --> 16

print(table.concat(t, ", ")) --> 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 
```
