--[[
	CoinForge.lua
	Micro-Tycoon Pilot Mini-Game for the Sky Sub-Arena.
	Loop: Raw Ore Hopper -> Smelting Furnace (bellows pumping) -> Hydraulic Stamper.
	Players race against the 60-second clock to smelt and stamp out coin batches!
]]

local CoinForge = {}
CoinForge.__index = CoinForge

function CoinForge.Start(options)
	local self = setmetatable({}, CoinForge)

	self.player = options.player
	self.base = options.base
	self.container = options.gameContentFolder
	self.center = options.center
	self.duration = options.duration or 60
	self.onProgress = options.onProgress
	self.onComplete = options.onComplete

	self.isStopped = false
	self.connections = {}
	self.batchesStamped = 0

	-- Player state in factory
	self.carriedItem = "None"
	self.crucibleState = "Empty"
	self.smeltPumps = 0
	self.maxSmeltPumps = 3

	self:BuildWorld()
	self:UpdateStatus()

	return self
end

function CoinForge:BuildWorld()
	local folder = self.container
	local center = self.center

	-- 1. Raw Ore Hopper (Left station)
	local oreBin = Instance.new("Part")
	oreBin.Name = "OreBin"
	oreBin.Size = Vector3.new(6, 3, 6)
	oreBin.Position = center + Vector3.new(-14, 2.5, 0)
	oreBin.Anchored = true
	oreBin.Material = Enum.Material.Metal
	oreBin.Color = Color3.fromRGB(55, 60, 68)
	oreBin.Parent = folder

	local oreGold = Instance.new("Part")
	oreGold.Name = "OreGold"
	oreGold.Size = Vector3.new(5.2, 1.5, 5.2)
	oreGold.Position = oreBin.Position + Vector3.new(0, 1.2, 0)
	oreGold.Anchored = true
	oreGold.Material = Enum.Material.Neon
	oreGold.Color = Color3.fromRGB(241, 196, 15)
	oreGold.Parent = folder

	local oreLight = Instance.new("PointLight")
	oreLight.Color = Color3.fromRGB(255, 215, 0)
	oreLight.Brightness = 0.5
	oreLight.Range = 8
	oreLight.Parent = oreGold

	local orePrompt = Instance.new("ProximityPrompt")
	orePrompt.Name = "OrePrompt"
	orePrompt.ActionText = "Grab Raw Gold Ore"
	orePrompt.ObjectText = "Ore Cart"
	orePrompt.KeyboardKeyCode = Enum.KeyCode.E
	orePrompt.RequiresLineOfSight = false
	orePrompt.MaxActivationDistance = 10
	orePrompt.HoldDuration = 0
	orePrompt.Parent = oreBin
	self.orePrompt = orePrompt

	-- 2. Smelting Furnace / Crucible (Center station)
	local furnace = Instance.new("Part")
	furnace.Name = "Furnace"
	furnace.Size = Vector3.new(7, 5, 7)
	furnace.Position = center + Vector3.new(0, 3.5, 6)
	furnace.Anchored = true
	furnace.Material = Enum.Material.Cobblestone
	furnace.Color = Color3.fromRGB(45, 52, 58)
	furnace.Parent = folder

	local furnaceCore = Instance.new("Part")
	furnaceCore.Name = "FurnaceCore"
	furnaceCore.Size = Vector3.new(4, 3, 4)
	furnaceCore.Position = furnace.Position + Vector3.new(0, 0, -1)
	furnaceCore.Anchored = true
	furnaceCore.Material = Enum.Material.Neon
	furnaceCore.Color = Color3.fromRGB(230, 126, 34)
	furnaceCore.Parent = folder
	self.furnaceCore = furnaceCore

	local furnaceLight = Instance.new("PointLight")
	furnaceLight.Color = Color3.fromRGB(255, 120, 30)
	furnaceLight.Brightness = 0.8
	furnaceLight.Range = 12
	furnaceLight.Parent = furnaceCore
	self.furnaceLight = furnaceLight

	local furnacePrompt = Instance.new("ProximityPrompt")
	furnacePrompt.Name = "FurnacePrompt"
	furnacePrompt.ActionText = "Deposit Ore into Furnace"
	furnacePrompt.ObjectText = "Crucible"
	furnacePrompt.KeyboardKeyCode = Enum.KeyCode.E
	furnacePrompt.RequiresLineOfSight = false
	furnacePrompt.MaxActivationDistance = 10
	furnacePrompt.HoldDuration = 0
	furnacePrompt.Parent = furnace
	self.furnacePrompt = furnacePrompt

	-- 3. Hydraulic Coin Stamper (Right station)
	local stamperBase = Instance.new("Part")
	stamperBase.Name = "StamperBase"
	stamperBase.Size = Vector3.new(6, 2, 6)
	stamperBase.Position = center + Vector3.new(14, 2, 0)
	stamperBase.Anchored = true
	stamperBase.Material = Enum.Material.DiamondPlate
	stamperBase.Color = Color3.fromRGB(40, 45, 50)
	stamperBase.Parent = folder

	local stamperAnvil = Instance.new("Part")
	stamperAnvil.Name = "StamperAnvil"
	stamperAnvil.Size = Vector3.new(4, 1.2, 4)
	stamperAnvil.Position = stamperBase.Position + Vector3.new(0, 1.2, 0)
	stamperAnvil.Anchored = true
	stamperAnvil.Material = Enum.Material.Metal
	stamperAnvil.Color = Color3.fromRGB(90, 95, 105)
	stamperAnvil.Parent = folder

	local stamperHead = Instance.new("Part")
	stamperHead.Name = "StamperHead"
	stamperHead.Size = Vector3.new(3.6, 2, 3.6)
	stamperHead.Position = stamperAnvil.Position + Vector3.new(0, 3.5, 0)
	stamperHead.Anchored = true
	stamperHead.Material = Enum.Material.Neon
	stamperHead.Color = Color3.fromRGB(241, 196, 15)
	stamperHead.Parent = folder
	self.stamperHead = stamperHead

	local stamperPrompt = Instance.new("ProximityPrompt")
	stamperPrompt.Name = "StamperPrompt"
	stamperPrompt.ActionText = "Load Ingot & Stamp Coins"
	stamperPrompt.ObjectText = "Hydraulic Stamper"
	stamperPrompt.KeyboardKeyCode = Enum.KeyCode.E
	stamperPrompt.RequiresLineOfSight = false
	stamperPrompt.MaxActivationDistance = 10
	stamperPrompt.HoldDuration = 0
	stamperPrompt.Parent = stamperAnvil
	self.stamperPrompt = stamperPrompt

	-- Floating HUD Billboard above center showing current carried item
	local statusPart = Instance.new("Part")
	statusPart.Name = "StatusSign"
	statusPart.Size = Vector3.new(1, 1, 1)
	statusPart.Position = center + Vector3.new(0, 10, 0)
	statusPart.Anchored = true
	statusPart.Transparency = 1
	statusPart.CanCollide = false
	statusPart.Parent = folder

	local statusGui = Instance.new("BillboardGui")
	statusGui.Name = "StatusGui"
	statusGui.Size = UDim2.new(0, 240, 0, 60)
	statusGui.AlwaysOnTop = true
	statusGui.Parent = statusPart

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 1, 0)
	statusLabel.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
	statusLabel.BackgroundTransparency = 0.2
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.Text = "CARRIER: Empty"
	statusLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
	statusLabel.TextSize = 16
	statusLabel.Parent = statusGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = statusLabel
	self.statusLabel = statusLabel

	-- =====================================================================
	-- Interactivity Bindings
	-- =====================================================================

	-- Step 1: Ore Cart Pickup
	local connOre = orePrompt.Triggered:Connect(function(player)
		if player ~= self.player or self.isStopped then return end
		if self.carriedItem ~= "None" then
			return
		end
		self.carriedItem = "CarryingOre"
		self:UpdateStatus()
	end)
	table.insert(self.connections, connOre)

	-- Step 2: Furnace Deposit & Bellows Smelting
	local connFurnace = furnacePrompt.Triggered:Connect(function(player)
		if player ~= self.player or self.isStopped then return end

		if self.crucibleState == "Empty" and self.carriedItem == "CarryingOre" then
			self.carriedItem = "None"
			self.crucibleState = "Smelting"
			self.smeltPumps = 0
			self:UpdateStatus()

			-- Automated slow smelt (5s) unless pumped
			task.spawn(function()
				local currentSessionSmelt = self.batchesStamped
				task.wait(5)
				local currentState: string = self.crucibleState
				if not self.isStopped and currentState == "Smelting" and self.batchesStamped == currentSessionSmelt then
					self.crucibleState = "IngotReady"
					self:UpdateStatus()
				end
			end)

		elseif self.crucibleState == "Smelting" then
			-- Pump bellows to accelerate smelting!
			self.smeltPumps += 1
			self.furnaceLight.Brightness = 1.4
			task.delay(0.2, function()
				if not self.isStopped and self.furnaceLight then
					self.furnaceLight.Brightness = 0.8
				end
			end)

			if self.smeltPumps >= self.maxSmeltPumps then
				self.crucibleState = "IngotReady"
			end
			self:UpdateStatus()

		elseif self.crucibleState == "IngotReady" and self.carriedItem == "None" then
			-- Pick up molten ingot
			self.crucibleState = "Empty"
			self.carriedItem = "CarryingIngot"
			self:UpdateStatus()
		end
	end)
	table.insert(self.connections, connFurnace)

	-- Step 3: Coin Stamper Action
	local connStamper = stamperPrompt.Triggered:Connect(function(player)
		if player ~= self.player or self.isStopped then return end

		if self.carriedItem == "CarryingIngot" then
			self.carriedItem = "None"
			self.batchesStamped += 1

			-- Animate stamper slam
			self.stamperHead.Position = self.stamperHead.Position - Vector3.new(0, 1.8, 0)
			self.stamperHead.Color = Color3.fromRGB(255, 255, 255)

			task.delay(0.25, function()
				if not self.isStopped and self.stamperHead then
					self.stamperHead.Position = self.stamperHead.Position + Vector3.new(0, 1.8, 0)
					self.stamperHead.Color = Color3.fromRGB(241, 196, 15)
				end
			end)

			self:UpdateStatus()
		end
	end)
	table.insert(self.connections, connStamper)
