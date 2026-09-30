--[[
	AlienBaseDefence/Config.luau
	Pure configuration, enemy archetypes, wave schedules, and defense station parameters
	for the Alien Base Defence tactical tower defense mini-game package.
]]

local Config = {
	id = "AlienBaseDefence",
	displayName = "Alien Base Defence",
	category = "Tower Defense",
	description = "Deploy fortified soldier bunkers and heavy plasma batteries to protect the outpost command core from alien swarms!",
	icon = "🪖",
	duration = 95,
	order = 2,
	mode = "Hybrid",
	placeId = 0,
	platformSize = 108,

	totalWaves = 3,
	maxCoreHealth = 100,

	-- Enemy archetype stats
	enemyStats = {
		Scout = {
			name = "Alien Swarmer",
			health = 40,
			speed = 15,
			color = Color3.fromRGB(46, 204, 113),
			size = Vector3.new(2.2, 1.8, 2.2),
			vaultDamage = 15,
		},
		Armored = {
			name = "Alien Warrior",
			health = 90,
			speed = 11,
			color = Color3.fromRGB(155, 89, 182),
			size = Vector3.new(3.2, 2.6, 3.2),
			vaultDamage = 20,
		},
		Boss = {
			name = "Alien Behemoth",
			health = 280,
			speed = 7.5,
			color = Color3.fromRGB(230, 126, 34),
			size = Vector3.new(5.5, 4.5, 5.5),
			vaultDamage = 40,
		},
	},

	-- Tactical Defense Station stats
	sentryStats = {
		Tier1 = {
			name = "Soldier Bunker",
			range = 24,
			fireRate = 0.45,
			damage = 16,
			color = Color3.fromRGB(58, 85, 42),
		},
		Tier2 = {
			name = "Heavy Plasma Bunker",
			range = 28,
			fireRate = 0.25,
			damage = 30,
			color = Color3.fromRGB(41, 128, 185),
		},
	},

	-- Wave Spawning counts & cadence
	waves = {
		[1] = { count = 6, interval = 2.0 },
		[2] = { count = 8, interval = 1.8 },
		[3] = { count = 7, interval = 2.0 },
	},

	-- 9-waypoint winding path on 108x108 field
	relativeWaypoints = {
		Vector3.new(-42, 1.2, -42),
		Vector3.new(-38, 1.2, -18),
		Vector3.new(-20, 1.2, -8),
		Vector3.new(-18, 1.2, 16),
		Vector3.new(2, 1.2, 18),
		Vector3.new(4, 1.2, -22),
		Vector3.new(24, 1.2, -18),
		Vector3.new(28, 1.2, 12),
		Vector3.new(38, 1.2, 38),
	},

	-- 5 Tactical Defense Station coordinates relative to platform center
	nodeOffsets = {
		Vector3.new(-30, 1.5, -28),
		Vector3.new(-10, 1.5, -6),
		Vector3.new(-14, 1.5, 22),
		Vector3.new(16, 1.5, -12),
		Vector3.new(22, 1.5, 20),
	},

	-- Economy Rewards
	rewards = {
		minCoins = 60,
		maxCoins = 130,
		minGems = 1,
		maxGems = 3,
		relicChance = 0.20,
		fragmentChance = 0.10,
	},

	-- Next-Run Central Arena Buff
	buff = {
		id = "AlienBaseDefence_Buff",
		type = "TimeBonus",
		value = 6,
		displayName = "Orbital Recon Boost",
		description = "+6 Seconds Extra Time on your next Central Arena run!",
		icon = "🛸",
	},
}

return Config
