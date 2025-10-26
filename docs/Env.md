# Executing code

???+ warning
    Because Luau Runner uses the execute code cloud api to run code, this means physics will not be simulated. 

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

You can also provide inputs in the code using `--@<input>` comments.
```lua
--@Hello, World!
local input = io.read()
print(input) --> Hello, World!
```

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
