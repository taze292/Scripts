local GetAmmoTables = function()
    return filtergc("table", {
        Keys = {
            "reload", "ammo",
            "magSize", "magCurrent"
        }
    })
end

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer.Backpack

Backpack.ChildAdded:Connect(function(Child)
    if Child:IsA("Tool") and InfiniteAmmo then
        task.wait()
        local AmmoTables = GetAmmoTables()

        for _, AmmoTable in AmmoTables do
            AmmoTable.magCurrent = math.huge
        end
    end
end)
