-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Load Syde
local syde = loadstring(game:HttpGet("https://raw.githubusercontent.com/essencejs/syde/refs/heads/main/source", true))()

-- Config Customization Setup
syde:Load({
    Logo = "7488932274",
    Name = "Adaptive Aimbot",
    Status = "Stable",
    Accent = Color3.fromRGB(54, 57, 241),
    HitBox = Color3.fromRGB(54, 57, 241),
    AutoLoad = true,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AdaptiveAimbot",
        FileName = "config"
    }
})

local Config = {
    -- Master switches
    AimbotEnabled = false,
    SilentAimEnabled = false,
    
    -- Keybinds
    UiToggleKey = Enum.KeyCode.RightControl,
    AimbotToggleKey = Enum.KeyCode.Delete,
    SilentAimToggleKey = Enum.KeyCode.Insert,
    
    -- Humanization mode: "Custom" or "Copied"
    HumanizationMode = "Custom",
    
    -- Custom profile parameters
    Smoothing = 5,
    DynamicSmoothing = false,
    ReactionDelay = 0, -- In milliseconds
    AccelerationCurve = 1.0,
    AimShake = 0.0,
    Overshoot = 0.0,
    Undershoot = 0.0,
    FlickTrackingBias = 0.5,
    
    -- Advanced Targeting Mechanics
    AdaptiveSmoothing = false,
    BezierPathing = false,
    CursorJitter = false,
    JitterIntensity = 2,
    MouseEventEmulation = false,

    -- Autoshoot & Wallbang
    AutoShootEnabled = false,
    AutoShootDelay = 150,
    AutoWallbangEnabled = false,
    MaxWalls = 1,
    MaxWallThickness = 2,
    LegitMode = true,
    
    -- Triggerbot
    TriggerbotEnabled = false,
    TriggerbotKey = "MouseButton1",
    TriggerbotDelay = 0,
    TriggerbotMode = "Aimbot Lock",
    
    -- Anti-Aim
    AntiAimEnabled = false,
    AntiAimMode = "Spin", -- "Spin", "Jitter", "Side Jitter", "Backward", "Up-Down", "Custom Yaw", "Lurch"
    AntiAimSpeed = 10,
    AntiAimJitterAmplitude = 45,
    AntiAimYawOffset = 90,

    -- Camera FOV
    CustomFOVEnabled = false,
    CustomFOV = 70,

    -- Hold controls
    HoldToAim = true,
    AimMouseButton = "MouseButton2",
    AimKeyboardKey = Enum.KeyCode.E,

    -- Silent Aim Options
    Method = "Raycast",
    TargetPart = "Auto",
    DynamicPartList = {},

    -- Checks
    TeamCheck = false,
    VisibleCheck = false,
    HitChance = 100,

    -- Prediction
    Prediction = false,
    PredictionAmount = 0.165,

    -- FOV circle
    FOVEnabled = true,
    FOVRadius = 130,
    FOVColor = Color3.fromRGB(54, 57, 241),
    FOVTransparency = 1,
    FOVThickness = 1,
    FOVNumSides = 100,
    FOVFilled = false,
    FovAnimated = false,
    FovAnimationSpeed = 5,
    FovAnimationAmplitude = 20,

    -- Target indicator
    ShowTargetIndicator = true,
    TargetIndicatorSize = 20,
    TargetIndicatorColor = Color3.fromRGB(54, 57, 241),

    -- Silent Aim Visualizer
    SilentVisualizerEnabled = false,
    SilentVisualizerRadius = 6,
    SilentVisualizerColor = Color3.fromRGB(255, 0, 0),
    SilentVisualizerTransparency = 0.8,

    -- Player ESP Settings
    EspEnabled = false,
    EspBoxes = false,
    EspNames = false,
    EspDistances = false,
    EspHealth = false,
    EspTracers = false,
    EspTracerOrigin = "Bottom",
    EspColor = Color3.fromRGB(255, 255, 255),
    EspTextSize = 13,

    -- Out of View (OOF) Indicators Settings
    OofIndicatorsEnabled = false,
    OofIndicatorsSize = 10,
    OofIndicatorsRadius = 150,
    OofIndicatorsColor = Color3.fromRGB(255, 0, 0),

    -- Chams Settings
    ChamsEnabled = false,
    ChamsFillColor = Color3.fromRGB(255, 0, 0),
    ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
    ChamsFillTransparency = 0.5,
    ChamsOutlineTransparency = 0.0,
    ChamsAlwaysOnTop = true,

    -- World Environment Settings
    FogEnabled = false,
    FogStart = 0,
    FogEnd = 10000,
    FogColor = Color3.fromRGB(128, 128, 128),
    CustomLightingEnabled = false,
    ShadowsEnabled = true,
    AmbientColor = Color3.fromRGB(128, 128, 128),
    OutdoorAmbientColor = Color3.fromRGB(128, 128, 128),
    Brightness = 2.0,
    ClockTime = 12.0,
    ExposureCompensation = 0.0,
    
    -- Movement Utilities
    BhopEnabled = false,
    EdgeJumpEnabled = false,
    SilentWalkEnabled = false,
    SilentWalkSpeed = 6,
    SilentWalkKey = Enum.KeyCode.LeftShift,
    AntiAfkEnabled = false,
    FakeLagEnabled = false,
    FakeLagInterval = 10,
    FakeLagDuration = 100,
    
    -- Additional Combat Visuals
    RadarHackEnabled = false,
    RadarScale = 1.0,
    RadarSize = 120,
    DamageIndicators = false,
    HitMarkers = false,
    HitSoundEnabled = false,
    
    -- Diagnostics/Branding
    PerfMonitorEnabled = false,
    WatermarkEnabled = false,
    WatermarkText = "Adaptive Aimbot",
    CloudConfigCode = "",
}

-- Performance Indicators
local lastFps = 60
local statsInstance = game:GetService("Stats")

-- Custom Screen Drawing Instances
local fovCircle = Drawing.new("Circle")
local targetBox = Drawing.new("Square")
local silentVisualizer = Drawing.new("Circle")

local watermarkText = Drawing.new("Text")
watermarkText.Size = 16
watermarkText.Color = Color3.fromRGB(255, 255, 255)
watermarkText.Outline = true
watermarkText.Center = false

local watermarkBg = Drawing.new("Square")
watermarkBg.Color = Color3.fromRGB(15, 15, 15)
watermarkBg.Thickness = 1
watermarkBg.Filled = true
watermarkBg.Transparency = 0.6

local perfText = Drawing.new("Text")
perfText.Size = 16
perfText.Color = Color3.fromRGB(255, 255, 255)
perfText.Outline = true
perfText.Center = false

local perfBg = Drawing.new("Square")
perfBg.Color = Color3.fromRGB(15, 15, 15)
perfBg.Thickness = 1
perfBg.Filled = true
perfBg.Transparency = 0.6

local radarOuter = Drawing.new("Circle")
radarOuter.Radius = Config.RadarSize
radarOuter.Thickness = 2
radarOuter.Color = Color3.fromRGB(50, 250, 50)
radarOuter.Filled = false

local radarCenter = Drawing.new("Circle")
radarCenter.Radius = 3
radarCenter.Thickness = 1
radarCenter.Color = Color3.fromRGB(250, 50, 50)
radarCenter.Filled = true

local radarHeading = Drawing.new("Line")
radarHeading.Thickness = 1.5
radarHeading.Color = Color3.fromRGB(50, 250, 50)

local radarDots = {}

-- Original lighting backup
local originalLighting = {
    FogColor = Lighting.FogColor,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    ExposureCompensation = Lighting.ExposureCompensation
}
local atmosphereCache = nil

-- Dynamic Camera Reference Tracker
local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Shortcuts
local getPlayers = Players.GetPlayers
local getMouseLocation = UserInputService.GetMouseLocation

-- Helper notifications
local function notify(title, content, duration)
    syde:Notify({
        Title = title,
        Content = content,
        Duration = duration or 2
    })
end

