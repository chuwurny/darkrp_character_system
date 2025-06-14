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
```
