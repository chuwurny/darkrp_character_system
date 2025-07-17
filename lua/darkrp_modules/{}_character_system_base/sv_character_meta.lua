---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

---@type integer
DarkRP.Characters.NextTemporaryID = DarkRP.Characters.NextTemporaryID or 0

---@class DarkRP.Character
local CHARACTER = DarkRP.Characters.CHARACTER

function CHARACTER:__index(key)
    local value = CHARACTER[key]

    if value ~= nil then
        return value
    end

    value = rawget(self, key)

    if value ~= nil then
        return value
    end

    return rawget(self, "_UserData")[key]
end

local DEFAULT_FIELDS = {
    ["ID"] = true,
    ["Player"] = true,
    ["LastAccessTime"] = true,
    ["Health"] = true,
    ["Armor"] = true,
    ["Dead"] = true,
    ["Pos"] = true,
    ["Temporary"] = true,
    ["ManualUnload"] = true,
    ["SharedData"] = true,
    ["PrivateData"] = true,
    ["_UserData"] = true,
    ["_Receivers"] = true,
}

function CHARACTER:__newindex(key, value)
    if DEFAULT_FIELDS[key] then
        rawset(self, key, value)
    else
        self:SetField(key, value)
    end
end

---@protected
function CHARACTER:EnsureInDatabase()
    assert(
        self.ID,
        "Character is not saved in database. Did you forget to call CHARACTER:Save?"
    )
end

--- Fully synchronizes character with creator
---@param fields ("all"|"info"|"data")? Default: "all"
---@param receivers (Player|Player[]|CRecipientFilter)?
function CHARACTER:Sync(fields, receivers)
    net.Start("DarkRPSyncCharacter")

    local syncAll = not fields or fields == "all"
    local syncInfo = syncAll or fields == "info"
    local syncData = syncAll or fields == "data"

    net.WriteUInt(self.ID, 32)

    net.WriteBool(syncInfo)

    if syncInfo then
        net.WriteUInt64(util.SteamIDTo64(self.SteamID))
        net.WriteUInt(self.LastAccessTime, 32)
        net.WriteUInt(self.Health, 32)
        net.WriteUInt(self.Armor, 32)
        net.WriteBool(self.Dead)
    end

    net.WriteBool(syncData)

    if syncData then
        net.WriteTable(self.SharedData)
    end

    net.Send(receivers or self._Receivers)
end

--- Saves current player position
---@param callback fun(self: DarkRP.Character)?
function CHARACTER:SavePos(callback)
    self:EnsureInDatabase()

    if self.Temporary or GAMEMODE.Config.CharacterSpawnsOnLastPos == false then
        if callback then
            callback(self)
        end
    else
        MySQLite.query(
            string.format(
                [[REPLACE INTO darkrp_chars_pos
                  (char_id, map, pos_x, pos_y, pos_z)
                  VALUES(%d, %s, %d, %d, %d)]],
                self.ID,
                MySQLite.SQLStr(game.GetMap()),
                self.Pos.x,
                self.Pos.y,
                self.Pos.z
            ),
            function()
                if callback then
                    callback(self)
                end
            end,
            DarkRP.Characters._TraceAsyncError()
        )
    end
end

--- Deletes saved player position
---@param callback fun(self: DarkRP.Character)?
function CHARACTER:DeletePos(callback)
    self:EnsureInDatabase()

    if cvars.Bool("developer") then
        print(string.format("Deleting character's %s last pos", self))
    end

    self.Pos = nil

    if self.Temporary or GAMEMODE.Config.CharacterSpawnsOnLastPos == false then
        if callback then
            callback(self)
        end
    else
        MySQLite.query(
            string.format(
                "DELETE FROM darkrp_chars_pos WHERE char_id = %d",
                self.ID
            ),
            function()
                if callback then
                    callback(self)
                end
            end,
            DarkRP.Characters._TraceAsyncError()
        )
    end
end

