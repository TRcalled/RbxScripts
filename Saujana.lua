local SCRIPT_VERSION = "3.0.0"
local TARGET_PLACE_ID = 89346234653070

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if game.PlaceId ~= TARGET_PLACE_ID then
    return
end

local envGlobal: { [string]: any } = (type(getgenv) == "function" and getgenv()) or {}
if type(envGlobal._AutoFishCleanup) == "function" then
    pcall(function()
        envGlobal._AutoFishCleanup()
    end)
end

local Svc = {
    Players = game:GetService("Players"),
    VirtualUser = game:GetService("VirtualUser"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    UIS = game:GetService("UserInputService"),
    Collection = game:GetService("CollectionService"),
    Http = game:GetService("HttpService"),
    Gui = game:GetService("GuiService"),
    CoreGui = game:GetService("CoreGui"),
    Lighting = game:GetService("Lighting"),
}

local LocalPlayer = Svc.Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Svc.Players.LocalPlayer
end

if type(envGlobal._AntiAFKState) == "table" then
    envGlobal._AntiAFKState.Active = false
end
local AntiAFKState = { Active = true, Interval = 120 }
envGlobal._AntiAFKState = AntiAFKState

local function sendAntiAFKPulse()
    pcall(function()
        Svc.VirtualUser:CaptureController()
        Svc.VirtualUser:ClickButton2(Vector2.zero)
    end)
end

task.spawn(function()
    while AntiAFKState.Active do
        task.wait(AntiAFKState.Interval)
        if not AntiAFKState.Active then
            break
        end
        sendAntiAFKPulse()
    end
end)

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

local CONST = {
    DEFAULT_MINIGAME = {
        StartingProgress = 0.4,
        MinSecondsPerTap = 0.06,
        AutoSecondsPerTap = 0.1,
        AutoExtraTaps = 2,
        CastCooldown = 0.6,
    },
    DEFAULT_FISH_XP = {
        Common = 5,
        Uncommon = 8,
        Rare = 15,
        Epic = 30,
        Mythic = 120,
        Secret = 600,
        Supremacy = 3000,
        Primordial = 8000,
    },
    DEFAULT_PLAYTIME_QUESTS = {
        { Minutes = 5, Coin = 25000 },
        { Minutes = 10, Coin = 50000 },
        { Minutes = 15, Coin = 75000 },
        { Minutes = 30, Coin = 150000 },
        { Minutes = 45, Coin = 200000 },
        { Minutes = 60, Coin = 300000 },
        { Minutes = 90, Coin = 400000 },
        { Minutes = 120, Coin = 600000 },
        { Minutes = 180, Coin = 900000 },
        { Minutes = 240, Coin = 1200000 },
        { Minutes = 300, Coin = 1600000 },
        { Minutes = 360, Coin = 2000000 },
        { Minutes = 480, Coin = 3500000 },
        { Minutes = 720, Coin = 4000000 },
    },
    DEFAULT_MAZE_MIN_SECONDS = {
        Easy = 6,
        Medium = 12,
        Hard = 20,
        Extreme = 30,
        Nightmare = 30,
    },
    PERSONAL_BOOST_IDS = { "Coin", "Exp", "Supremacy", "Primordial" },
    RARITY_COLORS = {
        Mythic = 0xFF6048,
        Secret = 0xFFD65A,
        Supremacy = 0xFF48D6,
        Primordial = 0xAAFF00,
        Report = 0x3B82F6,
        Alert = 0xEF4444,
        Resume = 0x22C55E,
        Coffee = 0xD97706,
        Quest = 0xF59E0B,
        Event = 0xFF8CC3,
        Afk = 0xA855F7,
    },
    NOTIFY_RARITIES = { Mythic = true, Secret = true, Supremacy = true, Primordial = true },
    CLOSE_KEYWORDS = { "close", "ok", "okay", "claim", "continue", "confirm", "dismiss", "exit", "skip", "done" },
    MUSIC_GENRES = { "All Mix", "Indonesia", "English", "DJ", "Japanese", "Philippines", "Malaysia", "Java" },
    COFFEE_DEFAULT_LIMIT = 5,
    COFFEE_MEMBER_LIMIT = 12,
    COFFEE_ORDER = { "SaujanaSignature", "LuckyShot", "FortuneBrew" },
    COFFEE_DEFAULT_COSTS = {
        FortuneBrew = { Cost = { Mythic = 28 }, MemberCost = { Mythic = 18 } },
        LuckyShot = { Cost = { Secret = 12 }, MemberCost = { Secret = 6 } },
        SaujanaSignature = { Cost = { Supremacy = 3 }, MemberCost = { Supremacy = 1 } },
    },
    COFFEE_NAMES = {
        ["Fortune Brew"] = true,
        ["Lucky Shot"] = true,
        ["Saujana Signature"] = true,
    },
    BLOCKED_FX_GUIS = {
        FishFxGui = true,
        CelestraVignette = true,
        ThalvyraVignette = true,
        SoreKrakenVignette = true,
        SoreKrakenHitFx = true,
        SoreAmuletFx = true,
        CoinGainFxUI = true,
    },
    RESTORE_GAME_GUIS = {
        "GameUI",
        "FishingGui",
        "Backpack",
        "TouchGui",
        "FishLuckGui",
        "NotificationsUI",
        "ToastNotifications",
        "FishingNotifications",
        "ProgressHintsUI",
        "GalatamaUI",
    },
    CONFIG_LIST = {
        "FishConfig",
        "RodConfig",
        "RodSkinConfig",
        "BaitConfig",
        "RodEnhanceConfig",
        "RodAscensionConfig",
        "LevelConfig",
        "DailyQuestConfig",
        "DailyLoginConfig",
        "EventConfig",
        "CelestraConfig",
        "ThalvyraConfig",
        "SoreKrakenConfig",
    },
    PRIMORDIAL_ORDER = { "SoreKraken", "Thalvyra", "Celestra" },
    PRIMORDIAL_SPOTS = {
        SoreKraken = {
            Key = "SoreKraken",
            Name = "Sore Kraken",
            Priority = 3,
            CfgName = "SoreKrakenConfig",
            StateName = "SoreKrakenState",
            NotifUI = "SoreKrakenNotifUI",
            UnlockAttr = "SoreKrakenUnlocked",
            CaughtAttr = "SoreKrakenCaught",
            PreferRod = "Sore Kraken Rod",
            MinKg = 1000,
            CFrame = CFrame.new(-16547.748, 3776.079, -4804.017, 0.3007, -0.0000, 0.9537, 0.0000, 1.0000, 0.0000, -0.9537, 0.0000, 0.3007),
        },
        Thalvyra = {
            Key = "Thalvyra",
            Name = "Thalvyra",
            Priority = 2,
            CfgName = "ThalvyraConfig",
            StateName = "ThalvyraState",
            NotifUI = "ThalvyraNotifUI",
            UnlockAttr = "CrimsonUnlocked",
            CaughtAttr = "ThalvyraCaught",
            PreferRod = "Thalvyra Rod",
            MinKg = 900,
            CFrame = CFrame.new(-16408.523, 4193.781, -2052.475, 0.7052, -0.0000, -0.7090, 0.0000, 1.0000, -0.0000, 0.7090, 0.0000, 0.7052),
        },
        Celestra = {
            Key = "Celestra",
            Name = "Celestra",
            Priority = 1,
            CfgName = "CelestraConfig",
            StateName = "CelestraState",
            NotifUI = "CelestraNotifUI",
            UnlockAttr = "NpcTalkedRevano",
            CaughtAttr = "CelestraCaught",
            PreferRod = "Celestra Rod",
            MinKg = 750,
            CFrame = CFrame.new(-16322.375, 3885.807, -2916.187, 0.6414, 0.0000, 0.7672, -0.0000, 1.0000, -0.0000, -0.7672, 0.0000, 0.6414),
        },
    },
}

local Cache: { [string]: any } = {
    Configs = {},
    States = {},
    Fallbacks = {},
    SkinDisplays = nil,
    CoffeeNames = nil,
    CoffeeOrder = nil,
    FishingFrame = nil,
    InfoLabel = nil,
    TapBtn = nil,
    TapText = nil,
    BarFill = nil,
    AutoBtn = nil,
    RodContent = nil,
    ItemsFrame = nil,
    GearSummary = nil,
    GearSummaryAt = 0,
    VipCached = false,
    VipCheckedAt = 0,
    SafeUiContainer = nil,
    CheckedUiContainer = false,
}

do
    local function makeChanceFn(cMin, cMax, lFloor, lCap)
        return function(luck)
            local v1 = math.log(lFloor)
            local v2 = math.log(lCap)
            local v3 = math.clamp((math.log(math.max(tonumber(luck) or 1, 1)) - v1) / (v2 - v1), 0, 1)
            return cMin + (cMax - cMin) * v3
        end
    end

    local cel = {
        FishName = "Celestra",
        WindowSeconds = 1800,
        CycleSeconds = 7200,
        ChanceMin = 6.12366238e-05 * 0.5 * 1.1 * (2 / 3) * 1.05,
        ChanceMax = 0.00018345682749999997 * 0.5 * 1.1 * (2 / 3) * 1.05,
        LuckFloor = 9,
        LuckCap = 70,
        RequireLevel = 80,
        ForceAttribute = "CelestraForceUntil",
    }
    cel.chance = makeChanceFn(cel.ChanceMin, cel.ChanceMax, cel.LuckFloor, cel.LuckCap)
    function cel.isActive(nowEp)
        local t = nowEp or os.time()
        local f = tonumber(Svc.ReplicatedStorage:GetAttribute(cel.ForceAttribute)) or 0
        if (f - t) > 0 then
            return true
        end
        return (t % cel.CycleSeconds) < cel.WindowSeconds
    end
    function cel.secondsLeft(nowEp)
        local t = nowEp or os.time()
        local f = tonumber(Svc.ReplicatedStorage:GetAttribute(cel.ForceAttribute)) or 0
        if (f - t) > 0 then
            return f - t
        end
        local ph = t % cel.CycleSeconds
        return ph < cel.WindowSeconds and (cel.WindowSeconds - ph) or 0
    end
    Cache.Fallbacks.CelestraConfig = cel

    local tha = {
        FishName = "Thalvyra",
        WindowSeconds = 1800,
        CycleSeconds = 14400,
        Offset = 3600,
        AvoidGap = 120,
        ChanceMin = cel.ChanceMin * 0.6380296631758927,
        ChanceMax = cel.ChanceMax * 0.6380296631758927,
        LuckFloor = 9,
        LuckCap = 70,
        RequireLevel = 150,
        ForceAttribute = "ThalvyraForceUntil",
    }
    tha.chance = makeChanceFn(tha.ChanceMin, tha.ChanceMax, tha.LuckFloor, tha.LuckCap)
    local function thaCurrentStart(t)
        local base = math.floor((t - tha.Offset) / tha.CycleSeconds)
        for i = base - 1, base do
            local st = i * tha.CycleSeconds + tha.Offset
            for _ = 1, 3 do
                local cb = math.floor(st / cel.CycleSeconds)
                local ov = nil
                for j = cb - 1, cb + 1 do
                    local cs = j * cel.CycleSeconds
                    if st < cs + cel.WindowSeconds and cs < st + tha.WindowSeconds then
                        ov = cs + cel.WindowSeconds
                        break
                    end
                end
                if not ov then
                    break
                end
                st = ov + tha.AvoidGap
            end
            if st <= t and t < st + tha.WindowSeconds then
                return st
            end
        end
        return nil
    end
    function tha.isActive(nowEp)
        local t = nowEp or os.time()
        local f = tonumber(Svc.ReplicatedStorage:GetAttribute(tha.ForceAttribute)) or 0
        if (f - t) > 0 then
            return true
        end
        return thaCurrentStart(t) ~= nil
    end
    function tha.secondsLeft(nowEp)
        local t = nowEp or os.time()
        local f = tonumber(Svc.ReplicatedStorage:GetAttribute(tha.ForceAttribute)) or 0
        if (f - t) > 0 then
            return f - t
        end
        local st = thaCurrentStart(t)
        return st and (st + tha.WindowSeconds - t) or 0
    end
    Cache.Fallbacks.ThalvyraConfig = tha

    local sk = {
        FishName = "Sore Kraken",
        WindowSeconds = 1800,
        CycleSeconds = 14400,
        Offset = 10800,
        ChanceMin = cel.ChanceMin * 0.34425405010186544,
        ChanceMax = cel.ChanceMax * 0.34425405010186544,
        LuckFloor = 9,
        LuckCap = 70,
        RequireLevel = 300,
        ForceAttribute = "SoreKrakenForceUntil",
    }
    sk.chance = makeChanceFn(sk.ChanceMin, sk.ChanceMax, sk.LuckFloor, sk.LuckCap)
    local function skCurrentStart(t)
        local st = math.floor((t - sk.Offset) / sk.CycleSeconds) * sk.CycleSeconds + sk.Offset
        if st <= t and t < st + sk.WindowSeconds then
            return st
        end
        return nil
    end
    function sk.isActive(nowEp)
        local t = nowEp or os.time()
        local f = tonumber(Svc.ReplicatedStorage:GetAttribute(sk.ForceAttribute)) or 0
        if (f - t) > 0 then
            return true
        end
        return skCurrentStart(t) ~= nil
    end
    function sk.secondsLeft(nowEp)
        local t = nowEp or os.time()
        local f = tonumber(Svc.ReplicatedStorage:GetAttribute(sk.ForceAttribute)) or 0
        if (f - t) > 0 then
            return f - t
        end
        local st = skCurrentStart(t)
        return st and (st + sk.WindowSeconds - t) or 0
    end
    Cache.Fallbacks.SoreKrakenConfig = sk
end

local Cfg = {}

function Cfg.get(name: string)
    if Cache.Configs[name] then
        return Cache.Configs[name]
    end
    local shared = Svc.ReplicatedStorage:FindFirstChild("Shared")
    local cfgFolder = shared and shared:FindFirstChild("Config")
    local mod = cfgFolder and cfgFolder:FindFirstChild(name)
    if mod then
        local okCfg, tbl = pcall(function()
            return require(mod)
        end)
        if okCfg and type(tbl) == "table" then
            Cache.Configs[name] = tbl
            return tbl
        end
    end
    return Cache.Fallbacks[name]
end

function Cfg.sharedMod(name: string)
    if Cache.States[name] then
        return Cache.States[name]
    end
    local shared = Svc.ReplicatedStorage:FindFirstChild("Shared")
    local mod = shared and shared:FindFirstChild(name)
    if mod then
        local okMod, tbl = pcall(function()
            return require(mod)
        end)
        if okMod and type(tbl) == "table" then
            Cache.States[name] = tbl
            return tbl
        end
    end
    return nil
end

function Cfg.minigame()
    local fc = Cfg.get("FishConfig")
    if fc and type(fc.Minigame) == "table" then
        return fc.Minigame
    end
    return CONST.DEFAULT_MINIGAME
end

function Cfg.rodSkin()
    local rsc = Cfg.get("RodSkinConfig")
    if rsc and not Cache.SkinDisplays and type(rsc.Skins) == "table" then
        Cache.SkinDisplays = {}
        for k, info in pairs(rsc.Skins) do
            Cache.SkinDisplays[k] = true
            if type(info) == "table" and type(info.Display) == "string" then
                Cache.SkinDisplays[info.Display] = true
            end
        end
    end
    return rsc
end

function Cfg.syncCoffeeCache()
    local cc = Cfg.get("CoffeeConfig")
    if cc and not Cache.CoffeeOrder and type(cc.Coffees) == "table" then
        local names = {}
        local ordered = {}
        for _, entry in ipairs(cc.Coffees) do
            if type(entry) == "table" and type(entry.Id) == "string" then
                table.insert(ordered, entry)
                if type(entry.Name) == "string" then
                    names[entry.Name] = true
                end
            end
        end
        table.sort(ordered, function(a, b)
            return (tonumber(a.Order) or tonumber(a.Duration) or 0) > (tonumber(b.Order) or tonumber(b.Duration) or 0)
        end)
        local idList = {}
        for _, entry in ipairs(ordered) do
            table.insert(idList, entry.Id)
        end
        if #idList > 0 then
            Cache.CoffeeOrder = idList
            Cache.CoffeeNames = names
        end
    end
    return cc
end

local Util = {}

function Util.trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return string.match(s, "^%s*(.-)%s*$") or ""
end

function Util.isValidWebhookUrl(url)
    return string.match(Util.trim(url), "^https?://[%w%.%-]+/api/webhooks/") ~= nil
end

function Util.normalizeGenre(raw)
    if type(raw) ~= "string" then
        return "All Mix"
    end
    local low = string.lower(Util.trim(raw))
    for _, g in ipairs(CONST.MUSIC_GENRES) do
        if string.lower(g) == low then
            return g
        end
    end
    return "All Mix"
end

function Util.serverNow()
    local okT, t = pcall(function()
        return workspace:GetServerTimeNow()
    end)
    if okT and type(t) == "number" and t > 100000 then
        return math.floor(t)
    end
    return os.time()
end

function Util.formatNum(n)
    local num = math.floor((tonumber(n) or 0) + 0.5)
    local neg = num < 0
    local s = tostring(math.abs(num))
    local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    if neg then
        return "-" .. formatted
    end
    return formatted
end

function Util.formatShort(n)
    local v = tonumber(n) or 0
    if v >= 1000000000 then
        return string.format("%.2fB", v / 1000000000)
    elseif v >= 1000000 then
        return string.format("%.2fM", v / 1000000)
    elseif v >= 1000 then
        return string.format("%.1fK", v / 1000)
    end
    return tostring(math.floor(v + 0.5))
end

function Util.formatDur(seconds)
    local secNum = tonumber(seconds)
    if not secNum or secNum ~= secNum or secNum == math.huge then
        return "--"
    end
    if secNum <= 0 then
        return "Now"
    end
    local total = math.floor(secNum + 0.5)
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
    end
    return string.format("%ds", secs)
end

function Util.formatClock(seconds)
    local total = math.floor(math.max(0, tonumber(seconds) or 0))
    return string.format("%02d:%02d:%02d", math.floor(total / 3600), math.floor((total % 3600) / 60), total % 60)
end

function Util.formatOneIn(prob)
    local pNum = tonumber(prob)
    if not pNum or pNum <= 0 then
        return "--"
    end
    return "1 in " .. Util.formatNum(math.max(1, math.floor((1 / pNum) + 0.5)))
end

function Util.getExecutorFunc(name)
    local fenv: { [string]: any } = (type(getfenv) == "function" and getfenv()) or {}
    local fn = envGlobal[name] or fenv[name]
    if type(fn) == "function" then
        return fn
    end
    return nil
end

function Util.canUseContainerInSpawn(target)
    if typeof(target) ~= "Instance" then
        return false
    end
    local finished = false
    local passed = false
    task.spawn(function()
        local ok = pcall(function()
            local sg = Instance.new("ScreenGui")
            sg.Name = "_CapProbe"
            sg.Enabled = false
            sg.Parent = target
            local fr = Instance.new("Frame")
            fr.Name = "_ProbeFrame"
            fr.Parent = sg
            local found = sg:FindFirstChild("_ProbeFrame")
            if found then
                found:Destroy()
            end
            local _ = target:FindFirstChild("_CapProbe")
            sg:Destroy()
        end)
        passed = ok == true
        finished = true
    end)
    local t0 = os.clock()
    while not finished and (os.clock() - t0) < 0.4 do
        task.wait()
    end
    return finished and passed
end

function Util.getSafeUiContainer(forceRefresh)
    if Cache.CheckedUiContainer and not forceRefresh and Cache.SafeUiContainer and Cache.SafeUiContainer.Parent then
        return Cache.SafeUiContainer, (Cache.SafeUiContainer == PlayerGui)
    end
    Cache.CheckedUiContainer = true

    local getHuiFn = Util.getExecutorFunc("gethui")
    if getHuiFn then
        local okH, hui = pcall(function()
            return getHuiFn()
        end)
        if okH and Util.canUseContainerInSpawn(hui) then
            Cache.SafeUiContainer = hui
            return hui, false
        end
    end

    if Util.canUseContainerInSpawn(Svc.CoreGui) then
        Cache.SafeUiContainer = Svc.CoreGui
        return Svc.CoreGui, false
    end

    Cache.SafeUiContainer = PlayerGui
    return PlayerGui, true
end

function Util.fireSignals(signalObj, ...)
    if not signalObj then
        return false
    end
    local fired = false
    local args = table.pack(...)
    local getConnsFn = Util.getExecutorFunc("getconnections")
    local fireSigFn = Util.getExecutorFunc("firesignal")

    if getConnsFn then
        local okConns, conns = pcall(function()
            return getConnsFn(signalObj)
        end)
        if okConns and type(conns) == "table" and #conns > 0 then
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

    if not fired and fireSigFn then
        local okSig = pcall(function()
            fireSigFn(signalObj, table.unpack(args, 1, args.n))
        end)
        if not okSig and args.n > 0 then
            okSig = pcall(function()
                fireSigFn(signalObj)
            end)
        end
        if okSig then
            fired = true
        end
    end
    return fired
end

function Util.mockInput(state, x, y)
    return {
        UserInputType = Enum.UserInputType.MouseButton1,
        UserInputState = state or Enum.UserInputState.Begin,
        KeyCode = Enum.KeyCode.Unknown,
        Position = Vector3.new(x or 0, y or 0, 0),
        Delta = Vector3.zero,
    }
end

function Util.triggerBtn(btn)
    if not btn then
        return
    end
    pcall(function()
        if btn.Name == "TapMobile" then
            if not btn.Visible then
                btn.Visible = true
            end
            if btn:IsA("GuiObject") and not btn.Active then
                btn.Active = true
            end
        end
        local cx = btn.AbsolutePosition.X + (btn.AbsoluteSize.X / 2)
        local cy = btn.AbsolutePosition.Y + (btn.AbsoluteSize.Y / 2)
        local bIn = Util.mockInput(Enum.UserInputState.Begin, cx, cy)
        local eIn = Util.mockInput(Enum.UserInputState.End, cx, cy)

        Util.fireSignals(btn.MouseButton1Down, cx, cy)
        Util.fireSignals(btn.Activated, bIn, 1)
        Util.fireSignals(btn.MouseButton1Click)
        Util.fireSignals(btn.MouseButton1Up, cx, cy)
        if btn:IsA("GuiButton") then
            pcall(function()
                Util.fireSignals(btn.TouchTap, { Vector2.new(cx, cy) })
            end)
        end
        if btn.Name == "TapMobile" or not btn:IsA("GuiButton") then
            Util.fireSignals(btn.InputBegan, bIn, false)
            Util.fireSignals(btn.InputEnded, eIn, false)
        end
    end)
end

function Util.groundCFrame(rawCF, lookAtPos)
    local exclude = {}
    for _, plr in ipairs(Svc.Players:GetPlayers()) do
        if plr.Character then
            table.insert(exclude, plr.Character)
        end
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude
    params.IgnoreWater = true

    local hit = workspace:Raycast(rawCF.Position + Vector3.new(0, 6, 0), Vector3.new(0, -24, 0), params)
    local finalPos = rawCF.Position
    if hit and hit.Instance and hit.Instance.CanCollide then
        finalPos = Vector3.new(rawCF.Position.X, hit.Position.Y + 3, rawCF.Position.Z)
    end
    if lookAtPos then
        local flatTarget = Vector3.new(lookAtPos.X, finalPos.Y, lookAtPos.Z)
        if (flatTarget - finalPos).Magnitude > 0.1 then
            return CFrame.lookAt(finalPos, flatTarget)
        end
    end
    return CFrame.new(finalPos) * rawCF.Rotation
end

local Remotes: { [string]: any } = {
    Cast = nil,
    Reel = nil,
    Cancel = nil,
    SellAll = nil,
    SetAuto = nil,
    GetState = nil,
    GetFish = nil,
    Server = nil,
    Fx = nil,
    CoffeeBrew = nil,
    CoffeeHold = nil,
    CoffeeMeet = nil,
    QuestGetState = nil,
    QuestClaim = nil,
    QuestWeeklyGet = nil,
    QuestWeeklyClaim = nil,
    QuestWeeklyBonus = nil,
    DailyLoginGetState = nil,
    DailyLoginClaim = nil,
    SoreKrakenQuest = nil,
    EventGet = nil,
    EventClaim = nil,
}

local Conns: { [string]: any } = {
    Global = {},
    Char = {},
    LevelUp = {},
    PrimNotif = {},
    DisabledFxConns = {},
    Gradient = nil,
    BarFill = nil,
    BarSize = nil,
    InfoText = nil,
    FishingVis = nil,
    GuiDesc = nil,
    Server = nil,
    Heartbeat = nil,
    WorkspaceFx = nil,
    LightingFx = nil,
    CameraType = nil,
    QuestPlaytime = nil,
    QuestWeekly = nil,
    EventClaimable = nil,
    InAfkServer = nil,
}

local UI: { [string]: any } = {
    Window = nil,
    StatusTag = nil,
    AutoCastToggle = nil,
    PrimordialToggle = nil,
    ReturnHomeToggle = nil,
    GameAutoCastToggle = nil,
    FastSafeReelToggle = nil,
    ColorReelToggle = nil,
    AutoCoffeeToggle = nil,
    PingSlider = nil,
}

local State: { [string]: any } = {
    EnabledCast = true,
    CastMode = "Smart Cast",
    EnabledClick = false,
    EnabledReel = false,
    EnabledFastSafeReel = true,
    EnabledColorReel = false,
    EnabledSell = false,
    EnabledGameAutoCast = false,
    EnabledAutoEquip = true,
    EnabledAutoCloseLevelUp = true,
    EnabledPauseNoWater = true,
    EnabledSmartWaterAim = true,
    LowPowerMode = false,
    ClickMethod = "Button Signals",
    ReelTimingMode = "Fastest Zero-Fail (Auto)",
    AutoTunePingBuffer = true,

    DetectedBait = nil,
    RodData = {
        rods = {},
        rodEnh = {},
        rodEnh2 = {},
        rodEnh3 = {},
        rodAsc = {},
    },
    BagFishCounts = nil,
    BagFishCountsAt = 0,
    LastSlowTickAt = 0,
    LastClickTime = 0,
    LastSellTime = 0,
    ProactiveSellCooldownUntil = 0,
    LastCastSentAt = 0,
    CastBusyUntil = 0,
    LastAutoBtnClick = 0,
    LastAutoReelFire = 0,
    LastAutoCheckTime = 0,
    LastRemoteResolveTime = 0,
    LastServerActivityAt = os.clock(),
    LastLevelUpClose = 0,
    LastUiRodClickAt = 0,
    LastRodCheckAt = 0,
    LastWaterCheckAt = 0,
    LastFullWaterScanAt = 0,
    LastWaterScanPos = nil,
    LastWaterHitPos = nil,
    IsSelling = false,
    FishingOpenedAt = 0,
    SawProgressBelowTarget = false,

    IsNearWater = true,
    IsFarmPausedNoWater = false,
    InAfkServer = false,
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
    PingBuffer = 0.03,
    AutoTuneUseFullTaps = true,
    AutoTuneFloorBuffer = 0.02,
    LastBufferAdjustAt = 0,
    ConsecutiveCatches = 0,
    ConsecutiveInvalidFails = 0,
    ConsecutiveBusyFails = 0,
    IsUpdatingPingSlider = false,

    ClickDelay = 0.13,
    ReelAt = 5,
    SellInterval = 20,
    CastPos = (typeof(vector) == "table" and vector.create) and vector.create(0, 0, 0) or Vector3.new(0, 0, 0),
    CastPower = 1,

    Primordial = {
        Enabled = true,
        CheckUnlocks = false,
        PriorityMode = "Rarest First",
        SwapEventRod = true,
        ReturnHome = false,
        CurrentEvent = nil,
        HomeCFrame = nil,
        IsTeleporting = false,
        TeleportStartedAt = 0,
        LastCheckAt = 0,
        LastTeleportAt = 0,
        ActivatedAt = {},
        BlockedUntil = {},
        NotifUntil = {},
    },

    Coffee = {
        Enabled = true,
        TriggerMode = "Primordial Events Only",
        Preference = "Best Available",
        AllowFishTrade = true,
        AutoVisitFellicia = true,
        IsDrinking = false,
        HoldingTool = false,
        DrinkStartedAt = 0,
        LastAttemptAt = 0,
        BrewCooldownUntil = 0,
        DailyLimitDay = nil,
        LevelLockedUntil = 0,
        NoFelliciaUntil = 0,
        FelliciaCFrame = typeof(envGlobal._SaujanaFelliciaCF) == "CFrame" and envGlobal._SaujanaFelliciaCF or nil,
        WarnedHotbar = false,
    },

    Perf = {
        LowestGraphics = true,
        DisableCutscenes = true,
        AutoDismissLoading = true,
        MusicGenre = Util.normalizeGenre(envGlobal.AutoFishMusicGenre),
        LoadingHandled = false,
    },

    Quests = {
        Mode = "Auto-Claim & Notify",
        AutoDailyLogin = true,
        AutoSakuraEvent = true,
        NotifyWebhook = true,
        IsClaiming = false,
        IsClaimingEvent = false,
        IsCheckingDaily = false,
        LastPlaytimeAlert = "",
        LastWeeklyAlert = "",
        LastEventAlert = "",
        LastDailyLoginUtcDay = nil,
        DailyLoginNextCheckAt = 0,
        LastQuestCheckAt = 0,
    },

    Maze = {
        AutoDaily = false,
        TimingMode = "Safe (+1.6s)",
        VisitHoneymoon = true,
        IsRunning = false,
        StartedAt = 0,
        LastAutoCheckAt = 0,
        CooldownUntil = 0,
        HoneymoonCFrame = typeof(envGlobal._SaujanaHoneymoonCF) == "CFrame" and envGlobal._SaujanaHoneymoonCF or nil,
        LastStatus = "Idle",
    },
}

do
    local envRaw = envGlobal.AutoFishWebhook or ""
    local envUrl = Util.trim(envRaw)
    local envValid = Util.isValidWebhookUrl(envUrl)
    State.Webhook = {
        Active = true,
        Enabled = envValid,
        Url = envValid and envUrl or "",
        NotifyRareCatches = true,
        NotifyPrimordial = true,
        NotifyConnections = true,
        PeriodicReport = true,
        AlertOnIssues = true,
        IntervalMinutes = 15,
        LastReportAt = os.clock(),
        LastAlertAt = 0,
        Queue = {},
        SentCount = 0,
        FailedCount = 0,
    }
end

State.Monitor = {
    Active = true,
    SessionStart = os.clock(),
    TotalCaught = 0,
    TotalFailed = 0,
    InvalidFails = 0,
    SessionFishXp = 0,
    StartObservedXp = nil,
    LastCatchTime = 0,
    RecentCatches = {},
    CycleTimeSum = 0,
    CycleTimeCount = 0,
    RarityCounts = {},
    FailReasons = { Invalid = 0, Lost = 0, Timeout = 0, Full = 0, Other = 0 },
}

local function clearConnList(list)
    for _, conn in ipairs(list) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(list)
end

envGlobal._AutoFishCleanup = function()
    AntiAFKState.Active = false
    State.Monitor.Active = false
    State.Webhook.Active = false
    if State.LowPowerMode then
        State.LowPowerMode = false
        pcall(function()
            Svc.RunService:Set3dRenderingEnabled(true)
        end)
    end
    for _, conn in ipairs(Conns.DisabledFxConns) do
        pcall(function()
            conn:Enable()
        end)
    end
    table.clear(Conns.DisabledFxConns)
    for _, k in ipairs({
        "Heartbeat",
        "Server",
        "Gradient",
        "BarFill",
        "BarSize",
        "InfoText",
        "FishingVis",
        "GuiDesc",
        "WorkspaceFx",
        "LightingFx",
        "CameraType",
        "QuestPlaytime",
        "QuestWeekly",
        "EventClaimable",
        "InAfkServer",
    }) do
        if Conns[k] then
            Conns[k]:Disconnect()
            Conns[k] = nil
        end
    end
    clearConnList(Conns.PrimNotif)
    clearConnList(Conns.LevelUp)
    clearConnList(Conns.Char)
    clearConnList(Conns.Global)
end

table.insert(Conns.Global, LocalPlayer.Idled:Connect(function()
    if AntiAFKState.Active then
        sendAntiAFKPulse()
    end
end))

local Monitor, RodSys, Webhook, Water, GameAuto, Reel, Primordial, Coffee, Perf, Quests, Maze, Binder, Engine = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}

