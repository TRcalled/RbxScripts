local SCRIPT_VERSION = "2.2.2"

-- Wait for the game to fully load (Crucial for auto-execution)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print(string.format("========== AUTO FISH v%s STARTING ==========", SCRIPT_VERSION))

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
local ALLOWED_PLACE_IDS = {
    [89346234653070] = true,
}

if not ALLOWED_PLACE_IDS[game.PlaceId] then
    local rs = game:GetService("ReplicatedStorage")
    if not rs:WaitForChild("FishRemotes", 2) then
        AntiAFKState.Active = false
        warn(string.format("[Auto Fish] Unsupported game (PlaceId %d, no FishRemotes) — aborting load.", game.PlaceId))
        return
    else
        warn(string.format("[Auto Fish] Different PlaceId (%d) detected — FishRemotes found, continuing load.", game.PlaceId))
    end
end

-- Load Rayfield safely
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)
if not ok or not Rayfield then
    AntiAFKState.Active = false
    warn("[Auto Fish] Rayfield failed to load:", Rayfield)
    return
end

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- ==================== GAME CONFIGS ====================
local DEFAULT_MINIGAME = {
    StartingProgress = 0.4,
    MinSecondsPerTap = 0.06,
    AutoSecondsPerTap = 0.1,
    AutoExtraTaps = 2,
    CastCooldown = 0.6,
}

local DEFAULT_FISH_XP = {
    Common = 5,
    Uncommon = 8,
    Rare = 15,
    Epic = 30,
    Mythic = 120,
    Secret = 600,
    Supremacy = 3000,
    Primordial = 8000,
}

local RARITY_COLORS = {
    Mythic = 0xFF6048,
    Secret = 0xFFD65A,
    Supremacy = 0xFF48D6,
    Primordial = 0xAAFF00,
    Report = 0x3B82F6,
    Alert = 0xEF4444,
    Resume = 0x22C55E,
}

local NOTIFY_CATCH_RARITIES = {
    Mythic = true,
    Secret = true,
    Supremacy = true,
    Primordial = true,
}

local cachedConfigs = {}
local cachedSkinDisplaySet = nil

local function getConfigModule(name)
    if cachedConfigs[name] then
        return cachedConfigs[name]
    end
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local cfgFolder = shared and shared:FindFirstChild("Config")
    local mod = cfgFolder and cfgFolder:FindFirstChild(name)
    if mod then
        local okCfg, tbl = pcall(require, mod)
        if okCfg and type(tbl) == "table" then
            cachedConfigs[name] = tbl
            return tbl
        end
    end
    return nil
end

local function getFishConfig() return getConfigModule("FishConfig") end
local function getRodConfig() return getConfigModule("RodConfig") end
local function getBaitConfig() return getConfigModule("BaitConfig") end
local function getRodEnhanceConfig() return getConfigModule("RodEnhanceConfig") end
local function getLevelConfig() return getConfigModule("LevelConfig") end
local function getCelestraConfig() return getConfigModule("CelestraConfig") end
local function getThalvyraConfig() return getConfigModule("ThalvyraConfig") end
local function getSoreKrakenConfig() return getConfigModule("SoreKrakenConfig") end

local function getMinigameConfig()
    local fc = getFishConfig()
    if fc and type(fc.Minigame) == "table" then
        return fc.Minigame
    end
    return DEFAULT_MINIGAME
end

local function getRodSkinConfig()
    local rsc = getConfigModule("RodSkinConfig")
    if rsc and not cachedSkinDisplaySet and type(rsc.Skins) == "table" then
        cachedSkinDisplaySet = {}
        for skinKey, skinInfo in pairs(rsc.Skins) do
            cachedSkinDisplaySet[skinKey] = true
            if type(skinInfo) == "table" and type(skinInfo.Display) == "string" then
                cachedSkinDisplaySet[skinInfo.Display] = true
            end
        end
    end
    return rsc
end

-- ==================== WEBHOOK URL HELPERS & ENV READ ====================
local function trimString(s)
    if type(s) ~= "string" then return "" end
    return string.match(s, "^%s*(.-)%s*$") or ""
end

local function isValidWebhookUrl(url)
    local clean = trimString(url)
    return string.match(clean, "^https?://[%w%.%-]+/api/webhooks/") ~= nil
end

local envWebhookRaw = (type(getgenv) == "function" and getgenv().AutoFishWebhook) or ""
local envWebhookUrl = trimString(envWebhookRaw)
local envWebhookValid = isValidWebhookUrl(envWebhookUrl)

-- ==================== CACHED REFERENCES & STATE ====================
local CastRemote, ReelRemote, SellAll, SetAutoRemote, GetStateRemote, ServerRemote
local cachedFishingFrame, cachedInfoLabel, cachedTapBtn, cachedTapText, cachedBarFill, cachedAutoFishingButton

local connections = {}
local charConnections = {}
local levelUpConns = {}
local gradientConn = nil
local barFillConn = nil
local barSizeConn = nil
local infoTextConn = nil
local fishingVisibleConn = nil
local guiDescendantConn = nil
local serverConn = nil
local heartbeatConn = nil

local enabledCast = true              -- Starts ON immediately at load
local enabledClick = false
local enabledReel = false
local enabledFastSafeReel = true      -- Starts ON immediately at load
local enabledColorReel = false        -- Starts OFF at launch
local enabledSell = false
local enabledGameAutoCast = false     -- Kept OFF by default for faster 0.06s/tap speed
local enabledAutoEquip = true
local enabledAutoCloseLevelUp = true  -- Auto-closes LevelUpUI popup
local enabledPauseNoWater = true      -- Pauses casting when away from water
local enabledSmartWaterAim = false    -- Optional LookVector aim toward nearest water
local lowPowerMode = false
local clickMethod = "Button Signals"
local reelTimingMode = "Auto-Tune (Best)"
local autoTunePingBuffer = true

local detectedEquippedBait = nil
local lastBaitRefreshAt = 0

local lastClickTime = 0
local lastSellTime = 0
local lastCastSentAt = 0
local lastAutoBtnClick = 0
local lastAutoReelFire = 0
local lastAutoCheckTime = 0
local lastRemoteResolveTime = 0
local lastServerActivityAt = os.clock()
local lastLevelUpClose = 0
local lastUiRodClickAt = 0
local lastRodCheckAt = 0
local lastWaterCheckAt = 0
local isSelling = false
local fishingOpenedAt = 0
local sawProgressBelowTarget = false

-- Water proximity tracking
local isNearWater = true
local isFarmPausedNoWater = false
local cachedWaterDir = nil

-- Live server-synced cast & bite tracking
local waitingForBite = false
local waitingSince = 0
local biteActive = false
local biteAt = 0
local biteTaps = 13
local biteIsAuto = false
local biteHasReeled = false
local lastReelAttemptAt = 0
local safeReelAt = 0
local pingBuffer = 0.08
local autoTuneUseFullTaps = false
local autoTuneFloorBuffer = 0.03
local lastBufferAdjustAt = 0
local consecutiveCatches = 0
local consecutiveInvalidFails = 0
local isUpdatingPingSlider = false

local clickDelay = 0.13
local reelAt = 5
local sellInterval = 20
local castPos = (typeof(vector) == "table" and vector.create) and vector.create(0, 0, 0) or Vector3.new(0, 0, 0)
local castPower = 1

-- Discord Webhook state (auto-reads getgenv().AutoFishWebhook if valid)
local webhookState = {
    Active = true,
    Enabled = envWebhookValid,
    Url = envWebhookValid and envWebhookUrl or "",
    NotifyRareCatches = true,
    PeriodicReport = true,
    AlertOnIssues = true,
    IntervalMinutes = 15,
    LastReportAt = os.clock(),
    LastAlertAt = 0,
    Queue = {},
    SentCount = 0,
    FailedCount = 0,
}

-- Rate Monitor state
local monitorState = {
    Active = true,
    SessionStart = os.clock(),
    TotalCaught = 0,
    TotalFailed = 0,
    InvalidFails = 0,
    SessionFishXp = 0,
    StartObservedXp = nil,
    LastCatchTime = 0,
    RecentCatches = {},
    BiteWaitSum = 0,
    BiteWaitCount = 0,
    ReelTimeSum = 0,
    ReelTimeCount = 0,
    CycleTimeSum = 0,
    CycleTimeCount = 0,
    RarityCounts = {},
    FailReasons = { Invalid = 0, Lost = 0, Timeout = 0, Full = 0, Other = 0 },
    LastFishText = "None yet",
}

-- Forward declarations for UI synchronization
local updateLoop
local autoCastToggleRef
local fastSafeReelToggleRef
local colorReelToggleRef
local gameAutoCastToggleRef
local pingBufferSliderRef
local Window
local statFishHrRef, statXpHrRef, statCaughtRef, statLevelRef
local paraRateRef, paraGearRef, paraXpRef, paraPrimordialRef, paraRarityRef

local function clearConnList(list)
    for _, conn in ipairs(list) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(list)
end

-- Register global cleanup so re-executing never creates duplicate loops/listeners
getgenv()._AutoFishCleanup = function()
    AntiAFKState.Active = false
    monitorState.Active = false
    webhookState.Active = false
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
    clearConnList(levelUpConns)
    clearConnList(charConnections)
    clearConnList(connections)
end

-- Backup Idled listener in addition to the 120s timer
table.insert(connections, LocalPlayer.Idled:Connect(function()
    if AntiAFKState.Active then
        sendAntiAFKPulse("Idled backup")
    end
end))

-- ==================== FORMATTING HELPERS ====================
local function formatNumber(n)
    local num = math.floor((tonumber(n) or 0) + 0.5)
    local neg = num < 0
    num = math.abs(num)
    local s = tostring(num)
    local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return neg and ("-" .. formatted) or formatted
end

local function formatDuration(seconds)
    if not seconds or seconds ~= seconds or seconds == math.huge then
        return "--"
    end
    if seconds <= 0 then
        return "Now"
    end
    local total = math.floor(seconds + 0.5)
    local days = math.floor(total / 86400)
    local hours = math.floor((total % 86400) / 3600)
    local mins = math.floor((total % 3600) / 60)
    local secs = total % 60
    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, mins)
    elseif mins > 0 then
        return string.format("%dm %ds", mins, secs)
    else
        return string.format("%ds", secs)
    end
end

