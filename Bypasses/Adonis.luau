-- Credits to Killa
for _, Thread in getreg() do
    if type(Thread) ~= "thread" then
        continue
    end

    local Source = debug.info(Thread, 1, 's')

    if not Source then
        continue
    end

    if Source:find(".Core.Anti") or Source:find(".Plugins.Anti_Cheat") then
        pcall(coroutine.close, Thread)
    end
end

local ACTables = filtergc("table", {
    Keys = {
        "Detected", "RLocked"
    }
})

for _, Table in ACTables do
    for _, Function in Table do
        if type(Function) ~= "function" then
            continue
        end

        hookfunction(Function, function()
            coroutine.yield()
            return task.wait(9e9)
        end)
    end
end

-- print("Bypassed")