function Util.updateStatusTag()
    if not UI.StatusTag or type(UI.StatusTag.Set) ~= "function" then
        return
    end
    pcall(function()
        if State.InAfkServer then
            UI.StatusTag:Set({ text = "AFK SRV", color = Color3.fromRGB(168, 85, 247) })
        elseif State.Primordial.CurrentEvent then
            UI.StatusTag:Set({ text = "EVENT", color = Color3.fromRGB(234, 179, 8) })
        elseif State.IsFarmPausedNoWater then
            UI.StatusTag:Set({ text = "PAUSED", color = Color3.fromRGB(239, 68, 68) })
        elseif State.EnabledCast then
            UI.StatusTag:Set({ text = "ACTIVE", color = Color3.fromRGB(34, 197, 94) })
        else
            UI.StatusTag:Set({ text = "IDLE", color = Color3.fromRGB(100, 116, 139) })
        end
    end)
end

function Util.stealthTeleport(targetCF, lookAtPos, jitterXZ)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not char.Parent or not hrp or not hrp.Parent or not hum or hum.Health <= 0 then
        return false
    end

    if RodSys.findEquipped(char) then
        RodSys.unequip()
        task.wait(0.08)
    end
    if hum.Sit then
        hum.Sit = false
        task.wait(0.06)
    end

    local destCF = targetCF
    local j = tonumber(jitterXZ) or 0
    if j > 0 then
        local ox = (math.random() - 0.5) * 2 * j
        local oz = (math.random() - 0.5) * 2 * j
        destCF = targetCF + Vector3.new(ox, 0, oz)
    end

    pcall(function()
        LocalPlayer:RequestStreamAroundAsync(destCF.Position)
    end)

    if not char.Parent or not hrp.Parent or hum.Health <= 0 then
        return false
    end

    if lookAtPos then
        destCF = Util.groundCFrame(destCF, lookAtPos)
    end

    local wasAnchored = hrp.Anchored
    hrp.Anchored = true
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    char:PivotTo(destCF)
    hrp.CFrame = destCF
    task.wait(0.25)

    if not char.Parent or not hrp.Parent or hum.Health <= 0 then
        return false
    end

    hrp.Anchored = wasAnchored
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    task.wait(0.32)
    return char.Parent ~= nil and hrp.Parent ~= nil and hum.Health > 0
end

-- ==================== MONITOR & TELEMETRY MODULE ====================
function Monitor.syncRodState(st)
    if type(st) ~= "table" then
        return
    end
    local rd = State.RodData
    local changed = false
    if type(st.equippedBait) == "string" and st.equippedBait ~= "" and st.equippedBait ~= State.DetectedBait then
        State.DetectedBait = st.equippedBait
        changed = true
    end
    for _, k in ipairs({ "rods", "rodEnh", "rodEnh2", "rodEnh3", "rodAsc" }) do
        if type(st[k]) == "table" then
            rd[k] = st[k]
            changed = true
        end
    end
    if changed then
        Cache.GearSummary = nil
    end
end

function Monitor.refreshState()
    local gs = Remotes.GetState
    if gs and gs.Parent then
        task.spawn(function()
            local okS, st = pcall(function()
                return gs:InvokeServer()
            end)
            if okS and type(st) == "table" then
                Monitor.syncRodState(st)
            end
        end)
    end
end

function Monitor.detectVip()
    local now = os.clock()
    if (now - Cache.VipCheckedAt) < 30 then
        return Cache.VipCached
    end
    Cache.VipCheckedAt = now
    Cache.VipCached = false
    for k, v in pairs(LocalPlayer:GetAttributes()) do
        local kl = string.lower(k)
        if (kl == "vip" or kl == "isvip" or kl == "hasvip" or kl == "gamepassvip") and v == true then
            Cache.VipCached = true
            break
        end
    end
    return Cache.VipCached
end

function Monitor.getBagCounts()
    local fc = Cfg.get("FishConfig")
    local count = tonumber(LocalPlayer:GetAttribute("FishCount"))
    local limit = tonumber(LocalPlayer:GetAttribute("FishLimit")) or (fc and tonumber(fc.InventoryLimit)) or 700
    return count, limit
end

function Monitor.getBoostTelemetry()
    local nowEp = Util.serverNow()
    local srvParts = {}

    local srvLuck = tonumber(Svc.ReplicatedStorage:GetAttribute("FishServerLuck")) or 0
    local srvEnd = tonumber(Svc.ReplicatedStorage:GetAttribute("FishServerLuckEnd")) or 0
    if srvLuck > 0 and srvEnd > nowEp then
        table.insert(srvParts, string.format("Server x%g (%s)", srvLuck, Util.formatDur(srvEnd - nowEp)))
    end

    local ownLuck = tonumber(Svc.ReplicatedStorage:GetAttribute("FishOwnerLuck")) or 0
    local ownEnd = tonumber(Svc.ReplicatedStorage:GetAttribute("FishOwnerLuckEnd")) or 0
    if ownLuck > 0 and ownEnd > nowEp then
        table.insert(srvParts, string.format("Owner x%g (%s)", ownLuck, Util.formatDur(ownEnd - nowEp)))
    end

    local expMult = tonumber(Svc.ReplicatedStorage:GetAttribute("ExpEventMult")) or 1
    local expEnd = tonumber(Svc.ReplicatedStorage:GetAttribute("ExpEventEndsAt")) or 0
    if expMult > 1 and expEnd > nowEp then
        table.insert(srvParts, string.format("EXP x%g (%s)", expMult, Util.formatDur(expEnd - nowEp)))
    end

    if Svc.ReplicatedStorage:GetAttribute("GalaState") == "Live" then
        local gEnd = tonumber(Svc.ReplicatedStorage:GetAttribute("GalaEndsAt")) or 0
        local gMode = tostring(Svc.ReplicatedStorage:GetAttribute("GalaMode") or "Tourney")
        table.insert(srvParts, string.format("Galatama: %s (%s)", gMode, Util.formatDur(gEnd - nowEp)))
    end

    local frCount = math.min(tonumber(LocalPlayer:GetAttribute("FishFriendCount")) or 0, 5)
    local frLuck = tonumber(LocalPlayer:GetAttribute("FishFriendLuck")) or 0
    if frCount > 0 then
        table.insert(srvParts, string.format("Friends x%d (+%d%%)", frCount, math.floor(frLuck * 100 + 0.5)))
    end

    local pParts = {}
    for _, bid in ipairs(CONST.PERSONAL_BOOST_IDS) do
        local pEnd = tonumber(LocalPlayer:GetAttribute("PBoost" .. bid .. "End")) or 0
        local pPaused = tonumber(LocalPlayer:GetAttribute("PBoost" .. bid .. "Paused")) or 0
        local pQ = tonumber(LocalPlayer:GetAttribute("PBoost" .. bid .. "Q")) or 0
        if pEnd > nowEp then
            table.insert(pParts, string.format("%s %s", bid, Util.formatDur(pEnd - nowEp)))
        elseif pPaused > 0 then
            table.insert(pParts, string.format("%s %s (paused)", bid, Util.formatDur(pPaused)))
        elseif pQ > 0 then
            table.insert(pParts, string.format("%s %s (queued)", bid, Util.formatDur(pQ)))
        end
    end

    return {
        ServerSummary = #srvParts > 0 and table.concat(srvParts, " • ") or "None",
        PersonalSummary = #pParts > 0 and table.concat(pParts, " • ") or "None",
    }
end

function Monitor.readLevelXp()
    local lvlCfg = Cfg.get("LevelConfig")
    local attrLvl = tonumber(LocalPlayer:GetAttribute("Level"))
    if attrLvl and attrLvl >= 1 then
        local cLvl = math.floor(attrLvl)
        local cInto = math.max(0, tonumber(LocalPlayer:GetAttribute("LevelXpInto")) or 0)
        local cNeed = math.max(0, tonumber(LocalPlayer:GetAttribute("LevelXpNeed")) or ((lvlCfg and type(lvlCfg.xpToNext) == "function" and tonumber(lvlCfg.xpToNext(cLvl))) or 0))
        local cTot = (lvlCfg and type(lvlCfg.totalForLevel) == "function")
            and ((tonumber(lvlCfg.totalForLevel(cLvl)) or 0) + cInto)
            or nil
        return cLvl, cInto, cNeed, cTot
    end
    return nil, 0, 0, nil
end

function Monitor.extractRodMods(rodName, tool)
    local enhanceCfg = Cfg.get("RodEnhanceConfig")
    local ascCfg = Cfg.get("RodAscensionConfig")
    local rd = State.RodData
    local ascLv = 0
    local ascLuck = 0

    if type(rodName) == "string" and type(rd.rodAsc) == "table" and rd.rodAsc[rodName] then
        ascLv = math.max(0, math.floor(tonumber(rd.rodAsc[rodName]) or 0))
        if ascCfg and type(ascCfg.luckAt) == "function" then
            ascLuck = tonumber(ascCfg.luckAt(ascLv)) or 0
        else
            ascLuck = math.min(ascLv, 20) * 0.25
        end
    end

    local slots = {}
    if type(rodName) == "string" then
        for _, tbl in ipairs({ rd.rodEnh, rd.rodEnh2, rd.rodEnh3 }) do
            local eid = type(tbl) == "table" and tbl[rodName] or nil
            if type(eid) == "string" and eid ~= "" then
                table.insert(slots, eid)
            end
        end
    end

    if #slots == 0 and tool then
        for _, attr in ipairs({ "Enhance", "Enhance1", "Enhance2", "Enhance3", "Enchant", "Enchant1", "Enchant2", "Enchant3" }) do
            local val = tool:GetAttribute(attr)
            if type(val) == "string" and val ~= "" then
                for part in string.gmatch(val, "[^,;]+") do
                    local trimmed = Util.trim(part)
                    if trimmed ~= "" then
                        table.insert(slots, trimmed)
                    end
                end
            end
        end
    end

    local directLuck = tool and tonumber(tool:GetAttribute("EnhanceLuck")) or nil
    local res = {
        AscLevel = ascLv,
        AscLuck = ascLuck,
        EnhanceLuck = directLuck or 0,
        SecretMult = 1,
        SupremacyMult = 1,
        PrimordialMult = 1,
        Names = slots,
    }

    if enhanceCfg and #slots > 0 and type(enhanceCfg.combine) == "function" then
        local comb = enhanceCfg.combine(slots)
        if comb then
            if directLuck == nil then
                res.EnhanceLuck = tonumber(comb.Luck) or 0
            end
            res.SecretMult = tonumber(comb.SecretMult) or 1
            res.SupremacyMult = tonumber(comb.SupremacyMult) or 1
            res.PrimordialMult = tonumber(comb.PrimordialMult) or 1
        end
    end

    return res
end

function Monitor.getBaitName()
    for _, attr in ipairs({ "EquippedBait", "Bait", "CurrentBait", "FishBait" }) do
        local val = LocalPlayer:GetAttribute(attr)
        if type(val) == "string" and val ~= "" then
            return val
        end
    end
    if type(State.DetectedBait) == "string" and State.DetectedBait ~= "" then
        return State.DetectedBait
    end
    local bc = Cfg.get("BaitConfig")
    return (bc and bc.Default) or "Basic Bait"
end

function Monitor.getGearSummary(forceRefresh)
    local now = os.clock()
    if not forceRefresh and Cache.GearSummary and (now - Cache.GearSummaryAt) < 4 then
        return Cache.GearSummary
    end

    local rc, bc = Cfg.get("RodConfig"), Cfg.get("BaitConfig")
    local activeTool = RodSys.findEquipped(LocalPlayer.Character) or RodSys.findBestBackpack(LocalPlayer:FindFirstChild("Backpack"))
    local rodName = (activeTool and (activeTool:GetAttribute("RodName") or activeTool.Name))
        or LocalPlayer:GetAttribute("FishRod")
        or (rc and rc.Default)
        or "Basic Rod"
    local rodInfo = (rc and type(rc.get) == "function" and rc.get(rodName)) or nil
    local rodLuck = (rodInfo and tonumber(rodInfo.Luck)) or 1

    local mods = Monitor.extractRodMods(rodName, activeTool)
    local baitName = Monitor.getBaitName()
    local baitInfo = (bc and type(bc.get) == "function" and bc.get(baitName)) or nil
    local baitLuck = (baitInfo and tonumber(baitInfo.Luck)) or 2

    local globalLuck = math.max(1, tonumber(Svc.ReplicatedStorage:GetAttribute("FishGlobalLuck")) or 0)
    local totalLuck = ((rodLuck + mods.AscLuck + mods.EnhanceLuck) * (1 + State.CastPower * 0.2) + baitLuck) * globalLuck

    Cache.GearSummary = {
        RodName = rodName,
        RodInfo = rodInfo,
        AscLevel = mods.AscLevel,
        PrimordialMult = mods.PrimordialMult,
        BaitName = baitName,
        TotalLuck = totalLuck,
    }
    Cache.GearSummaryAt = now
    return Cache.GearSummary
end