local function formatClock(seconds)
    local total = math.floor(math.max(0, seconds or 0))
    local h = math.floor(total / 3600)
    local m = math.floor((total % 3600) / 60)
    local s = total % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function formatOneIn(prob)
    if not prob or prob <= 0 then return "--" end
    local denom = math.max(1, math.floor((1 / prob) + 0.5))
    return "1 in " .. formatNumber(denom)
end

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

        fireSignalList(btn.MouseButton1Down, cx, cy)
        fireSignalList(btn.Activated, beginInput, 1)
        fireSignalList(btn.MouseButton1Click)
        fireSignalList(btn.MouseButton1Up, cx, cy)

        if btn:IsA("GuiButton") then
            pcall(function()
                fireSignalList(btn.TouchTap, { Vector2.new(cx, cy) })
            end)
        end

        if btn.Name == "TapMobile" or not btn:IsA("GuiButton") then
            fireSignalList(btn.InputBegan, beginInput, false)
            fireSignalList(btn.InputEnded, endInput, false)
        end
    end)
end

-- ==================== LEVEL, XP & GEAR LUCK CALCULATORS ====================
local function detectVipBonus()
    local attrs = LocalPlayer:GetAttributes()
    for k, v in pairs(attrs) do
        local kl = string.lower(k)
        if (kl == "vip" or kl == "isvip" or kl == "hasvip" or kl == "gamepassvip") and v == true then
            return true
        end
    end
    return false
end

local function parseFormattedExpNumber(str, expectedRef)
    if type(str) ~= "string" then return nil end
    local s = string.gsub(str, "%s+", "")
    if s == "" then return nil end

    local numPart, suffix = string.match(s, "^([%d%.,]+)([kKmMbB])$")
    if numPart and suffix then
        local val = tonumber((string.gsub(numPart, ",", ".")))
        if val then
            local sl = string.lower(suffix)
            if sl == "k" then return math.floor(val * 1000 + 0.5) end
            if sl == "m" then return math.floor(val * 1000000 + 0.5) end
            if sl == "b" then return math.floor(val * 1000000000 + 0.5) end
        end
    end

    local stripped = string.gsub(s, "[%.,]", "")
    local asInt = tonumber(stripped)

    if expectedRef and asInt and math.abs(asInt - expectedRef) <= math.max(10, expectedRef * 0.15) then
        return asInt
    end

    if string.match(s, "^%d+([%.,]%d%d%d)+$") then
        return asInt
    end

    return tonumber((string.gsub(s, ",", ""))) or asInt
end

local function readProfileExpHud()
    if not PlayerGui then return nil end
    local gameUI = PlayerGui:FindFirstChild("GameUI")
    local menus = gameUI and gameUI:FindFirstChild("Menus")
    local profile = menus and menus:FindFirstChild("Profile")
    local body = profile and profile:FindFirstChild("Body")
    local stats2 = body and body:FindFirstChild("Stats2")
    local expFrame = stats2 and stats2:FindFirstChild("Exp")
    if not expFrame then return nil end

    local captionLbl = expFrame:FindFirstChild("Caption")
    local countLbl = expFrame:FindFirstChild("Count")
    if not captionLbl or not countLbl then return nil end

    local capText = captionLbl.ContentText or captionLbl.Text or ""
    local cntText = countLbl.ContentText or countLbl.Text or ""
    if capText == "" or cntText == "" then return nil end

    local lvlCfg = getLevelConfig()
    local maxLvl = (lvlCfg and lvlCfg.MaxLevel) or 2000

    local nextLvl = tonumber(string.match(capText, "LV%.?%s*(%d+)")) or tonumber(string.match(capText, "(%d+)"))
    local curLevel
    if nextLvl then
        curLevel = math.clamp(nextLvl - 1, 1, maxLvl)
    elseif string.find(string.upper(capText), "MAX", 1, true) then
        curLevel = maxLvl
    else
        return nil
    end

    local expectedReq = (lvlCfg and type(lvlCfg.xpToNext) == "function") and lvlCfg.xpToNext(curLevel) or nil
    local leftStr, rightStr = string.match(cntText, "([^/]+)/([^/]+)")
    local xpReq = parseFormattedExpNumber(rightStr, expectedReq) or expectedReq or 0
    local xpInto = parseFormattedExpNumber(leftStr, expectedReq) or 0

    if xpReq <= 0 and curLevel < maxLvl then
        return nil
    end

    local totalXp = (lvlCfg and type(lvlCfg.totalForLevel) == "function")
        and (lvlCfg.totalForLevel(curLevel) + math.max(0, xpInto))
        or nil

    return curLevel, xpInto, xpReq, totalXp
end

local function readPlayerLevelAndXp()
    local hudLvl, hudInto, hudReq, hudTotal = readProfileExpHud()
    if hudLvl then
        return hudLvl, hudInto, hudReq, hudTotal, "Profile HUD"
    end

    local lvlCfg = getLevelConfig()
    local foundLevel, foundXp, foundTotalXp = nil, nil, nil

    for k, v in pairs(LocalPlayer:GetAttributes()) do
        if type(v) == "number" then
            local kl = string.lower(k)
            if kl == "totalxp" or kl == "totalexp" then
                foundTotalXp = v
            elseif kl == "level" or kl == "lvl" or kl == "fishlevel" then
                foundLevel = math.floor(v)
            elseif kl == "xp" or kl == "exp" or kl == "currentxp" then
                foundXp = v
            end
        end
    end

    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, child in ipairs(ls:GetChildren()) do
            if child:IsA("NumberValue") or child:IsA("IntValue") then
                local nl = string.lower(child.Name)
                if not foundLevel and (nl == "level" or nl == "lvl") then
                    foundLevel = math.floor(child.Value)
                elseif not foundTotalXp and (nl == "totalxp" or nl == "totalexp") then
                    foundTotalXp = child.Value
                elseif not foundXp and (nl == "xp" or nl == "exp") then
                    foundXp = child.Value
                end
            end
        end
    end

    if lvlCfg and type(lvlCfg.fromXp) == "function" and type(lvlCfg.totalForLevel) == "function" then
        if foundTotalXp then
            local lvl, xpInto, xpReq = lvlCfg.fromXp(foundTotalXp)
            return lvl, xpInto, xpReq, foundTotalXp, "Attributes"
        elseif foundLevel and foundXp then
            local xpReq = lvlCfg.xpToNext(foundLevel)
            if foundXp >= xpReq and lvlCfg.fromXp(foundXp) == foundLevel then
                local lvl, xpInto, req = lvlCfg.fromXp(foundXp)
                return lvl, xpInto, req, foundXp, "Attributes"
            else
                local total = lvlCfg.totalForLevel(foundLevel) + math.max(0, foundXp)
                return foundLevel, math.max(0, foundXp), xpReq, total, "Attributes"
            end
        elseif foundLevel then
            local xpReq = lvlCfg.xpToNext(foundLevel)
            return foundLevel, 0, xpReq, lvlCfg.totalForLevel(foundLevel), "Attributes"
        elseif foundXp then
            local lvl, xpInto, xpReq = lvlCfg.fromXp(foundXp)
            return lvl, xpInto, xpReq, foundXp, "Attributes"
        end
    end

    return foundLevel, foundXp, nil, foundTotalXp, "Estimated"
end

local function computeAverageLevelsPerHour(currentLevel, currentTotalXp, xpPerHour)
    if xpPerHour <= 0 then return 0 end
    local lvlCfg = getLevelConfig()
    if not lvlCfg or type(lvlCfg.fromXp) ~= "function" or type(lvlCfg.xpToNext) ~= "function" then
        return 0
    end
    if currentLevel and currentTotalXp then
        if currentLevel >= (lvlCfg.MaxLevel or 2000) then
            return 0
        end
        local futureLevel, futureInto = lvlCfg.fromXp(currentTotalXp + xpPerHour)
        local curReq = math.max(1, lvlCfg.xpToNext(currentLevel))
        local futReq = math.max(1, lvlCfg.xpToNext(futureLevel))
        local curExact = currentLevel + ((currentTotalXp - lvlCfg.totalForLevel(currentLevel)) / curReq)
        local futExact = futureLevel + (futReq > 0 and (futureInto / futReq) or 0)
        return math.max(0, futExact - curExact)
    else
        return xpPerHour / math.max(1, lvlCfg.xpToNext(1))
    end
end

local function extractToolEnhancements(tool)
    local enhanceCfg = getRodEnhanceConfig()
    local directEnhanceLuck = tool and tonumber(tool:GetAttribute("EnhanceLuck")) or nil
    local result = {
        Luck = directEnhanceLuck or 0,
        SecretMult = 1,
        SupremacyMult = 1,
        PrimordialMult = 1,
        Names = {},
    }
    if not tool then return result end

    local slots = {}
    for _, attrName in ipairs({ "Enhance", "Enhance1", "Enhance2", "Enhance3", "Enchant", "Enchant1", "Enchant2", "Enchant3" }) do
        local val = tool:GetAttribute(attrName)
        if type(val) == "string" and val ~= "" then
            for part in string.gmatch(val, "[^,;]+") do
                local trimmed = string.match(part, "^%s*(.-)%s*$")
                if trimmed and trimmed ~= "" then
                    table.insert(slots, trimmed)
                end
            end
        end
    end

    if enhanceCfg and #slots > 0 and type(enhanceCfg.combine) == "function" then
        local combined = enhanceCfg.combine(slots)
        if combined then
            if directEnhanceLuck == nil then
                result.Luck = combined.Luck or 0
            end
            result.SecretMult = combined.SecretMult or 1
            result.SupremacyMult = combined.SupremacyMult or 1
            result.PrimordialMult = combined.PrimordialMult or 1
            result.Names = slots
        end
    elseif #slots > 0 then
        result.Names = slots
    end

    return result
end

local function refreshEquippedBaitFromServer()
    if GetStateRemote and GetStateRemote.Parent then
        task.spawn(function()
            local okState, state = pcall(GetStateRemote.InvokeServer, GetStateRemote)
            if okState and type(state) == "table" and type(state.equippedBait) == "string" and state.equippedBait ~= "" then
                detectedEquippedBait = state.equippedBait
            end
        end)
    end
end

local function getEquippedBaitName()
    for _, attr in ipairs({ "EquippedBait", "Bait", "CurrentBait", "FishBait" }) do
        local val = LocalPlayer:GetAttribute(attr)
        if type(val) == "string" and val ~= "" then
            return val
        end
    end
    if type(detectedEquippedBait) == "string" and detectedEquippedBait ~= "" then
        return detectedEquippedBait
    end
    local bc = getBaitConfig()
    return (bc and bc.Default) or "Basic Bait"
end

