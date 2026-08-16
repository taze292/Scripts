-- References
local InsertService = game:GetService("InsertService")
local CurrentPlaybackName
local CurrentPlayback

if not isfolder("MIDI") then
    makefolder("MIDI")
end

local SustainChanged = 64
local NoteOffset = 20
local TypeSustain = 3
local TypeOff = 2
local TypeOn = 1

local ChannelPressure = 0xD0
local ProgramChange = 0xC0
local ControlChange = 0xB0
local MetaTypeTempo = 0x51
local MetaTypeEnd = 0x2F
local TypeNoteOff = 0x80
local KeyPressure = 0xA0
local TypeNoteOn = 0x90
local SysExStart = 0xF0
local TypeStatus = 0x80
local PitchBend = 0xE0
local SysExEnd = 0xF7
local TypeMeta = 0xFF

-- Functions
local FromString = buffer.fromstring
local ReadString = buffer.readstring
local BReadU32 = buffer.readu32
local BReadU16 = buffer.readu16
local ByteSwap = bit32.byteswap
local BReadU8 = buffer.readu8
local Band = bit32.band

local ReadU16 = function(Buffer, Offset)
    local Value = BReadU16(Buffer, Offset)
    return Value % 256 * 256 + math.floor(Value / 256)
end

local ReadU32 = function(Buffer, Offset)
    return ByteSwap(BReadU32(Buffer, Offset))
end

local ReadVLQ = function(Buffer, Offset)
    local Value = 0

    while true do
        local Byte = BReadU8(Buffer, Offset)
        Offset += 1

        Value = Value * 128 + Band(Byte, 0x7F)

        if Byte < 0x80 then
            break
        end
    end

    return Value, Offset
end

local GetPlaybackEvents = function(MIDI)
    local Sustain = false
    local MSPQ = 500000
    local Result = {}

    if ReadString(MIDI, 0, 4) ~= "MThd" then
        return warn("Invalid Signature")
    end

    if ReadU32(MIDI, 4) ~= 6 then
        return warn("Invalid Header Length")
    end

    local TrackCount = ReadU16(MIDI, 10)
    local Division = ReadU16(MIDI, 12)
    local Offset = 14

    for Iteration = 1, TrackCount do
        if ReadString(MIDI, Offset, 4) ~= "MTrk" then
            local AlienLength = ReadU32(MIDI, Offset + 4)
            Offset += 8 + AlienLength

            continue
        end

        local TrackLength = ReadU32(MIDI, Offset + 4)
        Offset += 8

        local TrackEndOffset = Offset + TrackLength
        local RunningStatus = 0
        local Time = 0

        while Offset < TrackEndOffset do
            local Delta

            Delta, Offset = ReadVLQ(MIDI, Offset)
            Time += Delta * (MSPQ / 1000) / Division

            local Event = BReadU8(MIDI, Offset)
            if Event >= TypeStatus then
                RunningStatus = Event
                Offset += 1
            else
                Event = RunningStatus
            end

            if Event == TypeMeta then
                local MetaType = BReadU8(MIDI, Offset)
                local Length
                Offset += 1

                Length, Offset = ReadVLQ(MIDI, Offset)
                if MetaType == MetaTypeEnd then
                    Offset += Length
                    break
                elseif MetaType == MetaTypeTempo then
                    MSPQ = BReadU8(MIDI, Offset) * 65536 + BReadU8(MIDI, Offset + 1) * 256 + BReadU8(MIDI, Offset + 2)
                end

                Offset += Length
                RunningStatus = 0
            elseif Event == SysExStart or Event == SysExEnd then
                local Length
                Length, Offset = ReadVLQ(MIDI, Offset)

                Offset += Length
                RunningStatus = 0
            else
                local EventType = Band(Event, 0xF0)

                if EventType == TypeNoteOn then
                    local Note = BReadU8(MIDI, Offset) - NoteOffset
                    local Velocity = BReadU8(MIDI, Offset + 1)
                    Offset += 2

                    if Velocity == 0 then
                        Result[#Result + 1] = {
                            Time = Time,
                            Note = Note,
                            Type = TypeOff
                        }
                    else
                        Result[#Result + 1] = {
                            Time = Time,
                            Note = Note,
                            Type = TypeOn
                        }
                    end
                elseif EventType == TypeNoteOff then
                    local Note = BReadU8(MIDI, Offset) - NoteOffset
                    Offset += 2

                    Result[#Result + 1] = {
                        Time = Time,
                        Note = Note,
                        Type = TypeOff
                    }
                elseif EventType == ControlChange then
                    local ControlChangeType = BReadU8(MIDI, Offset)
                    local Value = BReadU8(MIDI, Offset + 1)
                    Offset += 2

                    if ControlChangeType == SustainChanged then
                        if Value >= 64 then
                            Sustain = true
                        else
                            Sustain = false
                        end

                        Result[#Result + 1] = {
                            Type = TypeSustain,
                            Enabled = Sustain,
                            Time = Time
                        }
                    end
                elseif EventType == ProgramChange or Event == ChannelPressure then
                    Offset += 1
                elseif EventType == KeyPressure or EventType == PitchBend then
                    Offset += 2
                else
                    break
                end
            end
        end
    end

    table.sort(Result, function(Event1, Event2)
        return Event1.Time < Event2.Time
    end)

    return Result
end

