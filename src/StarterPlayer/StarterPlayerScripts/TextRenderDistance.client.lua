-- TextRenderDistance: Hides world-space GUIs (BillboardGui/SurfaceGui) when the player is too far to read them.
-- This prevents all the floating text from being jumbled together at long distances.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Configuration: distance thresholds (in studs) at which text becomes visible
local BILLBOARD_DISTANCE = 55      -- BillboardGuis (smaller floating labels)
local SURFACEGUI_DISTANCE = 85    -- SurfaceGuis (large arena display boards, readable from further)
local HYSTERESIS = 8               -- Extra distance buffer before hiding (prevents flickering at the threshold)

local player = Players.LocalPlayer

-- Track which GUIs are currently visible to avoid redundant Enabled toggling
local guiState = {}  -- [gui] = true (visible) / false (hidden)

-- Collect all BillboardGui and SurfaceGui instances to manage
local trackedGuis = {}

local function shouldTrack(gui)
	return gui:IsA("BillboardGui") or gui:IsA("SurfaceGui")
end

local function getGuiAdorneeOrParent(gui)
	local adornee = gui.Adornee
	if adornee then
		return adornee
	end
	return gui.Parent
end

local function getGuiPosition(gui)
	local target = getGuiAdorneeOrParent(gui)
	if not target then
		return nil
	end
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		return target:GetPivot().Position
	elseif target:IsA("Attachment") then
		return target.WorldPosition
	end
	return nil
end

local function addGui(gui)
	if not shouldTrack(gui) then return end
	if trackedGuis[gui] then return end
	-- Skip GUIs parented to PlayerGui or Backpack (screen-space UI, not world-space)
	local ancestor = gui.Parent
	while ancestor and ancestor ~= game do
		if ancestor:IsA("PlayerGui") or ancestor:IsA("Backpack") then
			return
		end
		ancestor = ancestor.Parent
	end
	trackedGuis[gui] = true
	guiState[gui] = true  -- Default to visible until first distance check
end

local function removeGui(gui)
	trackedGuis[gui] = nil
	guiState[gui] = nil
end

-- Scan existing GUIs in Workspace
for _, descendant in ipairs(Workspace:GetDescendants()) do
	addGui(descendant)
end

-- Track newly added GUIs (arena and bases are procedurally generated at runtime)
Workspace.DescendantAdded:Connect(function(descendant)
	addGui(descendant)
end)

Workspace.DescendantRemoving:Connect(function(descendant)
	if shouldTrack(descendant) then
		removeGui(descendant)
	end
end)

-- Main loop: check distances and toggle visibility
local checkInterval = 0
local CHECK_RATE = 0.2  -- Check every 0.2 seconds (5 times per second)

RunService.RenderStepped:Connect(function(dt)
	checkInterval += dt
	if checkInterval < CHECK_RATE then
		return
	end
	checkInterval = 0

	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local playerPos = rootPart.Position

	for gui in pairs(trackedGuis) do
		if not gui.Parent then
			-- GUI was destroyed/removed, clean up
			removeGui(gui)
			continue
		end

		local guiPos = getGuiPosition(gui)
		if not guiPos then
			continue
		end

		local distance = (guiPos - playerPos).Magnitude
		local maxDistance = gui:IsA("SurfaceGui") and SURFACEGUI_DISTANCE or BILLBOARD_DISTANCE
		local wasVisible = guiState[gui]

		-- Use hysteresis: need to be closer to show, farther to hide (prevents flicker)
		if wasVisible then
			-- Currently visible: only hide if beyond maxDistance + hysteresis
			if distance > maxDistance + HYSTERESIS then
				gui.Enabled = false
				guiState[gui] = false
			end
		else
			-- Currently hidden: only show if within maxDistance
			if distance <= maxDistance then
				gui.Enabled = true
				guiState[gui] = true
			end
		end
	end
end)