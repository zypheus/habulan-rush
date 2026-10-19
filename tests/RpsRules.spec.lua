--!strict
-- tests/RpsRules.spec.lua
-- Owner: Project Owner
-- Responsibility: Studio command bar assertions for pure MS_RPS resolution.
-- Task/spec: MS_RPS first Taya selection, System Spec 2.1.
-- Run the assertions in Studio after syncing RpsRules from this repository.

local RpsRules = require(game:GetService("ReplicatedStorage"):WaitForChild("RpsRules"))

local tieOne, safeOne = RpsRules.Resolve({ [1] = "Rock", [2] = "Rock" })
assert(tieOne and #safeOne == 0, "one sign must replay")

local tieThree, safeThree = RpsRules.Resolve({ [1] = "Rock", [2] = "Paper", [3] = "Scissors" })
assert(tieThree and #safeThree == 0, "three signs must replay")

local tieTwo, safeTwo = RpsRules.Resolve({ [1] = "Rock", [2] = "Scissors", [3] = "Rock" })
assert(not tieTwo and #safeTwo == 2 and safeTwo[1] == 1 and safeTwo[2] == 3, "winning signs must leave the stage pool")
