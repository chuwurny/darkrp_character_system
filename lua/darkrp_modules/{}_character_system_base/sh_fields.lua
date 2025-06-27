---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

---@class DarkRP.Characters.SimpleField.DarkRPVar
---@field Name string? Variable name
---@field WriteFn fun(v: any) Write function
---@field ReadFn fun(): any Read function
---
--- (Default: `false`) Field won't use DarkRP var to save this field
---@field NotForSave boolean?

---@class DarkRP.Characters.SimpleField.MetaWrapper
---@field FnName string? Overrides meta function name
---
--- Place custom logic here. Can return success or `false` with reason why this
--- value is invalid.
---@field OnCall (fun(char: DarkRP.Character, value: any, ...: any): boolean?, string?)?

---@class DarkRP.Characters.SimpleField
---@field Name string Field name
---
--- If `true` then field cannot be retrived from client in any way
---@field SetByServer boolean?
---
--- Validation function. Used when creating player character and in
--- `MetaWrapper` to check input value
---@field ValidateFn (fun(v: any, info: DarkRP.CharacterInfo): (boolean|string|nil))?
---
--- Called in "CharacterPreSpawn". Apply any changes to player here
---@field Apply fun(ply: Player, v: any)?
---
--- If `true` then field will be shared with character's assigned player
---@see DarkRP.Character.SharedData
---@field SharedData boolean?
---
--- If `true` then it will register a new DarkRP variable that can be accessed
--- via `PLAYER:getDarkRPVar` and `PLAYER:setDarkRPVar`
---@field DarkRPVar DarkRP.Characters.SimpleField.DarkRPVar?
---
--- Creates `PLAYER:SetCharacter<Name>` function that has following syntax:
--- `fun(self: Player, value: any, ...: any): boolean, string?`
--- First return value is the "success" of the function. If `false`, then
--- second argument *can* be an error explaining what did go wrong.
---@field MetaWrapper boolean|DarkRP.Characters.SimpleField.MetaWrapper?

--- Wrapper to create field in character
---@param field DarkRP.Characters.SimpleField
function DarkRP.Characters.CreateFieldSimple(field)
    local hookID = "DarkRPCharacters_SimpleField" .. field.Name

    --- preprocess field
    do
        if field.DarkRPVar then
            field.DarkRPVar.Name = field.DarkRPVar.Name
                or ("char_" .. field.Name)
        end
    end

    if SERVER then
        -- Add hook to validate field on character creation by calling
        -- `field.ValidateFn`
        if field.ValidateFn then
            ---@param info DarkRP.CharacterInfo
            hook.Add("ValidateCharacterInfo", hookID, function(info)
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

        --- Set field in `DarkRP.Character`, `DarkRP.Character.PrivateData` ,
        --- `DarkRP.Character.SharedData` from received info from the player
        ---
        ---@param char DarkRP.Character
        ---@param info DarkRP.CharacterInfo
        hook.Add("CreatePlayerCharacter", hookID, function(char, info)
            if field.SetByServer then
                info[field.Name] = nil

                return
            end

            char[field.Name] = info[field.Name]
            char.PrivateData[field.Name] = info[field.Name]

            if field.SharedData then
                char.SharedData[field.Name] = info[field.Name]
            end
        end)

        -- Call `field.Apply` when player is entered the character
        if field.Apply then
            ---@param char DarkRP.Character
            hook.Add("CharacterPreSpawn", hookID, function(char)
                field.Apply(char.Player, char[field.Name])
            end)
        end

        --- Save field by setting it in `DarkRP.Character.PrivateData`. If
        --- `field.DarkRPVar` is set then try to use it as saving value.
        --- Otherwise we're getting it from `DarkRP.Character` directly
        ---
        ---@param char DarkRP.Character
        ---@param private DarkRP.Character.PrivateData
        hook.Add("CharacterSave", hookID, function(char, _, private)
            if
                field.DarkRPVar
                and not field.DarkRPVar.NotForSave
                and char:IsActive()
            then
                private[field.Name] =
                    char.Player:getDarkRPVar(field.DarkRPVar.Name)

                return
            end

            private[field.Name] = char[field.Name]
        end)

        --- From `DarkRP.Character.PrivateData` set field directly to
        --- `DarkRP.Character` and if `field.SharedData` is set then to
        --- `DarkRP.Character.SharedData` to broadcast the field
        ---
        ---@param char DarkRP.Character
        ---@param private DarkRP.Character.PrivateData
        ---@param shared DarkRP.Character.SharedData
        hook.Add("CharacterLoad", hookID, function(char, private, shared)
            char[field.Name] = private[field.Name]

            if field.SharedData then
                shared[field.Name] = private[field.Name]
            end
        end)

        -- If field is shared and changed in `DarkRP.Character` then broadcast
        -- its state to the client and set DarkRP var
        if field.SharedData or field.DarkRPVar then
            ---@param char DarkRP.Character
            hook.Add("CharacterFieldSet", hookID, function(char, key, value)
                if key == field.Name then
                    if field.SharedData then
                        char:SetData(key, value)
                    end

                    if field.DarkRPVar and char:IsActive() then
                        char.Player:setDarkRPVar(field.DarkRPVar.Name, value)
                    end
                end
            end)
        end

        -- Add `PLAYER:SetCharacter[field name]` wrapper that will validate
        -- input data and
        if field.MetaWrapper then
            local fnName = "SetCharacter" .. field.Name
            local onCall

            if type(field.MetaWrapper) == "table" then
                fnName = field.MetaWrapper.FnName or fnName
                onCall = field.MetaWrapper.OnCall
            end

            local PLAYER = FindMetaTable("Player")

            ---@param ply Player
            ---@param value any
            ---@return boolean success
            ---@return string? err
            PLAYER[fnName] = function(ply, value, ...)
                local success, err
                local char = ply:GetCharacter()

                if field.ValidateFn then
                    local status = field.ValidateFn(value, char)

                    if type(status) == "string" then
                        success = false
                        err = status
                    elseif status == false then
                        success = false
                    end
                end

                if success ~= false and onCall then
                    success, err = onCall(char, value, ...)
                end

                if success ~= false then
                    char[field.Name] = value
                    char.PrivateData[field.Name] = value
                end

                return success ~= false, err
            end
        end

        -- Set DarkRP var to nil after player is left character
        if field.DarkRPVar then
            hook.Add("PlayerLeftCharacter", hookID, function(char)
                char.Player:setDarkRPVar(field.DarkRPVar.Name, nil)
            end)
        end
    else -- CLIENT
        -- Update field directly in `DarkRP.Character`
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

    -- Register DarkRP var
    if field.DarkRPVar then
        DarkRP.registerDarkRPVar(
            field.DarkRPVar.Name,
            field.DarkRPVar.WriteFn,
            field.DarkRPVar.ReadFn
        )
    end
end
