--// UI Library Setup
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- Clean up existing UI if re-executed
if CoreGui:FindFirstChild("AutoFarmGui") then
	CoreGui.AutoFarmGui:Destroy()
end

--// MOB TO QUEST MAPPING
local MOB_QUEST_MAP = {
	["Goku"] = "VegetaGokuQuestFirstTime",
	["VegetaGoku"] = "VegetaGokuQuestFirstTime",
	["VegetaChamber"] = "VegetaChamber",
	["Vegeta Chamber"] = "VegetaChamber",
}

--// Configurable Quest List
local QUEST_LIST = {
	"VegetaGokuQuestFirstTime",
	"VegetaChamber",
}

local TRANSFORM_LIST = {
	"FSSJ", "Ikari", "KAIOKENX10", "KAIOKENX20", "KAIOKENX3",
	"KK10", "KK20", "LSSJ", "MYSTIC", "Mui", "MuiF",
	"OOZARU", "RKK10", "SSJ", "SSJ2", "SSJ3", "SSJ4",
	"SSJ4LB", "SSJB", "SSJBE", "SSJBFP", "SSJG", "SSJROSE",
	"SSJRUSV", "SSJRage", "SUPERKAIOKEN", "UI", "ULTRAEGO"
}

--// ScreenGui Creation
local gui = Instance.new("ScreenGui")
gui.Name = "AutoFarmGui"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 320, 0, 580)
mainFrame.Position = UDim2.new(0.5, -160, 0.4, -290)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
title.Text = "Auto Farm & Quest Manager"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 16
title.Font = Enum.Font.SourceSansBold
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = title

-- Helper Elements
local function createLabel(text, posY)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.9, 0, 0, 20)
	label.Position = UDim2.new(0.05, 0, 0, posY)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(180, 180, 190)
	label.TextSize = 12
	label.Font = Enum.Font.SourceSansSemibold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = mainFrame
	return label
end

local function createToggleButton(text, posY)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.9, 0, 0, 28)
	btn.Position = UDim2.new(0.05, 0, 0, posY)
	btn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	btn.Text = text .. ": OFF"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 13
	btn.Font = Enum.Font.SourceSansBold
	btn.Parent = mainFrame
	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn
	return btn
end

local function createInputRow(labelText, defaultVal, posY)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0.9, 0, 0, 26)
	container.Position = UDim2.new(0.05, 0, 0, posY)
	container.BackgroundTransparency = 1
	container.Parent = mainFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.65, 0, 1, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(180, 180, 190)
	label.TextSize = 12
	label.Font = Enum.Font.SourceSansSemibold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.3, 0, 1, 0)
	box.Position = UDim2.new(0.7, 0, 0, 0)
	box.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	box.Text = tostring(defaultVal)
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.TextSize = 12
	box.Font = Enum.Font.SourceSansBold
	box.ClearTextOnFocus = false
	box.Parent = container

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 6)
	boxCorner.Parent = box

	return box
end

--// Logic Variables
local selectedTargets = {}
local selectedQuests = {}
local selectedTransform = TRANSFORM_LIST[1] or ""

local isFarming = false
local isQuesting = false
local isWaveMode = false
local isAutoTransform = false
local isTargetInRange = false

local mobIndex = 1
local currentTween

local BEHIND_DISTANCE = 4.5
local HEIGHT_OFFSET = 0.5
local TWEEN_TIME = 0.001
local ATTACK_RANGE_THRESHOLD = 15

local predictionLead = 0.15
local knockbackBuffer = 2.0

local lastTargetPos = nil
local lastTargetModel = nil
local lastTargetTime = nil
local lastPressedKeyText = ""

--// Remotes Setup
local CombatRemote = ReplicatedStorage
	:WaitForChild("Assets", 5)
	:WaitForChild("CombatAssets", 5)
	:WaitForChild("CombatRemotes", 5)
	:WaitForChild("ActivateCombat", 5)

local QuestRemote = ReplicatedStorage
	:WaitForChild("Remotes", 5)
	:WaitForChild("giveQuests", 5)

