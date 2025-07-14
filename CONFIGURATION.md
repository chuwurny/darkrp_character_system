# 🔧 Configuration

All configuration settings should be placed in
`addons/<darkrpmodification>/lua/darkrp_config/settings.lua`

**Current (default) configuration.** You can use it as a template!

```lua
--------------------------------------
--- Character system configuration ---
--------------------------------------

-- If `true` then automatically leaves character (on server) when trying to
-- switch to other character (by calling DarkRP.Characters.EnterCharacter
-- function)
GM.Config.AllowQuickCharacterEnter = false

-- Max characters amount player can create
GM.Config.MaxCharacters = 2

-- Max character name length (utf8 friendly)
GM.Config.CharacterMaxNameLength = 32

-- Weapons that shouldn't be saved
GM.Config.DontSaveCharacterWeapons = {
    -- Examples:
    --["weapon_physgun"] = true,
    --["weapon_fists"] = true,
}

-- Respawn character on the same position as the last time
--
-- NOTE: disabling it will stop saving character position!
GM.Config.CharacterSpawnsOnLastPos = true

-- Restore last character's health
GM.Config.CharacterRestoreLastHealth = true
```

## Disabling default implementation

To disable default field implementations use `GM.Config.DisabledCustomModules`
([darkrp modification code](https://github.com/FPtje/darkrpmodification/blob/407fc8bfa4d0828ea3d0d48dabc601e6d5eb5695/lua/darkrp_config/settings.lua#L349))

Modules that you can disable:

- `char_sys_base_money`: Saves player's money ("money" var)

- `char_sys_base_rpname`: Saves player's RP name ("rpname" var)
