-- Secure mode configuration
getgenv().SecureMode = true

-- Load Starlight and icon libraries
local Starlight = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/starlight"))()
local NebulaIcons = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/nebula-icon-library-loader"))()

-- Basic services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- State and Configuration Variables
local playerButtons = {}
local targetPlayer = nil
local toggleKey = "RightShift"
local logHistory = {}
local notifCounter = 0

-- Viewport Window States
local currentClone = nil
local rotationAngle = 0
local rotationConnection = nil

---------------------------------------------------------
-- CUSTOM REAL-TIME 3D VIEWPORT WINDOW
---------------------------------------------------------

local viewportGui = Instance.new("ScreenGui")
viewportGui.Name = "StarlightDripViewport"
viewportGui.ResetOnSpawn = false
viewportGui.DisplayOrder = 1000
viewportGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.new(0, 320, 0, 420)
previewFrame.Position = UDim2.new(0.5, 180, 0.5, -210)
previewFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
previewFrame.BorderSizePixel = 0
previewFrame.Visible = false
previewFrame.Active = true
previewFrame.Parent = viewportGui

local previewCorner = Instance.new("UICorner")
previewCorner.CornerRadius = UDim.new(0, 12)
previewCorner.Parent = previewFrame

local previewStroke = Instance.new("UIStroke")
previewStroke.Color = Color3.fromRGB(60, 60, 60)
previewStroke.Thickness = 1
previewStroke.Parent = previewFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -45, 0, 40)
title.Position = UDim2.new(0, 15, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Target Preview"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = previewFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = previewFrame

closeBtn.MouseButton1Click:Connect(function()
    previewFrame.Visible = false
end)

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.new(1, -20, 1, -60)
viewport.Position = UDim2.new(0, 10, 0, 50)
viewport.BackgroundTransparency = 1
viewport.Parent = previewFrame

local viewportCorner = Instance.new("UICorner")
viewportCorner.CornerRadius = UDim.new(0, 8)
viewportCorner.Parent = viewport

local cam = Instance.new("Camera")
cam.FieldOfView = 50
viewport.CurrentCamera = cam
cam.Parent = viewport

-- Floating Draggable Logic for the Viewport Frame
local dragging = false
local dragInput, dragStart, startPos

previewFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = previewFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

previewFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        previewFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Character cloning and 3D environment loading
local function updateViewportCharacter(targetPlr)
    if rotationConnection then
        rotationConnection:Disconnect()
        rotationConnection = nil
    end
    if currentClone then
        currentClone:Destroy()
        currentClone = nil
    end

    if not targetPlr then
        previewFrame.Visible = false
        return
    end

    local sourceChar = targetPlr.Character or workspace:FindFirstChild(targetPlr.Name)
    if not sourceChar then
        previewFrame.Visible = false
        return
    end

    -- Force Archivable flag to enable cloning process
    local originalArchivable = sourceChar.Archivable
    sourceChar.Archivable = true
    local clone = sourceChar:Clone()
    sourceChar.Archivable = originalArchivable

    if not clone then
        previewFrame.Visible = false
        return
    end

    -- Strip physics, active elements, and client-unsafe scripts
    for _, item in ipairs(clone:GetDescendants()) do
        if item:IsA("LuaSourceContainer") or item:IsA("Script") or item:IsA("LocalScript") then
            item:Destroy()
        elseif item:IsA("ForceField") then
            item:Destroy()
        elseif item:IsA("BasePart") then
            item.Anchored = true
            item.CanCollide = false
        end
    end

    clone.Parent = viewport
    currentClone = clone

    -- Anchor camera around target character's root frame
    local root = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChild("UpperTorso") or clone:FindFirstChild("Head")
    if root then
        local viewDistance = 7.5
        local viewHeightOffset = 0.5
        
        rotationAngle = 0
        rotationConnection = RunService.RenderStepped:Connect(function(dt)
            if not previewFrame.Visible or not clone or not clone.Parent then
                if rotationConnection then
                    rotationConnection:Disconnect()
                end
                return
            end
            -- Slowly orbit the camera in real time
            rotationAngle = rotationAngle + (dt * 35) 
            local rad = math.rad(rotationAngle)
            local offset = Vector3.new(math.sin(rad) * viewDistance, viewHeightOffset, math.cos(rad) * viewDistance)
            
            cam.CFrame = CFrame.new(root.Position + offset, root.Position + Vector3.new(0, viewHeightOffset, 0))
        end)
    end

    title.Text = "Live 3D View: " .. targetPlr.DisplayName
    previewFrame.Visible = true
end

---------------------------------------------------------
-- STARLIGHT WINDOW BUILD
---------------------------------------------------------

local Window = Starlight:CreateWindow({
    Name = "Premium Drip Stealer",
    Subtitle = "v6.0",
    Icon = NebulaIcons:GetIcon("style", "Material"),

    LoadingEnabled = true,
    LoadingSettings = {
        Title = "Drip Stealer Premium",
        Subtitle = "Initializing framework...",
    },

    FileSettings = {
        RootFolder = "DripStealer",
        ConfigFolder = "Premium",
        ThemesInRoot = true,
    },

    NotifyOnCallbackError = true,
    InterfaceAdvertisingPrompts = false,
})

-- Dashboard / Home Section (Hidden)
local HomeSection = Window:CreateTabSection("Home", false)
Window:CreateHomeTab({
    SupportedExecutors = {},
    UnsupportedExecutors = {},
    DiscordInvite = "",
    Backdrop = nil,
    IconStyle = 1,
    Changelog = {
        {
            Title = "Framework v6.0",
            Date = "2026",
            Description = "Ported custom UI over to Starlight Interface Suite with live viewport diagnostics.",
        },
    },
})

-- Tab Sections
local MainSection = Window:CreateTabSection("Main")
local SettingsSection = Window:CreateTabSection("Settings")

-- Tabs
local StealerTab = MainSection:CreateTab({
    Name = "Drip Stealer",
    Icon = NebulaIcons:GetIcon("face", "Material"),
    Columns = 2,
}, "StealerTab")

local SettingsTab = SettingsSection:CreateTab({
    Name = "Settings",
    Icon = NebulaIcons:GetIcon("settings", "Material"),
    Columns = 1,
}, "SettingsTab")

---------------------------------------------------------
-- UI ELEMENT LAYOUT DESIGN
---------------------------------------------------------

-- Column 1: Control Interfaces
local ControlsBox = StealerTab:CreateGroupbox({
    Name = "Controls",
    Icon = NebulaIcons:GetIcon("tune", "Material"),
    Column = 1,
}, "ControlsBox")

-- Target Profiling Container
local ProfileBox = StealerTab:CreateGroupbox({
    Name = "Selected Target Profile",
    Icon = NebulaIcons:GetIcon("account_box", "Material"),
    Column = 1,
}, "ProfileBox")

local InfoBox = StealerTab:CreateGroupbox({
    Name = "Status Logs",
    Icon = NebulaIcons:GetIcon("info", "Material"),
    Column = 1,
}, "InfoBox")

-- Column 2: Dynamic Players List
local ActivePlayersBox = StealerTab:CreateGroupbox({
    Name = "Active Players List",
    Icon = NebulaIcons:GetIcon("people", "Material"),
    Column = 2,
}, "ActivePlayersBox")

---------------------------------------------------------
-- PROFILE VISUALIZATION CONTROLS
---------------------------------------------------------

local SelectedNameLabel = ProfileBox:CreateLabel({
    Name = "Target: None selected",
    Icon = NebulaIcons:GetIcon("badge", "Material"),
}, "SelectedNameLabel")

local SelectedUserLabel = ProfileBox:CreateLabel({
    Name = "Username: N/A",
    Icon = NebulaIcons:GetIcon("alternate_email", "Material"),
}, "SelectedUserLabel")

ProfileBox:CreateButton({
    Name = "Open Real-time 3D View",
    Icon = NebulaIcons:GetIcon("visibility", "Material"),
    Tooltip = "Opens a live rendering window of the selected target",
    Callback = function()
        if targetPlayer then
            updateViewportCharacter(targetPlayer)
        else
            updateStatus("Select a valid target player profile first.", "Error")
        end
    end
}, "Open3DViewBtn")

-- Callback to refresh the viewport in case the target changes outfits
local function updateTargetMeta(plr)
    if not plr then
        SelectedNameLabel:Set({ Name = "Target: None selected" })
        SelectedUserLabel:Set({ Name = "Username: N/A" })
        return
    end

    SelectedNameLabel:Set({ Name = "Target: " .. plr.DisplayName })
    SelectedUserLabel:Set({ Name = "Username: @" .. plr.Name })
    
    if previewFrame.Visible then
        updateViewportCharacter(plr)
    end
end

---------------------------------------------------------
-- SYSTEM OPERATIONAL STATUS & LOGGER
---------------------------------------------------------

local StatusLabel = InfoBox:CreateLabel({
    Name = "Status: Ready",
    Icon = NebulaIcons:GetIcon("check_circle", "Material"),
}, "StatusLabel")

local CountLabel = InfoBox:CreateLabel({
    Name = "Players: 0/0",
    Icon = NebulaIcons:GetIcon("assessment", "Material"),
}, "CountLabel")

local LogParagraph = InfoBox:CreateParagraph({
    Name = "Recent Operations",
    Icon = NebulaIcons:GetIcon("article", "Material"),
    Content = "Waiting for action payloads...",
}, "LogParagraph")

local function updateStatus(text, statusType)
    local icon = "info"
    if statusType == "Success" then
        icon = "check_circle"
    elseif statusType == "Error" then
        icon = "error"
    end
    
    StatusLabel:Set({
        Name = "Status: " .. text,
        Icon = NebulaIcons:GetIcon(icon, "Material")
    })
    
    table.insert(logHistory, 1, "[" .. os.date("%X") .. "] " .. text)
    if #logHistory > 5 then
        table.remove(logHistory, 6)
    end
    
    LogParagraph:Set({
        Content = table.concat(logHistory, "\n")
    })
    
    notifCounter = notifCounter + 1
    Starlight:Notification({
        Title = "Drip Stealer",
        Icon = NebulaIcons:GetIcon(icon, "Material"),
        Content = text,
        Duration = 3,
    }, "DripNotif_" .. tostring(notifCounter))
end

local function updatePlayerCount()
    local total = #Players:GetPlayers()
    local tracked = 0
    for _ in pairs(playerButtons) do
        tracked = tracked + 1
    end
    CountLabel:Set({
        Name = "Players: " .. tostring(tracked) .. "/" .. tostring(total)
    })
end

---------------------------------------------------------
-- CORE LOGIC: CLOTHING SPOOFER
---------------------------------------------------------

local function stealDrip(plr)
    local charModel = workspace:FindFirstChild(plr.Name)
    local remote = ReplicatedStorage:FindFirstChild("WearOutfit")
    
    if charModel and remote then
        local success, err = pcall(function()
            remote:FireServer(charModel)
        end)
        
        if success then
            updateStatus("Stole drip successfully from @" .. plr.Name, "Success")
        else
            updateStatus("Remote error sequence: " .. tostring(err), "Error")
        end
    else
        updateStatus("Target character model or 'WearOutfit' event missing", "Error")
    end
end

---------------------------------------------------------
-- CONTROLS / TARGET DROPDOWN SELECTOR
---------------------------------------------------------

local TargetSelector = ControlsBox:CreateLabel({
    Name = "Target Selection Dropdown",
    Icon = NebulaIcons:GetIcon("person_search", "Material"),
}, "TargetSelectorLabel")

TargetSelector:AddDropdown({
    Special = 1, -- Built-in player-list selection indexer
    CurrentOption = {},
    Placeholder = "Select a player...",
    Callback = function(Options)
        local selectedName = Options[1]
        if selectedName then
            targetPlayer = Players:FindFirstChild(selectedName)
            updateTargetMeta(targetPlayer)
        else
            targetPlayer = nil
            updateTargetMeta(nil)
            previewFrame.Visible = false
        end
    end
}, "PlayerTargetDropdown")

ControlsBox:CreateButton({
    Name = "Steal From Target Profile",
    Icon = NebulaIcons:GetIcon("content_copy", "Material"),
    Tooltip = "Copies cosmetic elements from the profiled player",
    Callback = function()
        if targetPlayer then
            stealDrip(targetPlayer)
        else
            updateStatus("Select a valid target player profile first.", "Error")
        end
    end
}, "StealFromTargetBtn")

---------------------------------------------------------
-- DYNAMIC QUICK-ACTION PLAYER LIST
---------------------------------------------------------

local function addPlayerButton(plr)
    if plr == LocalPlayer then return end
    if playerButtons[plr.UserId] then return end

    local btnName = plr.DisplayName .. " (@" .. plr.Name .. ")"
    local btn = ActivePlayersBox:CreateButton({
        Name = btnName,
        Icon = NebulaIcons:GetIcon("person", "Material"),
        Tooltip = "Click to preview and copy " .. plr.DisplayName,
        Callback = function()
            targetPlayer = plr
            updateTargetMeta(plr)
            stealDrip(plr)
        end,
    }, "DripBtn_" .. tostring(plr.UserId))

    playerButtons[plr.UserId] = btn
    updatePlayerCount()
end

local function removePlayerButton(plr)
    if playerButtons[plr.UserId] then
        playerButtons[plr.UserId]:Destroy()
        playerButtons[plr.UserId] = nil
        updatePlayerCount()
    end
end

-- Assemble quick-action listing elements with staggered wait periods
for i, plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then
        task.spawn(function()
            task.wait(0.1 * (i % 5))
            addPlayerButton(plr)
        end)
    end
end

local playerAddedConn = Players.PlayerAdded:Connect(function(plr)
    task.wait(0.5)
    addPlayerButton(plr)
    updateStatus("Player logged in: @" .. plr.Name)
end)

local playerRemovingConn = Players.PlayerRemoving:Connect(function(plr)
    removePlayerButton(plr)
    updateStatus("Player logged out: @" .. plr.Name)
    if targetPlayer == plr then
        targetPlayer = nil
        updateTargetMeta(nil)
        previewFrame.Visible = false
    end
end)

---------------------------------------------------------
-- INTERFACE SETTINGS & THEMES
---------------------------------------------------------

local KeybindBox = SettingsTab:CreateGroupbox({
    Name = "Interface Control",
    Icon = NebulaIcons:GetIcon("keyboard", "Material"),
    Column = 1,
}, "KeybindBox")

local inputConnection = nil

local function hookToggle()
    if inputConnection then
        inputConnection:Disconnect()
    end
    inputConnection = UserInputService.InputEnded:Connect(function(input, processed)
        if input.KeyCode.Name == toggleKey and not processed then
            if Window.Instance then
                Window.Instance.Enabled = not Window.Instance.Enabled
            end
        end
    end)
end
hookToggle()

local KeybindLabel = KeybindBox:CreateLabel({
    Name = "Toggle Keybind Shortcut",
    Icon = NebulaIcons:GetIcon("vpn_key", "Material"),
}, "KeybindLabel")

KeybindLabel:AddBind({
    HoldToInteract = false,
    CurrentValue = "RightShift",
    SyncToggleState = false,
    Callback = function() end,
    OnChangedCallback = function(NewKey)
        toggleKey = tostring(NewKey)
        hookToggle()
    end
}, "UIKeybind")

-- Automatic configurations and native UI theme builders
SettingsTab:BuildConfigGroupbox(1)
Starlight:LoadAutoloadConfig()

SettingsTab:BuildThemeGroupbox(2)
Starlight:LoadAutoloadTheme()

Starlight:SetTheme("Starlight")

---------------------------------------------------------
-- SYSTEM ENGINE LOOPS
---------------------------------------------------------

-- Hide interface frames dynamically when local client views cutscenes
local lastCameraType = workspace.CurrentCamera.CameraType
local cameraConnection = RunService.RenderStepped:Connect(function()
    local currentCameraType = workspace.CurrentCamera.CameraType
    if currentCameraType ~= lastCameraType then
        lastCameraType = currentCameraType
        if Window.Instance then
            Window.Instance.Visible = currentCameraType ~= Enum.CameraType.Scriptable
        end
    end
end)

-- Garbage collection processes
Starlight:OnDestroy(function()
    if cameraConnection then cameraConnection:Disconnect() end
    if inputConnection then inputConnection:Disconnect() end
    if playerAddedConn then playerAddedConn:Disconnect() end
    if playerRemovingConn then playerRemovingConn:Disconnect() end
    if rotationConnection then rotationConnection:Disconnect() end
    if viewportGui then viewportGui:Destroy() end
end)

updateStatus("Drip Stealer Suite initialized.", "Success")
