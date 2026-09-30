--[[
	AlienBaseDefence/Server.luau
	Decoupled Server Engine for the Alien Base Defence tactical tower defense mini-game package.
	Operates seamlessly in embedded Procedural Sky Sub-Arena or Standalone Universe places.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DefaultConfig = require(ReplicatedStorage:WaitForChild("MiniGames"):WaitForChild("Packages"):WaitForChild("AlienBaseDefence"):WaitForChild("Config"))

local function mergeConfig(defaults, overrides)
	local result = {}
	if typeof(defaults) == "table" then
		for k, v in pairs(defaults) do
			if typeof(v) == "table" then
				local sub = {}
				for sk, sv in pairs(v) do sub[sk] = sv end
				result[k] = sub
			else
				result[k] = v
			end
		end
	end
	if typeof(overrides) == "table" then
		for k, v in pairs(overrides) do
			if typeof(v) == "table" and typeof(result[k]) == "table" then
				for sk, sv in pairs(v) do result[k][sk] = sv end
			else
				result[k] = v
			end
		end
	end
	return result
end

local AlienBaseDefenceServer = {}
AlienBaseDefenceServer.__index = AlienBaseDefenceServer

local function getEnemyTypeForWave(waveIndex, iteration)
	if waveIndex == 1 then
		return "Scout"
	elseif waveIndex == 2 then
		if iteration % 2 == 0 then
			return "Armored"
		else
			return "Scout"
		end
	elseif waveIndex == 3 then
		if iteration == 1 then
			return "Boss"
		else
			return "Armored"
		end
	end
	return "Scout"
end

function AlienBaseDefenceServer.Start(context)
	local self = setmetatable({}, AlienBaseDefenceServer)

	self.player = context.player
	self.base = context.base
	self.container = context.container or context.gameContentFolder or workspace
	self.center = context.center or Vector3.zero
	self.config = mergeConfig(DefaultConfig, context.config)
	self.duration = context.duration or self.config.duration or 95
	self.eventBus = context.eventBus
	self.isStandalone = context.isStandalone or false
	self.onProgress = context.onProgress
	self.onComplete = context.onComplete

	self.isStopped = false
	self.connections = {}
	self.activeEnemies = {}
	self.activeBeams = {}
	self.stations = {}
	self.currentWave = 0
	self.totalWaves = self.config.totalWaves or 3
	self.maxCoreHealth = self.config.maxCoreHealth or 100
	self.coreHealth = self.maxCoreHealth
	self.enemiesDefeated = 0

	self:BuildWorld()
	self:StartWaveLoop()

	return self
end

function AlienBaseDefenceServer:BuildWorld()
	local folder = self.container
	local center = self.center

	-- 1. Field Terrain: Rich Green Grass Layer (108x108)
	local grassPlate = Instance.new("Part")
	grassPlate.Name = "FieldGrassSurface"
	grassPlate.Size = Vector3.new(106, 0.4, 106)
	grassPlate.Position = center + Vector3.new(0, 1.1, 0)
	grassPlate.Anchored = true
	grassPlate.CanCollide = true
	grassPlate.Material = Enum.Material.Grass
	grassPlate.Color = Color3.fromRGB(42, 112, 48)
	grassPlate.TopSurface = Enum.SurfaceType.Smooth
	grassPlate.BottomSurface = Enum.SurfaceType.Smooth
	grassPlate.Parent = folder

	-- 2. Waypoint Road Coordinates (Snaking winding path)
	local relWaypoints = self.config.relativeWaypoints or {
		Vector3.new(-42, 1.2, -42),
		Vector3.new(-38, 1.2, -18),
		Vector3.new(-20, 1.2, -8),
		Vector3.new(-18, 1.2, 16),
		Vector3.new(2, 1.2, 18),
		Vector3.new(4, 1.2, -22),
		Vector3.new(24, 1.2, -18),
		Vector3.new(28, 1.2, 12),
		Vector3.new(38, 1.2, 38),
	}

	self.waypoints = {}
	for _, rel in ipairs(relWaypoints) do
		table.insert(self.waypoints, center + rel)
	end

	-- Connect waypoints with textured dirt/mud road segments
	for i = 1, #self.waypoints - 1 do
		local pA = self.waypoints[i]
		local pB = self.waypoints[i + 1]
		local dist = (pB - pA).Magnitude
		local road = Instance.new("Part")
		road.Name = "TacticalRoad_" .. i
		road.Size = Vector3.new(5.2, 0.28, dist)
		road.CFrame = CFrame.lookAt((pA + pB) / 2, pB)
		road.Anchored = true
		road.CanCollide = false
		road.Material = Enum.Material.Ground
		road.Color = Color3.fromRGB(110, 85, 62)
		road.TopSurface = Enum.SurfaceType.Smooth
		road.BottomSurface = Enum.SurfaceType.Smooth
		road.Parent = folder
	end

	-- 3. Procedural Grassy Mounds (12 rolling mounds)
	local moundOffsets = {
		Vector3.new(-36, 1.2, 12),
		Vector3.new(-26, 1.2, 34),
		Vector3.new(-40, 1.2, -8),
		Vector3.new(12, 1.2, 38),
		Vector3.new(36, 1.2, -34),
		Vector3.new(-14, 1.2, -36),
		Vector3.new(34, 1.2, -10),
		Vector3.new(-6, 1.2, 32),
		Vector3.new(18, 1.2, 36),
		Vector3.new(-28, 1.2, -6),
		Vector3.new(38, 1.2, 10),
		Vector3.new(-10, 1.2, -32),
	}

	for idx, offset in ipairs(moundOffsets) do
		local mPos = center + offset
		local mound = Instance.new("Part")
		mound.Name = "GrassyMound_" .. idx
		mound.Shape = Enum.PartType.Ball
		mound.Size = Vector3.new(10 + (idx % 3) * 2, 4 + (idx % 2), 10 + (idx % 3) * 2)
		mound.Position = mPos + Vector3.new(0, 0.5, 0)
		mound.Anchored = true
		mound.CanCollide = true
		mound.Material = Enum.Material.Grass
		mound.Color = if idx % 2 == 0 then Color3.fromRGB(48, 124, 54) else Color3.fromRGB(38, 104, 44)
		mound.Parent = folder
	end

	-- 4. Pine / Field Trees (14 lush trees)
	local treeOffsets = {
		Vector3.new(-44, 1.5, 20),
		Vector3.new(-32, 1.5, 38),
		Vector3.new(-42, 1.5, -28),
		Vector3.new(-24, 1.5, -40),
		Vector3.new(8, 1.5, 42),
		Vector3.new(24, 1.5, 40),
		Vector3.new(42, 1.5, -24),
		Vector3.new(38, 1.5, -42),
		Vector3.new(12, 1.5, -38),
		Vector3.new(-34, 1.5, 2),
		Vector3.new(42, 1.5, 4),
		Vector3.new(40, 1.5, 22),
		Vector3.new(-4, 1.5, -42),
		Vector3.new(-44, 1.5, -2),
	}

	for idx, offset in ipairs(treeOffsets) do
		local tPos = center + offset

		-- Tree Trunk
		local trunk = Instance.new("Part")
		trunk.Name = "TreeTrunk_" .. idx
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Size = Vector3.new(5.5, 1.2, 1.2)
		trunk.CFrame = CFrame.new(tPos + Vector3.new(0, 2.75, 0)) * CFrame.Angles(0, 0, math.rad(90))
		trunk.Anchored = true
		trunk.CanCollide = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(88, 58, 32)
		trunk.Parent = folder

		-- Tree Foliage Canopies
		local foliage = Instance.new("Part")
		foliage.Name = "TreeCanopy_" .. idx
		foliage.Shape = Enum.PartType.Ball
		foliage.Size = Vector3.new(5.5, 5.5, 5.5)
		foliage.Position = tPos + Vector3.new(0, 6.2, 0)
		foliage.Anchored = true
		foliage.CanCollide = false
		foliage.Material = Enum.Material.Grass
		foliage.Color = if idx % 2 == 0 then Color3.fromRGB(32, 88, 40) else Color3.fromRGB(26, 76, 34)
		foliage.Parent = folder
	end

	-- 5. Field Military Objects (Sandbag barriers, rocks, barricades)
	local sandbagPositions = {
		Vector3.new(-26, 1.4, -24),
		Vector3.new(-6, 1.4, -4),
		Vector3.new(-10, 1.4, 24),
		Vector3.new(20, 1.4, -10),
		Vector3.new(26, 1.4, 22),
		Vector3.new(34, 1.4, 34),
	}

	for idx, sOffset in ipairs(sandbagPositions) do
		local sPos = center + sOffset
		local sandbag = Instance.new("Part")
		sandbag.Name = "SandbagWall_" .. idx
		sandbag.Size = Vector3.new(3.8, 1.4, 1.2)
		sandbag.Position = sPos
		sandbag.Anchored = true
		sandbag.CanCollide = true
		sandbag.Material = Enum.Material.Sand
		sandbag.Color = Color3.fromRGB(185, 165, 125)
		sandbag.Parent = folder

		local rock = Instance.new("Part")
		rock.Name = "FieldRock_" .. idx
		rock.Shape = Enum.PartType.Ball
		rock.Size = Vector3.new(2.4, 1.8, 2.2)
		rock.Position = sPos + Vector3.new(2.5, -0.2, 1.5)
		rock.Anchored = true
		rock.CanCollide = true
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(85, 90, 95)
		rock.Parent = folder
	end

	-- 6. Outpost Command Center (Fortified Command Base at Waypoint 9)
	local outpostPos = self.waypoints[#self.waypoints]
	local outpostModel = Instance.new("Model")
	outpostModel.Name = "OutpostCommandBase"
	outpostModel.Parent = folder

	-- Bunker Foundation
	local bunkerBase = Instance.new("Part")
	bunkerBase.Name = "BunkerBase"
	bunkerBase.Size = Vector3.new(10, 3.6, 10)
	bunkerBase.Position = outpostPos + Vector3.new(0, 1.8, 0)
	bunkerBase.Anchored = true
	bunkerBase.CanCollide = true
	bunkerBase.Material = Enum.Material.Concrete
	bunkerBase.Color = Color3.fromRGB(52, 60, 68)
	bunkerBase.Parent = outpostModel

	-- Command Core Dome
	local commandCore = Instance.new("Part")
	commandCore.Name = "CommandCore"
	commandCore.Shape = Enum.PartType.Ball
	commandCore.Size = Vector3.new(5.2, 5.2, 5.2)
	commandCore.Position = bunkerBase.Position + Vector3.new(0, 2.6, 0)
	commandCore.Anchored = true
	commandCore.Material = Enum.Material.Neon
	commandCore.Color = Color3.fromRGB(46, 204, 113)
	commandCore.Parent = outpostModel
	self.vaultCore = commandCore

	-- Radar Mast & Dish
	local radarMast = Instance.new("Part")
	radarMast.Name = "RadarMast"
	radarMast.Size = Vector3.new(0.6, 6.5, 0.6)
	radarMast.Position = bunkerBase.Position + Vector3.new(3.2, 4.5, -3.2)
	radarMast.Anchored = true
	radarMast.CanCollide = false
	radarMast.Material = Enum.Material.Metal
	radarMast.Color = Color3.fromRGB(75, 80, 85)
	radarMast.Parent = outpostModel

	local radarDish = Instance.new("Part")
	radarDish.Name = "RadarDish"
	radarDish.Shape = Enum.PartType.Cylinder
	radarDish.Size = Vector3.new(0.4, 2.8, 2.8)
	radarDish.CFrame = CFrame.new(bunkerBase.Position + Vector3.new(3.2, 7.5, -3.2)) * CFrame.Angles(0, math.rad(45), math.rad(60))
	radarDish.Anchored = true
	radarDish.CanCollide = false
	radarDish.Material = Enum.Material.Metal
	radarDish.Color = Color3.fromRGB(130, 140, 150)
	radarDish.Parent = outpostModel

	-- Command Ambient Glow
	local coreLight = Instance.new("PointLight")
	coreLight.Color = Color3.fromRGB(80, 255, 160)
	coreLight.Brightness = 1.2
	coreLight.Range = 16
	coreLight.Parent = commandCore

	-- Billboard GUI for Outpost Integrity
	local outpostGui = Instance.new("BillboardGui")
	outpostGui.Name = "OutpostGui"
	outpostGui.Size = UDim2.new(0, 240, 0, 52)
	outpostGui.StudsOffset = Vector3.new(0, 7.5, 0)
	outpostGui.AlwaysOnTop = true
	outpostGui.Parent = commandCore

	local outpostLabel = Instance.new("TextLabel")
	outpostLabel.Name = "OutpostLabel"
	outpostLabel.Size = UDim2.new(1, 0, 1, 0)
	outpostLabel.BackgroundColor3 = Color3.fromRGB(16, 24, 20)
	outpostLabel.BackgroundTransparency = 0.15
	outpostLabel.Font = Enum.Font.GothamBold
	outpostLabel.Text = "🪖 OUTPOST INTEGRITY: 100%"
	outpostLabel.TextColor3 = Color3.fromRGB(140, 255, 170)
	outpostLabel.TextSize = 14
	outpostLabel.Parent = outpostGui

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 8)
	labelCorner.Parent = outpostLabel

	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = Color3.fromRGB(46, 204, 113)
	labelStroke.Thickness = 1.4
	labelStroke.Parent = outpostLabel
	self.vaultLabel = outpostLabel
	self.vaultStroke = labelStroke

	-- 7. 5 Tactical Defense Stations (Pedestals + Sandbags + Prompts)
	local nodeOffsets = self.config.nodeOffsets or {
		Vector3.new(-30, 1.5, -28),
		Vector3.new(-10, 1.5, -6),
		Vector3.new(-14, 1.5, 22),
		Vector3.new(16, 1.5, -12),
		Vector3.new(22, 1.5, 20),
	}

	for idx, offset in ipairs(nodeOffsets) do
		local pos = center + offset

		-- Concrete Station Pad
		local pad = Instance.new("Part")
		pad.Name = "DefensePad_" .. idx
		pad.Shape = Enum.PartType.Cylinder
		pad.Size = Vector3.new(0.8, 6.5, 6.5)
		pad.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		pad.Anchored = true
		pad.CanCollide = true
		pad.Material = Enum.Material.Concrete
		pad.Color = Color3.fromRGB(55, 62, 68)
		pad.Parent = folder

		-- Sandbag Perimeter around Station
		local ringOffsets = {
			Vector3.new(-2.8, 0.6, 0),
			Vector3.new(2.8, 0.6, 0),
			Vector3.new(0, 0.6, -2.8),
			Vector3.new(0, 0.6, 2.8),
		}
		for rIdx, rOff in ipairs(ringOffsets) do
			local sb = Instance.new("Part")
			sb.Name = string.format("StationSandbag_%d_%d", idx, rIdx)
			sb.Size = if rOff.X ~= 0 then Vector3.new(1.0, 1.2, 3.2) else Vector3.new(3.2, 1.2, 1.0)
			sb.Position = pos + rOff
			sb.Anchored = true
			sb.CanCollide = true
			sb.Material = Enum.Material.Sand
			sb.Color = Color3.fromRGB(180, 160, 120)
			sb.Parent = folder
		end

		-- Tactical Deployment ProximityPrompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DeployPrompt"
		prompt.ActionText = "Deploy Soldier Bunker [E]"
		prompt.ObjectText = string.format("Station #%d", idx)
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 12
		prompt.HoldDuration = 0
		prompt.Parent = pad

		local stationData = {
			index = idx,
			pad = pad,
			prompt = prompt,
			level = 0,
			model = nil,
			lastShot = 0,
			barrelPosition = pos + Vector3.new(0, 3, 0),
		}

		prompt.Triggered:Connect(function(player)
			if player ~= self.player or self.isStopped then
				return
			end
			self:InteractStation(stationData)
		end)

		table.insert(self.stations, stationData)
	end

	-- Station Automated Targeting & Firing Loop
	local firingConn = RunService.Heartbeat:Connect(function()
		if self.isStopped then
			return
		end
		local now = os.clock()
		for _, station in ipairs(self.stations) do
			if station.level > 0 then
				local stats = self.config.sentryStats
				local tierKey = if station.level == 1 then "Tier1" else "Tier2"
				local tierStats = stats and stats[tierKey]
				local fireRate = (tierStats and tierStats.fireRate) or (if station.level == 1 then 0.45 else 0.25)
				if now - station.lastShot >= fireRate then
					self:FireStation(station, tierStats)
					station.lastShot = now
				end
			end
		end
	end)
	table.insert(self.connections, firingConn)
end

function AlienBaseDefenceServer:InteractStation(station)
	if station.level == 0 then
		station.level = 1
		station.prompt.ActionText = "Upgrade to Heavy Plasma Bunker [E]"
		station.prompt.ObjectText = string.format("Soldier Bunker #%d", station.index)

		-- Build Tier 1: Fortified Soldier Bunker
		local bunkerModel = Instance.new("Model")
		bunkerModel.Name = "SoldierBunker_" .. station.index
		bunkerModel.Parent = self.container

		-- Fortification Body
		local bunkerBody = Instance.new("Part")
		bunkerBody.Name = "BunkerArmor"
		bunkerBody.Size = Vector3.new(4.2, 2.6, 4.2)
		bunkerBody.Position = station.pad.Position + Vector3.new(0, 1.7, 0)
		bunkerBody.Anchored = true
		bunkerBody.CanCollide = true
		bunkerBody.Material = Enum.Material.DiamondPlate
		bunkerBody.Color = Color3.fromRGB(58, 85, 42) -- Camo Olive
		bunkerBody.Parent = bunkerModel

		-- Soldier Guard Figure (Helmet, Torso, Rifle)
		local soldierTorso = Instance.new("Part")
		soldierTorso.Name = "SoldierTorso"
		soldierTorso.Size = Vector3.new(1.4, 1.6, 0.8)
		soldierTorso.Position = bunkerBody.Position + Vector3.new(0, 2.0, 0)
		soldierTorso.Anchored = true
		soldierTorso.CanCollide = false
		soldierTorso.Material = Enum.Material.Fabric
		soldierTorso.Color = Color3.fromRGB(48, 68, 38)
		soldierTorso.Parent = bunkerModel

		local soldierHelmet = Instance.new("Part")
		soldierHelmet.Name = "SoldierHelmet"
		soldierHelmet.Size = Vector3.new(1.2, 1.0, 1.2)
		soldierHelmet.Position = soldierTorso.Position + Vector3.new(0, 1.2, 0)
		soldierHelmet.Anchored = true
		soldierHelmet.CanCollide = false
		soldierHelmet.Material = Enum.Material.Metal
		soldierHelmet.Color = Color3.fromRGB(38, 55, 30)
		soldierHelmet.Parent = bunkerModel

		local rifleBarrel = Instance.new("Part")
		rifleBarrel.Name = "RifleBarrel"
		rifleBarrel.Size = Vector3.new(0.3, 0.3, 2.4)
		rifleBarrel.Position = soldierTorso.Position + Vector3.new(0.6, 0.2, 1.4)
		rifleBarrel.Anchored = true
		rifleBarrel.CanCollide = false
		rifleBarrel.Material = Enum.Material.Metal
		rifleBarrel.Color = Color3.fromRGB(25, 25, 25)
		rifleBarrel.Parent = bunkerModel

		station.model = bunkerModel
		station.barrelPosition = rifleBarrel.Position

	elseif station.level == 1 then
		station.level = 2
		station.prompt.Enabled = false

		-- Remove Tier 1 model
		if station.model then
			pcall(function() station.model:Destroy() end)
		end

		-- Build Tier 2: Heavy Plasma Fortified Bunker
		local plasmaModel = Instance.new("Model")
		plasmaModel.Name = "HeavyPlasmaBunker_" .. station.index
		plasmaModel.Parent = self.container

		local heavyBase = Instance.new("Part")
		heavyBase.Name = "HeavyArmor"
		heavyBase.Size = Vector3.new(4.8, 3.2, 4.8)
		heavyBase.Position = station.pad.Position + Vector3.new(0, 2.0, 0)
		heavyBase.Anchored = true
		heavyBase.CanCollide = true
		heavyBase.Material = Enum.Material.CorrodedMetal
		heavyBase.Color = Color3.fromRGB(41, 128, 185) -- Heavy Plasma Blue
		heavyBase.Parent = plasmaModel

		-- Shield Emitter
		local shieldDome = Instance.new("Part")
		shieldDome.Name = "ShieldEmitter"
		shieldDome.Shape = Enum.PartType.Ball
		shieldDome.Size = Vector3.new(2.4, 2.4, 2.4)
		shieldDome.Position = heavyBase.Position + Vector3.new(0, 2.0, 0)
		shieldDome.Anchored = true
		shieldDome.CanCollide = false
		shieldDome.Material = Enum.Material.ForceField
		shieldDome.Color = Color3.fromRGB(52, 152, 219)
		shieldDome.Parent = plasmaModel

		-- Dual Glowing Plasma Cannons
		local cannonLeft = Instance.new("Part")
		cannonLeft.Name = "PlasmaCannonL"
		cannonLeft.Size = Vector3.new(0.5, 0.5, 3.2)
		cannonLeft.Position = heavyBase.Position + Vector3.new(-1.2, 0.5, 1.8)
		cannonLeft.Anchored = true
		cannonLeft.CanCollide = false
		cannonLeft.Material = Enum.Material.Neon
		cannonLeft.Color = Color3.fromRGB(0, 210, 255)
		cannonLeft.Parent = plasmaModel

		local cannonRight = Instance.new("Part")
		cannonRight.Name = "PlasmaCannonR"
		cannonRight.Size = Vector3.new(0.5, 0.5, 3.2)
		cannonRight.Position = heavyBase.Position + Vector3.new(1.2, 0.5, 1.8)
		cannonRight.Anchored = true
		cannonRight.CanCollide = false
		cannonRight.Material = Enum.Material.Neon
		cannonRight.Color = Color3.fromRGB(0, 210, 255)
		cannonRight.Parent = plasmaModel

		station.model = plasmaModel
		station.barrelPosition = heavyBase.Position + Vector3.new(0, 0.5, 2.2)
	end
end

function AlienBaseDefenceServer:FireStation(station, tierStats)
	local barrelPos = station.barrelPosition or station.pad.Position + Vector3.new(0, 3, 0)
	local range = (tierStats and tierStats.range) or (if station.level == 2 then 28 else 24)

	local targetEnemy = nil
	local closestDist = math.huge

	for _, enemy in ipairs(self.activeEnemies) do
		if not enemy.isDead and enemy.rootPart and enemy.rootPart.Parent then
			local d = (enemy.rootPart.Position - barrelPos).Magnitude
			if d <= range and d < closestDist then
				closestDist = d
				targetEnemy = enemy
			end
		end
	end

	if targetEnemy and targetEnemy.rootPart and targetEnemy.rootPart.Parent then
		local damage = (tierStats and tierStats.damage) or (if station.level == 2 then 30 else 16)
		targetEnemy.health -= damage

		local enemyPos = targetEnemy.rootPart.Position
		local dist = (enemyPos - barrelPos).Magnitude

		-- Visual Laser/Tracer Beam
		local beamPart = Instance.new("Part")
		beamPart.Name = "CombatTracerBeam"
		beamPart.Anchored = true
		beamPart.CanCollide = false
		beamPart.Material = Enum.Material.Neon
		beamPart.Color = if station.level == 2 then Color3.fromRGB(0, 230, 255) else Color3.fromRGB(245, 180, 50)
		beamPart.Size = Vector3.new(0.35, 0.35, dist)
		beamPart.CFrame = CFrame.lookAt((barrelPos + enemyPos) / 2, enemyPos)
		beamPart.Parent = self.container
		table.insert(self.activeBeams, beamPart)

		-- Muzzle Flash
		local flashLight = Instance.new("PointLight")
		flashLight.Color = beamPart.Color
		flashLight.Brightness = 1.5
		flashLight.Range = 8
		flashLight.Parent = beamPart

		task.delay(0.08, function()
			if beamPart and beamPart.Parent then
				beamPart:Destroy()
			end
			local idx = table.find(self.activeBeams, beamPart)
			if idx then
				table.remove(self.activeBeams, idx)
			end
		end)

		if targetEnemy.health <= 0 then
			self:KillEnemy(targetEnemy)
		end
	end
end

function AlienBaseDefenceServer:SpawnEnemy(enemyType)
	if self.isStopped then
		return
	end

	local archetypes = self.config.enemyStats or {}
	local arch = archetypes[enemyType] or {}
	local hp = arch.health or (if enemyType == "Boss" then 280 elseif enemyType == "Armored" then 90 else 40)
	local speed = arch.speed or (if enemyType == "Boss" then 7.5 elseif enemyType == "Armored" then 11 else 15)
	local color = arch.color or (if enemyType == "Boss" then Color3.fromRGB(230, 126, 34) elseif enemyType == "Armored" then Color3.fromRGB(155, 89, 182) else Color3.fromRGB(46, 204, 113))
	local size = arch.size or (if enemyType == "Boss" then Vector3.new(5.5, 4.5, 5.5) elseif enemyType == "Armored" then Vector3.new(3.2, 2.6, 3.2) else Vector3.new(2.2, 1.8, 2.2))
	local vaultDmg = arch.vaultDamage or (if enemyType == "Boss" then 40 elseif enemyType == "Armored" then 20 else 15)

	-- Multi-Part Insectoid Alien Model
	local alienModel = Instance.new("Model")
	alienModel.Name = "Alien_" .. enemyType
	alienModel.Parent = self.container

	-- Primary Root Body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = size
	body.Color = color
	body.Material = Enum.Material.Neon
	body.Anchored = true
	body.CanCollide = false
	body.CFrame = CFrame.lookAt(self.waypoints[1], self.waypoints[2])
	body.Parent = alienModel
	alienModel.PrimaryPart = body

	-- Welded Segmented Carapace
	local carapace = Instance.new("Part")
	carapace.Name = "Carapace"
	carapace.Size = size * Vector3.new(1.15, 0.5, 1.15)
	carapace.CFrame = body.CFrame * CFrame.new(0, size.Y * 0.25, 0)
	carapace.Color = Color3.fromRGB(math.clamp(color.R * 255 - 35, 15, 255), math.clamp(color.G * 255 - 35, 15, 255), math.clamp(color.B * 255 - 35, 15, 255))
	carapace.Material = Enum.Material.CorrodedMetal
	carapace.Anchored = false
	carapace.CanCollide = false
	carapace.Massless = true
	carapace.Parent = alienModel

	local carapaceWeld = Instance.new("WeldConstraint")
	carapaceWeld.Part0 = body
	carapaceWeld.Part1 = carapace
	carapaceWeld.Parent = carapace

	-- Welded Antennae with Glowing Neon Tips
	local antLeft = Instance.new("Part")
	antLeft.Name = "AntennaL"
	antLeft.Size = Vector3.new(0.2, size.Y * 0.7, 0.2)
	antLeft.CFrame = body.CFrame * CFrame.new(-size.X * 0.35, size.Y * 0.55, -size.Z * 0.4) * CFrame.Angles(math.rad(25), 0, math.rad(-15))
	antLeft.Color = Color3.fromRGB(240, 50, 50)
	antLeft.Material = Enum.Material.Neon
	antLeft.Anchored = false
	antLeft.CanCollide = false
	antLeft.Massless = true
	antLeft.Parent = alienModel

	local antLeftWeld = Instance.new("WeldConstraint")
	antLeftWeld.Part0 = body
	antLeftWeld.Part1 = antLeft
	antLeftWeld.Parent = antLeft

	local antRight = Instance.new("Part")
	antRight.Name = "AntennaR"
	antRight.Size = Vector3.new(0.2, size.Y * 0.7, 0.2)
	antRight.CFrame = body.CFrame * CFrame.new(size.X * 0.35, size.Y * 0.55, -size.Z * 0.4) * CFrame.Angles(math.rad(25), 0, math.rad(15))
	antRight.Color = Color3.fromRGB(240, 50, 50)
	antRight.Material = Enum.Material.Neon
	antRight.Anchored = false
	antRight.CanCollide = false
	antRight.Massless = true
	antRight.Parent = alienModel

	local antRightWeld = Instance.new("WeldConstraint")
	antRightWeld.Part0 = body
	antRightWeld.Part1 = antRight
	antRightWeld.Parent = antRight

	-- Alien Biological Glow
	local bioLight = Instance.new("PointLight")
	bioLight.Color = color
	bioLight.Brightness = 0.8
	bioLight.Range = 8
	bioLight.Parent = body

	local enemy = {
		model = alienModel,
		rootPart = body,
		health = hp,
		maxHealth = hp,
		speed = speed,
		vaultDamage = vaultDmg,
		isDead = false,
		activeTween = nil,
	}
	table.insert(self.activeEnemies, enemy)

	-- Sequential Tweening Along 9 Waypoints
	task.spawn(function()
		for i = 2, #self.waypoints do
			if self.isStopped or enemy.isDead or not body.Parent then
				return
			end
			local currentPos = body.Position
			local targetPt = self.waypoints[i]
			local nextPt = if i < #self.waypoints then self.waypoints[i + 1] else targetPt + (targetPt - currentPos)
			local dist = (targetPt - currentPos).Magnitude
			local timeToTravel = dist / speed

			local targetCFrame = CFrame.lookAt(targetPt, nextPt)
			local tween = TweenService:Create(body, TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear), {
				CFrame = targetCFrame
			})
			enemy.activeTween = tween
			tween:Play()

			local completed = false
			local conn = tween.Completed:Connect(function()
				completed = true
			end)

			while not completed and not self.isStopped and not enemy.isDead and body.Parent do
				task.wait(0.05)
			end
			conn:Disconnect()
			enemy.activeTween = nil
		end

		-- Alien breached Outpost Command Center
		if not enemy.isDead and not self.isStopped then
			enemy.isDead = true
			self:DamageVault(enemy.vaultDamage or 15)

			-- Breach Impact Flash
			local breachFlash = Instance.new("Part")
			breachFlash.Shape = Enum.PartType.Ball
			breachFlash.Size = Vector3.new(4, 4, 4)
			breachFlash.Position = body.Position
			breachFlash.Anchored = true
			breachFlash.CanCollide = false
			breachFlash.Material = Enum.Material.Neon
			breachFlash.Color = Color3.fromRGB(231, 76, 60)
			breachFlash.Parent = self.container
			task.delay(0.2, function()
				if breachFlash and breachFlash.Parent then
					breachFlash:Destroy()
				end
			end)

			if alienModel and alienModel.Parent then
				alienModel:Destroy()
			end
		end
	end)
end

function AlienBaseDefenceServer:DamageVault(amount)
	self.coreHealth = math.max(0, self.coreHealth - amount)

	if self.vaultLabel then
		local pct = math.floor((self.coreHealth / self.maxCoreHealth) * 100)
		self.vaultLabel.Text = string.format("🪖 OUTPOST INTEGRITY: %d%%", pct)
		if pct <= 30 then
			self.vaultLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
			if self.vaultStroke then
				self.vaultStroke.Color = Color3.fromRGB(231, 76, 60)
			end
			if self.vaultCore then
				self.vaultCore.Color = Color3.fromRGB(231, 76, 60)
			end
		elseif pct <= 60 then
			self.vaultLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
			if self.vaultStroke then
				self.vaultStroke.Color = Color3.fromRGB(241, 196, 15)
			end
			if self.vaultCore then
				self.vaultCore.Color = Color3.fromRGB(241, 196, 15)
			end
		end
	end

	self:UpdateProgress()

	if self.coreHealth <= 0 then
		if self.eventBus and self.eventBus.SessionEnded then
			self.eventBus.SessionEnded:Fire("Defeated", 0.3)
		end
		if self.onComplete then
			self.onComplete("Defeated", 0.3)
		end
	end
end

function AlienBaseDefenceServer:KillEnemy(enemy)
	if enemy.isDead then
		return
	end
	enemy.isDead = true
	self.enemiesDefeated += 1

	-- Cancel Active Motion Tween
	if enemy.activeTween then
		pcall(function() enemy.activeTween:Cancel() end)
		enemy.activeTween = nil
	end

	-- Death Dissolution Effect
	if enemy.rootPart and enemy.rootPart.Parent then
		local deathPos = enemy.rootPart.Position
		local pop = Instance.new("Part")
		pop.Name = "DissolutionBurst"
		pop.Shape = Enum.PartType.Ball
		pop.Size = Vector3.new(2, 2, 2)
		pop.Position = deathPos
		pop.Anchored = true
		pop.CanCollide = false
		pop.Material = Enum.Material.Neon
		pop.Color = enemy.rootPart.Color
		pop.Parent = self.container

		local tween = TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(5, 5, 5),
			Transparency = 1,
		})
		tween:Play()
		task.delay(0.28, function()
			if pop and pop.Parent then
				pop:Destroy()
			end
		end)
	end

	if enemy.model and enemy.model.Parent then
		enemy.model:Destroy()
	end

	self:UpdateProgress()
