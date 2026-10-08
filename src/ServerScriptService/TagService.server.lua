--!strict
-- ServerScriptService/TagService.lua
-- Owner: Programmer A (T05)
-- Responsibility: Pounce/touch tag validation, tag transfer, Safe Window,
--                 Lock Delay, lag rewind buffer.
-- See System Specification §4 and DESIGN_LOCK.md for confirmed rules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Config)

-- Shared untouchable rule (RS_01 air state): BOTH tag paths must call
-- TagRules.isUntouchable(target) before applying a hit, so the rule lives in
-- one place and touch (TM_08) and pounce (TM_05) can never disagree.
local TagRules = require(ReplicatedStorage:WaitForChild("TagRules"))

-- TODO (T11): Implement server-authoritative tag validation.
--   First check of every tag attempt: TagRules.isUntouchable(targetModel).
-- TODO (T12): Implement Safe Window, speed boost, and lock delay.
-- TODO (T13): Implement pounce mechanics and validation.

print("[TagService] Loaded — stub only. Implement T11–T13.")
