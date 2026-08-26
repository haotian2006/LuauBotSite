
# Discord

Discord-specific APIs are available only for executions started from Discord. 

### `discord.followUpNext()`

Sends the next output as a follow-up response instead of editing the original response.

In a Discord guild, the follow-up is ephemeral. Outside a guild, it is sent as a DM.

```lua
discord.followUpNext()
print("This appears as a separate follow-up message")
```

### `discord.button(options): DiscordButton`

Creates a Discord button attached to the current response.

#### String argument form

```lua
local button = discord.button("Click me")
```

#### Options-table form

```lua
local button = discord.button({
    Label = "Run",
    Style = "Success",
    Disabled = false,
    OwnerOnly = true,
})
```

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `Label` / `label` | `string` | required | Button text, 1–80 characters |
| `Style` / `style` | `string` | `"Primary"` | `Primary`, `Secondary`, `Success`, or `Danger` |
| `Disabled` / `disabled` | `boolean` | `false` | Makes the button unusable |
| `OwnerOnly` / `ownerOnly` | `boolean` | `true` | Only the script-starting user can click it |

A response can contain a maximum of 25 buttons.

## Discord button object

`discord.button()` returns an object with two event properties and two methods.

### `button.Clicked: RBXScriptSignal`

Fires when the button is clicked. The callback receives `userId: string` and `username: string`.

```lua
local button = discord.button("Click me")

button.Clicked:Connect(function(userId, username)
    print(username .. " clicked the button")
end)
```

### `button.Event: RBXScriptSignal`

Alias of `button.Clicked`.

```lua
button.Event:Connect(function(userId, username)
    print(userId, username)
end)
```

### `button:Update(changes: table): DiscordButton`

Updates the button in the existing Discord response.

```lua
local button = discord.button({
    Label = "Loading...",
    Style = "Primary",
})

button:Update({
    Label = "Finished",
    Style = "Success",
})
```

Accepted update fields:

```lua
button:Update({
    Label = "New label",
    Style = "Secondary",
    Disabled = true,
    OwnerOnly = false,
})
```

Returns the same button object, so chaining is possible:

```lua
button:Update({
    Label = "Done",
    Disabled = true,
}):Destroy()
```

Calling `Update` after `Destroy` raises an error.

### `button:Destroy()`

Removes the button from the Discord response and disconnects its internal callback.

```lua
local button = discord.button("Temporary")

task.delay(10, function()
    button:Destroy()
end)
```
