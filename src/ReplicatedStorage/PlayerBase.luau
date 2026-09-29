local Players = game:GetService("Players")

local PlayerBase = {}
PlayerBase.__index = PlayerBase

-- Color helpers for muted, non-glaring interactive elements
local function mutedColor(color)
	return Color3.fromRGB(
		math.floor(color.R * 255 * 0.42),
		math.floor(color.G * 255 * 0.42),
		math.floor(color.B * 255 * 0.42)
	)
end

local function addSoftGlow(part, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Name = "SoftGlow"
	light.Color = color
	light.Brightness = brightness or 0.4
	light.Range = range or 10
	light.Parent = part
	return light
end

-- Preset themes for the 4 player bases
PlayerBase.THEMES = {
	[1] = {
		name = "Base North (Sapphire)",
		direction = "North",
		primaryColor = Color3.fromRGB(41, 128, 185),
		accentColor = Color3.fromRGB(52, 152, 219),
		floorColor = Color3.fromRGB(44, 62, 80),
	},
	[2] = {
		name = "Base South (Emerald)",
		direction = "South",
		primaryColor = Color3.fromRGB(39, 174, 96),
		accentColor = Color3.fromRGB(46, 204, 113),
		floorColor = Color3.fromRGB(38, 56, 48),
	},
	[3] = {
		name = "Base East (Amber)",
		direction = "East",
		primaryColor = Color3.fromRGB(230, 126, 34),
		accentColor = Color3.fromRGB(243, 156, 18),
		floorColor = Color3.fromRGB(60, 48, 40),
	},
	[4] = {
		name = "Base West (Amethyst)",
		direction = "West",
		primaryColor = Color3.fromRGB(142, 68, 173),
		accentColor = Color3.fromRGB(155, 89, 182),
		floorColor = Color3.fromRGB(52, 40, 58),
	},
}

function PlayerBase.new(id, centerPosition, facingDirection, customConfig)
	local self = setmetatable({}, PlayerBase)

	self.id = id
	self.theme = PlayerBase.THEMES[id] or PlayerBase.THEMES[1]
	self.center = centerPosition
	self.facing = (facingDirection.Magnitude > 0) and facingDirection.Unit or Vector3.new(0, 0, 1)
	self.config = customConfig or {}

	self.size = self.config.size or 84
	self.wallHeight = self.config.wallHeight or 9

	-- Owner state
	self.owner = nil
	self.ownerUserId = 0
	self.ownerName = "Unclaimed"

	-- Dynamic performance attributes
	self.baseLevel = self.config.baseStartingLevel or 1
	self.bankedCoins = 0
	self.coinMultiplier = self.config.baseStartingMultiplier or 1.0
	self.performanceScore = 0
	self.totalEarned = 0
	self.hasWalls = false

	-- Instances
	self.model = nil
	self.wallsFolder = nil
	self.spawnLocation = nil
	self.claimPad = nil
	self.bankPad = nil
	self.activatePad = nil
	self.activateLabel = nil
	self.signLabel = nil
	self.barrierFolder = nil
	self.miniGamePad = nil

	-- Callbacks
	self._claimCallbacks = {}
	self._bankCallbacks = {}
	self._activateCallbacks = {}
	self._openVaultCallbacks = {}
	self._miniGamePromptCallbacks = {}

	return self
end

function PlayerBase:Build(parent)
	if self.model and self.model.Parent then
		self.model:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = string.format("PlayerBase_%d_%s", self.id, self.theme.direction)
	model.Parent = parent
	self.model = model

	-- Set dynamic attributes on model for external scripts/Studio inspectability
	model:SetAttribute("BaseId", self.id)
	model:SetAttribute("BaseName", self.theme.name)
	model:SetAttribute("Direction", self.theme.direction)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "Unclaimed")
	model:SetAttribute("BaseLevel", self.baseLevel)
	model:SetAttribute("BankedCoins", 0)
	model:SetAttribute("CoinMultiplier", self.coinMultiplier)
	model:SetAttribute("PerformanceScore", 0)
	model:SetAttribute("TotalEarned", 0)
	model:SetAttribute("HasWalls", false)

	local halfSize = self.size / 2

	-- Base Foundation / Open Platform Floor (Large 3x footprint: 84x84 studs)
	local floor = Instance.new("Part")
	floor.Name = "BaseFloor"
	floor.Size = Vector3.new(self.size, 1, self.size)
	floor.Position = self.center
	floor.Anchored = true
	floor.Material = Enum.Material.Concrete
	floor.Color = self.theme.floorColor
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = model

	-- Coordinate space: rotate relative to facing vector (facing toward central arena)
	local baseCFrame = CFrame.lookAt(self.center, self.center + self.facing)

	-- Low perimeter curb / foundation border (marking the boundary without blocking entry)
	local curbThickness = 1.0
	local curbHeight = 0.6
	local curbColor = Color3.fromRGB(30, 35, 42)

	local function makeCurb(name, offset, size)
		local curb = Instance.new("Part")
		curb.Name = name
		curb.Size = size
		curb.CFrame = baseCFrame * CFrame.new(offset)
		curb.Anchored = true
		curb.Material = Enum.Material.SmoothPlastic
		curb.Color = curbColor
		curb.TopSurface = Enum.SurfaceType.Smooth
		curb.BottomSurface = Enum.SurfaceType.Smooth
		curb.Parent = model
		return curb
	end

	local curbY = curbHeight / 2 + 0.5
	-- Solid curb at front (toward arena)
	makeCurb("CurbFront", Vector3.new(0, curbY, halfSize), Vector3.new(self.size, curbHeight, curbThickness))
	makeCurb("CurbLeft", Vector3.new(-halfSize, curbY, 0), Vector3.new(curbThickness, curbHeight, self.size))
	makeCurb("CurbRight", Vector3.new(halfSize, curbY, 0), Vector3.new(curbThickness, curbHeight, self.size))

	-- Back curb with 16-stud wide walkway opening (entrance now at rear)
	local frontDoorWidth = 16
	local frontSideWidth = (self.size - frontDoorWidth) / 2
	local frontSideOffset = (self.size / 2) - (frontSideWidth / 2)
	makeCurb("CurbBackLeft", Vector3.new(-frontSideOffset, curbY, -halfSize), Vector3.new(frontSideWidth, curbHeight, curbThickness))
	makeCurb("CurbBackRight", Vector3.new(frontSideOffset, curbY, -halfSize), Vector3.new(frontSideWidth, curbHeight, curbThickness))

	-- Entrance Gate Signboard Post (Standing at the back entrance)
	local signPost = Instance.new("Part")
	signPost.Name = "SignPost"
	signPost.Size = Vector3.new(1.2, 7, 1.2)
	signPost.CFrame = baseCFrame * CFrame.new(frontDoorWidth / 2 + 1.2, 3.5, halfSize)
	signPost.Anchored = true
	signPost.Material = Enum.Material.Metal
	signPost.Color = Color3.fromRGB(30, 30, 30)
	signPost.Parent = model

	local signPart = Instance.new("Part")
	signPart.Name = "SignPart"
	signPart.Size = Vector3.new(10, 2.5, 0.8)
	signPart.CFrame = baseCFrame * CFrame.new(0, 7.5, halfSize)
	signPart.Anchored = true
	signPart.Material = Enum.Material.Metal
	signPart.Color = Color3.fromRGB(30, 30, 30)
	signPart.Parent = model

	local signGui = Instance.new("BillboardGui")
	signGui.Name = "SignGui"
	signGui.Size = UDim2.new(0, 300, 0, 80)
	signGui.StudsOffset = Vector3.new(0, 0, 0.6)
	signGui.AlwaysOnTop = false
	signGui.Parent = signPart

	local signText = Instance.new("TextLabel")
	signText.Name = "SignText"
	signText.Size = UDim2.new(1, -10, 1, -6)
	signText.Position = UDim2.new(0, 5, 0, 3)
	signText.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
	signText.BackgroundTransparency = 0.2
	signText.Font = Enum.Font.GothamBold
	signText.Text = string.format("%s\n[ Unclaimed ]", self.theme.name)
	signText.TextColor3 = self.theme.accentColor
	signText.TextStrokeTransparency = 0.4
	signText.TextScaled = true
	signText.Parent = signGui

	local signCorner = Instance.new("UICorner")
	signCorner.CornerRadius = UDim.new(0, 6)
	signCorner.Parent = signText
	self.signLabel = signText

	-- Base SpawnLocation inside (Sanctuary at front, opposite entrance)
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "BaseSpawn"
	spawnPad.Size = Vector3.new(8, 0.6, 8)
	spawnPad.CFrame = baseCFrame * CFrame.new(0, 0.8, halfSize - 8)
	spawnPad.Anchored = true
	spawnPad.Material = Enum.Material.SmoothPlastic
	spawnPad.Color = mutedColor(self.theme.accentColor)
	addSoftGlow(spawnPad, self.theme.accentColor, 0.3, 8)
	spawnPad.Neutral = true
	spawnPad.Enabled = (self.owner == nil)
	spawnPad.Parent = model
	self.spawnLocation = spawnPad

	-- Interactive Claim Pad in back-left corner of base
	local claimOffset = Vector3.new(-halfSize + 12, 0.8, -halfSize + 12)
	local claim = Instance.new("Part")
	claim.Name = "ClaimPad"
	claim.Shape = Enum.PartType.Cylinder
	claim.Size = Vector3.new(0.5, 7, 7)
	claim.CFrame = baseCFrame * CFrame.new(claimOffset) * CFrame.Angles(0, 0, math.rad(90))
	claim.Anchored = true
	claim.CanCollide = false
	claim.Material = Enum.Material.SmoothPlastic
	claim.Color = Color3.fromRGB(35, 110, 60) -- Lighter green claim pad
	self.claimGlow = addSoftGlow(claim, Color3.fromRGB(80, 200, 110), 0.5, 10)
	claim.Parent = model
	self.claimPad = claim

	local claimRing = Instance.new("Part")
	claimRing.Name = "ClaimRing"
	claimRing.Shape = Enum.PartType.Cylinder
	claimRing.Size = Vector3.new(0.05, 10, 10)
	claimRing.CFrame = baseCFrame * CFrame.new(claimOffset.X, 0.55, claimOffset.Z) * CFrame.Angles(0, 0, math.rad(90))
	claimRing.Anchored = true
	claimRing.CanCollide = false
	claimRing.Material = Enum.Material.SmoothPlastic
	claimRing.Color = self.theme.accentColor
	claimRing.Parent = model

	local claimBillboard = Instance.new("BillboardGui")
	claimBillboard.Name = "ClaimBillboard"
	claimBillboard.Size = UDim2.new(0, 200, 0, 50)
	claimBillboard.StudsOffset = Vector3.new(0, 4, 0)
	claimBillboard.AlwaysOnTop = false
	claimBillboard.Parent = claim

	local claimText = Instance.new("TextLabel")
	claimText.Name = "ClaimLabel"
	claimText.Size = UDim2.new(1, -8, 1, -4)
	claimText.Position = UDim2.new(0, 4, 0, 2)
	claimText.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
	claimText.BackgroundTransparency = 0.2
	claimText.Font = Enum.Font.GothamBold
	claimText.Text = "★ STEP TO CLAIM ★"
	claimText.TextColor3 = Color3.fromRGB(80, 200, 110)
	claimText.TextStrokeTransparency = 0.4
	claimText.TextScaled = true
	claimText.Parent = claimBillboard

	local claimTextCorner = Instance.new("UICorner")
	claimTextCorner.CornerRadius = UDim.new(0, 6)
	claimTextCorner.Parent = claimText
	self.claimLabel = claimText

	-- Coin Bank / Vault Pad on the left interior wing
	local bankFloor = Instance.new("Part")
	bankFloor.Name = "BankFloorTile"
	bankFloor.Size = Vector3.new(14, 0.2, 14)
	bankFloor.CFrame = baseCFrame * CFrame.new(-halfSize + 12, 0.6, 0)
	bankFloor.Anchored = true
	bankFloor.Material = Enum.Material.DiamondPlate
	bankFloor.Color = Color3.fromRGB(35, 40, 45)
	bankFloor.Parent = model

	local bank = Instance.new("Part")
	bank.Name = "CoinBank"
	bank.Size = Vector3.new(7, 4.5, 7)
	bank.CFrame = baseCFrame * CFrame.new(-halfSize + 12, 2.85, 0)
	bank.Anchored = true
	bank.Material = Enum.Material.Metal
	bank.Color = Color3.fromRGB(50, 50, 50)
	bank.Parent = model
	self.bankPad = bank

	-- Interactive Vault ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VaultPrompt"
	prompt.ActionText = "Open Vault"
	prompt.ObjectText = "Coin Vault"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.HoldDuration = 0
	prompt.Parent = bank

	prompt.Triggered:Connect(function(player)
		if player == self.owner then
			for _, cb in ipairs(self._openVaultCallbacks) do
				task.spawn(cb, player, self)
			end
		end
	end)

	-- Bank accent
	local bankLid = Instance.new("Part")
	bankLid.Name = "BankLid"
	bankLid.Size = Vector3.new(7.6, 0.8, 7.6)
	bankLid.CFrame = baseCFrame * CFrame.new(-halfSize + 12, 5.5, 0)
	bankLid.Anchored = true
	bankLid.Material = Enum.Material.SmoothPlastic
	bankLid.Color = mutedColor(self.theme.accentColor)
	addSoftGlow(bankLid, self.theme.accentColor, 0.25, 7)
	bankLid.Parent = model

	local bankLabelGui = Instance.new("BillboardGui")
	bankLabelGui.Name = "BankLabelGui"
	bankLabelGui.Size = UDim2.new(0, 160, 0, 45)
	bankLabelGui.StudsOffset = Vector3.new(0, 4, 0)
	bankLabelGui.AlwaysOnTop = false
	bankLabelGui.Parent = bank

	local bankText = Instance.new("TextLabel")
	bankText.Size = UDim2.new(1, -8, 1, -4)
	bankText.Position = UDim2.new(0, 4, 0, 2)
	bankText.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
	bankText.BackgroundTransparency = 0.2
	bankText.Font = Enum.Font.GothamBold
	bankText.Text = "COIN VAULT\n[Step to Deposit]"
	bankText.TextColor3 = Color3.fromRGB(190, 150, 20)
	bankText.TextStrokeTransparency = 0.4
	bankText.TextScaled = true
	bankText.Parent = bankLabelGui

	local bankTextCorner = Instance.new("UICorner")
	bankTextCorner.CornerRadius = UDim.new(0, 6)
	bankTextCorner.Parent = bankText

	-- Dedicated Future Activity & Task Zones in the spacious front and side areas
	local function makeActivityZone(name, offset, labelText)
		local zonePad = Instance.new("Part")
		zonePad.Name = name
		zonePad.Size = Vector3.new(18, 0.2, 18)
		zonePad.CFrame = baseCFrame * CFrame.new(offset)
		zonePad.Anchored = true
		zonePad.CanCollide = false
		zonePad.Material = Enum.Material.SmoothPlastic
		zonePad.Color = Color3.fromRGB(40, 45, 52)
		zonePad.Parent = model

		-- Neon corner accents
		local border = Instance.new("SelectionBox")
		border.Name = "ZoneBorder"
		border.Adornee = zonePad
		border.Color3 = self.theme.accentColor
		border.LineThickness = 0.08
		border.Parent = zonePad

		local zoneGui = Instance.new("BillboardGui")
		zoneGui.Name = "ZoneBillboard"
		zoneGui.Size = UDim2.new(0, 180, 0, 40)
		zoneGui.StudsOffset = Vector3.new(0, 2, 0)
		zoneGui.AlwaysOnTop = false
		zoneGui.Parent = zonePad

		local zoneText = Instance.new("TextLabel")
		zoneText.Size = UDim2.new(1, -8, 1, -4)
		zoneText.Position = UDim2.new(0, 4, 0, 2)
		zoneText.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
		zoneText.BackgroundTransparency = 0.2
		zoneText.Font = Enum.Font.GothamMedium
		zoneText.Text = labelText
		zoneText.TextColor3 = Color3.fromRGB(200, 210, 220)
		zoneText.TextStrokeTransparency = 0.4
		zoneText.TextScaled = true
		zoneText.Parent = zoneGui

		local zoneTextCorner = Instance.new("UICorner")
		zoneTextCorner.CornerRadius = UDim.new(0, 6)
		zoneTextCorner.Parent = zoneText

		return zonePad, zoneText
	end

	-- Activity Zone 1 (Right Back Yard - e.g. Upgrades / Tasks)
	makeActivityZone("ActivityZone_Alpha", Vector3.new(22, 0.6, -20), "ACTIVITY ZONE ALPHA\n[Open for Tasks]")

	-- Activity Zone 2 (Left Back Yard - Sky Sub-Arena Mini-Games Portal)
	local _zoneBeta, zoneBetaText = makeActivityZone("ActivityZone_Beta", Vector3.new(-30, 0.6, 24.5), "🔒 SKY SUB-ARENA [LOCKED]\n[Claim Base at Front to Activate]")
	zoneBetaText.TextColor3 = Color3.fromRGB(240, 160, 40)
	self.zoneBetaLabel = zoneBetaText

	-- Interactive Mini-Game Sky Portal Pad (in ActivityZone_Beta)
	local portalOffset = Vector3.new(-30, 0.75, 24.5)
	local portalPad = Instance.new("Part")
	portalPad.Name = "MiniGamePortalPad"
	portalPad.Shape = Enum.PartType.Cylinder
	portalPad.Size = Vector3.new(0.5, 9, 9)
	portalPad.CFrame = baseCFrame * CFrame.new(portalOffset) * CFrame.Angles(0, 0, math.rad(90))
	portalPad.Anchored = true
	portalPad.CanCollide = false
	portalPad.Material = Enum.Material.Neon
	portalPad.Color = Color3.fromRGB(155, 89, 182) -- Radiant amethyst purple
	addSoftGlow(portalPad, Color3.fromRGB(180, 110, 220), 0.7, 12)
	portalPad.Parent = model
	self.miniGamePad = portalPad

	local portalRing = Instance.new("Part")
	portalRing.Name = "PortalRing"
	portalRing.Shape = Enum.PartType.Cylinder
	portalRing.Size = Vector3.new(0.1, 11, 11)
	portalRing.CFrame = baseCFrame * CFrame.new(portalOffset.X, 0.55, portalOffset.Z) * CFrame.Angles(0, 0, math.rad(90))
	portalRing.Anchored = true
	portalRing.CanCollide = false
	portalRing.Material = Enum.Material.SmoothPlastic
	portalRing.Color = self.theme.accentColor
	portalRing.Parent = model

	local portalPrompt = Instance.new("ProximityPrompt")
	portalPrompt.Name = "PortalPrompt"
	portalPrompt.ActionText = "Claim Base First"
	portalPrompt.ObjectText = "Sky Sub-Arena [Locked]"
	portalPrompt.KeyboardKeyCode = Enum.KeyCode.E
	portalPrompt.RequiresLineOfSight = false
	portalPrompt.MaxActivationDistance = 14
	portalPrompt.HoldDuration = 0
	portalPrompt.Parent = portalPad
	self.portalPrompt = portalPrompt

	local portalDebounce = {}
	local function triggerMiniGamePrompt(player)
		local now = os.clock()
		if portalDebounce[player] and (now - portalDebounce[player] < 2.5) then
			return
		end
		portalDebounce[player] = now
		local isOwner = (player == self.owner)
		for _, cb in ipairs(self._miniGamePromptCallbacks) do
			task.spawn(cb, player, self, isOwner)
		end
	end

	portalPrompt.Triggered:Connect(function(player)
		triggerMiniGamePrompt(player)
	end)

	portalPad.Touched:Connect(function(hit)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end
		triggerMiniGamePrompt(player)
	end)

	-- Activity Zone 3 (Front Workshop Yard)
	makeActivityZone("ActivityZone_Gamma", Vector3.new(22, 0.6, 18), "WORKSHOP YARD\n[Open for Future Expansion]")

	-- Interactive Arena Activation Pad (at the back of base, near entrance)
	local activatePad = Instance.new("Part")
	activatePad.Name = "ArenaActivatePad"
	activatePad.Shape = Enum.PartType.Cylinder
	activatePad.Size = Vector3.new(0.6, 9, 9)
	activatePad.CFrame = baseCFrame * CFrame.new(0, 0.8, -halfSize + 14) * CFrame.Angles(0, 0, math.rad(90))
	activatePad.Anchored = true
	activatePad.CanCollide = false
	activatePad.Material = Enum.Material.SmoothPlastic
	activatePad.Color = Color3.fromRGB(28, 125, 68) -- Brighter muted green ready pad
	self.activateGlow = addSoftGlow(activatePad, Color3.fromRGB(52, 200, 105), 0.7, 12)
	activatePad.Parent = model
	self.activatePad = activatePad

	local activateRing = Instance.new("Part")
	activateRing.Name = "ActivateRing"
	activateRing.Shape = Enum.PartType.Cylinder
	activateRing.Size = Vector3.new(0.1, 11, 11)
	activateRing.CFrame = baseCFrame * CFrame.new(0, 0.6, -halfSize + 14) * CFrame.Angles(0, 0, math.rad(90))
	activateRing.Anchored = true
	activateRing.CanCollide = false
	activateRing.Material = Enum.Material.SmoothPlastic
	activateRing.Color = self.theme.accentColor
	activateRing.Parent = model

	local activateGui = Instance.new("BillboardGui")
	activateGui.Name = "ActivateBillboard"
	activateGui.Size = UDim2.new(0, 240, 0, 50)
	activateGui.StudsOffset = Vector3.new(0, 3.5, 0)
	activateGui.AlwaysOnTop = false
	activateGui.Parent = activatePad

	local activateText = Instance.new("TextLabel")
	activateText.Name = "ActivateText"
	activateText.Size = UDim2.new(1, -8, 1, -4)
	activateText.Position = UDim2.new(0, 4, 0, 2)
	activateText.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
	activateText.BackgroundTransparency = 0.2
	activateText.Font = Enum.Font.GothamBold
	activateText.Text = "⚡ START ARENA RUN ⚡\n[Step to Open Gate]"
	activateText.TextColor3 = Color3.fromRGB(50, 185, 100)
	activateText.TextStrokeTransparency = 0.4
	activateText.TextScaled = true
	activateText.Parent = activateGui

	local activateTextCorner = Instance.new("UICorner")
	activateTextCorner.CornerRadius = UDim.new(0, 6)
	activateTextCorner.Parent = activateText
	self.activateLabel = activateText

	-- Connect Claim Pad Touched
	claim.Touched:Connect(function(hit)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		for _, cb in ipairs(self._claimCallbacks) do
			task.spawn(cb, player, self)
		end
	end)

	-- Connect Bank Touched
	bank.Touched:Connect(function(hit)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		for _, cb in ipairs(self._bankCallbacks) do
			task.spawn(cb, player, self)
		end
	end)

	-- Connect Arena Activate Pad Touched
	activatePad.Touched:Connect(function(hit)
		if not activatePad.CanTouch then
			return
		end
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		for _, cb in ipairs(self._activateCallbacks) do
			task.spawn(cb, player, self)
		end
	end)

	return self
