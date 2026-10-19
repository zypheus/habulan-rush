--!strict
-- tests/MomentumClient.spec.lua
-- Owner: Project Owner
-- Responsibility: client Command Bar smoke assertions for local momentum reset and cap.
-- Task/spec: momentum steps 2 to 4, 2026-10-19.
-- Run in a Runner client while out of a live round, after source sync.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
assert(player ~= nil, "run in the client Command Bar")
assert(player:GetAttribute("HRushRole") ~= "Taya", "run as Runner")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local rules = require(ReplicatedStorage:WaitForChild("MomentumRules"))
local momentum = require(player:WaitForChild("PlayerScripts"):WaitForChild("MomentumController"))

for _, reason in { "stun", "tagged", "role changed", "death", "round ended", "respawn" } do
	momentum.hardZero("setup")
	local gain = momentum.predict("Slide")
	assert(gain > 0, reason .. " setup gained no momentum")
	assert(rules.speed(25.2, 1.2, 1, momentum.value()) <= Config.Momentum.GlobalSpeedCeiling)
	momentum.hardZero(reason)
	assert(momentum.value() == 0, reason .. " did not clear local momentum")
end
