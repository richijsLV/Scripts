local function importRelease(owner, repo, version, file)
    local tag = (version == "latest" and "latest/download" or "download/" .. version)
    return loadstring(game:HttpGetAsync(("https://github.com/%s/%s/releases/%s/%s"):format(owner, repo, tag, file)), file)()
end

local cascade = importRelease("cascadeui", "Cascade", "latest", "dist.luau")

local function titledRow(parent, title, subtitle)
    local row = parent:Row({
        SearchIndex = title,
    })
    row:Left():TitleStack({
        Title = title,
        Subtitle = subtitle,
    })
    return row
end

local app = cascade.New({
    WindowPill = true,
    Theme = cascade.Themes.Dark,
    Accent = cascade.Accents.Blue,
})

local window = app:Window({
    Title = "Product Faker BETA",
    Subtitle = "DevProduct Emulator",
    Size = UDim2.fromOffset(700, 520),
    Draggable = true,
    Resizable = true,
    Searching = true,
    CanExit = true,
    CanMinimize = true,
    CanZoom = true,
    Dropshadow = true,
    UIBlur = false,
})

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local success, developerProducts = pcall(function()
    return MarketplaceService:GetDeveloperProductsAsync():GetCurrentPage()
end)

if not success or not developerProducts then 
    developerProducts = {} 
end

local simulationDelay = 0.1
local simulateSuccess = true

local mainSection = window:Section({
    Title = "Emulator Tools",
    Disclosure = false,
})

local productsTab = mainSection:Tab({
    Selected = true,
    Title = "Discovery",
    Icon = cascade.Symbols.squareStack3dUp,
})

local manualTab = mainSection:Tab({
    Title = "Manual Spoof",
    Icon = cascade.Symbols.house,
})

local toolsTab = mainSection:Tab({
    Title = "Exporter",
    Icon = cascade.Symbols.sunMax,
})

local settingsSection = window:Section({
    Title = "Configuration",
    Disclosure = false,
})

local settingsTab = settingsSection:Tab({
    Title = "Customizer",
    Icon = cascade.Symbols.gear,
})

local globalSection = productsTab:PageSection({
    Title = "Global Controller",
    Subtitle = "Execute batch emulations and simulation criteria.",
})
local globalForm = globalSection:Form()

local globalRow = globalForm:Row({
    SearchIndex = "Simulate Buy All",
})

globalRow:Left():TitleStack({
    Title = "Simulate Buy All",
    Subtitle = "Triggers mock purchase confirmations for all discovered assets.",
})

globalRow:Right():Button({
    Label = "Buy All (" .. #developerProducts .. ")",
    State = "Primary",
    Pushed = function(self)
        app:Notification({
            App = "Product Faker",
            Title = "Executing Simulation",
            Subtitle = "Running " .. #developerProducts .. " simulations...",
            Duration = 2,
        })
        for _, devProduct in ipairs(developerProducts) do
            MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, devProduct.ProductId, simulateSuccess)
            task.wait(0.01)
        end
        app:Notification({
            App = "Product Faker",
            Title = "Simulation Done",
            Subtitle = "Processed all loaded product purchases.",
            Duration = 2,
        })
    end,
})

local simSettingsForm = globalSection:Form()

local delayRow = titledRow(simSettingsForm, "Loop Interval", "Adjust rate limit for automated buy tasks.")
delayRow:Right():Slider({
    Minimum = 0.05,
    Maximum = 5,
    Value = 0.1,
    ValueChanged = function(self, value)
        simulationDelay = value
    end,
})

local successRow = titledRow(simSettingsForm, "Mock Transaction Result", "Toggle simulated receipt transaction state.")
successRow:Right():Toggle({
    Value = true,
    ValueChanged = function(self, value)
        simulateSuccess = value
    end,
})

local listSection = productsTab:PageSection({
    Title = "Discovered Products",
    Subtitle = "Interact with active developer product listings.",
})
local listForm = listSection:Form()

if #developerProducts == 0 then
    local emptyRow = listForm:Row({ SearchIndex = "Empty" })
    emptyRow:Left():TitleStack({
        Title = "No Listings Detected",
        Subtitle = "Developer products could not be scanned in this instance.",
    })
