# Player Base System Instructions

This document specifies the design, mechanics, configuration, and future extensibility for the **4-Player Base System** in the Coin Collector game.

---

## 🏰 Overview

The game supports up to 4 players simultaneously, each having their own dedicated, enclosed, and maintained base situated outside the central coin arena in one of the 4 cardinal directions:

| Base ID | Direction | Theme Name | Primary Color | Accent Color |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **North** | Sapphire | Royal Blue (`41, 128, 185`) | Sky Blue (`52, 152, 219`) |
| **2** | **South** | Emerald | Forest Green (`39, 174, 96`) | Mint Green (`46, 204, 113`) |
| **3** | **East** | Amber | Rust Orange (`230, 126, 34`) | Golden Amber (`243, 156, 18`) |
| **4** | **West** | Amethyst | Deep Purple (`142, 68, 173`) | Lavender (`155, 89, 182`) |

Each base is an independent compound expanded to **3 times its original size** ($84 \times 84$ studs, over 7,000 sq studs of space).

**Important Architecture Note (No Default Walls)**:
Bases start as **open platforms without perimeter walls**. Players must build up their walls later as they collect money, bank coins, and complete tasks. The low border curb clearly outlines the boundary of the lot while keeping the space completely open and unobstructed for early gameplay and future task expansions.

---

## 🎮 Core Mechanics & Player Compound Layout

### 1. 3x Spacious Open Compound Layout ($84 \times 84$ Studs)
Each base is zoned into functional open activity areas:
- **Entrance Courtyard**: Wide 16-stud walkway with dedicated signpost connecting directly to the central arena highway.
- **Arena Activation Pad (`ArenaActivatePad`)**: Interactive cylindrical launchpad at the front courtyard used by the base owner to start their solo arena run.
- **Central Core (`ClaimPad`)**: 12-stud golden interactive cylinder with concentric circular floor rings.
- **Banking Wing (`CoinBank`)**: Diamond-plate vault terrace on the left wing for coin deposits and leveling.
- **Activity Zone Alpha**: Dedicated $18 \times 18$ stud interactive task courtyard on the right front yard.
- **Activity Zone Beta**: Dedicated $18 \times 18$ stud interactive task courtyard on the left front yard.
- **Workshop Yard Gamma**: Expansive $18 \times 18$ stud open area for future crafting, powerups, or pets.
- **Spawning Sanctuary (`BaseSpawn`)**: Rear sanctuary area with dedicated player spawn pad.

*(Note: The freestanding wall bottom stats display has been removed to preserve the clean, open compound layout. Base stats are directly inspectable via model attributes).*

### 2. Solo Arena Activation from Base Pad
- Only the **base owner** can step on their base's `ArenaActivatePad` to initiate an arena run.
- Stepping on the pad checks if the central arena is free:
  - If free: The pad activates, opening **only this base's gate** into the arena and starting the 30-second countdown.
  - While active: The active player's pad displays `RUN IN PROGRESS [Arena Active]`, and all other player pads turn red and display `ARENA OCCUPIED [[PlayerName] Playing]` (disabled, `CanTouch = false`).
- No other player can enter the arena through the active player's gate. If another player tries to walk through, the security sensor detects them and teleports them back to their home base spawn pad.
- **Round Completion, Player Ejection & Immediate Door Closure**:
  - When the run ends (all coins collected or 30s timer expired), the active runner is immediately **ejected back to their home base spawn pad** (without killing/reloading character), and any remaining players inside the arena are ejected to their home bases or nearest gate exterior approach pathways.
  - The arena door **closes immediately upon ejection** and locks.
  - **Runner Base Activation Plate Deactivated**: The ejected runner's base activation plate is **not left active or enabled**. It immediately switches to cooldown (`RunnerCooldown`, default 10s), disabling touches (`CanTouch = false`) and displaying `COOLDOWN [Xs] [Other Players First]` in yellow.
  - **Immediate Opportunity for Other Players**: Other waiting players' base activation plates are **immediately enabled** (`CanTouch = true`, green `⚡ START ARENA RUN ⚡`), allowing any other player to step on their pad and start their base's arena run right away.
  - The arena never reopens automatically: an eligible player must step on their activation pad to initialize the next entry.