--// Quest Status Checker
local function isInQuest()
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local inQuestObj = backpack:FindFirstChild("inQuest")
		if inQuestObj and inQuestObj:IsA("BoolValue") then
			return inQuestObj.Value
		end
	end
	return false
end

--// COMBO PRESSER LOGIC
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
	if not isFarming or not isTargetInRange or not contentText or contentText == "" then 
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
	if not isFarming or not isTargetInRange then return end
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

local function getTransformRemote(formName)
	local ssjsFolder = ReplicatedStorage:FindFirstChild("ssjs")
	return ssjsFolder and ssjsFolder:FindFirstChild(formName)
end

local function isPlayerCharacter(model)
	return Players:GetPlayerFromCharacter(model) ~= nil
end

local function isTargetAlive(model)
	if not model or not model:IsA("Model") then return false end
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

--// DROPDOWN BUILDERS

-- 1. Target Multi-Select Dropdown
createLabel("Select Targets (Multi-Select):", 48)

local targetDropdownBtn = Instance.new("TextButton")
targetDropdownBtn.Size = UDim2.new(0.9, 0, 0, 26)
targetDropdownBtn.Position = UDim2.new(0.05, 0, 0, 68)
targetDropdownBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
targetDropdownBtn.Text = "Select Targets..."
targetDropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
targetDropdownBtn.TextSize = 12
targetDropdownBtn.Font = Enum.Font.SourceSans
targetDropdownBtn.Parent = mainFrame

local targetDdCorner = Instance.new("UICorner")
targetDdCorner.CornerRadius = UDim.new(0, 6)
targetDdCorner.Parent = targetDropdownBtn

local targetContainer = Instance.new("ScrollingFrame")
targetContainer.Size = UDim2.new(0.9, 0, 0, 80)
targetContainer.Position = UDim2.new(0.05, 0, 0, 96)
targetContainer.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
targetContainer.Visible = false
targetContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
targetContainer.ScrollBarThickness = 4
targetContainer.ZIndex = 5
targetContainer.Parent = mainFrame

local targetLayout = Instance.new("UIListLayout")
targetLayout.SortOrder = Enum.SortOrder.LayoutOrder
targetLayout.Parent = targetContainer

local function updateTargetDropdownText()
	local selectedList = {}
	for key, data in pairs(selectedTargets) do
		if data.selected then table.insert(selectedList, data.name) end
	end
	targetDropdownBtn.Text = #selectedList == 0 and "Select Targets..." or table.concat(selectedList, ", ")
end

