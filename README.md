# Coin Collector & Arena Battle

A modular Roblox multiplayer game where up to 4 players maintain their own cardinal base compounds away from the central collection arena in the middle of the map, featuring 4 solo-entry synchronized sliding gates, nearest-base ejection, round-based clearance, decoupled multi-currency economy, and pluggable unlock triggers.

---

## 🎯 Features

- **Central Collection Arena**: Located in the middle of the map (`0, 0, 0`) with 4 solo-entry synchronized sliding gates (North, South, East, West), transparent spectator wall triggers, and dynamic arena digital status boards.
- **4 Dedicated Player Bases**: Spacious compounds positioned 140 studs away in cardinal directions, each equipped with a spawn pad, golden base claim pad, coin/gem banking vault, and dedicated arena activation pad. Claimed bases project a high-tech translucent perimeter visual barrier.
- **Decoupled Multi-Currency Economy**: Economic logic is completely decoupled from gameplay items. Managed via `VaultItemRegistry` and `VaultService` with support for coins, gems, treasures, and materials, non-linear leveling curves, and bounded diminishing-returns multipliers.
- **Strict Coin vs. Gem Jackpot Rounds**:
  - **Standard Coin Rounds**: 100% coins spawn in the arena with zero gems. The client HUD compacts to 52px, displaying only Coins.
  - **Gem Jackpot Rounds**: 1-in-5 chance (20% spawn rate) for an all-gem jackpot round. Collect radiant gemstones scaled to **$2.0\times$ the value of coins** (Emerald = 2.0, Sapphire = 6.0, Ruby = 20.0). The client HUD dynamically expands to 96px displaying both currencies.
- **Solo Arena Runs & Security Ejection**: An arena run can only be initiated by a player standing on their own base activation pad. Only their cardinal gate slides open; unauthorized intruders are bounced back to their bases. When all items are collected or the 30s expiration timer runs out, the runner is teleported home, the gate locks, and a runner cooldown gives other players first opportunity to trigger the next run.
- **Sky Sub-Arena Mini-Games**: Isolated procedural platforms high above the compounds at $Y=400$ host solo mini-games (e.g. *Coin Forge* micro-tycoon and *Base Sentry* tower defense) during central arena downtime, awarding coins, gems, rare drops (Ancient Relics & Star Fragments), and temporary Next-Run Arena Buffs.
- **Automated Scaling Verification**: Includes a headless Luau simulation engine (`EconomySimulator`) to stress-test 100+ rounds across 4 player profiles, asserting smooth leveling curves, inflation control, and multiplier caps ($< 3.0\times$).
- **Live Studio Attributes**: Tune timers, coin/gem values, spawn chances, base stats, and gate settings in real-time via `ReplicatedStorage.CoinSettings` and `ReplicatedStorage.GemSettings` without restarting.
- **Roblox Studio MCP Direct Sync**: Synchronized directly with Roblox Studio using the Roblox Studio Model Context Protocol (MCP), eliminating external syncing servers.

---

## 📚 Guidebook Directory

For in-depth architectural and mechanical specifications, refer to the dedicated subsystem guides:

| Guidebook | Focus Area | Key Systems Documented |
| :--- | :--- | :--- |
| **[INSTRUCTIONS.md](INSTRUCTIONS.md)** | Core Game Rules & Loop | Multiplayer loop, 4 core rules, cardinal base setup, and quickstart overview |
| **[ARENA_INSTRUCTIONS.md](ARENA_INSTRUCTIONS.md)** | Central Arena & Gates | Dimensions, gate state machine, coin/gem geometries, jackpot rounds, and spectator walls |
| **[BASE_INSTRUCTIONS.md](BASE_INSTRUCTIONS.md)** | 4-Player Compounds | Base claiming, banking pads, perimeter visual barriers, upgrades, and respawn routing |
| **[ECONOMY_INSTRUCTIONS.md](ECONOMY_INSTRUCTIONS.md)** | Decoupled Economy | Schema validation, progression power curves, bounded multipliers, faucets/sinks, and scaling tests |
| **[docs/minigames/README.md](docs/minigames/README.md)** | Sky Sub-Arena Mini-Games | Vertical platform ($Y=400$), session lifecycle, Coin Forge, Base Sentry, and Next-Run Buffs |

---

## 📁 Project Structure

