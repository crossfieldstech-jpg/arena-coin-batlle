local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CoinHud"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 210, 0, 64)
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
title.Size = UDim2.new(1, -20, 0, 22)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Coins"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local countLabel = Instance.new("TextLabel")
countLabel.Name = "Count"
countLabel.Size = UDim2.new(1, -20, 0, 22)
countLabel.Position = UDim2.new(0, 10, 0, 32)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamSemibold
countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
countLabel.TextSize = 22
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = panel

local function updateCounter()

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
end)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		countLabel.Text = "0"
		return
	end

	local coinValue = leaderstats:FindFirstChild("Coins")
	if coinValue then
		countLabel.Text = tostring(coinValue.Value)
	else
		countLabel.Text = "0"
	end
end

local leaderstats = player:WaitForChild("leaderstats", 5)
if leaderstats then
	local coinValue = leaderstats:FindFirstChild("Coins")
	if coinValue then
		coinValue:GetPropertyChangedSignal("Value"):Connect(updateCounter)
	end
	leaderstats.ChildAdded:Connect(function(child)
		if child.Name == "Coins" then
			child:GetPropertyChangedSignal("Value"):Connect(updateCounter)
		end
		updateCounter()
	end)
end

updateCounter()
