_G.Ignore            = _G.Ignore or {}
_G.SendNotifications = true
_G.ConsoleLogs       = false

_G.Settings = {
    -- Target Exclusions (What to keep safe)
    Players = {
        ["Ignore Me"]     = true,
        ["Ignore Others"] = true,
        ["Ignore Tools"]  = true
    },

    -- 3D Assets & Details
    Meshes = {
        NoMesh    = false, -- Set true to remove mesh data completely
        NoTexture = true,  -- Strips VRAM-heavy textures
        Destroy   = false
    },
    MeshParts = {
        LowerQuality = true,
        Invisible    = false,
        NoTexture    = true,
        NoMesh       = true,
        Destroy      = false
    },

    -- 2D Visuals & UI
    Images = {
        Invisible = true,
        Destroy   = true
    },
    TextLabels = {
        LowerQuality = true,
        Invisible    = false,
        Destroy      = false
    },

    -- Effects & Visual Hazards
    Explosions = {
        Smaller   = true,
        Invisible = true,
        Destroy   = true
    },
    Particles = {
        Invisible = true,
        Destroy   = true
    },

    -- Global Core Optimizations
    Other = {
        ["FPS Cap"]             = true, -- Uncaps frame rate
        ["No Shadows"]          = true,
        ["No Clothes"]          = true,
        ["No Camera Effects"]   = true,
        ["Low Water Graphics"]  = true,
        ["Low Rendering"]       = true,
        ["Low Quality Parts"]   = true,
        ["Low Quality Models"]  = true,
        ["Reset Materials"]     = true,
        ClearNilInstances       = true
    }
}


if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local MaterialService = game:GetService("MaterialService")
local Workspace = game:GetService("Workspace")
local ME = Players.LocalPlayer

-- Hash map lookup instead of table.find for lightning-fast performance
local BadClasses = {
    ParticleEmitter = true, Trail = true, Smoke = true, Fire = true, Sparkles = true, 
    PostEffect = true, BloomEffect = true, BlurEffect = true, ColorCorrectionEffect = true, 
    SunRaysEffect = true, DepthOfFieldEffect = true
}

local function Notify(text)
    if _G.SendNotifications then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "FPS Booster",
                Text = text,
                Duration = 5,
                Button1 = "Okay"
            })
        end)
    end
    if _G.ConsoleLogs then warn("[FPS Booster] " .. text) end
end

local function IsPlayerItem(Inst)
    if _G.Settings.Players["Ignore Others"] then
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= ME and v.Character and Inst:IsDescendantOf(v.Character) then return true end
        end
    end
    if _G.Settings.Players["Ignore Me"] and ME.Character and Inst:IsDescendantOf(ME.Character) then return true end
    if _G.Settings.Players["Ignore Tools"] and (Inst:IsA("BackpackItem") or Inst:FindFirstAncestorWhichIsA("BackpackItem")) then return true end
    return false
end

local function IsIgnored(Inst)
    for _, v in ipairs(_G.Ignore) do
        if Inst == v or Inst:IsDescendantOf(v) then return true end
    end
    return false
end

