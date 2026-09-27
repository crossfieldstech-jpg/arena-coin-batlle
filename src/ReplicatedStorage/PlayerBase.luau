local Players = game:GetService("Players")

local PlayerBase = {}
PlayerBase.__index = PlayerBase

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

	-- Callbacks
	self._claimCallbacks = {}
	self._bankCallbacks = {}
	self._activateCallbacks = {}
	self._openVaultCallbacks = {}

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
	makeCurb("CurbBack", Vector3.new(0, curbY, -halfSize), Vector3.new(self.size, curbHeight, curbThickness))
	makeCurb("CurbLeft", Vector3.new(-halfSize, curbY, 0), Vector3.new(curbThickness, curbHeight, self.size))
	makeCurb("CurbRight", Vector3.new(halfSize, curbY, 0), Vector3.new(curbThickness, curbHeight, self.size))

	-- Front curb with 16-stud wide walkway opening
	local frontDoorWidth = 16
	local frontSideWidth = (self.size - frontDoorWidth) / 2
	local frontSideOffset = (self.size / 2) - (frontSideWidth / 2)
	makeCurb("CurbFrontLeft", Vector3.new(-frontSideOffset, curbY, halfSize), Vector3.new(frontSideWidth, curbHeight, curbThickness))
	makeCurb("CurbFrontRight", Vector3.new(frontSideOffset, curbY, halfSize), Vector3.new(frontSideWidth, curbHeight, curbThickness))

	-- Entrance Gate Signboard Post (Standing at the front entrance)
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
	signText.Size = UDim2.new(1, 0, 1, 0)
	signText.BackgroundTransparency = 1
	signText.Font = Enum.Font.GothamBold
	signText.Text = string.format("%s\n[ Unclaimed ]", self.theme.name)
	signText.TextColor3 = self.theme.accentColor
	signText.TextScaled = true
	signText.Parent = signGui
	self.signLabel = signText

	-- Base SpawnLocation inside (Sanctuary in rear)
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "BaseSpawn"
	spawnPad.Size = Vector3.new(8, 0.6, 8)
	spawnPad.CFrame = baseCFrame * CFrame.new(0, 0.8, -halfSize + 8)
	spawnPad.Anchored = true
	spawnPad.Material = Enum.Material.Neon
	spawnPad.Color = self.theme.accentColor
	spawnPad.Neutral = true
	spawnPad.Enabled = (self.owner == nil)
	spawnPad.Parent = model
	self.spawnLocation = spawnPad

	-- Interactive Claim Pad in center of base
	local claim = Instance.new("Part")
	claim.Name = "ClaimPad"
	claim.Shape = Enum.PartType.Cylinder
	claim.Size = Vector3.new(0.5, 12, 12)
	claim.CFrame = baseCFrame * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	claim.Anchored = true
	claim.CanCollide = false
	claim.Material = Enum.Material.Neon
	claim.Color = Color3.fromRGB(241, 196, 15) -- Gold claim pad
	claim.Parent = model
	self.claimPad = claim

	local claimRing = Instance.new("Part")
	claimRing.Name = "ClaimRing"
	claimRing.Shape = Enum.PartType.Cylinder
	claimRing.Size = Vector3.new(0.05, 18, 18)
	claimRing.CFrame = baseCFrame * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90))
	claimRing.Anchored = true
	claimRing.CanCollide = false
	claimRing.Material = Enum.Material.SmoothPlastic
	claimRing.Color = self.theme.accentColor
	claimRing.Parent = model

	local claimBillboard = Instance.new("BillboardGui")
	claimBillboard.Name = "ClaimBillboard"
	claimBillboard.Size = UDim2.new(0, 220, 0, 60)
	claimBillboard.StudsOffset = Vector3.new(0, 5, 0)
	claimBillboard.AlwaysOnTop = true
	claimBillboard.Parent = claim

	local claimText = Instance.new("TextLabel")
	claimText.Name = "ClaimLabel"
	claimText.Size = UDim2.new(1, 0, 1, 0)
	claimText.BackgroundTransparency = 1
	claimText.Font = Enum.Font.GothamBold
	claimText.Text = "★ STEP TO CLAIM BASE ★"
	claimText.TextColor3 = Color3.fromRGB(255, 230, 80)
	claimText.TextScaled = true
	claimText.Parent = claimBillboard
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
	bankLid.Material = Enum.Material.Neon
	bankLid.Color = self.theme.accentColor
	bankLid.Parent = model

	local bankLabelGui = Instance.new("BillboardGui")
	bankLabelGui.Name = "BankLabelGui"
	bankLabelGui.Size = UDim2.new(0, 160, 0, 45)
	bankLabelGui.StudsOffset = Vector3.new(0, 4, 0)
	bankLabelGui.AlwaysOnTop = true
	bankLabelGui.Parent = bank

	local bankText = Instance.new("TextLabel")
	bankText.Size = UDim2.new(1, 0, 1, 0)
	bankText.BackgroundTransparency = 1
	bankText.Font = Enum.Font.GothamBold
	bankText.Text = "COIN VAULT\n[Step to Deposit]"
	bankText.TextColor3 = Color3.fromRGB(241, 196, 15)
	bankText.TextScaled = true
	bankText.Parent = bankLabelGui

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
		zoneText.Size = UDim2.new(1, 0, 1, 0)
		zoneText.BackgroundTransparency = 1
		zoneText.Font = Enum.Font.GothamMedium
		zoneText.Text = labelText
		zoneText.TextColor3 = Color3.fromRGB(180, 190, 205)
		zoneText.TextScaled = true
		zoneText.Parent = zoneGui

		return zonePad
	end

	-- Activity Zone 1 (Right Front Yard - e.g. Upgrades / Tasks)
	makeActivityZone("ActivityZone_Alpha", Vector3.new(22, 0.6, 20), "ACTIVITY ZONE ALPHA\n[Open for Tasks]")

	-- Activity Zone 2 (Left Front Yard - e.g. Workshops / Mini-games)
	makeActivityZone("ActivityZone_Beta", Vector3.new(-22, 0.6, 20), "ACTIVITY ZONE BETA\n[Open for Tasks]")

	-- Activity Zone 3 (Rear Workshop Yard)
	makeActivityZone("ActivityZone_Gamma", Vector3.new(22, 0.6, -18), "WORKSHOP YARD\n[Open for Future Expansion]")

	-- Interactive Arena Activation Pad (Inside the player's base courtyard)
	local activatePad = Instance.new("Part")
	activatePad.Name = "ArenaActivatePad"
	activatePad.Shape = Enum.PartType.Cylinder
	activatePad.Size = Vector3.new(0.6, 9, 9)
	activatePad.CFrame = baseCFrame * CFrame.new(0, 0.8, halfSize - 14) * CFrame.Angles(0, 0, math.rad(90))
	activatePad.Anchored = true
	activatePad.CanCollide = false
	activatePad.Material = Enum.Material.Neon
	activatePad.Color = Color3.fromRGB(46, 204, 113) -- Green ready pad
	activatePad.Parent = model
	self.activatePad = activatePad

	local activateRing = Instance.new("Part")
	activateRing.Name = "ActivateRing"
	activateRing.Shape = Enum.PartType.Cylinder
	activateRing.Size = Vector3.new(0.1, 11, 11)
	activateRing.CFrame = baseCFrame * CFrame.new(0, 0.6, halfSize - 14) * CFrame.Angles(0, 0, math.rad(90))
	activateRing.Anchored = true
	activateRing.CanCollide = false
	activateRing.Material = Enum.Material.SmoothPlastic
	activateRing.Color = self.theme.accentColor
	activateRing.Parent = model

	local activateGui = Instance.new("BillboardGui")
	activateGui.Name = "ActivateBillboard"
	activateGui.Size = UDim2.new(0, 240, 0, 50)
	activateGui.StudsOffset = Vector3.new(0, 3.5, 0)
	activateGui.AlwaysOnTop = true
	activateGui.Parent = activatePad

	local activateText = Instance.new("TextLabel")
	activateText.Name = "ActivateText"
	activateText.Size = UDim2.new(1, 0, 1, 0)
	activateText.BackgroundTransparency = 1
	activateText.Font = Enum.Font.GothamBold
	activateText.Text = "⚡ START ARENA RUN ⚡\n[Step to Open Gate]"
	activateText.TextColor3 = Color3.fromRGB(46, 204, 113)
	activateText.TextScaled = true
	activateText.Parent = activateGui
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
		self.claimPad.Color = self.theme.accentColor
	end

	if self.spawnLocation then
		self.spawnLocation.Enabled = false
	end
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
		self.claimLabel.Text = "★ STEP TO CLAIM BASE ★"
		self.claimLabel.TextColor3 = Color3.fromRGB(255, 230, 80)
	end

	if self.claimPad then
		self.claimPad.Color = Color3.fromRGB(241, 196, 15)
	end

	if self.spawnLocation then
		self.spawnLocation.Enabled = true
	end

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

	-- Back wall
	makeWallSegment("BackWall", Vector3.new(0, wallY, -halfSize - wallThickness / 2), Vector3.new(self.size + wallThickness * 2, height, wallThickness))
	-- Left wall
	makeWallSegment("LeftWall", Vector3.new(-halfSize - wallThickness / 2, wallY, 0), Vector3.new(wallThickness, height, self.size))
	-- Right wall
	makeWallSegment("RightWall", Vector3.new(halfSize + wallThickness / 2, wallY, 0), Vector3.new(wallThickness, height, self.size))

	-- Front wall with entrance opening
	local doorWidth = 16
	local sideWidth = (self.size - doorWidth) / 2
	local sideOffset = (self.size / 2) - (sideWidth / 2)
	makeWallSegment("FrontLeftWall", Vector3.new(-sideOffset, wallY, halfSize + wallThickness / 2), Vector3.new(sideWidth, height, wallThickness))
	makeWallSegment("FrontRightWall", Vector3.new(sideOffset, wallY, halfSize + wallThickness / 2), Vector3.new(sideWidth, height, wallThickness))

	-- Arch over base entrance
	local arch = makeWallSegment("EntranceArch", Vector3.new(0, height - 0.5, halfSize + wallThickness / 2), Vector3.new(doorWidth, 2, wallThickness), self.theme.accentColor)

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

function PlayerBase:SetActivatePadState(statusText, color, canTouch)
	if self.activatePad then
		self.activatePad.Color = color or Color3.fromRGB(46, 204, 113)
		if canTouch ~= nil then
			self.activatePad.CanTouch = canTouch
		end
	end
	if self.activateLabel then
		self.activateLabel.Text = statusText
		self.activateLabel.TextColor3 = color or Color3.fromRGB(46, 204, 113)
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

function PlayerBase:Destroy()
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	self._claimCallbacks = {}
	self._bankCallbacks = {}
	self._activateCallbacks = {}
	self._openVaultCallbacks = {}
end

return PlayerBase
