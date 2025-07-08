--- WARNING: for internal usage only!
---
---@param cols table
---@param steamID string
---@return DarkRP.Character?
function DarkRP.Characters.LoadFromRow(cols, steamID)
    local data = util.JSONToTable(cols.data)

    if data == nil then
        ErrorNoHalt(
            string.format(
                'Player %s character %d has corrupted database "data" field. Not loading character until fixed!',
                steamID,
                cols.id
            )
        )

        return nil
    end

    local plyOrSteamID = player.GetBySteamID(steamID) or steamID

    ---@type DarkRP.Character
    local char = DarkRP.Characters.New(plyOrSteamID --[[@as Player|string]])

    if cvars.Bool("developer") then
        print(
            string.format(
                "Loaded character %s as %s",
                cols.id,
                char:IsOffline() and "offline" or "online"
            )
        )
    end

    char.Armor = tonumber(cols.armor) --[[@as integer]]
    char.Health = tonumber(cols.health) --[[@as integer]]

    char.Dead = cols.dead == "1"

    char.LastAccessTime = tonumber(cols.last_access_time) --[[@as integer]]

    if cols.pos_x and cols.pos_x ~= "NULL" then
        char.Pos = Vector(
            tonumber(cols.pos_x),
            tonumber(cols.pos_y),
            tonumber(cols.pos_z)
        )
    end

    char.PrivateData = data.PrivateData

    hook.Run("CharacterLoad", char, char.PrivateData, char.SharedData)

    char.ID = tonumber(cols.id) --[[@as integer]]

    DarkRP.Characters.Loaded[char.ID] = char

    hook.Run("CharacterLoaded", char)

    char:Sync()

    return char
end

--- Loads all character from database by character ID. If character is already
--- loaded (exist in `DarkRP.Characters.Loaded`) then it will use it instead of
--- loading a new one
---
--- WARN: you shouldn't use it unless you know what you're doing. See
--- `DarkRP.Characters.LoadBySteamID64` for more important information
---@see DarkRP.Characters.LoadBySteamID64
---
---@param charID integer
---@param callback fun(char: DarkRP.Character?)
function DarkRP.Characters.LoadByID(charID, callback)
    local char = DarkRP.Characters.Loaded[charID]

    if char then
        char:TryMakeOnline()

        return callback(char)
    end

    MySQLite.query(
        string.format(
            [[SELECT
                  id, steamid,
                  last_access_time,
                  health, armor,
                  dead,
                  data,
                  darkrp_chars_pos.pos_x,
                  darkrp_chars_pos.pos_y,
                  darkrp_chars_pos.pos_z
              FROM
                  darkrp_characters
              LEFT JOIN darkrp_chars_pos ON
                  darkrp_characters.id = darkrp_chars_pos.char_id AND
                  darkrp_chars_pos.map = %s
              WHERE id = %d
              LIMIT 1]],
            MySQLite.SQLStr(game.GetMap()),
            charID
        ),
        function(rows)
            local cols = rows and rows[1] or nil

            if not cols then
                return callback(nil)
            end

            callback(DarkRP.Characters.LoadFromRow(cols, cols.steamid))
        end,
        DarkRP.Characters._TraceAsyncError()
    )
end

--- Loads all characters from database by Steam ID.
---
--- WARN: you shouldn't use it unless you know what you're doing. See
--- `PLAYER:FindLoadedCharacters` to find all loaded characters. If you're
--- using it then don't forget to call `CHARACTER:Unload` when you're done!
---@see Player.FindLoadedCharacters
---@see DarkRP.Character.Unload
---
--- When loading characters hook "CharacterLoad" will be called to restore data
--- from database (`CHARACTER.PrivateData`). After this hook "CharacterLoaded"
--- is called and character is synchronized with this player.
---
--- NOTE: `DarkRP.Characters.Loaded` is modified on hook "CharacterLoaded"!
---
---@param steamID string SteamID in format STEAM_X:Y:ZZZZZZ
---@param callback fun(chars: DarkRP.Character[])
function DarkRP.Characters.LoadBySteamID(steamID, callback)
    MySQLite.query(
        string.format(
            "SELECT id FROM darkrp_characters WHERE steamid = %s",
            MySQLite.SQLStr(steamID)
        ),
        function(rows)
            rows = rows or {}

            ---@type DarkRP.Character[]
            local chars = {}

            local charsLeft = #rows

            if charsLeft == 0 then
                return callback(chars)
            end

            ---@param char DarkRP.Character?
            local function insertChar(char)
                if char then
                    table.insert(chars, char)
                end

                charsLeft = charsLeft - 1

                if charsLeft == 0 then
                    callback(chars)
                end
            end

            for _, cols in ipairs(rows) do
                local id = tonumber(cols.id)

                if id then
                    DarkRP.Characters.LoadByID(id, insertChar)
                else
                    -- shouldn't happen but better safe than sorry

                    insertChar(nil)
                end
            end
        end,
        DarkRP.Characters._TraceAsyncError()
    )
