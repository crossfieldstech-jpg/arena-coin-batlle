--[[
	BaseSentry/Server.luau
	Decoupled Server Engine for the Base Sentry tower defense mini-game package.
	Operates seamlessly in embedded Procedural Sky Sub-Arena or Standalone Universe places.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DefaultConfig = require(ReplicatedStorage:WaitForChild("MiniGames"):WaitForChild("Packages"):WaitForChild("BaseSentry"):WaitForChild("Config"))

local BaseSentryServer = {}
BaseSentryServer.__index = BaseSentryServer

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

function BaseSentryServer.Start(context)
	local self = setmetatable({}, BaseSentryServer)

	self.player = context.player
	self.base = context.base
	self.container = context.container or context.gameContentFolder or workspace
	self.center = context.center or Vector3.zero
	self.config = context.config or DefaultConfig
	self.duration = context.duration or self.config.duration or 90
	self.eventBus = context.eventBus
	self.isStandalone = context.isStandalone or false
	self.onProgress = context.onProgress
	self.onComplete = context.onComplete

	self.isStopped = false
	self.connections = {}
	self.activeEnemies = {}
	self.sentries = {}
	self.currentWave = 0
	self.totalWaves = self.config.totalWaves or 3
	self.maxCoreHealth = self.config.maxCoreHealth or 100
	self.coreHealth = self.maxCoreHealth
	self.enemiesDefeated = 0

	self:BuildWorld()
	self:StartWaveLoop()

	return self
end

function BaseSentryServer:BuildWorld()
	local folder = self.container
	local center = self.center
	local relWaypoints = self.config.relativeWaypoints or {
		Vector3.new(-18, 1.2, -18),
		Vector3.new(-18, 1.2, -6),
		Vector3.new(0, 1.2, -6),
		Vector3.new(0, 1.2, 8),
		Vector3.new(18, 1.2, 8),
		Vector3.new(18, 1.2, 18),
	}

	-- 1. Defense Pathway Waypoints
	self.waypoints = {}
	for _, rel in ipairs(relWaypoints) do
		table.insert(self.waypoints, center + rel)
	end

	-- Draw visual track segments on floor
	for i = 1, #self.waypoints - 1 do
		local pA = self.waypoints[i]
		local pB = self.waypoints[i + 1]
		local dist = (pB - pA).Magnitude
		local trackPart = Instance.new("Part")
		trackPart.Name = "Lane_" .. i
		trackPart.Size = Vector3.new(4.5, 0.25, dist)
		trackPart.CFrame = CFrame.lookAt((pA + pB) / 2, pB)
		trackPart.Anchored = true
		trackPart.CanCollide = false
		trackPart.Material = Enum.Material.Concrete
		trackPart.Color = Color3.fromRGB(50, 56, 64)
		trackPart.Parent = folder
	end

	-- 2. Mini-Vault Core
	local vaultCore = Instance.new("Part")
	vaultCore.Name = "MiniVaultCore"
	vaultCore.Size = Vector3.new(6, 6, 6)
	vaultCore.Position = self.waypoints[#self.waypoints] + Vector3.new(0, 2.5, 0)
	vaultCore.Anchored = true
	vaultCore.Material = Enum.Material.Neon
	vaultCore.Color = Color3.fromRGB(52, 152, 219)
	vaultCore.Parent = folder
	self.vaultCore = vaultCore

	local coreGlow = Instance.new("PointLight")
	coreGlow.Color = Color3.fromRGB(80, 200, 255)
	coreGlow.Brightness = 0.8
	coreGlow.Range = 12
	coreGlow.Parent = vaultCore

	local vaultGui = Instance.new("BillboardGui")
	vaultGui.Name = "VaultGui"
	vaultGui.Size = UDim2.new(0, 200, 0, 50)
	vaultGui.StudsOffset = Vector3.new(0, 5, 0)
	vaultGui.AlwaysOnTop = true
	vaultGui.Parent = vaultCore

	local vaultLabel = Instance.new("TextLabel")
	vaultLabel.Name = "VaultLabel"
	vaultLabel.Size = UDim2.new(1, 0, 1, 0)
	vaultLabel.BackgroundColor3 = Color3.fromRGB(15, 20, 25)
	vaultLabel.BackgroundTransparency = 0.2
	vaultLabel.Font = Enum.Font.GothamBold
	vaultLabel.Text = "VAULT HP: 100%"
	vaultLabel.TextColor3 = Color3.fromRGB(80, 220, 255)
	vaultLabel.TextSize = 16
	vaultLabel.Parent = vaultGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = vaultLabel
	self.vaultLabel = vaultLabel

	-- 3. Sentry Build Nodes
	local nodeOffsets = self.config.nodeOffsets or {
		Vector3.new(-8, 1.5, -12),
		Vector3.new(8, 1.5, 1),
		Vector3.new(-8, 1.5, 14),
	}

	for idx, offset in ipairs(nodeOffsets) do
		local pos = center + offset
		local pedestal = Instance.new("Part")
		pedestal.Name = "SentryNode_" .. idx
		pedestal.Shape = Enum.PartType.Cylinder
		pedestal.Size = Vector3.new(1, 4.5, 4.5)
		pedestal.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		pedestal.Anchored = true
		pedestal.Material = Enum.Material.Metal
		pedestal.Color = Color3.fromRGB(45, 50, 58)
		pedestal.Parent = folder

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BuildPrompt"
		prompt.ActionText = "Deploy Gatling Sentry"
		prompt.ObjectText = string.format("Node #%d", idx)
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.HoldDuration = 0
		prompt.Parent = pedestal

		local nodeData = {
			index = idx,
			pedestal = pedestal,
			prompt = prompt,
			level = 0,
			turretModel = nil,
			lastShot = 0,
		}

		prompt.Triggered:Connect(function(player)
			if player ~= self.player or self.isStopped then
				return
			end
			self:InteractNode(nodeData)
		end)

		table.insert(self.sentries, nodeData)
	end

	-- Sentry Automated Firing Loop
	local firingConn = RunService.Heartbeat:Connect(function()
		if self.isStopped then
			return
		end
		local now = os.clock()
		for _, node in ipairs(self.sentries) do
			if node.level > 0 then
				local stats = self.config.sentryStats
				local fireRate = if node.level == 1 then (stats and stats.Level1 and stats.Level1.fireRate or 0.6)
					else (stats and stats.Level2 and stats.Level2.fireRate or 0.35)
				if now - node.lastShot >= fireRate then
					self:FireSentry(node)
					node.lastShot = now
				end
			end
		end
	end)
	table.insert(self.connections, firingConn)
end

function BaseSentryServer:InteractNode(node)
	if node.level == 0 then
		node.level = 1
		node.prompt.ActionText = "Overclock Turret [+Damage]"

		local turret = Instance.new("Part")
		turret.Name = "TurretHead"
		turret.Shape = Enum.PartType.Block
		turret.Size = Vector3.new(2, 2.5, 2)
		turret.Position = node.pedestal.Position + Vector3.new(0, 2.2, 0)
		turret.Anchored = true
		turret.Material = Enum.Material.Neon
		local l1Color = self.config.sentryStats and self.config.sentryStats.Level1 and self.config.sentryStats.Level1.color or Color3.fromRGB(46, 204, 113)
		turret.Color = l1Color
		turret.Parent = self.container
		node.turretModel = turret

	elseif node.level == 1 then
		node.level = 2
		node.prompt.Enabled = false
		if node.turretModel then
			local l2Color = self.config.sentryStats and self.config.sentryStats.Level2 and self.config.sentryStats.Level2.color or Color3.fromRGB(241, 196, 15)
			node.turretModel.Color = l2Color
			node.turretModel.Size = Vector3.new(2.4, 3, 2.4)
		end
	end
end

function BaseSentryServer:FireSentry(node)
	if not node.turretModel then
		return
	end
	local turretPos = node.turretModel.Position
	local range = 18

	local targetEnemy = nil
	local closestDist = math.huge
	for _, enemy in ipairs(self.activeEnemies) do
		if enemy.health > 0 and enemy.part and enemy.part.Parent then
			local d = (enemy.part.Position - turretPos).Magnitude
			if d <= range and d < closestDist then
				closestDist = d
				targetEnemy = enemy
			end
		end
	end

	if targetEnemy then
		local stats = self.config.sentryStats
		local damage = if node.level == 2 then (stats and stats.Level2 and stats.Level2.damage or 25)
			else (stats and stats.Level1 and stats.Level1.damage or 14)
		targetEnemy.health -= damage

		local beamPart = Instance.new("Part")
		beamPart.Name = "LaserBeam"
		beamPart.Anchored = true
		beamPart.CanCollide = false
		beamPart.Material = Enum.Material.Neon
		beamPart.Color = if node.level == 2 then Color3.fromRGB(241, 196, 15) else Color3.fromRGB(46, 204, 113)
		local enemyPos = targetEnemy.part.Position
		local dist = (enemyPos - turretPos).Magnitude
		beamPart.Size = Vector3.new(0.3, 0.3, dist)
		beamPart.CFrame = CFrame.lookAt((turretPos + enemyPos) / 2, enemyPos)
		beamPart.Parent = self.container

		task.delay(0.08, function()
			if beamPart and beamPart.Parent then
				beamPart:Destroy()
			end
		end)

		if targetEnemy.health <= 0 then
			self:KillEnemy(targetEnemy)
		end
	end
end

function BaseSentryServer:SpawnEnemy(enemyType)
	if self.isStopped then
		return
	end

	local archetypes = self.config.enemyStats or {}
	local arch = archetypes[enemyType] or {}
	local hp = arch.health or (if enemyType == "Boss" then 180 elseif enemyType == "Armored" then 65 else 35)
	local speed = arch.speed or (if enemyType == "Boss" then 6 elseif enemyType == "Armored" then 9 else 11)
	local color = arch.color or (if enemyType == "Boss" then Color3.fromRGB(243, 156, 18) elseif enemyType == "Armored" then Color3.fromRGB(155, 89, 182) else Color3.fromRGB(231, 76, 60))
	local size = arch.size or (if enemyType == "Boss" then Vector3.new(4, 4, 4) elseif enemyType == "Armored" then Vector3.new(2.5, 2.5, 2.5) else Vector3.new(2, 2, 2))
	local vaultDmg = arch.vaultDamage or (if enemyType == "Boss" then 35 else 15)

	local part = Instance.new("Part")
	part.Name = "Bandit_" .. enemyType
	part.Shape = Enum.PartType.Ball
	part.Size = size
	part.Position = self.waypoints[1]
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Parent = self.container

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 0.5
	light.Range = 6
	light.Parent = part

	local enemy = {
		part = part,
		health = hp,
		maxHealth = hp,
		speed = speed,
		vaultDamage = vaultDmg,
		isDead = false,
	}
	table.insert(self.activeEnemies, enemy)

	-- Move along waypoints
	task.spawn(function()
		for i = 2, #self.waypoints do
			if self.isStopped or enemy.isDead or not part.Parent then
				return
			end
			local targetPt = self.waypoints[i]
			local dist = (targetPt - part.Position).Magnitude
			local timeToTravel = dist / speed

			local tween = TweenService:Create(part, TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear), {
				Position = targetPt
			})
			tween:Play()
			task.wait(timeToTravel)
		end

		if not enemy.isDead and not self.isStopped then
			enemy.isDead = true
			self:DamageVault(enemy.vaultDamage or 15)
			if part and part.Parent then
				part:Destroy()
			end
		end
	end)
end

function BaseSentryServer:DamageVault(amount)
	self.coreHealth = math.max(0, self.coreHealth - amount)

	if self.vaultLabel then
		local pct = math.floor((self.coreHealth / self.maxCoreHealth) * 100)
		self.vaultLabel.Text = string.format("VAULT HP: %d%%", pct)
		if pct <= 30 then
			self.vaultLabel.TextColor3 = Color3.fromRGB(231, 76, 60)
			self.vaultCore.Color = Color3.fromRGB(231, 76, 60)
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

function BaseSentryServer:KillEnemy(enemy)
	if enemy.isDead then
		return
	end
	enemy.isDead = true
	self.enemiesDefeated += 1

	if enemy.part and enemy.part.Parent then
		enemy.part:Destroy()
	end

	self:UpdateProgress()
end

function BaseSentryServer:StartWaveLoop()
	task.spawn(function()
		for wave = 1, self.totalWaves do
			if self.isStopped or self.coreHealth <= 0 then
				return
			end
			self.currentWave = wave
			self:UpdateProgress()

			local waveConfig = self.config.waves and self.config.waves[wave]
			local count = (waveConfig and waveConfig.count) or (if wave == 2 then 6 else 5)
			local interval = (waveConfig and waveConfig.interval) or 2.2

			for i = 1, count do
				if not self.isStopped and self.coreHealth > 0 then
					local enemyType = getEnemyTypeForWave(wave, i)
					self:SpawnEnemy(enemyType)
					task.wait(interval)
				end
			end

			local waitTimer = 0
			while waitTimer < 15 and not self.isStopped and self.coreHealth > 0 do
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

			task.wait(2)
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

function BaseSentryServer:UpdateProgress()
	if self.isStopped then
		return
	end

	local pct = math.floor((self.coreHealth / self.maxCoreHealth) * 100)
	local obj = string.format("Wave %d/%d | Vault HP: %d%% | Defeated: %d", self.currentWave, self.totalWaves, pct, self.enemiesDefeated)
	local progressData = {
		objective = obj,
		score = self.enemiesDefeated,
		extra = {
			wave = self.currentWave,
			coreHealth = self.coreHealth,
		},
	}

	if self.eventBus and self.eventBus.SessionProgress then
		self.eventBus.SessionProgress:Fire(progressData)
	end
	if self.onProgress then
		self.onProgress(progressData)
	end
end

function BaseSentryServer:GetObjective()
	local pct = math.floor((self.coreHealth / self.maxCoreHealth) * 100)
	return string.format("Wave %d/%d (Vault HP: %d%%)", self.currentWave, self.totalWaves, pct)
end

function BaseSentryServer:Stop()
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
		if enemy.part and enemy.part.Parent then
			pcall(function() enemy.part:Destroy() end)
		end
	end
	self.activeEnemies = {}
end

return BaseSentryServer
