local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local Gem = {}
Gem.__index = Gem

local DEFAULT_CONFIG = {
	shape = Enum.PartType.Block,
	size = Vector3.new(1.8, 1.8, 1.8),
	value = 2.0,
	color = Color3.fromRGB(46, 204, 113),
	material = Enum.Material.Neon,
	reflectance = 0.4,
	respawnDelay = 2,
	hasLight = true,
	lightColor = Color3.fromRGB(80, 225, 140),
	lightRange = 4.0,
	lightBrightness = 0.4,
}

function Gem.new(position, customConfig)
	local self = setmetatable({}, Gem)

	local config = {}
	for k, v in pairs(DEFAULT_CONFIG) do
		config[k] = v
	end
	if customConfig then
		for k, v in pairs(customConfig) do
			config[k] = v
		end
	end
	self.config = config

	-- Create visual Part
	local part = Instance.new("Part")
	part.Name = "Gem"
	part.Shape = config.shape
	part.Size = config.size
	part.Material = config.material
	part.Reflectance = config.reflectance or 0.4
	part.Color = config.color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(position) * CFrame.Angles(math.rad(45), math.rad(math.random(0, 360)), math.rad(45))

	CollectionService:AddTag(part, "Gem")

	part:SetAttribute("Value", config.value)
	part:SetAttribute("BasePosition", position)
	part:SetAttribute("ItemType", "Gem")
	if config.name then
		part:SetAttribute("TierName", config.name)
	end

	if config.hasLight then
		local light = Instance.new("PointLight")
		light.Color = config.lightColor
		light.Range = config.lightRange
		light.Brightness = config.lightBrightness
		light.Parent = part
	end

	self.part = part
	self._touchedConnection = nil
	self._collected = false

	return self
end

function Gem:SetParent(parent)
	self.part.Parent = parent
	return self
end

function Gem:GetPart()
	return self.part
end

function Gem:GetValue()
	return self.config.value
end

function Gem:SetValue(newValue)
	self.config.value = newValue
	if self.part and self.part.Parent then
		self.part:SetAttribute("Value", newValue)
	end
end

function Gem:BindCollection(onCollectCallback)
	if self._touchedConnection then
		self._touchedConnection:Disconnect()
		self._touchedConnection = nil
	end

	self._touchedConnection = self.part.Touched:Connect(function(hit)
		if self._collected or self.part.Parent == nil then
			return
		end

		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end

		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end

		self._collected = true
		if self._touchedConnection then
			self._touchedConnection:Disconnect()
			self._touchedConnection = nil
		end

		if onCollectCallback then
			onCollectCallback(player, self)
		end

		self:Destroy()
	end)
end

function Gem:Destroy()
	if self._touchedConnection then
		self._touchedConnection:Disconnect()
		self._touchedConnection = nil
	end
	if self.part then
		self.part:Destroy()
		self.part = nil
	end
end

return Gem