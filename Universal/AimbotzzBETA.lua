-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Aggressive Cleanup Hook (Destroys any cached/running Autofarm Syde UIs first)
local coregui = (gethui and gethui()) or game:GetService("CoreGui")
for _, child in ipairs(coregui:GetChildren()) do
    if child:IsA("ScreenGui") and (child.Name == "sydeUILoader" or child.Name == "Syde" or child.Name == "loader" or child:FindFirstChild("loader") or child:FindFirstChild("main")) then
        pcall(function() child:Destroy() end)
    end
end

-- Load Syde UI Framework
local syde = loadstring(game:HttpGet("https://raw.githubusercontent.com/essencejs/syde/refs/heads/main/source", true))()

-- Monkeypatch Modal to suppress internal library Frame errors
local originalModal = syde.Modal
syde.Modal = function(self, options)
    local success, err = pcall(function()
        if originalModal then
            return originalModal(self, options)
        end
    end)
    if not success then
        warn("[Safe Mode] Suppressed library modal warning: " .. tostring(err))
    end
end

-- Configuration Setup
syde:Load({
    Name = "Adaptive UI",
    Status = "Stable",
    Accent = Color3.fromRGB(54, 57, 241),
    HitBox = Color3.fromRGB(54, 57, 241),
    AutoLoad = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AdaptiveUI_Fresh",
        FileName = "settings"
    }
})

-- Global State & Options
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
    TargetIndicatorThickness = 2,
    TargetIndicatorFilled = false,
    TargetIndicatorTransparency = 1.0,
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
}

-- Global Scope Targeting State (Ensures thread synchronization) [1]
local cachedClosestPart = nil
local lastTarget = nil
local lockStartTime = 0
local reactionTargetTime = 0
local autoShootNext = 0

-- Safe Drawing Constructor (Prevents script halt if Drawing API is unsupported)
local function safeCreateDrawing(class, props)
    if not Drawing or not Drawing.new then return nil end
    local d
    local success = pcall(function()
        d = Drawing.new(class)
        if props then
            for k, v in pairs(props) do
                d[k] = v
            end
        end
    end)
    return success and d or nil
end

-- Screen Drawing Instances
local fovCircle = safeCreateDrawing("Circle")
local targetBox = safeCreateDrawing("Square")
local silentVisualizer = safeCreateDrawing("Circle")

local watermarkText = safeCreateDrawing("Text", { Size = 16, Color = Color3.fromRGB(255, 255, 255), Outline = true, Center = false })
local watermarkBg = safeCreateDrawing("Square", { Color = Color3.fromRGB(15, 15, 15), Thickness = 1, Filled = true, Transparency = 0.6 })

local perfText = safeCreateDrawing("Text", { Size = 16, Color = Color3.fromRGB(255, 255, 255), Outline = true, Center = false })
local perfBg = safeCreateDrawing("Square", { Color = Color3.fromRGB(15, 15, 15), Thickness = 1, Filled = true, Transparency = 0.6 })

local radarOuter = safeCreateDrawing("Circle", { Radius = Config.RadarSize, Thickness = 2, Color = Color3.fromRGB(50, 250, 50), Filled = false })
local radarCenter = safeCreateDrawing("Circle", { Radius = 3, Thickness = 1, Color = Color3.fromRGB(250, 50, 50), Filled = true })
local radarHeading = safeCreateDrawing("Line", { Thickness = 1.5, Color = Color3.fromRGB(50, 250, 50) })

local radarDots = {}
local statsInstance = game:GetService("Stats")

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

-- Input Emulation Click Wrapper
local function clickMouse()
    if mouse1click then
        mouse1click()
    elseif mouse1press and mouse1release then
        mouse1press()
        task.wait(0.01)
        mouse1release()
    elseif mouse1press then
        mouse1press()
    end
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
    else
        print("Shareable Loadout Code:", code)
        notify("Sync Generated", "Loadout code printed to output (Unsupported Executor).", 3)
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
    local d = safeCreateDrawing("Text")
    if not d then return end
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
    local l = safeCreateDrawing("Line")
    if l then
        l.Visible = false
        l.Color = Color3.fromRGB(255, 255, 255)
        l.Thickness = 1.5
        table.insert(hitmarkerLines, l)
    end
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