local DownloadFile = function(Name, URL)
    if Name:sub(#Name - 2, #Name) ~= "mid" and Name:sub(#Name - 3, #Name) ~= "midi" then
        return "Invalid File Name"
    end

    local Success, Data = pcall(game.HttpGet, game, URL)
    if not Success then
        return "Couldn't download file"
    end

    writefile(Name, Data)
    return "Success"
end

-- Playback
local PianoController = require(game:GetService("ReplicatedStorage"):FindFirstChild("PianoController", true))
local PlayingConnection
local IsPlaying = false
local IsPaused = false
local EventIndex = 1
local LastTime = 0

local function Pause()
    if not IsPlaying or IsPaused then
        return
    end

    IsPaused = true
    PianoController:ReleaseAllClientKeys()
end

local function Resume()
    if not IsPlaying or not IsPaused then
        return
    end

    IsPaused = false
end

local function Stop()
    if not IsPlaying then
        return
    end

    IsPlaying = false
    IsPaused = false

    if PlayingConnection then
        task.cancel(PlayingConnection)
        PlayingConnection = nil
    end

    PianoController:ReleaseAllClientKeys()
end

local function Play()
    if not CurrentPlayback or IsPlaying then
        return
    end

    IsPlaying = true
    IsPaused = false
    EventIndex = 1
    LastTime = 0

    PlayingConnection = task.spawn(function()
        while IsPlaying do
            local Event = CurrentPlayback[EventIndex]
            if not Event then
                break
            end

            local WaitTime = (Event.Time - LastTime) / 1000
            LastTime = Event.Time

            local Start = os.clock()

            while IsPlaying and os.clock() - Start < WaitTime do
                if IsPaused then
                    Start = os.clock()
                    while IsPlaying and IsPaused do
                        task.wait()
                    end
                else
                    task.wait(math.min(0.05, WaitTime - (os.clock() - Start)))
                end
            end

            if not IsPlaying then
                break
            end

            if Event.Type == TypeOn then
                PianoController:PressClientKey(Event.Note, Event.Note)
            elseif Event.Type == TypeOff then
                PianoController:ReleaseClientKey(Event.Note)
            elseif Event.Type == TypeSustain then
                PianoController:ToggleSustain(Event.Enabled)
            end

            EventIndex += 1
        end

        IsPlaying = false
        PlayingConnection = nil
        PianoController:ReleaseAllClientKeys()
    end)
end

-- UI
local ReGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/myethg/Dear-ReGui/refs/heads/main/ReGui.lua"))()
ReGui:Init({ Prefabs = InsertService:LoadLocalAsset("rbxassetid://91788667330406") })

local Window = ReGui:TabsWindow({
    Title = "Visual Pianos MIDI Player | @taze29",
    Size = UDim2.fromOffset(425, 217),
    NoCollapse = true,
    NoResize = true,
    NoClose = true,
}):Center()

local MainTab = Window:CreateTab({ Name = "Main" })
local DownloadTab = Window:CreateTab({ Name = "Download" })
local InfoTab = Window:CreateTab({ Name = "Info" })

-- Main Tab
local FileSelect = MainTab:Combo({
    Label = "Select File",
    GetItems = function()
        return listfiles("MIDI")
    end
})

MainTab:Row():Button({
    Text = "Load MIDI",
    Callback = function()
        local File = FileSelect.Value
        if CurrentPlaybackName == File then
            return
        end

        local PlaybackTable = GetPlaybackEvents(FromString(readfile(File)))
        if type(PlaybackTable) ~= "table" then
            return
        end

        if IsPlaying then
            Stop()
        end

        CurrentPlaybackName = File
        CurrentPlayback = PlaybackTable
    end
})

MainTab:Label({ Text = "Controls" })

local ControlRow = MainTab:Row()
ControlRow:Button({
    Text = "Play",
    Callback = function()
        Play()
    end
})
ControlRow:Button({
    Text = "Pause",
    Callback = function()
        if IsPaused then
            Resume()
        else
            Pause()
        end
    end
})
ControlRow:Button({
    Text = "Stop",
    Callback = function()
        Stop()
    end
})

-- Download Tab
local StatusLabel
local URLBox = DownloadTab:InputText({
    Placeholder = "Enter a URL here",
    Label = "",
    Value = ""
})

local NameBox = DownloadTab:InputText({
    Placeholder = "Enter file name",
    Label = "",
    Value = ""
})

DownloadTab:Row():Button({
    Text = "Download",
    Callback = function()
        local Result = DownloadFile(`MIDI/{NameBox.Value}`, URLBox.Value)
        StatusLabel.Text = Result
    end
})

DownloadTab:Label({ Text = "" })
StatusLabel = DownloadTab:Label({ Text = "" })

-- Info Tab
InfoTab:Label({ Text = "Made with <3 by taze" })
InfoTab:Label({ Text = "Discord: https://discord.gg/tazer" })
InfoTab:Label({ Text = "Github: https://github.com/taze292/Scripts" })

InfoTab:Label({ Text = "All files downloaded are stored in workspace/MIDI" })
InfoTab:Label({ Text = "" })

local Row = InfoTab:Row()
Row:Button({
    Text = "Copy Discord Invite",
    Callback = function()
        setclipboard("https://discord.gg/tazer")
    end
})

Row:Button({
    Text = "Copy Github Link",
    Callback = function()
        setclipboard("https://github.com/taze292/Scripts")
    end
})