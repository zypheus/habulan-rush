--!strict
-- StarterPlayerScripts/AudioRouter.lua (ModuleScript)
-- Owner: UI Dev
-- Responsibility: client SoundGroups (Master with Music and SFX inside it)
-- and one routing call so every gameplay sound lands in the right group.
-- Reads volumes from ClientSettings. Never touches gameplay.
-- Refs: Settings screen task (Art Bible section 3, UI/UX Spec section 7).

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local AudioRouter = {}

local masterGroup: SoundGroup? = nil
local musicGroup: SoundGroup? = nil
local sfxGroup: SoundGroup? = nil
local subscribed = false

-- Lazy require (keeps module top level cheap and non-yielding): ClientSettings
-- is a sibling ModuleScript created in the same Rojo sync.
local settingsModule: any = nil
local function settings(): any
	if settingsModule == nil then
		settingsModule = require(script.Parent:WaitForChild("ClientSettings"))
	end
	return settingsModule
end

local function curve(v: number): number
	local power = Config.Settings.VolumeCurve
	return math.pow(math.clamp(v, 0, 1), power)
end

-- Recompute group volumes from the current slider values. Slider 0 is silent.
local function applyVolumes()
	if masterGroup == nil or musicGroup == nil or sfxGroup == nil then
		return
	end
	local cs = settings()
	local master = (cs.get("master") :: number) / 100
	local music = (cs.get("music") :: number) / 100
	local sfx = (cs.get("sfx") :: number) / 100
	masterGroup.Volume = curve(master)
	musicGroup.Volume = curve(music)
	sfxGroup.Volume = curve(sfx)
end

-- Adopt-or-create: a place saved after a Play session already contains the
-- groups (runtime instances persist into the saved file). Reusing by name
-- keeps one canonical tree no matter how the place was saved.
local function getOrCreateGroup(parent: Instance, name: string): SoundGroup
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = parent
	return group
end

-- Idempotent startup: creates the groups once and follows setting changes.
function AudioRouter.ensure()
	if masterGroup == nil then
		masterGroup = getOrCreateGroup(SoundService, "HRushMaster")
		musicGroup = getOrCreateGroup(masterGroup, "HRushMusic")
		sfxGroup = getOrCreateGroup(masterGroup, "HRushSFX")
		-- Remove strays saved from an older session so only one tree plays.
		for _, child in SoundService:GetChildren() do
			if child ~= masterGroup and child.Name == "HRushMaster" then
				child:Destroy()
			end
		end
	end
	if not subscribed then
		subscribed = true
		settings().Changed:Connect(function(_key: unknown, _value: unknown)
			applyVolumes()
		end)
	end
	applyVolumes()
end

-- Assign a sound to a group ("music" or "sfx"). Everything else defaults to sfx.
function AudioRouter.route(sound: Sound, which: string?)
	AudioRouter.ensure()
	local target = sfxGroup
	if which == "music" and musicGroup ~= nil then
		target = musicGroup
	end
	sound.SoundGroup = target
end

function AudioRouter.master(): SoundGroup?
	AudioRouter.ensure()
	return masterGroup
end

function AudioRouter.music(): SoundGroup?
	AudioRouter.ensure()
	return musicGroup
end

function AudioRouter.sfx(): SoundGroup?
	AudioRouter.ensure()
	return sfxGroup
end

-- Non-positional one-shot through the SFX group (UI, countdown, tag slap).
-- Empty IDs stay silent. Defaults to PlayerGui so distance never mutes it;
-- pass a part (and optional pitch) for positional world sounds like footsteps.
function AudioRouter.playSfxId(id: unknown, volume: number, parent: Instance?, pitch: number?)
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local host = parent
	if host == nil then
		host = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end
	if host == nil then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.RollOffMaxDistance = 60
	if pitch ~= nil then
		sound.PlaybackSpeed = pitch
	end
	AudioRouter.route(sound, "sfx")
	sound.Parent = host
	local ok = pcall(function()
		sound:Play()
	end)
	if not ok then
		sound:Destroy()
		return
	end
	game:GetService("Debris"):AddItem(sound, 3)
end

-- Shared UI one-shot. Reads Config.Sfx.UI; unhooked keys (error) wait for
-- the feature that fires them.
function AudioRouter.playUi(key: string)
	local ui = Config.Sfx.UI
	local id = (ui :: any)[key]
	if typeof(id) ~= "string" or id == "" then
		return
	end
	AudioRouter.playSfxId(id, ui.volume)
end

return AudioRouter
