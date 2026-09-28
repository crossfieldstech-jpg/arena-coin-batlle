local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local coinFolder = Workspace:WaitForChild("Coins", 10)

-- Cache of original stationary base positions for each gem
local basePositions = {}

local function isGem(part)
	if not part:IsA("BasePart") then
		return false
	end
	return part.Name == "Gem" or CollectionService:HasTag(part, "Gem")
end

local function registerGem(gem)
	if not isGem(gem) then
		return
	end

	local attrPos = gem:GetAttribute("BasePosition")
	if attrPos then
		basePositions[gem] = attrPos
	else
		basePositions[gem] = gem.Position
	end
end

if coinFolder then
	for _, gem in ipairs(coinFolder:GetChildren()) do
		registerGem(gem)
	end

	coinFolder.ChildAdded:Connect(function(child)
		task.defer(function()
			registerGem(child)
		end)
	end)

	coinFolder.ChildRemoved:Connect(function(child)
		basePositions[child] = nil
	end)
end

-- Render loop: multi-axis 3D tumbling rotation and floating bobbing
local TUMBLE_SPEED_Y = 1.8
local TUMBLE_SPEED_X = 1.1
local TUMBLE_SPEED_Z = 0.9
local BOB_SPEED = 2.2
local BOB_AMPLITUDE = 0.35

RunService.RenderStepped:Connect(function()
	if not coinFolder then
		return
	end

	local t = os.clock()
	local yaw = (t * TUMBLE_SPEED_Y) % (math.pi * 2)
	local pitch = (t * TUMBLE_SPEED_X) % (math.pi * 2)
	local roll = (t * TUMBLE_SPEED_Z) % (math.pi * 2)

	for _, gem in ipairs(coinFolder:GetChildren()) do
		if isGem(gem) and gem.Parent then
			local basePos = basePositions[gem]
			if not basePos then
				local attrPos = gem:GetAttribute("BasePosition")
				basePos = attrPos or gem.Position
				basePositions[gem] = basePos
			end

			local phase = (basePos.X * 0.4) + (basePos.Z * 0.4)
			local bobY = math.sin((t * BOB_SPEED) + phase) * BOB_AMPLITUDE

			gem.CFrame = CFrame.new(basePos.X, basePos.Y + bobY, basePos.Z) * CFrame.Angles(pitch, yaw, roll)
		end
	end
end)