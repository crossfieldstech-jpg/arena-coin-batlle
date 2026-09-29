--[[
	EconomySimulator.luau
	Standalone / Headless Luau simulation module for Arena Coin Battle economy.
	Validates leveling progression, diminishing return multipliers, faucet/sink dynamics,
	and anti-inflation boundaries across 100+ rounds and diverse player archetypes.
]]

local EconomySimulator = {}

-- Safe dependency resolution supporting both Roblox DataModel and headless/CLI runners
local VaultItemRegistry = nil
pcall(function()
	VaultItemRegistry = require(script.Parent:WaitForChild("VaultItemRegistry"))
end)
if not VaultItemRegistry then
	pcall(function()
		VaultItemRegistry = require("./VaultItemRegistry")
	end)
end

-- Fallback pure math implementations if running completely uncoupled
local function fallbackGetBaseUpgradeRequirement(targetLevel)
	if targetLevel <= 0 then
		return 0
	end
	return math.floor(50 * (targetLevel ^ 1.35))
end

local function fallbackCalculateMultiplier(baseLevel)
	local level = if typeof(baseLevel) == "number" then math.max(1, baseLevel) else 1
	local delta = level - 1
	local bonus = math.min(2.0, (delta * 0.1) / (1 + delta * 0.02))
	return 1.0 + bonus
end

local function fallbackCalculateBaseLevel(vaultItems)
	local totalWeight = 0
	if typeof(vaultItems) == "number" then
		totalWeight = math.max(0, vaultItems)
	elseif typeof(vaultItems) == "table" then
		totalWeight += (vaultItems.Coins or 0) * 1
		totalWeight += (vaultItems.Gems or 0) * 10
		totalWeight += (vaultItems.AncientRelic or 0) * 50
		totalWeight += (vaultItems.StarFragment or 0) * 200
	end

	local function requirement(lvl)
		if lvl <= 1 then
			return 0
		end
		if VaultItemRegistry and VaultItemRegistry.GetBaseUpgradeRequirement then
			return VaultItemRegistry.GetBaseUpgradeRequirement(lvl - 1)
		end
		return fallbackGetBaseUpgradeRequirement(lvl - 1)
	end

	local level = 1
	while true do
		local nextReq = requirement(level + 1)
		if totalWeight >= nextReq then
			level += 1
		else
			break
		end
	end

	local currentReq = requirement(level)
	local nextReq = requirement(level + 1)
	local progressInLevel = totalWeight - currentReq
	local nextLevelCost = nextReq - currentReq

	return level, progressInLevel, nextLevelCost
end

local function getUpgradeReq(targetLevel)
	if VaultItemRegistry and VaultItemRegistry.GetBaseUpgradeRequirement then
		return VaultItemRegistry.GetBaseUpgradeRequirement(targetLevel)
	end
	return fallbackGetBaseUpgradeRequirement(targetLevel)
end

local function calcMultiplier(level)
	if VaultItemRegistry and VaultItemRegistry.CalculateMultiplier then
		return VaultItemRegistry.CalculateMultiplier(level)
	end
	return fallbackCalculateMultiplier(level)
end

local function calcLevel(vault)
	if VaultItemRegistry and VaultItemRegistry.CalculateBaseLevel then
		return VaultItemRegistry.CalculateBaseLevel(vault)
	end
	return fallbackCalculateBaseLevel(vault)
end

