-- Tested on Steal An Egg & Grow a Chicken Fighter

-- local DetectionFunctions = filtergc("function", {
--     Name = "o"
-- })

-- for _, Function in DetectionFunctions do
--     local Protos = debug.getprotos(Function)

--     for Index, _ in Protos do
--         local Proto = getproto(Function, Index, true)[1]
--         local Upvalues = getupvalues(Proto)

--         for _, Upvalue in Upvalues do
--             if type(Upvalue) == "table" then
--                 setmetatable(Upvalue, {
--                     __newindex = function() end
--                 })
--             end
--         end
--     end
-- end

-- Simplified (credits to Killa)
local Function = filtergc("function", {
    Constants = { "gmatch", "GetFullName" }
}, true)

for _, Table in debug.getupvalues(Function) do
    if typeof(Table) ~= "table" then continue end
    
    setrawmetatable(Table, {
        __newindex = function(_, Index, Value)
            warn(`Blocked detection {Index} {Value}`)
        end
    })
end

print("Bypassed")