end

--- Gets all steamids which has characters. Later you can load these characters
--- by calling `DarkRP.Characters.LoadBySteamID`.
---@see DarkRP.Characters.LoadBySteamID
---
---@param offset integer? List offset
---@param amount integer? Amount to get
---@param callback fun(chars: { ID: integer, SteamID: string }[])
function DarkRP.Characters.ListAll(offset, amount, callback)
    local query = "SELECT id, steamid FROM darkrp_characters"

    if amount then
        query = string.format("%s LIMIT %d", query, amount)
    end

    if offset then
        query = string.format("%s OFFSET %d", query, offset)
    end

    MySQLite.query(query, function(rows)
        rows = rows or {}

        for _, cols in ipairs(rows) do
            cols.SteamID = cols.steamid
            cols.ID = tonumber(cols.id)

            cols.steamid = nil
            cols.id = nil
        end

        callback(rows)
    end, DarkRP.Characters._TraceAsyncError())
end

--- Creates offline character for any player by steam id. If you wan't to create
--- character for the existing player then see `PLAYER:CreateCharacter` function
---@see Player.CreateCharacter
---
--- Calls "ValidateCharacterInfo" hook before creating character to validate
--- @info. Hook won't be called if @force is set to `true`.
---
---@param steamID string In STEAM_X:Y:ZZZZZZ format
---@param info DarkRP.CharacterInfo
---
--- Called _before_ saving. Setup wanted character fields here
---@param onCreated fun(char: DarkRP.Character)?
---
--- Called when character is ready. If @doLoad is `true` then `char` argument
--- will be set, if no error is occured. If @doLoad is `false` then on success
--- this field will be character ID.
---
--- `err` argument will be set only if `force` is *not* set to `false`.
---@param callback fun(err: ("no_reason"|string)?, char: nil)
---
---@param force boolean? (Default: false) Ignore checks
---@param doLoad boolean? (Default: false) Loads character after loading
---@overload fun(steamID: string, info: DarkRP.CharacterInfo, onCreated: fun(char: DarkRP.Character)?, callback: fun(err: ("no_reason"|string)?, char: DarkRP.Character), force: boolean?, doLoad: true)
---@overload fun(steamID: string, info: DarkRP.CharacterInfo, onCreated: fun(char: DarkRP.Character)?, callback: fun(err: nil, char: DarkRP.Character), force: true, doLoad: true)
---@overload fun(steamID: string, info: DarkRP.CharacterInfo, onCreated: fun(char: DarkRP.Character)?, callback: fun(err: nil, charId: integer), force: true, doLoad: boolean?)
function DarkRP.Characters.Create(
    steamID,
    info,
    onCreated,
    callback,
    force,
    doLoad
)
    if not force then
        local valid, reason = hook.Run("ValidateCharacterInfo", info)

        if valid == false then
            return callback(reason or "no_reason", nil)
        end
    end

    local char = DarkRP.Characters.New(
        player.GetBySteamID(steamID) --[[@as Player?]]
            or steamID
    )

    -- hypothetically speaking character is just being born :trollface:
    char.Dead = true

    if onCreated then
        onCreated(char)
    end

    local function loadChar()
        if doLoad then
            char:Sync()

            callback(nil, char)
        else
            char:Unload()

            callback(nil, char.ID)
        end
    end

    char:Save(loadChar)
end
