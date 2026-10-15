--!strict
-- tools/AnimationDev/HRush_AnimPreview.lua
-- Owner: Project Owner
-- Responsibility: command-bar entry point for R15 animation preview and scrubbing.
-- Task/spec: Movement animation amendment, Batch 0, approved 2026-10-15.

-- Copy this script into the Studio Command Bar after placing HRush_AnimDev as:
-- Workspace.AnimationDevelopment.HRush_AnimDev
-- Change ACTION and ANIMATION_NAME, then run while a Play test is active.

local ACTION: "Normal" | "QuarterSpeed" | "Scrub" | "BuildAll" | "Stop" = "Normal"
local ANIMATION_NAME = "HRush_PipelineSelfTest"
local SCRUB_TIME = 0.25

local folder = workspace:WaitForChild("AnimationDevelopment")
local AnimDev = require(folder:WaitForChild("HRush_AnimDev"))

if ACTION == "Normal" then
	AnimDev.preview(ANIMATION_NAME, 1)
elseif ACTION == "QuarterSpeed" then
	AnimDev.previewQuarterSpeed(ANIMATION_NAME)
elseif ACTION == "Scrub" then
	AnimDev.scrub(ANIMATION_NAME, SCRUB_TIME)
elseif ACTION == "BuildAll" then
	AnimDev.buildAll(false)
elseif ACTION == "Stop" then
	AnimDev.destroyPreviewRig()
end
