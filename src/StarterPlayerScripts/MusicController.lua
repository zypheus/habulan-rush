--!strict
-- StarterPlayerScripts/MusicController.lua (ModuleScript)
-- Owner: UI Dev
-- Responsibility: looping match-state music with crossfades. Reads one track
-- per match state from Config.Audio.Music (all "" until licensed audio is
-- logged). Empty IDs play nothing and never error. All output obeys the
-- Music SoundGroup. Presentation only, never gameplay.
-- Refs: Settings screen task (Art Bible sections 3.1 and 3.3, UI/UX Spec section 5).
-- Task/spec: MS_RPS first Taya selection, GDD 3.2 / System Spec 2.1.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local MUSIC = Config.Audio.Music
local INTRO = Config.UI.MatchIntro

local MusicController = {}

local LocalPlayer = Players.LocalPlayer
local track: Sound? = nil
local tone: Sound? = nil
local currentId = ""
local fadeToken = 0
local started = false

-- Map vote and bato bato pick share the pre-round track.
local function keyForState(state: string): string
	if state == "MS_VOTE" or state == "MS_RPS" then
		return "draft"
	elseif state == "MS_03" then
		return "countdown"
	elseif state == "MS_04" then
		return "round"
	elseif state == "MS_05" then
		return "roundEnd"
	elseif state == "MS_06" then
		return "matchEnd"
	else
		return "lobby"
	end
end

-- Per-state track id. In-match states fall back to the match BGM until their
-- own licensed tracks land. Lobby has no fallback and stays silent.
local function idForState(state: string): string
	local key = keyForState(state)
	local id = (MUSIC :: any)[key]
	if typeof(id) == "string" and id ~= "" then
		return id
	end
	if key ~= "lobby" and typeof(INTRO.BgmId) == "string" then
		return INTRO.BgmId
	end
	return ""
end

local function fadeOut(sound: Sound, done: () -> ())
	fadeToken += 1
	local token = fadeToken
	local t = TweenService:Create(
		sound,
		TweenInfo.new(INTRO.BgmFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = 0 }
	)
	t:Play()
	t.Completed:Connect(function()
		if fadeToken == token then
			done()
		end
	end)
end

local function playTrack(id: string)
	local router = require(script.Parent:WaitForChild("AudioRouter"))
	if track == nil then
		local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui == nil then
			return
		end
		local s = Instance.new("Sound")
		s.Name = "HRushMusicTrack"
		s.Looped = true
		s.Volume = 0
		router.route(s, "music")
		s.Parent = playerGui
		track = s
	end
	local s: Sound = track :: Sound
	if currentId == id and s.IsPlaying then
		return
	end
	currentId = id
	s.SoundId = id
	s.Volume = 0
	local ok = pcall(function()
		s:Play()
	end)
	if not ok then
		return
	end
	TweenService:Create(
		s,
		TweenInfo.new(INTRO.BgmFadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Volume = 1 }
	):Play()
end

local function stopTrack()
	if track == nil then
		return
	end
	local s: Sound = track :: Sound
	if not s.IsPlaying then
		currentId = ""
		return
	end
	currentId = ""
	fadeOut(s, function()
		s:Stop()
	end)
end

-- Debug only (TODO: remove before submission): loops a built-in engine sound
-- through the Music group so the Music slider is provable with no licensed
-- music. No new asset ID is introduced.
local function playTestTone()
	local router = require(script.Parent:WaitForChild("AudioRouter"))
	if tone == nil then
		local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui == nil then
			return
		end
		local s = Instance.new("Sound")
		s.Name = "HRushSettingsTestTone"
		s.SoundId = "rbxasset://sounds/electronicpingshort.wav"
		s.Looped = true
		s.Volume = 1
		router.route(s, "music")
		s.Parent = playerGui
		tone = s
	end
	local s: Sound = tone :: Sound
	if not s.IsPlaying then
		pcall(function()
			s:Play()
		end)
	end
end

local function stopTestTone()
	if tone ~= nil then
		local s: Sound = tone :: Sound
		if s.IsPlaying then
			s:Stop()
		end
	end
end

local function refresh()
	if Config.Debug.SettingsTestTone then
		stopTrack()
		playTestTone()
		return
	end
	stopTestTone()
	if LocalPlayer:GetAttribute("HRushInMatch") ~= true then
		stopTrack()
		return
	end
	local state = LocalPlayer:GetAttribute("HRushState")
	local id = if typeof(state) == "string" then idForState(state) else ""
	if id == "" then
		stopTrack()
	else
		playTrack(id)
	end
end

-- One persistent track plus two attribute connections. Nothing is rebuilt on
-- respawn (no character refs), so round changes only retarget the same Sound.
function MusicController.Init()
	if started then
		return
	end
	started = true
	local router = require(script.Parent:WaitForChild("AudioRouter"))
	router.ensure()
	LocalPlayer:GetAttributeChangedSignal("HRushInMatch"):Connect(refresh)
	LocalPlayer:GetAttributeChangedSignal("HRushState"):Connect(refresh)
	refresh()
end

return MusicController
