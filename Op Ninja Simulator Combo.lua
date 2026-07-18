-- Wrap everything to prevent the main thread from locking up
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local LocalPlayer = Players.LocalPlayer
    
    -- Safe check for UI layer without hanging
    local TargetParent = nil
    local success, coregui = pcall(function() return game:GetService("CoreGui") end)
    if success and coregui then
        TargetParent = coregui
    else
        TargetParent = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
    end
    
    if not TargetParent then return end

    -- Clean up legacy scripts
    local oldScreenGui = TargetParent:FindFirstChild("CustomTPGui")
    if oldScreenGui then oldScreenGui:Destroy() end

    -----------------------------------------
    -- SIMULATOR STATE VARIABLES
    -----------------------------------------
    getgenv().autotrain = false
    getgenv().autoclick = false
    getgenv().autoupgrade = false

    local SelectedTargetName = nil
    local IsLoopTPEnabled = false
    local TPBehindToggle = false
    local LoopConnection = nil
    local TrainConnection = nil 
    local DropdownOpen = false

    -----------------------------------------
    -- UTILITIES
    -----------------------------------------
    local function press(btn)
        if not btn then return end
        pcall(firesignal, btn.MouseButton1Down)
        task.wait()
        pcall(firesignal, btn.MouseButton1Up)
        pcall(firesignal, btn.MouseButton1Click)
    end

    -----------------------------------------
    -- UI CONSTRUCTION
    -----------------------------------------
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "CustomTPGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999
    ScreenGui.Parent = TargetParent

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 250, 0, 425) 
    MainFrame.Position = UDim2.new(0.5, -125, 0.4, -212)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui

    local MainUICorner = Instance.new("UICorner")
    MainUICorner.CornerRadius = UDim.new(0, 8)
    MainUICorner.Parent = MainFrame

    local TopBar = Instance.new("Frame")
    TopBar.Name = "TopBar"
    TopBar.Size = UDim2.new(1, 0, 0, 35)
    TopBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    TopBar.BorderSizePixel = 0
    TopBar.Parent = MainFrame

    local TopUICorner = Instance.new("UICorner")
    TopUICorner.CornerRadius = UDim.new(0, 8)
    TopUICorner.Parent = TopBar

    local FixTopCorner = Instance.new("Frame")
    FixTopCorner.Size = UDim2.new(1, 0, 0, 10)
    FixTopCorner.Position = UDim2.new(0, 0, 1, -10)
    FixTopCorner.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    FixTopCorner.BorderSizePixel = 0
    FixTopCorner.Parent = TopBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -40, 1, 0)
    TitleLabel.Position = UDim2.new(0, 10, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "Ninja Hub All-In-One"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.SourceSansBold
    TitleLabel.TextSize = 16
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TopBar

    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Size = UDim2.new(0, 25, 0, 25)
    MinimizeBtn.Position = UDim2.new(1, -30, 0, 5)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
    MinimizeBtn.Text = "-"
    MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeBtn.Font = Enum.Font.SourceSansBold
    MinimizeBtn.TextSize = 16
    MinimizeBtn.Parent = TopBar

    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 4)
    MinCorner.Parent = MinimizeBtn

    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, 0, 1, -35)
    ContentFrame.Position = UDim2.new(0, 0, 0, 35)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.Parent = MainFrame

    local DropdownBtn = Instance.new("TextButton")
    DropdownBtn.Name = "DropdownBtn"
    DropdownBtn.Size = UDim2.new(1, -20, 0, 35)
    DropdownBtn.Position = UDim2.new(0, 10, 0, 15)
    DropdownBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    DropdownBtn.Text = "Click to Select Player..."
    DropdownBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    DropdownBtn.Font = Enum.Font.SourceSans
    DropdownBtn.TextSize = 14
    DropdownBtn.Parent = ContentFrame

    local DropCorner = Instance.new("UICorner")
    DropCorner.CornerRadius = UDim.new(0, 6)
    DropCorner.Parent = DropdownBtn

    local DropdownList = Instance.new("ScrollingFrame")
    DropdownList.Name = "DropdownList"
    DropdownList.Size = UDim2.new(1, -20, 0, 100)
    DropdownList.Position = UDim2.new(0, 10, 0, 55)
    DropdownList.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    DropdownList.BorderSizePixel = 0
    DropdownList.Visible = false
    DropdownList.ZIndex = 5
    DropdownList.CanvasSize = UDim2.new(0, 0, 0, 0)
    DropdownList.ScrollBarThickness = 4
    DropdownList.Parent = ContentFrame

    local ListLayout = Instance.new("UIListLayout")
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = DropdownList

    local ListCorner = Instance.new("UICorner")
    ListCorner.CornerRadius = UDim.new(0, 6)
    ListCorner.Parent = DropdownList

    local BehindToggleBtn = Instance.new("TextButton")
    BehindToggleBtn.Size = UDim2.new(1, -20, 0, 35)
    BehindToggleBtn.Position = UDim2.new(0, 10, 0, 65)
    BehindToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    BehindToggleBtn.Text = "Lock 3 Studs Behind: OFF"
    BehindToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    BehindToggleBtn.Font = Enum.Font.SourceSansBold
    BehindToggleBtn.TextSize = 14
    BehindToggleBtn.Parent = ContentFrame

    local ToggleCorner1 = Instance.new("UICorner")
    ToggleCorner1.CornerRadius = UDim.new(0, 6)
    ToggleCorner1.Parent = BehindToggleBtn

    local TPToggleBtn = Instance.new("TextButton")
    TPToggleBtn.Size = UDim2.new(1, -20, 0, 45)
    TPToggleBtn.Position = UDim2.new(0, 10, 0, 115)
    TPToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    TPToggleBtn.Text = "Loop Teleport: DISABLED"
    TPToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TPToggleBtn.Font = Enum.Font.SourceSansBold
    TPToggleBtn.TextSize = 16
    TPToggleBtn.Parent = ContentFrame

    local ToggleCorner2 = Instance.new("UICorner")
    ToggleCorner2.CornerRadius = UDim.new(0, 6)
    ToggleCorner2.Parent = TPToggleBtn

    local Divider = Instance.new("Frame")
    Divider.Size = UDim2.new(1, -20, 0, 2)
    Divider.Position = UDim2.new(0, 10, 0, 175)
    Divider.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    Divider.BorderSizePixel = 0
    Divider.Parent = ContentFrame

    local TrainToggleBtn = Instance.new("TextButton")
    TrainToggleBtn.Size = UDim2.new(1, -20, 0, 35)
    TrainToggleBtn.Position = UDim2.new(0, 10, 0, 190)
    TrainToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    TrainToggleBtn.Text = "Auto Train: OFF"
    TrainToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    TrainToggleBtn.Font = Enum.Font.SourceSansBold
    TrainToggleBtn.TextSize = 14
    TrainToggleBtn.Parent = ContentFrame

    local TrainCorner = Instance.new("UICorner")
    TrainCorner.CornerRadius = UDim.new(0, 6)
    TrainCorner.Parent = TrainToggleBtn

    local ClickToggleBtn = Instance.new("TextButton")
    ClickToggleBtn.Size = UDim2.new(1, -20, 0, 35)
    ClickToggleBtn.Position = UDim2.new(0, 10, 0, 235)
    ClickToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    ClickToggleBtn.Text = "Auto Clicker: OFF"
    ClickToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    ClickToggleBtn.Font = Enum.Font.SourceSansBold
    ClickToggleBtn.TextSize = 14
    ClickToggleBtn.Parent = ContentFrame

    local ClickCorner = Instance.new("UICorner")
    ClickCorner.CornerRadius = UDim.new(0, 6)
    ClickCorner.Parent = ClickToggleBtn

    local UpgradeToggleBtn = Instance.new("TextButton")
    UpgradeToggleBtn.Size = UDim2.new(1, -20, 0, 35)
    UpgradeToggleBtn.Position = UDim2.new(0, 10, 0, 280)
    UpgradeToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
    UpgradeToggleBtn.Text = "Auto Upgrade: OFF"
    UpgradeToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    UpgradeToggleBtn.Font = Enum.Font.SourceSansBold
    UpgradeToggleBtn.TextSize = 14
    UpgradeToggleBtn.Parent = ContentFrame

    local UpgradeCorner = Instance.new("UICorner")
    UpgradeCorner.CornerRadius = UDim.new(0, 6)
    UpgradeCorner.Parent = UpgradeToggleBtn

    local PlatformBtn = Instance.new("TextButton")
    PlatformBtn.Size = UDim2.new(1, -20, 0, 35)
    PlatformBtn.Position = UDim2.new(0, 10, 0, 325)
    PlatformBtn.BackgroundColor3 = Color3.fromRGB(45, 65, 90)
    PlatformBtn.Text = "Teleport to Safe South Platform"
    PlatformBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    PlatformBtn.Font = Enum.Font.SourceSansBold
    PlatformBtn.TextSize = 14
    PlatformBtn.Parent = ContentFrame

    local PlatformCorner = Instance.new("UICorner")
    PlatformCorner.CornerRadius = UDim.new(0, 6)
    PlatformCorner.Parent = PlatformBtn

    -----------------------------------------
    -- CORE EVENT LOGIC
    -----------------------------------------
    local dragging, dragInput, dragStart, startPos
    local function update(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    TopBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then update(input) end
    end)

    local isMinimised = false
    MinimizeBtn.MouseButton1Click:Connect(function()
        isMinimised = not isMinimised
        if isMinimised then
            ContentFrame.Visible = false
            MainFrame.Size = UDim2.new(0, 250, 0, 35)
            MinimizeBtn.Text = "+"
            DropdownList.Visible = false
            DropdownOpen = false
        else
            MainFrame.Size = UDim2.new(0, 250, 0, 425)
            ContentFrame.Visible = true
            MinimizeBtn.Text = "-"
        end
    end)

    local function refreshDropdownList()
        for _, child in ipairs(DropdownList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local allPlayers = Players:GetPlayers()
        local generatedCount = 0
        
        for _, p in ipairs(allPlayers) do
            if p ~= LocalPlayer and p.Name ~= "" then
                generatedCount = generatedCount + 1
                local PBtn = Instance.new("TextButton")
                PBtn.Name = "Player_" .. p.Name
                PBtn.Size = UDim2.new(1, 0, 0, 25)
                PBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
                PBtn.BackgroundTransparency = 0.5
                PBtn.Text = p.Name
                PBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                PBtn.Font = Enum.Font.SourceSans
                PBtn.TextSize = 14
                PBtn.ZIndex = 6
                PBtn.Parent = DropdownList
                
                PBtn.MouseButton1Click:Connect(function()
                    SelectedTargetName = p.Name
                    DropdownBtn.Text = "Target: " .. p.Name
                    DropdownList.Visible = false
                    DropdownOpen = false
                end)
            end
        end
        
        if generatedCount == 0 then
            local NoPlayersLabel = Instance.new("TextButton")
            NoPlayersLabel.Size = UDim2.new(1, 0, 0, 25)
            NoPlayersLabel.BackgroundTransparency = 1
            NoPlayersLabel.Text = "No other players found"
            NoPlayersLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            NoPlayersLabel.Font = Enum.Font.SourceSansItalic
            NoPlayersLabel.TextSize = 14
            NoPlayersLabel.ZIndex = 6
            NoPlayersLabel.Parent = DropdownList
            DropdownList.CanvasSize = UDim2.new(0, 0, 0, 25)
        else
            DropdownList.CanvasSize = UDim2.new(0, 0, 0, generatedCount * 25)
        end
    end

    DropdownBtn.MouseButton1Click:Connect(function()
        DropdownOpen = not DropdownOpen
        if DropdownOpen then
            refreshDropdownList()
            DropdownList.Visible = true
        else
            DropdownList.Visible = false
        end
    end)

    -----------------------------------------
    -- TELEPORT RUNNER
    -----------------------------------------
    BehindToggleBtn.MouseButton1Click:Connect(function()
        TPBehindToggle = not TPBehindToggle
        if TPBehindToggle then
            BehindToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
            BehindToggleBtn.Text = "Lock 3 Studs Behind: ON"
        else
            BehindToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
            BehindToggleBtn.Text = "Lock 3 Studs Behind: OFF"
        end
    end)

    local function startLoop()
        if LoopConnection then LoopConnection:Disconnect() end
        LoopConnection = RunService.Heartbeat:Connect(function()
            if not IsLoopTPEnabled or not SelectedTargetName then return end
            local target = Players:FindFirstChild(SelectedTargetName)
            if not target then return end
            
            local myChar = LocalPlayer.Character
            local targetChar = target.Character
            if myChar and targetChar then
                local myRoot = myChar:FindFirstChild("HumanoidRootPart")
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
                if myRoot and targetRoot then
                    if TPBehindToggle then
                        local targetCFrame = targetRoot.CFrame
                        myRoot.CFrame = CFrame.new(targetCFrame.Position + (targetCFrame.LookVector * -3)) * targetCFrame.Rotation
                    else
                        myRoot.CFrame = targetRoot.CFrame
                    end
                end
            end
        end)
    end

    TPToggleBtn.MouseButton1Click:Connect(function()
        IsLoopTPEnabled = not IsLoopTPEnabled
        if IsLoopTPEnabled then
            TPToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
            TPToggleBtn.Text = "Loop Teleport: ENABLED"
            startLoop()
        else
            TPToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
            TPToggleBtn.Text = "Loop Teleport: DISABLED"
            if LoopConnection then LoopConnection:Disconnect(); LoopConnection = nil end
        end
    end)

    -----------------------------------------
    -- SAFE SOUTH VOID PLATFORM LOGIC (Anti-Spam)
    -----------------------------------------
    PlatformBtn.MouseButton1Click:Connect(function()
        local platformName = "SafeTrainingPlatform"
        local platform = workspace:FindFirstChild(platformName)
        
        -- Positioned exactly 10,000 studs South and slightly elevated to clear assets cleanly
        local targetCFrame = CFrame.new(0, 50, 10000) 

        -- Prevent spamming identical Parts into client memory
        if not platform then
            platform = Instance.new("Part")
            platform.Name = platformName
            platform.Size = Vector3.new(20, 2, 20) 
            platform.CFrame = targetCFrame
            platform.Anchored = true
            platform.Material = Enum.Material.SmoothPlastic
            platform.Color = Color3.fromRGB(40, 45, 50)
            platform.Parent = workspace
        end

        -- Safe character deployment offset
        local character = LocalPlayer.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                rootPart.CFrame = targetCFrame + Vector3.new(0, 4, 0)
            end
        end
    end)

    -----------------------------------------
    -- RENDERSTEPPED AUTO TRAIN
    -----------------------------------------
    TrainToggleBtn.MouseButton1Click:Connect(function()
        getgenv().autotrain = not getgenv().autotrain
        if getgenv().autotrain then
            TrainToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
            TrainToggleBtn.Text = "Auto Train: ON"
            
            if TrainConnection then TrainConnection:Disconnect() end
            TrainConnection = RunService.RenderStepped:Connect(function()
                local character = LocalPlayer.Character
                if character then
                    -- Fires weapon triggers immediately on every frame update cycle
                    local equippedTool = character:FindFirstChildOfClass("Tool")
                    if equippedTool then
                        equippedTool:Activate()
                    end
                end
            end)
        else
            TrainToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
            TrainToggleBtn.Text = "Auto Train: OFF"
            if TrainConnection then 
                TrainConnection:Disconnect() 
                TrainConnection = nil 
            end
        end
    end)

    -----------------------------------------
    -- BOT THREADS (SAFETY LOOPS)
    -----------------------------------------
    ClickToggleBtn.MouseButton1Click:Connect(function()
        getgenv().autoclick = not getgenv().autoclick
        if getgenv().autoclick then
            ClickToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
            ClickToggleBtn.Text = "Auto Clicker: ON"
        else
            ClickToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
            ClickToggleBtn.Text = "Auto Clicker: OFF"
        end
    end)

    task.spawn(function()
        while true do
            if getgenv().autoclick then
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                if playerGui then
                    local pvpProtectionHud = playerGui:FindFirstChild("PvPProtectionHud")
                    local pvpBtn = pvpProtectionHud and pvpProtectionHud:FindFirstChild("Btn")

                    local mainGui = playerGui:FindFirstChild("MainGui")
                    local spawnF = mainGui and mainGui:FindFirstChild("SpawnF")
                    local randomSpawnImgBtn = spawnF and spawnF:FindFirstChild("RandomSpawnImgBtn")

                    if pvpBtn and pvpBtn.Visible then
                        press(pvpBtn)
                        task.wait()
                    end

                    if randomSpawnImgBtn and randomSpawnImgBtn.Visible then
                        press(randomSpawnImgBtn)
                        task.wait()
                    end
                end
            end
            task.wait()
        end
    end)

    UpgradeToggleBtn.MouseButton1Click:Connect(function()
        getgenv().autoupgrade = not getgenv().autoupgrade
        if getgenv().autoupgrade then
            UpgradeToggleBtn.BackgroundColor3 = Color3.fromRGB(30, 60, 30)
            UpgradeToggleBtn.Text = "Auto Upgrade: ON"
        else
            UpgradeToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
            UpgradeToggleBtn.Text = "Auto Upgrade: OFF"
        end
    end)

    task.spawn(function()
        while true do
            if getgenv().autoupgrade then
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local mainGui = playerGui and playerGui:FindFirstChild("MainGui")
                local upgradeF = mainGui and mainGui:FindFirstChild("UpgradeF")
                
                if upgradeF then
                    local swordF = upgradeF:FindFirstChild("SwordF")
                    local maxUpgradeBtn = swordF and swordF:FindFirstChild("MaxUpgradeBtn")
                    if maxUpgradeBtn and maxUpgradeBtn.Visible then
                        press(maxUpgradeBtn)
                    end

                    local classF = upgradeF:FindFirstChild("ClassF")
                    local classImgBtn = classF and classF:FindFirstChild("ClassImgBtn")
                    if classImgBtn and classImgBtn.Visible then
                        press(classImgBtn)
                    end

                    local ascendF = upgradeF:FindFirstChild("AscendF")
                    local ascendImgBtn = ascendF and ascendF:FindFirstChild("AscendImgBtn")
                    if ascendImgBtn and ascendImgBtn.Visible then
                        press(ascendImgBtn)
                    end
                end
            end
            task.wait(1)
        end
    end)
end)