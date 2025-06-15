hook.Add("DatabaseInitialized", "DarkRPCharacters_InitDB", function()
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
        [[CREATE TABLE IF NOT EXISTS darkrp_chars_pos(
            char_id INTEGER NOT NULL,
            map VARCHAR(128) NOT NULL,
            pos_x FLOAT NOT NULL,
            pos_y FLOAT NOT NULL,
            pos_z FLOAT NOT NULL,

            UNIQUE(map, char_id)
        )]],
        nil,
        DarkRP.Characters._TraceAsyncError()
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

            hook.Run("CharacterPrepareToSpawn", char)
        end

        self:_CharSys_oPlayerSpawn(ply)

        if ply._EnteredCharacter then
            do
                local pos = char.Pos
                pos = hook.Run("CharacterOverrideSpawnPos", char, pos) or pos

                if pos then
                    ply:SetPos(pos)
                end
            end

            do
                local hp = char.Health
                hp = hook.Run("CharacterOverrideHealth", char, hp) or hp

                ply:SetHealth(hp)
            end

            do
                local ar = char.Armor
                ar = hook.Run("CharacterOverrideArmor", char, ar) or ar

                ply:SetArmor(ar)
            end

            ply:RemoveAllItems()

            if char.PrivateData.Weapons then
                for class, info in pairs(char.PrivateData.Weapons) do
                    local weapon = ply:Give(class, true)

                    if IsValid(weapon) then
                        weapon:SetClip1(info.Clip1)
                    end
                end
            end

            if char.PrivateData.Ammo then
                for type, amount in pairs(char.PrivateData.Ammo) do
                    ply:SetAmmo(amount, type)
                end
            end

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
    ---@cast ply Player

    if ply:IsEnteredCharacter() then
        ply:LeaveCharacter()
    end
end)

hook.Add("playerGetSalary", "DarkRPCharacters_NoCharNoSalary", function(ply)
    ---@cast ply Player

    if not ply:IsEnteredCharacter() then
        return false, nil, false
    end
end)

concommand.Add("darkrp_wipe_chars", function(ply)
    if IsValid(ply) then
        return
    end

    MySQLite.query(
        [[DELETE FROM darkrp_characters;
          DELETE FROM darkrp_chars_pos;]],
        nil,
        DarkRP.Characters._TraceAsyncError()
    )

    print("Characters has been wiped!")
end)

concommand.Add("darkrp_drop_chars", function(ply)
    if IsValid(ply) then
        return
    end

    MySQLite.query(
        [[DROP TABLE darkrp_characters;
          DROP TABLE darkrp_chars_pos;]],
        nil,
        DarkRP.Characters._TraceAsyncError()
    )

    print("Characters has been dropped!")
end)
