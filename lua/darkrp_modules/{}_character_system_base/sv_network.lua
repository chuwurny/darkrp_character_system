util.AddNetworkString("DarkRPLoadCharacters") -- C2S
util.AddNetworkString("DarkRPCreateCharacter") -- S2C/C2S
util.AddNetworkString("DarkRPEnterCharacter") -- S2C/C2S
util.AddNetworkString("DarkRPSyncCharacter") -- S2C
util.AddNetworkString("DarkRPSyncCharacterData") -- S2C
util.AddNetworkString("DarkRPDeleteCharacter") -- C2S/S2C
util.AddNetworkString("DarkRPUnloadCharacter") -- S2C
util.AddNetworkString("DarkRPLeaveCharacter") -- S2C/C2S

---@class Player
---@field _DarkRPLoadCharacters boolean?

net.Receive("DarkRPLoadCharacters", function(_, ply)
    if ply._DarkRPLoadCharacters then
        return
    end

    ply._DarkRPLoadCharacters = true

    ply:LoadCharacters(function(chars)
        if cvars.Bool("developer") then
            print(string.format("%s characters loaded: %d", ply, #chars))
        end
    end)
end)

net.Receive("DarkRPCreateCharacter", function(_, ply)
    ---@type DarkRP.CharacterInfo
    local charInfo = net.ReadTable()

    if cvars.Bool("developer") then
        print(string.format("%s creating char", ply))

        PrintTable(charInfo)
    end

    ply:CreateCharacter(charInfo, function(err)
        if err and cvars.Bool("developer") then
            ErrorNoHalt("Failed to create char " .. err)
        end

        net.Start("DarkRPCreateCharacter")

        if err then
            net.WriteBool(true)
            net.WriteString(err)
        else
            net.WriteBool(false)
        end

        net.Send(ply)
    end)
end)

net.Receive("DarkRPEnterCharacter", function(_, ply)
    local charID = net.ReadUInt(32)

    if ply:IsEnteredCharacter() then
            ---@diagnostic disable-next-line: undefined-field
        if not GAMEMODE.Config.AllowQuickCharacterEnter then
            return
        end

        ply:LeaveCharacter()
    end

    local _, err = ply:EnterCharacter(charID)

    if cvars.Bool("developer") then
        if err then
            ErrorNoHalt(string.format("%s failed to enter char: %s", ply, err))
        else
            print(
                string.format(
                    "%s entered char %s",
                    ply,
                    DarkRP.Characters.Loaded[charID]
                )
            )
        end
    end

    net.Start("DarkRPEnterCharacter")

    if err then
        net.WriteBool(true)
        net.WriteString(err)
    else
        net.WriteBool(false)
    end

    net.Send(ply)
end)

net.Receive("DarkRPDeleteCharacter", function(_, ply)
    local id = net.ReadUInt(32)

    local char = DarkRP.Characters.Loaded[id]

    if not char then
        return
    end

    if char.Player ~= ply then
        return
    end

    if hook.Run("PlayerCanDeleteCharacter", ply, char) == false then
        return
    end

    char:Delete()
end)

net.Receive("DarkRPLeaveCharacter", function(_, ply)
    if not ply:IsEnteredCharacter() then
        return
    end

    ply:LeaveCharacter()
end)