-- Cloud Config Sync Serializer
local function generateCloudCode()
    local parts = {}
    local keys = {
        "AimbotEnabled", "SilentAimEnabled", "Smoothing", "DynamicSmoothing", "ReactionDelay",
        "AdaptiveSmoothing", "BezierPathing", "CursorJitter", "JitterIntensity", "MouseEventEmulation",
        "FOVRadius", "Prediction", "PredictionAmount", "HitChance", "EspEnabled", "EspBoxes",
        "EspNames", "EspDistances", "EspHealth", "EspTracers", "OofIndicatorsEnabled", "ChamsEnabled"
    }
    for _, k in ipairs(keys) do
        table.insert(parts, tostring(Config[k]))
    end
    local code = "AA-" .. table.concat(parts, "|")
    Config.CloudConfigCode = code
    if setclipboard then
        setclipboard(code)
        notify("Sync Generated", "Loadout config code copied to clipboard.", 3)
    end
    return code
end

local function parseCloudCode(code)
    if not code or not string.match(code, "^AA%-") then
        notify("Sync Failed", "Invalid configuration loadout code.", 3)
        return false
    end
    local raw = string.sub(code, 4)
    local parts = string.split(raw, "|")
    local keys = {
        "AimbotEnabled", "SilentAimEnabled", "Smoothing", "DynamicSmoothing", "ReactionDelay",
        "AdaptiveSmoothing", "BezierPathing", "CursorJitter", "JitterIntensity", "MouseEventEmulation",
        "FOVRadius", "Prediction", "PredictionAmount", "HitChance", "EspEnabled", "EspBoxes",
        "EspNames", "EspDistances", "EspHealth", "EspTracers", "OofIndicatorsEnabled", "ChamsEnabled"
    }
    for i, k in ipairs(keys) do
        if parts[i] ~= nil then
            if parts[i] == "true" then
                Config[k] = true
            elseif parts[i] == "false" then
                Config[k] = false
            else
                Config[k] = tonumber(parts[i]) or Config[k]
            end
        end
    end
    notify("Loaded Successfully", "Configuration successfully imported.", 3)
    return true
end

-- Lighting Control
local function applyLightingSettings()
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if Config.FogEnabled then
        if atmosphere then
            atmosphereCache = atmosphere
            atmosphere.Parent = nil
        end
        Lighting.FogStart = Config.FogStart
        Lighting.FogEnd = Config.FogEnd
        Lighting.FogColor = Config.FogColor
    else
        if atmosphereCache and not Lighting:FindFirstChildOfClass("Atmosphere") then
            atmosphereCache.Parent = Lighting
            atmosphereCache = nil
        end
        Lighting.FogStart = originalLighting.FogStart
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogColor = originalLighting.FogColor
    end
    
    if Config.CustomLightingEnabled then
        Lighting.GlobalShadows = Config.ShadowsEnabled
        Lighting.Ambient = Config.AmbientColor
        Lighting.OutdoorAmbient = Config.OutdoorAmbientColor
        Lighting.Brightness = Config.Brightness
        Lighting.ClockTime = Config.ClockTime
        Lighting.ExposureCompensation = Config.ExposureCompensation
    else
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.ExposureCompensation = originalLighting.ExposureCompensation
    end
end

-- Custom Damage Indicators Tracker
local damageIndicators = {}
local function spawnDamageIndicator(position, damage)
    if not Config.DamageIndicators then return end
    local d = Drawing.new("Text")
    d.Visible = true
    d.Text = "-" .. tostring(math.floor(damage))
    d.Size = 18
    d.Color = Color3.fromRGB(255, 50, 50)
    d.Outline = true
    d.Center = true
    table.insert(damageIndicators, {
        Drawing = d,
        WorldPos = position + Vector3.new(math.random(-1,1), math.random(1,3), math.random(-1,1)),
        Life = 1.0
    })
end

-- Audio Playback Hitmarker Sound Emulator
local function playHitmarkerSound()
    if Config.HitSoundEnabled then
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://160432334"
        sound.Volume = 2
        sound.Parent = game:GetService("SoundService")
        sound:Play()
        game:GetService("Debris"):AddItem(sound, 2)
    end
end

-- Hitmarker Crosshair Flash Lines
local hitmarkerLines = {}
for i = 1, 4 do
    local l = Drawing.new("Line")
    l.Visible = false
    l.Color = Color3.fromRGB(255, 255, 255)
    l.Thickness = 1.5
    table.insert(hitmarkerLines, l)
end

local hitmarkerTime = 0
local function triggerHitmarkerFlash()
    hitmarkerTime = tick() + 0.2 -- flash for 200ms
end

-- Part selection
local function getAutoTargetPart(character)
    if not character then return nil end
    local highest = nil
    local maxY = -math.huge
    for _, v in ipairs(character:GetDescendants()) do
        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" then
            local y = v.Position.Y
            if y > maxY then
                maxY = y
                highest = v
            end
        end
    end
    return highest
end

