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
---@param plyOrSteamID Player|string Player or steam id
---@return DarkRP.Character
function DarkRP.Characters.New(plyOrSteamID)
    local ply, steamID

    if type(plyOrSteamID) == "Player" then
        ply = plyOrSteamID
        steamID = ply:SteamID()
    else
        ply = nil
        steamID = plyOrSteamID
    end

    local receivers

    if SERVER then
        receivers = RecipientFilter()

        if type(ply) == "Player" then
            receivers:AddPlayer(ply)
        end
    end

    return setmetatable({
        ID = nil,
        Player = ply,
        ManualUnload = not IsValid(ply),
        SteamID = steamID,
        LastAccessTime = 0,
        Health = IsValid(ply)
                ---@cast ply -?
                and ply:GetMaxHealth()
            or 100,
        Armor = 0,
        Dead = false,
        Pos = nil,
        SharedData = {},
        PrivateData = SERVER and {} or nil,
        _UserData = SERVER and {} or nil,
        _Receivers = receivers,
    }, DarkRP.Characters.CHARACTER)
end
