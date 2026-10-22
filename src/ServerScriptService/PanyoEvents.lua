--!strict
-- ServerScriptService/PanyoEvents.lua
-- Owner: Project Owner
-- Responsibility: Server-timed Agawan ng Panyo phase and reveal thresholds.
-- Task/spec: Agawan ng Panyo round events, approved 2026-10-23.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))

local PanyoEvents = {}
PanyoEvents.__index = PanyoEvents

function PanyoEvents.new(emit: (string, any) -> ())
	return setmetatable({
		emit = emit,
		endsAt = 0,
		active = false,
		phase = "Simula",
		fired = {} :: { [string]: boolean },
	}, PanyoEvents)
end

function PanyoEvents:start(endsAt: number)
	self.endsAt = endsAt
	self.active = true
	self.phase = "Simula"
	self.fired = {}
	self.emit("Phase", { phase = "Simula" })
end

function PanyoEvents:step(now: number)
	if not self.active then return end
	local timing = Config.Panyo.Events
	local remaining = math.max(0, self.endsAt - now)
	if remaining <= timing.HulingHabol and self.phase ~= "HulingHabol" then
		self.phase = "HulingHabol"
		self.emit("Phase", { phase = self.phase })
	elseif remaining <= timing.BarangayRush and self.phase == "Simula" then
		self.phase = "BarangayRush"
		self.emit("Phase", { phase = self.phase })
	end
	for _, threshold in ipairs(timing.Reveals) do
		local key = "Reveal" .. tostring(threshold)
		if remaining <= threshold and not self.fired[key] then
			self.fired[key] = true
			self.emit("Reveal", { duration = Config.Panyo.RevealDuration, remaining = threshold })
		end
	end
	for _, threshold in ipairs(timing.FinalCues) do
		local key = "Final" .. tostring(threshold)
		if remaining <= threshold and not self.fired[key] then
			self.fired[key] = true
			self.emit("FinalCue", { remaining = threshold })
		end
	end
end

function PanyoEvents:stop()
	self.active = false
end

return PanyoEvents
