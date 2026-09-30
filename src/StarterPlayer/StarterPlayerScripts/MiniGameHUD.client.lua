--[[
	MiniGameHUD.client.lua
	Client interface for the Sky Sub-Arena mini-games subsystem.
	Provides:
	1. Missions Selection Modal (cards, rewards, arena buffs, launch buttons).
	2. Active In-Mission HUD (timer, objective tracker, return button).
	3. Mission Results Modal (rewards breakdown, rare relic/fragment drops, buff activation).
	4. Active Next-Run Buff HUD Pill.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MiniGameRegistry = require(ReplicatedStorage:WaitForChild("MiniGames"):WaitForChild("MiniGameRegistry"))
local MiniGameEventBus = require(ReplicatedStorage:WaitForChild("MiniGames"):WaitForChild("MiniGameEventBus"))

-- ScreenGui Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MiniGameGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 15
screenGui.Parent = playerGui

-- =========================================================================
-- 1. Missions Selection Modal
-- =========================================================================
local menuContainer = Instance.new("Frame")
menuContainer.Name = "MenuContainer"
menuContainer.Size = UDim2.new(1, 0, 1, 0)
menuContainer.BackgroundTransparency = 1
menuContainer.Visible = false
menuContainer.Parent = screenGui

local menuBackdrop = Instance.new("TextButton")
menuBackdrop.Name = "Backdrop"
menuBackdrop.Size = UDim2.new(1, 0, 1, 0)
menuBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
menuBackdrop.BackgroundTransparency = 0.6
menuBackdrop.BorderSizePixel = 0
menuBackdrop.Text = ""
menuBackdrop.AutoButtonColor = false
menuBackdrop.Parent = menuContainer

local menuCard = Instance.new("Frame")
menuCard.Name = "Card"
menuCard.AnchorPoint = Vector2.new(0.5, 0.5)
menuCard.Position = UDim2.new(0.5, 0, 0.5, 0)
menuCard.Size = UDim2.new(0, 560, 0, 540)
menuCard.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
menuCard.BorderSizePixel = 0
menuCard.Parent = menuContainer

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 16)
cardCorner.Parent = menuCard

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = Color3.fromRGB(155, 89, 182)
cardStroke.Thickness = 2
cardStroke.Transparency = 0.3
cardStroke.Parent = menuCard

-- Header
local menuTitle = Instance.new("TextLabel")
menuTitle.Name = "Title"
menuTitle.Size = UDim2.new(1, -60, 0, 32)
menuTitle.Position = UDim2.new(0, 24, 0, 18)
menuTitle.BackgroundTransparency = 1
menuTitle.Font = Enum.Font.GothamBlack
menuTitle.Text = "🌀 SKY SUB-ARENA MISSIONS"
menuTitle.TextColor3 = Color3.fromRGB(215, 175, 255)
menuTitle.TextSize = 22
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Parent = menuCard

local menuSubtitle = Instance.new("TextLabel")
menuSubtitle.Name = "Subtitle"
menuSubtitle.Size = UDim2.new(1, -60, 0, 20)
menuSubtitle.Position = UDim2.new(0, 24, 0, 48)
menuSubtitle.BackgroundTransparency = 1
menuSubtitle.Font = Enum.Font.GothamMedium
menuSubtitle.Text = "Short 1-2 min challenges • High rewards & Next-Run Arena Buffs"
menuSubtitle.TextColor3 = Color3.fromRGB(160, 170, 185)
menuSubtitle.TextSize = 13
menuSubtitle.TextXAlignment = Enum.TextXAlignment.Left
menuSubtitle.Parent = menuCard

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -18, 0, 18)
closeButton.Size = UDim2.new(0, 32, 0, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(35, 42, 54)
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.fromRGB(220, 225, 235)
closeButton.TextSize = 16
closeButton.Parent = menuCard

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- Games List Container
local gamesScroll = Instance.new("ScrollingFrame")
gamesScroll.Name = "GamesScroll"
gamesScroll.Position = UDim2.new(0, 18, 0, 80)
gamesScroll.Size = UDim2.new(1, -36, 1, -96)
gamesScroll.BackgroundTransparency = 1
gamesScroll.BorderSizePixel = 0
gamesScroll.ScrollBarThickness = 4
gamesScroll.ScrollBarImageColor3 = Color3.fromRGB(155, 89, 182)
gamesScroll.Parent = menuCard

local gamesLayout = Instance.new("UIListLayout")
gamesLayout.Padding = UDim.new(0, 14)
gamesLayout.SortOrder = Enum.SortOrder.LayoutOrder
gamesLayout.Parent = gamesScroll

-- =========================================================================
-- 2. Active In-Mission HUD Overlay
-- =========================================================================
local activeHud = Instance.new("Frame")
activeHud.Name = "ActiveHud"
activeHud.AnchorPoint = Vector2.new(0.5, 0)
activeHud.Position = UDim2.new(0.5, 0, 0, 16)
activeHud.Size = UDim2.new(0, 440, 0, 72)
activeHud.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
activeHud.BackgroundTransparency = 0.15
activeHud.BorderSizePixel = 0
activeHud.Visible = false
activeHud.Parent = screenGui

local activeCorner = Instance.new("UICorner")
activeCorner.CornerRadius = UDim.new(0, 12)
activeCorner.Parent = activeHud

local activeStroke = Instance.new("UIStroke")
activeStroke.Color = Color3.fromRGB(155, 89, 182)
activeStroke.Thickness = 1.5
activeStroke.Parent = activeHud

local activeTitle = Instance.new("TextLabel")
activeTitle.Name = "ActiveTitle"
activeTitle.Size = UDim2.new(1, -140, 0, 24)
activeTitle.Position = UDim2.new(0, 16, 0, 8)
activeTitle.BackgroundTransparency = 1
activeTitle.Font = Enum.Font.GothamBold
activeTitle.Text = "MISSION IN PROGRESS"
activeTitle.TextColor3 = Color3.fromRGB(241, 196, 15)
activeTitle.TextSize = 16
activeTitle.TextXAlignment = Enum.TextXAlignment.Left
activeTitle.Parent = activeHud

local activeTimer = Instance.new("TextLabel")
activeTimer.Name = "ActiveTimer"
activeTimer.AnchorPoint = Vector2.new(1, 0)
activeTimer.Position = UDim2.new(1, -120, 0, 8)
activeTimer.Size = UDim2.new(0, 90, 0, 24)
activeTimer.BackgroundTransparency = 1
activeTimer.Font = Enum.Font.GothamBold
activeTimer.Text = "⏱ 60s"
activeTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
activeTimer.TextSize = 18
activeTimer.TextXAlignment = Enum.TextXAlignment.Right
activeTimer.Parent = activeHud

local activeObjective = Instance.new("TextLabel")
activeObjective.Name = "ActiveObjective"
activeObjective.Size = UDim2.new(1, -130, 0, 26)
activeObjective.Position = UDim2.new(0, 16, 0, 36)
activeObjective.BackgroundTransparency = 1
activeObjective.Font = Enum.Font.GothamMedium
activeObjective.Text = "Objective in progress..."
activeObjective.TextColor3 = Color3.fromRGB(200, 210, 225)
activeObjective.TextSize = 14
activeObjective.TextXAlignment = Enum.TextXAlignment.Left
activeObjective.Parent = activeHud

local exitButton = Instance.new("TextButton")
exitButton.Name = "ExitButton"
exitButton.AnchorPoint = Vector2.new(1, 0.5)
exitButton.Position = UDim2.new(1, -12, 0.5, 0)
exitButton.Size = UDim2.new(0, 96, 0, 44)
exitButton.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
exitButton.BorderSizePixel = 0
exitButton.Font = Enum.Font.GothamBold
exitButton.Text = "RETURN\n[To Base]"
exitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
exitButton.TextSize = 12
exitButton.Parent = activeHud

local exitCorner = Instance.new("UICorner")
exitCorner.CornerRadius = UDim.new(0, 8)
exitCorner.Parent = exitButton

-- Dedicated Container for Per-Game Custom Client Widgets
local activeCustomContainer = Instance.new("Frame")
activeCustomContainer.Name = "ActiveCustomFrame"
activeCustomContainer.AnchorPoint = Vector2.new(0.5, 0)
activeCustomContainer.Position = UDim2.new(0.5, 0, 0, 94)
activeCustomContainer.Size = UDim2.new(0, 440, 0, 52)
activeCustomContainer.BackgroundTransparency = 1
activeCustomContainer.Visible = false
activeCustomContainer.Parent = screenGui

local activeClientController = nil
local activeClientGameId = nil
local isSessionActive = false
local activeNoticeTween = nil
local clearGuidanceVisuals = nil
local hideNoticeBanner = nil

local function mountGameClient(gameId)
	isSessionActive = true
	if clearGuidanceVisuals then
		clearGuidanceVisuals()
	end
	if hideNoticeBanner then
		hideNoticeBanner()
	end

	if activeClientController then
		pcall(function() activeClientController:Unmount() end)
		activeClientController = nil
		activeClientGameId = nil
		activeCustomContainer:ClearAllChildren()
	end

	local gameDef = MiniGameRegistry.GetGame(gameId)
	local clientPkgName = (gameDef and gameDef.clientPackage) or gameId

	local packagesFolder = ReplicatedStorage:FindFirstChild("MiniGames") and ReplicatedStorage.MiniGames:FindFirstChild("Packages")
	local pkg = packagesFolder and packagesFolder:FindFirstChild(clientPkgName)
	local clientMod = pkg and pkg:FindFirstChild("Client")

	if clientMod and clientMod:IsA("ModuleScript") then
		local ok, controllerClass = pcall(require, clientMod)
		if ok and controllerClass then
			local instance = if controllerClass.new then controllerClass.new() else controllerClass
			if instance.Mount then
				activeCustomContainer.Visible = true
				pcall(function()
					instance:Mount({
						player = player,
						rootContainer = activeCustomContainer,
						eventBus = MiniGameEventBus,
						config = gameDef,
					})
				end)
				activeClientController = instance
				activeClientGameId = gameId
			end
		end
	end
end

local function unmountGameClient()
	if activeClientController then
		pcall(function() activeClientController:Unmount() end)
		activeClientController = nil
		activeClientGameId = nil
	end
	activeCustomContainer:ClearAllChildren()
	activeCustomContainer.Visible = false
end

-- =========================================================================
-- 3. Mission Results Modal
-- =========================================================================
local resultsContainer = Instance.new("Frame")
resultsContainer.Name = "ResultsContainer"
resultsContainer.Size = UDim2.new(1, 0, 1, 0)
resultsContainer.BackgroundTransparency = 1
resultsContainer.Visible = false
resultsContainer.Parent = screenGui

local resultsBackdrop = Instance.new("TextButton")
resultsBackdrop.Name = "Backdrop"
resultsBackdrop.Size = UDim2.new(1, 0, 1, 0)
resultsBackdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
resultsBackdrop.BackgroundTransparency = 0.65
resultsBackdrop.BorderSizePixel = 0
resultsBackdrop.Text = ""
resultsBackdrop.AutoButtonColor = false
resultsBackdrop.Parent = resultsContainer

local resultsCard = Instance.new("Frame")
resultsCard.Name = "Card"
resultsCard.AnchorPoint = Vector2.new(0.5, 0.5)
resultsCard.Position = UDim2.new(0.5, 0, 0.5, 0)
resultsCard.Size = UDim2.new(0, 460, 0, 380)
resultsCard.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
resultsCard.BorderSizePixel = 0
resultsCard.Parent = resultsContainer

local resultsCorner = Instance.new("UICorner")
resultsCorner.CornerRadius = UDim.new(0, 16)
resultsCorner.Parent = resultsCard

local resultsStroke = Instance.new("UIStroke")
resultsStroke.Color = Color3.fromRGB(46, 204, 113)
resultsStroke.Thickness = 2
resultsStroke.Parent = resultsCard

local resultsBanner = Instance.new("TextLabel")
resultsBanner.Name = "Banner"
resultsBanner.Size = UDim2.new(1, 0, 0, 48)
resultsBanner.Position = UDim2.new(0, 0, 0, 16)
resultsBanner.BackgroundTransparency = 1
resultsBanner.Font = Enum.Font.GothamBlack
resultsBanner.Text = "★ MISSION COMPLETED ★"
resultsBanner.TextColor3 = Color3.fromRGB(46, 204, 113)
resultsBanner.TextSize = 24
resultsBanner.Parent = resultsCard

local resultsBody = Instance.new("TextLabel")
resultsBody.Name = "Body"
resultsBody.Size = UDim2.new(1, -40, 0, 220)
resultsBody.Position = UDim2.new(0, 20, 0, 70)
resultsBody.BackgroundColor3 = Color3.fromRGB(15, 18, 24)
resultsBody.BackgroundTransparency = 0.4
resultsBody.Font = Enum.Font.GothamMedium
resultsBody.Text = ""
resultsBody.TextColor3 = Color3.fromRGB(230, 235, 245)
resultsBody.TextSize = 16
resultsBody.TextYAlignment = Enum.TextYAlignment.Top
resultsBody.Parent = resultsCard

local bodyCorner = Instance.new("UICorner")
bodyCorner.CornerRadius = UDim.new(0, 10)
bodyCorner.Parent = resultsBody

local resultsOkButton = Instance.new("TextButton")
resultsOkButton.Name = "OkButton"
resultsOkButton.AnchorPoint = Vector2.new(0.5, 1)
resultsOkButton.Position = UDim2.new(0.5, 0, 1, -16)
resultsOkButton.Size = UDim2.new(0, 220, 0, 44)
resultsOkButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
resultsOkButton.BorderSizePixel = 0
resultsOkButton.Font = Enum.Font.GothamBold
resultsOkButton.Text = "RETURN TO BASE"
resultsOkButton.TextColor3 = Color3.fromRGB(15, 20, 25)
resultsOkButton.TextSize = 16
resultsOkButton.Parent = resultsCard

local okCorner = Instance.new("UICorner")
okCorner.CornerRadius = UDim.new(0, 10)
okCorner.Parent = resultsOkButton

-- =========================================================================
-- 4. Active Next-Run Buff Pill (Floating indicator on screen)
-- =========================================================================
local buffPill = Instance.new("Frame")
buffPill.Name = "NextRunBuffPill"
buffPill.AnchorPoint = Vector2.new(1, 0)
buffPill.Position = UDim2.new(1, -230, 0, 122) -- Sits directly beneath CoinHUD
buffPill.Size = UDim2.new(0, 210, 0, 36)
buffPill.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
buffPill.BackgroundTransparency = 0.2
buffPill.BorderSizePixel = 0
buffPill.Visible = false
buffPill.Parent = screenGui

local pillCorner = Instance.new("UICorner")
pillCorner.CornerRadius = UDim.new(0, 10)
pillCorner.Parent = buffPill

local pillStroke = Instance.new("UIStroke")
pillStroke.Color = Color3.fromRGB(241, 196, 15)
pillStroke.Thickness = 1.2
pillStroke.Parent = buffPill

local pillLabel = Instance.new("TextLabel")
pillLabel.Name = "Label"
pillLabel.Size = UDim2.new(1, -12, 1, 0)
pillLabel.Position = UDim2.new(0, 8, 0, 0)
pillLabel.BackgroundTransparency = 1
pillLabel.Font = Enum.Font.GothamBold
pillLabel.Text = "⚡ ARENA BUFF READY"
pillLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
pillLabel.TextSize = 12
pillLabel.TextXAlignment = Enum.TextXAlignment.Left
pillLabel.Parent = buffPill

-- =========================================================================
-- 5. Base Inactive Visual Alert Banner & In-World Guidance System
-- =========================================================================
local noticeBanner = Instance.new("Frame")
noticeBanner.Name = "NoticeBanner"
noticeBanner.AnchorPoint = Vector2.new(0.5, 0)
noticeBanner.Position = UDim2.new(0.5, 0, 0, -110)
noticeBanner.Size = UDim2.new(0, 520, 0, 80)
noticeBanner.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
noticeBanner.BackgroundTransparency = 0.08
noticeBanner.BorderSizePixel = 0
noticeBanner.Visible = false
noticeBanner.ZIndex = 50
noticeBanner.Parent = screenGui

local noticeCorner = Instance.new("UICorner")
noticeCorner.CornerRadius = UDim.new(0, 14)
noticeCorner.Parent = noticeBanner

local noticeStroke = Instance.new("UIStroke")
noticeStroke.Name = "NoticeStroke"
noticeStroke.Color = Color3.fromRGB(243, 156, 18)
noticeStroke.Thickness = 2
noticeStroke.Parent = noticeBanner

local noticeIcon = Instance.new("TextLabel")
noticeIcon.Name = "Icon"
noticeIcon.Size = UDim2.new(0, 48, 0, 48)
noticeIcon.Position = UDim2.new(0, 14, 0, 16)
noticeIcon.BackgroundTransparency = 1
noticeIcon.Font = Enum.Font.GothamBlack
noticeIcon.Text = "⚠️"
noticeIcon.TextColor3 = Color3.fromRGB(243, 156, 18)
noticeIcon.TextSize = 28
noticeIcon.ZIndex = 51
noticeIcon.Parent = noticeBanner

local noticeTitle = Instance.new("TextLabel")
noticeTitle.Name = "Title"
noticeTitle.Size = UDim2.new(1, -74, 0, 24)
noticeTitle.Position = UDim2.new(0, 64, 0, 12)
noticeTitle.BackgroundTransparency = 1
noticeTitle.Font = Enum.Font.GothamBold
noticeTitle.Text = "BASE NOT ACTIVE"
noticeTitle.TextColor3 = Color3.fromRGB(241, 196, 15)
noticeTitle.TextSize = 16
noticeTitle.TextXAlignment = Enum.TextXAlignment.Left
noticeTitle.ZIndex = 51
noticeTitle.Parent = noticeBanner

local noticeMessage = Instance.new("TextLabel")
noticeMessage.Name = "Message"
noticeMessage.Size = UDim2.new(1, -74, 0, 36)
noticeMessage.Position = UDim2.new(0, 64, 0, 34)
noticeMessage.BackgroundTransparency = 1
noticeMessage.Font = Enum.Font.GothamMedium
noticeMessage.Text = "Step on the glowing [CLAIM BASE] pad at the front entrance to activate this compound!"
noticeMessage.TextColor3 = Color3.fromRGB(225, 230, 240)
noticeMessage.TextSize = 13
noticeMessage.TextWrapped = true
noticeMessage.TextXAlignment = Enum.TextXAlignment.Left
noticeMessage.ZIndex = 51
noticeMessage.Parent = noticeBanner

local noticeProgress = Instance.new("Frame")
noticeProgress.Name = "ProgressLine"
noticeProgress.AnchorPoint = Vector2.new(0, 1)
noticeProgress.Position = UDim2.new(0, 14, 1, -4)
noticeProgress.Size = UDim2.new(1, -28, 0, 3)
noticeProgress.BackgroundColor3 = Color3.fromRGB(243, 156, 18)
noticeProgress.BorderSizePixel = 0
noticeProgress.ZIndex = 52
noticeProgress.Parent = noticeBanner

local progressCorner = Instance.new("UICorner")
progressCorner.CornerRadius = UDim.new(0, 2)
progressCorner.Parent = noticeProgress

local noticeHideThread = nil

local function showNoticeBanner(titleText, bodyText, strokeColor, duration)
	duration = duration or 4.5
	if noticeHideThread then
		task.cancel(noticeHideThread)
		noticeHideThread = nil
	end

	noticeTitle.Text = titleText or "⚠️ ATTENTION"
	noticeMessage.Text = bodyText or ""
	local color = strokeColor or Color3.fromRGB(243, 156, 18)
	noticeStroke.Color = color
	noticeTitle.TextColor3 = color
	noticeProgress.BackgroundColor3 = color

	noticeBanner.Visible = true
	noticeProgress.Size = UDim2.new(1, -28, 0, 3)

	if activeNoticeTween then
		pcall(function() activeNoticeTween:Cancel() end)
		activeNoticeTween = nil
	end

	activeNoticeTween = TweenService:Create(noticeBanner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 24)
	})
	activeNoticeTween:Play()

	TweenService:Create(noticeProgress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 0, 3)
	}):Play()

	noticeHideThread = task.delay(duration, function()
		local hideTween = TweenService:Create(noticeBanner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -110)
		})
		activeNoticeTween = hideTween
		hideTween:Play()
		hideTween.Completed:Wait()
		noticeBanner.Visible = false
	end)
