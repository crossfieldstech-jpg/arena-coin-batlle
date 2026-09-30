--[[
	AlienBaseDefence.lua
	Games directory entrypoint delegating to decoupled package engine:
	src/ServerScriptService/MiniGames/Packages/AlienBaseDefence/Server.luau
]]

local AlienBaseDefenceServer = require(script.Parent.Parent:WaitForChild("Packages"):WaitForChild("AlienBaseDefence"):WaitForChild("Server"))
return AlienBaseDefenceServer