else
    for _, product in ipairs(developerProducts) do
        local name = product.Name or "Unknown Product"
        local id = product.ProductId or 0
        local price = product.PriceInRobux or 0

        local itemRow = listForm:Row({
            SearchIndex = name .. " " .. tostring(id),
        })
        itemRow:Left():TitleStack({
            Title = name,
            Subtitle = "ID: " .. tostring(id) .. " • Price: " .. tostring(price) .. " Robux",
        })

        local actions = itemRow:Right():HStack({
            Padding = UDim.new(0, 8),
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment = Enum.VerticalAlignment.Center,
        })

        actions:Button({
            Label = "Copy ID",
            State = "Secondary",
            Pushed = function(self)
                if setclipboard then
                    setclipboard(tostring(id))
                    app:Notification({
                        App = "Product Faker",
                        Title = "ID Copied",
                        Subtitle = tostring(id) .. " added to clipboard.",
                        Duration = 2,
                    })
                end
            end,
        })

        actions:Button({
            Label = "Buy",
            State = "Primary",
            Pushed = function(self)
                MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, id, simulateSuccess)
                app:Notification({
                    App = "Product Faker",
                    Title = "Simulated Buy",
                    Subtitle = "Signaled prompt finished for product: " .. tostring(id),
                    Duration = 2,
                })
            end,
        })

        actions:Label({
            Text = "Auto:",
        })

        local active = false
        local thread = nil
        actions:Toggle({
            Value = false,
            ValueChanged = function(self, value)
                active = value
                if active then
                    thread = task.spawn(function()
                        while active do
                            MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, id, simulateSuccess)
                            task.wait(simulationDelay)
                        end
                    end)
                else
                    if thread then
                        task.cancel(thread)
                        thread = nil
                    end
                end
            end,
        })
    end
end

local manualSection = manualTab:PageSection({
    Title = "Manual Injection",
    Subtitle = "Manually simulate prompt success for raw product keys.",
})
local manualForm = manualSection:Form()

local customId = 0

local idRow = titledRow(manualForm, "Target Product ID", "Specify a custom developer product ID to target.")
idRow:Right():TextField({
    Placeholder = "Product ID",
    Value = "",
    TextChanged = function(self, text)
        local parsed = tonumber(text)
        if parsed then
            customId = parsed
        end
    end,
    ValueChanged = function(self, text)
        local parsed = tonumber(text)
        if parsed then
            customId = parsed
        end
    end,
})

local execRow = titledRow(manualForm, "Execute Spoof", "Trigger fake transaction using targeted ID.")
execRow:Right():Button({
    Label = "Spoof Purchase",
    State = "Primary",
    Pushed = function(self)
        if customId > 0 then
            MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, customId, simulateSuccess)
            app:Notification({
                App = "Product Faker",
                Title = "Spoofed Key",
                Subtitle = "Dispatched callback sequence for manual product key: " .. tostring(customId),
                Duration = 3,
            })
        else
            app:Notification({
                App = "Product Faker",
                Title = "Action Denied",
                Subtitle = "Provide a valid numeric product ID before executing.",
                Duration = 3,
            })
        end
    end,
})

local autoCustomActive = false
local autoCustomThread = nil
local autoCustomRow = titledRow(manualForm, "Automated Manual Spoof", "Repeatedly simulate buy sequences for specified target.")
autoCustomRow:Right():Toggle({
    Value = false,
    ValueChanged = function(self, value)
        autoCustomActive = value
        if autoCustomActive then
            if customId > 0 then
                autoCustomThread = task.spawn(function()
                    while autoCustomActive do
                        MarketplaceService:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, customId, simulateSuccess)
                        task.wait(simulationDelay)
                    end
                end)
                app:Notification({
                    App = "Product Faker",
                    Title = "Manual Loop Started",
                    Subtitle = "Repeating spoof for ID " .. tostring(customId),
                    Duration = 2,
                })
            else
                self.Value = false
                autoCustomActive = false
                app:Notification({
                    App = "Product Faker",
                    Title = "Action Denied",
                    Subtitle = "Specify product ID prior to loop startup.",
                    Duration = 2,
                })
            end
        else
            if autoCustomThread then
                task.cancel(autoCustomThread)
                autoCustomThread = nil
            end
        end
    end,
})

local toolsSection = toolsTab:PageSection({
    Title = "Export Utilities",
    Subtitle = "Extract discovered developer product datasets.",
})
local toolsForm = toolsSection:Form()

local formatRow = titledRow(toolsForm, "Data Output Format", "Choose notation format when exporting products.")
local selectedFormatIndex = 1
formatRow:Right():PopUpButton({
    Options = { "JSON Object", "Lua Table String", "Key List (Raw)" },
    Value = 1,
    ValueChanged = function(self, value)
        selectedFormatIndex = value
    end,
})

local function formatData()
    if selectedFormatIndex == 1 then
        local entries = {}
        for _, item in ipairs(developerProducts) do
            table.insert(entries, string.format('{"name": "%s", "id": %d, "price": %d}', item.Name or "Unknown", item.ProductId or 0, item.PriceInRobux or 0))
        end
        return "[\n  " .. table.concat(entries, ",\n  ") .. "\n]"
    elseif selectedFormatIndex == 2 then
        local entries = {}
        for _, item in ipairs(developerProducts) do
            table.insert(entries, string.format('    {Name = "%s", ProductId = %d, PriceInRobux = %d}', item.Name or "Unknown", item.ProductId or 0, item.PriceInRobux or 0))
        end
        return "return {\n" .. table.concat(entries, ",\n") .. "\n}"
    else
        local entries = {}
        for _, item in ipairs(developerProducts) do
            table.insert(entries, tostring(item.ProductId or 0))
        end
        return table.concat(entries, "\n")
    end