local function populateTargets()
	for _, child in ipairs(targetContainer:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local discovered = {}
	local bossesFolder = workspace:FindFirstChild("Bosses")
	if bossesFolder then
		for _, child in ipairs(bossesFolder:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				table.insert(discovered, { name = child.Name, location = "Bosses" })
			end
		end
	end
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Model") and child.Name ~= "Bosses" and child:FindFirstChildOfClass("Humanoid") and not isPlayerCharacter(child) then
			table.insert(discovered, { name = child.Name, location = "Workspace" })
		end
	end

	for _, item in ipairs(discovered) do
		local key = item.location .. ":" .. item.name
		if not selectedTargets[key] then
			selectedTargets[key] = { name = item.name, location = item.location, selected = false }
		end

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 24)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		local isSel = selectedTargets[key].selected
		btn.Text = (isSel and "[X] " or "[ ] ") .. item.name .. "  [" .. item.location .. "]"
		btn.TextColor3 = isSel and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(220, 220, 220)
		btn.TextSize = 12
		btn.Font = Enum.Font.SourceSans
		btn.ZIndex = 6
		btn.Parent = targetContainer

		btn.MouseButton1Click:Connect(function()
			selectedTargets[key].selected = not selectedTargets[key].selected
			local newState = selectedTargets[key].selected
			btn.Text = (newState and "[X] " or "[ ] ") .. item.name .. "  [" .. item.location .. "]"
			btn.TextColor3 = newState and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(220, 220, 220)
			updateTargetDropdownText()
		end)
	end
	targetContainer.CanvasSize = UDim2.new(0, 0, 0, targetLayout.AbsoluteContentSize.Y)
end

targetDropdownBtn.MouseButton1Click:Connect(function()
	targetContainer.Visible = not targetContainer.Visible
	if targetContainer.Visible then populateTargets() end
end)

-- 2. Quest Multi-Select Dropdown
createLabel("Select Quests (Multi-Select):", 180)

local questDropdownBtn = Instance.new("TextButton")
questDropdownBtn.Size = UDim2.new(0.9, 0, 0, 26)
questDropdownBtn.Position = UDim2.new(0.05, 0, 0, 200)
questDropdownBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
questDropdownBtn.Text = "Select Quests..."
questDropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
questDropdownBtn.TextSize = 12
questDropdownBtn.Font = Enum.Font.SourceSans
questDropdownBtn.Parent = mainFrame

local questDdCorner = Instance.new("UICorner")
questDdCorner.CornerRadius = UDim.new(0, 6)
questDdCorner.Parent = questDropdownBtn

local questContainer = Instance.new("ScrollingFrame")
questContainer.Size = UDim2.new(0.9, 0, 0, 70)
questContainer.Position = UDim2.new(0.05, 0, 0, 228)
questContainer.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
questContainer.Visible = false
questContainer.ScrollBarThickness = 4
questContainer.ZIndex = 5
questContainer.Parent = mainFrame

local questLayout = Instance.new("UIListLayout")
questLayout.SortOrder = Enum.SortOrder.LayoutOrder
questLayout.Parent = questContainer

local function updateQuestDropdownText()
	local selectedList = {}
	for qName, data in pairs(selectedQuests) do
		if data.selected then table.insert(selectedList, qName) end
	end
	questDropdownBtn.Text = #selectedList == 0 and "Select Quests..." or table.concat(selectedList, ", ")
end

local function populateQuests()
	for _, child in ipairs(questContainer:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	for _, qName in ipairs(QUEST_LIST) do
		if not selectedQuests[qName] then
			selectedQuests[qName] = { name = qName, selected = true }
		end

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 24)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		local isSel = selectedQuests[qName].selected
		btn.Text = (isSel and "[X] " or "[ ] ") .. qName
		btn.TextColor3 = isSel and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(220, 220, 220)
		btn.TextSize = 12
		btn.Font = Enum.Font.SourceSans
		btn.ZIndex = 6
		btn.Parent = questContainer

		btn.MouseButton1Click:Connect(function()
			selectedQuests[qName].selected = not selectedQuests[qName].selected
			local newState = selectedQuests[qName].selected
			btn.Text = (newState and "[X] " or "[ ] ") .. qName
			btn.TextColor3 = newState and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(220, 220, 220)
			updateQuestDropdownText()
		end)
	end
	updateQuestDropdownText()
	questContainer.CanvasSize = UDim2.new(0, 0, 0, questLayout.AbsoluteContentSize.Y)
end

questDropdownBtn.MouseButton1Click:Connect(function()
	questContainer.Visible = not questContainer.Visible
	if questContainer.Visible then populateQuests() end
end)

-- Initialize quest selections
populateQuests()

-- 3. Transformation Selector Dropdown
createLabel("Select Transformation:", 232)

local transformDropdownBtn = Instance.new("TextButton")
transformDropdownBtn.Size = UDim2.new(0.9, 0, 0, 26)
transformDropdownBtn.Position = UDim2.new(0.05, 0, 0, 252)
transformDropdownBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
transformDropdownBtn.Text = selectedTransform ~= "" and selectedTransform or "Select Form..."
transformDropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
transformDropdownBtn.TextSize = 12
transformDropdownBtn.Font = Enum.Font.SourceSans
transformDropdownBtn.Parent = mainFrame

local transformDdCorner = Instance.new("UICorner")
transformDdCorner.CornerRadius = UDim.new(0, 6)
transformDdCorner.Parent = transformDropdownBtn

local transformContainer = Instance.new("ScrollingFrame")
transformContainer.Size = UDim2.new(0.9, 0, 0, 90)
transformContainer.Position = UDim2.new(0.05, 0, 0, 280)
transformContainer.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
transformContainer.Visible = false
transformContainer.ScrollBarThickness = 4
transformContainer.ZIndex = 5
transformContainer.Parent = mainFrame

local transformLayout = Instance.new("UIListLayout")
transformLayout.SortOrder = Enum.SortOrder.LayoutOrder
transformLayout.Parent = transformContainer

local function populateTransforms()
	for _, child in ipairs(transformContainer:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	for _, formName in ipairs(TRANSFORM_LIST) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 24)
		btn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		btn.Text = formName
		btn.TextColor3 = (selectedTransform == formName) and Color3.fromRGB(80, 220, 80) or Color3.fromRGB(220, 220, 220)
		btn.TextSize = 12
		btn.Font = Enum.Font.SourceSans
		btn.ZIndex = 6
		btn.Parent = transformContainer

		btn.MouseButton1Click:Connect(function()
			selectedTransform = formName
			transformDropdownBtn.Text = formName
			transformContainer.Visible = false
		end)
	end
	transformContainer.CanvasSize = UDim2.new(0, 0, 0, transformLayout.AbsoluteContentSize.Y)
end

transformDropdownBtn.MouseButton1Click:Connect(function()
	transformContainer.Visible = not transformContainer.Visible
	if transformContainer.Visible then populateTransforms() end
end)

-- Buttons & Controls
local waveToggle = createToggleButton("Wave / Dungeon Mode", 290)
local farmToggle = createToggleButton("Auto Farm", 325)
local questToggle = createToggleButton("Auto Quest", 360)
local transformToggle = createToggleButton("Auto Transform", 395)

local predBox = createInputRow("Prediction Lead (s):", predictionLead, 432)
local bufferBox = createInputRow("Knockback Buffer:", knockbackBuffer, 464)

predBox.FocusLost:Connect(function()
	local val = tonumber(predBox.Text)
	predictionLead = val and math.clamp(val, 0, 1.0) or predictionLead
	predBox.Text = tostring(predictionLead)
end)

bufferBox.FocusLost:Connect(function()
	local val = tonumber(bufferBox.Text)
	knockbackBuffer = val and math.clamp(val, 0, 15.0) or knockbackBuffer
	bufferBox.Text = tostring(knockbackBuffer)
end)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 20)
statusLabel.Position = UDim2.new(0.05, 0, 0, 502)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Idle"
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.SourceSansItalic
statusLabel.Parent = mainFrame

