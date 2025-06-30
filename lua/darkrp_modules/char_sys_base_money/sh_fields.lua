---@class DarkRP.Character.Data
---@field Money integer? From "char_sys_base_money"

DarkRP.Characters.CreateFieldSimple({
    Name = "Money",

    DarkRPVar = { Name = "money" },

    SharedData = true,
    SetByServer = true,

    TreatNilAs = "default",
    DefaultValue = 0,
})
