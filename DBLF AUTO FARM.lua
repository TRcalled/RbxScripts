--// Ice UI Library Load
local Ice = loadstring(game:HttpGet("https://raw.githubusercontent.com/TRcalled/Ice/refs/heads/main/Library.lua"))()

--// Services Setup
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

--// Window Creation
local Window = Ice:CreateWindow({
    Name = "🌊 ICE & SEA HUB",
    LoadingTitle = "Ice & Sea Hub",
    LoadingSubtitle = "Loaded with Ice UI Library",
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

local isFarming = false
local isAutoCombo = false
local isQuesting = false
local isWaveMode = false
local isAutoTransform = false
local isAutoAttackPlayers = false
local isAntiAFK = true
local PLAYER_ATTACK_RADIUS = 14
local isTargetInRange = false

local mobIndex = 1
local lastQuestAttempt = 0

local BEHIND_DISTANCE = 4.5
local HEIGHT_OFFSET = 0.5
local predictionLead = 0.15
local knockbackBuffer = 2.0

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

local function getActiveTargetArray()
    return selectedTargets
end

local function getCharacter()
    local char = player.Character
    if not char then return nil, nil, nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, hum, hrp
end

local function setNoclip(char, state)
    if not char then return end
    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = not state end
    end
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

--// AUTO ANTI-AFK CONNECTION
if getgenv().AntiAFKConnection then
    getgenv().AntiAFKConnection:Disconnect()
end

getgenv().AntiAFKConnection = player.Idled:Connect(function()
    if isAntiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
        print("[Anti-AFK] Prevented idle kick at " .. os.date("%X"))
    end
end)

--// AUTO COMBO LOGIC
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

local comboConnection
local function bindComboPresser()
    if comboConnection then comboConnection:Disconnect() comboConnection = nil end
    local playerGui = player:FindFirstChild("PlayerGui")
    local combatGui = playerGui and playerGui:FindFirstChild("CombatGui")
    local pressHere = combatGui and combatGui:FindFirstChild("PressHere")
    if not pressHere then return end
    checkAndPress(pressHere.ContentText)
    comboConnection = pressHere:GetPropertyChangedSignal("ContentText"):Connect(function()
        checkAndPress(pressHere.ContentText)
    end)
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

task.spawn(function()
    local playerGui = player:WaitForChild("PlayerGui")
    playerGui.DescendantAdded:Connect(function(desc)
        if desc.Name == "PressHere" or desc.Name == "CombatGui" then
            task.defer(bindComboPresser)
        end
    end)
    bindComboPresser()
end)

--// TAB CREATION
local FarmTab = Window:CreateTab("Farm", 4483362458)
local FormsTab = Window:CreateTab("Forms", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

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

-- Auto-refresh dropdown on workspace additions
workspace.ChildAdded:Connect(function(child)
    task.wait(0.5)
    if TargetDropdown then
        TargetDropdown:Refresh(getDiscoveredTargets())
    end
end)

local bosses = workspace:FindFirstChild("Bosses")
if bosses then
    bosses.ChildAdded:Connect(function(child)
        task.wait(0.5)
        if TargetDropdown then
            TargetDropdown:Refresh(getDiscoveredTargets())
        end
    end)
end

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
            local char = player.Character
            if char then setNoclip(char, false) end
            lastTargetPos = nil
            lastTargetModel = nil
            isTargetInRange = false
        end
    end,
})

FarmTab:CreateToggle({
    Name = "🥊 Auto Combo",
    CurrentValue = false,
    Flag = "AutoCombo",
    Callback = function(Value)
        isAutoCombo = Value
        if isAutoCombo then
            bindComboPresser()
        else
            lastPressedKeyText = ""
        end
    end,
})

FarmTab:CreateToggle({
    Name = "🎯 Auto Attack Players (14 Studs)",
    CurrentValue = false,
    Flag = "AutoAttackPlayers",
    Callback = function(Value)
        isAutoAttackPlayers = Value
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

FarmTab:CreateToggle({
    Name = "📜 Auto Quest",
    CurrentValue = false,
    Flag = "AutoQuest",
    Callback = function(Value)
        isQuesting = Value
    end,
})

--// TAB 2: FORM CONTROLS

FormsTab:CreateDropdown({
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

FormsTab:CreateToggle({
    Name = "⚡ Auto Transform",
    CurrentValue = false,
    Flag = "AutoTransform",
    Callback = function(Value)
        isAutoTransform = Value
        if isAutoTransform then
            triggerTransform()
        end
    end,
})

local function handleCharacterSpawn(char)
    if not char then return end
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    task.spawn(function()
        for i = 1, 5 do
            if isAutoTransform then triggerTransform() end
            task.wait(0.6)
        end
    end)
end

if player.Character then task.spawn(handleCharacterSpawn, player.Character) end
player.CharacterAdded:Connect(handleCharacterSpawn)

--// TAB 3: SETTINGS CONTROLS & THEME SELECTOR

local availableThemes = {}
if Ice and type(Ice.Themes) == "table" then
    for themeName, _ in pairs(Ice.Themes) do
        table.insert(availableThemes, themeName)
    end
    table.sort(availableThemes)
end

if #availableThemes == 0 then
    availableThemes = {"Ocean", "Default", "Amber", "Midnight", "Serenity", "Bloom", "DarkBlue", "Light"}
end

SettingsTab:CreateDropdown({
    Name = "🎨 UI Theme Selector",
    Options = availableThemes,
    CurrentOption = {"Ocean"},
    MultipleOptions = false,
    Flag = "ThemeSelect",
    Callback = function(Option)
        local chosenTheme = type(Option) == "table" and Option[1] or Option
        if not chosenTheme then return end

        if Ice and type(Ice.ChangeTheme) == "function" then
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

local lastStatusMessage = ""
local function updateStatus(text)
    if lastStatusMessage ~= text then
        lastStatusMessage = text
        StatusParagraph:Set({Title = "Status", Content = text})
    end
end

--// NEARBY PLAYER AUTO ATTACK LOOP
RunService.RenderStepped:Connect(function()
    if not isAutoAttackPlayers then return end

    local char, hum, hrp = getCharacter()
    if not char or not hum or not hrp then return end

    local nearbyChar, nearbyRoot = getNearbyPlayer(hrp, PLAYER_ATTACK_RADIUS)
    if nearbyChar and nearbyRoot then
        if CombatRemote then
            CombatRemote:FireServer()
        end
    end
end)

--// MAIN AUTO FARM RENDER LOOP
RunService.RenderStepped:Connect(function()
    if not isFarming then 
        isTargetInRange = false
        return 
    end

    local char, hum, hrp = getCharacter()
    if not char or not hum or not hrp then 
        isTargetInRange = false
        return 
    end

    hum.AutoRotate = false
    local targetModel, targetLocation

    if isWaveMode then
        targetModel, targetLocation = getAnyAliveTarget()
        if not targetModel then
            updateStatus("Waiting for wave...")
            lastTargetPos = nil
            isTargetInRange = false
            return
        end
    else
        local activeTargets = getActiveTargetArray()
        if #activeTargets == 0 then
            updateStatus("No target selected")
            lastTargetPos = nil
            isTargetInRange = false
            return
        end

        if mobIndex > #activeTargets then mobIndex = 1 end
        local currentTargetData = activeTargets[mobIndex]
        targetModel = findTargetModel(currentTargetData)

        if not isTargetAlive(targetModel) then
            updateStatus("Searching " .. (currentTargetData and currentTargetData.name or "Target"))
            mobIndex += 1
            if mobIndex > #activeTargets then mobIndex = 1 end
            lastTargetPos = nil
            isTargetInRange = false
            return
        end
        targetLocation = currentTargetData.location
    end

    local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        isTargetInRange = false
        return
    end

    isTargetInRange = true

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

    if CombatRemote then
        CombatRemote:FireServer()
    end
end)