local function getCurrentTargetPart(player)
    local char = player.Character
    if not char then return nil end
    if Config.TargetPart == "Auto" then
        return getAutoTargetPart(char)
    elseif Config.TargetPart == "Random" then
        local available = {}
        for _, partName in ipairs({"Head", "HumanoidRootPart"}) do
            local p = char:FindFirstChild(partName)
            if p then table.insert(available, p) end
        end
        if #available == 0 then return getAutoTargetPart(char) end
        return available[math.random(1, #available)]
    else
        return char:FindFirstChild(Config.TargetPart)
    end
end

-- Core Screen Projection Helpers
local function getPositionOnScreen(position)
    if not Camera then return Vector2.new(0,0), false end
    local vec3, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(vec3.X, vec3.Y), onScreen
end

local function isPlayerVisible(player)
    local char = player.Character
    local localChar = LocalPlayer.Character
    if not char or not localChar or not Camera then return false end
    local part = getCurrentTargetPart(player)
    if not part then return false end
    local castPoints = {part.Position, localChar, char}
    local ignoreList = {localChar, char}
    return #Camera:GetPartsObscuringTarget(castPoints, ignoreList) == 0
end

local function calculateChance(percentage)
    return math.random() * 100 <= math.floor(percentage)
end

-- Get closest player
local function getClosestPlayer()
    local mousePos = getMouseLocation(UserInputService)
    local closestPart = nil
    local closestDist = math.huge
    for _, player in ipairs(getPlayers(Players)) do
        if player == LocalPlayer then continue end
        if Config.TeamCheck and player.Team == LocalPlayer.Team then continue end
        local char = player.Character
        if not char then continue end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        if Config.VisibleCheck and not isPlayerVisible(player) then continue end
        local part = getCurrentTargetPart(player)
        if not part then continue end
        local screenPos, onScreen = getPositionOnScreen(part.Position)
        if not onScreen then continue end
        local dist = (mousePos - screenPos).Magnitude
        if dist <= Config.FOVRadius and dist < closestDist then
            closestDist = dist
            closestPart = part
        end
    end
    return closestPart
end

-- Cubic Bezier Math Curve calculation
local function getBezierPoint(p0, p1, p2, p3, t)
    return (1-t)^3 * p0 + 3*(1-t)^2 * t * p1 + 3*(1-t) * t^2 * p2 + t^3 * p3
end

-- Core ESP Engine
local espCache = {}

local function createEsp(player)
    if espCache[player] then return end
    local drawings = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        OofIndicator = Drawing.new("Triangle"),
        HealthBarOutline = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        Highlight = nil
    }
    
    drawings.Box.Visible = false
    drawings.Box.Thickness = 1
    drawings.Box.Color = Config.EspColor
    drawings.Box.Filled = false
    
    drawings.Name.Visible = false
    drawings.Name.Size = Config.EspTextSize
    drawings.Name.Center = true
    drawings.Name.Outline = true
    drawings.Name.Color = Config.EspColor
    
    drawings.Distance.Visible = false
    drawings.Distance.Size = Config.EspTextSize
    drawings.Distance.Center = true
    drawings.Distance.Outline = true
    drawings.Distance.Color = Config.EspColor

    drawings.Tracer.Visible = false
    drawings.Tracer.Thickness = 1
    drawings.Tracer.Color = Config.EspColor

    drawings.OofIndicator.Visible = false
    drawings.OofIndicator.Filled = true
    drawings.OofIndicator.Color = Config.OofIndicatorsColor
    drawings.OofIndicator.Thickness = 1
    drawings.OofIndicator.Transparency = 1

    drawings.HealthBarOutline.Visible = false
    drawings.HealthBarOutline.Thickness = 1
    drawings.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    drawings.HealthBarOutline.Filled = true

    drawings.HealthBar.Visible = false
    drawings.HealthBar.Thickness = 1
    drawings.HealthBar.Color = Color3.fromRGB(0, 255, 0)
    drawings.HealthBar.Filled = true
    
    espCache[player] = drawings
end

local function removeEsp(player)
    local drawings = espCache[player]
    if drawings then
        for k, drawing in pairs(drawings) do
            if k ~= "Highlight" then
                pcall(function() drawing:Remove() end)
            elseif drawing then
                pcall(function() drawing:Destroy() end)
            end
        end
        espCache[player] = nil
    end
end

local function updateChams(player, drawings)
    local char = player.Character
    if not char then
        if drawings.Highlight then
            pcall(function() drawings.Highlight:Destroy() end)
            drawings.Highlight = nil
        end
        return
    end
    
    if Config.ChamsEnabled then
        local isTeammate = Config.TeamCheck and player.Team == LocalPlayer.Team
        if isTeammate then
            if drawings.Highlight then
                pcall(function() drawings.Highlight:Destroy() end)
                drawings.Highlight = nil
            end
            return
        end

        local highlight = drawings.Highlight
        if not highlight or highlight.Parent ~= char then
            if highlight then pcall(function() highlight:Destroy() end) end
            local success = pcall(function()
                highlight = Instance.new("Highlight")
                highlight.Name = "CascadeHighlight"
                highlight.Parent = char
            end)
            if success then
                drawings.Highlight = highlight
            else
                drawings.Highlight = nil
                return
            end
        end
        highlight.FillColor = Config.ChamsFillColor
        highlight.OutlineColor = Config.ChamsOutlineColor
        highlight.FillTransparency = Config.ChamsFillTransparency
        highlight.OutlineTransparency = Config.ChamsOutlineTransparency
        highlight.DepthMode = Config.ChamsAlwaysOnTop and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        highlight.Enabled = true
    else
        if drawings.Highlight then
            pcall(function() drawings.Highlight:Destroy() end)
            drawings.Highlight = nil
        end
    end
end

local function updateEsp()
    if not Camera then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local isTeammate = Config.TeamCheck and player.Team == LocalPlayer.Team
        local drawings = espCache[player]
        if not drawings then
            createEsp(player)
            drawings = espCache[player]
        end
        
        updateChams(player, drawings)
        
        local char = player.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local rpart = char and char:FindFirstChild("HumanoidRootPart")
        
        if char and humanoid and rpart and humanoid.Health > 0 and not isTeammate then
            local rpartPos = rpart.Position
            local screenPos, onScreen = Camera:WorldToViewportPoint(rpartPos)
            
            -- Out of View (OOF) Indicators Rendering Logic
            local isOffscreen = not onScreen or screenPos.Z < 0
            if Config.OofIndicatorsEnabled and isOffscreen then
                local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                local target2D = Vector2.new(screenPos.X, screenPos.Y)
                
                local dir = (target2D - screenCenter).Unit
                if tostring(dir.X) == "nan" or tostring(dir.Y) == "nan" then
                    dir = Vector2.new(0, -1)
                end
                
                if screenPos.Z < 0 then
                    dir = -dir
                end
                
                local arrowCenter = screenCenter + (dir * Config.OofIndicatorsRadius)
                local perp = Vector2.new(-dir.Y, dir.X)
                local size = Config.OofIndicatorsSize
                
                local pointA = arrowCenter + (dir * size)
                local pointB = arrowCenter - (dir * size) + (perp * (size * 0.6))
                local pointC = arrowCenter - (dir * size) - (perp * (size * 0.6))
                
                drawings.OofIndicator.Visible = true
                drawings.OofIndicator.PointA = pointA
                drawings.OofIndicator.PointB = pointB
                drawings.OofIndicator.PointC = pointC
                drawings.OofIndicator.Color = Config.OofIndicatorsColor
            else
                drawings.OofIndicator.Visible = false
            end
            
            -- 2D Screen ESP Elements
            if Config.EspEnabled and not isOffscreen then
                local head = char:FindFirstChild("Head")
                local topPos = head and (head.Position + Vector3.new(0, 1.6, 0)) or (rpartPos + Vector3.new(0, 3, 0))
                local bottomPos = rpartPos - Vector3.new(0, 3, 0)
                
                local topScreen, topOn = Camera:WorldToViewportPoint(topPos)
                local bottomScreen, bottomOn = Camera:WorldToViewportPoint(bottomPos)
                
                if topOn and bottomOn then
                    local boxHeight = math.abs(topScreen.Y - bottomScreen.Y)
                    local boxWidth = boxHeight * 0.6
                    local boxX = topScreen.X - (boxWidth / 2)
                    local boxY = topScreen.Y
                    
                    -- Box
                    if Config.EspBoxes then
                        drawings.Box.Visible = true
                        drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
                        drawings.Box.Position = Vector2.new(boxX, boxY)
                        drawings.Box.Color = Config.EspColor
                    else
                        drawings.Box.Visible = false
                    end
                    
                    -- Name
                    if Config.EspNames then
                        drawings.Name.Visible = true
                        drawings.Name.Text = player.Name
                        drawings.Name.Position = Vector2.new(topScreen.X, boxY - Config.EspTextSize - 2)
                        drawings.Name.Color = Config.EspColor
                        drawings.Name.Size = Config.EspTextSize
                    else
                        drawings.Name.Visible = false
                    end
                    
                    -- Distance
                    if Config.EspDistances then
                        drawings.Distance.Visible = true
                        local dist = math.floor((Camera.CFrame.Position - rpartPos).Magnitude)
                        drawings.Distance.Text = ("[%d studs]"):format(dist)
                        drawings.Distance.Position = Vector2.new(topScreen.X, boxY + boxHeight + 2)
                        drawings.Distance.Color = Config.EspColor
                        drawings.Distance.Size = Config.EspTextSize
                    else
                        drawings.Distance.Visible = false
                    end

                    -- Tracers / Snaplines
                    if Config.EspTracers then
                        drawings.Tracer.Visible = true
                        local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        if Config.EspTracerOrigin == "Center" then
                            origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
                        elseif Config.EspTracerOrigin == "Mouse" then
                            origin = getMouseLocation(UserInputService)
                        end
                        drawings.Tracer.From = origin
                        drawings.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        drawings.Tracer.Color = Config.EspColor
                    else
                        drawings.Tracer.Visible = false
                    end
                    
                    -- Health Bar
                    if Config.EspHealth then
                        drawings.HealthBarOutline.Visible = true
                        drawings.HealthBarOutline.Position = Vector2.new(boxX - 6, boxY)
                        drawings.HealthBarOutline.Size = Vector2.new(4, boxHeight)
                        
                        drawings.HealthBar.Visible = true
                        local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                        local barHeight = boxHeight * healthPercent
                        drawings.HealthBar.Position = Vector2.new(boxX - 5, boxY + (boxHeight - barHeight))
                        drawings.HealthBar.Size = Vector2.new(2, barHeight)
                        drawings.HealthBar.Color = Color3.fromRGB(255 - (255 * healthPercent), 255 * healthPercent, 0)
                    else
                        drawings.HealthBarOutline.Visible = false
                        drawings.HealthBar.Visible = false
                    end
                else
                    drawings.Box.Visible = false
                    drawings.Name.Visible = false
                    drawings.Distance.Visible = false
                    drawings.Tracer.Visible = false
                    drawings.HealthBarOutline.Visible = false
                    drawings.HealthBar.Visible = false
                end
            else
                drawings.Box.Visible = false
                drawings.Name.Visible = false
                drawings.Distance.Visible = false
                drawings.Tracer.Visible = false
                drawings.HealthBarOutline.Visible = false
                drawings.HealthBar.Visible = false
            end
        else
            drawings.Box.Visible = false
            drawings.Name.Visible = false
            drawings.Distance.Visible = false
            drawings.Tracer.Visible = false
            drawings.OofIndicator.Visible = false
            drawings.HealthBarOutline.Visible = false
            drawings.HealthBar.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(removeEsp)

-- Radar update
local function updateRadar()
    if not Config.RadarHackEnabled or not Camera then
        radarOuter.Visible = false
        radarCenter.Visible = false
        radarHeading.Visible = false
        for _, dot in pairs(radarDots) do dot.Visible = false end
        return
    end
    
    local screenCenter = Vector2.new(200, 300)
    radarOuter.Visible = true
    radarOuter.Position = screenCenter
    radarOuter.Radius = Config.RadarSize
    
    radarCenter.Visible = true
    radarCenter.Position = screenCenter
    
    local lookVec = Camera.CFrame.LookVector
    local headingEnd = screenCenter + Vector2.new(lookVec.X, -lookVec.Z).Unit * Config.RadarSize
    radarHeading.Visible = true
    radarHeading.From = screenCenter
    radarHeading.To = headingEnd
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local isTeammate = Config.TeamCheck and player.Team == LocalPlayer.Team
        local char = player.Character
        local rpart = char and char:FindFirstChild("HumanoidRootPart")
        
        if char and rpart and not isTeammate then
            local offset = rpart.Position - Camera.CFrame.Position
            local flatDistance = Vector2.new(offset.X, offset.Z)
            
            local camAngle = math.atan2(lookVec.X, lookVec.Z)
            local cos = math.cos(-camAngle)
            local sin = math.sin(-camAngle)
            local rx = (flatDistance.X * cos - flatDistance.Y * sin) * Config.RadarScale
            local ry = (flatDistance.X * sin + flatDistance.Y * cos) * Config.RadarScale
            
            local localOffset = Vector2.new(rx, ry)
            if localOffset.Magnitude <= Config.RadarSize then
                local dot = radarDots[player]
                if not dot then
                    dot = Drawing.new("Circle")
                    dot.Radius = 4
                    dot.Filled = true
                    dot.Color = Color3.fromRGB(250, 50, 50)
                    radarDots[player] = dot
                end
                dot.Visible = true
                dot.Position = screenCenter + localOffset
            else
                if radarDots[player] then radarDots[player].Visible = false end
            end
        else
            if radarDots[player] then radarDots[player].Visible = false end
        end
    end
end

-- Health change damage indicators loop
local playerHealths = {}
task.spawn(function()
    while true do
        task.wait(0.1)
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local rpart = char and char:FindFirstChild("HumanoidRootPart")
            if hum and rpart then
                local lastH = playerHealths[player] or hum.MaxHealth
                local curH = hum.Health
                if curH < lastH then
                    local diff = lastH - curH
                    if diff > 0 and diff <= hum.MaxHealth then
                        spawnDamageIndicator(rpart.Position, diff)
                        if Config.HitMarkers then
                            playHitmarkerSound()
                            triggerHitmarkerFlash()
                        end
                    end
                end
                playerHealths[player] = curH
            else
                playerHealths[player] = nil
            end
        end
    end
end)

-- Autoshoot logic
local autoShootNext = 0
task.spawn(function()
    while true do
        task.wait()
        if Config.AutoShootEnabled and cachedClosestPart and isAimingHeld() then
            local now = tick() * 1000
            if now >= autoShootNext then
                if Config.LegitMode then
                    mouse1press()
                    autoShootNext = now + Config.AutoShootDelay
                else
                    mouse1press()
                    autoShootNext = now + 1
                end
            end
        end
    end
end)

-- Triggerbot
task.spawn(function()
    while true do
        task.wait(1/60)
        if Config.TriggerbotEnabled then
            local fire = false
            if Config.TriggerbotMode == "Crosshair" then
                local ray = Camera:ScreenPointToRay(getMouseLocation(UserInputService).X, getMouseLocation(UserInputService).Y)
                local part = workspace:FindPartOnRay(ray, LocalPlayer.Character)
                if part and part.Parent and part.Parent:FindFirstChildOfClass("Humanoid") then
                    fire = true
                end
            elseif Config.TriggerbotMode == "Aimbot Lock" then
                if cachedClosestPart then fire = true end
            end
            if fire then
                if Config.TriggerbotDelay > 0 then
                    task.wait(Config.TriggerbotDelay / 1000)
                end
                mouse1press()
            end
        end
    end
end)

-- Anti-AFK Setup
local IDLE_KICK_MUTEX = false
LocalPlayer.Idled:Connect(function()
    if Config.AntiAfkEnabled and not IDLE_KICK_MUTEX then
        IDLE_KICK_MUTEX = true
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, game)
        IDLE_KICK_MUTEX = false
    end
end)

