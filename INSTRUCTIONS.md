# Game Rules & System Requirements

Welcome to the **Coin Collector** project! This document outlines the high-level game rules, multiplayer loop, project structure, and quickstart instructions.

For deep-dive technical specifications and subsystem mechanics, refer to the dedicated guidebooks:
- **Central Arena & Gate Mechanics**: See [ARENA_INSTRUCTIONS.md](ARENA_INSTRUCTIONS.md)
- **4-Player Base Compound & Upgrades**: See [BASE_INSTRUCTIONS.md](BASE_INSTRUCTIONS.md)

---

## 🎯 Game Objective & Core Rules

**Coin Collector** is a 4-player competitive collector and homestead-building game. Players compete to collect coins from a central timed arena, safely deposit them in their home base vault, level up their multipliers, and build up their bases.

### The 4 Core Rules
1. **Base Claiming & Compound Activation**:
   - Each player claims one of the 4 cardinal player bases (North, South, East, West).
   - Players always respawn at their owned base compound.
   - An individual player can only activate the central arena from within **their own base** using their dedicated `ArenaActivatePad`.

2. **Solo Arena Run & Single Gate Entry**:
   - When a player activates the arena from their base, **only their cardinal gate slides open** (green lights). All other 3 gates remain locked (red lights).
   - A player can only enter through their own gate; security sensors prevent any other player from entering, teleporting unauthorized players back to their home base.
   - No other player can enter or activate the arena while an active run is in progress.
   - Collected coins grant points (`leaderstats.Coins`) scaled by the player's current base multiplier.

3. **Coin Expiration, Player Reset & Round Clearance**:
   - The active player has a fixed time limit (`CoinExpirationTime`, default 30s) to claim coins inside the arena.
   - The arena run concludes when **either**:
     - The player successfully claims **all coins** in the arena, OR
     - The timer runs out and remaining coins **expire**.
   - Upon completion or expiration:
     - The player is immediately ejected from the arena back to their base spawn pad.
     - The open gate slides shut and locks with red indicator lights immediately when the player is ejected.
     - **The ejected runner's base activation plate is deactivated** and placed on cooldown (`RunnerCooldown`, default 10s; `CanTouch = false`).
     - **Other players' base activation plates are immediately enabled** (`CanTouch = true`), giving other players the immediate opportunity to initialize the next run.
     - Coins repopulate to capacity while all gates remain closed.
     - **A player must manually initialize the next entry** by stepping on their base's activation pad; the arena never opens automatically.

4. **Banking, Multipliers & Base Construction**:
   - Players sprint back along high-speed pathways to their home base to deposit carried coins into their **Coin Bank**.
   - Deposited coins increase the base level and permanent coin multiplier ($1.0\times, 1.1\times, 1.2\times\dots$).
   - Bases start open without perimeter walls; players invest their earnings to build walls and expand their compound.

---

## 🔁 Complete Gameplay Loop

```mermaid
flowchart TD
    A[Spawn at Cardinal Base] --> B[Claim Base via Golden Claim Pad]
    B --> C{Is Arena Idle & Ready?}
    C -- No --> D[Wait at Base, Bank Coins, or Position for Next Run]
    C -- Yes --> E[Step on Arena Activation Pad in Base]
    E --> F[Player's Gate Opens Alone (Other 3 Locked)]
    F --> G[Solo Coin Collection Run (30s Expiration Timer)]
    G --> H{All Coins Claimed OR Timer Expired?}
    H -- Yes --> I[Player Ejected to Base, Door Closes & Cooldown Applied]
    I --> J[Other Players' Activation Pads Enable Immediately]
    J --> K[Another Player Initializes Next Entry via Base Activation Pad]
    K --> F
```

---

## 🚀 How to Run and Test

### 1. Starting Rojo Development Server
Open PowerShell in the project directory:
```powershell
# Refresh PATH if needed:
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Start Rojo:
rojo serve
```

