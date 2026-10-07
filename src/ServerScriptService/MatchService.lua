--!strict
-- ServerScriptService/MatchService.lua
-- Owner: Programmer A (T05)
-- Responsibility: State machine (MS_01→MS_06), shuffle bag, scoring,
--                 phase timers, and disconnect handling.
-- See PLANNING.md §3 and System Specification §2 for full rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Config = require(ReplicatedStorage.Config)

-- TODO (T07): Implement match state machine and shuffle bag.

print("[MatchService] Loaded — stub only. Implement T07.")
