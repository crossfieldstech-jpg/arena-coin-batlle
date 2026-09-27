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

-- Default Registered Items
VaultItemRegistry.RegisterItem({
	id = "Coins",
	displayName = "Gold Coins",
	category = "Currency",
	description = "Standard gold coins collected from the arena and deposited for base upgrades",
	icon = "🪙",
	rarity = "Common",
	order = 1,
	enabled = true,
	baseSellPrice = 1,
	storageCap = 1000000,
	tradeable = false,
})

VaultItemRegistry.RegisterItem({
	id = "Gems",
	displayName = "Precious Gems",
	category = "Currency",
	description = "Rare gems used for high-tier upgrades and unique bonuses",
	icon = "💎",
	rarity = "Rare",
	order = 2,
	enabled = true,
	baseSellPrice = 50,
	storageCap = 50000,
	tradeable = true,
})

VaultItemRegistry.RegisterItem({
	id = "AncientRelic",
	displayName = "Ancient Relic",
	category = "Treasure",
	description = "Mysterious artifact discovered within the arena ruins",
	icon = "🏺",
	rarity = "Epic",
	order = 3,
	enabled = false,
	baseSellPrice = 250,
	storageCap = 100,
	tradeable = true,
})

VaultItemRegistry.RegisterItem({
	id = "StarFragment",
	displayName = "Star Fragment",
	category = "Material",
	description = "Luminescent celestial fragment fallen from the night sky",
	icon = "⭐",
	rarity = "Legendary",
	order = 4,
	enabled = false,
	baseSellPrice = 1000,
	storageCap = 25,
	tradeable = true,
})

return VaultItemRegistry
