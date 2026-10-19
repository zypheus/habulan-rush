--!strict
-- ReplicatedStorage/MomentumRules.lua
-- Owner: Project Owner
-- Responsibility: shared pure momentum gain, decay, tier, and speed math.
-- Task/spec: momentum slice 1, 2026-10-19.
-- Task/spec: momentum steps 2 to 4, intent and reconciliation math, 2026-10-19.
-- Task/spec: slide chaining and entry speed, 2026-10-19.

local Config = require(script.Parent:WaitForChild("Config"))
local tuning = Config.Momentum

local MomentumRules = {}

function MomentumRules.slideEligible(observedSpeed: number, sprintSpeed: number): boolean
	return observedSpeed == observedSpeed and math.abs(observedSpeed) < math.huge
		and sprintSpeed > 0 and observedSpeed >= sprintSpeed * tuning.SlideMinSpeedPct
end

function MomentumRules.nextChainCount(previousCount: number, previousAt: number, now: number): number
	return if now - previousAt <= tuning.ChainWindow then previousCount + 1 else 1
end

function MomentumRules.gain(value: number, baseGain: number, previousAt: number, previousCount: number, now: number): (number, number, number)
	local count = if now - previousAt <= tuning.DiminishWindow then previousCount + 1 else 1
	local multiplier = tuning.DiminishingMult[math.min(count, #tuning.DiminishingMult)]
	local nextValue = math.min(tuning.Cap, value + baseGain * multiplier)
	return nextValue, nextValue - value, count
end

function MomentumRules.decay(value: number, lastGainAt: number, previousAt: number, now: number, moving: boolean): number
	local activeSince = math.max(previousAt, lastGainAt + tuning.DecayGrace)
	local duration = math.max(0, now - activeSince)
	return math.max(0, value - duration * (if moving then tuning.DecayMoving else tuning.DecayIdle))
end

function MomentumRules.tier(value: number): number
	local fraction = value / tuning.Cap
	for index = #tuning.TierThresholds, 1, -1 do
		if fraction >= tuning.TierThresholds[index] then
			return index
		end
	end
	return 0
end

function MomentumRules.tierTransition(previousTier: number, value: number): (number, boolean)
	local nextTier = MomentumRules.tier(value)
	return nextTier, nextTier ~= previousTier
end

function MomentumRules.speed(roleSpeed: number, exTayaMult: number, hardLandMult: number, value: number): number
	return math.min(tuning.GlobalSpeedCeiling, (roleSpeed * exTayaMult + value) * hardLandMult)
end

function MomentumRules.intentFresh(sentAt: number, receivedAt: number, maxAge: number): boolean
	return sentAt == sentAt and math.abs(sentAt) < math.huge
		and math.abs(receivedAt - sentAt) <= maxAge
end

function MomentumRules.perfectRoll(intentAt: number, acceptedAt: number): boolean
	return intentAt > 0 and acceptedAt >= intentAt
		and acceptedAt - intentAt <= tuning.PerfectRollWindow
end

function MomentumRules.reconcile(value: number, sequence: number, serverValue: number, serverSequence: number): (number, number, boolean)
	if serverSequence ~= serverSequence or math.abs(serverSequence) == math.huge
		or serverSequence <= sequence or serverValue ~= serverValue
		or serverValue < 0 or serverValue > tuning.Cap then
		return value, sequence, false
	end
	return serverValue, serverSequence, true
end

return MomentumRules
