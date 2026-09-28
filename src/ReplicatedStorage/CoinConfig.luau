local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinConfig = {}

-- Base default settings
CoinConfig.Defaults = {
	-- Server limits
	MaxPlayers = 4,      -- Maximum players supported (matches 4 bases)

	-- Spawn timing & limits
	SpawnInterval = 3,   -- Interval in seconds between periodic background spawns
	RespawnDelay = 2,    -- Delay in seconds before a collected coin respawns
	MaxCoins = 30,       -- Maximum simultaneous coins allowed in the arena
	ArenaRadius = 40,    -- Radius from arena center for coin spawning (+/- studs)
	MinHeight = 3.0,     -- Minimum coin spawn height (Ground top is y=0.5, player height ~5)
	MaxHeight = 4.0,     -- Maximum coin spawn height (right at player chest/eye level)

	-- Arena Enclosure Dimensions (Central Coin Area)
	ArenaSizeX = 90,     -- Width of central coin collection arena (studs)
	ArenaSizeZ = 90,     -- Depth of central coin collection arena (studs)
	WallHeight = 26,     -- Height of enclosure walls
	WallThickness = 2,   -- Thickness of enclosure walls

	-- 4 Gate Settings (North, South, East, West gates)
	GateWidth = 14,      -- Doorway entrance width
	GateHeight = 12,     -- Doorway entrance height
	GateMoveDuration = 1.2, -- TweenService duration in seconds for open/close animation

	-- Dynamic Gate Unlock Trigger Settings
	GateMinUnlockDelay = 3, -- Minimum random delay (seconds) after full coin repopulation before gate opens
	GateMaxUnlockDelay = 8, -- Maximum random delay (seconds) after full coin repopulation before gate opens
	GateUnlockTriggerType = "DynamicTimer", -- "DynamicTimer", "AttributeFlag", or "External"
	GateUnlockFlag = false, -- Boolean attribute: toggle true in Studio / scripts to immediately trigger unlock when using flags
	BatchRespawnOnly = true, -- When true, coins are collected as a full round until 0 remain before gate locks & repopulates

	-- Solo Arena Activation & Expiration System
	CoinExpirationTime = 30, -- Seconds a player has to claim coins in the arena before coins expire and gates lock
	RunnerCooldown = 15,     -- Seconds cooldown applied to the previous runner before they can trigger the arena again
	RespawnActiveRunnerOnFinish = true, -- When true, only the active runner is respawned at their base upon run end
	ArenaActivePlayer = "",  -- Name of player currently occupying/running the arena (empty if idle)
	ArenaActiveBaseId = 0,   -- Base ID currently controlling the arena (0 if none)

	-- Player Bases Configuration (4 Separate Bases: North, South, East, West)
	BaseDistance = 140,      -- Distance from central arena (0,0,0) to each player base center (spacious separation)
	BaseSize = 84,           -- Dimensions of each player base platform (studs) - expanded 3x from 28 to 84 for activity space
	BaseWallHeight = 9,      -- Wall height when constructed by player via tasks/upgrades
	BaseStartingLevel = 1,   -- Starting level for a newly claimed player base
	BaseStartingMultiplier = 1.0, -- Default coin performance multiplier
	BaseBankCapacity = 500,  -- Initial capacity for player's base coin bank
	BaseWallCost = 150,      -- Default coin / task requirement to construct perimeter walls

	-- Arena Wall Transparency (Spectator Visibility)
	ArenaWallTransparency = 0.7, -- Wall transparency (0 = opaque, 1 = invisible). Change via CoinSettings attribute for live event control.

	-- Round item type settings
	IsGemRound = false,
	CurrentRoundItemType = "Coin",
}

