--// Ice UI Library Load
local Ice = loadstring(game:HttpGet("https://raw.githubusercontent.com/TRcalled/Ice/main/Library.lua"))()

--// Services Setup
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local sessionStart = os.time()

--// Window Creation
local Window = Ice:CreateWindow({
    Name = "🌊 ICE & SEA HUB | ENHANCED",
    LoadingTitle = "Ice & Sea Hub",
    LoadingSubtitle = "Optimized & Enhanced Edition",
    Theme = "Nord",
    ConfigurationSaving = {
        Enabled = false,
        FileName = "IceSeaHubConfig"
    }
})

--// DATA TABLES & CONFIGS
local MOB_QUEST_MAP = {
    ["Goku"] = "VegetaGokuQuestFirstTime",
    ["VegetaGoku"] = "VegetaGokuQuestFirstTime",
    ["VegetaChamber"] = "VegetaChamber",
    ["Vegeta Chamber"] = "VegetaChamber",
}

local TRANSFORM_LIST = {
    "FSSJ", "Ikari", "KAIOKENX10", "KAIOKENX20", "KAIOKENX3",
    "KK10", "KK20", "LSSJ", "MYSTIC", "Mui", "MuiF",
    "OOZARU", "RKK10", "SSJ", "SSJ2", "SSJ3", "SSJ4",
    "SSJ4LB", "SSJB", "SSJBE", "SSJBFP", "SSJG", "SSJROSE",
    "SSJRUSV", "SSJRage", "SUPERKAIOKEN", "UI", "ULTRAEGO"
}

--// LOGIC VARIABLES
local selectedTargets = {}
local selectedTransform = TRANSFORM_LIST[1] or ""

-- Toggles & States
local isFarming = false
local isAutoCombo = false
local isQuesting = false
local isWaveMode = false
local isAutoTransform = false
local isAutoAttackPlayers = false
local isAntiAFK = true
local isLowHPSafety = false
local isFPSBooster = false

-- Config Values
local PLAYER_ATTACK_RADIUS = 14
local attackDelay = 0.08 -- Rate limit combat remote (seconds)
local lowHPThreshold = 25 -- Percent HP
local BEHIND_DISTANCE = 4.5
local HEIGHT_OFFSET = 0.5
local predictionLead = 0
local knockbackBuffer = 2.0

-- Internal Trackers
local mobIndex = 1
local lastQuestAttempt = 0
local lastAttackTime = 0
local lastPlayerAttackTime = 0
local lastTargetSwitchTime = 0
local isSafetyRetreating = false

local lastTargetPos = nil
local lastTargetModel = nil
local lastTargetTime = nil
local lastPressedKeyText = ""

--// REMOTES SETUP
local CombatRemote = ReplicatedStorage
    :WaitForChild("Assets", 5)
    :WaitForChild("CombatAssets", 5)
    :WaitForChild("CombatRemotes", 5)
    :WaitForChild("ActivateCombat", 5)

local QuestRemote = ReplicatedStorage
    :WaitForChild("Remotes", 5)
    :WaitForChild("giveQuests", 5)

--// HELPER FUNCTIONS
local function getCharacter()
    local char = player.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, hum, hrp
end

-- FIXED NOCLIP: Protects accessories and HumanoidRootPart collisions when restoring
local function setNoclip(char, state)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            if state then
                v.CanCollide = false
            else
                local isAccessory = v:FindFirstAncestorOfClass("Accessory") ~= nil
                if v.Name == "HumanoidRootPart" or isAccessory then
                    v.CanCollide = false
                else
                    v.CanCollide = true
                end
            end
        end
    end
end

-- FIXED RESET: Restores full physics control and clears retreat states
local function resetCharacterState()
    local char, hum, hrp = getCharacter()
    if char then 
        setNoclip(char, false) 
    end
    if hum then 
        hum.AutoRotate = true 
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    isSafetyRetreating = false
    lastTargetPos = nil
    lastTargetModel = nil
end

local function getQuestForMob(mobName)
    if not mobName then return nil end
    if MOB_QUEST_MAP[mobName] then return MOB_QUEST_MAP[mobName] end
    local lowerMob = mobName:lower()
    for key, questName in pairs(MOB_QUEST_MAP) do
        if lowerMob:find(key:lower(), 1, true) then
            return questName
        end
    end
    return nil
end

