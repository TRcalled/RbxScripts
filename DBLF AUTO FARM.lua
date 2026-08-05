--// UI & Services Setup
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Clean up existing UI if re-executed
if CoreGui:FindFirstChild("IceSeaFarmGui") then
	CoreGui.IceSeaFarmGui:Destroy()
end

--// THEME COLORS (Ice + Sea Palette)
local THEME = {
	MainBG = Color3.fromRGB(12, 18, 28),
	HeaderBG = Color3.fromRGB(18, 28, 44),
	CardBG = Color3.fromRGB(22, 34, 52),
	AccentCyan = Color3.fromRGB(0, 210, 255),
	AccentBlue = Color3.fromRGB(0, 132, 255),
	TabInactive = Color3.fromRGB(20, 30, 46),
	TabActive = Color3.fromRGB(0, 132, 255),
	ToggleON = Color3.fromRGB(0, 180, 216),
	ToggleOFF = Color3.fromRGB(28, 42, 62),
	TextMain = Color3.fromRGB(230, 245, 255),
	TextMuted = Color3.fromRGB(130, 160, 190)
}

--// MOB TO QUEST MAPPING
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

--// ScreenGui Creation
local gui = Instance.new("ScreenGui")
gui.Name = "IceSeaFarmGui"
gui.ResetOnSpawn = false
gui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 310, 0, 310)
mainFrame.Position = UDim2.new(0.5, -155, 0.35, -155)
mainFrame.BackgroundColor3 = THEME.MainBG
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = THEME.AccentCyan
mainStroke.Transparency = 0.6
mainStroke.Thickness = 1.2
mainStroke.Parent = mainFrame

--// Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.BackgroundColor3 = THEME.HeaderBG
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 10)
titleCorner.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -40, 1, 0)
titleText.Position = UDim2.new(0, 12, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "🌊 ICE & SEA HUB"
titleText.TextColor3 = THEME.AccentCyan
titleText.TextSize = 14
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Minimize Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
minimizeBtn.Position = UDim2.new(1, -31, 0, 5)
minimizeBtn.BackgroundColor3 = THEME.CardBG
minimizeBtn.Text = "—"
minimizeBtn.TextColor3 = THEME.TextMain
minimizeBtn.TextSize = 12
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = titleBar

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = minimizeBtn

-- Body Container (Collapsible)
local bodyContainer = Instance.new("Frame")
bodyContainer.Size = UDim2.new(1, 0, 1, -36)
bodyContainer.Position = UDim2.new(0, 0, 0, 36)
bodyContainer.BackgroundTransparency = 1
bodyContainer.Parent = mainFrame

local isMinimized = false
local function toggleMinimize()
	isMinimized = not isMinimized
	bodyContainer.Visible = not isMinimized
	mainFrame.Size = isMinimized and UDim2.new(0, 310, 0, 36) or UDim2.new(0, 310, 0, 310)
	minimizeBtn.Text = isMinimized and "+" or "—"
end
minimizeBtn.MouseButton1Click:Connect(toggleMinimize)

--// Navigation Tab Bar
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(0.92, 0, 0, 28)
tabBar.Position = UDim2.new(0.04, 0, 0, 6)
tabBar.BackgroundTransparency = 1
tabBar.Parent = bodyContainer

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = tabBar

-- Tab Pages Holder
local pagesContainer = Instance.new("Frame")
pagesContainer.Size = UDim2.new(0.92, 0, 0, 220)
pagesContainer.Position = UDim2.new(0.04, 0, 0, 40)
pagesContainer.BackgroundTransparency = 1
pagesContainer.Parent = bodyContainer

local tabs = {}
local pages = {}

local function createTabPage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name .. "Page"
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = THEME.AccentCyan
	page.CanvasSize = UDim2.new(0, 0, 0, 0)
	page.Parent = pagesContainer

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = page

	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end)

	pages[name] = page
	return page
end

local function selectTab(tabName)
	for name, btn in pairs(tabs) do
		local isSel = (name == tabName)
		btn.BackgroundColor3 = isSel and THEME.TabActive or THEME.TabInactive
		btn.TextColor3 = isSel and Color3.fromRGB(255, 255, 255) or THEME.TextMuted
		if pages[name] then pages[name].Visible = isSel end
	end
end

local function addTabButton(name, displayName)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.31, 0, 1, 0)
	btn.BackgroundColor3 = THEME.TabInactive
	btn.Text = displayName
	btn.TextColor3 = THEME.TextMuted
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamSemibold
	btn.Parent = tabBar

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	tabs[name] = btn
	btn.MouseButton1Click:Connect(function()
		selectTab(name)
	end)
end

-- Create Pages & Buttons
createTabPage("Farm")
createTabPage("Forms")
createTabPage("Settings")

addTabButton("Farm", "⚔️ Farm")
addTabButton("Forms", "🔥 Forms")
addTabButton("Settings", "⚙️ Config")

selectTab("Farm")

