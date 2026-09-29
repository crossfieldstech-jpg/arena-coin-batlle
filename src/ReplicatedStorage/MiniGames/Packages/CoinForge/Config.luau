--[[
	CoinForge/Config.luau
	Pure configuration and tuning parameters for the Coin Forge mini-game package.
	Shared across client and server.
]]

local Config = {
	id = "CoinForge",
	displayName = "Coin Forge",
	category = "Micro-Tycoon",
	description = "Mine raw gold ore, pump the bellows to smelt ingots, and stamp out minted coin batches before the clock runs out!",
	icon = "🔥",
	duration = 60,
	order = 1,
	mode = "Hybrid",
	placeId = 0,

	-- Gameplay tuning
	maxSmeltPumps = 3,
	smeltDuration = 5, -- seconds for automated melt if unassisted by bellows

	-- Procedural station offsets relative to platform center
	stationOffsets = {
		oreBin = Vector3.new(-14, 2.5, 0),
		furnace = Vector3.new(0, 3.5, 6),
		stamper = Vector3.new(14, 2, 0),
		statusSign = Vector3.new(0, 10, 0),
	},

	-- Economy Rewards
	rewards = {
		minCoins = 40,
		maxCoins = 80,
		minGems = 1,
		maxGems = 2,
		relicChance = 0.20,
		fragmentChance = 0.05,
	},

	-- Next-Run Central Arena Buff
	buff = {
		id = "CoinForge_MultiplierBuff",
		type = "MultiplierBonus",
		value = 0.20,
		displayName = "Forgemaster's Focus",
		description = "+20% Coin & Gem Multiplier on your next Central Arena run!",
		icon = "⚡",
	},
}

return Config
