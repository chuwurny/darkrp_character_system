---@class Player
local PLAYER = FindMetaTable("Player")

--- Throws an error if player is not playing any character
---@see Player.IsEnteredCharacter
function PLAYER:EnsureEnteredCharacter()
    assert(self:IsEnteredCharacter(), "Player must be entered to character")
end

--- Returns `true` if player is playing any character
---
---@return boolean
function PLAYER:IsEnteredCharacter()
    return self:getDarkRPVar("CharacterID") ~= nil
end

--- Returns character id. If player is not playing any character then error will
--- be thrown
---
---@return integer
function PLAYER:GetCharacterID()
    return assert(
        self:getDarkRPVar("CharacterID"),
        "Character is not loaded. You should use PLAYER:IsEnteredCharacter to check before using it!"
    )
end

--- Returns currently playing character. If player is not playing any character
--- then error will be thrown
---
---@return DarkRP.Character
function PLAYER:GetCharacter()
    return DarkRP.Characters.Loaded[self:GetCharacterID()]
end

--- Finds all characters assigned to this player
---
--- WARN: this function can impact performance
---
---@return DarkRP.Character[]
function PLAYER:FindLoadedCharacters()
    ---@type DarkRP.Character[]
    local chars = {}

    for _, char in pairs(DarkRP.Characters.Loaded) do
        if char.Player == self then
            table.insert(chars, char)
        end
    end

    return chars
end