-- Forward declare rod finder so Gear Stats can read active rod
local findEquippedRod
local findBestBackpackRod

local function getGearAndLuckSummary()
    local rc = getRodConfig()
    local bc = getBaitConfig()
    local fc = getFishConfig()

    local activeRodTool = findEquippedRod(LocalPlayer.Character) or findBestBackpackRod(LocalPlayer:FindFirstChild("Backpack"))
    local rodName = (activeRodTool and (activeRodTool:GetAttribute("RodName") or activeRodTool.Name))
        or (rc and rc.Default)
        or "Basic Rod"
    local rodInfo = (rc and type(rc.get) == "function" and rc.get(rodName)) or nil
    local rodBaseLuck = (rodInfo and tonumber(rodInfo.Luck)) or 1
    local rodTaps = (rodInfo and tonumber(rodInfo.Taps)) or 17
    local rodMaxRarity = (rodInfo and rodInfo.MaxRarity) or "Epic"

    local enh = extractToolEnhancements(activeRodTool)
    local baitName = getEquippedBaitName()
    local baitInfo = (bc and type(bc.get) == "function" and bc.get(baitName)) or nil
    local baitLuck = (baitInfo and tonumber(baitInfo.Luck)) or 2

    local globalLuck = math.max(1, tonumber(ReplicatedStorage:GetAttribute("FishGlobalLuck")) or 0)
    local powerMult = 1 + (castPower * 0.2)
    local totalLuck = ((rodBaseLuck + enh.Luck) * powerMult + baitLuck) * globalLuck

    local mythicProb, secretProb, supremacyProb = 0, 0, 0
    if fc and type(fc.topEffective) == "function" and type(fc.RarityOrder) == "table" then
        local maxOrd = fc.RarityOrder[rodMaxRarity] or 4
        if maxOrd >= 5 then
            mythicProb = fc.topEffective("Mythic", totalLuck, 1, 0, 1)
        end
        if maxOrd >= 6 then
            secretProb = fc.topEffective("Secret", totalLuck, 1, 0, enh.SecretMult)
        end
        if maxOrd >= 7 then
            supremacyProb = fc.topEffective("Supremacy", totalLuck, 1, 0, enh.SupremacyMult)
        end
    end

    return {
        RodName = rodName,
        RodInfo = rodInfo,
        RodLuck = rodBaseLuck,
        RodTaps = rodTaps,
        RodMaxRarity = rodMaxRarity,
        EnhanceLuck = enh.Luck,
        EnhanceNames = enh.Names,
        PrimordialMult = enh.PrimordialMult,
        BaitName = baitName,
        BaitLuck = baitLuck,
        GlobalLuck = globalLuck,
        TotalLuck = totalLuck,
        MythicProb = mythicProb,
        SecretProb = secretProb,
        SupremacyProb = supremacyProb,
    }
end

-- ==================== DISCORD WEBHOOK ENGINE ====================
local function getAllHttpRequestFuncs()
    local list = {}
    local seen = {}
    local candidates = {
        request,
        http_request,
        http and http.request,
        syn and syn.request,
        fluxus and fluxus.request,
    }
    for _, fn in ipairs(candidates) do
        if type(fn) == "function" and not seen[fn] then
            seen[fn] = true
            table.insert(list, fn)
        end
    end
    return list
end

local function extractHttpStatus(res)
    if type(res) ~= "table" then return 0, "Non-table response" end
    local raw = res.StatusCode or res.status_code or res.statusCode or res.Status or res.status or res.code or res.Code
    local code = tonumber(raw) or 0
    if code == 0 and res.Success == true then
        code = 200
    end
    local detail = res.StatusMessage or res.status_message or res.Error or res.error or res.Body or res.body or ""
    if type(detail) ~= "string" then
        detail = tostring(detail)
    end
    if #detail > 140 then
        detail = string.sub(detail, 1, 140) .. "..."
    end
    return code, detail
end

local function enqueueWebhookEmbed(embedTbl)
    if not webhookState.Enabled then return end
    if not isValidWebhookUrl(webhookState.Url) then return end
    if #webhookState.Queue >= 25 then
        table.remove(webhookState.Queue, 1)
    end
    embedTbl.timestamp = embedTbl.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ")
    embedTbl.footer = embedTbl.footer or {
        text = string.format("Saujana Auto Fish v%s • %s", SCRIPT_VERSION, LocalPlayer.Name)
    }
    table.insert(webhookState.Queue, { embeds = { embedTbl } })
end

local function tryPostWithUrl(reqFunc, targetUrl, jsonBody)
    local okReq, res = pcall(reqFunc, {
        Url = targetUrl,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json",
        },
        Body = jsonBody,
    })
    if not okReq then
        return 0, tostring(res), nil
    end
    local code, detail = extractHttpStatus(res)
    return code, detail, res
end

local function sendWebhookPayloadNow(payload)
    local reqFuncs = getAllHttpRequestFuncs()
    if #reqFuncs == 0 then
        return false, "Executor has no HTTP request function"
    end

    local cleanUrl = trimString(webhookState.Url)
    if not isValidWebhookUrl(cleanUrl) then
        return false, "Invalid Discord Webhook URL"
    end

    local okEnc, jsonBody = pcall(HttpService.JSONEncode, HttpService, payload)
    if not okEnc then
        return false, "JSON encode failed"
    end

    local urlsToTry = { cleanUrl }
    if (string.find(cleanUrl, "discord.com/api/webhooks/", 1, true) or string.find(cleanUrl, "discordapp.com/api/webhooks/", 1, true))
        and not string.find(cleanUrl, "wait=", 1, true) then
        local sep = string.find(cleanUrl, "?", 1, true) and "&" or "?"
        table.insert(urlsToTry, cleanUrl .. sep .. "wait=true")
    end

    local lastErr = "HTTP 0"
    for _, targetUrl in ipairs(urlsToTry) do
        for _, reqFunc in ipairs(reqFuncs) do
            local code, detail, res = tryPostWithUrl(reqFunc, targetUrl, jsonBody)
            if code >= 200 and code < 300 then
                webhookState.SentCount += 1
                return true, code
            elseif code == 429 then
                local retryAfter = 3
                if type(res) == "table" and type(res.Body) == "string" then
                    local okDec, dec = pcall(HttpService.JSONDecode, HttpService, res.Body)
                    if okDec and type(dec) == "table" and tonumber(dec.retry_after) then
                        retryAfter = math.clamp(tonumber(dec.retry_after), 1, 15)
                    end
                end
                task.wait(retryAfter)
                return false, "429 Rate Limited"
            elseif code > 0 then
                webhookState.FailedCount += 1
                local errMsg = (detail ~= "" and string.format("HTTP %d (%s)", code, detail)) or ("HTTP " .. tostring(code))
                warn("[Auto Fish Webhook] " .. errMsg)
                return false, errMsg
            else
                lastErr = (detail ~= "" and string.format("HTTP 0 (%s)", detail)) or "HTTP 0 (Request blocked or no response)"
            end
        end
    end

    webhookState.FailedCount += 1
    warn("[Auto Fish Webhook] " .. lastErr)
    return false, lastErr
end

task.spawn(function()
    while webhookState.Active do
        if #webhookState.Queue > 0 and webhookState.Enabled and isValidWebhookUrl(webhookState.Url) then
            local nextPayload = table.remove(webhookState.Queue, 1)
            local okSend = sendWebhookPayloadNow(nextPayload)
            if not okSend then
                task.wait(2.5)
            else
                task.wait(1.5)
            end
        else
            task.wait(0.5)
        end
    end
end)

