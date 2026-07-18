-- [[ HOSTED CORE ENGINE ]]
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Safely inherit settings from the loader, or use fallbacks if ran directly
_G.Ignore = _G.Ignore or {}
if _G.SendNotifications == nil then _G.SendNotifications = true end
if _G.ConsoleLogs == nil then _G.ConsoleLogs = false end
_G.Settings = _G.Settings or {
    Players = { ["Ignore Me"] = true, ["Ignore Others"] = true, ["Ignore Tools"] = true },
    Meshes = { NoMesh = false, NoTexture = true, Destroy = false },
    Images = { Invisible = true, Destroy = true },
    Explosions = { Smaller = true, Invisible = true, Destroy = true },
    Particles = { Invisible = true, Destroy = true },
    TextLabels = { LowerQuality = true, Invisible = false, Destroy = false },
    MeshParts = { LowerQuality = true, Invisible = false, NoTexture = true, NoMesh = false, Destroy = false },
    Other = {
        ["FPS Cap"] = true, ["No Camera Effects"] = true, ["No Clothes"] = true,
        ["Low Water Graphics"] = true, ["No Shadows"] = true, ["Low Rendering"] = true,
        ["Low Quality Parts"] = true, ["Low Quality Models"] = true, ["Reset Materials"] = true,
        ClearNilInstances = true 
    }
}

-- Service Caching
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local MaterialService = game:GetService("MaterialService")
local Workspace = game:GetService("Workspace")

local ME = Players.LocalPlayer
local BadClasses = {
    "ParticleEmitter", "Trail", "Smoke", "Fire", "Sparkles", 
    "PostEffect", "BloomEffect", "BlurEffect", "ColorCorrectionEffect", 
    "SunRaysEffect", "DepthOfFieldEffect"
}

-- Target Filter for incoming assets
local ValidTargetClasses = {
    ["Part"] = true, ["MeshPart"] = true, ["Decal"] = true, ["Texture"] = true,
    ["SpecialMesh"] = true, ["BlockMesh"] = true, ["CylinderMesh"] = true,
    ["ParticleEmitter"] = true, ["Trail"] = true, ["Smoke"] = true, 
    ["Fire"] = true, ["Sparkles"] = true, ["Explosion"] = true, 
    ["ShirtGraphic"] = true, ["Clothing"] = true, ["SurfaceAppearance"] = true, 
    ["BaseWrap"] = true, ["TextLabel"] = true, ["Model"] = true
}

local function Notify(text)
    if _G.SendNotifications then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "FPS Booster",
                Text = text,
                Duration = 4,
                Button1 = "Okay"
            })
        end)
    end
    if _G.ConsoleLogs then warn("[FPS Booster] " .. text) end
end

local function PartOfCharacter(Inst)
    local playersList = Players:GetPlayers()
    for i = 1, #playersList do
        local v = playersList[i]
        if v ~= ME and v.Character and Inst:IsDescendantOf(v.Character) then
            return true
        end
    end
    return false
end

local function DescendantOfIgnore(Inst)
    for i = 1, #_G.Ignore do
        if Inst:IsDescendantOf(_G.Ignore[i]) then
            return true
        end
    end
    return false
end

