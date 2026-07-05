-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Aggressive Cleanup Hook (Destroys any cached/running Syde UIs first to prevent clashing)
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

-- Branding Customization (Removed default logo to prevent autofarm text display)
syde:Load({
    Name = "Rixware",
    Status = "Stable",
    Accent = Color3.fromRGB(54, 57, 241),
    HitBox = Color3.fromRGB(54, 57, 241),
    AutoLoad = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Rixware_Configs",
        FileName = "settings"
    }
})

local Config = {
    UiToggleKey = Enum.KeyCode.RightControl,
}

-- Helper notifications
local function notify(title, content, duration)
    syde:Notify({
        Title = title,
        Content = content,
        Duration = duration or 2
    })
end

-- Safe UI API Wrappers to dynamically adjust across Syde updates & Prevent any Nil value crashes
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
    return success and result or nil
end

local function addDropdown(tab, title, options, placeholder, multi, callback)
    if not tab then return nil end
    local method = tab.Dropdown or tab.AddDropdown or tab.CreateDropdown
    if not method then return nil end
    local success, result = pcall(function()
        return method(tab, {
            Title = title,
            Options = options,
            PlaceHolder = placeholder or "Select...",
            Multi = multi or false,
            CallBack = callback
        })
    end)
    return success and result or nil
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
    return success and result or nil
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
    return success and result or nil
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
    Title = "Rixware",
    SubText = "Public Beta • v0.8.4"
})
assert(Window, "Syde failed to initialize Window")

local function requireTab(tab, name)
    assert(tab, "Syde failed to create tab: " .. name)
    return tab
end

-- Table-based Tab Initialization (Fixed incorrect string initialization calls) [1]
local UniversalTab = requireTab(Window:InitTab({ Title = "Universal Hub" }), "Universal Hub")
local GameSpecificTab = requireTab(Window:InitTab({ Title = "Game Specific Hub" }), "Game Specific Hub")
local SettingsTab = requireTab(Window:InitTab({ Title = "Settings" }), "Settings")

-- ==========================================
-- UNIVERSAL HUB TAB
-- ==========================================
addSection(CombatTab or UniversalTab or CombatTab or CombatTab, "Universal Framework Modules")

addButton(UniversalTab, "Aimbotzz BETA", "Execute and load the development build of the aimbot suite.", function()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/richijsLV/Scripts/refs/heads/main/Universal/AimbotzzBETA.lua"))()
    end)
    if success then
        notify("Loaded Aimbotzz BETA", "The development module compiled successfully.", 3)
    else
        notify("Loading Failed", "Aimbotzz BETA execution failed: " .. tostring(err), 4)
    end
end)

addButton(UniversalTab, "Aimbotzz STABLE", "Execute and load the finalized stable aimbot framework.", function()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/richijsLV/Scripts/refs/heads/main/Universal/Aimbotzz.lua"))()
    end)
    if success then
        notify("Loaded Aimbotzz STABLE", "The stable combat suite compiled successfully.", 3)
    else
        notify("Loading Failed", "Aimbotzz STABLE execution failed: " .. tostring(err), 4)
    end
end)

addButton(UniversalTab, "Gamepass Spoofer BETA", "Execute and load the beta gamepass/product spoofer simulation.", function()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://github.com/richijsLV/Scripts/raw/refs/heads/main/Universal/Product_Faker_BETA.lua"))()
    end)
    if success then
        notify("Loaded Gamepass Spoofer", "The product spoofer beta executed successfully.", 3)
    else
        notify("Loading Failed", "Product Spoofer execution failed: " .. tostring(err), 4)
    end
end)

addButton(UniversalTab, "Graphics Hub", "Can change ambience, animations, realism or just for more FPS...", function()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://github.com/richijsLV/Scripts/raw/refs/heads/main/Universal/GraphicsHub.lua"))()
    end)
    if success then
        notify("Loaded Graphics Hub", "The Graphics Hub executed successfully.", 3)
    else
        notify("Loading Failed", "Graphics Hubs execution failed: " .. tostring(err), 4)
    end
end)

-- ==========================================
-- GAME SPECIFIC HUB TAB
-- ==========================================
addSection(GameSpecificTab, "Development Status")
GameSpecificTab:Paragraph({
    Title = "Features Coming Soon",
    Content = "Game-specific configurations, bypasses, and targeted script modules are currently under active development and will be released in an upcoming update."
})

-- ==========================================
-- SETTINGS TAB
-- ==========================================

addSection(SettingsTab, "App Control Binds")
addKeybind(SettingsTab, "UI Open/Minimize Key", Config.UiToggleKey, function()
    window.Minimized = not window.Minimized
end)

SettingsTab:Paragraph({
    Title = "Rixware Hub",
    Content = "Public Beta • v0.8.4"
})

notify("Rixware Loaded", "Public Beta • v0.8.4", 3)

syde:LoadSaveConfig()