end

local consoleRow = titledRow(toolsForm, "Console Dump", "Print formatted datasets inside local F9 diagnostic utility.")
consoleRow:Right():Button({
    Label = "Dump Data",
    State = "Secondary",
    Pushed = function(self)
        local data = formatData()
        print(data)
        app:Notification({
            App = "Product Faker",
            Title = "Export Complete",
            Subtitle = "Data has been outputted to local print channels (F9).",
            Duration = 3,
        })
    end,
})

local fileRow = titledRow(toolsForm, "Local Storage Export", "Write file structure directly to disk directory.")
fileRow:Right():Button({
    Label = "Export File",
    State = "Secondary",
    Pushed = function(self)
        if writefile then
            local ext = selectedFormatIndex == 1 and "json" or selectedFormatIndex == 2 and "lua" or "txt"
            local filepath = "products_dump." .. ext
            local data = formatData()
            writefile(filepath, data)
            app:Notification({
                App = "Product Faker",
                Title = "Disk Output Success",
                Subtitle = "Written data safely to " .. filepath,
                Duration = 3,
            })
        else
            app:Notification({
                App = "Product Faker",
                Title = "Environment Warning",
                Subtitle = "Disk operations (writefile) unsupported in current context.",
                Duration = 3,
            })
        end
    end,
})

local customizeSection = settingsTab:PageSection({
    Title = "Visual Customizer",
    Subtitle = "Tweak display layout and decoration parameters.",
})
local customizationForm = customizeSection:Form()

titledRow(customizationForm, "Theme Toggle", "Toggle dark interface appearance."):Right():Toggle({
    Value = app.Theme == cascade.Themes.Dark,
    ValueChanged = function(self, value)
        app.Theme = value and cascade.Themes.Dark or cascade.Themes.Light
    end,
})

titledRow(customizationForm, "Gaussian UI Blur", "Apply glassmorphism effects to main panel."):Right():Toggle({
    Value = window.UIBlur,
    ValueChanged = function(self, value)
        window.UIBlur = value
    end,
})

local accentNames = { "Blue", "Red", "Orange", "Yellow", "Green", "Graphite", "Pink", "Purple" }
local accentEnums = {
    cascade.Accents.Blue, cascade.Accents.Red, cascade.Accents.Orange, cascade.Accents.Yellow,
    cascade.Accents.Green, cascade.Accents.Graphite, cascade.Accents.Pink, cascade.Accents.Purple
}

local accentRow = titledRow(customizationForm, "Color Accent", "Select active color styling layout.")
accentRow:Right():PopUpButton({
    Options = accentNames,
    Value = 1,
    ValueChanged = function(self, value)
        app.Accent = accentEnums[value]
    end,
})

titledRow(customizationForm, "Searching Feature", "Keep lookup field visible on titlebar."):Right():Toggle({
    Value = window.Searching,
    ValueChanged = function(self, value)
        window.Searching = value
    end,
})

titledRow(customizationForm, "Draggable Panel", "Allow mouse drag window shifting."):Right():Toggle({
    Value = window.Draggable,
    ValueChanged = function(self, value)
        window.Draggable = value
    end,
})

titledRow(customizationForm, "Resizable Window", "Determine manual resizing controls availability."):Right():Toggle({
    Value = window.Resizable,
    ValueChanged = function(self, value)
        window.Resizable = value
    end,
})

local inputForm = settingsTab:PageSection({
    Title = "Input Settings",
    Subtitle = "Map control sequences and trigger actions.",
}):Form()

local toggleKey = Enum.KeyCode.RightControl
local inputConnection = nil

local function hookToggle()
    if inputConnection then
        inputConnection:Disconnect()
    end
    inputConnection = UserInputService.InputEnded:Connect(function(input, processed)
        if input.KeyCode == toggleKey and not processed then
            window.Minimized = not window.Minimized
        end
    end)
end
hookToggle()

local bindRow = titledRow(inputForm, "Toggle Keybind", "Sets shortcut to show or hide main panel interface.")
bindRow:Right():KeybindField({
    Value = toggleKey,
    ValueChanged = function(self, value)
        toggleKey = value
        hookToggle()
    end,
})

app:Notification({
    App = "Product Faker",
    Title = "Loaded",
    Subtitle = "Scanned " .. #developerProducts .. " developer products successfully.",
    Duration = 3,
})
