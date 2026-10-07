--!strict
-- ServerScriptService/EventService.lua
-- Owner: Programmer B (T05)
-- Responsibility: Orchestrates Barangay Rush events and Huling Habol
--                 timeline based on MatchService phase changes.
-- See System Specification §7 and Config.Match / Config.Events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)

-- TODO (T24–T26): Implement Court Rush event, match phase controller,
--                 and Huling Habol presentation escalation.

print("[EventService] Loaded — stub only. Implement T24–T26.")