-- Ledge jump check
task.spawn(function()
    while true do
        task.wait(0.05)
        if Config.EdgeJumpEnabled then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if root and hum and hum.FloorMaterial ~= Enum.Material.Air then
                local velocity = root.Velocity
                if velocity.Magnitude > 2 then
                    local dir = velocity.Unit * 1.5
                    local checkOrigin = root.Position + dir - Vector3.new(0, 2.5, 0)
                    local rayResult = workspace:Raycast(checkOrigin, Vector3.new(0, -5, 0))
                    if not rayResult then
                        hum.Jump = true
                    end
                end
            end
        end
    end
end)

-- Silent walk Input logic
local silentWalkActive = false
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.SilentWalkKey then
        silentWalkActive = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Config.SilentWalkKey then
        silentWalkActive = false
    end
end)

-- Render Loop Updates
local cachedClosestPart = nil
local lastTarget = nil
local lockStartTime = 0
local reactionTargetTime = 0

RunService.RenderStepped:Connect(function()
    cachedClosestPart = getClosestPlayer()
    updateEsp()
    applyLightingSettings()
    
    -- Performance Metrics Calculations
    local fps = math.floor(1 / RunService.RenderStepped:Wait())
    local ping = math.floor(statsInstance.Network.ServerStatsItem["Data Ping"]:GetValue())
    local mem = math.floor(gcinfo())

    -- Watermark & Performance Rendering
    if Config.WatermarkEnabled then
        watermarkText.Text = " " .. Config.WatermarkText .. " | Live "
        watermarkText.Position = Vector2.new(15, 20)
        watermarkText.Visible = true
        watermarkBg.Position = Vector2.new(10, 15)
        watermarkBg.Size = Vector2.new(watermarkText.TextBounds.X + 10, watermarkText.TextBounds.Y + 10)
        watermarkBg.Visible = true
    else
        watermarkText.Visible = false
        watermarkBg.Visible = false
    end

    if Config.PerfMonitorEnabled then
        perfText.Text = string.format(" FPS: %d | Ping: %dms | Mem: %dMB", fps, ping, mem)
        perfText.Position = Vector2.new(15, 60)
        perfText.Visible = true
        perfBg.Position = Vector2.new(10, 55)
        perfBg.Size = Vector2.new(perfText.TextBounds.X + 10, perfText.TextBounds.Y + 10)
        perfBg.Visible = true
    else
        perfText.Visible = false
        perfBg.Visible = false
    end

    -- Hitmarker crosshair lines updater
    if Config.HitMarkers and tick() < hitmarkerTime then
        local center = getMouseLocation(UserInputService)
        local gap = 4
        local len = 8
        
        hitmarkerLines[1].From = center - Vector2.new(gap, gap)
        hitmarkerLines[1].To = center - Vector2.new(gap + len, gap + len)
        hitmarkerLines[1].Visible = true
        
        hitmarkerLines[2].From = center + Vector2.new(gap, -gap)
        hitmarkerLines[2].To = center + Vector2.new(gap + len, -(gap + len))
        hitmarkerLines[2].Visible = true
        
        hitmarkerLines[3].From = center + Vector2.new(-gap, gap)
        hitmarkerLines[3].To = center + Vector2.new(-(gap + len), gap + len)
        hitmarkerLines[3].Visible = true
        
        hitmarkerLines[4].From = center + Vector2.new(gap, gap)
        hitmarkerLines[4].To = center + Vector2.new(gap + len, gap + len)
        hitmarkerLines[4].Visible = true
    else
        for _, l in ipairs(hitmarkerLines) do l.Visible = false end
    end

    -- Floating damage indicators
    for i = #damageIndicators, 1, -1 do
        local indicator = damageIndicators[i]
        indicator.Life = indicator.Life - 0.02
        if indicator.Life <= 0 then
            indicator.Drawing:Remove()
            table.remove(damageIndicators, i)
        else
            local screenPos, onScreen = getPositionOnScreen(indicator.WorldPos)
            if onScreen then
                indicator.Drawing.Visible = true
                indicator.Drawing.Position = screenPos - Vector2.new(0, (1 - indicator.Life) * 50)
                indicator.Drawing.Transparency = indicator.Life
            else
                indicator.Drawing.Visible = false
            end
        end
    end

    -- Bunny Hop Space bar input
    if Config.BhopEnabled and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            hum.Jump = true
        end
    end

    -- Silent walk physics slow speed
    if Config.SilentWalkEnabled and silentWalkActive then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = Config.SilentWalkSpeed
        end
    end

    -- Fake Lag spikes
    if Config.FakeLagEnabled then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and math.random(1, 100) <= Config.FakeLagInterval then
            root.Anchored = true
            task.wait(Config.FakeLagDuration / 1000)
            root.Anchored = false
        end
    end

    -- Aimbot Calculations
    if Config.AimbotEnabled and cachedClosestPart and isAimingHeld() and Camera then
        if cachedClosestPart ~= lastTarget then
            lastTarget = cachedClosestPart
            lockStartTime = tick()
            reactionTargetTime = tick() + (Config.ReactionDelay / 1000)
        end
        
        if tick() >= reactionTargetTime then
            local timeElapsed = tick() - reactionTargetTime
            local targetPos = cachedClosestPart.Position
            if Config.Prediction and cachedClosestPart.Velocity then
                targetPos = targetPos + cachedClosestPart.Velocity * Config.PredictionAmount
            end
            local currentCFrame = Camera.CFrame

            -- Dynamic humanization paths
            local smooth, curve, shake = Config.Smoothing, Config.AccelerationCurve, Config.AimShake
            local distance = (Camera.CFrame.Position - targetPos).Magnitude

            -- Adaptive Smoothing Calculations
            if Config.AdaptiveSmoothing then
                if distance < 30 then
                    smooth = smooth * 1.5
                elseif distance > 150 then
                    smooth = math.max(1, smooth * 0.7)
                end
            end

            -- Dynamic Smoothing Waves
            if Config.DynamicSmoothing then
                smooth = smooth + (math.sin(tick() * 5) * (smooth * 0.25))
            end

            -- Jitter pattern additions
            if Config.CursorJitter then
                local jIntensity = Config.JitterIntensity * 0.05
                targetPos = targetPos + Vector3.new(
                    (math.random() - 0.5) * jIntensity,
                    (math.random() - 0.5) * jIntensity,
                    (math.random() - 0.5) * jIntensity
                )
            end

            local rawTargetCFrame = CFrame.new(currentCFrame.Position, targetPos)
            local step = 1 / math.clamp(smooth, 1, 100)
            step = math.pow(step, curve)

            -- Optional Mouse Emulation bypass paths
            if Config.MouseEventEmulation and mousemoverel then
                local screenPos, onScreen = getPositionOnScreen(targetPos)
                if onScreen then
                    local mousePos = getMouseLocation(UserInputService)
                    local delta = (screenPos - mousePos) / smooth
                    mousemoverel(delta.X, delta.Y)
                end
            elseif Config.BezierPathing then
                local p0 = currentCFrame.Position
                local p3 = targetPos
                local diff = (p3 - p0)
                local p1 = p0 + currentCFrame.LookVector * (diff.Magnitude * 0.33)
                local p2 = p3 - rawTargetCFrame.LookVector * (diff.Magnitude * 0.33)
                
                local bezierT = math.clamp(timeElapsed / (smooth * 0.1), 0, 1)
                local currentPos = getBezierPoint(p0, p1, p2, p3, bezierT)
                Camera.CFrame = CFrame.new(currentCFrame.Position, currentPos)
            else
                Camera.CFrame = currentCFrame:Lerp(rawTargetCFrame, math.clamp(step, 0, 1))
            end
        end
    else
        lastTarget = nil
    end

    -- FOV circle drawing anims
    if Config.FOVEnabled then
        local radius = Config.FOVRadius
        if Config.FovAnimated then
            radius = radius + math.sin(tick() * Config.FovAnimationSpeed) * Config.FovAnimationAmplitude
        end
        fovCircle.Visible = true
        fovCircle.Radius = radius
        fovCircle.Color = Config.FOVColor
        fovCircle.Position = getMouseLocation(UserInputService)
        fovCircle.Thickness = Config.FOVThickness
        fovCircle.NumSides = Config.FOVNumSides
        fovCircle.Filled = Config.FOVFilled
        fovCircle.Transparency = Config.FOVTransparency
    else
        fovCircle.Visible = false
    end

    -- Target indicator
    if Config.ShowTargetIndicator and cachedClosestPart then
        local pos, onScreen = getPositionOnScreen(cachedClosestPart.Position)
        if onScreen then
            targetBox.Visible = true
            targetBox.Position = pos - Vector2.new(Config.TargetIndicatorSize / 2, Config.TargetIndicatorSize / 2)
            targetBox.Color = Config.TargetIndicatorColor
            targetBox.Size = Vector2.new(Config.TargetIndicatorSize, Config.TargetIndicatorSize)
        else
            targetBox.Visible = false
        end
    else
        targetBox.Visible = false
    end

    -- Silent Aim target visualizer
    if Config.SilentVisualizerEnabled and Config.SilentAimEnabled and cachedClosestPart then
        local targetPos = cachedClosestPart.Position
        if Config.Prediction and cachedClosestPart.Velocity then
            targetPos = targetPos + cachedClosestPart.Velocity * Config.PredictionAmount
        end
        local pos, onScreen = getPositionOnScreen(targetPos)
        if onScreen then
            silentVisualizer.Visible = true
            silentVisualizer.Position = pos
            silentVisualizer.Radius = Config.SilentVisualizerRadius
            silentVisualizer.Color = Config.SilentVisualizerColor
            silentVisualizer.Transparency = Config.SilentVisualizerTransparency
        else
            silentVisualizer.Visible = false
        end
    else
        silentVisualizer.Visible = false
    end

    updateRadar()
end)