local function buildRateSnapshot()
    local now = os.clock()
    local elapsed = math.max(1, now - monitorState.SessionStart)
    local elapsedMins = elapsed / 60
    local elapsedHrs = elapsed / 3600

    while #monitorState.RecentCatches > 0 and (now - monitorState.RecentCatches[1]) > 120 do
        table.remove(monitorState.RecentCatches, 1)
    end

    local rollingWindowSecs = math.min(120, math.max(15, elapsed))
    local liveFishPerMin = (#monitorState.RecentCatches / rollingWindowSecs) * 60
    local liveFishPerHr = liveFishPerMin * 60
    local sessionFishPerMin = monitorState.TotalCaught / elapsedMins
    local sessionFishPerHr = monitorState.TotalCaught / elapsedHrs

    local totalAttempts = monitorState.TotalCaught + monitorState.TotalFailed
    local successPct = totalAttempts > 0 and ((monitorState.TotalCaught / totalAttempts) * 100) or 100

    local avgBite = monitorState.BiteWaitCount > 0 and (monitorState.BiteWaitSum / monitorState.BiteWaitCount) or 0
    local avgReel = monitorState.ReelTimeCount > 0 and (monitorState.ReelTimeSum / monitorState.ReelTimeCount) or 0
    local avgCycle = monitorState.CycleTimeCount > 0 and (monitorState.CycleTimeSum / monitorState.CycleTimeCount) or 0

    local lvlCfg = getLevelConfig()
    local curLevel, curXpInto, curXpReq, curTotalXp, xpHudSource = readPlayerLevelAndXp()
    if not monitorState.StartObservedXp and curTotalXp then
        monitorState.StartObservedXp = curTotalXp
    end

    local playtimeXp = elapsedMins * ((lvlCfg and lvlCfg.XpPerMinute) or 10)
    local estimatedSessionXp = monitorState.SessionFishXp + playtimeXp
    local observedGain = (curTotalXp and monitorState.StartObservedXp) and math.max(0, curTotalXp - monitorState.StartObservedXp) or 0

    local activeXpGain = observedGain > 0 and observedGain or estimatedSessionXp
    local xpSourceLabel = observedGain > 0 and (xpHudSource or "Live XP") or "FishConfig + Playtime"
    local xpPerMin = activeXpGain / elapsedMins
    local xpPerHr = activeXpGain / elapsedHrs
    local xpPerSec = activeXpGain / elapsed
    local levelsPerHr = computeAverageLevelsPerHour(curLevel, curTotalXp, xpPerHr)

    return {
        elapsed = elapsed,
        liveFishPerMin = liveFishPerMin,
        liveFishPerHr = liveFishPerHr,
        sessionFishPerMin = sessionFishPerMin,
        sessionFishPerHr = sessionFishPerHr,
        successPct = successPct,
        avgBite = avgBite,
        avgReel = avgReel,
        avgCycle = avgCycle,
        curLevel = curLevel,
        curXpInto = curXpInto,
        curXpReq = curXpReq,
        curTotalXp = curTotalXp,
        activeXpGain = activeXpGain,
        xpSourceLabel = xpSourceLabel,
        xpPerMin = xpPerMin,
        xpPerHr = xpPerHr,
        xpPerSec = xpPerSec,
        levelsPerHr = levelsPerHr,
    }
end

local function buildStatsReportEmbed(titleOverride, colorOverride)
    local snap = buildRateSnapshot()
    local gear = getGearAndLuckSummary()
    local lvlCfg = getLevelConfig()

    local statusText = isFarmPausedNoWater and "Paused (Away from water)"
        or (enabledCast and "Active" or "Idle (Auto Cast OFF)")

    local levelText = "N/A"
    local etaNext = "--"
    if snap.curLevel and lvlCfg then
        local rankInfo = type(lvlCfg.rankFor) == "function" and lvlCfg.rankFor(snap.curLevel) or nil
        local rankTitle = rankInfo and rankInfo.Title or ""
        local xpReq = snap.curXpReq or (type(lvlCfg.xpToNext) == "function" and lvlCfg.xpToNext(snap.curLevel) or 0)
        levelText = string.format("Lv. %d (%s)\n%s / %s XP", snap.curLevel, rankTitle, formatNumber(snap.curXpInto or 0), formatNumber(xpReq))
        if snap.xpPerSec > 0 and snap.curTotalXp and type(lvlCfg.totalForLevel) == "function" and snap.curLevel < (lvlCfg.MaxLevel or 2000) then
            local nextNeed = math.max(0, lvlCfg.totalForLevel(snap.curLevel + 1) - snap.curTotalXp)
            etaNext = formatDuration(nextNeed / snap.xpPerSec)
        end
    end

    local rarityText = string.format(
        "Common: %d | Uncommon: %d | Rare: %d | Epic: %d\nMythic: %d | Secret: %d | Supremacy: %d | Primordial: %d",
        monitorState.RarityCounts.Common or 0,
        monitorState.RarityCounts.Uncommon or 0,
        monitorState.RarityCounts.Rare or 0,
        monitorState.RarityCounts.Epic or 0,
        monitorState.RarityCounts.Mythic or 0,
        monitorState.RarityCounts.Secret or 0,
        monitorState.RarityCounts.Supremacy or 0,
        monitorState.RarityCounts.Primordial or 0
    )

    return {
        title = titleOverride or "Overnight Farm Report",
        color = colorOverride or RARITY_COLORS.Report,
        fields = {
            {
                name = "Player & Status",
                value = string.format("%s (@%s)\n%s • Uptime: %s", LocalPlayer.DisplayName, LocalPlayer.Name, statusText, formatClock(snap.elapsed)),
                inline = true,
            },
            {
                name = "Gear & Luck",
                value = string.format("%s • %s\nTotal Luck: %.1fx (Global %.1fx)", gear.RodName, gear.BaitName, gear.TotalLuck, gear.GlobalLuck),
                inline = true,
            },
            {
                name = "Catch Rates",
                value = string.format("Live: **%s/hr** (%.1f/m)\nAvg: %s/hr | Cycle: %.2fs", formatNumber(snap.liveFishPerHr), snap.liveFishPerMin, formatNumber(snap.sessionFishPerHr), snap.avgCycle),
                inline = true,
            },
            {
                name = "Session Totals",
                value = string.format("Caught: **%s**\nFailed: %d (Inv: %d) • %.1f%%", formatNumber(monitorState.TotalCaught), monitorState.TotalFailed, monitorState.InvalidFails, snap.successPct),
                inline = true,
            },
            {
                name = "Level & XP",
                value = string.format("%s\n%s XP/hr (%.2f Lv/hr) • Next: %s", levelText, formatNumber(snap.xpPerHr), snap.levelsPerHr, etaNext),
                inline = true,
            },
            {
                name = "Tuning",
                value = string.format("Mode: %s\nPing Buffer: %.2fs (Floor: %.2fs)", autoTuneUseFullTaps and "100% Locked" or "60% Auto-Tune", pingBuffer, autoTuneFloorBuffer),
                inline = true,
            },
            {
                name = "Rarity Breakdown",
                value = rarityText,
                inline = false,
            },
        },
    }
end

local function queueRareCatchWebhook(fishName, rarity, weightKg, rawChance)
    if not webhookState.Enabled or not webhookState.NotifyRareCatches then return end
    if not NOTIFY_CATCH_RARITIES[rarity] then return end

    local fc = getFishConfig()
    local oneInVal = tonumber(rawChance)
    if not oneInVal and fc and type(fc.oneIn) == "function" then
        oneInVal = fc.oneIn(fishName)
    end
    local chanceText = (oneInVal and oneInVal > 0) and ("1 in " .. formatNumber(oneInVal)) or "Rare Drop"
    if weightKg then
        chanceText = string.format("%s • %.1f kg", chanceText, weightKg)
    end

    local snap = buildRateSnapshot()
    local gear = getGearAndLuckSummary()
    local levelStr = snap.curLevel and string.format("Lv. %d (%s XP/hr)", snap.curLevel, formatNumber(snap.xpPerHr)) or (formatNumber(snap.xpPerHr) .. " XP/hr")

    enqueueWebhookEmbed({
        title = string.format("[%s] %s Caught!", tostring(rarity), tostring(fishName)),
        color = RARITY_COLORS[rarity] or RARITY_COLORS.Report,
        fields = {
            {
                name = "Player",
                value = string.format("%s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name),
                inline = true,
            },
            {
                name = "Rarity",
                value = tostring(rarity),
                inline = true,
            },
            {
                name = "Odds / Info",
                value = chanceText,
                inline = true,
            },
            {
                name = "Live Rate",
                value = string.format("%s fish/hr (%.1f/m)", formatNumber(snap.liveFishPerHr), snap.liveFishPerMin),
                inline = true,
            },
            {
                name = "Level & XP",
                value = levelStr,
                inline = true,
            },
            {
                name = "Session Stats",
                value = string.format("Caught: %s | Fails: %d (%.1f%%)\nUptime: %s • %s (%.1fx)", formatNumber(monitorState.TotalCaught), monitorState.TotalFailed, snap.successPct, formatClock(snap.elapsed), gear.RodName, gear.TotalLuck),
                inline = false,
            },
        },
    })
end

local function queueAlertWebhook(title, message, color)
    if not webhookState.Enabled or not webhookState.AlertOnIssues then return end
    local now = os.clock()
    if (now - webhookState.LastAlertAt) < 30 then return end
    webhookState.LastAlertAt = now
    enqueueWebhookEmbed({
        title = title,
        description = message,
        color = color or RARITY_COLORS.Alert,
    })
end

-- ==================== WATER PROXIMITY DETECTION ====================
local function isWaterRaycastHit(hit)
    if not hit then return false end
    if hit.Material == Enum.Material.Water then
        return true
    end
    local inst = hit.Instance
    for _ = 1, 4 do
        if not inst or inst == workspace then
            break
        end
        if inst:IsA("BasePart") and inst.Material == Enum.Material.Water then
            return true
        end
        if CollectionService:HasTag(inst, "FishWater") or inst:GetAttribute("FishWater") == true then
            return true
        end
        local lower = string.lower(inst.Name)
        if lower == "fishwater" or lower == "water" or lower == "air" then
            return true
        end
        inst = inst.Parent
    end
    return false
end

local function scanNearestWater()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false, nil
    end

    local exclude = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            table.insert(exclude, plr.Character)
        end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude
    params.IgnoreWater = false

    local originPos = hrp.Position
    for radius = 4, 31, 4.5 do
        local steps = math.max(8, math.floor(radius * 0.7))
        for j = 0, steps - 1 do
            local angle = (j / steps) * (math.pi * 2)
            local probe = originPos + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            local hit = workspace:Raycast(probe + Vector3.new(0, 25, 0), Vector3.new(0, -70, 0), params)
            if isWaterRaycastHit(hit) then
                local flat = Vector3.new(hit.Position.X - originPos.X, 0, hit.Position.Z - originPos.Z)
                local dir = flat.Magnitude > 0.5 and flat.Unit or nil
                return true, dir
            end
        end
    end

    return false, nil
end

local function refreshWaterState(forceNotify)
    local found, dir = scanNearestWater()
    isNearWater = found
    cachedWaterDir = dir

    if enabledPauseNoWater then
        if not found and not isFarmPausedNoWater then
            isFarmPausedNoWater = true
            waitingForBite = false
            queueAlertWebhook("Farm Paused (Away From Water)", "Character moved away from water. Waiting to return.", RARITY_COLORS.Alert)
            if Window and forceNotify ~= false then
                task.defer(function()
                    Window:Notify({
                        title = "Farm Paused",
                        content = "Moved away from water — waiting to return",
                        duration = 3,
                    })
                end)
            end
        elseif found and isFarmPausedNoWater then
            isFarmPausedNoWater = false
            queueAlertWebhook("Farm Resumed", "Water detected nearby — casting resumed.", RARITY_COLORS.Resume)
            if Window and forceNotify ~= false then
                task.defer(function()
                    Window:Notify({
                        title = "Farm Resumed",
                        content = "Water detected nearby — casting resumed",
                        duration = 3,
                    })
                end)
            end
        end
    else
        isFarmPausedNoWater = false
    end
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

-- ==================== LEVELUP UI AUTO-CLOSER ====================
local CLOSE_BTN_KEYWORDS = { "close", "ok", "okay", "claim", "continue", "confirm", "dismiss", "exit", "skip", "done" }

local function isLevelUpCloseButton(obj)
    if not obj:IsA("GuiButton") or not obj.Visible then
        return false
    end
    local nameLower = string.lower(obj.Name)
    if nameLower == "x" then
        return true
    end
    for _, kw in ipairs(CLOSE_BTN_KEYWORDS) do
        if string.find(nameLower, kw, 1, true) then
            return true
        end
    end
    if obj:IsA("TextButton") then
        local txtLower = string.lower(obj.Text or "")
        if txtLower == "x" then
            return true
        end
        for _, kw in ipairs(CLOSE_BTN_KEYWORDS) do
            if string.find(txtLower, kw, 1, true) then
                return true
            end
        end
    end
    return false
end

local function closeLevelUpUI(gui)
    if not enabledAutoCloseLevelUp or not gui or not gui.Parent then return end
    local now = os.clock()
    if (now - lastLevelUpClose) < 0.15 then return end

    local isVisible = false
    if gui:IsA("LayerCollector") and gui.Enabled then
        isVisible = true
    else
        for _, child in ipairs(gui:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible then
                isVisible = true
                break
            end
        end
    end
    if not isVisible then return end

    lastLevelUpClose = now

    for _, desc in ipairs(gui:GetDescendants()) do
        if isLevelUpCloseButton(desc) then
            triggerImageButton(desc)
        end
    end

    task.delay(0.1, function()
        if not enabledAutoCloseLevelUp or not gui or not gui.Parent then return end
        pcall(function()
            if gui:IsA("LayerCollector") then
                gui.Enabled = false
            end
            for _, child in ipairs(gui:GetChildren()) do
                if child:IsA("GuiObject") and child.Visible then
                    child.Visible = false
                end
            end
        end)
    end)
end

local function bindLevelUpUI(gui)
    clearConnList(levelUpConns)
    if not gui then return end

    local function watchGuiChild(child)
        if child:IsA("GuiObject") then
            table.insert(levelUpConns, child:GetPropertyChangedSignal("Visible"):Connect(function()
                if child.Visible then
                    closeLevelUpUI(gui)
                end
            end))
            if child.Visible then
                closeLevelUpUI(gui)
            end
        end
    end

    if gui:IsA("LayerCollector") then
        table.insert(levelUpConns, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if gui.Enabled then
                closeLevelUpUI(gui)
            end
        end))
    end

    for _, child in ipairs(gui:GetChildren()) do
        watchGuiChild(child)
    end
    table.insert(levelUpConns, gui.ChildAdded:Connect(watchGuiChild))

    closeLevelUpUI(gui)
end

local function resetRateMonitor()
    monitorState.SessionStart = os.clock()
    monitorState.TotalCaught = 0
    monitorState.TotalFailed = 0
    monitorState.InvalidFails = 0
    monitorState.SessionFishXp = 0
    monitorState.LastCatchTime = 0
    table.clear(monitorState.RecentCatches)
    monitorState.BiteWaitSum = 0
    monitorState.BiteWaitCount = 0
    monitorState.ReelTimeSum = 0
    monitorState.ReelTimeCount = 0
    monitorState.CycleTimeSum = 0
    monitorState.CycleTimeCount = 0
    table.clear(monitorState.RarityCounts)
    monitorState.FailReasons = { Invalid = 0, Lost = 0, Timeout = 0, Full = 0, Other = 0 }
    monitorState.LastFishText = "None yet"

    local _, _, _, totalXp = readPlayerLevelAndXp()
    monitorState.StartObservedXp = totalXp
end

-- ==================== FAST SAFE REEL & PING BUFFER AUTO-TUNE ====================
local function updatePingBufferSliderUI()
    if pingBufferSliderRef and pingBufferSliderRef.Set then
        isUpdatingPingSlider = true
        pcall(function()
            pingBufferSliderRef:Set(math.floor(pingBuffer * 100 + 0.5) / 100)
        end)
        isUpdatingPingSlider = false
    end
end

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
        useFull = autoTuneUseFullTaps
    end

    local effectiveTaps
    if useFull then
        effectiveTaps = taps
    else
        effectiveTaps = math.max(1, math.ceil(taps * math.max(0.1, 1 - startProg)))
    end

    return (effectiveTaps * perTap) + pingBuffer
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
    local now = os.clock()
    lastServerActivityAt = now

    if eventName == "State" and type(data) == "table" then
        if type(data.equippedBait) == "string" and data.equippedBait ~= "" then
            detectedEquippedBait = data.equippedBait
        end
    elseif eventName == "CastOk" then
        waitingForBite = true
        waitingSince = now
    elseif eventName == "Bite" and type(data) == "table" then
        waitingForBite = false
        biteActive = true
        biteAt = now
        biteTaps = tonumber(data.taps) or 13
        biteIsAuto = (data.auto == true)
        biteHasReeled = false
        lastReelAttemptAt = 0
        fishingOpenedAt = now
        sawProgressBelowTarget = false

        if lastCastSentAt > 0 and (now - lastCastSentAt) <= 15 then
            monitorState.BiteWaitSum += (now - lastCastSentAt)
            monitorState.BiteWaitCount += 1
        end

        recalculateSafeReelTime()
    elseif eventName == "Caught" then
        waitingForBite = false
        biteActive = false
        biteHasReeled = true
        consecutiveCatches += 1
        consecutiveInvalidFails = 0

        monitorState.TotalCaught += 1
        table.insert(monitorState.RecentCatches, now)
        if biteAt > 0 and (now - biteAt) <= 30 then
            monitorState.ReelTimeSum += (now - biteAt)
            monitorState.ReelTimeCount += 1
        end
        if monitorState.LastCatchTime > 0 and (now - monitorState.LastCatchTime) <= 60 then
            monitorState.CycleTimeSum += (now - monitorState.LastCatchTime)
            monitorState.CycleTimeCount += 1
        end
        monitorState.LastCatchTime = now

        local rarity = (type(data) == "table" and data.rarity) or "Common"
        local fishName = (type(data) == "table" and data.name) or "Fish"
        local weightKg = (type(data) == "table" and (tonumber(data.kg) or tonumber(data.weight))) or nil
        local rawChance = (type(data) == "table" and (tonumber(data.oneIn) or tonumber(data.chance))) or nil

        monitorState.RarityCounts[rarity] = (monitorState.RarityCounts[rarity] or 0) + 1
        monitorState.LastFishText = string.format("%s (%s)", tostring(fishName), tostring(rarity))

        local lvlCfg = getLevelConfig()
        local xpTable = (lvlCfg and lvlCfg.FishXp) or DEFAULT_FISH_XP
        local baseXp = xpTable[rarity] or 5
        local vipMult = (detectVipBonus() and (1 + ((lvlCfg and lvlCfg.VipBonus) or 0.25))) or 1
        monitorState.SessionFishXp += (baseXp * vipMult)

        -- Trigger Discord Webhook for Mythic / Secret / Supremacy / Primordial
        queueRareCatchWebhook(fishName, rarity, weightKg, rawChance)

        -- Ping Buffer Auto-Tune: trim down cautiously after 25 clean catches above floor lock
        if autoTunePingBuffer and consecutiveCatches >= 25 and (now - lastBufferAdjustAt) >= 45 then
            local floorTarget = math.max(0.03, autoTuneFloorBuffer)
            if pingBuffer > floorTarget + 0.005 then
                pingBuffer = math.max(floorTarget, math.floor((pingBuffer - 0.01) * 100 + 0.5) / 100)
                lastBufferAdjustAt = now
                consecutiveCatches = 0
                updatePingBufferSliderUI()
                print(string.format("[Auto Fish] Ping Auto-Tune: Trimmed buffer to %.2fs after 25 clean catches.", pingBuffer))
            end
        end
    elseif eventName == "Failed" then
        waitingForBite = false
        biteActive = false
        biteHasReeled = true
        monitorState.TotalFailed += 1

        local reason = type(data) == "table" and data.reason or "Other"
        if monitorState.FailReasons[reason] ~= nil then
            monitorState.FailReasons[reason] += 1
        else
            monitorState.FailReasons.Other += 1
        end

        if reason == "Invalid" then
            monitorState.InvalidFails += 1
            consecutiveCatches = 0
            consecutiveInvalidFails += 1
            lastBufferAdjustAt = now

            local switchedToFull = false
            if reelTimingMode == "Auto-Tune (Best)" and not autoTuneUseFullTaps then
                autoTuneUseFullTaps = true
                switchedToFull = true
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
            end

            if autoTunePingBuffer and not switchedToFull then
                local newBuf = math.min(0.45, math.floor((pingBuffer + 0.03) * 100 + 0.5) / 100)
                if newBuf > pingBuffer then
                    pingBuffer = newBuf
                    autoTuneFloorBuffer = math.max(autoTuneFloorBuffer, pingBuffer)
                    updatePingBufferSliderUI()
                    warn(string.format("[Auto Fish] Ping Auto-Tune: Bumped buffer to %.2fs (floor locked).", pingBuffer))
                    if Window then
                        task.defer(function()
                            Window:Notify({
                                title = "Ping Buffer Auto-Tuned",
                                content = string.format("Increased Ping Buffer to %.2fs (0 fails lock)", pingBuffer),
                                duration = 3,
                            })
                        end)
                    end
                end
            end

            if consecutiveInvalidFails >= 5 then
                queueAlertWebhook("Repeated 'Invalid' Fails Detected", string.format("%d consecutive Invalid fails occurred. Current Ping Buffer: %.2fs.", consecutiveInvalidFails, pingBuffer), RARITY_COLORS.Alert)
            end
        end
    elseif eventName == "CastFail" and type(data) == "table" then
        if data.reason ~= "Busy" then
            waitingForBite = false
            if not biteActive then
                biteHasReeled = false
            end
            if data.reason == "NotWater" and enabledPauseNoWater then
                lastWaterCheckAt = now
                refreshWaterState(true)
            elseif data.reason == "Full" and enabledSell and not isSelling and SellAll and SellAll.Parent then
                lastSellTime = now
                isSelling = true
                task.spawn(function()
                    pcall(SellAll.InvokeServer, SellAll)
                    isSelling = false
                end)
            end
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

    local lvlGui = PlayerGui:FindFirstChild("LevelUpUI")
    if lvlGui then
        bindLevelUpUI(lvlGui)
    end

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
                elseif isGameAutoCastOn() then
                    setGameAutoCast(false)
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
        elseif child.Name == "LevelUpUI" then
            task.defer(bindLevelUpUI, child)
        end
    end))
    table.insert(connections, PlayerGui.ChildRemoved:Connect(function(child)
        if child.Name == "FishingGui" then
            clearUICache()
        elseif child.Name == "LevelUpUI" then
            clearConnList(levelUpConns)
        end
    end))