-- Clean Visibility Check (Uses standard Raycasting to prevent legacies failures)
local function isPlayerVisible(player)
    local char = player.Character
    local localChar = LocalPlayer.Character
    if not char or not localChar or not Camera then return false end
    local part = getCurrentTargetPart(player)
    if not part then return false end
    
    local origin = Camera.CFrame.Position
    local destination = part.Position
    local direction = destination - origin
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {localChar, char}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    
    local result = workspace:Raycast(origin, direction, raycastParams)
    return result == nil
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
        Box = safeCreateDrawing("Square"),
        Name = safeCreateDrawing("Text"),
        Distance = safeCreateDrawing("Text"),
        Tracer = safeCreateDrawing("Line"),
        OofIndicator = safeCreateDrawing("Triangle"),
        HealthBarOutline = safeCreateDrawing("Square"),
        HealthBar = safeCreateDrawing("Square"),
        Highlight = nil
    }
    
    if drawings.Box then
        drawings.Box.Visible = false
        drawings.Box.Thickness = 1
        drawings.Box.Color = Config.EspColor
        drawings.Box.Filled = false
    end
    
    if drawings.Name then
        drawings.Name.Visible = false
        drawings.Name.Size = Config.EspTextSize
        drawings.Name.Center = true
        drawings.Name.Outline = true
        drawings.Name.Color = Config.EspColor
    end
    
    if drawings.Distance then
        drawings.Distance.Visible = false
        drawings.Distance.Size = Config.EspTextSize
        drawings.Distance.Center = true
        drawings.Distance.Outline = true
        drawings.Distance.Color = Config.EspColor
    end

    if drawings.Tracer then
        drawings.Tracer.Visible = false
        drawings.Tracer.Thickness = 1
        drawings.Tracer.Color = Config.EspColor
    end

    if drawings.OofIndicator then
        drawings.OofIndicator.Visible = false
        drawings.OofIndicator.Filled = true
        drawings.OofIndicator.Color = Config.OofIndicatorsColor
        drawings.OofIndicator.Thickness = 1
        drawings.OofIndicator.Transparency = 1
    end

    if drawings.HealthBarOutline then
        drawings.HealthBarOutline.Visible = false
        drawings.HealthBarOutline.Thickness = 1
        drawings.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
        drawings.HealthBarOutline.Filled = true
    end

    if drawings.HealthBar then
        drawings.HealthBar.Visible = false
        drawings.HealthBar.Thickness = 1
        drawings.HealthBar.Color = Color3.fromRGB(0, 255, 0)
        drawings.HealthBar.Filled = true
    end
    
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
            if Config.OofIndicatorsEnabled and isOffscreen and drawings.OofIndicator then
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
                if drawings.OofIndicator then drawings.OofIndicator.Visible = false end
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
                    if Config.EspBoxes and drawings.Box then
                        drawings.Box.Visible = true
                        drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
                        drawings.Box.Position = Vector2.new(boxX, boxY)
                        drawings.Box.Color = Config.EspColor
                    else
                        if drawings.Box then drawings.Box.Visible = false end
                    end
                    
                    -- Name
                    if Config.EspNames and drawings.Name then
                        drawings.Name.Visible = true
                        drawings.Name.Text = player.Name
                        drawings.Name.Position = Vector2.new(topScreen.X, boxY - Config.EspTextSize - 2)
                        drawings.Name.Color = Config.EspColor
                        drawings.Name.Size = Config.EspTextSize
                    else
                        if drawings.Name then drawings.Name.Visible = false end
                    end
                    
                    -- Distance
                    if Config.EspDistances and drawings.Distance then
                        drawings.Distance.Visible = true
                        local dist = math.floor((Camera.CFrame.Position - rpartPos).Magnitude)
                        drawings.Distance.Text = ("[%d studs]"):format(dist)
                        drawings.Distance.Position = Vector2.new(topScreen.X, boxY + boxHeight + 2)
                        drawings.Distance.Color = Config.EspColor
                        drawings.Distance.Size = Config.EspTextSize
                    else
                        if drawings.Distance then drawings.Distance.Visible = false end
                    end

                    -- Tracers / Snaplines
                    if Config.EspTracers and drawings.Tracer then
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
                        if drawings.Tracer then drawings.Tracer.Visible = false end
                    end
                    
                    -- Health Bar
                    if Config.EspHealth and drawings.HealthBarOutline and drawings.HealthBar then
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
                        if drawings.HealthBarOutline then drawings.HealthBarOutline.Visible = false end
                        if drawings.HealthBar then drawings.HealthBar.Visible = false end
                    end
                else
                    if drawings.Box then drawings.Box.Visible = false end
                    if drawings.Name then drawings.Name.Visible = false end
                    if drawings.Distance then drawings.Distance.Visible = false end
                    if drawings.Tracer then drawings.Tracer.Visible = false end
                    if drawings.HealthBarOutline then drawings.HealthBarOutline.Visible = false end
                    if drawings.HealthBar then drawings.HealthBar.Visible = false end
                end
            else
                if drawings.Box then drawings.Box.Visible = false end
                if drawings.Name then drawings.Name.Visible = false end
                if drawings.Distance then drawings.Distance.Visible = false end
                if drawings.Tracer then drawings.Tracer.Visible = false end
                if drawings.HealthBarOutline then drawings.HealthBarOutline.Visible = false end
                if drawings.HealthBar then drawings.HealthBar.Visible = false end
            end
        else
            if drawings.Box then drawings.Box.Visible = false end
            if drawings.Name then drawings.Name.Visible = false end
            if drawings.Distance then drawings.Distance.Visible = false end
            if drawings.Tracer then drawings.Tracer.Visible = false end
            if drawings.OofIndicator then drawings.OofIndicator.Visible = false end
            if drawings.HealthBarOutline then drawings.HealthBarOutline.Visible = false end
            if drawings.HealthBar then drawings.HealthBar.Visible = false end
        end
    end
end

Players.PlayerRemoving:Connect(removeEsp)

