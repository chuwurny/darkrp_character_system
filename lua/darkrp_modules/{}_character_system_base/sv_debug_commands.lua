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
