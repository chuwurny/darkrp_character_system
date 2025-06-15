---@class Player
local PLAYER = FindMetaTable("Player")

--- Creates new character by provided @info.
---
--- Hook "PlayerCanEnterCharacter" is called before creating character.
---
--- After character is created hook "PlayerCreatedCharacter" is raised. After
--- this hook character is being saved and synced between this player.
---
--- Use hook "CreatePlayerCharacter" to modify new character before passing it
--- into "PlayerCreatedCharacter" hook.
---
---@param info DarkRP.CharacterInfo
---@param callback fun(err: string?, char: DarkRP.Character?)
function PLAYER:CreateCharacter(info, callback)
    ---@diagnostic disable-next-line: undefined-field
    if #self:FindLoadedCharacters() >= (GAMEMODE.Config.MaxCharacters or 2) then
        return callback("char_limit", nil)
    end

    if utf8.len(info.Name) > (GAMEMODE.Config.CharacterMaxNameLength or 32) then
        return callback("long_name", nil)
    end

    local allowed, reason = hook.Run("PlayerCanCreateCharacter", self, info)

    if allowed == false then
        return callback(reason or "no_reason", nil)
    end

    local char = DarkRP.Characters.New(self)
    char.Name = info.Name

    hook.Run("CreatePlayerCharacter", char, info)

    char:Save(function()
        char:Sync()

        callback(nil, char)
    end)
end

--- Loads all characters from database.
---
--- WARN: you shouldn't use it unless you know what you're doing. See
--- `PLAYER:FindLoadedCharacters` to find all loaded characters.
---@see Player.FindLoadedCharacters
---
--- When loading characters hook "CharacterLoad" will be called to restore data
--- from database (`CHARACTER.PrivateData`). After this hook "CharacterLoaded"
--- is called and character is synchronized with this player.
---
--- NOTE: `DarkRP.Characters.Loaded` is modified on hook "CharacterLoaded"!
---
---@param callback fun(chars: DarkRP.CharacterInfo[])
function PLAYER:LoadCharacters(callback)
    MySQLite.query(
        string.format(
            [[SELECT
                  id, steamid,
                  name,
                  last_access_time,
                  health, armor,
                  data,
                  darkrp_chars_pos.pos_x,
                  darkrp_chars_pos.pos_y,
                  darkrp_chars_pos.pos_z
              FROM
                  darkrp_characters
              LEFT JOIN darkrp_chars_pos ON
                  darkrp_characters.id = darkrp_chars_pos.char_id AND
                  darkrp_chars_pos.map = %s
              WHERE steamid = %s]],
            MySQLite.SQLStr(game.GetMap()),
            MySQLite.SQLStr(self:SteamID())
        ),
        function(rows)
            if not IsValid(self) then
                return
            end

            ---@type DarkRP.CharacterInfo[]
            local chars = {}

            for _, cols in ipairs(rows or {}) do
                local data = util.JSONToTable(cols.data)

                if data == nil then
                    ErrorNoHalt(
                        string.format(
                            'Player %s character %d has corrupted database "data" field. Not loading character until fixed!',
                            self,
                            cols.id
                        )
                    )
                else
                    ---@type DarkRP.Character
                    local char = DarkRP.Characters.New(self)

                    char.ID = tonumber(cols.id) --[[@as integer]]
                    char.Player = self

                    char.Name = cols.name

                    char.Armor = tonumber(cols.armor) --[[@as integer]]
                    char.Health = tonumber(cols.health) --[[@as integer]]

                    char.LastAccessTime = tonumber(cols.last_access_time) --[[@as integer]]

                    if cols.pos_x and cols.pos_x ~= "NULL" then
                        char.Pos = Vector(
                            tonumber(cols.pos_x),
                            tonumber(cols.pos_y),
                            tonumber(cols.pos_z)
                        )
                    end

                    char.PrivateData = data.PrivateData

                    hook.Run(
                        "CharacterLoad",
                        char,
                        char.PrivateData,
                        char.SharedData
                    )

                    DarkRP.Characters.Loaded[char.ID] = char

                    hook.Run("CharacterLoaded", char)

                    char:Sync()

                    table.insert(chars, char)
                end
            end

            callback(chars)
        end,
        DarkRP.Characters._TraceAsyncError()
    )
