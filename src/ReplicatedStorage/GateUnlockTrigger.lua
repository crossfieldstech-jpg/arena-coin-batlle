local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoinConfig = require(ReplicatedStorage:WaitForChild("CoinConfig"))

local GateUnlockTrigger = {}
GateUnlockTrigger.__index = GateUnlockTrigger

function GateUnlockTrigger.new(customConfig)
	local self = setmetatable({}, GateUnlockTrigger)

	self.customConfig = customConfig or {}
	self._activeTrigger = nil
	self._disarmed = false
	self._customTriggers = {}

	-- Register built-in triggers
	self:_registerBuiltIns()

	return self
end

function GateUnlockTrigger:_registerBuiltIns()
	-- 1. DynamicTimer trigger (default): waits a random dynamic duration between Min and Max delay
	self:RegisterTrigger("DynamicTimer", function(onUnlock, isCancelled)
		local minDelay = CoinConfig.GetSetting("GateMinUnlockDelay") or 3
		local maxDelay = CoinConfig.GetSetting("GateMaxUnlockDelay") or 8
		if minDelay > maxDelay then
			minDelay, maxDelay = maxDelay, minDelay
		end

		local randomDelay = minDelay + math.random() * (maxDelay - minDelay)
		randomDelay = math.floor(randomDelay * 10) / 10

		-- Broadcast remaining unlock timer to an attribute for HUDs or debugging
		local settingsFolder = CoinConfig.GetSettingsInstance()
		settingsFolder:SetAttribute("CurrentUnlockDelay", randomDelay)
		settingsFolder:SetAttribute("UnlockTargetTime", os.time() + randomDelay)

		task.delay(randomDelay, function()
			if not isCancelled() then
				onUnlock({
					triggerType = "DynamicTimer",
					delay = randomDelay,
				})
			end
		end)
	end)

	-- 2. AttributeFlag trigger: unlocks as soon as an attribute flag is toggled true
	self:RegisterTrigger("AttributeFlag", function(onUnlock, isCancelled)
		local settingsFolder = CoinConfig.GetSettingsInstance()
		local flagName = CoinConfig.GetSetting("GateUnlockFlagName") or "GateUnlockFlag"

		if settingsFolder:GetAttribute(flagName) == true then
			onUnlock({ triggerType = "AttributeFlag", flag = flagName })
			return
		end

		local connection
		connection = settingsFolder:GetAttributeChangedSignal(flagName):Connect(function()
			if settingsFolder:GetAttribute(flagName) == true then
				if connection then
					connection:Disconnect()
					connection = nil
				end
				if not isCancelled() then
					-- Reset flag automatically after trigger
					settingsFolder:SetAttribute(flagName, false)
					onUnlock({ triggerType = "AttributeFlag", flag = flagName })
				end
			end
		end)
	end)
end

-- Easily register custom triggers (e.g., boss defeated, puzzle solved, minigame timer)
function GateUnlockTrigger:RegisterTrigger(name, handlerFn)
	self._customTriggers[name] = handlerFn
end

-- Arm the trigger once the arena is fully populated with coins
function GateUnlockTrigger:Arm(onUnlockCallback)
	self:Disarm()
	self._disarmed = false

	local triggerType = CoinConfig.GetSetting("GateUnlockTriggerType") or "DynamicTimer"
	local handler = self._customTriggers[triggerType] or self._customTriggers["DynamicTimer"]

	local function isCancelled()
		return self._disarmed
	end

	local function onTriggered(details)
		if self._disarmed then
			return
		end
		self._disarmed = true
		if onUnlockCallback then
			onUnlockCallback(details or {})
		end
	end

	self._activeTrigger = handler
	task.spawn(handler, onTriggered, isCancelled)
end

-- Disarm / cancel any pending unlock
function GateUnlockTrigger:Disarm()
	self._disarmed = true
	local settingsFolder = CoinConfig.GetSettingsInstance()
	settingsFolder:SetAttribute("CurrentUnlockDelay", 0)
	settingsFolder:SetAttribute("UnlockTargetTime", 0)
end

-- Force unlock immediately (e.g. admin command or debug bypass)
function GateUnlockTrigger:ForceUnlock(onUnlockCallback)
	self:Disarm()
	if onUnlockCallback then
		onUnlockCallback({ triggerType = "ForceUnlock", delay = 0 })
	end
end

return GateUnlockTrigger