end

function PlayerBase:UpdatePerformance(updates)
	if updates.level then self.baseLevel = updates.level end
	if updates.bankedCoins then self.bankedCoins = updates.bankedCoins end
	if updates.multiplier then self.coinMultiplier = updates.multiplier end
	if updates.score then self.performanceScore = updates.score end
	if updates.totalEarned then self.totalEarned = updates.totalEarned end

	if self.model then
		self.model:SetAttribute("BaseLevel", self.baseLevel)
		self.model:SetAttribute("BankedCoins", self.bankedCoins)
		self.model:SetAttribute("CoinMultiplier", self.coinMultiplier)
		self.model:SetAttribute("PerformanceScore", self.performanceScore)
		self.model:SetAttribute("TotalEarned", self.totalEarned)
	end
end

function PlayerBase:SetOwner(player)
	self.owner = player
	self.ownerUserId = player.UserId
	self.ownerName = player.DisplayName or player.Name

	if self.model then
		self.model:SetAttribute("OwnerUserId", self.ownerUserId)
		self.model:SetAttribute("OwnerName", self.ownerName)
	end

	if self.signLabel then
		self.signLabel.Text = string.format("%s\n[ %s ]", self.theme.name, self.ownerName)
		self.signLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	if self.claimLabel then
		self.claimLabel.Text = string.format("OWNED BY %s", string.upper(self.ownerName))
		self.claimLabel.TextColor3 = self.theme.accentColor
	end

	if self.claimPad then
		self.claimPad.Color = mutedColor(self.theme.accentColor)
	end
	if self.claimGlow then
		self.claimGlow.Color = self.theme.accentColor
	end

	if self.spawnLocation then
		self.spawnLocation.Enabled = false
	end

	-- Update Sky Sub-Arena Portal Visuals
	if self.zoneBetaLabel then
		self.zoneBetaLabel.Text = "🌀 SKY SUB-ARENA\n[Step to Play]"
		self.zoneBetaLabel.TextColor3 = Color3.fromRGB(215, 175, 255)
	end
	if self.portalPrompt then
		self.portalPrompt.ActionText = "Open Mini-Games"
		self.portalPrompt.ObjectText = "Sky Sub-Arena"
	end

	self:BuildVisualBarrier()