--- Saves character into database including position
---@param callback fun(self: DarkRP.Character)?
function CHARACTER:Save(callback)
    hook.Run("CharacterPreSave", self)

    if not self:IsOffline() then
        if self.Player:Alive() then
            self.Pos = self.Player:GetPos()
            self.Health = self.Player:Health()
            self.Armor = self.Player:Armor()
            self.Dead = false
        else
            self.Pos = nil
            self.Health = self.Player:GetMaxHealth()
            self.Armor = self.Player:GetMaxArmor()
            self.Dead = true
        end

        if self.Dead then
            self.PrivateData.Weapons = nil
            self.PrivateData.Ammo = nil
        else
            local ignoreWeapons = GAMEMODE.Config.DontSaveCharacterWeapons or {}

            local weapons = {}
            local ammo = {}

            for _, weapon in ipairs(self.Player:GetWeapons()) do
                ---@cast weapon Weapon

                if not ignoreWeapons[weapon:GetClass()] then
                    weapons[weapon:GetClass()] = {
                        Clip1 = weapon:Clip1(),
                    }

                    local ammoType = weapon:GetPrimaryAmmoType()

                    if not ammo[ammoType] then
                        ammo[ammoType] = self.Player:GetAmmoCount(ammoType)
                    end
                end
            end

            self.PrivateData.Weapons = weapons
            self.PrivateData.Ammo = ammo
        end
    end

    hook.Run("CharacterSave", self, self.SharedData, self.PrivateData)

    if not self.ID then
        local function insertCallback(rows)
            local id =
                assert(tonumber(rows[1].id), "Got non number last row id!")

            self.ID = id

            DarkRP.Characters.Loaded[id] = self

            hook.Run("CharacterLoaded", self)
            hook.Run("CharacterSaved", self)

            if callback then
                callback(self)
            end
        end

        if self.Temporary then
            insertCallback({
                {
                    id = 4294967295 --[[ MAX_UINT ]]
                        - DarkRP.Characters.NextTemporaryID,
                },
            })

            DarkRP.Characters.NextTemporaryID = DarkRP.Characters.NextTemporaryID
                + 1
        else
            MySQLite.query(
                string.format(
                    [[INSERT INTO darkrp_characters
                      (steamid, health, armor, dead, last_access_time, data)
                      VALUES(%s, %d, %d, %d, %d, %s);
                      SELECT LAST_INSERT_ROWID() AS id;]],
                    MySQLite.SQLStr(self.SteamID),
                    self.Health,
                    self.Armor,
                    self.Dead and 1 or 0,
                    self.LastAccessTime,
                    MySQLite.SQLStr(util.TableToJSON({
                        PrivateData = self.PrivateData,
                    }))
                ),
                insertCallback,
                DarkRP.Characters._TraceAsyncError()
            )
        end
    else
        if self.Pos then
            self:SavePos()
        else
            self:DeletePos()
        end

        local function updateCallback()
            hook.Run("CharacterSaved", self)

            if callback then
                callback(self)
            end
        end

        if self.Temporary then
            updateCallback()
        else
            MySQLite.query(
                string.format(
                    [[UPDATE darkrp_characters
                      SET health = %d, armor = %d,
                          dead = %d,
                          data = %s
                      WHERE id = %d]],
                    self.Health,
                    self.Armor,
                    self.Dead and 1 or 0,
                    MySQLite.SQLStr(util.TableToJSON({
                        PrivateData = self.PrivateData,
                    })),
                    self.ID
                ),
                updateCallback,
                DarkRP.Characters._TraceAsyncError()
            )
        end
    end
end

--- Unloads and deletes character
---@param callback fun()?
function CHARACTER:Delete(callback)
    self:Unload()

    local function deleteCallback()
        if IsValid(self.Player) then
            net.Start("DarkRPDeleteCharacter")
            net.WriteUInt(self.ID, 32)
            net.Send(self._Receivers)
        end

        if callback then
            callback()
        end
    end

    if self.Temporary then
        deleteCallback()
    else
        MySQLite.query(
            string.format(
                "DELETE FROM darkrp_characters WHERE id = %d",
                self.ID
            ),
            deleteCallback,
            DarkRP.Characters._TraceAsyncError()
        )
    end
