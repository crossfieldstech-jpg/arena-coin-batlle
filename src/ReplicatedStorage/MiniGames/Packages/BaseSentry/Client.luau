--[[
	BaseSentry/Client.luau
	Custom Client Controller for Base Sentry mini-game package.
	Mounts in-mission dynamic widgets: wave progress tracker and animated vault core health bar.
]]

local TweenService = game:GetService("TweenService")

local BaseSentryClient = {}
BaseSentryClient.__index = BaseSentryClient

function BaseSentryClient.new()
	local self = setmetatable({}, BaseSentryClient)
	self._isMounted = false
	self._connections = {}
	self._elements = {}
	return self
end

function BaseSentryClient:Mount(context)
	if self._isMounted then
		self:Unmount()
	end
	self._isMounted = true

	local rootContainer = context.rootContainer
	local eventBus = context.eventBus
	self._context = context

	-- Custom Widget Container inside ActiveCustomFrame
	local widgetFrame = Instance.new("Frame")
	widgetFrame.Name = "BaseSentryWidget"
	widgetFrame.Size = UDim2.new(1, 0, 1, 0)
	widgetFrame.BackgroundTransparency = 1
	widgetFrame.Parent = rootContainer
	table.insert(self._elements, widgetFrame)

	-- 1. Wave Tracker Badge (Left side)
	local waveBadge = Instance.new("Frame")
	waveBadge.Name = "WaveBadge"
	waveBadge.Position = UDim2.new(0, 8, 0, 8)
	waveBadge.Size = UDim2.new(0, 140, 0, 36)
	waveBadge.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
	waveBadge.BorderSizePixel = 0
	waveBadge.Parent = widgetFrame
	table.insert(self._elements, waveBadge)

	local waveCorner = Instance.new("UICorner")
	waveCorner.CornerRadius = UDim.new(0, 8)
	waveCorner.Parent = waveBadge

	local waveStroke = Instance.new("UIStroke")
	waveStroke.Color = Color3.fromRGB(52, 152, 219)
	waveStroke.Thickness = 1.2
	waveStroke.Parent = waveBadge

	local waveLabel = Instance.new("TextLabel")
	waveLabel.Name = "WaveLabel"
	waveLabel.Size = UDim2.new(1, 0, 1, 0)
	waveLabel.BackgroundTransparency = 1
	waveLabel.Font = Enum.Font.GothamBold
	waveLabel.Text = "🌊 Wave 1/3"
	waveLabel.TextColor3 = Color3.fromRGB(130, 205, 255)
	waveLabel.TextSize = 13
	waveLabel.Parent = waveBadge
	self._waveLabel = waveLabel

	-- 2. Vault Core Health Bar Container (Right side)
	local hpContainer = Instance.new("Frame")
	hpContainer.Name = "HpContainer"
	hpContainer.Position = UDim2.new(0, 156, 0, 8)
	hpContainer.Size = UDim2.new(1, -164, 0, 36)
	hpContainer.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	hpContainer.BorderSizePixel = 0
	hpContainer.Parent = widgetFrame
	table.insert(self._elements, hpContainer)

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 8)
	hpCorner.Parent = hpContainer

	local hpStroke = Instance.new("UIStroke")
	hpStroke.Color = Color3.fromRGB(52, 152, 219)
	hpStroke.Thickness = 1.2
	hpStroke.Parent = hpContainer

	-- Fill bar
	local hpBarBackground = Instance.new("Frame")
	hpBarBackground.Name = "HpBarBg"
	hpBarBackground.Position = UDim2.new(0, 8, 0, 20)
	hpBarBackground.Size = UDim2.new(1, -16, 0, 8)
	hpBarBackground.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
	hpBarBackground.BorderSizePixel = 0
	hpBarBackground.Parent = hpContainer

	local hpBarBgCorner = Instance.new("UICorner")
	hpBarBgCorner.CornerRadius = UDim.new(0, 4)
	hpBarBgCorner.Parent = hpBarBackground

	local hpFill = Instance.new("Frame")
	hpFill.Name = "HpFill"
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBarBackground
	self._hpFill = hpFill

	local hpFillCorner = Instance.new("UICorner")
	hpFillCorner.CornerRadius = UDim.new(0, 4)
	hpFillCorner.Parent = hpFill

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HpText"
	hpText.Size = UDim2.new(1, -16, 0, 16)
	hpText.Position = UDim2.new(0, 8, 0, 3)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = "🛡️ VAULT INTEGRITY: 100%"
	hpText.TextColor3 = Color3.fromRGB(150, 230, 255)
	hpText.TextSize = 11
	hpText.TextXAlignment = Enum.TextXAlignment.Left
	hpText.Parent = hpContainer
	self._hpText = hpText

	-- Progress updates listener
	if eventBus and eventBus.SessionProgress then
		local conn = eventBus.SessionProgress:Connect(function(progressData)
			if not self._isMounted then return end
			if typeof(progressData) ~= "table" then return end

			local extra = progressData.extra or {}
			local wave = extra.wave or 1
			local coreHealth = extra.coreHealth or 100
			local maxHealth = 100

			if self._waveLabel then
				self._waveLabel.Text = string.format("🌊 Wave %d/3", wave)
			end

			local pct = math.clamp(coreHealth / maxHealth, 0, 1)
			if self._hpFill then
				local targetColor = if pct > 0.5 then Color3.fromRGB(46, 204, 113)
					elseif pct > 0.25 then Color3.fromRGB(241, 196, 15)
					else Color3.fromRGB(231, 76, 60)

				local tween = TweenService:Create(self._hpFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(pct, 0, 1, 0),
					BackgroundColor3 = targetColor,
				})
				tween:Play()
			end

			if self._hpText then
				self._hpText.Text = string.format("🛡️ VAULT INTEGRITY: %d%%", math.floor(pct * 100))
			end
		end)
		table.insert(self._connections, conn)
	end
end

function BaseSentryClient:Unmount()
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

	self._waveLabel = nil
	self._hpFill = nil
	self._hpText = nil
end

return BaseSentryClient