end

function PlayerBase:ClearOwner()
	self.owner = nil
	self.ownerUserId = 0
	self.ownerName = "Unclaimed"

	if self.model then
		self.model:SetAttribute("OwnerUserId", 0)
		self.model:SetAttribute("OwnerName", "Unclaimed")
	end

	if self.signLabel then
		self.signLabel.Text = string.format("%s\n[ Unclaimed ]", self.theme.name)
		self.signLabel.TextColor3 = self.theme.accentColor
	end

	if self.claimLabel then
		self.claimLabel.Text = "★ STEP TO CLAIM ★"
		self.claimLabel.TextColor3 = Color3.fromRGB(80, 200, 110)
	end

	if self.claimPad then
		self.claimPad.Color = Color3.fromRGB(35, 110, 60)
	end
	if self.claimGlow then
		self.claimGlow.Color = Color3.fromRGB(80, 200, 110)
	end

	if self.spawnLocation then
		self.spawnLocation.Enabled = true
	end

	-- Reset Sky Sub-Arena Portal Visuals to Locked
	if self.zoneBetaLabel then
		self.zoneBetaLabel.Text = "🔒 SKY SUB-ARENA [LOCKED]\n[Claim Base at Front to Activate]"
		self.zoneBetaLabel.TextColor3 = Color3.fromRGB(240, 160, 40)
	end
	if self.portalPrompt then
		self.portalPrompt.ActionText = "Claim Base First"
		self.portalPrompt.ObjectText = "Sky Sub-Arena [Locked]"
	end

	self:ClearVisualBarrier()

	self:UpdatePerformance({
		bankedCoins = 0,
		level = 1,
		multiplier = 1.0,
		score = 0,
		totalEarned = 0,
	})
