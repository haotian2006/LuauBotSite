# Executing code

???+ warning
    Because Luau Runner uses the execute code cloud api to run code, this means physics will not be simulated and some RunService events will not fire. These may be emulated in the future.

Luau Runner has a few custom globals that you can use.

You can get a typefile contianing all the types [here](https://gist.github.com/haotian2006/8b0f32a26f3661969836ef7915ca682b).

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

### `runpy(code:string): pyruntime`
Executes the given Python code and returns the runtime. This is missing a lot of features and is very basic currently.
Check out the module [here](https://devforum.roblox.com/t/pylua-python-interpreter-in-luau/3672669).

### `newpy(): pyruntime`
Creates a new Python environment. `input` links to `io.read()` and any prints or errors gets logged to the output.


??? warning
    These were added for gimmicky purposes and are just here for fun.