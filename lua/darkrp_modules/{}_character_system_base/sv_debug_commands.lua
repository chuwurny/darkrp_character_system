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
          DROP TABLE darkrp_chars_pos;
          DROP TABLE darkrp_chars_db_state;]],
        nil,
        DarkRP.Characters._TraceAsyncError()
    )

    print("Characters has been dropped!")
end)

concommand.Add("darkrp_chars_migrate", function(ply, cmd, args)
    if IsValid(ply) then
        return
    end

    local version = tonumber(args[1] or "")

    if not version then
        return print(string.format("%s [version]", cmd))
    end

    MySQLite.query(
        string.format(
            "REPLACE INTO darkrp_chars_db_state VALUES('version', %d)",
            version - 1
        ),
        hook.GetTable().DatabaseInitialized.DarkRPCharacters_InitDB,
        DarkRP.Characters._TraceAsyncError()
    )
end)
