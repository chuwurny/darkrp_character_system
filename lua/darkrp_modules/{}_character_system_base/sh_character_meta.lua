---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

--- Type that shares fields among "SharedData" and "PrivateData"
---@see DarkRP.Character.SharedData
---@see DarkRP.Character.PrivateData
---@class DarkRP.Character.Data

---@class DarkRP.Character.SharedData : DarkRP.Character.Data

---@class DarkRP.Character.PrivateData : DarkRP.Character.Data
--- (Default internal field) Saved weapons
---@field Weapons { [string]: { Clip1: integer } }?
---
--- (Default internal field) Saved ammo
---@field Ammo { [integer]: integer }?

---@class DarkRP.CharacterInfo
---@field Name string Last saved character rp name

---@class DarkRP.Character : DarkRP.CharacterInfo
---@field ID integer? ID in database. If this is `nil` then character is not
--- saved
---@field Player Player Assigned player
---@field SteamID string Assigned player's Steam ID
---@field LastAccessTime integer Last character loaded timestamp (UTC)
---@field Health integer Last saved character health
---@field Armor integer Last saved character armor
---@field Pos Vector? Last saved character position
---@field Dead boolean Last saved character dead state
---@field Temporary boolean? Makes character temporary and prevents saving
---
--- Marks character to be unloaded only by calling `DarkRP.Character.Unload`
---@field ManualUnload boolean?
---
--- Data that is shared between assigned player
---@field SharedData DarkRP.Character.SharedData
---
--- Data that will be saved in database. Unlike `SharedData` this table is not
--- shared between assigned player
---@field PrivateData DarkRP.Character.PrivateData
---
---@field protected _UserData table
---@field protected _Receivers CRecipientFilter
DarkRP.Characters.CHARACTER = DarkRP.Characters.CHARACTER or {}

---@class DarkRP.Character
local CHARACTER = DarkRP.Characters.CHARACTER
CHARACTER.__index = CHARACTER

function CHARACTER:__tostring()
    return string.format(
        "Char(%s)[%s,%s]",
        self.Name,
        self.ID or "invalid",
        tostring(self.Player)
    )
end

--- Returns `true` if character has ID (is in database) and `CHARACTER.Player`
--- is valid
---@return boolean
function CHARACTER:IsValid()
    return self.ID ~= nil and IsValid(self.Player)
end

---@return boolean
function CHARACTER:FirstTimeCreated()
    return self.LastAccessTime == 0
end

--- Returns `true` if character is valid and player is playing this character
---@return boolean
function CHARACTER:IsActive()
    return self:IsValid()
        and self.Player:IsEnteredCharacter()
        and self.Player:GetCharacter() == self
end

--- Returns `true` if character is offline character. It means that
--- `DarkRP.Character.Player` is invalid
---@see DarkRP.Character.Player
---
---@return boolean
function CHARACTER:IsOffline()
    return not IsValid(self.Player)
end

--- Tries to make character online by searching online player
---
--- WARNING: this is for internal usage only!
---
---@return boolean If `true` then character is now online
function CHARACTER:TryMakeOnline()
    if not self:IsOffline() then
        return true
    end

    local ply = player.GetBySteamID(self.SteamID)

    if not IsValid(ply) then
        return false
    end

    ---@cast ply Player

    self.Player = ply

    if CLIENT then
        hook.Run("CharacterSync", self, self.SharedData)
        hook.Run("CharacterSynced", self)
    else
        hook.Run("CharacterLoad", self, self.PrivateData, self.SharedData)
        hook.Run("CharacterLoaded", self)

        self:AddListener(ply)
    end

    return true
end
