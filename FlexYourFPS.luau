local Bypass = loadstring(game:HttpGet("https://raw.githubusercontent.com/taze292/script-archive/refs/heads/main/AdonisBypassObfuscated.luau"))
local Event = game:GetService("ReplicatedStorage"):FindFirstChild("nya")
local OldNamecall
Bypass()

OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(Self, Packet, ...)
    if Spoof and Self == Event and type(Packet) == "table" then
        local ActualFPS = math.random(FPS - FPSVariation, FPS + FPSVariation)
        local ActualMemory = math.random(MemoryUsage - MemoryVariation, MemoryUsage + MemoryVariation)

        rawset(Packet, "fps", ActualFPS)
        rawset(Packet, "gfx", Enum.SavedQualitySetting:FromValue(Graphics))
        rawset(Packet, "mem", ActualMemory)
        rawset(Packet, "res", Resolution)
    end

    return OldNamecall(Self, Packet, ...)
end))
