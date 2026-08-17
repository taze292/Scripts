-- doesnt handle edge cases, adding later
local OutputTable
local FormatTable

FormatTable = function(Table, Indent)
    Indent = Indent or 0

    local IndentString = string.rep("    ", Indent + 1)
    local Result = "{\n"

    for Key, Value in Table do
        Result ..= IndentString

        if type(Key) == "number" then
            Result ..= `[{Key}] = `
        elseif Key:find(" ") then
            Result ..= `["{Key}"] = `
        else
            Result ..= `{Key} = `
        end

        if type(Value) == "table" then
            Result ..= `{FormatTable(Value, Indent + 1)},\n`
        elseif type(Value) == "string" then
            Result ..= `"{Value}",\n`
        else
            Result ..= `{Value},\n`
        end
    end

    Result ..= `{string.rep("    ", Indent)}}`

    return Result
end

OutputTable = function(Table, Indent)
    return FormatTable(Table, Indent or 0)
end

return OutputTable, FormatTable