end

function AlienBaseDefenceServer:StartWaveLoop()
	task.spawn(function()
		for wave = 1, self.totalWaves do
			if self.isStopped or self.coreHealth <= 0 then
				return
			end
			self.currentWave = wave
			self:UpdateProgress()

			local waveConfig = self.config.waves and self.config.waves[wave]
			local count = (waveConfig and waveConfig.count) or (if wave == 2 then 8 elseif wave == 3 then 7 else 6)
			local interval = (waveConfig and waveConfig.interval) or 2.0

			for i = 1, count do
				if not self.isStopped and self.coreHealth > 0 then
					local enemyType = getEnemyTypeForWave(wave, i)
					self:SpawnEnemy(enemyType)
					task.wait(interval)
				end
			end

			-- Await Wave Elimination
			local waitTimer = 0
			while waitTimer < 20 and not self.isStopped and self.coreHealth > 0 do
				local anyAlive = false
				for _, e in ipairs(self.activeEnemies) do
					if not e.isDead then
						anyAlive = true
						break
					end
				end
				if not anyAlive then
					break
				end
				task.wait(1)
				waitTimer += 1
			end

			task.wait(2.5)
		end

		if not self.isStopped and self.coreHealth > 0 then
			local scoreMult = (self.coreHealth / self.maxCoreHealth) * 0.8 + 0.5
			if self.eventBus and self.eventBus.SessionEnded then
				self.eventBus.SessionEnded:Fire("Victory", scoreMult)
			end
			if self.onComplete then
				self.onComplete("Victory", scoreMult)
			end
		end
	end)