end

--- Unloads character on receivers clientside.
---
--- WARNING: Don't use it if you don't know what you're doing! See
--- `CHARACTER:RemoveListener` as an better alternative
---@see DarkRP.Character.RemoveListener
---
---@param receivers Player|Player[]|CRecipientFilter
function CHARACTER:UnloadFor(receivers)
    net.Start("DarkRPUnloadCharacter")
    net.WriteUInt(self.ID, 32)
    net.Send(receivers)
end

--- Unloads character. Character will become unusable until will be loaded
--- again. Don't use it if you don't know what you're doing!
function CHARACTER:Unload()
    if self:IsActive() then
        self.Player:LeaveCharacter(true)
    end

    if IsValid(self.Player) then
        self:UnloadFor(self._Receivers)
    end

    DarkRP.Characters.Loaded[self.ID] = nil

    hook.Run("CharacterUnloaded", self)
end

--- Sets shared/private data value.
---
--- If @addToPrivateData is not true, then this value become temporary (aka
--- shared), and will not be saved into the database.
---@see DarkRP.Character.SharedData
---
--- If you want to save data without sharing with player, check out
--- `CHARACTER.PrivateData`
---@see DarkRP.Character.PrivateData
---
---@param key any
---@param value any
---@param addToPrivateData boolean?
function CHARACTER:SetData(key, value, addToPrivateData)
    if cvars.Bool("developer") then
        print(
            string.format(
                "%s set data %s to %s",
                self,
                tostring(key),
                tostring(value)
            )
        )

        debug.Trace()
    end

    self.SharedData[key] = value

    if addToPrivateData then
        self.PrivateData[key] = value
    end

    self:SyncData(key)
end

--- Synchronizes data value with client.
---
---@param key any
---@param receivers (Player|Player[]|CRecipientFilter)?
function CHARACTER:SyncData(key, receivers)
    -- prevent sending data when character is loading
    if not self.ID then
        return
    end

    local value = self.SharedData[key]

    net.Start("DarkRPSyncCharacterData")
    net.WriteUInt(self.ID, 32)
    net.WriteType(key)
    net.WriteType(value)
    net.Send(receivers or self._Receivers)
end

---@param ply Player
---@return boolean
function CHARACTER:IsListening(ply)
    return table.HasValue(self._Receivers:GetPlayers(), ply)
end

---@param ply Player
---@param doSync boolean? (Default: true)
function CHARACTER:AddListener(ply, doSync)
    self._Receivers:AddPlayer(ply)

    if doSync ~= false then
        self:Sync("all", ply)
    end
end

---@param ply Player
function CHARACTER:RemoveListener(ply)
    self._Receivers:RemovePlayer(ply)
    self:UnloadFor(ply)
end

--- Safely sets field value.
---
--- Calls "CharacterCanSetField". If value can't be set then "disallow" will be
--- returned with error string.
---
--- After that "CharacterOverrideField" hook is called. If field is overridden
--- by this hook then return status would be changed to "overridden" otherwise
--- status will be "set"
---
--- Hook "CharacterFieldPreSet" will be called _before_ setting the field.
---
--- Hook "CharacterFieldSet" will be called _after_ setting the field.
---
---@return "set"|"overridden"|"disallow" status
---@return (string|"no_reason")? err
function CHARACTER:SetField(name, value)
    local canChange, reason =
        hook.Run("CharacterCanSetField", self, name, value)

    if canChange == false then
        if cvars.Bool("developer") then
            print(
                "Prevent setting",
                name,
                "for character",
                self,
                "because",
                reason or "*no reason"
            )
        end

        return "disallow", reason or "no_reason"
    end

    local overriddenValue =
        hook.Run("CharacterOverrideField", self, name, value)

    local status

    if overriddenValue ~= nil then
        status = "overridden"

        value = overriddenValue
    else
        status = "set"
    end

    hook.Run("CharacterFieldPreSet", self, name, value)

    self._UserData[name] = value

    hook.Run("CharacterFieldSet", self, name, value)

    return status
end