--// UI HELPER BUILDERS
local function createToggleButton(parent, text, defaultVal, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = defaultVal and THEME.ToggleON or THEME.ToggleOFF
	btn.Text = text .. ": " .. (defaultVal and "ON" or "OFF")
	btn.TextColor3 = THEME.TextMain
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamBold
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	local state = defaultVal
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.BackgroundColor3 = state and THEME.ToggleON or THEME.ToggleOFF
		btn.Text = text .. ": " .. (state and "ON" or "OFF")
		callback(state)
	end)
	return btn
end

local function createInputRow(parent, labelText, defaultVal, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.BackgroundColor3 = THEME.CardBG
	frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.65, -10, 1, 0)
	label.Position = UDim2.new(0, 10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = THEME.TextMuted
	label.TextSize = 11
	label.Font = Enum.Font.GothamSemibold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(0.3, 0, 0.7, 0)
	box.Position = UDim2.new(0.67, 0, 0.15, 0)
	box.BackgroundColor3 = THEME.HeaderBG
	box.Text = tostring(defaultVal)
	box.TextColor3 = THEME.AccentCyan
	box.TextSize = 11
	box.Font = Enum.Font.GothamBold
	box.ClearTextOnFocus = false
	box.Parent = frame

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 4)
	boxCorner.Parent = box

	box.FocusLost:Connect(function()
		local val = tonumber(box.Text)
		if val then callback(val) else box.Text = tostring(defaultVal) end
	end)
end

--// LOGIC VARIABLES
local selectedTargets = {}
local selectedTransform = TRANSFORM_LIST[1] or ""

local isFarming = false
local isQuesting = false
local isWaveMode = false
local isAutoTransform = false
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

--// COMBO PRESSER
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

--// TAB 1: FARM CONTROLS

-- 1. Targets Dropdown
local targetDropdownBtn = Instance.new("TextButton")
targetDropdownBtn.Size = UDim2.new(1, 0, 0, 32)
targetDropdownBtn.BackgroundColor3 = THEME.CardBG
targetDropdownBtn.Text = "🎯 Target: Select Targets..."
targetDropdownBtn.TextColor3 = THEME.TextMain
targetDropdownBtn.TextSize = 11
targetDropdownBtn.Font = Enum.Font.GothamSemibold
targetDropdownBtn.Parent = pages["Farm"]

local targetDdCorner = Instance.new("UICorner")
targetDdCorner.CornerRadius = UDim.new(0, 6)
targetDdCorner.Parent = targetDropdownBtn

local targetContainer = Instance.new("ScrollingFrame")
targetContainer.Size = UDim2.new(1, 0, 0, 90)
targetContainer.BackgroundColor3 = THEME.HeaderBG
targetContainer.Visible = false
targetContainer.ScrollBarThickness = 3
targetContainer.ScrollBarImageColor3 = THEME.AccentCyan
targetContainer.ZIndex = 5
targetContainer.Parent = pages["Farm"]

local targetLayout = Instance.new("UIListLayout")
targetLayout.SortOrder = Enum.SortOrder.LayoutOrder
targetLayout.Parent = targetContainer

local function updateTargetDropdownText()
	local selectedList = {}
	for key, data in pairs(selectedTargets) do
		if data.selected then table.insert(selectedList, data.name) end
	end
	targetDropdownBtn.Text = #selectedList == 0 and "🎯 Target: Select Targets..." or "🎯 Targets (" .. #selectedList .. ")"
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
		btn.BackgroundColor3 = THEME.CardBG
		local isSel = selectedTargets[key].selected
		btn.Text = (isSel and " [✓] " or " [ ] ") .. item.name
		btn.TextColor3 = isSel and THEME.AccentCyan or THEME.TextMuted
		btn.TextSize = 11
		btn.Font = Enum.Font.Gotham
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.ZIndex = 6
		btn.Parent = targetContainer

		btn.MouseButton1Click:Connect(function()
			selectedTargets[key].selected = not selectedTargets[key].selected
			local newState = selectedTargets[key].selected
			btn.Text = (newState and " [✓] " or " [ ] ") .. item.name
			btn.TextColor3 = newState and THEME.AccentCyan or THEME.TextMuted
			updateTargetDropdownText()
		end)
	end
	targetContainer.CanvasSize = UDim2.new(0, 0, 0, targetLayout.AbsoluteContentSize.Y)
end

targetDropdownBtn.MouseButton1Click:Connect(function()
	targetContainer.Visible = not targetContainer.Visible
	if targetContainer.Visible then populateTargets() end
end)

createToggleButton(pages["Farm"], "Auto Farm", false, function(state)
	isFarming = state
	if isFarming then
		targetContainer.Visible = false
		bindComboPresser()
	else
		local char = player.Character
		if char then setNoclip(char, false) end
		lastTargetPos = nil
		lastTargetModel = nil
		lastPressedKeyText = ""
		isTargetInRange = false
	end
end)

createToggleButton(pages["Farm"], "Wave Mode", false, function(state)
	isWaveMode = state
	targetDropdownBtn.Visible = not isWaveMode
	if isWaveMode then targetContainer.Visible = false end
end)

createToggleButton(pages["Farm"], "Auto Quest", false, function(state)
	isQuesting = state
end)

