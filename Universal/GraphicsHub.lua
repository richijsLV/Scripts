--// Syde Graphics+ Hub
--// Smooth FPS / Realism / Ambience / FOV / WalkSpeed / Animation Pack Changer
--// Uses Heartbeat fog lock + batched world optimization.

local ENV = ((type(getgenv) == "function") and getgenv()) or _G

if ENV.__SydeGraphicsPlus and ENV.__SydeGraphicsPlus.Cleanup then
    pcall(ENV.__SydeGraphicsPlus.Cleanup)
end

--// Services
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Terrain = Workspace:FindFirstChildOfClass("Terrain")

--// Syde UI
local syde = loadstring(game:HttpGet("https://raw.githubusercontent.com/essencejs/syde/refs/heads/main/source", true))()

syde:Load({
    Logo = "7488932274",
    Name = "Syde Graphics+",
    Status = "Stable",
    Accent = Color3.fromRGB(190, 120, 255),
    HitBox = Color3.fromRGB(190, 120, 255),
    AutoLoad = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "SydeGraphicsPlus",
        FileName = "config"
    },
    AutoJoinDiscord = {
        Enabled = false,
        Invite = "",
        RememberJoins = false
    }
})

local Window = syde:Init({
    Title = "Syde Graphics+",
    SubText = "FPS / Realism / Ambience / Player / Animations"
})

--// State
local State = {
    Connections = {},
    Created = {},
    Originals = setmetatable({}, { __mode = "k" }),

    Queue = {},
    Queued = setmetatable({}, { __mode = "k" }),
    QueueIndex = 1,

    ScanStack = {},
    ScanActive = false,

    FPS = 0,
    LastLightingApply = 0,
    LastStatus = 0,

    CurrentAnimationPack = "Default",
    CustomAnimationPack = {
        run = "0",
        walk = "0",
        jump = "0",
        idle1 = "0",
        idle2 = "0",
        fall = "0",
        climb = "0",
        swim = "0",
        swimidle = "0",
    },

    OriginalAnimations = nil,
    PreviewTrack = nil,
    Window = Window,
}

ENV.__SydeGraphicsPlus = State

--// Settings
local Settings = {
    MasterEnabled = true,

    -- Smoothness
    AutoEnforce = true,
    HeartbeatFogLock = true,
    AutoApplyNewObjects = true,
    LightingRefreshRate = 0.35,
    WorldBatchSize = 175,
    ScanBatchSize = 40,

    -- Player
    WalkSpeedLoop = false,
    WalkSpeed = 16,
    JumpLoop = false,
    JumpPower = 50,

    -- Camera
    FOVLoop = true,
    FOV = 70,

    -- Lighting
    ClearFog = true,
    FogStart = 0,
    FogEnd = 1000000,
    FogColor = Color3.fromRGB(255, 255, 255),

    Brightness = 4,
    Exposure = 0,
    ClockTime = 14,
    GlobalShadows = true,
    ShadowSoftness = 0.2,
    Technology = "Voxel",

    Ambient = Color3.fromRGB(180, 180, 180),
    OutdoorAmbient = Color3.fromRGB(180, 180, 180),
    ColorShiftTop = Color3.fromRGB(255, 255, 255),
    ColorShiftBottom = Color3.fromRGB(0, 0, 0),
    EnvironmentDiffuseScale = 0.45,
    EnvironmentSpecularScale = 0.35,

    -- Atmosphere
    CustomAtmosphere = false,
    AtmosphereDensity = 0,
    AtmosphereOffset = 0,
    AtmosphereGlare = 0,
    AtmosphereHaze = 0,
    AtmosphereColor = Color3.fromRGB(210, 210, 210),
    AtmosphereDecay = Color3.fromRGB(110, 110, 110),

    -- Effects
    CinematicEffects = false,
    DisableAllPostEffects = false,

    BloomIntensity = 0.25,
    BloomSize = 35,
    BloomThreshold = 1.1,

    SunRaysIntensity = 0.045,
    SunRaysSpread = 0.75,

    ColorCorrectionBrightness = 0,
    ColorCorrectionContrast = 0.08,
    ColorCorrectionSaturation = 0.08,
    ColorCorrectionTint = Color3.fromRGB(255, 245, 230),

    DepthOfField = false,
    DOFFocusDistance = 70,
    DOFInFocusRadius = 45,
    DOFNearIntensity = 0,
    DOFFarIntensity = 0.18,

    Blur = false,
    BlurSize = 0,

    -- FPS
    DisableParticles = false,
    ParticleRateScale = 0.35,
    DisableTrailsBeams = false,
    DisableDecalsTextures = false,
    SmoothMaterials = false,
    DisablePartShadows = false,
    LowWater = false,
    DisableClouds = false,

    -- Animations
    AnimationAutoReapply = true,
    StopTracksOnPackChange = true,
    PreviewAnimationId = "",
    PreviewAnimationSpeed = 1,
    PreviewAnimationTime = 0,
}

--// Helpers
local function notify(title, content, duration)
    pcall(function()
        syde:Notify({
            Title = tostring(title),
            Content = tostring(content),
            Duration = duration or 2
        })
    end)
end

local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(State.Connections, c)
    return c
end

local function remember(inst, prop)
    if not inst then return nil end

    local saved = State.Originals[inst]
    if not saved then
        saved = {}
        State.Originals[inst] = saved
    end

    if saved[prop] == nil then
        local ok, value = pcall(function()
            return inst[prop]
        end)

        if ok then
            saved[prop] = value
        end
    end

    return saved[prop]
end

local function rawSet(inst, prop, value)
    pcall(function()
        inst[prop] = value
    end)
end

local function setProp(inst, prop, value)
    if not inst then return end

    local ok, current = pcall(function()
        return inst[prop]
    end)

    if ok and current == value then
        return
    end

    remember(inst, prop)

    pcall(function()
        inst[prop] = value
    end)
end

local function restoreProp(inst, prop)
    local saved = State.Originals[inst]
    if saved and saved[prop] ~= nil then
        rawSet(inst, prop, saved[prop])
    end
end

local function restoreProps(inst, props)
    for _, prop in ipairs(props) do
        restoreProp(inst, prop)
    end
end

local function restoreAll()
    for inst, saved in pairs(State.Originals) do
        if typeof(inst) == "Instance" and inst.Parent then
            for prop, value in pairs(saved) do
                rawSet(inst, prop, value)
            end
        end
    end

    for _, inst in ipairs(State.Created) do
        if inst and inst.Parent then
            pcall(function()
                inst:Destroy()
            end)
        end
    end

    State.Created = {}
    State.Queue = {}
    State.Queued = setmetatable({}, { __mode = "k" })
    State.QueueIndex = 1
    State.ScanStack = {}
    State.ScanActive = false
end

local function enumFromName(enumObject, name)
    for _, item in ipairs(enumObject:GetEnumItems()) do
        if item.Name == name then
            return item
        end
    end
    return nil
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local character = getCharacter()
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function getCamera()
    return Workspace.CurrentCamera
end

local function isPostEffect(obj)
    return obj:IsA("BloomEffect")
        or obj:IsA("BlurEffect")
        or obj:IsA("ColorCorrectionEffect")
        or obj:IsA("DepthOfFieldEffect")
        or obj:IsA("SunRaysEffect")
end

local function ensureEffect(className, name)
    local existing = Lighting:FindFirstChild(name)
    if existing and existing:IsA(className) then
        return existing
    end

    local effect = Instance.new(className)
    effect.Name = name

    pcall(function()
        effect.Enabled = false
    end)

    effect.Parent = Lighting
    table.insert(State.Created, effect)

    return effect
end

local function ensureAtmospheres()
    local atmospheres = {}

    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("Atmosphere") then
            table.insert(atmospheres, obj)
        end
    end

    if #atmospheres == 0 then
        local atmosphere = Instance.new("Atmosphere")
        atmosphere.Name = "SGP_Atmosphere"
        atmosphere.Parent = Lighting
        table.insert(State.Created, atmosphere)
        table.insert(atmospheres, atmosphere)
    end

    return atmospheres
end

