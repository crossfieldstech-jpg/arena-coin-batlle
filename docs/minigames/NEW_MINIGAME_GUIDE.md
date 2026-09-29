# New Mini-Game Authoring Guide

This guide walks through creating, registering, and verifying a new mini-game for the Sky Sub-Arena subsystem.

---

## 📐 Controller Lifecycle Contract

Every mini-game controller must adhere to standard module-level and instance-level contracts to interface with `MiniGameService`:

### Module Entry Point
```lua
function GameController.Start(options: MiniGameOptions): GameControllerInstance
```

### Required Instance Methods
- **`controller:Stop()`**: Executed upon round completion, forfeit, player disconnect, death, or bounds ejection. Must disconnect all `RBXScriptConnection` instances, stop active tweens/tasks, and destroy any spawned dynamic entities.
- **`controller:GetObjective(): string`**: Returns a concise single-line string summarizing current player progress for the client HUD (e.g., `"Wave 2/3 (Vault HP: 85%)"`).

### `options` Payload Schema
When `MiniGameService.StartSession` initializes your game, it passes a table with the following parameters:

| Field | Type | Description |
| :--- | :--- | :--- |
| `player` | `Player` | The participating Roblox player instance. |
| `base` | `table` | Reference to the player's cardinal base compound object. |
| `platformModel` | `Model` | Procedural sky platform model at $Y=400$ in `Workspace`. |
| `gameContentFolder` | `Folder` | Dedicated folder inside `platformModel` where all game parts must be parented. |
| `center` | `Vector3` | Center coordinate of the sky platform $(X, 400, Z)$. |
| `duration` | `number` | Allocated duration in seconds (configured in registry). |
| `onProgress` | `function(data)` | Callback to stream progress to client HUD: `{ objective: string, score: number, extra: table? }`. |
| `onComplete` | `function(outcome, scoreMultiplier)` | Callback when the game ends early: `outcome` (`"Victory"`, `"Completed"`, `"Defeated"`), `scoreMultiplier` ($0.25 - 2.0$). |

---

## 📝 Boilerplate Template: TemplateMiniGame.lua

