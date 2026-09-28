local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 210, 0, 52)
panel.Position = UDim2.new(1, -230, 0, 18)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
panel.BackgroundTransparency = 0.18
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 0, 18)
title.Position = UDim2.new(0, 10, 0, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Coins"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local countLabel = Instance.new("TextLabel")
countLabel.Name = "Count"
countLabel.Size = UDim2.new(1, -20, 0, 20)
countLabel.Position = UDim2.new(0, 10, 0, 24)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamMedium
countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countLabel.TextSize = 20
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = panel

local gemTitle = Instance.new("TextLabel")
gemTitle.Name = "GemTitle"
gemTitle.Size = UDim2.new(1, -20, 0, 18)
gemTitle.Position = UDim2.new(0, 10, 0, 48)
gemTitle.BackgroundTransparency = 1
gemTitle.Font = Enum.Font.GothamBold
gemTitle.Text = "Gems"
gemTitle.TextColor3 = Color3.fromRGB(80, 220, 255)
gemTitle.TextSize = 16
gemTitle.TextXAlignment = Enum.TextXAlignment.Left
gemTitle.Visible = false
gemTitle.Parent = panel

local gemCountLabel = Instance.new("TextLabel")
gemCountLabel.Name = "GemCount"
gemCountLabel.Size = UDim2.new(1, -20, 0, 20)
gemCountLabel.Position = UDim2.new(0, 10, 0, 66)
gemCountLabel.BackgroundTransparency = 1
gemCountLabel.Font = Enum.Font.GothamMedium
gemCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
gemCountLabel.TextSize = 20
gemCountLabel.TextXAlignment = Enum.TextXAlignment.Left
gemCountLabel.Visible = false
gemCountLabel.Parent = panel

local function updateRoundVisibility(coinSettings)
	local isGemRound = false
	if coinSettings then
		isGemRound = coinSettings:GetAttribute("IsGemRound") == true
	end

	if isGemRound then
		gemTitle.Visible = true
		gemCountLabel.Visible = true
		panel.Size = UDim2.new(0, 210, 0, 96)
	else
		gemTitle.Visible = false
		gemCountLabel.Visible = false
		panel.Size = UDim2.new(0, 210, 0, 52)
	end
end

task.spawn(function()
	local coinSettings = ReplicatedStorage:WaitForChild("CoinSettings", 10)
	if coinSettings then
		updateRoundVisibility(coinSettings)
		coinSettings:GetAttributeChangedSignal("IsGemRound"):Connect(function()
			updateRoundVisibility(coinSettings)
		end)
		coinSettings:GetAttributeChangedSignal("CurrentRoundItemType"):Connect(function()
			updateRoundVisibility(coinSettings)
		end)
	end
end)

-- Proximity fade: fade CoinHUD when far from any player base
local RunService = game:GetService("RunService")

local basePositions = {}
local function refreshBasePositions()
	basePositions = {}
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("Model") and string.match(desc.Name or "", "^PlayerBase_") then
			table.insert(basePositions, desc:GetPivot().Position)
		end
	end
end

task.spawn(function()
	while true do
		refreshBasePositions()
		task.wait(3)
	end
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local nearest = math.huge
	for _, pos in ipairs(basePositions) do
		local dist = (pos - root.Position).Magnitude
		if dist < nearest then
			nearest = dist
		end
	end

	-- Visible within 30 studs, fades to 30% opacity at 60+ studs
	local alpha
	if nearest <= 30 then
		alpha = 1
	elseif nearest >= 60 then
		alpha = 0.3
	else
		alpha = 1 - (nearest - 30) / 30 * 0.7
	end

	panel.BackgroundTransparency = 1 - alpha * 0.82
	title.TextTransparency = 1 - alpha
	countLabel.TextTransparency = 1 - alpha
	gemTitle.TextTransparency = 1 - alpha
	gemCountLabel.TextTransparency = 1 - alpha
end)

local function formatNumber(val)
	if not val then
		return "0"
	end
	return math.floor(val) == val and string.format("%d", val) or string.format("%.1f", val)
end

local function updateCounter()
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		countLabel.Text = "0"
		gemCountLabel.Text = "0"
		return
	end

	local coinValue = leaderstats:FindFirstChild("Coins")
	if coinValue then
		countLabel.Text = formatNumber(coinValue.Value)
	else
		countLabel.Text = "0"
	end

	local gemValue = leaderstats:FindFirstChild("Gems")
	if gemValue then
		gemCountLabel.Text = formatNumber(gemValue.Value)
	else
		gemCountLabel.Text = "0"
	end
end

local leaderstats = player:WaitForChild("leaderstats", 5)
if leaderstats then
	local coinValue = leaderstats:FindFirstChild("Coins")
	if coinValue then
		coinValue:GetPropertyChangedSignal("Value"):Connect(updateCounter)
	end
	local gemValue = leaderstats:FindFirstChild("Gems")
	if gemValue then
		gemValue:GetPropertyChangedSignal("Value"):Connect(updateCounter)
	end
	leaderstats.ChildAdded:Connect(function(child)
		if child.Name == "Coins" or child.Name == "Gems" then
			child:GetPropertyChangedSignal("Value"):Connect(updateCounter)
		end
		updateCounter()
	end)
end

updateCounter()
