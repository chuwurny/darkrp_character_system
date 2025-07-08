---@class Player
local PLAYER = FindMetaTable("Player")

--- Creates new character by provided @info.
---
--- Hook "PlayerCanEnterCharacter" is called before creating character.
---
--- After "ValidateCharacterInfo" hook is called before creating character.
---
--- After character is created hook "PlayerCreatedCharacter" is called. After
--- this hook character is being saved and synced between this player.
---
--- Use hook "CreateCharacter" to modify new character before passing it into
--- "CharacterCreated" hook.
---
---@param info DarkRP.CharacterInfo
---@param callback fun(err: string?, char: DarkRP.Character?)
---@param temporary boolean? (Default: false)
---@param force boolean? (Default: false)
---@overload fun(info: DarkRP.CharacterInfo, callback: fun(err: nil, char: DarkRP.Character?), temporary: boolean?, force: true)
function PLAYER:CreateCharacter(info, callback, temporary, force)
    if not force then
        if
            not temporary
            and #self:FindLoadedCharacters()
                ---@diagnostic disable-next-line: undefined-field
                >= (GAMEMODE.Config.MaxCharacters or 2)
        then
            return callback("char_limit", nil)
        end

        local allowed, reason = hook.Run("PlayerCanCreateCharacter", self, info)

        if allowed == false then
            return callback(reason or "no_reason", nil)
        end
    end

    DarkRP.Characters.Create(self:SteamID(), info, function(char)
        char.Temporary = temporary == true

        -- TODO: remove these hook calls. They're deprecated.
        --
        -- HACK: these hooks are still here for the backwards compatibility.
        --
        -- Use "CreateCharacter" and "CharacterCreated" hooks instead!
        hook.Run("CreatePlayerCharacter", char, info)
        hook.Run("PlayerCreatedCharacter", char)
    end, callback, force, true)
end

--- Loads all characters from database.
---
--- WARN: you shouldn't use it unless you know what you're doing. See
--- `PLAYER:FindLoadedCharacters` to find all loaded characters.
---@see Player.FindLoadedCharacters
---
--- Internally calls `DarkRP.Characters.LoadBySteamID64` so check it out for
--- important information
---@see DarkRP.Characters.LoadBySteamID64
---
---@param callback fun(chars: DarkRP.CharacterInfo[])
function PLAYER:LoadCharacters(callback)
    DarkRP.Characters.LoadBySteamID(self:SteamID(), callback)
end

function PLAYER:UnloadCharacters()
    for _, char in pairs(DarkRP.Characters.Loaded) do
        if char.Player == self and not char.ManualUnload then
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
--- 1. Hook "CharacterRestore" is called when player is allowed to enter
--- character.
--- Modify player in this hook!
---
--- 2. Hook "PlayerEnteredCharacter" is called after "CharacterRestore".
--- Character is ready to be used!
---
--- 3. `PLAYER:Spawn` is forcefully called with modified behavior. E.g. hooks
--- like "PlayerSpawn" will be called here!
---
--- 4. Hook "CharacterPrePlayerSpawn" is called before running default
--- gamemode's `GM:PlayerSpawn` behavior. After `GM:PlayerSpawn` hook
--- "CharacterPostPlayerSpawn" is called.
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
---
--- (Default: false) If `true` then it enters character by force.
--- "PlayerCanEnterCharacter" wont be called and return value will be _always_
--- `true`
---@param force boolean?
---
---@return boolean success
---@return string? err
---@overload fun(self: self, char: DarkRP.MaybeCharacter, force: true): true, nil
function PLAYER:EnterCharacter(char, force)
    assert(
        not self:IsEnteredCharacter(),
        "Leave character first. Use PLAYER:LeaveCharacter"
    )

    char = DarkRP.Characters.ToCharacter(char)

    if not force then
        local allowed, reason = hook.Run("PlayerCanEnterCharacter", self, char)

        if allowed == false then
            return false, reason or "no_reason"
        end
    end

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
---
--- (Default: false) If `true` then it will ignore all checks and wont run
--- "PlayerCanLeaveCharacter" and this function will _always_ return `true`
---@param force boolean?
---
---@return boolean `true` if player left
---@overload fun(self: self, force: true): true
function PLAYER:LeaveCharacter(force)
    assert(
        self:IsEnteredCharacter(),
        "Enter character first. Use PLAYER:EnterCharacter"
    )

    local char = self:GetCharacter()

    if not force then
        if hook.Run("PlayerCanLeaveCharacter", self, char) == false then
            return false
        end
    end

    char:Save()
    char:Sync()

    self:setDarkRPVar("CharacterID", nil)

    self:KillSilent()

    hook.Run("PlayerLeftCharacter", self, char)

    return true
end
