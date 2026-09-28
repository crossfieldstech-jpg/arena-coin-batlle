local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Coin = require(ReplicatedStorage:WaitForChild("Coin"))
local CoinConfig = require(ReplicatedStorage:WaitForChild("CoinConfig"))
local Gem = require(ReplicatedStorage:WaitForChild("Gem"))
local GemConfig = require(ReplicatedStorage:WaitForChild("GemConfig"))
local ArenaEnclosure = require(ReplicatedStorage:WaitForChild("ArenaEnclosure"))
local GateController = require(ReplicatedStorage:WaitForChild("GateController"))
local PlayerBase = require(ReplicatedStorage:WaitForChild("PlayerBase"))
local VaultItemRegistry = require(ReplicatedStorage:WaitForChild("VaultItemRegistry"))
local VaultService = require(script.Parent:WaitForChild("VaultService"))

local coinFolder = nil
local enclosure = nil
local gate = nil
local isRoundResetting = false
local currentRoundItemType = "Coin"

-- Solo Arena Active Run Tracking
local activePlayer = nil          -- Player currently running the arena
local activeBase = nil            -- PlayerBase currently active
local activeExpirationTimer = 0   -- Remaining seconds for active run
local activeTimerThread = nil     -- Active task thread for countdown

-- Runner Cooldown Tracking (Gives other waiting players advantage to trigger next run)
local cooldownPlayer = nil
local cooldownRemaining = 0
local cooldownThread = nil

-- 4 Player Bases storage
local playerBases = {}
local playerToBaseMap = {} -- Player -> PlayerBase

local function ensureLeaderstats(player)
	local leaderstats, valMap = VaultService.EnsurePlayerLeaderstats(player)
	return leaderstats, valMap["Coins"], valMap["Gems"]
end

local function getRandomPosition()
	local radius = CoinConfig.GetSetting("ArenaRadius") or 38
	local minH = CoinConfig.GetSetting("MinHeight") or 3.0
	local maxH = CoinConfig.GetSetting("MaxHeight") or 4.0

	local x = math.random(-radius, radius)
	local z = math.random(-radius, radius)
	local y = math.random(math.floor(minH * 10), math.floor(maxH * 10)) / 10
	return Vector3.new(x, y, z)
end

local function getActiveCoinCount()
	if not coinFolder then
		return 0
	end
	return #coinFolder:GetChildren()
end

local spawnCoin -- forward declaration
local spawnGem -- forward declaration
local spawnArenaItem -- forward declaration
local onArenaCleared -- forward declaration

function spawnCoin(position, tierConfig)
	if not coinFolder or not coinFolder.Parent then
		return nil
	end

	local maxCoins = CoinConfig.GetSetting("MaxCoins")
	if getActiveCoinCount() >= maxCoins then
		return nil
	end

	position = position or getRandomPosition()
	tierConfig = tierConfig or CoinConfig.SelectRandomTier()

	local coinInstance = Coin.new(position, tierConfig)
	coinInstance:SetParent(coinFolder)

	coinInstance:BindCollection(function(player, coin)
		-- Only the active player who initiated the run is allowed to collect coins
		if activePlayer and player ~= activePlayer then
			return
		end

		-- Apply player's base coin multiplier if they own a base
		local multiplier = 1.0
		local ownedBase = playerToBaseMap[player]
		if ownedBase then
			multiplier = ownedBase.coinMultiplier or 1.0
		end

		local result = VaultService.ProcessCollection(player, "Coins", coin:GetValue(), multiplier)
		if ownedBase and result then
			ownedBase:UpdatePerformance({
				totalEarned = ownedBase.totalEarned + result.earned,
				score = ownedBase.performanceScore + result.score,
			})
		end

		local isBatchOnly = CoinConfig.GetSetting("BatchRespawnOnly")
		if isBatchOnly then
			-- Round-based: check if arena cleared
			task.defer(function()
				if getActiveCoinCount() == 0 and not isRoundResetting then
					onArenaCleared("AllCoinsCollected")
				end
			end)
		else
			-- Continuous trickle respawn mode
			local delayTime = math.max(0.1, CoinConfig.GetSetting("RespawnDelay"))
			task.delay(delayTime, function()
				if coinFolder and getActiveCoinCount() < CoinConfig.GetSetting("MaxCoins") then
					spawnArenaItem()
				end
			end)

			task.defer(function()
				if getActiveCoinCount() == 0 and not isRoundResetting then
					onArenaCleared("AllCoinsCollected")
				end
			end)
		end
	end)

	return coinInstance
