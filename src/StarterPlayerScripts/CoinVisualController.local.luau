local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local coinFolder = Workspace:WaitForChild("Coins", 10)

-- Cache of original stationary base positions for each coin
local basePositions = {}

local function registerCoin(coin)
	if not coin:IsA("BasePart") then
		return
	end

	-- Retrieve saved attribute or take current position as base
	local attrPos = coin:GetAttribute("BasePosition")
	if attrPos then
		basePositions[coin] = attrPos
	else
		basePositions[coin] = coin.Position
	end
end

if coinFolder then
	for _, coin in ipairs(coinFolder:GetChildren()) do
		registerCoin(coin)
	end

	coinFolder.ChildAdded:Connect(function(child)
		task.defer(function()
			registerCoin(child)
		end)
	end)

	coinFolder.ChildRemoved:Connect(function(child)
		basePositions[child] = nil
	end)
end

-- Render loop: smooth spinning and gentle vertical bobbing on the client
-- Spin rate: ~100 degrees per second (1.75 rad/s)
-- Bob frequency: ~2.4 rad/s, amplitude: 0.25 studs
local SPIN_SPEED = 1.75
local BOB_SPEED = 2.4
local BOB_AMPLITUDE = 0.25

RunService.RenderStepped:Connect(function()
	if not coinFolder then
		return
	end

	local t = os.clock()
	local spinAngle = (t * SPIN_SPEED) % (math.pi * 2)

	for _, coin in ipairs(coinFolder:GetChildren()) do
		if coin:IsA("BasePart") and coin.Parent then
			local basePos = basePositions[coin]
			if not basePos then
				local attrPos = coin:GetAttribute("BasePosition")
				basePos = attrPos or coin.Position
				basePositions[coin] = basePos
			end

			-- Spatial phase offset so coins don't all bob in lockstep
			local phase = (basePos.X * 0.4) + (basePos.Z * 0.4)
			local bobY = math.sin((t * BOB_SPEED) + phase) * BOB_AMPLITUDE

			-- In Roblox cylinder parts, the circular faces are along the X axis.
			-- CFrame.Angles(0, theta, 0) keeps the cylinder axis horizontal and spins it upright around the Y axis.
			coin.CFrame = CFrame.new(basePos.X, basePos.Y + bobY, basePos.Z) * CFrame.Angles(0, spinAngle, 0)
		end
	end
end)