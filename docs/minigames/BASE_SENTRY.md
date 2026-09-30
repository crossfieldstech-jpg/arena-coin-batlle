# Base Sentry Mini-Game Specification (Legacy Reference)

> **Notice**: Base Sentry has been completely redesigned into **[Alien Base Defence](ALIEN_BASE_DEFENCE.md)** (`AlienBaseDefence`), featuring military soldier bunkers, alien swarms, cleaner icons (🪖 / 👽 / 🛸), and an expanded $108 \times 108$ overgrown battlefield with rolling mounds and trees. This document is retained for historical architectural reference.

A tactical tower defense mini-game situated on the Sky Sub-Arena platform at $Y=400$. Players construct automated Gatling sentries and overclock defenses to guard their high-tech Mini-Vault Core across 3 intense waves of rogue clockwork bandits.

---

## 📋 Game Metadata

| Field | Value |
| :--- | :--- |
| **Identifier** | `BaseSentry` |
| **Display Name** | Base Sentry |
| **Category** | Tower Defense |
| **Icon** | 🛡️ |
| **Duration** | 90 seconds (3 waves) |
| **Core Health** | 100 HP |
| **Order Index** | 2 |
| **Source Implementation** | [src/ServerScriptService/MiniGames/Games/BaseSentry.lua](src/ServerScriptService/MiniGames/Games/BaseSentry.lua) |
| **Catalog Registration** | [src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau](src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau) |

---

## ⚙️ Arena Defense Map & Wave Mechanics

The sky platform features a winding multi-segment defense corridor, 3 tactical sentry build pedestals, and an illuminated Mini-Vault Core at the end of the track.

```
Waypoint 1 (Spawn: -18, -18)
    |
    v
Waypoint 2 (-18, -6) ----> Waypoint 3 (0, -6)
                             |
         [Node #1]           v
         (-8, 1.5, -12)    Waypoint 4 (0, 8) ----> Waypoint 5 (18, 8)
                                                     |
                                   [Node #2]         v
                                   (8, 1.5, 1)    Waypoint 6: Mini-Vault Core (18, 18)
                                                     - HP: 100 / 100
                                 [Node #3]           - Emissive Core & Shield Billboard
                                 (-8, 1.5, 14)
```

### Sentry Pedestals & Overclocking
Players can walk up to three cylindrical sentry nodes and interact via ProximityPrompts:

| Tier | Name | Visual | Range | Fire Rate | Damage / Shot | Interaction |
| :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| **0** | Empty Pedestal | Dark steel cylinder | — | — | — | `"Deploy Gatling Sentry"` |
| **1** | Gatling Sentry | Emerald Neon head (`#2ECC71`) | 18 studs | 0.60s | 14 HP | `"Overclock Turret [+Damage]"` |
| **2** | Overclocked Sentry | Golden Neon enlarged head (`#F1C40F`) | 18 studs | 0.35s | 25 HP | Max upgrade reached (Prompt disabled) |

- **Targeting System**: Every `Heartbeat`, active sentries locate the nearest living enemy within 18 studs.
- **Visual FX**: Fires a neon laser beam connecting the turret head to the enemy target for 0.08s.

---

## 👾 Enemy Archetypes & Wave Structure

Bandits traverse the waypoints sequentially using `TweenService`. If an enemy reaches the Mini-Vault Core, it self-destructs and inflicts damage.

### Bandit Archetypes
| Archetype | HP | Speed | Color / Size | Vault Core Damage | Behavior |
| :--- | :---: | :---: | :--- | :---: | :--- |
| **Scout** | 35 | 11 studs/s | Crimson Neon (`#E74C3C`), $2\times 2\times 2$ | 15 HP | Fast, light skirmisher designed to slip past single turrets. |
| **Armored** | 65 | 9 studs/s | Amethyst Neon (`#9B59B6`), $2.5\times 2.5\times 2.5$ | 15 HP | Durable bruiser requiring sustained turret fire. |
| **Boss** | 180 | 6 studs/s | Amber Neon (`#F39C12`), $4\times 4\times 4$ | 35 HP | High-durability clockwork juggernaut that severely damages the core. |

