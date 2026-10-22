--!strict
-- ServerScriptService/TagService.server.lua
-- Owner: Project Owner
-- Responsibility: validate click tag requests, select a target, and replicate third-person tag animation.
-- Task/spec: simple click tagging with perspective-specific animations, approved 2026-10-18.
-- Task/spec: Agawan ng Panyo server-validated steals, approved 2026-10-23.
-- Task/spec: Lihim na Target assigned-target captures, approved 2026-10-23.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PanyoMode = require(ServerScriptService:WaitForChild("PanyoMode"))
local SecretHuntMode = require(ServerScriptService:WaitForChild("SecretHuntMode"))
local TagRules = require(ReplicatedStorage:WaitForChild("TagRules"))
local RequestTag = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestTag") :: RemoteEvent
local commitInstance = ServerScriptService:WaitForChild("HRUSH_CommitTag", 10)
assert(commitInstance ~= nil and commitInstance:IsA("BindableFunction"), "HRUSH_CommitTag missing")
local CommitTag = commitInstance :: BindableFunction

type AnimationState = {
	character: Model,
	track: AnimationTrack,
}

local lastRequestAt: { [Player]: number } = {}
local animationStates: { [Player]: AnimationState } = {}
local minimumFacingDot = math.cos(math.rad(Config.Tag.ActionMaxAngle))

