---@class DarkRP.Characters
DarkRP.Characters = DarkRP.Characters or {}

--- Used to trace mysqlite query errors with query call trace.
---
--- Example:
--- ```
--- MySQLite.query("...", nil, DarkRP.Characters._TraceAsyncError())
--- ```
function DarkRP.Characters._TraceAsyncError()
    local stack = debug.traceback()

    return function(err)
        ErrorNoHalt(
            string.format(
                "Characters database error occured: %s\n%s",
                err,
                stack
            )
        )
    end
end
