# Slash Commands

Here are the valid slash commands that you can use with the bot:

- `/ping`: Responds with "Pong!"
- `/compile`: Executes the given Luau code in the Roblox environment.
- `/help`: Brings them here
- `/input`: sends inputs to io.read() when compiling code

---

# Application Commands

Here are the valid application commands that you can use with the bot:

- `bytecode`: Compiles the given Luau code into bytecode.
- `compile`: Executes the given Luau code in the Roblox environment.
- `bytecodeWOption`: Compiles the given Luau code into bytecode with additional options and in a form.

---

!!! info
`compile` will also truncate the output to reduce spam.

???+ info "Flags"
Commands executed using `bytecode` check for flags in the text that determine how the code is compiled. Here are the available flags:
``--!optimize <level 0-2> --!debug <level 0-2> --!remarks``

```
Example:
```lua
--!optimize 2
print(1+1) -- would optimize to print(2)
```
```

!!! warning
You are allowed to use application command on files as well but there is a maximum file size limit of 30 kb.
Exceeding this limit will fail to compile.

!!! warning
Native code generation is currently not supported.
