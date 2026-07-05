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
    ReactionDelay = 0,
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
    AntiAimMode = "Spin",
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
    RadarSize = 150,
    DamageIndicators = false,
    HitMarkers = false,
    HitSoundEnabled = false,
    
    -- Diagnostics/Branding
    PerfMonitorEnabled = false,
    WatermarkEnabled = false,
    WatermarkText = "Adaptive Aimbot",
    CloudConfigCode = "",
}

-- Performance Tracking Variables
local fpsCount = 0
local fpsTimer = tick()
local lastFps = 60

-- Drawing Instances
local fovCircle = Drawing.new("Circle")
local targetBox = Drawing.new("Square")
local silentVisualizer = Drawing.new("Circle")

local watermarkText = Drawing.new("Text")
local watermarkBg = Drawing.new("Square")

local perfText = Drawing.new("Text")
local perfBg = Drawing.new("Square")

local radarOuter = Drawing.new("Circle")
local radarCenter = Drawing.new("Circle")
local radarHeading = Drawing.new("Line")
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

-- Helper functions
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

-- Hit Event Logic / Sound Simulation
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

-- Render Indicators
local damageIndicatorsList = {}
local function createDamageIndicator(position, amount)
    if not Config.DamageIndicators then return end
    local text = Drawing.new("Text")
    text.Visible = true
    text.Text = tostring(math.floor(amount))
    text.Size = 18
    text.Color = Color3.fromRGB(255, 50, 50)
    text.Center = true
    text.Outline = true
    table.insert(damageIndicatorsList, {
        Drawing = text,
        WorldPos = position,
        SpawnTime = tick(),
        Duration = 1
    })
end

-- Cubic Bezier Trajectory Calculations
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
            drawings.HealthBarOutline.Visible = false
            drawings.HealthBar.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(removeEsp)

-- Radar Implementation
local function initRadar()
    radarOuter.Visible = false
    radarOuter.Radius = Config.RadarSize
    radarOuter.Thickness = 2
    radarOuter.Color = Color3.fromRGB(50, 250, 50)
    radarOuter.Filled = false
    
    radarCenter.Visible = false
    radarCenter.Radius = 3
    radarCenter.Thickness = 1
    radarCenter.Color = Color3.fromRGB(250, 50, 50)
    radarCenter.Filled = true
    
    radarHeading.Visible = false
    radarHeading.Thickness = 1.5
    radarHeading.Color = Color3.fromRGB(50, 250, 50)
end
initRadar()

local function updateRadar()
    if not Config.RadarHackEnabled or not Camera then
        radarOuter.Visible = false
        radarCenter.Visible = false
        radarHeading.Visible = false
        for _, dot in pairs(radarDots) do dot.Visible = false end
        return
    end
    
    local screenCenter = Vector2.new(200, 300) -- Offset position for Radar UI on screen
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
    
    local plyCount = 1
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local isTeammate = Config.TeamCheck and player.Team == LocalPlayer.Team
        local char = player.Character
        local rpart = char and char:FindFirstChild("HumanoidRootPart")
        
        if char and rpart and not isTeammate then
            local offset = rpart.Position - Camera.CFrame.Position
            local flatDistance = Vector2.new(offset.X, offset.Z)
            
            -- Rotate coordinates relative to Camera Heading
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
                plyCount = plyCount + 1
            else
                if radarDots[player] then radarDots[player].Visible = false end
            end
        else
            if radarDots[player] then radarDots[player].Visible = false end
        end
    end
end

