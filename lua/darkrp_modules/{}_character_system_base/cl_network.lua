net.Receive("DarkRPSyncCharacter", function()
    local id = net.ReadUInt(32)

    local hasSyncedBefore = DarkRP.Characters.Loaded[id] ~= nil

    local char = DarkRP.Characters.Loaded[id]

    local syncInfo = net.ReadBool()

    if syncInfo then
        local steamID = util.SteamIDFrom64(net.ReadUInt64())

        if not char then
            if steamID == LocalPlayer():SteamID() then
                char = DarkRP.Characters.New(LocalPlayer())
            else
                local ply = player.GetBySteamID(steamID)

                if IsValid(ply) then
                    ---@cast ply Player

                    char = DarkRP.Characters.New(ply)
                else
                    char = DarkRP.Characters.New(steamID)
                end
            end

            char.ID = id
        end

        char.LastAccessTime = net.ReadUInt(32)
        char.Health = net.ReadUInt(32)
        char.Armor = net.ReadUInt(32)
        char.Dead = net.ReadBool()
    end

    local syncData = net.ReadBool()

    if syncData then
        char.SharedData = net.ReadTable()
    end

    if not hasSyncedBefore and not syncInfo and not syncData then
        ErrorNoHalt(
            "Horrible error! Got character "
                .. tostring(char)
                .. " first time but it has not sent all fields!"
        )
    end

    DarkRP.Characters.Loaded[char.ID] = char

    if cvars.Bool("developer") then
        print("Synced char " .. tostring(char))
    end

    hook.Run("CharacterSync", char, char.SharedData)
    hook.Run("CharacterSynced", char)
end)

net.Receive("DarkRPSyncCharacterData", function()
    local id = net.ReadUInt(32)
    local key = net.ReadType()
    local value = net.ReadType()

    local char = DarkRP.Characters.Loaded[id]

    if not char then
        error(
            string.format(
                "Bug: got character (%d) data update (%s = %s), but no character is loaded!",
                id,
                tostring(key),
                tostring(value)
            )
        )
    end

    local oValue = char.SharedData[key]
    char.SharedData[key] = value

    if cvars.Bool("developer") then
        print(
            string.format(
                "Synced char %s data: %s = %s",
                char,
                tostring(key),
                tostring(value)
            )
        )
    end

    hook.Run("CharacterDataSync", char, key, value, oValue)
    hook.Run("CharacterDataSynced", char, key, value, oValue)
end)

net.Receive("DarkRPUnloadCharacter", function()
    local id = net.ReadUInt(32)
    local char = DarkRP.Characters.Loaded[id]

    if not char then
        return
    end

    DarkRP.Characters.Loaded[id] = nil

    hook.Run("CharacterUnloaded", char)
end)