-- Radar update
local function updateRadar()
    if not Config.RadarHackEnabled or not Camera or not radarOuter then
        if radarOuter then radarOuter.Visible = false end
        if radarCenter then radarCenter.Visible = false end
        if radarHeading then radarHeading.Visible = false end
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
                    dot = safeCreateDrawing("Circle")
                    if dot then
                        dot.Radius = 4
                        dot.Filled = true
                        dot.Color = Color3.fromRGB(250, 50, 50)
                        radarDots[player] = dot
                    end
                end
                if dot then
                    dot.Visible = true
                    dot.Position = screenCenter + localOffset
                end
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
task.spawn(function()
    while true do
        task.wait()
        if Config.AutoShootEnabled and cachedClosestPart and isAimingHeld() then
            local now = tick() * 1000
            if now >= autoShootNext then
                if Config.LegitMode then
                    clickMouse()
                    autoShootNext = now + Config.AutoShootDelay
                else
                    clickMouse()
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
                clickMouse()
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

-- Improved AutoWallbang: count walls and thickness
local function getWallPenetrationIgnoreList(origin, targetPos, maxWalls)
    local rayDir = (targetPos - origin).Unit
    local ignoreList = {LocalPlayer.Character}
    local rayOrigin = origin
    local walls = {}

    while true do
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = ignoreList
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local result = workspace:Raycast(rayOrigin, rayDir * 1000, rayParams)
        if not result then break end
        local part = result.Instance
        -- If we hit the target
        if part:IsDescendantOf(cachedClosestPart and cachedClosestPart.Parent) then
            return ignoreList -- success, can shoot through walls collected
        end
        -- It's a wall
        table.insert(walls, part)
        if #walls > maxWalls then return nil end
        -- Compute wall thickness
        local backResult = workspace:Raycast(result.Position + rayDir * part.Size.Magnitude, -rayDir * part.Size.Magnitude, rayParams)
        if backResult and backResult.Instance == part then
            local thickness = (backResult.Position - result.Position).Magnitude
            if thickness > Config.MaxWallThickness then return nil end
        end
        table.insert(ignoreList, part)
        rayOrigin = result.Position + rayDir * 0.01
    end
    return nil
end

-- Silent Aim Hooks (Restored completely from reference codebase)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local method = getnamecallmethod()
    local args = {...}
    local self = args[1]

    if Config.SilentAimEnabled and self == workspace and not checkcaller() and calculateChance(Config.HitChance) then
        local hitPart = cachedClosestPart
        if hitPart then
            local targetPos = hitPart.Position
            if Config.Prediction and hitPart.Velocity then
                targetPos = targetPos + hitPart.Velocity * Config.PredictionAmount
            end

            -- AutoWallbang
            if Config.AutoWallbangEnabled and (method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" or method == "FindPartOnRay" or method == "findPartOnRay") then
                local ray = args[2]
                local origin = ray.Origin
                local dir = (targetPos - origin).Unit * 1000
                args[2] = Ray.new(origin, dir)

                -- Attempt to penetrate walls
                local ignoreList = getWallPenetrationIgnoreList(origin, targetPos, Config.MaxWalls)
                if ignoreList then
                    -- Override ignore list
                    local existingIgnore = args[3] or {}
                    for _, obj in ipairs(ignoreList) do
                        if not table.find(existingIgnore, obj) then
                            table.insert(existingIgnore, obj)
                        end
                    end
                    args[3] = existingIgnore
                    return oldNamecall(unpack(args))
                else
                    -- Too many walls, don't allow shot
                    return nil
                end
            end

            -- Normal silent aim redirect
            if method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" or method == "FindPartOnRay" or method == "findPartOnRay" then
                local ray = args[2]
                local origin = ray.Origin
                local dir = (targetPos - origin).Unit * 1000
                args[2] = Ray.new(origin, dir)
                return oldNamecall(unpack(args))
            elseif method == "Raycast" then
                local origin = args[2]
                local dir = (targetPos - origin).Unit * 1000
                args[3] = dir
                return oldNamecall(unpack(args))
            end
        end
    end

    return oldNamecall(...)
end))

local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, index)
    if self == Mouse and not checkcaller() and Config.SilentAimEnabled and Config.Method == "Mouse.Hit/Target" and calculateChance(Config.HitChance) then
        local hitPart = cachedClosestPart
        if hitPart then
            if index == "Target" or index == "target" then
                return hitPart
            elseif index == "Hit" or index == "hit" then
                if Config.Prediction and hitPart.Velocity then
                    return hitPart.CFrame + hitPart.Velocity * Config.PredictionAmount
                else
                    return hitPart.CFrame
                end
            elseif index == "UnitRay" then
                return Ray.new(self.Origin, (self.Hit - self.Origin).Unit)
            end
        end
    end
    return oldIndex(self, index)
end))