end

function spawnGem(position, tierConfig)
	if not coinFolder or not coinFolder.Parent then
		return nil
	end

	local maxCoins = CoinConfig.GetSetting("MaxCoins")
	if getActiveCoinCount() >= maxCoins then
		return nil
	end

	position = position or getRandomPosition()
	tierConfig = tierConfig or GemConfig.SelectRandomTier()

	local gemInstance = Gem.new(position, tierConfig)
	gemInstance:SetParent(coinFolder)

	gemInstance:BindCollection(function(player, gem)
		-- Only the active player who initiated the run is allowed to collect items
		if activePlayer and player ~= activePlayer then
			return
		end

		-- Apply player's base multiplier if they own a base
		local multiplier = 1.0
		local ownedBase = playerToBaseMap[player]
		if ownedBase then
			multiplier = ownedBase.coinMultiplier or 1.0
		end

		local result = VaultService.ProcessCollection(player, "Gems", gem:GetValue(), multiplier)
		if ownedBase and result then
			ownedBase:UpdatePerformance({
				score = ownedBase.performanceScore + result.score,
			})
		end

		local isBatchOnly = CoinConfig.GetSetting("BatchRespawnOnly")
		if isBatchOnly then
			-- Round-based: check if arena cleared
			task.defer(function()
				if getActiveCoinCount() == 0 and not isRoundResetting then
					onArenaCleared("AllCoinsCollected")
				end
			end)
		else
			-- Continuous trickle respawn mode
			local delayTime = math.max(0.1, GemConfig.GetSetting("RespawnDelay") or 2)
			task.delay(delayTime, function()
				if coinFolder and getActiveCoinCount() < CoinConfig.GetSetting("MaxCoins") then
					spawnArenaItem()
				end
			end)

			task.defer(function()
				if getActiveCoinCount() == 0 and not isRoundResetting then
					onArenaCleared("AllCoinsCollected")
				end
			end)
		end
	end)

	return gemInstance
end

function spawnArenaItem(position)
	local gemEnabled = GemConfig.GetSetting("Enabled")
	if currentRoundItemType == "Gem" and gemEnabled == true then
		return spawnGem(position, GemConfig.SelectRandomTier())
	else
		return spawnCoin(position, CoinConfig.SelectRandomTier())
	end
end

-- Fully repopulates the arena up to MaxCoins
local function repopulateAllCoins(forceItemType: string?)
	if not coinFolder then
		return
	end

	-- Clear out any uncollected or remaining coins first
	coinFolder:ClearAllChildren()

	if forceItemType then
		currentRoundItemType = forceItemType
	else
		-- Determine round item type: 1 in 5 rounds (SpawnRate default 0.2) spawns all gems
		local gemEnabled = GemConfig.GetSetting("Enabled")
		local gemRate = GemConfig.GetSetting("SpawnRate") or 0.2
		if gemEnabled == true and math.random() < gemRate then
			currentRoundItemType = "Gem"
		else
			currentRoundItemType = "Coin"
		end
	end

	local isGemRound = (currentRoundItemType == "Gem")
	local coinSettings = CoinConfig.GetSettingsInstance()
	if coinSettings then
		coinSettings:SetAttribute("CurrentRoundItemType", currentRoundItemType)
		coinSettings:SetAttribute("IsGemRound", isGemRound)
	end

	local gemSettings = GemConfig.GetSettingsInstance()
	if gemSettings then
		gemSettings:SetAttribute("CurrentRoundItemType", currentRoundItemType)
		gemSettings:SetAttribute("IsGemRound", isGemRound)
	end

	local maxCoins = CoinConfig.GetSetting("MaxCoins")
	for _ = 1, maxCoins do
		spawnArenaItem()
	end
end

local function cancelRunnerCooldown()
	if cooldownThread then
		local thread = cooldownThread
		cooldownThread = nil
		if thread ~= coroutine.running() and coroutine.status(thread) ~= "dead" then
			pcall(function()
				task.cancel(thread)
			end)
		end
	end
	cooldownPlayer = nil
	cooldownRemaining = 0
end

