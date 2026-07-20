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

    --[[ ========================================================= ]]--
    --                     STATE VARIABLES                         --
    --[[ ========================================================= ]]--
    getgenv().autotrain = false
    getgenv().autoclick = false
    getgenv().autoupgrade = false
    getgenv().AntiAFKRunning = false

    -- Webhook State
    local WebhookURL = ""
    local WebhookEnabled = false
    local WebhookInterval = 60 
    local NextWebhookTime = 0

    -- Combat Configuration
    local SelectedTargetName = nil
    local IsLoopTPEnabled = false
    local DistanceLockEnabled = true -- Defaulted to true (Lock toggle removed per request)
    local CombatDistance = 3
    local LoopConnection = nil
    local TrainConnection = nil 

    -- System UI Variables
    local PerformanceGui = nil
    local PerformanceOverlay = nil

    --[[ ========================================================= ]]--
    --                   UTILITY FUNCTIONS                         --
    --[[ ========================================================= ]]--
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

    -- Initial Statistics Capture
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
    NotificationContainer.Position = UDim2.new(1, -280, 0, 210) -- Positions smoothly under the performance HUD
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
        Frame.BackgroundTransparency = 1 -- Animate entry transparency
        
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

        -- Auto Dismiss Out Engine
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
    --             RAYFIELD GEN2 CORE INITIALIZATION               --
    --[[ ========================================================= ]]--
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    
    local Window = Rayfield:CreateWindow({
        Name = "Ninja Hub | Premium Edition",
        LoadingTitle = "NINJA HUB PREMIUM SUITE",
        LoadingSubtitle = "Loading Script...",
        Theme = "Serenity", -- Enforce default visual theme environment configuration
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "NinjaHubData",
            FileName = "PremiumSaveConfig"
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

    -- Custom System Notification (Replaced Rayfield default notification completely)
    CustomNotify("Ninja Hub Premium", "Script loaded successfully! Press Right Control to toggle UI.", 5)

    -- Premium Script Hub Tab Layout
    local DashboardTab = Window:CreateTab("Dashboard")
    local CombatTab = Window:CreateTab("Combat")
    local AutomationTab = Window:CreateTab("Automation")
    local WebhooksTab = Window:CreateTab("Webhooks")
    local SettingsTab = Window:CreateTab("Settings")

    --[[ ========================================================= ]]--
    --                STANDALONE HUD NOTIFICATION LAYER            --
    --[[ ========================================================= ]]--
    local HudGui = Instance.new("ScreenGui")
    HudGui.Name = "NinjaHubDashboardOverlay"
    HudGui.ResetOnSpawn = false
    if not pcall(function() HudGui.Parent = CoreGui end) then
        HudGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local HudContainer = Instance.new("Frame", HudGui)
    HudContainer.Name = "HUD"
    HudContainer.Size = UDim2.new(0, 240, 0, 160)
    HudContainer.Position = UDim2.new(1, -260, 0, 40)
    HudContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    HudContainer.BackgroundTransparency = 0.2
    
    local HudCorner = Instance.new("UICorner", HudContainer)
    HudCorner.CornerRadius = UDim.new(0, 8)
    
    local HudStroke = Instance.new("UIStroke", HudContainer)
    HudStroke.Color = Color3.fromRGB(0, 140, 255)
    HudStroke.Thickness = 1.5
    HudStroke.Transparency = 0.5

    local HudTitle = Instance.new("TextLabel", HudContainer)
    HudTitle.Size = UDim2.new(1, 0, 0, 25)
    HudTitle.BackgroundTransparency = 1
    HudTitle.Font = Enum.Font.GothamBold
    HudTitle.Text = "LIVE PERFORMANCE METRICS"
    HudTitle.TextColor3 = Color3.fromRGB(0, 140, 255)
    HudTitle.TextSize = 11

    local HudList = Instance.new("UIListLayout", HudContainer)
    HudList.SortOrder = Enum.SortOrder.LayoutOrder
    HudList.Padding = UDim.new(0, 4)
    
    Instance.new("UIPadding", HudContainer).PaddingLeft = UDim.new(0, 12)

    local function createHudLabel(text, order)
        local lbl = Instance.new("TextLabel", HudContainer)
        lbl.Size = UDim2.new(1, -24, 0, 18)
        lbl.BackgroundTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.Text = text
        lbl.TextColor3 = Color3.fromRGB(230, 230, 235)
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.LayoutOrder = order
        return lbl
    end

    local HudNinjutsu = createHudLabel("Ninjutsu/s: 0", 1)
    local HudSoul = createHudLabel("Soul Force/s: 0", 2)
    local HudPower = createHudLabel("Power/s: 0", 3)
    local HudRealm = createHudLabel("Realm: Unknown", 4)
    local HudStatus = createHudLabel("Telemetry: Active", 5)

    -- Toggle control for HUD inside Rayfield Dashboard
    DashboardTab:CreateSection("Dashboard Configuration")
    DashboardTab:CreateToggle({
        Name = "Show Statistics Overlay HUD",
        CurrentValue = true,
        Flag = "HudVisibilityToggle",
        Callback = function(Value)
            HudGui.Enabled = Value
            CustomNotify("HUD Display", Value and "Statistics Overlay Enabled." or "Statistics Overlay Disabled.", 3)
        end,
    })

    --[[ ========================================================= ]]--
    --                PHASE 2: DYNAMIC COMBAT ENGINE               --
    --[[ ========================================================= ]]--
    local function startLoop()
        if LoopConnection then LoopConnection:Disconnect() end
        LoopConnection = RunService.Heartbeat:Connect(function()
            if not IsLoopTPEnabled or not SelectedTargetName then return end
            local target = Players:FindFirstChild(SelectedTargetName)
            local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if myRoot and targetRoot then
                if DistanceLockEnabled then
                    local targetCFrame = targetRoot.CFrame
                    myRoot.CFrame = CFrame.new(targetCFrame.Position + (targetCFrame.LookVector * -CombatDistance)) * targetCFrame.Rotation
                else
                    myRoot.CFrame = targetRoot.CFrame
                end
            end
        end)
    end

    local PlayerDropdown = CombatTab:CreateDropdown({
        Name = "Select Target Player",
        Options = getPlayerNames(),
        CurrentOption = {""},
        MultipleOptions = false,
        Flag = "CombatTargetDropdown",
        Callback = function(Options)
            local choice = type(Options) == "table" and Options[1] or Options
            SelectedTargetName = (choice and choice ~= "No other players found" and choice ~= "") and choice or nil
            if SelectedTargetName then
                CustomNotify("Target Acquired", "Locked onto " .. SelectedTargetName .. ".", 3)
            end
        end,
    })

    local function updateDropdown()
        if PlayerDropdown then PlayerDropdown:Refresh(getPlayerNames(), true) end
    end
    Players.PlayerAdded:Connect(updateDropdown)
    Players.PlayerRemoving:Connect(updateDropdown)

    CombatTab:CreateSlider({
        Name = "Combat Target Distance (Studs)",
        Range = {1, 15},
        Increment = 1,
        Suffix = "Studs",
        CurrentValue = 3,
        Flag = "TargetDistanceSlider",
        Callback = function(Value)
            CombatDistance = Value
            CustomNotify("Combat Setting", "Offset distance set to " .. Value .. " studs.", 2)
        end,
    })

    CombatTab:CreateToggle({
        Name = "Loop Teleport to Player",
        CurrentValue = false,
        Flag = "LoopTeleportToggle",
        Callback = function(Value)
            IsLoopTPEnabled = Value
            CustomNotify("Combat Engine", Value and "Loop Teleport Activated." or "Loop Teleport Deactivated.", 3)
            if IsLoopTPEnabled then
                startLoop()
            else
                if LoopConnection then LoopConnection:Disconnect(); LoopConnection = nil end
            end
        end,
    })

    --[[ ========================================================= ]]--
    --                  TAB 3: ADVANCED WEBHOOK ENG               --
    --[[ ========================================================= ]]--
    local function sendStatsWebhook(embedType, specialTitle, specialDesc)
        if WebhookURL == "" or not string.match(WebhookURL, "^https://") then return end

        local currentNinjutsu = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0
        local currentSoul = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0
        local currentPower = tonumber(getStatValue("leaderstats", "Power")) or 0
        
        local currentClass = tostring(getStatValue("leaderstats", "Class"))
        local currentHonor = tonumber(getStatValue("leaderstats", "Honor")) or 0
        local currentRealm = tostring(getStatValue("leaderstats", "Realm"))

        local title = specialTitle or "🥷 Ninja Hub | Status Update"
        local description = specialDesc or "Telemetry logging update for **" .. LocalPlayer.Name .. "**."
        local color = 32767 -- Default Cyan

        if embedType == "RealmUp" then
            color = 16753920 -- Gold/Orange
        elseif embedType == "Milestone" then
            color = 16711824 -- Pink/Purple
        end

        local data = {
            ["embeds"] = {{
                ["title"] = title,
                ["description"] = description,
                ["color"] = color,
                ["fields"] = {
                    {["name"] = "📈 Combat Statistics", ["value"] = "• **Power:** " .. formatNumber(currentPower) .. "\n• **Ninjutsu:** " .. formatNumber(currentNinjutsu) .. "\n• **Soul Force:** " .. formatNumber(currentSoul) .. "", ["inline"] = false},
                    {["name"] = "🏆 Identity & Rankings", ["value"] = "• **Class:** " .. currentClass .. "\n• **Realm:** " .. currentRealm .. "\n• **Honor:** " .. formatNumber(currentHonor), ["inline"] = false}
                },
                ["footer"] = {["text"] = "Ninja Hub Premium Engine Suite"},
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
        end
    end

    WebhooksTab:CreateInput({
        Name = "Webhook URL Address",
        PlaceholderText = "Paste Discord URL Here...",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            WebhookURL = Text
            if Text ~= "" then
                CustomNotify("Webhook Config", "Discord Webhook URL updated successfully.", 3)
            end
        end,
    })

    WebhooksTab:CreateDropdown({
        Name = "Transmission Loop Interval",
        Options = {"10 Seconds", "30 Seconds", "1 Minute", "5 Minutes"},
        CurrentOption = {"1 Minute"},
        MultipleOptions = false,
        Callback = function(Options)
            local mode = type(Options) == "table" and Options[1] or Options
            if mode == "10 Seconds" then WebhookInterval = 10
            elseif mode == "30 Seconds" then WebhookInterval = 30
            elseif mode == "1 Minute" then WebhookInterval = 60
            elseif mode == "5 Minutes" then WebhookInterval = 300
            end
            CustomNotify("Webhook Config", "Transmission interval set to " .. mode .. ".", 3)
        end,
    })

    WebhooksTab:CreateToggle({
        Name = "Enable Webhook Sender",
        CurrentValue = false,
        Callback = function(Value)
            WebhookEnabled = Value
            CustomNotify("Webhook Service", Value and "Telemetry transmission enabled." or "Telemetry transmission disabled.", 3)
            if WebhookEnabled then NextWebhookTime = tick() end
        end,
    })

    --[[ ========================================================= ]]--
    --             PHASE 4: 3D RENDERING DISABLE PERFORMANCE       --
    --[[ ========================================================= ]]--
    local function createPerformanceCanvas()
        PerformanceGui = Instance.new("ScreenGui")
        PerformanceGui.Name = "NinjaHubPerformanceOverlay"
        PerformanceGui.IgnoreGuiInset = true
        PerformanceGui.ResetOnSpawn = false
        
        if not pcall(function() PerformanceGui.Parent = CoreGui end) then
            PerformanceGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        end

        PerformanceOverlay = Instance.new("Frame", PerformanceGui)
        PerformanceOverlay.Size = UDim2.new(1, 0, 1, 0)
        PerformanceOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
        
        local Title = Instance.new("TextLabel", PerformanceOverlay)
        Title.Size = UDim2.new(1, 0, 0, 50)
        Title.Position = UDim2.new(0, 0, 0.35, 0)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = "NINJA HUB | RESOURCE ENGAGE AUTOMATION"
        Title.TextColor3 = Color3.fromRGB(0, 140, 255)
        Title.TextSize = 24

        local Subtext = Instance.new("TextLabel", PerformanceOverlay)
        Subtext.Size = UDim2.new(1, 0, 0, 30)
        Subtext.Position = UDim2.new(0, 0, 0.42, 0)
        Subtext.BackgroundTransparency = 1
        Subtext.Font = Enum.Font.GothamMedium
        Subtext.Text = "3D Graphics Pipeline Haltered — Maximizing Process Frame Resource Limits"
        Subtext.TextColor3 = Color3.fromRGB(150, 150, 160)
        Subtext.TextSize = 14

        local StatsLabel = Instance.new("TextLabel", PerformanceOverlay)
        StatsLabel.Name = "LiveMetrics"
        StatsLabel.Size = UDim2.new(1, 0, 0, 80)
        StatsLabel.Position = UDim2.new(0, 0, 0.50, 0)
        StatsLabel.BackgroundTransparency = 1
        StatsLabel.Font = Enum.Font.Code
        StatsLabel.Text = "Loading Telemetry Core Data..."
        StatsLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
        StatsLabel.TextSize = 16
    end

    local function updatePerformanceCanvasData()
        if not PerformanceOverlay then return end
        local canvasLabel = PerformanceOverlay:FindFirstChild("LiveMetrics")
        if canvasLabel then
            local p = formatNumber(getStatValue("leaderstats", "Power"))
            local r = tostring(getStatValue("leaderstats", "Realm"))
            local n = formatNumber(getStatValue("PlayerStats", "Ninjutsu"))
            canvasLabel.Text = string.format("CURRENT REALM: %s \nPOWER METRICS: %s \nTOTAL NINJUTSU: %s", r, p, n)
        end
    end

    SettingsTab:CreateSection("Performance Customization")

    -- Restored FPS Booster Button (Utilizes User's Custom Notification System)
    SettingsTab:CreateButton({
        Name = "Run FPS Booster",
        Callback = function()
            local success, err = pcall(function()
                loadstring(game:HttpGet("https://raw.githubusercontent.com/TRcalled/RbxScripts/refs/heads/main/Fps%20Booster_1.lua"))()
            end)
            if success then
                CustomNotify("Performance", "FPS Booster Script Executed Successfully!", 3.5)
            else
                CustomNotify("Error", "Failed to load FPS Booster.", 3.5)
            end
        end,
    })

    SettingsTab:CreateToggle({
        Name = "3D Rendering (ON/OFF)",
        CurrentValue = false,
        Flag = "PerformanceRenderToggle",
        Callback = function(Value)
            RunService:Set3dRenderingEnabled(not Value)
            CustomNotify("Performance Engine", Value and "3D Rendering Disabled (Max FPS Mode)." or "3D Rendering Restored.", 3)
            
            if Value then
                createPerformanceCanvas()
                updatePerformanceCanvasData()
            else
                if PerformanceGui then
                    PerformanceGui:Destroy()
                    PerformanceGui = nil
                    PerformanceOverlay = nil
                end
            end
        end,
    })

    --[[ ========================================================= ]]--
    --                 STANDARD AUTOMATION ELEMENT LINKS           --
    --[[ ========================================================= ]]--
    AutomationTab:CreateToggle({
        Name = "Auto Train",
        CurrentValue = false,
        Flag = "AutoTrainToggle",
        Callback = function(Value)
            getgenv().autotrain = Value
            CustomNotify("Automation", Value and "Auto Train Enabled." or "Auto Train Disabled.", 3)
            
            if getgenv().autotrain then
                if TrainConnection then TrainConnection:Disconnect() end
                TrainConnection = RunService.RenderStepped:Connect(function()
                    local equippedTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if equippedTool then equippedTool:Activate() end
                end)
            else
                if TrainConnection then TrainConnection:Disconnect(); TrainConnection = nil end
            end
        end,
    })

    AutomationTab:CreateToggle({
        Name = "Auto Spawn/PvP Skip)",
        CurrentValue = false,
        Flag = "AutoClickToggle",
        Callback = function(Value)
            getgenv().autoclick = Value
            CustomNotify("Automation", Value and "Auto Clicker Activated." or "Auto Clicker Deactivated.", 3)
        end,
    })

    AutomationTab:CreateToggle({
        Name = "Auto Upgrade (Ignores Shuriken)",
        CurrentValue = false,
        Flag = "AutoUpgradeToggle",
        Callback = function(Value)
            getgenv().autoupgrade = Value
            CustomNotify("Automation", Value and "Auto Upgrade Enabled." or "Auto Upgrade Disabled.", 3)
        end
    })

    AutomationTab:CreateButton({
        Name = "Teleport to Safe Platform Area",
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
                CustomNotify("Navigation", "Successfully teleported to Safe Platform Zone.", 3)
            end
        end,
    })

    SettingsTab:CreateButton({
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
                        end)
                    end
                end)
                CustomNotify("System Configuration", "Anti-AFK routine initialized and running in background.", 3)
            else
                CustomNotify("System Configuration", "Anti-AFK routine is already running.", 3)
            end
        end,
    })

    -- Live Theme Switcher Component Architecture Block (Safely handles index & execution structures)
    SettingsTab:CreateSection("Theme Customization")

    SettingsTab:CreateDropdown({
        Name = "Active UI Theme Preset",
        Options = {"Default", "Serenity", "Amber", "Green", "Ocean", "Light"},
        CurrentOption = {"Serenity"},
        MultipleOptions = false,
        Flag = "ThemeSwitcherDropdown",
        Callback = function(Options)
            local SelectedTheme = type(Options) == "table" and Options[1] or Options
            if SelectedTheme then
                pcall(function()
                    if Rayfield.ModifyTheme then
                        Rayfield:ModifyTheme(SelectedTheme)
                    else
                        Rayfield.Theme = SelectedTheme
                    end
                end)
                CustomNotify("Theme System", "User interface theme updated to " .. SelectedTheme .. ".", 3)
            end
        end,
    })

    --[[ ========================================================= ]]--
    --               BACKGROUND AUTOMATION LOOPS                   --
    --[[ ========================================================= ]]--
    
    -- Telemetry Processing Engine Loop
    task.spawn(function()
        while true do
            task.wait(1)
            
            local currentNinjutsu = tonumber(getStatValue("PlayerStats", "Ninjutsu")) or 0
            local currentSoul = tonumber(getStatValue("PlayerStats", "Soul Force")) or 0
            local currentPower = tonumber(getStatValue("leaderstats", "Power")) or 0
            local currentRealm = tostring(getStatValue("leaderstats", "Realm"))

            local ninjutsuRate = currentNinjutsu - previousStats.Ninjutsu
            local soulRate = currentSoul - previousStats.SoulForce
            local powerRate = currentPower - previousStats.Power

            -- Standard HUD Engine Updates
            HudNinjutsu.Text = "Ninjutsu/s: " .. formatNumber(ninjutsuRate)
            HudSoul.Text = "Soul Force/s: " .. formatNumber(soulRate)
            HudPower.Text = "Power/s: " .. formatNumber(powerRate)
            HudRealm.Text = "Realm: " .. currentRealm

            -- Dynamic Core Interceptions for Advanced Webhook Systems
            if currentRealm ~= previousStats.Realm then
                sendStatsWebhook("RealmUp", "🚀 Realm Progression Upgraded!", "Character **" .. LocalPlayer.Name .. "** successfully advanced progression into **" .. currentRealm .. "**.")
                
                -- Add internal custom notification for rank up
                if currentRealm ~= "Unknown" and previousStats.Realm ~= "Unknown" then
                    CustomNotify("Rank Progression", "Advanced to new Realm: " .. currentRealm, 5)
                end
                
                previousStats.Realm = currentRealm
            end

            -- Performance canvas processing logic
            updatePerformanceCanvasData()

            previousStats.Ninjutsu = currentNinjutsu
            previousStats.SoulForce = currentSoul
            previousStats.Power = currentPower

            if WebhookEnabled and tick() >= NextWebhookTime then
                sendStatsWebhook("Status", nil, nil)
                NextWebhookTime = tick() + WebhookInterval
            end
        end
    end)

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

    -- Dynamic Upgrades Shop Loop
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
