--[[
	MiniGameService.lua
	Server-authoritative coordinator for Sky Sub-Arena mini-games.
	Manages procedural sky platforms at Y=400, player sessions, mutual exclusion with
	central arena, safe teleportation, reward payouts, and lifecycle cleanup.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MiniGameRegistry = require(ReplicatedStorage:WaitForChild("MiniGames"):WaitForChild("MiniGameRegistry"))
local MiniGameEventBus = require(ReplicatedStorage:WaitForChild("MiniGames"):WaitForChild("MiniGameEventBus"))
local VaultService = require(script.Parent.Parent:WaitForChild("VaultService"))

local MiniGameService = {}

local isInitialized = false
local remotesFolder = nil
local openGameMenuEvent = nil
local requestStartGameFunction = nil
local requestExitGameEvent = nil
local gameStateUpdateEvent = nil
local gameCompletedEvent = nil

-- Active sessions: [userId] = sessionData
local activeSessions = {}

-- External check and base resolver hooks (injected by CoinCollector)
local isPlayerInArenaFn = nil
local getBaseForPlayerFn = nil
local getBaseByIdFn = nil

function MiniGameService.SetArenaChecker(fn)
	isPlayerInArenaFn = fn
end

function MiniGameService.SetBaseResolver(fn)
	getBaseForPlayerFn = fn
end

function MiniGameService.SetBaseLookup(fn)
	getBaseByIdFn = fn
end

function MiniGameService.IsPlayerInMiniGame(player)
	if not player or not player.UserId then
		return false
	end
	return activeSessions[player.UserId] ~= nil
end

function MiniGameService.GetActiveSession(player)
	if not player or not player.UserId then
		return nil
	end
	return activeSessions[player.UserId]
end

-- =========================================================================
-- Procedural Sky Platform Builder
-- =========================================================================

local function buildSkyPlatform(baseId, centerPosition)
	local skyY = 400
	local center = Vector3.new(centerPosition.X, skyY, centerPosition.Z)

	local model = Instance.new("Model")
	model.Name = string.format("SkySubArena_Base%d", baseId)
	model.Parent = Workspace

	local platformSize = 54
	local wallHeight = 16
	local wallThickness = 2

	-- 1. Main Floor
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(platformSize, 2, platformSize)
	floor.Position = center
	floor.Anchored = true
	floor.Material = Enum.Material.DiamondPlate
	floor.Color = Color3.fromRGB(30, 35, 42)
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = model

	-- Neon floor perimeter glow
	local floorBorder = Instance.new("SelectionBox")
	floorBorder.Name = "FloorGlow"
	floorBorder.Adornee = floor
	floorBorder.Color3 = Color3.fromRGB(155, 89, 182)
	floorBorder.LineThickness = 0.08
	floorBorder.Parent = floor

	-- 2. Perimeter Walls (Safety barriers so players cannot fall off at Y=400)
	local function makeWall(name, size, cframe)
		local wall = Instance.new("Part")
		wall.Name = name
		wall.Size = size
		wall.CFrame = cframe
		wall.Anchored = true
		wall.CanCollide = true
		wall.Material = Enum.Material.ForceField
		wall.Color = Color3.fromRGB(160, 100, 220)
		wall.Transparency = 0.65
		wall.TopSurface = Enum.SurfaceType.Smooth
		wall.BottomSurface = Enum.SurfaceType.Smooth
		wall.Parent = model
		return wall
	end

	local half = platformSize / 2
	local wallY = center.Y + (wallHeight / 2) + 1

	-- North wall (-Z)
	makeWall("Wall_North", Vector3.new(platformSize, wallHeight, wallThickness), CFrame.new(center.X, wallY, center.Z - half))
	-- South wall (+Z)
	makeWall("Wall_South", Vector3.new(platformSize, wallHeight, wallThickness), CFrame.new(center.X, wallY, center.Z + half))
	-- East wall (+X)
	makeWall("Wall_East", Vector3.new(wallThickness, wallHeight, platformSize), CFrame.new(center.X + half, wallY, center.Z))
	-- West wall (-X)
	makeWall("Wall_West", Vector3.new(wallThickness, wallHeight, platformSize), CFrame.new(center.X - half, wallY, center.Z))

	-- 3. Dedicated Spawning / Entry Pad
	local spawnPad = Instance.new("Part")
	spawnPad.Name = "PlayerSpawnPad"
	spawnPad.Shape = Enum.PartType.Cylinder
	spawnPad.Size = Vector3.new(0.4, 8, 8)
	spawnPad.CFrame = CFrame.new(center.X, center.Y + 1.2, center.Z + (half - 8)) * CFrame.Angles(0, 0, math.rad(90))
	spawnPad.Anchored = true
	spawnPad.CanCollide = false
	spawnPad.Material = Enum.Material.Neon
	spawnPad.Color = Color3.fromRGB(142, 68, 173)
	spawnPad.Parent = model

	local gameContentFolder = Instance.new("Folder")
	gameContentFolder.Name = "GameContent"
	gameContentFolder.Parent = model

	local spawnCFrame = CFrame.new(center.X, center.Y + 4, center.Z + (half - 8)) * CFrame.Angles(0, math.rad(180), 0)

	return model, spawnCFrame, gameContentFolder, center
end

-- =========================================================================
-- Safe Teleportation Helper
-- =========================================================================

local function safeTeleport(character, targetCFrame)
	if not character or not targetCFrame then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = true
	root.CFrame = targetCFrame

	task.delay(0.15, function()
		if root and root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

-- =========================================================================
-- Core Service Lifecycle & Session Management
-- =========================================================================

function MiniGameService.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	remotesFolder = ReplicatedStorage:FindFirstChild("MiniGameRemotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "MiniGameRemotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	openGameMenuEvent = remotesFolder:FindFirstChild("OpenGameMenu")
	if not openGameMenuEvent then
		openGameMenuEvent = Instance.new("RemoteEvent")
		openGameMenuEvent.Name = "OpenGameMenu"
		openGameMenuEvent.Parent = remotesFolder
	end

	requestStartGameFunction = remotesFolder:FindFirstChild("RequestStartGame")
	if not requestStartGameFunction then
		requestStartGameFunction = Instance.new("RemoteFunction")
		requestStartGameFunction.Name = "RequestStartGame"
		requestStartGameFunction.Parent = remotesFolder
	end

	requestExitGameEvent = remotesFolder:FindFirstChild("RequestExitGame")
	if not requestExitGameEvent then
		requestExitGameEvent = Instance.new("RemoteEvent")
		requestExitGameEvent.Name = "RequestExitGame"
		requestExitGameEvent.Parent = remotesFolder
	end

	gameStateUpdateEvent = remotesFolder:FindFirstChild("GameStateUpdate")
	if not gameStateUpdateEvent then
		gameStateUpdateEvent = Instance.new("RemoteEvent")
		gameStateUpdateEvent.Name = "GameStateUpdate"
		gameStateUpdateEvent.Parent = remotesFolder
	end

	gameCompletedEvent = remotesFolder:FindFirstChild("GameCompleted")
	if not gameCompletedEvent then
		gameCompletedEvent = Instance.new("RemoteEvent")
		gameCompletedEvent.Name = "GameCompleted"
		gameCompletedEvent.Parent = remotesFolder
	end

	-- Bind RemoteFunction: Client requests to launch a mini-game
	requestStartGameFunction.OnServerInvoke = function(player, gameId, targetBaseId)
		return MiniGameService.StartSession(player, gameId, targetBaseId)
	end

	-- Bind RemoteEvent: Client requests to exit/forfeit
	requestExitGameEvent.OnServerEvent:Connect(function(player)
		if MiniGameService.IsPlayerInMiniGame(player) then
			MiniGameService.EndSession(player, "Forfeit", 0)
		end
	end)

	-- Fallback bounds-checker loop: If a player somehow clips below the sky platform, safely rescue them
	task.spawn(function()
		while true do
			task.wait(1)
			for userId, session in pairs(activeSessions) do
				local player = session.player
				if player and player.Character then
					local root = player.Character:FindFirstChild("HumanoidRootPart")
					if root and root.Position.Y < 370 then
						-- Fallen out of sky arena
						warn(string.format("[MiniGameService] Player %s fell below sky boundary (Y=%.1f). Teleporting back to base.", player.Name, root.Position.Y))
						MiniGameService.EndSession(player, "FellOutOfBounds", 0)
					end
				end
			end
		end
	end)

	-- Disconnect handler
	Players.PlayerRemoving:Connect(function(player)
		if MiniGameService.IsPlayerInMiniGame(player) then
			MiniGameService.EndSession(player, "PlayerLeft", 0)
		end
	end)
end

function MiniGameService.OpenMenuForPlayer(player, base)
	if not player or not player.Parent then
		return
	end
	if isPlayerInArenaFn and isPlayerInArenaFn(player) then
		return
	end
	if MiniGameService.IsPlayerInMiniGame(player) then
		return
	end

	local enabledGames = MiniGameRegistry.GetEnabledGames()
	local activeBuff = VaultService.GetActiveBuff and VaultService.GetActiveBuff(player)

	openGameMenuEvent:FireClient(player, {
		baseId = base and base.id or 1,
		games = enabledGames,
		activeBuff = activeBuff,
	})
end

function MiniGameService.StartSession(player, gameId, targetBase)
	if not player or not player.Parent then
		return false, "Player not found"
	end
	local userId = player.UserId

	-- 1. Validation & Mutual Exclusion Guards
	if activeSessions[userId] ~= nil then
		return false, "Already playing a mini-game"
	end

	if isPlayerInArenaFn and isPlayerInArenaFn(player) then
		return false, "Cannot enter while Central Arena run is active"
	end

	local gameDef = MiniGameRegistry.GetGame(gameId)
	if not gameDef or not gameDef.enabled then
		return false, "Mini-game not available"
	end

	-- Resolve player's base: priority to player's actual owned base
	local base = nil
	if getBaseForPlayerFn then
		base = getBaseForPlayerFn(player)
	end
	if not base and getBaseByIdFn and typeof(targetBase) == "number" then
		base = getBaseByIdFn(targetBase)
	end
	if not base and typeof(targetBase) == "table" and targetBase.GetSpawnCFrame then
		base = targetBase
	end
	if not base and getBaseByIdFn then
		local assignedId = player:GetAttribute("AssignedBaseId")
		if assignedId then
			base = getBaseByIdFn(assignedId)
		end
	end

	local baseCenter = (base and base.center) or (base and base:GetPosition()) or Vector3.new(0, 0, -140)
	local baseId = (base and base.id) or (player:GetAttribute("AssignedBaseId")) or 1

	-- Standalone Universe Place Teleportation Handoff (if configured and published)
	if gameDef.mode == "Universe" and not RunService:IsStudio() and (gameDef.placeId and gameDef.placeId > 0) then
		local teleportOptions = Instance.new("TeleportOptions")
		local teleportData = {
			userId = player.UserId,
			baseId = baseId,
			gameId = gameId,
			sourcePlaceId = game.PlaceId,
		}
		teleportOptions:SetTeleportData(teleportData)

		local ok, err = pcall(function()
			TeleportService:TeleportAsync(gameDef.placeId, { player }, teleportOptions)
		end)
		if ok then
			return true, "Teleporting to standalone mini-game place"
		else
			warn(string.format("[MiniGameService] Universe teleport failed (%s). Falling back to embedded sky arena.", tostring(err)))
		end
	end

	-- 2. Construct Procedural Sky Platform
	local platformModel, spawnCFrame, gameContentFolder, platformCenter = buildSkyPlatform(baseId, baseCenter)

	-- 3. Prepare Session State
	local session = {
		player = player,
		base = base,
		gameId = gameId,
		gameDef = gameDef,
		platformModel = platformModel,
		spawnCFrame = spawnCFrame,
		gameContentFolder = gameContentFolder,
		platformCenter = platformCenter,
		startTime = os.clock(),
		duration = gameDef.duration,
		timeRemaining = gameDef.duration,
		isEnded = false,
		controller = nil,
		diedConnection = nil,
	}
	activeSessions[userId] = session

	-- 4. Safely Teleport Player Character
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		local root = character.HumanoidRootPart
		root.Anchored = true
		root.CFrame = spawnCFrame
		root.AssemblyLinearVelocity = Vector3.zero
		task.wait(0.2)
		root.Anchored = false
	end

	-- Hook Humanoid Died
	if character and character:FindFirstChildOfClass("Humanoid") then
		local hum = character:FindFirstChildOfClass("Humanoid")
		session.diedConnection = hum.Died:Connect(function()
			if not session.isEnded then
				MiniGameService.EndSession(player, "Defeated", 0)
			end
		end)
	end

	-- 5. Launch Dedicated Mini-Game Package Controller (Dynamic discovery - ZERO hardcoded game names!)
	local gameControllerModule = nil
	local serverPkgName = gameDef.serverPackage or gameId

	-- Look in Packages folder first
	local packagesFolder = script.Parent:FindFirstChild("Packages")
	if packagesFolder then
		local pkg = packagesFolder:FindFirstChild(serverPkgName)
		local srv = pkg and pkg:FindFirstChild("Server")
		if srv and srv:IsA("ModuleScript") then
			local ok, mod = pcall(require, srv)
			if ok then gameControllerModule = mod end
		end
	end

	-- Fallback to Games folder for backward compatibility
	if not gameControllerModule then
		local gamesFolder = script.Parent:FindFirstChild("Games")
		local gameMod = gamesFolder and gamesFolder:FindFirstChild(serverPkgName)
		if gameMod and gameMod:IsA("ModuleScript") then
			local ok, mod = pcall(require, gameMod)
			if ok then gameControllerModule = mod end
		end
	end

	if gameControllerModule and gameControllerModule.Start then
		local context = {
			player = player,
			base = base,
			platformModel = platformModel,
			gameContentFolder = gameContentFolder,
			container = gameContentFolder,
			center = platformCenter,
			duration = gameDef.duration,
			config = gameDef,
			eventBus = MiniGameEventBus,
			isStandalone = false,
			onProgress = function(progressData)
				if not session.isEnded and gameStateUpdateEvent then
					gameStateUpdateEvent:FireClient(player, {
						gameId = gameId,
						timeRemaining = session.timeRemaining,
						objective = progressData.objective or "",
						score = progressData.score or 0,
						extra = progressData.extra or {},
					})
				end
			end,
			onComplete = function(outcome, scoreMultiplier)
				if not session.isEnded then
					MiniGameService.EndSession(player, outcome or "Completed", scoreMultiplier or 1.0)
				end
			end,
		}

		session.controller = gameControllerModule.Start(context)
	else
		warn(string.format("[MiniGameService] Failed to find game controller for %s", tostring(gameId)))
	end

	-- 6. Countdown Timer Thread
	session.timerThread = task.spawn(function()
		while session.timeRemaining > 0 and not session.isEnded do
			task.wait(1)
			session.timeRemaining -= 1
			if gameStateUpdateEvent and not session.isEnded then
				gameStateUpdateEvent:FireClient(player, {
					gameId = gameId,
					timeRemaining = session.timeRemaining,
					objective = session.controller and session.controller.GetObjective and session.controller:GetObjective() or "In Progress",
				})
			end
		end

		if not session.isEnded then
			MiniGameService.EndSession(player, "TimeExpired", 1.0)
		end
	end)

	return true, "Game launched"
end

function MiniGameService.EndSession(player, outcome, scoreMultiplier)
	local userId = player.UserId
	local session = activeSessions[userId]
	if not session or session.isEnded then
		return
	end
	session.isEnded = true
	activeSessions[userId] = nil

	-- Clean up died listener
	if session.diedConnection then
		session.diedConnection:Disconnect()
		session.diedConnection = nil
	end

	-- Stop controller
	if session.controller and session.controller.Stop then
		pcall(function()
			session.controller:Stop()
		end)
	end

	-- 1. Calculate Hybrid Rewards
	local gameDef = session.gameDef
	local mult = math.clamp(scoreMultiplier or 1.0, 0.25, 2.0)
	local coinsEarned = 0
	local gemsEarned = 0
	local relicDropped = false
	local fragmentDropped = false
	local buffGranted = nil

	if outcome == "Completed" or outcome == "Victory" or (outcome == "TimeExpired" and mult > 0.4) then
		local rawCoins = math.random(gameDef.rewards.minCoins, gameDef.rewards.maxCoins)
		coinsEarned = math.round(rawCoins * mult)
		local rawGems = math.random(gameDef.rewards.minGems, gameDef.rewards.maxGems)
		gemsEarned = math.round(rawGems * mult * 10) / 10

		-- Credit to carried leaderstats or directly to vault
		VaultService.AddItem(player, "Coins", coinsEarned)
		VaultService.AddItem(player, "Gems", gemsEarned)

		-- Rare Vault Item drop rolls
		if math.random() < gameDef.rewards.relicChance then
			relicDropped = true
			VaultService.AddItem(player, "AncientRelic", 1)
		end
		if math.random() < gameDef.rewards.fragmentChance then
			fragmentDropped = true
			VaultService.AddItem(player, "StarFragment", 1)
		end

		-- Apply Next-Run Arena Buff!
		if gameDef.buff and VaultService.ApplyNextRunBuff then
			VaultService.ApplyNextRunBuff(player, gameDef.buff)
			buffGranted = gameDef.buff
		end
	end

	-- 2. Return Teleportation to Ground Base
	local base = session.base
	if not base and getBaseForPlayerFn then
		base = getBaseForPlayerFn(player)
	end
	if not base and getBaseByIdFn then
		local assignedId = player:GetAttribute("AssignedBaseId")
		if assignedId then
			base = getBaseByIdFn(assignedId)
		end
	end

	local targetCFrame = nil
	if base and base.GetSpawnCFrame then
		targetCFrame = base:GetSpawnCFrame()
	elseif base and base.center then
		targetCFrame = CFrame.new(base.center + Vector3.new(0, 4, 0))
	else
		targetCFrame = CFrame.new(0, 4, -140)
	end

	safeTeleport(player.Character, targetCFrame)

	-- 3. Clean Up Sky Platform Model
	task.delay(0.5, function()
		if session.platformModel and session.platformModel.Parent then
			session.platformModel:Destroy()
		end
	end)

	-- 4. Notify Client of Results
	if gameCompletedEvent and player.Parent then
		gameCompletedEvent:FireClient(player, {
			gameId = session.gameId,
			outcome = outcome,
			coinsEarned = coinsEarned,
			gemsEarned = gemsEarned,
			relicDropped = relicDropped,
			fragmentDropped = fragmentDropped,
			buffGranted = buffGranted,
		})
	end
end

return MiniGameService
