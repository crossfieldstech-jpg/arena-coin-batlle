# Coin Collector

A modular Roblox multiplayer game where up to 4 players maintain their own bases away from the central coin collection area in the middle of the map, featuring 4 synchronized sliding gates, nearest-base ejection, round-based clearance, and pluggable unlock triggers.

## Features

- **Central Coin Collection Area**: Located in the middle of the map (`0,0,0`) with 4 synchronized animated gates (North, South, East, West).
- **4 Dedicated Player Bases**: Positioned in cardinal directions far back from the central arena, each with its own spawn pad, claim pad, coin banking vault, and arena launch pad. See [BASE_INSTRUCTIONS.md](BASE_INSTRUCTIONS.md) for full base documentation.
- **Dynamic 4-Gate System**: 4 synchronized sliding gates powered by `TweenService` with security indicator lights (Green = Open, Red = Locked, Yellow = Moving).
- **Solo Arena Activation & Ejection**: Players activate solo arena runs from their base activation pad. Upon completion or expiration, players are ejected and gates close immediately.
- **Round-Based Respawn**: When all coins are collected or time expires, the open gate locks and batch-repopulates the arena.
- **Dynamic Tiered Coins & Multipliers**: Standard (Gold), Silver, and Mega (Diamond) coins with customizable shapes, sizes, values, and base performance multipliers.
- **Live Studio Attributes**: Tune timers, coin values, spawn chances, base stats, and gate settings in real-time without restarting.

## Project Structure

- `default.project.json` - Rojo project definition
- `INSTRUCTIONS.md` - Primary game overview & instructions
- `BASE_INSTRUCTIONS.md` - Dedicated player base guide & future customization specifications
- `src/ReplicatedStorage/Coin.lua` - Coin class handling shape, size, color, value, and touch pickups
- `src/ReplicatedStorage/CoinConfig.lua` - Central configuration module and default parameters
- `src/ReplicatedStorage/ArenaEnclosure.lua` - Procedural arena construction, highways to bases, and ejection handling
- `src/ReplicatedStorage/GateController.lua` - Animated sliding gate controller with status indicators and state management
- `src/ReplicatedStorage/GateUnlockTrigger.lua` - Pluggable gate unlock trigger manager (dynamic timers, attribute flags, custom triggers)
- `src/ReplicatedStorage/PlayerBase.lua` - Modular player base class: claim pad, coin bank, launch pad, and dynamic attributes
- `src/ServerScriptService/CoinCollector.server.lua` - Game lifecycle coordinator (clearance detection, bases, gate locking, repopulation, and reopening)
- `src/StarterPlayer/StarterPlayerScripts/CoinHUD.client.lua` - Live coin count HUD

## Dynamic Configuration & Live Attributes

When the game boots, a `Configuration` instance named **`CoinSettings`** is created in `ReplicatedStorage`. All attributes can be edited live during gameplay in Roblox Studio via the **Properties > Attributes** panel:

### Arena & Gate Settings
| Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `ArenaStatus` | string | `"Open"` | Live status indicator (`"Open"`, `"Locked"`, `"Repopulated"`) |
| `GateMinUnlockDelay` | number | `3` | Minimum random seconds after coin repopulation before the gate reopens |
| `GateMaxUnlockDelay` | number | `8` | Maximum random seconds after coin repopulation before the gate reopens |
| `GateUnlockTriggerType` | string | `"DynamicTimer"` | Active trigger mechanism (`"DynamicTimer"`, `"AttributeFlag"`, or custom) |
| `GateUnlockFlag` | boolean | `false` | When `GateUnlockTriggerType` is `"AttributeFlag"`, set this to `true` to immediately unlock the gate |
| `BatchRespawnOnly` | boolean | `true` | When `true`, coins are collected as a complete round until 0 remain before gate closes |
| `MaxCoins` | number | `30` | Target coin capacity in the arena |

### Coin Values & Weights
| Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Standard_Value` | number | `1` | Point value awarded for Standard (Gold) coins |
| `Standard_Weight`| number | `60` | Spawn probability weight for Standard coins |
| `Silver_Value` | number | `3` | Point value awarded for Silver coins |
| `Silver_Weight` | number | `30` | Spawn probability weight for Silver coins |
| `Mega_Value` | number | `10` | Point value awarded for Mega (Cyan) coins |
| `Mega_Weight` | number | `10` | Spawn probability weight for Mega coins |

## How to Customize or Switch Gate Triggers in the Future

### 1. Using an Attribute Flag instead of a Timer
In Roblox Studio or by script:
1. Set the attribute `GateUnlockTriggerType` on `CoinSettings` to `"AttributeFlag"`.
2. Whenever you want to unlock the gate (e.g. from an admin command, button click, or boss defeat), set `GateUnlockFlag = true`. The gate will open and automatically reset the flag.

### 2. Registering a Custom Trigger Function in Lua
You can easily attach any custom trigger condition to `GateUnlockTrigger`:

```lua
local GateUnlockTrigger = require(ReplicatedStorage.GateUnlockTrigger)

-- In your custom script:
GateUnlockTrigger:RegisterTrigger("MyCustomTrigger", function(onUnlock, isCancelled)
    -- Wait for your custom event, e.g.:
    workspace.BigRedButton.ClickDetector.MouseClick:Once(function()
        if not isCancelled() then
            onUnlock({ triggerType = "ButtonPress" })
        end
    end)
end)
```
Then set `GateUnlockTriggerType` to `"MyCustomTrigger"`.

## How to Test
1. Run `rojo serve` in the project root.
2. Connect Roblox Studio using the Rojo plugin.
3. Press **Play**. You spawn outside on the courtyard facing the open gate.
4. Walk through the gate and collect all coins.
5. Once all coins are collected:
   - The gate slides down and locks (status light turns red).
   - Any players remaining inside are teleported back to the outside spawn.
   - All coins repopulate in the arena.
   - After a dynamic random delay (or flag trigger), the gate slides up (green light), allowing players back inside.