local function isPlayerCharacter(model)
    return Players:GetPlayerFromCharacter(model) ~= nil
end

local function isTargetAlive(model)
    if not model or not model:IsA("Model") or not model.Parent then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function findTargetModel(targetData)
    if not targetData then return nil end
    if targetData.location == "Bosses" then
        local bossesFolder = workspace:FindFirstChild("Bosses")
        return bossesFolder and bossesFolder:FindFirstChild(targetData.name)
    elseif targetData.location == "Workspace" then
        return workspace:FindFirstChild(targetData.name)
    end
    return nil
end

local function getAnyAliveTarget()
    local bossesFolder = workspace:FindFirstChild("Bosses")
    if bossesFolder then
        for _, child in ipairs(bossesFolder:GetChildren()) do
            if isTargetAlive(child) then return child, "Bosses" end
        end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Bosses" and not isPlayerCharacter(child) then
            if isTargetAlive(child) then return child, "Workspace" end
        end
    end
    return nil, nil
end

local function getNearbyPlayer(myHrp, radius)
    if not myHrp then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local pChar = p.Character
            local pHum = pChar:FindFirstChildOfClass("Humanoid")
            local pRoot = pChar:FindFirstChild("HumanoidRootPart")
            if pHum and pHum.Health > 0 and pRoot then
                local dist = (myHrp.Position - pRoot.Position).Magnitude
                if dist <= radius then
                    return pChar, pRoot, dist
                end
            end
        end
    end
    return nil, nil, nil
end

local function getDiscoveredTargets()
    local options = {}
    local bossesFolder = workspace:FindFirstChild("Bosses")
    if bossesFolder then
        for _, child in ipairs(bossesFolder:GetChildren()) do
            if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
                table.insert(options, "Bosses:" .. child.Name)
            end
        end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Bosses" and child:FindFirstChildOfClass("Humanoid") and not isPlayerCharacter(child) then
            table.insert(options, "Workspace:" .. child.Name)
        end
    end
    return options
end

--// ANTI-AFK SYSTEM
if getgenv().AntiAFKConnection then
    getgenv().AntiAFKConnection:Disconnect()
end

