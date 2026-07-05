-- Cascade Loader
local function importRelease(owner, repo, version, file)
    local tag = (version == "latest" and "latest/download" or "download/" .. version)
    return loadstring(game:HttpGetAsync(("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)), file)()
end

local cascade = importRelease("cascadeui", "Cascade", "latest", "dist.luau")

local Config = {
    -- Master switches
    AimbotEnabled = false,
    SilentAimEnabled = false,
    
    -- Humanization mode: "Custom" or "Copied"
    HumanizationMode = "Custom",
    
    -- Custom profile parameters
    Smoothing = 5,
    AccelerationCurve = 1.0,
    AimShake = 0.0,
    Overshoot = 0.0,
    Undershoot = 0.0,
    FlickTrackingBias = 0.5,

    -- Autoshoot & Wallbang
    AutoShootEnabled = false,
    AutoShootDelay = 150, -- now populated from dropdown
    AutoWallbangEnabled = false,
    MaxWalls = 1,          -- 0,1,2
    MaxWallThickness = 2,  -- from dropdown
    LegitMode = true,      -- false = rage (instant, full wallbang)
    
    -- Triggerbot
    TriggerbotEnabled = false,
    TriggerbotKey = "MouseButton1",
    TriggerbotDelay = 0,  -- from dropdown
    TriggerbotMode = "Aimbot Lock", -- "Crosshair", "Aimbot Lock"
    
    -- Anti-Aim
    AntiAimEnabled = false,
    AntiAimMode = "Spin", -- "Spin", "Jitter", "Side Jitter", "Backward"
    AntiAimSpeed = 10,
    AntiAimJitterAmplitude = 45,

    -- Camera FOV
    CustomFOVEnabled = false,
    CustomFOV = 103,

    -- Hold controls
    HoldToAim = true,
    AimMouseButton = "MouseButton2",
    AimKeyboardKey = Enum.KeyCode.E,

    -- Silent Aim Options
    Method = "Raycast",
    TargetPart = "Auto",   -- "Auto" = auto-detect head, else part name
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

    -- Target indicator
    ShowTargetIndicator = true,
    TargetIndicatorSize = 20,
    TargetIndicatorColor = Color3.fromRGB(54, 57, 241),

    -- Player ESP Settings
    EspEnabled = false,
    EspBoxes = false,
    EspNames = false,
    EspDistances = false,
    EspHealth = false,
    EspColor = Color3.fromRGB(255, 255, 255),
    EspTextSize = 13,

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
    ShadowsEnabled = true,
    AmbientColor = Color3.fromRGB(128, 128, 128),
    Brightness = 2.0,
    ClockTime = 12.0,
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

-- Dynamic Camera Reference Tracker (Prevents failures on player respawning)
local Camera = workspace.CurrentCamera
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end)

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- Shortcuts
local getPlayers = Players.GetPlayers
local findFirstChild = game.FindFirstChild
local getMouseLocation = UserInputService.GetMouseLocation

-- Lighting Backup for Safe Restoration
local originalLighting = {
    FogColor = Lighting.FogColor,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime
}

local function applyLightingSettings()
    if Config.FogEnabled then
        Lighting.FogStart = Config.FogStart
        Lighting.FogEnd = Config.FogEnd
        Lighting.FogColor = Config.FogColor
    else
        Lighting.FogStart = originalLighting.FogStart
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogColor = originalLighting.FogColor
    end
    
    Lighting.GlobalShadows = Config.ShadowsEnabled
    Lighting.Ambient = Config.AmbientColor
    Lighting.Brightness = Config.Brightness
    Lighting.ClockTime = Config.ClockTime
end

-- Dynamic part detection (auto-fetch head)
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
        if #available == 0 then
            return getAutoTargetPart(char)
        end
        return available[math.random(1, #available)]
    else
        return char:FindFirstChild(Config.TargetPart)
    end
end

local function refreshPartList()
    local list = {"Auto", "Random"}
    local char = LocalPlayer.Character
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                table.insert(list, v.Name)
            end
        end
    end
    table.insert(list, "Head")
    table.insert(list, "HumanoidRootPart")
    Config.DynamicPartList = list
end

-- Adaptive Live Profile (Copied)
local Profile = { AverageSpeed = 0, JitterScale = 0 }
local naturalMovementData = {}
local lastMousePos = getMouseLocation(UserInputService)

task.spawn(function()
    while true do
        task.wait(1 / 144)
        local holding = true
        if Config.HoldToAim then
            if Config.AimMouseButton == "MouseButton1" then
                holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            elseif Config.AimMouseButton == "MouseButton2" then
                holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            elseif Config.AimMouseButton == "Keyboard" then
                holding = UserInputService:IsKeyDown(Config.AimKeyboardKey)
            end
        end
        if not Config.AimbotEnabled or not holding then
            local currentMousePos = getMouseLocation(UserInputService)
            local delta = (currentMousePos - lastMousePos)
            if delta.Magnitude > 0.1 then
                table.insert(naturalMovementData, { delta = delta, speed = delta.Magnitude, time = tick() })
                if #naturalMovementData > 144 then table.remove(naturalMovementData, 1) end
                local speedSum, jitterSum = 0, 0
                for i = 2, #naturalMovementData do
                    speedSum = speedSum + naturalMovementData[i].speed
                    local v1 = naturalMovementData[i-1].delta
                    local v2 = naturalMovementData[i].delta
                    if v1.Magnitude > 0 and v2.Magnitude > 0 then
                        local dot = v1:Dot(v2) / (v1.Magnitude * v2.Magnitude)
                        local angle = math.acos(math.clamp(dot, -1, 1))
                        jitterSum = jitterSum + angle
                    end
                end
                local count = #naturalMovementData
                if count > 1 then
                    Profile.AverageSpeed = speedSum / count
                    Profile.JitterScale = jitterSum / count
                end
            end
            lastMousePos = currentMousePos
        end
    end
end)

-- FOV Changer
local fovConnection
local function updateFOV()
    if fovConnection then fovConnection:Disconnect() end
    if Config.CustomFOVEnabled then
        fovConnection = RunService.RenderStepped:Connect(function()
            if Camera then
                Camera.FieldOfView = Config.CustomFOV
            end
        end)
    else
        if Camera then
            Camera.FieldOfView = 70 -- reset
        end
    end
end

-- Anti-Aim Loop
local antiAimConnection
local function updateAntiAim()
    if antiAimConnection then antiAimConnection:Disconnect() end
    if Config.AntiAimEnabled then
        antiAimConnection = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local rotY = 0
            if Config.AntiAimMode == "Spin" then
                rotY = (tick() * Config.AntiAimSpeed * 10) % 360
            elseif Config.AntiAimMode == "Jitter" then
                rotY = math.sin(tick() * Config.AntiAimSpeed) * Config.AntiAimJitterAmplitude
            elseif Config.AntiAimMode == "Side Jitter" then
                rotY = (math.sin(tick() * Config.AntiAimSpeed) > 0 and 1 or -1) * Config.AntiAimJitterAmplitude
            elseif Config.AntiAimMode == "Backward" then
                rotY = 180
            end
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(rotY), 0)
        end)
    end
end

-- isAimingHeld
local function isAimingHeld()
    if not Config.HoldToAim then return true end
    if Config.AimMouseButton == "MouseButton1" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    elseif Config.AimMouseButton == "MouseButton2" then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    elseif Config.AimMouseButton == "Keyboard" then
        return UserInputService:IsKeyDown(Config.AimKeyboardKey)
    end
    return true
end

-- Drawings
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.ZIndex = 999
fovCircle.Thickness = Config.FOVThickness
fovCircle.NumSides = Config.FOVNumSides
fovCircle.Radius = Config.FOVRadius
fovCircle.Filled = Config.FOVFilled
fovCircle.Transparency = Config.FOVTransparency
fovCircle.Color = Config.FOVColor

local targetBox = Drawing.new("Square")
targetBox.Visible = false
targetBox.ZIndex = 999
targetBox.Thickness = 2
targetBox.Size = Vector2.new(Config.TargetIndicatorSize, Config.TargetIndicatorSize)
targetBox.Filled = false
targetBox.Color = Config.TargetIndicatorColor

-- Core ESP & Chams Engine
local espCache = {}

local function createEsp(player)
    if espCache[player] then return end
    local drawings = {
        Box = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
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
        
        if Config.EspEnabled and char and humanoid and rpart and humanoid.Health > 0 and not isTeammate then
            local rpartPos = rpart.Position
            local screenPos, onScreen = Camera:WorldToViewportPoint(rpartPos)
            
            if onScreen then
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
                    
                    if Config.EspBoxes then
                        drawings.Box.Visible = true
                        drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
                        drawings.Box.Position = Vector2.new(boxX, boxY)
                        drawings.Box.Color = Config.EspColor
                    else
                        drawings.Box.Visible = false
                    end
                    
                    if Config.EspNames then
                        drawings.Name.Visible = true
                        drawings.Name.Text = player.Name
                        drawings.Name.Position = Vector2.new(topScreen.X, boxY - Config.EspTextSize - 2)
                        drawings.Name.Color = Config.EspColor
                        drawings.Name.Size = Config.EspTextSize
                    else
                        drawings.Name.Visible = false
                    end
                    
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
                    drawings.HealthBarOutline.Visible = false
                    drawings.HealthBar.Visible = false
                end
            else
                drawings.Box.Visible = false
                drawings.Name.Visible = false
                drawings.Distance.Visible = false
                drawings.HealthBarOutline.Visible = false
                drawings.HealthBar.Visible = false
            end
        else
            drawings.Box.Visible = false
            drawings.Name.Visible = false
            drawings.Distance.Visible = false
            drawings.HealthBarOutline.Visible = false
            drawings.HealthBar.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(removeEsp)

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

-- Tracker State
local cachedClosestPart = nil
local lockStartTime = 0
local lastTarget = nil
local autoShootNext = 0

-- Autoshoot logic
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
        -- Compute wall thickness: we approximate by measuring distance from entry to exit
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

-- Silent Aim Hooks
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

-- Aimbot Render Loop
RunService.RenderStepped:Connect(function()
    cachedClosestPart = getClosestPlayer()
    updateEsp()

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
        local step = 1 / baseSmooth
        step = math.pow(step, curve)

        if flick > 0.5 then
            if timeElapsed < 0.15 then step = math.clamp(step * (flick * 2), 0, 1) end
        else
            if timeElapsed < 0.2 then step = step * (flick + 0.5) end
        end

        Camera.CFrame = currentCFrame:Lerp(rawTargetCFrame, math.clamp(step, 0, 1))
    else
        lastTarget = nil
    end

    -- FOV circle
    if Config.FOVEnabled then
        fovCircle.Visible = true
        fovCircle.Radius = Config.FOVRadius
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
end)

-- UI Setup
local app = cascade.New({
    WindowPill = true,
    Theme = cascade.Themes.Dark,
    Accent = cascade.Accents.Blue,
})

local window = app:Window({
    Title = "Aimbotzz",
    Subtitle = "Build: BETA",
    Size = UDim2.fromOffset(850, 530),
    Draggable = true,
    Resizable = true,
    Searching = true,
    CanExit = true,
    CanMinimize = true,
    CanZoom = true,
    Dropshadow = true,
    UIBlur = true,
})

local function titledRow(parent, title, subtitle)
    local row = parent:Row({ SearchIndex = title })
    row:Left():TitleStack({ Title = title, Subtitle = subtitle })
    return row
end

-- Pre‑define arrays to avoid inline indexing syntax issues
local wallOptions = {0, 1, 2}
local thicknessOptions = {1, 2, 3, 5}
local delayOptions = {0, 50, 100, 150, 200, 300, 500}
local triggerDelayOptions = {0, 50, 100, 150, 200}

-- Combat Section
local combatSection = window:Section({ Title = "Combat", Disclosure = false })
local aimbotTab = combatSection:Tab({ Selected = true, Title = "Aimbot", Icon = cascade.Symbols.squareStack3dUp })

-- Aimbot Main Form
local aimbotForm = aimbotTab:Form()
titledRow(aimbotForm, "Aimbot Enabled", ""):Right():Toggle({ Value = Config.AimbotEnabled, ValueChanged = function(s,v) Config.AimbotEnabled = v end })
titledRow(aimbotForm, "Silent Aim Enabled", ""):Right():Toggle({ Value = Config.SilentAimEnabled, ValueChanged = function(s,v) Config.SilentAimEnabled = v end })
titledRow(aimbotForm, "Hold to Aim", ""):Right():Toggle({ Value = Config.HoldToAim, ValueChanged = function(s,v) Config.HoldToAim = v end })
local triggerModes = { "MouseButton1", "MouseButton2", "Keyboard" }
titledRow(aimbotForm, "Hold Trigger Source", ""):Right():PopUpButton({ Options = triggerModes, Value = 2, ValueChanged = function(s, idx) Config.AimMouseButton = triggerModes[idx] end })
titledRow(aimbotForm, "Keyboard Bind", ""):Right():KeybindField({ Value = Config.AimKeyboardKey, ValueChanged = function(s,v) Config.AimKeyboardKey = v end })

-- Humanization Section
local humanizeSection = aimbotTab:PageSection({ Title = "Humanization Profile", Subtitle = "Choose movement style" })
local humanizeForm = humanizeSection:Form()

local humanizationModes = {"Custom", "Copied (Live)"}
titledRow(humanizeForm, "Humanization Mode", ""):Right():PopUpButton({
    Options = humanizationModes,
    Value = 1,
    ValueChanged = function(s, idx) Config.HumanizationMode = humanizationModes[idx] end
})

local customParamsForm = humanizeSection:Form()
titledRow(customParamsForm, "Smoothing", ""):Right():Slider({ Minimum=1, Maximum=100, Value=Config.Smoothing, ValueChanged=function(s,v) Config.Smoothing=v end })
titledRow(customParamsForm, "Acceleration Curve", ""):Right():Slider({ Minimum=1, Maximum=3, Value=Config.AccelerationCurve, ValueChanged=function(s,v) Config.AccelerationCurve=v end })
titledRow(customParamsForm, "Aim Shake", ""):Right():Slider({ Minimum=0, Maximum=10, Value=Config.AimShake, ValueChanged=function(s,v) Config.AimShake=v end })
titledRow(customParamsForm, "Overshoot", ""):Right():Slider({ Minimum=0, Maximum=100, Value=Config.Overshoot, ValueChanged=function(s,v) Config.Overshoot=v end })
titledRow(customParamsForm, "Undershoot", ""):Right():Slider({ Minimum=0, Maximum=100, Value=Config.Undershoot, ValueChanged=function(s,v) Config.Undershoot=v end })
titledRow(customParamsForm, "Flick Bias", ""):Right():Slider({ Minimum=0, Maximum=100, Value=math.floor(Config.FlickTrackingBias * 100), ValueChanged=function(s,v) Config.FlickTrackingBias= v / 100 end })

-- Autoshoot & Wallbang Section
local autoSection = aimbotTab:PageSection({ Title = "Autoshoot & Autowallbang" })
local autoForm = autoSection:Form()
titledRow(autoForm, "Autoshoot", ""):Right():Toggle({ Value=Config.AutoShootEnabled, ValueChanged=function(s,v) Config.AutoShootEnabled=v end })

titledRow(autoForm, "Autoshoot Delay (ms)", ""):Right():PopUpButton({
    Options = delayOptions,
    Value = 4,
    ValueChanged = function(s, idx) Config.AutoShootDelay = delayOptions[idx] end
})

titledRow(autoForm, "Autowallbang", ""):Right():Toggle({ Value=Config.AutoWallbangEnabled, ValueChanged=function(s,v) Config.AutoWallbangEnabled=v end })

titledRow(autoForm, "Max Walls", ""):Right():PopUpButton({
    Options = wallOptions,
    Value = 2,
    ValueChanged = function(s, idx) Config.MaxWalls = wallOptions[idx] end
})

titledRow(autoForm, "Max Wall Thickness", ""):Right():PopUpButton({
    Options = thicknessOptions,
    Value = 2,
    ValueChanged = function(s, idx) Config.MaxWallThickness = thicknessOptions[idx] end
})

titledRow(autoForm, "Legit Mode", "Off = Rage (instant, bypass walls)"):Right():Toggle({ Value=Config.LegitMode, ValueChanged=function(s,v) Config.LegitMode=v end })

-- Triggerbot Section
local triggerSection = aimbotTab:PageSection({ Title = "Triggerbot" })
local triggerForm = triggerSection:Form()
titledRow(triggerForm, "Triggerbot Enabled", ""):Right():Toggle({ Value=Config.TriggerbotEnabled, ValueChanged=function(s,v) Config.TriggerbotEnabled=v end })
local triggerModeList = {"Crosshair", "Aimbot Lock"}
titledRow(triggerForm, "Trigger Mode", ""):Right():PopUpButton({ Options=triggerModeList, Value=2, ValueChanged=function(s, idx) Config.TriggerbotMode = triggerModeList[idx] end })

titledRow(triggerForm, "Delay (ms)", ""):Right():PopUpButton({
    Options = triggerDelayOptions,
    Value = 1,
    ValueChanged = function(s, idx) Config.TriggerbotDelay = triggerDelayOptions[idx] end
})

-- Anti-Aim Section
local aaSection = aimbotTab:PageSection({ Title = "Anti-Aim" })
local aaForm = aaSection:Form()
titledRow(aaForm, "Anti-Aim Enabled", ""):Right():Toggle({ Value=Config.AntiAimEnabled, ValueChanged=function(s,v) Config.AntiAimEnabled=v; updateAntiAim() end })
local aaModes = {"Spin", "Jitter", "Side Jitter", "Backward"}
titledRow(aaForm, "Mode", ""):Right():PopUpButton({ Options=aaModes, Value=1, ValueChanged=function(s, idx) Config.AntiAimMode=aaModes[idx]; updateAntiAim() end })
titledRow(aaForm, "Speed", ""):Right():Slider({ Minimum=1, Maximum=20, Value=Config.AntiAimSpeed, ValueChanged=function(s,v) Config.AntiAimSpeed=v end })
titledRow(aaForm, "Jitter Angle", ""):Right():Slider({ Minimum=0, Maximum=90, Value=Config.AntiAimJitterAmplitude, ValueChanged=function(s,v) Config.AntiAimJitterAmplitude=v end })

-- Camera FOV Section
local camSection = aimbotTab:PageSection({ Title = "Camera FOV" })
local camForm = camSection:Form()
titledRow(camForm, "Override FOV", ""):Right():Toggle({ Value=Config.CustomFOVEnabled, ValueChanged=function(s,v) Config.CustomFOVEnabled=v; updateFOV() end })
titledRow(camForm, "FOV Value", ""):Right():Slider({ Minimum=30, Maximum=120, Value=Config.CustomFOV, ValueChanged=function(s,v) Config.CustomFOV=v; if Config.CustomFOVEnabled then updateFOV() end end })

-- Target Filtering
local filterSection = aimbotTab:PageSection({ Title = "Target Filtering" })
local filterForm = filterSection:Form()

local methodOptions = { "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "Mouse.Hit/Target" }
titledRow(filterForm, "Silent Aim Method", ""):Right():PopUpButton({
    Options = methodOptions,
    Value = 1,
    ValueChanged = function(s, idx) Config.Method = methodOptions[idx] end,
})

refreshPartList()
titledRow(filterForm, "Target Part", ""):Right():PopUpButton({
    Options = Config.DynamicPartList,
    Value = 1,
    ValueChanged = function(s, idx) Config.TargetPart = Config.DynamicPartList[idx] end,
})

titledRow(filterForm, "Team Check", ""):Right():Toggle({ Value=Config.TeamCheck, ValueChanged=function(s,v) Config.TeamCheck=v end })
titledRow(filterForm, "Visible Check", ""):Right():Toggle({ Value=Config.VisibleCheck, ValueChanged=function(s,v) Config.VisibleCheck=v end })
titledRow(filterForm, "Hit Chance", ""):Right():Slider({ Minimum=0, Maximum=100, Value=Config.HitChance, ValueChanged=function(s,v) Config.HitChance=v end })
titledRow(filterForm, "Prediction", ""):Right():Toggle({ Value=Config.Prediction, ValueChanged=function(s,v) Config.Prediction=v end })
titledRow(filterForm, "Prediction Amount", ""):Right():Stepper({ Minimum=0.001, Maximum=1.0, Step=0.005, Fielded=true, Value=Config.PredictionAmount, ValueChanged=function(s,v) Config.PredictionAmount=v end })

-- Visuals Section (Revamped, Expanded, and Highly Customizable)
local visualsSection = window:Section({ Title = "Visuals", Disclosure = false })

-- 1. Player ESP Tab
local espTab = visualsSection:Tab({ Selected = true, Title = "Player ESP", Icon = cascade.Symbols.person })
local espForm = espTab:Form()
titledRow(espForm, "Enable ESP", ""):Right():Toggle({ Value=Config.EspEnabled, ValueChanged=function(s,v) Config.EspEnabled=v end })
titledRow(espForm, "Show Boxes", ""):Right():Toggle({ Value=Config.EspBoxes, ValueChanged=function(s,v) Config.EspBoxes=v end })
titledRow(espForm, "Show Names", ""):Right():Toggle({ Value=Config.EspNames, ValueChanged=function(s,v) Config.EspNames=v end })
titledRow(espForm, "Show Distance", ""):Right():Toggle({ Value=Config.EspDistances, ValueChanged=function(s,v) Config.EspDistances=v end })
titledRow(espForm, "Show Health Bar", ""):Right():Toggle({ Value=Config.EspHealth, ValueChanged=function(s,v) Config.EspHealth=v end })
titledRow(espForm, "Text Size", ""):Right():Slider({ Minimum=8, Maximum=24, Value=Config.EspTextSize, ValueChanged=function(s,v) Config.EspTextSize=v end })

local espColorSection = espTab:PageSection({ Title = "ESP Color Settings" }):Form()
local function espRGB() return Config.EspColor.R*255, Config.EspColor.G*255, Config.EspColor.B*255 end
local er, eg, eb = espRGB()
titledRow(espColorSection, "Red", ""):Right():Slider({ Minimum=0, Maximum=255, Value=er, ValueChanged=function(s,v) Config.EspColor=Color3.fromRGB(v, eg, eb); er=v end })
titledRow(espColorSection, "Green", ""):Right():Slider({ Minimum=0, Maximum=255, Value=eg, ValueChanged=function(s,v) Config.EspColor=Color3.fromRGB(er, v, eb); eg=v end })
titledRow(espColorSection, "Blue", ""):Right():Slider({ Minimum=0, Maximum=255, Value=eb, ValueChanged=function(s,v) Config.EspColor=Color3.fromRGB(er, eg, v); eb=v end })

-- 2. Chams Tab
local chamsTab = visualsSection:Tab({ Selected = false, Title = "Chams", Icon = cascade.Symbols.squareAndLineVerticalAndSquare })
local chamsForm = chamsTab:Form()
titledRow(chamsForm, "Enable Chams", ""):Right():Toggle({ Value=Config.ChamsEnabled, ValueChanged=function(s,v) Config.ChamsEnabled=v end })
titledRow(chamsForm, "Always On Top", "Render through walls"):Right():Toggle({ Value=Config.ChamsAlwaysOnTop, ValueChanged=function(s,v) Config.ChamsAlwaysOnTop=v end })
titledRow(chamsForm, "Fill Transparency", ""):Right():Slider({ Minimum=0, Maximum=100, Value=math.floor(Config.ChamsFillTransparency*100), ValueChanged=function(s,v) Config.ChamsFillTransparency=v/100 end })
titledRow(chamsForm, "Outline Transparency", ""):Right():Slider({ Minimum=0, Maximum=100, Value=math.floor(Config.ChamsOutlineTransparency*100), ValueChanged=function(s,v) Config.ChamsOutlineTransparency=v/100 end })

local chamsFillSection = chamsTab:PageSection({ Title = "Chams Fill Color" }):Form()
local function cfRGB() return Config.ChamsFillColor.R*255, Config.ChamsFillColor.G*255, Config.ChamsFillColor.B*255 end
local cfr, cfg, cfb = cfRGB()
titledRow(chamsFillSection, "Red", ""):Right():Slider({ Minimum=0, Maximum=255, Value=cfr, ValueChanged=function(s,v) Config.ChamsFillColor=Color3.fromRGB(v, cfg, cfb); cfr=v end })
titledRow(chamsFillSection, "Green", ""):Right():Slider({ Minimum=0, Maximum=255, Value=cfg, ValueChanged=function(s,v) Config.ChamsFillColor=Color3.fromRGB(cfr, v, cfb); cfg=v end })
titledRow(chamsFillSection, "Blue", ""):Right():Slider({ Minimum=0, Maximum=255, Value=cfb, ValueChanged=function(s,v) Config.ChamsFillColor=Color3.fromRGB(cfr, cfg, v); cfb=v end })

local chamsOutlineSection = chamsTab:PageSection({ Title = "Chams Outline Color" }):Form()
local function coRGB() return Config.ChamsOutlineColor.R*255, Config.ChamsOutlineColor.G*255, Config.ChamsOutlineColor.B*255 end
local cor, cog, cob = coRGB()
titledRow(chamsOutlineSection, "Red", ""):Right():Slider({ Minimum=0, Maximum=255, Value=cor, ValueChanged=function(s,v) Config.ChamsOutlineColor=Color3.fromRGB(v, cog, cob); cor=v end })
titledRow(chamsOutlineSection, "Green", ""):Right():Slider({ Minimum=0, Maximum=255, Value=cog, ValueChanged=function(s,v) Config.ChamsOutlineColor=Color3.fromRGB(cor, v, cob); cog=v end })
titledRow(chamsOutlineSection, "Blue", ""):Right():Slider({ Minimum=0, Maximum=255, Value=cob, ValueChanged=function(s,v) Config.ChamsOutlineColor=Color3.fromRGB(cor, cog, v); cob=v end })

-- 3. World & Lighting Tab
local worldTab = visualsSection:Tab({ Selected = false, Title = "World & Lighting", Icon = cascade.Symbols.bolt })
local worldForm = worldTab:Form()
titledRow(worldForm, "Custom Fog Enabled", ""):Right():Toggle({ Value=Config.FogEnabled, ValueChanged=function(s,v) Config.FogEnabled=v; applyLightingSettings() end })
titledRow(worldForm, "Fog Start", ""):Right():Slider({ Minimum=0, Maximum=5000, Value=Config.FogStart, ValueChanged=function(s,v) Config.FogStart=v; applyLightingSettings() end })
titledRow(worldForm, "Fog End", ""):Right():Slider({ Minimum=100, Maximum=20000, Value=Config.FogEnd, ValueChanged=function(s,v) Config.FogEnd=v; applyLightingSettings() end })
titledRow(worldForm, "Global Shadows", ""):Right():Toggle({ Value=Config.ShadowsEnabled, ValueChanged=function(s,v) Config.ShadowsEnabled=v; applyLightingSettings() end })
titledRow(worldForm, "Brightness", ""):Right():Slider({ Minimum=0, Maximum=10, Value=math.floor(Config.Brightness), ValueChanged=function(s,v) Config.Brightness=v; applyLightingSettings() end })
titledRow(worldForm, "Clock Time", ""):Right():Slider({ Minimum=0, Maximum=24, Value=math.floor(Config.ClockTime), ValueChanged=function(s,v) Config.ClockTime=v; applyLightingSettings() end })

local fogColorSection = worldTab:PageSection({ Title = "Fog Color" }):Form()
local function fogRGB() return Config.FogColor.R*255, Config.FogColor.G*255, Config.FogColor.B*255 end
local fgr, fgg, fgb = fogRGB()
titledRow(fogColorSection, "Red", ""):Right():Slider({ Minimum=0, Maximum=255, Value=fgr, ValueChanged=function(s,v) Config.FogColor=Color3.fromRGB(v, fgg, fgb); fgr=v; applyLightingSettings() end })
titledRow(fogColorSection, "Green", ""):Right():Slider({ Minimum=0, Maximum=255, Value=fgg, ValueChanged=function(s,v) Config.FogColor=Color3.fromRGB(fgr, v, fgb); fgg=v; applyLightingSettings() end })
titledRow(fogColorSection, "Blue", ""):Right():Slider({ Minimum=0, Maximum=255, Value=fgb, ValueChanged=function(s,v) Config.FogColor=Color3.fromRGB(fgr, fgg, v); fgb=v; applyLightingSettings() end })

local ambientSection = worldTab:PageSection({ Title = "Ambient Color" }):Form()
local function ambRGB() return Config.AmbientColor.R*255, Config.AmbientColor.G*255, Config.AmbientColor.B*255 end
local ambr, ambg, ambb = ambRGB()
titledRow(ambientSection, "Red", ""):Right():Slider({ Minimum=0, Maximum=255, Value=ambr, ValueChanged=function(s,v) Config.AmbientColor=Color3.fromRGB(v, ambg, ambb); ambr=v; applyLightingSettings() end })
titledRow(ambientSection, "Green", ""):Right():Slider({ Minimum=0, Maximum=255, Value=ambg, ValueChanged=function(s,v) Config.AmbientColor=Color3.fromRGB(ambr, v, ambb); ambg=v; applyLightingSettings() end })
titledRow(ambientSection, "Blue", ""):Right():Slider({ Minimum=0, Maximum=255, Value=ambb, ValueChanged=function(s,v) Config.AmbientColor=Color3.fromRGB(ambr, ambg, v); ambb=v; applyLightingSettings() end })

-- 4. FOV Circle Tab
local fovTab = visualsSection:Tab({ Selected = false, Title = "FOV Circle", Icon = cascade.Symbols.sunMax })
local fovForm = fovTab:Form()
titledRow(fovForm, "Show FOV Circle", ""):Right():Toggle({ Value=Config.FOVEnabled, ValueChanged=function(s,v) Config.FOVEnabled=v end })
titledRow(fovForm, "Radius", ""):Right():Slider({ Minimum=10, Maximum=800, Value=Config.FOVRadius, ValueChanged=function(s,v) Config.FOVRadius=v end })
titledRow(fovForm, "Thickness", ""):Right():Slider({ Minimum=1, Maximum=10, Value=Config.FOVThickness, ValueChanged=function(s,v) Config.FOVThickness=v end })
titledRow(fovForm, "Sides", ""):Right():Slider({ Minimum=10, Maximum=100, Value=Config.FOVNumSides, ValueChanged=function(s,v) Config.FOVNumSides=v end })
titledRow(fovForm, "Filled", ""):Right():Toggle({ Value=Config.FOVFilled, ValueChanged=function(s,v) Config.FOVFilled=v end })
titledRow(fovForm, "Transparency", ""):Right():Slider({ Minimum=0, Maximum=1, Value=Config.FOVTransparency, ValueChanged=function(s,v) Config.FOVTransparency=v end })
local fovColorSection = fovTab:PageSection({ Title = "FOV Color" }):Form()
local fr,fg,fb = fovRGB()
titledRow(fovColorSection, "Red", ""):Right():Slider({ Minimum=0, Maximum=255, Value=fr, ValueChanged=function(s,v) Config.FOVColor=Color3.fromRGB(v,fg,fb) end })
titledRow(fovColorSection, "Green", ""):Right():Slider({ Minimum=0, Maximum=255, Value=fg, ValueChanged=function(s,v) Config.FOVColor=Color3.fromRGB(fr,v,fb) end })
titledRow(fovColorSection, "Blue", ""):Right():Slider({ Minimum=0, Maximum=255, Value=fb, ValueChanged=function(s,v) Config.FOVColor=Color3.fromRGB(fr,fg,v) end })

-- 5. Target Indicator Tab
local indicatorTab = visualsSection:Tab({ Selected = false, Title = "Indicator", Icon = cascade.Symbols.sunMin })
local indicatorForm = indicatorTab:Form()
titledRow(indicatorForm, "Show Indicator", ""):Right():Toggle({ Value=Config.ShowTargetIndicator, ValueChanged=function(s,v) Config.ShowTargetIndicator=v end })
titledRow(indicatorForm, "Box Size", ""):Right():Slider({ Minimum=5, Maximum=100, Value=Config.TargetIndicatorSize, ValueChanged=function(s,v) Config.TargetIndicatorSize=v end })
local indColorSection = indicatorTab:PageSection({ Title = "Indicator Color" }):Form()
local function indRGB() return Config.TargetIndicatorColor.R*255, Config.TargetIndicatorColor.G*255, Config.TargetIndicatorColor.B*255 end
local ir,ig,ib = indRGB()
titledRow(indColorSection, "Red", ""):Right():Slider({ Minimum=0, Maximum=255, Value=ir, ValueChanged=function(s,v) Config.TargetIndicatorColor=Color3.fromRGB(v,ig,ib) end })
titledRow(indColorSection, "Green", ""):Right():Slider({ Minimum=0, Maximum=255, Value=ig, ValueChanged=function(s,v) Config.TargetIndicatorColor=Color3.fromRGB(ir,v,ib) end })
titledRow(indColorSection, "Blue", ""):Right():Slider({ Minimum=0, Maximum=255, Value=ib, ValueChanged=function(s,v) Config.TargetIndicatorColor=Color3.fromRGB(ir,ig,v) end })

-- Settings Section
local settingsSection = window:Section({ Title = "Settings", Disclosure = false })
local configTab = settingsSection:Tab({ Selected = false, Title = "Configuration", Icon = cascade.Symbols.gear })
local appearanceForm = configTab:PageSection({ Title = "Appearance" }):Form()
titledRow(appearanceForm, "Dark Theme", ""):Right():Toggle({ Value = app.Theme == cascade.Themes.Dark, ValueChanged = function(s,v) app.Theme = v and cascade.Themes.Dark or cascade.Themes.Light end })
titledRow(appearanceForm, "Searchable", ""):Right():Toggle({ Value = window.Searching, ValueChanged = function(s,v) window.Searching = v end })
titledRow(appearanceForm, "Draggable", ""):Right():Toggle({ Value = window.Draggable, ValueChanged = function(s,v) window.Draggable = v end })
titledRow(appearanceForm, "Resizable", ""):Right():Toggle({ Value = window.Resizable, ValueChanged = function(s,v) window.Resizable = v end })

local minimizeKeybind = Enum.KeyCode.RightControl
UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
    if input.KeyCode == minimizeKeybind and not gameProcessedEvent then
        window.Minimized = not window.Minimized
    end
end)
local appControlForm = configTab:PageSection({ Title = "App Controls" }):Form()
titledRow(appControlForm, "Minimize Keybind", ""):Right():KeybindField({ Value = minimizeKeybind, ValueChanged = function(s,v) minimizeKeybind = v end })

-- Initialize
updateFOV()
updateAntiAim()
applyLightingSettings()
cachedClosestPart = getClosestPlayer()