-- Main Syde Interface Initialization (Tabs require String arguments only!)
local Window = syde:Init({
    Title = "Adaptive Aimbot",
    SubText = "Universal Premium UI Framework"
})

local CombatTab = Window:InitTab("Combat")
local VisualsTab = Window:InitTab("Visuals")
local MovementTab = Window:InitTab("Movement")
local WorldTab = Window:InitTab("World")
local SettingsTab = Window:InitTab("Settings")

-- ==========================================
-- COMBAT TAB
-- ==========================================
CombatTab:Section("Combat Framework Switch")
CombatTab:Toggle({
    Title = "Aimbot Enabled",
    Description = "Activate master lock-on mechanics.",
    Value = Config.AimbotEnabled,
    Config = true,
    Flag = "AimbotEnabled",
    CallBack = function(v) Config.AimbotEnabled = v end
})
CombatTab:Toggle({
    Title = "Silent Aim Enabled",
    Description = "Redirects server-side shoot vectors natively.",
    Value = Config.SilentAimEnabled,
    Config = true,
    Flag = "SilentAimEnabled",
    CallBack = function(v) Config.SilentAimEnabled = v end
})
CombatTab:Toggle({
    Title = "Hold To Aim",
    Description = "Require manual tracking keys to be pressed.",
    Value = Config.HoldToAim,
    Config = true,
    Flag = "HoldToAim",
    CallBack = function(v) Config.HoldToAim = v end
})

CombatTab:Section("Fine-Tuning & Prediction")
CombatTab:Toggle({
    Title = "Target Velocity Prediction",
    Description = "Calibrates distance/velocity trajectories.",
    Value = Config.Prediction,
    Config = true,
    Flag = "Prediction",
    CallBack = function(v) Config.Prediction = v end
})

