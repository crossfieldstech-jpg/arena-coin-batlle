local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local VaultItemRegistry = require(ReplicatedStorage:WaitForChild("VaultItemRegistry"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 190, 205),
	Rare = Color3.fromRGB(59, 130, 246),
	Epic = Color3.fromRGB(168, 85, 247),
	Legendary = Color3.fromRGB(245, 158, 11),
}

local function formatNumber(val)
	local n = tonumber(val) or 0
	local formatted = tostring(n)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

-- ScreenGui Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VaultGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- Modal Overlay Container
local modalContainer = Instance.new("Frame")
modalContainer.Name = "ModalContainer"
modalContainer.Size = UDim2.new(1, 0, 1, 0)
modalContainer.BackgroundTransparency = 1
modalContainer.Visible = false
modalContainer.Parent = screenGui

-- Semi-transparent Backdrop for dismissal
local backdrop = Instance.new("TextButton")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
backdrop.BackgroundTransparency = 0.55
backdrop.BorderSizePixel = 0
backdrop.Text = ""
backdrop.AutoButtonColor = false
backdrop.Parent = modalContainer

-- Main Dialog Card
local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.new(0.5, 0, 0.5, 0)
card.Size = UDim2.new(0, 480, 0, 520)
card.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
card.BorderSizePixel = 0
card.Parent = modalContainer

local cardConstraint = Instance.new("UISizeConstraint")
cardConstraint.MaxSize = Vector2.new(500, 560)
cardConstraint.MinSize = Vector2.new(320, 380)
cardConstraint.Parent = card

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 16)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(55, 65, 81)
cardStroke.Thickness = 1.5
cardStroke.Parent = card

-- Header Frame
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, -32, 0, 60)
header.Position = UDim2.new(0, 16, 0, 14)
header.BackgroundTransparency = 1
header.Parent = card

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -50, 0, 26)
titleLabel.Position = UDim2.new(0, 0, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "VAULT STORAGE"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.TextSize = 22
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.new(1, -50, 0, 20)
subtitleLabel.Position = UDim2.new(0, 0, 0, 32)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Font = Enum.Font.GothamMedium
subtitleLabel.Text = "Stored Items & Treasures"
subtitleLabel.TextColor3 = Color3.fromRGB(156, 163, 175)
subtitleLabel.TextSize = 13
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 6)
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(45, 52, 64)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(220, 225, 235)
closeButton.TextSize = 16
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- Summary Info Bar
local summaryBar = Instance.new("Frame")
summaryBar.Name = "SummaryBar"
summaryBar.Size = UDim2.new(1, -32, 0, 36)
summaryBar.Position = UDim2.new(0, 16, 0, 82)
summaryBar.BackgroundColor3 = Color3.fromRGB(31, 38, 49)
summaryBar.BorderSizePixel = 0
summaryBar.Parent = card

local summaryCorner = Instance.new("UICorner")
summaryCorner.CornerRadius = UDim.new(0, 8)
summaryCorner.Parent = summaryBar

local summaryLabel = Instance.new("TextLabel")
summaryLabel.Name = "SummaryLabel"
summaryLabel.Size = UDim2.new(1, -20, 1, 0)
summaryLabel.Position = UDim2.new(0, 10, 0, 0)
summaryLabel.BackgroundTransparency = 1
summaryLabel.Font = Enum.Font.GothamSemibold
summaryLabel.Text = "Total Unique Types: 0"
summaryLabel.TextColor3 = Color3.fromRGB(209, 213, 219)
summaryLabel.TextSize = 13
summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
summaryLabel.Parent = summaryBar

-- Items ScrollingFrame
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ItemsScroll"
scrollFrame.Size = UDim2.new(1, -32, 1, -142)
scrollFrame.Position = UDim2.new(0, 16, 0, 126)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(75, 85, 99)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = card

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.Padding = UDim.new(0, 10)
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Parent = scrollFrame

-- Build Item Cards
local itemLabels = {} -- [itemId] = { amountLabel = TextLabel, card = Frame }
local enabledItems = VaultItemRegistry.GetEnabledItems()