local noteLabel = Instance.new("TextLabel")
noteLabel.Size = UDim2.new(0.9, 0, 0, 20)
noteLabel.Position = UDim2.new(0.05, 0, 0, 545)
noteLabel.BackgroundTransparency = 1
noteLabel.Text = "Press 'Right Control' to hide/show UI"
noteLabel.TextColor3 = Color3.fromRGB(100, 100, 110)
noteLabel.TextSize = 11
noteLabel.Font = Enum.Font.SourceSans
noteLabel.Parent = mainFrame

local function triggerTransform()
	if not isAutoTransform or selectedTransform == "" then return end
	local remote = getTransformRemote(selectedTransform)
	if remote then remote:FireServer() end
end

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

local function getActiveTargetArray()
	local active = {}
	for _, data in pairs(selectedTargets) do
		if data.selected then table.insert(active, data) end
	end
	return active
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

-- Toggles
waveToggle.MouseButton1Click:Connect(function()
	isWaveMode = not isWaveMode
	waveToggle.BackgroundColor3 = isWaveMode and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
	waveToggle.Text = "Wave / Dungeon Mode: " .. (isWaveMode and "ON" or "OFF")
	targetDropdownBtn.AutoButtonColor = not isWaveMode
	if isWaveMode then targetDropdownBtn.Text = "[Wave Mode Active]" else updateTargetDropdownText() end
end)

