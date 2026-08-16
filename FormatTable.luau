local FormatTable
FormatTable = function(Table, Indent)
    Indent = Indent or 0

    local IndentString = string.rep("    ", Indent or 0)
    local Result = ""

    for Key, Value in Table do
        Result = `{Result}{IndentString}{Key}: {Value}\n`

        if type(Value) == "table" then
            Result = `{Result}{FormatTable(Value, Indent + 1)}`
        end
    end

    return Result
end

local OutputTable = function(Table, Indent)
    return FormatTable(Table, Indent or 0)
end

return OutputTable, FormatTable
