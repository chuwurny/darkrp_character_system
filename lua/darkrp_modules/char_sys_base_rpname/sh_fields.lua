---@class DarkRP.Character.Data
---@field Name string (From "char_sys_base_money")

---@class DarkRP.CharacterInfo
---@field Name string (From "char_sys_base_rpname") Character RP name

DarkRP.Characters.CreateFieldSimple({
    Name = "Name",

    SharedData = true,

    DarkRPVar = { Name = "rpname" },

    ValidateFn = function(name)
        if
            utf8.len(name)
            ---@diagnostic disable-next-line: undefined-field
            > (GAMEMODE.Config.CharacterMaxNameLength or 32)
        then
            return "long_name"
        end
    end,

    -- backwards fallback
    MetaWrapper = {},
})
