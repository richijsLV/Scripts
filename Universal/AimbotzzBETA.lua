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
