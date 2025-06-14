---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

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
function CHARACTER:Sync()
    net.Start("DarkRPSyncCharacter")

    net.WriteUInt(self.ID, 32)
    net.WriteString(self.Name)
    net.WriteUInt(self.LastAccessTime, 32)
    net.WriteUInt(self.Health, 32)
    net.WriteUInt(self.Armor, 32)
    net.WriteTable(self.SharedData)

    net.Send(self.Player)
end

--- Saves current player position
---@param callback fun(self: DarkRP.Character)?
function CHARACTER:SavePos(callback)
    self:EnsureInDatabase()

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

--- Deletes saved player position
---@param callback fun(self: DarkRP.Character)?
function CHARACTER:DeletePos(callback)
    self:EnsureInDatabase()

    if cvars.Bool("developer") then
        print(string.format("Deleting character %d last pos", self.ID))
    end

    self.Pos = nil

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

--- Saves character into database including position
---@param callback fun(self: DarkRP.Character)?
function CHARACTER:Save(callback)
    hook.Run("CharacterPreSave", self)

    self.LastAccessTime = os.time(os.date("!*t") --[[@as osdate]])

    if self.Player:Alive() then
        self.Pos = self.Player:GetPos()
        self.Health = self.Player:Health()
        self.Armor = self.Player:Armor()
    else
        self.Pos = nil
        self.Health = self.Player:GetMaxHealth()
        self.Armor = self.Player:GetMaxArmor()
    end

    do
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
        MySQLite.query(
            string.format(
                [[INSERT INTO darkrp_characters
                      (steamid, name, health, armor, data)
                      VALUES(%s, %s, %d, %d, %s);
                  SELECT LAST_INSERT_ROWID() AS id;]],
                MySQLite.SQLStr(self.Player:SteamID()),
                MySQLite.SQLStr(self.Name),
                self.Health,
                self.Armor,
                MySQLite.SQLStr(util.TableToJSON({
                    PrivateData = self.PrivateData,
                }))
            ),
            function(rows)
                local id =
                    assert(tonumber(rows[1].id), "Got non number last row id!")

                self.ID = id

                DarkRP.Characters.Loaded[id] = self

                hook.Run("CharacterLoaded", self)
                hook.Run("CharacterSaved", self)

                if callback then
                    callback(self)
                end
            end,
            DarkRP.Characters._TraceAsyncError()
        )
    else
        if self.Pos then
            self:SavePos()
        else
            self:DeletePos()
        end

        MySQLite.query(
            string.format(
                [[UPDATE darkrp_characters
                  SET name = %s,
                      health = %d, armor = %d,
                      data = %s
                  WHERE id = %d]],
                MySQLite.SQLStr(self.Name),
                self.Health,
                self.Armor,
                MySQLite.SQLStr(util.TableToJSON({
                    PrivateData = self.PrivateData,
                })),
                self.ID
            ),
            function()
                hook.Run("CharacterSaved", self)

                if callback then
                    callback(self)
                end
            end,
            DarkRP.Characters._TraceAsyncError()
        )
    end
end

--- Unloads and deletes character
---@param callback fun()?
function CHARACTER:Delete(callback)
    self:Unload()

    MySQLite.query(
        string.format("DELETE FROM darkrp_characters WHERE id = %d", self.ID),
        function()
            if IsValid(self.Player) then
                net.Start("DarkRPDeleteCharacter")
                net.WriteUInt(self.ID, 32)
                net.Send(self.Player)
            end

            if callback then
                callback()
            end
        end,
        DarkRP.Characters._TraceAsyncError()
    )
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
