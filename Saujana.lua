-- Wait for the game to fully load (Crucial for auto-execution)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("========== AUTO FISH STARTING ==========")

-- ==================== CLEANUP PREVIOUS INSTANCE ====================
if getgenv()._AutoFishCleanup then
    pcall(getgenv()._AutoFishCleanup)
    print("[Auto Fish] Cleaned up previous script instance.")
end

-- ==================== ANTI-AFK MODULE ====================
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

if getgenv()._AntiAFKState then
    getgenv()._AntiAFKState.Active = false
end

local AntiAFKState = {
    Active = true,
    Interval = 120
}
getgenv()._AntiAFKState = AntiAFKState

local function sendAntiAFKPulse(sourceLabel)
    local success, err = pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end)

    if success then
        print(string.format("[Anti-AFK] %s pulse sent at %s", sourceLabel, os.date("%X")))
    else
        warn(string.format("[Anti-AFK] %s failed: %s", sourceLabel, tostring(err)))
    end
end

task.spawn(function()
    print(string.format("[Anti-AFK] Initialized: Proactive keep-alive active (every %d seconds).", AntiAFKState.Interval))

    while AntiAFKState.Active do
        task.wait(AntiAFKState.Interval)
        if not AntiAFKState.Active then break end
        sendAntiAFKPulse("Keep-alive")
    end

    print("[Anti-AFK] Worker thread safely exited.")
end)

-- ==================== ENVIRONMENT CONFIG ====================
local TARGET_PLACE_ID = 89346234653070
if game.PlaceId ~= TARGET_PLACE_ID then
    warn(string.format("[Auto Fish] PlaceId mismatch! Expected %d, got %d", TARGET_PLACE_ID, game.PlaceId))
end

-- Load Rayfield safely
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)
if not ok or not Rayfield then
    warn("[Auto Fish] Rayfield failed to load:", Rayfield)
    return
end

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- ==================== FISH CONFIG (FROM GAME) ====================
local DEFAULT_MINIGAME = {
    StartingProgress = 0.4,
    MinSecondsPerTap = 0.06,
    AutoSecondsPerTap = 0.1,
    AutoExtraTaps = 2,
    CastCooldown = 0.6,
}
local cachedFishMinigame = nil

local function getMinigameConfig()
    if cachedFishMinigame then
        return cachedFishMinigame
    end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local cfgFolder = shared and shared:FindFirstChild("Config")
    local fishCfgMod = cfgFolder and cfgFolder:FindFirstChild("FishConfig")
    if fishCfgMod then
        local okCfg, cfg = pcall(require, fishCfgMod)
        if okCfg and type(cfg) == "table" and type(cfg.Minigame) == "table" then
            cachedFishMinigame = cfg.Minigame
            return cachedFishMinigame
        end
    end
    return DEFAULT_MINIGAME
end

-- ==================== CACHED REFERENCES & STATE ====================
local CastRemote, ReelRemote, SellAll, SetAutoRemote, ServerRemote
local cachedFishingFrame, cachedInfoLabel, cachedTapBtn, cachedTapText, cachedBarFill, cachedAutoFishingButton

local connections = {}
local charConnections = {}
local gradientConn = nil
local barFillConn = nil
local barSizeConn = nil
local infoTextConn = nil
local fishingVisibleConn = nil
local guiDescendantConn = nil
local serverConn = nil
local heartbeatConn = nil

local enabledCast = true          -- Starts ON immediately at load
local enabledClick = false
local enabledReel = false
local enabledFastSafeReel = true  -- Starts ON immediately at load
local enabledColorReel = true     -- Starts ON immediately at load
local enabledSell = false
local enabledGameAutoCast = false -- Kept OFF by default for faster 0.06s/tap speed
local enabledAutoEquip = true
local lowPowerMode = false
local clickMethod = "Button Signals"
local reelTimingMode = "Auto-Tune (Best)"

local lastClickTime = 0
local lastSellTime = 0
local lastAutoBtnClick = 0
local lastAutoReelFire = 0
local lastAutoCheckTime = 0
local lastRemoteResolveTime = 0
local isSelling = false
local fishingOpenedAt = 0
local sawProgressBelowTarget = false

-- Live server-synced bite tracking
local biteActive = false
local biteAt = 0
local biteTaps = 13
local biteIsAuto = false
local biteHasReeled = false
local lastReelAttemptAt = 0
local safeReelAt = 0
local pingBuffer = 0.08
local autoTuneUseFullTaps = false
local autoTuneExtraBuffer = 0
local consecutiveCatches = 0

