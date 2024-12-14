local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local CoreGui = game:GetService("CoreGui")
local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ContentProvider = game:GetService("ContentProvider")
local Stats = game:GetService("Stats")
local ScriptService = game:GetService("ScriptService")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPack = game:GetService("StarterPack")
local NetworkClient = game:GetService("NetworkClient")
local NetworkServer = game:GetService("NetworkServer")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataModel = game

local Signal = require(game:GetService("CorePackages").Signal)

local ZetaV3 = {}
ZetaV3.Version = "ZetaV3.5.0"

ZetaV3.config = {
    printStackTraces = false,
    maxTableDepth = 15,
    blacklist = {},
    whitelist = {},
    logTimestamps = true,
    formatOutput = true,
    logLevel = 1,
    hookMetamethods = true,
    hookGlobals = true,
    useSignals = true,
    maxLogLength = 4000,
    logFilter = nil,
    logContext = true,
    logMemoryUsage = true,
    memoryLogInterval = 5,
    logObjectIdentity = true,
    logErrorsAsWarnings = false,
    logPerformance = true,
    logCallHierarchy = true,
    maxCallHierarchyDepth = 25,
    logMetatableChanges = true,
    logIndexChanges = true,
    logUpvalues = true,
    logEnv = true,
    useWeakTablesForSeen = true,
    logYields = true,
    logThreads = true,
    logWarnings = true,
    useCustomToString = true,
    logScriptContext = true,
    logReplicatedFirstDescendants = true,
    useCustomErrorHandling = true,
    captureReturnValues = true,
    logGC = true,
    gcLogInterval = 10,
    logDescendantAddedRemoved = true,
    logScriptExecution = true,
    logInstanceCreation = true,
    logSetRawMemory = false,
    logDataModelChanges = true,
    logStats = true,
    statLogInterval = 2,
    logUserInput = true,
    logTeleporting = true,
    logPathfinding = true,
    logPhysics = true,
    logBadgeAwarding = true,
    logDataStoreOperations = true,
    logMessagingService = true,
    logRenderStepped = true,
    logHeartbeat = true,
    logStepped = true,
    logNetworkOwnership = true,
    logPhysicsSimulation = true,
    logMemoryDetails = true,
    logTaskSchedulerActivity = true,
    logScriptErrors = true,
    logJoinsAndLeaves = true,
    logRemoteFunctionCalls = true,
    logDataStoreErrors = true,
    logMessagingServiceErrors = true,
    logNetworkClient = true,
    logNetworkServer = true,
    logMemoryStoreService = true,
    logDataModel = true
}

ZetaV3.logSignal = Signal.new()
ZetaV3.logBuffer = {}
local memoryLogLastTime = 0
local gcLogLastTime = 0
local statLogLastTime = 0
local callHierarchyDepth = 0
local weakTableMeta = {__mode = "k"}

local function safeToString(value)
    local success, str = pcall(tostring, value)
    return success and str or "<error converting to string>"
end

