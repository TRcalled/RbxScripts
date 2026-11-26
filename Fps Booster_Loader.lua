if not game:IsLoaded() then
    game.Loaded:Wait()
end

if type(_G._FPSBoosterCleanup) == "function" then
    pcall(_G._FPSBoosterCleanup)
end

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ME = Players.LocalPlayer
while not ME do
    task.wait()
    ME = Players.LocalPlayer
end

_G.Ignore = _G.Ignore or {}
if _G.SendNotifications == nil then
    _G.SendNotifications = true
end
if _G.ConsoleLogs == nil then
    _G.ConsoleLogs = false
end

local function def(tbl, defaults)
    if type(tbl) ~= "table" then
        tbl = {}
    end
    for k, v in pairs(defaults) do
        if tbl[k] == nil then
            tbl[k] = v
        end
    end
    return tbl
end

_G.Settings = _G.Settings or {}
_G.Settings.Players = def(_G.Settings.Players, {
    ["Ignore Me"] = true,
    ["Ignore Others"] = false,
    ["Ignore Tools"] = true,
    ["Hide Others"] = true,
})
_G.Settings.Meshes = def(_G.Settings.Meshes, {
    NoMesh = true,
    NoTexture = true,
    Destroy = false,
})
_G.Settings.MeshParts = def(_G.Settings.MeshParts, {
    LowerQuality = true,
    Invisible = false,
    NoTexture = true,
    NoMesh = false,
    Destroy = false,
})
_G.Settings.Images = def(_G.Settings.Images, {
    Invisible = true,
    Destroy = true,
})
_G.Settings.TextLabels = def(_G.Settings.TextLabels, {
    LowerQuality = true,
    Invisible = true,
    Destroy = false,
})
_G.Settings.Explosions = def(_G.Settings.Explosions, {
    Smaller = true,
    Invisible = true,
    Destroy = true,
})
_G.Settings.Particles = def(_G.Settings.Particles, {
    Invisible = true,
    Destroy = true,
})
_G.Settings.Other = def(_G.Settings.Other, {
    ["FPS Cap"] = true,
    ["Target FPS"] = 240,
    ["No Shadows"] = true,
    ["No Lights"] = true,
    ["No Clothes"] = true,
    ["No Camera Effects"] = true,
    ["Low Water Graphics"] = true,
    ["Low Rendering"] = true,
    ["Low Quality Parts"] = true,
    ["Low Quality Models"] = true,
    ["Hide World Parts"] = false,
    ["Disable World UI"] = true,
    ["Mute World Sounds"] = false,
    ["No 3D Rendering"] = false,
    ["Reset Materials"] = true,
    ClearNilInstances = true,
})

local ParticleClasses = {
    ParticleEmitter = true,
    Trail = true,
    Beam = true,
    Smoke = true,
    Fire = true,
    Sparkles = true,
    Highlight = true,
    SelectionBox = true,
    SelectionSphere = true,
}

local LightClasses = {
    PointLight = true,
    SpotLight = true,
    SurfaceLight = true,
}

local NilSafeDestroyClasses = {
    ParticleEmitter = true,
    Trail = true,
    Beam = true,
    Smoke = true,
    Fire = true,
    Sparkles = true,
    Explosion = true,
    Decal = true,
    Texture = true,
    ShirtGraphic = true,
    SurfaceAppearance = true,
    Highlight = true,
    PointLight = true,
    SpotLight = true,
    SurfaceLight = true,
    BloomEffect = true,
    BlurEffect = true,
    ColorCorrectionEffect = true,
    SunRaysEffect = true,
    DepthOfFieldEffect = true,
}

local IgnoreLookup = {}
for _, v in ipairs(_G.Ignore) do
    if typeof(v) == "Instance" then
        IgnoreLookup[v] = true
    end
end

local Conns = {}
local PendingQueue = {}
local Active = true

_G._FPSBoosterCleanup = function()
    Active = false
    for _, c in ipairs(Conns) do
        if c and c.Connected then
            c:Disconnect()
        end
    end
    table.clear(Conns)
    table.clear(PendingQueue)
    pcall(function()
        RunService:Set3dRenderingEnabled(true)
    end)
end

local function Notify(text)
    if _G.SendNotifications then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "FPS Booster",
                Text = text,
                Duration = 5,
                Button1 = "Okay",
            })
        end)
    end
    if _G.ConsoleLogs then
        warn("[FPS Booster] " .. tostring(text))
    end
end