-- Updates all bases' activate pads with the current arena availability
local function updateAllBaseActivationPads(isBusy, busyOwnerName)
	for _, b in ipairs(playerBases) do
		local owner = b:GetOwner()
		if isBusy then
			if owner and (owner.DisplayName == busyOwnerName or owner.Name == busyOwnerName) then
				b:SetActivatePadState("RUN IN PROGRESS\n[Arena Active]", Color3.fromRGB(230, 126, 34), false)
			else
				b:SetActivatePadState(string.format("ARENA OCCUPIED\n[%s Playing]", busyOwnerName or "Player"), Color3.fromRGB(231, 76, 60), false)
			end
		else
			if cooldownPlayer and owner == cooldownPlayer and cooldownRemaining > 0 then
				b:SetActivatePadState(string.format("COOLDOWN [%ds]\n[Other Players First]", cooldownRemaining), Color3.fromRGB(241, 196, 15), false)
			else
				if currentRoundItemType == "Gem" then
					b:SetActivatePadState("💎 GEM JACKPOT RUN 💎\n[Step to Open Gate]", Color3.fromRGB(80, 220, 255), true)
				else
					b:SetActivatePadState("⚡ START ARENA RUN ⚡\n[Step to Open Gate]", Color3.fromRGB(46, 204, 113), true)
				end
			end
		end
	end
end

local function startRunnerCooldown(player, base)
	cancelRunnerCooldown()
	local duration = CoinConfig.GetSetting("RunnerCooldown") or 10
	if duration <= 0 then
		return
	end

	cooldownPlayer = player
	cooldownRemaining = duration

	-- Immediately disable and reflect cooldown on the runner's base activation pad
	if base then
		base:SetActivatePadState(string.format("COOLDOWN [%ds]\n[Other Players First]", cooldownRemaining), Color3.fromRGB(241, 196, 15), false)
	end

	cooldownThread = task.spawn(function()
		while cooldownRemaining > 0 do
			task.wait(1)
			cooldownRemaining -= 1
			if cooldownRemaining > 0 then
				if base and activePlayer == nil then
					base:SetActivatePadState(string.format("COOLDOWN [%ds]\n[Other Players First]", cooldownRemaining), Color3.fromRGB(241, 196, 15), false)
				end
			end
		end

		cooldownPlayer = nil
		cooldownThread = nil

		-- Re-enable runner's pad if arena is idle and not resetting
		if base and activePlayer == nil and not isRoundResetting then
			if currentRoundItemType == "Gem" then
				base:SetActivatePadState("💎 GEM JACKPOT RUN 💎\n[Step to Open Gate]", Color3.fromRGB(80, 220, 255), true)
			else
				base:SetActivatePadState("⚡ START ARENA RUN ⚡\n[Step to Open Gate]", Color3.fromRGB(46, 204, 113), true)
			end
		end
	end)
end

-- Cancels the active timer countdown if running
local function cancelExpirationTimer()
	if activeTimerThread then
		local thread = activeTimerThread
		activeTimerThread = nil
		if thread ~= coroutine.running() and coroutine.status(thread) ~= "dead" then
			pcall(function()
				task.cancel(thread)
			end)
		end
	end
	activeExpirationTimer = 0
end

