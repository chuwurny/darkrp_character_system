---@class Player
local PLAYER = FindMetaTable("Player")

function PLAYER:EnsureEnteredCharacter()
    assert(self:IsEnteredCharacter(), "Player must be entered to character")
end

---@return boolean
function PLAYER:IsEnteredCharacter()
    return self:getDarkRPVar("CharacterID") ~= nil
end

---@return integer
function PLAYER:GetCharacterID()
    return assert(
        self:getDarkRPVar("CharacterID"),
        "Character is not loaded. You should use PLAYER:IsEnteredCharacter to check before using it!"
    )
end

---@return DarkRP.Character
function PLAYER:GetCharacter()
    return DarkRP.Characters.Loaded[self:GetCharacterID()]
end

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
