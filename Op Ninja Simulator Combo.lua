-- Wrap execution cleanly to isolate local variables and protect the main thread
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

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

    -----------------------------------------
    -- UTILITIES & OPTIMIZATIONS
    -----------------------------------------
    local function press(btn)
        if not btn or not btn.Visible then return end
        pcall(firesignal, btn.MouseButton1Down)
        task.wait()
        pcall(firesignal, btn.MouseButton1Up)
        pcall(firesignal, btn.MouseButton1Click)
    end

    local function getPlayerNames()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Name ~= "" then
                table.insert(names, p.Name)
            end
        end
        if #names == 0 then table.insert(names, "No other players found") end
        return names
    end

    -----------------------------------------
    -- INITIALIZE RAYFIELD
    -----------------------------------------
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    
    local Window = Rayfield:CreateWindow({
        Name = "Ninja Hub | Ultimate Edition",
        LoadingTitle = "Ninja Hub loading...",
        LoadingSubtitle = "Secure Mode Enabled",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "NinjaHubData",
            FileName = "SafeSave"
        },
        Discord = {
            Enabled = false,
            Invite = "",
            RememberJoins = false
        },
        KeySystem = false,
        SecureMode = true,
        Keybind = Enum.KeyCode.RightControl,
        AntiDetection = true
    })

    -----------------------------------------
    -- UI TABS SETUP
    -----------------------------------------
    local MainTab = Window:CreateTab("Combat & Target", 4483362458)
    local AutomationTab = Window:CreateTab("Automation & Safe Zone", 4483362458)
    local MiscTab = Window:CreateTab("Misc & Tools", 4483362458)

    -----------------------------------------
    -- TARGET TELEPORT ROUTINE
    -----------------------------------------
    local function startLoop()
        if LoopConnection then LoopConnection:Disconnect() end
        LoopConnection = RunService.Heartbeat:Connect(function()
            if not IsLoopTPEnabled or not SelectedTargetName then return end
            local target = Players:FindFirstChild(SelectedTargetName)
            local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if myRoot and targetRoot then
                if TPBehindToggle then
                    local targetCFrame = targetRoot.CFrame
                    myRoot.CFrame = CFrame.new(targetCFrame.Position + (targetCFrame.LookVector * -3)) * targetCFrame.Rotation
                else
                    myRoot.CFrame = targetRoot.CFrame
                end
            end
        end)
    end

    -----------------------------------------
    -- TAB 1 ELEMENTS: COMBAT & TELEPORT
    -----------------------------------------
    local PlayerDropdown = MainTab:CreateDropdown({
        Name = "Select Target Player",
        Options = getPlayerNames(),
        CurrentOption = {""},
        MultipleOptions = false,
        Flag = "TargetDropdown",
        Callback = function(Options)
            local choice = Options[1]
            SelectedTargetName = (choice and choice ~= "No other players found" and choice ~= "") and choice or nil
        end,
    })

    local function updateDropdown()
        if PlayerDropdown then PlayerDropdown:Refresh(getPlayerNames(), true) end
    end
    Players.PlayerAdded:Connect(updateDropdown)
    Players.PlayerRemoving:Connect(updateDropdown)

    MainTab:CreateToggle({
        Name = "Lock 3 Studs Behind Target",
        CurrentValue = false,
        Flag = "BehindToggle",
        Callback = function(Value)
            TPBehindToggle = Value
        end,
    })

    MainTab:CreateToggle({
        Name = "Loop Teleport to Player",
        CurrentValue = false,
        Flag = "LPToggle",
        Callback = function(Value)
            IsLoopTPEnabled = Value
            if IsLoopTPEnabled then
                startLoop()
            else
                if LoopConnection then LoopConnection:Disconnect(); LoopConnection = nil end
            end
        end,
    })

    -----------------------------------------
    -- TAB 2 ELEMENTS: AUTOMATION & SAFE PLATFORM
    -----------------------------------------
    AutomationTab:CreateToggle({
        Name = "Auto Train (Frame Optimized)",
        CurrentValue = false,
        Flag = "TrainToggle",
        Callback = function(Value)
            getgenv().autotrain = Value
            if getgenv().autotrain then
                if TrainConnection then TrainConnection:Disconnect() end
                TrainConnection = RunService.RenderStepped:Connect(function()
                    local equippedTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if equippedTool then
                        equippedTool:Activate()
                    end
                end)
            else
                if TrainConnection then 
                    TrainConnection:Disconnect() 
                    TrainConnection = nil 
                end
            end
        end,
    })

    AutomationTab:CreateToggle({
        Name = "Auto Clicker (Spawn/PvP Skip)",
        CurrentValue = false,
        Flag = "ClickToggle",
        Callback = function(Value)
            getgenv().autoclick = Value
        end,
    })

    AutomationTab:CreateToggle({
        Name = "Auto Upgrade All",
        CurrentValue = false,
        Flag = "UpgradeToggle",
        Callback = function(Value)
            getgenv().autoupgrade = Value
        end
    })

    AutomationTab:CreateButton({
        Name = "Teleport to Safe South Platform (10,000 Studs)",
        Callback = function()
            local platformName = "SafeTrainingPlatform"
            local platform = workspace:FindFirstChild(platformName)
            local targetCFrame = CFrame.new(0, 50, 10000) 

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

            local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                rootPart.CFrame = targetCFrame + Vector3.new(0, 4, 0)
            end
        end,
    })

    -----------------------------------------
    -- TAB 3 ELEMENTS: MISC & UTILITIES
    -----------------------------------------
    MiscTab:CreateButton({
        Name = "Run Anti-AFK Script",
        Callback = function()
            -- Removed protective suppression so error alerts reveal exactly why a script fails to execute
            local success, content = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/TRcalled/RbxScripts/refs/heads/main/Roblox%20Anti%20AFK%20script.lua")
            end)
            
            if success and content then
                local func, err = loadstring(content)
                if func then
                    task.spawn(func)
                else
                    warn("Compile error in Anti-AFK: " .. tostring(err))
                end
            else
                warn("Failed to fetch Anti-AFK script: " .. tostring(content))
            end
        end,
    })

    MiscTab:CreateButton({
        Name = "Run FPS Booster",
        Callback = function()
            local success, content = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/TRcalled/RbxScripts/refs/heads/main/Fps%20Booster_Loader.lua")
            end)
            
            if success and content then
                local func, err = loadstring(content)
                if func then
                    task.spawn(func)
                else
                    warn("Compile error in FPS Booster: " .. tostring(err))
                end
            else
                warn("Failed to fetch FPS Booster script: " .. tostring(content))
            end
        end,
    })

    -----------------------------------------
    -- INTERMITTENT AUTOMATION LOOPS
    -----------------------------------------
    task.spawn(function()
        while true do
            if getgenv().autoclick then
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                if playerGui then
                    local pvpBtn = playerGui:FindFirstChild("PvPProtectionHud", true) and playerGui.PvPProtectionHud:FindFirstChild("Btn")
                    local randomSpawnBtn = playerGui:FindFirstChild("SpawnF", true) and playerGui.SpawnF:FindFirstChild("RandomSpawnImgBtn")

                    press(pvpBtn)
                    press(randomSpawnBtn)
                end
            end
            task.wait(0.1)
        end
    end)

    task.spawn(function()
        while true do
            if getgenv().autoupgrade then
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local upgradeF = playerGui and playerGui:FindFirstChild("UpgradeF", true)
                
                if upgradeF then
                    press(upgradeF:FindFirstChild("MaxUpgradeBtn", true))
                    press(upgradeF:FindFirstChild("ClassImgBtn", true))
                    press(upgradeF:FindFirstChild("AscendImgBtn", true))
                end
            end
            task.wait(1)
        end
    end)
end)
