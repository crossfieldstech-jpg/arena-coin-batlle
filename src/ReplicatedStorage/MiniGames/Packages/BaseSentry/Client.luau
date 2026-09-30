--[[
	BaseSentry/Client.luau
	Backward-compatibility wrapper delegating to AlienBaseDefence client package:
	src/ReplicatedStorage/MiniGames/Packages/AlienBaseDefence/Client.luau
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AlienBaseDefenceClient = require(ReplicatedStorage:WaitForChild("MiniGames"):WaitForChild("Packages"):WaitForChild("AlienBaseDefence"):WaitForChild("Client"))

return AlienBaseDefenceClient
