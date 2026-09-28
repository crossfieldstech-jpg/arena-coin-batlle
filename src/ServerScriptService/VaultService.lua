local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VaultItemRegistry = require(ReplicatedStorage:WaitForChild("VaultItemRegistry"))

local VaultService = {}

local vaultStore = nil
local pcallSuccess, err = pcall(function()
	vaultStore = DataStoreService:GetDataStore("PlayerVaultStore_v1")
end)
if not pcallSuccess then
	warn("[VaultService] DataStoreService unavailable, using in-memory mode:", err)
end

local playerVaults = {} -- userId -> { isLoaded = boolean, items = { [itemId] = number } }
local playerDepositLocks = {} -- userId -> boolean
local playerNextRunBuffs = {} -- userId -> { id, type, value, displayName, description, icon, grantedAt }

local remotesFolder = nil
local getVaultDataFunction = nil
local vaultUpdatedEvent = nil
local openVaultUIEvent = nil
local buffUpdatedEvent = nil
local isInitialized = false

-- Rolling 60-second sliding window telemetry
local faucetHistory = {} -- { { timestamp = number, itemId = string, amount = number } }
local sinkHistory = {}   -- { { timestamp = number, itemId = string, amount = number } }

local function pruneTelemetry()
	local now = os.clock()
	local cutoff = now - 60

	local i = 1
	while i <= #faucetHistory do
		if faucetHistory[i].timestamp < cutoff then
			table.remove(faucetHistory, i)
		else
			i += 1
		end
	end

	local j = 1
	while j <= #sinkHistory do
		if sinkHistory[j].timestamp < cutoff then
			table.remove(sinkHistory, j)
		else
			j += 1
		end
	end
end

local function recordFaucet(itemId, amount)
	table.insert(faucetHistory, {
		timestamp = os.clock(),
		itemId = itemId,
		amount = amount,
	})
	pruneTelemetry()
end

local function recordSink(itemId, amount)
	table.insert(sinkHistory, {
		timestamp = os.clock(),
		itemId = itemId,
		amount = amount,
	})
	pruneTelemetry()
end

local function ensureDefaultItems(items)
	local result = items or {}
	for _, item in ipairs(VaultItemRegistry.GetAllItems()) do
		if result[item.id] == nil then
			result[item.id] = 0
		end
	end
	return result
end

function VaultService.Init()
	if isInitialized then
		return
	end
	isInitialized = true

	remotesFolder = ReplicatedStorage:FindFirstChild("VaultRemotes")
	if not remotesFolder then
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = "VaultRemotes"
		remotesFolder.Parent = ReplicatedStorage
	end

	getVaultDataFunction = remotesFolder:FindFirstChild("GetVaultData")
	if not getVaultDataFunction then
		getVaultDataFunction = Instance.new("RemoteFunction")
		getVaultDataFunction.Name = "GetVaultData"
		getVaultDataFunction.Parent = remotesFolder
	end

	vaultUpdatedEvent = remotesFolder:FindFirstChild("VaultUpdated")
	if not vaultUpdatedEvent then
		vaultUpdatedEvent = Instance.new("RemoteEvent")
		vaultUpdatedEvent.Name = "VaultUpdated"
		vaultUpdatedEvent.Parent = remotesFolder
	end

	openVaultUIEvent = remotesFolder:FindFirstChild("OpenVaultUI")
	if not openVaultUIEvent then
		openVaultUIEvent = Instance.new("RemoteEvent")
		openVaultUIEvent.Name = "OpenVaultUI"
		openVaultUIEvent.Parent = remotesFolder
	end

	buffUpdatedEvent = remotesFolder:FindFirstChild("BuffUpdated")
	if not buffUpdatedEvent then
		buffUpdatedEvent = Instance.new("RemoteEvent")
		buffUpdatedEvent.Name = "BuffUpdated"
		buffUpdatedEvent.Parent = remotesFolder
	end

	getVaultDataFunction.OnServerInvoke = function(player)
		return VaultService.GetVault(player)
	end

	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			VaultService.SavePlayer(player)
		end
	end)
end

function VaultService.LoadPlayer(player)
	local userId = player.UserId
	if playerVaults[userId] and playerVaults[userId].isLoaded then
		return playerVaults[userId].items
	end

	local loadedData = nil
	if vaultStore then
		local success, result = pcall(function()
			return vaultStore:GetAsync("Vault_" .. tostring(userId))
		end)
		if success and typeof(result) == "table" then
			loadedData = result
		elseif not success then
			warn(string.format("[VaultService] Failed to load vault for player %s (%d): %s", player.Name, userId, tostring(result)))
		end
	end

	local items = ensureDefaultItems(loadedData)
	playerVaults[userId] = {
		isLoaded = true,
		items = items,
	}

	if vaultUpdatedEvent then
		vaultUpdatedEvent:FireClient(player, { items = items })
	end

	return items