--// Lighting / atmosphere
local function applyFogAtmosphere()
    if not Settings.MasterEnabled then return end

    if Settings.ClearFog then
        setProp(Lighting, "FogStart", 0)
        setProp(Lighting, "FogEnd", 1000000)
    else
        setProp(Lighting, "FogStart", Settings.FogStart)
        setProp(Lighting, "FogEnd", Settings.FogEnd)
    end

    setProp(Lighting, "FogColor", Settings.FogColor)

    for _, atmosphere in ipairs(ensureAtmospheres()) do
        if Settings.ClearFog and not Settings.CustomAtmosphere then
            setProp(atmosphere, "Density", 0)
            setProp(atmosphere, "Offset", 0)
            setProp(atmosphere, "Glare", 0)
            setProp(atmosphere, "Haze", 0)
        else
            setProp(atmosphere, "Density", Settings.AtmosphereDensity)
            setProp(atmosphere, "Offset", Settings.AtmosphereOffset)
            setProp(atmosphere, "Glare", Settings.AtmosphereGlare)
            setProp(atmosphere, "Haze", Settings.AtmosphereHaze)
            setProp(atmosphere, "Color", Settings.AtmosphereColor)
            setProp(atmosphere, "Decay", Settings.AtmosphereDecay)
        end
    end
end

local function applyLighting()
    if not Settings.MasterEnabled then return end

    applyFogAtmosphere()

    setProp(Lighting, "Brightness", Settings.Brightness)
    setProp(Lighting, "ExposureCompensation", Settings.Exposure)
    setProp(Lighting, "ClockTime", Settings.ClockTime)
    setProp(Lighting, "GlobalShadows", Settings.GlobalShadows)
    setProp(Lighting, "ShadowSoftness", Settings.ShadowSoftness)

    setProp(Lighting, "Ambient", Settings.Ambient)
    setProp(Lighting, "OutdoorAmbient", Settings.OutdoorAmbient)
    setProp(Lighting, "ColorShift_Top", Settings.ColorShiftTop)
    setProp(Lighting, "ColorShift_Bottom", Settings.ColorShiftBottom)

    setProp(Lighting, "EnvironmentDiffuseScale", Settings.EnvironmentDiffuseScale)
    setProp(Lighting, "EnvironmentSpecularScale", Settings.EnvironmentSpecularScale)

    local tech = enumFromName(Enum.Technology, Settings.Technology)
    if tech then
        setProp(Lighting, "Technology", tech)
    end
end

local function applyEffects()
    if not Settings.MasterEnabled then return end

    if Settings.DisableAllPostEffects then
        for _, obj in ipairs(Lighting:GetDescendants()) do
            if isPostEffect(obj) then
                setProp(obj, "Enabled", false)
            end
        end
        return
    end

    for _, obj in ipairs(Lighting:GetDescendants()) do
        if isPostEffect(obj) and not obj.Name:match("^SGP_") then
            restoreProp(obj, "Enabled")
        end
    end

    local bloom = ensureEffect("BloomEffect", "SGP_Bloom")
    setProp(bloom, "Enabled", Settings.CinematicEffects)
    setProp(bloom, "Intensity", Settings.BloomIntensity)
    setProp(bloom, "Size", Settings.BloomSize)
    setProp(bloom, "Threshold", Settings.BloomThreshold)

    local sun = ensureEffect("SunRaysEffect", "SGP_SunRays")
    setProp(sun, "Enabled", Settings.CinematicEffects)
    setProp(sun, "Intensity", Settings.SunRaysIntensity)
    setProp(sun, "Spread", Settings.SunRaysSpread)

    local cc = ensureEffect("ColorCorrectionEffect", "SGP_ColorCorrection")
    setProp(cc, "Enabled", Settings.CinematicEffects)
    setProp(cc, "Brightness", Settings.ColorCorrectionBrightness)
    setProp(cc, "Contrast", Settings.ColorCorrectionContrast)
    setProp(cc, "Saturation", Settings.ColorCorrectionSaturation)
    setProp(cc, "TintColor", Settings.ColorCorrectionTint)

    local dof = ensureEffect("DepthOfFieldEffect", "SGP_DepthOfField")
    setProp(dof, "Enabled", Settings.CinematicEffects and Settings.DepthOfField)
    setProp(dof, "FocusDistance", Settings.DOFFocusDistance)
    setProp(dof, "InFocusRadius", Settings.DOFInFocusRadius)
    setProp(dof, "NearIntensity", Settings.DOFNearIntensity)
    setProp(dof, "FarIntensity", Settings.DOFFarIntensity)

    local blur = ensureEffect("BlurEffect", "SGP_Blur")
    setProp(blur, "Enabled", Settings.CinematicEffects and Settings.Blur)
    setProp(blur, "Size", Settings.BlurSize)
end

local function applyTerrain()
    if not Terrain then return end

    if Settings.LowWater then
        setProp(Terrain, "WaterWaveSize", 0)
        setProp(Terrain, "WaterWaveSpeed", 0)
        setProp(Terrain, "WaterReflectance", 0)
        setProp(Terrain, "WaterTransparency", 1)
        setProp(Terrain, "Decoration", false)
    else
        restoreProps(Terrain, {
            "WaterWaveSize",
            "WaterWaveSpeed",
            "WaterReflectance",
            "WaterTransparency",
            "Decoration",
        })
    end
end

local function applyCamera()
    local camera = getCamera()
    if camera and Settings.FOVLoop then
        setProp(camera, "FieldOfView", Settings.FOV)
    end
end

local function applyPlayer()
    local hum = getHumanoid()
    if not hum then return end

    if Settings.WalkSpeedLoop then
        pcall(function()
            hum.WalkSpeed = Settings.WalkSpeed
        end)
    end

    if Settings.JumpLoop then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = Settings.JumpPower
        end)
    end
end

--// Batched world optimization
local function clearQueue()
    State.Queue = {}
    State.Queued = setmetatable({}, { __mode = "k" })
    State.QueueIndex = 1
end

local function isWorldObject(obj)
    return obj:IsA("ParticleEmitter")
        or obj:IsA("Trail")
        or obj:IsA("Beam")
        or obj:IsA("Smoke")
        or obj:IsA("Fire")
        or obj:IsA("Sparkles")
        or obj:IsA("Decal")
        or obj:IsA("Texture")
        or obj:IsA("BasePart")
        or obj:IsA("Highlight")
        or obj:IsA("Clouds")
end

local function queueObject(obj)
    if not obj or State.Queued[obj] or not isWorldObject(obj) then return end

    State.Queued[obj] = true
    table.insert(State.Queue, obj)
end

local function startWorldScan()
    State.ScanStack = { Workspace }
    State.ScanActive = true
end

local function applyWorldObject(obj)
    if not Settings.MasterEnabled or not obj or not obj.Parent then return end

    if obj:IsA("ParticleEmitter") then
        if Settings.DisableParticles then
            setProp(obj, "Enabled", false)
        else
            restoreProp(obj, "Enabled")
        end

        local originalRate = remember(obj, "Rate") or 0

        if Settings.ParticleRateScale < 1 then
            setProp(obj, "Rate", math.max(0, originalRate * Settings.ParticleRateScale))
        else
            restoreProp(obj, "Rate")
        end
    end

    if obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
        if Settings.DisableParticles then
            setProp(obj, "Enabled", false)
        else
            restoreProp(obj, "Enabled")
        end
    end

    if obj:IsA("Trail") or obj:IsA("Beam") then
        if Settings.DisableTrailsBeams then
            setProp(obj, "Enabled", false)
        else
            restoreProp(obj, "Enabled")
        end
    end

    if obj:IsA("Decal") or obj:IsA("Texture") then
        if Settings.DisableDecalsTextures then
            setProp(obj, "Transparency", 1)
        else
            restoreProp(obj, "Transparency")
        end
    end

    if obj:IsA("BasePart") then
        if Settings.SmoothMaterials then
            setProp(obj, "Material", Enum.Material.SmoothPlastic)
            setProp(obj, "Reflectance", 0)
        else
            restoreProp(obj, "Material")
            restoreProp(obj, "Reflectance")
        end

        if Settings.DisablePartShadows then
            setProp(obj, "CastShadow", false)
        else
            restoreProp(obj, "CastShadow")
        end
    end

    if obj:IsA("Highlight") then
        if Settings.DisableParticles then
            setProp(obj, "Enabled", false)
        else
            restoreProp(obj, "Enabled")
        end
    end

    if obj:IsA("Clouds") then
        if Settings.DisableClouds then
            setProp(obj, "Enabled", false)
            setProp(obj, "Cover", 0)
            setProp(obj, "Density", 0)
        else
            restoreProps(obj, { "Enabled", "Cover", "Density" })
        end
    end
