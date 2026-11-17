-- Saujana Auto Fish | Version 2.4.1 local SCRIPT_VERSION = "2.4.1"

if not game:IsLoaded() then
    game.Loaded:Wait() 
end

local TARGET_PLACE_ID = 89346234653070 if game.PlaceId ~= TARGET_PLACE_ID then
    warn(string.format("[Auto Fish] PlaceId mismatch! Expected %d, got %d —
aborting.", TARGET_PLACE_ID, game.PlaceId)) return 
end

print(string.format("========== AUTO FISH v%s STARTING ==========",
SCRIPT_VERSION))

if getgenv()._AutoFishCleanup then
    pcall(getgenv()._AutoFishCleanup)
    print("[Auto Fish] Cleaned up previous script instance.") 
end

-- ==================== SERVICES & CORE ==================== 
local Svc = {
Players = game:GetService("Players"), VirtualUser =
game:GetService("VirtualUser"), ReplicatedStorage =
game:GetService("ReplicatedStorage"), RunService =
game:GetService("RunService"), UIS = game:GetService("UserInputService"),
Collection = game:GetService("CollectionService"), Http =
game:GetService("HttpService"), Gui = game:GetService("GuiService"), }

local LocalPlayer = Svc.Players.LocalPlayer while not LocalPlayer do
    task.wait()
    LocalPlayer = Svc.Players.LocalPlayer 
end

-- ==================== ANTI-AFK MODULE ==================== if
getgenv()._AntiAFKState then
    getgenv()._AntiAFKState.Active = false 
end

local AntiAFKState = { Active = true, Interval = 120 } getgenv()._AntiAFKState =
AntiAFKState

local function sendAntiAFKPulse(sourceLabel) local success, err =
pcall(function() Svc.VirtualUser:CaptureController()
Svc.VirtualUser:ClickButton2(Vector2.zero) 
end
) if success then
    print(string.format("[Anti-AFK] %s pulse sent at %s", sourceLabel,
    os.date("%X"))) 
else
    warn(string.format("[Anti-AFK] %s failed: %s", sourceLabel,
    tostring(err))) 
end
end

task.spawn(function() print(string.format("[Anti-AFK] Initialized: Proactive
keep-alive active (every %d seconds).", AntiAFKState.Interval)) while
AntiAFKState.Active do
    task.wait(AntiAFKState.Interval) if not
    AntiAFKState.Active then
        break 
    end
    sendAntiAFKPulse("Keep-alive") 
end
print("[Anti-AFK] Worker thread safely exited.") 
end
)

-- ==================== LOAD RAYFIELD ==================== local ok, Rayfield
for attempt = 1, 3 do
    ok, Rayfield = pcall(function() return
    loadstring(game:HttpGet("https://sirius.menu/gen2"))() 
end
) if ok and Rayfield
then
    break 
end
warn(string.format("[Auto Fish] Rayfield attempt %d failed: %s",
attempt, tostring(Rayfield))) task.wait(2) 
end
if not ok or not Rayfield then
    AntiAFKState.Active = false warn("[Auto Fish] Rayfield failed to load after 3
attempts.") return 
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

-- ==================== CONSTANTS & CONFIG LOADERS ==================== local
CONST = { DEFAULT_MINIGAME = { StartingProgress = 0.4, MinSecondsPerTap = 0.06,
AutoSecondsPerTap = 0.1, AutoExtraTaps = 2, CastCooldown = 0.6, },
DEFAULT_FISH_XP = { Common = 5, Uncommon = 8, Rare = 15, Epic = 30, Mythic
= 120, Secret = 600, Supremacy = 3000, Primordial = 8000, }, RARITY_COLORS = {
Mythic = 0xFF6048, Secret = 0xFFD65A, Supremacy = 0xFF48D6, Primordial
= 0xAAFF00, Report = 0x3B82F6, Alert = 0xEF4444, Resume = 0x22C55E, },
NOTIFY_RARITIES = { Mythic = true, Secret = true, Supremacy = true, Primordial =
true }, CLOSE_KEYWORDS = { "close", "ok", "okay", "claim", "continue",
"confirm", "dismiss", "exit", "skip", "done" }, PRIMORDIAL_ORDER = {
"SoreKraken", "Thalvyra", "Celestra" }, PRIMORDIAL_SPOTS = { SoreKraken = { Key
= "SoreKraken", Name = "Sore Kraken", Priority = 3, -- Hardest / Rarest
(Difficulty 0.3012) Difficulty = 0.3012, CfgFunc = "soreKraken", StateName =
"SoreKrakenState", NotifUI = "SoreKrakenNotifUI", PreferRod = "Sore Kraken Rod",
UnlockAttr = "SoreKrakenUnlocked", CFrame = CFrame.new(-16547.748, 3776.079,
-4804.017, 0.3007, -0.0000, 0.9537, 0.0000, 1.0000, 0.0000,
-0.9537, 0.0000, 0.3007), }, Thalvyra = { Key = "Thalvyra", Name = "Thalvyra",
Priority = 2, -- Medium (Difficulty 0.6090) Difficulty = 0.6090, CfgFunc =
"thalvyra", StateName = "ThalvyraState", NotifUI = "ThalvyraNotifUI", PreferRod
= "Thalvyra Rod", UnlockAttr = "CrimsonUnlocked", CFrame =
CFrame.new(-16408.523, 4193.781, -2052.475, 0.7052, -0.0000,
-0.7090, 0.0000, 1.0000, -0.0000, 0.7090, 0.0000, 0.7052), }, Celestra = { Key =
"Celestra", Name = "Celestra", Priority = 1, -- Easiest (Difficulty 1.0000)
Difficulty = 1.0000, CfgFunc = "celestra", StateName = "CelestraState", NotifUI
= "CelestraNotifUI", PreferRod = "Celestra Rod", UnlockAttr = "NpcTalkedRevano",
CFrame = CFrame.new(-16322.375, 3885.807, -2916.187, 0.6414, 0.0000, 0.7672,
-0.0000, 1.0000, -0.0000, -0.7672, 0.0000, 0.6414), }, }, }

local Cache = { Configs = {}, States = {}, SkinDisplays = nil, FishingFrame =
nil, InfoLabel = nil, TapBtn = nil, TapText = nil, BarFill = nil, AutoBtn = nil,
}

local Cfg = {}

function Cfg.get(name) if Cache.Configs[name] then
    return Cache.Configs[name]
end
local shared = Svc.ReplicatedStorage:FindFirstChild("Shared") local
cfgFolder = shared and shared:FindFirstChild("Config") local mod = cfgFolder and
cfgFolder:FindFirstChild(name) if mod then
    local okCfg, tbl = pcall(require,
    mod) if okCfg and type(tbl) == "table" then
        Cache.Configs[name] = tbl return tbl
    end
end
return nil 
end

function Cfg.sharedMod(name) if Cache.States[name] then
    return
    Cache.States[name] 
end
local shared =
Svc.ReplicatedStorage:FindFirstChild("Shared") local mod = shared and
shared:FindFirstChild(name) if mod then
    local okMod, tbl = pcall(require, mod)
    if okMod and type(tbl) == "table" then
        Cache.States[name] = tbl return tbl 
    end
end
return nil 
end

function Cfg.fish() return Cfg.get("FishConfig") 
end
function Cfg.rod() return
Cfg.get("RodConfig") 
end
function Cfg.bait() return Cfg.get("BaitConfig") 
end
function Cfg.enhance() return Cfg.get("RodEnhanceConfig") 
end
function
Cfg.level() return Cfg.get("LevelConfig") 
end
function Cfg.celestra() return
Cfg.get("CelestraConfig") 
end
function Cfg.thalvyra() return
Cfg.get("ThalvyraConfig") 
end
function Cfg.soreKraken() return
Cfg.get("SoreKrakenConfig") 
end

function Cfg.minigame() local fc = Cfg.fish() return (fc and type(fc.Minigame)
== "table") and fc.Minigame or CONST.DEFAULT_MINIGAME 
end

function Cfg.rodSkin() local rsc = Cfg.get("RodSkinConfig") if rsc and not
Cache.SkinDisplays and type(rsc.Skins) == "table" then
    Cache.SkinDisplays = {}
    for k, info in pairs(rsc.Skins) do
        Cache.SkinDisplays[k] = true if type(info) ==
        "table" and type(info.Display) == "string" then
            Cache.SkinDisplays[info.Display]
            = true 
        end
    end
end
return rsc 
end

-- ==================== UTILITIES ==================== local Util = {}

function Util.trim(s) if type(s) ~= "string" then
    return "" 
end
return
string.match(s, "^%s*(.-)%s*$") or "" 
end

function Util.isValidWebhookUrl(url) local clean = Util.trim(url) return
string.match(clean, "^https?://[%w%.%-]+/api/webhooks/") ~= nil 
end

function Util.serverNow() local okT, t = pcall(workspace.GetServerTimeNow,
workspace) if okT and type(t) == "number" and t > 100000 then
    return
    math.floor(t) 
end
return os.time() 
end

function Util.formatNum(n) local num = math.floor((tonumber(n) or 0) + 0.5)
local neg = num < 0 local s = tostring(math.abs(num)) local formatted =
s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "") return neg and ("-"
.. formatted) or formatted 
end

function Util.formatDur(seconds) if not seconds or seconds ~= seconds or seconds
== math.huge then
    return "--" 
end
if seconds <= 0 then
    return "Now" 
end
local
total = math.floor(seconds + 0.5) local days = math.floor(total / 86400) local
hours = math.floor((total % 86400) / 3600) local mins = math.floor((total
% 3600) / 60) local secs = total % 60 if days > 0 then
    return string.format("%dd
%dh", days, hours) 
elseif hours > 0 then
        return string.format("%dh %dm", hours,
        mins) 
    elseif mins > 0 then
            return string.format("%dm %ds", mins, secs) 
        else
            return string.format("%ds", secs) 
        end
    end

    function Util.formatClock(seconds) local total = math.floor(math.max(0, seconds
    or 0)) return string.format("%02d:%02d:%02d", math.floor(total / 3600),
    math.floor((total % 3600) / 60), total % 60) 
end

function Util.formatOneIn(prob) if not prob or prob <= 0 then
    return "--" 
end
return "1 in " .. Util.formatNum(math.max(1, math.floor((1 / prob) + 0.5))) 
end

function Util.fireSignals(signalObj, ...) if not signalObj then
    return false 
end
local fired = false local args = table.pack(...) if getconnections then
    local
    okConns, conns = pcall(getconnections, signalObj) if okConns and conns and
    #conns > 0 then
        for _, conn in ipairs(conns) do
            local okFire = pcall(function()
            conn:Fire(table.unpack(args, 1, args.n)) 
        end
        ) if not okFire and args.n > 0 then
            okFire = pcall(function() conn:Fire() 
        end
        ) 
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
end
) if not okSig and
args.n > 0 then
    okSig = pcall(firesignal, signalObj) 
end
if okSig then
    fired =
    true 
end
end
return fired 
end

function Util.mockInput(state, x, y) return { UserInputType =
Enum.UserInputType.MouseButton1, UserInputState = state or
Enum.UserInputState.Begin, KeyCode = Enum.KeyCode.Unknown, Position =
Vector3.new(x or 0, y or 0, 0), Delta = Vector3.zero, } 
end

function Util.triggerBtn(btn) if not btn then
    return 
end
pcall(function() if
btn.Name == "TapMobile" then
    if not btn.Visible then
        btn.Visible = true 
    end
    if
    btn:IsA("GuiObject") and not btn.Active then
        btn.Active = true 
    end
end
local cx
= btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2) local cy =
btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2) local bIn =
Util.mockInput(Enum.UserInputState.Begin, cx, cy) local eIn =
Util.mockInput(Enum.UserInputState.End, cx, cy)

Util.fireSignals(btn.MouseButton1Down, cx, cy)
Util.fireSignals(btn.Activated, bIn, 1)
Util.fireSignals(btn.MouseButton1Click)
Util.fireSignals(btn.MouseButton1Up, cx, cy)
if btn:IsA("GuiButton") then
    pcall(function() Util.fireSignals(btn.TouchTap, { Vector2.new(cx, cy) }) 
end
)
end
if btn.Name == "TapMobile" or not btn:IsA("GuiButton") then
    Util.fireSignals(btn.InputBegan, bIn, false)
    Util.fireSignals(btn.InputEnded, eIn, false)
end
end
)

end

-- ==================== STATE, REMOTES, CONNECTIONS & UI REFS
==================== local Remotes = { Cast = nil, Reel = nil, SellAll = nil,
SetAuto = nil, GetState = nil, Server = nil } local Conns = { Global = {}, Char
= {}, LevelUp = {}, PrimNotif = {}, Gradient = nil, BarFill = nil, BarSize =
nil, InfoText = nil, FishingVis = nil, GuiDesc = nil, Server = nil, Heartbeat =
nil, } local UI = {}

local State = { EnabledCast = true, EnabledClick = false, EnabledReel = false,
EnabledFastSafeReel = true, EnabledColorReel = false, EnabledSell = false,
EnabledGameAutoCast = false, EnabledAutoEquip = true, EnabledAutoCloseLevelUp =
true, EnabledPauseNoWater = true, EnabledSmartWaterAim = false, LowPowerMode =
false, ClickMethod = "Button Signals", ReelTimingMode = "Auto-Tune (Best)",
AutoTunePingBuffer = true,

DetectedBait = nil,
LastBaitRefreshAt = 0,
LastClickTime = 0,
LastSellTime = 0,
LastCastSentAt = 0,
LastAutoBtnClick = 0,
LastAutoReelFire = 0,
LastAutoCheckTime = 0,
LastRemoteResolveTime = 0,
LastServerActivityAt = os.clock(),
LastLevelUpClose = 0,
LastUiRodClickAt = 0,
LastRodCheckAt = 0,
LastWaterCheckAt = 0,
IsSelling = false,
FishingOpenedAt = 0,
SawProgressBelowTarget = false,

IsNearWater = true,
IsFarmPausedNoWater = false,
CachedWaterDir = nil,

WaitingForBite = false,
WaitingSince = 0,
BiteActive = false,
BiteAt = 0,
BiteTaps = 13,
BiteIsAuto = false,
BiteHasReeled = false,
LastReelAttemptAt = 0,
SafeReelAt = 0,
PingBuffer = 0.08,
AutoTuneUseFullTaps = false,
AutoTuneFloorBuffer = 0.03,
LastBufferAdjustAt = 0,
ConsecutiveCatches = 0,
ConsecutiveInvalidFails = 0,
IsUpdatingPingSlider = false,

ClickDelay = 0.13,
ReelAt = 5,
SellInterval = 20,
CastPos = (typeof(vector) == "table" and vector.create) and vector.create(0, 0, 0) or Vector3.new(0, 0, 0),
CastPower = 1,

Primordial = {
Enabled = true,
PriorityMode = "Rarest First",
SwapEventRod = true,
ReturnHome = true,
CurrentEvent = nil,
HomeCFrame = nil,
IsTeleporting = false,
LastCheckAt = 0,
LastTeleportAt = 0,
ActivatedAt = {},
BlockedUntil = {},
NotifUntil = {},
},

}

do
    local envRaw = (type(getgenv) == "function" and getgenv().AutoFishWebhook) or
    "" local envUrl = Util.trim(envRaw) local envValid =
    Util.isValidWebhookUrl(envUrl) State.Webhook = { Active = true, Enabled =
    envValid, Url = envValid and envUrl or "", NotifyRareCatches = true,
    NotifyPrimordial = true, NotifyConnections = true, PeriodicReport = true,
    AlertOnIssues = true, IntervalMinutes = 15, LastReportAt = os.clock(),
    LastAlertAt = 0, Queue = {}, SentCount = 0, FailedCount = 0, } 
end

State.Monitor = { Active = true, SessionStart = os.clock(), TotalCaught = 0,
TotalFailed = 0, InvalidFails = 0, SessionFishXp = 0, StartObservedXp = nil,
LastCatchTime = 0, RecentCatches = {}, BiteWaitSum = 0, BiteWaitCount = 0,
ReelTimeSum = 0, ReelTimeCount = 0, CycleTimeSum = 0, CycleTimeCount = 0,
RarityCounts = {}, FailReasons = { Invalid = 0, Lost = 0, Timeout = 0, Full = 0,
Other = 0 }, LastFishText = "None yet", }

local function clearConnList(list) for _, conn in ipairs(list) do
    if conn and
    conn.Connected then
        conn:Disconnect() 
    end
end
table.clear(list) 
end

getgenv()._AutoFishCleanup = function() AntiAFKState.Active = false
State.Monitor.Active = false State.Webhook.Active = false if State.LowPowerMode
then
    State.LowPowerMode = false pcall(function()
    Svc.RunService:Set3dRenderingEnabled(true) 
end
) 
end
for _, k in ipairs({
"Heartbeat", "Server", "Gradient", "BarFill", "BarSize", "InfoText",
"FishingVis", "GuiDesc" }) do
    if Conns[k] then
        Conns[k]:Disconnect() Conns[k] =
        nil 
    end
end
clearConnList(Conns.PrimNotif) clearConnList(Conns.LevelUp)
clearConnList(Conns.Char) clearConnList(Conns.Global) 
end

table.insert(Conns.Global, LocalPlayer.Idled:Connect(function() if
AntiAFKState.Active then
    sendAntiAFKPulse("Idled backup") 
end
end
))

-- ==================== MONITOR, LEVEL, XP & GEAR MODULE ====================
local Monitor = {} local RodSys = {} local Webhook = {} local Primordial = {}

function Monitor.detectVip() for k, v in pairs(LocalPlayer:GetAttributes()) do
    local kl = string.lower(k) if (kl == "vip" or kl == "isvip" or kl == "hasvip" or
    kl == "gamepassvip") and v == true then
        return true 
    end
end
return false 
end

function Monitor.parseExpNum(str, expectedRef) if type(str) ~= "string" then
    return nil 
end
local s = string.gsub(str, "%s+", "") if s == "" then
    return nil
end

local numPart, suffix = string.match(s, "^([%d%.,]+)([kKmMbB])$")
if numPart and suffix then
    local val = tonumber((string.gsub(numPart, ",", ".")))
    if val then
        local sl = string.lower(suffix)
        if sl == "k" then
            return math.floor(val * 1000 + 0.5)
        elseif sl == "m" then
                return math.floor(val * 1000000 + 0.5)
            elseif sl == "b" then
                    return math.floor(val * 1000000000 + 0.5) 
                end
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

    function Monitor.readProfileHud() if not PlayerGui then
        return nil 
    end
    local g =
    PlayerGui:FindFirstChild("GameUI") local m = g and g:FindFirstChild("Menus")
    local p = m and m:FindFirstChild("Profile") local b = p and
    p:FindFirstChild("Body") local st = b and b:FindFirstChild("Stats2") local expF
    = st and st:FindFirstChild("Exp") if not expF then
        return nil 
    end

    local capL = expF:FindFirstChild("Caption")
    local cntL = expF:FindFirstChild("Count")
    if not capL or not cntL then
        return nil 
    end

    local capText = capL.ContentText or capL.Text or ""
    local cntText = cntL.ContentText or cntL.Text or ""
    if capText == "" or cntText == "" then
        return nil 
    end

    local lvlCfg = Cfg.level()
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
        local xpReq = Monitor.parseExpNum(rightStr, expectedReq) or expectedReq or 0
        local xpInto = Monitor.parseExpNum(leftStr, expectedReq) or 0
        if xpReq <= 0 and curLevel < maxLvl then
            return nil 
        end

        local totalXp = (lvlCfg and type(lvlCfg.totalForLevel) == "function")
        and (lvlCfg.totalForLevel(curLevel) + math.max(0, xpInto))
        or nil
        return curLevel, xpInto, xpReq, totalXp

    end

    function Monitor.readLevelXp() local hl, hi, hr, ht = Monitor.readProfileHud()
    if hl then
        return hl, hi, hr, ht, "Profile HUD" 
    end

    local lvlCfg = Cfg.level()
    local fLvl, fXp, fTot = nil, nil, nil
    for k, v in pairs(LocalPlayer:GetAttributes()) do
        if type(v) == "number" then
            local kl = string.lower(k)
            if kl == "totalxp" or kl == "totalexp" then
                fTot = v
            elseif kl == "level" or kl == "lvl" or kl == "fishlevel" then
                    fLvl = math.floor(v)
                elseif kl == "xp" or kl == "exp" or kl == "currentxp" then
                        fXp = v 
                    end
                end
            end

            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then
                for _, child in ipairs(ls:GetChildren()) do
                    if child:IsA("NumberValue") or child:IsA("IntValue") then
                        local nl = string.lower(child.Name)
                        if not fLvl and (nl == "level" or nl == "lvl") then
                            fLvl = math.floor(child.Value)
                        elseif not fTot and (nl == "totalxp" or nl == "totalexp") then
                                fTot = child.Value
                            elseif not fXp and (nl == "xp" or nl == "exp") then
                                    fXp = child.Value 
                                end
                            end
                        end
                    end

                    if lvlCfg and type(lvlCfg.fromXp) == "function" and type(lvlCfg.totalForLevel) == "function" then
                        if fTot then
                            local l, i, r = lvlCfg.fromXp(fTot)
                            return l, i, r, fTot, "Attributes"
                        elseif fLvl and fXp then
                                local req = lvlCfg.xpToNext(fLvl)
                                if fXp >= req and lvlCfg.fromXp(fXp) == fLvl then
                                    local l, i, r = lvlCfg.fromXp(fXp)
                                    return l, i, r, fXp, "Attributes"
                                else
                                    return fLvl, math.max(0, fXp), req, lvlCfg.totalForLevel(fLvl) + math.max(0, fXp), "Attributes"
                                end
                            elseif fLvl then
                                    return fLvl, 0, lvlCfg.xpToNext(fLvl), lvlCfg.totalForLevel(fLvl), "Attributes"
                                elseif fXp then
                                        local l, i, r = lvlCfg.fromXp(fXp)
                                        return l, i, r, fXp, "Attributes"
                                    end
                                end
                                return fLvl, fXp, nil, fTot, "Estimated"

                            end

                            function Monitor.avgLevelsPerHour(curLvl, curTotXp, xpHr) if xpHr <= 0 then
                                return 0 
                            end
                            local lvlCfg = Cfg.level() if not lvlCfg or type(lvlCfg.fromXp) ~=
                            "function" or type(lvlCfg.xpToNext) ~= "function" then
                                return 0 
                            end
                            if curLvl
                            and curTotXp then
                                if curLvl >= (lvlCfg.MaxLevel or 2000) then
                                    return 0 
                                end
                                local
                                fLvl, fInto = lvlCfg.fromXp(curTotXp + xpHr) local cReq = math.max(1,
                                lvlCfg.xpToNext(curLvl)) local fReq = math.max(1, lvlCfg.xpToNext(fLvl)) local
                                cEx = curLvl + ((curTotXp - lvlCfg.totalForLevel(curLvl)) / cReq) local fEx =
                                fLvl + (fReq > 0 and (fInto / fReq) or 0) return math.max(0, fEx - cEx) 
                            end
                            return xpHr / math.max(1, lvlCfg.xpToNext(1)) 
                        end

                        function Monitor.extractEnhances(tool) local enhanceCfg = Cfg.enhance() local
                        directLuck = tool and tonumber(tool:GetAttribute("EnhanceLuck")) or nil local
                        res = { Luck = directLuck or 0, SecretMult = 1, SupremacyMult = 1,
                        PrimordialMult = 1, Names = {} } if not tool then
                            return res 
                        end

                        local slots = {}
                        for _, attr in ipairs({ "Enhance", "Enhance1", "Enhance2", "Enhance3", "Enchant", "Enchant1", "Enchant2", "Enchant3" }) do
                            local val = tool:GetAttribute(attr)
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
                            local comb = enhanceCfg.combine(slots)
                            if comb then
                                if directLuck == nil then
                                    res.Luck = comb.Luck or 0 
                                end
                                res.SecretMult = comb.SecretMult or 1
                                res.SupremacyMult = comb.SupremacyMult or 1
                                res.PrimordialMult = comb.PrimordialMult or 1
                                res.Names = slots
                            end
                        elseif #slots > 0 then
                                res.Names = slots
                            end
                            return res

                        end

                        function Monitor.refreshBait() if Remotes.GetState and Remotes.GetState.Parent
                        then
                            task.spawn(function() local okS, st = pcall(Remotes.GetState.InvokeServer,
                            Remotes.GetState) if okS and type(st) == "table" and type(st.equippedBait) ==
                            "string" and st.equippedBait ~= "" then
                                State.DetectedBait = st.equippedBait 
                            end
                        end
                        ) 
                    end
                end

                function Monitor.getBaitName() for _, attr in ipairs({ "EquippedBait", "Bait",
                "CurrentBait", "FishBait" }) do
                    local val = LocalPlayer:GetAttribute(attr) if
                    type(val) == "string" and val ~= "" then
                        return val 
                    end
                end
                if
                type(State.DetectedBait) == "string" and State.DetectedBait ~= "" then
                    return
                    State.DetectedBait 
                end
                local bc = Cfg.bait() return (bc and bc.Default) or
                "Basic Bait" 
            end

            function Monitor.getGearSummary() local rc, bc, fc = Cfg.rod(), Cfg.bait(),
            Cfg.fish() local activeTool = RodSys.findEquipped(LocalPlayer.Character) or
            RodSys.findBestBackpack(LocalPlayer:FindFirstChild("Backpack")) local rodName =
            (activeTool and (activeTool:GetAttribute("RodName") or activeTool.Name)) or (rc
            and rc.Default) or "Basic Rod" local rodInfo = (rc and type(rc.get) ==
            "function" and rc.get(rodName)) or nil local rodLuck = (rodInfo and
            tonumber(rodInfo.Luck)) or 1 local rodTaps = (rodInfo and
            tonumber(rodInfo.Taps)) or 17 local rodMaxRar = (rodInfo and rodInfo.MaxRarity)
            or "Epic"

            local enh = Monitor.extractEnhances(activeTool)
            local baitName = Monitor.getBaitName()
            local baitInfo = (bc and type(bc.get) == "function" and bc.get(baitName)) or nil
            local baitLuck = (baitInfo and tonumber(baitInfo.Luck)) or 2

            local globalLuck = math.max(1, tonumber(Svc.ReplicatedStorage:GetAttribute("FishGlobalLuck")) or 0)
            local totalLuck = ((rodLuck + enh.Luck) * (1 + State.CastPower * 0.2) + baitLuck) * globalLuck

            local mP, sP, supP = 0, 0, 0
            if fc and type(fc.topEffective) == "function" and type(fc.RarityOrder) == "table" then
                local ord = fc.RarityOrder[rodMaxRar] or 4
                if ord >= 5 then
                    mP = fc.topEffective("Mythic", totalLuck, 1, 0, 1) 
                end
                if ord >= 6 then
                    sP = fc.topEffective("Secret", totalLuck, 1, 0, enh.SecretMult) 
                end
                if ord >= 7 then
                    supP = fc.topEffective("Supremacy", totalLuck, 1, 0, enh.SupremacyMult) 
                end
            end

            return {
            RodName = rodName, RodInfo = rodInfo, RodLuck = rodLuck, RodTaps = rodTaps, RodMaxRarity = rodMaxRar,
            EnhanceLuck = enh.Luck, EnhanceNames = enh.Names, PrimordialMult = enh.PrimordialMult,
            BaitName = baitName, BaitLuck = baitLuck, GlobalLuck = globalLuck, TotalLuck = totalLuck,
            MythicProb = mP, SecretProb = sP, SupremacyProb = supP,
            }

        end

        function Monitor.snapshot() local now = os.clock() local m = State.Monitor local
        elapsed = math.max(1, now - m.SessionStart) local eMin, eHr = elapsed / 60,
        elapsed / 3600

        while #m.RecentCatches > 0 and (now - m.RecentCatches[1]) > 120 do
            table.remove(m.RecentCatches, 1)
        end

        local rollWin = math.min(120, math.max(15, elapsed))
        local liveMin = (#m.RecentCatches / rollWin) * 60
        local liveHr = liveMin * 60
        local sessMin = m.TotalCaught / eMin
        local sessHr = m.TotalCaught / eHr
        local totAtt = m.TotalCaught + m.TotalFailed
        local sucPct = totAtt > 0 and ((m.TotalCaught / totAtt) * 100) or 100

        local lvlCfg = Cfg.level()
        local curLvl, curInto, curReq, curTot, xpHudSrc = Monitor.readLevelXp()
        if not m.StartObservedXp and curTot then
            m.StartObservedXp = curTot 
        end

        local playXp = eMin * ((lvlCfg and lvlCfg.XpPerMinute) or 10)
        local estXp = m.SessionFishXp + playXp
        local obsGain = (curTot and m.StartObservedXp) and math.max(0, curTot - m.StartObservedXp) or 0
        local activeXp = obsGain > 0 and obsGain or estXp
        local xpSrc = obsGain > 0 and (xpHudSrc or "Live XP") or "FishConfig + Playtime"

        return {
        elapsed = elapsed, liveFishPerMin = liveMin, liveFishPerHr = liveHr,
        sessionFishPerMin = sessMin, sessionFishPerHr = sessHr, successPct = sucPct,
        avgBite = m.BiteWaitCount > 0 and (m.BiteWaitSum / m.BiteWaitCount) or 0,
        avgReel = m.ReelTimeCount > 0 and (m.ReelTimeSum / m.ReelTimeCount) or 0,
        avgCycle = m.CycleTimeCount > 0 and (m.CycleTimeSum / m.CycleTimeCount) or 0,
        curLevel = curLvl, curXpInto = curInto, curXpReq = curReq, curTotalXp = curTot,
        activeXpGain = activeXp, xpSourceLabel = xpSrc,
        xpPerMin = activeXp / eMin, xpPerHr = activeXp / eHr, xpPerSec = activeXp / elapsed,
        levelsPerHr = Monitor.avgLevelsPerHour(curLvl, curTot, activeXp / eHr),
        }

    end

    function Monitor.reset() local m = State.Monitor m.SessionStart = os.clock()
    m.TotalCaught, m.TotalFailed, m.InvalidFails, m.SessionFishXp, m.LastCatchTime
    = 0, 0, 0, 0, 0 table.clear(m.RecentCatches) m.BiteWaitSum, m.BiteWaitCount,
    m.ReelTimeSum, m.ReelTimeCount, m.CycleTimeSum, m.CycleTimeCount
    = 0, 0, 0, 0, 0, 0 table.clear(m.RarityCounts) m.FailReasons = { Invalid = 0,
    Lost = 0, Timeout = 0, Full = 0, Other = 0 } m.LastFishText = "None yet" local
    _, _, _, tot = Monitor.readLevelXp() m.StartObservedXp = tot 
end

-- ==================== DISCORD WEBHOOK MODULE ==================== function
Webhook.getHttpFuncs() local list, seen = {}, {} local candidates = { request,
http_request, http and http.request, syn and syn.request, fluxus and
fluxus.request } for i = 1, 5 do
    local fn = candidates[i] if type(fn) ==
    "function" and not seen[fn] then
        seen[fn] = true table.insert(list, fn) 
    end
end
return list 
end

function Webhook.extractStatus(res) if type(res) ~= "table" then
    return 0,
    "Non-table response" 
end
local raw = res.StatusCode or res.status_code or
res.statusCode or res.Status or res.status or res.code or res.Code local code =
tonumber(raw) or 0 if code == 0 and res.Success == true then
    code = 200 
end
local detail = res.StatusMessage or res.status_message or res.Error or res.error
or res.Body or res.body or "" if type(detail) ~= "string" then
    detail =
    tostring(detail) 
end
if #detail > 140 then
    detail = string.sub(detail, 1, 140)
    .. "..." 
end
return code, detail 
end

function Webhook.enqueue(embed) local w = State.Webhook if not w.Enabled or not
Util.isValidWebhookUrl(w.Url) then
    return 
end
if #w.Queue >= 25 then
    table.remove(w.Queue, 1) 
end
embed.timestamp = embed.timestamp or
os.date("!%Y-%m-%dT%H:%M:%SZ") embed.footer = embed.footer or { text =
string.format("Saujana Auto Fish v%s • %s", SCRIPT_VERSION, LocalPlayer.Name) }
table.insert(w.Queue, { embeds = { embed } }) 
end

function Webhook.sendNow(payload) local funcs = Webhook.getHttpFuncs() if #funcs
== 0 then
    return false, "Executor has no HTTP request function" 
end

local cleanUrl = Util.trim(State.Webhook.Url)
if not Util.isValidWebhookUrl(cleanUrl) then
    return false, "Invalid Discord Webhook URL" 
end

local okEnc, jsonBody = pcall(Svc.Http.JSONEncode, Svc.Http, payload)
if not okEnc then
    return false, "JSON encode failed" 
end

local urls = { cleanUrl }
if (string.find(cleanUrl, "discord.com/api/webhooks/", 1, true) or string.find(cleanUrl, "discordapp.com/api/webhooks/", 1, true))
and not string.find(cleanUrl, "wait=", 1, true) then
    local sep = string.find(cleanUrl, "?", 1, true) and "&" or "?"
    table.insert(urls, cleanUrl .. sep .. "wait=true")
end

local lastErr = "HTTP 0"
for _, targetUrl in ipairs(urls) do
    for _, reqFn in ipairs(funcs) do
        local okReq, res = pcall(reqFn, {
        Url = targetUrl, Method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["Accept"] = "application/json" },
        Body = jsonBody,
        })
        if okReq then
            local code, detail = Webhook.extractStatus(res)
            if code >= 200 and code < 300 then
                State.Webhook.SentCount += 1
                return true, code
            elseif code == 429 then
                    local retryAfter = 3
                    if type(res) == "table" and type(res.Body) == "string" then
                        local okDec, dec = pcall(Svc.Http.JSONDecode, Svc.Http, res.Body)
                        if okDec and type(dec) == "table" and tonumber(dec.retry_after) then
                            retryAfter = math.clamp(tonumber(dec.retry_after), 1, 15)
                        end
                    end
                    task.wait(retryAfter)
                    return false, "429 Rate Limited"
                elseif code > 0 then
                        State.Webhook.FailedCount += 1
                        local errMsg = (detail ~= "" and string.format("HTTP %d (%s)", code, detail)) or ("HTTP " .. tostring(code))
                        warn("[Auto Fish Webhook] " .. errMsg)
                        return false, errMsg
                    else
                        lastErr = (detail ~= "" and string.format("HTTP 0 (%s)", detail)) or "HTTP 0 (Request blocked or no response)"
                    end
                else
                    lastErr = tostring(res)
                end
            end
        end

        State.Webhook.FailedCount += 1
        warn("[Auto Fish Webhook] " .. lastErr)
        return false, lastErr

    end

    function Webhook.buildReport(titleOverride, colorOverride) local snap =
    Monitor.snapshot() local gear = Monitor.getGearSummary() local lvlCfg =
    Cfg.level() local m = State.Monitor

    local statusText = State.IsFarmPausedNoWater and "Paused (Away from water)"
    or (State.EnabledCast and "Active" or "Idle (Auto Cast OFF)")

    local locText = "Normal Spot"
    if State.Primordial.CurrentEvent then
        local sp = CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent]
        local cfg = sp and Cfg[sp.CfgFunc]()
        local leftSec = (cfg and type(cfg.secondsLeft) == "function") and cfg.secondsLeft(Util.serverNow()) or 0
        locText = string.format("%s (%s left)", sp.Name, Util.formatDur(leftSec))
    end

    local levelText, etaNext = "N/A", "--"
    if snap.curLevel and lvlCfg then
        local rInfo = type(lvlCfg.rankFor) == "function" and lvlCfg.rankFor(snap.curLevel) or nil
        local rTitle = rInfo and rInfo.Title or ""
        local xpReq = snap.curXpReq or (type(lvlCfg.xpToNext) == "function" and lvlCfg.xpToNext(snap.curLevel) or 0)
        levelText = string.format("Lv. %d (%s)\n%s / %s XP", snap.curLevel, rTitle, Util.formatNum(snap.curXpInto or 0), Util.formatNum(xpReq))
        if snap.xpPerSec > 0 and snap.curTotalXp and type(lvlCfg.totalForLevel) == "function" and snap.curLevel < (lvlCfg.MaxLevel or 2000) then
            local nextNeed = math.max(0, lvlCfg.totalForLevel(snap.curLevel + 1) - snap.curTotalXp)
            etaNext = Util.formatDur(nextNeed / snap.xpPerSec)
        end
    end

    local rarText = string.format(
    "Common: %d | Uncommon: %d | Rare: %d | Epic: %d\nMythic: %d | Secret: %d | Supremacy: %d | Primordial: %d",
    m.RarityCounts.Common or 0, m.RarityCounts.Uncommon or 0, m.RarityCounts.Rare or 0, m.RarityCounts.Epic or 0,
    m.RarityCounts.Mythic or 0, m.RarityCounts.Secret or 0, m.RarityCounts.Supremacy or 0, m.RarityCounts.Primordial or 0
    )

    return {
    title = titleOverride or "Overnight Farm Report",
    color = colorOverride or CONST.RARITY_COLORS.Report,
    fields = {
    { name = "Player & Status", value = string.format("%s (@%s)\n%s • Uptime: %s\nLocation: %s", LocalPlayer.DisplayName, LocalPlayer.Name, statusText, Util.formatClock(snap.elapsed), locText), inline = true },
    { name = "Gear & Luck", value = string.format("%s • %s\nTotal Luck: %.1fx (Global %.1fx)", gear.RodName, gear.BaitName, gear.TotalLuck, gear.GlobalLuck), inline = true },
    { name = "Catch Rates", value = string.format("Live: **%s/hr** (%.1f/m)\nAvg: %s/hr | Cycle: %.2fs", Util.formatNum(snap.liveFishPerHr), snap.liveFishPerMin, Util.formatNum(snap.sessionFishPerHr), snap.avgCycle), inline = true },
    { name = "Session Totals", value = string.format("Caught: **%s**\nFailed: %d (Inv: %d) • %.1f%%", Util.formatNum(m.TotalCaught), m.TotalFailed, m.InvalidFails, snap.successPct), inline = true },
    { name = "Level & XP", value = string.format("%s\n%s XP/hr (%.2f Lv/hr) • Next: %s", levelText, Util.formatNum(snap.xpPerHr), snap.levelsPerHr, etaNext), inline = true },
    { name = "Tuning", value = string.format("Mode: %s\nPing Buffer: %.2fs (Floor: %.2fs)", State.AutoTuneUseFullTaps and "100% Locked" or "60% Auto-Tune", State.PingBuffer, State.AutoTuneFloorBuffer), inline = true },
    { name = "Rarity Breakdown", value = rarText, inline = false },
    },
    }

end

function Webhook.rareCatch(fishName, rarity, weightKg, rawChance) local w =
State.Webhook if not w.Enabled or not w.NotifyRareCatches or not
CONST.NOTIFY_RARITIES[rarity] then
    return 
end

local fc = Cfg.fish()
local oneInVal = tonumber(rawChance)
if not oneInVal and fc and type(fc.oneIn) == "function" then
    oneInVal = fc.oneIn(fishName) 
end
local chanceText = (oneInVal and oneInVal > 0) and ("1 in " .. Util.formatNum(oneInVal)) or "Rare Drop"
if weightKg then
    chanceText = string.format("%s • %.1f kg", chanceText, weightKg) 
end

local snap = Monitor.snapshot()
local gear = Monitor.getGearSummary()
local levelStr = snap.curLevel and string.format("Lv. %d (%s XP/hr)", snap.curLevel, Util.formatNum(snap.xpPerHr)) or (Util.formatNum(snap.xpPerHr) .. " XP/hr")

Webhook.enqueue({
title = string.format("[%s] %s Caught!", tostring(rarity), tostring(fishName)),
color = CONST.RARITY_COLORS[rarity] or CONST.RARITY_COLORS.Report,
fields = {
{ name = "Player", value = string.format("%s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name), inline = true },
{ name = "Rarity", value = tostring(rarity), inline = true },
{ name = "Odds / Info", value = chanceText, inline = true },
{ name = "Live Rate", value = string.format("%s fish/hr (%.1f/m)", Util.formatNum(snap.liveFishPerHr), snap.liveFishPerMin), inline = true },
{ name = "Level & XP", value = levelStr, inline = true },
{ name = "Session Stats", value = string.format("Caught: %s | Fails: %d (%.1f%%)\nUptime: %s • %s (%.1fx)", Util.formatNum(State.Monitor.TotalCaught), State.Monitor.TotalFailed, snap.successPct, Util.formatClock(snap.elapsed), gear.RodName, gear.TotalLuck), inline = false },
},
})

end

function Webhook.connected() local w = State.Webhook if not w.Enabled or not
w.NotifyConnections then
    return 
end
local snap = Monitor.snapshot() local gear =
Monitor.getGearSummary() local shortJob = string.sub(tostring(game.JobId or
"Private/Local"), 1, 12) local lvlStr = snap.curLevel and ("Lv. " ..
tostring(snap.curLevel)) or "Loading" local evStr =
State.Primordial.CurrentEvent and
CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent].Name or "Normal Spot"

Webhook.enqueue({
title = "Connected / Session Online",
color = CONST.RARITY_COLORS.Resume,
fields = {
{ name = "Player", value = string.format("%s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name), inline = true },
{ name = "Level & Server", value = string.format("%s • Job `%s`", lvlStr, shortJob), inline = true },
{ name = "Gear & Location", value = string.format("%s • %s (%.1fx)\nLocation: %s", gear.RodName, gear.BaitName, gear.TotalLuck, evStr), inline = false },
},
})

end

function Webhook.primordial(title, desc, color) local w = State.Webhook if not
w.Enabled or not w.NotifyPrimordial then
    return 
end
Webhook.enqueue({ title =
title, description = desc, color = color or CONST.RARITY_COLORS.Primordial })
end

function Webhook.alert(title, message, color, force) local w = State.Webhook if
not w.Enabled or not w.AlertOnIssues then
    return 
end
local now = os.clock() if
not force and (now - w.LastAlertAt) < 30 then
    return 
end
w.LastAlertAt = now
Webhook.enqueue({ title = title, description = message, color = color or
CONST.RARITY_COLORS.Alert }) 
end

task.spawn(function() while State.Webhook.Active do
    local w = State.Webhook if
    #w.Queue > 0 and w.Enabled and Util.isValidWebhookUrl(w.Url) then
        local
        nextPayload = table.remove(w.Queue, 1) local okSend =
        Webhook.sendNow(nextPayload) task.wait(okSend and 1.5 or 2.5) 
    else
        task.wait(0.5) 
    end
end
end
)

-- ==================== WATER DETECTION & GAME AUTO CAST ====================
local function isWaterRaycastHit(hit) if not hit then
    return false 
end
if
hit.Material == Enum.Material.Water then
    return true 
end
local inst =
hit.Instance for _ = 1, 4 do
    if not inst or inst == workspace then
        break 
    end
    if
    inst:IsA("BasePart") and inst.Material == Enum.Material.Water then
        return true
    end
    if Svc.Collection:HasTag(inst, "FishWater") or
    inst:GetAttribute("FishWater") == true then
        return true 
    end
    local lower =
    string.lower(inst.Name) if lower == "fishwater" or lower == "water" or lower ==
    "air" then
        return true 
    end
    inst = inst.Parent 
end
return false 
end

local function refreshWaterState(forceNotify) local char = LocalPlayer.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart") local found, dir =
false, nil

if hrp then
    local exclude = {}
    for _, plr in ipairs(Svc.Players:GetPlayers()) do
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
                dir = flat.Magnitude > 0.5 and flat.Unit or nil
                found = true
                break
            end
        end
        if found then
            break 
        end
    end
end

State.IsNearWater = found
State.CachedWaterDir = dir

if State.EnabledPauseNoWater then
    if not found and not State.IsFarmPausedNoWater then
        State.IsFarmPausedNoWater = true
        State.WaitingForBite = false
        Webhook.alert("Farm Paused (Away From Water)", "Character moved away from water. Waiting to return.", CONST.RARITY_COLORS.Alert)
        if UI.Window and forceNotify ~= false then
            task.defer(function()
            UI.Window:Notify({ title = "Farm Paused", content = "Moved away from water — waiting to return", duration = 3 })
        end
        )
    end
elseif found and State.IsFarmPausedNoWater then
        State.IsFarmPausedNoWater = false
        Webhook.alert("Farm Resumed", "Water detected nearby — casting resumed.", CONST.RARITY_COLORS.Resume)
        if UI.Window and forceNotify ~= false then
            task.defer(function()
            UI.Window:Notify({ title = "Farm Resumed", content = "Water detected nearby — casting resumed", duration = 3 })
        end
        )
    end
end
else
    State.IsFarmPausedNoWater = false
end

end

local function isGradientGreen(uiGrad) if not uiGrad then
    return false 
end
local
kps = uiGrad.Color.Keypoints return #kps > 0 and kps[1].Value.G > kps[1].Value.R
end

local function isGameAutoCastOn() local btn = Cache.AutoBtn if not btn then
    return false 
end
local uiGrad = btn:FindFirstChildOfClass("UIGradient") if
uiGrad then
    return isGradientGreen(uiGrad) 
end
local col =
btn:IsA("ImageButton") and btn.ImageColor3 or btn.BackgroundColor3 return (col.G
> 0.6 and col.G > col.R) 
end

local function setGameAutoCast(targetState) if Cache.AutoBtn then
    if
    isGameAutoCastOn() ~= targetState then
        State.LastAutoBtnClick = os.clock()
        Util.triggerBtn(Cache.AutoBtn) 
    end
elseif Remotes.SetAuto and
    Remotes.SetAuto.Parent then
        task.spawn(function() pcall(function()
        Remotes.SetAuto:InvokeServer(targetState) 
    end
    ) 
end
) 
end
end

local function enforceGameAutoCast(uiGrad) if State.EnabledGameAutoCast and not
isGradientGreen(uiGrad) then
    local now = os.clock() if (now -
    State.LastAutoBtnClick) >= 0.5 then
        State.LastAutoBtnClick = now
        setGameAutoCast(true) 
    end
end
end

local function bindAutoGradient(autoBtn) if Conns.Gradient then
    Conns.Gradient:Disconnect() Conns.Gradient = nil 
end
if not autoBtn then
    return
end
local uiGrad = autoBtn:FindFirstChildOfClass("UIGradient") if uiGrad then
    Conns.Gradient = uiGrad:GetPropertyChangedSignal("Color"):Connect(function()
    enforceGameAutoCast(uiGrad) 
end
) enforceGameAutoCast(uiGrad) 
end
end

-- ==================== LEVELUP UI AUTO-CLOSER ==================== local
function closeLevelUpUI(gui) if not State.EnabledAutoCloseLevelUp or not gui or
not gui.Parent then
    return 
end
local now = os.clock() if (now -
State.LastLevelUpClose) < 0.15 then
    return 
end

local isVisible = (gui:IsA("LayerCollector") and gui.Enabled)
if not isVisible then
    for _, child in ipairs(gui:GetChildren()) do
        if child:IsA("GuiObject") and child.Visible then
            isVisible = true break 
        end
    end
end
if not isVisible then
    return 
end

State.LastLevelUpClose = now
for _, desc in ipairs(gui:GetDescendants()) do
    if desc:IsA("GuiButton") and desc.Visible then
        local nl = string.lower(desc.Name)
        local tl = desc:IsA("TextButton") and string.lower(desc.Text or "") or ""
        local match = (nl == "x" or tl == "x")
        if not match then
            for _, kw in ipairs(CONST.CLOSE_KEYWORDS) do
                if string.find(nl, kw, 1, true) or string.find(tl, kw, 1, true) then
                    match = true
                    break
                end
            end
        end
        if match then
            Util.triggerBtn(desc) 
        end
    end
end

task.delay(0.1, function()
if not State.EnabledAutoCloseLevelUp or not gui or not gui.Parent then
    return 
end
pcall(function()
if gui:IsA("LayerCollector") then
    gui.Enabled = false 
end
for _, child in ipairs(gui:GetChildren()) do
    if child:IsA("GuiObject") and child.Visible then
        child.Visible = false 
    end
end
end
)
end
)

end

local function bindLevelUpUI(gui) clearConnList(Conns.LevelUp) if not gui then
    return 
end
local function watchChild(child) if child:IsA("GuiObject") then
    table.insert(Conns.LevelUp,
    child:GetPropertyChangedSignal("Visible"):Connect(function() if child.Visible
    then
        closeLevelUpUI(gui) 
    end
end
)) if child.Visible then
    closeLevelUpUI(gui) 
end
end
end
if gui:IsA("LayerCollector") then
    table.insert(Conns.LevelUp,
    gui:GetPropertyChangedSignal("Enabled"):Connect(function() if gui.Enabled then
        closeLevelUpUI(gui) 
    end
end
)) 
end
for _, child in ipairs(gui:GetChildren()) do
    watchChild(child) 
end
table.insert(Conns.LevelUp,
gui.ChildAdded:Connect(watchChild)) closeLevelUpUI(gui) 
end

-- ==================== PRIMORDIAL EVENT TELEPORT SYSTEM ====================
function Primordial.isSpotActive(spot) local nowEp = Util.serverNow() local
active = false

local cfg = Cfg[spot.CfgFunc]()
if cfg and type(cfg.isActive) == "function" then
    local okA, res = pcall(cfg.isActive, nowEp)
    if okA and res == true then
        active = true 
    end
end

if not active then
    local stMod = Cfg.sharedMod(spot.StateName)
    if stMod and type(stMod.isActive) == "function" then
        local okS, resS = pcall(stMod.isActive)
        if okS and resS == true then
            active = true 
        end
    end
end

if not active and State.Primordial.NotifUntil[spot.Key] and os.clock() < State.Primordial.NotifUntil[spot.Key] then
    active = true
end

if active then
    if not State.Primordial.ActivatedAt[spot.Key] then
        State.Primordial.ActivatedAt[spot.Key] = os.clock()
    end
else
    State.Primordial.ActivatedAt[spot.Key] = nil
    State.Primordial.NotifUntil[spot.Key] = nil
end

return active

end

function Primordial.isSpotEligible(spot, curLvl, gear) if
State.Primordial.BlockedUntil[spot.Key] and os.clock() <
State.Primordial.BlockedUntil[spot.Key] then
    return false, "Cooldown after fail"
end

local cfg = Cfg[spot.CfgFunc]()
if not cfg then
    return false, "Config loading" 
end

-- Check specific unlock attribute if explicitly false
if spot.UnlockAttr and LocalPlayer:GetAttribute(spot.UnlockAttr) == false then
    return false, "Area not unlocked"
end

local reqLvl = cfg.RequireLevel or 0
if curLvl and curLvl < reqLvl then
    return false, "Need Lv." .. reqLvl
end

if type(cfg.rodAllowed) == "function" then
    local okR, rodAllowed = pcall(cfg.rodAllowed, gear.RodName)
    if okR and not rodAllowed then
        -- Verify if user owns any allowed rod in Backpack before rejecting
        local hasAllowed = false
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, item in ipairs(bp:GetChildren()) do
                if RodSys.isRod(item) then
                    local okB, resB = pcall(cfg.rodAllowed, item:GetAttribute("RodName") or item.Name)
                    if okB and resB then
                        hasAllowed = true break 
                    end
                end
            end
        end
        if not hasAllowed then
            return false, "Need Supremacy Rod" 
        end
    end
end

return true, "Eligible"

end

function Primordial.pickBestEvent() local curLvl = Monitor.readLevelXp() local
gear = Monitor.getGearSummary() local candidates = {}

for _, key in ipairs(CONST.PRIMORDIAL_ORDER) do
    local spot = CONST.PRIMORDIAL_SPOTS[key]
    if Primordial.isSpotActive(spot) then
        local okElig = Primordial.isSpotEligible(spot, curLvl, gear)
        if okElig then
            table.insert(candidates, spot)
        end
    end
end

if #candidates == 0 then
    return nil 
end

table.sort(candidates, function(a, b)
if State.Primordial.PriorityMode == "Newest First" then
    local tA = State.Primordial.ActivatedAt[a.Key] or 0
    local tB = State.Primordial.ActivatedAt[b.Key] or 0
    if tA ~= tB then
        return tA > tB 
    end
    return a.Priority > b.Priority
else
    -- "Rarest First": Sore Kraken (Priority 3) > Thalvyra (Priority 2) > Celestra (Priority 1)
    if a.Priority ~= b.Priority then
        return a.Priority > b.Priority 
    end
    return (State.Primordial.ActivatedAt[a.Key] or 0) > (State.Primordial.ActivatedAt[b.Key] or 0)
end
end
)

return candidates[1]

end

function Primordial.teleportTo(targetCF, spot) local p = State.Primordial if
p.IsTeleporting or not targetCF then
    return 
end
local char =
LocalPlayer.Character local hrp = char and
char:FindFirstChild("HumanoidRootPart") local hum = char and
char:FindFirstChildOfClass("Humanoid") if not hrp or not hum or hum.Health <= 0
then
    return 
end

p.IsTeleporting = true
p.LastTeleportAt = os.clock()

task.spawn(function()
-- Wait briefly if a bite is currently in progress so we don't drop the catch
local waitStart = os.clock()
while State.BiteActive and (os.clock() - waitStart) < 3 do
    task.wait(0.1)
end

State.WaitingForBite = false
char = LocalPlayer.Character
hrp = char and char:FindFirstChild("HumanoidRootPart")
hum = char and char:FindFirstChildOfClass("Humanoid")

if hrp and hum and hum.Health > 0 then
    if not p.HomeCFrame and spot then
        p.HomeCFrame = hrp.CFrame
    end

    if hum.Sit then
        hum.Sit = false
        task.wait(0.05)
    end

    pcall(function() LocalPlayer:RequestStreamAroundAsync(targetCF.Position) 
end
)

hrp.AssemblyLinearVelocity = Vector3.zero
hrp.AssemblyAngularVelocity = Vector3.zero
char:PivotTo(targetCF)
hrp.CFrame = targetCF

local wasAnchored = hrp.Anchored
hrp.Anchored = true
task.wait(0.4)
if hrp and hrp.Parent then
    hrp.Anchored = wasAnchored
    hrp.AssemblyLinearVelocity = Vector3.zero
end

if spot then
    local prev = p.CurrentEvent
    p.CurrentEvent = spot.Key
    if p.SwapEventRod then
        RodSys.recheckBestRod() 
    end
    refreshWaterState(false)

    local cfg = Cfg[spot.CfgFunc]()
    local leftSec = (cfg and type(cfg.secondsLeft) == "function") and cfg.secondsLeft(Util.serverNow()) or 0
    local gear = Monitor.getGearSummary()
    local chStr = "--"
    if cfg and type(cfg.chance) == "function" then
        local okC, bProb = pcall(cfg.chance, gear.TotalLuck)
        if okC and type(bProb) == "number" and bProb > 0 then
            local rb = (gear.RodInfo and gear.RodInfo.PrimordialBonus and gear.RodInfo.PrimordialBonus[spot.Name]) or 0
            chStr = Util.formatOneIn(bProb * (1 + rb) * (gear.PrimordialMult or 1))
        end
    end

    local actionTitle = (prev and prev ~= spot.Key) and ("Switched to " .. spot.Name) or ("Joined " .. spot.Name)
    if UI.Window then
        UI.Window:Notify({ title = "Primordial Event!", content = string.format("%s (%s left)", actionTitle, Util.formatDur(leftSec)), duration = 4 })
    end
    Webhook.primordial(
    "Primordial Event: " .. spot.Name,
    string.format("%s (%s remaining)\nRod: %s • Luck: %.1fx (%s)", actionTitle, Util.formatDur(leftSec), gear.RodName, gear.TotalLuck, chStr),
    CONST.RARITY_COLORS.Primordial
    )

    -- Snapback check after 1.8s
    task.delay(1.8, function()
    if hrp and hrp.Parent and p.CurrentEvent == spot.Key then
        local dist = (hrp.Position - targetCF.Position).Magnitude
        local stMod = Cfg.sharedMod(spot.StateName)
        local inside = (stMod and type(stMod.insideArea) == "function") and stMod.insideArea() or (dist < 60)
        if dist > 60 or not inside then
            p.BlockedUntil[spot.Key] = os.clock() + 120
            p.CurrentEvent = nil
            warn(string.format("[Auto Fish] Snapback detected at %s (dist %.1f). Skipping for 120s.", spot.Name, dist))
            Webhook.alert("Primordial Snapback", string.format("Server moved player away from %s. Skipping for 2m.", spot.Name), CONST.RARITY_COLORS.Alert)
        end
    end
end
)
else
    p.CurrentEvent = nil
    p.HomeCFrame = nil
    if p.SwapEventRod then
        RodSys.recheckBestRod() 
    end
    refreshWaterState(false)
    if UI.Window then
        UI.Window:Notify({ title = "Primordial Ended", content = "Returned to your normal fishing spot", duration = 3 })
    end
    Webhook.primordial("Primordial Window Ended", "Returned safely to normal fishing spot.", CONST.RARITY_COLORS.Report)
end
end

p.IsTeleporting = false
end
)

end

function Primordial.evaluate() local p = State.Primordial if not p.Enabled or
p.IsTeleporting then
    return 
end
if (os.clock() - p.LastTeleportAt) < 3 then
    return 
end

local char = LocalPlayer.Character
local hrp = char and char:FindFirstChild("HumanoidRootPart")
if not hrp then
    return 
end

local bestSpot = Primordial.pickBestEvent()
if bestSpot then
    if p.CurrentEvent ~= bestSpot.Key then
        Primordial.teleportTo(bestSpot.CFrame, bestSpot)
    elseif (hrp.Position - bestSpot.CFrame.Position).Magnitude > 60 then
            -- Re-center if knocked far from the safe spot while event is still active
            Primordial.teleportTo(bestSpot.CFrame, bestSpot)
        end
    elseif p.CurrentEvent ~= nil then
            if p.ReturnHome and p.HomeCFrame then
                Primordial.teleportTo(p.HomeCFrame, nil)
            else
                p.CurrentEvent = nil
                if p.SwapEventRod then
                    RodSys.recheckBestRod() 
                end
            end
        end

    end

    function Primordial.bindNotifUI(gui) local matchedKey = nil for _, key in
    ipairs(CONST.PRIMORDIAL_ORDER) do
        if gui.Name ==
        CONST.PRIMORDIAL_SPOTS[key].NotifUI then
            matchedKey = key break 
        end
    end
    if not
    matchedKey or not gui:IsA("LayerCollector") then
        return 
    end

    local function onEnabled()
    if gui.Enabled then
        State.Primordial.NotifUntil[matchedKey] = os.clock() + 1800
        State.Primordial.ActivatedAt[matchedKey] = State.Primordial.ActivatedAt[matchedKey] or os.clock()
        if State.Primordial.Enabled then
            task.defer(Primordial.evaluate)
        end
    end
end

table.insert(Conns.PrimNotif, gui:GetPropertyChangedSignal("Enabled"):Connect(onEnabled))
if gui.Enabled then
    onEnabled() 
end

end

-- ==================== FAST SAFE REEL & PING AUTO-TUNE ====================
local function updatePingSliderUI() if UI.PingSlider and UI.PingSlider.Set then
    State.IsUpdatingPingSlider = true pcall(function()
    UI.PingSlider:Set(math.floor(State.PingBuffer * 100 + 0.5) / 100) 
end
)
State.IsUpdatingPingSlider = false 
end
end

local function recalculateSafeReelTime() if not State.BiteActive then
    return 
end
local mg = Cfg.minigame() local startProg = tonumber(mg.StartingProgress) or 0.4
local perTap = State.BiteIsAuto and (tonumber(mg.AutoSecondsPerTap) or 0.1) or
(tonumber(mg.MinSecondsPerTap) or 0.06)

local useFull = (State.ReelTimingMode == "Safe (100%)")
or (State.ReelTimingMode == "Auto-Tune (Best)" and State.AutoTuneUseFullTaps)

local effTaps = useFull and State.BiteTaps or math.max(1, math.ceil(State.BiteTaps * math.max(0.1, 1 - startProg)))
State.SafeReelAt = State.BiteAt + (effTaps * perTap) + State.PingBuffer

end

local function fireReel() if not Remotes.Reel or not Remotes.Reel.Parent then
    return 
end
local now = os.clock() if (now - State.LastAutoReelFire) < 0.15 then
    return 
end
State.LastAutoReelFire = now State.LastReelAttemptAt = now
State.BiteHasReeled = true pcall(function() Remotes.Reel:FireServer(true) 
end
)
end

local function isSafeToReelNow() return not (State.EnabledFastSafeReel and
State.BiteActive and os.clock() < State.SafeReelAt) 
end

local function getInfoProgress() if not Cache.InfoLabel then
    return nil 
end
local curStr = string.match(Cache.InfoLabel.Text, "(%d+)%s*/%s*%d+") return
curStr and tonumber(curStr) or nil 
end

local function shouldAutoReel() if not State.EnabledReel or not Remotes.Reel or
not Remotes.Reel.Parent then
    return false 
end
if not isSafeToReelNow() then
    return false 
end
if State.BiteHasReeled and State.BiteActive then
    return false
end
if Conns.Server and not State.BiteActive then
    return false 
end
if not
Cache.FishingFrame or not Cache.FishingFrame.Visible then
    return false 
end
if
not State.BiteActive and Cache.TapText and Cache.TapText.Text == "CAST" then
    return false 
end

local current = getInfoProgress()
if current ~= nil then
    if current < State.ReelAt then
        State.SawProgressBelowTarget = true
        return false
    end
    return State.SawProgressBelowTarget or (os.clock() - State.FishingOpenedAt) >= 0.25
end

if Cache.BarFill then
    if Cache.BarFill.Size.X.Scale < (State.ReelAt / 13) then
        State.SawProgressBelowTarget = true
        return false
    end
    return State.SawProgressBelowTarget
end
return false

end

local function onServerEvent(eventName, data) local now = os.clock()
State.LastServerActivityAt = now

if eventName == "State" and type(data) == "table" then
    if type(data.equippedBait) == "string" and data.equippedBait ~= "" then
        State.DetectedBait = data.equippedBait
    end
elseif eventName == "CastOk" then
        State.WaitingForBite = true
        State.WaitingSince = now
    elseif eventName == "Bite" and type(data) == "table" then
            State.WaitingForBite = false
            State.BiteActive = true
            State.BiteAt = now
            State.BiteTaps = tonumber(data.taps) or 13
            State.BiteIsAuto = (data.auto == true)
            State.BiteHasReeled = false
            State.LastReelAttemptAt = 0
            State.FishingOpenedAt = now
            State.SawProgressBelowTarget = false

            if State.LastCastSentAt > 0 and (now - State.LastCastSentAt) <= 15 then
                State.Monitor.BiteWaitSum += (now - State.LastCastSentAt)
                State.Monitor.BiteWaitCount += 1
            end
            recalculateSafeReelTime()
        elseif eventName == "Caught" then
                State.WaitingForBite = false
                State.BiteActive = false
                State.BiteHasReeled = true
                State.ConsecutiveCatches += 1
                State.ConsecutiveInvalidFails = 0

                local m = State.Monitor
                m.TotalCaught += 1
                table.insert(m.RecentCatches, now)
                if State.BiteAt > 0 and (now - State.BiteAt) <= 30 then
                    m.ReelTimeSum += (now - State.BiteAt)
                    m.ReelTimeCount += 1
                end
                if m.LastCatchTime > 0 and (now - m.LastCatchTime) <= 60 then
                    m.CycleTimeSum += (now - m.LastCatchTime)
                    m.CycleTimeCount += 1
                end
                m.LastCatchTime = now

                local rarity = (type(data) == "table" and data.rarity) or "Common"
                local fishName = (type(data) == "table" and data.name) or "Fish"
                local weightKg = (type(data) == "table" and (tonumber(data.kg) or tonumber(data.weight))) or nil
                local rawChance = (type(data) == "table" and (tonumber(data.oneIn) or tonumber(data.chance))) or nil

                m.RarityCounts[rarity] = (m.RarityCounts[rarity] or 0) + 1
                m.LastFishText = string.format("%s (%s)", tostring(fishName), tostring(rarity))

                local lvlCfg = Cfg.level()
                local xpTbl = (lvlCfg and lvlCfg.FishXp) or CONST.DEFAULT_FISH_XP
                local baseXp = xpTbl[rarity] or 5
                local vipMult = (Monitor.detectVip() and (1 + ((lvlCfg and lvlCfg.VipBonus) or 0.25))) or 1
                m.SessionFishXp += (baseXp * vipMult)

                Webhook.rareCatch(fishName, rarity, weightKg, rawChance)

                if State.AutoTunePingBuffer and State.ConsecutiveCatches >= 25 and (now - State.LastBufferAdjustAt) >= 45 then
                    local floorTarget = math.max(0.03, State.AutoTuneFloorBuffer)
                    if State.PingBuffer > floorTarget + 0.005 then
                        State.PingBuffer = math.max(floorTarget, math.floor((State.PingBuffer - 0.01) * 100 + 0.5) / 100)
                        State.LastBufferAdjustAt = now
                        State.ConsecutiveCatches = 0
                        updatePingSliderUI()
                        print(string.format("[Auto Fish] Ping Auto-Tune: Trimmed buffer to %.2fs after 25 clean catches.", State.PingBuffer))
                    end
                end
            elseif eventName == "Failed" then
                    State.WaitingForBite = false
                    State.BiteActive = false
                    State.BiteHasReeled = true
                    State.Monitor.TotalFailed += 1

                    local reason = type(data) == "table" and data.reason or "Other"
                    if State.Monitor.FailReasons[reason] ~= nil then
                        State.Monitor.FailReasons[reason] += 1
                    else
                        State.Monitor.FailReasons.Other += 1
                    end

                    if reason == "Invalid" then
                        State.Monitor.InvalidFails += 1
                        State.ConsecutiveCatches = 0
                        State.ConsecutiveInvalidFails += 1
                        State.LastBufferAdjustAt = now

                        local switched = false
                        if State.ReelTimingMode == "Auto-Tune (Best)" and not State.AutoTuneUseFullTaps then
                            State.AutoTuneUseFullTaps = true
                            switched = true
                            warn("[Auto Fish] Auto-Tune: Upgraded to 100% taps after 'Invalid'.")
                            if UI.Window then
                                task.defer(function()
                                UI.Window:Notify({ title = "Auto-Tune Adjusted", content = "Switched to 100% tap timing for 0 fails", duration = 3 })
                            end
                            )
                        end
                    end

                    if State.AutoTunePingBuffer and not switched then
                        local newBuf = math.min(0.45, math.floor((State.PingBuffer + 0.03) * 100 + 0.5) / 100)
                        if newBuf > State.PingBuffer then
                            State.PingBuffer = newBuf
                            State.AutoTuneFloorBuffer = math.max(State.AutoTuneFloorBuffer, newBuf)
                            updatePingSliderUI()
                            warn(string.format("[Auto Fish] Ping Auto-Tune: Bumped buffer to %.2fs (floor locked).", newBuf))
                            if UI.Window then
                                task.defer(function()
                                UI.Window:Notify({ title = "Ping Buffer Auto-Tuned", content = string.format("Increased Ping Buffer to %.2fs (0 fails lock)", newBuf), duration = 3 })
                            end
                            )
                        end
                    end
                end

                if State.ConsecutiveInvalidFails >= 5 then
                    Webhook.alert("Repeated 'Invalid' Fails Detected", string.format("%d consecutive Invalid fails. Ping Buffer: %.2fs.", State.ConsecutiveInvalidFails, State.PingBuffer), CONST.RARITY_COLORS.Alert)
                end
            end
        elseif eventName == "CastFail" and type(data) == "table" and data.reason ~= "Busy" then
                State.WaitingForBite = false
                if not State.BiteActive then
                    State.BiteHasReeled = false 
                end
                if data.reason == "NotWater" and State.EnabledPauseNoWater then
                    State.LastWaterCheckAt = now
                    refreshWaterState(true)
                elseif data.reason == "Full" and State.EnabledSell and not State.IsSelling and Remotes.SellAll and Remotes.SellAll.Parent then
                        State.LastSellTime = now
                        State.IsSelling = true
                        task.spawn(function()
                        pcall(Remotes.SellAll.InvokeServer, Remotes.SellAll)
                        State.IsSelling = false
                    end
                    )
                end
            end

        end

        -- ==================== UI CACHING & BINDINGS ==================== local
        function bindServerRemote(remote) if Conns.Server then
            Conns.Server:Disconnect()
            Conns.Server = nil 
        end
        Remotes.Server = remote if remote then
            Conns.Server =
            remote.OnClientEvent:Connect(onServerEvent) 
        end
    end

    local function bindFishingFrame(frame) if Conns.FishingVis then
        Conns.FishingVis:Disconnect() Conns.FishingVis = nil 
    end
    Cache.FishingFrame =
    frame if not frame then
        return 
    end
    if frame.Visible then
        State.FishingOpenedAt =
        os.clock() State.SawProgressBelowTarget = false 
    end
    Conns.FishingVis =
    frame:GetPropertyChangedSignal("Visible"):Connect(function() if frame.Visible
    then
        State.FishingOpenedAt = os.clock() State.SawProgressBelowTarget = false
    else
        State.SawProgressBelowTarget = false 
    end
end
) 
end

local function bindInfoLabel(lbl) if Conns.InfoText then
    Conns.InfoText:Disconnect() Conns.InfoText = nil 
end
Cache.InfoLabel = lbl if
lbl then
    Conns.InfoText =
    lbl:GetPropertyChangedSignal("Text"):Connect(function() if shouldAutoReel() then
        fireReel() 
    end
end
) 
end
end

local function bindBarFill(bar) if Conns.BarFill then
    Conns.BarFill:Disconnect()
    Conns.BarFill = nil 
end
if Conns.BarSize then
    Conns.BarSize:Disconnect()
    Conns.BarSize = nil 
end
if not bar then
    return 
end
local fill =
bar:FindFirstChild("Fill") Cache.BarFill = fill if fill then
    Conns.BarFill =
    fill:GetPropertyChangedSignal("BackgroundColor3"):Connect(function() if not
    State.EnabledColorReel or not Remotes.Reel then
        return 
    end
    if not
    isSafeToReelNow() then
        return 
    end
    if Conns.Server and not State.BiteActive then
        return 
    end
    if Cache.FishingFrame and not Cache.FishingFrame.Visible then
        return
    end
    if not State.BiteActive and Cache.TapText and Cache.TapText.Text == "CAST"
    then
        return 
    end
    local col = fill.BackgroundColor3 local isGreen = (col.G > 0.7
    and col.G > col.R and col.G > col.B) or (math.abs(col.R * 255 - 100) < 30 and
    (col.G * 255) > 220 and math.abs(col.B * 255 - 100) < 30) if isGreen then
        fireReel() 
    end
end
) Conns.BarSize =
fill:GetPropertyChangedSignal("Size"):Connect(function() if shouldAutoReel()
then
    fireReel() 
end
end
) 
end
end

local function clearUICache() Cache.FishingFrame, Cache.InfoLabel, Cache.TapBtn,
Cache.TapText, Cache.BarFill, Cache.AutoBtn = nil, nil, nil, nil, nil, nil for
_, k in ipairs({ "Gradient", "BarFill", "BarSize", "InfoText", "FishingVis",
"GuiDesc" }) do
    if Conns[k] then
        Conns[k]:Disconnect() Conns[k] = nil 
    end
end
end

local function cacheUI() if not PlayerGui then
    return 
end
local lvlGui =
PlayerGui:FindFirstChild("LevelUpUI") if lvlGui then
    bindLevelUpUI(lvlGui) 
end

clearConnList(Conns.PrimNotif)
for _, key in ipairs(CONST.PRIMORDIAL_ORDER) do
    local nGui = PlayerGui:FindFirstChild(CONST.PRIMORDIAL_SPOTS[key].NotifUI)
    if nGui then
        Primordial.bindNotifUI(nGui) 
    end
end

local gui = PlayerGui:FindFirstChild("FishingGui")
if gui then
    bindFishingFrame(gui:FindFirstChild("Fishing", true))
    Cache.TapBtn = gui:FindFirstChild("TapMobile") or gui:FindFirstChild("TapMobile", true)
    Cache.TapText = Cache.TapBtn and Cache.TapBtn:FindFirstChild("TAP")
    Cache.AutoBtn = gui:FindFirstChild("AutoFishingButton", true)

    if Cache.FishingFrame then
        bindInfoLabel(Cache.FishingFrame:FindFirstChild("Info", true))
        bindBarFill(Cache.FishingFrame:FindFirstChild("Bar", true))
    end
    if Cache.AutoBtn then
        bindAutoGradient(Cache.AutoBtn) 
    end

    if Conns.GuiDesc then
        Conns.GuiDesc:Disconnect() 
    end
    Conns.GuiDesc = gui.DescendantAdded:Connect(function(desc)
    if desc.Name == "AutoFishingButton" then
        Cache.AutoBtn = desc
        bindAutoGradient(desc)
        if State.EnabledGameAutoCast then
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
                        Cache.TapBtn = desc
                        Cache.TapText = desc:FindFirstChild("TAP")
                    elseif desc.Name == "TAP" and desc.Parent and desc.Parent.Name == "TapMobile" then
                            Cache.TapText = desc
                        end
                    end
                    )
                else
                    clearUICache()
                end

            end

            if PlayerGui then
                cacheUI() table.insert(Conns.Global,
                PlayerGui.ChildAdded:Connect(function(c) if c.Name == "FishingGui" then
                    task.wait() cacheUI() 
                elseif c.Name == "LevelUpUI" then
                        task.defer(bindLevelUpUI, c) 
                    elseif c.Name == "CelestraNotifUI" or c.Name ==
                        "ThalvyraNotifUI" or c.Name == "SoreKrakenNotifUI" then
                            task.defer(Primordial.bindNotifUI, c) 
                        end
                    end
                    )) table.insert(Conns.Global,
                    PlayerGui.ChildRemoved:Connect(function(c) if c.Name == "FishingGui" then
                        clearUICache() 
                    elseif c.Name == "LevelUpUI" then
                            clearConnList(Conns.LevelUp)
                        end
                    end
                    )) 
                end

                table.insert(Conns.Global, Svc.Gui.ErrorMessageChanged:Connect(function(errMsg)
                if errMsg and errMsg ~= "" then
                    Webhook.alert("Disconnected from Server",
                    tostring(errMsg), CONST.RARITY_COLORS.Alert, true) 
                end
            end
            ))

            -- ==================== REMOTE RESOLUTION ==================== local function
            isRemoteValid(r) return r ~= nil and r.Parent ~= nil 
        end

        local function resolveAllConfigs() Cfg.fish() Cfg.rod() Cfg.rodSkin() Cfg.bait()
        Cfg.enhance() Cfg.level() Cfg.celestra() Cfg.thalvyra() Cfg.soreKraken()
        Cfg.sharedMod("CelestraState") Cfg.sharedMod("ThalvyraState")
        Cfg.sharedMod("SoreKrakenState") 
    end

    local function resolveRemotes() local fr =
    Svc.ReplicatedStorage:FindFirstChild("FishRemotes") if not fr then
        return false
    end
    if not isRemoteValid(Remotes.Cast) then
        Remotes.Cast =
        fr:FindFirstChild("Cast") 
    end
    if not isRemoteValid(Remotes.Reel) then
        Remotes.Reel = fr:FindFirstChild("Reel") 
    end
    if not
    isRemoteValid(Remotes.SellAll) then
        Remotes.SellAll =
        fr:FindFirstChild("SellAll") 
    end
    if not isRemoteValid(Remotes.SetAuto) then
        Remotes.SetAuto = fr:FindFirstChild("SetAuto") 
    end
    if not
    isRemoteValid(Remotes.GetState) then
        Remotes.GetState =
        fr:FindFirstChild("GetState") 
    end
    if not isRemoteValid(Remotes.Server) then
        local srv = fr:FindFirstChild("Server") if srv then
            bindServerRemote(srv) 
        end
    end
    return isRemoteValid(Remotes.Cast) 
end

task.spawn(function() local attempts = 0 while not resolveRemotes() do
    attempts
    += 1 task.wait(attempts <= 25 and 0.25 or 1) 
end
print("[Auto Fish] CastRemote
connected.") resolveAllConfigs() Monitor.refreshBait() task.spawn(function() for
_ = 1, 20 do
    resolveRemotes() resolveAllConfigs() if isRemoteValid(Remotes.Reel)
    and isRemoteValid(Remotes.SellAll) and isRemoteValid(Remotes.SetAuto) and
    isRemoteValid(Remotes.Server) and isRemoteValid(Remotes.GetState) then
        break 
    end
    task.wait(1) 
end
Monitor.refreshBait() 
end
) 
end
)

-- ==================== UNIVERSAL ROD AUTO EQUIP ==================== function
RodSys.isRod(tool) if not tool or not tool:IsA("Tool") then
    return false 
end
if
tool:GetAttribute("FishRod") or tool:GetAttribute("RodName") ~= nil or
tool:GetAttribute("SkinName") ~= nil then
    return true 
end
local rc = Cfg.rod()
if rc and type(rc.Rods) == "table" and rc.Rods[tool.Name] ~= nil then
    return
    true 
end
Cfg.rodSkin() if Cache.SkinDisplays and Cache.SkinDisplays[tool.Name]
then
    return true 
end
local ln = string.lower(tool.Name) return string.find(ln,
"rod", 1, true) ~= nil or string.find(ln, "katana", 1, true) ~= nil 
end

function RodSys.score(rodName, obj) local score = 1 local rc = Cfg.rod() if rc
and type(rc.get) == "function" and type(rodName) == "string" then
    local info =
    rc.get(rodName) if info and type(info.Luck) == "number" then
        score = info.Luck
    end
end
if obj then
    score += (tonumber(obj:GetAttribute("Luck")) or 0) +
    (Monitor.extractEnhances(obj).Luck or 0) 
end

-- Event-specific Primordial Rod bonus
if State.Primordial.Enabled and State.Primordial.SwapEventRod and State.Primordial.CurrentEvent then
    local spot = CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent]
    if spot and rodName == spot.PreferRod then
        score += 10000
    else
        local cfg = spot and Cfg[spot.CfgFunc]()
        if cfg and type(cfg.rodAllowed) == "function" then
            local okR, allowed = pcall(cfg.rodAllowed, rodName)
            if okR and allowed then
                score += 500
            else
                score -= 500
            end
        end
    end
end
return score

end

function RodSys.findEquipped(char) if not char then
    return nil 
end
for _, c in
ipairs(char:GetChildren()) do
    if RodSys.isRod(c) then
        return c 
    end
end
return
nil 
end

function RodSys.findBestBackpack(bp) if not bp then
    return nil 
end
local best,
bestScore = nil, -1 for _, c in ipairs(bp:GetChildren()) do
    if RodSys.isRod(c)
    then
        local sc = RodSys.score(c:GetAttribute("RodName") or c.Name, c) if not best
        or sc > bestScore then
            best, bestScore = c, sc 
        end
    end
end
return best 
end

function RodSys.findBestContentTarget() if not PlayerGui then
    return nil, nil,
    -1 
end
local bpGui = PlayerGui:FindFirstChild("Backpack") if not bpGui then
    return nil, nil, -1 
end
local inv = bpGui:FindFirstChild("Inventory") local cf =
inv and inv:FindFirstChild("ContentFrame") local rcCont = (cf and
cf:FindFirstChild("RodContent")) or bpGui:FindFirstChild("RodContent", true) if
not rcCont then
    return nil, nil, -1 
end

local rc = Cfg.rod()
Cfg.rodSkin()
local bestTarget, bestScore = nil, -1
for _, entry in ipairs(rcCont:GetChildren()) do
    if entry:IsA("GuiObject") and entry.Visible then
        local lower = string.lower(entry.Name)
        if lower ~= "template" and lower ~= "example" and lower ~= "placeholder" then
            local rName = entry:GetAttribute("RodName") or entry.Name
            local isKnown = (rc and type(rc.Rods) == "table" and rc.Rods[rName] ~= nil)
            or (Cache.SkinDisplays and Cache.SkinDisplays[rName] == true)
            or (entry:GetAttribute("FishRod") ~= nil)
            or (entry:GetAttribute("RodName") ~= nil)
            or string.find(lower, "rod", 1, true) ~= nil
            or string.find(lower, "katana", 1, true) ~= nil
            or entry:IsA("GuiButton") or entry:FindFirstChildWhichIsA("GuiButton", true) ~= nil
            if isKnown then
                local sc = RodSys.score(rName, entry)
                if not bestTarget or sc > bestScore then
                    bestTarget, bestScore = entry, sc 
                end
            end
        end
    end
end

if not bestTarget then
    return nil, nil, -1 
end
if bestTarget:IsA("GuiButton") then
    return bestTarget, bestTarget, bestScore 
end
for _, nm in ipairs({ "Button", "Click", "Equip", "Select", "Hitbox" }) do
    local btn = bestTarget:FindFirstChild(nm, true)
    if btn and btn:IsA("GuiButton") then
        return btn, bestTarget, bestScore 
    end
end
return (bestTarget:FindFirstChildWhichIsA("GuiButton", true) or bestTarget), bestTarget, bestScore

end

function RodSys.equip() if not State.EnabledAutoEquip then
    return 
end
local char
= LocalPlayer.Character if not char or RodSys.findEquipped(char) then
    return 
end
local hum = char:FindFirstChildOfClass("Humanoid") if not hum or hum.Health <= 0
then
    return 
end

local bpTool = RodSys.findBestBackpack(LocalPlayer:FindFirstChild("Backpack"))
if bpTool then
    pcall(function() hum:EquipTool(bpTool) 
end
)
return
end

local now = os.clock()
if (now - State.LastUiRodClickAt) < 1.5 then
    return 
end
local clickBtn, entryFrame = RodSys.findBestContentTarget()
if clickBtn then
    State.LastUiRodClickAt = now
    Util.triggerBtn(clickBtn)
    if entryFrame and entryFrame ~= clickBtn then
        Util.triggerBtn(entryFrame) 
    end
    task.delay(0.35, function()
    if State.EnabledAutoEquip and LocalPlayer.Character == char and not RodSys.findEquipped(char) then
        local newTool = RodSys.findBestBackpack(LocalPlayer:FindFirstChild("Backpack"))
        if newTool and hum and hum.Health > 0 then
            pcall(function() hum:EquipTool(newTool) 
        end
        ) 
    end
end
end
)
end

end

function RodSys.recheckBestRod() if not State.EnabledAutoEquip then
    return 
end
local char = LocalPlayer.Character local hum = char and
char:FindFirstChildOfClass("Humanoid") if not char or not hum or hum.Health <= 0
then
    return 
end

local held = RodSys.findEquipped(char)
if not held then
    RodSys.equip()
    return
end

local heldScore = RodSys.score(held:GetAttribute("RodName") or held.Name, held)
local bpBest = RodSys.findBestBackpack(LocalPlayer:FindFirstChild("Backpack"))
if bpBest then
    local bpScore = RodSys.score(bpBest:GetAttribute("RodName") or bpBest.Name, bpBest)
    if bpScore > heldScore + 0.01 then
        pcall(function() hum:EquipTool(bpBest) 
    end
    )
    return
end
end

local clickBtn, entryFrame, uiScore = RodSys.findBestContentTarget()
if clickBtn and uiScore > heldScore + 0.01 and (os.clock() - State.LastUiRodClickAt) >= 1.5 then
    State.LastUiRodClickAt = os.clock()
    Util.triggerBtn(clickBtn)
    if entryFrame and entryFrame ~= clickBtn then
        Util.triggerBtn(entryFrame) 
    end
    task.delay(0.35, RodSys.equip)
end

end

local function bindCharacterEvents(char) if not char then
    return 
end
clearConnList(Conns.Char) State.WaitingForBite, State.BiteActive,
State.BiteHasReeled = false, false, false task.wait(1) RodSys.equip()
refreshWaterState(false) if State.Primordial.Enabled then
    task.defer(Primordial.evaluate) 
end
if State.EnabledGameAutoCast then
    setGameAutoCast(true) 
end

table.insert(Conns.Char, char.ChildRemoved:Connect(function(c)
if RodSys.isRod(c) then
    task.defer(RodSys.equip) 
end
end
))
local bp = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
if bp then
    table.insert(Conns.Char, bp.ChildAdded:Connect(function(c)
    if RodSys.isRod(c) then
        task.defer(RodSys.equip) 
    end
end
))
end

end

if LocalPlayer.Character then
    task.spawn(bindCharacterEvents,
    LocalPlayer.Character) 
end
table.insert(Conns.Global,
LocalPlayer.CharacterAdded:Connect(bindCharacterEvents))

-- ==================== CLICKER & MAIN LOOP ==================== local function
doClick() if State.ClickMethod == "Input Signals" then
    local mouse =
    LocalPlayer:GetMouse() if mouse then
        Util.fireSignals(mouse.Button1Down)
        Util.fireSignals(mouse.Button1Up) 
    end
    if getconnections then
        local bIn =
        Util.mockInput(Enum.UserInputState.Begin, 0, 0) local eIn =
        Util.mockInput(Enum.UserInputState.End, 0, 0) for _, pair in ipairs({ {
        Svc.UIS.InputBegan, bIn }, { Svc.UIS.InputEnded, eIn } }) do
            local okC, conns =
            pcall(getconnections, pair[1]) if okC and conns then
                for _, conn in
                ipairs(conns) do
                    if conn.Function then
                        local okI, src = pcall(debug.info,
                        conn.Function, "s") if okI and type(src) == "string" and (string.find(src,
                        "Players%.") or string.find(src, "Replicated") or string.find(src, "Starter"))
                        then
                            pcall(function() conn:Fire(pair[2], false) 
                        end
                        ) 
                    end
                end
            end
        end
    end
end
else
    if not Cache.TapBtn and PlayerGui then
        local gui =
        PlayerGui:FindFirstChild("FishingGui") if gui then
            Cache.TapBtn =
            gui:FindFirstChild("TapMobile") or gui:FindFirstChild("TapMobile", true)
            Cache.TapText = Cache.TapBtn and Cache.TapBtn:FindFirstChild("TAP") 
        end
    end
    if
    Cache.TapBtn then
        Util.triggerBtn(Cache.TapBtn) 
    end
end
end

local function mainLoop() local now = os.clock()

if (now - State.LastRemoteResolveTime) >= 2 then
    if not isRemoteValid(Remotes.Cast) or not isRemoteValid(Remotes.Reel) or not isRemoteValid(Remotes.SellAll) or not isRemoteValid(Remotes.SetAuto) or not isRemoteValid(Remotes.Server) then
        State.LastRemoteResolveTime = now
        resolveRemotes()
    end
end

if (now - State.LastBaitRefreshAt) >= 60 then
    State.LastBaitRefreshAt = now
    Monitor.refreshBait()
end

if State.WaitingForBite and (now - State.WaitingSince) >= 11 then
    State.WaitingForBite = false 
end
if State.BiteActive and (now - State.BiteAt) >= 26 then
    State.BiteActive, State.BiteHasReeled = false, false 
end

if State.EnabledCast and not State.IsFarmPausedNoWater and (now - State.LastServerActivityAt) >= 45 then
    State.LastServerActivityAt = now
    State.WaitingForBite, State.BiteActive, State.BiteHasReeled = false, false, false
    if State.EnabledAutoEquip then
        RodSys.equip() 
    end
end

if State.Primordial.Enabled and (now - State.Primordial.LastCheckAt) >= 2 then
    State.Primordial.LastCheckAt = now
    Primordial.evaluate()
end

if (State.EnabledPauseNoWater or State.EnabledSmartWaterAim) and not State.BiteActive and not State.Primordial.IsTeleporting and (now - State.LastWaterCheckAt) >= 1.2 then
    State.LastWaterCheckAt = now
    refreshWaterState(true)
end

if State.EnabledAutoEquip and not State.BiteActive and (now - State.LastRodCheckAt) >= 3 then
    State.LastRodCheckAt = now
    if LocalPlayer.Character and not RodSys.findEquipped(LocalPlayer.Character) then
        RodSys.equip() 
    end
end

if State.EnabledCast and isRemoteValid(Remotes.Cast) and not State.Primordial.IsTeleporting then
    if not State.IsFarmPausedNoWater and not State.BiteActive and not State.WaitingForBite and (now - State.LastCastSentAt) >= 0.06 then
        lastCastSentAt = now
        local targetVec = (State.EnabledSmartWaterAim and State.CachedWaterDir) or State.CastPos
        pcall(Remotes.Cast.FireServer, Remotes.Cast, targetVec, State.CastPower)
    end
end

if State.EnabledClick then
    local canClick = Conns.Server and (State.BiteActive and not State.BiteHasReeled) or (Cache.FishingFrame and Cache.FishingFrame.Visible)
    if canClick and (now - State.LastClickTime) >= State.ClickDelay then
        State.LastClickTime = now
        doClick()
    end
end

if State.EnabledFastSafeReel and State.BiteActive and isRemoteValid(Remotes.Reel) then
    if now >= State.SafeReelAt and (not State.BiteHasReeled or (now - State.LastReelAttemptAt) >= 1.5) then
        fireReel()
    end
end

if shouldAutoReel() then
    fireReel() 
end

if State.EnabledSell and not State.IsSelling and isRemoteValid(Remotes.SellAll) then
    if (now - State.LastSellTime) >= State.SellInterval then
        State.LastSellTime = now
        State.IsSelling = true
        task.spawn(function()
        pcall(Remotes.SellAll.InvokeServer, Remotes.SellAll)
        State.IsSelling = false
    end
    )
end
end

if State.EnabledGameAutoCast and not State.IsFarmPausedNoWater and not State.Primordial.IsTeleporting and (now - State.LastAutoCheckTime) >= 4 then
    State.LastAutoCheckTime = now
    if Cache.AutoBtn and not isGameAutoCastOn() then
        setGameAutoCast(true) 
    end
end

if State.Webhook.Enabled and State.Webhook.PeriodicReport then
    if (now - State.Webhook.LastReportAt) >= (State.Webhook.IntervalMinutes * 60) then
        State.Webhook.LastReportAt = now
        Webhook.enqueue(Webhook.buildReport())
    end
end

end

local function updateLoop() local shouldRun = (State.EnabledCast or
State.EnabledClick or State.EnabledReel or State.EnabledFastSafeReel or
State.EnabledSell or State.EnabledGameAutoCast or State.EnabledAutoEquip or
State.Primordial.Enabled or (State.Webhook.Enabled and
State.Webhook.PeriodicReport)) if shouldRun then
    if not Conns.Heartbeat then
        State.LastClickTime, State.LastSellTime, State.LastAutoCheckTime = 0, 0, 0
        Conns.Heartbeat = Svc.RunService.Heartbeat:Connect(mainLoop) 
    end
elseif
    Conns.Heartbeat then
        Conns.Heartbeat:Disconnect() Conns.Heartbeat = nil 
    end
end

-- ==================== RAYFIELD UI CREATION (SCOPED) ==================== do
local function safeStat(tab, opts) if tab and type(tab.CreateStat) == "function"
then
    local okS, h = pcall(tab.CreateStat, tab, opts) if okS and h then
        return h
    end
end
return nil 
end
local function safePara(tab, title, content) if tab and
type(tab.CreateParagraph) == "function" then
    local okP, h =
    pcall(tab.CreateParagraph, tab, { title = title, content = content }) if okP and
    h then
        return h 
    end
elseif tab and type(tab.CreateLabel) == "function" then
        local okL, h = pcall(tab.CreateLabel, tab, title .. ": " .. content) if okL and
        h then
            return h 
        end
    end
    return nil 
end

UI.Window = Rayfield:CreateWindow({
name = "Auto Fish",
subtitle = string.format("v%s • Place %d", SCRIPT_VERSION, game.PlaceId),
theme = "cobalt",
configuration = { autoSave = true, autoLoad = false, fileName = "AutoFishConfig" },
})

local AutoTab = UI.Window:CreateTab({ name = "Automation" })
AutoTab:CreateSection({ name = "Casting & Events" })
UI.AutoCastToggle = AutoTab:CreateToggle({
name = "Auto Cast", description = "Smart casts between catches (pauses while waiting for bite)",
flag = "AutoCast", value = true,
callback = function(v) State.EnabledCast = v updateLoop() 
end
,
})
AutoTab:CreateToggle({
name = "Pause Away From Water", description = "Automatically pauses farming when you move away from water",
flag = "PauseAwayFromWater", value = true,
callback = function(v) State.EnabledPauseNoWater = v refreshWaterState(false) 
end
,
})
UI.PrimordialToggle = AutoTab:CreateToggle({
name = "Auto TP Primordial Events", description = "Teleports to eligible active Primordial spots & returns afterward",
flag = "AutoTpPrimordial", value = true,
callback = function(v)
State.Primordial.Enabled = v
updateLoop()
if v then
    task.defer(Primordial.evaluate)
elseif State.Primordial.CurrentEvent and State.Primordial.ReturnHome and State.Primordial.HomeCFrame then
        Primordial.teleportTo(State.Primordial.HomeCFrame, nil)
    end
end
,
})
UI.GameAutoCastToggle = AutoTab:CreateToggle({
name = "Game Auto Cast", description = "Optional built-in auto cast (keep OFF for faster 0.06s/tap speed)",
flag = "GameAutoCast", value = false,
callback = function(v) State.EnabledGameAutoCast = v updateLoop() setGameAutoCast(v) 
end
,
})

AutoTab:CreateSection({ name = "Reeling & Clicking" })
UI.FastSafeReelToggle = AutoTab:CreateToggle({
name = "Fast Safe Reel", description = "Reels at earliest safe server time from FishConfig (Auto-Tunes on fails)",
flag = "FastSafeReel", value = true,
callback = function(v) State.EnabledFastSafeReel = v updateLoop() 
end
,
})
AutoTab:CreateToggle({
name = "Auto Clicker", description = "Clicks automatically during active fishing bites",
flag = "AutoClicker", value = false,
callback = function(v) State.EnabledClick = v updateLoop() 
end
,
})
AutoTab:CreateToggle({
name = "Auto Reel", description = "Reels when progress reaches the Reel At target",
flag = "AutoReel", value = false,
callback = function(v) State.EnabledReel = v updateLoop() 
end
,
})
UI.ColorReelToggle = AutoTab:CreateToggle({
name = "Color Reel", description = "Reels when the fill bar turns green (starts OFF; guarded by Fast Safe Reel)",
flag = "ColorReel", value = false,
callback = function(v) State.EnabledColorReel = v 
end
,
})

AutoTab:CreateSection({ name = "Equipment, UI & Economy" })
AutoTab:CreateToggle({
name = "Auto Equip Rod", description = "Equips your best rod from Backpack or RodContent Inventory UI",
flag = "AutoEquipRod", value = true,
callback = function(v) State.EnabledAutoEquip = v if v then
    RodSys.equip() 
end
end
,
})
AutoTab:CreateToggle({
name = "Auto Close LevelUp UI", description = "Automatically dismisses the LevelUpUI popup when leveling up",
flag = "AutoCloseLevelUp", value = true,
callback = function(v)
State.EnabledAutoCloseLevelUp = v
if v and PlayerGui then
    local lg = PlayerGui:FindFirstChild("LevelUpUI")
    if lg then
        closeLevelUpUI(lg) 
    end
end
end
,
})
AutoTab:CreateToggle({
name = "Auto Sell", description = "Sells all fish on an interval (plus instant sell if bag is full)",
flag = "AutoSell", value = false,
callback = function(v) State.EnabledSell = v if v then
    State.LastSellTime = 0 
end
updateLoop() 
end
,
})

local MonTab = UI.Window:CreateTab({ name = "Rate Monitor" })
MonTab:CreateSection({ name = "Live Overview" })
UI.StatFishHr = safeStat(MonTab, { name = "Fish / Hour (Live)", value = 0, numberEasing = false })
UI.StatXpHr = safeStat(MonTab, { name = "XP / Hour", value = 0, numberEasing = false })
UI.StatCaught = safeStat(MonTab, { name = "Session Caught", value = 0, numberEasing = false })
UI.StatLevel = safeStat(MonTab, { name = "Current Level", value = 0, numberEasing = false })

MonTab:CreateSection({ name = "Detailed Rates & Projections" })
UI.ParaRate = safePara(MonTab, "Fishing Efficiency & Fails", "Waiting for first catch...")
UI.ParaGear = safePara(MonTab, "Active Gear, Luck & Odds", "Loading gear configs...")
UI.ParaXp = safePara(MonTab, "XP & Level Estimates", "Calculating...")
UI.ParaPrimordial = safePara(MonTab, "Primordial Windows", "Checking Celestra / Thalvyra / Sore Kraken...")
UI.ParaRarity = safePara(MonTab, "Rarity Breakdown", "No catches yet.")
MonTab:CreateButton({
name = "Reset Rate Monitor",
callback = function()
Monitor.reset()
UI.Window:Notify({ title = "Rate Monitor Reset", content = "Session statistics cleared.", duration = 2 })
end
,
})

local WebTab = UI.Window:CreateTab({ name = "Webhook" })
WebTab:CreateSection({ name = "Discord Configuration" })
WebTab:CreateInput({
name = "Discord Webhook URL", value = State.Webhook.Url,
placeholder = "https://discord.com/api/webhooks/...", flag = "DiscordWebhookUrl",
callback = function(txt) State.Webhook.Url = Util.trim(txt) 
end
,
})
WebTab:CreateToggle({
name = "Enable Discord Webhook", description = "Auto-enables if getgenv().AutoFishWebhook is set",
flag = "EnableDiscordWebhook", value = State.Webhook.Enabled,
callback = function(v)
State.Webhook.Enabled = v
if v then
    State.Webhook.LastReportAt = os.clock() 
end
updateLoop()
end
,
})
WebTab:CreateSection({ name = "Notifications & Reports" })
WebTab:CreateToggle({
name = "Notify Rare Catches", description = "Alerts on Mythic, Secret, Supremacy, and Primordial catches",
flag = "WebhookRareCatches", value = true,
callback = function(v) State.Webhook.NotifyRareCatches = v 
end
,
})
WebTab:CreateToggle({
name = "Notify Primordial Teleports", description = "Alerts when joining/switching/leaving Primordial events",
flag = "WebhookPrimordial", value = true,
callback = function(v) State.Webhook.NotifyPrimordial = v 
end
,
})
WebTab:CreateToggle({
name = "Notify Connected & Disconnected", description = "Alerts on script load/reconnect and server disconnect",
flag = "WebhookConnections", value = true,
callback = function(v) State.Webhook.NotifyConnections = v 
end
,
})
WebTab:CreateToggle({
name = "Periodic Stats Summary", description = "Sends an overnight rate & progress embed on an interval",
flag = "WebhookPeriodicReport", value = true,
callback = function(v)
State.Webhook.PeriodicReport = v
if v then
    State.Webhook.LastReportAt = os.clock() 
end
updateLoop()
end
,
})
WebTab:CreateSlider({
name = "Summary Interval", range = { 5, 60 }, increment = 5, value = 15, suffix = "m", flag = "WebhookIntervalMinutes",
callback = function(v) State.Webhook.IntervalMinutes = v 
end
,
})
WebTab:CreateToggle({
name = "Alert on Pause / Fails", description = "Sends an alert if away from water or 5+ Invalid fails",
flag = "WebhookAlerts", value = true,
callback = function(v) State.Webhook.AlertOnIssues = v 
end
,
})
WebTab:CreateButton({
name = "Send Test Webhook",
callback = function()
if not Util.isValidWebhookUrl(State.Webhook.Url) then
    UI.Window:Notify({ title = "Invalid Webhook URL", content = "Paste a valid Discord webhook URL first.", duration = 3 })
    return
end
task.spawn(function()
local embed = Webhook.buildReport("Test Stats Report (Auto Fish v" .. SCRIPT_VERSION .. ")", CONST.RARITY_COLORS.Report)
embed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
embed.footer = { text = string.format("Saujana Auto Fish v%s • %s", SCRIPT_VERSION, LocalPlayer.Name) }
local okS, info = Webhook.sendNow({ embeds = { embed } })
UI.Window:Notify({ title = okS and "Webhook Sent!" or "Webhook Failed", content = okS and "Check your Discord channel." or tostring(info), duration = 4 })
end
)
end
,
})

local SetTab = UI.Window:CreateTab({ name = "Settings" })
SetTab:CreateSection({ name = "Primordial Event Settings" })
SetTab:CreateDropdown({
name = "Overlap Priority", description = "Chooses which event to fish if two Primordial windows overlap",
options = { "Rarest First", "Newest First" }, value = "Rarest First", flag = "PrimordialPriority",
callback = function(sel)
if type(sel) == "table" then
    sel = sel[1] 
end
State.Primordial.PriorityMode = (sel == "Newest First") and "Newest First" or "Rarest First"
if State.Primordial.Enabled then
    task.defer(Primordial.evaluate) 
end
end
,
})
SetTab:CreateToggle({
name = "Auto-Swap Matching Event Rod", description = "Equips Sore Kraken/Thalvyra/Celestra Rod during its event if owned",
flag = "SwapEventRod", value = true,
callback = function(v) State.Primordial.SwapEventRod = v RodSys.recheckBestRod() 
end
,
})
SetTab:CreateToggle({
name = "Return Home After Event", description = "Teleports back to your starting spot when all events end",
flag = "ReturnHomeAfterEvent", value = true,
callback = function(v) State.Primordial.ReturnHome = v 
end
,
})

SetTab:CreateSection({ name = "Click & Cast Methods" })
SetTab:CreateDropdown({
name = "Click Method", description = "Button Signals targets TapMobile • Input Signals uses mouse/input events",
options = { "Button Signals", "Input Signals" }, value = "Button Signals", flag = "ClickMethod",
callback = function(sel)
if type(sel) == "table" then
    sel = sel[1] 
end
State.ClickMethod = (sel == "Input Signals") and "Input Signals" or "Button Signals"
end
,
})
SetTab:CreateToggle({
name = "Smart Water Aim", description = "Aims CastRemote toward nearest detected water instead of Vector3.zero",
flag = "SmartWaterAim", value = false,
callback = function(v) State.EnabledSmartWaterAim = v if v then
    refreshWaterState(false) 
end
end
,
})

SetTab:CreateSection({ name = "Fast Safe Reel Tuning" })
SetTab:CreateDropdown({
name = "Fast Reel Mode", description = "Auto-Tune starts at 60% taps & locks to 100% if an Invalid happens",
options = { "Auto-Tune (Best)", "Aggressive (60%)", "Safe (100%)" }, value = "Auto-Tune (Best)", flag = "FastReelMode",
callback = function(sel)
if type(sel) == "table" then
    sel = sel[1] 
end
State.ReelTimingMode = (sel == "Aggressive (60%)" or sel == "Safe (100%)") and sel or "Auto-Tune (Best)"
recalculateSafeReelTime()
end
,
})
SetTab:CreateToggle({
name = "Auto-Tune Ping Buffer", description = "Bumps +0.03s & locks floor on Invalid; trims -0.01s every 25 clean catches",
flag = "AutoTunePingBuffer", value = true,
callback = function(v) State.AutoTunePingBuffer = v 
end
,
})
UI.PingSlider = SetTab:CreateSlider({
name = "Reel Ping Buffer", range = { 0.02, 0.50 }, increment = 0.01, value = 0.08, suffix = "s", flag = "ReelPingBuffer",
callback = function(v)
State.PingBuffer = v
if not State.IsUpdatingPingSlider then
    State.AutoTuneFloorBuffer = math.max(0.03, v)
    State.LastBufferAdjustAt = os.clock()
    State.ConsecutiveCatches = 0
end
recalculateSafeReelTime()
end
,
})

SetTab:CreateSection({ name = "Timing & Thresholds" })
SetTab:CreateSlider({ name = "Clicker Speed", range = { 0.03, 0.25 }, increment = 0.01, value = 0.13, suffix = "s", flag = "ClickerSpeed", callback = function(v) State.ClickDelay = v 
end
})
SetTab:CreateSlider({ name = "Reel At", range = { 1, 13 }, increment = 1, value = 5, suffix = "/13", flag = "ReelAt", callback = function(v) State.ReelAt = v 
end
})
SetTab:CreateSlider({ name = "Sell Interval", range = { 3, 30 }, increment = 1, value = 20, suffix = "s", flag = "SellInterval", callback = function(v) State.SellInterval = v 
end
})

SetTab:CreateSection({ name = "Overnight / Mobile" })
SetTab:CreateToggle({
name = "Battery Saver (No 3D Render)", description = "Disables 3D world rendering to reduce heat/battery overnight",
flag = "BatterySaver", value = false,
callback = function(v) State.LowPowerMode = v pcall(function() Svc.RunService:Set3dRenderingEnabled(not v) 
end
) 
end
,
})

end

-- ==================== RATE MONITOR UPDATER LOOP ====================
task.spawn(function() local function setStat(h, v) if h and type(h.Set) ==
"function" then
    pcall(h.Set, h, v) 
end
end
local function setPara(h, t, c) if
not h or type(h.Set) ~= "function" then
    return 
end
if not pcall(h.Set, h, {
title = t, content = c }) then
    pcall(h.Set, h, t .. ": " .. c) 
end
end
local
function primLine(spotKey, curLvl, gear) local spot =
CONST.PRIMORDIAL_SPOTS[spotKey] local cfg = Cfgspot.CfgFunc if not cfg then
    return spot.Name .. ": Config loading..." 
end

local nowEp = Util.serverNow()
local active = Primordial.isSpotActive(spot)
local tStr
if active then
    local okL, left = pcall(cfg.secondsLeft, nowEp)
    tStr = "ACTIVE (" .. Util.formatDur(okL and left or 0) .. " left)"
else
    local okU, untilS = pcall(cfg.secondsUntil, nowEp)
    tStr = "Opens in " .. Util.formatDur(okU and untilS or 0)
end

local _, elig = Primordial.isSpotEligible(spot, curLvl, gear)
local chStr = "--"
if type(cfg.chance) == "function" then
    local okC, bProb = pcall(cfg.chance, gear.TotalLuck)
    if okC and type(bProb) == "number" and bProb > 0 then
        local rBonus = (gear.RodInfo and gear.RodInfo.PrimordialBonus and gear.RodInfo.PrimordialBonus[spot.Name]) or 0
        chStr = Util.formatOneIn(bProb * (1 + rBonus) * (gear.PrimordialMult or 1))
    end
end
local tag = (State.Primordial.CurrentEvent == spotKey) and " [HERE]" or ""
return string.format("%s%s: %s  |  %s  |  %s", spot.Name, tag, tStr, chStr, elig)
end

local _, _, _, initXp = Monitor.readLevelXp()
State.Monitor.StartObservedXp = initXp

while State.Monitor.Active do
    task.wait(1)
    if not State.Monitor.Active then
        break 
    end

    local snap = Monitor.snapshot()
    local gear = Monitor.getGearSummary()
    local lvlCfg = Cfg.level()
    local m = State.Monitor

    setStat(UI.StatFishHr, math.floor(snap.liveFishPerHr + 0.5))
    setStat(UI.StatXpHr, math.floor(snap.xpPerHr + 0.5))
    setStat(UI.StatCaught, m.TotalCaught)
    if snap.curLevel then
        setStat(UI.StatLevel, snap.curLevel) 
    end

    local locLabel = State.Primordial.CurrentEvent and CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent].Name or "Normal Spot"
    local statusStr = State.Primordial.IsTeleporting and "Teleporting..."
    or (State.IsFarmPausedNoWater and "Paused (No water nearby)" or (State.EnabledCast and "Active" or "Idle (Auto Cast OFF)"))
    local tuneStr = (State.ReelTimingMode == "Auto-Tune (Best)") and (State.AutoTuneUseFullTaps and "100% Locked" or "60% Aggressive") or State.ReelTimingMode

    setPara(UI.ParaRate, "Fishing Efficiency & Fails", string.format(
    "Status: %s  |  Spot: %s  |  Uptime: %s\nLast Catch: %s\nCaught: %s  |  Failed: %d (Success: %.1f%%)\nFail Log: Invalid %d • Lost %d • Timeout %d • Full %d • Other %d\nLive Rate (2m): %.1f fish/min  (%s fish/hr)\nSession Avg: %.1f fish/min  (%s fish/hr)\nAvg Timings: Bite %.2fs • Reel %.2fs • Full Cycle %.2fs\nTuning: %s  |  Ping Buffer: %.2fs (Floor: %.2fs)",
    statusStr, locLabel, Util.formatClock(snap.elapsed), m.LastFishText, Util.formatNum(m.TotalCaught), m.TotalFailed, snap.successPct,
    m.FailReasons.Invalid or 0, m.FailReasons.Lost or 0, m.FailReasons.Timeout or 0, m.FailReasons.Full or 0, m.FailReasons.Other or 0,
    snap.liveFishPerMin, Util.formatNum(snap.liveFishPerHr), snap.sessionFishPerMin, Util.formatNum(snap.sessionFishPerHr),
    snap.avgBite, snap.avgReel, snap.avgCycle, tuneStr, State.PingBuffer, State.AutoTuneFloorBuffer
    ))

    local enhStr = (#gear.EnhanceNames > 0) and table.concat(gear.EnhanceNames, ", ")
    or (gear.EnhanceLuck > 0 and ("+" .. gear.EnhanceLuck .. " Luck") or "None")
    setPara(UI.ParaGear, "Active Gear, Luck & Odds", string.format(
    "Rod: %s (Luck %.2f • %d Taps • Max: %s)\nEnhance: %s  |  Bait: %s (+%.1f Luck)\nGlobal Luck: %.1fx  |  Effective Cast Luck: %.1fx\nDrop Odds: Mythic %s • Secret %s • Supremacy %s",
    gear.RodName, gear.RodLuck, gear.RodTaps, gear.RodMaxRarity, enhStr, gear.BaitName, gear.BaitLuck,
    gear.GlobalLuck, gear.TotalLuck, Util.formatOneIn(gear.MythicProb), Util.formatOneIn(gear.SecretProb), Util.formatOneIn(gear.SupremacyProb)
    ))

    local lvlLine, etaNext, eta10, etaRank, etaMax = "Level: Waiting for Profile HUD / Attributes", "--", "--", "--", "--"
    if snap.curLevel and lvlCfg then
        local maxL = lvlCfg.MaxLevel or 2000
        local rInfo = type(lvlCfg.rankFor) == "function" and lvlCfg.rankFor(snap.curLevel) or nil
        local rTitle = rInfo and rInfo.Title or "Unknown"
        local xpReq = snap.curXpReq or (type(lvlCfg.xpToNext) == "function" and lvlCfg.xpToNext(snap.curLevel) or 0)
        local xpInto = snap.curXpInto or 0
        if snap.curLevel >= maxL then
            lvlLine = string.format("Level: %d (MAX) • %s", snap.curLevel, rTitle)
            etaNext, eta10, etaRank, etaMax = "MAX", "MAX", "MAX", "MAX"
        else
            local pct = xpReq > 0 and ((xpInto / xpReq) * 100) or 0
            lvlLine = string.format("Level: %d (%s)  |  XP: %s / %s (%.1f%%)", snap.curLevel, rTitle, Util.formatNum(xpInto), Util.formatNum(xpReq), pct)
            if snap.xpPerSec > 0 and snap.curTotalXp and type(lvlCfg.totalForLevel) == "function" then
                etaNext = Util.formatDur(math.max(0, lvlCfg.totalForLevel(snap.curLevel + 1) - snap.curTotalXp) / snap.xpPerSec)
                local t10 = math.min(maxL, snap.curLevel + 10)
                eta10 = string.format("%s (Lv %d)", Util.formatDur(math.max(0, lvlCfg.totalForLevel(t10) - snap.curTotalXp) / snap.xpPerSec), t10)
                local nRank = nil
                if type(lvlCfg.Ranks) == "table" then
                    for _, r in ipairs(lvlCfg.Ranks) do
                        if r.Min > snap.curLevel then
                            nRank = r.Min break 
                        end
                    end
                end
                etaRank = nRank and string.format("%s (Lv %d)", Util.formatDur(math.max(0, lvlCfg.totalForLevel(nRank) - snap.curTotalXp) / snap.xpPerSec), nRank) or "Max Rank"
                etaMax = Util.formatDur(math.max(0, lvlCfg.totalForLevel(maxL) - snap.curTotalXp) / snap.xpPerSec)
            end
        end
    elseif snap.xpPerSec > 0 and lvlCfg and type(lvlCfg.xpToNext) == "function" then
            etaNext = Util.formatDur(lvlCfg.xpToNext(1) / snap.xpPerSec) .. " (at Lv 1 rate)"
        end

        setPara(UI.ParaXp, "XP & Level Estimates", string.format(
        "%s\nSource: %s  |  Session XP: +%s (Fish: +%s)\nXP Rate: %s XP/min  |  %s XP/hr\nLevel Rate: %.2f Levels/hr\nETA Next Lv: %s  |  Next Rank: %s\nETA +10 Lvs: %s  |  Max (2000): %s",
        lvlLine, snap.xpSourceLabel, Util.formatNum(snap.activeXpGain), Util.formatNum(m.SessionFishXp),
        Util.formatNum(snap.xpPerMin), Util.formatNum(snap.xpPerHr), snap.levelsPerHr, etaNext, etaRank, eta10, etaMax
        ))

        setPara(UI.ParaPrimordial, "Primordial Windows", string.format(
        "%s\n%s\n%s",
        primLine("SoreKraken", snap.curLevel, gear),
        primLine("Thalvyra", snap.curLevel, gear),
        primLine("Celestra", snap.curLevel, gear)
        ))

        setPara(UI.ParaRarity, "Rarity Breakdown", string.format(
        "Common: %d  |  Uncommon: %d  |  Rare: %d  |  Epic: %d\nMythic: %d  |  Secret: %d  |  Supremacy: %d  |  Primordial: %d",
        m.RarityCounts.Common or 0, m.RarityCounts.Uncommon or 0, m.RarityCounts.Rare or 0, m.RarityCounts.Epic or 0,
        m.RarityCounts.Mythic or 0, m.RarityCounts.Secret or 0, m.RarityCounts.Supremacy or 0, m.RarityCounts.Primordial or 0
        ))
    end

end
)

-- ==================== STARTUP SEQUENCE ==================== State.EnabledCast
= true State.EnabledFastSafeReel = true State.EnabledColorReel = false
State.EnabledGameAutoCast = false updateLoop()

if UI.AutoCastToggle and UI.AutoCastToggle.Set then
    UI.AutoCastToggle:Set(true)
end
if UI.FastSafeReelToggle and UI.FastSafeReelToggle.Set then
    UI.FastSafeReelToggle:Set(true) 
end
if UI.ColorReelToggle and
UI.ColorReelToggle.Set then
    UI.ColorReelToggle:Set(false) 
end
if
UI.GameAutoCastToggle and UI.GameAutoCastToggle.Set then
    UI.GameAutoCastToggle:Set(false) 
end

task.delay(2.5, function() if not State.Monitor.Active then
    return 
end
refreshWaterState(false) if not State.EnabledGameAutoCast and Cache.AutoBtn and
isGameAutoCastOn() then
    setGameAutoCast(false) 
end
if State.Primordial.Enabled
then
    Primordial.evaluate() 
end
Webhook.connected() 
end
)

print(string.format("[Auto Fish v%s] Ready: Fast Safe Reel, Ping Auto-Tune,
Primordial Auto-TP, Rate Monitor & Webhook.", SCRIPT_VERSION))

task.defer(function() UI.Window:Notify({ title = "Auto Fish v" ..
SCRIPT_VERSION, content = State.Webhook.Enabled and "Primordial Auto-TP + Rate
Monitor + Webhook Active" or "Primordial Auto-TP + Rate Monitor Active",
duration = 4, }) 
end
)