end

-- Disconnect error alert listener
table.insert(connections, GuiService.ErrorMessageChanged:Connect(function(errMsg)
    if errMsg and errMsg ~= "" then
        queueAlertWebhook("Roblox Disconnect / Error Detected", tostring(errMsg), RARITY_COLORS.Alert)
    end
end))

-- ==================== REMOTE RESOLUTION ====================
local function isRemoteValid(remote)
    return remote ~= nil and remote.Parent ~= nil
end

local function resolveAllConfigs()
    getFishConfig()
    getRodConfig()
    getRodSkinConfig()
    getBaitConfig()
    getRodEnhanceConfig()
    getLevelConfig()
    getCelestraConfig()
    getThalvyraConfig()
    getSoreKrakenConfig()
end

local function resolveRemotes()
    local fishRemotes = ReplicatedStorage:FindFirstChild("FishRemotes")
    if not fishRemotes then return false end

    if not isRemoteValid(CastRemote) then CastRemote = fishRemotes:FindFirstChild("Cast") end
    if not isRemoteValid(ReelRemote) then ReelRemote = fishRemotes:FindFirstChild("Reel") end
    if not isRemoteValid(SellAll) then SellAll = fishRemotes:FindFirstChild("SellAll") end
    if not isRemoteValid(SetAutoRemote) then SetAutoRemote = fishRemotes:FindFirstChild("SetAuto") end
    if not isRemoteValid(GetStateRemote) then GetStateRemote = fishRemotes:FindFirstChild("GetState") end

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

    resolveAllConfigs()
    refreshEquippedBaitFromServer()

    task.spawn(function()
        for _ = 1, 20 do
            resolveRemotes()
            resolveAllConfigs()
            if isRemoteValid(ReelRemote) and isRemoteValid(SellAll) and isRemoteValid(SetAutoRemote) and isRemoteValid(ServerRemote) and isRemoteValid(GetStateRemote) then
                break
            end
            task.wait(1)
        end
        refreshEquippedBaitFromServer()
    end)
