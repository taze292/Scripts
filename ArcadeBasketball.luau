-- Config
local Environment = getgenv()
Environment.AlwaysGreen = false
Environment.InfiniteStamina = false

Environment.AutoGuard = false
Environment.AutoGuardDistance = 3
Environment.AutoGuardMethod = "CFrame" -- CFrame, WalkToPoint

Environment.AutoBlock = false
Environment.AutoBlockDelay = 0.17

-- References
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Events = ReplicatedStorage:FindFirstChild("Events")
local BlockEvent = Events:FindFirstChild("Block")
local GuardEvent = Events:FindFirstChild("Guard")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character
local PlayerName = LocalPlayer.Name

local PlayerValues = LocalPlayer:FindFirstChild("Values")
local RootPart = Character:FindFirstChild("HumanoidRootPart")
local Humanoid = Character:FindFirstChild("Humanoid")
local Courts = workspace:FindFirstChild("Courts")
Courts = Courts:GetChildren()

local getupvalue = getupvalue or debug.getupvalue

-- Always Green
local ShotFunction = filtergc("function", { Name = "Shoot" }, true)
local ShotProgress = getupvalue(ShotFunction, 1)

ShotProgress.Changed:Connect(function()
    if AlwaysGreen then
        ShotProgress.Value = 0.98
    end
end)

-- Infinite Stamina
local Stamina = PlayerValues:FindFirstChild("Stamina")
Stamina.Changed:Connect(function()
    if InfiniteStamina then
        Stamina.Value = 1
    end
end)

-- Auto Guard & Block
local GuardingValue = PlayerValues:FindFirstChild("Guarding")
local Basketball = PlayerValues:FindFirstChild("Basketball")
local Teammate1 = PlayerValues:FindFirstChild("Teammate1")
local Teammate2 = PlayerValues:FindFirstChild("Teammate2")
local InGame = PlayerValues:FindFirstChild("InGame")
local Guarding = false

local AutoBlockConnection
local CurrentBasketball
local CurrentlyMoving
local GuardPart

local IsTeammate = function(Player)
    local Name = Player.Name
    return (Teammate1.Value == Name) or (Teammate2.Value == Name)
end

local UpdateVariables = function()
    for _, Court in Courts do
        local CourtValues = Court:FindFirstChild("Values")

        local Player1 = CourtValues:FindFirstChild("Player1").Value
        local Player2 = CourtValues:FindFirstChild("Player2").Value
        local Player3 = CourtValues:FindFirstChild("Player3").Value
        local Player4 = CourtValues:FindFirstChild("Player4").Value

        if (Player1 == PlayerName) or (Player2 == PlayerName) or (Player3 == PlayerName) or (Player4 == PlayerName) then
            CurrentBasketball = Court:FindFirstChild("Basketball")
            CurrentlyMoving = CourtValues:FindFirstChild("Moving")
            return
        end
    end
end

local Loop = function()
    if not AutoGuard or not InGame.Value or not Guarding or not GuardPart or CurrentlyMoving.Value then
        return
    end

    if not GuardingValue.Value then
        GuardEvent:FireServer(true)
    end

    local GuardPosition = GuardPart.Position + (GuardPart.CFrame.LookVector * AutoGuardDistance)
    local NewCFrame = CFrame.lookAt(GuardPosition, GuardPart.Position)

    if AutoGuardMethod == "CFrame" then
        RootPart.CFrame = NewCFrame
    else
        Humanoid.WalkToPoint = GuardPosition
    end
end

Basketball.Changed:Connect(function(Value)
    if Value ~= nil then
        Guarding = false
    end
end)

for _, Player in Players:GetPlayers() do
    local TheirCharacter = Player.Character

    local TheirRootPart = TheirCharacter:FindFirstChild("HumanoidRootPart")
    local TheirValues = Player:FindFirstChild("Values")

    local TheirBasketball = TheirValues:FindFirstChild("Basketball")
    local TheirShooting = TheirValues:FindFirstChild("Shooting")
    
    TheirBasketball.Changed:Connect(function(Value)
        if CurrentBasketball and not IsTeammate(Player) and Value == CurrentBasketball then
            GuardPart = TheirRootPart
            Guarding = true

            print("setting autoblock connection hehe")
            AutoBlockConnection = TheirShooting.Changed:Connect(function(Value)
                if Value ~= true then
                    return
                end

                local Connection = AutoBlockConnection

                if Connection then
                    AutoBlockConnection:Disconnect()
                    AutoBlockConnection = nil
                end

                task.wait(AutoBlockDelay)
                BlockEvent:FireServer()
            end)
        end
    end)
end

InGame.Changed:Connect(UpdateVariables)
RunService.Heartbeat:Connect(Loop)

-- GUI
local ReGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/myethg/Dear-ReGui/refs/heads/main/ReGui.lua"))()
ReGui:Init({ Prefabs = InsertService:LoadLocalAsset("rbxassetid://91788667330406") })

local Window = ReGui:TabsWindow({
    Title = "Basketball Arcade | @taze29",
    Size = UDim2.fromOffset(425, 217),
    NoCollapse = true,
    NoResize = true,
    NoClose = true,
}):Center()

local MainTab = Window:CreateTab({ Name = "Main" })

MainTab:Checkbox({
    Label = "Always Green",
    Value = false,

    Callback = function(Self, Value)
        getgenv().AlwaysGreen = Value
    end
})

MainTab:Checkbox({
    Label = "Infinite Stamina",
    Value = false,

    Callback = function(Self, Value)
        getgenv().InfiniteStamina = Value
    end
})

MainTab:Checkbox({
    Label = "Auto Guard",
    Value = false,

    Callback = function(Self, Value)
        getgenv().AutoGuard = Value
    end
})

MainTab:InputInt({
    Label = "Auto Guard Distance",
    Value = 3,

    Minimum = 1,
    Maximum = 20,

    Callback = function(Self, Value)
        getgenv().AutoGuardDistance = Value
    end
})

MainTab:Combo({
    Label = "Auto Guard Method",
    Items = { "CFrame", "WalkToPoint" },
    Value = "CFrame",

    Callback = function(Self, Value)
        warn(Value)
        getgenv().AutoGuardMethod = Value
    end
})

MainTab:Checkbox({
    Label = "Auto Block",
    Value = false,

    Callback = function(Self, Value)
        getgenv().AutoBlock = Value
    end
})

MainTab:SliderFloat({
    Label = "Auto Block Delay",
    Value = 0.17,
    
    Minimum = 0,
    Maximum = 1,

    Callback = function(Self, Value)
        warn(Value)
        getgenv().AutoBlockDelay = Value
    end
})

local InfoTab = Window:CreateTab({ Name = "Info" })
InfoTab:Label({ Text = "Join the discord for bug reports/suggestions: discord.gg/tazer", TextWrapped = true })
InfoTab:Label({ Text = "" })

InfoTab:Label({ Text = "Note: Auto Block only works with Auto Guard" })
InfoTab:Label({ Text = "" })
InfoTab:Label({ Text = "Made with <3 by taze" })

local ButtonRow = InfoTab:Row()
ButtonRow:Button({
    Text = "Copy discord invite",

    Callback = function()
        setclipboard("https://discord.gg/tazer")
    end
})

ButtonRow:Button({
    Text = "Copy github repo link",

    Callback = function()
        setclipboard("https://github.com/taze292/script-archive")
    end
})