function Monitor.snapshot()
    local now = os.clock()
    local m = State.Monitor
    local elapsed = math.max(1, now - m.SessionStart)
    local eMin, eHr = elapsed / 60, elapsed / 3600

    while #m.RecentCatches > 0 and (now - m.RecentCatches[1]) > 120 do
        table.remove(m.RecentCatches, 1)
    end

    local rollWin = math.min(120, math.max(15, elapsed))
    local liveHr = (#m.RecentCatches / rollWin) * 3600
    local sessHr = m.TotalCaught / eHr
    local totAtt = m.TotalCaught + m.TotalFailed
    local sucPct = totAtt > 0 and ((m.TotalCaught / totAtt) * 100) or 100

    local lvlCfg = Cfg.get("LevelConfig")
    local curLvl, curInto, curReq, curTot = Monitor.readLevelXp()
    if not m.StartObservedXp and curTot then
        m.StartObservedXp = curTot
    end

    local estXp = m.SessionFishXp + eMin * ((lvlCfg and tonumber(lvlCfg.XpPerMinute)) or 10)
    local obsGain = (curTot and m.StartObservedXp) and math.max(0, curTot - m.StartObservedXp) or 0
    local activeXp = obsGain > 0 and obsGain or estXp

    local xpHr = activeXp / eHr
    local lvHr = 0
    if xpHr > 0 and lvlCfg and type(lvlCfg.fromXp) == "function" and type(lvlCfg.xpToNext) == "function" then
        if curLvl and curTot and curLvl < (tonumber(lvlCfg.MaxLevel) or 2000) then
            local fLvl, fInto = lvlCfg.fromXp(curTot + xpHr)
            local cReq = math.max(1, tonumber(lvlCfg.xpToNext(curLvl)) or 1)
            local fReq = math.max(1, tonumber(lvlCfg.xpToNext(fLvl)) or 1)
            local cTot = tonumber(lvlCfg.totalForLevel(curLvl)) or 0
            lvHr = math.max(0, (fLvl + ((tonumber(fInto) or 0) / fReq)) - (curLvl + ((curTot - cTot) / cReq)))
        else
            lvHr = xpHr / math.max(1, tonumber(lvlCfg.xpToNext(1)) or 60)
        end
    end

    return {
        elapsed = elapsed,
        liveFishPerHr = liveHr,
        liveFishPerMin = liveHr / 60,
        sessionFishPerHr = sessHr,
        successPct = sucPct,
        avgCycle = m.CycleTimeCount > 0 and (m.CycleTimeSum / m.CycleTimeCount) or 0,
        curLevel = curLvl,
        curXpInto = curInto,
        curXpReq = curReq,
        curTotalXp = curTot,
        xpPerHr = xpHr,
        xpPerSec = activeXp / elapsed,
        levelsPerHr = lvHr,
    }
end

function Monitor.reset()
    local m = State.Monitor
    m.SessionStart = os.clock()
    m.TotalCaught = 0
    m.TotalFailed = 0
    m.InvalidFails = 0
    m.SessionFishXp = 0
    m.LastCatchTime = 0
    table.clear(m.RecentCatches)
    m.CycleTimeSum = 0
    m.CycleTimeCount = 0
    table.clear(m.RarityCounts)
    m.FailReasons = { Invalid = 0, Lost = 0, Timeout = 0, Full = 0, Other = 0 }
    local okTot, _, _, _, tot = pcall(Monitor.readLevelXp)
    m.StartObservedXp = okTot and tot or nil
end

-- ==================== DISCORD WEBHOOK MODULE ====================
function Webhook.getHttpFuncs()
    local list, seen = {}, {}
    local fenv: { [string]: any } = (type(getfenv) == "function" and getfenv()) or {}
    local httpTbl = envGlobal.http or fenv.http
    local synTbl = envGlobal.syn or fenv.syn
    local fluxTbl = envGlobal.fluxus or fenv.fluxus

    local candidates = {
        envGlobal.request or fenv.request,
        envGlobal.http_request or fenv.http_request,
        type(httpTbl) == "table" and httpTbl.request or nil,
        type(synTbl) == "table" and synTbl.request or nil,
        type(fluxTbl) == "table" and fluxTbl.request or nil,
    }
    for i = 1, 5 do
        local fn = candidates[i]
        if type(fn) == "function" and not seen[fn] then
            seen[fn] = true
            table.insert(list, fn)
        end
    end
    return list
end

function Webhook.extractStatus(res)
    if type(res) ~= "table" then
        return 0, "Non-table response"
    end
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

function Webhook.enqueue(embed)
    local w = State.Webhook
    if not w.Enabled or not Util.isValidWebhookUrl(w.Url) then
        return
    end
    if #w.Queue >= 25 then
        table.remove(w.Queue, 1)
    end
    embed.timestamp = embed.timestamp or os.date("!%Y-%m-%dT%H:%M:%SZ")
    embed.footer = embed.footer or { text = string.format("Saujana Hub v%s • %s", SCRIPT_VERSION, LocalPlayer.Name) }
    table.insert(w.Queue, { embeds = { embed } })
end

function Webhook.sendNow(payload)
    local funcs = Webhook.getHttpFuncs()
    if #funcs == 0 then
        return false, "Executor has no HTTP request function"
    end

    local cleanUrl = Util.trim(State.Webhook.Url)
    if not Util.isValidWebhookUrl(cleanUrl) then
        return false, "Invalid Discord Webhook URL"
    end

    local okEnc, jsonBody = pcall(function()
        return Svc.Http:JSONEncode(payload)
    end)
    if not okEnc or type(jsonBody) ~= "string" then
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
            local okReq, res = pcall(function()
                return reqFn({
                    Url = targetUrl,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json", ["Accept"] = "application/json" },
                    Body = jsonBody,
                })
            end)
            if okReq then
                local code, detail = Webhook.extractStatus(res)
                if code >= 200 and code < 300 then
                    State.Webhook.SentCount += 1
                    return true, code
                elseif code == 429 then
                    local retryAfter = 3
                    if type(res) == "table" and type(res.Body) == "string" then
                        local okDec, dec = pcall(function()
                            return Svc.Http:JSONDecode(res.Body)
                        end)
                        if okDec and type(dec) == "table" then
                            local parsedRetry = tonumber(dec.retry_after)
                            if parsedRetry then
                                retryAfter = math.clamp(parsedRetry, 1, 15)
                            end
                        end
                    end
                    task.wait(retryAfter)
                    return false, "429 Rate Limited"
                elseif code > 0 then
                    State.Webhook.FailedCount += 1
                    return false, (detail ~= "" and string.format("HTTP %d (%s)", code, detail)) or ("HTTP " .. tostring(code))
                else
                    lastErr = (detail ~= "" and string.format("HTTP 0 (%s)", detail)) or "HTTP 0"
                end
            else
                lastErr = tostring(res)
            end
        end
    end

    State.Webhook.FailedCount += 1
    return false, lastErr
end

function Webhook.buildReport(titleOverride, colorOverride)
    local snap = Monitor.snapshot()
    local gear = Monitor.getGearSummary()
    local boosts = Monitor.getBoostTelemetry()
    local bagCnt, bagLim = Monitor.getBagCounts()
    local lvlCfg = Cfg.get("LevelConfig")
    local m = State.Monitor

    local statusText = State.InAfkServer and "In AFK Server"
        or (State.IsFarmPausedNoWater and "Paused (Away from water)"
        or (State.EnabledCast and "Active" or "Idle (Auto Cast OFF)"))

    local locText = "Normal Spot"
    if State.InAfkServer then
        locText = "AFK Server"
    elseif State.Primordial.CurrentEvent then
        local sp = CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent]
        local cfg = sp and Cfg.get(sp.CfgName)
        local leftSec = (cfg and type(cfg.secondsLeft) == "function") and cfg.secondsLeft(Util.serverNow()) or 0
        local evCaught = tonumber(Svc.ReplicatedStorage:GetAttribute(sp.CaughtAttr)) or 0
        locText = string.format("%s (%s left • Server %dx)", sp.Name, Util.formatDur(leftSec), evCaught)
    end

    local coffeeStr = Coffee.getStatusSummary()
    local bagText = bagCnt ~= nil and string.format("%d / %d", bagCnt, bagLim) or string.format("-- / %d", bagLim)
    local ascStr = gear.AscLevel > 0 and string.format(" ★%d", gear.AscLevel) or ""

    local levelText, etaNext = "N/A", "--"
    if snap.curLevel and lvlCfg then
        local rInfo = type(lvlCfg.rankFor) == "function" and lvlCfg.rankFor(snap.curLevel) or nil
        local rTitle = rInfo and rInfo.Title or ""
        local xpReq = snap.curXpReq or (type(lvlCfg.xpToNext) == "function" and lvlCfg.xpToNext(snap.curLevel) or 0)
        levelText = string.format("Lv. %d (%s)\n%s / %s XP", snap.curLevel, rTitle, Util.formatNum(snap.curXpInto or 0), Util.formatNum(xpReq))
        if snap.xpPerSec > 0 and snap.curTotalXp and type(lvlCfg.totalForLevel) == "function" and snap.curLevel < (tonumber(lvlCfg.MaxLevel) or 2000) then
            local nextNeed = math.max(0, (tonumber(lvlCfg.totalForLevel(snap.curLevel + 1)) or 0) - snap.curTotalXp)
            etaNext = Util.formatDur(nextNeed / snap.xpPerSec)
        end
    end

    local rarText = string.format(
        "Common: %d | Uncommon: %d | Rare: %d | Epic: %d\nMythic: %d | Secret: %d | Supremacy: %d | Primordial: %d",
        m.RarityCounts.Common or 0,
        m.RarityCounts.Uncommon or 0,
        m.RarityCounts.Rare or 0,
        m.RarityCounts.Epic or 0,
        m.RarityCounts.Mythic or 0,
        m.RarityCounts.Secret or 0,
        m.RarityCounts.Supremacy or 0,
        m.RarityCounts.Primordial or 0
    )

    return {
        title = titleOverride or "Overnight Farm Report",
        color = colorOverride or CONST.RARITY_COLORS.Report,
        fields = {
            { name = "Player & Status", value = string.format("%s (@%s)\n%s • Uptime: %s\nLocation: %s", LocalPlayer.DisplayName, LocalPlayer.Name, statusText, Util.formatClock(snap.elapsed), locText), inline = true },
            { name = "Gear, Bag & Coffee", value = string.format("%s%s • %s (Luck %.1fx)\nBag: %s • Coffee: %s", gear.RodName, ascStr, gear.BaitName, gear.TotalLuck, bagText, coffeeStr), inline = true },
            { name = "Active Boosts", value = string.format("Server: %s\nPersonal: %s", boosts.ServerSummary, boosts.PersonalSummary), inline = false },
            { name = "Catch Rates", value = string.format("Live: **%s/hr** (%.1f/m)\nAvg: %s/hr | Cycle: %.2fs", Util.formatNum(snap.liveFishPerHr), snap.liveFishPerMin, Util.formatNum(snap.sessionFishPerHr), snap.avgCycle), inline = true },
            { name = "Session Totals", value = string.format("Caught: **%s**\nFailed: %d (Inv: %d) • %.1f%%", Util.formatNum(m.TotalCaught), m.TotalFailed, m.InvalidFails, snap.successPct), inline = true },
            { name = "Level & XP", value = string.format("%s\n%s XP/hr (%.2f Lv/hr) • Next: %s", levelText, Util.formatNum(snap.xpPerHr), snap.levelsPerHr, etaNext), inline = true },
            { name = "Rarity Breakdown", value = rarText, inline = false },
        },
    }
end

function Webhook.rareCatch(fishName, rarity, weightKg, rawChance)
    local w = State.Webhook
    if not w.Enabled or not w.NotifyRareCatches or not CONST.NOTIFY_RARITIES[rarity] then
        return
    end

    local fc = Cfg.get("FishConfig")
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

function Webhook.connected()
    local w = State.Webhook
    if not w.Enabled or not w.NotifyConnections then
        return
    end
    local snap = Monitor.snapshot()
    local gear = Monitor.getGearSummary(true)
    local shortJob = string.sub(tostring(game.JobId or "Private/Local"), 1, 12)
    local lvlStr = snap.curLevel and ("Lv. " .. tostring(snap.curLevel)) or "Loading"
    local evStr = State.InAfkServer and "AFK Server"
        or (State.Primordial.CurrentEvent and CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent].Name or "Normal Spot")

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

function Webhook.primordial(title, desc, color)
    local w = State.Webhook
    if not w.Enabled or not w.NotifyPrimordial then
        return
    end
    Webhook.enqueue({ title = title, description = desc, color = color or CONST.RARITY_COLORS.Primordial })
end

function Webhook.quest(title, desc, color)
    local w = State.Webhook
    if not w.Enabled or not State.Quests.NotifyWebhook then
        return
    end
    Webhook.enqueue({ title = title, description = desc, color = color or CONST.RARITY_COLORS.Quest })
end

function Webhook.alert(title, message, color, force)
    local w = State.Webhook
    if not w.Enabled or not w.AlertOnIssues then
        return
    end
    local now = os.clock()
    if not force and (now - w.LastAlertAt) < 30 then
        return
    end
    w.LastAlertAt = now
    Webhook.enqueue({ title = title, description = message, color = color or CONST.RARITY_COLORS.Alert })
end

task.spawn(function()
    while State.Webhook.Active do
        local w = State.Webhook
        if #w.Queue > 0 and w.Enabled and Util.isValidWebhookUrl(w.Url) then
            local nextPayload = table.remove(w.Queue, 1)
            local okSend = Webhook.sendNow(nextPayload)
            task.wait(okSend and 1.5 or 2.5)
        else
            task.wait(0.5)
        end
    end
end)

-- ==================== WATER DETECTION MODULE ====================
function Water.isHit(hit)
    if not hit then
        return false
    end
    if hit.Material == Enum.Material.Water then
        return true
    end
    local inst = hit.Instance
    for _ = 1, 8 do
        if not inst or inst == workspace then
            break
        end
        if inst:IsA("BasePart") and inst.Material == Enum.Material.Water then
            return true
        end
        if Svc.Collection:HasTag(inst, "FishWater") or inst:GetAttribute("FishWater") == true then
            return true
        end
        local lower = string.lower(inst.Name)
        if lower == "fishwater"
            or lower == "water"
            or lower == "air"
            or lower == "lava"
            or lower == "magma"
            or lower == "sea"
            or lower == "ocean"
            or lower == "pond"
            or lower == "lake" then
            return true
        end
        inst = inst.Parent
    end
    return false
end

function Water.castDown(probePos, baseExclude)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = {}
    for i = 1, #baseExclude do
        exclude[i] = baseExclude[i]
    end
    params.FilterDescendantsInstances = exclude
    params.IgnoreWater = false

    local rayOrigin = probePos + Vector3.new(0, 4, 0)
    local rayDir = Vector3.new(0, -85, 0)

    for _ = 1, 5 do
        local hit = workspace:Raycast(rayOrigin, rayDir, params)
        if not hit then
            return nil
        end
        if Water.isHit(hit) then
            return hit
        end
        local inst = hit.Instance
        if inst and inst:IsA("BasePart") and (inst.Transparency >= 0.7 or not inst.CanCollide) then
            table.insert(exclude, inst)
            params.FilterDescendantsInstances = exclude
        else
            return nil
        end
    end
    return nil
end

function Water.refresh(forceNotify, forceFullScan)
    if State.Coffee.IsDrinking or State.Primordial.IsTeleporting or State.Maze.IsRunning or State.InAfkServer then
        return
    end

    local now = os.clock()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local found, dir = false, nil

    if hrp then
        local originPos = hrp.Position
        local nearPrimSafeSpot = false

        if State.Primordial.CurrentEvent then
            local spot = CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent]
            if spot and (originPos - spot.CFrame.Position).Magnitude <= 45 then
                nearPrimSafeSpot = true
                State.IsNearWater = true
                State.IsFarmPausedNoWater = false
            end
        end

        local movedFar = (not State.LastWaterScanPos) or ((originPos - State.LastWaterScanPos).Magnitude >= 4)
        if not forceFullScan and not movedFar and State.IsNearWater and State.CachedWaterDir and State.LastWaterHitPos and (now - State.LastFullWaterScanAt) < 12 then
            if (originPos - State.LastWaterHitPos).Magnitude <= 38 then
                return
            end
        end

        local exclude = {}
        for _, plr in ipairs(Svc.Players:GetPlayers()) do
            if plr.Character then
                table.insert(exclude, plr.Character)
            end
        end

        if State.LastWaterHitPos and (originPos - State.LastWaterHitPos).Magnitude <= 38 then
            local singleHit = Water.castDown(State.LastWaterHitPos, exclude)
            if singleHit then
                local flat = Vector3.new(singleHit.Position.X - originPos.X, 0, singleHit.Position.Z - originPos.Z)
                dir = flat.Magnitude > 0.5 and flat.Unit or nil
                found = true
                State.LastWaterHitPos = singleHit.Position
            end
        end

        if not found then
            for radius = 3, 38, 4.5 do
                local steps = math.max(8, math.floor(radius * 0.7))
                for j = 0, steps - 1 do
                    local angle = (j / steps) * (math.pi * 2)
                    local probe = originPos + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                    local hit = Water.castDown(probe, exclude)
                    if hit then
                        local flat = Vector3.new(hit.Position.X - originPos.X, 0, hit.Position.Z - originPos.Z)
                        dir = flat.Magnitude > 0.5 and flat.Unit or nil
                        found = true
                        State.LastWaterHitPos = hit.Position
                        break
                    end
                end
                if found then
                    break
                end
            end
            if not found then
                State.LastWaterHitPos = nil
            end
        end

        if not found and nearPrimSafeSpot then
            local spot = CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent]
            found = true
            local flatLook = Vector3.new(spot.CFrame.LookVector.X, 0, spot.CFrame.LookVector.Z)
            if flatLook.Magnitude > 0.01 then
                dir = flatLook.Unit
            else
                dir = nil
            end
        end

        State.LastWaterScanPos = originPos
        State.LastFullWaterScanAt = now
    end

    State.IsNearWater = found
    State.CachedWaterDir = dir

    if State.EnabledPauseNoWater then
        if not found and not State.IsFarmPausedNoWater then
            State.IsFarmPausedNoWater = true
            State.WaitingForBite = false
            if not State.BiteActive then
                RodSys.unequip()
            end
            Util.updateStatusTag()
            Webhook.alert("Farm Paused (Away From Water)", "Character moved away from water. Rod unequipped until returning.", CONST.RARITY_COLORS.Alert)
            if UI.Window and forceNotify ~= false then
                task.defer(function()
                    UI.Window:Notify({ title = "Farm Paused", content = "Moved away from water — rod unequipped", duration = 3 })
                end)
            end
        elseif found and State.IsFarmPausedNoWater then
            State.IsFarmPausedNoWater = false
            if State.EnabledAutoEquip then
                task.defer(RodSys.equip)
            end
            Util.updateStatusTag()
            Webhook.alert("Farm Resumed", "Water detected nearby — rod equipped & casting resumed.", CONST.RARITY_COLORS.Resume)
            if UI.Window and forceNotify ~= false then
                task.defer(function()
                    UI.Window:Notify({ title = "Farm Resumed", content = "Water detected nearby — casting resumed", duration = 3 })
                end)
            end
        end
    elseif State.IsFarmPausedNoWater then
        State.IsFarmPausedNoWater = false
        if State.EnabledAutoEquip then
            task.defer(RodSys.equip)
        end
        Util.updateStatusTag()
    end
end

-- ==================== GAME AUTO CAST MODULE ====================
function GameAuto.isGreen(uiGrad)
    if not uiGrad then
        return false
    end
    local kps = uiGrad.Color.Keypoints
    return #kps > 0 and kps[1].Value.G > kps[1].Value.R
end

function GameAuto.isOn()
    local btn = Cache.AutoBtn
    if not btn then
        return false
    end
    local uiGrad = btn:FindFirstChildOfClass("UIGradient")
    if uiGrad then
        return GameAuto.isGreen(uiGrad)
    end
    local col = btn:IsA("ImageButton") and btn.ImageColor3 or btn.BackgroundColor3
    return (col.G > 0.6 and col.G > col.R)
end

function GameAuto.set(targetState)
    if Cache.AutoBtn then
        if GameAuto.isOn() ~= targetState then
            State.LastAutoBtnClick = os.clock()
            Util.triggerBtn(Cache.AutoBtn)
        end
    else
        local setAuto = Remotes.SetAuto
        if setAuto and setAuto.Parent then
            task.spawn(function()
                pcall(function()
                    setAuto:InvokeServer(targetState)
                end)
            end)
        end
    end
end

function GameAuto.enforce(uiGrad)
    if State.EnabledGameAutoCast and not GameAuto.isGreen(uiGrad) then
        local now = os.clock()
        if (now - State.LastAutoBtnClick) >= 0.5 then
            State.LastAutoBtnClick = now
            GameAuto.set(true)
        end
    end
end

function GameAuto.bindGradient(autoBtn)
    if Conns.Gradient then
        Conns.Gradient:Disconnect()
        Conns.Gradient = nil
    end
    if not autoBtn then
        return
    end
    local uiGrad = autoBtn:FindFirstChildOfClass("UIGradient")
    if uiGrad then
        Conns.Gradient = uiGrad:GetPropertyChangedSignal("Color"):Connect(function()
            GameAuto.enforce(uiGrad)
        end)
        GameAuto.enforce(uiGrad)
    end
end

-- ==================== REEL & LEVELUP UI MODULE ====================
function Reel.closeLevelUp(gui)
    if not State.EnabledAutoCloseLevelUp or not gui or not gui.Parent then
        return
    end
    local now = os.clock()
    if (now - State.LastLevelUpClose) < 0.15 then
        return
    end

    local isVisible = (gui:IsA("LayerCollector") and gui.Enabled)
    if not isVisible then
        for _, child in ipairs(gui:GetChildren()) do
            if child:IsA("GuiObject") and child.Visible then
                isVisible = true
                break
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
        end)
    end)
end

function Reel.bindLevelUp(gui)
    clearConnList(Conns.LevelUp)
    if not gui then
        return
    end
    local function watchChild(child)
        if child:IsA("GuiObject") then
            table.insert(Conns.LevelUp, child:GetPropertyChangedSignal("Visible"):Connect(function()
                if child.Visible then
                    Reel.closeLevelUp(gui)
                end
            end))
            if child.Visible then
                Reel.closeLevelUp(gui)
            end
        end
    end
    if gui:IsA("LayerCollector") then
        table.insert(Conns.LevelUp, gui:GetPropertyChangedSignal("Enabled"):Connect(function()
            if gui.Enabled then
                Reel.closeLevelUp(gui)
            end
        end))
    end
    for _, child in ipairs(gui:GetChildren()) do
        watchChild(child)
    end
    table.insert(Conns.LevelUp, gui.ChildAdded:Connect(watchChild))
    Reel.closeLevelUp(gui)
end

function Reel.updatePingSlider()
    local slider = UI.PingSlider
    if slider and type(slider.Set) == "function" then
        State.IsUpdatingPingSlider = true
        pcall(function()
            slider:Set(math.floor(State.PingBuffer * 100 + 0.5) / 100)
        end)
        State.IsUpdatingPingSlider = false
    end
end

function Reel.recalcSafeTime()
    if not State.BiteActive then
        return
    end
    local mg = Cfg.minigame()
    local startProg = tonumber(mg.StartingProgress) or 0.4
    local perTap = State.BiteIsAuto and (tonumber(mg.AutoSecondsPerTap) or 0.1) or (tonumber(mg.MinSecondsPerTap) or 0.06)

    local useFull = (State.ReelTimingMode == "Safe (100%)")
        or (State.ReelTimingMode == "Fastest Zero-Fail (Auto)" and State.AutoTuneUseFullTaps)

    local effTaps = useFull and State.BiteTaps or math.max(1, math.ceil(State.BiteTaps * math.max(0.1, 1 - startProg)))
    State.SafeReelAt = State.BiteAt + (effTaps * perTap) + State.PingBuffer
end

function Reel.fire()
    local reelRem = Remotes.Reel
    if not reelRem or not reelRem.Parent then
        return
    end
    local now = os.clock()
    if (now - State.LastAutoReelFire) < 0.15 then
        return
    end
    State.LastAutoReelFire = now
    State.LastReelAttemptAt = now
    State.BiteHasReeled = true
    pcall(function()
        reelRem:FireServer(true)
    end)
end

function Reel.isSafeNow()
    return not (State.EnabledFastSafeReel and State.BiteActive and os.clock() < State.SafeReelAt)
end

function Reel.getInfoProgress()
    if not Cache.InfoLabel then
        return nil
    end
    local curStr = string.match(Cache.InfoLabel.Text, "(%d+)%s*/%s*%d+")
    return curStr and tonumber(curStr) or nil
end

function Reel.shouldAuto()
    if not State.EnabledReel or not Remotes.Reel or not Remotes.Reel.Parent then
        return false
    end
    if not Reel.isSafeNow() then
        return false
    end
    if State.BiteHasReeled and State.BiteActive then
        return false
    end
    if Conns.Server and not State.BiteActive then
        return false
    end
    if not Cache.FishingFrame or not Cache.FishingFrame.Visible then
        return false
    end
    if not State.BiteActive and Cache.TapText and Cache.TapText.Text == "CAST" then
        return false
    end

    local current = Reel.getInfoProgress()
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

function Reel.invokeSellAll(isProactive)
    local sellRem = Remotes.SellAll
    if not sellRem or not sellRem.Parent or State.IsSelling then
        return
    end
    State.LastSellTime = os.clock()
    State.IsSelling = true
    task.spawn(function()
        local okS, res, info = pcall(function()
            return sellRem:InvokeServer()
        end)
        State.IsSelling = false
        State.BagFishCounts = nil
        if okS and (res == false or info == 0 or info == "Nothing" or info == "TooFar") then
            State.ProactiveSellCooldownUntil = os.clock() + State.SellInterval
        elseif isProactive then
            State.ProactiveSellCooldownUntil = os.clock() + 3
        end
    end)
end

function Reel.onServerEvent(eventName, data)
    local now = os.clock()
    State.LastServerActivityAt = now

    if eventName == "State" and type(data) == "table" then
        Monitor.syncRodState(data)
    elseif eventName == "CastOk" then
        State.WaitingForBite = true
        State.WaitingSince = now
        State.CastBusyUntil = 0
        State.ConsecutiveBusyFails = 0
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
        State.ConsecutiveBusyFails = 0
        Reel.recalcSafeTime()
    elseif eventName == "Caught" then
        State.WaitingForBite = false
        State.BiteActive = false
        State.BiteHasReeled = true
        State.CastBusyUntil = 0
        State.ConsecutiveCatches += 1
        State.ConsecutiveInvalidFails = 0
        State.ConsecutiveBusyFails = 0

        local m = State.Monitor
        m.TotalCaught += 1
        table.insert(m.RecentCatches, now)
        if m.LastCatchTime > 0 and (now - m.LastCatchTime) <= 60 then
            m.CycleTimeSum += (now - m.LastCatchTime)
            m.CycleTimeCount += 1
        end
        m.LastCatchTime = now

        local rarity = (type(data) == "table" and data.rarity) or "Common"
        local fishName = (type(data) == "table" and data.name) or "Fish"
        local weightKg = (type(data) == "table" and (tonumber(data.kg) or tonumber(data.weight))) or nil
        local rawChance = (type(data) == "table" and (tonumber(data.oneIn) or tonumber(data.chance))) or nil

        if rarity == "Mythic" or rarity == "Secret" or rarity == "Supremacy" then
            State.BagFishCounts = nil
        end

        m.RarityCounts[rarity] = (m.RarityCounts[rarity] or 0) + 1

        local lvlCfg = Cfg.get("LevelConfig")
        local xpTbl = (lvlCfg and lvlCfg.FishXp) or CONST.DEFAULT_FISH_XP
        local baseXp = xpTbl[rarity] or 5
        local vipMult = (Monitor.detectVip() and (1 + ((lvlCfg and lvlCfg.VipBonus) or 0.25))) or 1
        m.SessionFishXp += (baseXp * vipMult)

        Webhook.rareCatch(fishName, rarity, weightKg, rawChance)

        if State.EnabledSell and now >= State.ProactiveSellCooldownUntil then
            local bagCnt, bagLim = Monitor.getBagCounts()
            if bagCnt ~= nil and bagLim > 0 and bagCnt >= (bagLim - 2) then
                Reel.invokeSellAll(true)
            end
        end

        if State.AutoTunePingBuffer and State.ConsecutiveCatches >= 20 and (now - State.LastBufferAdjustAt) >= 35 then
            local floorTarget = math.max(0.02, State.AutoTuneFloorBuffer)
            if State.PingBuffer > floorTarget + 0.005 then
                State.PingBuffer = math.max(floorTarget, math.floor((State.PingBuffer - 0.01) * 100 + 0.5) / 100)
                State.LastBufferAdjustAt = now
                State.ConsecutiveCatches = 0
                Reel.updatePingSlider()
            end
        end
    elseif eventName == "Failed" then
        State.WaitingForBite = false
        State.BiteActive = false
        State.BiteHasReeled = true
        State.ConsecutiveBusyFails = 0
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
            if State.ReelTimingMode == "Fastest Zero-Fail (Auto)" and not State.AutoTuneUseFullTaps then
                State.AutoTuneUseFullTaps = true
                switched = true
            end

            if State.AutoTunePingBuffer and not switched then
                local newBuf = math.min(0.45, math.floor((State.PingBuffer + 0.03) * 100 + 0.5) / 100)
                if newBuf > State.PingBuffer then
                    State.PingBuffer = newBuf
                    State.AutoTuneFloorBuffer = math.max(State.AutoTuneFloorBuffer, newBuf)
                    Reel.updatePingSlider()
                end
            end

            if State.ConsecutiveInvalidFails >= 5 then
                Webhook.alert("Repeated 'Invalid' Fails Detected", string.format("%d consecutive Invalid fails. Ping Buffer: %.2fs.", State.ConsecutiveInvalidFails, State.PingBuffer), CONST.RARITY_COLORS.Alert)
            end
        end
    elseif eventName == "CastFail" and type(data) == "table" then
        if data.reason == "Busy" then
            State.CastBusyUntil = now + 0.25
            if not State.BiteActive and not State.WaitingForBite then
                State.ConsecutiveBusyFails += 1
                if State.ConsecutiveBusyFails >= 12 then
                    State.ConsecutiveBusyFails = 0
                    local cancelRem = Remotes.Cancel
                    if cancelRem and cancelRem.Parent then
                        pcall(function()
                            cancelRem:FireServer()
                        end)
                    end
                end
            end
        else
            State.ConsecutiveBusyFails = 0
            State.WaitingForBite = false
            if not State.BiteActive then
                State.BiteHasReeled = false
            end
            if data.reason == "NotWater" and State.EnabledPauseNoWater then
                State.LastWaterCheckAt = now
                Water.refresh(true, true)
            elseif data.reason == "Full" and State.EnabledSell and not State.IsSelling then
                Reel.invokeSellAll(true)
            end
        end
    end
