-- Wrap execution cleanly to isolate local variables and protect the main thread
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local TextService = game:GetService("TextService")
    local CoreGui = game:GetService("CoreGui")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    -----------------------------------------
    -- SIMULATOR STATE VARIABLES
    -----------------------------------------
    getgenv().autotrain = false
    getgenv().autoclick = false
    getgenv().autoupgrade = false
    getgenv().AntiAFKRunning = false

    -- Webhook State Config
    local WebhookURL = ""
    local WebhookEnabled = false
    local WebhookInterval = 60 
    local NextWebhookTime = 0

    local SelectedTargetName = nil
    local IsLoopTPEnabled = false
    local TPBehindToggle = false
    local LoopConnection = nil
    local TrainConnection = nil 

    -----------------------------------------
    -- ADVANCED CUSTOM BLUE NOTIFICATION LAYER
    -----------------------------------------
    local NotifGui = Instance.new("ScreenGui")
    NotifGui.Name = "NinjaHubModernUI"
    NotifGui.ResetOnSpawn = false
    
    if not pcall(function() NotifGui.Parent = CoreGui end) then
        NotifGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local NotifContainer = Instance.new("Frame", NotifGui)
    NotifContainer.Name = "Container"
    NotifContainer.Size = UDim2.new(0, 300, 1, 0)
    NotifContainer.Position = UDim2.new(1, -320, 0, 0)
    NotifContainer.BackgroundTransparency = 1

    local UIListLayout = Instance.new("UIListLayout", NotifContainer)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    UIListLayout.Padding = UDim.new(0, 10)

    Instance.new("UIPadding", NotifContainer).PaddingBottom = UDim.new(0, 20)

    local function CustomNotify(title, text, duration)
        duration = duration or 4

        local Wrapper = Instance.new("Frame", NotifContainer)
        Wrapper.Size = UDim2.new(1, 0, 0, 0)
        Wrapper.BackgroundTransparency = 1
        Wrapper.ClipsDescendants = true

        local Inner = Instance.new("Frame", Wrapper)
        Inner.Size = UDim2.new(1, 0, 1, 0)
        Inner.Position = UDim2.new(1, 50, 0, 0)
        Inner.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        Inner.BackgroundTransparency = 0.15
        Instance.new("UICorner", Inner).CornerRadius = UDim.new(0, 8)
        
        local Stroke = Instance.new("UIStroke", Inner)
        Stroke.Color = Color3.fromRGB(0, 140, 255)
        Stroke.Transparency = 0.4
        Stroke.Thickness = 1.5

        local TitleLabel = Instance.new("TextLabel", Inner)
        TitleLabel.Size = UDim2.new(1, -30, 0, 20)
        TitleLabel.Position = UDim2.new(0, 15, 0, 8)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.Text = tostring(title):upper()
        TitleLabel.TextColor3 = Color3.fromRGB(100, 180, 255)
        TitleLabel.TextSize = 13
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

        local BodyLabel = Instance.new("TextLabel", Inner)
        BodyLabel.Size = UDim2.new(1, -30, 1, -35)
        BodyLabel.Position = UDim2.new(0, 15, 0, 28)
        BodyLabel.BackgroundTransparency = 1
        BodyLabel.Font = Enum.Font.Gotham
        BodyLabel.Text = text
        BodyLabel.TextColor3 = Color3.fromRGB(225, 225, 230)
        BodyLabel.TextSize = 12
        BodyLabel.TextWrapped = true
        BodyLabel.TextXAlignment = Enum.TextXAlignment.Left
        BodyLabel.TextYAlignment = Enum.TextYAlignment.Top

        -- Context-aware clean sizing calculation based on layout boundaries
        local textHeight = TextService:GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(270, math.huge)).Y
        local targetHeight = math.max(65, textHeight + 42)

        TweenService:Create(Wrapper, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
        TweenService:Create(Inner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

        task.delay(duration, function()
            if not Inner or not Wrapper then return end
            TweenService:Create(Inner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 50, 0, 0), BackgroundTransparency = 1}):Play()
            TweenService:Create(Stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
            TweenService:Create(TitleLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            TweenService:Create(BodyLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            task.wait(0.3)
            
            local closeTween = TweenService:Create(Wrapper, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0)})
            closeTween:Play()
            closeTween.Completed:Wait()
            Wrapper:Destroy()
        end)
    end

    -----------------------------------------
    -- NUMBER FORMATTING WITH EXTENDED SUFFIX SUPPORT
    -----------------------------------------
    local suffixes = {
        {1e120, "NoTg"}, {1e117, "OcTg"}, {1e114, "SpTg"}, {1e111, "SxTg"}, {1e108, "QnTg"}, {1e105, "QdTg"}, {1e102, "TTg"}, {1e99, "DTg"}, {1e96, "UTg"}, {1e93, "Tg"},
        {1e90, "NoVt"}, {1e87, "OcVt"}, {1e84, "SpVt"}, {1e81, "SxVt"}, {1e78, "QnVt"}, {1e75, "QdVt"}, {1e72, "TVt"}, {1e69, "DVt"}, {1e66, "UVt"}, {1e63, "Vt"},
        {1e60, "NoDe"}, {1e57, "OcDe"}, {1e54, "SpDe"}, {1e51, "SxDe"}, {1e48, "QnDe"}, {1e45, "QdDe"}, {1e42, "TDe"}, {1e39, "DDe"}, {1e36, "UDe"}, {1e33, "De"},
        {1e30, "No"}, {1e27, "Oc"}, {1e24, "Sp"}, {1e21, "Sx"}, {1e18, "Qn"}, {1e15, "Qd"}, {1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}
    }

    local function formatNumber(num)
        num = tonumber(num) or 0
        if num < 1000 then return tostring(num) end
        for _, v in ipairs(suffixes) do
            if num >= v[1] then
                return string.format("%.2f%s", num / v[1], v[2])
            end
        end
        return tostring(num)
    end

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

    local function getStatValue(path, key)
        local folder = LocalPlayer:FindFirstChild(path)
        local stat = folder and folder:FindFirstChild(key)
        return stat and stat.Value or 0
    end

    -----------------------------------------
    -- STATS INITIALIZATION
    -----------------------------------------
    local initialStats = {
        Ninjutsu = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0,
        SoulForce = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0,
        Power = tonumber(getStatValue("leaderstats", "Power")) or 0
    }

    local previousStats = {
        Ninjutsu = initialStats.Ninjutsu,
        SoulForce = initialStats.SoulForce,
        Power = initialStats.Power
    }

    -----------------------------------------
    -- DISCORD WEBHOOK SENDER
    -----------------------------------------
    local function sendStatsWebhook()
        if WebhookURL == "" or not string.match(WebhookURL, "^https://") then return end

        local currentNinjutsu = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0
        local currentSoul = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0
        local currentPower = tonumber(getStatValue("leaderstats", "Power")) or 0
        
        local currentClass = tostring(getStatValue("leaderstats", "Class"))
        local currentHonor = tonumber(getStatValue("leaderstats", "Honor")) or 0
        local currentRealm = tostring(getStatValue("leaderstats", "Realm"))

        local ninjutsuGained = currentNinjutsu - initialStats.Ninjutsu
        local soulGained = currentSoul - initialStats.SoulForce
        local powerGained = currentPower - initialStats.Power

        local data = {
            ["embeds"] = {{
                ["title"] = "🥷 Ninja Hub | Live Performance Status",
                ["description"] = "Real-time character metrics update log for **" .. LocalPlayer.Name .. "**.",
                ["color"] = 32767,
                ["fields"] = {
                    {["name"] = "📈 Combat Statistics", ["value"] = "• **Power:** " .. formatNumber(currentPower) .. " *(+" .. formatNumber(powerGained) .. ")*\n• **Ninjutsu:** " .. formatNumber(currentNinjutsu) .. " *(+" .. formatNumber(ninjutsuGained) .. ")*\n• **Soul Force:** " .. formatNumber(currentSoul) .. " *(+" .. formatNumber(soulGained) .. ")*", ["inline"] = false},
                    {["name"] = "🏆 Identity & Rankings", ["value"] = "• **Class:** " .. currentClass .. "\n• **Realm:** " .. currentRealm .. "\n• **Honor:** " .. formatNumber(currentHonor), ["inline"] = false}
                },
                ["footer"] = {["text"] = "Ninja Hub Ultimate Tracking System • Execution Mode"},
                ["timestamp"] = DateTime.now():ToIsoDate()
            }}
        }

        local request = (syn and syn.request) or (http and http.request) or http_request or request
        if request then
            task.spawn(function()
                pcall(request, {
                    Url = WebhookURL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(data)
                })
            end)
        else
            warn("Exploit executor does not support HTTP post requests.")
        end
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
    local StatsTab = Window:CreateTab("Stats Tracker", 4483362458)
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
            if SelectedTargetName then
                CustomNotify("Target System", "Locked on to " .. SelectedTargetName .. "! Ready for deployment.", 4)
            else
                CustomNotify("Target System", "Cleared targeted player configuration.", 3)
            end
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
            if Value then
                CustomNotify("Combat Strategy", "Positioning changed! You will now automatically tail right behind your target.", 4)
            else
                CustomNotify("Combat Strategy", "Returned targeting positions back to default center-stacking.", 3)
            end
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
                CustomNotify("Teleport Engine", "Teleport loop is active! Sticky attachment lock initiated on your target.", 4)
            else
                if LoopConnection then LoopConnection:Disconnect(); LoopConnection = nil end
                CustomNotify("Teleport Engine", "Teleport tracking sequence safely turned off.", 3)
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
                CustomNotify("Auto Train", "Training routine activated at maximum speed using render frame ticks.", 4)
            else
                if TrainConnection then 
                    TrainConnection:Disconnect() 
                    TrainConnection = nil 
                end
                CustomNotify("Auto Train", "Auto-training features paused.", 3)
            end
        end,
    })

    AutomationTab:CreateToggle({
        Name = "Auto Clicker (Spawn/PvP Skip)",
        CurrentValue = false,
        Flag = "ClickToggle",
        Callback = function(Value)
            getgenv().autoclick = Value
            if Value then
                CustomNotify("Auto Clicker", "Spam routines engaged. Menu protections and popups will clear automatically.", 4)
            else
                CustomNotify("Auto Clicker", "Interface automatic skip routines disabled.", 3)
            end
        end,
    })

    AutomationTab:CreateToggle({
        Name = "Auto Upgrade All",
        CurrentValue = false,
        Flag = "UpgradeToggle",
        Callback = function(Value)
            getgenv().autoupgrade = Value
            if Value then
                CustomNotify("Auto Upgrade", "Global automated shop upgrades loop is now active.", 4)
            else
                CustomNotify("Auto Upgrade", "Auto upgrades paused.", 3)
            end
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
                CustomNotify("Teleport Engine", "Transported safely to the secure isolated platform zone.", 4)
            end
        end,
    })

    -----------------------------------------
    -- TAB 3 ELEMENTS: STATS TRACKER
    -----------------------------------------
    StatsTab:CreateSection("Live Leaderboard Statistics")
    local NinjutsuGainedLabel = StatsTab:CreateLabel("Gained since launch: 0")
    local NinjutsuRateLabel = StatsTab:CreateLabel("Rate per second: 0/s")

    StatsTab:CreateSection("Soul Force Tracking")
    local SoulGainedLabel = StatsTab:CreateLabel("Gained since launch: 0")
    local SoulRateLabel = StatsTab:CreateLabel("Rate per second: 0/s")

    StatsTab:CreateSection("Power Tracking")
    local PowerGainedLabel = StatsTab:CreateLabel("Gained since launch: 0")
    local PowerRateLabel = StatsTab:CreateLabel("Rate per second: 0/s")

    StatsTab:CreateSection("Discord Webhook Config")
    StatsTab:CreateInput({
        Name = "Webhook URL Address",
        PlaceholderText = "Paste Discord URL Here...",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            WebhookURL = Text
        end,
    })

    StatsTab:CreateDropdown({
        Name = "Transmission Loop Interval",
        Options = {"10 Seconds", "30 Seconds", "1 Minute", "5 Minutes", "15 Minutes", "30 Minutes"},
        CurrentOption = {"1 Minute"},
        MultipleOptions = false,
        Callback = function(Options)
            local mode = Options[1]
            if mode == "10 Seconds" then WebhookInterval = 10
            elseif mode == "30 Seconds" then WebhookInterval = 30
            elseif mode == "1 Minute" then WebhookInterval = 60
            elseif mode == "5 Minutes" then WebhookInterval = 300
            elseif mode == "15 Minutes" then WebhookInterval = 900
            elseif mode == "30 Minutes" then WebhookInterval = 1800
            end
            CustomNotify("Webhook Config", "Transmission frequency updated to every " .. mode .. ".", 4)
        end,
    })

    StatsTab:CreateToggle({
        Name = "Enable Webhook Sender",
        CurrentValue = false,
        Callback = function(Value)
            WebhookEnabled = Value
            if WebhookEnabled then
                NextWebhookTime = tick()
                CustomNotify("Webhook Loop", "Discord loop activated! Script will broadcast live metrics updates automatically.", 4)
            else
                CustomNotify("Webhook Loop", "Automated Discord telemetry updates suspended.", 3)
            end
        end,
    })

    StatsTab:CreateButton({
        Name = "Test Send Webhook Frame Now",
        Callback = function()
            sendStatsWebhook()
            CustomNotify("Webhook Dispatch", "Fired off a fresh metrics frame directly to your Discord server.", 4)
        end,
    })

    -----------------------------------------
    -- TAB 4 ELEMENTS: MISC & UTILITIES
    -----------------------------------------
    MiscTab:CreateButton({
        Name = "Run Anti-AFK Script",
        Callback = function()
            if not getgenv().AntiAFKRunning then
                getgenv().AntiAFKRunning = true
                
                LocalPlayer.Idled:Connect(function()
                    if getgenv().AntiAFKRunning then
                        pcall(function()
                            VirtualUser:CaptureController()
                            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                            task.wait(math.random(0.1, 0.5))
                            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                            print(string.format("[Anti-AFK] Character un-idled successfully at %s", os.date("%X")))
                        end)
                    end
                end)
                
                CustomNotify("Anti-AFK System", "Hardware mouse-input simulation initiated. You are now protected against idle drops!", 5)
            else
                CustomNotify("Anti-AFK System", "The anti-disconnect mechanism is already armed and guarding your session.", 3)
            end
        end,
    })

    MiscTab:CreateButton({
        Name = "Run FPS Booster",
        Callback = function()
            local success, content = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/TRcalled/RbxScripts/refs/heads/main/Fps%20Booster_1.lua")
            end)
            
            if success and content then
                local func, err = loadstring(content)
                if func then
                    task.spawn(func)
                    CustomNotify("Graphics Engine", "3D scene optimizations successfully pushed to memory. Performance should lift shortly.", 5)
                else
                    warn("Compile error in FPS Booster: " .. tostring(err))
                end
            else
                warn("Failed to fetch FPS Booster script: " .. tostring(content))
            end
        end,
    })

    -----------------------------------------
    -- AUTOMATION LOOPS & TRACKERS
    -----------------------------------------
    task.spawn(function()
        while true do
            task.wait(1)
            
            local currentNinjutsu = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0
            local currentSoul = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0
            local currentPower = tonumber(getStatValue("leaderstats", "Power")) or 0

            local ninjutsuGained = currentNinjutsu - initialStats.Ninjutsu
            local soulGained = currentSoul - initialStats.SoulForce
            local powerGained = currentPower - initialStats.Power

            local ninjutsuRate = currentNinjutsu - previousStats.Ninjutsu
            local soulRate = currentSoul - previousStats.SoulForce
            local powerRate = currentPower - previousStats.Power

            NinjutsuGainedLabel:Set("Gained since launch: " .. formatNumber(ninjutsuGained))
            NinjutsuRateLabel:Set("Rate per second: " .. formatNumber(ninjutsuRate) .. "/s")

            SoulGainedLabel:Set("Gained since launch: " .. formatNumber(soulGained))
            SoulRateLabel:Set("Rate per second: " .. formatNumber(soulRate) .. "/s")

            PowerGainedLabel:Set("Gained since launch: " .. formatNumber(powerGained))
            PowerRateLabel:Set("Rate per second: " .. formatNumber(powerRate) .. "/s")

            previousStats.Ninjutsu = currentNinjutsu
            previousStats.SoulForce = currentSoul
            previousStats.Power = currentPower

            -- Webhook Interval Check Engine Loop
            if WebhookEnabled and tick() >= NextWebhookTime then
                sendStatsWebhook()
                NextWebhookTime = tick() + WebhookInterval
            end
        end
    end)

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