### 3. Wall Construction System (Build Later via Tasks & Coins)
- Bases start with `HasWalls = false` (attribute on the base model).
- The `PlayerBase` class provides modular methods:
  - `base:BuildWalls(customWallHeight, customWallColor)`: Constructs the full perimeter walls with an entrance arch when the player unlocks or purchases them.
  - `base:ClearWalls()`: Removes walls if reset or upgraded.
- Future tasks, tycoon-style buttons, or coin milestones can call `base:BuildWalls()` when the player earns enough money.

### 4. Spawning & Initial Assignment
- The experience supports up to 4 players matching the 4 directional bases (North, South, East, West).
- When new or unclaimed players join or spawn, they are placed at a randomly selected vacant/unclaimed base.
- Claimed bases disable their native `SpawnLocation` pad (`Enabled = false`) so that unowned players cannot natively spawn inside another player's claimed territory.
- When an owned player respawns after resetting or being defeated, they are positioned directly at their own base spawn pad (`ownedBase:GetSpawnCFrame()`).
- If all 4 bases are claimed and an unclaimed player joins/spawns, they are safely placed outside the arena gates as a fallback.

### 5. Claiming Base Ownership
- Each base has a glowing circular **Claim Pad** in the center (`ClaimPad`).
- Unclaimed bases display `[ Unclaimed ]` and `★ STEP TO CLAIM BASE ★`.
- Stepping onto an unclaimed base's pad immediately claims it for that player.
- The entrance sign updates to display `[PlayerName]'s Base` and the claim pad switches to the player's base theme color.
- **Single Base Claim per Session**: A player can only claim a base once per session. Stepping on another base's claim pad is silently ignored. Once claimed, the player cannot switch bases until they have left the experience completely and returned.
- When a player leaves the game (`PlayerRemoving`), their base is automatically cleared and made available for other players.

### 6. Extensible Vault Storage System & Banking Progression
- On the left interior of each base sits a **Coin Bank / Vault** (`CoinBank`).
- **Interactive ProximityPrompt & Step Deposit**:
  - Stepping onto the bank pad deposits carried coins and automatically opens the Vault UI modal (throttled by a 1.5-second debounce).
  - Interacting with the dedicated `ProximityPrompt` (`[E]` key or tap on mobile, labeled *"Open Vault"*) directly opens the Vault UI modal at any time.
- **Deposit & Level Progression**:
  - All coins currently carried in `leaderstats.Coins` are deposited into the player's persistent vault (`VaultService.AddItem(player, "Coins", amount)`).
  - Base level scales dynamically with total banked coins:
    $$\text{Base Level} = 1 + \left\lfloor \frac{\text{Banked Coins}}{50} \right\rfloor$$
  - Base level grants a permanent coin multiplier:
    $$\text{Coin Multiplier} = 1.0 + (\text{Base Level} - 1) \times 0.1$$
  - Claiming a base restores the player's level and multiplier based on their stored coins.
  - Clearing a base on leave cleanly resets base performance metrics.
- **Extensible Item Registry ([src/ReplicatedStorage/VaultItemRegistry.lua](src/ReplicatedStorage/VaultItemRegistry.lua))**:
  - Standardized item schema: `id`, `displayName`, `category`, `description`, `icon`, `rarity` ("Common", "Rare", "Epic", "Legendary"), `order`.
  - Built-in items: Gold Coins (`Coins`), Precious Gems (`Gems`), Ancient Relic (`AncientRelic`), and Star Fragment (`StarFragment`).
  - Modular item registration via `VaultItemRegistry.RegisterItem(itemDef)` for upcoming expansions, drops, and craftables.
