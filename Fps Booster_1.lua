-- [[ HOSTED CORE ENGINE ]]
if not game:IsLoaded() then game.Loaded:Wait() end

-- Safely inherit settings or set fallbacks
_G.Ignore            = _G.Ignore or {}
_G.SendNotifications = _G.SendNotifications == nil and true or _G.SendNotifications
_G.ConsoleLogs       = _G.ConsoleLogs == nil and false or _G.ConsoleLogs

_G.Settings = _G.Settings or {
    Players    = { ["Ignore Me"] = true, ["Ignore Others"] = true, ["Ignore Tools"] = true },
    Meshes     = { NoMesh = false, NoTexture = true, Destroy = false },
    Images     = { Invisible = true, Destroy = true },
    Explosions = { Smaller = true, Invisible = true, Destroy = true },
    Particles  = { Invisible = true, Destroy = true },
    TextLabels = { LowerQuality = true, Invisible = false, Destroy = false },
    MeshParts  = { LowerQuality = true, Invisible = false, NoTexture = true, NoMesh = false, Destroy = false },
    Other      = {
        ["FPS Cap"] = true, ["No Camera Effects"] = true, ["No Clothes"] = true,
        ["Low Water Graphics"] = true, ["No Shadows"] = true, ["Low Rendering"] = true,
        ["Low Quality Parts"] = true, ["Low Quality Models"] = true, ["Reset Materials"] = true,
        ClearNilInstances = true 
    }
}

-- Services Cache
local Players         = game:GetService("Players")
local Lighting        = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local Workspace       = game:GetService("Workspace")
local CoreGui         = game:GetService("CoreGui")
local TweenService    = game:GetService("TweenService")
local TextService     = game:GetService("TextService")

local ME = Players.LocalPlayer

-- Target Filters
local BadClasses = {
    "ParticleEmitter", "Trail", "Smoke", "Fire", "Sparkles", "PostEffect", 
    "BloomEffect", "BlurEffect", "ColorCorrectionEffect", "SunRaysEffect", "DepthOfFieldEffect"
}

local ValidTargetClasses = {
    Part = true, MeshPart = true, Decal = true, Texture = true, SpecialMesh = true, BlockMesh = true, 
    CylinderMesh = true, ParticleEmitter = true, Trail = true, Smoke = true, Fire = true, Sparkles = true, 
    Explosion = true, ShirtGraphic = true, Clothing = true, SurfaceAppearance = true, BaseWrap = true, 
    TextLabel = true, Model = true
}

-- ==========================================
-- MODERN UI SYSTEM (NOTIFS & PROGRESS BAR)
-- ==========================================
local NotifGui = Instance.new("ScreenGui")
NotifGui.Name = "ModernFPSUI"
NotifGui.ResetOnSpawn = false
if not pcall(function() NotifGui.Parent = CoreGui end) then
    NotifGui.Parent = ME:WaitForChild("PlayerGui")
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

