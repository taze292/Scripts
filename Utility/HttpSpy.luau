--[[

    Contrbutors
    @taze29 - Main Developer
    @deaggilisspees - Providing Detections
    Killa (idk his discord) - Major bug fix
    @actualmasteroogway - "detection" (kinda)

    Taze - https://v3rm.net/members/.97636/
    De Aggilis - https://v3rm.net/members/.79930/
    Killa - https://v3rm.net/members/.2976/
    MasterOogway - https://v3rm.net/members/.6431/

]]--

-- Initialization
local StringLengthLimit = StringLengthLimit or 1000
local FilterLPHStrings = FilterLPHStrings or true
getgenv().StringLengthLimit = nil
getgenv().FilterLPHStrings = nil

local StartLoading = os.clock()
local TestEndpoint = "https://httpbun.com/anything"
local HttpService = game:GetService("HttpService")
local TestUUID = HttpService:GenerateGUID(false)

local HookHttpPostAsync = false
local HookHttpGetAsync = false
local HookHttpPost = false
local HookHttpGet = false

local Success, Message

local FunctionsToHook = {}
local UserHooks = {}
local Wrappers = {}
local Hooks = {}

print("Taze's Http Spy - 8/12/26")
print()
print("Compatability Checks")

-- Utility
local JSONDecode

local ExtractError = function(ErrorMessage)
    local ActualMessage

    if ErrorMessage:sub(1, 1) == ":" then
        ActualMessage = ErrorMessage:sub(ErrorMessage:find(" ") + 1)
    else
        ActualMessage = ErrorMessage
    end

    return ActualMessage
end

local FindValue = function(Table, Value)
    for Key, TableValue in Table do
        if TableValue == Value then
            return Key
        end
    end

    return nil
end

local GetOutputString = function(String)
    local IsIndented = String:sub(1, 4) == "    "

    if type(String) == "string" then
        local LoweredString = String:lower()
        if FilterLPHStrings and (LoweredString:find("lph")) then
            String = "LPH String"
        end

        if #String > StringLengthLimit then
            String = `{String:sub(1, StringLengthLimit)} (Truncated. Max String Length: {StringLengthLimit}; This String's Length: {#String})`
        end
    end

    return (IsIndented and "    " or "") .. String
end