local formatValue
local formatTable
formatTable = function(t, depth, seenTables)
    depth = depth or 1
    if depth > ZetaV3.config.maxTableDepth then
        return "{...}"
    end
    if type(t) ~= "table" then
        return safeToString(t)
    end
    seenTables = seenTables or (ZetaV3.config.useWeakTablesForSeen and setmetatable({}, weakTableMeta) or {})
    if seenTables[t] then
        return "<circular reference>"
    end
    seenTables[t] = true
    local str = "{"
    local i = 1
    for k, v in pairs(t) do
        local keyStr = type(k) == "string" and string.format('"%s"', k) or safeToString(k)
        local valStr = formatValue(v, depth + 1, seenTables)
        str = str .. keyStr .. "=" .. valStr .. (i < #t and ", " or "")
        i = i + 1
    end
    seenTables[t] = nil
    return str .. "}"
end

formatValue = function(value, depth, seenTables)
    seenTables = seenTables or (ZetaV3.config.useWeakTablesForSeen and setmetatable({}, weakTableMeta) or {})
    local valueType = typeof(value)
    if seenTables[value] then
        return "<circular reference>"
    end
    seenTables[value] = true

    local formatted = ""
    if valueType == "Instance" then
        formatted =
            ZetaV3.config.useCustomToString and value:GetFullName() or
            string.format(
                "%s (%s%s)",
                value:GetFullName(),
                value.ClassName,
                ZetaV3.config.logObjectIdentity and string.format(", 0x%x", value) or ""
            )
    elseif valueType == "table" then
        formatted = formatTable(value, depth, seenTables)
    elseif valueType == "function" then
        formatted = "function"
    elseif valueType == "userdata" then
        formatted = "userdata"
    elseif type(value) == "string" and #value > 4096 then
        formatted = string.sub(value, 1, 4096) .. "... (truncated)"
    else
        formatted = safeToString(value)
    end
    seenTables[value] = nil
    return formatted
end

local function formatArgs(args)
    local formatted = {}
    for i = 1, #args do
        formatted[i] = formatValue(args[i], 1, {})
    end
    return table.concat(formatted, ", ")
end

local function log(message, level, context, logType, scriptContext, err)
    level = level or 1
    if level > ZetaV3.config.logLevel then
        return
    end
    if ZetaV3.config.logFilter and not ZetaV3.config.logFilter(message, level, context, logType, scriptContext, err) then
        return
    end

    local fullMessage = message
    if ZetaV3.config.logTimestamps then
        fullMessage = "[" .. os.date("%Y-%m-%d %H:%M:%S") .. "] " .. fullMessage
    end

    if ZetaV3.config.logContext and context then
        fullMessage = fullMessage .. " (Context: " .. context .. ")"
    end

    if ZetaV3.config.logScriptContext and scriptContext then
        fullMessage = fullMessage .. " (Script: " .. scriptContext .. ")"
    end

    if ZetaV3.config.formatOutput then
        local prefix = fullMessage:match("^%[(%a+)%]")
        if prefix then
            local color = ""
            if prefix == "[Remote]" then
                color = "\x1b[36m"
            elseif prefix == "[Event]" then
                color = "\x1b[32m"
            elseif prefix == "[Property]" then
                color = "\x1b[33m"
            elseif prefix == "[Metamethod]" then
                color = "\x1b[35m"
            elseif prefix == "[Global]" then
                color = "\x1b[94m"
            elseif prefix == "[Metatable]" then
                color = "\x1b[31;1m"
            elseif prefix == "[Index]" then
                color = "\x1b[34;1m"
            elseif prefix == "[Thread]" then
                color = "\x1b[35;1m"
            elseif prefix == "[Yield]" then
                color = "\x1b[36;1m"
            elseif prefix == "[GC]" then
                color = "\x1b[32;1m"
            elseif prefix == "[DescendantAdded]" then
                color = "\x1b[92m"
            elseif prefix == "[DescendantRemoving]" then
                color = "\x1b[91m"
            elseif prefix == "[ScriptExecution]" then
                color = "\x1b[93m"
            elseif prefix == "[InstanceCreation]" then
                color = "\x1b[96m"
            elseif prefix == "[SetRawMemory]" then
                color = "\x1b[95m"
            elseif prefix == "[DataModel]" then
                color = "\x1b[34m"
            elseif prefix == "[Stats]" then
                color = "\x1b[37m"
            elseif prefix == "[UserInput]" then
                color = "\x1b[38;5;46m"
            elseif prefix == "[Teleporting]" then
                color = "\x1b[38;5;172m"
            elseif prefix == "[Pathfinding]" then
                color = "\x1b[38;5;226m"
            elseif prefix == "[Physics]" then
                color = "\x1b[38;5;118m"
            elseif prefix == "[Physics Simulation]" then
                color = "\x1b[38;5;82m"
            elseif prefix == "[BadgeService]" then
                color = "\x1b[38;5;208m"
            elseif prefix == "[DataStoreService]" then
                color = "\x1b[38;5;160m"
            elseif prefix == "[MessagingService]" then
                color = "\x1b[38;5;124m"
            elseif prefix == "[RunService]" then
                color = "\x1b[38;5;28m"
            elseif prefix == "[NetworkClient]" then
                color = "\x1b[38;5;166m"
            elseif prefix == "[NetworkServer]" then
                color = "\x1b[38;5;136m"
            elseif prefix == "[MemoryStoreService]" then
                color = "\x1b[38;5;93m"
            elseif prefix == "[DataModel]" then
                color = "\x1b[38;5;51m"
            elseif logType == "Warning" then
                color = "\x1b[33;1m"
            elseif logType == "Error" then
                color = "\x1b[31;1m"
            end
            fullMessage = color .. fullMessage .. "\x1b[0m"
        end
    end

    print(string.rep("  ", callHierarchyDepth) .. fullMessage)
    table.insert(ZetaV3.logBuffer, fullMessage)
    if #ZetaV3.logBuffer > ZetaV3.config.maxLogLength then
        table.remove(ZetaV3.logBuffer, 1)
    end
    ZetaV3.logSignal:Fire(fullMessage, level, logType, context, scriptContext, err)
end

local function hook(object, hookType, name, originalFunc)
    if not object or ZetaV3.isBlacklisted(object) or type(originalFunc) ~= "function" then
        return originalFunc
    end
    local scriptContext = debug.info(2, "source") or "Unknown Script"
    return function(...)
        local context = debug.info(2, "n")
        local startTime = ZetaV3.config.logPerformance and os.clock() or nil
        local args = {...}
        local co = coroutine.running()
        local isCoroutine = co ~= nil
        local formattedArgs = formatArgs(args)
        local upvalues = {}
        local env = {}
        local info = debug.getinfo(originalFunc)
        local ret

        if ZetaV3.config.logUpvalues and info and info.nups > 0 then
            for i = 1, info.nups do
                local name, value = debug.getupvalue(originalFunc, i)
                if name then
                    upvalues[name] = formatValue(value, 1, {})
                end
            end
        end

        if ZetaV3.config.logEnv and info and info.func then
            local envTable = getfenv(info.func)
            if envTable then
                for k, v in pairs(envTable) do
                    env[k] = formatValue(v, 1, {})
                end
            end
        end

        local message =
            string.format(
            "[%s] %s called on %s with arguments: %s%s%s",
            hookType,
            name,
            object:GetFullName(),
            formattedArgs,
            ZetaV3.config.logUpvalues and " Upvalues: " .. formatTable(upvalues, 1, {}) or "",
            ZetaV3.config.logEnv and " Env: " .. formatTable(env, 1, {}) or ""
        )

        local result, err = xpcall(originalFunc, debug.traceback, object, unpack(args))

        if ZetaV3.config.captureReturnValues and result then
            ret = {select(2, result, ...)}
            message = message .. string.format(" Returns: %s", formatArgs(ret))
        end

        if not result then
            message = message .. string.format(" Error: %s", err)
            if ZetaV3.config.printStackTraces then
                message = message .. "\nStack Trace:\n" .. debug.traceback()
            end
            if ZetaV3.config.useCustomErrorHandling then
                log(message, 0, context, "Error", scriptContext, err)
            else
                if not ZetaV3.config.logErrorsAsWarnings then
                    error(message, 2)
                else
                    log(message, 0, context, "Error", scriptContext, err)
                end
            end
        else
            log(message, 1, context, nil, scriptContext)
        end

        if startTime then
            local endTime = os.clock()
            log(
                string.format("[Performance] %s.%s took %.4f seconds", object:GetFullName(), name, endTime - startTime),
                2,
                context,
                nil,
                scriptContext
            )
        end

        if ZetaV3.config.logCallHierarchy then
            callHierarchyDepth = math.min(callHierarchyDepth + 1, ZetaV3.config.maxCallHierarchyDepth)
            if callHierarchyDepth <= ZetaV3.config.maxCallHierarchyDepth then
                log(
                    string.format("[Call Hierarchy] Entering %s.%s", object:GetFullName(), name),
                    2,
                    context,
                    nil,
                    scriptContext
                )
            end
        end

        if isCoroutine and ZetaV3.config.logYields and coroutine.status(co) == "suspended" then
            log(string.format("[Yield] %s.%s yielded", object:GetFullName(), name), 2, context, nil, scriptContext)
        end

        if ZetaV3.config.logCallHierarchy then
            callHierarchyDepth = math.max(0, callHierarchyDepth - 1)
            if callHierarchyDepth <= ZetaV3.config.maxCallHierarchyDepth then
                log(
                    string.format("[Call Hierarchy] Exiting %s.%s", object:GetFullName(), name),
                    2,
                    context,
                    nil,
                    scriptContext
                )
            end
        end
        return ret and unpack(ret) or result
    end
end

function ZetaV3.isBlacklisted(object)
    local fullName = object and object:GetFullName() or ""
    if #ZetaV3.config.whitelist > 0 then
        for _, whitelistedName in ipairs(ZetaV3.config.whitelist) do
            if fullName:sub(1, #whitelistedName) == whitelistedName then
                return false
            end
        end
        return true
    end
    for _, blacklistedName in ipairs(ZetaV3.config.blacklist) do
        if fullName:sub(1, #blacklistedName) == blacklistedName then
            return true
        end
    end
    return false
end

local function hookObject(object)
    if not object or ZetaV3.isBlacklisted(object) then
        return
    end
    local scriptContext = debug.info(2, "source") or "Unknown Script"

    if ZetaV3.config.logDescendantAddedRemoved then
        object.DescendantAdded:Connect(
            function(child)
                log(
                    string.format("[DescendantAdded] %s added to %s", child:GetFullName(), object:GetFullName()),
                    2,
                    "Descendant Management",
                    nil,
                    scriptContext
                )
                hookObject(child)
            end
        )
        object.DescendantRemoving:Connect(
            function(child)
                log(
                    string.format("[DescendantRemoving] %s removed from %s", child:GetFullName(), object:GetFullName()),
                    2,
                    "Descendant Management",
                    nil,
                    scriptContext
                )
            end
        )
    end

    for eventName, _ in pairs(object:GetEvents()) do
        local originalEvent = object[eventName]
        if type(originalEvent) == "function" then
            object[eventName] = hook(object, "Event", eventName, originalEvent)
        end
    end

    local mt = getmetatable(object)
    if mt then
        if ZetaV3.config.logMetatableChanges then
            local oldMetatable = mt
            local metatableHook = {__metatable = function()
                    return oldMetatable
                end}
            if ZetaV3.config.logIndexChanges then
                metatableHook.__newindex = function(self, key, value)
                    local oldValue = rawget(self, key)
                    local indexMessage =
                        string.format(
                        "[Index] %s.%s changed from %s to %s",
                        object:GetFullName(),
                        key,
                        formatValue(oldValue, 1, {}),
                        formatValue(value, 1, {})
                    )
                    log(indexMessage, 1, "Metatable Change", nil, scriptContext)
                    rawset(self, key, value)
                end
                metatableHook.__index = function(t, k)
                    local result = rawget(t, k)
                    local indexMessage =
                        string.format(
                        "[Index] Accessing %s.%s, Value: %s",
                        object:GetFullName(),
                        k,
                        formatValue(result, 1, {}) or "nil"
                    )
                    log(indexMessage, 3, "Index Access", nil, scriptContext)
                    return result
                end
            end
            setmetatable(object, metatableHook)

            local mtHook = function(newMetatable)
                local message =
                    string.format(
                    "[Metatable] Metatable of %s changed from %s to %s",
                    object:GetFullName(),
                    formatValue(oldMetatable, 1, {}),
                    formatValue(newMetatable, 1, {})
                )
                log(message, 1, "Metatable Change", nil, scriptContext)
                oldMetatable = newMetatable
                return newMetatable
            end

            if type(mt.__metatable) == "function" then
                local oldMetaMeta = mt.__metatable
                mt.__metatable = function(...)
                    return mtHook(oldMetaMeta(...))
                end
            else
                mt.__metatable = mtHook
            end
        end

        if ZetaV3.config.hookMetamethods then
            for metaName, metaFunc in pairs(mt) do
                if
                    type(metaFunc) == "function" and metaName ~= "__index" and metaName ~= "__newindex" and
                        metaName ~= "__metatable"
                 then
                    mt[metaName] = hook(object, "Metamethod", metaName, metaFunc)
                end
            end
        end
    end
end

local function hookRemote(remote)
    local function hookThread(thread, name)
        local function hookWarning()
            local function hookGlobals()
                local function hookReplicatedFirstDescendants(parent)
                    local servicesToHook = {
                        Lighting,
                        SoundService,
                        LocalPlayer,
                        TweenService,
                        RunService,
                        CollectionService,
                        InsertService,
                        StarterGui,
                        GuiService,
                        UserInputService,
                        MarketplaceService,
                        TeleportService,
                        PathfindingService,
                        PhysicsService,
                        CoreGui,
                        BadgeService,
                        DataStoreService,
                        MessagingService,
                        DataModel,
                        NetworkClient,
                        NetworkServer,
                        MemoryStoreService,
                        Teams,
                        ServerStorage,
                        ServerScriptService,
                        StarterPack,
                        Stats,
                        ScriptService
                    }
                    for _, service in ipairs(servicesToHook) do
                        if service then
                            hookObject(service)
                        end
                    end

                    Players.PlayerAdded:Connect(
                        function(player)
                            if ZetaV3.config.logJoinsAndLeaves then
                                log(
                                    string.format("[JoinsAndLeaves] Player %s joined", player.Name),
                                    2,
                                    "Player Management",
                                    nil,
                                    debug.info(2, "source")
                                )
                            end
                            player.CharacterAdded:Connect(hookObject)
                            player.CharacterRemoving:Connect(
                                function(char)
                                    if char then
                                        log(
                                            string.format(
                                                "[JoinsAndLeaves] Character %s removed for player %s",
                                                char:GetFullName(),
                                                player.Name
                                            ),
                                            2,
                                            "Player Management",
                                            nil,
                                            debug.info(2, "source")
                                        )
                                    end
                                end
                            )
                            player.Removed:Connect(
                                function()
                                    log(
                                        string.format("[JoinsAndLeaves] Player %s left", player.Name),
                                        2,
                                        "Player Management",
                                        nil,
                                        debug.info(2, "source")
                                    )
                                end
                            )
                        end
                    )

                    if LocalPlayer.Character then
                        hookObject(LocalPlayer.Character)
                    end

                    if ZetaV3.config.hookGlobals then
                        hookGlobals()
                    end

                    if ZetaV3.config.logReplicatedFirstDescendants then
                        hookReplicatedFirstDescendants(ReplicatedFirst)
                    end

                    if ZetaV3.config.logThreads then
                        local oldCoroutineCreate = coroutine.create
                        local scriptContext = debug.info(2, "source") or "Unknown Script"
                        coroutine.create = function(func)
                            local co = oldCoroutineCreate(func)
                            hookThread(co, "Created Thread")
                            log(
                                string.format("[Thread] Created thread: %s", tostring(co)),
                                2,
                                "Thread Management",
                                nil,
                                scriptContext
                            )
                            return co
                        end

                        for _, thread in next, coroutine.listthreads() do
                            if thread ~= coroutine.running() then
                                hookThread(thread, "Existing Thread")
                            end
                        end
                    end

                    if ZetaV3.config.logRenderStepped then
                        RunService.RenderStepped:Connect(
                            function(deltaTime)
                                log(
                                    string.format("[RunService] RenderStepped: %s", deltaTime),
                                    4,
                                    "RunService",
                                    nil,
                                    debug.info(2, "source")
                                )
                            end
                        )
                    end

                    if ZetaV3.config.logHeartbeat then
                        RunService.Heartbeat:Connect(
                            function(deltaTime)
                                log(
                                    string.format("[RunService] Heartbeat: %s", deltaTime),
                                    4,
                                    "RunService",
                                    nil,
                                    debug.info(2, "source")
                                )
                            end
                        )
                    end

                    if ZetaV3.config.logStepped then
                        RunService.Stepped:Connect(
                            function(time, deltaTime)
                                log(
                                    string.format("[RunService] Stepped: Time: %s, DeltaTime: %s", time, deltaTime),
                                    4,
                                    "RunService",
                                    nil,
                                    debug.info(2, "source")
                                )
                            end
                        )
                    end

                    if ZetaV3.config.logNetworkOwnership then
                        game:GetService("Workspace").ChildAdded:Connect(
                            function(child)
                                if child:IsA("BasePart") then
                                    child:GetPropertyChangedSignal("NetworkOwnership"):Connect(
                                        function()
                                            log(
                                                string.format(
                                                    "[NetworkOwnership] %s NetworkOwnership changed to %s",
                                                    child:GetFullName(),
                                                    child.NetworkOwnership
                                                ),
                                                2,
                                                "Network Ownership",
                                                nil,
                                                debug.info(2, "source")
                                            )
                                        end
                                    )
                                end
                            end
                        )
                    end

                    if ZetaV3.config.logPhysicsSimulation then
                        RunService.Heartbeat:Connect(
                            function()
                                local stepSize = workspace.CurrentStep
                                local gravity = workspace.Gravity
                                local time = workspace.DistributedGameTime
                                local frameRate = Stats.FrameRate
                                local physicsReceiveKbps = Stats.PhysicsReceiveBytesPerSecond
                                local physicsSentKbps = Stats.PhysicsSentBytesPerSecond
                                log(
                                    string.format(
                                        "[Physics Simulation] StepSize: %s, Gravity: %s, Time: %s, FrameRate: %s, Physics Receive Kbps: %s, Physics Sent Kbps: %s",
                                        stepSize,
                                        gravity,
                                        time,
                                        frameRate,
                                        physicsReceiveKbps,
                                        physicsSentKbps
                                    ),
                                    4,
                                    "Physics Simulation",
                                    nil,
                                    debug.info(2, "source")
                                )
                            end
                        )
                    end

                    function ZetaV3.startMemoryLogging()
                        if ZetaV3.config.logMemoryUsage or ZetaV3.config.logMemoryDetails then
                            RunService.Heartbeat:Connect(
                                function()
                                    local currentTime = tick()
                                    if currentTime - memoryLogLastTime >= ZetaV3.config.memoryLogInterval then
                                        memoryLogLastTime = currentTime
                                        local memory = collectgarbage("count")
                                        log(
                                            string.format("[Memory] Total Memory Usage: %.2f KB", memory / 1024),
                                            2,
                                            "Memory Monitor",
                                            nil,
                                            debug.info(2, "source")
                                        )
                                        if ZetaV3.config.logMemoryDetails then
                                            for _, memoryType in ipairs({"Lua", "Physical", "Temporary"}) do
                                                local memoryByType = collectgarbage("count", memoryType)
                                                log(
                                                    string.format(
                                                        "[Memory] %s Memory: %.2f KB",
                                                        memoryType,
                                                        memoryByType / 1024
                                                    ),
                                                    3,
                                                    "Memory Monitor",
                                                    nil,
                                                    debug.info(2, "source")
                                                )
                                            end
                                        end
                                    end
                                end
                            )
                        end
                    end

                    function ZetaV3.startGCLogging()
                        if ZetaV3.config.logScriptExecution then
                            if ZetaV3.config.logInstanceCreation then
                                if ZetaV3.config.logSetRawMemory then
                                    if ZetaV3.config.logDataModelChanges then
                                        if ZetaV3.config.logStats then
                                            if ZetaV3.config.logUserInput then
                                                if ZetaV3.config.logTeleporting then
                                                    if ZetaV3.config.logPathfinding then
                                                        if ZetaV3.config.logPhysics then
                                                            if ZetaV3.config.logBadgeAwarding then
                                                                if ZetaV3.config.logDataStoreOperations then
                                                                    if ZetaV3.config.logMessagingService then
                                                                        if ZetaV3.config.logNetworkClient then
                                                                            local scriptContext =
                                                                                debug.info(2, "source") or
                                                                                "Unknown Script"
                                                                            NetworkClient.ConnectionCreated:Connect(
                                                                                function(connection)
                                                                                    log(
                                                                                        string.format(
                                                                                            "[NetworkClient] Connection Created: %s",
                                                                                            formatValue(
                                                                                                connection,
                                                                                                1,
                                                                                                {}
                                                                                            )
                                                                                        ),
                                                                                        2,
                                                                                        "Network Client",
                                                                                        nil,
                                                                                        scriptContext
                                                                                    )
                                                                                end
                                                                            )
                                                                            NetworkClient.ConnectionDestroyed:Connect(
                                                                                function(connection)
                                                                                    log(
                                                                                        string.format(
                                                                                            "[NetworkClient] Connection Destroyed: %s",
                                                                                            formatValue(
                                                                                                connection,
                                                                                                1,
                                                                                                {}
                                                                                            )
                                                                                        ),
                                                                                        2,
                                                                                        "Network Client",
                                                                                        nil,
                                                                                        scriptContext
                                                                                    )
                                                                                end
                                                                            )
                                                                        end

                                                                        if ZetaV3.config.logNetworkServer then
                                                                            local scriptContext =
                                                                                debug.info(2, "source") or
                                                                                "Unknown Script"
                                                                            if NetworkServer.IsActive then
                                                                                log(
                                                                                    "[NetworkServer] Server is Active",
                                                                                    2,
                                                                                    "Network Server",
                                                                                    nil,
                                                                                    scriptContext
                                                                                )
                                                                            else
                                                                                log(
                                                                                    "[NetworkServer] Server is Not Active",
                                                                                    2,
                                                                                    "Network Server",
                                                                                    nil,
                                                                                    scriptContext
                                                                                )
                                                                            end
                                                                            NetworkServer.ConnectionCreated:Connect(
                                                                                function(peer)
                                                                                    log(
                                                                                        string.format(
                                                                                            "[NetworkServer] Peer Connected: %s",
                                                                                            formatValue(peer, 1, {})
                                                                                        ),
                                                                                        2,
                                                                                        "Network Server",
                                                                                        nil,
                                                                                        scriptContext
                                                                                    )
                                                                                end
                                                                            )
                                                                            NetworkServer.ConnectionClosed:Connect(
                                                                                function(peer)
                                                                                    log(
                                                                                        string.format(
                                                                                            "[NetworkServer] Peer Disconnected: %s",
                                                                                            formatValue(peer, 1, {})
                                                                                        ),
                                                                                        2,
                                                                                        "Network Server",
                                                                                        nil,
                                                                                        scriptContext
                                                                                    )
                                                                                end
                                                                            )
                                                                        end

                                                                        if ZetaV3.config.logMemoryStoreService then
                                                                            local scriptContext =
                                                                                debug.info(2, "source") or
                                                                                "Unknown Script"
                                                                            local oldGetSortedMap =
                                                                                MemoryStoreService.GetSortedMap
                                                                            MemoryStoreService.GetSortedMap = function(
                                                                                ...)
                                                                                local sortedMap = oldGetSortedMap(...)
                                                                                log(
                                                                                    string.format(
                                                                                        "[MemoryStoreService] GetSortedMap called with: %s, Result: %s",
                                                                                        formatArgs({...}),
                                                                                        formatValue(sortedMap, 1, {})
                                                                                    ),
                                                                                    2,
                                                                                    "MemoryStore Service",
                                                                                    nil,
                                                                                    scriptContext
                                                                                )
                                                                                return sortedMap
                                                                            end
                                                                        end

                                                                        if ZetaV3.config.logDataModel then
                                                                            local scriptContext =
                                                                                debug.info(2, "source") or
                                                                                "Unknown Script"
                                                                            for propertyName, _ in pairs(
                                                                                DataModel:GetProperties()
                                                                            ) do
                                                                                DataModel:GetPropertyChangedSignal(
                                                                                    propertyName
                                                                                ):Connect(
                                                                                    function()
                                                                                        log(
                                                                                            string.format(
                                                                                                "[DataModel] DataModel.%s changed to: %s",
                                                                                                propertyName,
                                                                                                formatValue(
                                                                                                    DataModel[
                                                                                                        propertyName
                                                                                                    ],
                                                                                                    1,
                                                                                                    {}
                                                                                                )
                                                                                            ),
                                                                                            2,
                                                                                            "DataModel",
                                                                                            nil,
                                                                                            scriptContext
                                                                                        )
                                                                                    end
                                                                                )
                                                                            end
                                                                        end

                                                                        if ZetaV3.config.logScriptErrors then
                                                                            game.OnScriptError:Connect(
                                                                                function(message, stackTrace, script)
                                                                                    local scriptName =
                                                                                        script and script:GetFullName() or
                                                                                        "Unknown"
                                                                                    log(
                                                                                        string.format(
                                                                                            "[ScriptError] Error in %s: %s\nStack Trace: %s",
                                                                                            scriptName,
                                                                                            message,
                                                                                            stackTrace
                                                                                        ),
                                                                                        0,
                                                                                        "Global Error Handler",
                                                                                        "Error",
                                                                                        debug.info(2, "source")
                                                                                    )
                                                                                end
                                                                            )
                                                                        end

                                                                        ZetaV3.startMemoryLogging()
                                                                        ZetaV3.startGCLogging()

                                                                        log(
                                                                            ZetaV3.Version ..
                                                                                ": Advanced event/remote/property/global/metamethod spy active.",
                                                                            1,
                                                                            "Initialization",
                                                                            nil,
                                                                            "ZetaV3 Module"
                                                                        )

                                                                        return ZetaV3
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