-- Triggered when coins have been collected or timer expired
function onArenaCleared(reason)
	if isRoundResetting then
		return
	end
	isRoundResetting = true
	cancelExpirationTimer()

	local runnerToReset = activePlayer
	local runnerBase = activeBase

	local settingsFolder = CoinConfig.GetSettingsInstance()
	settingsFolder:SetAttribute("ArenaStatus", "Locked")
	settingsFolder:SetAttribute("ArenaActivePlayer", "")
	settingsFolder:SetAttribute("ArenaActiveBaseId", 0)
	settingsFolder:SetAttribute("ArenaTimeRemaining", 0)
	enclosure:UpdateDisplayBoards("", 0, false)

	-- Restore arena walls to opaque now that the run is over
	enclosure:SetWallTransparency(0)

	-- Safety watchdog timeout to guarantee recovery if any callback or tween drops
	task.delay(4.0, function()
		if isRoundResetting then
			warn("[CoinCollector] Watchdog triggered: recovering stuck arena state")
			settingsFolder:SetAttribute("ArenaStatus", "IdleReady")
			settingsFolder:SetAttribute("ArenaActivePlayer", "")
			settingsFolder:SetAttribute("ArenaActiveBaseId", 0)
			settingsFolder:SetAttribute("ArenaTimeRemaining", 0)
			activePlayer = nil
			activeBase = nil
			isRoundResetting = false
			updateAllBaseActivationPads(false)
			enclosure:UpdateDisplayBoards("", 0, false, currentRoundItemType == "Gem")
			enclosure:SetWallTransparency(0)
		end
	end)

	-- 1. Immediately eject player(s) from the arena
	if runnerToReset and runnerToReset.Parent and runnerBase then
		if runnerToReset.Character and runnerToReset.Character:FindFirstChild("HumanoidRootPart") then
			local root = runnerToReset.Character.HumanoidRootPart
			root.CFrame = runnerBase:GetSpawnCFrame()
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- Eject any remaining players inside the arena to their bases or gate approach pathways
	enclosure:EjectPlayers(function(player)
		local base = playerToBaseMap[player]
		if base then
			return base:GetSpawnCFrame()
		end
		return nil
	end)

	-- 2. Deactivate the runner's base activation pad immediately & put on cooldown,
	-- while enabling other players' base activation pads so they can activate their base!
	if runnerToReset and runnerBase then
		startRunnerCooldown(runnerToReset, runnerBase)
	end
	updateAllBaseActivationPads(false)

	-- 3. Close the gate smoothly now that the player has been ejected
	gate:Close(function()
		-- Repopulate all coins into the collection area while gates are locked
		task.wait(0.3)
		repopulateAllCoins()

		settingsFolder:SetAttribute("ArenaStatus", "IdleReady")
		activePlayer = nil
		activeBase = nil
		isRoundResetting = false
		updateAllBaseActivationPads(false)
		enclosure:UpdateDisplayBoards("", 0, false, currentRoundItemType == "Gem")
	end)
end

-- Starts a solo arena run initiated by a player from their own base
local function startSoloArenaRun(player, base)
	if isRoundResetting or activePlayer ~= nil then
		return
	end

	activePlayer = player
	activeBase = base
	local playerName = player.DisplayName or player.Name

	local settingsFolder = CoinConfig.GetSettingsInstance()
	settingsFolder:SetAttribute("ArenaStatus", "ActiveRun")
	settingsFolder:SetAttribute("ArenaActivePlayer", playerName)
	settingsFolder:SetAttribute("ArenaActiveBaseId", base.id)

	-- Make arena walls transparent so other players can see the runner and timer
	local wallTrans = CoinConfig.GetSetting("ArenaWallTransparency") or 0.7
	enclosure:SetWallTransparency(wallTrans)

	-- Update pads across all bases
	updateAllBaseActivationPads(true, playerName)

	local duration = CoinConfig.GetSetting("CoinExpirationTime") or 30
	activeExpirationTimer = duration
	enclosure:UpdateDisplayBoards(playerName, duration, true, currentRoundItemType == "Gem")

	-- Eject any unauthorized players lingering inside the arena before opening gate
	enclosure:EjectPlayers(function(intruder)
		local ownedBase = playerToBaseMap[intruder]
		if ownedBase then
			return ownedBase:GetSpawnCFrame()
		end
		return nil
	end, player)

	-- Open ONLY this player's cardinal gate; keep other 3 gates firmly shut
	local cardinalDirection = base.theme.direction
	gate:OpenSingleGate(cardinalDirection, function()
		-- Start expiration timer countdown
		local duration = CoinConfig.GetSetting("CoinExpirationTime") or 30
		activeExpirationTimer = duration

		activeTimerThread = task.spawn(function()
			while activeExpirationTimer > 0 do
				task.wait(1)
				activeExpirationTimer -= 1
				settingsFolder:SetAttribute("ArenaTimeRemaining", activeExpirationTimer)
				enclosure:UpdateDisplayBoards(playerName, activeExpirationTimer, true, currentRoundItemType == "Gem")
			end
			-- Timer expired without collecting all coins!
			if not isRoundResetting and activePlayer == player then
				task.defer(function()
					onArenaCleared("TimeExpired")
				end)
			end
		end)
	end)
end

