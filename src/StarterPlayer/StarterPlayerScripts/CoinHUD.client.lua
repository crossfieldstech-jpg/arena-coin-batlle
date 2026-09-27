local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 210, 0, 96)
panel.Position = UDim2.new(1, -230, 0, 18)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
panel.BackgroundTransparency = 0.18
panel.BorderSizePixel = 0
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
countLabel.Font = Enum.Font.GothamSemibold
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
gemTitle.Parent = panel

local gemCountLabel = Instance.new("TextLabel")
gemCountLabel.Name = "GemCount"
gemCountLabel.Size = UDim2.new(1, -20, 0, 20)
gemCountLabel.Position = UDim2.new(0, 10, 0, 66)
gemCountLabel.BackgroundTransparency = 1
gemCountLabel.Font = Enum.Font.GothamSemibold
gemCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
gemCountLabel.TextSize = 20
gemCountLabel.TextXAlignment = Enum.TextXAlignment.Left
gemCountLabel.Parent = panel

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
