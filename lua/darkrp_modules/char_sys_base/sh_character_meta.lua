---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

---@class DarkRP.CharacterInfo
---@field Name string

---@class DarkRP.Character : DarkRP.CharacterInfo
---@field ID integer?
---@field Player Player
---@field LastAccessTime integer
---@field Health integer
---@field Armor integer
---@field Pos Vector?
---@field SharedData table
---@field PrivateData table
DarkRP.Characters.CHARACTER = DarkRP.Characters.CHARACTER or {}

---@class DarkRP.Character
local CHARACTER = DarkRP.Characters.CHARACTER
CHARACTER.__index = CHARACTER

---@return boolean
function CHARACTER:IsValid()
    return self.ID ~= nil and IsValid(self.Player)
end

---@return boolean
function CHARACTER:FirstTimeCreated()
    return self.LastAccessTime == 0
end

---@return boolean
function CHARACTER:IsActive()
    return self:IsValid() and self.Player:GetCharacter() == self
end
