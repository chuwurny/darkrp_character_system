DarkRP.Characters.DATABASE_VERSION = 4

local MIGRATE_VERSION = {
    -- Add "dead" column
    [2] = function(next)
        MySQLite.query(
            string.format(
                "ALTER TABLE darkrp_characters ADD dead %s NOT NULL DEFAULT 0",

                MySQLite.isMySQL() and "ENUM(0, 1)"
                    or "INTEGER CHECK(dead IN (0, 1))"
            ),
            next,
            DarkRP.Characters._TraceAsyncError()
        )
    end,

    -- Remove "name" column"
    [3] = function(next)
        local function dropName()
            if MySQLite.isMySQL() then
                MySQLite.query(
                    "ALTER TABLE darkrp_characters DROP COLUMN name",
                    next,
                    DarkRP.Characters._TraceAsyncError()
                )
            else
                -- SQLite doesn't support `ALTER TABLE ... DROP COLUMN`
                -- throwing syntax error
                --
                -- P.S. https://stackoverflow.com/a/21019278
                -- P.P.S. fixed in database version 4

                next()
            end
        end

        MySQLite.query(
            "SELECT id, name, data FROM darkrp_characters",
            function(rows)
                if not rows then
                    return
                end

                local leftToAlter = #rows

                local function tryDropName()
                    leftToAlter = leftToAlter - 1

                    if leftToAlter == 0 then
                        dropName()
                    end
                end

                for _, cols in ipairs(rows) do
                    local data = util.JSONToTable(cols.data)

                    print(
                        string.format(
                            "[DarkRP Characters] Migrating character %s",
                            cols.id
                        )
                    )

                    if not data then
                        ErrorNoHalt(
                            string.format(
                                "Failed to migrate character %s: can't parse/corrupted data",
                                cols.id
                            )
                        )

                        tryDropName()
                    else
                        data.PrivateData = data.PrivateData or {}
                        data.PrivateData.Name = cols.name

                        local updateErrHandler =
                            DarkRP.Characters._TraceAsyncError()

                        MySQLite.query(
                            string.format(
                                "UPDATE darkrp_characters SET data=%s WHERE id=%d",
                                MySQLite.SQLStr(util.TableToJSON(data)),
                                cols.id
                            ),
                            tryDropName,
                            function(err)
                                tryDropName()

                                updateErrHandler(err)
                            end
                        )
                    end
                end
            end,
            DarkRP.Characters._TraceAsyncError()
        )
    end,

    -- (SQLite migration)
    --
    -- "Drop" "name" SQLite column by creating a new table
    --
    -- Character not being created because we're not inserting "name" column. To
    -- fix this issue without writing spaghetti code we just create a whole new
    -- table!
    [4] = function(next)
        if MySQLite.isMySQL() then
            return next()
        end

        MySQLite.query(
            string.format(
                [[BEGIN TRANSACTION;
                  CREATE TABLE darkrp_characters_v4(
                      id INTEGER NOT NULL PRIMARY KEY,
                      steamid VARCHAR(32) NOT NULL,
                      last_access_time INTEGER NOT NULL DEFAULT 0,
                      health INTEGER NOT NULL,
                      armor INTEGER NOT NULL,
                      data TEXT NOT NULL DEFAULT "{}",
                      dead %s NOT NULL DEFAULT 0
                  );
                  INSERT INTO darkrp_characters_v4
                      (id, steamid, last_access_time, health, armor, data)
                      SELECT id, steamid, last_access_time, health, armor, data
                          FROM darkrp_characters;
                  DROP TABLE darkrp_characters;
                  ALTER TABLE darkrp_characters_v4 RENAME TO darkrp_characters;
                  COMMIT;]],
                MySQLite.isMySQL() and "ENUM(0, 1)"
                    or "INTEGER CHECK(dead IN (0, 1))"
            ),
            next,
            DarkRP.Characters._TraceAsyncError()
        )
    end,
}

