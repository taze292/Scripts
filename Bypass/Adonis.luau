for _, Thread in getreg() do
    if type(Thread) ~= "thread" then
        continue
    end

    local Source = debug.info(Thread, 1, "s")
    if not Source or (not Source:match(".Core.Anti") and not Source:match(".Plugins.Anti_Cheat")) then
        continue
    end

    pcall(coroutine.close, Thread)
end

local ATables = filtergc("table", {
    Keys = { "Detected", "RLocked" }
})

for _, ATable in ATables do
    for _, Function in ATable do
        if type(Function) ~= "function" or isfunctionhooked(Function) then
            continue
        end

        hookfunction(Function, function()
            coroutine.yield()
            return task.wait(9e9)
        end)
    end
end

print("Bypassed")