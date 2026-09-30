# Alien Base Defence Mini-Game Specification

A tactical military tower defense mini-game situated on an expanded $108 \times 108$ stud Sky Sub-Arena field at $Y=400$. Players command frontline soldier bunker towers and heavy plasma batteries across an overgrown battlefield with rolling mounds and trees to defend their Outpost Command Core against 3 waves of encroaching alien swarms.

---

## 📋 Game Metadata

| Field | Value |
| :--- | :--- |
| **Identifier** | `AlienBaseDefence` *(alias: `BaseSentry`)* |
| **Display Name** | Alien Base Defence |
| **Category** | Tower Defense |
| **Icon** | 🪖 |
| **Duration** | 95 seconds (3 waves) |
| **Core Health** | 100 HP |
| **Platform Size** | $108 \times 108$ studs (doubled scale) |
| **Order Index** | 2 |
| **Source Implementation** | [src/ServerScriptService/MiniGames/Packages/AlienBaseDefence/Server.luau](src/ServerScriptService/MiniGames/Packages/AlienBaseDefence/Server.luau) |
| **Catalog Registration** | [src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau](src/ReplicatedStorage/MiniGames/MiniGameRegistry.luau) |

---

## ⚙️ Battlefield Map & Wave Mechanics

The expanded $108 \times 108$ sky battlefield features an overgrown grassy field, 12 rolling earthen mounds, 14 pine/field trees, defensive sandbag barricades, rock clusters, and a long snaking dirt road traversed by alien swarms toward the fortified Outpost Command Center.

### Tactical Defense Stations
Players walk up to 5 strategic concrete defense pads fortified with sandbag rings and interact via `ProximityPrompt`:

| Tier | Name | Visual | Range | Fire Rate | Damage / Shot | Interaction |
| :---: | :--- | :--- | :---: | :---: | :---: | :--- |
| **0** | Defense Pad | Concrete ring with sandbag perimeter | — | — | — | `"Deploy Soldier Bunker [E]"` |
| **1** | Soldier Bunker | Camo-drab bunker with armed soldier guard & rifle | 24 studs | 0.45s | 16 HP | `"Upgrade to Heavy Plasma Bunker [E]"` |
| **2** | Heavy Plasma Bunker | Heavy armored fortification with dual glowing plasma cannons & energy shield | 28 studs | 0.25s | 30 HP | Max upgrade reached (Prompt disabled) |

- **Targeting System**: Every `Heartbeat`, active stations track and engage the nearest living alien swarm unit within range.
- **Visual FX**: Fires high-velocity tracer and plasma beams with dynamic muzzle flashes and automatic 0.08s beam cleanup.

---

## 👽 Alien Swarms & Wave Breakdown

Enemies navigate sequentially through 9 waypoints across the $108 \times 108$ field using `TweenService`. If an alien reaches the Outpost Command Core, it breaches and detonates, damaging outpost integrity.

### Alien Swarm Archetypes
| Archetype | Name | HP | Speed | Visual Theme | Outpost Damage | Behavior |
| :--- | :--- | :---: | :---: | :--- | :---: | :--- |
| **Scout** | Alien Swarmer | 40 | 15 studs/s | Acid Green Neon (`#2ECC71`), Carapace & Antennae | 15 HP | Agile insectoid runner designed to rush past unupgraded stations. |
| **Armored** | Alien Warrior | 90 | 11 studs/s | Purple Spiked Chitin (`#9B59B6`), Glowing Carapace | 20 HP | Heavily armored brute absorbing substantial fire before falling. |
| **Boss** | Alien Behemoth | 280 | 7.5 studs/s | Fiery Orange/Red Core (`#E67E22`), Massive Horns | 40 HP | Colossal alien juggernaut capable of inflicting devastating base damage. |

### Progressive Wave Schedule
- **Wave 1**: 6 Alien Swarmers (spawn interval: 2.0s). Tests early frontline bunker placement.
- **Wave 2**: 8 Mixed Swarmers & Alien Warriors (spawn interval: 1.8s). Requires perimeter defense and upgrades.
- **Wave 3**: 1 Alien Behemoth boss followed by 6 Alien Warriors (interval: 2.0s). Demands multiple Heavy Plasma Bunkers to prevent outpost collapse.

---

## 💰 Rewards & Arena Buffs

### Reward Payout Table
| Reward Item | Base Quantity | Multiplier Scaling | Drop Chance |
| :--- | :--- | :--- | :--- |
| **Coins** | 60 – 130 | Scaled by final score multiplier ($\text{HP}\% \times 0.8 + 0.5$) | 100% |
| **Gems** | 1.0 – 3.0 | Scaled by final score multiplier | 100% |
| **Ancient Relic** | 1 | Independent percentage roll | 20% |
| **Star Fragment** | 1 | Independent percentage roll | 10% |

### Next-Run Central Arena Buff
- **Buff ID**: `AlienBaseDefence_Buff` *(alias: `BaseSentry_TimeBuff`)*
- **Buff Name**: **Orbital Recon Boost** (🛸)
- **Buff Effect**: Grants $+6$ seconds of extra time on the player's next Central Arena coin run.
