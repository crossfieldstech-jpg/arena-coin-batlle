local VaultItemRegistry = {}

local registeredItems = {}

function VaultItemRegistry.RegisterItem(itemDef)
	assert(typeof(itemDef) == "table", "itemDef must be a table")
	assert(typeof(itemDef.id) == "string", "itemDef.id must be a string")
	assert(typeof(itemDef.displayName) == "string", "itemDef.displayName must be a string")
	assert(typeof(itemDef.category) == "string", "itemDef.category must be a string")
	assert(typeof(itemDef.description) == "string", "itemDef.description must be a string")
	assert(typeof(itemDef.icon) == "string", "itemDef.icon must be a string")
	assert(typeof(itemDef.rarity) == "string", "itemDef.rarity must be a string")
	assert(typeof(itemDef.order) == "number", "itemDef.order must be a number")

	local validRoles = { Currency = true, Commodity = true, Treasure = true, Material = true }
	local economicRole = itemDef.economicRole or "Commodity"
	assert(validRoles[economicRole], "Invalid economicRole: " .. tostring(economicRole))

	local leaderstatsKey = itemDef.leaderstatsKey
	if leaderstatsKey ~= nil then
		assert(typeof(leaderstatsKey) == "string", "leaderstatsKey must be a string or nil")
	end

	local leaderstatsType = itemDef.leaderstatsType or "IntValue"
	assert(leaderstatsType == "IntValue" or leaderstatsType == "NumberValue", "leaderstatsType must be 'IntValue' or 'NumberValue'")

	local baseValue = if itemDef.baseValue ~= nil then itemDef.baseValue else 1
	assert(typeof(baseValue) == "number", "baseValue must be a number")

	local scoreMultiplier = if itemDef.scoreMultiplier ~= nil then itemDef.scoreMultiplier else 1
	assert(typeof(scoreMultiplier) == "number", "scoreMultiplier must be a number")

	local progressionWeight = if itemDef.progressionWeight ~= nil then itemDef.progressionWeight else 1
	assert(typeof(progressionWeight) == "number", "progressionWeight must be a number")

	local exchangeRate = if itemDef.exchangeRate ~= nil then itemDef.exchangeRate else 1
	assert(typeof(exchangeRate) == "number", "exchangeRate must be a number")

	registeredItems[itemDef.id] = {
		id = itemDef.id,
		displayName = itemDef.displayName,
		category = itemDef.category,
		description = itemDef.description,
		icon = itemDef.icon,
		rarity = itemDef.rarity,
		order = itemDef.order,
		enabled = if itemDef.enabled ~= nil then itemDef.enabled else false,
		baseSellPrice = itemDef.baseSellPrice,
		storageCap = itemDef.storageCap,
		tradeable = if itemDef.tradeable ~= nil then itemDef.tradeable else false,
		economicRole = economicRole,
		leaderstatsKey = leaderstatsKey,
		leaderstatsType = leaderstatsType,
		baseValue = baseValue,
		scoreMultiplier = scoreMultiplier,
		progressionWeight = progressionWeight,
		exchangeRate = exchangeRate,
	}
	return registeredItems[itemDef.id]
end

function VaultItemRegistry.GetItem(id)
	return registeredItems[id]
end

function VaultItemRegistry.GetAllItems()
	local items = {}
	for _, item in pairs(registeredItems) do
		table.insert(items, item)
	end
	table.sort(items, function(a, b)
		return a.order < b.order
	end)
	return items
end

function VaultItemRegistry.GetEnabledItems()
	local items = {}
	for _, item in pairs(registeredItems) do
		if item.enabled == true then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		return a.order < b.order
	end)
	return items
end

function VaultItemRegistry.SetItemEnabled(id, enabled)
	assert(registeredItems[id], "Item with id '" .. tostring(id) .. "' does not exist")
	registeredItems[id].enabled = (enabled == true)
end

function VaultItemRegistry.GetCurrencies()
	local items = {}
	for _, item in pairs(registeredItems) do
		if item.enabled == true and item.economicRole == "Currency" then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		return a.order < b.order
	end)
	return items
end

