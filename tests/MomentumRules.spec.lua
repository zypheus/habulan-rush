--!strict
-- tests/MomentumRules.spec.lua
-- Owner: Project Owner
-- Responsibility: Studio command bar assertions for pure momentum math.
-- Task/spec: momentum steps 1 to 4, 2026-10-19.
-- Task/spec: slide chaining and entry speed, 2026-10-19.
-- Run after syncing MomentumRules and Config from this repository.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local rules = require(ReplicatedStorage:WaitForChild("MomentumRules"))
local tuning = Config.Momentum

local function near(actual: number, expected: number)
	assert(math.abs(actual - expected) < 0.0001, string.format("%.4f ~= %.4f", actual, expected))
end

local sprintSpeed = Config.Movement.RunnerSprintSpeed * Config.Movement.SpeedScale
local threshold = sprintSpeed * tuning.SlideMinSpeedPct
local function awardSlide(value: number, previousAt: number, previousCount: number, now: number, speed: number): (number, number, number)
	if not rules.slideEligible(speed, sprintSpeed) then return value, 0, previousCount end
	return rules.gain(value, tuning.GainSlide, previousAt, previousCount, now)
end

local value, gain, count = awardSlide(0, -math.huge, 0, 10, threshold)
near(value, 1.5)
near(gain, 1.5)
assert(count == 1)

-- Both MovementAuthority and MovementController call this eligibility rule
-- before awarding or predicting the same slide gain.
assert(not rules.slideEligible(0, sprintSpeed), "a standing slide cannot earn momentum")
assert(not rules.slideEligible(threshold - 0.01, sprintSpeed), "a slow slide cannot earn momentum")
assert(rules.slideEligible(threshold, sprintSpeed), "the exact threshold must earn momentum")
assert(rules.slideEligible(threshold + 0.01, sprintSpeed), "a fast slide must earn momentum")
assert(not rules.slideEligible(0 / 0, sprintSpeed), "invalid observed speed must not earn momentum")
local slowValue, slowGain, slowCount = awardSlide(value, 10, count, 10.5, threshold - 0.01)
near(slowValue, value)
near(slowGain, 0)
assert(slowCount == count, "slow slide must not use a diminishing count")
local serverValue, serverGain, serverCount = awardSlide(0, -math.huge, 0, 10, threshold)
local clientValue, clientGain, clientCount = awardSlide(0, -math.huge, 0, 10, threshold)
near(serverValue, clientValue)
near(serverGain, clientGain)
assert(serverCount == clientCount, "both sides must use the same slide count")

value, gain, count = awardSlide(value, 10, count, 11, threshold)
near(gain, 0.9)
assert(count == 2)
value, gain, count = awardSlide(value, 11, count, 12, threshold)
near(gain, 0.45)
assert(count == 3)
value, gain, count = awardSlide(value, 12, count, 15, threshold)
near(gain, 1.5)
assert(count == 1)

local chainCount = rules.nextChainCount(0, -math.huge, 10)
assert(chainCount == 1, "first slide starts a chain")
chainCount = rules.nextChainCount(chainCount, 10, 11)
assert(chainCount == 2, "roll inside ChainWindow extends the slide chain")
assert(rules.nextChainCount(chainCount, 11, 11 + tuning.ChainWindow + 0.01) == 1,
	"chain resets after the window")

-- Prediction does not request HUD feedback; only a new confirmed server
-- sequence can request a slide popup. A repeated snapshot cannot duplicate it.
local popupRequests = 0
local popupValue, popupSequence = 0, 0
for _, packet in {
	{ sequence = 1, value = 0, action = nil },
	{ sequence = 2, value = tuning.GainSlide, action = "Slide" },
	{ sequence = 2, value = tuning.GainSlide, action = "Slide" },
} do
	local accepted
	popupValue, popupSequence, accepted = rules.reconcile(popupValue, popupSequence, packet.value, packet.sequence)
	if accepted and packet.action == "Slide" then popupRequests += 1 end
end
assert(popupRequests == 1, "one confirmed slide requests one popup")

value, gain = rules.gain(5.8, tuning.GainRollPerfect, -math.huge, 0, 20)
near(value, tuning.Cap)
near(gain, 0.2)

near(rules.decay(5, 10, 10, 10.5, true), 5)
near(rules.decay(5, 10, 10.5, 11, true), 5 - 0.25 * tuning.DecayMoving)
near(rules.decay(5, 10, 10.5, 11, false), 5 - 0.25 * tuning.DecayIdle)
near(rules.decay(1, 10, 11, 12, false), 0)

assert(rules.tier(0) == 0)
assert(rules.tier(tuning.Cap * 0.25) == 1)
assert(rules.tier(tuning.Cap * 0.5) == 2)
assert(rules.tier(tuning.Cap * 0.85) == 3)
local sameTier, changedTier = rules.tierTransition(1, tuning.Cap * 0.4)
assert(sameTier == 1 and not changedTier, "tier attribute must not rewrite within a tier")
local higherTier, crossedTier = rules.tierTransition(1, tuning.Cap * 0.5)
assert(higherTier == 2 and crossedTier, "tier attribute must update on threshold crossing")
near(rules.speed(25.2, 1, 1, 1.5), 26.7)
near(rules.speed(25.2, 1.2, 1, 6), tuning.GlobalSpeedCeiling)
near(rules.speed(25.2, 1, 0.85, 1.5), 26.7 * 0.85)

assert(rules.intentFresh(10, 10.1, 0.4), "fresh intent must pass")
assert(not rules.intentFresh(10, 10.5, 0.4), "stale intent must fail")
assert(not rules.intentFresh(10.5, 10, 0.4), "future intent must fail")
assert(not rules.intentFresh(0 / 0, 10, 0.4), "spoofed NaN intent must fail")
assert(rules.perfectRoll(10, 10.04), "last 0.05 s intent must be perfect")
assert(not rules.perfectRoll(10, 10.1), "early intent must be normal")
assert(not rules.perfectRoll(10, 9.99), "post-landing intent must be normal")
local rollRequestAt, floorObservedAt = 10.04, 10.18
assert(rules.perfectRoll(10, rollRequestAt), "request interval must determine perfect status")
assert(not rules.perfectRoll(10, floorObservedAt), "late floor observation cannot substitute for request time")

-- The client and server call this same module. A locally predicted perfect
-- roll must yield to the server's normal-roll award.
local predicted = rules.gain(0, tuning.GainRollPerfect, -math.huge, 0, 20)
local authoritative = rules.gain(0, tuning.GainRoll, -math.huge, 0, 20)
local corrected, sequence, accepted = rules.reconcile(predicted, 2, authoritative, 3)
near(corrected, tuning.GainRoll)
assert(sequence == 3 and accepted, "new server snapshot must win")
corrected, sequence, accepted = rules.reconcile(corrected, sequence, 5, 2)
near(corrected, tuning.GainRoll)
assert(sequence == 3 and not accepted, "stale snapshot must not rewind prediction")
near(rules.speed(25.2, 1.2, 1, predicted), tuning.GlobalSpeedCeiling)
near(rules.speed(25.2, 1.2, 1, corrected), tuning.GlobalSpeedCeiling)
