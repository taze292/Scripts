-- Game: https://www.roblox.com/games/107778070777162

local DetectionFunctions = filtergc("function", {
    Name = "o"
})

for _, Function in DetectionFunctions do
    local Protos = debug.getprotos(Function)

    for Index, _ in Protos do
        local Proto = getproto(Function, Index, true)[1]
        local Upvalues = getupvalues(Proto)

        for _, Upvalue in Upvalues do
            if type(Upvalue) == "table" then
                setmetatable(Upvalue, {
                    __newindex = function() end
                })
            end
        end
    end
end

print("Bypassed")