end

-- ==================== COFFEE BOOST MODULE ====================
function Coffee.utcDay()
    local cc = Cfg.syncCoffeeCache()
    local nowEp = Util.serverNow()
    if cc and type(cc.dayNumber) == "function" then
        local okD, d = pcall(function()
            return cc.dayNumber(nowEp)
        end)
        if okD and type(d) == "number" then
            return d
        end
    end
    return math.floor(nowEp / 86400)
end

function Coffee.isCoffeeTool(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end
    if tool:GetAttribute("CoffeeId") ~= nil then
        return true
    end
    Cfg.syncCoffeeCache()
    local namesTbl = Cache.CoffeeNames or CONST.COFFEE_NAMES
    return namesTbl[tool.Name] == true
end

function Coffee.syncHeldFlag()
    local char = LocalPlayer.Character
    local holding = false
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if Coffee.isCoffeeTool(c) then
                holding = true
                break
            end
        end
    end
    State.Coffee.HoldingTool = holding
    return holding
end

function Coffee.cacheFellicia()
    local fell = workspace:FindFirstChild("Fellicia", true)
    if fell then
        local root = fell:IsA("BasePart") and fell
            or fell:FindFirstChild("HumanoidRootPart")
            or fell.PrimaryPart
            or fell:FindFirstChildWhichIsA("BasePart")
        if root then
            State.Coffee.FelliciaCFrame = root.CFrame
            envGlobal._SaujanaFelliciaCF = root.CFrame
        end
    elseif not State.Coffee.FelliciaCFrame and typeof(envGlobal._SaujanaFelliciaCF) == "CFrame" then
        State.Coffee.FelliciaCFrame = envGlobal._SaujanaFelliciaCF
    end
end

function Coffee.getActiveInfo()
    local cc = Cfg.syncCoffeeCache()
    local activeId = LocalPlayer:GetAttribute("CoffeeActive")
    local endEpoch = tonumber(LocalPlayer:GetAttribute("CoffeeEnd")) or 0
    local nowEp = Util.serverNow()

    if type(activeId) == "string" and activeId ~= "" and endEpoch > nowEp then
        local info = (cc and cc.ById) and cc.ById[activeId] or nil
        local display = (info and info.Name) or activeId
        return activeId, display, (endEpoch - nowEp)
    end
    return nil, nil, 0
end

function Coffee.getItemsFrame()
    if Cache.ItemsFrame and Cache.ItemsFrame.Parent then
        return Cache.ItemsFrame
    end
    if not PlayerGui then
        return nil
    end
    local bp = PlayerGui:FindFirstChild("Backpack")
    local inv = bp and bp:FindFirstChild("Inventory")
    Cache.ItemsFrame = inv and inv:FindFirstChild("Frame")
    return Cache.ItemsFrame
end

function Coffee.isHotbarFull()
    if not PlayerGui then
        return false
    end
    local bp = PlayerGui:FindFirstChild("Backpack")
    local hotBar = bp and bp:FindFirstChild("hotBar")
    if not hotBar then
        return false
    end
    local filled = 0
    for i = 1, 6 do
        local slot = hotBar:FindFirstChild(tostring(i))
        local tn = slot and slot:FindFirstChild("toolName")
        if tn and (tn:IsA("TextLabel") or tn:IsA("TextButton")) and tn.Text ~= "" then
            filled += 1
        end
    end
    return filled >= 6
end

function Coffee.getInvCount(coffeeId)
    local attrCount = tonumber(LocalPlayer:GetAttribute("CoffeeInv_" .. coffeeId)) or 0
    if attrCount > 0 then
        return attrCount
    end
    local frame = Coffee.getItemsFrame()
    if frame then
        local tile = frame:FindFirstChild("Coffee_" .. coffeeId)
        if tile then
            local amtLbl = tile:FindFirstChild("Amount")
            if amtLbl and (amtLbl:IsA("TextLabel") or amtLbl:IsA("TextButton")) then
                local amtNum = tonumber(string.match(amtLbl.Text or "", "(%d+)"))
                if amtNum and amtNum > 0 then
                    return amtNum
                end
            end
            return 1
        end
    end
    return 0
end

function Coffee.hasTicket(coffeeId)
    local attrCount = tonumber(LocalPlayer:GetAttribute("CoffeeTicket_" .. coffeeId)) or 0
    if attrCount > 0 then
        return true, attrCount
    end
    local frame = Coffee.getItemsFrame()
    if frame then
        local tile = frame:FindFirstChild("CoffeeTicket_" .. coffeeId)
        if tile then
            local amtLbl = tile:FindFirstChild("Amount")
            if amtLbl and (amtLbl:IsA("TextLabel") or amtLbl:IsA("TextButton")) then
                local amtNum = tonumber(string.match(amtLbl.Text or "", "(%d+)"))
                if amtNum and amtNum > 0 then
                    return true, amtNum
                end
            end
            return true, 1
        end
    end
    return false, 0
end

function Coffee.getCandidateOrder()
    local pref = State.Coffee.Preference
    if pref ~= "Best Available" and type(pref) == "string" then
        return { pref }
    end
    Cfg.syncCoffeeCache()
    return Cache.CoffeeOrder or CONST.COFFEE_ORDER
end

function Coffee.tradesRemaining()
    local cc = Cfg.syncCoffeeCache()
    local dayNum = Coffee.utcDay()
    if State.Coffee.DailyLimitDay == dayNum then
        return 0
    end
    local curDay = tonumber(LocalPlayer:GetAttribute("CoffeeDay")) or 0
    local used = (curDay == dayNum) and (tonumber(LocalPlayer:GetAttribute("CoffeeN")) or 0) or 0
    local attrLimit = tonumber(LocalPlayer:GetAttribute("CoffeeLimit"))
    local cfgLimit = nil
    if cc and type(cc.limitFor) == "function" then
        local okL, lim = pcall(function()
            return cc.limitFor(LocalPlayer)
        end)
        if okL and tonumber(lim) then
            cfgLimit = tonumber(lim)
        end
    end
    local isMember = (LocalPlayer:GetAttribute("CoffeeMember") == true)
    local limit = (attrLimit and attrLimit > 0 and attrLimit)
        or cfgLimit
        or (isMember and CONST.COFFEE_MEMBER_LIMIT or CONST.COFFEE_DEFAULT_LIMIT)
    return math.max(0, limit - used)
end

function Coffee.getBagFishCounts(forceRefresh)
    local now = os.clock()
    if not forceRefresh and State.BagFishCounts and (now - State.BagFishCountsAt) < 15 then
        return State.BagFishCounts
    end
    local gf = Remotes.GetFish
    if not gf or not gf.Parent then
        return nil
    end
    local okF, list = pcall(function()
        return gf:InvokeServer()
    end)
    if not okF or type(list) ~= "table" then
        return nil
    end
    local fc = Cfg.get("FishConfig")
    local byName = fc and fc.ByName
    local counts = { Mythic = 0, Secret = 0, Supremacy = 0 }
    for _, item in ipairs(list) do
        if type(item) == "table" and not item.f then
            local info = byName and byName[item.n]
            local rar = info and info.Rarity
            if rar and counts[rar] ~= nil then
                counts[rar] += 1
            end
        end
    end
    State.BagFishCounts = counts
    State.BagFishCountsAt = now
    return counts
end

function Coffee.canAffordFishRecipe(cid, counts)
    if not counts then
        return false
    end
    local cc = Cfg.syncCoffeeCache()
    local isMember = (LocalPlayer:GetAttribute("CoffeeMember") == true)
    local entry = (cc and cc.ById and cc.ById[cid]) or CONST.COFFEE_DEFAULT_COSTS[cid]
    if not entry then
        return false
    end
    local costTbl = (isMember and entry.MemberCost) or entry.Cost
    if type(costTbl) ~= "table" then
        return false
    end
    for rar, need in pairs(costTbl) do
        if (counts[rar] or 0) < (tonumber(need) or 999) then
            return false
        end
    end
    return true
end

function Coffee.getStatusSummary()
    local id, display, left = Coffee.getActiveInfo()
    if id then
        return string.format("%s (%s left)", tostring(display), Util.formatDur(left))
    end
    local cc = Cfg.syncCoffeeCache()
    local parts = {}
    for _, cid in ipairs(Cache.CoffeeOrder or CONST.COFFEE_ORDER) do
        local inv = Coffee.getInvCount(cid)
        local _, tix = Coffee.hasTicket(cid)
        if inv > 0 or tix > 0 then
            local info = (cc and cc.ById) and cc.ById[cid] or nil
            local nm = (info and info.Name) or cid
            table.insert(parts, string.format("%s (%d bag, %d tix)", nm, inv, tix))
        end
    end
    if #parts > 0 then
        return "Ready: " .. table.concat(parts, " | ")
    end
    if Coffee.tradesRemaining() <= 0 then
        return "Daily limit reached (0 left)"
    end
    return "None active"
end

function Coffee.findHeldOrBackpackTool(targetId)
    local cc = Cfg.syncCoffeeCache()
    local info = (targetId and cc and cc.ById) and cc.ById[targetId] or nil
    local targetName = info and info.Name or nil

    for _, container in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                if child:IsA("Tool") then
                    local cid = child:GetAttribute("CoffeeId")
                    if targetId then
                        if cid == targetId or (targetName and child.Name == targetName) then
                            return child, cid or targetId
                        end
                    elseif Coffee.isCoffeeTool(child) then
                        return child, cid or child.Name
                    end
                end
            end
        end
    end
    return nil, nil
end

function Coffee.drinkExistingTool(tool, labelId)
    if not tool or not tool.Parent then
        return false
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then
        return false
    end

    if tool.Parent ~= char then
        hum:EquipTool(tool)
        local eqAt = os.clock()
        while tool.Parent ~= char and (os.clock() - eqAt) < 1.0 do
            task.wait(0.05)
        end
    end

    if tool.Parent ~= char then
        return false
    end

    State.Coffee.HoldingTool = true
    local enAt = os.clock()
    while not tool.Enabled and (os.clock() - enAt) < 0.8 do
        task.wait(0.05)
    end

    for _ = 1, 3 do
        if not tool.Parent or tool.Parent ~= char then
            break
        end
        if tool.Enabled then
            tool:Activate()
        end
        local actWait = os.clock()
        while (os.clock() - actWait) < 0.8 do
            local activeId = Coffee.getActiveInfo()
            if activeId or not tool.Parent then
                if UI.Window then
                    UI.Window:Notify({ title = "Coffee Boost Active!", content = "Drank " .. tostring(labelId or tool.Name), duration = 3 })
                end
                return true
            end
            task.wait(0.1)
        end
    end
    return false
end

function Coffee.pullAndDrink(cid)
    State.Coffee.IsDrinking = true
    State.Coffee.DrinkStartedAt = os.clock()
    State.Coffee.LastAttemptAt = os.clock() + 8

    local okRun, drank = pcall(function()
        local bWait = os.clock()
        while (State.BiteActive or State.WaitingForBite) and (os.clock() - bWait) < 10 do
            task.wait(0.1)
        end
        if (State.BiteActive or State.WaitingForBite) and Remotes.Cancel and Remotes.Cancel.Parent then
            pcall(function()
                Remotes.Cancel:FireServer()
            end)
            task.wait(0.15)
        end

        local existingTool, existingId = Coffee.findHeldOrBackpackTool(nil)
        if existingTool then
            return Coffee.drinkExistingTool(existingTool, existingId)
        end

        if Coffee.isHotbarFull() then
            if not State.Coffee.WarnedHotbar and UI.Window then
                State.Coffee.WarnedHotbar = true
                UI.Window:Notify({ title = "Coffee Blocked", content = "Hotbar full — free 1 slot for Coffee", duration = 4 })
            end
            return false
        end

        local holdRem = Remotes.CoffeeHold
        if holdRem and holdRem.Parent then
            local okH, holdRes, holdReason = pcall(function()
                return holdRem:InvokeServer(cid)
            end)
            if okH and holdRes == false then
                if holdReason == "HotbarFull" and not State.Coffee.WarnedHotbar then
                    State.Coffee.WarnedHotbar = true
                    if UI.Window then
                        UI.Window:Notify({ title = "Coffee Blocked", content = "Hotbar full — free 1 tool slot for Coffee", duration = 4 })
                    end
                end
                return false
            end
        else
            local frame = Coffee.getItemsFrame()
            local tile = frame and frame:FindFirstChild("Coffee_" .. cid)
            if tile then
                Util.triggerBtn(tile)
            end
        end

        local tool = nil
        local waitToolAt = os.clock()
        while not tool and (os.clock() - waitToolAt) < 1.5 do
            tool = Coffee.findHeldOrBackpackTool(cid) or Coffee.findHeldOrBackpackTool(nil)
            if tool then
                break
            end
            task.wait(0.1)
        end

        if not tool then
            return false
        end

        return Coffee.drinkExistingTool(tool, cid)
    end)

    State.Coffee.IsDrinking = false
    Coffee.syncHeldFlag()
    if State.EnabledAutoEquip and not (State.EnabledPauseNoWater and State.IsFarmPausedNoWater) then
        task.delay(0.2, RodSys.equip)
    end
    return okRun and drank == true
end

function Coffee.buildBrewTasks()
    local c = State.Coffee
    local candidates = Coffee.getCandidateOrder()
    local tasksToTry = {}

    for _, cid in ipairs(candidates) do
        if Coffee.hasTicket(cid) then
            table.insert(tasksToTry, { cid, true })
        end
    end

    if c.AllowFishTrade and Coffee.tradesRemaining() > 0 then
        local counts = Coffee.getBagFishCounts(false)
        if counts then
            for _, cid in ipairs(candidates) do
                if Coffee.canAffordFishRecipe(cid, counts) then
                    table.insert(tasksToTry, { cid, false })
                end
            end
        end
    end

    return tasksToTry
end

function Coffee.tryInvokeBrew(brewRem, cid, useTicket)
    local okB, res = pcall(function()
        if useTicket then
            return brewRem:InvokeServer(cid, "ticket")
        else
            return brewRem:InvokeServer(cid)
        end
    end)
    if okB and type(res) == "table" then
        return res
    end
    return { ok = false, reason = "Error" }
end

function Coffee.brewBatchAndDrink(tasksToTry, syncBeforeReturn)
    local brewRem = Remotes.CoffeeBrew
    if not brewRem or not brewRem.Parent or #tasksToTry == 0 then
        return false
    end

    if Coffee.isHotbarFull() then
        if not State.Coffee.WarnedHotbar and UI.Window then
            State.Coffee.WarnedHotbar = true
            UI.Window:Notify({ title = "Coffee Skipped", content = "Hotbar full — free 1 tool slot before brewing", duration = 4 })
        end
        State.Coffee.BrewCooldownUntil = os.clock() + 30
        return false
    end

    State.Coffee.IsDrinking = true
    State.Coffee.DrinkStartedAt = os.clock()
    State.Coffee.LastAttemptAt = os.clock() + 12

    local brewedId = nil

    pcall(function()
        local bWait = os.clock()
        while (State.BiteActive or State.WaitingForBite) and (os.clock() - bWait) < 10 do
            task.wait(0.1)
        end
        if (State.BiteActive or State.WaitingForBite) and Remotes.Cancel and Remotes.Cancel.Parent then
            pcall(function()
                Remotes.Cancel:FireServer()
            end)
            task.wait(0.15)
        end

        local needVisitFellicia = false
        local sawDailyLimit = false
        local sawLevelLock = false

        for _, item in ipairs(tasksToTry) do
            local cid, useTicket = item[1], item[2]
            if useTicket or (not sawDailyLimit and Coffee.tradesRemaining() > 0) then
                local res = Coffee.tryInvokeBrew(brewRem, cid, useTicket)
                if res.ok then
                    brewedId = cid
                    State.BagFishCounts = nil
                    break
                elseif res.reason == "Far" then
                    needVisitFellicia = true
                    break
                elseif res.reason == "DailyLimit" and not useTicket then
                    sawDailyLimit = true
                elseif res.reason == "Level" then
                    sawLevelLock = true
                    break
                end
            end
        end

        if not brewedId and needVisitFellicia and State.Coffee.AutoVisitFellicia then
            Coffee.cacheFellicia()
            local fCF = State.Coffee.FelliciaCFrame
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")

            if not fCF then
                State.Coffee.NoFelliciaUntil = os.clock() + 120
            elseif char and hrp and hum and hum.Health > 0 then
                local savedCF = hrp.CFrame
                if State.Primordial.CurrentEvent and CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent] then
                    savedCF = CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent].CFrame
                end

                if Util.stealthTeleport(fCF * CFrame.new(0, 0, -4), fCF.Position, 0) then
                    local qStep = tonumber(LocalPlayer:GetAttribute("CoffeeQuestStep")) or 0
                    if qStep < 1 and Remotes.CoffeeMeet and Remotes.CoffeeMeet.Parent then
                        pcall(function()
                            Remotes.CoffeeMeet:InvokeServer()
                        end)
                        task.wait(0.3)
                    end

                    sawDailyLimit = false
                    sawLevelLock = false

                    for _, item in ipairs(tasksToTry) do
                        local cid, useTicket = item[1], item[2]
                        if useTicket or (not sawDailyLimit and Coffee.tradesRemaining() > 0) then
                            local res2 = nil
                            for retry = 1, 3 do
                                res2 = Coffee.tryInvokeBrew(brewRem, cid, useTicket)
                                if res2.reason == "Busy" and retry < 3 then
                                    task.wait(0.6)
                                elseif res2.reason == "Far" and retry < 3 then
                                    Util.stealthTeleport(fCF * CFrame.new(0, 0, -3.5), fCF.Position, 0)
                                else
                                    break
                                end
                            end

                            if res2 and res2.ok then
                                brewedId = cid
                                State.BagFishCounts = nil
                                break
                            elseif res2 and res2.reason == "DailyLimit" and not useTicket then
                                sawDailyLimit = true
                            elseif res2 and res2.reason == "Level" then
                                sawLevelLock = true
                                break
                            elseif res2 and res2.reason == "NotEnough" and not useTicket then
                                State.BagFishCounts = nil
                            end
                        end
                    end

                    Util.stealthTeleport(savedCF, nil, 0.35)
                end
            end
        end

        if sawDailyLimit then
            State.Coffee.DailyLimitDay = Coffee.utcDay()
        end
        if sawLevelLock then
            State.Coffee.LevelLockedUntil = os.clock() + 120
        end

        if brewedId then
            if UI.Window then
                UI.Window:Notify({ title = "Coffee Brewed", content = "Crafted " .. brewedId, duration = 3 })
            end
            local waitStart = os.clock()
            while Coffee.getInvCount(brewedId) <= 0 and not Coffee.findHeldOrBackpackTool(brewedId) and (os.clock() - waitStart) < 4.5 do
                task.wait(0.2)
            end
        else
            State.Coffee.BrewCooldownUntil = os.clock() + 45
        end
    end)

    State.Coffee.IsDrinking = false
    if not syncBeforeReturn then
        Water.refresh(false, true)
    end
    if brewedId then
        return Coffee.pullAndDrink(brewedId)
    elseif State.EnabledAutoEquip and not (State.EnabledPauseNoWater and State.IsFarmPausedNoWater) then
        task.delay(0.2, RodSys.equip)
    end
    return false
end

function Coffee.prepareBeforeEvent()
    local c = State.Coffee
    if not c.Enabled or c.IsDrinking or State.InAfkServer then
        return
    end
    if Coffee.getActiveInfo() then
        return
    end
    local existingTool, existingId = Coffee.findHeldOrBackpackTool(nil)
    if existingTool then
        Coffee.pullAndDrink(existingId)
        return
    end
    local candidates = Coffee.getCandidateOrder()
    for _, cid in ipairs(candidates) do
        if Coffee.getInvCount(cid) > 0 then
            Coffee.pullAndDrink(cid)
            return
        end
    end
    local now = os.clock()
    if now < c.BrewCooldownUntil or now < c.LevelLockedUntil or now < c.NoFelliciaUntil then
        return
    end
    local cc = Cfg.syncCoffeeCache()
    local curLvl = Monitor.readLevelXp()
    if cc and cc.RequireLevel and curLvl and curLvl < cc.RequireLevel then
        return
    end
    local tasksToTry = Coffee.buildBrewTasks()
    if #tasksToTry > 0 then
        c.BrewCooldownUntil = now + 20
        Coffee.brewBatchAndDrink(tasksToTry, true)
    end
end

function Coffee.evaluate()
    local c = State.Coffee
    if not c.Enabled or c.IsDrinking or State.Primordial.IsTeleporting or State.Maze.IsRunning or State.InAfkServer then
        return
    end
    local now = os.clock()
    if (now - c.LastAttemptAt) < 4 then
        return
    end

    if c.TriggerMode == "Primordial Events Only" and not State.Primordial.CurrentEvent then
        return
    end

    if Coffee.getActiveInfo() then
        return
    end

    c.LastAttemptAt = now

    local existingTool, existingId = Coffee.findHeldOrBackpackTool(nil)
    if existingTool then
        task.spawn(Coffee.pullAndDrink, existingId)
        return
    end

    local candidates = Coffee.getCandidateOrder()
    for _, cid in ipairs(candidates) do
        if Coffee.getInvCount(cid) > 0 then
            task.spawn(Coffee.pullAndDrink, cid)
            return
        end
    end

    if now < c.BrewCooldownUntil or now < c.LevelLockedUntil or now < c.NoFelliciaUntil then
        return
    end

    local cc = Cfg.syncCoffeeCache()
    local curLvl = Monitor.readLevelXp()
    if cc and cc.RequireLevel and curLvl and curLvl < cc.RequireLevel then
        return
    end

    local tasksToTry = Coffee.buildBrewTasks()
    if #tasksToTry > 0 then
        c.BrewCooldownUntil = now + 15
        task.spawn(Coffee.brewBatchAndDrink, tasksToTry, false)
    end
end

-- ==================== AUTO QUESTS, DAILY LOGIN & SAKURA EVENT MODULE ====================
function Quests.notify(title, text, color)
    if UI.Window then
        task.defer(function()
            UI.Window:Notify({ title = title, content = text, duration = 4 })
        end)
    end
    Webhook.quest(title, text, color)
end

function Quests.checkPlaytime()
    local q = State.Quests
    if q.Mode == "Disabled" or q.IsClaiming then
        return
    end
    local claimable = tonumber(LocalPlayer:GetAttribute("QuestClaimable")) or 0
    if claimable <= 0 then
        q.LastPlaytimeAlert = ""
        return
    end

    if q.Mode == "Notify Only" then
        local key = tostring(claimable)
        if q.LastPlaytimeAlert ~= key then
            q.LastPlaytimeAlert = key
            Quests.notify("Playtime Quest Ready", string.format("%d Playtime milestone(s) ready to claim.", claimable), CONST.RARITY_COLORS.Quest)
        end
        return
    end

    local getRem = Remotes.QuestGetState
    local claimRem = Remotes.QuestClaim
    if not getRem or not getRem.Parent or not claimRem or not claimRem.Parent then
        return
    end

    q.IsClaiming = true
    pcall(function()
        local okS, st = pcall(function()
            return getRem:InvokeServer()
        end)
        if not okS or type(st) ~= "table" or not st.loaded then
            return
        end

        local dqCfg = Cfg.get("DailyQuestConfig")
        local list = (dqCfg and type(dqCfg.Quests) == "table" and dqCfg.Quests) or CONST.DEFAULT_PLAYTIME_QUESTS
        local secs = tonumber(st.seconds) or 0
        local claimedTbl = type(st.claimed) == "table" and st.claimed or {}

        local claimedCount = 0
        local totalCoins = 0

        for idx, milestone in ipairs(list) do
            local reqSec = (tonumber(milestone.Minutes) or 99999) * 60
            if not claimedTbl[idx] and secs >= reqSec then
                local okC, okRes, newSt = pcall(function()
                    return claimRem:InvokeServer(idx)
                end)
                if okC and okRes then
                    claimedCount += 1
                    totalCoins += (tonumber(milestone.Coin) or 0)
                    if type(newSt) == "table" and type(newSt.claimed) == "table" then
                        claimedTbl = newSt.claimed
                        secs = tonumber(newSt.seconds) or secs
                    else
                        claimedTbl[idx] = true
                    end
                    task.wait(0.15)
                end
            end
        end

        if claimedCount > 0 then
            Quests.notify("Playtime Quests Claimed", string.format("Claimed %d Playtime Quest(s) (+%s coins)", claimedCount, Util.formatShort(totalCoins)), CONST.RARITY_COLORS.Quest)
        end
    end)
    q.IsClaiming = false