CombatTab:CreateSlider({
    Title = "Precision Parameters",
    Description = "Configures smoothing speeds and reaction delays.",
    Sliders = {
        {
            Title = "Base Smoothing",
            Range = {1, 100},
            Increment = 1,
            StarterValue = Config.Smoothing,
            Flag = "Smoothing",
            CallBack = function(v) Config.Smoothing = v end
        },
        {
            Title = "Reaction Delay (ms)",
            Range = {0, 500},
            Increment = 5,
            StarterValue = Config.ReactionDelay,
            Flag = "ReactionDelay",
            CallBack = function(v) Config.ReactionDelay = v end
        },
        {
            Title = "Hit Chance (%)",
            Range = {0, 100},
            Increment = 1,
            StarterValue = Config.HitChance,
            Flag = "HitChance",
            CallBack = function(v) Config.HitChance = v end
        }
    }
})

CombatTab:Section("Aim Humanization Mechanics")
CombatTab:Toggle({
    Title = "Dynamic Smoothing",
    Description = "Adds randomized smoothing scales over time.",
    Value = Config.DynamicSmoothing,
    Config = true,
    Flag = "DynamicSmoothing",
    CallBack = function(v) Config.DynamicSmoothing = v end
})
CombatTab:Toggle({
    Title = "Adaptive Smoothing",
    Description = "Scales smoothing dynamically based on target distance.",
    Value = Config.AdaptiveSmoothing,
    Config = true,
    Flag = "AdaptiveSmoothing",
    CallBack = function(v) Config.AdaptiveSmoothing = v end
})
CombatTab:Toggle({
    Title = "Bézier Path Curve Generation",
    Description = "Utilizes Cubic Bézier curves for realistic hand trajectories.",
    Value = Config.BezierPathing,
    Config = true,
    Flag = "BezierPathing",
    CallBack = function(v) Config.BezierPathing = v end
})
CombatTab:Toggle({
    Title = "Micro Cursor Jitter",
    Description = "Injects microscopic hand vibrations into movement paths.",
    Value = Config.CursorJitter,
    Config = true,
    Flag = "CursorJitter",
    CallBack = function(v) Config.CursorJitter = v end
})
CombatTab:CreateSlider({
    Title = "Human Jitter Tuning",
    Description = "Modifies simulated human micro-adjustment tremors.",
    Sliders = {
        {
            Title = "Jitter Intensity",
            Range = {1, 10},
            Increment = 1,
            StarterValue = Config.JitterIntensity,
            Flag = "JitterIntensity",
            CallBack = function(v) Config.JitterIntensity = v end
        }
    }
})
CombatTab:Toggle({
    Title = "Mouse Input Emulation Bypass",
    Description = "Translates aim movement via mousemoverel virtual frames.",
    Value = Config.MouseEventEmulation,
    Config = true,
    Flag = "MouseEventEmulation",
    CallBack = function(v) Config.MouseEventEmulation = v end
})

CombatTab:Section("Autoshoot & Wallbang Calibration")
CombatTab:Toggle({
    Title = "Autoshoot Enabled",
    Description = "Triggers weapons automatically when targets lock.",
    Value = Config.AutoShootEnabled,
    Config = true,
    Flag = "AutoShootEnabled",
    CallBack = function(v) Config.AutoShootEnabled = v end
})
CombatTab:Toggle({
    Title = "Autowallbang Enabled",
    Description = "Penetrates solid map parts towards player joints.",
    Value = Config.AutoWallbangEnabled,
    Config = true,
    Flag = "AutoWallbangEnabled",
    CallBack = function(v) Config.AutoWallbangEnabled = v end
})
CombatTab:Toggle({
    Title = "Rage Mode Legit Bypass Off",
    Description = "Bypasses all thickness checks for instant wall-piercing.",
    Value = not Config.LegitMode,
    Config = true,
    Flag = "RageModeBypass",
    CallBack = function(v) Config.LegitMode = not v end
})

CombatTab:Section("Triggerbot Settings")
CombatTab:Toggle({
    Title = "Triggerbot Enabled",
    Description = "Shoot automatically when your cursor crosses an enemy.",
    Value = Config.TriggerbotEnabled,
    Config = true,
    Flag = "TriggerbotEnabled",
    CallBack = function(v) Config.TriggerbotEnabled = v end
})

local triggerModes = {"Crosshair", "Aimbot Lock"}
CombatTab:Dropdown({
    Title = "Triggerbot Evaluation Mode",
    Options = triggerModes,
    PlaceHolder = "Select type...",
    Multi = false,
    CallBack = function(opt) Config.TriggerbotMode = opt end
})

CombatTab:Section("Anti-Aim Overrides")
CombatTab:Toggle({
    Title = "Enable Anti-Aim",
    Description = "Actively distorts player alignment coordinates.",
    Value = Config.AntiAimEnabled,
    Config = true,
    Flag = "AntiAimEnabled",
    CallBack = function(v) Config.AntiAimEnabled = v; updateAntiAim() end
})

local antiAimModes = {"Spin", "Jitter", "Side Jitter", "Backward", "Up-Down", "Custom Yaw", "Lurch"}
CombatTab:Dropdown({
    Title = "AA Movement Profile",
    Options = antiAimModes,
    PlaceHolder = "Select style...",
    Multi = false,
    CallBack = function(opt) Config.AntiAimMode = opt; updateAntiAim() end
})

CombatTab:CreateSlider({
    Title = "AA Rotation Speeds",
    Description = "Manages yaw customization limits.",
    Sliders = {
        {
            Title = "Anti-Aim Rotation Velocity",
            Range = {1, 50},
            Increment = 1,
            StarterValue = Config.AntiAimSpeed,
            Flag = "AntiAimSpeed",
            CallBack = function(v) Config.AntiAimSpeed = v end
        },
        {
            Title = "Custom Offset Angle",
            Range = {0, 360},
            Increment = 5,
            StarterValue = Config.AntiAimYawOffset,
            Flag = "AntiAimYawOffset",
            CallBack = function(v) Config.AntiAimYawOffset = v end
        }
    }
})

-- ==========================================
-- VISUALS TAB
-- ==========================================
VisualsTab:Section("ESP Rendering Elements")
VisualsTab:Toggle({
    Title = "Master ESP Toggle",
    Description = "Render drawing frames around other active entities.",
    Value = Config.EspEnabled,
    Config = true,
    Flag = "EspEnabled",
    CallBack = function(v) Config.EspEnabled = v end
})
VisualsTab:Toggle({
    Title = "Box Frames",
    Value = Config.EspBoxes,
    Config = true,
    Flag = "EspBoxes",
    CallBack = function(v) Config.EspBoxes = v end
})
VisualsTab:Toggle({
    Title = "Entity Names",
    Value = Config.EspNames,
    Config = true,
    Flag = "EspNames",
    CallBack = function(v) Config.EspNames = v end
})
VisualsTab:Toggle({
    Title = "Distance Meters",
    Value = Config.EspDistances,
    Config = true,
    Flag = "EspDistances",
    CallBack = function(v) Config.EspDistances = v end
})
VisualsTab:Toggle({
    Title = "Health Indicators",
    Value = Config.EspHealth,
    Config = true,
    Flag = "EspHealth",
    CallBack = function(v) Config.EspHealth = v end
})
VisualsTab:Toggle({
    Title = "Snaplines / Tracers",
    Value = Config.EspTracers,
    Config = true,
    Flag = "EspTracers",
    CallBack = function(v) Config.EspTracers = v end
})

local tracersOrigins = {"Bottom", "Center", "Mouse"}
VisualsTab:Dropdown({
    Title = "Snaplines Origin Coordinate",
    Options = tracersOrigins,
    PlaceHolder = "Select origin...",
    Multi = false,
    CallBack = function(opt) Config.EspTracerOrigin = opt end
})