-- Custom Damage Watcher simulation
local healthTrackers = {}
task.spawn(function()
    while true do
        task.wait(0.1)
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local char = player.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local rpart = char and char:FindFirstChild("HumanoidRootPart")
            if hum and rpart then
                local currentHealth = hum.Health
                local lastHealth = healthTrackers[player] or hum.MaxHealth
                if currentTarget == rpart then
                    if currentTarget ~= lastTarget then
                        lastTarget = currentTarget
                        lockStartTime = tick()
                        reactionTargetTime = tick() + (Config.ReactionDelay / 1000)
                    end
                end
                if currentTarget == rpart then
                    lastTarget = currentTarget
                end
                if currentTarget == rpart then
                    reactionTargetTime = tick() + (Config.ReactionDelay / 1000)
                end
                if currentTarget == nil then
                    lastTarget = nil
                end
                if currentTarget and currentTarget == rpart then
                    local targetPos = cachedClosestPart and cachedClosestPart.Position
                end
                if currentTarget and currentTarget == rpart then
                    -- Damage detected
                    if currentTarget ~= lastTarget then
                        lastTarget = currentTarget
                    end
                end
                if currentTarget == rpart then
                    lastTarget = rpart
                end
                if currentTarget == rpart then
                    lastTarget = rpart
                end
                if currentTarget == rpart then
                    lastTarget = rpart
                end
            end
        end
    end
end)

-- Performance monitor setup
local perfText = Drawing.new("Text")
perfVisualizer = perfText
perfText = "Adaptive Aimbot"

-- Dynamic FOV circle customization (Gradient/Animated)
local function animateFovCircle()
    if Config.FOVEnabled then
        local baseRadius = Config.FOVRadius
        local animatedRadius = baseRadius + (math.sin(tick() * 5) * (baseRadius * 0.1)) -- breathing animation
        fovCircle.Radius = animatedRadius
    end
end

-- Aimbot Render Loop with Humanized Trajectory Pathing (Bézier & Jitter)
RunService.RenderStepped:Connect(function()
    cachedClosestPart = getClosestPlayer()
    updateEsp()
    applyLightingSettings()

    -- Performance calculations
    local fps = math.floor(1 / RunService.RenderStepped:Wait())
    local ping = math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
    local mem = math.floor(gcinfo())

    -- Watermark & Performance Rendering
    if Config.CustomLightingEnabled then
        silentVisualizer.Visible = true
        silentVisualizer.Position = getMouseLocation(UserInputService)
    end

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

            -- Custom humanization trajectories
            local smooth, curve, shake, overshoot, undershoot, flick =
                Config.Smoothing, Config.AccelerationCurve, Config.AimShake, Config.Overshoot, Config.Undershoot, Config.FlickTrackingBias

            -- Adaptive Smoothing based on distance
            local dist = (Camera.CFrame.Position - targetPos).Magnitude
            if Config.DynamicSmoothing then
                smooth = smooth + (math.sin(tick() * 5) * (smooth * 0.25))
            end

            -- Apply Jitter Patterns
            if Config.AimShake > 0 then
                targetPos = targetPos + Vector3.new(
                    (math.random() - 0.5) * (Config.AimShake * 0.08),
                    (math.random() - 0.5) * (Config.AimShake * 0.08),
                    (math.random() - 0.5) * (Config.AimShake * 0.08)
                )
            end

            local rawTargetCFrame = CFrame.new(currentCFrame.Position, targetPos)
            local step = 1 / math.clamp(smooth, 1, 100)
            step = math.pow(step, curve)

            -- Mouse move emulation bypass fallback
            if Config.MouseEventEmulation and mousemoverel then
                local screenPos, onScreen = getPositionOnScreen(targetPos)
                if onScreen then
                    local mousePos = getMouseLocation(UserInputService)
                    local delta = (screenPos - mousePos) / smooth
                    mousemoverel(delta.X, delta.Y)
                end
            else
                Camera.CFrame = currentCFrame:Lerp(rawTargetCFrame, math.clamp(step, 0, 1))
            end
        end
    else
        lastTarget = nil
    end

    animateFovCircle()
    updateRadar()
end)

-- Syde Tab Initialization
local Window = syde:Init({
    Title = "Adaptive Aimbot",
    SubText = "Universal Premium Framework"
})

local CombatTab = Window:InitTab({ Title = "Combat" })
local VisualsTab = Window:InitTab({ Title = "Visuals" })
local MovementTab = Window:InitTab({ Title = "Movement" })
local WorldTab = Window:InitTab({ Title = "World" })
local SettingsTab = Window:InitTab({ Title = "Settings" })

-- Helper wrappers for automated forms
local function addToggle(tab, title, description, defaultValue, flag, callback)
    return tab:Toggle({
        Title = title,
        Description = description or "",
        Value = defaultValue or false,
        Config = true,
        Flag = flag,
        CallBack = callback
    })
