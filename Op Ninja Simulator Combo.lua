-- Wrap execution cleanly to isolate local variables and protect the main thread
task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end

    --[[ ========================================================= ]]--
    --                          SERVICES                           --
    --[[ ========================================================= ]]--
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local HttpService = game:GetService("HttpService")
    local TweenService = game:GetService("TweenService")
    local TextService = game:GetService("TextService")
    local CoreGui = game:GetService("CoreGui")
    local VirtualUser = game:GetService("VirtualUser")
    local LocalPlayer = Players.LocalPlayer

    -- Load Rayfield UI Library
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

    --[[ ========================================================= ]]--
    --                     STATE VARIABLES                         --
    --[[ ========================================================= ]]--
    getgenv().autotrain = false
    getgenv().autoclick = false
    getgenv().AntiAFKRunning = false

    -- Auto-Upgrade Configuration State
    local SelectedUpgrades = {
        Sword = false,
        Shuriken = false,
        Class = false,
        Ascend = false
    }

    -- Webhook State
    local WebhookURL = ""
    local WebhookEnabled = false
    local WebhookInterval = 60 
    local NextWebhookTime = 0

    -- Combat Configuration
    local SelectedTargetName = nil
    local IsLoopTPEnabled = false
    local CombatDistance = 3
    local LoopConnection = nil
    local TrainConnection = nil 

    -- System UI Variables
    local PerformanceGui = nil
    local StatHUDEnabled = false

    --[[ ========================================================= ]]--
    --                   UTILITY FUNCTIONS                         --
    --[[ ========================================================= ]]--
    
    -- Helper to check exact integer RGB values (prevents floating-point precision mismatches)
    local function isRGB(color3, r, g, b)
        if not color3 then return false end
        local cr = math.floor(color3.R * 255 + 0.5)
        local cg = math.floor(color3.G * 255 + 0.5)
        local cb = math.floor(color3.B * 255 + 0.5)
        return cr == r and cg == g and cb == b
    end

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

    -- Initial Statistics Tracking
    local initialStats = {
        Ninjutsu = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0,
        SoulForce = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0,
        Power = tonumber(getStatValue("leaderstats", "Power")) or 0,
        Realm = tostring(getStatValue("leaderstats", "Realm"))
    }

    local previousStats = {
        Ninjutsu = initialStats.Ninjutsu,
        SoulForce = initialStats.SoulForce,
        Power = initialStats.Power,
        Realm = initialStats.Realm
    }

    --[[ ========================================================= ]]--
    --            STANDALONE CUSTOM NOTIFICATION SYSTEM            --
    --[[ ========================================================= ]]--
    local NotificationGui = Instance.new("ScreenGui")
    NotificationGui.Name = "NinjaHubNotificationOverlay"
    NotificationGui.ResetOnSpawn = false
    if not pcall(function() NotificationGui.Parent = CoreGui end) then
        NotificationGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local NotificationContainer = Instance.new("Frame", NotificationGui)
    NotificationContainer.Name = "Container"
    NotificationContainer.Size = UDim2.new(0, 260, 0, 500)
    NotificationContainer.Position = UDim2.new(1, -280, 0, 210)
    NotificationContainer.BackgroundTransparency = 1

    local NotificationList = Instance.new("UIListLayout", NotificationContainer)
    NotificationList.SortOrder = Enum.SortOrder.LayoutOrder
    NotificationList.VerticalAlignment = Enum.VerticalAlignment.Top
    NotificationList.Padding = UDim.new(0, 8)

    local function CustomNotify(title, content, duration)
        duration = duration or 3.5
        
        local Frame = Instance.new("Frame", NotificationContainer)
        Frame.Size = UDim2.new(1, 0, 0, 55)
        Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        Frame.BackgroundTransparency = 1
        
        local Corner = Instance.new("UICorner", Frame)
        Corner.CornerRadius = UDim.new(0, 6)
        
        local Stroke = Instance.new("UIStroke", Frame)
        Stroke.Color = Color3.fromRGB(0, 140, 255)
        Stroke.Thickness = 1.2
        Stroke.Transparency = 1

        local TitleLabel = Instance.new("TextLabel", Frame)
        TitleLabel.Size = UDim2.new(1, -20, 0, 20)
        TitleLabel.Position = UDim2.new(0, 12, 0, 6)
        TitleLabel.BackgroundTransparency = 1
        TitleLabel.Font = Enum.Font.GothamBold
        TitleLabel.Text = string.upper(title)
        TitleLabel.TextColor3 = Color3.fromRGB(0, 140, 255)
        TitleLabel.TextSize = 11
        TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        TitleLabel.TextTransparency = 1

        local ContentLabel = Instance.new("TextLabel", Frame)
        ContentLabel.Size = UDim2.new(1, -24, 0, 24)
        ContentLabel.Position = UDim2.new(0, 12, 0, 24)
        ContentLabel.BackgroundTransparency = 1
        ContentLabel.Font = Enum.Font.GothamMedium
        ContentLabel.Text = content
        ContentLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
        ContentLabel.TextSize = 11
        ContentLabel.TextXAlignment = Enum.TextXAlignment.Left
        ContentLabel.TextWrapped = true
        ContentLabel.TextTransparency = 1

        -- Fade In Animation Sequence
        TweenService:Create(Frame, TweenInfo.new(0.25), {BackgroundTransparency = 0.15}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.25), {Transparency = 0.4}):Play()
        TweenService:Create(TitleLabel, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
        TweenService:Create(ContentLabel, TweenInfo.new(0.25), {TextTransparency = 0}):Play()

        -- Auto Dismiss Out
        task.delay(duration, function()
            if not Frame or not Frame.Parent then return end
            local fadeOut = TweenService:Create(Frame, TweenInfo.new(0.3), {BackgroundTransparency = 1})
            TweenService:Create(Stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
            TweenService:Create(TitleLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            TweenService:Create(ContentLabel, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            fadeOut:Play()
            fadeOut.Completed:Wait()
            Frame:Destroy()
        end)
    end

    --[[ ========================================================= ]]--
    --                 ON-SCREEN STAT TRACKER HUD                   --
    --[[ ========================================================= ]]--
    local function CreateStatHUD()
        if PerformanceGui then PerformanceGui:Destroy() end

        PerformanceGui = Instance.new("ScreenGui")
        PerformanceGui.Name = "NinjaHubStatTrackerHUD"
        PerformanceGui.ResetOnSpawn = false
        if not pcall(function() PerformanceGui.Parent = CoreGui end) then
            PerformanceGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        local Container = Instance.new("Frame", PerformanceGui)
        Container.Size = UDim2.new(0, 320, 0, 75)
        Container.Position = UDim2.new(0.5, -160, 0, 15)
        Container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
        Container.BackgroundTransparency = 0.2

        local Corner = Instance.new("UICorner", Container)
        Corner.CornerRadius = UDim.new(0, 8)

        local Stroke = Instance.new("UIStroke", Container)
        Stroke.Color = Color3.fromRGB(0, 140, 255)
        Stroke.Thickness = 1.5

        local Title = Instance.new("TextLabel", Container)
        Title.Size = UDim2.new(1, 0, 0, 22)
        Title.Position = UDim2.new(0, 0, 0, 4)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = "NINJA HUB | REAL-TIME STAT TELEMETRY"
        Title.TextColor3 = Color3.fromRGB(0, 140, 255)
        Title.TextSize = 11

        local StatLabel = Instance.new("TextLabel", Container)
        StatLabel.Name = "StatDisplay"
        StatLabel.Size = UDim2.new(1, -20, 0, 40)
        StatLabel.Position = UDim2.new(0, 10, 0, 28)
        StatLabel.BackgroundTransparency = 1
        StatLabel.Font = Enum.Font.GothamMedium
        StatLabel.Text = "Ninjutsu: +0/s | Soul Force: +0/s\nPower: +0/s | Realm: Unchanged"
        StatLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
        StatLabel.TextSize = 11
        StatLabel.TextWrapped = true

        PerformanceGui.Enabled = StatHUDEnabled
    end

    CreateStatHUD()

    -- Real-Time Stat Rate Calculation Thread
    task.spawn(function()
        while true do
            task.wait(1)
            local currentNinjutsu = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0
            local currentSoulForce = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0
            local currentPower = tonumber(getStatValue("leaderstats", "Power")) or 0
            local currentRealm = tostring(getStatValue("leaderstats", "Realm"))

            local diffNinjutsu = currentNinjutsu - previousStats.Ninjutsu
            local diffSoulForce = currentSoulForce - previousStats.SoulForce
            local diffPower = currentPower - previousStats.Power

            previousStats.Ninjutsu = currentNinjutsu
            previousStats.SoulForce = currentSoulForce
            previousStats.Power = currentPower
            previousStats.Realm = currentRealm

            if PerformanceGui and PerformanceGui:FindFirstChild("Frame") then
                local statDisplay = PerformanceGui.Frame:FindFirstChild("StatDisplay")
                if statDisplay then
                    statDisplay.Text = string.format(
                        "Ninjutsu: +%s/s | Soul Force: +%s/s\nPower: +%s/s | Realm: %s",
                        formatNumber(diffNinjutsu),
                        formatNumber(diffSoulForce),
                        formatNumber(diffPower),
                        currentRealm
                    )
                end
            end
        end
    end)

    --[[ ========================================================= ]]--
    --                 DISCORD WEBHOOK TELEMETRY                   --
    --[[ ========================================================= ]]--
    local function sendStatsWebhook(statusType)
        if not WebhookEnabled or WebhookURL == "" then return end

        local curNinjutsu = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0
        local curSoulForce = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0
        local curPower = tonumber(getStatValue("leaderstats", "Power")) or 0
        local curRealm = tostring(getStatValue("leaderstats", "Realm"))

        local gainsNinjutsu = curNinjutsu - initialStats.Ninjutsu
        local gainsSoulForce = curSoulForce - initialStats.SoulForce
        local gainsPower = curPower - initialStats.Power

        local payload = {
            embeds = {{
                title = "Ninja Hub Telemetry Report",
                color = 35983,
                fields = {
                    {name = "Player", value = LocalPlayer.Name, inline = true},
                    {name = "Status", value = statusType or "Active", inline = true},
                    {name = "Realm", value = curRealm, inline = true},
                    {name = "Current Ninjutsu", value = formatNumber(curNinjutsu), inline = true},
                    {name = "Current Soul Force", value = formatNumber(curSoulForce), inline = true},
                    {name = "Current Power", value = formatNumber(curPower), inline = true},
                    {name = "Session Gains (Ninjutsu)", value = "+" .. formatNumber(gainsNinjutsu), inline = true},
                    {name = "Session Gains (Soul Force)", value = "+" .. formatNumber(gainsSoulForce), inline = true},
                    {name = "Session Gains (Power)", value = "+" .. formatNumber(gainsPower), inline = true}
                },
                timestamp = DateTime.now():ToIsoDate()
            }}
        }

        pcall(function()
            local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
            if requestFunc then
                requestFunc({
                    Url = WebhookURL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode(payload)
                })
            end
        end)
    end

    -- Webhook Background Loop
    task.spawn(function()
        while true do
            task.wait(1)
            if WebhookEnabled and tick() >= NextWebhookTime then
                sendStatsWebhook("Scheduled Update")
                NextWebhookTime = tick() + WebhookInterval
            end
        end
    end)

    --[[ ========================================================= ]]--
    --                     AUTOMATION LOOPS                        --
    --[[ ========================================================= ]]--

    -- Pop-up Removal Click Loop
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

    -- Dynamic Auto-Upgrade Color Trigger Engine & UI Auto-Dismissal Loop
    task.spawn(function()
        while true do
            task.wait(0.1) -- Fast checking interval for instant responsiveness
            
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if not playerGui then continue end
            
            local mainGui = playerGui:FindFirstChild("MainGui")
            if not mainGui then continue end

            -- 1. Auto-Close Upgrade Failure UI Prompts (UpgradeFailedF, UpgradeClassFailedF, UpgradeAscensionFailedF)
            local failedFrames = {"UpgradeFailedF", "UpgradeClassFailedF", "UpgradeAscensionFailedF"}
            for _, frameName in ipairs(failedFrames) do
                local failedFrame = mainGui:FindFirstChild(frameName)
                if failedFrame and failedFrame.Visible then
                    local closeBtn = failedFrame:FindFirstChild("NoImgBtn")
                    if closeBtn then
                        press(closeBtn)
                    end
                end
            end

            -- 2. Color Detection Logic (Triggers click when color changes away from base disabled color)
            local upgradeF = mainGui:FindFirstChild("UpgradeF")
            if upgradeF then
                -- Sword Auto Upgrade (Base/Disabled Color: 0, 20, 0)
                if SelectedUpgrades["Sword"] then
                    local swordBtn = upgradeF:FindFirstChild("SwordF") and upgradeF.SwordF:FindFirstChild("MaxUpgradeBtn")
                    if swordBtn and not isRGB(swordBtn.ImageColor3, 0, 20, 0) then
                        press(swordBtn)
                    end
                end

                -- Shuriken Auto Upgrade (Base/Disabled Color: 0, 20, 0)
                if SelectedUpgrades["Shuriken"] then
                    local shurikenBtn = upgradeF:FindFirstChild("ShurikenF") and upgradeF.ShurikenF:FindFirstChild("ShurikenImgBtn")
                    if shurikenBtn and not isRGB(shurikenBtn.ImageColor3, 0, 20, 0) then
                        press(shurikenBtn)
                    end
                end

                -- Class Auto Upgrade (Base/Disabled Color: 0, 0, 105)
                if SelectedUpgrades["Class"] then
                    local classBtn = upgradeF:FindFirstChild("ClassF") and upgradeF.ClassF:FindFirstChild("ClassImgBtn")
                    if classBtn and not isRGB(classBtn.ImageColor3, 0, 0, 105) then
                        press(classBtn)
                    end
                end

                -- Ascend Auto Upgrade (Base/Disabled Color: 0, 0, 105)
                if SelectedUpgrades["Ascend"] then
                    local ascendBtn = upgradeF:FindFirstChild("AscendF") and upgradeF.AscendF:FindFirstChild("AscendImgBtn")
                    if ascendBtn and not isRGB(ascendBtn.ImageColor3, 0, 0, 105) then
                        press(ascendBtn)
                    end
                end
            end
        end
    end)

    -- Built-in Anti-AFK Handler
    LocalPlayer.Idled:Connect(function()
        if getgenv().AntiAFKRunning then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)

    --[[ ========================================================= ]]--
    --                        RAYFIELD UI                          --
    --[[ ========================================================= ]]--
    local Window = Rayfield:CreateWindow({
        Name = "Ninja Hub | Ultimate Edition",
        LoadingTitle = "Ninja Hub Loading...",
        LoadingSubtitle = "by Ninja Hub Team",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "NinjaHubConfigs",
            FileName = "NinjaHub_Config"
        },
        Discord = {
            Enabled = false,
            Invite = "",
            RememberJoins = true
        },
        KeySystem = false
    })

    -- 1. Main / Auto Farming Tab
    local MainTab = Window:CreateTab("Auto Farming", 4483362458)

    MainTab:CreateToggle({
        Name = "Auto Train (Frame Optimized)",
        CurrentValue = false,
        Flag = "AutoTrainToggle",
        Callback = function(Value)
            getgenv().autotrain = Value
            if Value then
                TrainConnection = RunService.RenderStepped:Connect(function()
                    if getgenv().autotrain and LocalPlayer.Character then
                        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool then
                            tool:Activate()
                        end
                    end
                end)
                CustomNotify("Auto Train", "Auto Train active at max FPS speed", 3)
            else
                if TrainConnection then
                    TrainConnection:Disconnect()
                    TrainConnection = nil
                end
                CustomNotify("Auto Train", "Auto Train disabled", 3)
            end
        end,
    })

    MainTab:CreateToggle({
        Name = "Auto Click Pop-ups",
        CurrentValue = false,
        Flag = "AutoClickToggle",
        Callback = function(Value)
            getgenv().autoclick = Value
            CustomNotify("Auto Click", Value and "Auto Clicking Pop-ups Enabled" or "Auto Clicking Disabled", 3)
        end,
    })

    MainTab:CreateDropdown({
        Name = "Select Auto Upgrade Types",
        Options = {"Sword", "Shuriken", "Class", "Ascend"},
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "AutoUpgradeDropdown",
        Callback = function(Options)
            -- Reset all upgrade triggers
            SelectedUpgrades["Sword"] = false
            SelectedUpgrades["Shuriken"] = false
            SelectedUpgrades["Class"] = false
            SelectedUpgrades["Ascend"] = false
            
            -- Enable selected options
            for _, opt in ipairs(Options) do
                if SelectedUpgrades[opt] ~= nil then
                    SelectedUpgrades[opt] = true
                end
            end
            CustomNotify("Auto Upgrade", "Updated target upgrade selections", 2.5)
        end,
    })

    MainTab:CreateButton({
        Name = "Create Safe Zone Platform",
        Callback = function()
            local platform = Instance.new("Part")
            platform.Name = "NinjaHubSafeZone"
            platform.Size = Vector3.new(20, 1, 20)
            platform.Position = Vector3.new(0, 50, 10000)
            platform.Anchored = true
            platform.Material = Enum.Material.SmoothPlastic
            platform.Parent = workspace

            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = platform.CFrame + Vector3.new(0, 3, 0)
                CustomNotify("Safe Zone", "Teleported to Safe Zone Platform", 3)
            end
        end,
    })

    -- 2. Combat Tab
    local CombatTab = Window:CreateTab("Combat & TP", 4483362458)

    local PlayerDropdown = CombatTab:CreateDropdown({
        Name = "Select Player Target",
        Options = getPlayerNames(),
        CurrentOption = {"None"},
        MultipleOptions = false,
        Flag = "TargetPlayerDropdown",
        Callback = function(Option)
            SelectedTargetName = Option[1] or Option
            CustomNotify("Target Lock", "Selected Target: " .. tostring(SelectedTargetName), 3)
        end,
    })

    CombatTab:CreateButton({
        Name = "Refresh Player List",
        Callback = function()
            PlayerDropdown:Refresh(getPlayerNames())
            CustomNotify("Combat", "Player list refreshed", 2)
        end,
    })

    CombatTab:CreateSlider({
        Name = "Combat Teleport Distance",
        Range = {1, 10},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = 3,
        Flag = "CombatDistanceSlider",
        Callback = function(Value)
            CombatDistance = Value
        end,
    })

    CombatTab:CreateToggle({
        Name = "Loop TP Behind Target",
        CurrentValue = false,
        Flag = "LoopTPToggle",
        Callback = function(Value)
            IsLoopTPEnabled = Value
            if Value then
                LoopConnection = RunService.Heartbeat:Connect(function()
                    if IsLoopTPEnabled and SelectedTargetName and SelectedTargetName ~= "No other players found" then
                        local targetPlayer = Players:FindFirstChild(SelectedTargetName)
                        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                local targetHRP = targetPlayer.Character.HumanoidRootPart
                                LocalPlayer.Character.HumanoidRootPart.CFrame = targetHRP.CFrame * CFrame.new(0, 0, CombatDistance)
                            end
                        end
                    end
                end)
                CustomNotify("Combat", "Loop TP Enabled for target: " .. tostring(SelectedTargetName), 3)
            else
                if LoopConnection then
                    LoopConnection:Disconnect()
                    LoopConnection = nil
                end
                CustomNotify("Combat", "Loop TP Disabled", 3)
            end
        end,
    })

    -- 3. Telemetry / Stat Tracker Tab
    local TelemetryTab = Window:CreateTab("Telemetry", 4483362458)

    TelemetryTab:CreateToggle({
        Name = "Enable On-Screen Stat HUD",
        CurrentValue = false,
        Flag = "StatHUDToggle",
        Callback = function(Value)
            StatHUDEnabled = Value
            if PerformanceGui then
                PerformanceGui.Enabled = Value
            end
            CustomNotify("HUD Overlay", Value and "Stat HUD Enabled" or "Stat HUD Disabled", 2.5)
        end,
    })

    TelemetryTab:CreateInput({
        Name = "Discord Webhook URL",
        PlaceholderText = "Paste Webhook URL Here",
        RemoveTextOnFocus = false,
        Callback = function(Text)
            WebhookURL = Text
            CustomNotify("Webhook", "Webhook URL updated", 2.5)
        end,
    })

    TelemetryTab:CreateToggle({
        Name = "Enable Discord Webhook",
        CurrentValue = false,
        Flag = "WebhookToggle",
        Callback = function(Value)
            WebhookEnabled = Value
            if Value then
                NextWebhookTime = tick()
                CustomNotify("Webhook", "Discord Webhook Logging Enabled", 3)
            else
                CustomNotify("Webhook", "Discord Webhook Logging Disabled", 3)
            end
        end,
    })

    TelemetryTab:CreateSlider({
        Name = "Webhook Interval (Seconds)",
        Range = {10, 300},
        Increment = 5,
        Suffix = "s",
        CurrentValue = 60,
        Flag = "WebhookIntervalSlider",
        Callback = function(Value)
            WebhookInterval = Value
        end,
    })

    TelemetryTab:CreateButton({
        Name = "Send Test Webhook Report",
        Callback = function()
            if WebhookURL ~= "" then
                sendStatsWebhook("Manual Test")
                CustomNotify("Webhook", "Test Webhook sent successfully!", 3)
            else
                CustomNotify("Webhook Error", "Please input a valid Webhook URL first", 3)
            end
        end,
    })

    -- 4. Misc & Tools Tab
    local MiscTab = Window:CreateTab("Misc & Tools", 4483362458)

    MiscTab:CreateToggle({
        Name = "Anti-AFK Protection",
        CurrentValue = false,
        Flag = "AntiAFKToggle",
        Callback = function(Value)
            getgenv().AntiAFKRunning = Value
            CustomNotify("Anti-AFK", Value and "Anti-AFK Enabled" or "Anti-AFK Disabled", 3)
        end,
    })

    MiscTab:CreateButton({
        Name = "Run FPS Booster",
        Callback = function()
            pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/TRcalled/RbxScripts/refs/heads/main/Fps%20Booster_Loader.lua"))()
            end)
            CustomNotify("Tools", "FPS Booster Executed", 3)
        end,
    })

    CustomNotify("Ninja Hub", "Ninja Hub | Ultimate Edition Loaded Successfully!", 4)
end)