-- Default tiers definitions (shape, size, base colors, etc.)
CoinConfig.Tiers = {
	Standard = {
		name = "Standard",
		itemType = "Coin",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.3, 2.5, 2.5),
		value = 1,
		weight = 60,
		color = Color3.fromRGB(240, 195, 30), -- Polished Gold
		material = Enum.Material.Metal,
		reflectance = 0.35,
		lightColor = Color3.fromRGB(255, 220, 100),
		lightRange = 3.5,
		lightBrightness = 0.35,
	},
	Silver = {
		name = "Silver",
		itemType = "Coin",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.25, 2.2, 2.2),
		value = 3,
		weight = 30,
		color = Color3.fromRGB(210, 215, 225), -- Gleaming Silver
		material = Enum.Material.Metal,
		reflectance = 0.45,
		lightColor = Color3.fromRGB(220, 230, 255),
		lightRange = 3.5,
		lightBrightness = 0.35,
	},
	Mega = {
		name = "Mega",
		itemType = "Coin",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.4, 3.5, 3.5),
		value = 10,
		weight = 10,
		color = Color3.fromRGB(70, 190, 255), -- Azure Diamond / Crystal Platinum
		material = Enum.Material.Metal,
		reflectance = 0.5,
		lightColor = Color3.fromRGB(120, 210, 255),
		lightRange = 4.0,
		lightBrightness = 0.4,
	},
}

local settingsFolder = nil

-- Creates or retrieves the Configuration instance in ReplicatedStorage
-- All attributes here can be changed live in Roblox Studio (Properties panel) or by script
function CoinConfig.GetSettingsInstance()
	if settingsFolder and settingsFolder.Parent then
		return settingsFolder
	end

	settingsFolder = ReplicatedStorage:FindFirstChild("CoinSettings")
	if not settingsFolder then
		settingsFolder = Instance.new("Configuration")
		settingsFolder.Name = "CoinSettings"
		settingsFolder.Parent = ReplicatedStorage
	end

	-- Initialize attributes with defaults if not already set
	for key, value in pairs(CoinConfig.Defaults) do
		if settingsFolder:GetAttribute(key) == nil then
			settingsFolder:SetAttribute(key, value)
		end
	end

	-- Initialize per-tier Value and Weight attributes
	for tierName, tierData in pairs(CoinConfig.Tiers) do
		local valKey = tierName .. "_Value"
		local weightKey = tierName .. "_Weight"

		if settingsFolder:GetAttribute(valKey) == nil then
			settingsFolder:SetAttribute(valKey, tierData.value)
		end
		if settingsFolder:GetAttribute(weightKey) == nil then
			settingsFolder:SetAttribute(weightKey, tierData.weight)
		end
	end

	return settingsFolder
end

-- Read an attribute dynamically (with fallback to Defaults)
function CoinConfig.GetSetting(key)
	local folder = CoinConfig.GetSettingsInstance()
	local val = folder:GetAttribute(key)
	if val ~= nil then
		return val
	end
	return CoinConfig.Defaults[key]
end

-- Read a tier's live config with dynamic attribute overrides
function CoinConfig.GetTierConfig(tierName)
	local base = CoinConfig.Tiers[tierName]
	if not base then
		return nil
	end

	local folder = CoinConfig.GetSettingsInstance()
	local liveValue = folder:GetAttribute(tierName .. "_Value")
	local liveWeight = folder:GetAttribute(tierName .. "_Weight")

	local config = {}
	for k, v in pairs(base) do
		config[k] = v
	end

	if liveValue ~= nil then
		config.value = liveValue
	end
	if liveWeight ~= nil then
		config.weight = liveWeight
	end

	return config
end

-- Pick a random tier according to live weights
function CoinConfig.SelectRandomTier()
	local tiersList = {}
	local totalWeight = 0

	for tierName in pairs(CoinConfig.Tiers) do
		local tierConf = CoinConfig.GetTierConfig(tierName)
		local weight = math.max(0, tierConf.weight or 0)
		if weight > 0 then
			table.insert(tiersList, { name = tierName, config = tierConf, weight = weight })
			totalWeight += weight
		end
	end

	if totalWeight <= 0 or #tiersList == 0 then
		return CoinConfig.GetTierConfig("Standard")
	end

	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, item in ipairs(tiersList) do
		cumulative += item.weight
		if roll <= cumulative then
			return item.config
		end
	end

	return tiersList[#tiersList].config
end

return CoinConfig