end

function PlayerBase:GetOwner()
	return self.owner
end

function PlayerBase:IsOwned()
	return self.owner ~= nil
end

function PlayerBase:GetClaimPadPosition()
	if self.claimPad then
		return self.claimPad.Position
	end
	return self.center + Vector3.new(0, 1, -self.size / 2 + 22)
end

-- Modular method to construct walls later on when player collects money / completes tasks
function PlayerBase:BuildWalls(customWallHeight, customWallColor)
	if not self.model then
		return
	end

	self:ClearWalls()

	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "BaseWalls"
	wallsFolder.Parent = self.model
	self.wallsFolder = wallsFolder

	local halfSize = self.size / 2
	local height = customWallHeight or self.wallHeight or 9
	local wallY = (height / 2) + 0.5
	local wallColor = customWallColor or self.theme.primaryColor
	local wallThickness = 2
	local baseCFrame = CFrame.lookAt(self.center, self.center + self.facing)

	local function makeWallSegment(name, offset, size, color)
		local wall = Instance.new("Part")
		wall.Name = name
		wall.Size = size
		wall.CFrame = baseCFrame * CFrame.new(offset)
		wall.Anchored = true
		wall.Material = Enum.Material.SmoothPlastic
		wall.Color = color or wallColor
		wall.TopSurface = Enum.SurfaceType.Smooth
		wall.BottomSurface = Enum.SurfaceType.Smooth
		wall.Parent = wallsFolder
		return wall
	end

	-- Front wall (solid, toward arena)
	makeWallSegment("FrontWall", Vector3.new(0, wallY, halfSize + wallThickness / 2), Vector3.new(self.size + wallThickness * 2, height, wallThickness))
	-- Left wall
	makeWallSegment("LeftWall", Vector3.new(-halfSize - wallThickness / 2, wallY, 0), Vector3.new(wallThickness, height, self.size))
	-- Right wall
	makeWallSegment("RightWall", Vector3.new(halfSize + wallThickness / 2, wallY, 0), Vector3.new(wallThickness, height, self.size))

	-- Back wall with entrance opening (entrance now at rear)
	local doorWidth = 16
	local sideWidth = (self.size - doorWidth) / 2
	local sideOffset = (self.size / 2) - (sideWidth / 2)
	makeWallSegment("BackLeftWall", Vector3.new(-sideOffset, wallY, -halfSize - wallThickness / 2), Vector3.new(sideWidth, height, wallThickness))
	makeWallSegment("BackRightWall", Vector3.new(sideOffset, wallY, -halfSize - wallThickness / 2), Vector3.new(sideWidth, height, wallThickness))

	-- Arch over base entrance (at rear)
	local _arch = makeWallSegment("EntranceArch", Vector3.new(0, height - 0.5, -halfSize - wallThickness / 2), Vector3.new(doorWidth, 2, wallThickness), self.theme.accentColor)

	self.hasWalls = true
	self.model:SetAttribute("HasWalls", true)