-- Sets up the 4 player bases in cardinal directions outside the arena
local function setupPlayerBases()
	local baseDistance = CoinConfig.GetSetting("BaseDistance") or 140
	local baseSize = CoinConfig.GetSetting("BaseSize") or 84
	local wallHeight = CoinConfig.GetSetting("BaseWallHeight") or 9

	local basesFolder = Workspace:FindFirstChild("PlayerBases")
	if basesFolder then
		basesFolder:Destroy()
	end
	basesFolder = Instance.new("Folder")
	basesFolder.Name = "PlayerBases"
	basesFolder.Parent = Workspace

	local baseLayouts = {
		{ id = 1, pos = Vector3.new(0, 0, -baseDistance), facing = Vector3.new(0, 0, 1) },  -- North base
		{ id = 2, pos = Vector3.new(0, 0, baseDistance), facing = Vector3.new(0, 0, -1) },  -- South base
		{ id = 3, pos = Vector3.new(baseDistance, 0, 0), facing = Vector3.new(-1, 0, 0) },  -- East base
		{ id = 4, pos = Vector3.new(-baseDistance, 0, 0), facing = Vector3.new(1, 0, 0) },  -- West base
	}

	playerBases = {}
	local bankDebounce = {}

	for _, cfg in ipairs(baseLayouts) do
		local base = PlayerBase.new(cfg.id, cfg.pos, cfg.facing, {
			size = baseSize,
			wallHeight = wallHeight,
			baseStartingLevel = CoinConfig.GetSetting("BaseStartingLevel") or 1,
			baseStartingMultiplier = CoinConfig.GetSetting("BaseStartingMultiplier") or 1.0,
		})
		base:Build(basesFolder)

		-- Interactive Claim Pad Handler
		base:OnClaim(function(player, claimedBase)
			-- If base is already owned, or if player has already claimed a base this session, ignore
			if claimedBase:IsOwned() or playerToBaseMap[player] ~= nil then
				return
			end

			claimedBase:SetOwner(player)
			playerToBaseMap[player] = claimedBase
			player:SetAttribute("AssignedBaseId", claimedBase.id)

			local vault = VaultService.GetVault(player)
			local storedCoins = vault["Coins"] or 0
			local restoredLevel = VaultItemRegistry.CalculateBaseLevel(vault)
			local restoredMultiplier = VaultItemRegistry.CalculateMultiplier(restoredLevel)
			claimedBase:UpdatePerformance({
				bankedCoins = storedCoins,
				level = restoredLevel,
				multiplier = restoredMultiplier,
			})
		end)

		-- Interactive Bank Pad Handler: deposit coins into base
		base:OnBank(function(player, targetBase)
			if targetBase:GetOwner() ~= player then
				return
			end

			VaultService.ProcessDeposit(player, targetBase)

			local now = tick()
			if not bankDebounce[player] or now >= bankDebounce[player] then
				bankDebounce[player] = now + 1.5
				VaultService.OpenVaultForPlayer(player)
			end
		end)

		-- Interactive Proximity Prompt Vault Open
		base:OnOpenVault(function(player, targetBase)
			if targetBase:GetOwner() == player then
				VaultService.OpenVaultForPlayer(player)
			end
		end)

		-- Interactive Arena Activation Pad Handler: Step on pad in own base to start run
		base:OnActivate(function(player, triggeringBase)
			-- If base is unclaimed and player has no base, auto-claim
			if not triggeringBase:IsOwned() and not playerToBaseMap[player] then
				triggeringBase:SetOwner(player)
				playerToBaseMap[player] = triggeringBase
				player:SetAttribute("AssignedBaseId", triggeringBase.id)
			end

			-- Can only activate if the player owns this base
			if triggeringBase:GetOwner() ~= player then
				return
			end

			-- Cannot activate if arena is already occupied or round is resetting
			if activePlayer ~= nil or isRoundResetting then
				return
			end

			-- Cannot activate if this player is currently in runner cooldown (giving others advantage)
			if cooldownPlayer == player and cooldownRemaining > 0 then
				return
			end

			cancelRunnerCooldown()
			startSoloArenaRun(player, triggeringBase)
		end)

		table.insert(playerBases, base)
	end
end