end

function Quests.checkWeekly()
    local q = State.Quests
    if q.Mode == "Disabled" or q.IsClaiming then
        return
    end
    local claimable = tonumber(LocalPlayer:GetAttribute("QuestWeeklyClaimable")) or 0
    if claimable <= 0 then
        q.LastWeeklyAlert = ""
        return
    end

    if q.Mode == "Notify Only" then
        local key = tostring(claimable)
        if q.LastWeeklyAlert ~= key then
            q.LastWeeklyAlert = key
            Quests.notify("Weekly Quest Ready", string.format("%d Weekly reward(s) ready to claim.", claimable), CONST.RARITY_COLORS.Quest)
        end
        return
    end

    local wGet = Remotes.QuestWeeklyGet
    local wClaim = Remotes.QuestWeeklyClaim
    local wBonus = Remotes.QuestWeeklyBonus
    if not wGet or not wGet.Parent or not wClaim or not wClaim.Parent then
        return
    end

    q.IsClaiming = true
    pcall(function()
        local okS, st = pcall(function()
            return wGet:InvokeServer()
        end)
        if not okS or type(st) ~= "table" or not st.loaded or type(st.quests) ~= "table" then
            return
        end

        local claimedCount = 0
        local totalCoins = 0
        local bonusTickets = 0

        for idx, mission in ipairs(st.quests) do
            local prog = tonumber(mission.progress) or 0
            local goal = math.max(1, tonumber(mission.goal) or 1)
            if not mission.claimed and prog >= goal then
                local okC, okRes, newSt = pcall(function()
                    return wClaim:InvokeServer(idx)
                end)
                if okC and okRes then
                    claimedCount += 1
                    totalCoins += (tonumber(mission.coins) or 0)
                    if type(newSt) == "table" and newSt.loaded then
                        st = newSt
                    end
                    task.wait(0.15)
                end
            end
        end

        if wBonus and wBonus.Parent and type(st.bonus) == "table" and st.bonus.ready == true and not st.bonus.claimed then
            local okB, okBRes = pcall(function()
                return wBonus:InvokeServer()
            end)
            if okB and okBRes then
                claimedCount += 1
                totalCoins += (tonumber(st.bonus.coins) or 0)
                bonusTickets += (tonumber(st.bonus.tickets) or 0)
            end
        end

        if claimedCount > 0 then
            local tixStr = bonusTickets > 0 and string.format(" + %d Enhance Ticket(s)", bonusTickets) or ""
            Quests.notify("Weekly Quests Claimed", string.format("Claimed %d Weekly reward(s) (+%s coins%s)", claimedCount, Util.formatShort(totalCoins), tixStr), CONST.RARITY_COLORS.Quest)
        end
    end)
    q.IsClaiming = false
end

function Quests.checkSakuraEvent()
    local q = State.Quests
    if not q.AutoSakuraEvent or q.Mode == "Disabled" or q.IsClaimingEvent then
        return
    end

    local claimable = tonumber(LocalPlayer:GetAttribute("EventClaimable")) or 0
    if claimable <= 0 then
        q.LastEventAlert = ""
        return
    end

    if q.Mode == "Notify Only" then
        local key = tostring(claimable)
        if q.LastEventAlert ~= key then
            q.LastEventAlert = key
            Quests.notify("Sakura Event Ready", string.format("%d Sakura Event mission(s) ready to claim.", claimable), CONST.RARITY_COLORS.Event)
        end
        return
    end

    local eGet = Remotes.EventGet
    local eClaim = Remotes.EventClaim
    if not eGet or not eGet.Parent or not eClaim or not eClaim.Parent then
        return
    end

    q.IsClaimingEvent = true
    pcall(function()
        local okS, st = pcall(function()
            return eGet:InvokeServer()
        end)
        if not okS or type(st) ~= "table" or not st.ok or type(st.daily) ~= "table" then
            return
        end
        if st.phase ~= "live" and st.phase ~= "exchange" then
            return
        end

        local evCfg = Cfg.get("EventConfig")
        local curEv = evCfg and type(evCfg.current) == "function" and evCfg.current() or nil
        local byId = nil
        if curEv and type(evCfg.dailyFor) == "function" and type(evCfg.forTier) == "function" then
            local dList = evCfg.dailyFor(curEv, st.day)
            _, byId = evCfg.forTier(dList, st.tier)
        end

        local claimedCount = 0
        local totalPts = 0

        for _, mission in ipairs(st.daily) do
            local prog = tonumber(mission.progress) or 0
            local goal = math.max(1, tonumber(mission.goal) or 1)
            if not mission.claimed and prog >= goal then
                local okC, okRes, gainPts, newSt = pcall(function()
                    return eClaim:InvokeServer("d", mission.id)
                end)
                if okC and okRes then
                    claimedCount += 1
                    totalPts += (tonumber(gainPts) or 20)
                    mission.claimed = true
                    if type(newSt) == "table" and newSt.ok then
                        st = newSt
                    end
                    task.wait(0.15)
                end
            end
        end

        local reqTotal = 0
        local reqDone = 0
        for _, mission in ipairs(st.daily or {}) do
            local def = byId and byId[mission.id]
            if not def or not def.Optional then
                reqTotal += 1
                if mission.claimed then
                    reqDone += 1
                end
            end
        end

        if reqTotal > 0 and reqDone >= reqTotal and type(st.bonus) == "table" and not st.bonus.claimed then
            local okB, okBRes, bPts, newStB = pcall(function()
                return eClaim:InvokeServer("bonus")
            end)
            if okB and okBRes then
                claimedCount += 1
                totalPts += (tonumber(bPts) or 60)
                if type(newStB) == "table" and newStB.ok then
                    st = newStB
                end
            end
        end

        if claimedCount > 0 then
            local bal = tonumber(st.pts) or 0
            Quests.notify("Sakura Event Claimed", string.format("Claimed %d Event reward(s) (+%d • Total: %s)", claimedCount, totalPts, Util.formatNum(bal)), CONST.RARITY_COLORS.Event)
        end
    end)
    q.IsClaimingEvent = false
end

function Quests.checkDailyLogin(forceCheck)
    local q = State.Quests
    if not q.AutoDailyLogin or q.Mode == "Disabled" or q.IsCheckingDaily then
        return
    end
    local dlGet = Remotes.DailyLoginGetState
    local dlClaim = Remotes.DailyLoginClaim
    if not dlGet or not dlGet.Parent or not dlClaim or not dlClaim.Parent then
        return
    end

    local utcDay = Coffee.utcDay()
    local nowEp = Util.serverNow()
    if not forceCheck then
        local dayDone = (q.LastDailyLoginUtcDay == utcDay)
        local timerReady = (q.DailyLoginNextCheckAt > 0 and nowEp >= q.DailyLoginNextCheckAt)
        if dayDone and not timerReady then
            return
        end
    end

    q.IsCheckingDaily = true
    pcall(function()
        local okS, st = pcall(function()
            return dlGet:InvokeServer()
        end)
        if not okS or type(st) ~= "table" or not st.ready then
            return
        end

        q.LastDailyLoginUtcDay = utcDay

        if st.canClaim == true then
            if q.Mode == "Notify Only" then
                Quests.notify("Daily Login Ready", string.format("Day %d Daily Reward is ready to claim!", tonumber(st.cycle) or 1), CONST.RARITY_COLORS.Quest)
            else
                local okC, okRes, payload = pcall(function()
                    return dlClaim:InvokeServer()
                end)
                if okC and okRes and type(payload) == "table" then
                    local rwd = type(payload.reward) == "table" and payload.reward or {}
                    local dayNum = tonumber(payload.index) or tonumber(st.cycle) or 1
                    local desc
                    if rwd.Type == "Egg" then
                        desc = string.format("Day %d: %dx %s Egg", dayNum, tonumber(rwd.Count) or 1, tostring(rwd.Egg or "Daily"))
                    else
                        desc = string.format("Day %d: +%s coins", dayNum, Util.formatShort(tonumber(rwd.Amount) or 0))
                    end
                    local bonusCoins = tonumber(payload.bonus) or 0
                    if bonusCoins > 0 then
                        desc = desc .. string.format(" (+%s streak)", Util.formatShort(bonusCoins))
                    end
                    Quests.notify("Daily Login Claimed", desc, CONST.RARITY_COLORS.Quest)
                end
            end
        end

        local left = tonumber(st.secondsLeft)
        if left and left > 0 then
            q.DailyLoginNextCheckAt = nowEp + math.floor(left) + 3
        else
            q.DailyLoginNextCheckAt = 0
        end
    end)
    q.IsCheckingDaily = false
end

function Quests.evaluateAll(forceDaily)
    if State.Quests.Mode == "Disabled" then
        return
    end
    task.spawn(Quests.checkPlaytime)
    task.spawn(Quests.checkWeekly)
    task.spawn(Quests.checkSakuraEvent)
    task.spawn(Quests.checkDailyLogin, forceDaily == true)
end

-- ==================== AUTO MAZE SOLVER MODULE ====================
function Maze.cacheHoneymoon()
    local hm = workspace:FindFirstChild("Honeymoon Eternal", true)
    if hm then
        local root = hm:IsA("BasePart") and hm
            or hm:FindFirstChild("HumanoidRootPart")
            or hm.PrimaryPart
            or hm:FindFirstChildWhichIsA("BasePart")
        if root then
            State.Maze.HoneymoonCFrame = root.CFrame
            envGlobal._SaujanaHoneymoonCF = root.CFrame
        end
    elseif not State.Maze.HoneymoonCFrame and typeof(envGlobal._SaujanaHoneymoonCF) == "CFrame" then
        State.Maze.HoneymoonCFrame = envGlobal._SaujanaHoneymoonCF
    end
end

function Maze.getMinSeconds(startRes)
    local diff = tostring(startRes.diff or "Easy")
    local mc = type(startRes.mc) == "table" and startRes.mc or nil
    local minSec = mc and tonumber(mc.MinSeconds) or nil
    if not minSec then
        local skCfg = Cfg.get("SoreKrakenConfig")
        local mazeTbl = skCfg and type(skCfg.Maze) == "table" and skCfg.Maze[diff] or nil
        minSec = mazeTbl and tonumber(mazeTbl.MinSeconds) or nil
    end
    if not minSec then
        minSec = CONST.DEFAULT_MAZE_MIN_SECONDS[diff] or 6
    end

    local extra = 1.6
    if State.Maze.TimingMode == "Ultra Safe (+2.2s)" then
        extra = 2.2
    elseif State.Maze.TimingMode == "Fast (+0.9s)" then
        extra = 0.9
    end
    return minSec + extra
end

function Maze.solve(mode, isManual)
    local mz = State.Maze
    if mz.IsRunning then
        if isManual and UI.Window then
            UI.Window:Notify({ title = "AutoMaze Busy", content = "Already running a maze solve.", duration = 2 })
        end
        return false
    end
    if State.InAfkServer then
        mz.LastStatus = "Blocked (In AFK Server)"
        if isManual and UI.Window then
            UI.Window:Notify({ title = "AutoMaze", content = "Cannot run inside AFK Server.", duration = 3 })
        end
        return false
    end

    local questRem = Remotes.SoreKrakenQuest
    if not questRem or not questRem.Parent then
        mz.LastStatus = "Remote Missing"
        if isManual and UI.Window then
            UI.Window:Notify({ title = "AutoMaze Error", content = "SoreKrakenRemotes.Quest not found yet.", duration = 3 })
        end
        return false
    end

    if PlayerGui and PlayerGui:FindFirstChild("SoreMazeUI") then
        mz.LastStatus = "Manual Maze UI Open"
        if isManual and UI.Window then
            UI.Window:Notify({ title = "AutoMaze Skipped", content = "Close or finish the open Maze UI first.", duration = 3 })
        end
        return false
    end

    local curLvl = tonumber(LocalPlayer:GetAttribute("Level")) or 0
    if curLvl < 70 then
        mz.LastStatus = "Need Lv. 70+"
        if isManual and UI.Window then
            UI.Window:Notify({ title = "AutoMaze Locked", content = "Honeymoon Eternal unlocks at Level 70.", duration = 3 })
        end
        return false
    end

    if mode == "Daily" then
        if LocalPlayer:GetAttribute("HoneymoonDailyDone") == true then
            mz.LastStatus = "Daily Already Done"
            if isManual and UI.Window then
                UI.Window:Notify({ title = "Daily Maze", content = "Already cleared today's maze!", duration = 3 })
            end
            return false
        end
        if LocalPlayer:GetAttribute("HoneymoonDailyFailed") == true then
            mz.LastStatus = "Daily Attempt Used"
            if isManual and UI.Window then
                UI.Window:Notify({ title = "Daily Maze", content = "Today's daily attempt is already used.", duration = 3 })
            end
            return false
        end
    elseif mode == "Quest" then
        local skStep = tonumber(LocalPlayer:GetAttribute("SoreKrakenStep")) or 0
        if skStep >= 3 then
            mz.LastStatus = "4 Quest Mazes Already Done"
            if isManual and UI.Window then
                UI.Window:Notify({ title = "Quest Mazes", content = "All 4 Sore Kraken mazes are already cleared!", duration = 3 })
            end
            return false
        elseif skStep < 2 then
            mz.LastStatus = "Need SoreKrakenStep 2"
            if isManual and UI.Window then
                UI.Window:Notify({ title = "Quest Mazes Locked", content = "Complete 1 Daily Maze, then talk to Luna & Ryota first (Step: " .. tostring(skStep) .. ").", duration = 4 })
            end
            return false
        end
    end

    mz.IsRunning = true
    mz.StartedAt = os.clock()
    mz.LastStatus = "Preparing..."

    local okRun = pcall(function()
        local bWait = os.clock()
        while (State.BiteActive or State.WaitingForBite) and (os.clock() - bWait) < 10 do
            task.wait(0.1)
        end
        if (State.BiteActive or State.WaitingForBite) and Remotes.Cancel and Remotes.Cancel.Parent then
            pcall(function()
                Remotes.Cancel:FireServer()
            end)
            task.wait(0.2)
        end

        State.WaitingForBite = false
        State.BiteActive = false
        State.BiteHasReeled = false

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hrp or not hum or hum.Health <= 0 then
            mz.LastStatus = "No Character"
            return
        end

        local savedCF = nil
        local hopped = false

        local function ensureNearHoneymoon()
            if hopped then
                return true
            end
            if not mz.VisitHoneymoon then
                return false
            end
            Maze.cacheHoneymoon()
            if not mz.HoneymoonCFrame and State.Primordial.HomeCFrame then
                pcall(function()
                    LocalPlayer:RequestStreamAroundAsync(State.Primordial.HomeCFrame.Position)
                end)
                task.wait(0.35)
                Maze.cacheHoneymoon()
            end

            local hCF = mz.HoneymoonCFrame
            if not hCF then
                mz.LastStatus = "Honeymoon Not Found"
                if UI.Window then
                    UI.Window:Notify({ title = "AutoMaze", content = "Honeymoon Eternal not streamed — walk near her once.", duration = 4 })
                end
                return false
            end

            savedCF = (State.Primordial.CurrentEvent and CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent])
                and CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent].CFrame
                or hrp.CFrame

            if Util.stealthTeleport(hCF * CFrame.new(0, 0, -4), hCF.Position, 0) then
                hopped = true
                return true
            end
            return false
        end

        Maze.cacheHoneymoon()
        if mz.VisitHoneymoon and mz.HoneymoonCFrame and (hrp.Position - mz.HoneymoonCFrame.Position).Magnitude > 20 then
            ensureNearHoneymoon()
        end

        if LocalPlayer:GetAttribute("HoneymoonMet") ~= true then
            local okM, metRes = pcall(function()
                return questRem:InvokeServer("MeetHoneymoon")
            end)
            if okM and type(metRes) == "table" and not metRes.ok and metRes.reason == "Far" then
                if ensureNearHoneymoon() then
                    pcall(function()
                        questRem:InvokeServer("MeetHoneymoon")
                    end)
                    task.wait(0.3)
                end
            elseif okM and type(metRes) == "table" and metRes.ok then
                task.wait(0.3)
            end
        end

        local maxIter = (mode == "Quest") and 4 or 1
        local clearedCount = 0

        for _ = 1, maxIter do
            if not State.Monitor.Active or not char.Parent or not hrp.Parent or hum.Health <= 0 then
                break
            end

            local okS, resS = pcall(function()
                return questRem:InvokeServer("MazeStart", mode)
            end)
            local startRes = okS and type(resS) == "table" and resS or nil

            if startRes and not startRes.ok and startRes.reason == "Far" then
                if ensureNearHoneymoon() then
                    for retry = 1, 3 do
                        local okR, resR = pcall(function()
                            return questRem:InvokeServer("MazeStart", mode)
                        end)
                        startRes = okR and type(resR) == "table" and resR or nil
                        if startRes and (startRes.ok or startRes.reason ~= "Far") then
                            break
                        end
                        if retry < 3 and mz.HoneymoonCFrame then
                            Util.stealthTeleport(mz.HoneymoonCFrame * CFrame.new(0, 0, -3.5), mz.HoneymoonCFrame.Position, 0)
                        end
                    end
                end
            end

            if not startRes or not startRes.ok or startRes.token == nil then
                local rsn = (startRes and tostring(startRes.reason)) or "Failed"
                mz.LastStatus = "Start: " .. rsn
                if rsn == "DoneToday" or rsn == "Level" then
                    mz.CooldownUntil = os.clock() + 300
                else
                    mz.CooldownUntil = os.clock() + 120
                end
                if UI.Window and clearedCount == 0 then
                    UI.Window:Notify({ title = "AutoMaze Start Failed", content = "Server rejected MazeStart: " .. rsn, duration = 4 })
                end
                break
            end

            local waitSec = Maze.getMinSeconds(startRes)
            local diffLabel = tostring(startRes.diff or "Maze")
            mz.LastStatus = string.format("Solving %s (%.1fs)", diffLabel, waitSec)
            if UI.Window then
                UI.Window:Notify({ title = "AutoMaze Started", content = string.format("%s (%s) — finishing in %.1fs...", mode, diffLabel, waitSec), duration = 3 })
            end

            local waitEnd = os.clock() + waitSec
            while os.clock() < waitEnd and State.Monitor.Active and char.Parent and hrp.Parent and hum.Health > 0 do
                task.wait(0.2)
            end

            if not State.Monitor.Active or not char.Parent or not hrp.Parent or hum.Health <= 0 then
                break
            end

            local okF, finRes = pcall(function()
                return questRem:InvokeServer("MazeFinish", startRes.token)
            end)

            if okF and type(finRes) == "table" and finRes.ok then
                clearedCount += 1
                local rewardCoins = tonumber(finRes.reward) or 0
                local tix = tonumber(finRes.tickets) or 0
                local rewardStr = "+" .. Util.formatShort(rewardCoins) .. " coins"
                if tix > 0 then
                    rewardStr = rewardStr .. " + " .. tostring(tix) .. " Ticket(s)"
                end
                mz.LastStatus = string.format("Cleared %s (%s)", diffLabel, rewardStr)
                if UI.Window then
                    UI.Window:Notify({ title = "Maze Cleared!", content = string.format("%s (%s): %s", mode, diffLabel, rewardStr), duration = 4 })
                end
                Webhook.quest(string.format("Maze Cleared (%s - %s)", mode, diffLabel), rewardStr, CONST.RARITY_COLORS.Quest)

                if mode ~= "Quest" or finRes.next == nil then
                    break
                end
                task.wait(0.35)
            else
                local errReason = (okF and type(finRes) == "table" and tostring(finRes.reason)) or "Rejected"
                mz.LastStatus = "Finish Failed: " .. errReason
                mz.CooldownUntil = os.clock() + 300
                if UI.Window then
                    UI.Window:Notify({ title = "AutoMaze Failed", content = "MazeFinish rejected: " .. errReason, duration = 4 })
                end
                Webhook.alert("AutoMaze Finish Rejected", string.format("Mode: %s (%s) | Reason: %s", mode, diffLabel, errReason), CONST.RARITY_COLORS.Alert)
                break
            end
        end

        if hopped and savedCF and char.Parent and hrp.Parent then
            Util.stealthTeleport(savedCF, nil, 0.35)
        end
    end)

    mz.IsRunning = false
    if not okRun then
        mz.LastStatus = "Error"
    end
    Water.refresh(false, true)
    if State.EnabledAutoEquip and not (State.EnabledPauseNoWater and State.IsFarmPausedNoWater) then
        task.delay(0.2, RodSys.equip)
    end
    return okRun
end

-- ==================== PRIMORDIAL EVENT TELEPORT MODULE ====================
function Primordial.isSpotActive(spot)
    local nowEp = Util.serverNow()
    local active = false

    local cfg = Cfg.get(spot.CfgName)
    if cfg and type(cfg.isActive) == "function" then
        local okA, res = pcall(function()
            return cfg.isActive(nowEp)
        end)
        if okA and res == true then
            active = true
        end
    end

    if not active then
        local stMod = Cfg.sharedMod(spot.StateName)
        if stMod and type(stMod.isActive) == "function" then
            local okS, resS = pcall(function()
                return stMod.isActive()
            end)
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

function Primordial.isRodValidForSpot(rodName, cfg, spot)
    local rc = Cfg.get("RodConfig")
    local rInfo = rc and type(rc.get) == "function" and rc.get(rodName) or nil
    if rInfo and rInfo.Access == "Staff" then
        return true
    end
    if type(cfg.rodAllowed) == "function" then
        local okR, allowed = pcall(function()
            return cfg.rodAllowed(rodName)
        end)
        if okR and not allowed then
            return false
        end
    end
    if rInfo and spot.MinKg and (tonumber(rInfo.MaxKg) or 0) < spot.MinKg then
        return false
    end
    return true
end

function Primordial.hasEligibleRodInUI(cfg, spot)
    local rcCont = RodSys.getContentContainer()
    if not rcCont then
        return false
    end
    for _, entry in ipairs(rcCont:GetChildren()) do
        if entry:IsA("GuiObject") and entry.Visible then
            local lower = string.lower(entry.Name)
            if lower ~= "template" and lower ~= "example" and lower ~= "placeholder" then
                local rName = entry:GetAttribute("RodName") or entry.Name
                if Primordial.isRodValidForSpot(rName, cfg, spot) then
                    return true
                end
            end
        end
    end
    return false
end

function Primordial.isSpotEligible(spot, curLvl, gear)
    if State.Primordial.BlockedUntil[spot.Key] and os.clock() < State.Primordial.BlockedUntil[spot.Key] then
        return false, "Snapback cooldown"
    end

    local cfg = Cfg.get(spot.CfgName)
    if not cfg then
        return false, "Config loading"
    end

    if State.Primordial.CheckUnlocks and spot.UnlockAttr then
        if LocalPlayer:GetAttribute(spot.UnlockAttr) ~= true then
            return false, "Not Unlocked"
        end
    end

    local reqLvl = tonumber(cfg.RequireLevel) or 0
    if curLvl and curLvl < reqLvl then
        return false, "Need Lv." .. reqLvl
    end

    if not Primordial.isRodValidForSpot(gear.RodName, cfg, spot) then
        local hasAllowed = false
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, item in ipairs(bp:GetChildren()) do
                if RodSys.isRod(item) then
                    local rn = item:GetAttribute("RodName") or item.Name
                    if Primordial.isRodValidForSpot(rn, cfg, spot) then
                        hasAllowed = true
                        break
                    end
                end
            end
        end
        if not hasAllowed then
            hasAllowed = Primordial.hasEligibleRodInUI(cfg, spot)
        end
        if not hasAllowed then
            return false, "Need Stronger Rod"
        end
    end

    return true, "Eligible"
end

function Primordial.pickBestEvent()
    local curLvl = Monitor.readLevelXp()
    local gear = Monitor.getGearSummary()
    local candidates = {}

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
        end
        if a.Priority ~= b.Priority then
            return a.Priority > b.Priority
        end
        return (State.Primordial.ActivatedAt[a.Key] or 0) > (State.Primordial.ActivatedAt[b.Key] or 0)
    end)

    return candidates[1]
end