Create a new module in the games directory (e.g. YourMiniGame.lua inside [src/ServerScriptService/MiniGames/Games/CoinForge.lua](src/ServerScriptService/MiniGames/Games/CoinForge.lua)'s directory):

```lua
--[[
	TemplateMiniGame.lua
	Starter boilerplate for Sky Sub-Arena mini-games.
]]

local TemplateMiniGame = {}
TemplateMiniGame.__index = TemplateMiniGame

function TemplateMiniGame.Start(options)
	local self = setmetatable({}, TemplateMiniGame)

	self.player = options.player
	self.base = options.base
	self.container = options.gameContentFolder
	self.center = options.center
	self.duration = options.duration or 60
	self.onProgress = options.onProgress
	self.onComplete = options.onComplete

	self.isStopped = false
	self.connections = {}
	self.score = 0

	self:BuildWorld()
	self:StartGameLoop()

	return self
end

function TemplateMiniGame:BuildWorld()
	local folder = self.container
	local center = self.center

	-- Place all interactive parts, prompts, and props inside `folder`
	local target = Instance.new("Part")
	target.Name = "ChallengeTarget"
	target.Size = Vector3.new(4, 4, 4)
	target.Position = center + Vector3.new(0, 3, 0)
	target.Anchored = true
	target.Material = Enum.Material.Neon
	target.Color = Color3.fromRGB(46, 204, 113)
	target.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Interact with Target"
	prompt.ObjectText = "Challenge Node"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 10
	prompt.Parent = target

	local conn = prompt.Triggered:Connect(function(player)
		if player ~= self.player or self.isStopped then
			return
		end
		self.score += 1
		self:UpdateHUD()

		if self.score >= 10 then
			self:Finish("Victory", 1.5)
		end
	end)
	table.insert(self.connections, conn)
end

function TemplateMiniGame:StartGameLoop()
	-- Optional background loop / spawner logic
	self:UpdateHUD()
end

function TemplateMiniGame:UpdateHUD()
	if self.isStopped then
		return
	end
	if self.onProgress then
		self.onProgress({
			objective = string.format("Targets Collected: %d/10", self.score),
			score = self.score,
		})
	end
end

function TemplateMiniGame:GetObjective()
	return string.format("Targets: %d/10", self.score)
end

function TemplateMiniGame:Finish(outcome, scoreMultiplier)
	if self.isStopped then
		return
	end
	if self.onComplete then
		self.onComplete(outcome, scoreMultiplier)
	end
end

function TemplateMiniGame:Stop()
	if self.isStopped then
		return
	end
	self.isStopped = true

	-- Disconnect all RBXScriptConnections
	for _, conn in ipairs(self.connections) do
		pcall(function() conn:Disconnect() end)
	end
	self.connections = {}
end

return TemplateMiniGame
```

---

## 🔌 2-Step Registration Process

### Step 1: Register Definition in MiniGameRegistry.luau
Open [src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau](src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau) and append your game definition:

```lua
MiniGameRegistry.RegisterGame({
	id = "YourMiniGame",
	displayName = "Your Mini-Game",
	category = "Puzzle", -- or "Micro-Tycoon", "Tower Defense", "Action"
	description = "A clear 1-2 sentence description of the player's objective.",
	icon = "🎯",
	duration = 60, -- Length of session in seconds
	order = 3,
	enabled = true,
	rewards = {
		minCoins = 50,
		maxCoins = 100,
		minGems = 1,
		maxGems = 2,
		relicChance = 0.20,
		fragmentChance = 0.05,
	},
	buff = {
		id = "YourMiniGame_Buff",
		type = "MultiplierBonus", -- or "TimeBonus"
		value = 0.15,             -- e.g. +0.15x (+15%) or +5 seconds
		displayName = "Champion's Focus",
		description = "+15% Coin & Gem Multiplier on next arena run!",
		icon = "⚡",
	},
})
```

### Step 2: Wire Controller in MiniGameService.lua
Open [src/ServerScriptService/MiniGames/MiniGameService.lua](src/ServerScriptService/MiniGames/MiniGameService.lua). Inside `MiniGameService.StartSession`, locate the controller loader and add your game module branch:

```lua
	-- 5. Launch Dedicated Mini-Game Controller
	local gameControllerModule = nil
	if gameId == "CoinForge" then
		local ok, mod = pcall(function()
			return require(script.Parent:WaitForChild("Games"):WaitForChild("CoinForge"))
		end)
		if ok then gameControllerModule = mod end
	elseif gameId == "BaseSentry" then
		local ok, mod = pcall(function()
			return require(script.Parent:WaitForChild("Games"):WaitForChild("BaseSentry"))
		end)
		if ok then gameControllerModule = mod end
	elseif gameId == "YourMiniGame" then
		local ok, mod = pcall(function()
			return require(script.Parent:WaitForChild("Games"):WaitForChild("YourMiniGame"))
		end)
		if ok then gameControllerModule = mod end
	end
```

---

## ✅ QA Verification Checklist

Before deploying any new mini-game, verify each of the following points:

- [ ] **Isolated Coordinates**: All geometry and visual models are placed relative to `options.center` ($Y \approx 400$) and parented under `options.gameContentFolder`. Nothing is placed directly in `Workspace` or at ground level.
- [ ] **ProximityPrompt User Filtering**: In prompt trigger listeners, verify `player == self.player` before taking action to prevent cross-player interference.
- [ ] **Stop & Cleanup Verification**:
  - All `RBXScriptConnection` references (Heartbeat, Died, Triggered) are stored in `self.connections` and disconnected in `:Stop()`.
  - All dynamically spawned enemy parts, projectiles, or visual beams are explicitly destroyed in `:Stop()`.
- [ ] **Early Exit Scenarios**:
  - Test clicking "Exit / Forfeit" on client HUD.
  - Test resetting character (`Humanoid.Health = 0`).
  - Test walking off the edge or clipping below $Y=370$ (bounds-checker safety teleport).
  - Test player disconnect (`PlayerRemoving`).
- [ ] **HUD & Scoring Sync**: Ensure `onProgress` is invoked after state changes so the client HUD timer and objective text display accurate state.
- [ ] **Reward & Buff Grants**: Confirm `VaultService` balances increase appropriately and verify that the awarded Next-Run Buff activates upon the subsequent Central Arena entry.