VisualsTab:Section("Off-Screen Indicators")
VisualsTab:Toggle({
    Title = "Out of View (OOF) Pointers",
    Description = "Draws directional screen triangles towards offscreen players.",
    Value = Config.OofIndicatorsEnabled,
    Config = true,
    Flag = "OofIndicatorsEnabled",
    CallBack = function(v) Config.OofIndicatorsEnabled = v end
})
VisualsTab:CreateSlider({
    Title = "OOF Indicator Tuning",
    Description = "Fine-tune sizes and boundaries of OOF triangles.",
    Sliders = {
        {
            Title = "Pointer Size",
            Range = {5, 30},
            Increment = 1,
            StarterValue = Config.OofIndicatorsSize,
            Flag = "OofIndicatorsSize",
            CallBack = function(v) Config.OofIndicatorsSize = v end
        },
        {
            Title = "Screen Boundary Distance",
            Range = {50, 400},
            Increment = 5,
            StarterValue = Config.OofIndicatorsRadius,
            Flag = "OofIndicatorsRadius",
            CallBack = function(v) Config.OofIndicatorsRadius = v end
        }
    }
})

VisualsTab:Section("Chams Framework")
VisualsTab:Toggle({
    Title = "Chams Enabled",
    Description = "Fills character textures with standard solid colors.",
    Value = Config.ChamsEnabled,
    Config = true,
    Flag = "ChamsEnabled",
    CallBack = function(v) Config.ChamsEnabled = v end
})
VisualsTab:Toggle({
    Title = "Render Through Walls (Depth Mode Always)",
    Value = Config.ChamsAlwaysOnTop,
    Config = true,
    Flag = "ChamsAlwaysOnTop",
    CallBack = function(v) Config.ChamsAlwaysOnTop = v end
})
VisualsTab:CreateSlider({
    Title = "Chams Transparencies",
    Description = "Custom opacity configurations.",
    Sliders = {
        {
            Title = "Fill Alpha Opacity",
            Range = {0, 100},
            Increment = 5,
            StarterValue = math.floor(Config.ChamsFillTransparency * 100),
            Flag = "ChamsFillTransparency",
            CallBack = function(v) Config.ChamsFillTransparency = v / 100 end
        },
        {
            Title = "Outline Alpha Opacity",
            Range = {0, 100},
            Increment = 5,
            StarterValue = math.floor(Config.ChamsOutlineTransparency * 100),
            Flag = "ChamsOutlineTransparency",
            CallBack = function(v) Config.ChamsOutlineTransparency = v / 100 end
        }
    }
})

VisualsTab:Section("ESP Colors")
VisualsTab:ColorPicker({
    Title = "Primary ESP Colors",
    Color = Config.EspColor,
    Flag = "EspColorFlag",
    CallBack = function(c) Config.EspColor = c end
})
VisualsTab:ColorPicker({
    Title = "Chams Inner Color",
    Color = Config.ChamsFillColor,
    Flag = "ChamsFillColorFlag",
    CallBack = function(c) Config.ChamsFillColor = c end
})
VisualsTab:ColorPicker({
    Title = "Chams Border Outline Color",
    Color = Config.ChamsOutlineColor,
    Flag = "ChamsOutlineColorFlag",
    CallBack = function(c) Config.ChamsOutlineColor = c end
})
VisualsTab:ColorPicker({
    Title = "OOF Indicator Color",
    Color = Config.OofIndicatorsColor,
    Flag = "OofIndicatorsColorFlag",
    CallBack = function(c) Config.OofIndicatorsColor = c end
})

VisualsTab:Section("Screen Overlays")
VisualsTab:Toggle({
    Title = "Enable FOV Circle Overlay",
    Value = Config.FOVEnabled,
    Config = true,
    Flag = "FOVEnabled",
    CallBack = function(v) Config.FOVEnabled = v end
})
VisualsTab:Toggle({
    Title = "Animated FOV Circle (Breathing Effect)",
    Description = "Smoothly scale circle radius using sin wave functions.",
    Value = Config.FovAnimated,
    Config = true,
    Flag = "FovAnimated",
    CallBack = function(v) Config.FovAnimated = v end
})
VisualsTab:CreateSlider({
    Title = "FOV Parameters",
    Sliders = {
        {
            Title = "FOV Boundary Limit (Radius)",
            Range = {10, 800},
            Increment = 5,
            StarterValue = Config.FOVRadius,
            Flag = "FOVRadius",
            CallBack = function(v) Config.FOVRadius = v end
        }
    }
})
VisualsTab:ColorPicker({
    Title = "FOV Outline Color",
    Color = Config.FOVColor,
    Flag = "FOVColorFlag",
    CallBack = function(c) Config.FOVColor = c end
})

VisualsTab:Section("Target & Silent Trackers")
VisualsTab:Toggle({
    Title = "Show Selected Target Indicator Box",
    Value = Config.ShowTargetIndicator,
    Config = true,
    Flag = "ShowTargetIndicator",
    CallBack = function(v) Config.ShowTargetIndicator = v end
})
VisualsTab:Toggle({
    Title = "Show Silent Aim Tracking Point Dot",
    Value = Config.SilentVisualizerEnabled,
    Config = true,
    Flag = "SilentVisualizerEnabled",
    CallBack = function(v) Config.SilentVisualizerEnabled = v end
})

VisualsTab:Section("Minimap Radar Hack")
VisualsTab:Toggle({
    Title = "Enable Screen Minimap Radar",
    Description = "Spawns customized screen radar mapping enemy routes.",
    Value = Config.RadarHackEnabled,
    Config = true,
    Flag = "RadarHackEnabled",
    CallBack = function(v) Config.RadarHackEnabled = v end
})
VisualsTab:CreateSlider({
    Title = "Radar Controls",
    Description = "Adjust radar size and visual scale.",
    Sliders = {
        {
            Title = "Radar Box Radius",
            Range = {50, 250},
            Increment = 5,
            StarterValue = Config.RadarSize,
            Flag = "RadarSize",
            CallBack = function(v) Config.RadarSize = v end
        },
        {
            Title = "Radar Scale",
            Range = {1, 5},
            Increment = 1,
            StarterValue = Config.RadarScale,
            Flag = "RadarScale",
            CallBack = function(v) Config.RadarScale = v end
        }
    }
})

VisualsTab:Section("Feedback Overlays")
VisualsTab:Toggle({
    Title = "Floating Damage Indicators",
    Description = "Floats calculated deal-damage numbers in real-time above target joints.",
    Value = Config.DamageIndicators,
    Config = true,
    Flag = "DamageIndicators",
    CallBack = function(v) Config.DamageIndicators = v end
})
VisualsTab:Toggle({
    Title = "Enable Hitmarkers",
    Description = "Renders diagonal crosshair lines upon registered health changes.",
    Value = Config.HitMarkers,
    Config = true,
    Flag = "HitMarkers",
    CallBack = function(v) Config.HitMarkers = v end
})
VisualsTab:Toggle({
    Title = "Play Hitmarker Sound",
    Description = "Play classical FPS hit crunches.",
    Value = Config.HitSoundEnabled,
    Config = true,
    Flag = "HitSoundEnabled",
    CallBack = function(v) Config.HitSoundEnabled = v end
})

-- ==========================================
-- MOVEMENT TAB
-- ==========================================
MovementTab:Section("Player Physics Overrides")
MovementTab:Toggle({
    Title = "Bunny Hop Simulation",
    Description = "Automatically triggers jump sequences when holding the space bar.",
    Value = Config.BhopEnabled,
    Config = true,
    Flag = "BhopEnabled",
    CallBack = function(v) Config.BhopEnabled = v end
})
MovementTab:Toggle({
    Title = "Edge Jump / Auto Ledge Grab",
    Description = "Jump automatically when approaching solid edge boundaries to retain speed.",
    Value = Config.EdgeJumpEnabled,
    Config = true,
    Flag = "EdgeJumpEnabled",
    CallBack = function(v) Config.EdgeJumpEnabled = v end
})

MovementTab:Section("Movement Slow Walk (CS:GO style)")
MovementTab:Toggle({
    Title = "Silent Walk (Slow Walk)",
    Description = "Clamps maximum speeds when walking keys are depressed.",
    Value = Config.SilentWalkEnabled,
    Config = true,
    Flag = "SilentWalkEnabled",
    CallBack = function(v) Config.SilentWalkEnabled = v end
})
MovementTab:CreateSlider({
    Title = "Slow Walk Velocity Modifier",
    Sliders = {
        {
            Title = "Walk Velocity Clamping Speed",
            Range = {1, 16},
            Increment = 1,
            StarterValue = Config.SilentWalkSpeed,
            Flag = "SilentWalkSpeed",
            CallBack = function(v) Config.SilentWalkSpeed = v end
        }
    }
})