local function Notify(text, duration)
    if _G.ConsoleLogs then warn("[FPS Booster] " .. text) end
    if not _G.SendNotifications then return end
    duration = duration or 4

    local Wrapper = Instance.new("Frame", NotifContainer)
    Wrapper.Size = UDim2.new(1, 0, 0, 0)
    Wrapper.BackgroundTransparency = 1
    Wrapper.ClipsDescendants = true

    local Inner = Instance.new("Frame", Wrapper)
    Inner.Size = UDim2.new(1, 0, 1, 0)
    Inner.Position = UDim2.new(1, 50, 0, 0)
    Inner.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    Inner.BackgroundTransparency = 0.15
    Instance.new("UICorner", Inner).CornerRadius = UDim.new(0, 8)
    
    local Stroke = Instance.new("UIStroke", Inner)
    Stroke.Color, Stroke.Transparency, Stroke.Thickness = Color3.fromRGB(80, 120, 255), 0.5, 1.5

    local Title = Instance.new("TextLabel", Inner)
    Title.Size, Title.Position = UDim2.new(1, -30, 0, 20), UDim2.new(0, 15, 0, 8)
    Title.BackgroundTransparency, Title.Font = 1, Enum.Font.GothamBold
    Title.Text, Title.TextColor3, Title.TextSize = "FPS Booster", Color3.fromRGB(130, 170, 255), 14
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local Body = Instance.new("TextLabel", Inner)
    Body.Size, Body.Position = UDim2.new(1, -30, 1, -35), UDim2.new(0, 15, 0, 30)
    Body.BackgroundTransparency, Body.Font = 1, Enum.Font.Gotham
    Body.Text, Body.TextColor3, Body.TextSize = text, Color3.fromRGB(220, 220, 225), 13
    Body.TextWrapped, Body.TextXAlignment, Body.TextYAlignment = true, Enum.TextXAlignment.Left, Enum.TextYAlignment.Top

    local textHeight = TextService:GetTextSize(text, 13, Enum.Font.Gotham, Vector2.new(270, math.huge)).Y
    local targetHeight = math.max(65, textHeight + 45)

    TweenService:Create(Wrapper, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
    TweenService:Create(Inner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

    task.delay(duration, function()
        TweenService:Create(Inner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 50, 0, 0), BackgroundTransparency = 1}):Play()
        TweenService:Create(Stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
        TweenService:Create(Title, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        TweenService:Create(Body, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
        task.wait(0.3)
        local closeTween = TweenService:Create(Wrapper, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(1, 0, 0, 0)})
        closeTween:Play()
        closeTween.Completed:Wait()
        Wrapper:Destroy()
    end)
end

-- ==========================================
-- ENGINE LOGIC
-- ==========================================
local function PartOfCharacter(Inst)
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= ME and v.Character and Inst:IsDescendantOf(v.Character) then return true end
    end
    return false
end

local function DescendantOfIgnore(Inst)
    for _, v in ipairs(_G.Ignore) do
        if Inst:IsDescendantOf(v) then return true end
    end
    return false
end

local function CheckIfBad(Inst)
    if not Inst or not Inst.Parent or Inst:IsDescendantOf(Players) then return end
    
    local s = _G.Settings
    if s.Players["Ignore Others"] and PartOfCharacter(Inst) then return end
    if s.Players["Ignore Me"] and ME.Character and Inst:IsDescendantOf(ME.Character) then return end
    if s.Players["Ignore Tools"] and (Inst:IsA("BackpackItem") or Inst:FindFirstAncestorWhichIsA("BackpackItem")) then return end
    if #_G.Ignore > 0 and (table.find(_G.Ignore, Inst) or DescendantOfIgnore(Inst)) then return end

    if Inst:IsA("DataModelMesh") then
        if Inst:IsA("SpecialMesh") then
            if s.Meshes.NoMesh then Inst.MeshId = "" end
            if s.Meshes.NoTexture then Inst.TextureId = "" end
        end
        if s.Meshes.Destroy then Inst:Destroy() end

    elseif Inst:IsA("FaceInstance") or Inst:IsA("Decal") or Inst:IsA("Texture") then
        if s.Images.Invisible then Inst.Transparency = 1 end
        if s.Images.Destroy then Inst:Destroy() end

    elseif Inst:IsA("ShirtGraphic") then
        if s.Images.Invisible then Inst.Graphic = "" end
        if s.Images.Destroy then Inst:Destroy() end

    elseif table.find(BadClasses, Inst.ClassName) then
        if s.Particles.Invisible then Inst.Enabled = false end
        if s.Particles.Destroy or s.Other["No Camera Effects"] then Inst:Destroy() end

    elseif Inst:IsA("Explosion") then
        if s.Explosions.Smaller then Inst.BlastPressure, Inst.BlastRadius = 1, 1 end
        if s.Explosions.Invisible then Inst.Visible = false end
        if s.Explosions.Destroy then Inst:Destroy() end

    elseif Inst:IsA("Clothing") or Inst:IsA("SurfaceAppearance") or Inst:IsA("BaseWrap") then
        if s.Other["No Clothes"] then Inst:Destroy() end

    elseif Inst:IsA("BasePart") and not Inst:IsA("MeshPart") then
        if s.Other["Low Quality Parts"] then Inst.Material, Inst.Reflectance = Enum.Material.SmoothPlastic, 0 end

    elseif Inst:IsA("TextLabel") and Inst:IsDescendantOf(Workspace) then
        if s.TextLabels.LowerQuality then Inst.Font, Inst.TextScaled, Inst.RichText = Enum.Font.SourceSans, false, false end
        if s.TextLabels.Invisible then Inst.Visible = false end
        if s.TextLabels.Destroy then Inst:Destroy() end

    elseif Inst:IsA("Model") then
        if s.Other["Low Quality Models"] then pcall(function() Inst.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled end) end

    elseif Inst:IsA("MeshPart") then
        if s.MeshParts.LowerQuality then
            Inst.RenderFidelity, Inst.Reflectance, Inst.Material = Enum.RenderFidelity.Performance, 0, Enum.Material.SmoothPlastic
        end
        if s.MeshParts.Invisible then Inst.Transparency = 1 end
        if s.MeshParts.NoTexture then Inst.TextureID = "" end
        if s.MeshParts.NoMesh then Inst.MeshId = "" end
        if s.MeshParts.Destroy then Inst:Destroy() end
    end
end

-- ==========================================
-- EXECUTION & LOOP
-- ==========================================
task.spawn(function()
    local s = _G.Settings.Other
    if s["Low Water Graphics"] then
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize, terrain.WaterWaveSpeed, terrain.WaterReflectance, terrain.WaterTransparency = 0, 0, 0, 0
            if sethiddenproperty then pcall(sethiddenproperty, terrain, "Decoration", false) end
        end
    end

    if s["No Shadows"] then
        Lighting.GlobalShadows, Lighting.FogEnd, Lighting.ShadowSoftness, Lighting.Brightness = false, 9e9, 0, 2
        if sethiddenproperty then pcall(sethiddenproperty, Lighting, "Technology", 2) end
    end

    if s["Low Rendering"] then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    end

    if s["Reset Materials"] then MaterialService.Use2022Materials = false end

    if s["FPS Cap"] and setfpscap then
        setfpscap(1000000)
    end
end)

local descendants = Workspace:GetDescendants()
local totalDescendants = #descendants

-- Progress Bar UI Setup
local ProgressGui = Instance.new("Frame", NotifGui)
ProgressGui.Size = UDim2.new(0, 350, 0, 50)
ProgressGui.Position = UDim2.new(0.5, -175, 0.9, 0)
ProgressGui.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
ProgressGui.BackgroundTransparency = 1
Instance.new("UICorner", ProgressGui).CornerRadius = UDim.new(0, 8)

local PStroke = Instance.new("UIStroke", ProgressGui)
PStroke.Color, PStroke.Transparency, PStroke.Thickness = Color3.fromRGB(80, 120, 255), 1, 1.5

local PText = Instance.new("TextLabel", ProgressGui)
PText.Size, PText.Position = UDim2.new(1, 0, 0.5, 0), UDim2.new(0, 0, 0, 5)
PText.BackgroundTransparency, PText.Font = 1, Enum.Font.GothamBold
PText.Text, PText.TextColor3, PText.TextSize = "Optimizing Map Assets... 0%", Color3.fromRGB(220, 220, 225), 13
PText.TextTransparency = 1

local BarBG = Instance.new("Frame", ProgressGui)
BarBG.Size, BarBG.Position = UDim2.new(0.9, 0, 0, 6), UDim2.new(0.05, 0, 0.65, 0)
BarBG.BackgroundColor3, BarBG.BackgroundTransparency = Color3.fromRGB(15, 15, 20), 1
Instance.new("UICorner", BarBG).CornerRadius = UDim.new(1, 0)

local BarFill = Instance.new("Frame", BarBG)
BarFill.Size, BarFill.BackgroundColor3, BarFill.BackgroundTransparency = UDim2.new(0, 0, 1, 0), Color3.fromRGB(80, 120, 255), 1
Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)

-- Fade in Progress Bar
TweenService:Create(ProgressGui, TweenInfo.new(0.5), {Position = UDim2.new(0.5, -175, 0.85, 0), BackgroundTransparency = 0.15}):Play()
TweenService:Create(PStroke, TweenInfo.new(0.5), {Transparency = 0.5}):Play()
TweenService:Create(PText, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
TweenService:Create(BarBG, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()
TweenService:Create(BarFill, TweenInfo.new(0.5), {BackgroundTransparency = 0}):Play()

-- Process loop with Progress Updates
for i, target in ipairs(descendants) do
    if ValidTargetClasses[target.ClassName] or target:IsA("BasePart") or target:IsA("DataModelMesh") then
        CheckIfBad(target)
    end
    
    -- Update UI efficiently every 2500 items to prevent UI lag
    if i % 2500 == 0 then 
        local percent = math.floor((i / totalDescendants) * 100)
        PText.Text = "Optimizing Map Assets... " .. percent .. "%"
        TweenService:Create(BarFill, TweenInfo.new(0.1), {Size = UDim2.new(i / totalDescendants, 0, 1, 0)}):Play()
        task.wait() 
    end 
end

-- Optimization Complete Sequence
PText.Text = "Optimization Complete! 100%"
TweenService:Create(BarFill, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 1, 0)}):Play()
task.wait(1.5)

-- Fade out Progress Bar
TweenService:Create(ProgressGui, TweenInfo.new(0.5), {Position = UDim2.new(0.5, -175, 0.9, 0), BackgroundTransparency = 1}):Play()
TweenService:Create(PStroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
TweenService:Create(PText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
TweenService:Create(BarBG, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
TweenService:Create(BarFill, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
task.delay(0.5, function() ProgressGui:Destroy() end)

Workspace.DescendantAdded:Connect(function(Inst)
    if ValidTargetClasses[Inst.ClassName] or Inst:IsA("BasePart") or Inst:IsA("DataModelMesh") then
        task.defer(CheckIfBad, Inst)
    end
end)

if _G.Settings.Other.ClearNilInstances and getnilinstances then
    task.spawn(function()
        while task.wait(60) do
            for _, inst in ipairs(getnilinstances()) do pcall(inst.Destroy, inst) end
        end
    end)
end

Notify("Ultimate FPS Engine Active & Stable!", 5)