local function IsIgnored(Inst)
    if next(IgnoreLookup) then
        local cur = Inst
        while cur do
            if IgnoreLookup[cur] then
                return true
            end
            cur = cur.Parent
        end
    end
    local pCfg = _G.Settings.Players
    if pCfg["Ignore Tools"] and (Inst:IsA("BackpackItem") or Inst:FindFirstAncestorWhichIsA("BackpackItem")) then
        return true
    end
    local myChar = ME.Character
    if pCfg["Ignore Me"] and myChar and (Inst == myChar or Inst:IsDescendantOf(myChar)) then
        return true
    end
    local mdl = Inst:IsA("Model") and Inst or Inst:FindFirstAncestorOfClass("Model")
    if mdl then
        local plr = Players:GetPlayerFromCharacter(mdl)
        if plr and plr ~= ME then
            if pCfg["Ignore Others"] then
                return true
            end
            if pCfg["Hide Others"] and Inst:IsA("BasePart") then
                pcall(function()
                    Inst.LocalTransparencyModifier = 1
                    Inst.CastShadow = false
                end)
            end
        end
    end
    return false
end

local function OptimizeInstance(Inst)
    if not Inst or not Inst.Parent or IsIgnored(Inst) then
        return
    end

    local cfg = _G.Settings
    local other = cfg.Other
    local className = Inst.ClassName

    if Inst:IsA("DataModelMesh") then
        if Inst:IsA("SpecialMesh") then
            if cfg.Meshes.NoMesh then
                pcall(function()
                    Inst.MeshId = ""
                end)
            end
            if cfg.Meshes.NoTexture then
                pcall(function()
                    Inst.TextureId = ""
                end)
            end
        end
        if cfg.Meshes.Destroy then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif Inst:IsA("Decal") or Inst:IsA("Texture") then
        if cfg.Images.Invisible then
            Inst.Transparency = 1
        end
        if cfg.Images.Destroy then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif Inst:IsA("ShirtGraphic") then
        if cfg.Images.Invisible then
            Inst.Graphic = ""
        end
        if cfg.Images.Destroy then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif ParticleClasses[className] then
        if cfg.Particles.Invisible then
            pcall(function()
                Inst.Enabled = false
            end)
            if Inst:IsA("ParticleEmitter") then
                pcall(function()
                    Inst.Rate = 0
                    Inst:Clear()
                end)
            end
        end
        if cfg.Particles.Destroy then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif LightClasses[className] then
        if other["No Lights"] or other["No Shadows"] then
            pcall(function()
                Inst.Shadows = false
                if other["No Lights"] then
                    Inst.Enabled = false
                    Inst.Range = 0
                    Inst.Brightness = 0
                end
            end)
        end

    elseif Inst:IsA("PostEffect") then
        if other["No Camera Effects"] or cfg.Particles.Invisible then
            Inst.Enabled = false
        end
        if other["No Camera Effects"] then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif Inst:IsA("Atmosphere") then
        if other["No Camera Effects"] then
            pcall(function()
                Inst.Density = 0
                Inst.Offset = 0
                Inst.Glare = 0
                Inst.Haze = 0
            end)
        end

    elseif Inst:IsA("Clouds") then
        if other["No Camera Effects"] or cfg.Particles.Invisible then
            pcall(function()
                Inst.Enabled = false
                Inst.Cover = 0
                Inst.Density = 0
            end)
        end

    elseif Inst:IsA("Sky") then
        if other["No Camera Effects"] then
            pcall(function()
                Inst.CelestialBodiesShown = false
                Inst.StarCount = 0
            end)
        end

    elseif Inst:IsA("Explosion") then
        if cfg.Explosions.Smaller then
            Inst.BlastPressure = 1
            Inst.BlastRadius = 1
        end
        if cfg.Explosions.Invisible then
            Inst.Visible = false
        end
        if cfg.Explosions.Destroy then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif Inst:IsA("Clothing") or Inst:IsA("SurfaceAppearance") or Inst:IsA("BaseWrap") then
        if other["No Clothes"] then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif Inst:IsA("MeshPart") then
        if cfg.MeshParts.LowerQuality or other["Low Quality Parts"] then
            Inst.Material = Enum.Material.SmoothPlastic
            Inst.Reflectance = 0
            Inst.CastShadow = false
        end
        if cfg.MeshParts.NoTexture then
            pcall(function()
                Inst.TextureID = ""
            end)
        end
        if cfg.MeshParts.Invisible or other["Hide World Parts"] then
            Inst.LocalTransparencyModifier = 1
        end
        if cfg.MeshParts.Destroy then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif Inst:IsA("BasePart") and not Inst:IsA("Terrain") then
        if other["Low Quality Parts"] then
            Inst.Material = Enum.Material.SmoothPlastic
            Inst.Reflectance = 0
            Inst.CastShadow = false
        end
        if other["Hide World Parts"] then
            Inst.LocalTransparencyModifier = 1
        end

    elseif Inst:IsA("BillboardGui") or Inst:IsA("SurfaceGui") then
        if other["Disable World UI"] or cfg.TextLabels.Invisible then
            pcall(function()
                Inst.Enabled = false
            end)
        end

    elseif Inst:IsA("TextLabel") then
        if cfg.TextLabels.LowerQuality then
            pcall(function()
                Inst.Font = Enum.Font.SourceSans
                Inst.TextScaled = false
                Inst.RichText = false
            end)
        end
        if cfg.TextLabels.Invisible then
            Inst.Visible = false
        end
        if cfg.TextLabels.Destroy then
            pcall(function()
                Inst:Destroy()
            end)
        end

    elseif Inst:IsA("Model") then
        if other["Low Quality Models"] then
            pcall(function()
                Inst.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
            end)
        end

    elseif Inst:IsA("Sound") and other["Mute World Sounds"] then
        pcall(function()
            Inst.Volume = 0
            Inst:Stop()
        end)
    end