-- Dynamic Rendering & Humanized Core Lerping Loops
RunService.RenderStepped:Connect(function()
    cachedClosestPart = getClosestPlayer()
    updateEsp()
    applyLightingSettings()
    
    -- Delta Time Frame Metering (Non-blocking calculation)
    local now = tick()
    local dt = now - lastFpsTime
    lastFpsTime = now
    local fps = dt > 0 and math.floor(1 / dt) or 0
    local ping = math.floor(statsInstance.Network.ServerStatsItem["Data Ping"]:GetValue())
    local mem = math.floor(gcinfo())

    -- Watermark & Performance Rendering
    if Config.WatermarkEnabled and watermarkText and watermarkBg then
        watermarkText.Text = " " .. Config.WatermarkText .. " | Live "
        watermarkText.Position = Vector2.new(15, 20)
        watermarkText.Visible = true
        watermarkBg.Position = Vector2.new(10, 15)
        watermarkBg.Size = Vector2.new(watermarkText.TextBounds.X + 10, watermarkText.TextBounds.Y + 10)
        watermarkBg.Visible = true
    else
        if watermarkText then watermarkText.Visible = false end
        if watermarkBg then watermarkBg.Visible = false end
    end

    if Config.PerfMonitorEnabled and perfText and perfBg then
        perfText.Text = string.format(" FPS: %d | Ping: %dms | Mem: %dMB", fps, ping, mem)
        perfText.Position = Vector2.new(15, 60)
        perfText.Visible = true
        perfBg.Position = Vector2.new(10, 55)
        perfBg.Size = Vector2.new(perfText.TextBounds.X + 10, perfText.TextBounds.Y + 10)
        perfBg.Visible = true
    else
        if perfText then perfText.Visible = false end
        if perfBg then perfBg.Visible = false end
    end

    -- Hitmarker crosshair lines updater
    if Config.HitMarkers and tick() < hitmarkerTime then
        local center = getMouseLocation(UserInputService)
        local gap = 4
        local len = 8
        
        if hitmarkerLines[1] then
            hitmarkerLines[1].From = center - Vector2.new(gap, gap)
            hitmarkerLines[1].To = center - Vector2.new(gap + len, gap + len)
            hitmarkerLines[1].Visible = true
        end
        
        if hitmarkerLines[2] then
            hitmarkerLines[2].From = center + Vector2.new(gap, -gap)
            hitmarkerLines[2].To = center + Vector2.new(gap + len, -(gap + len))
            hitmarkerLines[2].Visible = true
        end
        
        if hitmarkerLines[3] then
            hitmarkerLines[3].From = center + Vector2.new(-gap, gap)
            hitmarkerLines[3].To = center + Vector2.new(-(gap + len), gap + len)
            hitmarkerLines[3].Visible = true
        end
        
        if hitmarkerLines[4] then
            hitmarkerLines[4].From = center + Vector2.new(gap, gap)
            hitmarkerLines[4].To = center + Vector2.new(gap + len, gap + len)
            hitmarkerLines[4].Visible = true
        end
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

    -- Aimbot Core Engine (Restored exact mathematical equations from reference Cascade script)
    if Config.AimbotEnabled and cachedClosestPart and isAimingHeld() and Camera then
        if cachedClosestPart ~= lastTarget then
            lastTarget = cachedClosestPart
            lockStartTime = tick()
        end
        local timeElapsed = tick() - lockStartTime
        local targetPos = cachedClosestPart.Position
        if Config.Prediction and cachedClosestPart.Velocity then
            targetPos = targetPos + cachedClosestPart.Velocity * Config.PredictionAmount
        end
        local currentCFrame = Camera.CFrame

        -- Humanization parameters
        local smooth, curve, shake, overshoot, undershoot, flick =
            Config.Smoothing, Config.AccelerationCurve, Config.AimShake, Config.Overshoot, Config.Undershoot, Config.FlickTrackingBias
        if Config.HumanizationMode == "Copied" then
            shake = Profile.JitterScale * 8.5
            smooth = math.clamp(Config.Smoothing * (1 / math.max(Profile.AverageSpeed / 10, 0.5)), 1, 100)
            overshoot, undershoot, curve, flick = 0, 0, 1.0, 0.5
        end

        -- Apply jitter
        if Config.HumanizationMode ~= "Custom" or Config.AimShake > 0 then
            local jitterScale = (Config.HumanizationMode == "Copied") and shake or Config.AimShake * 0.08
            targetPos = targetPos + Vector3.new(
                (math.random() - 0.5) * jitterScale,
                (math.random() - 0.5) * jitterScale,
                (math.random() - 0.5) * jitterScale
            )
        end

        -- Safe mouse emulation bypass option
        if Config.MouseEventEmulation and mousemoverel then
            local screenPos, onScreen = getPositionOnScreen(targetPos)
            if onScreen then
                local mousePos = getMouseLocation(UserInputService)
                local delta = (screenPos - mousePos) / smooth
                mousemoverel(delta.X, delta.Y)
            end
        else
            local rawTargetCFrame = CFrame.new(currentCFrame.Position, targetPos)

            if overshoot > 0 and timeElapsed < 0.25 then
                local angleFactor = 1 + (overshoot / 100) * math.exp(-timeElapsed * 10)
                local rawAngles = {rawTargetCFrame:ToEulerAnglesYXZ()}
                local curAngles = {currentCFrame:ToEulerAnglesYXZ()}
                rawTargetCFrame = CFrame.fromEulerAnglesYXZ(
                    curAngles[1] + (rawAngles[1] - curAngles[1]) * angleFactor,
                    curAngles[2] + (rawAngles[2] - curAngles[2]) * angleFactor,
                    0
                )
            end

            local smoothingMultiplier = 1
            if undershoot > 0 and timeElapsed > 0.1 then
                smoothingMultiplier = 1 + (undershoot / 50)
            end

            local baseSmooth = math.clamp(smooth * smoothingMultiplier, 1, 100)
            
            -- Dynamic Smoothing calculations
            if Config.DynamicSmoothing then
                baseSmooth = baseSmooth + (math.sin(tick() * 5) * (baseSmooth * 0.25))
            end

            local step = 1 / baseSmooth
            step = math.pow(step, curve)

            if flick > 0.5 then
                if timeElapsed < 0.15 then step = math.clamp(step * (flick * 2), 0, 1) end
            else
                if timeElapsed < 0.2 then step = step * (flick + 0.5) end
            end

            -- Optional Bezier Path interpolator
            if Config.BezierPathing then
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
    if Config.FOVEnabled and fovCircle then
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
        if fovCircle then fovCircle.Visible = false end
    end

    -- Target indicator [2]
    if Config.ShowTargetIndicator and cachedClosestPart and targetBox then
        local pos, onScreen = getPositionOnScreen(cachedClosestPart.Position)
        if onScreen then
            targetBox.Visible = true
            targetBox.Position = pos - Vector2.new(Config.TargetIndicatorSize / 2, Config.TargetIndicatorSize / 2)
            targetBox.Color = Config.TargetIndicatorColor
            targetBox.Size = Vector2.new(Config.TargetIndicatorSize, Config.TargetIndicatorSize)
            targetBox.Thickness = Config.TargetIndicatorThickness
            targetBox.Filled = Config.TargetIndicatorFilled
            targetBox.Transparency = Config.TargetIndicatorTransparency
        else
            targetBox.Visible = false
        end
    else
        if targetBox then targetBox.Visible = false end
    end

    -- Silent Aim target visualizer
    if Config.SilentVisualizerEnabled and Config.SilentAimEnabled and cachedClosestPart and silentVisualizer then
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
        if silentVisualizer then silentVisualizer.Visible = false end
    end

    updateRadar()
end)

