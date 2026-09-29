--[[
	CoinForge/Client.luau
	Custom Client Controller for Coin Forge mini-game package.
	Mounts in-mission dynamic widgets: bellows HUD pulse, minted batches tally, and station cues.
]]

local TweenService = game:GetService("TweenService")

local CoinForgeClient = {}
CoinForgeClient.__index = CoinForgeClient

function CoinForgeClient.new()
	local self = setmetatable({}, CoinForgeClient)
	self._isMounted = false
	self._connections = {}
	self._elements = {}
	return self
end

function CoinForgeClient:Mount(context)
	if self._isMounted then
		self:Unmount()
	end
	self._isMounted = true

	local rootContainer = context.rootContainer
	local eventBus = context.eventBus
	self._context = context

	-- Custom Widget Container inside ActiveCustomFrame
	local widgetFrame = Instance.new("Frame")
	widgetFrame.Name = "CoinForgeWidget"
	widgetFrame.Size = UDim2.new(1, 0, 1, 0)
	widgetFrame.BackgroundTransparency = 1
	widgetFrame.Parent = rootContainer
	table.insert(self._elements, widgetFrame)

	-- 1. Minted Batches Badge (Left Side)
	local mintedPill = Instance.new("Frame")
	mintedPill.Name = "MintedPill"
	mintedPill.Position = UDim2.new(0, 8, 0, 8)
	mintedPill.Size = UDim2.new(0, 160, 0, 36)
	mintedPill.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
	mintedPill.BorderSizePixel = 0
	mintedPill.Parent = widgetFrame
	table.insert(self._elements, mintedPill)

	local mintedCorner = Instance.new("UICorner")
	mintedCorner.CornerRadius = UDim.new(0, 8)
	mintedCorner.Parent = mintedPill

	local mintedStroke = Instance.new("UIStroke")
	mintedStroke.Color = Color3.fromRGB(241, 196, 15)
	mintedStroke.Thickness = 1.2
	mintedStroke.Parent = mintedPill

	local mintedLabel = Instance.new("TextLabel")
	mintedLabel.Name = "MintedLabel"
	mintedLabel.Size = UDim2.new(1, 0, 1, 0)
	mintedLabel.BackgroundTransparency = 1
	mintedLabel.Font = Enum.Font.GothamBold
	mintedLabel.Text = "🪙 Minted: 0"
	mintedLabel.TextColor3 = Color3.fromRGB(255, 225, 100)
	mintedLabel.TextSize = 14
	mintedLabel.Parent = mintedPill
	self._mintedLabel = mintedLabel
	self._mintedPill = mintedPill

	-- 2. Bellows Heat / Furnace Status Bar (Center)
	local bellowsFrame = Instance.new("Frame")
	bellowsFrame.Name = "BellowsFrame"
	bellowsFrame.Position = UDim2.new(0, 176, 0, 8)
	bellowsFrame.Size = UDim2.new(1, -184, 0, 36)
	bellowsFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	bellowsFrame.BorderSizePixel = 0
	bellowsFrame.Parent = widgetFrame
	table.insert(self._elements, bellowsFrame)

	local bellowsCorner = Instance.new("UICorner")
	bellowsCorner.CornerRadius = UDim.new(0, 8)
	bellowsCorner.Parent = bellowsFrame

	local bellowsStroke = Instance.new("UIStroke")
	bellowsStroke.Color = Color3.fromRGB(230, 126, 34)
	bellowsStroke.Thickness = 1.2
	bellowsStroke.Parent = bellowsFrame
	self._bellowsStroke = bellowsStroke

	local bellowsLabel = Instance.new("TextLabel")
	bellowsLabel.Name = "BellowsLabel"
	bellowsLabel.Size = UDim2.new(1, -12, 1, 0)
	bellowsLabel.Position = UDim2.new(0, 8, 0, 0)
	bellowsLabel.BackgroundTransparency = 1
	bellowsLabel.Font = Enum.Font.GothamMedium
	bellowsLabel.Text = "🔥 Forge Ready • Deposit Ore to Smelt"
	bellowsLabel.TextColor3 = Color3.fromRGB(250, 180, 100)
	bellowsLabel.TextSize = 12
	bellowsLabel.TextXAlignment = Enum.TextXAlignment.Left
	bellowsLabel.Parent = bellowsFrame
	self._bellowsLabel = bellowsLabel

	-- Pulse Bellows Animation Helper
	local function pulseBellows()
		if not self._isMounted or not self._bellowsStroke then return end
		self._bellowsStroke.Thickness = 2.5
		self._bellowsStroke.Color = Color3.fromRGB(255, 255, 150)
		local tween = TweenService:Create(self._bellowsStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 1.2,
			Color = Color3.fromRGB(230, 126, 34),
		})
		tween:Play()
	end

	-- Connect Event Bus SessionProgress
	if eventBus and eventBus.SessionProgress then
		local conn = eventBus.SessionProgress:Connect(function(progressData)
			if not self._isMounted then return end
			if typeof(progressData) ~= "table" then return end

			local score = progressData.score or 0
			if self._mintedLabel then
				self._mintedLabel.Text = string.format("🪙 Minted: %d", score)
			end

			-- Check for bellows pumps or objective cues
			if progressData.extra and progressData.extra.smeltPumps then
				local pumps = progressData.extra.smeltPumps
				local maxPumps = progressData.extra.maxSmeltPumps or 3
				if self._bellowsLabel then
					self._bellowsLabel.Text = string.format("💨 Bellows Pumping: %d/%d", pumps, maxPumps)
				end
				pulseBellows()
			elseif progressData.objective then
				if self._bellowsLabel then
					self._bellowsLabel.Text = progressData.objective
				end
				if string.find(progressData.objective, "Pump Bellows") then
					pulseBellows()
				end
			end
		end)
		table.insert(self._connections, conn)
	end
end

function CoinForgeClient:Unmount()
	self._isMounted = false

	for _, conn in ipairs(self._connections) do
		if conn.Disconnect then
			pcall(function() conn:Disconnect() end)
		end
	end
	table.clear(self._connections)

	for _, elem in ipairs(self._elements) do
		if elem and elem.Parent then
			pcall(function() elem:Destroy() end)
		end
	end
	table.clear(self._elements)

	self._mintedLabel = nil
	self._mintedPill = nil
	self._bellowsStroke = nil
	self._bellowsLabel = nil
end

return CoinForgeClient