function Primordial.teleportTo(targetCF, spot)
    local p = State.Primordial
    if p.IsTeleporting or not targetCF then
        return
    end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then
        return
    end

    p.IsTeleporting = true
    p.TeleportStartedAt = os.clock()
    p.LastTeleportAt = os.clock()

    task.spawn(function()
        pcall(function()
            local waitStart = os.clock()
            while (State.BiteActive or State.WaitingForBite) and (os.clock() - waitStart) < 12 do
                task.wait(0.1)
            end

            if (State.BiteActive or State.WaitingForBite) and Remotes.Cancel and Remotes.Cancel.Parent then
                pcall(function()
                    Remotes.Cancel:FireServer()
                end)
                task.wait(0.15)
            end

            State.WaitingForBite = false
            State.BiteActive = false
            State.BiteHasReeled = false
            State.ConsecutiveBusyFails = 0

            char = LocalPlayer.Character
            hrp = char and char:FindFirstChild("HumanoidRootPart")
            hum = char and char:FindFirstChildOfClass("Humanoid")

            if char and char.Parent and hrp and hrp.Parent and hum and hum.Health > 0 then
                if not p.HomeCFrame and spot then
                    p.HomeCFrame = hrp.CFrame
                end

                if spot and not p.CurrentEvent and State.Coffee.Enabled then
                    Coffee.prepareBeforeEvent()
                    char = LocalPlayer.Character
                    hrp = char and char:FindFirstChild("HumanoidRootPart")
                    hum = char and char:FindFirstChildOfClass("Humanoid")
                    if not (char and char.Parent and hrp and hrp.Parent and hum and hum.Health > 0) then
                        return
                    end
                end

                if not Util.stealthTeleport(targetCF, nil, 0.4) then
                    return
                end

                State.WaitingForBite = false
                State.LastWaterScanPos = nil
                State.LastWaterHitPos = nil
                State.LastCastSentAt = 0

                if spot then
                    p.CurrentEvent = spot.Key
                    State.IsNearWater = true
                    State.IsFarmPausedNoWater = false
                    Util.updateStatusTag()

                    Water.refresh(false, true)

                    if p.SwapEventRod then
                        RodSys.recheckBestRod()
                    elseif State.EnabledAutoEquip then
                        RodSys.equip()
                    end
                    if State.Coffee.Enabled then
                        task.delay(0.8, Coffee.evaluate)
                    end

                    local cfg = Cfg.get(spot.CfgName)
                    local leftSec = (cfg and type(cfg.secondsLeft) == "function") and cfg.secondsLeft(Util.serverNow()) or 0
                    local gear = Monitor.getGearSummary(true)
                    local chStr = "--"
                    if cfg and type(cfg.chance) == "function" then
                        local okC, bProb = pcall(function()
                            return cfg.chance(gear.TotalLuck)
                        end)
                        if okC and type(bProb) == "number" and bProb > 0 then
                            local rb = (gear.RodInfo and gear.RodInfo.PrimordialBonus and gear.RodInfo.PrimordialBonus[spot.Name]) or 0
                            chStr = Util.formatOneIn(bProb * (1 + rb) * (gear.PrimordialMult or 1))
                        end
                    end

                    if UI.Window then
                        UI.Window:Notify({ title = "Primordial Event!", content = string.format("Teleported to %s (%s left)", spot.Name, Util.formatDur(leftSec)), duration = 4 })
                    end
                    Webhook.primordial(
                        "Primordial Event Joined: " .. spot.Name,
                        string.format("Teleported to **%s** (%s remaining)\nRod: %s • Luck: %.1fx (%s)\nCoffee: %s", spot.Name, Util.formatDur(leftSec), gear.RodName, gear.TotalLuck, chStr, Coffee.getStatusSummary()),
                        CONST.RARITY_COLORS.Primordial
                    )

                    task.delay(1.8, function()
                        if hrp and hrp.Parent and p.CurrentEvent == spot.Key then
                            local dist = (hrp.Position - targetCF.Position).Magnitude
                            if dist > 60 then
                                p.BlockedUntil[spot.Key] = os.clock() + 120
                                p.CurrentEvent = nil
                                Util.updateStatusTag()
                                Webhook.alert("Primordial Snapback", string.format("Server moved player away from %s. Skipping for 2m.", spot.Name), CONST.RARITY_COLORS.Alert)
                            end
                        end
                    end)
                else
                    p.CurrentEvent = nil
                    p.HomeCFrame = nil
                    State.IsNearWater = true
                    State.IsFarmPausedNoWater = false
                    Util.updateStatusTag()
                    Water.refresh(false, true)
                    if p.SwapEventRod then
                        RodSys.recheckBestRod()
                    elseif State.EnabledAutoEquip then
                        RodSys.equip()
                    end
                    if UI.Window then
                        UI.Window:Notify({ title = "Primordial Ended", content = "Returned to your normal fishing spot", duration = 3 })
                    end
                    Webhook.primordial("Primordial Window Ended", "Returned safely to normal fishing spot.", CONST.RARITY_COLORS.Report)
                end
            end
        end)

        p.IsTeleporting = false
    end)
end

function Primordial.evaluate()
    local p = State.Primordial
    if not p.Enabled or p.IsTeleporting or State.Coffee.IsDrinking or State.Maze.IsRunning or State.InAfkServer then
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
            Primordial.teleportTo(bestSpot.CFrame, bestSpot)
        end
    elseif p.CurrentEvent ~= nil then
        if p.ReturnHome and p.HomeCFrame then
            Primordial.teleportTo(p.HomeCFrame, nil)
        else
            p.CurrentEvent = nil
            Util.updateStatusTag()
            if p.SwapEventRod then
                RodSys.recheckBestRod()
            end
        end
    end
end

function Primordial.bindNotifUI(gui)
    local matchedKey = nil
    for _, key in ipairs(CONST.PRIMORDIAL_ORDER) do
        if gui.Name == CONST.PRIMORDIAL_SPOTS[key].NotifUI then
            matchedKey = key
            break
        end
    end
    if not matchedKey or not gui:IsA("LayerCollector") then
        return
    end

    local function onEnabled()
        if gui.Enabled then
            State.Primordial.NotifUntil[matchedKey] = os.clock() + 60
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

-- ==================== PERFORMANCE, GRAPHICS, MUSIC & LOADING BYPASS ====================
function Perf.applyLowestGraphics()
    if State.Perf.LowestGraphics then
        pcall(function()
            LocalPlayer:SetAttribute("GraphicsDetail", "Low")
            LocalPlayer:SetAttribute("DisableEffects", true)
            LocalPlayer:SetAttribute("DisableBlur", true)
            LocalPlayer:SetAttribute("DisableShadow", true)
            LocalPlayer:SetAttribute("HideOtherPets", true)
            LocalPlayer:SetAttribute("HideTitles", true)
        end)
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        pcall(function()
            Svc.Lighting.GlobalShadows = false
            for _, child in ipairs(Svc.Lighting:GetChildren()) do
                if child:IsA("BlurEffect") or child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") then
                    child.Enabled = false
                elseif child:IsA("Atmosphere") then
                    child.Haze = 0
                    child.Glare = 0
                end
            end
        end)
        pcall(function()
            local terrain = workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
                terrain.WaterReflectance = 0
                local clouds = terrain:FindFirstChildOfClass("Clouds")
                if clouds then
                    clouds.Enabled = false
                end
            end
        end)
    else
        pcall(function()
            LocalPlayer:SetAttribute("DisableEffects", false)
            LocalPlayer:SetAttribute("DisableBlur", false)
            LocalPlayer:SetAttribute("DisableShadow", false)
        end)
    end
end

function Perf.setMusicGenre(genre, switchLive)
    local clean = Util.normalizeGenre(genre)
    State.Perf.MusicGenre = clean
    pcall(function()
        LocalPlayer:SetAttribute("MusicGenre", clean)
    end)

    if switchLive and PlayerGui then
        local g = PlayerGui:FindFirstChild("GameUI")
        local menus = g and g:FindFirstChild("Menus")
        local music = menus and menus:FindFirstChild("Music")
        if music then
            local genreBtn = music:FindFirstChild("Genre_" .. clean, true)
            if genreBtn and genreBtn:IsA("GuiButton") then
                Util.triggerBtn(genreBtn)
                local nextBtn = music:FindFirstChild("Next", true)
                if nextBtn and nextBtn:IsA("GuiButton") then
                    task.delay(0.1, function()
                        Util.triggerBtn(nextBtn)
                    end)
                end
            end
        end
    end
end

function Perf.disableLoadingConnections()
    local getConnsFn = Util.getExecutorFunc("getconnections")
    if not getConnsFn then
        return false
    end

    local function disableSignalFrom(sig, keyword)
        if not sig then
            return
        end
        local okC, conns = pcall(function()
            return getConnsFn(sig)
        end)
        if not okC or type(conns) ~= "table" then
            return
        end
        for _, conn in ipairs(conns) do
            if conn.Function then
                local okI, src = pcall(function()
                    return debug.info(conn.Function, "s")
                end)
                if okI and type(src) == "string" and string.find(src, keyword, 1, true) then
                    pcall(function()
                        conn:Disable()
                    end)
                end
            end
        end
    end

    disableSignalFrom(Svc.RunService.RenderStepped, "LemonadeLoadingScreen")
    if PlayerGui then
        disableSignalFrom(PlayerGui.ChildAdded, "LemonadeLoadingScreen")
        for _, child in ipairs(PlayerGui:GetChildren()) do
            if child:IsA("ScreenGui") and child.Name ~= "LemonadeLoadingScreen" then
                disableSignalFrom(child:GetPropertyChangedSignal("Enabled"), "LemonadeLoadingScreen")
            end
        end
    end
    return true
end

function Perf.handleLoadingScreen(gui)
    if not gui or not gui.Parent or State.Perf.LoadingHandled then
        return
    end
    State.Perf.LoadingHandled = true

    Perf.setMusicGenre(State.Perf.MusicGenre, false)
    if State.Perf.LowestGraphics then
        Perf.applyLowestGraphics()
    end

    if not State.Perf.AutoDismissLoading then
        return
    end

    task.spawn(function()
        local waitLang = os.clock()
        while LocalPlayer:GetAttribute("LanguageLoaded") ~= true and (os.clock() - waitLang) < 2.0 do
            task.wait(0.1)
        end

        pcall(function()
            local langMod = Cfg.sharedMod("Lang")
            if langMod and type(langMod.chosen) == "function" and not langMod.chosen() and type(langMod.set) == "function" then
                langMod.set("en")
            end
        end)

        Perf.setMusicGenre(State.Perf.MusicGenre, false)
        if State.Perf.LowestGraphics then
            Perf.applyLowestGraphics()
        end

        local skipNow = gui:FindFirstChild("SkipNow", true)
        if skipNow and skipNow:IsA("BindableEvent") then
            pcall(function()
                skipNow:Fire()
            end)
        end

        task.wait(0.15)
        local cleanedHooks = Perf.disableLoadingConnections()

        if cleanedHooks then
            pcall(function()
                local blur = Svc.Lighting:FindFirstChild("LemonadeGraphicsBlur")
                if blur then
                    blur:Destroy()
                end
            end)
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp then
                    hrp.Anchored = false
                end
                local cam = workspace.CurrentCamera
                if cam then
                    cam.CameraType = Enum.CameraType.Custom
                    if hum then
                        cam.CameraSubject = hum
                    end
                end
            end)
            if PlayerGui then
                for _, name in ipairs(CONST.RESTORE_GAME_GUIS) do
                    local sg = PlayerGui:FindFirstChild(name)
                    if sg and sg:IsA("ScreenGui") then
                        sg.Enabled = true
                    end
                end
            end
            pcall(function()
                gui:Destroy()
            end)
        else
            local endWait = os.clock() + 12
            while gui.Parent and os.clock() < endWait do
                local langGrp = gui:FindFirstChild("LanguageGroup")
                if langGrp and langGrp:IsA("GuiObject") and langGrp.Visible then
                    local enBtn = langGrp:FindFirstChild("en", true)
                    if enBtn then
                        Util.triggerBtn(enBtn)
                    end
                end
                local genGrp = gui:FindFirstChild("GenreGroup")
                if genGrp and genGrp:IsA("GuiObject") and genGrp.Visible then
                    local gBtn = genGrp:FindFirstChild(State.Perf.MusicGenre, true)
                    if gBtn then
                        Util.triggerBtn(gBtn)
                    end
                end
                local selGrp = gui:FindFirstChild("SelectGroup")
                if selGrp and selGrp:IsA("GuiObject") and selGrp.Visible then
                    local lowBtn = selGrp:FindFirstChild("Low", true)
                    if lowBtn then
                        Util.triggerBtn(lowBtn)
                    end
                end
                task.wait(0.25)
            end
        end

        task.wait(0.25)
        Perf.setMusicGenre(State.Perf.MusicGenre, false)
        if State.Perf.LowestGraphics then
            Perf.applyLowestGraphics()
        end
    end)
end

function Perf.hideOverlayGui(gui)
    if not gui or not CONST.BLOCKED_FX_GUIS[gui.Name] then
        return
    end
    pcall(function()
        if gui:IsA("LayerCollector") then
            gui.Enabled = false
        end
    end)
end

function Perf.suppressFxConnections(fxRemote)
    if not State.Perf.DisableCutscenes or not fxRemote or not fxRemote.Parent then
        return
    end
    local getConnsFn = Util.getExecutorFunc("getconnections")
    if not getConnsFn then
        return
    end
    local okC, conns = pcall(function()
        return getConnsFn(fxRemote.OnClientEvent)
    end)
    if not okC or type(conns) ~= "table" then
        return
    end
    for _, conn in ipairs(conns) do
        if conn.Function and not table.find(Conns.DisabledFxConns, conn) then
            local okI, src = pcall(function()
                return debug.info(conn.Function, "s")
            end)
            if okI and type(src) == "string" and string.find(src, "FishEffects", 1, true) then
                local okD = pcall(function()
                    conn:Disable()
                end)
                if okD then
                    table.insert(Conns.DisabledFxConns, conn)
                end
            end
        end
    end
end

function Perf.applyCutsceneBlocker(enabled)
    State.Perf.DisableCutscenes = enabled

    for _, k in ipairs({ "WorkspaceFx", "LightingFx", "CameraType" }) do
        if Conns[k] then
            Conns[k]:Disconnect()
            Conns[k] = nil
        end
    end

    if not enabled then
        for _, conn in ipairs(Conns.DisabledFxConns) do
            pcall(function()
                conn:Enable()
            end)
        end
        table.clear(Conns.DisabledFxConns)
        if PlayerGui then
            for name, _ in pairs(CONST.BLOCKED_FX_GUIS) do
                local g = PlayerGui:FindFirstChild(name)
                if g and g:IsA("LayerCollector") and (name == "FishFxGui" or name == "CoinGainFxUI") then
                    pcall(function()
                        g.Enabled = true
                    end)
                end
            end
        end
        return
    end

    if Remotes.Fx then
        Perf.suppressFxConnections(Remotes.Fx)
    end

    if PlayerGui then
        for name, _ in pairs(CONST.BLOCKED_FX_GUIS) do
            local g = PlayerGui:FindFirstChild(name)
            if g then
                Perf.hideOverlayGui(g)
            end
        end
    end

    for _, child in ipairs(workspace:GetChildren()) do
        pcall(function()
            if child:GetAttribute("FishFx") == true or child.Name == "SoreKrakenPreview" then
                child:Destroy()
            end
        end)
    end
    local skFolder = workspace:FindFirstChild("SORE KRAKEN")
    local skPrev = skFolder and skFolder:FindFirstChild("SoreKrakenPreview")
    if skPrev then
        pcall(function()
            skPrev:Destroy()
        end)
    end

    Conns.WorkspaceFx = workspace.ChildAdded:Connect(function(child)
        if not State.Perf.DisableCutscenes then
            return
        end
        pcall(function()
            if child:GetAttribute("FishFx") == true or child.Name == "SoreKrakenPreview" then
                task.defer(function()
                    if child.Parent then
                        pcall(function()
                            child:Destroy()
                        end)
                    end
                end)
            end
        end)
    end)

    for _, child in ipairs(Svc.Lighting:GetChildren()) do
        pcall(function()
            if child.Name == "LevelUpBlur" or child.Name == "SaujanaCoffeeBlur" then
                child:Destroy()
            end
        end)
    end

    Conns.LightingFx = Svc.Lighting.ChildAdded:Connect(function(child)
        if not State.Perf.DisableCutscenes then
            return
        end
        pcall(function()
            if child.Name == "LevelUpBlur" or child.Name == "SaujanaCoffeeBlur" then
                task.defer(function()
                    if child.Parent then
                        pcall(function()
                            child:Destroy()
                        end)
                    end
                end)
            end
        end)
    end)

    local cam = workspace.CurrentCamera
    if cam then
        pcall(function()
            if cam.CameraType == Enum.CameraType.Scriptable then
                cam.CameraType = Enum.CameraType.Custom
            end
        end)
        Conns.CameraType = cam:GetPropertyChangedSignal("CameraType"):Connect(function()
            if State.Perf.DisableCutscenes then
                pcall(function()
                    if cam.CameraType == Enum.CameraType.Scriptable then
                        cam.CameraType = Enum.CameraType.Custom
                    end
                end)
            end
        end)
    end
end

-- ==================== UNIVERSAL ROD SYSTEM ====================
function RodSys.isRod(tool)
    if not tool or not tool:IsA("Tool") then
        return false
    end
    if Coffee.isCoffeeTool(tool) then
        return false
    end
    if tool:GetAttribute("FishRod") or tool:GetAttribute("RodName") ~= nil or tool:GetAttribute("SkinName") ~= nil then
        return true
    end
    local rc = Cfg.get("RodConfig")
    if rc and type(rc.Rods) == "table" and rc.Rods[tool.Name] ~= nil then
        return true
    end
    Cfg.rodSkin()
    if Cache.SkinDisplays and Cache.SkinDisplays[tool.Name] then
        return true
    end
    local ln = string.lower(tool.Name)
    return string.find(ln, "rod", 1, true) ~= nil or string.find(ln, "katana", 1, true) ~= nil
end

function RodSys.score(rodName, obj)
    local score = 1
    local rc = Cfg.get("RodConfig")
    if rc and type(rc.get) == "function" and type(rodName) == "string" then
        local info = rc.get(rodName)
        if info and type(info.Luck) == "number" then
            score = info.Luck
        end
    end

    local mods = Monitor.extractRodMods(rodName, obj)
    score += mods.AscLuck + mods.EnhanceLuck

    if obj and mods.AscLuck == 0 and mods.EnhanceLuck == 0 then
        score += (tonumber(obj:GetAttribute("Luck")) or 0)
    end

    if State.Primordial.Enabled and State.Primordial.CurrentEvent then
        local spot = CONST.PRIMORDIAL_SPOTS[State.Primordial.CurrentEvent]
        local cfg = spot and Cfg.get(spot.CfgName)
        if spot and cfg then
            if Primordial.isRodValidForSpot(rodName, cfg, spot) then
                score += 10000
                if State.Primordial.SwapEventRod and rodName == spot.PreferRod then
                    score += 1000
                end
            else
                score -= 10000
            end
        end
    end

    return score
end

function RodSys.findEquipped(char)
    if not char then
        return nil
    end
    for _, c in ipairs(char:GetChildren()) do
        if RodSys.isRod(c) then
            return c
        end
    end
    return nil
end

function RodSys.unequip()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then
        return false
    end
    if not RodSys.findEquipped(char) then
        return false
    end
    pcall(function()
        hum:UnequipTools()
    end)
    return true
end

function RodSys.findBestBackpack(bp)
    if not bp then
        return nil
    end
    local best, bestScore = nil, -999999
    for _, c in ipairs(bp:GetChildren()) do
        if RodSys.isRod(c) then
            local sc = RodSys.score(c:GetAttribute("RodName") or c.Name, c)
            if not best or sc > bestScore then
                best = c
                bestScore = sc
            end
        end
    end
    return best
end

function RodSys.getContentContainer()
    if Cache.RodContent and Cache.RodContent.Parent then
        return Cache.RodContent
    end
    if not PlayerGui then
        return nil
    end
    local bpGui = PlayerGui:FindFirstChild("Backpack")
    if not bpGui then
        return nil
    end
    local inv = bpGui:FindFirstChild("Inventory")
    local cf = inv and inv:FindFirstChild("ContentFrame")
    Cache.RodContent = (cf and cf:FindFirstChild("RodContent")) or bpGui:FindFirstChild("RodContent", true)
    return Cache.RodContent
end

function RodSys.findBestContentTarget()
    local rcCont = RodSys.getContentContainer()
    if not rcCont then
        return nil, nil, -999999
    end

    local rc = Cfg.get("RodConfig")
    Cfg.rodSkin()
    local bestTarget, bestScore = nil, -999999
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
                    or entry:IsA("GuiButton")
                    or entry:FindFirstChildWhichIsA("GuiButton", true) ~= nil
                if isKnown then
                    local sc = RodSys.score(rName, entry)
                    if not bestTarget or sc > bestScore then
                        bestTarget = entry
                        bestScore = sc
                    end
                end
            end
        end
    end

    if not bestTarget then
        return nil, nil, -999999
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

function RodSys.canAutoEquip()
    if not State.EnabledAutoEquip or State.Coffee.IsDrinking or State.Coffee.HoldingTool or State.Maze.IsRunning or State.Primordial.IsTeleporting or State.InAfkServer then
        return false
    end
    if State.EnabledPauseNoWater and State.IsFarmPausedNoWater then
        return false
    end
    return true
end

function RodSys.equip()
    if not RodSys.canAutoEquip() then
        return
    end
    local char = LocalPlayer.Character
    if not char or RodSys.findEquipped(char) then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return
    end

    local bpTool = RodSys.findBestBackpack(LocalPlayer:FindFirstChild("Backpack"))
    if bpTool then
        pcall(function()
            hum:EquipTool(bpTool)
        end)
        State.WaitingForBite = false
        Cache.GearSummary = nil
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
            if RodSys.canAutoEquip() and LocalPlayer.Character == char and not RodSys.findEquipped(char) then
                local newTool = RodSys.findBestBackpack(LocalPlayer:FindFirstChild("Backpack"))
                if newTool and hum and hum.Health > 0 then
                    pcall(function()
                        hum:EquipTool(newTool)
                    end)
                    State.WaitingForBite = false
                    Cache.GearSummary = nil
                end
            end
        end)
    end
end

function RodSys.recheckBestRod()
    if not RodSys.canAutoEquip() then
        return
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then
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
            pcall(function()
                hum:EquipTool(bpBest)
            end)
            State.WaitingForBite = false
            Cache.GearSummary = nil
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

-- ==================== BINDERS & REMOTE RESOLUTION ====================
function Binder.onAfkServerChanged()
    local inAfk = (LocalPlayer:GetAttribute("InAfkServer") == true)
    local prev = State.InAfkServer
    State.InAfkServer = inAfk
    Util.updateStatusTag()
    if inAfk and not prev then
        State.WaitingForBite = false
        State.BiteActive = false
        sendAntiAFKPulse()
        if UI.Window then
            task.defer(function()
                pcall(function()
                    UI.Window:Notify({ title = "AFK Server Detected", content = "Game moved you into an AFK Server — Anti-AFK pulse active.", duration = 4 })
                end)
            end)
        end
        Webhook.alert("Moved to AFK Server", "Game moved player into an AFK Server (InAfkServer = true). Keeping Anti-AFK pulse active.", CONST.RARITY_COLORS.Afk, true)
    elseif not inAfk and prev then
        if UI.Window then
            task.defer(function()
                pcall(function()
                    UI.Window:Notify({ title = "Returned from AFK Server", content = "Back in main server — resuming normal checks.", duration = 3 })
                end)
            end)
        end
        Webhook.alert("Returned to Main Server", "Left AFK Server (InAfkServer = false).", CONST.RARITY_COLORS.Resume, true)
        task.delay(1, function()
            Water.refresh(false, true)
        end)
    end
end

function Binder.bindServerRemote(remote)
    if Conns.Server then
        Conns.Server:Disconnect()
        Conns.Server = nil
    end
    Remotes.Server = remote
    if remote then
        Conns.Server = remote.OnClientEvent:Connect(Reel.onServerEvent)
    end
end

function Binder.bindFishingFrame(frame)
    if Conns.FishingVis then
        Conns.FishingVis:Disconnect()
        Conns.FishingVis = nil
    end
    Cache.FishingFrame = frame
    if not frame then
        return
    end
    if frame.Visible then
        State.FishingOpenedAt = os.clock()
        State.SawProgressBelowTarget = false
    end
    Conns.FishingVis = frame:GetPropertyChangedSignal("Visible"):Connect(function()
        if frame.Visible then
            State.FishingOpenedAt = os.clock()
            State.SawProgressBelowTarget = false
        else
            State.SawProgressBelowTarget = false
        end
    end)
end

function Binder.bindInfoLabel(lbl)
    if Conns.InfoText then
        Conns.InfoText:Disconnect()
        Conns.InfoText = nil
    end
    Cache.InfoLabel = lbl
    if lbl then
        Conns.InfoText = lbl:GetPropertyChangedSignal("Text"):Connect(function()
            if Reel.shouldAuto() then
                Reel.fire()
            end
        end)
    end
end

function Binder.bindBarFill(bar)
    if Conns.BarFill then
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
    local fill = bar:FindFirstChild("Fill")
    Cache.BarFill = fill
    if fill then
        Conns.BarFill = fill:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            if not State.EnabledColorReel or not Remotes.Reel then
                return
            end
            if not Reel.isSafeNow() then
                return
            end
            if Conns.Server and not State.BiteActive then
                return
            end
            if Cache.FishingFrame and not Cache.FishingFrame.Visible then
                return
            end
            if not State.BiteActive and Cache.TapText and Cache.TapText.Text == "CAST" then
                return
            end
            local col = fill.BackgroundColor3
            local isGreen = (col.G > 0.7 and col.G > col.R and col.G > col.B) or
                            (math.abs(col.R * 255 - 100) < 30 and (col.G * 255) > 220 and math.abs(col.B * 255 - 100) < 30)
            if isGreen then
                Reel.fire()
            end
        end)
        Conns.BarSize = fill:GetPropertyChangedSignal("Size"):Connect(function()
            if Reel.shouldAuto() then
                Reel.fire()
            end
        end)
    end