end

local function processWorldScan()
    if not State.ScanActive then return end

    for _ = 1, Settings.ScanBatchSize do
        local parent = table.remove(State.ScanStack)

        if not parent then
            State.ScanActive = false
            return
        end

        if parent == Workspace or parent.Parent then
            for _, child in ipairs(parent:GetChildren()) do
                queueObject(child)
                table.insert(State.ScanStack, child)
            end
        end
    end
end

local function processWorldQueue()
    local processed = 0

    while processed < Settings.WorldBatchSize do
        local obj = State.Queue[State.QueueIndex]

        if not obj then
            clearQueue()
            return
        end

        State.Queue[State.QueueIndex] = nil
        State.QueueIndex += 1
        State.Queued[obj] = nil

        applyWorldObject(obj)
        processed += 1
    end
end

local function queueCount()
    return math.max(0, #State.Queue - State.QueueIndex + 1)
end

local function softApply(scanWorld)
    if not Settings.MasterEnabled then return end

    applyLighting()
    applyEffects()
    applyTerrain()
    applyCamera()
    applyPlayer()

    if scanWorld then
        startWorldScan()
    end
end

--// Presets
local function applyGraphicsPreset(name)
    if name == "Max FPS" then
        Settings.ClearFog = true
        Settings.CustomAtmosphere = false
        Settings.CinematicEffects = false
        Settings.DisableAllPostEffects = true
        Settings.DisableParticles = true
        Settings.ParticleRateScale = 0
        Settings.DisableTrailsBeams = true
        Settings.DisableDecalsTextures = true
        Settings.SmoothMaterials = true
        Settings.DisablePartShadows = true
        Settings.LowWater = true
        Settings.DisableClouds = true
        Settings.GlobalShadows = false
        Settings.Technology = "Voxel"
        Settings.Brightness = 3
        Settings.Exposure = 0
        Settings.ClockTime = 14
        Settings.FOV = 82
        Settings.EnvironmentDiffuseScale = 0
        Settings.EnvironmentSpecularScale = 0
    elseif name == "Balanced" then
        Settings.ClearFog = true
        Settings.CustomAtmosphere = false
        Settings.CinematicEffects = false
        Settings.DisableAllPostEffects = false
        Settings.DisableParticles = false
        Settings.ParticleRateScale = 0.55
        Settings.DisableTrailsBeams = false
        Settings.DisableDecalsTextures = false
        Settings.SmoothMaterials = false
        Settings.DisablePartShadows = false
        Settings.LowWater = false
        Settings.DisableClouds = false
        Settings.GlobalShadows = true
        Settings.Technology = "Voxel"
        Settings.Brightness = 3
        Settings.Exposure = 0
        Settings.ClockTime = 14
        Settings.FOV = 70
        Settings.EnvironmentDiffuseScale = 0.45
        Settings.EnvironmentSpecularScale = 0.35
    elseif name == "Clear Vision" then
        Settings.ClearFog = true
        Settings.CustomAtmosphere = false
        Settings.CinematicEffects = false
        Settings.DisableAllPostEffects = false
        Settings.GlobalShadows = true
        Settings.Technology = "Voxel"
        Settings.Brightness = 4
        Settings.Exposure = 0.05
        Settings.ClockTime = 13
        Settings.FOV = 75
        Settings.Ambient = Color3.fromRGB(195, 195, 195)
        Settings.OutdoorAmbient = Color3.fromRGB(195, 195, 195)
    elseif name == "Realism" then
        Settings.ClearFog = false
        Settings.FogStart = 45
        Settings.FogEnd = 900
        Settings.CustomAtmosphere = true
        Settings.AtmosphereDensity = 0.28
        Settings.AtmosphereOffset = 0.05
        Settings.AtmosphereGlare = 0.18
        Settings.AtmosphereHaze = 0.8
        Settings.AtmosphereColor = Color3.fromRGB(220, 220, 215)
        Settings.AtmosphereDecay = Color3.fromRGB(120, 120, 125)
        Settings.CinematicEffects = true
        Settings.DisableAllPostEffects = false
        Settings.GlobalShadows = true
        Settings.Technology = "Future"
        Settings.Brightness = 2.5
        Settings.Exposure = -0.05
        Settings.ClockTime = 15.5
        Settings.FOV = 70
        Settings.EnvironmentDiffuseScale = 0.8
        Settings.EnvironmentSpecularScale = 0.9
    elseif name == "Insane Realism" then
        Settings.ClearFog = false
        Settings.FogStart = 25
        Settings.FogEnd = 650
        Settings.CustomAtmosphere = true
        Settings.AtmosphereDensity = 0.38
        Settings.AtmosphereOffset = 0.12
        Settings.AtmosphereGlare = 0.32
        Settings.AtmosphereHaze = 1.55
        Settings.AtmosphereColor = Color3.fromRGB(225, 222, 212)
        Settings.AtmosphereDecay = Color3.fromRGB(105, 105, 115)
        Settings.CinematicEffects = true
        Settings.DisableAllPostEffects = false
        Settings.BloomIntensity = 0.45
        Settings.BloomSize = 55
        Settings.BloomThreshold = 0.95
        Settings.SunRaysIntensity = 0.075
        Settings.SunRaysSpread = 0.92
        Settings.ColorCorrectionContrast = 0.16
        Settings.ColorCorrectionSaturation = 0.14
        Settings.DepthOfField = true
        Settings.DOFFocusDistance = 80
        Settings.DOFInFocusRadius = 35
        Settings.DOFFarIntensity = 0.32
        Settings.GlobalShadows = true
        Settings.ShadowSoftness = 0.45
        Settings.Technology = "Future"
        Settings.Brightness = 2
        Settings.Exposure = -0.12
        Settings.ClockTime = 17.2
        Settings.FOV = 68
        Settings.EnvironmentDiffuseScale = 1
        Settings.EnvironmentSpecularScale = 1
    end

    softApply(true)
    notify("Graphics Preset", "Applied " .. name .. " smoothly.", 2)
end

local function applyAmbiencePreset(name)
    Settings.CinematicEffects = true
    Settings.DisableAllPostEffects = false
    Settings.CustomAtmosphere = true

    if name == "HvH Purple Night" then
        Settings.ClearFog = false
        Settings.FogStart = 0
        Settings.FogEnd = 850
        Settings.FogColor = Color3.fromRGB(75, 35, 110)
        Settings.ClockTime = 0
        Settings.Brightness = 2.4
        Settings.Exposure = -0.1
        Settings.Ambient = Color3.fromRGB(95, 55, 145)
        Settings.OutdoorAmbient = Color3.fromRGB(80, 35, 135)
        Settings.ColorCorrectionTint = Color3.fromRGB(205, 165, 255)
        Settings.ColorCorrectionContrast = 0.18
        Settings.ColorCorrectionSaturation = 0.25
        Settings.AtmosphereDensity = 0.22
        Settings.AtmosphereHaze = 1.2
        Settings.AtmosphereColor = Color3.fromRGB(145, 95, 210)
        Settings.AtmosphereDecay = Color3.fromRGB(65, 35, 100)
    elseif name == "HvH Cyan Flat" then
        Settings.ClearFog = true
        Settings.ClockTime = 14
        Settings.Brightness = 4.5
        Settings.Exposure = 0.1
        Settings.Ambient = Color3.fromRGB(120, 220, 255)
        Settings.OutdoorAmbient = Color3.fromRGB(95, 210, 255)
        Settings.ColorCorrectionTint = Color3.fromRGB(195, 245, 255)
        Settings.ColorCorrectionContrast = 0.1
        Settings.ColorCorrectionSaturation = 0.18
        Settings.AtmosphereDensity = 0
        Settings.AtmosphereHaze = 0
    elseif name == "Toxic Green" then
        Settings.ClearFog = false
        Settings.FogStart = 0
        Settings.FogEnd = 700
        Settings.FogColor = Color3.fromRGB(35, 90, 35)
        Settings.ClockTime = 3
        Settings.Brightness = 2.8
        Settings.Exposure = -0.05
        Settings.Ambient = Color3.fromRGB(80, 170, 80)
        Settings.OutdoorAmbient = Color3.fromRGB(45, 125, 45)
        Settings.ColorCorrectionTint = Color3.fromRGB(175, 255, 175)
        Settings.ColorCorrectionContrast = 0.18
        Settings.ColorCorrectionSaturation = 0.35
        Settings.AtmosphereDensity = 0.28
        Settings.AtmosphereHaze = 1.4
        Settings.AtmosphereColor = Color3.fromRGB(115, 210, 115)
        Settings.AtmosphereDecay = Color3.fromRGB(45, 80, 45)
    elseif name == "Blood Red" then
        Settings.ClearFog = false
        Settings.FogStart = 0
        Settings.FogEnd = 650
        Settings.FogColor = Color3.fromRGB(95, 20, 20)
        Settings.ClockTime = 0
        Settings.Brightness = 2.2
        Settings.Exposure = -0.2
        Settings.Ambient = Color3.fromRGB(150, 45, 45)
        Settings.OutdoorAmbient = Color3.fromRGB(105, 25, 25)
        Settings.ColorCorrectionTint = Color3.fromRGB(255, 175, 175)
        Settings.ColorCorrectionContrast = 0.22
        Settings.ColorCorrectionSaturation = 0.25
        Settings.AtmosphereDensity = 0.32
        Settings.AtmosphereHaze = 1.5
        Settings.AtmosphereColor = Color3.fromRGB(190, 70, 70)
        Settings.AtmosphereDecay = Color3.fromRGB(90, 25, 25)
    elseif name == "Golden Hour" then
        Settings.ClearFog = false
        Settings.FogStart = 40
        Settings.FogEnd = 750
        Settings.FogColor = Color3.fromRGB(255, 205, 145)
        Settings.ClockTime = 17.8
        Settings.Brightness = 2.4
        Settings.Exposure = -0.08
        Settings.Ambient = Color3.fromRGB(215, 165, 105)
        Settings.OutdoorAmbient = Color3.fromRGB(225, 175, 115)
        Settings.ColorCorrectionTint = Color3.fromRGB(255, 232, 195)
        Settings.ColorCorrectionContrast = 0.12
        Settings.ColorCorrectionSaturation = 0.18
        Settings.AtmosphereDensity = 0.3
        Settings.AtmosphereHaze = 1.1
        Settings.AtmosphereGlare = 0.35
        Settings.AtmosphereColor = Color3.fromRGB(255, 220, 170)
        Settings.AtmosphereDecay = Color3.fromRGB(180, 105, 70)
    elseif name == "Clean Fullbright" then
        Settings.ClearFog = true
        Settings.CustomAtmosphere = false
        Settings.CinematicEffects = false
        Settings.ClockTime = 14
        Settings.Brightness = 5
        Settings.Exposure = 0
        Settings.Ambient = Color3.fromRGB(255, 255, 255)
        Settings.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Settings.GlobalShadows = false
        Settings.AtmosphereDensity = 0
        Settings.AtmosphereHaze = 0
    end

    softApply(false)
    notify("Ambience", "Applied " .. name .. ".", 2)
end

--// Animation system
local AnimationPaths = {
    run = { "run", "RunAnim" },
    walk = { "walk", "WalkAnim" },
    jump = { "jump", "JumpAnim" },
    idle1 = { "idle", "Animation1" },
    idle2 = { "idle", "Animation2" },
    fall = { "fall", "FallAnim" },
    climb = { "climb", "ClimbAnim" },
    swim = { "swim", "Swim" },
    swimidle = { "swimidle", "SwimIdle" },
}

local AnimationPacks = {
    ["No Boundaries"] = { run = "18747070484", walk = "18747074203", jump = "18747069148", idle1 = "18747067405", idle2 = "18747063918", fall = "18747062535", climb = "18747060903", swim = "18747073181", swimidle = "18747071682" },
    ["Adidas"] = { run = "18537384940", walk = "18537392113", jump = "18537380791", idle1 = "18537376492", idle2 = "18537371272", fall = "18537367238", climb = "18537363391", swim = "18537389531", swimidle = "18537387180" },
    ["Bold"] = { run = "16738337225", walk = "16738340646", jump = "16738336650", idle1 = "16738333868", idle2 = "16738334710", fall = "16738333171", climb = "16738332169", swim = "16738339158", swimidle = "16738339817" },
    ["NFL"] = { run = "117333533048078", walk = "110358958299415", jump = "119846112151352", idle1 = "92080889861410", idle2 = "74451233229259", fall = "129773241321032", climb = "134630013742019", swim = "132697394189921", swimidle = "79090109939093" },
    ["None"] = { run = "0", walk = "0", jump = "0", idle1 = "0", idle2 = "0", fall = "0", climb = "0", swim = "0", swimidle = "0" },
    ["Default"] = { run = "913376220", walk = "913402848", jump = "507765000", idle1 = "507766388", idle2 = "507766666", fall = "507767968", climb = "507765644", swim = "913384386", swimidle = "913389285" },
    ["Rthro"] = { run = "2510198475", walk = "2510202577", jump = "2510197830", idle1 = "2510197257", idle2 = "2510196951", fall = "2510195892", climb = "2510192778", swim = "2510199791", swimidle = "2510201162" },
    ["Realistic"] = { run = "11600211410", walk = "11600249883", jump = "11600210487", idle1 = "17172918855", idle2 = "17173014241", fall = "11600206437", climb = "11600205519", swim = "11600212676", swimidle = "11600213505" },
    ["Astronaut"] = { run = "891636393", walk = "910025107", jump = "891627522", idle1 = "891621366", idle2 = "891633237", fall = "891617961", climb = "891609353", swim = "891639666", swimidle = "891663592" },
    ["Bubbly"] = { run = "910025107", walk = "910034870", jump = "910016857", idle1 = "910004836", idle2 = "910009958", fall = "910001910", climb = "909997997", swim = "910028158", swimidle = "910030921" },
    ["Cartoony"] = { run = "742638842", walk = "742640026", jump = "742637942", idle1 = "742637544", idle2 = "742638445", fall = "742637151", climb = "742636889", swim = "742639220", swimidle = "742639812" },
    ["Elder"] = { run = "845386501", walk = "845403856", jump = "845398858", idle1 = "845397899", idle2 = "845400520", fall = "845396048", climb = "845392038", swim = "845401742", swimidle = "845403127" },
    ["Knight"] = { run = "657564596", walk = "657552124", jump = "658409194", idle1 = "657595757", idle2 = "657568135", fall = "657600338", climb = "658360781", swim = "657560551", swimidle = "657557095" },
    ["Levitation"] = { run = "616010382", walk = "616013216", jump = "616008936", idle1 = "616006778", idle2 = "616008087", fall = "616005863", climb = "616003713", swim = "616011509", swimidle = "616012453" },
    ["Ghost"] = { run = "616013216", walk = "616013216", jump = "616008936", idle1 = "616006778", idle2 = "616008087", fall = "616005863", climb = "616003713", swim = "616011509", swimidle = "616012453" },
    ["Mage"] = { run = "707861613", walk = "707897309", jump = "707853694", idle1 = "707742142", idle2 = "707855907", fall = "707829716", climb = "707826056", swim = "707876443", swimidle = "707894699" },
    ["Ninja"] = { run = "656118852", walk = "656121766", jump = "656117878", idle1 = "656117400", idle2 = "656118341", fall = "656115606", climb = "656114359", swim = "656119721", swimidle = "656121397" },
    ["Pirate"] = { run = "750783738", walk = "750785693", jump = "750782230", idle1 = "750781874", idle2 = "750782770", fall = "750780242", climb = "750779899", swim = "750784579", swimidle = "750785176" },
    ["Robot"] = { run = "616091570", walk = "616095330", jump = "616090535", idle1 = "616088211", idle2 = "616089559", fall = "616087089", climb = "616086039", swim = "616092998", swimidle = "616094091" },
    ["Stylish"] = { run = "616140816", walk = "616146177", jump = "616139451", idle1 = "616136790", idle2 = "616138447", fall = "616134815", climb = "616133594", swim = "616143378", swimidle = "616144772" },
    ["Superhero"] = { run = "616117076", walk = "616122287", jump = "616115533", idle1 = "616111295", idle2 = "616113536", fall = "616108001", climb = "616104706", swim = "616119360", swimidle = "616120861" },
    ["Toy"] = { run = "782842708", walk = "782843345", jump = "782847020", idle1 = "782841498", idle2 = "782845736", fall = "782846423", climb = "782843869", swim = "782844582", swimidle = "782845186" },
    ["Vampire"] = { run = "1083462077", walk = "1083473930", jump = "1083455352", idle1 = "1083445855", idle2 = "1083450166", fall = "1083443587", climb = "1083439238", swim = "1083464683", swimidle = "1083467779" },
    ["Werewolf"] = { run = "1083216690", walk = "1083178339", jump = "1083218792", idle1 = "1083195517", idle2 = "1083214717", fall = "1083189019", climb = "1083182000", swim = "1083222527", swimidle = "1083225406" },
    ["Zombie"] = { run = "616163682", walk = "616168032", jump = "616161997", idle1 = "616158929", idle2 = "616160636", fall = "616157476", climb = "616156119", swim = "616165109", swimidle = "616166655" },
    ["Old School"] = { run = "10921240218", walk = "10921244891", jump = "10921242013", idle1 = "10921230744", idle2 = "10921232093", fall = "10921241244", climb = "10921229866", swim = "10921243048", swimidle = "10921244018" },
    ["Confident"] = { run = "1070001516", walk = "1070017263", jump = "1069984524", idle1 = "1069977950", idle2 = "1069987858", fall = "1069973677", climb = "1069946257", swim = "1070009914", swimidle = "1070012133" },
    ["Popstar"] = { run = "1212980348", walk = "1212980338", jump = "1212954642", idle1 = "1212900985", idle2 = "1212900985", fall = "1212900995", climb = "1213044939", swim = "1212852603", swimidle = "1212998578" },
    ["Patrol"] = { run = "1150967949", walk = "1151231493", jump = "1150944216", idle1 = "1149612882", idle2 = "1150842221", fall = "1148863382", climb = "1148811837", swim = "1151204998", swimidle = "1151221899" },
    ["Princess"] = { run = "941015281", walk = "941028902", jump = "941008832", idle1 = "941003647", idle2 = "941013098", fall = "941000007", climb = "940996062", swim = "941018893", swimidle = "941025398" },
    ["Sneaky"] = { run = "1132494274", walk = "1132510133", jump = "1132489853", idle1 = "1132473842", idle2 = "1132477671", fall = "1132469004", climb = "1132461372", swim = "1132500520", swimidle = "1132506407" },
    ["Cowboy"] = { run = "1014401683", walk = "1014421541", jump = "1014394726", idle1 = "1014390418", idle2 = "1014398616", fall = "1014384571", climb = "1014380606", swim = "1014406523", swimidle = "1014411816" },
    ["Stylish Female"] = { run = "4708192705", walk = "4708193840", jump = "4708188025", idle1 = "4708191566", idle2 = "4708192150", fall = "4708186162", climb = "4708184253", swim = "4708189360", swimidle = "4708190607" },
    ["Drooling Zombie"] = { run = "3489173414", walk = "3489174223", jump = "616161997", idle1 = "3489171152", idle2 = "3489171152", fall = "616157476", climb = "616156119", swim = "616165109", swimidle = "616166655" },
    ["R15"] = { run = "4211220381", walk = "4211223236", jump = "4211219390", idle1 = "4211217646", idle2 = "4211218409", fall = "4211216152", climb = "4211214992", swim = "4211221314", swimidle = "4374694239" },
    ["Old R15"] = { run = "507767714", walk = "540798782", jump = "507765000", idle1 = "434416649", idle2 = "434417169", fall = "507767968", climb = "507765644", swim = "507784897", swimidle = "481825862" },
    ["R6"] = { run = "12518152696", walk = "12518152696", jump = "12520880485", idle1 = "12521158637", idle2 = "12521162526", fall = "12520972571", climb = "12520982150", swim = "12518152696", swimidle = "12518152696" },
    ["Mr. Toilet"] = { run = "4417979645", walk = "10921269718", jump = "10921263860", idle1 = "4417977954", idle2 = "4417978624", fall = "10921262864", climb = "10921257536", swim = "10921264784", swimidle = "10921265698" },
    ["Ud'zal"] = { run = "3236836670", walk = "3303162967", jump = "10921263860", idle1 = "3303162274", idle2 = "3303162549", fall = "10921262864", climb = "10921257536", swim = "10921264784", swimidle = "10921265698" },
    ["Borock"] = { run = "3236836670", walk = "3303162967", jump = "10921263860", idle1 = "3293641938", idle2 = "3293642554", fall = "10921262864", climb = "10921257536", swim = "10921264784", swimidle = "10921265698" },
    ["Oinan Thickhoof"] = { run = "3236836670", walk = "3303162967", jump = "10921263860", idle1 = "10921117521", idle2 = "10921118894", fall = "10921262864", climb = "10921257536", swim = "10921264784", swimidle = "10921265698" },
}

local AnimationOptions = {}

for name in pairs(AnimationPacks) do
    table.insert(AnimationOptions, name)
end

table.sort(AnimationOptions)

local SlotOptions = {
    "run",
    "walk",
    "jump",
    "idle1",
    "idle2",
    "fall",
    "climb",
    "swim",
    "swimidle",
}

local CurrentCustomSlot = "run"

local function getAnimate()
    local character = getCharacter()
    if not character then return nil end
    return character:FindFirstChild("Animate")
end

local function getAnimationObject(animate, slot)
    local path = AnimationPaths[slot]
    if not animate or not path then return nil end

    local folder = animate:FindFirstChild(path[1])
    if not folder then return nil end

    return folder:FindFirstChild(path[2])
end

local function cacheOriginalAnimations()
    if State.OriginalAnimations then return end

    local animate = getAnimate()
    if not animate then return end

    State.OriginalAnimations = {}

    for slot in pairs(AnimationPaths) do
        local obj = getAnimationObject(animate, slot)
        if obj then
            State.OriginalAnimations[slot] = obj.AnimationId
        end
    end
end

local function stopAnimationTracks()
    local hum = getHumanoid()
    local animate = getAnimate()

    if animate then
        pcall(function()
            animate.Disabled = true
        end)
    end

    if hum then
        pcall(function()
            for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                track:Stop(0)
            end
        end)
    end
end

local function setAnimationPack(packName, pack)
    pack = pack or AnimationPacks[packName]

    if not pack then
        notify("Animation", "Pack not found: " .. tostring(packName), 2)
        return
    end

    cacheOriginalAnimations()

    local animate = getAnimate()
    if not animate then
        notify("Animation", "Animate script not found on character.", 2)
        return
    end

    if Settings.StopTracksOnPackChange then
        stopAnimationTracks()
    else
        pcall(function()
            animate.Disabled = true
        end)
    end

    for slot, id in pairs(pack) do
        local obj = getAnimationObject(animate, slot)
        if obj then
            obj.AnimationId = "rbxassetid://" .. tostring(id)
        end
    end

    task.defer(function()
        if animate and animate.Parent then
            animate.Disabled = false
        end
    end)

    State.CurrentAnimationPack = packName
    notify("Animation", "Changed to " .. packName .. ".", 2)
end

local function restoreOriginalAnimations()
    if not State.OriginalAnimations then
        notify("Animation", "No original animation cache found.", 2)
        return
    end

    local animate = getAnimate()
    if not animate then return end

    stopAnimationTracks()

    for slot, id in pairs(State.OriginalAnimations) do
        local obj = getAnimationObject(animate, slot)
        if obj then
            obj.AnimationId = id
        end
    end

    task.defer(function()
        if animate and animate.Parent then
            animate.Disabled = false
        end
    end)

    notify("Animation", "Restored original animation IDs.", 2)
end

local function playPreviewAnimation()
    local id = tostring(Settings.PreviewAnimationId or ""):gsub("rbxassetid://", ""):gsub("%D", "")
    if id == "" then
        notify("Preview", "Enter an animation asset ID first.", 2)
        return
    end

    local hum = getHumanoid()
    if not hum then return end

    if State.PreviewTrack then
        pcall(function()
            State.PreviewTrack:Stop(0)
        end)
        State.PreviewTrack = nil
    end

    stopAnimationTracks()

    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. id

    local ok, track = pcall(function()
        return hum:LoadAnimation(anim)
    end)

    if ok and track then
        State.PreviewTrack = track
        track:Play()
        track.TimePosition = Settings.PreviewAnimationTime
        track:AdjustSpeed(Settings.PreviewAnimationSpeed)

        track.Stopped:Connect(function()
            local animate = getAnimate()
            if animate then
                animate.Disabled = false
            end
        end)

        notify("Preview", "Playing animation " .. id .. ".", 2)
    else
        notify("Preview", "Could not load animation.", 2)
    end
end

local function stopPreviewAnimation()
    if State.PreviewTrack then
        pcall(function()
            State.PreviewTrack:Stop(0)
        end)
        State.PreviewTrack = nil
    end

    local animate = getAnimate()
    if animate then
        animate.Disabled = false
    end
end

--// UI tabs
local MainTab = Window:InitTab({ Title = "Main" })
local GraphicsTab = Window:InitTab({ Title = "Graphics" })
local AmbienceTab = Window:InitTab({ Title = "Ambience" })
local EffectsTab = Window:InitTab({ Title = "Effects" })
local FPSTab = Window:InitTab({ Title = "FPS Boost" })
local PlayerTab = Window:InitTab({ Title = "Player" })
local AnimTab = Window:InitTab({ Title = "Animations" })
local UtilityTab = Window:InitTab({ Title = "Utility" })

--// Main
MainTab:Section("Presets")

MainTab:Dropdown({
    Title = "Graphics Preset",
    Options = { "Max FPS", "Balanced", "Clear Vision", "Realism", "Insane Realism" },
    PlaceHolder = "Select preset...",
    CallBack = function(value)
        applyGraphicsPreset(tostring(value))
    end
})

MainTab:Dropdown({
    Title = "Ambience Preset",
    Options = { "Clean Fullbright", "HvH Purple Night", "HvH Cyan Flat", "Toxic Green", "Blood Red", "Golden Hour" },
    PlaceHolder = "Select ambience...",
    CallBack = function(value)
        applyAmbiencePreset(tostring(value))
    end
})

MainTab:Toggle({
    Title = "Master Enabled",
    Description = "Turns the whole hub on/off.",
    Value = Settings.MasterEnabled,
    CallBack = function(value)
        Settings.MasterEnabled = value

        if value then
            softApply(true)
        else
            restoreAll()
        end
    end
})

MainTab:Toggle({
    Title = "Heartbeat Fog Lock",
    Description = "Re-applies fog/atmosphere every Heartbeat to prevent flicker.",
    Value = Settings.HeartbeatFogLock,
    CallBack = function(value)
        Settings.HeartbeatFogLock = value
    end
})

MainTab:Toggle({
    Title = "Auto Enforce",
    Description = "Smoothly re-applies lighting, camera, effects, player values.",
    Value = Settings.AutoEnforce,
    CallBack = function(value)
        Settings.AutoEnforce = value
    end
})

MainTab:Keybind({
    Title = "Quick Apply",
    Key = Enum.KeyCode.F6,
    CallBack = function()
        softApply(true)
        notify("Quick Apply", "Started smooth apply.", 2)
    end
})

--// Graphics
GraphicsTab:Section("Lighting")

GraphicsTab:Toggle({
    Title = "Clear Fog",
    Description = "Removes classic fog and clears atmosphere unless Custom Atmosphere is on.",
    Value = Settings.ClearFog,
    CallBack = function(value)
        Settings.ClearFog = value
        applyLighting()
    end
})

GraphicsTab:Toggle({
    Title = "Global Shadows",
    Description = "Disable for FPS, enable for realism.",
    Value = Settings.GlobalShadows,
    CallBack = function(value)
        Settings.GlobalShadows = value
        applyLighting()
    end
})

GraphicsTab:Dropdown({
    Title = "Lighting Technology",
    Options = { "Voxel", "ShadowMap", "Future", "Compatibility" },
    PlaceHolder = Settings.Technology,
    CallBack = function(value)
        Settings.Technology = tostring(value)
        applyLighting()
    end
})

GraphicsTab:Slider({
    Title = "Lighting Sliders",
    Description = "Core Roblox Lighting values.",
    Sliders = {
        {
            Title = "Brightness",
            Range = { 0, 10 },
            Increment = 0.1,
            StarterValue = Settings.Brightness,
            CallBack = function(value)
                Settings.Brightness = value
                applyLighting()
            end
        },
        {
            Title = "Exposure",
            Range = { -3, 3 },
            Increment = 0.05,
            StarterValue = Settings.Exposure,
            CallBack = function(value)
                Settings.Exposure = value
                applyLighting()
            end
        },
        {
            Title = "Clock Time",
            Range = { 0, 24 },
            Increment = 0.1,
            StarterValue = Settings.ClockTime,
            CallBack = function(value)
                Settings.ClockTime = value
                applyLighting()
            end
        },
        {
            Title = "Shadow Softness",
            Range = { 0, 1 },
            Increment = 0.01,
            StarterValue = Settings.ShadowSoftness,
            CallBack = function(value)
                Settings.ShadowSoftness = value
                applyLighting()
            end
        },
        {
            Title = "Fog Start",
            Range = { 0, 5000 },
            Increment = 10,
            StarterValue = Settings.FogStart,
            CallBack = function(value)
                Settings.FogStart = value
                applyLighting()
            end
        },
        {
            Title = "Fog End",
            Range = { 0, 1000000 },
            Increment = 1000,
            StarterValue = Settings.FogEnd,
            CallBack = function(value)
                Settings.FogEnd = value
                applyLighting()
            end
        },
    }
})

GraphicsTab:ColorPicker({
    Title = "Ambient",
    Color = Settings.Ambient,
    Linkable = true,
    CallBack = function(color)
        Settings.Ambient = color
        applyLighting()
    end
})

GraphicsTab:ColorPicker({
    Title = "Outdoor Ambient",
    Color = Settings.OutdoorAmbient,
    Linkable = true,
    CallBack = function(color)
        Settings.OutdoorAmbient = color
        applyLighting()
    end
})

GraphicsTab:ColorPicker({
    Title = "Fog Color",
    Color = Settings.FogColor,
    Linkable = true,
    CallBack = function(color)
        Settings.FogColor = color
        applyLighting()
    end
})

--// Ambience
AmbienceTab:Section("HvH-Style Ambience")

AmbienceTab:Paragraph({
    Title = "Ambience System",
    Content = "This controls flat brightness, colored ambient light, fog tint, color correction, and atmosphere tint. Use Clean Fullbright for visibility or colored modes for stylized visuals."
})

AmbienceTab:ColorPicker({
    Title = "Color Correction Tint",
    Color = Settings.ColorCorrectionTint,
    Linkable = true,
    CallBack = function(color)
        Settings.ColorCorrectionTint = color
        Settings.CinematicEffects = true
        applyEffects()
    end
})

AmbienceTab:ColorPicker({
    Title = "Atmosphere Color",
    Color = Settings.AtmosphereColor,
    Linkable = true,
    CallBack = function(color)
        Settings.AtmosphereColor = color
        Settings.CustomAtmosphere = true
        applyLighting()
    end
})

AmbienceTab:ColorPicker({
    Title = "Atmosphere Decay",
    Color = Settings.AtmosphereDecay,
    Linkable = true,
    CallBack = function(color)
        Settings.AtmosphereDecay = color
        Settings.CustomAtmosphere = true
        applyLighting()
    end
})

AmbienceTab:Slider({
    Title = "Atmosphere",
    Description = "Fog/haze/air controls.",
    Sliders = {
        {
            Title = "Density",
            Range = { 0, 1 },
            Increment = 0.01,
            StarterValue = Settings.AtmosphereDensity,
            CallBack = function(value)
                Settings.AtmosphereDensity = value
                Settings.CustomAtmosphere = true
                applyLighting()
            end
        },
        {
            Title = "Haze",
            Range = { 0, 10 },
            Increment = 0.05,
            StarterValue = Settings.AtmosphereHaze,
            CallBack = function(value)
                Settings.AtmosphereHaze = value
                Settings.CustomAtmosphere = true
                applyLighting()
            end
        },
        {
            Title = "Glare",
            Range = { 0, 10 },
            Increment = 0.05,
            StarterValue = Settings.AtmosphereGlare,
            CallBack = function(value)
                Settings.AtmosphereGlare = value
                Settings.CustomAtmosphere = true
                applyLighting()
            end
        },
        {
            Title = "Offset",
            Range = { -1, 1 },
            Increment = 0.01,
            StarterValue = Settings.AtmosphereOffset,
            CallBack = function(value)
                Settings.AtmosphereOffset = value
                Settings.CustomAtmosphere = true
                applyLighting()
            end
        },
    }
})

--// Effects
EffectsTab:Section("Post Processing")

EffectsTab:Toggle({
    Title = "Cinematic Effects",
    Description = "Enables custom Bloom, SunRays, ColorCorrection, DOF, and Blur.",
    Value = Settings.CinematicEffects,
    CallBack = function(value)
        Settings.CinematicEffects = value
        applyEffects()
    end
})

EffectsTab:Toggle({
    Title = "Disable All Post Effects",
    Description = "Disables all Bloom/Blur/DOF/SunRays/ColorCorrection effects for FPS.",
    Value = Settings.DisableAllPostEffects,
    CallBack = function(value)
        Settings.DisableAllPostEffects = value
        applyEffects()
    end
})

EffectsTab:Toggle({
    Title = "Depth Of Field",
    Description = "Cinematic distance blur.",
    Value = Settings.DepthOfField,
    CallBack = function(value)
        Settings.DepthOfField = value
        Settings.CinematicEffects = true
        applyEffects()
    end
})

EffectsTab:Toggle({
    Title = "Blur",
    Description = "Screen blur.",
    Value = Settings.Blur,
    CallBack = function(value)
        Settings.Blur = value
        Settings.CinematicEffects = true
        applyEffects()
    end
})

EffectsTab:Slider({
    Title = "Effects Sliders",
    Description = "Bloom, sun rays, color correction, DOF, and blur.",
    Sliders = {
        {
            Title = "Bloom Intensity",
            Range = { 0, 5 },
            Increment = 0.01,
            StarterValue = Settings.BloomIntensity,
            CallBack = function(value)
                Settings.BloomIntensity = value
                Settings.CinematicEffects = true
                applyEffects()
            end
        },
        {
            Title = "Bloom Size",
            Range = { 0, 100 },
            Increment = 1,
            StarterValue = Settings.BloomSize,
            CallBack = function(value)
                Settings.BloomSize = value
                Settings.CinematicEffects = true
                applyEffects()
            end
        },
        {
            Title = "Sun Rays",
            Range = { 0, 1 },
            Increment = 0.005,
            StarterValue = Settings.SunRaysIntensity,
            CallBack = function(value)
                Settings.SunRaysIntensity = value
                Settings.CinematicEffects = true
                applyEffects()
            end
        },
        {
            Title = "Contrast",
            Range = { -1, 1 },
            Increment = 0.01,
            StarterValue = Settings.ColorCorrectionContrast,
            CallBack = function(value)
                Settings.ColorCorrectionContrast = value
                Settings.CinematicEffects = true
                applyEffects()
            end
        },
        {
            Title = "Saturation",
            Range = { -1, 1 },
            Increment = 0.01,
            StarterValue = Settings.ColorCorrectionSaturation,
            CallBack = function(value)
                Settings.ColorCorrectionSaturation = value
                Settings.CinematicEffects = true
                applyEffects()
            end
        },
        {
            Title = "DOF Far",
            Range = { 0, 1 },
            Increment = 0.01,
            StarterValue = Settings.DOFFarIntensity,
            CallBack = function(value)
                Settings.DOFFarIntensity = value
                Settings.CinematicEffects = true
                Settings.DepthOfField = true
                applyEffects()
            end
        },
        {
            Title = "Blur Size",
            Range = { 0, 56 },
            Increment = 1,
            StarterValue = Settings.BlurSize,
            CallBack = function(value)
                Settings.BlurSize = value
                Settings.CinematicEffects = true
                Settings.Blur = value > 0
                applyEffects()
            end
        },
    }
})

--// FPS
FPSTab:Section("Smooth FPS Boost")

FPSTab:Toggle({
    Title = "Disable Particles",
    Description = "Disables particle emitters, smoke, fire, sparkles, and highlights.",
    Value = Settings.DisableParticles,
    CallBack = function(value)
        Settings.DisableParticles = value
        startWorldScan()
    end
})

FPSTab:Toggle({
    Title = "Disable Trails / Beams",
    Description = "Turns off trails and beams.",
    Value = Settings.DisableTrailsBeams,
    CallBack = function(value)
        Settings.DisableTrailsBeams = value
        startWorldScan()
    end
})

FPSTab:Toggle({
    Title = "Hide Decals / Textures",
    Description = "Sets decals and textures transparent.",
    Value = Settings.DisableDecalsTextures,
    CallBack = function(value)
        Settings.DisableDecalsTextures = value
        startWorldScan()
    end
})

FPSTab:Toggle({
    Title = "Smooth Materials",
    Description = "Changes BaseParts to SmoothPlastic locally.",
    Value = Settings.SmoothMaterials,
    CallBack = function(value)
        Settings.SmoothMaterials = value
        startWorldScan()
    end
})

FPSTab:Toggle({
    Title = "Disable Part Shadows",
    Description = "Turns off CastShadow on BaseParts.",
    Value = Settings.DisablePartShadows,
    CallBack = function(value)
        Settings.DisablePartShadows = value
        startWorldScan()
    end
})

FPSTab:Toggle({
    Title = "Low Water / Terrain",
    Description = "Reduces terrain decoration and water cost.",
    Value = Settings.LowWater,
    CallBack = function(value)
        Settings.LowWater = value
        applyTerrain()
    end
})

FPSTab:Toggle({
    Title = "Disable Clouds",
    Description = "Disables Clouds objects.",
    Value = Settings.DisableClouds,
    CallBack = function(value)
        Settings.DisableClouds = value
        startWorldScan()
    end
})

FPSTab:Toggle({
    Title = "Auto Apply New Objects",
    Description = "Queues newly added objects automatically.",
    Value = Settings.AutoApplyNewObjects,
    CallBack = function(value)
        Settings.AutoApplyNewObjects = value
    end
})

FPSTab:Slider({
    Title = "Batch Performance",
    Description = "Lower values are smoother. Higher values apply faster.",
    Sliders = {
        {
            Title = "Particle Rate Scale",
            Range = { 0, 1 },
            Increment = 0.01,
            StarterValue = Settings.ParticleRateScale,
            CallBack = function(value)
                Settings.ParticleRateScale = value
                startWorldScan()
            end
        },
        {
            Title = "World Batch Size",
            Range = { 25, 1000 },
            Increment = 25,
            StarterValue = Settings.WorldBatchSize,
            CallBack = function(value)
                Settings.WorldBatchSize = value
            end
        },
        {
            Title = "Scan Batch Size",
            Range = { 5, 250 },
            Increment = 5,
            StarterValue = Settings.ScanBatchSize,
            CallBack = function(value)
                Settings.ScanBatchSize = value
            end
        },
        {
            Title = "Lighting Refresh Rate",
            Range = { 0.1, 2 },
            Increment = 0.05,
            StarterValue = Settings.LightingRefreshRate,
            CallBack = function(value)
                Settings.LightingRefreshRate = value
            end
        },
    }
})

FPSTab:Button({
    Title = "Smooth World Rescan",
    Description = "Queues the whole map gradually, avoiding one-frame freezing.",
    CallBack = function()
        startWorldScan()
        notify("World Scan", "Smooth rescan started.", 2)
    end
})

--// Player
PlayerTab:Section("Player Loops")

PlayerTab:Toggle({
    Title = "WalkSpeed Loop",
    Description = "Heartbeat loop that keeps WalkSpeed at your selected value.",
    Value = Settings.WalkSpeedLoop,
    CallBack = function(value)
        Settings.WalkSpeedLoop = value
        applyPlayer()
    end
})

PlayerTab:Toggle({
    Title = "JumpPower Loop",
    Description = "Heartbeat loop that keeps JumpPower at your selected value.",
    Value = Settings.JumpLoop,
    CallBack = function(value)
        Settings.JumpLoop = value
        applyPlayer()
    end
})

PlayerTab:Toggle({
    Title = "FOV Loop",
    Description = "Keeps camera FOV locked.",
    Value = Settings.FOVLoop,
    CallBack = function(value)
        Settings.FOVLoop = value
        applyCamera()
    end
})

PlayerTab:Slider({
    Title = "Player / Camera",
    Description = "WalkSpeed, JumpPower, and FOV.",
    Sliders = {
        {
            Title = "WalkSpeed",
            Range = { 0, 250 },
            Increment = 1,
            StarterValue = Settings.WalkSpeed,
            CallBack = function(value)
                Settings.WalkSpeed = value
                applyPlayer()
            end
        },
        {
            Title = "JumpPower",
            Range = { 0, 250 },
            Increment = 1,
            StarterValue = Settings.JumpPower,
            CallBack = function(value)
                Settings.JumpPower = value
                applyPlayer()
            end
        },
        {
            Title = "FOV",
            Range = { 40, 140 },
            Increment = 1,
            StarterValue = Settings.FOV,
            CallBack = function(value)
                Settings.FOV = value
                applyCamera()
            end
        },
    }
})

--// Animations
AnimTab:Section("Animation Pack Changer")

AnimTab:Dropdown({
    Title = "Animation Pack",
    Options = AnimationOptions,
    PlaceHolder = "Default",
    CallBack = function(value)
        setAnimationPack(tostring(value))
    end
})

AnimTab:Toggle({
    Title = "Auto Reapply On Respawn",
    Description = "Applies the selected animation pack after character respawn.",
    Value = Settings.AnimationAutoReapply,
    CallBack = function(value)
        Settings.AnimationAutoReapply = value
    end
})

AnimTab:Toggle({
    Title = "Stop Tracks On Change",
    Description = "Stops current tracks before changing animation IDs.",
    Value = Settings.StopTracksOnPackChange,
    CallBack = function(value)
        Settings.StopTracksOnPackChange = value
    end
})

AnimTab:Button({
    Title = "Restore Original Animations",
    Description = "Restores the animation IDs captured before the first pack change.",
    CallBack = function()
        restoreOriginalAnimations()
    end
})

AnimTab:Button({
    Title = "Stop Current Tracks",
    Description = "Stops currently playing animation tracks and re-enables Animate.",
    CallBack = function()
        stopAnimationTracks()
        task.defer(function()
            local animate = getAnimate()
            if animate then
                animate.Disabled = false
            end
        end)
        notify("Animation", "Stopped current tracks.", 2)
    end
})

AnimTab:Section("Custom Pack")

AnimTab:Dropdown({
    Title = "Custom Slot",
    Options = SlotOptions,
    PlaceHolder = "run",
    CallBack = function(value)
        CurrentCustomSlot = tostring(value)
    end
})

AnimTab:TextInput({
    Title = "Custom Slot Asset ID",
    PlaceHolder = "Paste numeric animation ID...",
    NumberOnly = true,
    ClearOnLost = false,
    CallBack = function(text)
        local id = tostring(text or ""):gsub("rbxassetid://", ""):gsub("%D", "")
        if id ~= "" then
            State.CustomAnimationPack[CurrentCustomSlot] = id
            notify("Custom Animation", CurrentCustomSlot .. " set to " .. id .. ".", 2)
        end
    end
})

AnimTab:Button({
    Title = "Apply Custom Pack",
    Description = "Applies your custom slot table.",
    CallBack = function()
        setAnimationPack("Custom", State.CustomAnimationPack)
    end
})

AnimTab:Section("Preview Single Animation")

AnimTab:TextInput({
    Title = "Preview Animation ID",
    PlaceHolder = "Paste numeric animation ID...",
    NumberOnly = true,
    ClearOnLost = false,
    CallBack = function(text)
        Settings.PreviewAnimationId = tostring(text or "")
    end
})

AnimTab:Slider({
    Title = "Preview Controls",
    Description = "Animation preview speed and starting time.",
    Sliders = {
        {
            Title = "Preview Speed",
            Range = { 0, 5 },
            Increment = 0.05,
            StarterValue = Settings.PreviewAnimationSpeed,
            CallBack = function(value)
                Settings.PreviewAnimationSpeed = value
                if State.PreviewTrack then
                    State.PreviewTrack:AdjustSpeed(value)
                end
            end
        },
        {
            Title = "Start Time",
            Range = { 0, 10 },
            Increment = 0.1,
            StarterValue = Settings.PreviewAnimationTime,
            CallBack = function(value)
                Settings.PreviewAnimationTime = value
            end
        },
    }
})

AnimTab:Button({
    Title = "Play Preview Animation",
    CallBack = function()
        playPreviewAnimation()
    end
})

AnimTab:Button({
    Title = "Stop Preview Animation",
    CallBack = function()
        stopPreviewAnimation()
    end
})

--// Utility
UtilityTab:Section("System")

local StatusText = nil

StatusText = UtilityTab:Paragraph({
    Title = "Status",
    Content = "Loading..."
})

UtilityTab:Button({
    Title = "Apply Everything Now",
    Description = "Applies lighting/effects/camera/player instantly and starts a smooth world scan.",
    CallBack = function()
        softApply(true)
        notify("Apply", "Full smooth apply started.", 2)
    end
})

UtilityTab:Button({
    Title = "Restore Visuals",
    Description = "Restores properties captured by this script.",
    CallBack = function()
        restoreAll()
        notify("Restore", "Visuals restored.", 2)
    end
})

UtilityTab:Button({
    Title = "Destroy Hub + Restore",
    Description = "Disconnects loops, restores visuals, and destroys created effects.",
    CallBack = function()
        if ENV.__SydeGraphicsPlus and ENV.__SydeGraphicsPlus.Cleanup then
            ENV.__SydeGraphicsPlus.Cleanup()
        end
    end
})

local function updateStatus()
    if not StatusText then return end

    local content =
        "FPS: " .. tostring(math.floor(State.FPS + 0.5))
        .. "\nWorld queue: " .. tostring(queueCount())
        .. "\nScanning world: " .. tostring(State.ScanActive)
        .. "\nCurrent animation: " .. tostring(State.CurrentAnimationPack)
        .. "\nWalkSpeed loop: " .. tostring(Settings.WalkSpeedLoop)
        .. "\nFOV: " .. tostring(Settings.FOV)
        .. "\nFog lock: " .. tostring(Settings.HeartbeatFogLock)

    pcall(function()
        StatusText:UpdateParagraph("Status", content)
    end)
end

--// Runtime loops
do
    local frames = 0
    local lastFps = os.clock()

    connect(RunService.Heartbeat, function()
        frames += 1

        local now = os.clock()

        if now - lastFps >= 1 then
            State.FPS = frames / (now - lastFps)
            frames = 0
            lastFps = now
        end

        if Settings.MasterEnabled then
            if Settings.HeartbeatFogLock then
                applyFogAtmosphere()
            end

            if Settings.AutoEnforce and now - State.LastLightingApply >= Settings.LightingRefreshRate then
                State.LastLightingApply = now
                applyLighting()
                applyEffects()
                applyTerrain()
                applyCamera()
                applyPlayer()
            end

            processWorldScan()
            processWorldQueue()
        end

        if now - State.LastStatus >= 0.5 then
            State.LastStatus = now
            updateStatus()
        end
    end)
end

connect(Workspace.DescendantAdded, function(obj)
    if not Settings.MasterEnabled or not Settings.AutoApplyNewObjects then return end

    task.defer(function()
        queueObject(obj)
    end)
end)

connect(Lighting.DescendantAdded, function(obj)
    if not Settings.MasterEnabled then return end

    task.defer(function()
        if obj:IsA("Atmosphere") then
            applyFogAtmosphere()
        elseif isPostEffect(obj) then
            applyEffects()
        end
    end)
end)

connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
    task.defer(applyCamera)
end)

connect(LocalPlayer.CharacterAdded, function()
    task.wait(1)

    if Settings.AnimationAutoReapply and State.CurrentAnimationPack and State.CurrentAnimationPack ~= "Default" then
        setAnimationPack(State.CurrentAnimationPack)
    end

    applyPlayer()
end)

--// Cleanup
function State.Cleanup()
    for _, c in ipairs(State.Connections) do
        pcall(function()
            c:Disconnect()
        end)
    end

    stopPreviewAnimation()
    restoreOriginalAnimations()
    restoreAll()

    ENV.__SydeGraphicsPlus = nil

    notify("Syde Graphics+", "Cleaned up.", 2)
end

--// Initial apply
softApply(true)

notify("Syde Graphics+", "Loaded. Use F6 for quick apply.", 4)