end)

-- ==================== UNIVERSAL ROD AUTO EQUIP (CHARACTER + BACKPACK + RODCONTENT UI) ====================
local function isFishingRodTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end

    if tool:GetAttribute("FishRod") then
        return true
    end
    if tool:GetAttribute("RodName") ~= nil or tool:GetAttribute("SkinName") ~= nil then
        return true
    end

    local rc = getRodConfig()
    if rc and type(rc.Rods) == "table" and rc.Rods[tool.Name] ~= nil then
        return true
    end

    getRodSkinConfig()
    if cachedSkinDisplaySet and cachedSkinDisplaySet[tool.Name] then
        return true
    end

    local lowerName = string.lower(tool.Name)
    if string.find(lowerName, "rod", 1, true) or string.find(lowerName, "katana", 1, true) then
        return true
    end

    return false
end

local function getRodNameScore(rodName, obj)
    local score = 1
    local rc = getRodConfig()
    if rc and type(rc.get) == "function" and type(rodName) == "string" then
        local info = rc.get(rodName)
        if info and type(info.Luck) == "number" then
            score = info.Luck
        end
    end
    if obj then
        score += (tonumber(obj:GetAttribute("Luck")) or 0)
        local enh = extractToolEnhancements(obj)
        score += (enh.Luck or 0)
    end
    return score
end

findEquippedRod = function(character)
    if not character then return nil end
    for _, child in ipairs(character:GetChildren()) do
        if isFishingRodTool(child) then
            return child
        end
    end
    return nil
end

findBestBackpackRod = function(backpack)
    if not backpack then return nil end
    local bestTool = nil
    local bestScore = -1
    for _, child in ipairs(backpack:GetChildren()) do
        if isFishingRodTool(child) then
            local rodName = child:GetAttribute("RodName") or child.Name
            local score = getRodNameScore(rodName, child)
            if not bestTool or score > bestScore then
                bestTool = child
                bestScore = score
            end
        end
    end
    return bestTool
end

local function getRodContentContainer()
    if not PlayerGui then return nil end
    local bpGui = PlayerGui:FindFirstChild("Backpack")
    if not bpGui then return nil end

    local inv = bpGui:FindFirstChild("Inventory")
    local content = inv and inv:FindFirstChild("ContentFrame")
    local rodContent = content and content:FindFirstChild("RodContent")
    if rodContent then
        return rodContent
    end
    return bpGui:FindFirstChild("RodContent", true)
end

local function findClickableInRodEntry(entry)
    if entry:IsA("GuiButton") then
        return entry
    end
    for _, name in ipairs({ "Button", "Click", "Equip", "Select", "Hitbox" }) do
        local btn = entry:FindFirstChild(name, true)
        if btn and btn:IsA("GuiButton") then
            return btn
        end
    end
    return entry:FindFirstChildWhichIsA("GuiButton", true) or entry
end

local function findBestRodContentTarget()
    local rodContent = getRodContentContainer()
    if not rodContent then return nil, nil end

    local rc = getRodConfig()
    getRodSkinConfig()

    local bestTarget = nil
    local bestScore = -1

    for _, entry in ipairs(rodContent:GetChildren()) do
        if entry:IsA("GuiObject") and entry.Visible then
            local lower = string.lower(entry.Name)
            if lower ~= "template" and lower ~= "example" and lower ~= "placeholder" then
                local rodName = entry:GetAttribute("RodName") or entry.Name
                local isKnownRod = (rc and type(rc.Rods) == "table" and rc.Rods[rodName] ~= nil)
                    or (cachedSkinDisplaySet and cachedSkinDisplaySet[rodName] == true)
                    or (entry:GetAttribute("FishRod") ~= nil)
                    or (entry:GetAttribute("RodName") ~= nil)
                    or string.find(lower, "rod", 1, true) ~= nil
                    or string.find(lower, "katana", 1, true) ~= nil
                    or (entry:IsA("GuiButton") or entry:FindFirstChildWhichIsA("GuiButton", true) ~= nil)

                if isKnownRod then
                    local score = getRodNameScore(rodName, entry)
                    if not bestTarget or score > bestScore then
                        bestTarget = entry
                        bestScore = score
                    end
                end
            end
        end
    end

    if bestTarget then
        return findClickableInRodEntry(bestTarget), bestTarget
    end
    return nil, nil
end

local equipRod
equipRod = function()
    if not enabledAutoEquip then return end
    local character = LocalPlayer.Character
    if not character then return end
    if findEquippedRod(character) then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local rodTool = findBestBackpackRod(backpack)
    if rodTool then
        pcall(function()
            humanoid:EquipTool(rodTool)
        end)
        return
    end

    local now = os.clock()
    if (now - lastUiRodClickAt) < 1.5 then return end

    local clickBtn, entryFrame = findBestRodContentTarget()
    if clickBtn then
        lastUiRodClickAt = now
        triggerImageButton(clickBtn)
        if entryFrame and entryFrame ~= clickBtn then
            triggerImageButton(entryFrame)
        end
        task.delay(0.35, function()
            if enabledAutoEquip and LocalPlayer.Character == character and not findEquippedRod(character) then
                local bp = LocalPlayer:FindFirstChild("Backpack")
                local newTool = findBestBackpackRod(bp)
                if newTool and humanoid and humanoid.Health > 0 then
                    pcall(function()
                        humanoid:EquipTool(newTool)
                    end)
                end
            end
        end)
    end
end