end

function Binder.clearUICache()
    Cache.FishingFrame = nil
    Cache.InfoLabel = nil
    Cache.TapBtn = nil
    Cache.TapText = nil
    Cache.BarFill = nil
    Cache.AutoBtn = nil
    for _, k in ipairs({ "Gradient", "BarFill", "BarSize", "InfoText", "FishingVis", "GuiDesc" }) do
        if Conns[k] then
            Conns[k]:Disconnect()
            Conns[k] = nil
        end
    end
end

function Binder.cacheUI()
    if not PlayerGui then
        return
    end
    local loadingGui = PlayerGui:FindFirstChild("LemonadeLoadingScreen")
    if loadingGui then
        Perf.handleLoadingScreen(loadingGui)
    end

    local lvlGui = PlayerGui:FindFirstChild("LevelUpUI")
    if lvlGui then
        Reel.bindLevelUp(lvlGui)
    end

    clearConnList(Conns.PrimNotif)
    for _, key in ipairs(CONST.PRIMORDIAL_ORDER) do
        local nGui = PlayerGui:FindFirstChild(CONST.PRIMORDIAL_SPOTS[key].NotifUI)
        if nGui then
            Primordial.bindNotifUI(nGui)
        end
    end

    if State.Perf.DisableCutscenes then
        for name, _ in pairs(CONST.BLOCKED_FX_GUIS) do
            local fxGui = PlayerGui:FindFirstChild(name)
            if fxGui then
                Perf.hideOverlayGui(fxGui)
            end
        end
    end

    local gui = PlayerGui:FindFirstChild("FishingGui")
    if gui then
        Binder.bindFishingFrame(gui:FindFirstChild("Fishing", true))
        Cache.TapBtn = gui:FindFirstChild("TapMobile") or gui:FindFirstChild("TapMobile", true)
        Cache.TapText = Cache.TapBtn and Cache.TapBtn:FindFirstChild("TAP")
        Cache.AutoBtn = gui:FindFirstChild("AutoFishingButton", true)

        if Cache.FishingFrame then
            Binder.bindInfoLabel(Cache.FishingFrame:FindFirstChild("Info", true))
            Binder.bindBarFill(Cache.FishingFrame:FindFirstChild("Bar", true))
        end
        if Cache.AutoBtn then
            GameAuto.bindGradient(Cache.AutoBtn)
        end

        if Conns.GuiDesc then
            Conns.GuiDesc:Disconnect()
        end
        Conns.GuiDesc = gui.DescendantAdded:Connect(function(desc)
            if desc.Name == "AutoFishingButton" then
                Cache.AutoBtn = desc
                GameAuto.bindGradient(desc)
                if State.EnabledGameAutoCast then
                    GameAuto.set(true)
                elseif GameAuto.isOn() then
                    GameAuto.set(false)
                end
            elseif desc.Name == "Bar" and desc.Parent and desc.Parent.Name == "Fishing" then
                Binder.bindFishingFrame(desc.Parent)
                Binder.bindBarFill(desc)
            elseif desc.Name == "Info" and desc.Parent and desc.Parent.Name == "Fishing" then
                Binder.bindFishingFrame(desc.Parent)
                Binder.bindInfoLabel(desc)
            elseif desc.Name == "TapMobile" then
                Cache.TapBtn = desc
                Cache.TapText = desc:FindFirstChild("TAP")
            elseif desc.Name == "TAP" and desc.Parent and desc.Parent.Name == "TapMobile" then
                Cache.TapText = desc
            end
        end)
    else
        Binder.clearUICache()
    end
end

function Binder.isRemoteValid(r)
    return r ~= nil and r.Parent ~= nil
end

function Binder.resolveAllConfigs()
    for _, name in ipairs(CONST.CONFIG_LIST) do
        Cfg.get(name)
    end
    Cfg.rodSkin()
    Cfg.syncCoffeeCache()
    Cfg.sharedMod("CelestraState")
    Cfg.sharedMod("ThalvyraState")
    Cfg.sharedMod("SoreKrakenState")
end

function Binder.resolveRemotes()
    local map = {
        FishRemotes = {
            { "Cast", "Cast" },
            { "Reel", "Reel" },
            { "Cancel", "Cancel" },
            { "SellAll", "SellAll" },
            { "SetAuto", "SetAuto" },
            { "GetState", "GetState" },
            { "GetFish", "GetFish" },
        },
        CoffeeRemotes = {
            { "CoffeeBrew", "Brew" },
            { "CoffeeHold", "Hold" },
            { "CoffeeMeet", "Meet" },
        },
        QuestRemotes = {
            { "QuestGetState", "GetState" },
            { "QuestClaim", "Claim" },
            { "QuestWeeklyGet", "WeeklyGet" },
            { "QuestWeeklyClaim", "WeeklyClaim" },
            { "QuestWeeklyBonus", "WeeklyBonus" },
        },
        DailyLoginRemotes = {
            { "DailyLoginGetState", "GetState" },
            { "DailyLoginClaim", "Claim" },
        },
        SoreKrakenRemotes = {
            { "SoreKrakenQuest", "Quest" },
        },
        EventRemotes = {
            { "EventGet", "Get" },
            { "EventClaim", "Claim" },
        },
    }

    for folderName, pairsList in pairs(map) do
        local folder = Svc.ReplicatedStorage:FindFirstChild(folderName)
        if folder then
            for _, entry in ipairs(pairsList) do
                if not Binder.isRemoteValid(Remotes[entry[1]]) then
                    Remotes[entry[1]] = folder:FindFirstChild(entry[2])
                end
            end
        end
    end

    local fr = Svc.ReplicatedStorage:FindFirstChild("FishRemotes")
    if fr then
        if not Binder.isRemoteValid(Remotes.Server) then
            local srv = fr:FindFirstChild("Server")
            if srv then
                Binder.bindServerRemote(srv)
            end
        end
        if not Binder.isRemoteValid(Remotes.Fx) then
            local fx = fr:FindFirstChild("Fx")
            if fx then
                Remotes.Fx = fx
                if State.Perf.DisableCutscenes then
                    task.delay(0.3, function()
                        Perf.suppressFxConnections(fx)
                    end)
                end
            end
        end
    end

    return Binder.isRemoteValid(Remotes.Cast)
end

function Binder.allRemotesReady()
    for _, key in ipairs({
        "Reel",
        "Cancel",
        "SellAll",
        "SetAuto",
        "Server",
        "Fx",
        "GetState",
        "GetFish",
        "CoffeeBrew",
        "CoffeeHold",
        "QuestGetState",
        "QuestWeeklyGet",
        "DailyLoginGetState",
        "SoreKrakenQuest",
        "EventGet",
        "EventClaim",
    }) do
        if not Binder.isRemoteValid(Remotes[key]) then
            return false
        end
    end
    return true
end