local function getLiveRig(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return character, humanoid, nil
	end
	return character, humanoid, root
end

local function clearAnimation(player: Player)
	local state = animationStates[player]
	if state ~= nil then
		state.track:Stop(0)
		state.track:Destroy()
		animationStates[player] = nil
	end
end

local function getThirdPersonTrack(player: Player, character: Model, humanoid: Humanoid): AnimationTrack?
	local state = animationStates[player]
	if state ~= nil and state.character == character then
		return state.track
	end
	clearAnimation(player)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = Config.Tag.ThirdPersonAnimationId
	local ok, loaded = pcall(function(): AnimationTrack
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		warn("[TagService] Failed to load the third-person tag animation")
		return nil
	end
	loaded.Priority = Enum.AnimationPriority.Action4
	loaded.Looped = false
	animationStates[player] = { character = character, track = loaded }
	return loaded
end

local function playThirdPersonAnimation(player: Player, character: Model, humanoid: Humanoid)
	local track = getThirdPersonTrack(player, character, humanoid)
	if track == nil then
		return
	end
	if track.IsPlaying then
		track:Stop(0)
	end
	track:Play(Config.Tag.AnimationFade, 1, 1)
end

local function canAttempt(player: Player): (boolean, Model?, Humanoid?, BasePart?)
	local isPanyo = player:GetAttribute("HRushGameMode") == "AgawanNgPanyo"
	local isHunt = player:GetAttribute("HRushGameMode") == "SecretHunt"
	if player:GetAttribute("HRushInMatch") ~= true
		or player:GetAttribute("HRushState") ~= "MS_04"
		or (if isPanyo then not PanyoMode.CanAttemptSteal(player)
			else if isHunt then not SecretHuntMode.CanAttemptCapture(player)
			else player:GetAttribute("HRushRole") ~= "Taya")
		or player:GetAttribute("HRushStunned") == true
		or player:GetAttribute("HRushAbilityBusy") == true
	then
		return false, nil, nil, nil
	end
	local character, humanoid, root = getLiveRig(player)
	return root ~= nil, character, humanoid, root
end

local function lineOfSight(taggerCharacter: Model, targetCharacter: Model, from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { taggerCharacter, targetCharacter }
	params.IgnoreWater = true
	return Workspace:Raycast(from, to - from, params) == nil
end

local function validTarget(
	target: Player,
	tagger: Player,
	taggerCharacter: Model,
	taggerRoot: BasePart,
	box: CFrame
): (boolean, number)
	if target:GetAttribute("HRushInMatch") ~= true or target:GetAttribute("HRushRole") ~= "Runner" then
		return false, math.huge
	end
	local targetCharacter, _, targetRoot = getLiveRig(target)
	if targetCharacter == nil or targetRoot == nil then
		return false, math.huge
	end
	local now = Workspace:GetServerTimeNow()
	if target:GetAttribute("HRushGameMode") == "AgawanNgPanyo" then
		if target ~= PanyoMode.GetCarrier() or not PanyoMode.CanBeStolen(target) then
			return false, math.huge
		end
	elseif target:GetAttribute("HRushGameMode") == "SecretHunt" then
		if not SecretHuntMode.CanCaptureTarget(tagger, target) then
			return false, math.huge
		end
	else
		local safeUntil = target:GetAttribute("HRushTagSafeUntil")
		if typeof(safeUntil) == "number" and safeUntil > now then
			return false, math.huge
		end
	end
	local immuneUntil = target:GetAttribute("HRushTagActionImmuneUntil")
	if typeof(immuneUntil) == "number" and immuneUntil > now then
		return false, math.huge
	end
	if TagRules.isUntouchable(targetCharacter) then
		return false, math.huge
	end

	local targetHeight = if target:GetAttribute("HRushServerSliding") == true
		then Config.Tag.SlidingTargetOffset
		else Config.Tag.StandingTargetOffset
	local targetPoint = targetRoot.Position + Vector3.new(0, targetHeight, 0)
	local localPoint = box:PointToObjectSpace(targetPoint)
	local halfSize = Config.Tag.ActionHitboxSize * 0.5
	if math.abs(localPoint.X) > halfSize.X
		or math.abs(localPoint.Y) > halfSize.Y
		or math.abs(localPoint.Z) > halfSize.Z
	then
		return false, math.huge
	end

	local delta = targetPoint - taggerRoot.Position
	if delta.Magnitude > Config.Tag.ActionRange then
		return false, math.huge
	end
	local flatDelta = Vector3.new(delta.X, 0, delta.Z)
	local flatFacing = Vector3.new(taggerRoot.CFrame.LookVector.X, 0, taggerRoot.CFrame.LookVector.Z)
	if flatDelta.Magnitude <= 0.05 or flatFacing.Magnitude <= 0.05
		or flatDelta.Unit:Dot(flatFacing.Unit) < minimumFacingDot
	then
		return false, math.huge
	end
	if not lineOfSight(taggerCharacter, targetCharacter, taggerRoot.Position + Vector3.new(0, 1, 0), targetPoint) then
		return false, math.huge
	end
	return true, delta.Magnitude
end

local function findTarget(tagger: Player, taggerCharacter: Model, taggerRoot: BasePart): Player?
	local facing = Vector3.new(taggerRoot.CFrame.LookVector.X, 0, taggerRoot.CFrame.LookVector.Z)
	if facing.Magnitude <= 0.05 then
		return nil
	end
	local box = CFrame.lookAt(taggerRoot.Position, taggerRoot.Position + facing.Unit)
		* CFrame.new(Config.Tag.ActionHitboxOffset)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { taggerCharacter }

	local candidates: { [Player]: boolean } = {}
	for _, part in Workspace:GetPartBoundsInBox(box, Config.Tag.ActionHitboxSize, overlap) do
		local model = part:FindFirstAncestorOfClass("Model")
		local player = if model ~= nil then Players:GetPlayerFromCharacter(model) else nil
		if player ~= nil and player ~= tagger then
			candidates[player] = true
		end
	end

	local closest: Player? = nil
	local closestDistance = math.huge
	for player in candidates do
		local valid, distance = validTarget(player, tagger, taggerCharacter, taggerRoot, box)
		if valid and distance < closestDistance then
			closest = player
			closestDistance = distance
		end
	end
	return closest
end

RequestTag.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (lastRequestAt[player] or 0) < Config.Tag.ActionRequestInterval then
		return
	end
	lastRequestAt[player] = now

	local allowed, character, humanoid, root = canAttempt(player)
	if not allowed or character == nil or humanoid == nil or root == nil then
		return
	end
	playThirdPersonAnimation(player, character, humanoid)
	local target = findTarget(player, character, root)
	if target ~= nil then
		CommitTag:Invoke(player, target)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastRequestAt[player] = nil
	clearAnimation(player)
end)