local function bindCharacterEvents(character)
    if not character then return end
    clearConnList(charConnections)
    waitingForBite = false
    biteActive = false
    biteHasReeled = false
    task.wait(1)
    equipRod()
    refreshWaterState(false)

    if enabledGameAutoCast then
        setGameAutoCast(true)
    end

    table.insert(charConnections, character.ChildRemoved:Connect(function(child)
        if isFishingRodTool(child) then
            task.defer(equipRod)
        end
    end))

    local backpack = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
    if backpack then
        table.insert(charConnections, backpack.ChildAdded:Connect(function(child)
            if isFishingRodTool(child) then
                task.defer(equipRod)
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
    local mouse = LocalPlayer:GetMouse()
    if mouse then
        fireSignalList(mouse.Button1Down)
        fireSignalList(mouse.Button1Up)
    end

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

    -- Refresh equipped bait state every 60s
    if (now - lastBaitRefreshAt) >= 60 then
        lastBaitRefreshAt = now
        refreshEquippedBaitFromServer()
    end

    -- Safety timeouts in case a server message is missed during lag
    if waitingForBite and (now - waitingSince) >= 11 then
        waitingForBite = false
    end
    if biteActive and (now - biteAt) >= 26 then
        biteActive = false
        biteHasReeled = false
    end

    -- Stuck-farm watchdog (45s with no server activity while near water)
    if enabledCast and not isFarmPausedNoWater and (now - lastServerActivityAt) >= 45 then
        lastServerActivityAt = now
        waitingForBite = false
        biteActive = false
        biteHasReeled = false
        if enabledAutoEquip then
            equipRod()
        end
    end

    -- Periodic water proximity check (every 1.2s when idle)
    if (enabledPauseNoWater or enabledSmartWaterAim) and not biteActive and (now - lastWaterCheckAt) >= 1.2 then
        lastWaterCheckAt = now
        refreshWaterState(true)
    end

    -- Periodic rod check (every 3s if rod isn't held yet)
    if enabledAutoEquip and not biteActive and (now - lastRodCheckAt) >= 3 then
        lastRodCheckAt = now
        if LocalPlayer.Character and not findEquippedRod(LocalPlayer.Character) then
            equipRod()
        end
    end

    -- 1. Smart Cast
    if enabledCast and isRemoteValid(CastRemote) then
        if not isFarmPausedNoWater and not biteActive and not waitingForBite and (now - lastCastSentAt) >= 0.06 then
            lastCastSentAt = now
            local targetVec = (enabledSmartWaterAim and cachedWaterDir) or castPos
            pcall(CastRemote.FireServer, CastRemote, targetVec, castPower)
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
    if enabledGameAutoCast and not isFarmPausedNoWater and (now - lastAutoCheckTime) >= 4 then
        lastAutoCheckTime = now
        if cachedAutoFishingButton and not isGameAutoCastOn() then
            setGameAutoCast(true)
        end
    end

    -- 7. Periodic Discord Stats Report
    if webhookState.Enabled and webhookState.PeriodicReport then
        if (now - webhookState.LastReportAt) >= (webhookState.IntervalMinutes * 60) then
            webhookState.LastReportAt = now
            enqueueWebhookEmbed(buildStatsReportEmbed())
        end
    end
end

function updateLoop()
    local shouldRun = (enabledCast or enabledClick or enabledReel or enabledFastSafeReel or enabledSell or enabledGameAutoCast or enabledAutoEquip or (webhookState.Enabled and webhookState.PeriodicReport))
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

-- ==================== UI SAFE ELEMENT HELPERS ====================
local function safeCreateStat(tab, opts)
    if tab and type(tab.CreateStat) == "function" then
        local okStat, handle = pcall(tab.CreateStat, tab, opts)
        if okStat and handle then
            return handle
        end
    end
    return nil
end

local function safeSetStat(handle, val)
    if handle and type(handle.Set) == "function" then
        pcall(handle.Set, handle, val)
    end
end

local function safeCreateParagraph(tab, title, content)
    if tab and type(tab.CreateParagraph) == "function" then
        local okPara, handle = pcall(tab.CreateParagraph, tab, { title = title, content = content })
        if okPara and handle then
            return handle
        end
    elseif tab and type(tab.CreateLabel) == "function" then
        local okLbl, handle = pcall(tab.CreateLabel, tab, title .. ": " .. content)
        if okLbl and handle then
            return handle
        end
    end
    return nil
end

local function safeSetParagraph(handle, title, content)
    if not handle or type(handle.Set) ~= "function" then return end
    local okSet = pcall(handle.Set, handle, { title = title, content = content })
    if not okSet then
        pcall(handle.Set, handle, title .. ": " .. content)
    end
end

-- ==================== UI ORGANIZATION (TABS) ====================
Window = Rayfield:CreateWindow({
    name = "Auto Fish",
    subtitle = string.format("v%s • Place %d", SCRIPT_VERSION, game.PlaceId),
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
    description = "Smart casts between catches (pauses while waiting for bite)",
    flag = "AutoCast",
    value = true,
    callback = function(value)
        enabledCast = value
        updateLoop()
    end,
})

AutomationTab:CreateToggle({
    name = "Pause Away From Water",
    description = "Automatically pauses farming when you move away from water",
    flag = "PauseAwayFromWater",
    value = true,
    callback = function(value)
        enabledPauseNoWater = value
        refreshWaterState(false)
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

colorReelToggleRef = AutomationTab:CreateToggle({
    name = "Color Reel",
    description = "Reels when the fill bar turns green (starts OFF; guarded by Fast Safe Reel)",
    flag = "ColorReel",
    value = false,
    callback = function(value)
        enabledColorReel = value
    end,
})

AutomationTab:CreateSection({ name = "Equipment, UI & Economy" })

AutomationTab:CreateToggle({
    name = "Auto Equip Rod",
    description = "Equips your best rod from Backpack or RodContent Inventory UI",
    flag = "AutoEquipRod",
    value = true,
    callback = function(value)
        enabledAutoEquip = value
        if value then equipRod() end
    end,
})

AutomationTab:CreateToggle({
    name = "Auto Close LevelUp UI",
    description = "Automatically dismisses the LevelUpUI popup when leveling up",
    flag = "AutoCloseLevelUp",
    value = true,
    callback = function(value)
        enabledAutoCloseLevelUp = value
        if value and PlayerGui then
            local lvlGui = PlayerGui:FindFirstChild("LevelUpUI")
            if lvlGui then closeLevelUpUI(lvlGui) end
        end
    end,
})

AutomationTab:CreateToggle({
    name = "Auto Sell",
    description = "Sells all fish on an interval (plus instant sell if bag is full)",
    flag = "AutoSell",
    value = false,
    callback = function(value)
        enabledSell = value
        if value then lastSellTime = 0 end
        updateLoop()
    end,
})

-- TAB 2: RATE MONITOR
local MonitorTab = Window:CreateTab({ name = "Rate Monitor" })

MonitorTab:CreateSection({ name = "Live Overview" })

statFishHrRef = safeCreateStat(MonitorTab, { name = "Fish / Hour (Live)", value = 0, numberEasing = false })
statXpHrRef = safeCreateStat(MonitorTab, { name = "XP / Hour", value = 0, numberEasing = false })
statCaughtRef = safeCreateStat(MonitorTab, { name = "Session Caught", value = 0, numberEasing = false })
statLevelRef = safeCreateStat(MonitorTab, { name = "Current Level", value = 0, numberEasing = false })

MonitorTab:CreateSection({ name = "Detailed Rates & Projections" })

paraRateRef = safeCreateParagraph(MonitorTab, "Fishing Efficiency & Fails", "Waiting for first catch...")
paraGearRef = safeCreateParagraph(MonitorTab, "Active Gear, Luck & Odds", "Loading gear configs...")
paraXpRef = safeCreateParagraph(MonitorTab, "XP & Level Estimates", "Calculating...")
paraPrimordialRef = safeCreateParagraph(MonitorTab, "Primordial Windows", "Checking Celestra / Thalvyra / Sore Kraken...")
paraRarityRef = safeCreateParagraph(MonitorTab, "Rarity Breakdown", "No catches yet.")

MonitorTab:CreateButton({
    name = "Reset Rate Monitor",
    callback = function()
        resetRateMonitor()
        if Window then
            Window:Notify({
                title = "Rate Monitor Reset",
                content = "Session statistics cleared.",
                duration = 2,
            })
        end
    end,
})

-- TAB 3: WEBHOOK
local WebhookTab = Window:CreateTab({ name = "Webhook" })

WebhookTab:CreateSection({ name = "Discord Configuration" })

WebhookTab:CreateInput({
    name = "Discord Webhook URL",
    value = webhookState.Url,
    placeholder = "https://discord.com/api/webhooks/...",
    flag = "DiscordWebhookUrl",
    callback = function(text)
        webhookState.Url = trimString(text)
    end,
})

WebhookTab:CreateToggle({
    name = "Enable Discord Webhook",
    description = "Auto-enables if getgenv().AutoFishWebhook is set",
    flag = "EnableDiscordWebhook",
    value = webhookState.Enabled,
    callback = function(value)
        webhookState.Enabled = value
        if value then
            webhookState.LastReportAt = os.clock()
        end
        updateLoop()
    end,
})

WebhookTab:CreateSection({ name = "Notifications & Reports" })

WebhookTab:CreateToggle({
    name = "Notify Rare Catches",
    description = "Alerts on Mythic, Secret, Supremacy, and Primordial catches",
    flag = "WebhookRareCatches",
    value = true,
    callback = function(value)
        webhookState.NotifyRareCatches = value
    end,
})

WebhookTab:CreateToggle({
    name = "Periodic Stats Summary",
    description = "Sends an overnight rate & progress embed on an interval",
    flag = "WebhookPeriodicReport",
    value = true,
    callback = function(value)
        webhookState.PeriodicReport = value
        if value then
            webhookState.LastReportAt = os.clock()
        end
        updateLoop()
    end,
})

WebhookTab:CreateSlider({
    name = "Summary Interval",
    range = { 5, 60 },
    increment = 5,
    value = 15,
    suffix = "m",
    flag = "WebhookIntervalMinutes",
    callback = function(value)
        webhookState.IntervalMinutes = value
    end,
})

WebhookTab:CreateToggle({
    name = "Alert on Pause / Fails / Disconnect",
    description = "Sends an alert if away from water, 5+ Invalid fails, or disconnect",
    flag = "WebhookAlerts",
    value = true,
    callback = function(value)
        webhookState.AlertOnIssues = value
    end,
})

WebhookTab:CreateButton({
    name = "Send Test Webhook",
    callback = function()
        if not isValidWebhookUrl(webhookState.Url) then
            Window:Notify({
                title = "Invalid Webhook URL",
                content = "Paste a valid https://discord.com/api/webhooks/... URL first.",
                duration = 3,
            })
            return
        end
        task.spawn(function()
            local embed = buildStatsReportEmbed("Test Stats Report (Auto Fish v" .. SCRIPT_VERSION .. ")", RARITY_COLORS.Report)
            embed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            embed.footer = { text = string.format("Saujana Auto Fish v%s • %s", SCRIPT_VERSION, LocalPlayer.Name) }
            local okSend, info = sendWebhookPayloadNow({ embeds = { embed } })
            Window:Notify({
                title = okSend and "Webhook Sent!" or "Webhook Failed",
                content = okSend and "Check your Discord channel." or tostring(info),
                duration = 4,
            })
        end)
    end,
})

-- TAB 4: SETTINGS & TIMING
local SettingsTab = Window:CreateTab({ name = "Settings" })

SettingsTab:CreateSection({ name = "Click & Cast Methods" })

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

SettingsTab:CreateToggle({
    name = "Smart Water Aim",
    description = "Aims CastRemote toward nearest detected water instead of Vector3.zero",
    flag = "SmartWaterAim",
    value = false,
    callback = function(value)
        enabledSmartWaterAim = value
        if value then
            refreshWaterState(false)
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

SettingsTab:CreateToggle({
    name = "Auto-Tune Ping Buffer",
    description = "Bumps +0.03s & locks floor on Invalid; trims -0.01s every 25 clean catches",
    flag = "AutoTunePingBuffer",
    value = true,
    callback = function(value)
        autoTunePingBuffer = value
    end,
})

pingBufferSliderRef = SettingsTab:CreateSlider({
    name = "Reel Ping Buffer",
    range = { 0.02, 0.50 },
    increment = 0.01,
    value = 0.08,
    suffix = "s",
    flag = "ReelPingBuffer",
    callback = function(value)
        pingBuffer = value
        if not isUpdatingPingSlider then
            autoTuneFloorBuffer = math.max(0.03, value)
            lastBufferAdjustAt = os.clock()
            consecutiveCatches = 0
        end
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

-- ==================== RATE MONITOR UPDATER LOOP ====================
local function formatPrimordialLine(cfg, label, curLevel, rodName, gear)
    if not cfg then
        return label .. ": Config loading..."
    end
    local nowEpoch = os.time()
    local okAct, active = pcall(cfg.isActive, nowEpoch)
    local timeText
    if okAct and active then
        local okLeft, left = pcall(cfg.secondsLeft, nowEpoch)
        timeText = "ACTIVE (" .. formatDuration(okLeft and left or 0) .. " left)"
    else
        local okUntil, untilSec = pcall(cfg.secondsUntil, nowEpoch)
        timeText = "Opens in " .. formatDuration(okUntil and untilSec or 0)
    end

    local reqLvl = cfg.RequireLevel or 0
    local lvlOk = (not curLevel) or (curLevel >= reqLvl)
    local rodOk = true
    if type(cfg.rodAllowed) == "function" and rodName then
        local okRod, resRod = pcall(cfg.rodAllowed, rodName)
        if okRod then rodOk = resRod end
    end

    local chanceStr = "--"
    if type(cfg.chance) == "function" then
        local okCh, baseProb = pcall(cfg.chance, gear.TotalLuck)
        if okCh and type(baseProb) == "number" and baseProb > 0 then
            local rodBonus = (gear.RodInfo and gear.RodInfo.PrimordialBonus and gear.RodInfo.PrimordialBonus[cfg.FishName or label]) or 0
            local finalProb = baseProb * (1 + rodBonus) * (gear.PrimordialMult or 1)
            chanceStr = formatOneIn(finalProb)
        end
    end

    local eligStr = (lvlOk and rodOk) and "Eligible" or (not lvlOk and ("Need Lv." .. reqLvl) or "Need Supremacy Rod")
    return string.format("%s: %s  |  %s  |  %s", label, timeText, chanceStr, eligStr)
end

task.spawn(function()
    local _, _, _, initTotalXp = readPlayerLevelAndXp()
    monitorState.StartObservedXp = initTotalXp

    while monitorState.Active do
        task.wait(1)
        if not monitorState.Active then break end

        local snap = buildRateSnapshot()
        local gear = getGearAndLuckSummary()
        local lvlCfg = getLevelConfig()

        safeSetStat(statFishHrRef, math.floor(snap.liveFishPerHr + 0.5))
        safeSetStat(statXpHrRef, math.floor(snap.xpPerHr + 0.5))
        safeSetStat(statCaughtRef, monitorState.TotalCaught)
        if snap.curLevel then
            safeSetStat(statLevelRef, snap.curLevel)
        end

        local statusText = isFarmPausedNoWater and "Paused (No water nearby)"
            or (enabledCast and "Active" or "Idle (Auto Cast OFF)")

        local tuningLabel = (reelTimingMode == "Auto-Tune (Best)")
            and (autoTuneUseFullTaps and "100% Locked" or "60% Aggressive")
            or reelTimingMode

        local rateContent = string.format(
            "Status: %s  |  Uptime: %s\n"
            .. "Last Catch: %s\n"
            .. "Caught: %s  |  Failed: %d (Success: %.1f%%)\n"
            .. "Fail Log: Invalid %d • Lost %d • Timeout %d • Full %d • Other %d\n"
            .. "Live Rate (2m): %.1f fish/min  (%s fish/hr)\n"
            .. "Session Avg: %.1f fish/min  (%s fish/hr)\n"
            .. "Avg Timings: Bite %.2fs • Reel %.2fs • Full Cycle %.2fs\n"
            .. "Tuning: %s  |  Ping Buffer: %.2fs (Floor: %.2fs)",
            statusText,
            formatClock(snap.elapsed),
            monitorState.LastFishText,
            formatNumber(monitorState.TotalCaught),
            monitorState.TotalFailed,
            snap.successPct,
            monitorState.FailReasons.Invalid or 0,
            monitorState.FailReasons.Lost or 0,
            monitorState.FailReasons.Timeout or 0,
            monitorState.FailReasons.Full or 0,
            monitorState.FailReasons.Other or 0,
            snap.liveFishPerMin,
            formatNumber(snap.liveFishPerHr),
            snap.sessionFishPerMin,
            formatNumber(snap.sessionFishPerHr),
            snap.avgBite,
            snap.avgReel,
            snap.avgCycle,
            tuningLabel,
            pingBuffer,
            autoTuneFloorBuffer
        )
        safeSetParagraph(paraRateRef, "Fishing Efficiency & Fails", rateContent)

        local enhText = (#gear.EnhanceNames > 0) and table.concat(gear.EnhanceNames, ", ")
            or (gear.EnhanceLuck > 0 and ("+" .. gear.EnhanceLuck .. " Luck") or "None")
        local gearContent = string.format(
            "Rod: %s (Luck %.2f • %d Taps • Max: %s)\n"
            .. "Enhance: %s  |  Bait: %s (+%.1f Luck)\n"
            .. "Global Luck: %.1fx  |  Effective Cast Luck: %.1fx\n"
            .. "Drop Odds: Mythic %s • Secret %s • Supremacy %s",
            gear.RodName,
            gear.RodLuck,
            gear.RodTaps,
            gear.RodMaxRarity,
            enhText,
            gear.BaitName,
            gear.BaitLuck,
            gear.GlobalLuck,
            gear.TotalLuck,
            formatOneIn(gear.MythicProb),
            formatOneIn(gear.SecretProb),
            formatOneIn(gear.SupremacyProb)
        )
        safeSetParagraph(paraGearRef, "Active Gear, Luck & Odds", gearContent)

        local levelLine
        local etaNextText = "--"
        local etaPlus10Text = "--"
        local etaNextRankText = "--"
        local etaMaxText = "--"

        if snap.curLevel and lvlCfg then
            local maxLvl = lvlCfg.MaxLevel or 2000
            local rankInfo = type(lvlCfg.rankFor) == "function" and lvlCfg.rankFor(snap.curLevel) or nil
            local rankTitle = rankInfo and rankInfo.Title or "Unknown"
            local xpReq = snap.curXpReq or (type(lvlCfg.xpToNext) == "function" and lvlCfg.xpToNext(snap.curLevel) or 0)
            local xpInto = snap.curXpInto or 0

            if snap.curLevel >= maxLvl then
                levelLine = string.format("Level: %d (MAX) • %s", snap.curLevel, rankTitle)
                etaNextText, etaPlus10Text, etaNextRankText, etaMaxText = "MAX", "MAX", "MAX", "MAX"
            else
                local pct = xpReq > 0 and ((xpInto / xpReq) * 100) or 0
                levelLine = string.format("Level: %d (%s)  |  XP: %s / %s (%.1f%%)", snap.curLevel, rankTitle, formatNumber(xpInto), formatNumber(xpReq), pct)

                if snap.xpPerSec > 0 and snap.curTotalXp and type(lvlCfg.totalForLevel) == "function" then
                    local nextNeed = math.max(0, lvlCfg.totalForLevel(snap.curLevel + 1) - snap.curTotalXp)
                    etaNextText = formatDuration(nextNeed / snap.xpPerSec)

                    local target10 = math.min(maxLvl, snap.curLevel + 10)
                    local need10 = math.max(0, lvlCfg.totalForLevel(target10) - snap.curTotalXp)
                    etaPlus10Text = string.format("%s (Lv %d)", formatDuration(need10 / snap.xpPerSec), target10)

                    local nextRankLvl = nil
                    if type(lvlCfg.Ranks) == "table" then
                        for _, r in ipairs(lvlCfg.Ranks) do
                            if r.Min > snap.curLevel then
                                nextRankLvl = r.Min
                                break
                            end
                        end
                    end
                    if nextRankLvl then
                        local needRank = math.max(0, lvlCfg.totalForLevel(nextRankLvl) - snap.curTotalXp)
                        etaNextRankText = string.format("%s (Lv %d)", formatDuration(needRank / snap.xpPerSec), nextRankLvl)
                    else
                        etaNextRankText = "Max Rank"
                    end

                    local needMax = math.max(0, lvlCfg.totalForLevel(maxLvl) - snap.curTotalXp)
                    etaMaxText = formatDuration(needMax / snap.xpPerSec)
                end
            end
        else
            levelLine = "Level: Waiting for Profile HUD / Attributes (using Fish + Playtime XP)"
            if snap.xpPerSec > 0 and lvlCfg and type(lvlCfg.xpToNext) == "function" then
                etaNextText = formatDuration(lvlCfg.xpToNext(1) / snap.xpPerSec) .. " (at Lv 1 rate)"
            end
        end

        local xpContent = string.format(
            "%s\n"
            .. "Source: %s  |  Session XP: +%s (Fish: +%s)\n"
            .. "XP Rate: %s XP/min  |  %s XP/hr\n"
            .. "Level Rate: %.2f Levels/hr\n"
            .. "ETA Next Lv: %s  |  Next Rank: %s\n"
            .. "ETA +10 Lvs: %s  |  Max (2000): %s",
            levelLine,
            snap.xpSourceLabel,
            formatNumber(snap.activeXpGain),
            formatNumber(monitorState.SessionFishXp),
            formatNumber(snap.xpPerMin),
            formatNumber(snap.xpPerHr),
            snap.levelsPerHr,
            etaNextText,
            etaNextRankText,
            etaPlus10Text,
            etaMaxText
        )
        safeSetParagraph(paraXpRef, "XP & Level Estimates", xpContent)

        local primText = string.format(
            "%s\n%s\n%s",
            formatPrimordialLine(getCelestraConfig(), "Celestra", snap.curLevel, gear.RodName, gear),
            formatPrimordialLine(getThalvyraConfig(), "Thalvyra", snap.curLevel, gear.RodName, gear),
            formatPrimordialLine(getSoreKrakenConfig(), "Sore Kraken", snap.curLevel, gear.RodName, gear)
        )
        safeSetParagraph(paraPrimordialRef, "Primordial Windows", primText)

        local rarityContent = string.format(
            "Common: %d  |  Uncommon: %d  |  Rare: %d  |  Epic: %d\n"
            .. "Mythic: %d  |  Secret: %d  |  Supremacy: %d  |  Primordial: %d",
            monitorState.RarityCounts.Common or 0,
            monitorState.RarityCounts.Uncommon or 0,
            monitorState.RarityCounts.Rare or 0,
            monitorState.RarityCounts.Epic or 0,
            monitorState.RarityCounts.Mythic or 0,
            monitorState.RarityCounts.Secret or 0,
            monitorState.RarityCounts.Supremacy or 0,
            monitorState.RarityCounts.Primordial or 0
        )
        safeSetParagraph(paraRarityRef, "Rarity Breakdown", rarityContent)
    end
end)

-- ==================== STARTUP SEQUENCE ====================
enabledCast = true
enabledFastSafeReel = true
enabledColorReel = false
enabledGameAutoCast = false
updateLoop()

if autoCastToggleRef and autoCastToggleRef.Set then
    autoCastToggleRef:Set(true)
end
if fastSafeReelToggleRef and fastSafeReelToggleRef.Set then
    fastSafeReelToggleRef:Set(true)
end
if colorReelToggleRef and colorReelToggleRef.Set then
    colorReelToggleRef:Set(false)
end
if gameAutoCastToggleRef and gameAutoCastToggleRef.Set then
    gameAutoCastToggleRef:Set(false)
end

-- Check water & ensure server-restored Game Auto Cast stays OFF at startup
task.defer(function()
    refreshWaterState(false)
    if not enabledGameAutoCast and cachedAutoFishingButton and isGameAutoCastOn() then
        setGameAutoCast(false)
    end
end)

print(string.format("[Auto Fish v%s] Ready: Fast Safe Reel, Ping Auto-Tune, Universal Rod, Rate Monitor & Webhook.", SCRIPT_VERSION))

task.defer(function()
    Window:Notify({
        title = "Auto Fish v" .. SCRIPT_VERSION,
        content = webhookState.Enabled
            and "Fast Safe Reel + Rate Monitor + Webhook Active"
            or "Fast Safe Reel + Rate Monitor Active",
        duration = 4,
    })
end)

