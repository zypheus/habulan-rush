--!strict
-- StarterPlayerScripts/LandingController.lua
-- Owner: Project Owner
-- Responsibility: local landing classification, animation, impact events, and hard-landing penalty lifetime.
-- Task/spec: simple click-to-tag integration, approved 2026-10-18.
-- Task/spec: movement upgrade Part 2A landing owner, approved 2026-10-16.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Movement = Config.Movement
local Animations = Config.Animations
local LocalPlayer = Players.LocalPlayer

export type LandingPayload = {
	fallHeight: number,
	horizontalSpeed: number,
	class: string,
}

type Options = {
	onPenaltyChanged: (() -> ())?,
}

local LandingController = {}
local started = false
local options: Options = {}
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local stateConnection: RBXScriptConnection? = nil
local heartbeatConnection: RBXScriptConnection? = nil
local diedConnection: RBXScriptConnection? = nil
local landTrack: AnimationTrack? = nil
local hardLandTrack: AnimationTrack? = nil
local landMarkerConnection: RBXScriptConnection? = nil
local hardMarkerConnection: RBXScriptConnection? = nil
local airborne = false
local apexY = 0.0
local penaltyGeneration = 0
local activePayload: LandingPayload? = nil

local function eventNamed(name: string): BindableEvent
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing and existing:IsA("BindableEvent") then
		return existing
	end
	local event = Instance.new("BindableEvent")
	event.Name = name
	event.Parent = ReplicatedStorage
	return event
end

local landingEvent = eventNamed("HRushLandingEvent")
local impactEvent = eventNamed("HRushLandImpact")

local function usableAnimationId(value: unknown): boolean
	return typeof(value) == "string" and string.match(value, "^rbxassetid://%d+$") ~= nil
end

local function loadTrack(animator: Animator, definition: any): AnimationTrack?
	if not usableAnimationId(definition.Id) then
		return nil
	end
	local ok, result = pcall(function(): AnimationTrack
		local animation = Instance.new("Animation")
		animation.AnimationId = definition.Id
		local track = animator:LoadAnimation(animation)
		track.Priority = definition.Priority
		track.Looped = definition.Looped
		animation:Destroy()
		return track
	end)
	if ok then
		return result
	end
	return nil
end

local function horizontalSpeed(part: BasePart): number
	local velocity = part.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function notifyPenaltyChanged()
	if options.onPenaltyChanged then
		options.onPenaltyChanged()
	end
end

local function clearPenalty()
	penaltyGeneration += 1
	LocalPlayer:SetAttribute("HRushHardLandingSpeedMult", nil)
	LocalPlayer:SetAttribute("HRushHardLandingUntil", nil)
	notifyPenaltyChanged()
end

function LandingController.cancelPenalty(action: string): boolean
	if LocalPlayer:GetAttribute("HRushHardLandingSpeedMult") == nil then
		return false
	end
	clearPenalty()
	if RunService:IsStudio() then
		print(string.format("[Landing] hard-landing penalty cancelled by %s", action))
	end
	return true
end

local function beginPenalty()
	if LocalPlayer:GetAttribute("HRushVaulting") == true
		or LocalPlayer:GetAttribute("HRushRolling") == true
		or LocalPlayer:GetAttribute("HRushSliding") == true
	then
		return
	end
	penaltyGeneration += 1
	local generation = penaltyGeneration
	LocalPlayer:SetAttribute("HRushHardLandingSpeedMult", Movement.HardLandSpeedMult)
	LocalPlayer:SetAttribute("HRushHardLandingUntil", os.clock() + Movement.HardLandPenaltyTime)
	notifyPenaltyChanged()
	task.delay(Movement.HardLandPenaltyTime, function()
		if generation == penaltyGeneration then
			clearPenalty()
		end
	end)
end

local function playLanding(payload: LandingPayload)
	activePayload = payload
	local track = if payload.class == "Hard" then hardLandTrack else landTrack
	local definition = if payload.class == "Hard" then Animations.LandHard else Animations.Land
	if track == nil then
		impactEvent:Fire(payload)
		return
	end
	local ok = pcall(function()
		track:Play(definition.FadeIn, 1, 1)
	end)
	if not ok then
		impactEvent:Fire(payload)
	end
end

local function onLanded()
	local activeRoot = root
	if not airborne or activeRoot == nil then
		return
	end
	airborne = false
	local payload: LandingPayload = {
		fallHeight = math.max(0, apexY - activeRoot.Position.Y),
		horizontalSpeed = horizontalSpeed(activeRoot),
		class = "Soft",
	}
	if payload.fallHeight > Movement.HardLandHeight then
		payload.class = "Hard"
		beginPenalty()
	end
	LocalPlayer:SetAttribute("HRushLastFallHeight", payload.fallHeight)
	LocalPlayer:SetAttribute("HRushLastLandingClass", payload.class)
	landingEvent:Fire(payload)
	playLanding(payload)
end

local function clearCharacter()
	for _, connection in { stateConnection, heartbeatConnection, diedConnection, landMarkerConnection, hardMarkerConnection } do
		if connection then
			connection:Disconnect()
		end
	end
	stateConnection = nil
	heartbeatConnection = nil
	diedConnection = nil
	landMarkerConnection = nil
	hardMarkerConnection = nil
	landTrack = nil
	hardLandTrack = nil
	humanoid = nil
	root = nil
	airborne = false
	clearPenalty()
end

local function bindCharacter(character: Model)
	clearCharacter()
	local newHumanoid = character:WaitForChild("Humanoid") :: Humanoid
	local newRoot = character:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = newHumanoid:WaitForChild("Animator", Movement.ServerCharacterWaitTimeout)
	humanoid = newHumanoid
	root = newRoot
	apexY = newRoot.Position.Y
	if animator and animator:IsA("Animator") then
		landTrack = loadTrack(animator, Animations.Land)
		hardLandTrack = loadTrack(animator, Animations.LandHard)
		if landTrack then
			landMarkerConnection = landTrack:GetMarkerReachedSignal(Animations.Markers.LandImpact):Connect(function()
				if activePayload then
					impactEvent:Fire(activePayload)
				end
			end)
		end
		if hardLandTrack then
			hardMarkerConnection = hardLandTrack:GetMarkerReachedSignal(Animations.Markers.LandImpact):Connect(function()
				if activePayload then
					impactEvent:Fire(activePayload)
				end
			end)
		end
	end
	stateConnection = newHumanoid.StateChanged:Connect(function(_old, new)
		if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
			if not airborne then
				airborne = true
				apexY = newRoot.Position.Y
			end
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			onLanded()
		end
	end)
	heartbeatConnection = RunService.PostSimulation:Connect(function()
		if humanoid ~= newHumanoid or root ~= newRoot then
			return
		end
		if newHumanoid.FloorMaterial == Enum.Material.Air then
			if not airborne then
				airborne = true
				apexY = newRoot.Position.Y
			end
			apexY = math.max(apexY, newRoot.Position.Y)
		elseif airborne then
			onLanded()
		end
	end)
	diedConnection = newHumanoid.Died:Connect(clearCharacter)
end

function LandingController.start(startOptions: Options?)
	if started then
		return
	end
	started = true
	options = startOptions or {}
	LocalPlayer.CharacterAdded:Connect(bindCharacter)
	if LocalPlayer.Character then
		task.spawn(bindCharacter, LocalPlayer.Character)
	end
end

return LandingController
