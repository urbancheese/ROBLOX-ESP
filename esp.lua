local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local ESPObjects = {}

-- Settings
local espSettings = {
    teamColor = Color3.fromRGB(0, 255, 0),
    enemyColor = Color3.fromRGB(255, 0, 0),
    highlightColor = Color3.fromRGB(0, 0, 255),
    showHealth = true,
    maxDistance = 1000, -- Maximum distance to show ESP
    proximityAlertDistance = 50, -- Distance to trigger proximity alert
    showProximityAlert = true,
    playSoundOnAlert = true,
    enabled = true
}

-- Sound notification setup
local alertSound = Instance.new("Sound")
alertSound.SoundId = "rbxassetid://12222242" -- Example sound ID, replace with actual
alertSound.Volume = 1
alertSound.Parent = game.CoreGui

local function createESP(player)
    local espBox = Drawing.new("Square")
    local espName = Drawing.new("Text")
    local tracer = Drawing.new("Line")
    local healthBar = Drawing.new("Line")

    espBox.Thickness = 2
    espBox.Transparency = 1
    espBox.Filled = false

    espName.Size = 16
    espName.Center = true
    espName.Outline = true
    espName.OutlineColor = Color3.fromRGB(0, 0, 0)

    tracer.Thickness = 1
    tracer.Transparency = 1

    healthBar.Thickness = 2
    healthBar.Transparency = 1

    ESPObjects[player] = {espBox = espBox, espName = espName, tracer = tracer, healthBar = healthBar}
end

local function updateESP()
    if not espSettings.enabled then
        for _, objects in pairs(ESPObjects) do
            objects.espBox.Visible = false
            objects.espName.Visible = false
            objects.tracer.Visible = false
            objects.healthBar.Visible = false
        end
        return
    end

    for player, objects in pairs(ESPObjects) do
        local success, err = pcall(function()
            if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") and player.Character:FindFirstChild("Humanoid") then
                local rootPart = player.Character.HumanoidRootPart
                local head = player.Character.Head
                local humanoid = player.Character.Humanoid
                local rootPosition, onScreen = workspace.CurrentCamera:WorldToViewportPoint(rootPart.Position)
                local headPosition = workspace.CurrentCamera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))

                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).magnitude
                if onScreen and distance <= espSettings.maxDistance then
                    objects.espBox.Size = Vector2.new(2000 / rootPosition.Z, (headPosition.Y - rootPosition.Y) * 2)
                    objects.espBox.Position = Vector2.new(rootPosition.X - objects.espBox.Size.X / 2, rootPosition.Y - objects.espBox.Size.Y / 2)
                    objects.espBox.Visible = true

                    if player.TeamColor == LocalPlayer.TeamColor then
                        objects.espBox.Color = espSettings.teamColor
                        objects.espName.Color = espSettings.teamColor
                        objects.tracer.Color = espSettings.teamColor
                        objects.healthBar.Color = espSettings.teamColor
                    else
                        objects.espBox.Color = espSettings.enemyColor
                        objects.espName.Color = espSettings.enemyColor
                        objects.tracer.Color = espSettings.enemyColor
                        objects.healthBar.Color = espSettings.enemyColor

                        if distance <= espSettings.proximityAlertDistance and espSettings.showProximityAlert then
                            objects.espBox.Color = espSettings.highlightColor
                            objects.espName.Color = espSettings.highlightColor
                            objects.tracer.Color = espSettings.highlightColor
                            objects.healthBar.Color = espSettings.highlightColor

                            if espSettings.playSoundOnAlert then
                                alertSound:Play()
                            end
                        end
                    end

                    objects.espName.Position = Vector2.new(rootPosition.X, rootPosition.Y - objects.espBox.Size.Y / 2 - 15)
                    objects.espName.Text = player.Name .. " [" .. math.floor(distance) .. " studs]"
                    objects.espName.Visible = true

                    objects.tracer.From = Vector2.new(workspace.CurrentCamera.ViewportSize.X / 2, workspace.CurrentCamera.ViewportSize.Y)
                    objects.tracer.To = Vector2.new(rootPosition.X, rootPosition.Y)
                    objects.tracer.Visible = true

                    if espSettings.showHealth then
                        local healthPercent = humanoid.Health / humanoid.MaxHealth
                        objects.healthBar.From = Vector2.new(rootPosition.X - objects.espBox.Size.X / 2 - 5, rootPosition.Y + objects.espBox.Size.Y / 2)
                        objects.healthBar.To = Vector2.new(objects.healthBar.From.X, objects.healthBar.From.Y - (objects.espBox.Size.Y * healthPercent))
                        objects.healthBar.Visible = true
                    else
                        objects.healthBar.Visible = false
                    end
                else
                    objects.espBox.Visible = false
                    objects.espName.Visible = false
                    objects.tracer.Visible = false
                    objects.healthBar.Visible = false
                end
            else
                objects.espBox.Visible = false
                objects.espName.Visible = false
                objects.tracer.Visible = false
                objects.healthBar.Visible = false
            end
        end)
        if not success then
            warn("Error updating ESP for player " .. player.Name .. ": " .. err)
        end
    end
end

