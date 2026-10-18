-- Credits to pubmain
-- Last updated 10/11/26

assert(getactors or setfflag, "Your executor does not support actors.")

local Source = [[
    local OldBor
    OldBor = hookfunction(bit32.bor, newcclosure(function(...)
        local Source = debug.info(3, 's')

        if Source and Source:find("Tattle") then
            return 0
        end

        return OldBor(...)
    end))
]]

if not getactors then
    setfflag("DebugRunParallelLuaOnMainThread", "True")

    local Bypass = loadstring(Source)
    return Bypass()
end

runonactor(getactors()[1], Source)