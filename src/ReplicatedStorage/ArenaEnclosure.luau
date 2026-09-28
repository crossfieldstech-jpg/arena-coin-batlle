local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ArenaEnclosure = {}
ArenaEnclosure.__index = ArenaEnclosure

function ArenaEnclosure.new(config)
	local self = setmetatable({}, ArenaEnclosure)

	self.sizeX = config.sizeX or 90
	self.sizeZ = config.sizeZ or 90
	self.wallHeight = config.wallHeight or 26
	self.wallThickness = config.wallThickness or 2
	self.gateWidth = config.gateWidth or 14
	self.gateHeight = config.gateHeight or 12
	self.center = config.center or Vector3.new(0, 0, 0)
	self.baseDistance = config.baseDistance or 140
	self.baseSize = config.baseSize or 84
	self.wallTransparency = config.wallTransparency or 0

	self.container = nil
	self.gatesInfo = {}
	self.interiorDisplayBoards = {}

	return self
end

function ArenaEnclosure:Build()
	if self.container and self.container.Parent then
		self.container:Destroy()
	end

	local container = Instance.new("Model")
	container.Name = "ArenaEnclosure"
	container.Parent = Workspace
	self.container = container
	self.gatesInfo = {}
	self.interiorDisplayBoards = {}
	self.wallParts = {}

	local halfX = self.sizeX / 2
	local halfZ = self.sizeZ / 2
	local halfH = self.wallHeight / 2
	local wt = self.wallThickness

	-- 1. Central Arena Interior Floor
	local floor = Instance.new("Part")
	floor.Name = "ArenaFloor"
	floor.Size = Vector3.new(self.sizeX, 1, self.sizeZ)
	floor.Position = self.center + Vector3.new(0, 0, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(45, 52, 54) -- Dark sleek slate
	floor.TopSurface = Enum.SurfaceType.Smooth
	floor.BottomSurface = Enum.SurfaceType.Smooth
	floor.Parent = container

	-- Invisible Ceiling Barrier Enclosure (fully seals arena top)
	local ceiling = Instance.new("Part")
	ceiling.Name = "ArenaCeiling"
	ceiling.Size = Vector3.new(self.sizeX + wt * 2, 2, self.sizeZ + wt * 2)
	ceiling.CFrame = CFrame.new(self.center + Vector3.new(0, self.wallHeight + 1, 0))
	ceiling.Anchored = true
	ceiling.CanCollide = true
	ceiling.CanTouch = false
	ceiling.CanQuery = false
	ceiling.CastShadow = false
	ceiling.Transparency = 1
	ceiling.Material = Enum.Material.ForceField
	ceiling.Color = Color3.fromRGB(255, 255, 255)
	ceiling.TopSurface = Enum.SurfaceType.Smooth
	ceiling.BottomSurface = Enum.SurfaceType.Smooth
	ceiling.Parent = container

	-- 2. Four Perimeter Walls with Centered Gate Entrances (North, South, East, West)
	local wallColor = Color3.fromRGB(30, 39, 46) -- Modern graphite
	local wallMaterial = Enum.Material.Concrete
	local pillarColor = Color3.fromRGB(15, 20, 25)

	local function makePart(name, size, cframe, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Anchored = true
		p.Color = color or wallColor
		p.Material = material or wallMaterial
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = container
		return p
	end

	local function setWallPart(p)
		p.Transparency = self.wallTransparency
		table.insert(self.wallParts, p)
		return p
	end

	local sideWidthX = (self.sizeX - self.gateWidth) / 2
	local sideOffsetX = (self.sizeX / 2) - (sideWidthX / 2)
	local lintelHeight = self.wallHeight - self.gateHeight
	local lintelY = self.gateHeight + (lintelHeight / 2)

	-- Wall builder helper for a wall facing a cardinal angle
	local function buildWallWithGate(directionName, angleY, offsetDist)
		local baseCF = CFrame.new(self.center) * CFrame.Angles(0, math.rad(angleY), 0)

		-- Left wall segment
		setWallPart(makePart(
			directionName .. "_WallLeft",
			Vector3.new(sideWidthX, self.wallHeight, wt),
			baseCF * CFrame.new(-sideOffsetX, halfH, offsetDist)
		))

		-- Right wall segment
		setWallPart(makePart(
			directionName .. "_WallRight",
			Vector3.new(sideWidthX, self.wallHeight, wt),
			baseCF * CFrame.new(sideOffsetX, halfH, offsetDist)
		))

		-- Lintel above doorway
		if lintelHeight > 0 then
			local _lintelPart = setWallPart(makePart(
				directionName .. "_Lintel",
				Vector3.new(self.gateWidth, lintelHeight, wt),
				baseCF * CFrame.new(0, lintelY, offsetDist)
			))

			-- Interior Wall Digital Countdown & Runner Display Board (facing inward toward 0,0,0)
			local boardThickness = 0.4
			local boardHeight = math.min(3.2, lintelHeight - 0.4)
			local boardWidth = self.gateWidth - 1.5
			local boardCF = baseCF * CFrame.new(0, lintelY, offsetDist - (wt / 2) - (boardThickness / 2) - 0.05)

			local displayBoard = Instance.new("Part")
			displayBoard.Name = directionName .. "_InteriorDisplayBoard"
			displayBoard.Size = Vector3.new(boardWidth, boardHeight, boardThickness)
			displayBoard.CFrame = boardCF
			displayBoard.Anchored = true
			displayBoard.Material = Enum.Material.Metal
			displayBoard.Color = Color3.fromRGB(15, 18, 22)
			displayBoard.TopSurface = Enum.SurfaceType.Smooth
			displayBoard.BottomSurface = Enum.SurfaceType.Smooth
			displayBoard.Parent = container

			-- Border frame glow
			local border = Instance.new("SelectionBox")
			border.Name = "BoardGlow"
			border.Adornee = displayBoard
			border.Color3 = Color3.fromRGB(230, 126, 34)
			border.LineThickness = 0.05
			border.Parent = displayBoard

			local surfaceGui = Instance.new("SurfaceGui")
			surfaceGui.Name = "InteriorDisplayGui"
			surfaceGui.Face = Enum.NormalId.Front
			surfaceGui.CanvasSize = Vector2.new(1000, 260)
			surfaceGui.LightInfluence = 0
			surfaceGui.AlwaysOnTop = false
			surfaceGui.Parent = displayBoard

			local frame = Instance.new("Frame")
			frame.Name = "MainFrame"
			frame.Size = UDim2.new(1, 0, 1, 0)
			frame.BackgroundColor3 = Color3.fromRGB(12, 15, 20)
			frame.BorderSizePixel = 0
			frame.Parent = surfaceGui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = frame

			local runnerText = Instance.new("TextLabel")
			runnerText.Name = "RunnerText"
			runnerText.Size = UDim2.new(1, -40, 0, 100)
			runnerText.Position = UDim2.new(0, 20, 0, 15)
			runnerText.BackgroundTransparency = 1
			runnerText.Font = Enum.Font.GothamBlack
			runnerText.Text = "★ ARENA STANDBY ★"
			runnerText.TextColor3 = Color3.fromRGB(46, 204, 113)
			runnerText.TextStrokeTransparency = 0
			runnerText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			runnerText.TextScaled = true
			runnerText.Parent = frame

			local timerText = Instance.new("TextLabel")
			timerText.Name = "TimerText"
			timerText.Size = UDim2.new(1, -40, 0, 120)
			timerText.Position = UDim2.new(0, 20, 0, 120)
			timerText.BackgroundTransparency = 1
			timerText.Font = Enum.Font.GothamBlack
			timerText.Text = "TIME: 45s"
			timerText.TextColor3 = Color3.fromRGB(255, 255, 255)
			timerText.TextStrokeTransparency = 0
			timerText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			timerText.TextScaled = true
			timerText.Parent = frame

			table.insert(self.interiorDisplayBoards, {
				board = displayBoard,
				glow = border,
				runnerLabel = runnerText,
				timerLabel = timerText,
				direction = directionName,
			})
		end

		-- Gate decorative pillars flanking doorway
		local _pillarLeft = setWallPart(makePart(
			directionName .. "_PillarLeft",
			Vector3.new(1.2, self.wallHeight + 1, wt + 1),
			baseCF * CFrame.new(-self.gateWidth / 2 - 0.6, (self.wallHeight + 1) / 2, offsetDist),
			pillarColor,
			Enum.Material.Metal
		))
		local _pillarRight = setWallPart(makePart(
			directionName .. "_PillarRight",
			Vector3.new(1.2, self.wallHeight + 1, wt + 1),
			baseCF * CFrame.new(self.gateWidth / 2 + 0.6, (self.wallHeight + 1) / 2, offsetDist),
			pillarColor,
			Enum.Material.Metal
		))

		-- Gate Doorway CFrame Information
		local closedY = self.center.Y + (self.gateHeight / 2)
		local openY = closedY + self.gateHeight + 1
		local gateSize = Vector3.new(self.gateWidth, self.gateHeight, wt * 0.8)

		local closedCF = baseCF * CFrame.new(0, closedY, offsetDist)
		local openCF = baseCF * CFrame.new(0, openY, offsetDist)

		table.insert(self.gatesInfo, {
			name = directionName .. "_Gate",
			direction = directionName,
			size = gateSize,
			closedCFrame = closedCF,
			openCFrame = openCF,
			center = closedCF.Position,
		})
	end

	-- Build 4 symmetric walls & gates:
	buildWallWithGate("South", 0, halfZ)        -- South (+Z)
	buildWallWithGate("North", 180, halfZ)      -- North (-Z)
	buildWallWithGate("East", 90, halfX)        -- East (+X)
	buildWallWithGate("West", -90, halfX)       -- West (-X)

	-- 3. Highways connecting Central Arena Gates to the 4 Player Bases
	local baseFront = self.baseDistance - (self.baseSize / 2)
	local roadEnd = baseFront + 2 -- slight overlap with base entrance
	local highwayLength = math.max(10, roadEnd - halfZ)
	local highwayCenterDist = halfZ + (highwayLength / 2)
	local roadWidth = 16

	-- South highway
	makePart("Road_South", Vector3.new(roadWidth, 1, highwayLength), CFrame.new(0, 0, highwayCenterDist), Color3.fromRGB(64, 70, 78), Enum.Material.SmoothPlastic)
	-- North highway
	makePart("Road_North", Vector3.new(roadWidth, 1, highwayLength), CFrame.new(0, 0, -highwayCenterDist), Color3.fromRGB(64, 70, 78), Enum.Material.SmoothPlastic)
	-- East highway
	makePart("Road_East", Vector3.new(highwayLength, 1, roadWidth), CFrame.new(highwayCenterDist, 0, 0), Color3.fromRGB(64, 70, 78), Enum.Material.SmoothPlastic)
	-- West highway
	makePart("Road_West", Vector3.new(highwayLength, 1, roadWidth), CFrame.new(-highwayCenterDist, 0, 0), Color3.fromRGB(64, 70, 78), Enum.Material.SmoothPlastic)

	self:UpdateDisplayBoards("", 0, false)

	return self
end

function ArenaEnclosure:GetGatesInfo()
	return self.gatesInfo
end

-- Updates all interior wall digital boards with active runner name and time remaining
function ArenaEnclosure:UpdateDisplayBoards(activeRunnerName, timeRemaining, isRunning, isGemRound)
	local isUrgent = isRunning and (timeRemaining and timeRemaining <= 10)
	local bannerText
	if isRunning then
		if isGemRound then
			bannerText = string.format("RUNNER: %s [💎 GEM ROUND 💎]", string.upper(activeRunnerName or "PLAYER"))
		else
			bannerText = string.format("RUNNER: %s", string.upper(activeRunnerName or "PLAYER"))
		end
	else
		if isGemRound then
			bannerText = "★ 💎 GEM JACKPOT ROUND READY 💎 ★"
		else
			bannerText = "★ ARENA STANDBY ★"
		end
	end
	local timeStr = isRunning and string.format("⏱ %02d SECONDS", math.max(0, timeRemaining or 0)) or "READY TO ACTIVATE"

	local runnerColor = isRunning and Color3.fromRGB(241, 196, 15) or Color3.fromRGB(46, 204, 113)
	if isGemRound and not isUrgent then
		runnerColor = Color3.fromRGB(80, 220, 255)
	end
	local timerColor = isUrgent and Color3.fromRGB(231, 76, 60) or (isRunning and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 205))
	local glowColor = isUrgent and Color3.fromRGB(231, 76, 60) or (isRunning and Color3.fromRGB(230, 126, 34) or Color3.fromRGB(46, 204, 113))
	if isGemRound and not isUrgent then
		glowColor = Color3.fromRGB(0, 200, 255)
	end

	for _, boardInfo in ipairs(self.interiorDisplayBoards) do
		if boardInfo.runnerLabel then
			boardInfo.runnerLabel.Text = bannerText
			boardInfo.runnerLabel.TextColor3 = runnerColor
		end
		if boardInfo.timerLabel then
			boardInfo.timerLabel.Text = timeStr
			boardInfo.timerLabel.TextColor3 = timerColor
		end
		if boardInfo.glow then
			boardInfo.glow.Color3 = glowColor
		end
	end
end

function ArenaEnclosure:IsInside(position)
	local halfX = self.sizeX / 2
	local halfZ = self.sizeZ / 2
	local localPos = position - self.center

	return (math.abs(localPos.X) <= halfX) and (math.abs(localPos.Z) <= halfZ) and (localPos.Y >= -2 and localPos.Y < self.wallHeight)
end

function ArenaEnclosure:GetPlayersInside(ignorePlayer)
	local insidePlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= ignorePlayer then
			local character = player.Character
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root and self:IsInside(root.Position) then
					table.insert(insidePlayers, player)
				end
			end
		end
	end
	return insidePlayers
end

-- Ejects players inside the arena to their home bases or nearest gate exterior approach
function ArenaEnclosure:EjectPlayers(getPlayerTargetCFrameFn, ignorePlayer)
	local ejected = {}

	for _, player in ipairs(self:GetPlayersInside(ignorePlayer)) do
		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local target = getPlayerTargetCFrameFn and getPlayerTargetCFrameFn(player)
				local targetCFrame = nil

				if typeof(target) == "CFrame" then
					targetCFrame = target
				elseif typeof(target) == "Vector3" then
					targetCFrame = CFrame.new(target + Vector3.new(0, 3, 0))
				end

				if not targetCFrame then
					local nearestGate = nil
					local nearestDist = math.huge
					for _, gateInfo in ipairs(self.gatesInfo) do
						local dist = (gateInfo.closedCFrame.Position - root.Position).Magnitude
						if dist < nearestDist then
							nearestDist = dist
							nearestGate = gateInfo
						end
					end

					if nearestGate then
						targetCFrame = nearestGate.closedCFrame * CFrame.new(math.random(-2, 2), 2, 16)
					else
						targetCFrame = CFrame.new(self.center + Vector3.new(0, 3, self.sizeZ / 2 + 16))
					end
				end

				root.CFrame = targetCFrame
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero

				table.insert(ejected, {
					player = player,
					targetCFrame = targetCFrame,
				})
			end
		end
	end

	return ejected
end

-- Updates the transparency of all tracked arena wall parts at runtime
-- Call this from events or scripts to dynamically change wall visibility
function ArenaEnclosure:SetWallTransparency(transparency)
	self.wallTransparency = transparency
	for _, part in ipairs(self.wallParts) do
		if part and part.Parent then
			part.Transparency = transparency
		end
	end
end

function ArenaEnclosure:Destroy()
	if self.container then
		self.container:Destroy()
		self.container = nil
	end
	self.gatesInfo = {}
end

return ArenaEnclosure
