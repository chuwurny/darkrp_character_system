---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

--- List of all loaded characters by `PLAYER:LoadCharacters`
---@type { [integer]: DarkRP.Character }
DarkRP.Characters.Loaded = DarkRP.Characters.Loaded or {}

---@alias DarkRP.MaybeCharacter DarkRP.Character|integer

--- Ensures that @v is a character. Will return character if value successfully
--- translated to character, otherwise throws an error.
---@param v DarkRP.MaybeCharacter
---@return DarkRP.Character
function DarkRP.Characters.ToCharacter(v)
    if type(v) == "table" then
        return v
    elseif type(v) == "number" then
        return DarkRP.Characters.Loaded[v]
    else
        error("Character is required but got " .. type(v))
    end
end

--- Creates a new character, but doesn't store it in any way
---
--- WARN: For internal usage only!
---
---@param ply Player
---@return DarkRP.Character
function DarkRP.Characters.New(ply)
    return setmetatable({
        ID = nil,
        Player = ply,
        LastAccessTime = 0,
        Health = ply:GetMaxHealth(),
        Armor = 0,
        Dead = false,
        Pos = nil,
        SharedData = {},
        PrivateData = {},
        _UserData = SERVER and {} or nil,
    }, DarkRP.Characters.CHARACTER)
end
