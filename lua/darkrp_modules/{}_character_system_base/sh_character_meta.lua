---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

--- Type that shares fields among "SharedData" and "PrivateData"
---@see DarkRP.Character.SharedData
---@see DarkRP.Character.PrivateData
---@class DarkRP.CharacterInfo.Data

---@class DarkRP.Character.SharedData : DarkRP.CharacterInfo.Data

---@class DarkRP.Character.PrivateData : DarkRP.CharacterInfo.Data
--- (Default internal field) Saved weapons
---@field Weapons { [string]: { Clip1: integer } }
---
--- (Default internal field) Saved ammo
---@field Ammo { [integer]: integer }

---@class DarkRP.CharacterInfo
---@field Name string Last saved character rp name

---@class DarkRP.Character : DarkRP.CharacterInfo
---@field ID integer? ID in database. If this is `nil` then character is not
--- saved
---@field Player Player Assigned player
---@field LastAccessTime integer Last character loaded timestamp (UTC)
---@field Health integer Last saved character health
---@field Armor integer Last saved character armor
---@field Pos Vector? Last saved character position
---
--- Data that is shared between assigned player
---@field SharedData DarkRP.Character.SharedData
---
--- Data that will be saved in database. Unlike `SharedData` this table is not
--- shared between assigned player
---@field PrivateData DarkRP.Character.PrivateData
DarkRP.Characters.CHARACTER = DarkRP.Characters.CHARACTER or {}

---@class DarkRP.Character
local CHARACTER = DarkRP.Characters.CHARACTER
CHARACTER.__index = CHARACTER

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
    return self:IsValid() and self.Player:GetCharacter() == self
end