### Progressive Wave Breakdown
- **Wave 1**: 5 Scouts (spawn interval: 2.2s). Introduces player to basic sentry deployment.
- **Wave 2**: 6 mixed enemies (alternating Scouts and Armored bandits). Tests sentry coverage.
- **Wave 3**: 1 Boss bandit followed by 4 Armored bandits. Demands multiple overclocked sentries to prevent core breach.

---

## 💰 Rewards & Arena Buffs

### Reward Payout Table
| Reward Item | Base Quantity | Multiplier Scaling | Drop Chance |
| :--- | :--- | :--- | :--- |
| **Coins** | 60 – 120 | Scaled by final score multiplier ($\text{HP}\% \times 0.8 + 0.5$) | 100% |
| **Gems** | 1 – 3 | Scaled by final score multiplier | 100% |
| **Ancient Relic** | 1 | Unscaled flat roll | 15% (`relicChance = 0.15`) |
| **Star Fragment** | 1 | Unscaled flat roll | 10% (`fragmentChance = 0.10`) |

### Next-Run Arena Buff: "Overclocked Chrono-Armor"
- **Buff ID**: `BaseSentry_TimeBuff`
- **Buff Type**: `TimeBonus`
- **Bonus Value**: $+5$ seconds
- **Effect**: Extends the central arena countdown timer on the player's next run from 30 seconds to **35 seconds**. Provides extra runway to clear jackpot gem boards or collect edge coins.

---

## 🔧 Tuning Parameters & Maintenance Tips

Key configuration constants in [src/ServerScriptService/MiniGames/Games/BaseSentry.lua](src/ServerScriptService/MiniGames/Games/BaseSentry.lua) and [src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau](src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau):

| Parameter | Location | Default | Impact |
| :--- | :--- | :--- | :--- |
| `duration` | [src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau](src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau) | `90` | Wave loop execution window in seconds. |
| `maxCoreHealth` | [src/ServerScriptService/MiniGames/Games/BaseSentry.lua](src/ServerScriptService/MiniGames/Games/BaseSentry.lua) | `100` | Starting HP for the Mini-Vault Core. |
| `turretRange` | [src/ServerScriptService/MiniGames/Games/BaseSentry.lua](src/ServerScriptService/MiniGames/Games/BaseSentry.lua) | `18` | Sentry acquisition and firing radius in studs. |
| `tier1FireRate` / `tier2FireRate` | [src/ServerScriptService/MiniGames/Games/BaseSentry.lua](src/ServerScriptService/MiniGames/Games/BaseSentry.lua) | `0.60s` / `0.35s` | Heartbeat cooldown between turret shots. |
| `tier1Damage` / `tier2Damage` | [src/ServerScriptService/MiniGames/Games/BaseSentry.lua](src/ServerScriptService/MiniGames/Games/BaseSentry.lua) | `14` / `25` | Damage dealt per projectile hit. |
| `relicChance` | [src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau](src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau) | `0.15` | Probability of receiving an Ancient Relic upon completion. |
| `fragmentChance` | [src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau](src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau) | `0.10` | Probability of receiving a Star Fragment upon completion. |

### Maintenance & Debugging Tips
1. **Enemy Cleanup on Early Termination**: In `BaseSentry:Stop()`, all living enemies are marked dead and their parts destroyed to prevent lingering parts in Workspace.
2. **Heartbeat Disconnection**: All `RunService.Heartbeat` sentry firing connections are stored in `self.connections` and cleanly disconnected during `Stop()`.
3. **Core HP Alert Threshold**: When core HP drops below $30\%$, the BillboardGui turns crimson to signal critical danger.