end

function PlayerBase:ClearWalls()
	if self.wallsFolder then
		self.wallsFolder:Destroy()
		self.wallsFolder = nil
	end
	self.hasWalls = false
	if self.model then
		self.model:SetAttribute("HasWalls", false)
	end
end

function PlayerBase:BuildVisualBarrier()
	if not self.model then
		return
	end

	self:ClearVisualBarrier()

	local barrierFolder = Instance.new("Folder")
	barrierFolder.Name = "VisualBarrier"
	barrierFolder.Parent = self.model
	self.barrierFolder = barrierFolder

	local halfSize = self.size / 2
	local height = 22
	local barrierY = (height / 2) + 0.5
	local barrierColor = self.theme.primaryColor
	local barrierThickness = 0.5
	local baseCFrame = CFrame.lookAt(self.center, self.center + self.facing)

	local function makeBarrierSegment(name, offset, size)
		local panel = Instance.new("Part")
		panel.Name = name
		panel.Size = size
		panel.CFrame = baseCFrame * CFrame.new(offset)
		panel.Anchored = true
		panel.CanCollide = false
		panel.Material = Enum.Material.SmoothPlastic
		panel.Color = barrierColor
		panel.Transparency = 0.75
		panel.TopSurface = Enum.SurfaceType.Smooth
		panel.BottomSurface = Enum.SurfaceType.Smooth
		panel.Parent = barrierFolder
		return panel
	end

	-- Front barrier (toward arena)
	makeBarrierSegment("BarrierFront", Vector3.new(0, barrierY, halfSize + barrierThickness / 2), Vector3.new(self.size + barrierThickness * 2, height, barrierThickness))

	-- Left barrier
	makeBarrierSegment("BarrierLeft", Vector3.new(-halfSize - barrierThickness / 2, barrierY, 0), Vector3.new(barrierThickness, height, self.size))

	-- Right barrier
	makeBarrierSegment("BarrierRight", Vector3.new(halfSize + barrierThickness / 2, barrierY, 0), Vector3.new(barrierThickness, height, self.size))

	-- Back barrier with entrance opening (entrance at rear)
	local doorWidth = 16
	local sideWidth = (self.size - doorWidth) / 2
	local sideOffset = (self.size / 2) - (sideWidth / 2)
	makeBarrierSegment("BarrierBackLeft", Vector3.new(-sideOffset, barrierY, -halfSize - barrierThickness / 2), Vector3.new(sideWidth, height, barrierThickness))
	makeBarrierSegment("BarrierBackRight", Vector3.new(sideOffset, barrierY, -halfSize - barrierThickness / 2), Vector3.new(sideWidth, height, barrierThickness))

	-- Arch over entrance
	makeBarrierSegment("BarrierArch", Vector3.new(0, height - 0.5, -halfSize - barrierThickness / 2), Vector3.new(doorWidth, 2, barrierThickness))