farmToggle.MouseButton1Click:Connect(function()
	isFarming = not isFarming
	farmToggle.BackgroundColor3 = isFarming and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
	farmToggle.Text = "Auto Farm: " .. (isFarming and "ON" or "OFF")
	if isFarming then
		targetContainer.Visible = false
		bindComboPresser()
	else
		if currentTween then currentTween:Cancel() end
		local char = player.Character
		if char then setNoclip(char, false) end
		statusLabel.Text = "Status: Idle"
		lastTargetPos = nil
		lastTargetModel = nil
		lastPressedKeyText = ""
		isTargetInRange = false
	end
end)

questToggle.MouseButton1Click:Connect(function()
	isQuesting = not isQuesting
	questToggle.BackgroundColor3 = isQuesting and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
	questToggle.Text = "Auto Quest: " .. (isQuesting and "ON" or "OFF")
	if isQuesting then questContainer.Visible = false end
end)

transformToggle.MouseButton1Click:Connect(function()
	isAutoTransform = not isAutoTransform
	transformToggle.BackgroundColor3 = isAutoTransform and Color3.fromRGB(50, 180, 50) or Color3.fromRGB(180, 50, 50)
	transformToggle.Text = "Auto Transform: " .. (isAutoTransform and "ON" or "OFF")
	if isAutoTransform then transformContainer.Visible = false triggerTransform() end
end)

game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
	if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
		gui.Enabled = not gui.Enabled
	end
end)

--// Main Render Loop
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
			statusLabel.Text = "Status: Waiting for next wave..."
			lastTargetPos = nil
			isTargetInRange = false
			return
		end
	else
		local activeTargets = getActiveTargetArray()
		if #activeTargets == 0 then
			statusLabel.Text = "Status: No targets selected"
			lastTargetPos = nil
			isTargetInRange = false
			return
		end

		if mobIndex > #activeTargets then mobIndex = 1 end
		local currentTargetData = activeTargets[mobIndex]
		targetModel = findTargetModel(currentTargetData)

		if not isTargetAlive(targetModel) then
			statusLabel.Text = "Status: Searching for " .. currentTargetData.name
			mobIndex += 1
			if mobIndex > #activeTargets then mobIndex = 1 end
			lastTargetPos = nil
			isTargetInRange = false
			return
		end
		targetLocation = currentTargetData.location
	end

	--// SEQUENTIAL DYNAMIC MULTI-QUEST ACCEPTANCE
	if isQuesting and QuestRemote and targetModel then
		if not isInQuest() then
			local mobName = targetModel.Name
			local targetQuest = MOB_QUEST_MAP[mobName]
			
			-- Accept mapped quest if checked in multi-select dropdown
			if targetQuest and selectedQuests[targetQuest] and selectedQuests[targetQuest].selected then
				QuestRemote:FireServer(targetQuest)
			else
				-- Fallback to the first available checked quest from the UI list
				for qName, qData in pairs(selectedQuests) do
					if qData.selected then
						QuestRemote:FireServer(qName)
						break
					end
				end
			end
		end
	end

	statusLabel.Text = "Status: Farming " .. targetModel.Name .. " (" .. targetLocation .. ")"

	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart")
	if not targetRoot then 
		isTargetInRange = false
		return 
	end

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
	local finalCF = CFrame.lookAt(behindPos, lookTarget)

	if currentTween then currentTween:Cancel() end
	currentTween = TweenService:Create(
		hrp,
		TweenInfo.new(TWEEN_TIME, Enum.EasingStyle.Linear),
		{ CFrame = finalCF }
	)
	currentTween:Play()

	local distanceToTarget = (hrp.Position - targetRoot.Position).Magnitude
	if distanceToTarget <= ATTACK_RANGE_THRESHOLD then
		isTargetInRange = true
		if CombatRemote then CombatRemote:FireServer() end
	else
		isTargetInRange = false
	end
end)