```
arena-coin-battle/
├── INSTRUCTIONS.md                                  # Overarching game rules & multiplayer loop
├── ARENA_INSTRUCTIONS.md                            # Central arena layout, 4 gates & drop tables
├── BASE_INSTRUCTIONS.md                             # 4-player compounds, claiming & visual barriers
├── ECONOMY_INSTRUCTIONS.md                          # Economy decoupling, formulas & diagnostic guide
├── README.md                                        # Repository overview (this document)
├── docs/
│   └── minigames/
│       ├── README.md                                # Sky Sub-Arena architecture, lifecycle & rewards
│       ├── COIN_FORGE.md                            # Coin Forge micro-tycoon loop & buff specs
│       ├── BASE_SENTRY.md                           # Base Sentry tower defense waves & sentry specs
│       └── NEW_MINIGAME_GUIDE.md                    # Mini-game authoring guide & template
└── src/
    ├── ReplicatedStorage/
    │   ├── ArenaEnclosure.luau                      # Procedural arena walls, interior digital displays & ejection
    │   ├── Coin.luau                                # Coin OOP class: geometry, light, and collection hooks
    │   ├── CoinConfig.luau                          # Coin parameters, tier definitions & live CoinSettings attributes
    │   ├── Gem.luau                                 # Gem OOP class: crystal block geometry, materials & collection hooks
    │   ├── GemConfig.luau                           # Gem economy configuration & live GemSettings attributes
    │   ├── GateController.luau                      # TweenService 4-gate synchronizer & neon indicator lights
    │   ├── GateUnlockTrigger.luau                   # Pluggable unlock trigger manager (timer, flags, custom)
    │   ├── PlayerBase.luau                          # Player base compound class: claim pad, bank vault, visual barrier
    │   ├── VaultItemRegistry.luau                   # Pure item catalog, economic roles, leveling curve & multiplier math
    │   ├── EconomySimulator.luau                    # Headless economy simulator & scaling assertion suite
    │   └── MiniGames/
    │       └── MiniGameRegistry.luau                # Pure catalog & schema for Sky Sub-Arena games & buffs
    ├── ServerScriptService/
    │   ├── CoinCollector.server.lua                 # Main game coordinator: round lifecycle, solo runs, and gates
    │   ├── VaultService.lua                         # Atomic economy pipelines, mutex locking, persistence & live telemetry
    │   └── MiniGames/
    │       ├── MiniGameService.lua                  # Sky platform spawner, session manager & rewards
    │       └── Games/
    │           ├── CoinForge.lua                    # Micro-Tycoon ore -> furnace -> stamper loop
    │           └── BaseSentry.lua                   # Tower Defense wave runner & sentry nodes
    └── StarterPlayer/
        └── StarterPlayerScripts/
            ├── CoinHUD.client.lua                   # Dynamic single/dual-currency HUD with proximity fading
            ├── CoinVisualController.client.lua      # Smooth 60fps coin spinning & floating bob animation
            ├── GemVisualController.client.lua       # Radiant 3D tumbling rotation animation for gemstones
            ├── MiniGameHUD.client.lua               # Dynamic mini-game launcher & active HUD
            ├── TextProximityFade.local.luau         # Proximity-based billboard text fading
            └── VaultHUD.client.lua                  # Interactive modal dialog for persistent player vault storage
```
            ├── CoinHUD.client.lua                   # Dynamic single/dual-currency HUD with proximity fading
            ├── CoinVisualController.client.lua      # Smooth 60fps coin spinning & floating bob animation
            ├── GemVisualController.client.lua       # Radiant 3D tumbling rotation animation for gemstones
            ├── TextProximityFade.local.luau         # Proximity-based billboard text fading
            └── VaultHUD.client.lua                  # Interactive modal dialog for persistent player vault storage
