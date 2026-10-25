# Executing code

???+ warning
    Because Luwa runs code in Roblox Studio on its own server, or with the execute code cloud api when Studio is busy, this means physics will not be simulated. RunService events are emulated.


Luwa has a few custom globals that you can use.

You can get a typefile containing all the types [here](https://rluwa.com/playground/botTypes.d.luau).

### `TIMEOUT: number`
The maximum time (in seconds) that a code execution is allowed to run before terminated. Defaults to 25 seconds. 

```lua
TIMEOUT = 3 -- make sure it's not a local
while task.wait(.5) do
    print('hello') -- will stop after 3 seconds
end 
```

???+ info
    The maximum time a session can run for is 5 minutes before it shuts down. In Studio a session lasts up to 4 minutes, and code still running when it ends stops with `Session ended.`

### Limits
- Each run can use the memory left of 1 GB, and at least 128 MB: `Memory limit exceeded`.
- At most 8 files can be written, 10 MB each.



### `OUTPUT_LOGS: boolean|"LOG"`
Should a file be attached once the code execution finishes, containing all the outputs, defaults to false. If set to "LOG" then headers will not be included.

### `TIMESTAMP: boolean`
Should the time stamp be included when logging. If false it will not give a timeout warning and does not apply to errors. Defaults to false. 

### `user:{Name:string,UserId:number}`
A table containing information about the user who sent the code to be executed.

### DataStores and MemoryStores
`DataStoreService` and `MemoryStoreService` work in Discord, and what you save is kept between runs.

- Your data is kept under your User ID, up to 1 MB.
- Data that isn't used for 30 days is deleted. MemoryStore entries are deleted when they expire.
- Code run in the play ground doesn't save anything.

```lua
local store = game:GetService("DataStoreService"):GetDataStore("scores")
print(store:GetAsync("best")) -- nil the first time
store:SetAsync("best", 42)
```

### `ask(prompt:string,contextId:string?): string`

Uses `TextGenerator` to answer a question. Context will be preserved on each server and can be cleared by passing true to the second argument. Returns the contextId. FYI this is not reliable and just a gimmick.

### `bench(funcs:{},printMode:number?,iterations:number?,delayEveryXIter:number?): results`

Runs benchmarks on the provided functions.

- `funcs`: A dictionary of functions to benchmark. The key is the name of the function, and the value is the function itself. This also supports BoatBomber's format of a ParameterGenerator and Functions table.
    - If using the ParameterGenerator format, the `ParameterGenerator` function will be called once to generate parameters, which will then be passed to each function in the `Functions` table.
- `printMode`: (optional) Determines how results are printed. 
    - `0` = No output
    - `1` = table format (default)
    - `2` = compact format
- `iterations`: (optional) The number of iterations to run for each function. Defaults to 1000.
- `delayEveryXIter`: (optional) Introduces a small delay every X iterations to prevent timeouts. Defaults to 20.

Returns a table containing the results of the benchmarks.

Examples:
```lua
local results = bench({
    ["sum"] = function()
        local s = 0
        for i = 1, 100 do
            s = s + i
        end
        return s
    end,
})

local results = bench({
    ParameterGenerator = function()
        local t = {}
        for i = 1, 100 do
            t[i] = math.random()
        end
        return t
    end,
    Functions = {
        ["sum"] = function(profile,t)
            local s = 0
            for i = 1, #t do
                s = s + t[i]
            end
        return s
    end,
    }
})

```

### `println(text:string,line:number?):number`
returns the line the number is printed on

### `log(text:string,color:string,newLine:boolean?)`
Logs text to the console with a specified color. If newLine is true, it will add a new line after the text.

### `colorstring(text:string,color:string):string`
Returns a string that will be colored when outputted in ansi.

Valid colors are (casing does not matter):

- `black`
- `red`
- `green`
- `yellow`
- `blue`
- `purple`
- `white`
- `cyan`


### `native: boolean`
Is native code generation enabled. Should not be modified at runtime. Does not effect running code.

### `optimize: number`
The optimization level that the script is running in. Should not be modified at runtime. Does not effect running code.

### Libraries
These are available without requiring anything:

- [`discord`](discord.md): buttons and other things for the response.
- [`table`](etable.md): the default table library with extra functions.
- [`io`](io.md): input, output files, images and `import`.
- [`misc`](misc.md): some random functions.
- [`Image`](Image.md): create, edit and render images.

[Lune libraries](lune.md) like `@lune/fs` and `@lune/serde` can be required too.