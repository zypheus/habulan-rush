--!strict
-- StarterPlayerScripts/ClientSettings.lua (ModuleScript)
-- Owner: UI Dev
-- Responsibility: per-player client presentation settings (audio volumes,
-- VFX intensity, reduced camera effects, camera look, view mode). No GUI.
-- Choices live here and never write to Config at runtime.
-- Refs: Settings screen task (UI/UX Spec section 7, T33 accessibility);
-- camera overhaul Phase 4 (view mode key).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local S = Config.Settings

export type SettingKey = "master" | "music" | "sfx" | "vfx" | "reducedCamera" | "cameraSensitivity" | "invertCameraY" | "cameraEffectsIntensity" | "lookBackEnabled" | "chaserIndicatorEnabled" | "cameraViewMode"

type NumberSpec = {
	kind: string,
	min: number,
	max: number,
	step: number,
	default: number,
}
type BoolSpec = {
	kind: string,
	default: boolean,
}
type StringSpec = {
	kind: string,
	default: string,
	allowed: { string },
}
type SettingSpec = NumberSpec | BoolSpec | StringSpec

-- Registry: add future options (UI text scale, colorblind palette) as new
-- entries here without touching the screen code.
local SPECS: { [SettingKey]: SettingSpec } = {
	master = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.MasterDefault },
	music = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.MusicDefault },
	sfx = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.SfxDefault },
	vfx = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.VfxDefault },
	reducedCamera = { kind = "boolean", default = S.ReducedCameraDefault },
	cameraSensitivity = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.CameraSensitivityDefault },
	invertCameraY = { kind = "boolean", default = S.InvertCameraYDefault },
	cameraEffectsIntensity = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.CameraEffectsDefault },
	lookBackEnabled = { kind = "boolean", default = S.LookBackDefault },
	chaserIndicatorEnabled = { kind = "boolean", default = S.ChaserIndicatorDefault },
	cameraViewMode = { kind = "string", default = S.CameraViewModeDefault, allowed = { "ThirdPerson", "FirstPerson" } },
}

local ClientSettings = {}

local values: { [SettingKey]: number | boolean | string } = {}
for key, spec in SPECS do
	values[key] = spec.default
end

local changedEvent = Instance.new("BindableEvent")
ClientSettings.Changed = changedEvent.Event

local function snap(step: number, v: number): number
	if step <= 0 then
		return v
	end
	return math.floor(v / step + 0.5) * step
end

-- Read a setting. Errors on unknown keys so typos fail loudly.
function ClientSettings.get(key: SettingKey): number | boolean | string
	local spec = SPECS[key]
	assert(spec ~= nil, "ClientSettings.get: unknown key " .. tostring(key))
	return values[key]
end

-- Write a setting with clamping, step snapping, and string allow-listing.
-- Fires Changed once per real change with (key, value). Never touches Config.
function ClientSettings.set(key: SettingKey, value: number | boolean | string)
	local spec = SPECS[key]
	assert(spec ~= nil, "ClientSettings.set: unknown key " .. tostring(key))
	local next: number | boolean | string = value
	if spec.kind == "number" then
		assert(typeof(value) == "number", "ClientSettings.set: number expected for " .. tostring(key))
		local numSpec = spec :: NumberSpec
		next = math.clamp(snap(numSpec.step, value :: number), numSpec.min, numSpec.max)
	elseif spec.kind == "string" then
		assert(typeof(value) == "string", "ClientSettings.set: string expected for " .. tostring(key))
		local strSpec = spec :: StringSpec
		assert(table.find(strSpec.allowed, value :: string) ~= nil, "ClientSettings.set: value not allowed for " .. tostring(key))
	else
		assert(typeof(value) == "boolean", "ClientSettings.set: boolean expected for " .. tostring(key))
	end
	if values[key] == next then
		return
	end
	values[key] = next
	changedEvent:Fire(key, next)
end

-- Restore every default. Fires Changed once per key that actually changed.
function ClientSettings.reset()
	for key, spec in SPECS do
		if values[key] ~= spec.default then
			values[key] = spec.default
			changedEvent:Fire(key, spec.default)
		end
	end
end

return ClientSettings
