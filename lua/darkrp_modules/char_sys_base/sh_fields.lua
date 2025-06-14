---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

---@class DarkRP.Characters.SimpleField.DarkRPVar
---@field Name string?
---@field WriteFn fun(v: any)
---@field ReadFn fun(): any

---@class DarkRP.Characters.SimpleField
---@field Name string
---@field SetByServer boolean?
---@field ValidateFn (fun(v: any, info: DarkRP.CharacterInfo): (boolean|string|nil))?
---@field Apply fun(ply: Player, v: any)?
---@field SharedData boolean?
---@field DarkRPVar DarkRP.Characters.SimpleField.DarkRPVar?

---@param field DarkRP.Characters.SimpleField
function DarkRP.Characters.CreateFieldSimple(field)
    local hookID = "DarkRPCharacters_SimpleField" .. field.Name

    if SERVER then
        if field.ValidateFn then
            ---@param info DarkRP.CharacterInfo
            hook.Add("PlayerCanCreateCharacter", hookID, function(_, info)
                if field.SetByServer then
                    return
                elseif info[field.Name] == nil then
                    return false, "missing_field:" .. field.Name
                end

                if field.ValidateFn then
                    local status = field.ValidateFn(info[field.Name], info)

                    if type(status) == "string" then
                        return false, status
                    elseif type(status) == "boolean" and not status then
                        return false, "invalid_field:" .. field.Name
                    end
                end
            end)
        end

        ---@param char DarkRP.Character
        ---@param info DarkRP.CharacterInfo
        hook.Add("CreatePlayerCharacter", hookID, function(char, info)
            if field.SetByServer then
                info[field.Name] = nil

                return
            end

            char[field.Name] = info[field.Name]
            char.PrivateData[field.Name] = info[field.Name]
        end)

        if field.Apply then
            ---@param char DarkRP.Character
            hook.Add("CharacterPreSpawn", hookID, function(char)
                field.Apply(char.Player, char[field.Name])
            end)
        end

        ---@param char DarkRP.Character
        ---@param private table
        hook.Add("CharacterSave", hookID, function(char, _, private)
            private[field.Name] = char[field.Name]
        end)

        ---@param char DarkRP.Character
        ---@param private table
        ---@param shared table
        hook.Add("CharacterLoad", hookID, function(char, private, shared)
            char[field.Name] = private[field.Name]

            if field.SharedData then
                shared[field.Name] = private[field.Name]
            end
        end)
    else -- CLIENT
        if field.SharedData then
            ---@param char DarkRP.Character
            ---@param shared table
            hook.Add("CharacterSync", hookID, function(char, shared)
                char[field.Name] = shared[field.Name]
            end)

            ---@param char DarkRP.Character
            ---@param key any
            ---@param value any
            hook.Add("CharacterDataSync", hookID, function(char, key, value)
                if key == field.Name then
                    char[key] = value
                end
            end)
        end
    end

    if field.DarkRPVar then
        local varName = field.DarkRPVar.Name or ("char_" .. field.Name)

        DarkRP.registerDarkRPVar(
            varName,
            field.DarkRPVar.WriteFn,
            field.DarkRPVar.ReadFn
        )

        if SERVER then
            hook.Add("CharacterRestore", hookID, function(char)
                char.Player:setDarkRPVar(varName, char[field.Name])
            end)
        end
    end
end