local clickDelay = 0.13
local reelAt = 5
local sellInterval = 20
local castPos = (typeof(vector) == "table" and vector.create) and vector.create(0, 0, 0) or Vector3.new(0, 0, 0)
local castPower = 1

-- Forward declarations for UI synchronization
local updateLoop
local autoCastToggleRef
local fastSafeReelToggleRef
local gameAutoCastToggleRef
local Window

local function clearCharConnections()
    for _, conn in ipairs(charConnections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(charConnections)
end

-- Register global cleanup so re-executing never creates duplicate loops/listeners
getgenv()._AutoFishCleanup = function()
    AntiAFKState.Active = false
    if lowPowerMode then
        lowPowerMode = false
        pcall(function()
            RunService:Set3dRenderingEnabled(true)
        end)
    end
    if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end
    if serverConn then serverConn:Disconnect() serverConn = nil end
    if gradientConn then gradientConn:Disconnect() gradientConn = nil end
    if barFillConn then barFillConn:Disconnect() barFillConn = nil end
    if barSizeConn then barSizeConn:Disconnect() barSizeConn = nil end
    if infoTextConn then infoTextConn:Disconnect() infoTextConn = nil end
    if fishingVisibleConn then fishingVisibleConn:Disconnect() fishingVisibleConn = nil end
    if guiDescendantConn then guiDescendantConn:Disconnect() guiDescendantConn = nil end
    clearCharConnections()
    for _, conn in ipairs(connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(connections)
end

-- Backup Idled listener in addition to the 120s timer
table.insert(connections, LocalPlayer.Idled:Connect(function()
    if AntiAFKState.Active then
        sendAntiAFKPulse("Idled backup")
    end
end))

-- ==================== SIGNAL & BUTTON HELPERS ====================
local function fireSignalList(signalObj, ...)
    if not signalObj then return false end
    local fired = false
    local args = table.pack(...)

    if getconnections then
        local okConns, conns = pcall(getconnections, signalObj)
        if okConns and conns and #conns > 0 then
            for _, conn in ipairs(conns) do
                local okFire = pcall(function()
                    conn:Fire(table.unpack(args, 1, args.n))
                end)
                if not okFire and args.n > 0 then
                    okFire = pcall(function()
                        conn:Fire()
                    end)
                end
                if okFire then
                    fired = true
                end
            end
        end
    end

    if not fired and firesignal then
        local okSig = pcall(function()
            firesignal(signalObj, table.unpack(args, 1, args.n))
        end)
        if not okSig and args.n > 0 then
            okSig = pcall(firesignal, signalObj)
        end
        if okSig then
            fired = true
        end
    end

    return fired
end

local function makeMockMouseInput(state, x, y)
    return {
        UserInputType = Enum.UserInputType.MouseButton1,
        UserInputState = state or Enum.UserInputState.Begin,
        KeyCode = Enum.KeyCode.Unknown,
        Position = Vector3.new(x or 0, y or 0, 0),
        Delta = Vector3.zero,
    }
end

local function ensureTapButtonVisible(btn)
    if not btn then return end
    pcall(function()
        if not btn.Visible then
            btn.Visible = true
        end
        if btn:IsA("GuiObject") and not btn.Active then
            btn.Active = true
        end
    end)
end

-- ==================== GAME AUTO CAST (BUTTON TOGGLE) ====================
local function isGradientGreen(uiGrad)
    if not uiGrad then return false end
    local keypoints = uiGrad.Color.Keypoints
    if #keypoints > 0 then
        local c = keypoints[1].Value
        return c.G > c.R
    end
    return false
end

local function isGameAutoCastOn()
    if not cachedAutoFishingButton then return false end
    local uiGrad = cachedAutoFishingButton:FindFirstChildOfClass("UIGradient")
    if uiGrad then
        return isGradientGreen(uiGrad)
    end
    local col = cachedAutoFishingButton:IsA("ImageButton") and cachedAutoFishingButton.ImageColor3 or cachedAutoFishingButton.BackgroundColor3
    return (col.G > 0.6 and col.G > col.R)
end

local function triggerImageButton(btn)
    if not btn then return end
    pcall(function()
        if btn.Name == "TapMobile" then
            ensureTapButtonVisible(btn)
        end

        local cx = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
        local cy = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
        local beginInput = makeMockMouseInput(Enum.UserInputState.Begin, cx, cy)
        local endInput = makeMockMouseInput(Enum.UserInputState.End, cx, cy)

        -- Fire all standard GuiButton & mobile tap signals
        fireSignalList(btn.MouseButton1Down, cx, cy)
        fireSignalList(btn.Activated, beginInput, 1)
        fireSignalList(btn.MouseButton1Click)
        fireSignalList(btn.MouseButton1Up, cx, cy)

        if btn:IsA("GuiButton") then
            pcall(function()
                fireSignalList(btn.TouchTap, { Vector2.new(cx, cy) })
            end)
        end

        if btn.Name == "TapMobile" then
            fireSignalList(btn.InputBegan, beginInput, false)
            fireSignalList(btn.InputEnded, endInput, false)
        end
    end)
end

local function setGameAutoCast(targetState)
    if cachedAutoFishingButton then
        local currentState = isGameAutoCastOn()
        if currentState ~= targetState then
            lastAutoBtnClick = os.clock()
            triggerImageButton(cachedAutoFishingButton)
        end
    elseif SetAutoRemote and SetAutoRemote.Parent then
        task.spawn(function()
            pcall(function()
                SetAutoRemote:InvokeServer(targetState)
            end)
        end)
    end
end

local function enforceGameAutoCast(uiGrad)
    if not enabledGameAutoCast then return end
    if not isGradientGreen(uiGrad) then
        local now = os.clock()
        if (now - lastAutoBtnClick) >= 0.5 then
            lastAutoBtnClick = now
            setGameAutoCast(true)
        end
    end
end

local function bindAutoGradient(autoBtn)
    if gradientConn then
        gradientConn:Disconnect()
        gradientConn = nil
    end
    if not autoBtn then return end

    local uiGrad = autoBtn:FindFirstChildOfClass("UIGradient")
    if uiGrad then
        gradientConn = uiGrad:GetPropertyChangedSignal("Color"):Connect(function()
            enforceGameAutoCast(uiGrad)
        end)
        enforceGameAutoCast(uiGrad)
    end
end

-- ==================== FAST SAFE REEL & REELING ====================
local function computeSafeWait(taps, isAuto)
    local mg = getMinigameConfig()
    local startProg = tonumber(mg.StartingProgress) or 0.4
    local perTap = isAuto and (tonumber(mg.AutoSecondsPerTap) or 0.1) or (tonumber(mg.MinSecondsPerTap) or 0.06)

    local useFull = false
    if reelTimingMode == "Safe (100%)" then
        useFull = true
    elseif reelTimingMode == "Aggressive (60%)" then
        useFull = false
    else
        -- "Auto-Tune (Best)"
        useFull = autoTuneUseFullTaps
    end

    local effectiveTaps
    if useFull then
        effectiveTaps = taps
    else
        effectiveTaps = math.max(1, math.ceil(taps * math.max(0.1, 1 - startProg)))
    end

    local extra = (reelTimingMode == "Auto-Tune (Best)") and autoTuneExtraBuffer or 0
    return (effectiveTaps * perTap) + pingBuffer + extra
end

local function recalculateSafeReelTime()
    if biteActive then
        safeReelAt = biteAt + computeSafeWait(biteTaps, biteIsAuto)
    end
end

local function fireReel()
    if not ReelRemote or not ReelRemote.Parent then return end
    local now = os.clock()
    if (now - lastAutoReelFire) < 0.15 then return end
    lastAutoReelFire = now
    lastReelAttemptAt = now
    biteHasReeled = true
    pcall(function()
        ReelRemote:FireServer(true)
    end)
end

local function isSafeToReelNow()
    if enabledFastSafeReel and biteActive and os.clock() < safeReelAt then
        return false
    end
    return true
end

local function getInfoProgress()
    if not cachedInfoLabel then return nil, nil end
    local currentStr, maxStr = string.match(cachedInfoLabel.Text, "(%d+)%s*/%s*(%d+)")
    if currentStr then
        return tonumber(currentStr), tonumber(maxStr)
    end
    return nil, nil
end

local function shouldAutoReel()
    if not enabledReel or not ReelRemote or not ReelRemote.Parent then return false end
    if not isSafeToReelNow() then return false end
    if biteHasReeled and biteActive then return false end

    if serverConn and not biteActive then
        return false
    end

    if not cachedFishingFrame or not cachedFishingFrame.Visible then return false end
    if not biteActive and cachedTapText and cachedTapText.Text == "CAST" then return false end

    local current = getInfoProgress()
    if current ~= nil then
        if current < reelAt then
            sawProgressBelowTarget = true
            return false
        end
        if sawProgressBelowTarget or (os.clock() - fishingOpenedAt) >= 0.25 then
            return true
        end
        return false
    end

    -- Fallback to Bar.Fill only when Info label has no numeric "X / Y" text
    if cachedBarFill then
        local targetScale = reelAt / 13
        local scaleX = cachedBarFill.Size.X.Scale
        if scaleX < targetScale then
            sawProgressBelowTarget = true
            return false
        end
        if sawProgressBelowTarget then
            return true
        end
    end

    return false
end

local function onServerEvent(eventName, data)
    if eventName == "Bite" and type(data) == "table" then
        local now = os.clock()
        biteActive = true
        biteAt = now
        biteTaps = tonumber(data.taps) or 13
        biteIsAuto = (data.auto == true)
        biteHasReeled = false
        lastReelAttemptAt = 0
        fishingOpenedAt = now
        sawProgressBelowTarget = false
        recalculateSafeReelTime()
    elseif eventName == "Caught" then
        biteActive = false
        biteHasReeled = true
        consecutiveCatches += 1
    elseif eventName == "Failed" then
        biteActive = false
        biteHasReeled = true
        local reason = type(data) == "table" and data.reason or nil
        if reason == "Invalid" then
            consecutiveCatches = 0
            if reelTimingMode == "Auto-Tune (Best)" then
                if not autoTuneUseFullTaps then
                    autoTuneUseFullTaps = true
                    warn("[Auto Fish] Auto-Tune: Upgraded to 100% taps after 'Invalid' to prevent fails.")
                    if Window then
                        task.defer(function()
                            Window:Notify({
                                title = "Auto-Tune Adjusted",
                                content = "Switched to 100% tap timing for 0 fails",
                                duration = 3,
                            })
                        end)
                    end
                elseif autoTuneExtraBuffer < 0.30 then
                    autoTuneExtraBuffer = math.min(0.30, autoTuneExtraBuffer + 0.04)
                    warn(string.format("[Auto Fish] Auto-Tune: Added +0.04s buffer (now +%.2fs).", autoTuneExtraBuffer))
                end
            end
        end
    elseif eventName == "CastFail" and type(data) == "table" and data.reason ~= "Busy" then
        if not biteActive then
            biteHasReeled = false
        end
    end
end

local function bindServerRemote(remote)
    if serverConn then
        serverConn:Disconnect()
        serverConn = nil
    end
    ServerRemote = remote
    if not remote then return end
    serverConn = remote.OnClientEvent:Connect(onServerEvent)
end

local function bindFishingFrame(fishingFrame)
    if fishingVisibleConn then
        fishingVisibleConn:Disconnect()
        fishingVisibleConn = nil
    end
    cachedFishingFrame = fishingFrame
    if not fishingFrame then return end

    if fishingFrame.Visible then
        fishingOpenedAt = os.clock()
        sawProgressBelowTarget = false
    end

    fishingVisibleConn = fishingFrame:GetPropertyChangedSignal("Visible"):Connect(function()
        if fishingFrame.Visible then
            fishingOpenedAt = os.clock()
            sawProgressBelowTarget = false
        else
            sawProgressBelowTarget = false
        end
    end)
end

local function bindInfoLabel(infoLabel)
    if infoTextConn then
        infoTextConn:Disconnect()
        infoTextConn = nil
    end
    cachedInfoLabel = infoLabel
    if not infoLabel then return end

    infoTextConn = infoLabel:GetPropertyChangedSignal("Text"):Connect(function()
        if shouldAutoReel() then
            fireReel()
        end
    end)
end

local function bindBarFill(bar)
    if barFillConn then
        barFillConn:Disconnect()
        barFillConn = nil
    end
    if barSizeConn then
        barSizeConn:Disconnect()
        barSizeConn = nil
    end
    if not bar then return end

    local fill = bar:FindFirstChild("Fill")
    cachedBarFill = fill
    if fill then
        -- 1. Color Reel listener (fixed RGB 0-255 scaling, respects Fast Safe Reel timer)
        barFillConn = fill:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            if not enabledColorReel or not ReelRemote then return end
            if not isSafeToReelNow() then return end
            if serverConn and not biteActive then return end
            if cachedFishingFrame and not cachedFishingFrame.Visible then return end
            if not biteActive and cachedTapText and cachedTapText.Text == "CAST" then return end

            local col = fill.BackgroundColor3
            local isGreen = (col.G > 0.7 and col.G > col.R and col.G > col.B) or
                            (math.abs(col.R * 255 - 100) < 30 and (col.G * 255) > 220 and math.abs(col.B * 255 - 100) < 30)

            if isGreen then
                fireReel()
            end
        end)

        -- 2. Progress Auto Reel listener (synced with Reel At slider)
        barSizeConn = fill:GetPropertyChangedSignal("Size"):Connect(function()
            if shouldAutoReel() then
                fireReel()
            end
        end)
    end
end

-- ==================== UI CACHING ====================
local function clearUICache()
    cachedFishingFrame = nil
    cachedInfoLabel = nil
    cachedTapBtn = nil
    cachedTapText = nil
    cachedBarFill = nil
    cachedAutoFishingButton = nil
    if gradientConn then gradientConn:Disconnect() gradientConn = nil end
    if barFillConn then barFillConn:Disconnect() barFillConn = nil end
    if barSizeConn then barSizeConn:Disconnect() barSizeConn = nil end
    if infoTextConn then infoTextConn:Disconnect() infoTextConn = nil end
    if fishingVisibleConn then fishingVisibleConn:Disconnect() fishingVisibleConn = nil end
    if guiDescendantConn then guiDescendantConn:Disconnect() guiDescendantConn = nil end
end

local function cacheUI()
    if not PlayerGui then return end
    local gui = PlayerGui:FindFirstChild("FishingGui")
    if gui then
        bindFishingFrame(gui:FindFirstChild("Fishing", true))
        cachedTapBtn = gui:FindFirstChild("TapMobile") or gui:FindFirstChild("TapMobile", true)
        cachedTapText = cachedTapBtn and cachedTapBtn:FindFirstChild("TAP")
        cachedAutoFishingButton = gui:FindFirstChild("AutoFishingButton", true)

        if cachedFishingFrame then
            bindInfoLabel(cachedFishingFrame:FindFirstChild("Info", true))
            bindBarFill(cachedFishingFrame:FindFirstChild("Bar", true))
        end
        if cachedAutoFishingButton then
            bindAutoGradient(cachedAutoFishingButton)
        end

        if guiDescendantConn then
            guiDescendantConn:Disconnect()
        end
        guiDescendantConn = gui.DescendantAdded:Connect(function(desc)
            if desc.Name == "AutoFishingButton" then
                cachedAutoFishingButton = desc
                bindAutoGradient(desc)
                if enabledGameAutoCast then
                    setGameAutoCast(true)
                end
            elseif desc.Name == "Bar" and desc.Parent and desc.Parent.Name == "Fishing" then
                bindFishingFrame(desc.Parent)
                bindBarFill(desc)
            elseif desc.Name == "Info" and desc.Parent and desc.Parent.Name == "Fishing" then
                bindFishingFrame(desc.Parent)
                bindInfoLabel(desc)
            elseif desc.Name == "TapMobile" then
                cachedTapBtn = desc
                cachedTapText = desc:FindFirstChild("TAP")
            elseif desc.Name == "TAP" and desc.Parent and desc.Parent.Name == "TapMobile" then
                cachedTapText = desc
            end
        end)
    else
        clearUICache()
    end
end

if PlayerGui then
    cacheUI()
    table.insert(connections, PlayerGui.ChildAdded:Connect(function(child)
        if child.Name == "FishingGui" then
            task.wait()
            cacheUI()
        end
    end))
    table.insert(connections, PlayerGui.ChildRemoved:Connect(function(child)
        if child.Name == "FishingGui" then
            clearUICache()
        end
    end))
end

-- ==================== REMOTE RESOLUTION ====================
local function isRemoteValid(remote)
    return remote ~= nil and remote.Parent ~= nil
end

local function resolveRemotes()
    local fishRemotes = ReplicatedStorage:FindFirstChild("FishRemotes")
    if not fishRemotes then return false end

    if not isRemoteValid(CastRemote) then CastRemote = fishRemotes:FindFirstChild("Cast") end
    if not isRemoteValid(ReelRemote) then ReelRemote = fishRemotes:FindFirstChild("Reel") end
    if not isRemoteValid(SellAll) then SellAll = fishRemotes:FindFirstChild("SellAll") end
    if not isRemoteValid(SetAutoRemote) then SetAutoRemote = fishRemotes:FindFirstChild("SetAuto") end

    if not isRemoteValid(ServerRemote) then
        local srv = fishRemotes:FindFirstChild("Server")
        if srv then
            bindServerRemote(srv)
        end
    end

    return isRemoteValid(CastRemote)
end

task.spawn(function()
    local attempts = 0
    while not resolveRemotes() do
        attempts += 1
        task.wait(attempts <= 25 and 0.25 or 1)
    end
    print("[Auto Fish] CastRemote connected.")

    -- Resolve FishConfig & secondary remotes in background without blocking Auto Cast
    getMinigameConfig()
    task.spawn(function()
        for _ = 1, 20 do
            resolveRemotes()
            getMinigameConfig()
            if isRemoteValid(ReelRemote) and isRemoteValid(SellAll) and isRemoteValid(SetAutoRemote) and isRemoteValid(ServerRemote) then
                break
            end
            task.wait(1)
        end
    end)
end)

-- ==================== KATANA AUTO EQUIP ====================
local function equipKatana()
    if not enabledAutoEquip then return end
    local character = LocalPlayer.Character
    if not character then return end
    if character:FindFirstChild("Katana") then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local katanaTool = backpack:FindFirstChild("Katana")
        if katanaTool then
            pcall(function()
                humanoid:EquipTool(katanaTool)
            end)
        end
    end
end

local function bindCharacterEvents(character)
    if not character then return end
    clearCharConnections()
    biteActive = false
    biteHasReeled = false
    task.wait(1)
    equipKatana()

    -- Re-verify Game Auto Cast after respawn
    if enabledGameAutoCast then
        setGameAutoCast(true)
    end

    table.insert(charConnections, character.ChildRemoved:Connect(function(child)
        if child.Name == "Katana" then
            task.defer(equipKatana)
        end
    end))

    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
    if backpack then
        table.insert(charConnections, backpack.ChildAdded:Connect(function(child)
            if child.Name == "Katana" then
                task.defer(equipKatana)
            end
        end))
    end
end

if LocalPlayer.Character then
    task.spawn(bindCharacterEvents, LocalPlayer.Character)
end
table.insert(connections, LocalPlayer.CharacterAdded:Connect(bindCharacterEvents))

-- ==================== OPTIMIZED CLICK ACTIONS ====================
local function triggerInputSignals()
    -- 1. Fire LocalPlayer Mouse signals
    local mouse = LocalPlayer:GetMouse()
    if mouse then
        fireSignalList(mouse.Button1Down)
        fireSignalList(mouse.Button1Up)
    end

    -- 2. Fire only game-script UserInputService.InputBegan / InputEnded connections
    if getconnections then
        local beginInput = makeMockMouseInput(Enum.UserInputState.Begin, 0, 0)
        local endInput = makeMockMouseInput(Enum.UserInputState.End, 0, 0)

        local function fireGameInputConns(sig, inputObj)
            local okConns, conns = pcall(getconnections, sig)
            if not okConns or not conns then return end
            for _, conn in ipairs(conns) do
                local fn = conn.Function
                if fn then
                    local okInfo, src = pcall(debug.info, fn, "s")
                    if okInfo and type(src) == "string" and (
                        string.find(src, "Players%.") or
                        string.find(src, "Replicated") or
                        string.find(src, "Starter")
                    ) then
                        pcall(function()
                            conn:Fire(inputObj, false)
                        end)
                    end
                end
            end
        end

        fireGameInputConns(UserInputService.InputBegan, beginInput)
        fireGameInputConns(UserInputService.InputEnded, endInput)
    end
end

local function doClick()
    if clickMethod == "Input Signals" then
        triggerInputSignals()
    else
        -- "Button Signals" (Default)
        if not cachedTapBtn and PlayerGui then
            local gui = PlayerGui:FindFirstChild("FishingGui")
            if gui then
                cachedTapBtn = gui:FindFirstChild("TapMobile") or gui:FindFirstChild("TapMobile", true)
                cachedTapText = cachedTapBtn and cachedTapBtn:FindFirstChild("TAP")
            end
        end
        if not cachedTapBtn then return end
        triggerImageButton(cachedTapBtn)
    end
end

-- ==================== MAIN HEARTBEAT LOOP ====================
local function mainLoop()
    local now = os.clock()

    -- Background remote recovery if any remote detaches overnight
    if (now - lastRemoteResolveTime) >= 2 then
        if not isRemoteValid(CastRemote) or not isRemoteValid(ReelRemote) or not isRemoteValid(SellAll) or not isRemoteValid(SetAutoRemote) or not isRemoteValid(ServerRemote) then
            lastRemoteResolveTime = now
            resolveRemotes()
        end
    end

    -- Safety timeout for biteActive in case a packet was missed during lag
    if biteActive and (now - biteAt) >= 26 then
        biteActive = false
        biteHasReeled = false
    end

    -- 1. Raw Heartbeat Cast (skips during active bite minigame)
    if enabledCast and isRemoteValid(CastRemote) then
        if not biteActive then
            pcall(CastRemote.FireServer, CastRemote, castPos, castPower)
        end
    end

    -- 2. Auto Clicker
    if enabledClick then
        local canClick = false
        if serverConn then
            canClick = biteActive and not biteHasReeled
        else
            canClick = cachedFishingFrame and cachedFishingFrame.Visible
        end
        if canClick and (now - lastClickTime) >= clickDelay then
            lastClickTime = now
            doClick()
        end
    end

    -- 3. Fast Safe Reel (Server-synced earliest safe timing)
    if enabledFastSafeReel and biteActive and isRemoteValid(ReelRemote) then
        if now >= safeReelAt then
            if not biteHasReeled or (now - lastReelAttemptAt) >= 1.5 then
                fireReel()
            end
        end
    end

    -- 4. Auto Reel (UI fallback / progress threshold)
    if shouldAutoReel() then
        fireReel()
    end

    -- 5. Auto Sell (with overlap lock against server lag spikes)
    if enabledSell and not isSelling and isRemoteValid(SellAll) then
        if (now - lastSellTime) >= sellInterval then
            lastSellTime = now
            isSelling = true
            task.spawn(function()
                pcall(SellAll.InvokeServer, SellAll)
                isSelling = false
            end)
        end
    end

    -- 6. Periodic Game Auto Cast watchdog (every 4s)
    if enabledGameAutoCast and (now - lastAutoCheckTime) >= 4 then
        lastAutoCheckTime = now
        if cachedAutoFishingButton and not isGameAutoCastOn() then
            setGameAutoCast(true)
        end
    end
end

function updateLoop()
    local shouldRun = (enabledCast or enabledClick or enabledReel or enabledFastSafeReel or enabledSell or enabledGameAutoCast)
    if shouldRun then
        if not heartbeatConn then
            lastClickTime = 0
            lastSellTime = 0
            lastAutoCheckTime = 0
            heartbeatConn = RunService.Heartbeat:Connect(mainLoop)
        end
    else
        if heartbeatConn then
            heartbeatConn:Disconnect()
            heartbeatConn = nil
        end
    end
end

-- ==================== UI ORGANIZATION (TABS) ====================
Window = Rayfield:CreateWindow({
    name = "Auto Fish",
    subtitle = "Place " .. tostring(game.PlaceId),
    theme = "cobalt",
    configuration = {
        autoSave = true,
        autoLoad = false,
        fileName = "AutoFishConfig",
    },
})

-- TAB 1: AUTOMATION
local AutomationTab = Window:CreateTab({ name = "Automation" })

AutomationTab:CreateSection({ name = "Casting & Toggles" })

autoCastToggleRef = AutomationTab:CreateToggle({
    name = "Auto Cast",
    description = "Casts continuously on every Heartbeat frame",
    flag = "AutoCast",
    value = true,
    callback = function(value)
        enabledCast = value
        updateLoop()
    end,
})

gameAutoCastToggleRef = AutomationTab:CreateToggle({
    name = "Game Auto Cast",
    description = "Optional built-in auto cast (keep OFF for faster 0.06s/tap speed)",
    flag = "GameAutoCast",
    value = false,
    callback = function(value)
        enabledGameAutoCast = value
        updateLoop()
        setGameAutoCast(value)
    end,
})

AutomationTab:CreateSection({ name = "Reeling & Clicking" })

fastSafeReelToggleRef = AutomationTab:CreateToggle({
    name = "Fast Safe Reel",
    description = "Reels at earliest safe server time from FishConfig (Auto-Tunes on fails)",
    flag = "FastSafeReel",
    value = true,
    callback = function(value)
        enabledFastSafeReel = value
        updateLoop()
    end,
})

AutomationTab:CreateToggle({
    name = "Auto Clicker",
    description = "Clicks automatically during active fishing bites",
    flag = "AutoClicker",
    value = false,
    callback = function(value)
        enabledClick = value
        updateLoop()
    end,
})

AutomationTab:CreateToggle({
    name = "Auto Reel",
    description = "Reels when progress reaches the Reel At target",
    flag = "AutoReel",
    value = false,
    callback = function(value)
        enabledReel = value
        updateLoop()
    end,
})

AutomationTab:CreateToggle({
    name = "Color Reel",
    description = "Reels when the fill bar turns green (protected by Fast Safe Reel)",
    flag = "ColorReel",
    value = true,
    callback = function(value)
        enabledColorReel = value
    end,
})

AutomationTab:CreateSection({ name = "Equipment & Economy" })

AutomationTab:CreateToggle({
    name = "Auto Equip Katana",
    description = "Automatically equips Katana when unequipped",
    flag = "AutoEquipKatana",
    value = true,
    callback = function(value)
        enabledAutoEquip = value
        if value then equipKatana() end
    end,
})

AutomationTab:CreateToggle({
    name = "Auto Sell",
    description = "Sells all fish on an interval",
    flag = "AutoSell",
    value = false,
    callback = function(value)
        enabledSell = value
        if value then lastSellTime = 0 end
        updateLoop()
    end,
})

-- TAB 2: SETTINGS & TIMING
local SettingsTab = Window:CreateTab({ name = "Settings" })

SettingsTab:CreateSection({ name = "Click Methods" })

SettingsTab:CreateDropdown({
    name = "Click Method",
    description = "Button Signals targets TapMobile • Input Signals uses mouse/input events",
    options = { "Button Signals", "Input Signals" },
    value = "Button Signals",
    flag = "ClickMethod",
    callback = function(selected)
        if type(selected) == "table" then
            selected = selected[1]
        end
        if selected == "Input Signals" then
            clickMethod = "Input Signals"
        else
            clickMethod = "Button Signals"
        end
    end,
})

SettingsTab:CreateSection({ name = "Fast Safe Reel Tuning" })

SettingsTab:CreateDropdown({
    name = "Fast Reel Mode",
    description = "Auto-Tune starts at 60% taps & locks to 100% if an Invalid happens",
    options = { "Auto-Tune (Best)", "Aggressive (60%)", "Safe (100%)" },
    value = "Auto-Tune (Best)",
    flag = "FastReelMode",
    callback = function(selected)
        if type(selected) == "table" then
            selected = selected[1]
        end
        if selected == "Aggressive (60%)" or selected == "Safe (100%)" then
            reelTimingMode = selected
        else
            reelTimingMode = "Auto-Tune (Best)"
        end
        recalculateSafeReelTime()
    end,
})

SettingsTab:CreateSlider({
    name = "Reel Ping Buffer",
    range = { 0.02, 0.50 },
    increment = 0.01,
    value = 0.08,
    suffix = "s",
    flag = "ReelPingBuffer",
    callback = function(value)
        pingBuffer = value
        recalculateSafeReelTime()
    end,
})

SettingsTab:CreateSection({ name = "Timing & Thresholds" })

SettingsTab:CreateSlider({
    name = "Clicker Speed",
    range = { 0.03, 0.25 },
    increment = 0.01,
    value = 0.13,
    suffix = "s",
    flag = "ClickerSpeed",
    callback = function(value)
        clickDelay = value
    end,
})

SettingsTab:CreateSlider({
    name = "Reel At",
    range = { 1, 13 },
    increment = 1,
    value = 5,
    suffix = "/13",
    flag = "ReelAt",
    callback = function(value)
        reelAt = value
    end,
})

SettingsTab:CreateSlider({
    name = "Sell Interval",
    range = { 3, 30 },
    increment = 1,
    value = 20,
    suffix = "s",
    flag = "SellInterval",
    callback = function(value)
        sellInterval = value
    end,
})

SettingsTab:CreateSection({ name = "Overnight / Mobile" })

SettingsTab:CreateToggle({
    name = "Battery Saver (No 3D Render)",
    description = "Disables 3D world rendering to reduce heat/battery overnight",
    flag = "BatterySaver",
    value = false,
    callback = function(value)
        lowPowerMode = value
        pcall(function()
            RunService:Set3dRenderingEnabled(not value)
        end)
    end,
})

-- ==================== STARTUP SEQUENCE ====================
enabledCast = true
enabledFastSafeReel = true
enabledGameAutoCast = false
updateLoop()

if autoCastToggleRef and autoCastToggleRef.Set then
    autoCastToggleRef:Set(true)
end
if fastSafeReelToggleRef and fastSafeReelToggleRef.Set then
    fastSafeReelToggleRef:Set(true)
end
if gameAutoCastToggleRef and gameAutoCastToggleRef.Set then
    gameAutoCastToggleRef:Set(false)
end

-- Ensure server-restored Game Auto Cast stays OFF at startup for faster 0.06s/tap speed
task.defer(function()
    if not enabledGameAutoCast and cachedAutoFishingButton and isGameAutoCastOn() then
        setGameAutoCast(false)
    end
end)

print("[Auto Fish] Auto Cast & Fast Safe Reel (Auto-Tune) active at load.")

task.defer(function()
    Window:Notify({
        title = "Auto Fish Loaded",
        content = "Auto Cast & Fast Safe Reel (Auto-Tune) Active",
        duration = 4,
    })
end)