MovementTab:Section("Anti-AFK & Latency Spoofing")
MovementTab:Toggle({
    Title = "Anti-AFK Bypass",
    Description = "Simulates tiny movement loops when idle timers activate.",
    Value = Config.AntiAfkEnabled,
    Config = true,
    Flag = "AntiAfkEnabled",
    CallBack = function(v) Config.AntiAfkEnabled = v end
})
MovementTab:Toggle({
    Title = "Fake Lag Spike (Packet Distorter)",
    Description = "Spikes physical latency parameters to obtain peek advantages.",
    Value = Config.FakeLagEnabled,
    Config = true,
    Flag = "FakeLagEnabled",
    CallBack = function(v) Config.FakeLagEnabled = v end
})
MovementTab:CreateSlider({
    Title = "Fake Lag Modifiers",
    Sliders = {
        {
            Title = "Spike Frequency Range (%)",
            Range = {1, 100},
            Increment = 5,
            StarterValue = Config.FakeLagInterval,
            Flag = "FakeLagInterval",
            CallBack = function(v) Config.FakeLagInterval = v end
        },
        {
            Title = "Spike Latency Duration (ms)",
            Range = {50, 1000},
            Increment = 10,
            StarterValue = Config.FakeLagDuration,
            Flag = "FakeLagDuration",
            CallBack = function(v) Config.FakeLagDuration = v end
        }
    }
})

-- ==========================================
-- WORLD TAB
-- ==========================================
WorldTab:Section("Environmental Fog Modifications")
WorldTab:Toggle({
    Title = "Custom Fog Overrides",
    Description = "Enable custom client-side atmosphere settings.",
    Value = Config.FogEnabled,
    Config = true,
    Flag = "FogEnabled",
    CallBack = function(v) Config.FogEnabled = v; applyLightingSettings() end
})
WorldTab:CreateSlider({
    Title = "Atmospheric Fog Modifiers",
    Sliders = {
        {
            Title = "Fog Clear Range Start",
            Range = {0, 5000},
            Increment = 50,
            StarterValue = Config.FogStart,
            Flag = "FogStart",
            CallBack = function(v) Config.FogStart = v; applyLightingSettings() end
        },
        {
            Title = "Fog Dense Boundary Limit",
            Range = {100, 20000},
            Increment = 100,
            StarterValue = Config.FogEnd,
            Flag = "FogEnd",
            CallBack = function(v) Config.FogEnd = v; applyLightingSettings() end
        }
    }
})
WorldTab:ColorPicker({
    Title = "Fog Density Color",
    Color = Config.FogColor,
    Flag = "FogColorFlag",
    CallBack = function(c) Config.FogColor = c; applyLightingSettings() end
})

WorldTab:Section("Time Cycle Locking")
WorldTab:Toggle({
    Title = "Custom Ambient Lighting Enabled",
    Description = "Forces custom lighting parameters directly into client memory.",
    Value = Config.CustomLightingEnabled,
    Config = true,
    Flag = "CustomLightingEnabled",
    CallBack = function(v) Config.CustomLightingEnabled = v; applyLightingSettings() end
})
WorldTab:CreateSlider({
    Title = "Daylight Adjusters",
    Sliders = {
        {
            Title = "Forced Clock Time (0-24hr)",
            Range = {0, 24},
            Increment = 1,
            StarterValue = math.floor(Config.ClockTime),
            Flag = "ClockTime",
            CallBack = function(v) Config.ClockTime = v; applyLightingSettings() end
        },
        {
            Title = "Exposure Intensity",
            Range = {0, 10},
            Increment = 1,
            StarterValue = math.floor(Config.Brightness),
            Flag = "Brightness",
            CallBack = function(v) Config.Brightness = v; applyLightingSettings() end
        }
    }
})
WorldTab:ColorPicker({
    Title = "Custom Ambient Shadow Shade",
    Color = Config.AmbientColor,
    Flag = "AmbientColorFlag",
    CallBack = function(c) Config.AmbientColor = c; applyLightingSettings() end
})
WorldTab:ColorPicker({
    Title = "Custom Outdoor Ambient Color",
    Color = Config.OutdoorAmbientColor,
    Flag = "OutdoorAmbientColorFlag",
    CallBack = function(c) Config.OutdoorAmbientColor = c; applyLightingSettings() end
})

-- ==========================================
-- SETTINGS TAB
-- ==========================================
SettingsTab:Section("Local UI Styling Customizer")
local accentNames = {"Blue", "Purple", "Pink", "Red", "Orange", "Yellow", "Green", "Graphite"}
SettingsTab:Dropdown({
    Title = "Accent Theme Color Selector",
    Options = accentNames,
    PlaceHolder = "Select color theme...",
    Multi = false,
    CallBack = function(opt)
        if syde.Accents and syde.Accents[opt] then
            syde.Accent = syde.Accents[opt]
        end
    end
})

SettingsTab:Section("Telemetry Monitor Widgets")
SettingsTab:Toggle({
    Title = "Custom Watermark Overlay",
    Value = Config.WatermarkEnabled,
    Config = true,
    Flag = "WatermarkEnabled",
    CallBack = function(v) Config.WatermarkEnabled = v end
})
SettingsTab:TextInput({
    Title = "Watermark Text Label",
    PlaceHolder = "Adaptive Aimbot...",
    MaxSize = 50,
    CallBack = function(text) Config.WatermarkText = text end
})
SettingsTab:Toggle({
    Title = "Diagnostics / FPS & Ping Monitor",
    Description = "Displays detailed FPS, ping, and memory monitors.",
    Value = Config.PerfMonitorEnabled,
    Config = true,
    Flag = "PerfMonitorEnabled",
    CallBack = function(v) Config.PerfMonitorEnabled = v end
})

SettingsTab:Section("Loadout Cloud Config Sharing")
SettingsTab:TextInput({
    Title = "Config Serializer Loadout Code",
    PlaceHolder = "Paste shared code string here...",
    MaxSize = 300,
    CallBack = function(text) Config.CloudConfigCode = text end
})
SettingsTab:Button({
    Title = "Import Shared Config Code",
    Description = "Applies loaded settings instantly to current profile parameters.",
    Type = "Default",
    CallBack = function()
        if Config.CloudConfigCode ~= "" then
            parseCloudCode(Config.CloudConfigCode)
        end
    end
})
SettingsTab:Button({
    Title = "Generate Shareable Config Code",
    Description = "Serializes current UI options and copies the loadout string to your clipboard.",
    Type = "Default",
    CallBack = function()
        generateCloudCode()
    end
})

SettingsTab:Section("App Control Binds")
SettingsTab:Keybind({
    Title = "Aimbot Toggle Keybind",
    Key = Config.AimbotToggleKey,
    CallBack = function()
        Config.AimbotEnabled = not Config.AimbotEnabled
        notify("Aimbot Toggled", "Aimbot is now " .. (Config.AimbotEnabled and "ON" or "OFF"), 2)
    end
})
SettingsTab:Keybind({
    Title = "Silent Aim Toggle Keybind",
    Key = Config.SilentAimToggleKey,
    CallBack = function()
        Config.SilentAimEnabled = not Config.SilentAimEnabled
        notify("Silent Aim Toggled", "Silent Aim is now " .. (Config.SilentAimEnabled and "ON" or "OFF"), 2)
    end
})
SettingsTab:Keybind({
    Title = "Slow Walk Toggle Keybind",
    Key = Config.SilentWalkKey,
    CallBack = function()
        Config.SilentWalkEnabled = not Config.SilentWalkEnabled
        notify("Slow Walk Toggled", "Slow Walk is now " .. (Config.SilentWalkEnabled and "ON" or "OFF"), 2)
    end
})

SettingsTab:Paragraph({
    Title = "Adaptive Framework",
    Content = "Clean modular optimization with customized Syde integrations."
})

notify("Framework Loaded", "Aimbot setup completed.", 3)

syde:LoadSaveConfig()
