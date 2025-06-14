net.Receive("DarkRPSyncCharacter", function()
    local char = DarkRP.Characters.New(LocalPlayer())

    char.ID = net.ReadUInt(32)
    char.Name = net.ReadString()
    char.LastAccessTime = net.ReadUInt(32)
    char.Health = net.ReadUInt(32)
    char.Armor = net.ReadUInt(32)
    char.SharedData = net.ReadTable()

    DarkRP.Characters.Loaded[char.ID] = char

    if cvars.Bool("developer") then
        print("Synced char " .. char.ID)
    end

    hook.Run("CharacterSync", char, char.SharedData)
    hook.Run("CharacterSynced", char)
end)

net.Receive("DarkRPSyncCharacterData", function()
    local id = net.ReadUInt(32)
    local key = net.ReadType()
    local value = net.ReadType()

    local char = DarkRP.Characters.Loaded[id]

    local oValue = char.SharedData[key]
    char.SharedData[key] = value

    if cvars.Bool("developer") then
        print(
            string.format(
                "Synced char %d data: %s = %s",
                char.ID,
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
