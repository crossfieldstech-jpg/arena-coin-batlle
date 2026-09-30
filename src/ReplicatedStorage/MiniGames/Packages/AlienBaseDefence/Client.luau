--[[
	AlienBaseDefence/Client.luau
	Custom Client Controller for Alien Base Defence mini-game package.
	Mounts tactical military HUD widget: Wave counter, Outpost Integrity health bar, and Aliens Repelled counter.
]]

local TweenService = game:GetService("TweenService")

local AlienBaseDefenceClient = {}
AlienBaseDefenceClient.__index = AlienBaseDefenceClient

function AlienBaseDefenceClient.new()
	local self = setmetatable({}, AlienBaseDefenceClient)
	self._isMounted = false
	self._connections = {}
	self._elements = {}
	return self
end

function AlienBaseDefenceClient:Mount(context)
	if self._isMounted then
		self:Unmount()
	end
	self._isMounted = true

	local rootContainer = context.rootContainer
	local eventBus = context.eventBus
	self._context = context

	-- Tactical Military HUD Widget Container inside ActiveCustomFrame
	local widgetFrame = Instance.new("Frame")
	widgetFrame.Name = "AlienBaseDefenceWidget"
	widgetFrame.Size = UDim2.new(1, 0, 1, 0)
	widgetFrame.BackgroundTransparency = 1
	widgetFrame.Parent = rootContainer
	table.insert(self._elements, widgetFrame)

	-- 1. Wave Tracker Badge (Left)
	local waveBadge = Instance.new("Frame")
	waveBadge.Name = "WaveBadge"
	waveBadge.Position = UDim2.new(0, 4, 0, 4)
	waveBadge.Size = UDim2.new(0, 110, 0, 32)
	waveBadge.BackgroundColor3 = Color3.fromRGB(24, 32, 28)
	waveBadge.BorderSizePixel = 0
	waveBadge.Parent = widgetFrame
	table.insert(self._elements, waveBadge)

	local waveCorner = Instance.new("UICorner")
	waveCorner.CornerRadius = UDim.new(0, 6)
	waveCorner.Parent = waveBadge

	local waveStroke = Instance.new("UIStroke")
	waveStroke.Color = Color3.fromRGB(58, 120, 65)
	waveStroke.Thickness = 1.2
	waveStroke.Parent = waveBadge

	local waveLabel = Instance.new("TextLabel")
	waveLabel.Name = "WaveLabel"
	waveLabel.Size = UDim2.new(1, 0, 1, 0)
	waveLabel.BackgroundTransparency = 1
	waveLabel.Font = Enum.Font.GothamBold
	waveLabel.Text = "🪖 WAVE 1/3"
	waveLabel.TextColor3 = Color3.fromRGB(150, 240, 160)
	waveLabel.TextSize = 12
	waveLabel.Parent = waveBadge
	self._waveLabel = waveLabel

	-- 2. Aliens Repelled Counter Badge (Center-left)
	local killBadge = Instance.new("Frame")
	killBadge.Name = "KillBadge"
	killBadge.Position = UDim2.new(0, 120, 0, 4)
	killBadge.Size = UDim2.new(0, 140, 0, 32)
	killBadge.BackgroundColor3 = Color3.fromRGB(28, 26, 36)
	killBadge.BorderSizePixel = 0
	killBadge.Parent = widgetFrame
	table.insert(self._elements, killBadge)

	local killCorner = Instance.new("UICorner")
	killCorner.CornerRadius = UDim.new(0, 6)
	killCorner.Parent = killBadge

	local killStroke = Instance.new("UIStroke")
	killStroke.Color = Color3.fromRGB(155, 89, 182)
	killStroke.Thickness = 1.2
	killStroke.Parent = killBadge

	local killLabel = Instance.new("TextLabel")
	killLabel.Name = "KillLabel"
	killLabel.Size = UDim2.new(1, 0, 1, 0)
	killLabel.BackgroundTransparency = 1
	killLabel.Font = Enum.Font.GothamBold
	killLabel.Text = "👽 Aliens Repelled: 0"
	killLabel.TextColor3 = Color3.fromRGB(220, 180, 255)
	killLabel.TextSize = 11
	killLabel.Parent = killBadge
	self._killLabel = killLabel

	-- 3. Outpost Integrity Health Bar Container (Right side)
	local hpContainer = Instance.new("Frame")
	hpContainer.Name = "HpContainer"
	hpContainer.Position = UDim2.new(0, 268, 0, 4)
	hpContainer.Size = UDim2.new(1, -272, 0, 32)
	hpContainer.BackgroundColor3 = Color3.fromRGB(18, 24, 28)
	hpContainer.BorderSizePixel = 0
	hpContainer.Parent = widgetFrame
	table.insert(self._elements, hpContainer)

	local hpCorner = Instance.new("UICorner")
	hpCorner.CornerRadius = UDim.new(0, 6)
	hpCorner.Parent = hpContainer

	local hpStroke = Instance.new("UIStroke")
	hpStroke.Color = Color3.fromRGB(46, 204, 113)
	hpStroke.Thickness = 1.2
	hpStroke.Parent = hpContainer
	self._hpStroke = hpStroke

	local hpText = Instance.new("TextLabel")
	hpText.Name = "HpText"
	hpText.Size = UDim2.new(1, -12, 0, 14)
	hpText.Position = UDim2.new(0, 6, 0, 2)
	hpText.BackgroundTransparency = 1
	hpText.Font = Enum.Font.GothamBold
	hpText.Text = "🛡️ OUTPOST INTEGRITY: 100%"
	hpText.TextColor3 = Color3.fromRGB(160, 245, 180)
	hpText.TextSize = 10
	hpText.TextXAlignment = Enum.TextXAlignment.Left
	hpText.Parent = hpContainer
	self._hpText = hpText

	-- Fill bar background
	local hpBarBackground = Instance.new("Frame")
	hpBarBackground.Name = "HpBarBg"
	hpBarBackground.Position = UDim2.new(0, 6, 0, 18)
	hpBarBackground.Size = UDim2.new(1, -12, 0, 8)
	hpBarBackground.BackgroundColor3 = Color3.fromRGB(30, 40, 35)
	hpBarBackground.BorderSizePixel = 0
	hpBarBackground.Parent = hpContainer

	local hpBarBgCorner = Instance.new("UICorner")
	hpBarBgCorner.CornerRadius = UDim.new(0, 4)
	hpBarBgCorner.Parent = hpBarBackground

	-- Dynamic Fill Bar
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

	-- Progress updates listener
	if eventBus and eventBus.SessionProgress then
		local conn = eventBus.SessionProgress:Connect(function(progressData)
			if not self._isMounted then return end
			if typeof(progressData) ~= "table" then return end

			local extra = progressData.extra or {}
			local wave = extra.wave or 1
			local coreHealth = extra.coreHealth or 100
			local maxHealth = extra.maxCoreHealth or 100
			local defeated = progressData.score or extra.defeated or 0

			if self._waveLabel then
				self._waveLabel.Text = string.format("🪖 WAVE %d/3", wave)
			end

			if self._killLabel then
				self._killLabel.Text = string.format("👽 Aliens Repelled: %d", defeated)
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

				if self._hpStroke then
					self._hpStroke.Color = targetColor
				end
			end

			if self._hpText then
				self._hpText.Text = string.format("🛡️ OUTPOST INTEGRITY: %d%%", math.floor(pct * 100))
			end
		end)
		table.insert(self._connections, conn)
	end
end

function AlienBaseDefenceClient:Unmount()
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
	self._killLabel = nil
	self._hpFill = nil
	self._hpText = nil
	self._hpStroke = nil
end

return AlienBaseDefenceClient
