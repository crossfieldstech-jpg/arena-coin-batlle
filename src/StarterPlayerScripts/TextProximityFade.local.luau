local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Fade parameters (in studs)
local FADE_NEAR = 25  -- Fully visible within this distance
local FADE_FAR = 40   -- Fully invisible beyond this distance

-- Tracked guis: { [gui] = { adornee = BasePart, labels = { {label, origTextTrans, origStrokeTrans, origBgTrans} } } }
local tracked = {}

-- Guis exempt from proximity fade (always visible)
local EXEMPT_GUI_NAMES = {
	["InteriorDisplayGui"] = true, -- Arena wall display boards
}

local function isExempt(gui)
	return EXEMPT_GUI_NAMES[gui.Name] == true
end

local function trackGui(gui)
	if tracked[gui] then return end
	if isExempt(gui) then return end

	local adornee = gui.Adornee or gui.Parent
	if not (adornee and adornee:IsA("BasePart")) then return end

	local labels = {}
	for _, desc in ipairs(gui:GetDescendants()) do
		if desc:IsA("TextLabel") then
			table.insert(labels, {
				label = desc,
				origTextTrans = desc.TextTransparency,
				origStrokeTrans = desc.TextStrokeTransparency,
				origBgTrans = desc.BackgroundTransparency,
			})
		end
	end

	tracked[gui] = { adornee = adornee, labels = labels }
end

local function refreshTracked()
	-- Remove stale entries
	for gui in pairs(tracked) do
		if not gui.Parent then
			tracked[gui] = nil
		end
	end

	-- Scan for new BillboardGuis and SurfaceGuis in workspace
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
			trackGui(desc)
		end
	end
end

task.spawn(function()
	while true do
		refreshTracked()
		task.wait(2)
	end
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local playerPos = root.Position

	for gui, data in pairs(tracked) do
		if not gui.Parent or not data.adornee.Parent then
			tracked[gui] = nil
			continue
		end

		local dist = (data.adornee.Position - playerPos).Magnitude

		local alpha
		if dist <= FADE_NEAR then
			alpha = 1
		elseif dist >= FADE_FAR then
			alpha = 0
		else
			alpha = 1 - (dist - FADE_NEAR) / (FADE_FAR - FADE_NEAR)
		end

		for _, ld in ipairs(data.labels) do
			local label = ld.label
			if label and label.Parent then
				label.TextTransparency = 1 - alpha * (1 - ld.origTextTrans)
				label.TextStrokeTransparency = 1 - alpha * (1 - ld.origStrokeTrans)
				label.BackgroundTransparency = 1 - alpha * (1 - ld.origBgTrans)
			end
		end
	end
end)