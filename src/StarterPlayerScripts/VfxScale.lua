--!strict
-- StarterPlayerScripts/VfxScale.lua (ModuleScript)
-- Owner: UI Dev
-- Responsibility: one central cosmetic scale (0 to 1) and the reduced camera
-- flag, read from ClientSettings. Effect code reads this helper, never the
-- setting directly. Presentation only, never gameplay.
-- Refs: Settings screen task step 4 (UI/UX Spec section 7, T33 accessibility).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local VfxScale = {}

-- Lazy require (keeps module top level cheap and non-yielding): ClientSettings
-- is a sibling ModuleScript created in the same Rojo sync.
local settingsModule: any = nil
local function settings(): any
	if settingsModule == nil then
		settingsModule = require(script.Parent:WaitForChild("ClientSettings"))
	end
	return settingsModule
end

-- Player factor 0 to 1 from the VFX slider. 100 percent reads exactly 1.
function VfxScale.player(): number
	return (settings().get("vfx") :: number) / 100
end

-- Cosmetic scale for juice (counts, rates, lifetimes). Zero turns cosmetic
-- effects off. Callers round to a whole count and skip on zero.
function VfxScale.cosmetic(): number
	return VfxScale.player()
end

-- Telegraph scale for gameplay information. Never drops below the Config
-- floor, so aim, tells, and markers stay visible at every setting.
function VfxScale.telegraph(): number
	return math.max(VfxScale.player(), Config.Settings.TelegraphFloor)
end

-- Whole cosmetic count from a Config count. Rounds half up; zero means skip.
function VfxScale.count(n: number): number
	return math.floor(n * VfxScale.cosmetic() + 0.5)
end

-- Whole telegraph count from a Config count. Never below one.
function VfxScale.telegraphCount(n: number): number
	return math.max(1, math.floor(n * VfxScale.telegraph() + 0.5))
end

-- Reduced camera effects: the player toggle wins, and the Config QA override
-- forces it on. Either one disables FOV kicks, camera shake, and the aim
-- camera switch. Never touches steering, speeds, or simulation.
function VfxScale.reducedCamera(): boolean
	return (settings().get("reducedCamera") :: boolean) == true or Config.SprintVFX.ReducedEffects == true
end

return VfxScale
