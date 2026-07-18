--[[
    OPTIMIZED FPS BOOSTER
    Max Performance Edition
]]

_G.Ignore = _G.Ignore or {}
_G.SendNotifications = true
_G.ConsoleLogs = false

_G.Settings = {
    Players = {
        ["Ignore Me"] = true,
        ["Ignore Others"] = true,
        ["Ignore Tools"] = true
    },
    Meshes = {
        NoMesh = false,   -- Kept false to not break hitboxes
        NoTexture = true, -- Removes textures to save VRAM
        Destroy = false
    },
    Images = {
        Invisible = true,
        Destroy = true    -- Destroys decals/images entirely
    },
    Explosions = {
        Smaller = true,
        Invisible = true, 
        Destroy = true    -- Completely removes explosions
    },
    Particles = {
        Invisible = true,
        Destroy = true    -- Destroys all particles to save CPU
    },
    TextLabels = {
        LowerQuality = true,
        Invisible = false,
        Destroy = false
    },
    MeshParts = {
        LowerQuality = true,
        Invisible = false,
        NoTexture = true, -- Strips textures off maps
        NoMesh = false,
        Destroy = false
    },
    Other = {
        ["FPS Cap"] = true, -- true = Uncapped FPS
        ["No Camera Effects"] = true,
        ["No Clothes"] = true,
        ["Low Water Graphics"] = true,
        ["No Shadows"] = true,
        ["Low Rendering"] = true,
        ["Low Quality Parts"] = true,
        ["Low Quality Models"] = true,
        ["Reset Materials"] = true,
        ClearNilInstances = true 
    }
}

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Cache Services for faster access
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

-- Fast Notification Function
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

local function PartOfCharacter(Inst)
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= ME and v.Character and Inst:IsDescendantOf(v.Character) then
            return true
        end
    end
    return false
end

local function DescendantOfIgnore(Inst)
    for _, v in ipairs(_G.Ignore) do
        if Inst:IsDescendantOf(v) then
            return true
        end
    end
    return false
end

local function CheckIfBad(Inst)
    if not Inst:IsDescendantOf(Players) 
    and (_G.Settings.Players["Ignore Others"] and not PartOfCharacter(Inst) or not _G.Settings.Players["Ignore Others"]) 
    and (_G.Settings.Players["Ignore Me"] and ME.Character and not Inst:IsDescendantOf(ME.Character) or not _G.Settings.Players["Ignore Me"]) 
    and (_G.Settings.Players["Ignore Tools"] and not Inst:IsA("BackpackItem") and not Inst:FindFirstAncestorWhichIsA("BackpackItem") or not _G.Settings.Players["Ignore Tools"]) 
    and (#_G.Ignore == 0 or (not table.find(_G.Ignore, Inst) and not DescendantOfIgnore(Inst))) then

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
                Inst.Material = Enum.Material.SmoothPlastic -- SmoothPlastic is cheaper than Plastic
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
end

-- Apply Global World Optimizations
coroutine.wrap(pcall)(function()
    if _G.Settings.Other["Low Water Graphics"] then
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
            if sethiddenproperty then
                sethiddenproperty(terrain, "Decoration", false)
            end
        end
    end

    if _G.Settings.Other["No Shadows"] then
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.ShadowSoftness = 0
        Lighting.Brightness = 2
        if sethiddenproperty then
            sethiddenproperty(Lighting, "Technology", 2)
        end
    end

    if _G.Settings.Other["Low Rendering"] then
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
    end

    if _G.Settings.Other["Reset Materials"] then
        MaterialService.Use2022Materials = false
    end

    if _G.Settings.Other["FPS Cap"] then
        if setfpscap then
            setfpscap(1000000) -- Effectively uncapped
            Notify("FPS Uncapped!")
        end
    end

    if _G.Settings.Other.ClearNilInstances and getnilinstances then
        for _, v in ipairs(getnilinstances()) do
            pcall(function() v:Destroy() end)
        end
    end
end)

-- Process existing instances in chunks to prevent lag/crashing
local Descendants = game:GetDescendants()
Notify("Applying optimizations to " .. #Descendants .. " instances. Game may freeze briefly...")

for i, v in ipairs(Descendants) do
    CheckIfBad(v)
    -- Yield the thread every 2000 items so the client doesn't crash from overload
    if i % 2000 == 0 then task.wait() end
end

-- Optimized Listener for new instances
game.DescendantAdded:Connect(function(Inst)
    -- task.defer runs at the end of the current frame, much faster and safer than wait(1)
    task.defer(CheckIfBad, Inst)
end)

Notify("FPS Booster Loaded Successfully!")