end

hideNoticeBanner = function()
	if activeNoticeTween then
		pcall(function() activeNoticeTween:Cancel() end)
		activeNoticeTween = nil
	end
	if noticeHideThread then
		task.cancel(noticeHideThread)
		noticeHideThread = nil
	end
	noticeBanner.Visible = false
	noticeBanner.Position = UDim2.new(0.5, 0, 0, -110)
end

-- Client-only guidance beam and waypoint indicator
local activeGuideCleanup = nil

clearGuidanceVisuals = function()
	if activeGuideCleanup then
		pcall(activeGuideCleanup)
		activeGuideCleanup = nil
	end
end

local function spawnGuidanceBeam(targetPosition)
	clearGuidanceVisuals()
	if not targetPosition then return end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local anchorPart = Instance.new("Part")
	anchorPart.Name = "ClientGuideAnchor"
	anchorPart.Size = Vector3.new(0.5, 0.5, 0.5)
	anchorPart.Position = targetPosition + Vector3.new(0, 1.5, 0)
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.Transparency = 1
	anchorPart.Parent = workspace

	local attachTarget = Instance.new("Attachment")
	attachTarget.Name = "GuideTargetAttach"
	attachTarget.Parent = anchorPart

	local attachRoot = Instance.new("Attachment")
	attachRoot.Name = "GuideRootAttach"
	attachRoot.Parent = root

	local beam = Instance.new("Beam")
	beam.Name = "ClaimGuidanceBeam"
	beam.Attachment0 = attachRoot
	beam.Attachment1 = attachTarget
	beam.Width0 = 1.2
	beam.Width1 = 2.4
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(243, 156, 18)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(46, 204, 113)),
	})
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.TextureSpeed = 2.0
	beam.TextureLength = 5
	beam.Parent = anchorPart

	local waypointGui = Instance.new("BillboardGui")
	waypointGui.Name = "ClaimWaypointGui"
	waypointGui.Size = UDim2.new(0, 200, 0, 52)
	waypointGui.StudsOffset = Vector3.new(0, 4.5, 0)
	waypointGui.AlwaysOnTop = true
	waypointGui.Parent = anchorPart

	local waypointLabel = Instance.new("TextLabel")
	waypointLabel.Size = UDim2.new(1, 0, 1, 0)
	waypointLabel.BackgroundColor3 = Color3.fromRGB(15, 20, 28)
	waypointLabel.BackgroundTransparency = 0.15
	waypointLabel.Font = Enum.Font.GothamBlack
	waypointLabel.Text = "⚡ STEP HERE TO CLAIM ⚡\n[Activate Base]"
	waypointLabel.TextColor3 = Color3.fromRGB(80, 255, 140)
	waypointLabel.TextSize = 13
	waypointLabel.Parent = waypointGui

	local waypointCorner = Instance.new("UICorner")
	waypointCorner.CornerRadius = UDim.new(0, 8)
	waypointCorner.Parent = waypointLabel

	local waypointStroke = Instance.new("UIStroke")
	waypointStroke.Color = Color3.fromRGB(46, 204, 113)
	waypointStroke.Thickness = 2
	waypointStroke.Parent = waypointLabel

	local isCleaned = false
	local function cleanup()
		if isCleaned then return end
		isCleaned = true
		if attachRoot and attachRoot.Parent then attachRoot:Destroy() end
		if anchorPart and anchorPart.Parent then anchorPart:Destroy() end
	end
	activeGuideCleanup = cleanup

	task.spawn(function()
		local startTime = os.clock()
		while not isCleaned and (os.clock() - startTime < 6) do
			task.wait(0.2)
			local currentChar = player.Character
			local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
			if currentRoot then
				local dist = (currentRoot.Position - targetPosition).Magnitude
				if dist <= 7 then
					break
				end
			end
		end
		cleanup()
	end)