local RandomString = function()
    local RNG = Random.new(os.clock() * 100000000)
    local Length = RNG:NextInteger(6, 24)

    local ResultString = {}

    local Chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    for Iteration = 1, Length do
        local NextLetter = RNG:NextInteger(1, #Chars)
        local Letter = Chars:sub(NextLetter, NextLetter)

        ResultString[#ResultString + 1] = Letter
    end

    return table.concat(ResultString)
end

JSONDecode = function(Data)
    if type(Data) == "string" then
        local Success, Result = pcall(function()
            return HttpService:JSONDecode(Data)
        end)

        if Success then
            return JSONDecode(Result)
        end

        return Data
    end

    if type(Data) == "table" then
        local Result = {}

        for Key, Value in Data do
            Result[Key] = JSONDecode(Value)
        end

        return Result
    end

    return Data
end

-- Compatability checks
Success, Message = pcall(function()
    local MainFunction = debug.info(1, 'f')

    local CallerRef
    local Main = function()
        local Traceback = debug.traceback()
        if Traceback:find("Hidden") or Traceback:find("Hidden2") then
            return "Fail"
        end

        local Caller = debug.info(2, 'f')
        if Caller ~= CallerRef then
            return "Fail"
        end

        local SecondCaller = debug.info(4, 'f')
        if SecondCaller ~= MainFunction then
            return "Fail"
        end

        local CallerEnv = getfenv(2)
        if CallerEnv ~= getfenv(CallerRef) then
            return "Fail"
        end

        local SecondCallerEnv = getfenv(4)
        if SecondCallerEnv ~= getfenv(MainFunction) then
            return "Fail"
        end

        return "Pass"
    end

    local function Hidden()
        setstackhidden(1, true)
        return Main()
    end

    local function TrueCaller()
        -- print("Called Main")
        return Hidden()
    end

    CallerRef = TrueCaller

    local function Hidden2()
        return TrueCaller()
    end

    setstackhidden(Hidden2, true)

    local Result = Hidden2()
    if Result ~= "Pass" then
        assert("Failed")
    end
    
    return
end)

if Success then
    print("✅ setstackhidden")
else
    print("❌ setstackhidden |", ExtractError(Message))
    return
end

Success, Message = pcall(function()
    local Response = game:HttpPostAsync(TestEndpoint, `UUID={TestUUID}`)
    Response = HttpService:JSONDecode(Response).form.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["HttpPostAsync"] = game.HttpPostAsync
    HookHttpPostAsync = true
end)

if Success then
    print("✅ HttpPostAsync")
else
    print("❌ HttpPostAsync |", ExtractError(Message))
end

Success, Message = pcall(function()
    local Response = game:HttpGetAsync(`{TestEndpoint}?UUID={TestUUID}`)
    Response = HttpService:JSONDecode(Response).args.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["HttpGetAsync"] = game.HttpGetAsync
    HookHttpGetAsync = true
end)

if Success then
    print("✅ HttpGetAsync")
else
    print("❌ HttpGetAsync |", ExtractError(Message))
end

Success, Message = pcall(function()
    local Response = game:HttpPost(TestEndpoint, `UUID={TestUUID}`)
    Response = HttpService:JSONDecode(Response).form.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["HttpPost"] = game.HttpPost
    HookHttpPost = true
end)

if Success then
    print("✅ HttpPost")
else
    print("❌ HttpPost |", ExtractError(Message))
end

Success, Message = pcall(function()
    local Response = game:HttpGet(`{TestEndpoint}?UUID={TestUUID}`)
    Response = HttpService:JSONDecode(Response).args.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["HttpGet"] = game.HttpGet
    HookHttpGet = true
end)

if Success then
    print("✅ HttpGet")
else
    print("❌ HttpGet |", ExtractError(Message))
end

Success, Message = pcall(function()
    assert(FindValue(FunctionsToHook, httppost) == nil, "Alias")

    local Response = httppost(TestEndpoint, `UUID={TestUUID}`)
    Response = HttpService:JSONDecode(Response).form.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["httppost"] = httppost
end)

if Success then
    print("✅ httppost")
else
    print("❌ httppost |", ExtractError(Message))
end

Success, Message = pcall(function()
    assert(FindValue(FunctionsToHook, httpget) == nil, "Alias")

    local Response = httpget(`{TestEndpoint}?UUID={TestUUID}`)
    Response = HttpService:JSONDecode(Response).args.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["httpget"] = httpget
end)

if Success then
    print("✅ httpget")
else
    print("❌ httpget |", ExtractError(Message))
end

Success, Message = pcall(function()
    assert(FindValue(FunctionsToHook, http_post) == nil, "Alias")

    local Response = http_post(TestEndpoint, `UUID={TestUUID}`)
    Response = HttpService:JSONDecode(Response).form.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["http_post"] = http_post
end)

if Success then
    print("✅ http_post")
else
    print("❌ http_post |", ExtractError(Message))
end

Success, Message = pcall(function()
    assert(FindValue(FunctionsToHook, http_get) == nil, "Alias")

    local Response = http_get(`{TestEndpoint}?UUID={TestUUID}`)
    Response = HttpService:JSONDecode(Response).args.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["http_get"] = http_get
end)

if Success then
    print("✅ http_get")
else
    print("❌ http_get |", ExtractError(Message))
end

Success, Message = pcall(function()
    assert(FindValue(FunctionsToHook, request) == nil, "Alias")

    local Response = request({ Url = `{TestEndpoint}?UUID={TestUUID}`, Method = "GET" })
    Response = HttpService:JSONDecode(Response.Body).args.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["request"]  = request
end)

if Success then
    print("✅ request")
else
    print("❌ request |", ExtractError(Message))
end

Success, Message = pcall(function()
    assert(FindValue(FunctionsToHook, http_request) == nil, "Alias")

    local Response = http_request({ Url = `{TestEndpoint}?UUID={TestUUID}`, Method = "GET" })
    Response = HttpService:JSONDecode(Response.Body).args.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["http_request"]  = http_request
end)

if Success then
    print("✅ http_request")
else
    print("❌ http_request |", ExtractError(Message))
end

Success, Message = pcall(function()
    assert(FindValue(FunctionsToHook, http.request) == nil, "Alias")

    local Response = http.request({ Url = `{TestEndpoint}?UUID={TestUUID}`, Method = "GET" })
    Response = HttpService:JSONDecode(Response.Body).args.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["http.request"]  = http.request
end)

if Success then
    print("✅ http.request")
else
    print("❌ http.request |", ExtractError(Message))
end

Success, Message = pcall(function()
    -- SynZ support for vibecoded auths </3
    assert(FindValue(FunctionsToHook, syn.request) == nil, "Alias")

    local Response = syn.request({ Url = `{TestEndpoint}?UUID={TestUUID}`, Method = "GET" })
    Response = HttpService:JSONDecode(Response.Body).args.UUID

    assert(Response == TestUUID, "UUID Mismatch")

    FunctionsToHook["syn.request"]  = syn.request
end)

if Success then
    print("✅ syn.request")
else
    print("❌ syn.request |", ExtractError(Message))
end

-- Logging
local OutputString = ""
local OutputTable
local Output
local Dump

OutputTable = function(Table, Indent, Seen)
    Indent = Indent or 0
    Seen = Seen or {}

    local DoubleIndent = string.rep("    ", Indent + 1)
    local IndentString = string.rep("    ", Indent)

    if Seen[Table] then
        Output(`{IndentString}<Circular Reference>`)
        return
    end

    Seen[Table] = true
    for Key, Value in next, Table do
        if type(Value) == "string" then
            Value = GetOutputString(Value)
        end

        local ValueType = type(Value)
        Output(`{IndentString}[{Key}: {ValueType}] {ValueType == "table" and "table" or Value}`)

        if type(Value) == "table" then
            OutputTable(Value, Indent + 1, Seen)
            continue
        end

        if type(Value) == "function" then
            local Name, Line, Args, Varargs, Source = debug.info(Value, "nlas")

            Output(`{DoubleIndent}Name: {Name}`)
            Output(`{DoubleIndent}Line: {Line}`)
            Output(`{DoubleIndent}Arguments: {Args}`)
            Output(`{DoubleIndent}Varargs: {Varargs}`)
            Output(`{DoubleIndent}Source: {Source}`)
            Output(`{DoubleIndent}Hash: {getfunctionhash(Value)}`)

            continue
        end
    end
end

Output = function(...)
    local Arguments = {...}
    OutputString = `{OutputString}{OutputString ~= "" and "\n" or ""}`

    for Index, Value in Arguments do
        OutputString = `{OutputString}{Index ~= 1 and " " or ""}{Value}`
    end
end

-- Request hooks
print()
print("Request hooks")

local GameMetatable = getrawmetatable(game)
local Namecall = GameMetatable.__namecall
local OldNamecall

local NamecallWrapper = newcclosure(function(Self, ...)
    local Result = OldNamecall(Self, ...)
    local Method = getnamecallmethod()

    if Self == game then
        local Arguments = {...}

        if (Method == "HttpPostAsync" and HookHttpPostAsync) or (Method == "HttpGetAsync" and HookHttpGetAsync) or (Method == "HttpPost" and HookHttpPost) or (Method == "HttpGet" and HookHttpGet) then
            Output(`> {Method}`)
            OutputTable(Arguments, 1)
            
            Output("Return Values")
            local Decoded = JSONDecode(Result)
            if type(Decoded) == "table" then
                OutputTable(Decoded, 1)
            else
                Output(GetOutputString(`    {Result}`))
            end

            Output()
        end
    end

    return Result
end, "")

Success, Message = pcall(function()
    OldNamecall = hookfunction(Namecall, NamecallWrapper)
    Wrappers[Namecall] = NamecallWrapper
    Hooks[#Hooks + 1] = Namecall
end)

if Success then
    print("✅ Namecall")
else
    print("❌ Namecall |", ExtractError(Message))
end

local LogFunction = function(Name, Arguments, Result)
    Output(`> {Name}`)
    OutputTable(Arguments, 1)

    Output("Return Values")
    local Decoded = JSONDecode(Result)

    if type(Decoded) == "table" then
        OutputTable(Decoded, 1)
    else
        Output(GetOutputString(`    {Result}`))
    end

    Output()
end

for Name, Function in FunctionsToHook do
    local Old
    local Wrapper = newcclosure(function(...)
        local ActualFunction = UserHooks[Function] or Old

        setstackhidden(1, true)
        setstackhidden(Old, true)
    
        local Arguments = table.pack(...)

        for ArgIndex = 1, Arguments.n do
            local Arg = rawget(Arguments, ArgIndex)
            if type(Arg) ~= "table" then continue end

            local Meta = getrawmetatable(Arg)
            if not Meta then continue end

            local _, Index = pcall(function()
                return Meta.__index
            end)

            if Index and type(Index) == "function" then
                local Upvalues = getupvalues(Index)
                local Resolved = {}

                for _, Upvalue in Upvalues do
                    if type(Upvalue) == "table" and next(Upvalue) then
                        for Key, Value in Upvalue do
                            Resolved[Key] = Value
                        end
                    end
                end

                if next(Resolved) then
                    Arguments[ArgIndex] = Resolved
                end
            end
        end

        local Result = ActualFunction(...)
        LogFunction(Name, Arguments, Result)
        return Result
    end, Name)

    Success, Message = pcall(function()
        Old = hookfunction(Function, Wrapper)
        Wrappers[Function] = Wrapper
        Hooks[#Hooks + 1] = Function
    end)

    if Success then
        print(`✅ {Name}`)
    else
        print(`❌ {Name} | {ExtractError(Message)}`)
    end
end

-- Detection bypasses
print()
print("Detection patches")

local Empty = function() end
local OldIsFunctionHooked
local OldRestoreFunction
local OldHookFunction
local OldGetInfo

if isfunctionhooked then
    local IsFunctionHookedWrapper = newcclosure(function(TargetFunction)
        if UserHooks[isfunctionhooked] then
            return UserHooks[isfunctionhooked]()
        end

        setstackhidden(1, true)
        setstackhidden(OldIsFunctionHooked, true)

        if FindValue(Hooks, TargetFunction) then
            return false
        end

        return OldIsFunctionHooked(TargetFunction)
    end, "isfunctionhooked")

    Success, Message = pcall(function()
        OldIsFunctionHooked = hookfunction(isfunctionhooked, IsFunctionHookedWrapper)
        Wrappers[isfunctionhooked] = IsFunctionHookedWrapper
        Hooks[#Hooks + 1] = isfunctionhooked
    end)

    if Success then
        print("✅ isfunctionhooked")
    else
        print("❌ isfunctionhooked |", ExtractError(Message))
    end
end

if restorefunction then
    local RestoreFunctionWrapper = newcclosure(function(TargetFunction)
        if UserHooks[restorefunction] then
            return UserHooks[restorefunction]()
        end

        setstackhidden(1, true)
        setstackhidden(OldRestoreFunction, true)

        if FindValue(Hooks, TargetFunction) then
            return OldRestoreFunction(Empty)
        end

        if UserHooks[TargetFunction] then
            local Wrapper = Wrappers[TargetFunction]

            OldRestoreFunction(TargetFunction)
            OldHookFunction(TargetFunction, Wrapper)
            
            UserHooks[TargetFunction] = nil
            Hooks[#Hooks + 1] = TargetFunction
            return
        end

        return OldRestoreFunction(TargetFunction)
    end, "restorefunction")

    Success, Message = pcall(function()
        OldRestoreFunction = hookfunction(restorefunction, RestoreFunctionWrapper)
        Wrappers[restorefunction] = RestoreFunctionWrapper
        Hooks[#Hooks + 1] = restorefunction
    end)

    if Success then
        print("✅ restorefunction")
    else
        print("❌ restorefunction |", ExtractError(Message))
    end
end

if hookfunction then
    local HookFunctionWrapper = newcclosure(function(TargetFunction, Hook)
        if UserHooks[hookfunction] then
            return UserHooks[hookfunction]()
        end

        setstackhidden(1, true)
        setstackhidden(OldHookFunction, true)

        local TargetIndex = FindValue(Hooks, TargetFunction)
        if TargetIndex then
            Hooks[TargetIndex] = nil
            UserHooks[TargetFunction] = Hook

            return clonefunction(Wrappers[TargetFunction])
        end

        if UserHooks[TargetFunction] then
            UserHooks[TargetFunction] = Hook
            return clonefunction(Wrappers[TargetFunction])
        end

        return OldHookFunction(TargetFunction, Hook)
    end, "hookfunction")

    Success, Message = pcall(function()
        OldHookFunction = hookfunction(hookfunction, HookFunctionWrapper)
        Wrappers[hookfunction] = HookFunctionWrapper
        Hooks[#Hooks + 1] = hookfunction
    end)

    if Success then
        print("✅ hookfunction")
    else
        print("❌ hookfunction |", ExtractError(Message))
    end
end

if debug.getinfo then
    local GetInfoWrapper = newcclosure(function(FuncOrLevel, Selector)
        if UserHooks[debug.getinfo] then
            return UserHooks[debug.getinfo]() 
        end

        setstackhidden(1, true)
        setstackhidden(OldGetInfo, true)

        if type(FuncOrLevel) == "number" then
            FuncOrLevel += 1
        end

        local InfoResult = debug.info(FuncOrLevel, 'f')
        return OldGetInfo(InfoResult, Selector)
    end, "getinfo")

    Success, Message = pcall(function()
        OldGetInfo = hookfunction(debug.getinfo, GetInfoWrapper)
        Wrappers[debug.getinfo] = GetInfoWrapper
        Hooks[#Hooks + 1] = debug.getinfo
    end)

    if Success then
        print("✅ debug.getinfo")
    else
        print("❌ debug.getinfo |", ExtractError(Message))
    end
end

local DumpFunctionName = RandomString()
Dump = newcclosure(function()
    writefile(`Http Spy Log {tick()}.txt`, OutputString)
    OutputString = ""
end, DumpFunctionName)

getgenv()[DumpFunctionName] = Dump
setclipboard(`{DumpFunctionName}()`)

local LoadDuration = os.clock() - StartLoading

print()
print(`Loaded. Time Taken: {tostring(LoadDuration):sub(1, 5)}s`)
print(`Copied the code to dump the logs to your clipboard.`)