end

function CoinForge:UpdateStatus()
	if self.isStopped then
		return
	end

	-- Update prompts
	if self.orePrompt then
		self.orePrompt.Enabled = (self.carriedItem == "None")
	end

	if self.furnacePrompt then
		if self.crucibleState == "Empty" then
			self.furnacePrompt.Enabled = (self.carriedItem == "CarryingOre")
			self.furnacePrompt.ActionText = "Deposit Ore into Furnace"
			self.furnaceCore.Color = Color3.fromRGB(120, 60, 20)
		elseif self.crucibleState == "Smelting" then
			self.furnacePrompt.Enabled = true
			self.furnacePrompt.ActionText = string.format("Pump Bellows! [%d/%d]", self.smeltPumps, self.maxSmeltPumps)
			self.furnaceCore.Color = Color3.fromRGB(230, 126, 34)
		elseif self.crucibleState == "IngotReady" then
			self.furnacePrompt.Enabled = (self.carriedItem == "None")
			self.furnacePrompt.ActionText = "Collect Molten Ingot"
			self.furnaceCore.Color = Color3.fromRGB(255, 220, 80)
		end
	end

	if self.stamperPrompt then
		self.stamperPrompt.Enabled = (self.carriedItem == "CarryingIngot")
	end

	-- Update floating carrier text
	if self.statusLabel then
		local carriedText = "None"
		if self.carriedItem == "CarryingOre" then
			carriedText = "Gold Ore (Take to Furnace)"
		elseif self.carriedItem == "CarryingIngot" then
			carriedText = "Molten Ingot (Take to Stamper!)"
		end
		self.statusLabel.Text = string.format("CARRIER: %s\nBatches Minted: %d", carriedText, self.batchesStamped)
	end

	-- Notify Service Progress
	if self.onProgress then
		self.onProgress({
			objective = string.format("Batches Minted: %d | Carrier: %s", self.batchesStamped, self.carriedItem),
			score = self.batchesStamped,
		})
	end
end

function CoinForge:GetObjective()
	return string.format("Batches Minted: %d", self.batchesStamped)
end

function CoinForge:Stop()
	if self.isStopped then
		return
	end
	self.isStopped = true

	for _, conn in ipairs(self.connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	self.connections = {}
end

return CoinForge