- **Server Persistence ([src/ServerScriptService/VaultService.lua](src/ServerScriptService/VaultService.lua))**:
  - Backed by `DataStoreService` (`PlayerVaultStore_v1`) wrapped in safe `pcall` operations.
  - Automatically falls back to resilient in-memory storage when DataStore access is unavailable or offline in Studio/testing.
  - Saves on player disconnect and server shutdown via `game:BindToClose`.
- **Client HUD ([src/StarterPlayer/StarterPlayerScripts/VaultHUD.client.lua](src/StarterPlayer/StarterPlayerScripts/VaultHUD.client.lua))**:
  - Responsive modal card displaying stored items, categorized badges, rarity-coded labels, and live formatted quantities.
  - Opened via proximity prompt, step-to-deposit, or remote event; dismissable via `[X]` button, dark backdrop tap, or the Escape key.

### 6.1 Vault Economy & Modular Storage Management Guide
The vault system provides a data-driven economy backbone managed through [src/ReplicatedStorage/VaultItemRegistry.lua](src/ReplicatedStorage/VaultItemRegistry.lua) and persisted server-side via [src/ServerScriptService/VaultService.lua](src/ServerScriptService/VaultService.lua).

#### Item Definition & Economy Schema
Each item registered in the system defines properties governing both UI presentation and economy mechanics:
- `enabled` (boolean): Controls player-facing availability. Items with `enabled = true` appear in the player's Vault HUD and live interactions. Items with `enabled = false` are hidden from the UI but remain registered and valid in underlying data storage.
- `baseSellPrice` (optional number): Benchmark currency value in gold coins when selling or trading this item to NPCs or shops.
- `storageCap` (optional number): Maximum stack capacity permitted in a player's vault slot to prevent hyperinflation.
- `tradeable` (boolean): Flags whether the asset can be transferred between players in peer-to-peer trading.

#### Current Item Status & Unreleased Items
Currently, only base currency is enabled for active gameplay:
- **Gold Coins (`Coins`)**: `enabled = true`, `baseSellPrice = 1`, `storageCap = 1,000,000`, `tradeable = false`.
- **Precious Gems (`Gems`)**: `enabled = false`, `baseSellPrice = 50`, `storageCap = 50,000`, `tradeable = true`.
- **Ancient Relic (`AncientRelic`)**: `enabled = false`, `baseSellPrice = 250`, `storageCap = 100`, `tradeable = true`.
- **Star Fragment (`StarFragment`)**: `enabled = false`, `baseSellPrice = 1,000`, `storageCap = 25`, `tradeable = true`.

Unreleased items (Gems, Ancient Relics, and Star Fragments) are pre-registered with complete metadata and economy properties, but hidden from the player's Vault HUD via `VaultItemRegistry.GetEnabledItems()`.

#### Developer Guide: Activating Items & Economy Tuning
Developers can release items or adjust game balance with zero UI or network code changes:
1. **Activating an Item**: In [src/ReplicatedStorage/VaultItemRegistry.lua](src/ReplicatedStorage/VaultItemRegistry.lua), change `enabled = false` to `enabled = true` (or call `VaultItemRegistry.SetItemEnabled(itemId, true)` dynamically). The Vault HUD automatically queries `GetEnabledItems()` and renders the new item card on next open.
2. **Rebalancing Economy Caps & Values**: Adjust `baseSellPrice` or `storageCap` directly in the item definition table.
3. **Adding New Items**: Call `VaultItemRegistry.RegisterItem({ ... })` with the standardized schema.

#### Future Integration Points
- **NPC Merchants & Shopkeepers**: Read `item.baseSellPrice` to dynamically populate buy/sell menus in base workshop courtyards.
- **Coin Sinks & Crafting**: Consume high-tier materials (e.g., Star Fragments, Relics) along with banked coins to unlock permanent base perks and defensive structures.
- **Peer-to-Peer Trading Hub**: Filter candidate trade inventory using `item.tradeable == true` to prevent exploits or unauthorized transfer of core progression currencies.