end

function PlayerBase:ClearVisualBarrier()
	if self.barrierFolder then
		self.barrierFolder:Destroy()
		self.barrierFolder = nil
	end
end

function PlayerBase:SetActivatePadState(statusText, color, canTouch)
	local padColor = color or Color3.fromRGB(46, 204, 113)
	-- Active state uses a lighter mute so the pad reads as brighter/more inviting
	local activeMuted = Color3.fromRGB(
		math.floor(padColor.R * 255 * 0.60),
		math.floor(padColor.G * 255 * 0.60),
		math.floor(padColor.B * 255 * 0.60)
	)
	if self.activatePad then
		self.activatePad.Color = activeMuted
		if canTouch ~= nil then
			self.activatePad.CanTouch = canTouch
		end
	end
	if self.activateGlow then
		self.activateGlow.Color = padColor
		self.activateGlow.Brightness = canTouch and 0.7 or 0.45
	end
	if self.activateLabel then
		self.activateLabel.Text = statusText
		self.activateLabel.TextColor3 = Color3.fromRGB(
			math.floor(padColor.R * 255 * 0.85),
			math.floor(padColor.G * 255 * 0.85),
			math.floor(padColor.B * 255 * 0.85)
		)
	end
end

function PlayerBase:GetSpawnCFrame()
	if self.spawnLocation then
		return self.spawnLocation.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(self.center + Vector3.new(0, 4, 0))
end

function PlayerBase:GetPosition()
	return self.center
end

function PlayerBase:OnClaim(callback)
	table.insert(self._claimCallbacks, callback)
end

function PlayerBase:OnBank(callback)
	table.insert(self._bankCallbacks, callback)
end

function PlayerBase:OnActivate(callback)
	table.insert(self._activateCallbacks, callback)
end

function PlayerBase:OnOpenVault(callback)
	table.insert(self._openVaultCallbacks, callback)
end

function PlayerBase:OnMiniGamePrompt(callback)
	table.insert(self._miniGamePromptCallbacks, callback)
end

function PlayerBase:Destroy()
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	self._claimCallbacks = {}
	self._bankCallbacks = {}
	self._activateCallbacks = {}
	self._openVaultCallbacks = {}
	self._miniGamePromptCallbacks = {}
	self._openVaultCallbacks = {}
end

return PlayerBase