end

function AlienBaseDefenceServer:UpdateProgress()
	if self.isStopped then
		return
	end

	local pct = math.floor((self.coreHealth / self.maxCoreHealth) * 100)
	local obj = string.format("Wave %d/%d | Outpost: %d%% | Repelled: %d", self.currentWave, self.totalWaves, pct, self.enemiesDefeated)
	local progressData = {
		objective = obj,
		score = self.enemiesDefeated,
		extra = {
			wave = self.currentWave,
			coreHealth = self.coreHealth,
			maxCoreHealth = self.maxCoreHealth,
			defeated = self.enemiesDefeated,
		},
	}

	if self.eventBus and self.eventBus.SessionProgress then
		self.eventBus.SessionProgress:Fire(progressData)
	end
	if self.onProgress then
		self.onProgress(progressData)
	end
end

function AlienBaseDefenceServer:GetObjective()
	local pct = math.floor((self.coreHealth / self.maxCoreHealth) * 100)
	return string.format("Wave %d/%d (Outpost HP: %d%%)", self.currentWave, self.totalWaves, pct)
end

function AlienBaseDefenceServer:Stop()
	if self.isStopped then
		return
	end
	self.isStopped = true

	for _, conn in ipairs(self.connections) do
		pcall(function() conn:Disconnect() end)
	end
	self.connections = {}

	for _, enemy in ipairs(self.activeEnemies) do
		enemy.isDead = true
		if enemy.activeTween then
			pcall(function() enemy.activeTween:Cancel() end)
			enemy.activeTween = nil
		end
		if enemy.model and enemy.model.Parent then
			pcall(function() enemy.model:Destroy() end)
		end
	end
	self.activeEnemies = {}

	for _, beam in ipairs(self.activeBeams) do
		if beam and beam.Parent then
			pcall(function() beam:Destroy() end)
		end
	end
	self.activeBeams = {}
end

return AlienBaseDefenceServer
