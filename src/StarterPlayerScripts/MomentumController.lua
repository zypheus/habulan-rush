--!strict
-- StarterPlayerScripts/MomentumController.lua
-- Owner: Project Owner
-- Responsibility: local momentum prediction, server reconciliation, and local change events.
-- Task/spec: momentum steps 2 to 4, 2026-10-19.
-- Task/spec: slide chaining correction, 2026-10-19.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local MomentumRules = require(ReplicatedStorage:WaitForChild("MomentumRules"))
local tuning = Config.Momentum
local player = Players.LocalPlayer

local MomentumController = {}
local changed = Instance.new("BindableEvent")
MomentumController.Changed = changed.Event

local started = false
local amount = 0
local lastGainAt = 0
local lastSampleAt = Workspace:GetServerTimeNow()
local lastSequence = 0
local lastLocalResetAt = -math.huge
local previous: { [string]: { at: number, count: number } } = {}
local confirmedSlide: { at: number, count: number }? = nil

local function moving(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude > tuning.MovingThreshold
end

local function advance(now: number)
	if amount > 0 then
		amount = MomentumRules.decay(amount, lastGainAt, lastSampleAt, now, moving())
	end
	lastSampleAt = now
end

function MomentumController.value(): number
	advance(Workspace:GetServerTimeNow())
	return amount
end

function MomentumController.predict(action: string, perfect: boolean?): number
	if player:GetAttribute("HRushRole") == "Taya" and not tuning.TayaBuildsMomentum then return 0 end
	local now = Workspace:GetServerTimeNow()
	advance(now)
	local baseGain = if action == "Slide" then tuning.GainSlide
		else if perfect then tuning.GainRollPerfect else tuning.GainRoll
	local prior = previous[action]
	local nextValue, gain, count = MomentumRules.gain(amount, baseGain,
		if prior then prior.at else -math.huge, if prior then prior.count else 0, now)
	amount = nextValue
	lastGainAt = now
	previous[action] = { at = now, count = count }
	changed:Fire(amount, "predict", action, gain)
	return gain
end

function MomentumController.hardZero(reason: string)
	local hadMomentum = amount > 0
	lastLocalResetAt = Workspace:GetServerTimeNow()
	amount = 0
	lastGainAt = 0
	lastSampleAt = lastLocalResetAt
	previous = {}
	confirmedSlide = nil
	if hadMomentum then
		changed:Fire(0, "lost", reason, 0)
	end
end

function MomentumController.start()
	if started then return end
	started = true
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MomentumUpdate") :: RemoteEvent
	remote.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" or typeof(payload.sequence) ~= "number"
			or typeof(payload.value) ~= "number"
		then return end
		local nextValue, nextSequence, accepted = MomentumRules.reconcile(amount, lastSequence,
			payload.value, payload.sequence)
		if not accepted then return end
		lastSequence = nextSequence
		if typeof(payload.serverTime) == "number" and payload.serverTime <= lastLocalResetAt
			and payload.action ~= "Lost" then return end
		local now = Workspace:GetServerTimeNow()
		local oldAmount = amount
		amount = nextValue
		lastSampleAt = now
		if typeof(payload.lastGainAt) == "number" and payload.lastGainAt == payload.lastGainAt then
			lastGainAt = math.min(now, payload.lastGainAt)
		end
		if payload.rejectedAction == "Slide" or payload.rejectedAction == "Roll" then
			previous[payload.rejectedAction] = if payload.rejectedAction == "Slide" then confirmedSlide else nil
			changed:Fire(amount, "reconcile", nil, 0)
			return
		end
		if payload.action == "Lost" then
			previous = {}
			confirmedSlide = nil
			lastGainAt = 0
			if oldAmount > 0 then changed:Fire(0, "lost", "server", 0) end
		elseif typeof(payload.action) == "string" then
			local action = payload.action
			if typeof(payload.count) == "number" then
				previous[action] = { at = now, count = payload.count }
				if action == "Slide" then confirmedSlide = previous[action] end
			end
			changed:Fire(amount, "confirmed", action, payload.gain, payload)
		else
			changed:Fire(amount, "reconcile", nil, 0)
		end
	end)
end

return MomentumController