end

function PLAYER:UnloadCharacters()
    for _, char in pairs(DarkRP.Characters.Loaded) do
        if char.Player == self then
            char:Unload()
        end
    end
end

---@class Player
---@field _EnteredCharacter boolean?

--- Enters a character. If player is already playing some character error will
--- be thrown. Leave character before calling this function!
---@see Player.IsEnteredCharacter
---@see Player.LeaveCharacter
---
--- Hook "PlayerCanCreateCharacter" is called when trying to enter this
--- function. If hook return `false` then its results will be passed as return
--- values.
---
--- After granted permission to enter character, DarkRP variables "CharacterID",
--- "rpname" will be modified. Following things will happen in specified order:
---
--- 1. Hook "CharacterRestore" is called when player is allowed to enter character.
--- Modify player in this hook!
---
--- 2. Hook "PlayerEnteredCharacter" is called after "CharacterRestore".
--- Character is ready to be used!
---
--- 3. `PLAYER:Spawn` is forcefully called with modified behavior. E.g. hooks
--- like "PlayerSpawn" will be called here!
---
--- 4. Hook "CharacterPrepareToSpawn" is called before running default
--- gamemode's `GM:PlayerSpawn` behavior.
---
--- 5. Hook "CharacterOverrideSpawnPos" is called which allows to override
--- player's spawn position.
---
--- 6. Hook "CharacterOverrideHealth" is called which allows to override
--- player's health.
---
--- 7. Hook "CharacterOverrideArmor" is called which allows to override
--- player's armor.
---
--- 8. Player's items (weapons, ammo) will be stripped and saved weapons & ammo
--- amount from character will be loaded.
---
--- 9. Hook "CharacterPreSpawn" is called. Modify player here!
---
--- 10. Hook "CharacterSpawn" is called. Player is ready!
---
---@param char DarkRP.MaybeCharacter
---@return boolean success
---@return string? err
function PLAYER:EnterCharacter(char)
    assert(
        not self:IsEnteredCharacter(),
        "Leave character first. Use PLAYER:LeaveCharacter"
    )

    char = DarkRP.Characters.ToCharacter(char)

    local allowed, reason = hook.Run("PlayerCanEnterCharacter", self, char)

    if allowed == false then
        return false, reason or "no_reason"
    end

    self:setDarkRPVar("rpname", char.Name)
    self:setDarkRPVar("CharacterID", char.ID)

    hook.Run("CharacterRestore", char, char.PrivateData)
    hook.Run("PlayerEnteredCharacter", self, char)

    self._EnteredCharacter = true
    self:Spawn()
    self._EnteredCharacter = nil

    return true
end

--- Leaves character. If player is not entered character error will be thrown.
---@see Player.IsEnteredCharacter
---
--- Hook "PlayerCanLeaveCharacter" will be called which allows to prevent player
--- from leaving character. Useful when player is handcuffed and trying to leave
--- character! If hook returns `false` then this function will return `false`.
---
--- After this hook character will be saved and synced. "CharacterID" DarkRP
--- variable will be
--- set to `nil` and `PLAYER:KillSilent` will be called.
---
--- In the end hook "PlayerLeftCharacter" will be called and `true` will be
--- returned.
---
---@return boolean
function PLAYER:LeaveCharacter()
    assert(
        self:IsEnteredCharacter(),
        "Enter character first. Use PLAYER:EnterCharacter"
    )

    local char = self:GetCharacter()

    if hook.Run("PlayerCanLeaveCharacter", self, char) == false then
        return false
    end

    char:Save()
    char:Sync()

    self:setDarkRPVar("CharacterID", nil)

    self:KillSilent()

    hook.Run("PlayerLeftCharacter", self, char)

    return true
end

--- Helper function to modify rp name and sync it with player.
---@param newName string
function PLAYER:SetCharacterName(newName)
    assert(self:IsEnteredCharacter(), "Enter character first")

    self:setDarkRPVar("rpname", newName)
    self:GetCharacter().Name = newName
    self:GetCharacter():Sync()
end
