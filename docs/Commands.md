# Slash Commands

Here are the valid slash commands that you can use with the bot:

- `/ping`: Responds with "Pong!"
- `/compile`: Executes the given Luau code. Runs on Roblox by default; simple, self-contained scripts may instead run locally on [Lune](https://lune-org.github.io/docs) for a faster response.
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

`/compile` and `compileWOption` don't always run on Roblox. If the code is
self-contained, and no other
Roblox-only globals are used, it runs locally on [Lune](https://lune-org.github.io/docs)
instead, which responds much faster than spinning up a Roblox session. You can tell if its running locally by the presence of a `Lune` in the server number. You can force lune execution by using the `--!lune` hot comment.