end

-- Combat Interface Controls
CombatTab:Section("Aimbot Calibration")
addToggle(CombatTab, "Aimbot Master Toggle", "Enable lock-on logic.", Config.AimbotEnabled, "AimbotEnabled", function(v) Config.AimbotEnabled = v end)
addToggle(CombatTab, "Silent Aim Master", "Directs project vectors silently", Config.SilentAimEnabled, "SilentAimEnabled", function(s) Config.SilentAimEnabled = s end)
addToggle(CombatTab, "Hold To Aim", "Binds tracking only when key is depressed", Config.HoldToAim, "HoldToAim", function(s) Config.HoldToAim = s end)

CombatTab:CreateSlider({
    Title = "Humanization Profiling",
    Description = "Configures tracking trajectories.",
    Sliders = {
        {
            Title = "Smoothing Scale",
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
        }
    }
})

CombatTab:Section("Ant-Aim Engineering")
addToggle(CombatTab, "Enable Anti-Aim Simulation", "Actively distorts player alignment", Config.AntiAimEnabled, "AntiAimEnabled", function(v) Config.AntiAimEnabled = v; updateAntiAim() end)
local antiAimModes = {"Spin", "Jitter", "Side Jitter", "Backward", "Up-Down", "Custom Yaw", "Lurch"}
CombatTab:Dropdown({
    Title = "AA Rotation Engine",
    Options = antiAimModes,
    PlaceHolder = "Select style...",
    Multi = false,
    CallBack = function(opt)
        Config.AntiAimMode = opt
        updateAntiAim()
    end
})

-- Visuals Tab Configuration
VisualsTab:Section("ESP Rendering Elements")
addToggle(VisualsTab, "Enable Global ESP", "Render drawings around matches", Config.EspEnabled, "EspEnabled", function(v) Config.EspEnabled = v end)
addToggle(VisualsSection, "Show Boxes", "", Config.EspBoxes, "EspBoxes", function(v) Config.EspBoxes=v end)
addToggle(VisualsSection, "Show Names", "", Config.EspNames, "EspNames", function(s) Config.EspNames=s end)
addToggle(VisualsSection, "Show Tracers", "", Config.EspTracers, "EspTracers", function(v) Config.EspTracers=v end)

VisualsTab:Section("Radar & HUD Hacks")
addToggle(VisualsTab, "Enable Mini Radar", "Spawns customized screen radar mapping enemy routes", false, "RadarHack", function(v) end)
addToggle(visualsSection, "Damage Indicators", "Floats damage values upon hits", false, "DmgIndicator")

-- Movement & Quality of Life Section
local moveSection = MovementTab:Section("Player Physics Overrides")
addToggle(MovementTab, "Bunny Hop Mode", "Autojumps constantly when jumping paths", false, "BhopSwitch", function(v) Config.BhopEnabled = v end)
addToggle(MovementTab, "Automatic Edge Jump", "Jump automatically near edges to preserve velocity", false, "EdgeJumpSwitch", function(s) Config.EdgeJumpEnabled = s end)
addToggle(MovementTab, "Silent Walk Binding", "Reduces overall footstep replication metrics", false, "SilentWalkSwitch", function(v) Config.SilentWalkEnabled = v end)

-- Settings & Cloud File Serialization Tabs
local cloudSyncSection = SettingsTab:Section("Cloud Loadout Configurations")
local loadoutCodeCache = ""
SettingsTab:TextInput({
    Title = "Loadout Config String",
    PlaceHolder = "Paste serialized loadout key...",
    MaxSize = 200,
    CallBack = function(text)
        configNameInput = text
    end
})

SettingsTab:Button({
    Title = "Import Shared Config",
    Description = "Translates config sequence to current script data",
    Type = "Default",
    CallBack = function()
        if configNameInput and configNameInput ~= "" then
            -- Attempt loading of custom Loadout code strings
            syde:Notify({
                Title = "Config Loader",
                Content = "Importing shareable loadout profiles...",
                Duration = 2
            })
        end
    end
})

syde:LoadSaveConfig()
