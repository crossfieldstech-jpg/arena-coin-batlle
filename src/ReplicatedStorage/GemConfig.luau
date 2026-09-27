local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemConfig = {}

-- Base default settings
GemConfig.Defaults = {
	Enabled = true,          -- Toggle gem spawning in arena
	SpawnRate = 0.2,         -- 1 in 5 items spawn as gems (20% rate)
	ValueMultiplier = 1.2,   -- 1.2x value scale baseline
	RespawnDelay = 2,        -- Delay in seconds for trickle respawn
}

-- Default gem tiers definitions (Emerald, Sapphire, Ruby)
GemConfig.Tiers = {
	Standard = {
		name = "Emerald",
		shape = Enum.PartType.Block,
		size = Vector3.new(1.8, 1.8, 1.8),
		value = 1.2,
		weight = 60,
		color = Color3.fromRGB(46, 204, 113), -- Vivid Emerald Green
		material = Enum.Material.Neon,
		reflectance = 0.4,
		lightColor = Color3.fromRGB(80, 225, 140),
		lightRange = 4.0,
		lightBrightness = 0.4,
	},
	Silver = {
		name = "Sapphire",
		shape = Enum.PartType.Block,
		size = Vector3.new(2.0, 2.0, 2.0),
		value = 3.6,
		weight = 30,
		color = Color3.fromRGB(52, 152, 219), -- Sparkling Sapphire Blue
		material = Enum.Material.Neon,
		reflectance = 0.5,
		lightColor = Color3.fromRGB(100, 190, 255),
		lightRange = 4.5,
		lightBrightness = 0.45,
	},
	Mega = {
		name = "Ruby",
		shape = Enum.PartType.Block,
		size = Vector3.new(2.5, 2.5, 2.5),
		value = 12.0,
		weight = 10,
		color = Color3.fromRGB(231, 76, 60), -- Radiant Ruby Red
		material = Enum.Material.Neon,
		reflectance = 0.6,
		lightColor = Color3.fromRGB(255, 110, 100),
		lightRange = 5.0,
		lightBrightness = 0.5,
	},
}

local settingsFolder = nil

-- Creates or retrieves the Configuration instance in ReplicatedStorage
function GemConfig.GetSettingsInstance()
	if settingsFolder and settingsFolder.Parent then
		return settingsFolder
	end

	settingsFolder = ReplicatedStorage:FindFirstChild("GemSettings")
	if not settingsFolder then
		settingsFolder = Instance.new("Configuration")
		settingsFolder.Name = "GemSettings"
		settingsFolder.Parent = ReplicatedStorage
	end

	-- Initialize attributes with defaults if not already set
	for key, value in pairs(GemConfig.Defaults) do
		if settingsFolder:GetAttribute(key) == nil then
			settingsFolder:SetAttribute(key, value)
		end
	end

	-- Initialize per-tier Value and Weight attributes
	for tierName, tierData in pairs(GemConfig.Tiers) do
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
function GemConfig.GetSetting(key)
	local folder = GemConfig.GetSettingsInstance()
	local val = folder:GetAttribute(key)
	if val ~= nil then
		return val
	end
	return GemConfig.Defaults[key]
end

-- Read a tier's live config with dynamic attribute overrides
function GemConfig.GetTierConfig(tierName)
	local base = GemConfig.Tiers[tierName]
	if not base then
		return nil
	end

	local folder = GemConfig.GetSettingsInstance()
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
function GemConfig.SelectRandomTier()
	local tiersList = {}
	local totalWeight = 0

	for tierName in pairs(GemConfig.Tiers) do
		local tierConf = GemConfig.GetTierConfig(tierName)
		local weight = math.max(0, tierConf.weight or 0)
		if weight > 0 then
			table.insert(tiersList, { name = tierName, config = tierConf, weight = weight })
			totalWeight += weight
		end
	end

	if totalWeight <= 0 or #tiersList == 0 then
		return GemConfig.GetTierConfig("Standard")
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

return GemConfig
