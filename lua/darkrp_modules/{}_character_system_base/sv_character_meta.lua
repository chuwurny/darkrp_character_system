---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

---@type integer
DarkRP.Characters.NextTemporaryID = DarkRP.Characters.NextTemporaryID or 0

---@class DarkRP.Character
local CHARACTER = DarkRP.Characters.CHARACTER
CHARACTER.__index = CHARACTER

---@protected
function CHARACTER:EnsureInDatabase()
    assert(
        self.ID,
        "Character is not saved in database. Did you forget to call CHARACTER:Save?"
    )
end

--- Fully synchronizes character with creator
---@param fields ("all"|"info"|"data")? Default: "all"
function CHARACTER:Sync(fields)
    net.Start("DarkRPSyncCharacter")

    local syncAll = not fields or fields == "all"
    local syncInfo = syncAll or fields == "info"
    local syncData = syncAll or fields == "data"

    net.WriteUInt(self.ID, 32)

    net.WriteBool(syncInfo)

    if syncInfo then
        net.WriteString(self.Name)
        net.WriteUInt(self.LastAccessTime, 32)
        net.WriteUInt(self.Health, 32)
        net.WriteUInt(self.Armor, 32)
        net.WriteBool(self.Dead)
    end

    net.WriteBool(syncData)

    if syncData then
        net.WriteTable(self.SharedData)
    end

    net.Send(self.Player)
end

--- Saves current player position
---@param callback fun(self: DarkRP.Character)?
function CHARACTER:SavePos(callback)
    self:EnsureInDatabase()

    if self.Temporary then
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

    if self.Temporary then
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

    self.LastAccessTime = os.time(os.date("!*t") --[[@as osdate]])

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
        self.PrivateData.Weapons = {}
        self.PrivateData.Ammo = {}
    else
        local weapons = {}
        local ammo = {}

        for _, weapon in ipairs(self.Player:GetWeapons()) do
            ---@cast weapon Weapon

            weapons[weapon:GetClass()] = {
                Clip1 = weapon:Clip1(),
            }

            local ammoType = weapon:GetPrimaryAmmoType()

            if not ammo[ammoType] then
                ammo[ammoType] = self.Player:GetAmmoCount(ammoType)
            end
        end

        self.PrivateData.Weapons = weapons
        self.PrivateData.Ammo = ammo
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
                      (steamid, name, health, armor, dead, data)
                      VALUES(%s, %s, %d, %d, %d, %s);
                  SELECT LAST_INSERT_ROWID() AS id;]],
                    MySQLite.SQLStr(self.Player:SteamID()),
                    MySQLite.SQLStr(self.Name),
                    self.Health,
                    self.Armor,
                    self.Dead and 1 or 0,
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
                      SET name = %s,
                          health = %d, armor = %d,
                          dead = %d,
                          data = %s
                      WHERE id = %d]],
                    MySQLite.SQLStr(self.Name),
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
            net.Send(self.Player)
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

--- Unloads character. Character will become unusable until will be loaded
--- again. Don't use it if you don't know what you're doing!
function CHARACTER:Unload()
    if
        self.Player:IsEnteredCharacter()
        and self.Player:GetCharacter() == self
    then
        self.Player:LeaveCharacter()
    end

    if IsValid(self.Player) then
        net.Start("DarkRPUnloadCharacter")
        net.WriteUInt(self.ID, 32)
        net.Send(self.Player)
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
    self.SharedData[key] = value

    if addToPrivateData then
        self.PrivateData[key] = value
    end

    net.Start("DarkRPSyncCharacterData")
    net.WriteUInt(self.ID, 32)
    net.WriteType(key)
    net.WriteType(value)
    net.Send(self.Player)
end