hook.Add("DatabaseInitialized", "DarkRPCharacters_InitDB", function()
    MySQLite.query(
        [[CREATE TABLE IF NOT EXISTS darkrp_chars_db_state(
            var VARCHAR(32) NOT NULL PRIMARY KEY,
            value TEXT NOT NULL
        )]],
        nil,
        DarkRP.Characters._TraceAsyncError()
    )

    MySQLite.query(
        [[CREATE TABLE IF NOT EXISTS darkrp_characters(
            id INTEGER NOT NULL PRIMARY KEY,
            steamid VARCHAR(32) NOT NULL,
            name VARCHAR(255) NOT NULL,
            last_access_time INTEGER NOT NULL DEFAULT 0,
            health INTEGER NOT NULL,
            armor INTEGER NOT NULL,
            data TEXT NOT NULL DEFAULT "{}"
        )]],
        nil,
        DarkRP.Characters._TraceAsyncError()
    )

    MySQLite.query(
        string.format(
            [[CREATE TABLE IF NOT EXISTS darkrp_chars_pos(
                char_id INTEGER NOT NULL,
                map VARCHAR(128) NOT NULL,
                pos_x FLOAT NOT NULL,
                pos_y FLOAT NOT NULL,
                pos_z FLOAT NOT NULL,
                %s
            )]],
            MySQLite.isMySQL() and "UNIQUE map_char_id (map, char_id)"
                or "UNIQUE(map, char_id)"
        ),
        nil,
        DarkRP.Characters._TraceAsyncError()
    )

    -- migrate
    MySQLite.query(
        "SELECT value FROM darkrp_chars_db_state WHERE var = 'version' LIMIT 1",
        function(rows)
            local version

            if not rows then
                version = 1
            else
                version = tonumber(rows[1].value) or 1
            end

            local oldVersion = version

            if version == DarkRP.Characters.DATABASE_VERSION then
                return
            elseif version > DarkRP.Characters.DATABASE_VERSION then
                ErrorNoHalt(
                    string.format(
                        "Database version is more newer than character system's current database version?! (%d > %d). Something horrible happen! Try to update DarkRP characters base ASAP!",
                        version,
                        DarkRP.Characters.DATABASE_VERSION
                    )
                )
            end

            local function migrateNext()
                version = version + 1

                if version > DarkRP.Characters.DATABASE_VERSION then
                    print(
                        string.format(
                            "[DarkRP Characters] Migration from %d to %d done!",
                            oldVersion,
                            DarkRP.Characters.DATABASE_VERSION
                        )
                    )

                    MySQLite.query(
                        string.format(
                            "REPLACE INTO darkrp_chars_db_state VALUES('version', %d)",
                            DarkRP.Characters.DATABASE_VERSION
                        ),
                        nil,
                        DarkRP.Characters._TraceAsyncError()
                    )

                    return
                end

                print(
                    string.format(
                        "[DarkRP Characters] Migrating to version %d",
                        version
                    )
                )

                MIGRATE_VERSION[version](migrateNext)
            end

            migrateNext()
        end
    )
end)

---@param ply Player
hook.Add("PlayerDeath", "DarkRPCharacters_DeletePos", function(ply)
    if not ply:IsEnteredCharacter() then
        return
    end

    ply:GetCharacter():DeletePos()
end)

hook.Add("PlayerDeathThink", "DarkRPCharacters_DisallowRespawn", function(ply)
    ---@cast ply Player

    if not ply:IsEnteredCharacter() then
        return false
    end

    if hook.Run("CharacterCanRespawn", ply:GetCharacter()) == false then
        return false
    end
end)

local function overridePlayerSpawn()
    GAMEMODE._CharSys_oPlayerSpawn = GAMEMODE._CharSys_oPlayerSpawn
        or GAMEMODE.PlayerSpawn

    ---@param ply Player
    function GAMEMODE:PlayerSpawn(ply)
        if not ply:IsEnteredCharacter() then
            ply:KillSilent()

            return
        end

        local char

        if ply._EnteredCharacter then
            char = ply:GetCharacter()

            hook.Run("CharacterPrePlayerSpawn", char)
        end

        self:_CharSys_oPlayerSpawn(ply)

        if ply._EnteredCharacter then
            hook.Run("CharacterPostPlayerSpawn", char)

            if GAMEMODE.Config.CharacterSpawnsOnLastPos ~= false then
                local pos = char.Pos
                pos = hook.Run("CharacterOverrideSpawnPos", char, pos) or pos

                if pos then
                    ply:SetPos(pos)
                end
            end

            if GAMEMODE.Config.CharacterRestoreLastHealth ~= false then
                local hp = char.Health
                hp = hook.Run("CharacterOverrideHealth", char, hp) or hp

                ply:SetHealth(hp)
            end

            if GAMEMODE.Config.CharacterRestoreLastArmor ~= false then
                local ar = char.Armor
                ar = hook.Run("CharacterOverrideArmor", char, ar) or ar

                ply:SetArmor(ar)
            end

            if not char.Dead then
                ply:RemoveAllItems()

                if char.PrivateData.Weapons then
                    local ignoreWeapons = GAMEMODE.Config.DontSaveCharacterWeapons
                        or {}

                    for class, info in pairs(char.PrivateData.Weapons) do
                        if not ignoreWeapons[class] then
                            local weapon = ply:Give(class, true)

                            if IsValid(weapon) then
                                weapon:SetClip1(info.Clip1)
                            end
                        end
                    end
                end

                if char.PrivateData.Ammo then
                    for type, amount in pairs(char.PrivateData.Ammo) do
                        ply:SetAmmo(amount, type)
                    end
                end
            end

            char.LastAccessTime = os.time(os.date("!*t") --[[@as osdate]])
            char.Dead = false
            char:Sync("info")

            hook.Run("CharacterPreSpawn", char)
            hook.Run("CharacterSpawn", char)
        end
    end
end

if GAMEMODE then
    overridePlayerSpawn()
else
    hook.Add(
        "PostGamemodeLoaded",
        "DarkRPCharacters_OverrideSpawn",
        overridePlayerSpawn
    )
end

hook.Add("PlayerDisconnected", "DarkRPCharacters_LeaveCharacter", function(ply)
    ply:UnloadCharacters()
end)

hook.Add("playerGetSalary", "DarkRPCharacters_NoCharNoSalary", function(ply)
    ---@cast ply Player

    if not ply:IsEnteredCharacter() then
        return false, nil, false
    end
end)