-- Safe UI API Wrappers to dynamically adjust across Syde updates & Warn UI Errors
local function addToggle(tab, title, description, defaultValue, flag, callback)
    if not tab then return nil end
    local method = tab.Toggle or tab.AddToggle or tab.CreateToggle
    if not method then 
        warn("[Syde UI error] " .. tostring(title) .. ": Toggle method not found")
        return nil 
    end
    local success, result = pcall(function()
        return method(tab, {
            Title = title,
            Description = description or "",
            Value = defaultValue or false,
            Config = true,
            Flag = flag,
            CallBack = callback
        })
    end)
    if not success then
        warn("[Syde UI error] " .. tostring(title) .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function addSliders(tab, title, description, slidersData)
    if not tab then return nil end
    local method = tab.CreateSlider or tab.Slider or tab.AddSlider or tab.SliderGroup or tab.CreateSliders
    if not method then 
        warn("[Syde UI error] " .. tostring(title) .. ": Slider method not found")
        return nil 
    end
    local success, result = pcall(function()
        return method(tab, {
            Title = title,
            Description = description or "",
            Sliders = slidersData
        })
    end)
    
    if success then return result end
    
    -- Fallback: If CreateSlider failed (e.g. singular Slider API), add them individually
    for _, s in ipairs(slidersData) do
        local singleMethod = tab.Slider or tab.AddSlider or tab.CreateSlider
        if singleMethod then
            pcall(function()
                singleMethod(tab, {
                    Title = s.Title,
                    Description = description or "",
                    Range = s.Range,
                    Increment = s.Increment,
                    StarterValue = s.StarterValue,
                    Flag = s.Flag,
                    CallBack = s.CallBack
                })
            end)
        end
    end
    return nil
end

local function addDropdown(tab, title, options, placeholder, multi, callback)
    if not tab then return nil end
    local method = tab.Dropdown or tab.AddDropdown or tab.CreateDropdown
    if not method then 
        warn("[Syde UI error] " .. tostring(title) .. ": Dropdown method not found")
        return nil 
    end
    local success, result = pcall(function()
        return method(tab, {
            Title = title,
            Options = options,
            PlaceHolder = placeholder or "Select...",
            Multi = multi or false,
            CallBack = callback
        })
    end)
    if not success then
        warn("[Syde UI error] " .. tostring(title) .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function addColorPicker(tab, title, description, defaultColor, flag, callback)
    if not tab then return nil end
    local method = tab.ColorPicker or tab.AddColorPicker or tab.CreateColorPicker
    if not method then 
        warn("[Syde UI error] " .. tostring(title) .. ": ColorPicker method not found")
        return nil 
    end
    local success, result = pcall(function()
        return method(tab, {
            Title = title,
            Description = description or "",
            Linkable = false,
            Color = defaultColor,
            Flag = flag,
            CallBack = callback
        })
    end)
    if not success then
        warn("[Syde UI error] " .. tostring(title) .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function addTextInput(tab, title, placeholder, maxSize, callback)
    if not tab then return nil end
    local method = tab.TextInput or tab.AddTextInput or tab.CreateTextInput or tab.Input
    if not method then 
        warn("[Syde UI error] " .. tostring(title) .. ": TextInput method not found")
        return nil 
    end
    local success, result = pcall(function()
        return method(tab, {
            Title = title,
            PlaceHolder = placeholder or "Type here...",
            MaxSize = maxSize or 100,
            CallBack = callback
        })
    end)
    if not success then
        warn("[Syde UI error] " .. tostring(title) .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function addButton(tab, title, description, callback)
    if not tab then return nil end
    local method = tab.Button or tab.AddButton or tab.CreateButton
    if not method then 
        warn("[Syde UI error] " .. tostring(title) .. ": Button method not found")
        return nil 
    end
    local success, result = pcall(function()
        return method(tab, {
            Title = title,
            Description = description or "",
            Type = "Default",
            CallBack = callback
        })
    end)
    if not success then
        warn("[Syde UI error] " .. tostring(title) .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function addKeybind(tab, title, key, callback)
    if not tab then return nil end
    local method = tab.Keybind or tab.AddKeybind or tab.CreateKeybind
    if not method then 
        warn("[Syde UI error] " .. tostring(title) .. ": Keybind method not found")
        return nil 
    end
    local success, result = pcall(function()
        return method(tab, {
            Title = title,
            Key = key,
            CallBack = callback
        })
    end)
    if not success then
        warn("[Syde UI error] " .. tostring(title) .. ": " .. tostring(result))
        return nil
    end
    return result
end

local function addSection(tab, title, icon)
    if not tab then return nil end
    local method = tab.Section or tab.AddSection or tab.CreateSection
    if not method then 
        warn("[Syde UI error] " .. tostring(title) .. ": Section method not found")
        return nil 
    end
    local success, result = pcall(function()
        return method(tab, title, icon)
    end)
    if not success then
        warn("[Syde UI error] " .. tostring(title) .. ": " .. tostring(result))
        return nil
    end
    return result
end

-- Main Syde Interface Initialization
local Window = syde:Init({
    Title = "Adaptive UI",
    SubText = "Universal Premium UI Framework"
})
assert(Window, "Syde failed to initialize Window")

local function requireTab(tab, name)
    assert(tab, "Syde failed to create tab: " .. name)
    return tab
end

-- Table-based Tab Initialization
local CombatTab = requireTab(Window:InitTab({ Title = "Combat" }), "Combat")
local VisualsTab = requireTab(Window:InitTab({ Title = "Visuals" }), "Visuals")
local MovementTab = requireTab(Window:InitTab({ Title = "Movement" }), "Movement")
local WorldTab = requireTab(Window:InitTab({ Title = "World" }), "World")
local SettingsTab = requireTab(Window:InitTab({ Title = "Settings" }), "Settings")

-- ==========================================
-- COMBAT TAB
-- ==========================================
addSection(CombatTab, "Combat Framework Switch")
addToggle(CombatTab, "Aimbot Enabled", "Activate master lock-on mechanics.", Config.AimbotEnabled, "AimbotEnabled", function(v) Config.AimbotEnabled = v end)
addToggle(CombatTab, "Silent Aim Enabled", "Redirects server-side shoot vectors natively.", Config.SilentAimEnabled, "SilentAimEnabled", function(v) Config.SilentAimEnabled = v end)
addToggle(CombatTab, "Hold To Aim", "Require manual tracking keys to be pressed.", Config.HoldToAim, "HoldToAim", function(v) Config.HoldToAim = v end)

-- Target filtering options (Teamcheck and Visible check toggles) [1]
addSection(CombatTab, "Target Checks & Filters")
addToggle(CombatTab, "Team Check", "Bypasses teammates during targeting scans.", Config.TeamCheck, "TeamCheck", function(v) Config.TeamCheck = v end)
addToggle(CombatTab, "Visible Check", "Only lock on players who are fully visible.", Config.VisibleCheck, "VisibleCheck", function(v) Config.VisibleCheck = v end)

addSection(CombatTab, "Fine-Tuning & Prediction")
addToggle(CombatTab, "Target Velocity Prediction", "Calibrates distance/velocity trajectories.", Config.Prediction, "Prediction", function(v) Config.Prediction = v end)

addSliders(CombatTab, "Precision Parameters", "Configures smoothing speeds and reaction delays.", {
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
})

addSection(CombatTab, "Aim Humanization Mechanics")
addToggle(CombatTab, "Dynamic Smoothing", "Adds randomized smoothing scales over time.", Config.DynamicSmoothing, "DynamicSmoothing", function(v) Config.DynamicSmoothing = v end)
addToggle(CombatTab, "Adaptive Smoothing", "Scales smoothing dynamically based on target distance.", Config.AdaptiveSmoothing, "AdaptiveSmoothing", function(v) Config.AdaptiveSmoothing = v end)
addToggle(CombatTab, "Bézier Path Curve Generation", "Utilizes Cubic Bézier curves for realistic hand trajectories.", Config.BezierPathing, "BezierPathing", function(v) Config.BezierPathing = v end)
addToggle(CombatTab, "Micro Cursor Jitter", "Injects microscopic hand vibrations into movement paths.", Config.CursorJitter, "CursorJitter", function(v) Config.CursorJitter = v end)

addSliders(CombatTab, "Human Jitter Tuning", "Modifies simulated human micro-adjustment tremors.", {
    {
        Title = "Jitter Intensity",
        Range = {1, 10},
        Increment = 1,
        StarterValue = Config.JitterIntensity,
        Flag = "JitterIntensity",
        CallBack = function(v) Config.JitterIntensity = v end
    }
})

addToggle(CombatTab, "Mouse Input Emulation Bypass", "Translates aim movement via mousemoverel virtual frames.", Config.MouseEventEmulation, "MouseEventEmulation", function(v) Config.MouseEventEmulation = v end)

addSection(CombatTab, "Autoshoot & Wallbang Calibration")
addToggle(CombatTab, "Autoshoot Enabled", "Triggers weapons automatically when targets lock.", Config.AutoShootEnabled, "AutoShootEnabled", function(v) Config.AutoShootEnabled = v end)
addToggle(CombatTab, "Autowallbang Enabled", "Penetrates solid map parts towards player joints.", Config.AutoWallbangEnabled, "AutoWallbangEnabled", function(v) Config.AutoWallbangEnabled = v end)
addToggle(CombatTab, "Rage Mode Legit Bypass Off", "Bypasses all thickness checks for instant wall-piercing.", not Config.LegitMode, "RageModeBypass", function(v) Config.LegitMode = not v end)

addSection(CombatTab, "Triggerbot Settings")
addToggle(CombatTab, "Triggerbot Enabled", "Shoot automatically when your cursor crosses an enemy.", Config.TriggerbotEnabled, "TriggerbotEnabled", function(v) Config.TriggerbotEnabled = v end)
addDropdown(CombatTab, "Triggerbot Evaluation Mode", {"Crosshair", "Aimbot Lock"}, "Select type...", false, function(opt) Config.TriggerbotMode = opt end)

addSection(CombatTab, "Anti-Aim Overrides")
addToggle(CombatTab, "Enable Anti-Aim", "Actively distorts player alignment coordinates.", Config.AntiAimEnabled, "AntiAimEnabled", function(v) Config.AntiAimEnabled = v; updateAntiAim() end)
addDropdown(CombatTab, "AA Movement Profile", {"Spin", "Jitter", "Side Jitter", "Backward", "Up-Down", "Custom Yaw", "Lurch"}, "Select style...", false, function(opt) Config.AntiAimMode = opt; updateAntiAim() end)

addSliders(CombatTab, "AA Rotation Speeds", "Manages yaw customization limits.", {
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
})

-- ==========================================
-- VISUALS TAB
-- ==========================================
addSection(VisualsTab, "ESP Rendering Elements")
addToggle(VisualsTab, "Master ESP Toggle", "Render drawing frames around other active entities.", Config.EspEnabled, "EspEnabled", function(v) Config.EspEnabled = v end)
addToggle(VisualsTab, "Box Frames", "Render bounding boxes around players.", Config.EspBoxes, "EspBoxes", function(v) Config.EspBoxes = v end)
addToggle(VisualsTab, "Entity Names", "Display player nicknames.", Config.EspNames, "EspNames", function(v) Config.EspNames = v end)
addToggle(VisualsTab, "Distance Meters", "Display distance in studs.", Config.EspDistances, "EspDistances", function(v) Config.EspDistances = v end)
addToggle(VisualsTab, "Health Indicators", "Display active HP levels.", Config.EspHealth, "EspHealth", function(v) Config.EspHealth = v end)
addToggle(VisualsTab, "Snaplines / Tracers", "Draw lines from screen center or bottom.", Config.EspTracers, "EspTracers", function(v) Config.EspTracers = v end)
addDropdown(VisualsTab, "Snaplines Origin Coordinate", {"Bottom", "Center", "Mouse"}, "Select origin...", false, function(opt) Config.EspTracerOrigin = opt end)

addSection(VisualsTab, "Off-Screen Indicators")
addToggle(VisualsTab, "Out of View (OOF) Pointers", "Draws directional screen triangles towards offscreen players.", Config.OofIndicatorsEnabled, "OofIndicatorsEnabled", function(v) Config.OofIndicatorsEnabled = v end)
addSliders(VisualsTab, "OOF Indicator Tuning", "Fine-tune sizes and boundaries of OOF triangles.", {
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
})

addSection(VisualsTab, "Chams Framework")
addToggle(VisualsTab, "Chams Enabled", "Fills character textures with standard solid colors.", Config.ChamsEnabled, "ChamsEnabled", function(v) Config.ChamsEnabled = v end)
addToggle(VisualsTab, "Render Through Walls (Depth Mode Always)", "Always on top of world geometry.", Config.ChamsAlwaysOnTop, "ChamsAlwaysOnTop", function(v) Config.ChamsAlwaysOnTop = v end)
addSliders(VisualsTab, "Chams Transparencies", "Custom opacity configurations.", {
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
})

addSection(VisualsTab, "ESP Colors")
addColorPicker(VisualsTab, "Primary ESP Colors", "Default ESP text and box outlines.", Config.EspColor, "EspColorFlag", function(c) Config.EspColor = c end)
addColorPicker(VisualsTab, "Chams Inner Color", "Fill color of visible geometry.", Config.ChamsFillColor, "ChamsFillColorFlag", function(c) Config.ChamsFillColor = c end)
addColorPicker(VisualsTab, "Chams Border Outline Color", "Color of exterior borders.", Config.ChamsOutlineColor, "ChamsOutlineColorFlag", function(c) Config.ChamsOutlineColor = c end)
addColorPicker(VisualsTab, "OOF Indicator Color", "Color of screen pointer triangles.", Config.OofIndicatorsColor, "OofIndicatorsColorFlag", function(c) Config.OofIndicatorsColor = c end)

addSection(VisualsTab, "Screen Overlays")
addToggle(VisualsTab, "Enable FOV Circle Overlay", "Render interactive FOV guidelines.", Config.FOVEnabled, "FOVEnabled", function(v) Config.FOVEnabled = v end)
addToggle(VisualsTab, "Animated FOV Circle (Breathing Effect)", "Smoothly scale circle radius using sin wave functions.", Config.FovAnimated, "FovAnimated", function(v) Config.FovAnimated = v end)
addSliders(VisualsTab, "FOV Parameters", "Modify boundary range limits.", {
    {
        Title = "FOV Boundary Limit (Radius)",
        Range = {10, 800},
        Increment = 5,
        StarterValue = Config.FOVRadius,
        Flag = "FOVRadius",
        CallBack = function(v) Config.FOVRadius = v end
    }
})
addColorPicker(VisualsTab, "FOV Outline Color", "Change boundary color shade.", Config.FOVColor, "FOVColorFlag", function(c) Config.FOVColor = c end)

-- Customization of target and silent trackers (Target Indicator Box customizations) [2]
addSection(VisualsTab, "Target & Silent Trackers")
addToggle(VisualsTab, "Show Selected Target Indicator Box", "Highlights tracked enemy visually.", Config.ShowTargetIndicator, "ShowTargetIndicator", function(v) Config.ShowTargetIndicator = v end)
addToggle(VisualsTab, "Target Indicator Filled", "Apply solid color shading into target indicator bounds.", Config.TargetIndicatorFilled, "TargetIndicatorFilled", function(v) Config.TargetIndicatorFilled = v end)
addSliders(VisualsTab, "Target Indicator Design Limits", "Customizations for target indicators.", {
    {
        Title = "Indicator Box Size",
        Range = {5, 100},
        Increment = 1,
        StarterValue = Config.TargetIndicatorSize,
        Flag = "TargetIndicatorSize",
        CallBack = function(v) Config.TargetIndicatorSize = v end
    },
    {
        Title = "Indicator Outline Thickness",
        Range = {1, 10},
        Increment = 1,
        StarterValue = Config.TargetIndicatorThickness,
        Flag = "TargetIndicatorThickness",
        CallBack = function(v) Config.TargetIndicatorThickness = v end
    },
    {
        Title = "Indicator Transparency (%)",
        Range = {0, 100},
        Increment = 5,
        StarterValue = math.floor(Config.TargetIndicatorTransparency * 100),
        Flag = "TargetIndicatorTransparency",
        CallBack = function(v) Config.TargetIndicatorTransparency = v / 100 end
    }
})
addColorPicker(VisualsTab, "Target Indicator Box Color", "Visual target box outline color shade.", Config.TargetIndicatorColor, "TargetIndicatorColorFlag", function(c) Config.TargetIndicatorColor = c end)

addToggle(VisualsTab, "Show Silent Aim Tracking Point Dot", "Pointers where silent bullets are heading.", Config.SilentVisualizerEnabled, "SilentVisualizerEnabled", function(v) Config.SilentVisualizerEnabled = v end)

addSection(VisualsTab, "Minimap Radar Hack")
addToggle(VisualsTab, "Enable Screen Minimap Radar", "Spawns customized screen radar mapping enemy routes.", Config.RadarHackEnabled, "RadarHackEnabled", function(v) Config.RadarHackEnabled = v end)
addSliders(VisualsTab, "Radar Controls", "Adjust radar size and visual scale.", {
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
})

addSection(VisualsTab, "Feedback Overlays")
addToggle(VisualsTab, "Floating Damage Indicators", "Floats calculated deal-damage numbers in real-time.", Config.DamageIndicators, "DamageIndicators", function(v) Config.DamageIndicators = v end)
addToggle(VisualsTab, "Enable Hitmarkers", "Renders diagonal crosshair lines upon hits.", Config.HitMarkers, "HitMarkers", function(v) Config.HitMarkers = v end)
addToggle(VisualsTab, "Play Hitmarker Sound", "Play classical FPS hit crunches.", Config.HitSoundEnabled, "HitSoundEnabled", function(v) Config.HitSoundEnabled = v end)

VisualsTab:Paragraph({
    Title = "UI Test",
    Content = "If this appears, tabs are working."
})

-- ==========================================
-- MOVEMENT TAB
-- ==========================================
addSection(MovementTab, "Player Physics Overrides")
addToggle(MovementTab, "Bunny Hop Simulation", "Automatically triggers jump sequences when holding space.", Config.BhopEnabled, "BhopEnabled", function(v) Config.BhopEnabled = v end)
addToggle(MovementTab, "Automatic Edge Jump / Ledge Grab", "Jump automatically when approaching solid edge boundaries.", Config.EdgeJumpEnabled, "EdgeJumpEnabled", function(v) Config.EdgeJumpEnabled = v end)

addSection(MovementTab, "Movement Slow Walk")
addToggle(MovementTab, "Silent Walk (Slow Walk)", "Clamps maximum speeds when walking keys are depressed.", Config.SilentWalkEnabled, "SilentWalkEnabled", function(v) Config.SilentWalkEnabled = v end)
addSliders(MovementTab, "Slow Walk Velocity Modifier", "Fine-tune velocity clamps.", {
    {
        Title = "Walk Velocity Clamping Speed",
        Range = {1, 16},
        Increment = 1,
        StarterValue = Config.SilentWalkSpeed,
        Flag = "SilentWalkSpeed",
        CallBack = function(v) Config.SilentWalkSpeed = v end
    }
})

addSection(MovementTab, "Anti-AFK & Latency Spoofing")
addToggle(MovementTab, "Anti-AFK Bypass", "Simulates tiny movement loops when idle timers activate.", Config.AntiAfkEnabled, "AntiAfkEnabled", function(v) Config.AntiAfkEnabled = v end)
addToggle(MovementTab, "Fake Lag Spike (Packet Distorter)", "Spikes physical latency parameters to obtain peek advantages.", Config.FakeLagEnabled, "FakeLagEnabled", function(v) Config.FakeLagEnabled = v end)
addSliders(MovementTab, "Fake Lag Modifiers", "Modify rate and size of lag spikes.", {
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
})

-- ==========================================
-- WORLD TAB
-- ==========================================
addSection(WorldTab, "Environmental Fog Modifications")
addToggle(WorldTab, "Custom Fog Overrides", "Enable custom client-side atmosphere settings.", Config.FogEnabled, "FogEnabled", function(v) Config.FogEnabled = v; applyLightingSettings() end)
addSliders(WorldTab, "Atmospheric Fog Modifiers", "Fine-tune fog distances.", {
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
})
addColorPicker(WorldTab, "Fog Density Color", "Color of environmental fog.", Config.FogColor, "FogColorFlag", function(c) Config.FogColor = c; applyLightingSettings() end)

addSection(WorldTab, "Time Cycle Locking")
addToggle(WorldTab, "Custom Ambient Lighting Enabled", "Forces custom lighting parameters directly into client memory.", Config.CustomLightingEnabled, "CustomLightingEnabled", function(v) Config.CustomLightingEnabled = v; applyLightingSettings() end)
addSliders(WorldTab, "Daylight Adjusters", "Adjust brightness and times.", {
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
})
addColorPicker(WorldTab, "Custom Ambient Shadow Shade", "Ambient shadow shading.", Config.AmbientColor, "AmbientColorFlag", function(c) Config.AmbientColor = c; applyLightingSettings() end)
addColorPicker(WorldTab, "Custom Outdoor Ambient Color", "Atmosphere surrounding light.", Config.OutdoorAmbientColor, "OutdoorAmbientColorFlag", function(c) Config.OutdoorAmbientColor = c; applyLightingSettings() end)

-- ==========================================
-- SETTINGS TAB
-- ==========================================
addSection(SettingsTab, "Local UI Styling Customizer")
addDropdown(SettingsTab, "Accent Theme Color Selector", {"Blue", "Purple", "Pink", "Red", "Orange", "Yellow", "Green", "Graphite"}, "Select color theme...", false, function(opt)
    if syde.Accents and syde.Accents[opt] then
        syde.Accent = syde.Accents[opt]
    end
end)

addSection(SettingsTab, "Telemetry Monitor Widgets")
addToggle(SettingsTab, "Custom Watermark Overlay", "Show script watermark overlay.", Config.WatermarkEnabled, "WatermarkEnabled", function(v) Config.WatermarkEnabled = v end)
addTextInput(SettingsTab, "Watermark Text Label", "Adaptive Aimbot...", 50, function(text) Config.WatermarkText = text end)
addToggle(SettingsTab, "Diagnostics / FPS & Ping Monitor", "Displays detailed FPS, ping, and memory monitors.", Config.PerfMonitorEnabled, "PerfMonitorEnabled", function(v) Config.PerfMonitorEnabled = v end)

addSection(SettingsTab, "Loadout Cloud Config Sharing")
addTextInput(SettingsTab, "Config Serializer Loadout Code", "Paste shared code string here...", 300, function(text) Config.CloudConfigCode = text end)
addButton(SettingsTab, "Import Shared Config Code", "Applies loaded settings instantly to current profile parameters.", function()
    if Config.CloudConfigCode ~= "" then
        parseCloudCode(Config.CloudConfigCode)
    end
end)
addButton(SettingsTab, "Generate Shareable Config Code", "Serializes current UI options and copies the loadout string to your clipboard.", function()
    generateCloudCode()
end)

addSection(SettingsTab, "App Control Binds")
addKeybind(SettingsTab, "Aimbot Toggle Keybind", Config.AimbotToggleKey, function()
    Config.AimbotEnabled = not Config.AimbotEnabled
    notify("Aimbot Toggled", "Aimbot is now " .. (Config.AimbotEnabled and "ON" or "OFF"), 2)
end)
addKeybind(SettingsTab, "Silent Aim Toggle Keybind", Config.SilentAimToggleKey, function()
    Config.SilentAimEnabled = not Config.SilentAimEnabled
    notify("Silent Aim Toggled", "Silent Aim is now " .. (Config.SilentAimEnabled and "ON" or "OFF"), 2)
end)
addKeybind(SettingsTab, "Slow Walk Toggle Keybind", Config.SilentWalkKey, function()
    Config.SilentWalkEnabled = not Config.SilentWalkEnabled
    notify("Slow Walk Toggled", "Slow Walk is now " .. (Config.SilentWalkEnabled and "ON" or "OFF"), 2)
end)

SettingsTab:Paragraph({
    Title = "Adaptive Framework",
    Content = "Clean modular optimization with customized Syde integrations."
})

-- Initialize Core Features Safely (Executed after UI compilation completes)
task.spawn(function()
    task.wait(0.5) -- Safe structural rendering buffer
    
    local success, err = pcall(function()
        updateFOV()
        updateAntiAim()
        cachedClosestPart = getClosestPlayer()
        applyLightingSettings()
        
        -- Auto Load Last Configuration File
        local LAST_CONFIG_FILE = "AdaptiveAimbot_LastConfig.txt"
        if isFileSystemSupported and isfile(LAST_CONFIG_FILE) then
            local lastConfigName = readfile(LAST_CONFIG_FILE)
            if lastConfigName and lastConfigName ~= "" then
                loadConfig(lastConfigName)
            end
        end
    end)
    
    if not success then
        warn("[Adaptive Aimbot Runtime Error] Initialization loop failed: " .. tostring(err))
    end
end)

notify("Framework Loaded", "Refit initialization complete.", 3)

syde:LoadSaveConfig()