end

local function ApplyEnvironmentTweaks()
    local other = _G.Settings.Other

    pcall(function()
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if other["Low Water Graphics"] and terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 0
            local sethid = type(sethiddenproperty) == "function" and sethiddenproperty or nil
            if sethid then
                pcall(sethid, terrain, "Decoration", false)
            else
                pcall(function()
                    terrain.Decoration = false
                end)
            end
        end
    end)

    pcall(function()
        if other["No Shadows"] then
            Lighting.GlobalShadows = false
            Lighting.ShadowSoftness = 0
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            Lighting.FogEnd = 9e9
            local sethid = type(sethiddenproperty) == "function" and sethiddenproperty or nil
            if sethid then
                pcall(sethid, Lighting, "Technology", Enum.Technology.Voxel)
            end
        end
    end)

    pcall(function()
        if other["Low Rendering"] then
            local r = settings().Rendering
            r.QualityLevel = Enum.QualityLevel.Level01
            r.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
        end
    end)

    pcall(function()
        if other["Reset Materials"] then
            MaterialService.Use2022Materials = false
        end
    end)

    pcall(function()
        if other["FPS Cap"] and type(setfpscap) == "function" then
            local cap = tonumber(other["Target FPS"])
            setfpscap(cap and cap > 0 and cap or 240)
        end
    end)

    pcall(function()
        if other["No 3D Rendering"] then
            RunService:Set3dRenderingEnabled(false)
        end
    end)

    pcall(function()
        if other.ClearNilInstances and type(getnilinstances) == "function" then
            for _, v in ipairs(getnilinstances()) do
                if typeof(v) == "Instance" and NilSafeDestroyClasses[v.ClassName] then
                    pcall(function()
                        v:Destroy()
                    end)
                end
            end
        end
    end)
end

ApplyEnvironmentTweaks()

local Targets = {}
for _, container in ipairs({ Workspace, Lighting }) do
    for _, desc in ipairs(container:GetDescendants()) do
        Targets[#Targets + 1] = desc
    end
end
local cam = Workspace.CurrentCamera
if cam then
    for _, desc in ipairs(cam:GetDescendants()) do
        Targets[#Targets + 1] = desc
    end
end

Notify("Optimizing " .. tostring(#Targets) .. " world & lighting instances...")

for i, inst in ipairs(Targets) do
    if not Active then
        break
    end
    OptimizeInstance(inst)
    if i % 1500 == 0 then
        task.wait()
    end
end
table.clear(Targets)

local function QueueInstance(Inst)
    if Active and Inst and Inst.Parent then
        PendingQueue[#PendingQueue + 1] = Inst
    end
end

table.insert(Conns, Workspace.DescendantAdded:Connect(QueueInstance))
table.insert(Conns, Lighting.DescendantAdded:Connect(QueueInstance))
if cam then
    table.insert(Conns, cam.DescendantAdded:Connect(QueueInstance))
end

table.insert(Conns, Lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
    if Active and _G.Settings.Other["No Shadows"] and Lighting.GlobalShadows then
        Lighting.GlobalShadows = false
    end
end))

table.insert(Conns, Lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
    if Active and _G.Settings.Other["No Shadows"] and Lighting.FogEnd < 1e6 then
        Lighting.FogEnd = 9e9
    end
end))

table.insert(Conns, RunService.Heartbeat:Connect(function()
    if not Active or #PendingQueue == 0 then
        return
    end
    local count = math.min(#PendingQueue, 180)
    for i = 1, count do
        local inst = table.remove(PendingQueue)
        if inst and inst.Parent then
            OptimizeInstance(inst)
        end
    end
end))

Notify("FPS Booster Engine Active!")
