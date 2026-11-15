-- References
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Environment = getgenv()
Environment.Farming = true

local DarknessParts = workspace:QueryDescendants("#DarknessPart")
local ChestTrigger = workspace:FindFirstChild("Trigger", true)
local FarmParts = {}

-- Make Farm Parts
for _, DarknessPart in DarknessParts do
    local Number = tonumber(DarknessPart.Parent.Name:sub(-1))

    if Number == 0 then
        Number = 10
    end

    local FarmPart = Instance.new("Part")

    FarmPart.CFrame = CFrame.new(DarknessPart.Position)
    FarmPart.Size = Vector3.new(10, 1, 10)
    FarmPart.Anchored = true
    
    FarmPart.Parent = workspace
    FarmParts[Number] = FarmPart
end

-- Stats
local Container = Instance.new("Frame", Instance.new("ScreenGui", gethui()))
local List = Instance.new("UIListLayout")

if not isfile("Inter.ttf") then
    writefile("Inter.ttf", game:HttpGet("https://github.com/QuantConnect/Research/raw/refs/heads/master/Explore/Inter%20font/static/Inter-SemiBold.ttf"))
end

if not isfile("Inter.json") then
    local FontData = {
        name = "Inter",
        faces = {
            {
                name = "SemiBold",
                weight = 600,
                style = "Normal",
                assetId = getcustomasset("Inter.ttf")
            }
        }
    }

    writefile("Inter.json", HttpService:JSONEncode(FontData))
end

local Inter = Font.new(getcustomasset("Inter.json"), Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)

local function MakeLabel(Prefix, Value)
    local Label = Instance.new("TextLabel")
    local Border = Instance.new("UIStroke")

    Label.TextColor3 = Color3.new(1, 1, 1)
    Label.Size = UDim2.fromOffset(200, 25)
    Label.BackgroundTransparency = 1
    Label.Text = `{Prefix}: {Value}`
    Label.FontFace = Inter
    Label.RichText = true
    Label.TextSize = 14

    Border.Parent = Label
    Label.Parent = Container

    return Label
end

Container.Position = UDim2.fromScale(0.5, 0.895)
Container.AnchorPoint = Vector2.new(0.5, 0.5)
Container.Size = UDim2.fromOffset(200, 75)
Container.BackgroundTransparency = 1

List.SortOrder = Enum.SortOrder.LayoutOrder
List.Parent = Container

local PerHourLabel = MakeLabel("Per Hour", `<font color="rgb(255, 205, 6)">55k</font>`)
local ProfitLabel = MakeLabel("Profit", `<font color="rgb(23, 255, 50)">600</font>`)
local ElapsedLabel = MakeLabel("Elapsed", "1h")
local TimeFarmed = 0

local function FormatTime(Seconds)
    local Units = {
        { "d", 86400 },
        { "h", 3600 },
        { "m", 60 },
        { "s", 1 }
    }

    local Result = {}

    for _, Unit in Units do
        local Value = math.floor(Seconds / Unit[2])

        if Value > 0 then
            table.insert(Result, `{Value}{Unit[1]}`)
            Seconds %= Unit[2]
        end
    end

    return #Result > 0 and table.concat(Result, " ") or "0s"
end

RunService.PreRender:Connect(function(DeltaTime)
    if not Farming then
        return
    end

    TimeFarmed += DeltaTime
    local Time = FormatTime(TimeFarmed)

    if ElapsedLabel.Text ~= Time then
        ElapsedLabel.Text = `Elapsed: {Time}`
    end
end)

local GoldValue = LocalPlayer:FindFirstChild("Gold", true)
local StartingGold = GoldValue.Value

GoldValue:GetPropertyChangedSignal("Value"):Connect(function()
    local Color = GoldValue.Value < StartingGold and "255, 23, 50" or "23, 255, 50"

    ProfitLabel.Text = `Profit: <font color="rgb({Color})">{GoldValue.Value - StartingGold}</font>`
    PerHourLabel.Text = `Per Hour: <font color="rgb(255, 205, 6)">{math.floor((GoldValue.Value - StartingGold) / (TimeFarmed / 3600))}</font>`
end)

PerHourLabel.Text = `Per Hour: <font color="rgb(255, 205, 6)">0</font>`
ProfitLabel.Text = `Profit: <font color="rgb(23, 255, 50)">0</font>`

-- Main Loop
while true do
    local Character = LocalPlayer.Character
    
    if not Character then
        task.wait()
        continue
    end

    local RootPart = Character:FindFirstChild("HumanoidRootPart")

    if not RootPart then
        task.wait()
        continue
    end

    if Farming then
        if not Farming then continue end

        for _, FarmPart in FarmParts do
            if not Farming then break end

            RootPart.CFrame = FarmPart.CFrame * CFrame.new(0, 5, 0)
            task.wait(2)
        end

        RootPart.CFrame = ChestTrigger.CFrame
        LocalPlayer.CharacterAdded:Wait()
    end

    task.wait()
    continue
end