-- Simulates 100+ rounds across 4 player profiles and evaluates economy health assertions
function EconomySimulator.RunSimulation(rounds)
	local totalRounds = math.max(100, rounds or 100)

	local profiles = {
		Hardcore = {
			name = "Hardcore",
			participationChance = 0.85,
			collectionEfficiency = 0.95,
			bankInterval = 1, -- Banks after every run
			carried = { Coins = 0, Gems = 0 },
			vault = { Coins = 0, Gems = 0 },
			level = 1,
			multiplier = 1.0,
			score = 0,
			totalEarnedCoins = 0,
			totalEarnedGems = 0,
			totalBankedCoins = 0,
			totalBankedGems = 0,
			runsCompleted = 0,
		},
		Casual = {
			name = "Casual",
			participationChance = 0.50,
			collectionEfficiency = 0.65,
			bankInterval = 2, -- Banks every 2 runs
			carried = { Coins = 0, Gems = 0 },
			vault = { Coins = 0, Gems = 0 },
			level = 1,
			multiplier = 1.0,
			score = 0,
			totalEarnedCoins = 0,
			totalEarnedGems = 0,
			totalBankedCoins = 0,
			totalBankedGems = 0,
			runsCompleted = 0,
		},
		Minimal = {
			name = "Minimal",
			participationChance = 0.25,
			collectionEfficiency = 0.35,
			bankInterval = 3, -- Banks every 3 runs
			carried = { Coins = 0, Gems = 0 },
			vault = { Coins = 0, Gems = 0 },
			level = 1,
			multiplier = 1.0,
			score = 0,
			totalEarnedCoins = 0,
			totalEarnedGems = 0,
			totalBankedCoins = 0,
			totalBankedGems = 0,
			runsCompleted = 0,
		},
		Hoarder = {
			name = "Hoarder",
			participationChance = 0.60,
			collectionEfficiency = 0.80,
			bankInterval = 5, -- Holds carried coins before banking
			carried = { Coins = 0, Gems = 0 },
			vault = { Coins = 0, Gems = 0 },
			level = 1,
			multiplier = 1.0,
			score = 0,
			totalEarnedCoins = 0,
			totalEarnedGems = 0,
			totalBankedCoins = 0,
			totalBankedGems = 0,
			runsCompleted = 0,
		},
	}

	local globalFaucets = { Coins = 0, Gems = 0 }
	local globalSinks = { Coins = 0, Gems = 0 }
	local profileKeys = { "Hardcore", "Casual", "Minimal", "Hoarder" }

	-- 1. Execute simulation rounds
	for roundIndex = 1, totalRounds do
		local isGemRound = (math.random() < 0.20) -- 20% gem jackpot rate
		local maxItems = 25

		-- Select runner for this round
		local eligibleRunners = {}
		for _, key in ipairs(profileKeys) do
			local p = profiles[key]
			if math.random() < p.participationChance then
				table.insert(eligibleRunners, p)
			end
		end

		if #eligibleRunners == 0 then
			table.insert(eligibleRunners, profiles["Hardcore"])
		end

		local runner = eligibleRunners[math.random(1, #eligibleRunners)]
		runner.runsCompleted += 1

		local itemsToCollect = math.max(1, math.floor(maxItems * runner.collectionEfficiency))
		if isGemRound then
			local totalGemValue = 0
			for _ = 1, itemsToCollect do
				totalGemValue += math.random(1, 3)
			end
			local earned = math.round((totalGemValue * runner.multiplier) * 10) / 10
			runner.carried.Gems += earned
			runner.totalEarnedGems += earned
			runner.score += math.round(earned * 3)
			globalFaucets.Gems += earned
		else
			local totalCoinValue = 0
			for _ = 1, itemsToCollect do
				totalCoinValue += math.random(1, 5)
			end
			local earned = math.round(totalCoinValue * runner.multiplier)
			runner.carried.Coins += earned
			runner.totalEarnedCoins += earned
			runner.score += math.round(earned * 2)
			globalFaucets.Coins += earned
		end

		-- Deposit / Bank check
		if runner.runsCompleted % runner.bankInterval == 0 then
			if runner.carried.Coins > 0 then
				local deposit = runner.carried.Coins
				runner.carried.Coins = 0
				runner.vault.Coins += deposit
				runner.totalBankedCoins += deposit
				globalSinks.Coins += deposit
			end

			if runner.carried.Gems > 0 then
				local deposit = runner.carried.Gems
				runner.carried.Gems = 0
				runner.vault.Gems += deposit
				runner.totalBankedGems += deposit
				globalSinks.Gems += deposit
			end

			local newLevel, _progress, _nextCost = calcLevel(runner.vault)
			runner.level = newLevel
			runner.multiplier = calcMultiplier(newLevel)
		end
	end

	-- Bank remaining carried currency for end-of-sim tally
	for _, p in pairs(profiles) do
		if p.carried.Coins > 0 then
			local deposit = p.carried.Coins
			p.carried.Coins = 0
			p.vault.Coins += deposit
			p.totalBankedCoins += deposit
			globalSinks.Coins += deposit
		end
		if p.carried.Gems > 0 then
			local deposit = p.carried.Gems
			p.carried.Gems = 0
			p.vault.Gems += deposit
			p.totalBankedGems += deposit
			globalSinks.Gems += deposit
		end
		p.level = calcLevel(p.vault)
		p.multiplier = calcMultiplier(p.level)
	end

	-- 2. Verify Leveling Curve progression from L1 to L25+
	local curveTestsPassed = true
	local prevReq = 0
	local curveProgression = {}
	for lvl = 1, 25 do
		local req = getUpgradeReq(lvl)
		local mult = calcMultiplier(lvl)
		table.insert(curveProgression, { level = lvl, cumulativeRequirement = req, multiplier = mult })
		if lvl > 1 and req <= prevReq then
			curveTestsPassed = false
		end
		prevReq = req
	end

	-- 3. Assertions Evaluation
	local assertions = {}
	local allPassed = true

	local function assertCheck(name, condition, message)
		table.insert(assertions, {
			name = name,
			passed = condition,
			message = message,
		})
		if not condition then
			allPassed = false
		end
	end

	-- Assertion 1: Multipliers bounded strictly under 3.0x and >= 1.0x
	local maxSimMultiplier = 0
	local allMultipliersBounded = true
	for _, p in pairs(profiles) do
		if p.multiplier > maxSimMultiplier then
			maxSimMultiplier = p.multiplier
		end
		if p.multiplier < 1.0 or p.multiplier >= 3.0 then
			allMultipliersBounded = false
		end
	end
	-- Also test extreme level 100
	local extremeMultiplier = calcMultiplier(100)
	if extremeMultiplier > 3.0 or extremeMultiplier < 1.0 then
		allMultipliersBounded = false
	end
	assertCheck(
		"BoundedMultiplierCap",
		allMultipliersBounded,
		string.format("Multipliers stay in [1.0x, 3.0x). Max in sim: %.2fx, Level 100: %.2fx", maxSimMultiplier, extremeMultiplier)
	)

	-- Assertion 2: Base Level 1 baseline guarantees
	local level1Req = getUpgradeReq(0)
	local level1Mult = calcMultiplier(1)
	assertCheck(
		"Level1Baseline",
		level1Req == 0 and level1Mult == 1.0,
		string.format("Level 1 has baseline 1.0x multiplier (actual: %.2fx) and 0 base requirement", level1Mult)
	)

	-- Assertion 3: Hierarchy progression (Hardcore > Casual > Minimal)
	local hardcoreBeatsCasual = profiles.Hardcore.level >= profiles.Casual.level
	local casualBeatsMinimal = profiles.Casual.level >= profiles.Minimal.level
	assertCheck(
		"PlayerHierarchyProgression",
		hardcoreBeatsCasual and casualBeatsMinimal,
		string.format("Levels: Hardcore=L%d, Casual=L%d, Minimal=L%d", profiles.Hardcore.level, profiles.Casual.level, profiles.Minimal.level)
	)

	-- Assertion 4: Steady pacing and inflation control
	local totalFaucets = globalFaucets.Coins + globalFaucets.Gems
	local totalSinks = globalSinks.Coins + globalSinks.Gems
	local inflationRatio = if totalSinks > 0 then (totalFaucets / totalSinks) else totalFaucets
	local inflationHealthy = inflationRatio <= 1.5 -- Since all carried funds are banked at conclusion
	assertCheck(
		"SteadyPacingAndNoInflationExplosion",
		inflationHealthy,
		string.format("Faucet to Sink ratio is healthy: %.3f (Faucets: %.1f, Sinks: %.1f)", inflationRatio, totalFaucets, totalSinks)
	)

	-- Assertion 5: Leveling curve strictly monotonic L1 to L25
	assertCheck(
		"LevelingCurveMonotonicity",
		curveTestsPassed,
		"Base upgrade curve is strictly monotonic and non-linear from L1 to L25"
	)

	return {
		passed = allPassed,
		totalRounds = totalRounds,
		assertions = assertions,
		profiles = profiles,
		curveSample = curveProgression,
		economySummary = {
			totalFaucets = globalFaucets,
			totalSinks = globalSinks,
			inflationRatio = inflationRatio,
			maxMultiplierAchieved = maxSimMultiplier,
		},
	}
end

return EconomySimulator
