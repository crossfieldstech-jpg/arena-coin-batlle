--[[
	BaseSentry/Config.luau
	Backward-compatibility wrapper delegating to AlienBaseDefence config package:
	src/ReplicatedStorage/MiniGames/Packages/AlienBaseDefence/Config.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AlienBaseDefenceConfig = require(ReplicatedStorage:WaitForChild("MiniGames"):WaitForChild("Packages"):WaitForChild("AlienBaseDefence"):WaitForChild("Config"))

return AlienBaseDefenceConfig
