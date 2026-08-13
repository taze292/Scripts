local ShootFunction = filtergc("function", { Name = "Shoot" }, true)
local ShotProgressValue = getupvalue(ShootFunction, 1)

ShotProgressValue:GetPropertyChangedSignal("Value"):Connect(function()
    if AutoGreen then
        ShotProgressValue.Value = 0.98
    end
end)