### 2. Connecting in Roblox Studio
1. Open a blank baseplate in **Roblox Studio**.
2. Open the **Rojo** plugin inside Studio and click **Connect** (default port `34872`).
3. Press **Play** (F5).
4. Step on an unclaimed base pad, run to the arena, collect coins, and test ejection when the arena empties.

### 3. Standalone Place Build
To generate an independent `.rbxl` file:
```powershell
rojo build --output CoinCollector.rbxl
```

---

## 🛠️ Project Structure & Subsystem Map

```
coin-collector/
├── default.project.json                    # Rojo project definition
├── aftman.toml                            # Toolchain management (Rojo 7.7.0)
├── INSTRUCTIONS.md                        # High-level game rules & requirements (this document)
├── ARENA_INSTRUCTIONS.md                  # Central arena, 4 gates, coin tiers & ejection mechanics
├── BASE_INSTRUCTIONS.md                   # 4-player bases, claiming, banking, upgrades & walls
├── README.md                              # Repository overview
└── src/
    ├── ReplicatedStorage/
    │   ├── Coin.lua                       # Coin OOP class: geometry, spin, light, collection callback
    │   ├── CoinConfig.lua                 # Settings defaults & live attribute sync
    │   ├── ArenaEnclosure.lua             # Procedural arena walls, highways, and ejection routing
    │   ├── GateController.lua             # TweenService 4-gate synchronizer & neon lights
    │   └── PlayerBase.lua                 # Modular player base class: claim pad, bank vault, launch pad
    ├── ServerScriptService/
    │   └── CoinCollector.server.lua       # Main game coordinator: loop, round states & leaderstats
    └── StarterPlayer/
        └── StarterPlayerScripts/
            └── CoinHUD.client.lua         # Client-side UI displaying player coin balance
```

---

## 📖 Subsystem Guidebook Directory

For specific implementations, refer directly to the designated guide:

| Topic | Relevant Guide | Key Code Files |
| :--- | :--- | :--- |
| **Arena Layout & Walls** | [ARENA_INSTRUCTIONS.md](ARENA_INSTRUCTIONS.md) | [src/ReplicatedStorage/ArenaEnclosure.lua](src/ReplicatedStorage/ArenaEnclosure.lua) |
| **Synchronized Gates** | [ARENA_INSTRUCTIONS.md](ARENA_INSTRUCTIONS.md) | [src/ReplicatedStorage/GateController.lua](src/ReplicatedStorage/GateController.lua) |
| **Coin Tiers & Spawning** | [ARENA_INSTRUCTIONS.md](ARENA_INSTRUCTIONS.md) | [src/ReplicatedStorage/Coin.lua](src/ReplicatedStorage/Coin.lua) |
| **Clearance & Ejection** | [ARENA_INSTRUCTIONS.md](ARENA_INSTRUCTIONS.md) | [src/ServerScriptService/CoinCollector.server.lua](src/ServerScriptService/CoinCollector.server.lua) |
| **Base Compound & Claims** | [BASE_INSTRUCTIONS.md](BASE_INSTRUCTIONS.md) | [src/ReplicatedStorage/PlayerBase.lua](src/ReplicatedStorage/PlayerBase.lua) |
| **Coin Bank & Multipliers** | [BASE_INSTRUCTIONS.md](BASE_INSTRUCTIONS.md) | [src/ReplicatedStorage/PlayerBase.lua](src/ReplicatedStorage/PlayerBase.lua) |
| **Base Wall Construction** | [BASE_INSTRUCTIONS.md](BASE_INSTRUCTIONS.md) | [src/ReplicatedStorage/PlayerBase.lua](src/ReplicatedStorage/PlayerBase.lua) |
| **Activity & Task Zones** | [BASE_INSTRUCTIONS.md](BASE_INSTRUCTIONS.md) | [src/ReplicatedStorage/PlayerBase.lua](src/ReplicatedStorage/PlayerBase.lua) |
| **Global Config Attributes** | [src/ReplicatedStorage/CoinConfig.lua](src/ReplicatedStorage/CoinConfig.lua) | [src/ReplicatedStorage/CoinConfig.lua](src/ReplicatedStorage/CoinConfig.lua) |