local function createBoundingBox(player)
    local box = Instance.new("BoxHandleAdornment")
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Color3 = Color3.new(1, 0, 0)
    box.Transparency = 0.7
    box.Size = player.Character:GetExtentsSize()
    box.Adornee = player.Character
    box.Parent = game.CoreGui
    return box
end

local function notifyPlayerInOut(player, entering)
    local message = entering and "entered" or "exited"
    print(player.Name .. " has " .. message .. " your view.")
end

local function onPlayerAdded(player)
    if player ~= LocalPlayer then
        createESP(player)
        player.CharacterAdded:Connect(function()
            createESP(player)
        end)
        
        local box = createBoundingBox(player)
        ESPObjects[player].boundingBox = box

        player:GetPropertyChangedSignal("TeamColor"):Connect(function()
            if player.TeamColor == LocalPlayer.TeamColor then
                box.Color3 = espSettings.teamColor
            else
                box.Color3 = espSettings.enemyColor
            end
        end)
        
        local enteredView = false
        RunService.RenderStepped:Connect(function()
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local _, onScreen = workspace.CurrentCamera:WorldToViewportPoint(rootPart.Position)
                if onScreen and not enteredView then
                    notifyPlayerInOut(player, true)
                    enteredView = true
                elseif not onScreen and enteredView then
                    notifyPlayerInOut(player, false)
                    enteredView = false
                end
            end
        end)
    end
end

local function onPlayerRemoving(player)
    if ESPObjects[player] then
        ESPObjects[player].espBox:Remove()
        ESPObjects[player].espName:Remove()
        ESPObjects[player].tracer:Remove()
        ESPObjects[player].healthBar:Remove()
        if ESPObjects[player].boundingBox then
            ESPObjects[player].boundingBox:Destroy()
        end
        ESPObjects[player] = nil
    end
end

local function initializeESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createESP(player)
            local box = createBoundingBox(player)
            ESPObjects[player].boundingBox = box

            player:GetPropertyChangedSignal("TeamColor"):Connect(function()
                if player.TeamColor == LocalPlayer.TeamColor then
                    box.Color3 = espSettings.teamColor
                else
                    box.Color3 = espSettings.enemyColor
                end
            end)
        end
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    RunService.RenderStepped:Connect(updateESP)
end

initializeESP()

-- Create a refined GUI for settings
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 300, 0, 250)
Frame.Position = UDim2.new(0, 10, 0, 10)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BackgroundTransparency = 0.5
Frame.BorderSizePixel = 0

local UIListLayout = Instance.new("UIListLayout", Frame)
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.Padding = UDim.new(0, 5)

local function createLabel(text)
    local label = Instance.new("TextLabel", Frame)
    label.Text = text
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextScaled = true
    return label
end

local function createToggle(text, setting)
    local toggleButton = Instance.new("TextButton", Frame)
    toggleButton.Size = UDim2.new(1, 0, 0, 25)
    toggleButton.BackgroundTransparency = 0.5
    toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    toggleButton.Text = text .. ": " .. (espSettings[setting] and "ON" or "OFF")
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.SourceSans
    toggleButton.TextScaled = true

    toggleButton.MouseButton1Click:Connect(function()
        espSettings[setting] = not espSettings[setting]
        toggleButton.Text = text .. ": " .. (espSettings[setting] and "ON" or "OFF")
    end)
end

createLabel("ESP Settings")
createToggle("Show Health", "showHealth")
createToggle("Show Proximity Alert", "showProximityAlert")
createToggle("Play Sound on Alert", "playSoundOnAlert")
createToggle("ESP Enabled", "enabled")

local distanceSliderLabel = createLabel("Max Distance: " .. espSettings.maxDistance)
local distanceSlider = Instance.new("TextButton", Frame)
distanceSlider.Size = UDim2.new(1, 0, 0, 25)
distanceSlider.BackgroundTransparency = 0.5
distanceSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
distanceSlider.Text = "Adjust Distance"
distanceSlider.TextColor3 = Color3.fromRGB(255, 255, 255)
distanceSlider.Font = Enum.Font.SourceSans
distanceSlider.TextScaled = true

distanceSlider.MouseButton1Click:Connect(function()
    local input = tonumber(game:GetService("Players").LocalPlayer:InputBox("Enter Max Distance", "Distance", espSettings.maxDistance))
    if input then
        espSettings.maxDistance = input
        distanceSliderLabel.Text = "Max Distance: " .. espSettings.maxDistance
    end
end)

local proximitySliderLabel = createLabel("Proximity Alert Distance: " .. espSettings.proximityAlertDistance)
local proximitySlider = Instance.new("TextButton", Frame)
proximitySlider.Size = UDim2.new(1, 0, 0, 25)
proximitySlider.BackgroundTransparency = 0.5
proximitySlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
proximitySlider.Text = "Adjust Proximity Distance"
proximitySlider.TextColor3 = Color3.fromRGB(255, 255, 255)
proximitySlider.Font = Enum.Font.SourceSans
proximitySlider.TextScaled = true

proximitySlider.MouseButton1Click:Connect(function()
    local input = tonumber(game:GetService("Players").LocalPlayer:InputBox("Enter Proximity Distance", "Distance", espSettings.proximityAlertDistance))
    if input then
        espSettings.proximityAlertDistance = input
        proximitySliderLabel.Text = "Proximity Alert Distance: " .. espSettings.proximityAlertDistance
    end
end)