for idx, item in ipairs(enabledItems) do
	local row = Instance.new("Frame")
	row.Name = "ItemRow_" .. item.id
	row.Size = UDim2.new(1, -6, 0, 72)
	row.BackgroundColor3 = Color3.fromRGB(33, 40, 52)
	row.BorderSizePixel = 0
	row.LayoutOrder = item.order or idx
	row.Parent = scrollFrame

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 10)
	rowCorner.Parent = row

	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = Color3.fromRGB(48, 56, 70)
	rowStroke.Thickness = 1
	rowStroke.Parent = row

	-- Icon container
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.Size = UDim2.new(0, 48, 0, 48)
	iconBox.Position = UDim2.new(0, 12, 0.5, -24)
	iconBox.BackgroundColor3 = Color3.fromRGB(24, 28, 36)
	iconBox.BorderSizePixel = 0
	iconBox.Parent = row

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = iconBox

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = item.icon or "📦"
	iconLabel.TextSize = 24
	iconLabel.Parent = iconBox

	-- Name & Category
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "DisplayName"
	nameLabel.Size = UDim2.new(0.5, -60, 0, 20)
	nameLabel.Position = UDim2.new(0, 68, 0, 14)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = item.displayName
	nameLabel.TextColor3 = Color3.fromRGB(243, 244, 246)
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	-- Category pill
	local categoryPill = Instance.new("Frame")
	categoryPill.Name = "CategoryPill"
	categoryPill.Size = UDim2.new(0, 80, 0, 18)
	categoryPill.Position = UDim2.new(0, 68, 0, 38)
	categoryPill.BackgroundColor3 = Color3.fromRGB(45, 55, 72)
	categoryPill.BorderSizePixel = 0
	categoryPill.Parent = row

	local pillCorner = Instance.new("UICorner")
	pillCorner.CornerRadius = UDim.new(0, 6)
	pillCorner.Parent = categoryPill

	local categoryLabel = Instance.new("TextLabel")
	categoryLabel.Size = UDim2.new(1, 0, 1, 0)
	categoryLabel.BackgroundTransparency = 1
	categoryLabel.Font = Enum.Font.GothamMedium
	categoryLabel.Text = string.upper(item.category)
	categoryLabel.TextColor3 = Color3.fromRGB(156, 163, 175)
	categoryLabel.TextSize = 10
	categoryLabel.Parent = categoryPill

	-- Right Side: Rarity & Amount
	local rarityColor = RARITY_COLORS[item.rarity] or RARITY_COLORS.Common
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.new(0, 120, 0, 16)
	rarityLabel.Position = UDim2.new(1, -132, 0, 14)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.Text = string.upper(item.rarity)
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextSize = 11
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
	rarityLabel.Parent = row

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "Amount"
	amountLabel.Size = UDim2.new(0, 120, 0, 24)
	amountLabel.Position = UDim2.new(1, -132, 0, 34)
	amountLabel.BackgroundTransparency = 1
	amountLabel.Font = Enum.Font.GothamBold
	amountLabel.Text = "0"
	amountLabel.TextColor3 = (item.id == "Coins") and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(255, 255, 255)
	amountLabel.TextSize = 18
	amountLabel.TextXAlignment = Enum.TextXAlignment.Right
	amountLabel.Parent = row

	itemLabels[item.id] = {
		amountLabel = amountLabel,
		card = row,
	}
end

local function updateItemCounts(itemsTable)
	if not itemsTable then
		return
	end

	local uniqueCount = 0
	for _, item in ipairs(enabledItems) do
		local count = itemsTable[item.id] or 0
		local labelData = itemLabels[item.id]
		if labelData and labelData.amountLabel then
			labelData.amountLabel.Text = formatNumber(count)
		end
		if count > 0 then
			uniqueCount += 1
		end
	end

	summaryLabel.Text = string.format("Owned Item Types: %d / %d", uniqueCount, #enabledItems)
end

local function setModalVisible(visible)
	modalContainer.Visible = visible
end

-- Close triggers
backdrop.MouseButton1Click:Connect(function()
	setModalVisible(false)
end)

closeButton.MouseButton1Click:Connect(function()
	setModalVisible(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape and modalContainer.Visible then
		setModalVisible(false)
	end
end)

-- Remotes Binding
task.spawn(function()
	local vaultRemotes = ReplicatedStorage:WaitForChild("VaultRemotes", 10)
	if not vaultRemotes then
		warn("[VaultHUD] VaultRemotes folder not found")
		return
	end

	local openVaultUIEvent = vaultRemotes:WaitForChild("OpenVaultUI", 10)
	if openVaultUIEvent then
		openVaultUIEvent.OnClientEvent:Connect(function()
			setModalVisible(true)
		end)
	end

	local vaultUpdatedEvent = vaultRemotes:WaitForChild("VaultUpdated", 10)
	if vaultUpdatedEvent then
		vaultUpdatedEvent.OnClientEvent:Connect(function(data)
			if data and data.items then
				updateItemCounts(data.items)
			end
		end)
	end

	local getVaultDataFunction = vaultRemotes:WaitForChild("GetVaultData", 10)
	if getVaultDataFunction then
		local ok, initialData = pcall(function()
			return getVaultDataFunction:InvokeServer()
		end)
		if ok and initialData then
			updateItemCounts(initialData)
		end
	end
end)
