local Players = game:GetService("Players")

local Coin = {}
Coin.__index = Coin

-- Default coin configuration
local DEFAULT_CONFIG = {
	shape = Enum.PartType.Cylinder,
	size = Vector3.new(0.3, 2.5, 2.5), -- Size.X = thickness, Size.Y/Z = diameter
	value = 1,
	color = Color3.fromRGB(255, 215, 0),
	material = Enum.Material.Neon,
	respawnDelay = 3,
	hasLight = true,
	lightColor = Color3.fromRGB(255, 220, 50),
	lightRange = 7,
	lightBrightness = 1.2,
}

function Coin.new(position, customConfig)
	local self = setmetatable({}, Coin)

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
	part.Name = "Coin"
	part.Shape = config.shape
	part.Size = config.size
	part.Material = config.material
	part.Color = config.color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Anchored = true
	part.CanCollide = false
	-- Roblox cylinder parts orient their circular faces along the X-axis.
	-- Rotating 90 degrees around the Z axis stands the cylinder upright like a coin standing on edge.
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(math.random(0, 360)), math.rad(90))

	-- Store coin value as an attribute on the instance for easy inspection
	part:SetAttribute("Value", config.value)

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

function Coin:SetParent(parent)
	self.part.Parent = parent
	return self
end

function Coin:GetPart()
	return self.part
end

function Coin:GetValue()
	return self.config.value
end

function Coin:SetValue(newValue)
	self.config.value = newValue
	if self.part and self.part.Parent then
		self.part:SetAttribute("Value", newValue)
	end
end

function Coin:SetShape(newShape, newSize)
	self.config.shape = newShape
	self.part.Shape = newShape
	if newSize then
		self.config.size = newSize
		self.part.Size = newSize
	end
end

function Coin:BindCollection(onCollectCallback)
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

function Coin:Destroy()
	if self._touchedConnection then
		self._touchedConnection:Disconnect()
		self._touchedConnection = nil
	end
	if self.part then
		self.part:Destroy()
		self.part = nil
	end
end

return Coin
