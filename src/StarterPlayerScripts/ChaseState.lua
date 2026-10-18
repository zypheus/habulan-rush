--!strict
-- StarterPlayerScripts/ChaseState.lua (ModuleScript)
-- Owner: Project Owner
-- Responsibility: Phase 3 client chase awareness state: resolves the active
-- Taya (players), tracks distance, closing speed, and
-- on-screen visibility, and one smoothed chase intensity shared by the
-- camera FOV channel and the chase HUD. Presentation only; no authority, no
-- camera writes, no remotes.
-- Task/spec: test bots removed; camera overhaul Phase 3 approved 2026-10-18.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Cfg = Config.Camera
local Chase = Cfg.Chase

local localPlayer = Players.LocalPlayer

export type ChaseInfo = {
	isTaya: boolean,
	taya: Instance?,
	tayaRoot: BasePart?,
	distance: number,
	closing: number,
	visible: boolean,
	near: boolean,
	intensity: number,
}

local ChaseState = {}

local info: ChaseInfo = {
	isTaya = false,
	taya = nil,
	tayaRoot = nil,
	distance = math.huge,
	closing = 0.0,
	visible = false,
	near = false,
	intensity = 0.0,
}

local closingSmooth = 0.0
local prevDistance = math.huge
local prevTaya: Instance? = nil

-- Frame-rate independent exponential approach, matching the 3 / seconds
-- convention used by the camera effects.
local function approach(current: number, target: number, time: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-(3 / math.max(time, 0.01)) * dt))
end

local function rootOf(candidate: Instance): BasePart?
	local model: Model? = nil
	if candidate:IsA("Player") then
		model = candidate.Character
	end
	if model == nil then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function resolveTaya(): (Instance?, BasePart?)
	for _, p in Players:GetPlayers() do
		if p ~= localPlayer
			and p:GetAttribute("HRushRole") == "Taya"
			and p:GetAttribute("HRushInMatch") == true then
			local root = rootOf(p)
			if root ~= nil then
				return p, root
			end
		end
	end
	return nil, nil
end

-- Called once per frame by CameraDirector while the match camera is bound.
function ChaseState.update(dt: number)
	local isTaya = localPlayer:GetAttribute("HRushRole") == "Taya"
	info.isTaya = isTaya

	local taya: Instance? = nil
	local tayaRoot: BasePart? = nil
	if not isTaya then
		taya, tayaRoot = resolveTaya()
	end
	info.taya = taya
	info.tayaRoot = tayaRoot

	local character = localPlayer.Character
	local root: BasePart? = nil
	if character ~= nil then
		local found = character:FindFirstChild("HumanoidRootPart")
		if found ~= nil and found:IsA("BasePart") then
			root = found
		end
	end

	local distance = math.huge
	if tayaRoot ~= nil and root ~= nil then
		distance = (tayaRoot.Position - root.Position).Magnitude
	end
	info.distance = distance

	-- Closing speed: positive while the Taya is approaching. Only meaningful
	-- while the same Taya stays resolved and both bodies have a position.
	local rawClosing = 0.0
	if taya ~= nil and taya == prevTaya and distance < math.huge and prevDistance < math.huge and dt > 0 then
		rawClosing = math.clamp((prevDistance - distance) / dt, -60, 60)
	end
	prevTaya = taya
	prevDistance = distance
	closingSmooth = approach(closingSmooth, rawClosing, Chase.ClosingSmoothTime, dt)
	info.closing = closingSmooth

	-- Visibility: projected body center is on screen and in front of the camera.
	local visible = false
	if tayaRoot ~= nil then
		local camera = Workspace.CurrentCamera
		if camera ~= nil then
			local screen, onScreen = camera:WorldToViewportPoint(tayaRoot.Position + Vector3.new(0, 1, 0))
			visible = onScreen and screen.Z > 0
		end
	end
	info.visible = visible

	-- Intensity: distance dominant, closing-speed bonus, subtle visibility
	-- modifier. Asymmetric smoothing: rises fast, falls slower.
	local rawIntensity = 0.0
	if tayaRoot ~= nil and root ~= nil then
		local span = math.max(0.01, Chase.MaxDistance - Chase.MinDistance)
		local distanceFactor = math.clamp((Chase.MaxDistance - distance) / span, 0, 1)
		local bonus = math.clamp(closingSmooth * Chase.ClosingGain, 0, Chase.ClosingMax)
		local visibilityModifier = if visible then Chase.VisibleModifier else 1.0
		rawIntensity = math.clamp(distanceFactor * (1 + bonus) * visibilityModifier, 0, 1)
	end
	local riseTime = if rawIntensity > info.intensity then Chase.RiseTime else Chase.FallTime
	info.intensity = approach(info.intensity, rawIntensity, riseTime, dt)

	info.near = tayaRoot ~= nil and distance <= Cfg.ChaserIndicator.MaxDistance
end

-- Read-only by convention: consumers copy what they need per frame.
function ChaseState.get(): ChaseInfo
	return info
end

return ChaseState