end

function VaultService.SavePlayer(player)
	local userId = player.UserId
	local vault = playerVaults[userId]
	if not vault or not vault.isLoaded then
		return false
	end

	local success = true
	if vaultStore then
		local ok, result = pcall(function()
			vaultStore:SetAsync("Vault_" .. tostring(userId), vault.items)
		end)
		if not ok then
			warn(string.format("[VaultService] Failed to save vault for player %s (%d): %s", player.Name, userId, tostring(result)))
			success = false
		end
	end

	playerVaults[userId] = nil
	playerDepositLocks[userId] = nil
	playerNextRunBuffs[userId] = nil
	return success
end

function VaultService.GetVault(player)
	local userId = player.UserId
	if playerVaults[userId] and playerVaults[userId].isLoaded then
		return playerVaults[userId].items
	end

	-- If not loaded yet, attempt synchronous/inline load
	return VaultService.LoadPlayer(player)
end

function VaultService.GetItemAmount(player, itemId)
	local vault = VaultService.GetVault(player)
	if vault and vault[itemId] ~= nil then
		return vault[itemId]
	end
	return 0
end

function VaultService.SetItemAmount(player, itemId, amount)
	local userId = player.UserId
	if not playerVaults[userId] or not playerVaults[userId].isLoaded then
		VaultService.LoadPlayer(player)
	end

	local vault = playerVaults[userId]
	if not vault then
		return
	end

	vault.items[itemId] = amount

	if vaultUpdatedEvent then
		vaultUpdatedEvent:FireClient(player, {
			items = vault.items,
			updatedItem = itemId,
			newAmount = amount,
		})
	end
end

function VaultService.AddItem(player, itemId, amount)
	local current = VaultService.GetItemAmount(player, itemId)
	VaultService.SetItemAmount(player, itemId, current + amount)
end

function VaultService.OpenVaultForPlayer(player)
	if openVaultUIEvent then
		openVaultUIEvent:FireClient(player)
	end
end

function VaultService.ApplyNextRunBuff(player, buffDef)
	if not player or not player.UserId or not buffDef then
		return
	end
	local userId = player.UserId
	playerNextRunBuffs[userId] = {
		id = buffDef.id or "Buff",
		type = buffDef.type or "MultiplierBonus",
		value = buffDef.value or 0.15,
		displayName = buffDef.displayName or "Arena Buff",
		description = buffDef.description or "",
		icon = buffDef.icon or "⚡",
		grantedAt = os.clock(),
	}

	if buffUpdatedEvent and player.Parent then
		buffUpdatedEvent:FireClient(player, playerNextRunBuffs[userId])
	end
end

function VaultService.GetActiveBuff(player)
	if not player or not player.UserId then
		return nil
	end
	return playerNextRunBuffs[player.UserId]
end

function VaultService.ConsumeNextRunBuff(player)
	if not player or not player.UserId then
		return nil
	end
	local userId = player.UserId
	local buff = playerNextRunBuffs[userId]
	playerNextRunBuffs[userId] = nil

	if buffUpdatedEvent and player.Parent then
		buffUpdatedEvent:FireClient(player, nil)
	end
	return buff
end

