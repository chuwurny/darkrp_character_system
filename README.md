# 👤 DarkRP character system

This is addon for [DarkRP](https://github.com/FPtje/DarkRP) that extends
functionality by adding characters.

> [!WARNING]
>
> This module provides a **base** for your character system. This addon doesn't
> add new UI, doesn't provide any extra features, it's a **solid base**.

## TODO

- [ ] Fully functional example implementation of this base

## 📜 Documentation

- [Configuration](./CONFIGURATION.md)

## 🚀 Quick start

1. Install this addon into your `addons` directory.

2. Create directory for your module. For example
   `addons/<darkrpmodification>/lua/darkrp_modules/my_character_system`.

3. Follow this guide step by step!

### Character creation

Create `cl_creation.lua` inside module directory:

```lua
concommand.Add("create_char", function(_, _, args)
    DarkRP.Characters.SendCreateRequest({
        Name = args[1],
        -- ... other fields that can be extended (see "Extending fields")
    }, function(err)
        if err then
            print("Error occured: " .. err)
        else
            print("Character created!")
        end
    end)
end)
```

Now you can create character.

### Getting characters

Now let's capture our created characters. Create `cl_sync.lua`:

```lua
hook.Add("CharacterSynced", "CharSys_PrintSyncedCharacter", function(char)
    print("Character synced. ID is " .. char.ID .. ". Name is: " .. char.Name)
end)
```

This hook will be executed at:

- Character creation

- After joining the server

- After entering character

- Or manually calling `CHARACTER:Sync()`

Also characters can be get via `DarkRP.Characters.Loaded` table. You can be
sure that this table is always up-to-date, specially in `CharacterSynced` hook.
This table contains characters in this syntax:

```
[character id] = DarkRP.Character
```

You can check `DarkRP.Character` table structure in `sh_character_meta.lua`
file.

### Entering characters

Let's add console command `enter_char` to enter created characters. Create
`cl_entering.lua`:

```lua
concommand.Add("enter_char", function(_, _, args)
    local charId = tonumber(args[1])

    DarkRP.Characters.SendEnterRequest(charId, function(err)
        if err then
            print("Error occured: " .. err)
        else
            print("Character entered!")
        end
    end)
end)
```

### Testing written code!

Now in game we can run these commands:

```
] create_char Joe
Character created!
Character synced. ID is 1. Name is: Joe
] enter_char 1
ServerLog: [FAdmin] Joe (STEAM_0:1:22334455) Spawned
Character entered!
```

## 📥 Extending fields

To extend functionality without modifying internal code (hello Helix devs) you
can easily add custom fields via `DarkRP.Characters.CreateFieldSimple`
function:

```lua
---@class DarkRP.CharacterInfo
---@field MyColor Color
---@field Banned boolean

DarkRP.Characters.CreateFieldSimple({
    -- Name for your field
    Name = "MyColor",

    -- (optional) Makes variable be accessed via CHARACTER.SharedData.MyColor
    SharedData = true,

    -- (optional) Register and set DarkRP var for this field
    DarkRPVar = {
        -- If this field is set then you can access DarkRP var via
        --
        -- Player:getDarkRPVar("IDN")
        --
        -- otherwise via
        --
        -- Player:getDarkRPVar("char_IDN")
        --
        --Name = "IDN",
        WriteFn = net.WriteString,
        ReadFn = net.ReadString,
    },

    -- (optional) Validates field
    --
    ---@param info DarkRP.CharacterInfo
    ValidateFn = function(field, info)
        if not IsColor(field) then
            return "MyColor field is not a Color"
        end
    end,
    -- ... or just
    --ValidateFn = IsColor,

    -- (optional) Makes this field be set only by server. See "Banned" field
    -- below.
    --SetByServer = true

    -- (optional) Called in "CharacterPreSpawn" hook. Apply your variable here!
    Apply = function(ply, color)
        -- Apply color to the player
        ply:SetPlayerColor(color)
    end,
})

DarkRP.Characters.CreateFieldSimple({
    Name = "Banned",
    SharedData = true,
    SetByServer = true,
})
```