function VaultItemRegistry.GetEconomicItems()
	local items = {}
	for _, item in pairs(registeredItems) do
		if item.enabled == true and item.economicRole ~= nil then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		return a.order < b.order
	end)
	return items
end

function VaultItemRegistry.GetBaseUpgradeRequirement(targetLevel)
	if targetLevel <= 0 then
		return 0
	end
	return math.floor(50 * (targetLevel ^ 1.35))
end

function VaultItemRegistry.CalculateBaseLevel(vaultItems)
	local totalWeight = 0
	if typeof(vaultItems) == "number" then
		local coinsDef = registeredItems["Coins"]
		local weightPerCoin = if coinsDef then (coinsDef.progressionWeight or 1) else 1
		totalWeight = math.max(0, vaultItems * weightPerCoin)
	elseif typeof(vaultItems) == "table" then
		for itemId, amount in pairs(vaultItems) do
			if typeof(amount) == "number" and amount > 0 then
				local itemDef = registeredItems[itemId]
				local weight = if itemDef then (itemDef.progressionWeight or 1) else 1
				totalWeight += amount * weight
			end
		end
	end

	local function requirement(lvl)
		if lvl <= 1 then
			return 0
		end
		return VaultItemRegistry.GetBaseUpgradeRequirement(lvl - 1)
	end

	local level = 1
	while true do
		local nextReq = requirement(level + 1)
		if totalWeight >= nextReq then
			level += 1
		else
			break
		end
	end

	local currentReq = requirement(level)
	local nextReq = requirement(level + 1)
	local progressInLevel = totalWeight - currentReq
	local nextLevelCost = nextReq - currentReq

	return level, progressInLevel, nextLevelCost
end

function VaultItemRegistry.CalculateMultiplier(baseLevel)
	local level = if typeof(baseLevel) == "number" then math.max(1, baseLevel) else 1
	local delta = level - 1
	local bonus = math.min(2.0, (delta * 0.1) / (1 + delta * 0.02))
	return 1.0 + bonus
end

-- Default Registered Items
VaultItemRegistry.RegisterItem({
	id = "Coins",
	displayName = "Gold Coins",
	category = "Currency",
	economicRole = "Currency",
	description = "Standard gold coins collected from the arena and deposited for base upgrades",
	icon = "🪙",
	rarity = "Common",
	order = 1,
	enabled = true,
	leaderstatsKey = "Coins",
	leaderstatsType = "IntValue",
	baseValue = 1,
	scoreMultiplier = 2,
	progressionWeight = 1,
	baseSellPrice = 1,
	storageCap = 1000000,
	tradeable = false,
})

VaultItemRegistry.RegisterItem({
	id = "Gems",
	displayName = "Precious Gems",
	category = "Currency",
	economicRole = "Currency",
	description = "Rare gems used for high-tier upgrades and unique bonuses",
	icon = "💎",
	rarity = "Rare",
	order = 2,
	enabled = true,
	leaderstatsKey = "Gems",
	leaderstatsType = "NumberValue",
	baseValue = 50,
	scoreMultiplier = 3,
	progressionWeight = 10,
	baseSellPrice = 50,
	storageCap = 50000,
	tradeable = true,
})

VaultItemRegistry.RegisterItem({
	id = "AncientRelic",
	displayName = "Ancient Relic",
	category = "Treasure",
	economicRole = "Treasure",
	description = "Mysterious artifact discovered within the arena ruins",
	icon = "🏺",
	rarity = "Epic",
	order = 3,
	enabled = false,
	leaderstatsKey = nil,
	baseValue = 250,
	scoreMultiplier = 15,
	progressionWeight = 50,
	baseSellPrice = 250,
	storageCap = 100,
	tradeable = true,
})

VaultItemRegistry.RegisterItem({
	id = "StarFragment",
	displayName = "Star Fragment",
	category = "Material",
	economicRole = "Material",
	description = "Luminescent celestial fragment fallen from the night sky",
	icon = "⭐",
	rarity = "Legendary",
	order = 4,
	enabled = false,
	leaderstatsKey = nil,
	baseValue = 1000,
	scoreMultiplier = 50,
	progressionWeight = 200,
	baseSellPrice = 1000,
	storageCap = 25,
	tradeable = true,
})

return VaultItemRegistry