local function initializeGame()
	VaultService.Init()

	local settingsFolder = CoinConfig.GetSettingsInstance()
	settingsFolder:SetAttribute("ArenaStatus", "IdleReady")
	settingsFolder:SetAttribute("ArenaActivePlayer", "")
	settingsFolder:SetAttribute("ArenaActiveBaseId", 0)

	GemConfig.GetSettingsInstance()

	-- 1. Construct Central Coin Arena Enclosure with 4 Gates
	enclosure = ArenaEnclosure.new({
		sizeX = CoinConfig.GetSetting("ArenaSizeX"),
		sizeZ = CoinConfig.GetSetting("ArenaSizeZ"),
		wallHeight = CoinConfig.GetSetting("WallHeight"),
		wallThickness = CoinConfig.GetSetting("WallThickness"),
		gateWidth = CoinConfig.GetSetting("GateWidth"),
		gateHeight = CoinConfig.GetSetting("GateHeight"),
		center = Vector3.new(0, 0, 0),
		baseDistance = CoinConfig.GetSetting("BaseDistance") or 140,
		baseSize = CoinConfig.GetSetting("BaseSize") or 84,
	})
	enclosure:Build()

	-- 2. Construct Gate Controller with all 4 cardinal gates (North, South, East, West)
	local gatesData = enclosure:GetGatesInfo()
	local moveDuration = CoinConfig.GetSetting("GateMoveDuration")
	gate = GateController.new(gatesData, moveDuration)

	-- Bind gate sensor to prevent unauthorized players from entering the gate
	gate:BindGateSensors(function(hit, gateItem)
		-- Ignore sensor if the gate is closed (closed gates have CanCollide = true door parts)
		if gateItem.state == GateController.State.Closed then
			return
		end

		-- Ignore if arena is idle
		if not activePlayer then
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

		local root = hit.Parent:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		-- Ignore players who are already inside the arena
		if enclosure:IsInside(root.Position) then
			return
		end

		-- If this is not the active player, or if the gate does not belong to the active player's base, bounce them back
		local isAllowed = false
		if activePlayer and player == activePlayer and activeBase then
			if string.lower(gateItem.direction) == string.lower(activeBase.theme.direction) then
				isAllowed = true
			end
		end

		if not isAllowed then
			-- Bounce/teleport player back to their own base or gate approach pathway
			local ownedBase = playerToBaseMap[player]
			if ownedBase then
				root.CFrame = ownedBase:GetSpawnCFrame()
			else
				-- Teleport backward along the highway
				root.CFrame = gateItem.doorPart.CFrame * CFrame.new(0, 2, 16)
			end
		end
	end)

	-- 3. Construct 4 Contained Player Bases positioned away from central arena
	setupPlayerBases()

	-- 4. Clean up any previous coin folder and create a fresh one
	local existingFolder = Workspace:FindFirstChild("Coins")
	if existingFolder then
		existingFolder:Destroy()
	end

	coinFolder = Instance.new("Folder")
	coinFolder.Name = "Coins"
	coinFolder.Parent = Workspace

	-- 5. Spawn initial batch of coins in the central arena
	repopulateAllCoins("Coin")

	-- Make sure all 4 gates start closed and locked
	gate:Close()
	enclosure:UpdateDisplayBoards("", 0, false, currentRoundItemType == "Gem")
	updateAllBaseActivationPads(false)
end

-- Note: Coin spin & bob animation is handled client-side in StarterPlayerScripts (CoinVisualController)
-- to ensure maximum framerate smoothness and eliminate unnecessary network replication.

-- Player Join and Character Spawning Handler
local function onCharacterAdded(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end

	task.wait(0.1)
	-- If player owns a base, spawn them at their owned base
	local ownedBase = playerToBaseMap[player]
	if ownedBase then
		root.CFrame = ownedBase:GetSpawnCFrame()
	else
		-- Collect all available unclaimed bases
		local availableBases = {}
		for _, b in ipairs(playerBases) do
			if not b:IsOwned() then
				table.insert(availableBases, b)
			end
		end

		if #availableBases > 0 then
			local randomIndex = math.random(1, #availableBases)
			local targetBase = availableBases[randomIndex]
			root.CFrame = targetBase:GetSpawnCFrame()
		else
			-- Fallback if all 4 bases are claimed: place outside arena gates
			root.CFrame = CFrame.new(0, 5, 0)
		end
	end
end

initializeGame()

Players.PlayerAdded:Connect(function(player)
	ensureLeaderstats(player)
	VaultService.LoadPlayer(player)

	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end)

-- Clean up base ownership when player leaves
Players.PlayerRemoving:Connect(function(player)
	-- If active arena player leaves mid-run, abort and clear arena immediately
	if activePlayer == player then
		onArenaCleared("PlayerLeft")
	end

	if cooldownPlayer == player then
		cancelRunnerCooldown()
	end

	local ownedBase = playerToBaseMap[player]
	if ownedBase then
		ownedBase:ClearOwner()
		playerToBaseMap[player] = nil
	end

	VaultService.SavePlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	ensureLeaderstats(player)
	VaultService.LoadPlayer(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end