---

## 🚪 Ejection Points & Post-Ejection Pathing

When the central coin collection arena in the middle of the map is cleared and all 4 gates lock:
1. The server detects every player currently inside the central coin collection area.
2. Players with an owned base are teleported directly back to their home base spawn pad (`ownedBase:GetSpawnCFrame()`), with linear and angular velocities reset to zero.
3. Any unassigned players or intruders without a base are safely ejected just outside the nearest arena gate along the approach highway facing away from the arena.
4. Players can immediately deposit coins into their bank vault, upgrade their multiplier, and await the next round!

---

## ⚙️ Configuration & Live Attributes

All base dimensions, distances, and starting variables can be tuned in [src/ReplicatedStorage/CoinConfig.lua](src/ReplicatedStorage/CoinConfig.lua) and live via attributes on `ReplicatedStorage.CoinSettings`:

| Attribute / Config | Default | Description |
| :--- | :--- | :--- |
| `CoinExpirationTime` | `30` | Seconds a player has to claim coins in the arena before coins expire and gates lock |
| `RunnerCooldown` | `10` | Seconds cooldown applied to the last active runner before they can trigger the arena again |
| `RespawnActiveRunnerOnFinish` | `true` | When true, only the active runner is respawned at their base upon run end |
| `BaseDistance` | `140` | Studs from arena center $(0,0,0)$ to the center of each player base (spacious separation) |
| `BaseSize` | `84` | Dimensions of each player base platform (expanded 3x from 28 to 84 studs) |
| `BaseWallHeight` | `9` | Wall height when constructed by player via tasks/upgrades |
| `BaseEjectionDistance` | `54` | Distance fallback from arena center for gate approach clearance |
| `BaseStartingLevel` | `1` | Default starting level for newly claimed bases |
| `BaseStartingMultiplier`| `1.0` | Default multiplier applied to coins collected by base owners |
| `BaseBankCapacity` | `500` | Starting maximum storage limit for base vaults |
| `BaseWallCost` | `150` | Default coin requirement to build perimeter walls |

### Live Model Attributes on Each Base
Each base model (`PlayerBase_1_North`, etc.) in `Workspace.PlayerBases` has inspectable attributes:
- `OwnerUserId` (number)
- `OwnerName` (string)
- `BaseLevel` (number)
- `BankedCoins` (number)
- `CoinMultiplier` (number)
- `PerformanceScore` (number)
- `TotalEarned` (number)
- `HasWalls` (boolean) - `false` initially, becomes `true` when walls are constructed

---

## 🛠️ Future Extensibility Guide

The base class is modularly implemented in [src/ReplicatedStorage/PlayerBase.lua](src/ReplicatedStorage/PlayerBase.lua).

### Adding Base Upgrades (e.g. Speed Pads, Turrets, Walls)
You can attach new upgrade purchase pads or decor elements directly inside `PlayerBase:Build(parent)`:

```lua
-- Example: Adding an upgrade trigger to PlayerBase:Build
local speedPad = Instance.new("Part")
speedPad.Name = "SpeedBooster"
speedPad.Size = Vector3.new(4, 0.4, 4)
speedPad.CFrame = baseCFrame * CFrame.new(0, 0.5, -halfSize + 12)
speedPad.Parent = model

speedPad.Touched:Connect(function(hit)
    local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
    if humanoid and self.owner and hit.Parent.Name == self.owner.Name then
        humanoid.WalkSpeed = 24 -- Temporary or permanent speed boost
    end
end)
```

### Modifying Banking & Progression Formulas
To customize how coins level up bases or calculate multipliers, adjust `base:OnBank(...)` inside [src/ServerScriptService/CoinCollector.server.lua](src/ServerScriptService/CoinCollector.server.lua#L235-L260):

```lua
-- Custom banking curve:
local newLevel = 1 + math.floor(math.sqrt(newBanked / 25))
local newMultiplier = 1.0 + (newLevel - 1) * 0.15
```
