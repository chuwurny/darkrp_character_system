---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

---@param charInfo DarkRP.CharacterInfo
---@param callback fun(err: string?)?
function DarkRP.Characters.SendCreateRequest(charInfo, callback)
    net.Start("DarkRPCreateCharacter")
    net.WriteTable(charInfo)
    net.SendToServer()

    if callback then
        net.Receive("DarkRPCreateCharacter", function()
            net.Receivers.DarkRPCreateCharacter = nil

            local err = net.ReadBool() and net.ReadString() or nil

            callback(err)
        end)
    end
end

---@param char DarkRP.MaybeCharacter
---@param callback fun(err: string?)?
function DarkRP.Characters.SendEnterRequest(char, callback)
    char = DarkRP.Characters.ToCharacter(char)

    net.Start("DarkRPEnterCharacter")
    net.WriteUInt(char.ID, 32)
    net.SendToServer()

    if callback then
        net.Receive("DarkRPEnterCharacter", function()
            net.Receivers.DarkRPEnterCharacter = nil

            local err = net.ReadBool() and net.ReadString() or nil

            callback(err)
        end)
    end
end

---@param char DarkRP.MaybeCharacter
---@param callback fun(err: string?)?
function DarkRP.Characters.SendDeleteRequest(char, callback)
    char = DarkRP.Characters.ToCharacter(char)

    net.Start("DarkRPDeleteCharacter")
    net.WriteUInt(char.ID, 32)
    net.SendToServer()

    if callback then
        net.Receive("DarkRPDeleteCharacter", function()
            net.Receivers.DarkRPDeleteCharacter = nil

            local err = net.ReadBool() and net.ReadString() or nil

            callback(err)
        end)
    end
end

function DarkRP.Characters.SendLeaveRequest()
    net.Start("DarkRPLeaveCharacter")
    net.SendToServer()
end

hook.Add("InitPostEntity", "DarkRPCharacters_FetchThemAll", function()
    net.Start("DarkRPLoadCharacters")
    net.SendToServer()
end)
