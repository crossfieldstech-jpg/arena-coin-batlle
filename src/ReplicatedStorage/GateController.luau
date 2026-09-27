local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GateController = {}
GateController.__index = GateController

-- State definitions
GateController.State = {
	Open = "Open",
	Closed = "Closed",
	Opening = "Opening",
	Closing = "Closing",
}

-- Accepts either a single gateInfo table or an array of gateInfo tables
function GateController.new(gatesData, moveDuration)
	local self = setmetatable({}, GateController)

	if gatesData.closedCFrame then
		self.gatesList = { gatesData }
	else
		self.gatesList = gatesData
	end

	self.moveDuration = moveDuration or 1.2
	self.state = GateController.State.Closed

	self.model = nil
	self.doors = {} -- list of { doorPart, accentPart, indicatorPart, light, info, state }
	self._listeners = {}

	self:_build()
	return self
end

function GateController:_build()
	local model = Instance.new("Model")
	model.Name = "ArenaGates"
	model.Parent = Workspace
	self.model = model

	self.doors = {}

	for i, info in ipairs(self.gatesList) do
		local gateName = info.name or string.format("Gate_%d", i)

		-- Main sliding door slab
		local door = Instance.new("Part")
		door.Name = gateName .. "_Door"
		door.Size = info.size
		door.CFrame = info.closedCFrame
		door.Anchored = true
		door.CanCollide = true
		door.Material = Enum.Material.DiamondPlate
		door.Color = Color3.fromRGB(50, 55, 65)
		door.TopSurface = Enum.SurfaceType.Smooth
		door.BottomSurface = Enum.SurfaceType.Smooth
		door.Parent = model

		-- Neon accent bar on door
		local bar = Instance.new("Part")
		bar.Name = gateName .. "_Accent"
		bar.Size = Vector3.new(info.size.X * 0.9, 0.4, info.size.Z * 1.1)
		bar.CFrame = info.closedCFrame
		bar.Anchored = true
		bar.CanCollide = false
		bar.Material = Enum.Material.SmoothPlastic
		bar.Color = Color3.fromRGB(90, 30, 25)
		bar.Parent = model

		-- Status indicator above gate opening
		local indicator = Instance.new("Part")
		indicator.Name = gateName .. "_Indicator"
		indicator.Size = Vector3.new(info.size.X * 0.6, 0.8, 0.8)
		indicator.CFrame = info.closedCFrame * CFrame.new(0, (info.size.Y / 2) + 0.6, 0)
		indicator.Anchored = true
		indicator.CanCollide = false
		indicator.Material = Enum.Material.SmoothPlastic
		indicator.Color = Color3.fromRGB(90, 30, 25)
		indicator.Parent = model

		-- Entrance sensor zone for verifying player ownership and preventing unauthorized entry
		local sensor = Instance.new("Part")
		sensor.Name = gateName .. "_Sensor"
		sensor.Size = Vector3.new(info.size.X, info.size.Y, 4)
		sensor.CFrame = info.closedCFrame * CFrame.new(0, 0, 3)
		sensor.Anchored = true
		sensor.CanCollide = false
		sensor.Transparency = 1
		sensor.Parent = model

		local pointLight = Instance.new("PointLight")
		pointLight.Name = "StatusLight"
		pointLight.Color = Color3.fromRGB(231, 76, 60)
		pointLight.Range = 14
		pointLight.Brightness = 0.5
		pointLight.Parent = indicator

		table.insert(self.doors, {
			name = gateName,
			direction = info.direction,
			doorPart = door,
			accentPart = bar,
			indicatorPart = indicator,
			sensorPart = sensor,
			light = pointLight,
			info = info,
			state = GateController.State.Closed,
		})
	end

	self:_applyVisualState(GateController.State.Closed)
end

function GateController:_applyVisualState(state, specificItem)
	local color = Color3.fromRGB(22, 100, 55) -- Muted green for Open
	if state == GateController.State.Closed then
		color = Color3.fromRGB(90, 30, 25) -- Muted red for Locked
	elseif state == GateController.State.Opening or state == GateController.State.Closing then
		color = Color3.fromRGB(95, 76, 15) -- Muted yellow while transitioning
	end

	local targetList = specificItem and { specificItem } or self.doors
	for _, item in ipairs(targetList) do
		if item.indicatorPart then
			item.indicatorPart.Color = color
		end
		if item.light then
			item.light.Color = color
		end
		if item.accentPart then
			item.accentPart.Color = color
		end
	end
end

function GateController:_setState(newState)
	local oldState = self.state
	self.state = newState
	self:_applyVisualState(newState)

	for _, callback in ipairs(self._listeners) do
		task.spawn(callback, newState, oldState)
	end
end

function GateController:OnStateChanged(callback)
	table.insert(self._listeners, callback)
end

function GateController:GetState()
	return self.state
end

function GateController:IsOpen()
	return self.state == GateController.State.Open
end

function GateController:IsClosed()
	return self.state == GateController.State.Closed
end

function GateController:GetGateByDirection(direction)
	for _, item in ipairs(self.doors) do
		if string.lower(item.direction) == string.lower(direction) then
			return item
		end
	end
	return nil
end