function VaultService.EnsurePlayerLeaderstats(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local valueObjects = {}
	for _, item in ipairs(VaultItemRegistry.GetAllItems()) do
		if item.enabled and item.leaderstatsKey then
			local valObj = leaderstats:FindFirstChild(item.leaderstatsKey)
			if not valObj then
				if item.leaderstatsType == "NumberValue" then
					valObj = Instance.new("NumberValue")
				else
					valObj = Instance.new("IntValue")
				end
				valObj.Name = item.leaderstatsKey
				valObj.Value = 0
				valObj.Parent = leaderstats
			end
			valueObjects[item.id] = valObj
		end
	end

	return leaderstats, valueObjects
end

function VaultService.ProcessCollection(player, itemId, rawValue, multiplier)
	local item = VaultItemRegistry.GetItem(itemId)
	if not item or not item.enabled then
		return nil
	end

	multiplier = multiplier or 1.0
	local earned = 0
	if item.leaderstatsType == "IntValue" then
		earned = math.round(rawValue * multiplier)
	else
		earned = math.round((rawValue * multiplier) * 10) / 10
	end

	if item.leaderstatsKey then
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			leaderstats = VaultService.EnsurePlayerLeaderstats(player)
		end
		local valObj = leaderstats:FindFirstChild(item.leaderstatsKey)
		if not valObj then
			VaultService.EnsurePlayerLeaderstats(player)
			valObj = leaderstats:FindFirstChild(item.leaderstatsKey)
		end
		if valObj then
			valObj.Value += earned
		end
	end

	local score = math.round(earned * (item.scoreMultiplier or 1))
	recordFaucet(itemId, earned)

	return {
		earned = earned,
		score = score,
		itemId = itemId,
	}
end

function VaultService.ProcessDeposit(player, targetBase)
	if not player or not player.UserId then
		return nil
	end

	local userId = player.UserId
	if playerDepositLocks[userId] then
		return nil
	end
	playerDepositLocks[userId] = true

	local success, result = pcall(function()
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			return nil
		end

		local totalScoreGain = 0
		local depositedAny = false

		for _, item in ipairs(VaultItemRegistry.GetAllItems()) do
			if item.enabled and item.leaderstatsKey then
				local valObj = leaderstats:FindFirstChild(item.leaderstatsKey)
				if valObj and valObj.Value > 0 then
					local carriedAmount = valObj.Value
					valObj.Value = 0

					VaultService.AddItem(player, item.id, carriedAmount)
					totalScoreGain += math.round(carriedAmount * (item.scoreMultiplier or 1))
					recordSink(item.id, carriedAmount)
					depositedAny = true
				end
			end
		end

		local vault = VaultService.GetVault(player)
		local newLevel, progress, nextCost = VaultItemRegistry.CalculateBaseLevel(vault)
		local newMultiplier = VaultItemRegistry.CalculateMultiplier(newLevel)
		local totalBankedCoins = vault["Coins"] or 0

		if targetBase then
			local currentScore = targetBase.performanceScore or 0
			targetBase:UpdatePerformance({
				bankedCoins = totalBankedCoins,
				level = newLevel,
				multiplier = newMultiplier,
				score = currentScore + totalScoreGain,
			})
		end

		return {
			totalScoreGain = totalScoreGain,
			newLevel = newLevel,
			newMultiplier = newMultiplier,
			bankedCoins = totalBankedCoins,
		}
	end)

	playerDepositLocks[userId] = nil

	if not success then
		warn("[VaultService.ProcessDeposit] Error during deposit:", result)
		return nil
	end
	return result
end

function VaultService.ProcessSpend(player, itemId, amount)
	if typeof(amount) ~= "number" or amount <= 0 then
		return false
	end

	local current = VaultService.GetItemAmount(player, itemId)
	if current < amount then
		return false
	end

	VaultService.SetItemAmount(player, itemId, current - amount)
	recordSink(itemId, amount)
	return true
end

function VaultService.GetEconomyHealthReport()
	pruneTelemetry()

	local totalFaucets = 0
	local faucetsByItem = {}
	for _, entry in ipairs(faucetHistory) do
		totalFaucets += entry.amount
		faucetsByItem[entry.itemId] = (faucetsByItem[entry.itemId] or 0) + entry.amount
	end

	local totalSinks = 0
	local sinksByItem = {}
	for _, entry in ipairs(sinkHistory) do
		totalSinks += entry.amount
		sinksByItem[entry.itemId] = (sinksByItem[entry.itemId] or 0) + entry.amount
	end

	local faucetsPerMinute = totalFaucets
	local sinksPerMinute = totalSinks
	local netVelocity = faucetsPerMinute - sinksPerMinute
	local inflationRatio = if totalSinks > 0 then (totalFaucets / totalSinks) else totalFaucets

	local warnings = {}
	local status = "HEALTHY"

	if totalFaucets > 10 * math.max(1, totalSinks) then
		status = "WARNING"
		table.insert(warnings, "HIGH_INFLATION: Faucet outpaces sink by >10x")
	end

	-- Check if any player's multiplier exceeds 2.9x
	for _, p in ipairs(Players:GetPlayers()) do
		local vault = VaultService.GetVault(p)
		if vault then
			local level = VaultItemRegistry.CalculateBaseLevel(vault)
			local mult = VaultItemRegistry.CalculateMultiplier(level)
			if mult > 2.9 then
				status = "WARNING"
				table.insert(warnings, string.format("HIGH_MULTIPLIER: Player %s has multiplier %.2fx (>2.9x)", p.Name, mult))
			end
		end
	end

	return {
		status = status,
		metrics = {
			faucetsPerMinute = faucetsPerMinute,
			sinksPerMinute = sinksPerMinute,
			netVelocity = netVelocity,
			inflationRatio = inflationRatio,
			faucetsByItem = faucetsByItem,
			sinksByItem = sinksByItem,
		},
		warnings = warnings,
	}
end

return VaultService