local function CheckIfBad(Inst)
    if not Inst or not Inst.Parent then return end
    if Inst:IsDescendantOf(Players) then return end
    
    if _G.Settings.Players["Ignore Others"] and PartOfCharacter(Inst) then return end
    if _G.Settings.Players["Ignore Me"] and ME.Character and Inst:IsDescendantOf(ME.Character) then return end
    if _G.Settings.Players["Ignore Tools"] and (Inst:IsA("BackpackItem") or Inst:FindFirstAncestorWhichIsA("BackpackItem")) then return end
    if #_G.Ignore > 0 and (table.find(_G.Ignore, Inst) or DescendantOfIgnore(Inst)) then return end

    local className = Inst.ClassName

    if Inst:IsA("DataModelMesh") then
        if Inst:IsA("SpecialMesh") then
            if _G.Settings.Meshes.NoMesh then Inst.MeshId = "" end
            if _G.Settings.Meshes.NoTexture then Inst.TextureId = "" end
        end
        if _G.Settings.Meshes.Destroy then Inst:Destroy() end

    elseif Inst:IsA("FaceInstance") or Inst:IsA("Decal") or Inst:IsA("Texture") then
        if _G.Settings.Images.Invisible then Inst.Transparency = 1 end
        if _G.Settings.Images.Destroy then Inst:Destroy() end

    elseif Inst:IsA("ShirtGraphic") then
        if _G.Settings.Images.Invisible then Inst.Graphic = "" end
        if _G.Settings.Images.Destroy then Inst:Destroy() end

    elseif table.find(BadClasses, className) then
        if _G.Settings.Particles.Invisible then Inst.Enabled = false end
        if _G.Settings.Particles.Destroy or _G.Settings.Other["No Camera Effects"] then Inst:Destroy() end

    elseif Inst:IsA("Explosion") then
        if _G.Settings.Explosions.Smaller then
            Inst.BlastPressure = 1
            Inst.BlastRadius = 1
        end
        if _G.Settings.Explosions.Invisible then Inst.Visible = false end
        if _G.Settings.Explosions.Destroy then Inst:Destroy() end

    elseif Inst:IsA("Clothing") or Inst:IsA("SurfaceAppearance") or Inst:IsA("BaseWrap") then
        if _G.Settings.Other["No Clothes"] then Inst:Destroy() end

    elseif Inst:IsA("BasePart") and not Inst:IsA("MeshPart") then
        if _G.Settings.Other["Low Quality Parts"] then
            Inst.Material = Enum.Material.SmoothPlastic
            Inst.Reflectance = 0
        end

    elseif Inst:IsA("TextLabel") and Inst:IsDescendantOf(Workspace) then
        if _G.Settings.TextLabels.LowerQuality then
            Inst.Font = Enum.Font.SourceSans
            Inst.TextScaled = false
            Inst.RichText = false
        end
        if _G.Settings.TextLabels.Invisible then Inst.Visible = false end
        if _G.Settings.TextLabels.Destroy then Inst:Destroy() end

    elseif Inst:IsA("Model") then
        if _G.Settings.Other["Low Quality Models"] then
            pcall(function() Inst.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled end)
        end

    elseif Inst:IsA("MeshPart") then
        if _G.Settings.MeshParts.LowerQuality then
            Inst.RenderFidelity = Enum.RenderFidelity.Performance
            Inst.Reflectance = 0
            Inst.Material = Enum.Material.SmoothPlastic
        end
        if _G.Settings.MeshParts.Invisible then Inst.Transparency = 1 end
        if _G.Settings.MeshParts.NoTexture then Inst.TextureID = "" end
        if _G.Settings.MeshParts.NoMesh then Inst.MeshId = "" end
        if _G.Settings.MeshParts.Destroy then Inst:Destroy() end
    end
end

task.spawn(function()
    if _G.Settings.Other["Low Water Graphics"] then
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
            if sethiddenproperty then pcall(sethiddenproperty, terrain, "Decoration", false) end
        end
    end

    if _G.Settings.Other["No Shadows"] then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.ShadowSoftness = 0
        Lighting.Brightness = 2
        if sethiddenproperty then pcall(sethiddenproperty, Lighting, "Technology", 2) end
    end

    if _G.Settings.Other["Low Rendering"] then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    end

    if _G.Settings.Other["Reset Materials"] then
        MaterialService.Use2022Materials = false
    end

    if _G.Settings.Other["FPS Cap"] and setfpscap then
        setfpscap(1000000)
        Notify("FPS Uncapped successfully!")
    end
end)

local descendants = Workspace:GetDescendants()
Notify("Parsing map details (" .. #descendants .. " items). Please wait...")

for i = 1, #descendants do
    local target = descendants[i]
    if ValidTargetClasses[target.ClassName] or target:IsA("BasePart") or target:IsA("DataModelMesh") then
        CheckIfBad(target)
    end
    if i % 4000 == 0 then task.wait() end 
end

Workspace.DescendantAdded:Connect(function(Inst)
    if ValidTargetClasses[Inst.ClassName] or Inst:IsA("BasePart") or Inst:IsA("DataModelMesh") then
        task.defer(CheckIfBad, Inst)
    end
end)

if _G.Settings.Other.ClearNilInstances and getnilinstances then
    task.spawn(function()
        while task.wait(60) do
            local nilInstances = getnilinstances()
            for i = 1, #nilInstances do
                pcall(nilInstances[i].Destroy, nilInstances[i])
            end
        end
    end)
end

Notify("Ultimate FPS Engine Active & Stable!")
