--[[
	BaseSentry.lua
	Backward-compatibility wrapper delegating to decoupled package engine:
	src/ServerScriptService/MiniGames/Packages/BaseSentry/Server.luau
]]

local BaseSentryServer = require(script.Parent.Parent:WaitForChild("Packages"):WaitForChild("BaseSentry"):WaitForChild("Server"))
return BaseSentryServer
