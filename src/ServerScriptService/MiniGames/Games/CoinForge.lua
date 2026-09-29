--[[
	CoinForge.lua
	Backward-compatibility wrapper delegating to decoupled package engine:
	src/ServerScriptService/MiniGames/Packages/CoinForge/Server.luau
]]

local CoinForgeServer = require(script.Parent.Parent:WaitForChild("Packages"):WaitForChild("CoinForge"):WaitForChild("Server"))
return CoinForgeServer