end

-- =========================================================================
-- Logic & Remotes Binding
-- =========================================================================

local currentActiveBaseId = 1

local function updateBuffPill(buffData)
	if buffData then
		buffPill.Visible = true
		pillLabel.Text = string.format("%s %s", buffData.icon or "⚡", string.upper(buffData.displayName or "NEXT-RUN BUFF"))
	else
		buffPill.Visible = false
	end
end

local function populateGameCards(games, baseId)
	currentActiveBaseId = baseId or 1
	for _, child in ipairs(gamesScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local contentHeight = 0

	for idx, gameDef in ipairs(games) do
		local card = Instance.new("Frame")
		card.Name = "GameCard_" .. gameDef.id
		card.Size = UDim2.new(1, -8, 0, 180)
		card.BackgroundColor3 = Color3.fromRGB(28, 34, 46)
		card.BorderSizePixel = 0
		card.Parent = gamesScroll

		local cardC = Instance.new("UICorner")
		cardC.CornerRadius = UDim.new(0, 12)
		cardC.Parent = card

		local cardS = Instance.new("UIStroke")
		cardS.Color = Color3.fromRGB(50, 60, 80)
		cardS.Thickness = 1
		cardS.Parent = card

		-- Icon & Title
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -160, 0, 26)
		titleLabel.Position = UDim2.new(0, 16, 0, 12)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.Text = string.format("%s %s", gameDef.icon or "🎮", gameDef.displayName)
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		titleLabel.TextSize = 18
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Parent = card

		local catBadge = Instance.new("TextLabel")
		catBadge.AnchorPoint = Vector2.new(1, 0)
		catBadge.Position = UDim2.new(1, -16, 0, 12)
		catBadge.Size = UDim2.new(0, 120, 0, 22)
		catBadge.BackgroundColor3 = Color3.fromRGB(45, 52, 68)
		catBadge.Font = Enum.Font.GothamBold
		catBadge.Text = string.format("⏱ %ds • %s", gameDef.duration, gameDef.category)
		catBadge.TextColor3 = Color3.fromRGB(180, 200, 230)
		catBadge.TextSize = 11
		catBadge.Parent = card

		local catC = Instance.new("UICorner")
		catC.CornerRadius = UDim.new(0, 6)
		catC.Parent = catBadge

		-- Description
		local desc = Instance.new("TextLabel")
		desc.Size = UDim2.new(1, -32, 0, 36)
		desc.Position = UDim2.new(0, 16, 0, 42)
		desc.BackgroundTransparency = 1
		desc.Font = Enum.Font.GothamMedium
		desc.Text = gameDef.description
		desc.TextColor3 = Color3.fromRGB(170, 180, 195)
		desc.TextSize = 12
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.Parent = card

		-- Rewards summary label
		local rewText = string.format("Rewards: 🪙 %d-%d Coins • 💎 %d-%d Gems",
			gameDef.rewards.minCoins, gameDef.rewards.maxCoins,
			gameDef.rewards.minGems, gameDef.rewards.maxGems
		)
		if (gameDef.rewards.relicChance or 0) > 0 then
			rewText = rewText .. string.format(" • 🏺 Relic (%d%%)", math.floor(gameDef.rewards.relicChance * 100))
		end
		if (gameDef.rewards.fragmentChance or 0) > 0 then
			rewText = rewText .. string.format(" • ⭐ Star Fragment (%d%%)", math.floor(gameDef.rewards.fragmentChance * 100))
		end

		local rewLabel = Instance.new("TextLabel")
		rewLabel.Size = UDim2.new(1, -32, 0, 20)
		rewLabel.Position = UDim2.new(0, 16, 0, 84)
		rewLabel.BackgroundTransparency = 1
		rewLabel.Font = Enum.Font.GothamMedium
		rewLabel.Text = rewText
		rewLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
		rewLabel.TextSize = 12
		rewLabel.TextXAlignment = Enum.TextXAlignment.Left
		rewLabel.Parent = card

		-- Buff Preview Box
		local buffBox = Instance.new("Frame")
		buffBox.Size = UDim2.new(1, -160, 0, 42)
		buffBox.Position = UDim2.new(0, 16, 0, 114)
		buffBox.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
		buffBox.BorderSizePixel = 0
		buffBox.Parent = card

		local buffC = Instance.new("UICorner")
		buffC.CornerRadius = UDim.new(0, 8)
		buffC.Parent = buffBox

		local buffDesc = Instance.new("TextLabel")
		buffDesc.Size = UDim2.new(1, -16, 1, 0)
		buffDesc.Position = UDim2.new(0, 8, 0, 0)
		buffDesc.BackgroundTransparency = 1
		buffDesc.Font = Enum.Font.GothamBold
		buffDesc.Text = string.format("%s Next-Run Buff: %s", gameDef.buff.icon or "⚡", gameDef.buff.description)
		buffDesc.TextColor3 = Color3.fromRGB(150, 220, 255)
		buffDesc.TextSize = 11
		buffDesc.TextXAlignment = Enum.TextXAlignment.Left
		buffDesc.TextWrapped = true
		buffDesc.Parent = buffBox

		-- Launch Button
		local launchBtn = Instance.new("TextButton")
		launchBtn.AnchorPoint = Vector2.new(1, 0)
		launchBtn.Position = UDim2.new(1, -16, 0, 114)
		launchBtn.Size = UDim2.new(0, 130, 0, 42)
		launchBtn.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
		launchBtn.BorderSizePixel = 0
		launchBtn.Font = Enum.Font.GothamBlack
		launchBtn.Text = "🚀 LAUNCH"
		launchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		launchBtn.TextSize = 14
		launchBtn.Parent = card

		local launchC = Instance.new("UICorner")
		launchC.CornerRadius = UDim.new(0, 8)
		launchC.Parent = launchBtn

		launchBtn.MouseButton1Click:Connect(function()
			menuContainer.Visible = false
			isSessionActive = true
			if clearGuidanceVisuals then
				clearGuidanceVisuals()
			end
			if hideNoticeBanner then
				hideNoticeBanner()
			end

			local remotes = ReplicatedStorage:FindFirstChild("MiniGameRemotes")
			local startFn = remotes and remotes:FindFirstChild("RequestStartGame")
			if startFn then
				local ok, success, msg = pcall(function()
					return startFn:InvokeServer(gameDef.id, currentActiveBaseId)
				end)
				if not ok or success == false then
					isSessionActive = false
					if msg and tostring(msg) ~= "" then
						showNoticeBanner("⚠️ LAUNCH FAILED", tostring(msg), Color3.fromRGB(231, 76, 60), 4.5)
					end
				end
			end
		end)

		contentHeight += 194
	end

	gamesScroll.CanvasSize = UDim2.new(0, 0, 0, contentHeight)
