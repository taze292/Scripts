local DetectionFunctions = filtergc("function", { Name = "f" })

for _, Function in DetectionFunctions do
    local Upvalues = getupvalues(Function)

    for _, Upvalue in Upvalues do
        if type(Upvalue) == "table" then
            setmetatable(Upvalue, {
                __newindex = function() end
            })
        end
    end
end

print("Bypassed")