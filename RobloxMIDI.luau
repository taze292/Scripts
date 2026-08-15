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

-- Init
local URL = "https://bitmidi.com/uploads/72257.mid" or ...
local MIDI = FromString(game:HttpGet(URL))

if ReadString(MIDI, 0, 4) ~= "MThd" then
    return warn("Invalid Signature")
end

local HeaderLength = ReadU32(MIDI, 4)
if HeaderLength ~= 6 then
    return warn("Invalid Header Length")
end

-- Handling
local Offset = 14
local Tracks = ReadU16(MIDI, 10)
local Division = ReadU16(MIDI, 12)

local Sustain = false
local MicrosecondsPerQuarter = 500000
local PlaybackEvents = {}

local TypeOn = 1
local TypeOff = 2
local TypeSustain = 3

for Iteration = 1, Tracks do
    if ReadString(MIDI, Offset, 4) ~= "MTrk" then
        local AlienLength = ReadU32(MIDI, Offset + 4)
        Offset += 8 + AlienLength

        continue
    end

    Offset += 4

    local TrackLength = ReadU32(MIDI, Offset)
    Offset += 4

    local TrackEndOffset = Offset + TrackLength
    local RunningStatus = 0
    local Time = 0

    while Offset < TrackEndOffset do
        local Delta
        Delta, Offset = ReadVLQ(MIDI, Offset)
        Time += Delta * (MicrosecondsPerQuarter / 1000) / Division

        local Event = BReadU8(MIDI, Offset)
        if Event >= 0x80 then
            Offset += 1
            RunningStatus = Event
        else
            Event = RunningStatus
        end

        if Event == 0xFF then
            local MetaType = BReadU8(MIDI, Offset)
            Offset += 1

            local Length
            Length, Offset = ReadVLQ(MIDI, Offset)
            if MetaType == 0x2F then
                Offset += Length

                break
            elseif MetaType == 0x51 then
                MicrosecondsPerQuarter = BReadU8(MIDI, Offset) * 65536 + BReadU8(MIDI, Offset + 1) * 256 + BReadU8(MIDI, Offset + 2)
            end

            Offset += Length
            RunningStatus = 0
        elseif Event == 0xF0 or Event == 0xF7 then
            local Length
            Length, Offset = ReadVLQ(MIDI, Offset)

            Offset += Length
            RunningStatus = 0
        else
            local EventType = Band(Event, 0xF0)

            if EventType == 0x90 then
                local Note = BReadU8(MIDI, Offset)
                local Velocity = BReadU8(MIDI, Offset + 1)
                Offset += 2

                if Velocity == 0 then
                    PlaybackEvents[#PlaybackEvents + 1] = { Time = Time, Type = TypeOff, Note = Note - 20 }
                else
                    PlaybackEvents[#PlaybackEvents + 1] = { Time = Time, Type = TypeOn, Note = Note - 20 }
                end
            elseif EventType == 0x80 then
                local Note = BReadU8(MIDI, Offset)
                Offset += 2

                PlaybackEvents[#PlaybackEvents + 1] = { Time = Time, Type = TypeOff, Note = Note - 20 }
            elseif EventType == 0xA0 or EventType == 0xE0 then
                Offset += 2
            elseif EventType == 0xB0 then
                local CC = BReadU8(MIDI, Offset)
                local Value = BReadU8(MIDI, Offset + 1)
                Offset += 2

                if CC == 64 then
                    if Value >= 64 then
                        Sustain = true
                    else
                        Sustain = false
                    end

                    PlaybackEvents[#PlaybackEvents + 1] = { Time = Time, Type = TypeSustain, Enabled = Sustain }
                end
            elseif EventType == 0xC0 or EventType == 0xD0 then
                Offset += 1
            else
                break
            end
        end
    end
end

table.sort(PlaybackEvents, function(Event1, Event2)
    return Event1.Time < Event2.Time
end)

-- Playback
local PianoController = require(game:GetService("ReplicatedStorage"):FindFirstChild("PianoController", true))
local LastTime = 0

for _, Event in PlaybackEvents do
    task.wait((Event.Time - LastTime) / 1000)
    LastTime = Event.Time

    if Event.Type == TypeOn then
        PianoController:PressClientKey(Event.Note, Event.Note)
    elseif Event.Type == TypeOff then
        PianoController:ReleaseClientKey(Event.Note)
    elseif Event.Type == TypeSustain then
        PianoController:ToggleSustain(Event.Enabled)
    end
end
