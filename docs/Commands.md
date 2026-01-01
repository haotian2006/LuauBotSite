# Slash Commands

Here are the valid slash commands that you can use with the bot:

- `/ping`: Responds with "Pong!"
- `/compile`: Executes the given Luau code in the Roblox environment.
- `/help`: Brings them here
- `/input`: sends inputs to io.read() when compiling code
- `/hiddeninput`: sends inputs to io.read() without notifying the channel

---

# Application Commands

Here are the valid application commands that you can use with the bot:

- `bytecode`: Compiles the given Luau code into bytecode.
- `compile`: Executes the given Luau code in the Roblox environment.
- `bytecodeWOption`: Compiles the given Luau code into bytecode with additional options and in a form.
- `compileWOption`: Executes the given Luau code in the Roblox environment with additional options and in a form.
- `input` : sends inputs to io.read() 
---

???+ info 
    `compileWOption`'s options will also not work if the globals for the options were already defined in the code.

???+ info
    `compileWOption`'s `Additional Code` Option by default will append the code to the end of the original code.
    Example:
    Original Code: `print('hi')`
    Additional Code: `print('after')`
    Result:

    ```lua
    print('hi')
    print('after')
    ```

    You can also add a `{CODE}` placeholder in the additional code to specify where the original code should be placed.
    Example:
    Original Code: `print('hi')`
    Additional Code: 

    ```lua
    print('before')
    {CODE}
    print('after')
    ```

    Result:

    ```lua
    print('before')
    print('hi')
    print('after')
    ```

???+ info
    `compileWOption`'s `Additional Code` Option now also works with normal code blocks. You can chain blocks of code together.

    ```lua
    print('first block')
    ```

    ```lua
    print('second block')
    ```

    ```lua
    {CODE}
    {CODE}
    ```

    Result:

    ```lua
    print('first block')
    print('second block')
    print('first block')
    print('second block')
    ```

!!! info
    `compile` will also truncate the output to reduce spam.

???+ info "Flags"
    Commands executed using `bytecode` check for flags in the text that determine how the code is compiled. Here are the available flags:
    ``--!optimize <level 0-2> --!debug <level 0-2> --!remarks --!native``

    ```
    Example:
    ```lua
    --!optimize 2
    print(1+1) -- would optimize to print(2)
    ```
    ```