getgenv().AntiAFKConnection = player.Idled:Connect(function()
    if isAntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

--// AUTO COMBO SYSTEM
local KEY_MAP = {
    ["1"] = Enum.KeyCode.One, ["2"] = Enum.KeyCode.Two, ["3"] = Enum.KeyCode.Three,
    ["4"] = Enum.KeyCode.Four, ["5"] = Enum.KeyCode.Five, ["6"] = Enum.KeyCode.Six,
    ["7"] = Enum.KeyCode.Seven, ["8"] = Enum.KeyCode.Eight, ["9"] = Enum.KeyCode.Nine,
    ["0"] = Enum.KeyCode.Zero
}

local function getKeyCodeFromText(rawText)
    if not rawText or rawText == "" then return nil end
    local clean = rawText:gsub("[%[%]%s]", ""):upper()
    local keyChar = clean:match("PRESS(%w+)") or clean:match("(%w+)")
    if not keyChar then return nil end
    if KEY_MAP[keyChar] then return KEY_MAP[keyChar] end
    local success, code = pcall(function() return Enum.KeyCode[keyChar] end)
    return success and code or nil
end

local function fireKey(keyCode)
    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
    VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function checkAndPress(contentText)
    if not isAutoCombo or not contentText or contentText == "" then 
        lastPressedKeyText = ""
        return 
    end
    if lastPressedKeyText == contentText then return end
    local keyCode = getKeyCodeFromText(contentText)
    if keyCode then
        lastPressedKeyText = contentText
        fireKey(keyCode)
    end
end

RunService.Heartbeat:Connect(function()
    if not isAutoCombo then return end
    local playerGui = player:FindFirstChild("PlayerGui")
    local combatGui = playerGui and playerGui:FindFirstChild("CombatGui")
    local pressHere = combatGui and combatGui:FindFirstChild("PressHere")
    if pressHere and pressHere.ContentText ~= "" then
        checkAndPress(pressHere.ContentText)
    else
        lastPressedKeyText = ""
    end
end)

--// FPS BOOSTER FUNCTION
local originalSettings = {}
local function setFPSBooster(enable)
    if enable then
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("Decal") or object:IsA("Texture") then
                object.Transparency = 1
            elseif object:IsA("ParticleEmitter") or object:IsA("Trail") then
                object.Enabled = false
            end
        end
        Lighting.GlobalShadows = false
    else
        for _, object in ipairs(workspace:GetDescendants()) do
            if object:IsA("Decal") or object:IsA("Texture") then
                object.Transparency = 0
            elseif object:IsA("ParticleEmitter") or object:IsA("Trail") then
                object.Enabled = true
            end
        end
        Lighting.GlobalShadows = true
    end
end

--// TAB CREATION
local FarmTab = Window:CreateTab("🌾 Farm", 4483362458)
local CombatTab = Window:CreateTab("⚔️ Combat & Forms", 4483362458)
local SafetyTab = Window:CreateTab("🛡️ Safety & Visuals", 4483362458)
local SettingsTab = Window:CreateTab("⚙️ Settings", 4483362458)

--// TAB 1: FARM CONTROLS

local TargetDropdown = FarmTab:CreateDropdown({
    Name = "Select Targets",
    Options = getDiscoveredTargets(),
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "TargetDropdown",
    Callback = function(Options)
        selectedTargets = {}
        for _, opt in ipairs(Options) do
            local loc, name = opt:match("^(.-):(.+)$")
            if loc and name then
                table.insert(selectedTargets, { name = name, location = loc, selected = true })
            end
        end
    end,
})

FarmTab:CreateButton({
    Name = "🔄 Refresh Targets List",
    Callback = function()
        TargetDropdown:Refresh(getDiscoveredTargets())
    end,
})

FarmTab:CreateToggle({
    Name = "⚔️ Auto Farm",
    CurrentValue = false,
    Flag = "AutoFarm",
    Callback = function(Value)
        isFarming = Value
        if not isFarming then
            resetCharacterState()
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Attack Delay (Rate Limit)",
    Range = {0.02, 0.3},
    Increment = 0.01,
    Suffix = "s",
    CurrentValue = attackDelay,
    Flag = "AttackDelay",
    Callback = function(Value)
        attackDelay = Value
    end,
})

FarmTab:CreateToggle({
    Name = "📜 Auto Quest",
    CurrentValue = false,
    Flag = "AutoQuest",
    Callback = function(Value)
        isQuesting = Value
    end,
})

FarmTab:CreateToggle({
    Name = "🌊 Wave Mode",
    CurrentValue = false,
    Flag = "WaveMode",
    Callback = function(Value)
        isWaveMode = Value
    end,
})

--// TAB 2: COMBAT & FORMS

CombatTab:CreateToggle({
    Name = "🥊 Auto Combo",
    CurrentValue = false,
    Flag = "AutoCombo",
    Callback = function(Value)
        isAutoCombo = Value
        if not isAutoCombo then
            lastPressedKeyText = ""
        end
    end,
})

CombatTab:CreateToggle({
    Name = "🎯 Auto Attack Players",
    CurrentValue = false,
    Flag = "AutoAttackPlayers",
    Callback = function(Value)
        isAutoAttackPlayers = Value
    end,
})

CombatTab:CreateSlider({
    Name = "Auto Attack Player Range",
    Range = {5, 50},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = PLAYER_ATTACK_RADIUS,
    Flag = "PlayerAttackRadius",
    Callback = function(Value)
        PLAYER_ATTACK_RADIUS = Value
    end,
})

CombatTab:CreateDropdown({
    Name = "Select Form",
    Options = TRANSFORM_LIST,
    CurrentOption = {TRANSFORM_LIST[1] or ""},
    MultipleOptions = false,
    Flag = "FormSelect",
    Callback = function(Option)
        selectedTransform = type(Option) == "table" and Option[1] or Option
    end,
})

local function getTransformRemote(formName)
    local ssjsFolder = ReplicatedStorage:FindFirstChild("ssjs")
    return ssjsFolder and ssjsFolder:FindFirstChild(formName)
end

local function triggerTransform()
    if not isAutoTransform or selectedTransform == "" then return end
    local remote = getTransformRemote(selectedTransform)
    if remote then remote:FireServer() end
end

CombatTab:CreateToggle({
    Name = "⚡ Auto Transform",
    CurrentValue = false,
    Flag = "AutoTransform",
    Callback = function(Value)
        isAutoTransform = Value
        if isAutoTransform then triggerTransform() end
    end,
})

local function handleCharacterSpawn(char)
    if not char then return end
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    task.spawn(function()
        for i = 1, 4 do
            if isAutoTransform then triggerTransform() end
            task.wait(0.6)
        end
    end)
end

if player.Character then task.spawn(handleCharacterSpawn, player.Character) end
player.CharacterAdded:Connect(handleCharacterSpawn)

--// TAB 3: SAFETY & VISUALS

SafetyTab:CreateToggle({
    Name = "🩹 Low HP Protection",
    CurrentValue = false,
    Flag = "LowHPSafety",
    Callback = function(Value)
        isLowHPSafety = Value
    end,
})

SafetyTab:CreateSlider({
    Name = "Low HP Threshold",
    Range = {10, 50},
    Increment = 5,
    Suffix = "% HP",
    CurrentValue = lowHPThreshold,
    Flag = "LowHPThreshold",
    Callback = function(Value)
        lowHPThreshold = Value
    end,
})

SafetyTab:CreateToggle({
    Name = "🚀 FPS Booster / Potato Graphics",
    CurrentValue = false,
    Flag = "FPSBooster",
    Callback = function(Value)
        isFPSBooster = Value
        setFPSBooster(Value)
    end,
})

--// TAB 4: SETTINGS & THEMES

local availableThemes = {}
if Ice and type(Ice.GetThemes) == "function" then
    availableThemes = Ice:GetThemes()
elseif Ice and type(Ice.Theme) == "table" then
    for themeName, _ in pairs(Ice.Theme) do
        table.insert(availableThemes, themeName)
    end
    table.sort(availableThemes)
end

if #availableThemes == 0 then
    availableThemes = {
        "Default", "Nord", "Ocean", "AmberGlow", "Amethyst", "Bloom", "Cappuccino",
        "Crimson", "Cyberpunk", "DarkBlue", "Dracula", "Emerald", "Green", "Light",
        "Monochrome", "OLEDDark", "RoseGold", "Serenity", "Synthwave", "TokyoNight"
    }
end

SettingsTab:CreateDropdown({
    Name = "🎨 UI Theme Selector",
    Options = availableThemes,
    CurrentOption = {"Nord"},
    MultipleOptions = false,
    Flag = "ThemeSelect",
    Callback = function(Option)
        local chosenTheme = type(Option) == "table" and Option[1] or Option
        if not chosenTheme or chosenTheme == "" then return end

        if Window and type(Window.ChangeTheme) == "function" then
            Window:ChangeTheme(chosenTheme)
        elseif Ice and type(Ice.ChangeTheme) == "function" then
            Ice:ChangeTheme(chosenTheme)
        end
    end,
})

SettingsTab:CreateToggle({
    Name = "🛡️ Anti-AFK",
    CurrentValue = true,
    Flag = "AntiAFK",
    Callback = function(Value)
        isAntiAFK = Value
    end,
})

SettingsTab:CreateSlider({
    Name = "Prediction Lead (s)",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = predictionLead,
    Flag = "PredLead",
    Callback = function(Value)
        predictionLead = math.clamp(Value, 0, 1.0)
    end,
})

SettingsTab:CreateSlider({
    Name = "Knockback Buffer",
    Range = {0, 15},
    Increment = 0.5,
    Suffix = " studs",
    CurrentValue = knockbackBuffer,
    Flag = "KBBuffer",
    Callback = function(Value)
        knockbackBuffer = math.clamp(Value, 0, 15.0)
    end,
})

local StatusParagraph = SettingsTab:CreateParagraph({
    Title = "Status",
    Content = "Idle"
})

local SessionParagraph = SettingsTab:CreateParagraph({
    Title = "Session Runtime",
    Content = "00h 00m 00s"
})

local lastStatusMessage = ""
local function updateStatus(text)
    if lastStatusMessage ~= text then
        lastStatusMessage = text
        StatusParagraph:Set({Title = "Status", Content = text})
    end
end

-- Session Timer Updater
task.spawn(function()
    while task.wait(1) do
        local elapsed = os.time() - sessionStart
        local hours = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        SessionParagraph:Set({
            Title = "Session Runtime",
            Content = string.format("%02dh %02dm %02ds", hours, mins, secs)
        })
    end
end)

--// NEARBY PLAYER AUTO ATTACK LOOP
RunService.RenderStepped:Connect(function()
    if not isAutoAttackPlayers then return end

    local now = tick()
    if (now - lastPlayerAttackTime) < attackDelay then return end

    local char, hum, hrp = getCharacter()
    if not char or not hum or not hrp then return end

    local nearbyChar, nearbyRoot = getNearbyPlayer(hrp, PLAYER_ATTACK_RADIUS)
    if nearbyChar and nearbyRoot then
        lastPlayerAttackTime = now
        if CombatRemote then
            CombatRemote:FireServer()
        end
    end
end)

--// MAIN AUTO FARM RENDER LOOP
RunService.RenderStepped:Connect(function()
    if not isFarming then 
        return 
    end

    local char, hum, hrp = getCharacter()
    if not char or not hum or not hrp then 
        return 
    end

    -- LOW HP SAFETY CHECK
    if isLowHPSafety and hum.Health > 0 then
        local hpPercent = (hum.Health / hum.MaxHealth) * 100
        if hpPercent <= lowHPThreshold then
            isSafetyRetreating = true
            updateStatus("⚠️ Low HP! Regenerating in safe zone...")
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 500, 0) -- Teleport safe in air
            hrp.AssemblyLinearVelocity = Vector3.zero
            return
        elseif hpPercent >= 80 and isSafetyRetreating then
            isSafetyRetreating = false
        end
    end

    if isSafetyRetreating then return end

    hum.AutoRotate = false
    local targetModel, targetLocation

    if isWaveMode then
        targetModel, targetLocation = getAnyAliveTarget()
        if not targetModel then
            updateStatus("Waiting for wave...")
            resetCharacterState()
            return
        end
    else
        local activeTargets = selectedTargets
        if #activeTargets == 0 then
            updateStatus("No target selected")
            resetCharacterState()
            return
        end

        if mobIndex > #activeTargets then mobIndex = 1 end
        local currentTargetData = activeTargets[mobIndex]
        targetModel = findTargetModel(currentTargetData)

        if not isTargetAlive(targetModel) then
            updateStatus("Searching Target...")
            local now = tick()
            if (now - lastTargetSwitchTime) >= 0.3 then -- Throttle target index switching
                lastTargetSwitchTime = now
                mobIndex += 1
                if mobIndex > #activeTargets then mobIndex = 1 end
            end
            resetCharacterState()
            return
        end
        targetLocation = currentTargetData.location
    end

    local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        resetCharacterState()
        return
    end

    -- CONTINUOUS AUTO-QUESTING (3s Cooldown)
    if isQuesting and QuestRemote then
        local now = tick()
        if (now - lastQuestAttempt) >= 3 then
            lastQuestAttempt = now
            local targetQuest = getQuestForMob(targetModel.Name)
            if targetQuest then
                QuestRemote:FireServer(targetQuest)
            end
        end
    end

    updateStatus("Farming " .. targetModel.Name)

    setNoclip(char, true)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    local now = tick()
    local calcVel = Vector3.zero
    if lastTargetPos and lastTargetModel == targetModel and lastTargetTime then
        local dt = now - lastTargetTime
        if dt > 0 then calcVel = (targetRoot.Position - lastTargetPos) / dt end
    end

    lastTargetPos = targetRoot.Position
    lastTargetModel = targetModel
    lastTargetTime = now

    local velSpeed = calcVel.Magnitude
    local isMovingFast = velSpeed > 2
    local predictedTargetPos = targetRoot.Position + (calcVel * predictionLead)
    local extraDist = isMovingFast and math.clamp(velSpeed * 0.1, 0, knockbackBuffer) or 0
    local dynamicDistance = BEHIND_DISTANCE + extraDist
    local dynamicHeight = isMovingFast and (HEIGHT_OFFSET + (knockbackBuffer * 0.4)) or HEIGHT_OFFSET

    local baseCF = CFrame.new(predictedTargetPos, predictedTargetPos + targetRoot.CFrame.LookVector)
    local behindPos = baseCF.Position - baseCF.LookVector * dynamicDistance + Vector3.new(0, dynamicHeight, 0)
    local lookTarget = predictedTargetPos + Vector3.new(0, targetRoot.Size.Y * 0.5, 0)
    
    -- Instant frame-perfect lock
    hrp.CFrame = CFrame.lookAt(behindPos, lookTarget)

    -- Rate-limited Combat Remote Execution
    if CombatRemote and (now - lastAttackTime) >= attackDelay then
        lastAttackTime = now
        CombatRemote:FireServer()
    end
end)
