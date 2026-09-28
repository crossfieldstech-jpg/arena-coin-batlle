--[[
	MiniGameRegistry.luau
	Pure configuration, schema validation, and catalog for modular Sky Sub-Arena mini-games
	and Next-Run Arena Buffs. Zero side-effects, fully inspectable across client & server.
]]

local MiniGameRegistry = {}

local registeredGames = {}
local registeredBuffs = {}

-- Schema Validator
function MiniGameRegistry.RegisterGame(gameDef)
	assert(typeof(gameDef) == "table", "gameDef must be a table")
	assert(typeof(gameDef.id) == "string", "gameDef.id must be a string")
	assert(typeof(gameDef.displayName) == "string", "gameDef.displayName must be a string")
	assert(typeof(gameDef.category) == "string", "gameDef.category must be a string")
	assert(typeof(gameDef.description) == "string", "gameDef.description must be a string")
	assert(typeof(gameDef.icon) == "string", "gameDef.icon must be a string")
	assert(typeof(gameDef.duration) == "number", "gameDef.duration must be a number (seconds)")
	assert(typeof(gameDef.rewards) == "table", "gameDef.rewards must be a table")
	assert(typeof(gameDef.buff) == "table", "gameDef.buff must be a table")
	assert(typeof(gameDef.order) == "number", "gameDef.order must be a number")

	local rewards = {
		minCoins = gameDef.rewards.minCoins or 40,
		maxCoins = gameDef.rewards.maxCoins or 80,
		minGems = gameDef.rewards.minGems or 1,
		maxGems = gameDef.rewards.maxGems or 2,
		relicChance = gameDef.rewards.relicChance or 0,
		fragmentChance = gameDef.rewards.fragmentChance or 0,
	}

	local buff = {
		id = gameDef.buff.id or (gameDef.id .. "_Buff"),
		type = gameDef.buff.type or "MultiplierBonus", -- "TimeBonus" | "MultiplierBonus"
		value = gameDef.buff.value or 0.15,
		displayName = gameDef.buff.displayName or "Next-Run Buff",
		description = gameDef.buff.description or "Boosts next central arena run",
		icon = gameDef.buff.icon or "⚡",
	}

	registeredBuffs[buff.id] = buff

	registeredGames[gameDef.id] = {
		id = gameDef.id,
		displayName = gameDef.displayName,
		category = gameDef.category,
		description = gameDef.description,
		icon = gameDef.icon,
		duration = gameDef.duration,
		rewards = rewards,
		buff = buff,
		order = gameDef.order,
		enabled = if gameDef.enabled ~= nil then gameDef.enabled else true,
	}

	return registeredGames[gameDef.id]
end

function MiniGameRegistry.GetGame(id)
	return registeredGames[id]
end

function MiniGameRegistry.GetAllGames()
	local list = {}
	for _, gameItem in pairs(registeredGames) do
		table.insert(list, gameItem)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

function MiniGameRegistry.GetEnabledGames()
	local list = {}
	for _, gameItem in pairs(registeredGames) do
		if gameItem.enabled then
			table.insert(list, gameItem)
		end
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

function MiniGameRegistry.GetBuff(buffId)
	return registeredBuffs[buffId]
end

function MiniGameRegistry.GetAllBuffs()
	return registeredBuffs
end

-- =========================================================================
-- Built-in Pilot Mini-Games
-- =========================================================================

-- 1. "Coin Forge" (Micro-Tycoon Loop: Ore -> Bellows Crucible -> Stamper)
MiniGameRegistry.RegisterGame({
	id = "CoinForge",
	displayName = "Coin Forge",
	category = "Micro-Tycoon",
	description = "Mine raw gold ore, pump the bellows to smelt ingots, and stamp out minted coin batches before the clock runs out!",
	icon = "🔥",
	duration = 60, -- 60 seconds
	order = 1,
	enabled = true,
	rewards = {
		minCoins = 40,
		maxCoins = 80,
		minGems = 1,
		maxGems = 2,
		relicChance = 0.20, -- 20% chance to drop Ancient Relic
		fragmentChance = 0.05,
	},
	buff = {
		id = "CoinForge_MultiplierBuff",
		type = "MultiplierBonus",
		value = 0.20, -- +0.20x (+20%) bonus on player's next central arena run
		displayName = "Forgemaster's Focus",
		description = "+20% Coin & Gem Multiplier on your next Central Arena run!",
		icon = "⚡",
	},
})

-- 2. "Base Sentry" (Tower Defense: 3 Waves of rogue clockwork thieves -> Mini-Vault)
MiniGameRegistry.RegisterGame({
	id = "BaseSentry",
	displayName = "Base Sentry",
	category = "Tower Defense",
	description = "Deploy rapid Gatling sentries and frost traps along the defense corridor to protect the mini-vault from clockwork thieves!",
	icon = "🛡️",
	duration = 90, -- 90 seconds (3 waves)
	order = 2,
	enabled = true,
	rewards = {
		minCoins = 60,
		maxCoins = 120,
		minGems = 1,
		maxGems = 3,
		relicChance = 0.15,
		fragmentChance = 0.10, -- 10% chance to drop Star Fragment
	},
	buff = {
		id = "BaseSentry_TimeBuff",
		type = "TimeBonus",
		value = 5, -- +5 seconds to central arena run timer (30s -> 35s)
		displayName = "Overclocked Chrono-Armor",
		description = "+5 Seconds Extra Time on your next Central Arena run!",
		icon = "⏱️",
	},
})

return MiniGameRegistry
