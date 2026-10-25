# Slash Commands

Here are the valid slash commands that you can use with the bot:

- `/ping`: Responds with "Pong!"
- `/compile`: Executes the given Luau code on Roblox.
- `/help`: Brings them here
- `/input`: sends inputs to io.read() when compiling code
- `/hiddeninput`: sends inputs to io.read() without notifying the channel
- `/stopall`: Stops all currently running code executions that were started by you.
- `/tag <resource> [target]`: Looks up and posts a documentation resource, optionally pinging a user. Check out [resources](https://github.com/haotian2006/luau-runner-bot-resources) for a list of available resources.
---

# Application Commands

Here are the valid application commands that you can use with the bot:

- `bytecode`: Compiles the given Luau code into bytecode.
- `compile`: Executes the given Luau code (same runtime rules as `/compile`).
- `bytecodeWOption`: Compiles the given Luau code into bytecode with additional options and in a form.
- `compileWOption`: Executes the given Luau code with additional options and in a form.
- `input` : sends inputs to io.read()
- `analyze`: Runs `luau-analyze` on the given code and reports warnings/errors.
- `ast`: Dumps the parsed AST of the given code.
- `format`: Formats the given code with StyLua.
---

???+ info "Additional Code"
    `compileWOption`'s options won't work if the globals they rely on are already defined in the code.

    By default `Additional Code` is appended after the original code:

    | Original | Additional | Result |
    | --- | --- | --- |
    | `print('hi')` | `print('after')` | `print('hi')` then `print('after')` |

    Use a `{CODE}` placeholder to control where the original code lands instead, and repeat it to chain multiple blocks together:

    ```lua
    print('before')
    {CODE}
    print('after')
    ```

    ```lua
    -- Original: print('hi')
    print('before')
    print('hi')
    print('after')
    ```

!!! info
    `compile` will also truncate the output to reduce spam.

???+ info "Flags"
    Commands executed using `bytecode` check for flags in the text that determine how the code is compiled. Here are the available flags:
    ``--!optimize <level 0-2> --!debug <level 0-2> --!remarks --!native --!binary --!dump-constants --!architecture <target>``

    ```
    Example:
    ```lua
    --!optimize 2
    print(1+1) -- would optimize to print(2)
    ```
    ```
## Filtering & Spam

Any raw output will go through a basic filter for slurs and swears. If the output is filtered it will be replaced with tags like $*x*. To prevent output spam discord outputs are truncated to 24 lines and at 1900 characters the output will be truncated.

## Execution runtime

`/compile` and `compileWOption` run in Roblox Studio on the bot's own server, which responds much faster than spinning up a Roblox session. You can tell where it ran by the server number: `Studio #N` for Studio, `Server #N` for the execute code cloud api, which is used when Studio is busy. Code no longer runs on Lune.

## Cooldowns

Code that crashes or overloads the bot gets a short cooldown, with `Failed to start. Try again in N seconds.` The play ground allows 10 runs a minute.

