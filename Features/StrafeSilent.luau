-- doesnt work dont use ts son
getgenv().Enabled = true
getgenv().HitChance = 100
getgenv().HitPart = "Head"
getgenv().FOV = 150

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local OldDirection

local GetBloomDirection = filtergc("function", {
    Name = "getBloomDirection"
}, true)

local Circle = Drawing.new("Circle")
Circle.Color = Color3.new(1, 1, 1)
Circle.Radius = FOV

local UpdateCircle = function()
    Circle.Visible = Enabled
    if Enabled then
        Circle.Position = Camera.ViewportSize / 2
        Circle.Radius = FOV
    end
end

local Target = function()
    local Direction = Camera.CFrame.LookVector.Unit
    local ClosestDistance = FOV

    for _, Player in Players:GetPlayers() do
        local Character = Player.Character
        if Player == LocalPlayer or not Character then
            continue
        end

        local Humanoid = Character:FindFirstChild("Humanoid")
        local TargetPart = Character:FindFirstChild(HitPart)
        if not TargetPart or not Humanoid or Humanoid.Health <= 0 then
            continue
        end

        local ScreenPosition, OnScreen = Camera:WorldToViewportPoint(TargetPart.Position)
        if not OnScreen then
            continue
        end

        ScreenPosition = Vector2.new(ScreenPosition.X, ScreenPosition.Y)
        local Distance = (ScreenPosition - (Camera.ViewportSize / 2)).Magnitude
        if Distance < ClosestDistance then
            Direction = CFrame.lookAt(Camera.CFrame.Position, TargetPart.Position).LookVector.Unit
            ClosestDistance = Distance
        end
    end

    return Direction
end

print(GetBloomDirection)
OldDirection = hookfunction(GetBloomDirection, function(Unit, Bloom)
    if Enabled and math.random(1, 100) >= HitChance then
        Unit = Target()
    end

    return OldDirection(Unit, Bloom)
end)

RunService.Heartbeat:Connect(UpdateCircle)