end

-- Close triggers
closeButton.MouseButton1Click:Connect(function()
	menuContainer.Visible = false
end)

menuBackdrop.MouseButton1Click:Connect(function()
	menuContainer.Visible = false
end)

resultsOkButton.MouseButton1Click:Connect(function()
	resultsContainer.Visible = false
end)

resultsBackdrop.MouseButton1Click:Connect(function()
	resultsContainer.Visible = false
end)

exitButton.MouseButton1Click:Connect(function()
	isSessionActive = false
	unmountGameClient()
	local remotes = ReplicatedStorage:FindFirstChild("MiniGameRemotes")
	local exitEvt = remotes and remotes:FindFirstChild("RequestExitGame")
	if exitEvt then
		exitEvt:FireServer()
	end
	activeHud.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Escape then
		if menuContainer.Visible then
			menuContainer.Visible = false
		elseif resultsContainer.Visible then
			resultsContainer.Visible = false
		end
	end
end)

-- Hook Remotes
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("MiniGameRemotes", 10)
	if not remotes then return end

	local openMenu = remotes:WaitForChild("OpenGameMenu", 10)
	if openMenu then
		openMenu.OnClientEvent:Connect(function(data)
			if data and data.games then
				populateGameCards(data.games, data.baseId)
				updateBuffPill(data.activeBuff)
				menuContainer.Visible = true
			end
		end)
	end

	local inactiveNotice = remotes:WaitForChild("BaseInactiveNotice", 10)
	if inactiveNotice then
		inactiveNotice.OnClientEvent:Connect(function(data)
			-- Strict guard: never display base inactive notifications if player is inside or entering a mini-game
			if isSessionActive or activeHud.Visible or activeClientController ~= nil then
				return
			end

			if data then
				if data.status == "UNCLAIMED" then
					showNoticeBanner(
						"⚠️ BASE NOT ACTIVE",
						"Step on the glowing [CLAIM BASE] pad at the front entrance to activate this compound and unlock Sky Sub-Arena missions!",
						Color3.fromRGB(243, 156, 18),
						5.0
					)
					if data.claimPadPosition then
						spawnGuidanceBeam(data.claimPadPosition)
					end
				elseif data.status == "OWNED_BY_OTHER" then
					showNoticeBanner(
						"⚠️ NOT YOUR BASE",
						string.format("This base belongs to %s! Claim your own unclaimed base at its front pad to unlock missions.", tostring(data.ownerName or "another player")),
						Color3.fromRGB(231, 76, 60),
						4.5
					)
				elseif data.status == "ARENA_ACTIVE" then
					menuContainer.Visible = false
					showNoticeBanner(
						"⚠️ ARENA RUN IN PROGRESS",
						"You cannot enter the Sky Sub-Arena while your Central Arena run is active! Finish your run first.",
						Color3.fromRGB(231, 76, 60),
						4.5
					)
				end
			end
		end)
	end

	local stateUpdate = remotes:WaitForChild("GameStateUpdate", 10)
	if stateUpdate then
		stateUpdate.OnClientEvent:Connect(function(data)
			if data then
				isSessionActive = true
				if clearGuidanceVisuals then
					clearGuidanceVisuals()
				end
				if hideNoticeBanner then
					hideNoticeBanner()
				end

				if activeClientGameId ~= data.gameId then
					mountGameClient(data.gameId)
				end

				-- Forward to In-Process EventBus
				MiniGameEventBus.SessionProgress:Fire(data)

				activeHud.Visible = true
				activeTimer.Text = string.format("⏱ %02ds", math.max(0, data.timeRemaining or 0))
				if (data.timeRemaining or 0) <= 10 then
					activeTimer.TextColor3 = Color3.fromRGB(231, 76, 60)
				else
					activeTimer.TextColor3 = Color3.fromRGB(255, 255, 255)
				end

				local gameDef = MiniGameRegistry.GetGame(data.gameId)
				if gameDef then
					activeTitle.Text = string.format("%s %s", gameDef.icon or "🎮", string.upper(gameDef.displayName))
				end

				activeObjective.Text = data.objective or "Objective in progress"
			end
		end)
	end

	local completed = remotes:WaitForChild("GameCompleted", 10)
	if completed then
		completed.OnClientEvent:Connect(function(data)
			isSessionActive = false
			unmountGameClient()
			activeHud.Visible = false
			if data then
				local isWin = (data.outcome == "Victory" or data.outcome == "Completed")
				resultsBanner.Text = isWin and "★ MISSION COMPLETED ★" or "MISSION ENDED"
				resultsBanner.TextColor3 = isWin and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)
				resultsStroke.Color = isWin and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(231, 76, 60)

				local lines = {}
				table.insert(lines, string.format("<b>Outcome:</b> %s", data.outcome or "Finished"))
				table.insert(lines, "")
				table.insert(lines, "<b>Rewards Vaulted:</b>")
				table.insert(lines, string.format("  • 🪙 <b>+%d Gold Coins</b>", data.coinsEarned or 0))
				table.insert(lines, string.format("  • 💎 <b>+%.1f Precious Gems</b>", data.gemsEarned or 0))

				if data.relicDropped then
					table.insert(lines, "  • 🏺 <b>Ancient Relic Discovered!</b> (+50 Base Leveling Weight)")
				end
				if data.fragmentDropped then
					table.insert(lines, "  • ⭐ <b>Star Fragment Found!</b> (+200 Base Leveling Weight)")
				end

				if data.buffGranted then
					table.insert(lines, "")
					table.insert(lines, string.format("<b>Arena Buff Activated:</b> %s %s", data.buffGranted.icon or "⚡", data.buffGranted.displayName))
					table.insert(lines, string.format("<i>%s</i>", data.buffGranted.description))
					updateBuffPill(data.buffGranted)
				else
					updateBuffPill(nil)
				end

				resultsBody.Text = table.concat(lines, "\n")
				resultsContainer.Visible = true
			end
		end)
	end
end)

-- Hook VaultRemotes for Buff changes
task.spawn(function()
	local vaultRemotes = ReplicatedStorage:WaitForChild("VaultRemotes", 10)
	if vaultRemotes then
		local buffEvent = vaultRemotes:WaitForChild("BuffUpdated", 10)
		if buffEvent then
			buffEvent.OnClientEvent:Connect(function(buffData)
				updateBuffPill(buffData)
			end)
		end
	end
end)