-- Close all gates together
function GateController:Close(onComplete)
	local tweenInfo = TweenInfo.new(self.moveDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self:_setState(GateController.State.Closing)

	local doorsToClose = {}
	for _, item in ipairs(self.doors) do
		local isAlreadyClosed = (item.state == GateController.State.Closed)
			and (item.doorPart.Position - item.info.closedCFrame.Position).Magnitude < 0.2
		if not isAlreadyClosed then
			table.insert(doorsToClose, item)
		else
			item.doorPart.CanCollide = true
			item.doorPart.CFrame = item.info.closedCFrame
			item.accentPart.CFrame = item.info.closedCFrame
			item.state = GateController.State.Closed
			self:_applyVisualState(GateController.State.Closed, item)
		end
	end

	local finished = false
	local function finishClose()
		if finished then
			return
		end
		finished = true

		for _, item in ipairs(self.doors) do
			item.doorPart.CanCollide = true
			item.doorPart.CFrame = item.info.closedCFrame
			item.accentPart.CFrame = item.info.closedCFrame
			item.state = GateController.State.Closed
			self:_applyVisualState(GateController.State.Closed, item)
		end

		self.state = GateController.State.Closed
		for _, callback in ipairs(self._listeners) do
			task.spawn(callback, GateController.State.Closed, GateController.State.Closing)
		end
		if onComplete then
			onComplete()
		end
	end

	if #doorsToClose == 0 then
		finishClose()
		return
	end

	local remaining = #doorsToClose
	for _, item in ipairs(doorsToClose) do
		item.state = GateController.State.Closing
		self:_applyVisualState(GateController.State.Closing, item)

		local doorTween = TweenService:Create(item.doorPart, tweenInfo, { CFrame = item.info.closedCFrame })
		local accentTween = TweenService:Create(item.accentPart, tweenInfo, { CFrame = item.info.closedCFrame })

		accentTween:Play()
		doorTween:Play()

		doorTween.Completed:Connect(function()
			remaining -= 1
			if remaining <= 0 then
				finishClose()
			end
		end)
	end

	-- Safety net timeout to guarantee callback executes even if engine drops tween completion
	task.delay(self.moveDuration + 0.15, finishClose)
end

-- Open ONLY the specific gate in the specified cardinal direction; keep all other gates closed
function GateController:OpenSingleGate(direction, onComplete)
	local targetGate = self:GetGateByDirection(direction)
	if not targetGate then
		warn("[GateController] Gate not found for direction:", direction)
		if onComplete then
			onComplete()
		end
		return
	end

	local tweenInfo = TweenInfo.new(self.moveDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Ensure all other gates are firmly closed
	for _, item in ipairs(self.doors) do
		if item ~= targetGate then
			item.doorPart.CanCollide = true
			item.doorPart.CFrame = item.info.closedCFrame
			item.accentPart.CFrame = item.info.closedCFrame
			item.state = GateController.State.Closed
			self:_applyVisualState(GateController.State.Closed, item)
		end
	end

	targetGate.state = GateController.State.Opening
	self:_applyVisualState(GateController.State.Opening, targetGate)

	local doorTween = TweenService:Create(targetGate.doorPart, tweenInfo, { CFrame = targetGate.info.openCFrame })
	local accentTween = TweenService:Create(targetGate.accentPart, tweenInfo, { CFrame = targetGate.info.openCFrame })

	accentTween:Play()
	doorTween:Play()

	local finished = false
	local function finishOpen()
		if finished then
			return
		end
		finished = true

		targetGate.doorPart.CanCollide = false
		targetGate.doorPart.CFrame = targetGate.info.openCFrame
		targetGate.accentPart.CFrame = targetGate.info.openCFrame
		targetGate.state = GateController.State.Open
		self:_applyVisualState(GateController.State.Open, targetGate)
		self.state = GateController.State.Open

		for _, callback in ipairs(self._listeners) do
			task.spawn(callback, GateController.State.Open, GateController.State.Opening)
		end
		if onComplete then
			onComplete()
		end
	end

	doorTween.Completed:Connect(finishOpen)
	task.delay(self.moveDuration + 0.15, finishOpen)
end

-- Legacy support for opening all gates if needed
function GateController:Open(onComplete)
	if self.state == GateController.State.Open or self.state == GateController.State.Opening then
		if onComplete then
			onComplete()
		end
		return
	end

	self:_setState(GateController.State.Opening)

	local tweenInfo = TweenInfo.new(self.moveDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local completedCount = 0
	local totalDoors = #self.doors

	for _, item in ipairs(self.doors) do
		item.state = GateController.State.Opening
		self:_applyVisualState(GateController.State.Opening, item)

		local doorTween = TweenService:Create(item.doorPart, tweenInfo, { CFrame = item.info.openCFrame })
		local accentTween = TweenService:Create(item.accentPart, tweenInfo, { CFrame = item.info.openCFrame })

		accentTween:Play()
		doorTween:Play()

		doorTween.Completed:Connect(function()
			item.doorPart.CanCollide = false
			item.state = GateController.State.Open
			self:_applyVisualState(GateController.State.Open, item)
			completedCount += 1
			if completedCount >= totalDoors then
				self:_setState(GateController.State.Open)
				if onComplete then
					onComplete()
				end
			end
		end)
	end
end

-- Binds a touch verification listener to all gate sensors
function GateController:BindGateSensors(callback)
	for _, item in ipairs(self.doors) do
		if item.sensorPart then
			item.sensorPart.Touched:Connect(function(hit)
				callback(hit, item)
			end)
		end
	end
end

function GateController:Destroy()
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	self.doors = {}
	self._listeners = {}
end

return GateController