--// TAB 2: FORM CONTROLS

local transformDropdownBtn = Instance.new("TextButton")
transformDropdownBtn.Size = UDim2.new(1, 0, 0, 32)
transformDropdownBtn.BackgroundColor3 = THEME.CardBG
transformDropdownBtn.Text = "⚡ Form: " .. (selectedTransform ~= "" and selectedTransform or "Select Form...")
transformDropdownBtn.TextColor3 = THEME.TextMain
transformDropdownBtn.TextSize = 11
transformDropdownBtn.Font = Enum.Font.GothamSemibold
transformDropdownBtn.Parent = pages["Forms"]

local transformDdCorner = Instance.new("UICorner")
transformDdCorner.CornerRadius = UDim.new(0, 6)
transformDdCorner.Parent = transformDropdownBtn

local transformContainer = Instance.new("ScrollingFrame")
transformContainer.Size = UDim2.new(1, 0, 0, 90)
transformContainer.BackgroundColor3 = THEME.HeaderBG
transformContainer.Visible = false
transformContainer.ScrollBarThickness = 3
transformContainer.ScrollBarImageColor3 = THEME.AccentCyan
transformContainer.ZIndex = 5
transformContainer.Parent = pages["Forms"]

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
		btn.BackgroundColor3 = THEME.CardBG
		btn.Text = "  " .. formName
		btn.TextColor3 = (selectedTransform == formName) and THEME.AccentCyan or THEME.TextMuted
		btn.TextSize = 11
		btn.Font = Enum.Font.Gotham
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.ZIndex = 6
		btn.Parent = transformContainer

		btn.MouseButton1Click:Connect(function()
			selectedTransform = formName
			transformDropdownBtn.Text = "⚡ Form: " .. formName
			transformContainer.Visible = false
		end)
	end
	transformContainer.CanvasSize = UDim2.new(0, 0, 0, transformLayout.AbsoluteContentSize.Y)
end

transformDropdownBtn.MouseButton1Click:Connect(function()
	transformContainer.Visible = not transformContainer.Visible
	if transformContainer.Visible then populateTransforms() end
end)

local function getTransformRemote(formName)
	local ssjsFolder = ReplicatedStorage:FindFirstChild("ssjs")
	return ssjsFolder and ssjsFolder:FindFirstChild(formName)
end

local function triggerTransform()
	if not isAutoTransform or selectedTransform == "" then return end
	local remote = getTransformRemote(selectedTransform)
	if remote then remote:FireServer() end
end

createToggleButton(pages["Forms"], "Auto Transform", false, function(state)
	isAutoTransform = state
	if isAutoTransform then
		transformContainer.Visible = false
		triggerTransform()
	end
end)

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

--// TAB 3: SETTINGS & CONFIG

createInputRow(pages["Settings"], "Prediction Lead (s)", predictionLead, function(val)
	predictionLead = math.clamp(val, 0, 1.0)
end)

createInputRow(pages["Settings"], "Knockback Buffer", knockbackBuffer, function(val)
	knockbackBuffer = math.clamp(val, 0, 15.0)
end)

local statusCard = Instance.new("Frame")
statusCard.Size = UDim2.new(1, 0, 0, 48)
statusCard.BackgroundColor3 = THEME.CardBG
statusCard.Parent = pages["Settings"]

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 6)
statusCorner.Parent = statusCard

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 20)
statusLabel.Position = UDim2.new(0, 8, 0, 4)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Idle"
statusLabel.TextColor3 = THEME.TextMuted
statusLabel.TextSize = 10
statusLabel.Font = Enum.Font.GothamSemibold
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = statusCard

local noteLabel = Instance.new("TextLabel")
noteLabel.Size = UDim2.new(1, -16, 0, 18)
noteLabel.Position = UDim2.new(0, 8, 0, 24)
noteLabel.BackgroundTransparency = 1
noteLabel.Text = "Press 'Right Control' to Toggle UI"
noteLabel.TextColor3 = THEME.AccentCyan
noteLabel.TextSize = 10
noteLabel.Font = Enum.Font.Gotham
noteLabel.TextXAlignment = Enum.TextXAlignment.Left
noteLabel.Parent = statusCard

UserInputService.InputBegan:Connect(function(input, gpe)
	if not gpe and input.KeyCode == Enum.KeyCode.RightControl then
		toggleMinimize()
	end
end)

--// MAIN RENDER LOOP
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
			statusLabel.Text = "Status: Waiting for wave..."
			lastTargetPos = nil
			isTargetInRange = false
			return
		end
	else
		local activeTargets = getActiveTargetArray()
		if #activeTargets == 0 then
			statusLabel.Text = "Status: No target selected"
			lastTargetPos = nil
			isTargetInRange = false
			return
		end

		if mobIndex > #activeTargets then mobIndex = 1 end
		local currentTargetData = activeTargets[mobIndex]
		targetModel = findTargetModel(currentTargetData)

		if not isTargetAlive(targetModel) then
			statusLabel.Text = "Status: Searching " .. currentTargetData.name
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

	statusLabel.Text = "Status: Farming " .. targetModel.Name

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
