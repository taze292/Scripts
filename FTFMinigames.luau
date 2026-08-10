getgenv().AutoCompleteMinigames = false
getgenv().NeverFailMinigames = true

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remote = ReplicatedStorage:FindFirstChild("RemoteEvent")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Auto Complete Minigames
local TimingGoalPosition = LocalPlayer:FindFirstChild("TimingGoalPosition", true)
TimingGoalPosition:GetPropertyChangedSignal("Value"):Connect(function()
    if AutoCompleteMinigames then
        Remote:FireServer("SetPlayerMinigameResult", true)
    end
end)

local Callback = getconnections(TimingGoalPosition.Changed)[1].Function
local Original

Original = hookfunction(Callback, function()    
    if AutoCompleteMinigames then
        return
    end

    return Original()
end)

--[[
    I sincerely apologize for writing this shitty unoptimized code.
    My only other option was to reverse the following math:

    Rotation += 360 / (-ActionProgress + 2) * DeltaTime

    I am retarded, which explains why I opted for shitty namecall hook over that.
    Thank you for your understanding.
]]--

-- Never Fail Minigames
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(Self, ...)
    local Method = getnamecallmethod()
    local Caller = checkcaller()
    local Arguments = {...}

    if not Caller and Method == "FireServer" and Arguments[1] == "SetPlayerMinigameResult" and Arguments[2] == false then
        Arguments[2] = true
    end

    return OldNamecall(Self, table.unpack(Arguments))
end))