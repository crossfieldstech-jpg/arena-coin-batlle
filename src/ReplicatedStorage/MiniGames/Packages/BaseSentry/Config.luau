--[[
	BaseSentry/Config.luau
	Pure configuration, enemy stats, wave schedules, and sentry parameters
	for the Base Sentry tower defense mini-game package.
]]

local Config = {
	id = "BaseSentry",
	displayName = "Base Sentry",
	category = "Tower Defense",
	description = "Deploy rapid Gatling sentries and frost traps along the defense corridor to protect the mini-vault from clockwork thieves!",
	icon = "🛡️",
	duration = 90,
	order = 2,
	mode = "Hybrid",
	placeId = 0,

	totalWaves = 3,
	maxCoreHealth = 100,

	-- Enemy archetype stats
	enemyStats = {
		Scout = {
			health = 35,
			speed = 11,
			color = Color3.fromRGB(231, 76, 60),
			size = Vector3.new(2, 2, 2),
			vaultDamage = 15,
		},
		Armored = {
			health = 65,
			speed = 9,
			color = Color3.fromRGB(155, 89, 182),
			size = Vector3.new(2.5, 2.5, 2.5),
			vaultDamage = 20,
		},
		Boss = {
			health = 180,
			speed = 6,
			color = Color3.fromRGB(243, 156, 18),
			size = Vector3.new(4, 4, 4),
			vaultDamage = 35,
		},
	},

	-- Sentry level progression stats
	sentryStats = {
		Level1 = {
			range = 18,
			fireRate = 0.6,
			damage = 14,
			color = Color3.fromRGB(46, 204, 113),
		},
		Level2 = {
			range = 18,
			fireRate = 0.35,
			damage = 25,
			color = Color3.fromRGB(241, 196, 15),
		},
	},

	-- Wave Spawning counts & cadence
	waves = {
		[1] = { count = 5, interval = 2.2 },
		[2] = { count = 6, interval = 2.0 },
		[3] = { count = 5, interval = 2.2 },
	},

	-- Waypoint relative offsets from center
	relativeWaypoints = {
		Vector3.new(-18, 1.2, -18),
		Vector3.new(-18, 1.2, -6),
		Vector3.new(0, 1.2, -6),
		Vector3.new(0, 1.2, 8),
		Vector3.new(18, 1.2, 8),
		Vector3.new(18, 1.2, 18),
	},

	-- Pedestal relative offsets from center
	nodeOffsets = {
		Vector3.new(-8, 1.5, -12),
		Vector3.new(8, 1.5, 1),
		Vector3.new(-8, 1.5, 14),
	},

	-- Economy Rewards
	rewards = {
		minCoins = 60,
		maxCoins = 120,
		minGems = 1,
		maxGems = 3,
		relicChance = 0.15,
		fragmentChance = 0.10,
	},

	-- Next-Run Central Arena Buff
	buff = {
		id = "BaseSentry_TimeBuff",
		type = "TimeBonus",
		value = 5,
		displayName = "Overclocked Chrono-Armor",
		description = "+5 Seconds Extra Time on your next Central Arena run!",
		icon = "⏱️",
	},
}

return Config
