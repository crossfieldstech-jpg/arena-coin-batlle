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

local remotesFolder = nil
local getVaultDataFunction = nil
local vaultUpdatedEvent = nil
local openVaultUIEvent = nil
local isInitialized = false

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

return VaultService
