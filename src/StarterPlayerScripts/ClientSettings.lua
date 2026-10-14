--!strict
-- StarterPlayerScripts/ClientSettings.lua (ModuleScript)
-- Owner: UI Dev
-- Responsibility: per-player client presentation settings (audio volumes,
-- VFX intensity, reduced camera effects). No GUI. Choices live here and
-- never write to Config at runtime.
-- Refs: Settings screen task (UI/UX Spec section 7, T33 accessibility).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local S = Config.Settings

export type SettingKey = "master" | "music" | "sfx" | "vfx" | "reducedCamera"

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
type SettingSpec = NumberSpec | BoolSpec

-- Registry: add future options (UI text scale, colorblind palette) as new
-- entries here without touching the screen code.
local SPECS: { [SettingKey]: SettingSpec } = {
	master = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.MasterDefault },
	music = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.MusicDefault },
	sfx = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.SfxDefault },
	vfx = { kind = "number", min = 0, max = 100, step = S.SliderStep, default = S.VfxDefault },
	reducedCamera = { kind = "boolean", default = S.ReducedCameraDefault },
}

local ClientSettings = {}

local values: { [SettingKey]: number | boolean } = {}
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
function ClientSettings.get(key: SettingKey): number | boolean
	local spec = SPECS[key]
	assert(spec ~= nil, "ClientSettings.get: unknown key " .. tostring(key))
	return values[key]
end

-- Write a setting with clamping and step snapping. Fires Changed once per
-- real change with (key, value). Never touches Config.
function ClientSettings.set(key: SettingKey, value: number | boolean)
	local spec = SPECS[key]
	assert(spec ~= nil, "ClientSettings.set: unknown key " .. tostring(key))
	local next: number | boolean = value
	if spec.kind == "number" then
		assert(typeof(value) == "number", "ClientSettings.set: number expected for " .. tostring(key))
		local numSpec = spec :: NumberSpec
		next = math.clamp(snap(numSpec.step, value :: number), numSpec.min, numSpec.max)
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