```

---

## ⚙️ Dynamic Configuration & Live Attributes

When the game boots, `Configuration` instances named **`CoinSettings`** and **`GemSettings`** are initialized in `ReplicatedStorage`. All attributes can be edited live during gameplay in Roblox Studio via the **Properties > Attributes** panel:

### Arena & Gate Settings (`CoinSettings`)
| Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `ArenaStatus` | string | `"IdleReady"` | Live status indicator (`"IdleReady"`, `"ActiveRun"`, `"Locked"`) |
| `CurrentRoundItemType` | string | `"Coin"` | Current round type (`"Coin"` or `"Gem"`) |
| `IsGemRound` | boolean | `false` | True when active round is an all-gem jackpot round |
| `CoinExpirationTime` | number | `30` | Seconds runner has to collect items before ejection |
| `RunnerCooldown` | number | `15` | Seconds previous runner must wait before initiating another run |
| `GateMoveDuration` | number | `1.2` | Tween duration in seconds for sliding gates |
| `GateMinUnlockDelay` | number | `3` | Minimum random seconds after coin repopulation before gate reopens |
| `GateMaxUnlockDelay` | number | `8` | Maximum random seconds after coin repopulation before gate reopens |
| `GateUnlockTriggerType` | string | `"DynamicTimer"` | Active trigger mechanism (`"DynamicTimer"`, `"AttributeFlag"`, or custom) |
| `GateUnlockFlag` | boolean | `false` | When `GateUnlockTriggerType` is `"AttributeFlag"`, set to `true` to immediately unlock |
| `BatchRespawnOnly` | boolean | `true` | When `true`, coins/gems are cleared as a round before gate closes |
| `MaxCoins` | number | `30` | Maximum simultaneous item capacity in the arena |
| `ArenaWallTransparency` | number | `0.7` | Spectator wall transparency during active runs (0 = opaque, 1 = invisible) |

### Coin Values & Weights (`CoinSettings`)
| Tier | Color | Value | Weight | Description |
| :--- | :--- | :---: | :---: | :--- |
| **Standard** | Polished Gold | `1` | `60` | Common gold coin |
| **Silver** | Gleaming Silver | `3` | `30` | Uncommon silver coin |
| **Mega** | Azure Diamond | `10` | `10` | High-value treasure coin |

### Gem Values & Jackpot Round Settings (`GemSettings`)
Gems spawn as an all-gem jackpot round 1 in 5 times (`SpawnRate = 0.2`). All gems are scaled to **$2.0\times$ the value of coins**:

| Attribute | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `Enabled` | boolean | `true` | Toggle whether gem jackpot rounds can occur in the arena |
| `SpawnRate` | number | `0.2` | Probability (0.0 to 1.0) of rolling a gem jackpot round (1 in 5 = 0.2) |
| `ValueMultiplier` | number | `2.0` | Base multiplier scale for gems vs coin tiers (2x coin value) |
| `Standard_Value` | number | `2.0` | Point value awarded for Emerald gems (2x Standard Coin) |
| `Standard_Weight`| number | `60` | Spawn probability weight for Emerald gems |
| `Silver_Value` | number | `6.0` | Point value awarded for Sapphire gems (2x Silver Coin) |
| `Silver_Weight` | number | `30` | Spawn probability weight for Sapphire gems |
| `Mega_Value` | number | `20.0` | Point value awarded for Ruby gems (2x Mega Coin) |
| `Mega_Weight` | number | `10` | Spawn probability weight for Ruby gems |

---

## 🔌 Roblox Studio MCP Two-Way Synchronization

Development and synchronization in this repository operate through the **Roblox Studio Model Context Protocol (MCP)** bridge, directly linking VS Code with your active Roblox Studio session:

### How MCP Sync Operates
1. **Direct Communication**: VS Code interacts with Roblox Studio's live DataModel via MCP tools (`execute_luau`, `script_read`, `multi_edit`, `inspect_instance`, `search_game_tree`), eliminating background sync daemons.
2. **Automatic Outbound Push (VS Code $\rightarrow$ Studio)**:
   - When code is modified, refactored, or added in VS Code, the updated script source is pushed directly into Roblox Studio's DataModel.
   - Associated live configuration attributes (`CoinSettings`, `GemSettings`) update dynamically.
3. **Automatic Inbound Pull (Studio $\rightarrow$ VS Code)**:
   - When scripts are edited directly within Roblox Studio's editor, the assistant reads the live `.Source` via MCP and updates the local files in `src/` to guarantee parity.

---

## 🧪 Testing & Verification

### 1. In-Game Playtesting in Roblox Studio
1. Open the project in **Roblox Studio**.
2. Press **Play** (F5).
3. Step onto an unclaimed base's golden claim pad to claim your compound and raise the visual barrier.
4. Step onto the base's **Arena Activation Pad** to open your cardinal gate.
5. Collect coins (or gems during a jackpot round) and return to your base bank pad to deposit and level up your multiplier.

### 2. Running the Headless Economy Simulator
To stress-test economy scaling and assert anti-inflation boundaries across 100+ rounds, run the following in the **Roblox Studio Command Bar**:

```luau
local EconomySimulator = require(game.ReplicatedStorage.EconomySimulator)
local report = EconomySimulator.RunSimulation(100)
print(string.format("=== Economy Simulation: %s (Rounds: %d) ===", report.passed and "PASSED" or "FAILED", report.totalRounds))
for _, a in ipairs(report.assertions) do
    print(string.format("  [%s] %s: %s", a.passed and "OK" or "FAIL", a.name, a.message))
end
```

### 3. Live Server Economy Health Diagnostics
To check real-time faucet and sink velocity on a running server, invoke the diagnostic engine:

```luau
local VaultService = require(game.ServerScriptService.VaultService)
local health = VaultService.GetEconomyHealthReport()
print(string.format("[Economy Health] Status: %s | Faucets/min: %.1f | Sinks/min: %.1f | Ratio: %.2f",
    health.status,
    health.metrics.faucetsPerMinute,
    health.metrics.sinksPerMinute,
    health.metrics.inflationRatio
))
if #health.warnings > 0 then
    for _, w in ipairs(health.warnings) do
        warn("  Alert: " .. w)
    end
end
```