local function OptimizeInstance(Inst)
    if Inst:IsDescendantOf(Players) or IsPlayerItem(Inst) or IsIgnored(Inst) then return end

    local className = Inst.ClassName
    local cfg = _G.Settings

    if Inst:IsA("DataModelMesh") then
        if Inst:IsA("SpecialMesh") then
            if cfg.Meshes.NoMesh then Inst.MeshId = "" end
            if cfg.Meshes.NoTexture then Inst.TextureId = "" end
        end
        if cfg.Meshes.Destroy then Inst:Destroy() end

    elseif Inst:IsA("FaceInstance") or Inst:IsA("Decal") or Inst:IsA("Texture") then
        if cfg.Images.Invisible then Inst.Transparency = 1 end
        if cfg.Images.Destroy then Inst:Destroy() end

    elseif Inst:IsA("ShirtGraphic") then
        if cfg.Images.Invisible then Inst.Graphic = "" end
        if cfg.Images.Destroy then Inst:Destroy() end

    elseif BadClasses[className] then
        if cfg.Particles.Invisible then Inst.Enabled = false end
        if cfg.Particles.Destroy or cfg.Other["No Camera Effects"] then Inst:Destroy() end

    elseif Inst:IsA("Explosion") then
        if cfg.Explosions.Smaller then
            Inst.BlastPressure, Inst.BlastRadius = 1, 1
        end
        if cfg.Explosions.Invisible then Inst.Visible = false end
        if cfg.Explosions.Destroy then Inst:Destroy() end

    elseif Inst:IsA("Clothing") or Inst:IsA("SurfaceAppearance") or Inst:IsA("BaseWrap") then
        if cfg.Other["No Clothes"] then Inst:Destroy() end

    elseif Inst:IsA("BasePart") and not Inst:IsA("MeshPart") then
        if cfg.Other["Low Quality Parts"] then
            Inst.Material, Inst.Reflectance = Enum.Material.SmoothPlastic, 0
        end

    elseif Inst:IsA("TextLabel") and Inst:IsDescendantOf(Workspace) then
        if cfg.TextLabels.LowerQuality then
            Inst.Font, Inst.TextScaled, Inst.RichText = Enum.Font.SourceSans, false, false
        end
        if cfg.TextLabels.Invisible then Inst.Visible = false end
        if cfg.TextLabels.Destroy then Inst:Destroy() end

    elseif Inst:IsA("Model") then
        if cfg.Other["Low Quality Models"] then
            pcall(function() Inst.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled end)
        end

    elseif Inst:IsA("MeshPart") then
        if cfg.MeshParts.LowerQuality then
            Inst.RenderFidelity, Inst.Reflectance, Inst.Material = Enum.RenderFidelity.Performance, 0, Enum.Material.SmoothPlastic
        end
        if cfg.MeshParts.Invisible then Inst.Transparency = 1 end
        if cfg.MeshParts.NoTexture then Inst.TextureID = "" end
        if cfg.MeshParts.NoMesh then Inst.MeshId = "" end
        if cfg.MeshParts.Destroy then Inst:Destroy() end
    end
end

-- World/Environment Level Tweaks
coroutine.wrap(pcall)(function()
    local cfg = _G.Settings.Other
    local terrain = Workspace:FindFirstChildOfClass("Terrain")
    
    if cfg["Low Water Graphics"] and terrain then
        terrain.WaterWaveSize, terrain.WaterWaveSpeed = 0, 0
        terrain.WaterReflectance, terrain.WaterTransparency = 0, 0
        if sethiddenproperty then sethiddenproperty(terrain, "Decoration", false) end
    end

    if cfg["No Shadows"] then
        Lighting.GlobalShadows, Lighting.ShadowSoftness, Lighting.Brightness, Lighting.FogEnd = false, 0, 2, 9e9
        if sethiddenproperty then sethiddenproperty(Lighting, "Technology", 2) end
    end

    if cfg["Low Rendering"] then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    end

    if cfg["Reset Materials"] then MaterialService.Use2022Materials = false end
    if cfg["FPS Cap"] and setfpscap then setfpscap(1000000) end
    
    if cfg.ClearNilInstances and getnilinstances then
        for _, v in ipairs(getnilinstances()) do pcall(function() v:Destroy() end) end
    end
end)()

-- Index Initial World Instances
local Descendants = game:GetDescendants()
Notify("Optimizing " .. #Descendants .. " active instances. Brief freeze expected...")

for i, v in ipairs(Descendants) do
    OptimizeInstance(v)
    if i % 3000 == 0 then task.wait() end -- Increased frequency slightly for optimization speed
end

-- Continuous Dynamic Optimization
game.DescendantAdded:Connect(function(Inst)
    task.defer(OptimizeInstance, Inst)
end)

Notify("FPS Booster Engine Active!")