function Binder.bindCharacter(char)
    if not char then
        return
    end
    clearConnList(Conns.Char)
    State.WaitingForBite = false
    State.BiteActive = false
    State.BiteHasReeled = false
    State.Coffee.IsDrinking = false
    State.Coffee.HoldingTool = false
    Cache.GearSummary = nil

    task.wait(1)
    if LocalPlayer.Character ~= char then
        return
    end

    Coffee.cacheFellicia()
    Maze.cacheHoneymoon()
    Coffee.syncHeldFlag()
    Water.refresh(false, true)
    if RodSys.canAutoEquip() then
        RodSys.equip()
    end
    if State.Primordial.Enabled then
        task.defer(Primordial.evaluate)
    end
    if State.Coffee.Enabled then
        task.defer(Coffee.evaluate)
    end
    if State.EnabledGameAutoCast then
        GameAuto.set(true)
    end

    table.insert(Conns.Char, char.ChildAdded:Connect(function(c)
        if Coffee.isCoffeeTool(c) then
            State.Coffee.HoldingTool = true
        elseif RodSys.isRod(c) then
            Cache.GearSummary = nil
        end
    end))

    table.insert(Conns.Char, char.ChildRemoved:Connect(function(c)
        if Coffee.isCoffeeTool(c) then
            Coffee.syncHeldFlag()
            if RodSys.canAutoEquip() then
                task.delay(0.15, RodSys.equip)
            end
        elseif RodSys.isRod(c) then
            Cache.GearSummary = nil
            if RodSys.canAutoEquip() then
                task.delay(0.2, RodSys.equip)
            end
        end
    end))

    local bp = LocalPlayer:FindFirstChild("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
    if bp and LocalPlayer.Character == char then
        table.insert(Conns.Char, bp.ChildAdded:Connect(function(c)
            if RodSys.isRod(c) then
                Cache.GearSummary = nil
                if RodSys.canAutoEquip() then
                    task.delay(0.2, RodSys.equip)
                end
            end
        end))
    end
end

-- ==================== ENGINE (CLICKER & HEARTBEAT LOOP) ====================
function Engine.doClick()
    if State.ClickMethod == "Input Signals" then
        local mouse = LocalPlayer:GetMouse()
        if mouse then
            Util.fireSignals(mouse.Button1Down)
            Util.fireSignals(mouse.Button1Up)
        end
        local getConnsFn = Util.getExecutorFunc("getconnections")
        if getConnsFn then
            local bIn = Util.mockInput(Enum.UserInputState.Begin, 0, 0)
            local eIn = Util.mockInput(Enum.UserInputState.End, 0, 0)
            for _, pair in ipairs({ { Svc.UIS.InputBegan, bIn }, { Svc.UIS.InputEnded, eIn } }) do
                local okC, conns = pcall(function()
                    return getConnsFn(pair[1])
                end)
                if okC and type(conns) == "table" then
                    for _, conn in ipairs(conns) do
                        if conn.Function then
                            local okI, src = pcall(function()
                                return debug.info(conn.Function, "s")
                            end)
                            if okI and type(src) == "string" and (string.find(src, "Players%.") or string.find(src, "Replicated") or string.find(src, "Starter")) then
                                pcall(function()
                                    conn:Fire(pair[2], false)
                                end)
                            end
                        end
                    end
                end
            end
        end
    else
        if not Cache.TapBtn and PlayerGui then
            local gui = PlayerGui:FindFirstChild("FishingGui")
            if gui then
                Cache.TapBtn = gui:FindFirstChild("TapMobile") or gui:FindFirstChild("TapMobile", true)
                Cache.TapText = Cache.TapBtn and Cache.TapBtn:FindFirstChild("TAP")
            end
        end
        if Cache.TapBtn then
            Util.triggerBtn(Cache.TapBtn)
        end
    end
end

function Engine.slowTick(now)
    if (now - State.LastRemoteResolveTime) >= 2 then
        if not Binder.isRemoteValid(Remotes.Cast) or not Binder.allRemotesReady() then
            State.LastRemoteResolveTime = now
            Binder.resolveRemotes()
        elseif State.Perf.DisableCutscenes then
            Perf.suppressFxConnections(Remotes.Fx)
        end
    end

    if (LocalPlayer:GetAttribute("InAfkServer") == true) ~= State.InAfkServer then
        Binder.onAfkServerChanged()
    end

    if (now - State.LastBaitRefreshAt) >= 60 then
        State.LastBaitRefreshAt = now
        Monitor.refreshState()
        Coffee.cacheFellicia()
        Maze.cacheHoneymoon()
        if State.Perf.LowestGraphics then
            Perf.applyLowestGraphics()
        end
    end

    if State.WaitingForBite and (now - State.WaitingSince) >= 8 then
        State.WaitingForBite = false
    end
    if State.BiteActive and (now - State.BiteAt) >= 26 then
        State.BiteActive = false
        State.BiteHasReeled = false
    end
    if State.Coffee.IsDrinking and (now - State.Coffee.DrinkStartedAt) >= 18 then
        State.Coffee.IsDrinking = false
        Coffee.syncHeldFlag()
    end
    if State.Primordial.IsTeleporting and (now - State.Primordial.TeleportStartedAt) >= 20 then
        State.Primordial.IsTeleporting = false
    end
    if State.Maze.IsRunning and (now - State.Maze.StartedAt) >= 160 then
        State.Maze.IsRunning = false
    end

    if State.EnabledCast and not State.IsFarmPausedNoWater and not State.InAfkServer and not State.Maze.IsRunning and (now - State.LastServerActivityAt) >= 45 then
        State.LastServerActivityAt = now
        State.WaitingForBite = false
        State.BiteActive = false
        State.BiteHasReeled = false
        if RodSys.canAutoEquip() then
            RodSys.equip()
        end
    end

    if State.Primordial.Enabled and (now - State.Primordial.LastCheckAt) >= 2 then
        State.Primordial.LastCheckAt = now
        Primordial.evaluate()
    end

    if State.Coffee.Enabled and not State.BiteActive then
        Coffee.evaluate()
    end

    if State.Quests.Mode ~= "Disabled" and (now - State.Quests.LastQuestCheckAt) >= 15 then
        State.Quests.LastQuestCheckAt = now
        Quests.evaluateAll(false)
    end

    if State.Maze.AutoDaily
        and not State.InAfkServer
        and not State.Primordial.IsTeleporting
        and not State.Primordial.CurrentEvent
        and not State.Coffee.IsDrinking
        and not State.Maze.IsRunning
        and not State.BiteActive
        and (now - State.Maze.LastAutoCheckAt) >= 30
        and now >= State.Maze.CooldownUntil then
        State.Maze.LastAutoCheckAt = now
        local curLvl = tonumber(LocalPlayer:GetAttribute("Level")) or 0
        if curLvl >= 70
            and LocalPlayer:GetAttribute("HoneymoonDailyDone") ~= true
            and LocalPlayer:GetAttribute("HoneymoonDailyFailed") ~= true then
            task.spawn(Maze.solve, "Daily", false)
        end
    end

    if (State.EnabledPauseNoWater or State.EnabledSmartWaterAim)
        and not State.BiteActive
        and not State.Primordial.IsTeleporting
        and not State.Coffee.IsDrinking
        and not State.Maze.IsRunning
        and not State.InAfkServer
        and (now - State.LastWaterCheckAt) >= 1.5 then
        State.LastWaterCheckAt = now
        Water.refresh(true, false)
    end

    if (now - State.LastRodCheckAt) >= 3 then
        State.LastRodCheckAt = now
        if State.EnabledPauseNoWater and State.IsFarmPausedNoWater and not State.BiteActive and not State.WaitingForBite then
            RodSys.unequip()
        elseif RodSys.canAutoEquip() and LocalPlayer.Character and not RodSys.findEquipped(LocalPlayer.Character) then
            RodSys.equip()
        end
    end

    local sellRem = Remotes.SellAll
    if State.EnabledSell and not State.IsSelling and not State.BiteActive and Binder.isRemoteValid(sellRem) then
        local bagCnt, bagLim = Monitor.getBagCounts()
        if bagCnt ~= nil and bagCnt == 0 then
            State.LastSellTime = now
        elseif bagCnt ~= nil and bagLim > 0 and bagCnt >= (bagLim - 2) and now >= State.ProactiveSellCooldownUntil then
            Reel.invokeSellAll(true)
        elseif (now - State.LastSellTime) >= State.SellInterval then
            if bagCnt == nil or bagCnt > 0 then
                Reel.invokeSellAll(false)
            else
                State.LastSellTime = now
            end
        end
    end

    if State.EnabledGameAutoCast and not State.IsFarmPausedNoWater and not State.Primordial.IsTeleporting and not State.Maze.IsRunning and not State.InAfkServer and (now - State.LastAutoCheckTime) >= 4 then
        State.LastAutoCheckTime = now
        if Cache.AutoBtn and not GameAuto.isOn() then
            GameAuto.set(true)
        end
    end

    if State.Webhook.Enabled and State.Webhook.PeriodicReport then
        if (now - State.Webhook.LastReportAt) >= (State.Webhook.IntervalMinutes * 60) then
            State.Webhook.LastReportAt = now
            Webhook.enqueue(Webhook.buildReport())
        end
    end
end

function Engine.getCastTargetVector()
    if State.EnabledSmartWaterAim then
        if State.CachedWaterDir then
            return State.CachedWaterDir
        end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local lv = hrp.CFrame.LookVector
            local flat = Vector3.new(lv.X, 0, lv.Z)
            if flat.Magnitude > 0.05 then
                return flat.Unit
            end
        end
    end
    return State.CastPos
end

function Engine.mainLoop()
    local now = os.clock()
    local castRem = Remotes.Cast

    if State.EnabledCast
        and Binder.isRemoteValid(castRem)
        and not State.Primordial.IsTeleporting
        and not State.Coffee.IsDrinking
        and not State.Maze.IsRunning
        and not State.InAfkServer then
        if not State.IsFarmPausedNoWater and not State.Coffee.HoldingTool and now >= State.CastBusyUntil then
            local targetVec = Engine.getCastTargetVector()
            if State.CastMode == "Heartbeat Cast" then
                pcall(function()
                    castRem:FireServer(targetVec, State.CastPower)
                end)
            elseif not State.BiteActive and not State.WaitingForBite and (now - State.LastCastSentAt) >= 0.06 then
                State.LastCastSentAt = now
                pcall(function()
                    castRem:FireServer(targetVec, State.CastPower)
                end)
            end
        end
    end

    if State.EnabledClick and not State.Maze.IsRunning then
        local canClick = Conns.Server and (State.BiteActive and not State.BiteHasReeled) or (Cache.FishingFrame and Cache.FishingFrame.Visible)
        if canClick and (now - State.LastClickTime) >= State.ClickDelay then
            State.LastClickTime = now
            Engine.doClick()
        end
    end

    if State.EnabledFastSafeReel and State.BiteActive and Binder.isRemoteValid(Remotes.Reel) then
        if now >= State.SafeReelAt and (not State.BiteHasReeled or (now - State.LastReelAttemptAt) >= 1.5) then
            Reel.fire()
        end
    end

    if Reel.shouldAuto() then
        Reel.fire()
    end

    if (now - State.LastSlowTickAt) >= 0.5 then
        State.LastSlowTickAt = now
        Engine.slowTick(now)
    end
end

function Engine.updateLoop()
    local shouldRun = (State.EnabledCast or State.EnabledClick or State.EnabledReel or State.EnabledFastSafeReel
        or State.EnabledSell or State.EnabledGameAutoCast or State.EnabledAutoEquip or State.Primordial.Enabled
        or State.Coffee.Enabled or (State.Quests.Mode ~= "Disabled") or State.Maze.AutoDaily
        or (State.Webhook.Enabled and State.Webhook.PeriodicReport))
    if shouldRun then
        if not Conns.Heartbeat then
            State.LastClickTime = 0
            State.LastSellTime = 0
            State.LastAutoCheckTime = 0
            State.LastSlowTickAt = 0
            Conns.Heartbeat = Svc.RunService.Heartbeat:Connect(Engine.mainLoop)
        end
    elseif Conns.Heartbeat then
        Conns.Heartbeat:Disconnect()
        Conns.Heartbeat = nil
    end
end

-- ==================== APPLY STARTUP GRAPHICS, MUSIC & LOADING SCREEN ====================
State.LastBaitRefreshAt = 0
Perf.setMusicGenre(State.Perf.MusicGenre, false)
if State.Perf.LowestGraphics then
    Perf.applyLowestGraphics()
end
if State.Perf.DisableCutscenes then
    Perf.applyCutsceneBlocker(true)
end

-- ==================== RAYFIELD GEN2 LOADER (WITH CAPABILITY FALLBACK) ====================
local okRf, Rayfield = false, nil
do
    local _, forcePlayerGui = Util.getSafeUiContainer(true)
    local function loadRayfieldWithMode(usePlayerGuiProxy)
        local rfSrc = game:HttpGet("https://sirius.menu/gen2")
        local chunk, loadErr = loadstring(rfSrc)
        if type(chunk) ~= "function" then
            error(tostring(loadErr))
        end
        if usePlayerGuiProxy and type(setfenv) == "function" and type(getfenv) == "function" then
            local baseEnv = getfenv(chunk)
            local safeEnv = setmetatable({
                gethui = function()
                    return PlayerGui
                end,
                getgenv = function()
                    return setmetatable({
                        gethui = function()
                            return PlayerGui
                        end,
                    }, { __index = envGlobal })
                end,
            }, { __index = baseEnv })
            pcall(setfenv, chunk, safeEnv)
        end
        return chunk()
    end

    for _ = 1, 3 do
        local okTry, resTry = pcall(function()
            return loadRayfieldWithMode(forcePlayerGui)
        end)
        if okTry and resTry then
            local okWin, winObj = pcall(function()
                return resTry:CreateWindow({
                    name = "Saujana Hub",
                    subtitle = "v" .. SCRIPT_VERSION,
                    sidebarLayout = true,
                    theme = "cobalt",
                    configuration = { autoSave = true, autoLoad = false, fileName = "SaujanaFishGen2" },
                })
            end)
            if okWin and winObj then
                okRf = true
                Rayfield = resTry
                UI.Window = winObj
                break
            elseif not forcePlayerGui then
                forcePlayerGui = true
            end
        end
        task.wait(2)
    end
end

if not okRf or not Rayfield or not UI.Window then
    AntiAFKState.Active = false
    return
end

if type(UI.Window.CreateTag) == "function" then
    local okTag, tagHandle = pcall(function()
        return UI.Window:CreateTag({ text = "ACTIVE", color = Color3.fromRGB(34, 197, 94) })
    end)
    if okTag and tagHandle then
        UI.StatusTag = tagHandle
    end
end

-- ==================== TAB 1: FARMING ====================
do
    local FarmTab = UI.Window:CreateTab({ name = "Farming" })

    FarmTab:CreateSection({ name = "Core Automation" })
    UI.AutoCastToggle = FarmTab:CreateToggle({
        name = "Auto Cast",
        description = "Casts automatically between catches",
        flag = "AutoCast",
        value = true,
        callback = function(v)
            State.EnabledCast = v
            Util.updateStatusTag()
            Engine.updateLoop()
        end,
    })
    UI.FastSafeReelToggle = FarmTab:CreateToggle({
        name = "Fast Safe Reel",
        description = "Reels at earliest safe server time (zero-fail start + auto-trim)",
        flag = "FastSafeReel",
        value = true,
        callback = function(v)
            State.EnabledFastSafeReel = v
            Engine.updateLoop()
        end,
    })
    FarmTab:CreateToggle({
        name = "Auto Equip Rod",
        description = "Equips your best rod (yields during Coffee & Away-From-Water)",
        flag = "AutoEquipRod",
        value = true,
        callback = function(v)
            State.EnabledAutoEquip = v
            if v then
                RodSys.equip()
            end
        end,
    })
    FarmTab:CreateToggle({
        name = "Pause Away From Water",
        description = "Unequips rod & pauses casting when you walk away from water",
        flag = "PauseAwayFromWater",
        value = true,
        callback = function(v)
            State.EnabledPauseNoWater = v
            Water.refresh(false, true)
        end,
    })
    FarmTab:CreateToggle({
        name = "Auto Close LevelUp UI",
        description = "Dismisses the LevelUpUI popup automatically",
        flag = "AutoCloseLevelUp",
        value = true,
        callback = function(v)
            State.EnabledAutoCloseLevelUp = v
            if v and PlayerGui then
                local lg = PlayerGui:FindFirstChild("LevelUpUI")
                if lg then
                    Reel.closeLevelUp(lg)
                end
            end
        end,
    })
    FarmTab:CreateToggle({
        name = "Auto Sell",
        description = "Smart sell: skips 0/max, sells early at Limit-2 & on interval",
        flag = "AutoSell",
        value = false,
        callback = function(v)
            State.EnabledSell = v
            if v then
                State.LastSellTime = 0
                State.ProactiveSellCooldownUntil = 0
            end
            Engine.updateLoop()
        end,
    })

    if type(FarmTab.CreateDivider) == "function" then
        pcall(function()
            FarmTab:CreateDivider()
        end)
    end

    FarmTab:CreateSection({ name = "Events & Boosts" })
    UI.PrimordialToggle = FarmTab:CreateToggle({
        name = "Auto TP Primordial Events",
        description = "Stealth-teleports to active Primordial spots (waits for bite)",
        flag = "AutoTpPrimordial",
        value = true,
        callback = function(v)
            State.Primordial.Enabled = v
            Engine.updateLoop()
            if v then
                task.defer(Primordial.evaluate)
            elseif State.Primordial.CurrentEvent and State.Primordial.ReturnHome and State.Primordial.HomeCFrame then
                Primordial.teleportTo(State.Primordial.HomeCFrame, nil)
            end
        end,
    })
    UI.AutoCoffeeToggle = FarmTab:CreateToggle({
        name = "Auto Coffee Boost",
        description = "Drinks Coffee or crafts only when fish/tickets are verified",
        flag = "AutoCoffeeBoost",
        value = true,
        callback = function(v)
            State.Coffee.Enabled = v
            Engine.updateLoop()
            if v then
                task.defer(Coffee.evaluate)
            end
        end,
    })
    UI.GameAutoCastToggle = FarmTab:CreateToggle({
        name = "Game Auto Cast",
        description = "Built-in auto cast (keep OFF for faster 0.06s/tap speed)",
        flag = "GameAutoCast",
        value = false,
        callback = function(v)
            State.EnabledGameAutoCast = v
            Engine.updateLoop()
            GameAuto.set(v)
        end,
    })

    if type(FarmTab.CreateDivider) == "function" then
        pcall(function()
            FarmTab:CreateDivider()
        end)
    end

    FarmTab:CreateSection({ name = "Fallback Reeling" })
    FarmTab:CreateToggle({
        name = "Auto Clicker",
        description = "Clicks automatically during active bites",
        flag = "AutoClicker",
        value = false,
        callback = function(v)
            State.EnabledClick = v
            Engine.updateLoop()
        end,
    })
    FarmTab:CreateToggle({
        name = "Auto Reel",
        description = "Reels when progress hits the Reel At target",
        flag = "AutoReel",
        value = false,
        callback = function(v)
            State.EnabledReel = v
            Engine.updateLoop()
        end,
    })
    UI.ColorReelToggle = FarmTab:CreateToggle({
        name = "Color Reel",
        description = "Reels when bar turns green (starts OFF)",
        flag = "ColorReel",
        value = false,
        callback = function(v)
            State.EnabledColorReel = v
        end,
    })
end

-- ==================== TAB 2: WEBHOOK ====================
do
    local WebTab = UI.Window:CreateTab({ name = "Webhook" })
    WebTab:CreateSection({ name = "Discord Connection" })
    WebTab:CreateInput({
        name = "Discord Webhook URL",
        value = State.Webhook.Url,
        placeholder = "https://discord.com/api/webhooks/...",
        flag = "DiscordWebhookUrl",
        callback = function(txt)
            State.Webhook.Url = Util.trim(txt)
        end,
    })
    WebTab:CreateToggle({
        name = "Enable Discord Webhook",
        description = "Auto-enables when getgenv().AutoFishWebhook is set",
        flag = "EnableDiscordWebhook",
        value = State.Webhook.Enabled,
        callback = function(v)
            State.Webhook.Enabled = v
            if v then
                State.Webhook.LastReportAt = os.clock()
            end
            Engine.updateLoop()
        end,
    })
    WebTab:CreateButton({
        name = "Send Report / Test Now",
        callback = function()
            if not Util.isValidWebhookUrl(State.Webhook.Url) then
                UI.Window:Notify({ title = "Invalid Webhook URL", content = "Paste a valid Discord webhook URL first.", duration = 3 })
                return
            end
            task.spawn(function()
                local embed = Webhook.buildReport("Live Farm Report (v" .. SCRIPT_VERSION .. ")", CONST.RARITY_COLORS.Report)
                embed.timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                embed.footer = { text = string.format("Saujana Hub v%s • %s", SCRIPT_VERSION, LocalPlayer.Name) }
                local okS, info = Webhook.sendNow({ embeds = { embed } })
                UI.Window:Notify({ title = okS and "Webhook Sent!" or "Webhook Failed", content = okS and "Check your Discord channel." or tostring(info), duration = 4 })
            end)
        end,
    })
    WebTab:CreateButton({
        name = "Reset Session Stats",
        callback = function()
            Monitor.reset()
            UI.Window:Notify({ title = "Stats Reset", content = "Session catch & XP counters cleared.", duration = 2 })
        end,
    })

    if type(WebTab.CreateDivider) == "function" then
        pcall(function()
            WebTab:CreateDivider()
        end)
    end

    WebTab:CreateSection({ name = "Notifications & Reports" })
    WebTab:CreateToggle({
        name = "Notify Rare Catches",
        description = "Mythic, Secret, Supremacy, and Primordial drops",
        flag = "WebhookRareCatches",
        value = true,
        callback = function(v)
            State.Webhook.NotifyRareCatches = v
        end,
    })
    WebTab:CreateToggle({
        name = "Notify Primordial Teleports",
        description = "Event join, switch, and return-home notifications",
        flag = "WebhookPrimordial",
        value = true,
        callback = function(v)
            State.Webhook.NotifyPrimordial = v
        end,
    })
    WebTab:CreateToggle({
        name = "Notify Quests, Event & Maze",
        description = "Claimed Playtime, Weekly, Sakura Event, Daily Login & Maze rewards",
        flag = "WebhookQuests",
        value = true,
        callback = function(v)
            State.Quests.NotifyWebhook = v
        end,
    })
    WebTab:CreateToggle({
        name = "Notify Connected & Disconnected",
        description = "Alerts on script load/reconnect and server kick",
        flag = "WebhookConnections",
        value = true,
        callback = function(v)
            State.Webhook.NotifyConnections = v
        end,
    })
    WebTab:CreateToggle({
        name = "Alert on Pause / Fails / AFK",
        description = "Alerts on water pause, 5+ Invalid fails, or AFK Server move",
        flag = "WebhookAlerts",
        value = true,
        callback = function(v)
            State.Webhook.AlertOnIssues = v
        end,
    })
    WebTab:CreateToggle({
        name = "Periodic Stats Summary",
        description = "Sends overnight rate & progress embeds on interval",
        flag = "WebhookPeriodicReport",
        value = true,
        callback = function(v)
            State.Webhook.PeriodicReport = v
            if v then
                State.Webhook.LastReportAt = os.clock()
            end
            Engine.updateLoop()
        end,
    })
    WebTab:CreateSlider({
        name = "Summary Interval",
        range = { 5, 60 },
        increment = 5,
        value = 15,
        suffix = "m",
        flag = "WebhookIntervalMinutes",
        callback = function(v)
            State.Webhook.IntervalMinutes = v
        end,
    })
end

-- ==================== TAB 3: TUNING ====================
do
    local TuneTab = UI.Window:CreateTab({ name = "Tuning" })

    TuneTab:CreateSection({ name = "Primordial Events" })
    TuneTab:CreateDropdown({
        name = "Overlap Priority",
        description = "Rarest First: Sore Kraken > Thalvyra > Celestra",
        options = { "Rarest First", "Newest First" },
        value = "Rarest First",
        flag = "PrimordialPriority",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            State.Primordial.PriorityMode = (sel == "Newest First") and "Newest First" or "Rarest First"
            if State.Primordial.Enabled then
                task.defer(Primordial.evaluate)
            end
        end,
    })
    TuneTab:CreateToggle({
        name = "Auto-Swap Matching Event Rod",
        description = "Equips Celestra/Thalvyra/Sore Kraken Rod (respects MinKg)",
        flag = "SwapEventRod",
        value = true,
        callback = function(v)
            State.Primordial.SwapEventRod = v
            RodSys.recheckBestRod()
        end,
    })
    UI.ReturnHomeToggle = TuneTab:CreateToggle({
        name = "Return Home After Event",
        description = "Always starts OFF on load so you keep fishing at the event spot",
        flag = "ReturnHomeAfterEvent",
        value = false,
        callback = function(v)
            State.Primordial.ReturnHome = v
        end,
    })
    TuneTab:CreateToggle({
        name = "Check Unlock Attributes",
        description = "Optional check for NpcTalkedRevano / CrimsonUnlocked / SoreKrakenUnlocked",
        flag = "PrimordialCheckUnlocks",
        value = false,
        callback = function(v)
            State.Primordial.CheckUnlocks = v
            if State.Primordial.Enabled then
                task.defer(Primordial.evaluate)
            end
        end,
    })

    if type(TuneTab.CreateDivider) == "function" then
        pcall(function()
            TuneTab:CreateDivider()
        end)
    end

    TuneTab:CreateSection({ name = "Quests, Sakura Event & AutoMaze" })
    TuneTab:CreateDropdown({
        name = "Quest Claim Mode",
        description = "Claims Playtime, Weekly, Sakura Event & Daily Login rewards",
        options = { "Auto-Claim & Notify", "Notify Only", "Disabled" },
        value = "Auto-Claim & Notify",
        flag = "QuestClaimMode",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            if sel == "Notify Only" or sel == "Disabled" then
                State.Quests.Mode = sel
            else
                State.Quests.Mode = "Auto-Claim & Notify"
            end
            Engine.updateLoop()
            if State.Quests.Mode ~= "Disabled" then
                Quests.evaluateAll(true)
            end
        end,
    })
    TuneTab:CreateToggle({
        name = "Auto Claim Sakura Event (Daily + Bonus)",
        description = "Auto-claims completed Sakura Blossom daily missions & bonus",
        flag = "AutoSakuraEvent",
        value = true,
        callback = function(v)
            State.Quests.AutoSakuraEvent = v
            if v and State.Quests.Mode ~= "Disabled" then
                task.spawn(Quests.checkSakuraEvent)
            end
        end,
    })
    TuneTab:CreateToggle({
        name = "Auto Claim Daily Login",
        description = "Checks DailyLoginRemotes.GetState once per UTC day",
        flag = "AutoDailyLogin",
        value = true,
        callback = function(v)
            State.Quests.AutoDailyLogin = v
            if v and State.Quests.Mode ~= "Disabled" then
                task.spawn(Quests.checkDailyLogin, true)
            end
        end,
    })
    TuneTab:CreateToggle({
        name = "Auto-Solve Daily Maze",
        description = "Solves Honeymoon's Daily Maze once per day (Lv.70+, skips active events)",
        flag = "AutoDailyMaze",
        value = false,
        callback = function(v)
            State.Maze.AutoDaily = v
            State.Maze.CooldownUntil = 0
            Engine.updateLoop()
        end,
    })
    TuneTab:CreateDropdown({
        name = "Maze Finish Timing",
        description = "Safe (+1.6s) beats game's own +1.4s timer (Daily = 1 try/day)",
        options = { "Safe (+1.6s)", "Ultra Safe (+2.2s)", "Fast (+0.9s)" },
        value = "Safe (+1.6s)",
        flag = "MazeTimingMode",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            if sel == "Ultra Safe (+2.2s)" or sel == "Fast (+0.9s)" then
                State.Maze.TimingMode = sel
            else
                State.Maze.TimingMode = "Safe (+1.6s)"
            end
        end,
    })
    TuneTab:CreateToggle({
        name = "Visit Honeymoon If Far",
        description = "Stealth-hops to Honeymoon Eternal if out of range, then returns",
        flag = "MazeVisitHoneymoon",
        value = true,
        callback = function(v)
            State.Maze.VisitHoneymoon = v
        end,
    })
    TuneTab:CreateButton({
        name = "Solve Daily Maze Now",
        callback = function()
            task.spawn(Maze.solve, "Daily", true)
        end,
    })
    TuneTab:CreateButton({
        name = "Solve 4 Quest Mazes (Sore Kraken)",
        callback = function()
            task.spawn(Maze.solve, "Quest", true)
        end,
    })

    if type(TuneTab.CreateDivider) == "function" then
        pcall(function()
            TuneTab:CreateDivider()
        end)
    end

    TuneTab:CreateSection({ name = "Coffee Boost" })
    TuneTab:CreateDropdown({
        name = "When to Drink Coffee",
        description = "Primordial Events Only saves boosts for Primordial windows",
        options = { "Primordial Events Only", "Always (24/7)" },
        value = "Primordial Events Only",
        flag = "CoffeeTriggerMode",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            State.Coffee.TriggerMode = (sel == "Always (24/7)") and "Always (24/7)" or "Primordial Events Only"
            if State.Coffee.Enabled then
                task.defer(Coffee.evaluate)
            end
        end,
    })
    TuneTab:CreateDropdown({
        name = "Coffee Preference",
        description = "Best Available prioritizes highest tier brew",
        options = { "Best Available", "SaujanaSignature", "LuckyShot", "FortuneBrew" },
        value = "Best Available",
        flag = "CoffeePreference",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            if sel == "SaujanaSignature" or sel == "LuckyShot" or sel == "FortuneBrew" then
                State.Coffee.Preference = sel
            else
                State.Coffee.Preference = "Best Available"
            end
        end,
    })
    TuneTab:CreateToggle({
        name = "Allow Fish Trade Brew",
        description = "Crafts only after verifying un-favorited Mythic/Secret/Supremacy counts",
        flag = "CoffeeAllowFishTrade",
        value = true,
        callback = function(v)
            State.Coffee.AllowFishTrade = v
        end,
    })
    TuneTab:CreateToggle({
        name = "Visit Fellicia If Far",
        description = "Stealth-hops to Fellicia when brew is verified craftable, then returns",
        flag = "CoffeeVisitFellicia",
        value = true,
        callback = function(v)
            State.Coffee.AutoVisitFellicia = v
        end,
    })

    if type(TuneTab.CreateDivider) == "function" then
        pcall(function()
            TuneTab:CreateDivider()
        end)
    end

    TuneTab:CreateSection({ name = "Casting & Reel Timing" })
    TuneTab:CreateDropdown({
        name = "Cast Mode",
        description = "Smart Cast pauses while waiting • Heartbeat Cast spams continuously",
        options = { "Smart Cast", "Heartbeat Cast" },
        value = "Smart Cast",
        flag = "CastMode",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            State.CastMode = (sel == "Heartbeat Cast") and "Heartbeat Cast" or "Smart Cast"
            State.WaitingForBite = false
        end,
    })
    TuneTab:CreateToggle({
        name = "Smart Water Aim",
        description = "Aims CastRemote toward detected water / LookVector",
        flag = "SmartWaterAim",
        value = true,
        callback = function(v)
            State.EnabledSmartWaterAim = v
            if v then
                Water.refresh(false, true)
            end
        end,
    })
    TuneTab:CreateDropdown({
        name = "Fast Reel Mode",
        description = "Fastest Zero-Fail starts at 100% taps + 0.03s for 0 startup fails",
        options = { "Fastest Zero-Fail (Auto)", "Safe (100%)", "Aggressive (60%)" },
        value = "Fastest Zero-Fail (Auto)",
        flag = "FastReelMode",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            if sel == "Safe (100%)" or sel == "Aggressive (60%)" then
                State.ReelTimingMode = sel
            else
                State.ReelTimingMode = "Fastest Zero-Fail (Auto)"
            end
            Reel.recalcSafeTime()
        end,
    })
    TuneTab:CreateToggle({
        name = "Auto-Tune Ping Buffer",
        description = "Bumps +0.03s on Invalid; trims -0.01s per 20 clean catches down to 0.02s",
        flag = "AutoTunePingBuffer",
        value = true,
        callback = function(v)
            State.AutoTunePingBuffer = v
        end,
    })
    UI.PingSlider = TuneTab:CreateSlider({
        name = "Reel Ping Buffer",
        range = { 0.02, 0.50 },
        increment = 0.01,
        value = 0.03,
        suffix = "s",
        flag = "ReelPingBuffer",
        callback = function(v)
            State.PingBuffer = v
            if not State.IsUpdatingPingSlider then
                State.AutoTuneFloorBuffer = math.max(0.02, v)
                State.LastBufferAdjustAt = os.clock()
                State.ConsecutiveCatches = 0
            end
            Reel.recalcSafeTime()
        end,
    })
    TuneTab:CreateDropdown({
        name = "Click Method",
        description = "Button Signals targets TapMobile • Input Signals uses input events",
        options = { "Button Signals", "Input Signals" },
        value = "Button Signals",
        flag = "ClickMethod",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            State.ClickMethod = (sel == "Input Signals") and "Input Signals" or "Button Signals"
        end,
    })
    TuneTab:CreateSlider({
        name = "Clicker Speed",
        range = { 0.03, 0.25 },
        increment = 0.01,
        value = 0.13,
        suffix = "s",
        flag = "ClickerSpeed",
        callback = function(v)
            State.ClickDelay = v
        end,
    })
    TuneTab:CreateSlider({
        name = "Reel At",
        range = { 1, 13 },
        increment = 1,
        value = 5,
        suffix = "/13",
        flag = "ReelAt",
        callback = function(v)
            State.ReelAt = v
        end,
    })
    TuneTab:CreateSlider({
        name = "Sell Interval",
        range = { 3, 30 },
        increment = 1,
        value = 20,
        suffix = "s",
        flag = "SellInterval",
        callback = function(v)
            State.SellInterval = v
        end,
    })

    if type(TuneTab.CreateDivider) == "function" then
        pcall(function()
            TuneTab:CreateDivider()
        end)
    end

    TuneTab:CreateSection({ name = "Startup & Performance" })
    TuneTab:CreateDropdown({
        name = "Startup Music Genre",
        description = "Auto-selected past loading screen (or getgenv().AutoFishMusicGenre)",
        options = CONST.MUSIC_GENRES,
        value = State.Perf.MusicGenre,
        flag = "StartupMusicGenre",
        callback = function(sel)
            if type(sel) == "table" then
                sel = sel[1]
            end
            Perf.setMusicGenre(sel, true)
        end,
    })
    TuneTab:CreateToggle({
        name = "Auto-Bypass Loading Screen",
        description = "Skips Language/Music/Graphics screens and restores game UI cleanly",
        flag = "AutoDismissLoading",
        value = true,
        callback = function(v)
            State.Perf.AutoDismissLoading = v
            if v and PlayerGui then
                local lg = PlayerGui:FindFirstChild("LemonadeLoadingScreen")
                if lg then
                    State.Perf.LoadingHandled = false
                    Perf.handleLoadingScreen(lg)
                end
            end
        end,
    })
    TuneTab:CreateToggle({
        name = "Lowest Graphics Mode",
        description = "Forces Low graphics, disables shadows, blur, effects & other pets",
        flag = "LowestGraphicsMode",
        value = true,
        callback = function(v)
            State.Perf.LowestGraphics = v
            Perf.applyLowestGraphics()
        end,
    })
    TuneTab:CreateToggle({
        name = "Disable Cutscenes & FX",
        description = "Blocks Mythic/Secret/Supremacy cutscenes, camera lock & vignettes",
        flag = "DisableCutscenesFX",
        value = true,
        callback = function(v)
            Perf.applyCutsceneBlocker(v)
        end,
    })
    TuneTab:CreateToggle({
        name = "Battery Saver (No 3D Render)",
        description = "Disables 3D world rendering to cut heat & battery overnight",
        flag = "BatterySaver",
        value = false,
        callback = function(v)
            State.LowPowerMode = v
            pcall(function()
                Svc.RunService:Set3dRenderingEnabled(not v)
            end)
        end,
    })
end

-- ==================== EVENT CONNECTIONS & STARTUP ====================
if PlayerGui then
    Binder.cacheUI()
    table.insert(Conns.Global, PlayerGui.ChildAdded:Connect(function(c)
        if c.Name == "LemonadeLoadingScreen" then
            State.Perf.LoadingHandled = false
            Perf.handleLoadingScreen(c)
        elseif c.Name == "FishingGui" then
            task.wait()
            Binder.cacheUI()
        elseif c.Name == "LevelUpUI" then
            task.defer(Reel.bindLevelUp, c)
        elseif c.Name == "CelestraNotifUI" or c.Name == "ThalvyraNotifUI" or c.Name == "SoreKrakenNotifUI" then
            task.defer(Primordial.bindNotifUI, c)
        elseif CONST.BLOCKED_FX_GUIS[c.Name] and State.Perf.DisableCutscenes then
            task.defer(Perf.hideOverlayGui, c)
        elseif c.Name == "Backpack" then
            Cache.RodContent = nil
            Cache.ItemsFrame = nil
        end
    end))
    table.insert(Conns.Global, PlayerGui.ChildRemoved:Connect(function(c)
        if c.Name == "LemonadeLoadingScreen" then
            task.delay(0.3, function()
                Perf.setMusicGenre(State.Perf.MusicGenre, false)
                if State.Perf.LowestGraphics then
                    Perf.applyLowestGraphics()
                end
            end)
        elseif c.Name == "FishingGui" then
            Binder.clearUICache()
        elseif c.Name == "LevelUpUI" then
            clearConnList(Conns.LevelUp)
        elseif c.Name == "Backpack" then
            Cache.RodContent = nil
            Cache.ItemsFrame = nil
        end
    end))
end

Conns.QuestPlaytime = LocalPlayer:GetAttributeChangedSignal("QuestClaimable"):Connect(function()
    if State.Quests.Mode ~= "Disabled" and (tonumber(LocalPlayer:GetAttribute("QuestClaimable")) or 0) > 0 then
        task.spawn(Quests.checkPlaytime)
    end
end)

Conns.QuestWeekly = LocalPlayer:GetAttributeChangedSignal("QuestWeeklyClaimable"):Connect(function()
    if State.Quests.Mode ~= "Disabled" and (tonumber(LocalPlayer:GetAttribute("QuestWeeklyClaimable")) or 0) > 0 then
        task.spawn(Quests.checkWeekly)
    end
end)

Conns.EventClaimable = LocalPlayer:GetAttributeChangedSignal("EventClaimable"):Connect(function()
    if State.Quests.AutoSakuraEvent and State.Quests.Mode ~= "Disabled" and (tonumber(LocalPlayer:GetAttribute("EventClaimable")) or 0) > 0 then
        task.spawn(Quests.checkSakuraEvent)
    end
end)

Conns.InAfkServer = LocalPlayer:GetAttributeChangedSignal("InAfkServer"):Connect(Binder.onAfkServerChanged)
Binder.onAfkServerChanged()

table.insert(Conns.Global, Svc.Gui.ErrorMessageChanged:Connect(function(errMsg)
    if errMsg and errMsg ~= "" then
        Webhook.alert("Disconnected from Server", tostring(errMsg), CONST.RARITY_COLORS.Alert, true)
    end
end))

if LocalPlayer.Character then
    task.spawn(Binder.bindCharacter, LocalPlayer.Character)
end
table.insert(Conns.Global, LocalPlayer.CharacterAdded:Connect(Binder.bindCharacter))

task.spawn(function()
    local attempts = 0
    while not Binder.resolveRemotes() do
        attempts += 1
        task.wait(attempts <= 25 and 0.25 or 1)
    end
    Binder.resolveAllConfigs()
    Monitor.refreshState()
    Coffee.cacheFellicia()
    Maze.cacheHoneymoon()
    if State.Perf.DisableCutscenes then
        Perf.suppressFxConnections(Remotes.Fx)
    end
    task.spawn(function()
        for _ = 1, 20 do
            Binder.resolveRemotes()
            Binder.resolveAllConfigs()
            if Binder.allRemotesReady() then
                break
            end
            task.wait(1)
        end
        Monitor.refreshState()
        Coffee.cacheFellicia()
        Maze.cacheHoneymoon()
        if State.Perf.DisableCutscenes then
            Perf.suppressFxConnections(Remotes.Fx)
        end
        Quests.evaluateAll(true)
    end)
end)

State.EnabledCast = true
State.EnabledFastSafeReel = true
State.EnabledColorReel = false
State.EnabledGameAutoCast = false
State.EnabledSmartWaterAim = true
State.Primordial.ReturnHome = false
State.Coffee.AllowFishTrade = true
State.Coffee.AutoVisitFellicia = true
Engine.updateLoop()

if UI.AutoCastToggle and UI.AutoCastToggle.Set then
    UI.AutoCastToggle:Set(true)
end
if UI.FastSafeReelToggle and UI.FastSafeReelToggle.Set then
    UI.FastSafeReelToggle:Set(true)
end
if UI.ColorReelToggle and UI.ColorReelToggle.Set then
    UI.ColorReelToggle:Set(false)
end
if UI.GameAutoCastToggle and UI.GameAutoCastToggle.Set then
    UI.GameAutoCastToggle:Set(false)
end
if UI.ReturnHomeToggle and UI.ReturnHomeToggle.Set then
    UI.ReturnHomeToggle:Set(false)
end

task.delay(1.35, function()
    if UI.Window and State.Monitor.Active then
        if type(UI.Window.ToggleMinimise) == "function" then
            pcall(function()
                UI.Window:ToggleMinimise()
            end)
        elseif type(UI.Window.Hide) == "function" then
            pcall(function()
                UI.Window:Hide()
            end)
        end
    end
end)

task.delay(2.5, function()
    if not State.Monitor.Active then
        return
    end
    local okInit, _, _, _, initXp = pcall(Monitor.readLevelXp)
    if okInit and initXp then
        State.Monitor.StartObservedXp = initXp
    end
    Binder.onAfkServerChanged()
    Util.updateStatusTag()
    Water.refresh(false, true)
    if not State.EnabledGameAutoCast and Cache.AutoBtn and GameAuto.isOn() then
        GameAuto.set(false)
    end
    if State.Perf.LowestGraphics then
        Perf.applyLowestGraphics()
    end
    if State.Perf.DisableCutscenes then
        Perf.applyCutsceneBlocker(true)
    end
    if State.Primordial.Enabled then
        Primordial.evaluate()
    end
    if State.Coffee.Enabled then
        Coffee.evaluate()
    end
    Quests.evaluateAll(true)
    Webhook.connected()
end)

task.defer(function()
    pcall(function()
        UI.Window:Notify({
            title = "Saujana Hub v" .. SCRIPT_VERSION,
            content = State.Webhook.Enabled and "Ready • All Systems + Webhook Active" or "Ready • All Systems Active",
            duration = 4,
        })
    end)
end)
