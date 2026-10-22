--!strict
-- ServerScriptService/MovementAuthority.lua
-- Owner: Project Owner
-- Responsibility: server movement request validation, state ledger, and passive observation.
-- Task/spec: simple click-to-tag integration, approved 2026-10-18.
-- Task/spec: movement upgrade Part 2 landing and Vault validation, approved 2026-10-16.
-- Task/spec: momentum slice 1, server-owned gains, decay, and speed allowance, 2026-10-19.
-- Task/spec: momentum steps 2 to 4, validated roll intent and character tier, 2026-10-19.
-- Task/spec: slide chaining and entry speed, 2026-10-19.
-- Task/spec: server-owned equipment launch and glide bridge, 2026-10-22.
-- Task/spec: accepted-dash cosmetic broadcast, approved 2026-10-22.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local MomentumRules = require(ReplicatedStorage:WaitForChild("MomentumRules"))

type Ledger = {
	state: string,
	dashUntil: number,
	dashReadyAt: number,
	slideUntil: number,
	slideReadyAt: number,
	rollUntil: number,
	rollBaseSpeed: number,
	rollRequestUntil: number,
	rollRequestedAt: number,
	rollIntentAt: number,
	vaultUntil: number,
	vaultReadyAt: number,
	vaultAllowedSpeed: number,
	recentVelocity: Vector3,
	recentVelocityAt: number,
	lastAirborneAt: number,
	airborne: boolean,
	airStartedAt: number,
	lastGroundedAt: number,
	lastVerticalVelocity: number,
	takeoffObserved: boolean,
	airTimeReported: boolean,
	airPeakY: number,
	hardLandUntil: number,
	boostUntil: number,
	momentum: number,
	momentumGainAt: number,
	momentumSampleAt: number,
	momentumSyncAt: number,
	momentumSeq: number,
	momentumMoves: { [string]: { at: number, count: number } },
	requestWindowStartedAt: number,
	requestCount: number,
	lastPosition: Vector3?,
	lastSampleAt: number,
	lastRole: string,
	violations: { [string]: number },
	totalViolations: number,
	diedConnection: RBXScriptConnection?,
	connections: { RBXScriptConnection },
}

type EquipmentGlide = {
	sourceId: string,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	params: RaycastParams,
	phase: string,
	acceptedAt: number,
	phaseStartedAt: number,
	glideStartY: number,
	origin: Vector3,
	launchRise: number,
	launchDuration: number,
	duration: number,
	horizontalSpeedCap: number,
	downwardSpeed: number,
	maxTravelDistance: number,
	steeringTurnDegreesPerSecond: number,
	direction: Vector3,
	speed: number,
	steer: Vector3,
	steerAt: number,
	onPhase: (string) -> (),
	onEnded: (string) -> (),
	previousNetworkOwner: Player?,
	restoreAutoOwnership: boolean,
}

local MovementAuthority = {}

local started = false
local movement: any = nil
local momentum: any = nil
local momentumUpdate: RemoteEvent
local dashVfxEvent: UnreliableRemoteEvent
local ledgers: { [Player]: Ledger } = {}
local equipmentGlides: { [Player]: EquipmentGlide } = {}

local function updateMomentumTier(player: Player, value: number)
	local character = player.Character
	if character == nil then return end
	local current = character:GetAttribute("MomentumTier")
	local nextTier, changed = MomentumRules.tierTransition(if typeof(current) == "number" then current else -1, value)
	if changed then character:SetAttribute("MomentumTier", nextTier) end
end

local function sendMomentum(player: Player, ledger: Ledger, now: number, action: string?, gain: number?, count: number?, perfect: boolean?, rejectedAction: string?)
	ledger.momentumSeq += 1
	ledger.momentumSyncAt = now
	local serverTime = Workspace:GetServerTimeNow()
	momentumUpdate:FireClient(player, {
		value = ledger.momentum,
		sequence = ledger.momentumSeq,
		serverTime = serverTime,
		lastGainAt = if ledger.momentumGainAt > 0 then serverTime - (now - ledger.momentumGainAt) else 0,
		action = action,
		gain = gain,
		count = count,
		perfect = perfect,
		rejectedAction = rejectedAction,
	})
end

local function grantMomentum(player: Player, ledger: Ledger, action: string, baseGain: number, now: number, perfect: boolean?)
	if player:GetAttribute("HRushRole") == "Taya" and not momentum.TayaBuildsMomentum then
		return
	end
	local previous = ledger.momentumMoves[action]
	local value, gain, count = MomentumRules.gain(
		ledger.momentum, baseGain,
		if previous then previous.at else -math.huge,
		if previous then previous.count else 0,
		now
	)
	ledger.momentum = value
	updateMomentumTier(player, value)
	ledger.momentumGainAt = now
	ledger.momentumMoves[action] = { at = now, count = count }
	if momentum.Debug and action == "Slide" then
		print(string.format("[Momentum] slide gain awarded: %s +%.2f total=%.2f count=%d",
			player.Name, gain, value, count))
	end
	sendMomentum(player, ledger, now, action, gain, count, perfect)
end

local function finiteNumber(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function finiteVector(value: unknown): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end
	local vector = value :: Vector3
	return finiteNumber(vector.X) and finiteNumber(vector.Y) and finiteNumber(vector.Z)
end

local function setState(player: Player, ledger: Ledger, state: string)
	ledger.state = state
	player:SetAttribute("HRushMovementState", state)
	player:SetAttribute("HRushServerSliding", state == "Slide")
	player:SetAttribute("HRushServerDashing", state == "Dash")
	player:SetAttribute("HRushServerRolling", state == "Roll")
	player:SetAttribute("HRushServerVaulting", state == "Vault")
	if state ~= "Vault" then
		player:SetAttribute("HRushServerVaultVariant", "")
	end
end

local function resetLedger(player: Player, ledger: Ledger)
	ledger.dashUntil = 0
	ledger.dashReadyAt = 0
	ledger.slideUntil = 0
	ledger.slideReadyAt = 0
	ledger.rollUntil = 0
	ledger.rollBaseSpeed = 0
	ledger.rollRequestUntil = 0
	ledger.rollRequestedAt = 0
	ledger.rollIntentAt = 0
	ledger.vaultUntil = 0
	ledger.vaultReadyAt = 0
	ledger.vaultAllowedSpeed = 0
	ledger.recentVelocity = Vector3.zero
	ledger.recentVelocityAt = 0
	ledger.lastAirborneAt = -math.huge
	ledger.airborne = false
	ledger.airStartedAt = 0
	ledger.lastGroundedAt = os.clock()
	ledger.lastVerticalVelocity = 0
	ledger.takeoffObserved = false
	ledger.airTimeReported = false
	ledger.airPeakY = 0
	ledger.hardLandUntil = 0
	ledger.boostUntil = 0
	if ledger.momentum > 0 then
		ledger.momentum = 0
		ledger.momentumGainAt = 0
		sendMomentum(player, ledger, os.clock(), "Lost", 0)
	end
	ledger.momentumGainAt = 0
	ledger.momentumSampleAt = os.clock()
	ledger.momentumMoves = {}
	updateMomentumTier(player, 0)
	ledger.lastPosition = nil
	ledger.lastSampleAt = os.clock()
	player:SetAttribute("HRushServerAirborne", false)
	player:SetAttribute("HRushServerFallHeight", 0)
	player:SetAttribute("HRushServerLandingClass", "")
	player:SetAttribute("HRushServerHardLandUntil", 0)
	setState(player, ledger, "Walk")
end

local function recordViolation(player: Player, ledger: Ledger, reason: string, detail: string)
	local count = (ledger.violations[reason] or 0) + 1
	ledger.violations[reason] = count
	ledger.totalViolations += 1
	player:SetAttribute("HRushMovementViolations", ledger.totalViolations)
	if movement.ServerLogsEnabled and count == movement.ServerLogViolationThreshold then
		warn(string.format("[MovementAuthority] %s: %s (%s)", player.Name, reason, detail))
	end
	-- A rejected predicted slide or roll should return to the authoritative
	-- value immediately instead of waiting for the next idle sync.
	if string.sub(reason, 1, 6) == "slide_" or string.sub(reason, 1, 5) == "roll_" then
		sendMomentum(player, ledger, os.clock(), nil, nil, nil, nil,
			if string.sub(reason, 1, 6) == "slide_" then "Slide" else "Roll")
	end
end

local function withinRequestRate(player: Player, ledger: Ledger, now: number): boolean
	if now - ledger.requestWindowStartedAt >= movement.ServerRequestWindow then
		ledger.requestWindowStartedAt = now
		ledger.requestCount = 0
	end
	ledger.requestCount += 1
	if ledger.requestCount > movement.ServerRequestRate then
		recordViolation(player, ledger, "request_rate", tostring(ledger.requestCount))
		return false
	end
	return true
end

local function liveCharacter(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if character == nil then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

local function isLiveParticipant(player: Player): boolean
	return player:GetAttribute("HRushInMatch") == true
		and player:GetAttribute("HRushState") == "MS_04"
		and ReplicatedStorage:GetAttribute("HRushRoundState") == "MS_04"
end

local function horizontalSpeed(root: BasePart): number
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

local function roleSpeed(player: Player, sprinting: boolean): number
	if player:GetAttribute("HRushRole") == "Taya" then
		return (if sprinting then movement.TayaSprintSpeed else movement.TayaSpeed) * movement.SpeedScale
	end
	local base = if sprinting then movement.RunnerSprintSpeed else movement.RunnerWalkSpeed
	return base * movement.SpeedScale
end

local function allowedSpeed(player: Player, ledger: Ledger, now: number): number
	if ledger.state == "Dash" and now < ledger.dashUntil then
		return movement.DashDistance * movement.SpeedScale / movement.DashDuration
	end
	if ledger.state == "Roll" and now < ledger.rollUntil then
		return MomentumRules.speed(ledger.rollBaseSpeed, 1, 1, ledger.momentum)
	end
	if ledger.state == "Vault" and now < ledger.vaultUntil then
		return math.min(momentum.GlobalSpeedCeiling, ledger.vaultAllowedSpeed)
	end

	local exTayaMult = if now < ledger.boostUntil and player:GetAttribute("HRushRole") == "Runner"
		then movement.PostTagSpeedBoostMult else 1
	local hardLandMult = if now < ledger.hardLandUntil then movement.HardLandSpeedMult else 1
	local baseSpeed = roleSpeed(player, ledger.state == "Slide" or ledger.state == "Sprint")
	return MomentumRules.speed(baseSpeed, exTayaMult, hardLandMult, ledger.momentum)
end

local function validateCommon(player: Player, ledger: Ledger): (Humanoid?, BasePart?)
	if not isLiveParticipant(player) then
		recordViolation(player, ledger, "request_state", tostring(player:GetAttribute("HRushState")))
		return nil, nil
	end
	if player:GetAttribute("HRushStunned") == true then
		recordViolation(player, ledger, "request_stunned", ledger.state)
		return nil, nil
	end
	local humanoid, root = liveCharacter(player)
	if humanoid == nil or root == nil then
		recordViolation(player, ledger, "request_character", "not alive")
		return nil, nil
	end
	return humanoid, root
end

local function glideParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	return params
end

local function glideBox(humanoid: Humanoid, root: BasePart): Vector3
	return Vector3.new(
		math.max(root.Size.X + 1, 3),
		root.Size.Y + humanoid.HipHeight * 2,
		math.max(root.Size.Z + 1, 3)
	)
end

local function notifyGlidePhase(record: EquipmentGlide, phase: string)
	record.phase = phase
	local ok, err = pcall(record.onPhase, phase)
	if not ok then warn("[MovementAuthority] equipment glide phase callback: " .. tostring(err)) end
end

local function finishEquipmentGlide(player: Player, reason: string, notify: boolean): boolean
	local record = equipmentGlides[player]
	if record == nil then return false end
	equipmentGlides[player] = nil
	if record.character:GetAttribute("HRushMovementState") == "Glide" then
		record.character:SetAttribute("HRushMovementState", nil)
	end
	record.character:SetAttribute("HRushEquipmentGlide", nil)
	local ledger = ledgers[player]
	if ledger ~= nil and ledger.state == "Glide" then
		setState(player, ledger, "Walk")
		ledger.lastPosition = nil
		ledger.lastSampleAt = os.clock()
		if record.humanoid.FloorMaterial == Enum.Material.Air then
			ledger.airStartedAt = os.clock()
			ledger.takeoffObserved = true
		end
	end
	if record.root.Parent ~= nil then
		if reason == "Landed" or record.phase == "Launching" then
			record.root.AssemblyLinearVelocity = Vector3.zero
		else
			record.root.AssemblyLinearVelocity = record.direction * record.speed
				- Vector3.yAxis * record.downwardSpeed
		end
		pcall(function()
			if record.restoreAutoOwnership then
				record.root:SetNetworkOwnershipAuto()
			else
				record.root:SetNetworkOwner(record.previousNetworkOwner)
			end
		end)
	end
	if notify then
		local ok, err = pcall(record.onEnded, reason)
		if not ok then warn("[MovementAuthority] equipment glide end callback: " .. tostring(err)) end
	end
	return true
end

local function validGlideNumber(value: any, maximum: number): boolean
	return typeof(value) == "number" and finiteNumber(value :: number)
		and value > 0 and value <= maximum
end

function MovementAuthority.beginEquipmentGlide(
	player: Player,
	request: any,
	onPhase: (string) -> (),
	onEnded: (string) -> ()
): (boolean, string?)
	if not started or movement == nil then return false, "Unavailable" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return false, "InvalidPlayer"
	end
	if typeof(request) ~= "table" or type(onPhase) ~= "function" or type(onEnded) ~= "function" then
		return false, "InvalidRequest"
	end
	if typeof(request.sourceId) ~= "string" or #request.sourceId == 0 or #request.sourceId > 128 then
		return false, "InvalidRequest"
	end
	if request.mode ~= "GroundLaunch" and request.mode ~= "AirborneGlide" then
		return false, "InvalidMode"
	end
	if not validGlideNumber(request.duration, movement.EquipmentGlideMaxDuration)
		or not validGlideNumber(request.launchRise, movement.EquipmentGlideMaxLaunchRise)
		or not validGlideNumber(request.launchDuration, movement.EquipmentGlideMaxLaunchDuration)
		or not validGlideNumber(request.horizontalSpeedCap, movement.EquipmentGlideMaxHorizontalSpeed)
		or not validGlideNumber(request.downwardSpeed, movement.EquipmentGlideMaxDownwardSpeed)
		or not validGlideNumber(request.maxTravelDistance, movement.EquipmentGlideMaxTravelDistance)
		or not validGlideNumber(request.steeringTurnDegreesPerSecond, movement.EquipmentGlideMaxTurnDegreesPerSecond)
	then
		return false, "InvalidRequest"
	end
	local ledger = ledgers[player]
	if ledger == nil or not isLiveParticipant(player) then return false, "RoundEnd" end
	if equipmentGlides[player] ~= nil then return false, "AlreadyGliding" end
	if player:GetAttribute("HRushStunned") == true
		or player:GetAttribute("IsAirborne") == true
		or player:GetAttribute("HRushPouncing") == true
		or (ledger.state ~= "Walk" and ledger.state ~= "Sprint")
	then
		return false, "BlockedState"
	end
	local character = player.Character
	local humanoid, root = liveCharacter(player)
	if character == nil or humanoid == nil or root == nil or root.Anchored then
		return false, "CharacterUnavailable"
	end
	local canOwn = root:CanSetNetworkOwnership()
	if not canOwn then return false, "NetworkOwnership" end
	local params = glideParams(character)
	local box = glideBox(humanoid, root)
	if request.mode == "GroundLaunch" then
		if humanoid.FloorMaterial == Enum.Material.Air then return false, "NotGrounded" end
		local rise = request.launchRise :: number
		local headroom = rise + movement.EquipmentGlideCeilingPadding
		if Workspace:Raycast(root.Position, Vector3.yAxis * headroom, params) ~= nil
			or Workspace:Blockcast(root.CFrame, box, Vector3.yAxis * headroom, params) ~= nil
		then
			return false, "NoHeadroom"
		end
	else
		if humanoid.FloorMaterial ~= Enum.Material.Air or root.AssemblyLinearVelocity.Y >= 0 then
			return false, "NotDescending"
		end
		local hit = Workspace:Raycast(root.Position,
			-Vector3.yAxis * movement.EquipmentGlideGroundProbeDepth, params)
		local feetY = root.Position.Y - root.Size.Y * 0.5 - humanoid.HipHeight
		if hit == nil or feetY - hit.Position.Y < movement.EquipmentGlideMinGroundClearance then
			return false, "NoClearance"
		end
	end
	local previousOwner = root:GetNetworkOwner()
	local ownerOk = pcall(function() root:SetNetworkOwner(nil) end)
	if not ownerOk then return false, "NetworkOwnership" end
	local flatVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local direction = if flatVelocity.Magnitude > movement.ServerDirectionMinMagnitude
		then flatVelocity.Unit else if facing.Magnitude > 0 then facing.Unit else Vector3.zAxis
	local now = os.clock()
	local record: EquipmentGlide = {
		sourceId = request.sourceId,
		character = character,
		humanoid = humanoid,
		root = root,
		params = params,
		phase = "",
		acceptedAt = now,
		phaseStartedAt = now,
		glideStartY = root.Position.Y,
		origin = root.Position,
		launchRise = request.launchRise,
		launchDuration = request.launchDuration,
		duration = request.duration,
		horizontalSpeedCap = request.horizontalSpeedCap,
		downwardSpeed = request.downwardSpeed,
		maxTravelDistance = request.maxTravelDistance,
		steeringTurnDegreesPerSecond = request.steeringTurnDegreesPerSecond,
		direction = direction,
		speed = math.min(flatVelocity.Magnitude, request.horizontalSpeedCap),
		steer = Vector3.zero,
		steerAt = 0,
		onPhase = onPhase,
		onEnded = onEnded,
		previousNetworkOwner = previousOwner,
		restoreAutoOwnership = previousOwner == player,
	}
	equipmentGlides[player] = record
	character:SetAttribute("HRushMovementState", "Glide")
	character:SetAttribute("HRushEquipmentGlide", true)
	setState(player, ledger, "Glide")
	ledger.rollRequestUntil = 0
	ledger.rollRequestedAt = 0
	ledger.rollIntentAt = 0
	notifyGlidePhase(record, if request.mode == "GroundLaunch" then "Launching" else "Gliding")
	return true, nil
end

function MovementAuthority.endEquipmentGlide(player: Player, sourceId: string, reason: string): boolean
	local record = equipmentGlides[player]
	if record == nil or record.sourceId ~= sourceId then return false end
	return finishEquipmentGlide(player, if type(reason) == "string" then reason else "Cancelled", false)
end

local function steerEquipmentGlide(player: Player, value: unknown)
	local record = equipmentGlides[player]
	if record == nil or not finiteVector(value) then return end
	local input = value :: Vector3
	if math.abs(input.Y) > movement.ServerDirectionMinMagnitude or input.Magnitude > 1.1 then return end
	local now = os.clock()
	if now - record.steerAt < movement.EquipmentGlideSteerMinInterval then return end
	record.steer = if input.Magnitude > movement.ServerDirectionMinMagnitude then input.Unit else Vector3.zero
	record.steerAt = now
end

local function stepEquipmentGlide(player: Player, now: number, dt: number)
	local record = equipmentGlides[player]
	if record == nil then return end
	if not isLiveParticipant(player) then
		finishEquipmentGlide(player, "RoundEnd", true)
		return
	end
	if player.Character ~= record.character or record.root.Parent == nil then
		finishEquipmentGlide(player, "CharacterRemoving", true)
		return
	end
	if record.humanoid.Health <= 0 then
		finishEquipmentGlide(player, "Death", true)
		return
	end
	local delta: Vector3
	if record.phase == "Launching" then
		local alpha = math.clamp((now - record.phaseStartedAt) / record.launchDuration, 0, 1)
		local target = Vector3.new(record.origin.X,
			record.origin.Y + record.launchRise * alpha, record.origin.Z)
		delta = target - record.root.Position
	else
		if now - record.phaseStartedAt >= record.duration then
			finishEquipmentGlide(player, "Duration", true)
			return
		end
		local feetY = record.root.Position.Y - record.root.Size.Y * 0.5 - record.humanoid.HipHeight
		local floor = Workspace:Raycast(record.root.Position,
			-Vector3.yAxis * (record.root.Size.Y * 0.5 + record.humanoid.HipHeight + 1), record.params)
		if floor ~= nil
			and floor.Normal.Y >= movement.VaultLandingNormalMin
			and feetY - floor.Position.Y <= movement.EquipmentGlideLandingTolerance
		then
			finishEquipmentGlide(player, "Landed", true)
			return
		end
		local steer = if now - record.steerAt <= movement.EquipmentGlideSteerTimeout
			then record.steer else Vector3.zero
		if steer.Magnitude > 0 then
			local current = record.direction
			local angle = math.atan2(current.X * steer.Z - current.Z * steer.X, current:Dot(steer))
			local maxTurn = math.rad(record.steeringTurnDegreesPerSecond) * dt
			local turn = math.clamp(angle, -maxTurn, maxTurn)
			record.direction = CFrame.fromAxisAngle(Vector3.yAxis, -turn):VectorToWorldSpace(current).Unit
			record.speed = record.horizontalSpeedCap
		end
		local targetY = record.glideStartY - record.downwardSpeed * (now - record.phaseStartedAt)
		delta = record.direction * record.speed * dt
			+ Vector3.yAxis * (targetY - record.root.Position.Y)
		local startOffset = record.root.Position - record.origin
		local flatStart = Vector3.new(startOffset.X, 0, startOffset.Z)
		local flatDelta = Vector3.new(delta.X, 0, delta.Z)
		if (flatStart + flatDelta).Magnitude > record.maxTravelDistance then
			local low, high = 0.0, 1.0
			for _ = 1, 12 do
				local mid = (low + high) * 0.5
				if (flatStart + flatDelta * mid).Magnitude <= record.maxTravelDistance then
					low = mid
				else
					high = mid
				end
			end
			delta *= low
		end
	end
	if delta.Magnitude > 0 then
		local hit = Workspace:Blockcast(record.root.CFrame,
			glideBox(record.humanoid, record.root), delta, record.params)
		if hit ~= nil then
			local safeDistance = math.max(0, hit.Distance - movement.EquipmentGlideCollisionSkin)
			if safeDistance > 0 then
				record.character:PivotTo(record.character:GetPivot() + delta.Unit * safeDistance)
			end
			finishEquipmentGlide(player,
				if record.phase == "Gliding" and hit.Normal.Y >= movement.VaultLandingNormalMin
					then "Landed" else "Obstruction", true)
			return
		end
		record.character:PivotTo(record.character:GetPivot() + delta)
	end
	record.root.AssemblyLinearVelocity = Vector3.zero
	record.root.AssemblyAngularVelocity = Vector3.zero
	if record.phase == "Launching" then
		if now - record.phaseStartedAt >= record.launchDuration then
			record.phaseStartedAt = now
			record.glideStartY = record.root.Position.Y
			notifyGlidePhase(record, "Gliding")
		end
	else
		local offset = record.root.Position - record.origin
		if Vector3.new(offset.X, 0, offset.Z).Magnitude >= record.maxTravelDistance - movement.EquipmentGlideCollisionSkin then
			finishEquipmentGlide(player, "Distance", true)
		end
	end
end

local function beginRoll(player: Player, ledger: Ledger, root: BasePart, role: string, now: number)
	local baseSpeed = roleSpeed(player, role == "Runner")
	if now < ledger.boostUntil and role == "Runner" then
		baseSpeed *= movement.PostTagSpeedBoostMult
	end
	local carriedSpeed = math.min(
		horizontalSpeed(root),
		baseSpeed * (1 + movement.ServerSpeedTolerancePct)
	)
	local walkSpeed = roleSpeed(player, false)
	local priorMomentum = ledger.momentum
	ledger.rollRequestUntil = 0
	-- Compare the two ordered client requests as received by the server. FloorMaterial
	-- may replicate later, so that observation delay must not cancel a valid intent.
	local perfect = MomentumRules.perfectRoll(ledger.rollIntentAt,
		if ledger.rollRequestedAt > 0 then ledger.rollRequestedAt else now)
	ledger.rollRequestedAt = 0
	ledger.rollIntentAt = 0
	ledger.hardLandUntil = 0
	player:SetAttribute("HRushServerHardLandUntil", 0)
	grantMomentum(player, ledger, "Roll", if perfect then momentum.GainRollPerfect else momentum.GainRoll, now, perfect)
	ledger.rollBaseSpeed = math.max(walkSpeed, carriedSpeed - priorMomentum)
	ledger.rollUntil = now + movement.RollDuration
	setState(player, ledger, "Roll")
end

type VaultCheck = {
	travel: number,
	variant: string,
}

local function findVaultTravel(
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	direction: Vector3,
	entrySpeed: number
): VaultCheck?
	local rootToFeet = root.Size.Y * 0.5 + humanoid.HipHeight
	local feetY = root.Position.Y - rootToFeet
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local groundHit = Workspace:Raycast(root.Position, Vector3.new(0, -movement.VaultGroundProbeDepth, 0), params)
	if groundHit == nil then
		return nil
	end

	local obstacleHit: RaycastResult? = nil
	for _, probeHeight in { movement.VaultKneeHeight, movement.VaultWaistHeight, movement.VaultChestHeight } do
		local origin = Vector3.new(root.Position.X, feetY + probeHeight, root.Position.Z)
		local hit = Workspace:Raycast(origin, direction * movement.VaultProbeDistance, params)
		if hit and hit.Instance:IsA("BasePart") and (obstacleHit == nil or hit.Distance < obstacleHit.Distance) then
			obstacleHit = hit
		end
	end
	if obstacleHit == nil then
		return nil
	end
	local obstacle = obstacleHit.Instance :: BasePart

	local topOrigin = Vector3.new(
		obstacleHit.Position.X + direction.X * movement.VaultTopInset,
		math.max(feetY + movement.VaultMaxH, groundHit.Position.Y + movement.VaultMaxAboveGround)
			+ movement.VaultTopProbeMargin,
		obstacleHit.Position.Z + direction.Z * movement.VaultTopInset
	)
	local topHit = Workspace:Raycast(
		topOrigin,
		Vector3.new(0, -(
			movement.VaultMaxAboveGround + movement.VaultGroundProbeDepth + movement.VaultTopProbeMargin * 2
		), 0),
		params
	)
	if topHit == nil or topHit.Instance ~= obstacle then
		return nil
	end
	local relativeHeight = topHit.Position.Y - feetY
	if relativeHeight < movement.VaultMinH - movement.VaultGeometryTolerance
		or relativeHeight > movement.VaultMaxH + movement.VaultGeometryTolerance
	then
		return nil
	end
	if topHit.Position.Y > groundHit.Position.Y + movement.VaultMaxAboveGround + movement.VaultGeometryTolerance then
		return nil
	end

	local half = obstacle.Size * 0.5
	local cf = obstacle.CFrame
	local extent = math.abs(direction:Dot(cf.RightVector)) * half.X
		+ math.abs(direction:Dot(cf.UpVector)) * half.Y
		+ math.abs(direction:Dot(cf.LookVector)) * half.Z
	local nearEdge = obstacleHit.Distance
	local farEdge = (obstacle.Position - root.Position):Dot(direction) + extent
	local depth = farEdge - nearEdge
	if depth <= 0 or depth > movement.VaultMaxDepth + movement.VaultGeometryTolerance then
		return nil
	end
	local travel = farEdge + movement.VaultLandingMargin
	if travel <= 0 or travel > movement.VaultMaxTravelDistance then
		return nil
	end

	local landingOrigin = Vector3.new(
		root.Position.X + direction.X * travel,
		topHit.Position.Y + movement.VaultTopProbeMargin,
		root.Position.Z + direction.Z * travel
	)
	local landingHit = Workspace:Raycast(
		landingOrigin,
		Vector3.new(0, -movement.VaultLandingProbeDepth, 0),
		params
	)
	if landingHit == nil then
		return nil
	end
	if topHit.Position.Y - landingHit.Position.Y < movement.VaultMinDrop - movement.VaultGeometryTolerance then
		return nil
	end
	local variant: string
	if humanoid.FloorMaterial == Enum.Material.Air then
		variant = "AirVault"
	elseif relativeHeight <= movement.VaultWaistHeight + movement.VaultGeometryTolerance then
		variant = "LowHop"
	elseif depth <= movement.VaultSpeedMaxDepth + movement.VaultGeometryTolerance
		and entrySpeed >= movement.RunnerSprintSpeed * movement.SpeedScale * movement.VaultSpeedVariantPct
	then
		variant = "SpeedVault"
	else
		variant = "StepVault"
	end
	return {
		travel = travel,
		variant = variant,
	}
end

local function handleMovementState(player: Player, action: unknown, active: unknown, directionValue: unknown)
	if action ~= "Sprint" and player:GetAttribute("HRushPouncing") == true then return end
	local ledger = ledgers[player]
	if ledger == nil then
		return
	end
	local now = os.clock()
	if not withinRequestRate(player, ledger, now) then
		return
	end
	if typeof(action) ~= "string" or typeof(active) ~= "boolean" then
		recordViolation(player, ledger, "request_schema", "movement state")
		return
	end
	if action ~= "Sprint" and action ~= "Slide" and action ~= "Roll" and action ~= "RollIntent" and action ~= "Vault" then
		recordViolation(player, ledger, "request_action", action)
		return
	end

	if not active then
		if action == "Roll" then
			ledger.rollRequestUntil = 0
			ledger.rollRequestedAt = 0
			ledger.rollIntentAt = 0
		elseif action == "RollIntent" then
			ledger.rollIntentAt = 0
		end
		if ledger.state == action then
			if action == "Roll" then
				ledger.rollUntil = 0
				ledger.rollBaseSpeed = 0
			end
			if action == "Vault" then
				ledger.vaultUntil = 0
				ledger.vaultAllowedSpeed = 0
			end
			setState(player, ledger, "Walk")
		end
		return
	end

	local humanoid, root = validateCommon(player, ledger)
	if humanoid == nil or root == nil then
		return
	end
	local role = player:GetAttribute("HRushRole")
	if role ~= "Runner" and role ~= "Taya" then
		recordViolation(player, ledger, "request_role", tostring(role))
		return
	end
	if equipmentGlides[player] ~= nil then
		if action == "Sprint" or action == "RollIntent" then return end
		finishEquipmentGlide(player, "Cancelled", true)
	end
	if action == "RollIntent" then
		if typeof(directionValue) ~= "number"
			or not MomentumRules.intentFresh(directionValue :: number, Workspace:GetServerTimeNow(),
				movement.RollWindow + movement.ServerSampleWindow)
		then
			recordViolation(player, ledger, "roll_intent_timestamp", "invalid or stale")
			return
		end
		if humanoid.FloorMaterial ~= Enum.Material.Air
			or player:GetAttribute("IsAirborne") == true
			or (ledger.state ~= "Walk" and ledger.state ~= "Sprint")
		then
			recordViolation(player, ledger, "roll_intent_state", ledger.state)
			return
		end
		ledger.rollIntentAt = now
		return
	end

	if action == "Sprint" then
		if ledger.state == "Roll" or ledger.state == "Vault" then
			recordViolation(player, ledger, "sprint_state", ledger.state)
			return
		end
		setState(player, ledger, "Sprint")
		return
	end

	if action == "Roll" then
		if player:GetAttribute("IsAirborne") == true then
			recordViolation(player, ledger, "roll_state", "skill_airborne")
			return
		end
		if ledger.state == "Slide" or ledger.state == "Dash" or ledger.state == "Roll" or ledger.state == "Vault" then
			recordViolation(player, ledger, "roll_state", ledger.state)
			return
		end
		ledger.rollRequestedAt = now
		if humanoid.FloorMaterial == Enum.Material.Air then
			-- Character ownership can make the client's confirmed landing arrive
			-- before FloorMaterial replicates to the server. Hold the request, then
			-- let the server's own observer accept only a prompt landing.
			if ledger.rollRequestUntil <= now then
				ledger.rollRequestUntil = now + movement.RollWindow + movement.ServerSampleWindow
			end
			return
		end
		local sinceAirborne = now - ledger.lastAirborneAt
		if sinceAirborne > movement.RollWindow + movement.ServerSampleWindow then
			recordViolation(player, ledger, "roll_window", string.format("%.3f", sinceAirborne))
			return
		end
		beginRoll(player, ledger, root, role, now)
		return
	end

	if action == "Vault" then
		if not finiteVector(directionValue) then
			recordViolation(player, ledger, "vault_direction", "not finite Vector3")
			return
		end
		local directionInput = directionValue :: Vector3
		local flatDirection = Vector3.new(directionInput.X, 0, directionInput.Z)
		local magnitude = flatDirection.Magnitude
		if magnitude < movement.ServerDirectionMinMagnitude or magnitude > movement.ServerDirectionMaxMagnitude then
			recordViolation(player, ledger, "vault_direction", string.format("magnitude %.2f", magnitude))
			return
		end
		if math.abs(directionInput.Y) > movement.ServerDirectionMinMagnitude then
			recordViolation(player, ledger, "vault_direction", string.format("vertical %.2f", directionInput.Y))
			return
		end
		if player:GetAttribute("IsAirborne") == true
			or ledger.state == "Dash"
			or ledger.state == "Roll"
			or ledger.state == "Vault"
		then
			recordViolation(player, ledger, "vault_state", ledger.state)
			return
		end
		if now < ledger.vaultReadyAt then
			recordViolation(player, ledger, "vault_cooldown", string.format("%.2f", ledger.vaultReadyAt - now))
			return
		end

		local observedVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		if now - ledger.recentVelocityAt <= movement.ServerSampleWindow
			and ledger.recentVelocity.Magnitude > observedVelocity.Magnitude
		then
			observedVelocity = ledger.recentVelocity
		end
		local minimumSpeed = movement.RunnerSprintSpeed * movement.SpeedScale * movement.VaultMinSpeedPct
		if observedVelocity.Magnitude < minimumSpeed * (1 - movement.ServerSpeedTolerancePct) then
			recordViolation(player, ledger, "vault_speed", string.format("%.2f < %.2f", observedVelocity.Magnitude, minimumSpeed))
			return
		end
		local direction = flatDirection.Unit
		if observedVelocity.Unit:Dot(direction) < movement.VaultDirectionMinDot then
			recordViolation(player, ledger, "vault_direction", "opposes observed travel")
			return
		end
		local character = player.Character
		if character == nil then
			return
		end
		local check = findVaultTravel(character, humanoid, root, direction, observedVelocity.Magnitude)
		if check == nil then
			recordViolation(player, ledger, "vault_obstacle", "no valid low obstacle and landing")
			return
		end

		local priorLimit = allowedSpeed(player, ledger, now)
		local carriedSpeed = math.min(
			observedVelocity.Magnitude,
			priorLimit * (1 + movement.ServerSpeedTolerancePct)
		)
		ledger.vaultAllowedSpeed = math.max(
			carriedSpeed * movement.VaultSpeedKeepPct,
			check.travel / movement.VaultDuration
		)
		ledger.hardLandUntil = 0
		player:SetAttribute("HRushServerHardLandUntil", 0)
		ledger.vaultReadyAt = now + movement.VaultCooldown
		ledger.vaultUntil = now + movement.VaultDuration
		setState(player, ledger, "Vault")
		player:SetAttribute("HRushServerVaultVariant", check.variant)
		return
	end

	if now < ledger.slideReadyAt then
		recordViolation(player, ledger, "slide_cooldown", string.format("%.2f", ledger.slideReadyAt - now))
		return
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		recordViolation(player, ledger, "slide_grounded", "airborne")
		return
	end
	if ledger.state == "Roll" or ledger.state == "Dash" or ledger.state == "Vault" then
		recordViolation(player, ledger, "slide_state", ledger.state)
		return
	end
	local entrySpeed = horizontalSpeed(root)
	-- The client flag can only withhold an award. A true flag alone never
	-- grants one: the server must independently observe the entry speed.
	local earnsMomentum = directionValue == true
		and MomentumRules.slideEligible(entrySpeed, roleSpeed(player, true))
	if momentum.Debug then
		print(string.format("[Momentum] server slide detected: %s state=%s speed=%.2f clientEligible=%s eligible=%s",
			player.Name, ledger.state, entrySpeed, tostring(directionValue), tostring(earnsMomentum)))
	end

	ledger.slideReadyAt = now + movement.SlideCooldown
	ledger.slideUntil = now + movement.SlideDuration
	ledger.hardLandUntil = 0
	player:SetAttribute("HRushServerHardLandUntil", 0)
	setState(player, ledger, "Slide")
	if earnsMomentum then
		grantMomentum(player, ledger, "Slide", momentum.GainSlide, now)
	else
		-- A valid slow slide has no gain event, popup, or chain step. This
		-- snapshot also corrects any client prediction based on a stale speed.
		sendMomentum(player, ledger, now, nil, nil, nil, nil, "Slide")
	end
end

local function handleDash(player: Player, direction: unknown)
	local ledger = ledgers[player]
	if ledger == nil then
		return
	end
	local now = os.clock()
	if not withinRequestRate(player, ledger, now) then
		return
	end
	if not finiteVector(direction) then
		recordViolation(player, ledger, "dash_direction", "not finite Vector3")
		return
	end
	local magnitude = (direction :: Vector3).Magnitude
	if magnitude < movement.ServerDirectionMinMagnitude or magnitude > movement.ServerDirectionMaxMagnitude then
		recordViolation(player, ledger, "dash_direction", string.format("magnitude %.2f", magnitude))
		return
	end

	local humanoid, root = validateCommon(player, ledger)
	if humanoid == nil or root == nil then
		return
	end
	if player:GetAttribute("HRushRole") ~= "Runner" then
		recordViolation(player, ledger, "dash_role", tostring(player:GetAttribute("HRushRole")))
		return
	end
	if now < ledger.dashReadyAt then
		recordViolation(player, ledger, "dash_cooldown", string.format("%.2f", ledger.dashReadyAt - now))
		return
	end
	if ledger.state == "Roll" or ledger.state == "Vault" then
		recordViolation(player, ledger, "dash_state", ledger.state)
		return
	end
	if equipmentGlides[player] ~= nil then
		finishEquipmentGlide(player, "Cancelled", true)
	end

	ledger.dashReadyAt = now + movement.DashCooldown
	ledger.dashUntil = now + movement.DashDuration
	player:SetAttribute("HRushTagActionImmuneUntil", Workspace:GetServerTimeNow() + movement.DashTagInvulnTime)
	setState(player, ledger, "Dash")
	local horizontal = Vector3.new((direction :: Vector3).X, 0, (direction :: Vector3).Z)
	if horizontal.Magnitude > 0.01 then
		dashVfxEvent:FireAllClients(player.UserId, horizontal.Unit, root.Position, Workspace:GetServerTimeNow())
	end
end

local function observePlayer(player: Player, ledger: Ledger, now: number)
	if ledger.momentum > 0 then
		local _, momentumRoot = liveCharacter(player)
		local moving = momentumRoot ~= nil and horizontalSpeed(momentumRoot) > momentum.MovingThreshold
		ledger.momentum = MomentumRules.decay(ledger.momentum, ledger.momentumGainAt,
			ledger.momentumSampleAt, now, moving)
		updateMomentumTier(player, ledger.momentum)
		if now - ledger.momentumSyncAt >= momentum.SyncInterval or ledger.momentum == 0 then
			sendMomentum(player, ledger, now, nil, nil)
		end
	elseif now - ledger.momentumSyncAt >= momentum.ZeroSyncInterval then
		sendMomentum(player, ledger, now, nil, nil)
	end
	ledger.momentumSampleAt = now
	if ledger.state == "Dash" and now >= ledger.dashUntil then
		setState(player, ledger, "Walk")
	elseif ledger.state == "Slide" and now >= ledger.slideUntil then
		setState(player, ledger, "Walk")
	elseif ledger.state == "Roll" and now >= ledger.rollUntil then
		ledger.rollBaseSpeed = 0
		setState(player, ledger, "Walk")
	elseif ledger.state == "Vault" and now >= ledger.vaultUntil then
		ledger.vaultAllowedSpeed = 0
		setState(player, ledger, "Walk")
	end

	local humanoid, root = liveCharacter(player)
	if root ~= nil then
		local velocity = root.AssemblyLinearVelocity
		local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		if flatVelocity.Magnitude >= ledger.recentVelocity.Magnitude
			or now - ledger.recentVelocityAt > movement.ServerSampleWindow
		then
			ledger.recentVelocity = flatVelocity
			ledger.recentVelocityAt = now
		end
	end
	if humanoid ~= nil and humanoid.FloorMaterial == Enum.Material.Air then
		ledger.lastAirborneAt = now
	end

	if humanoid ~= nil and root ~= nil then
		local scriptedAir = player:GetAttribute("IsAirborne") == true or ledger.state == "Vault" or ledger.state == "Glide"
			or player:GetAttribute("HRushPouncing") == true
		local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
		local verticalVelocity = root.AssemblyLinearVelocity.Y
		if grounded then
			if ledger.airborne then
				local airTime = now - ledger.airStartedAt
				if not scriptedAir
					and not ledger.airTimeReported
					and airTime > movement.ServerMaxAirTime + movement.ServerSampleWindow
				then
					recordViolation(player, ledger, "air_time", string.format("%.2f > %.2f", airTime, movement.ServerMaxAirTime))
				end
				local fallHeight = math.max(0, ledger.airPeakY - root.Position.Y)
				local landingClass = if fallHeight > movement.HardLandHeight then "Hard" else "Soft"
				player:SetAttribute("HRushServerFallHeight", fallHeight)
				player:SetAttribute("HRushServerLandingClass", landingClass)
				if landingClass == "Hard"
					and ledger.state ~= "Vault"
					and ledger.state ~= "Roll"
					and ledger.state ~= "Slide"
				then
					ledger.hardLandUntil = now + movement.HardLandPenaltyTime
					player:SetAttribute("HRushServerHardLandUntil", ledger.hardLandUntil)
				end
			end
			ledger.airborne = false
			ledger.airStartedAt = 0
			ledger.lastGroundedAt = now
			ledger.lastVerticalVelocity = verticalVelocity
			ledger.takeoffObserved = false
			ledger.airTimeReported = false
			player:SetAttribute("HRushServerAirborne", false)
		else
			if not ledger.airborne then
				ledger.airborne = true
				ledger.airStartedAt = now
				ledger.lastVerticalVelocity = verticalVelocity
				ledger.takeoffObserved = false
				ledger.airTimeReported = false
				ledger.airPeakY = root.Position.Y
				player:SetAttribute("HRushServerAirborne", true)
			end
			ledger.airPeakY = math.max(ledger.airPeakY, root.Position.Y)
			if not scriptedAir then
				local velocityTolerance = movement.JumpPower * movement.ServerSpeedTolerancePct
				if verticalVelocity > 0 then
					local takeoffLimit = movement.JumpPower * (1 + movement.ServerSpeedTolerancePct)
					if verticalVelocity > takeoffLimit then
						recordViolation(player, ledger, "jump_takeoff", string.format("%.2f > %.2f", verticalVelocity, takeoffLimit))
					end
					if not ledger.takeoffObserved then
						local sinceGrounded = now - ledger.lastGroundedAt
						if sinceGrounded > movement.CoyoteTime + movement.ServerSampleWindow then
							recordViolation(player, ledger, "jump_origin", string.format("%.3f after ground", sinceGrounded))
						end
						ledger.takeoffObserved = true
					elseif now - ledger.airStartedAt > movement.ServerTakeoffObservationTime
						and verticalVelocity > ledger.lastVerticalVelocity + velocityTolerance
					then
						recordViolation(player, ledger, "upward_gain", string.format("%.2f from %.2f", verticalVelocity, ledger.lastVerticalVelocity))
					end
				end
				local fallLimit = movement.TerminalFallSpeed * (1 + movement.ServerSpeedTolerancePct)
				if verticalVelocity < -fallLimit then
					recordViolation(player, ledger, "terminal_fall", string.format("%.2f < %.2f", verticalVelocity, -fallLimit))
				end
				local airTime = now - ledger.airStartedAt
				if not ledger.airTimeReported and airTime > movement.ServerMaxAirTime + movement.ServerSampleWindow then
					ledger.airTimeReported = true
					recordViolation(player, ledger, "air_time", string.format("%.2f > %.2f", airTime, movement.ServerMaxAirTime))
				end
			end
			ledger.lastVerticalVelocity = verticalVelocity
		end
	end

	if not isLiveParticipant(player)
		or player:GetAttribute("HRushStunned") == true
		or player:GetAttribute("IsAirborne") == true
		or equipmentGlides[player] ~= nil
	then
		ledger.lastPosition = nil
		ledger.lastSampleAt = now
		return
	end

	if ledger.rollRequestUntil > 0 then
		if now > ledger.rollRequestUntil then
			ledger.rollRequestUntil = 0
			ledger.rollRequestedAt = 0
			ledger.rollIntentAt = 0
		elseif humanoid ~= nil
			and root ~= nil
			and humanoid.FloorMaterial ~= Enum.Material.Air
			and player:GetAttribute("HRushStunned") ~= true
			and (ledger.state == "Walk" or ledger.state == "Sprint")
		then
			local role = player:GetAttribute("HRushRole")
			if role == "Runner" or role == "Taya" then
				beginRoll(player, ledger, root, role, now)
			else
				ledger.rollRequestUntil = 0
				ledger.rollRequestedAt = 0
				ledger.rollIntentAt = 0
			end
		end
	end

	if root == nil or root.Anchored then
		ledger.lastPosition = nil
		ledger.lastSampleAt = now
		return
	end
	if now < ledger.hardLandUntil then
		local exTayaMult = if now < ledger.boostUntil and player:GetAttribute("HRushRole") == "Runner"
			then movement.PostTagSpeedBoostMult else 1
		local penaltyLimit = MomentumRules.speed(roleSpeed(player, ledger.state == "Sprint"),
			exTayaMult, movement.HardLandSpeedMult, ledger.momentum)
			* (1 + movement.ServerSpeedTolerancePct)
		local observedSpeed = horizontalSpeed(root)
		if observedSpeed > penaltyLimit then
			recordViolation(player, ledger, "hard_landing_speed", string.format("%.2f > %.2f", observedSpeed, penaltyLimit))
		end
	end
	if ledger.lastPosition == nil then
		ledger.lastPosition = root.Position
		ledger.lastSampleAt = now
		return
	end

	local elapsed = now - ledger.lastSampleAt
	if elapsed < movement.ServerSampleWindow then
		return
	end
	local limit = allowedSpeed(player, ledger, now)
	local speedLimit = limit * (1 + movement.ServerSpeedTolerancePct)
		+ movement.ServerDisplacementSlack / movement.ServerSampleWindow
	local observedSpeed = horizontalSpeed(root)
	if observedSpeed > speedLimit then
		recordViolation(player, ledger, "horizontal_speed", string.format("%.2f > %.2f", observedSpeed, speedLimit))
	end

	local previous = ledger.lastPosition :: Vector3
	local delta = root.Position - previous
	local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
	local distanceLimit = limit * elapsed * (1 + movement.ServerSpeedTolerancePct)
		+ movement.ServerDisplacementSlack
	if horizontalDistance > distanceLimit then
		recordViolation(player, ledger, "horizontal_displacement", string.format("%.2f > %.2f", horizontalDistance, distanceLimit))
	end
	ledger.lastPosition = root.Position
	ledger.lastSampleAt = now
end

local function bindCharacter(player: Player, ledger: Ledger, character: Model)
	finishEquipmentGlide(player, "CharacterRemoving", true)
	resetLedger(player, ledger)
	if character:GetAttribute("MomentumTier") == nil then
		character:SetAttribute("MomentumTier", 0)
	end
	if ledger.diedConnection ~= nil then
		ledger.diedConnection:Disconnect()
		ledger.diedConnection = nil
	end
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", movement.ServerCharacterWaitTimeout)
		if humanoid ~= nil and humanoid:IsA("Humanoid") and player.Character == character then
			ledger.diedConnection = humanoid.Died:Connect(function()
				finishEquipmentGlide(player, "Death", true)
				resetLedger(player, ledger)
			end)
		end
	end)
end

local function attachPlayer(player: Player)
	local now = os.clock()
	local ledger: Ledger = {
		state = "Walk",
		dashUntil = 0,
		dashReadyAt = 0,
		slideUntil = 0,
		slideReadyAt = 0,
		rollUntil = 0,
		rollBaseSpeed = 0,
		rollRequestUntil = 0,
		rollRequestedAt = 0,
		rollIntentAt = 0,
		vaultUntil = 0,
		vaultReadyAt = 0,
		vaultAllowedSpeed = 0,
		recentVelocity = Vector3.zero,
		recentVelocityAt = 0,
		lastAirborneAt = -math.huge,
		airborne = false,
		airStartedAt = 0,
		lastGroundedAt = now,
		lastVerticalVelocity = 0,
		takeoffObserved = false,
		airTimeReported = false,
		airPeakY = 0,
		hardLandUntil = 0,
		boostUntil = 0,
		momentum = 0,
		momentumGainAt = 0,
		momentumSampleAt = now,
		momentumSyncAt = now,
		momentumSeq = 0,
		momentumMoves = {},
		requestWindowStartedAt = now,
		requestCount = 0,
		lastPosition = nil,
		lastSampleAt = now,
		lastRole = tostring(player:GetAttribute("HRushRole") or "Runner"),
		violations = {},
		totalViolations = 0,
		diedConnection = nil,
		connections = {},
	}
	ledgers[player] = ledger
	player:SetAttribute("HRushMovementViolations", 0)
	setState(player, ledger, "Walk")

	table.insert(ledger.connections, player.CharacterAdded:Connect(function(character)
		bindCharacter(player, ledger, character)
	end))
	table.insert(ledger.connections, player.CharacterRemoving:Connect(function()
		finishEquipmentGlide(player, "CharacterRemoving", true)
	end))
	table.insert(ledger.connections, player:GetAttributeChangedSignal("HRushRole"):Connect(function()
		local previousRole = ledger.lastRole
		local nextRole = tostring(player:GetAttribute("HRushRole") or "Runner")
		resetLedger(player, ledger)
		if equipmentGlides[player] ~= nil then
			setState(player, ledger, "Glide")
		end
		if previousRole == "Taya" and nextRole == "Runner" then
			ledger.boostUntil = os.clock() + movement.PostTagSpeedBoostDuration
		end
		ledger.lastRole = nextRole
	end))
	table.insert(ledger.connections, player:GetAttributeChangedSignal("HRushStunned"):Connect(function()
		if player:GetAttribute("HRushStunned") == true then
			finishEquipmentGlide(player, "Cancelled", true)
		end
		resetLedger(player, ledger)
	end))
	table.insert(ledger.connections, player:GetAttributeChangedSignal("HRushInMatch"):Connect(function()
		if not isLiveParticipant(player) then finishEquipmentGlide(player, "RoundEnd", true) end
		resetLedger(player, ledger)
	end))
	table.insert(ledger.connections, player:GetAttributeChangedSignal("HRushState"):Connect(function()
		if not isLiveParticipant(player) then finishEquipmentGlide(player, "RoundEnd", true) end
		resetLedger(player, ledger)
	end))

	if player.Character ~= nil then
		bindCharacter(player, ledger, player.Character :: Model)
	end
end

local function detachPlayer(player: Player)
	finishEquipmentGlide(player, "CharacterRemoving", true)
	local ledger = ledgers[player]
	if ledger == nil then
		return
	end
	if ledger.diedConnection ~= nil then
		ledger.diedConnection:Disconnect()
	end
	for _, connection in ledger.connections do
		connection:Disconnect()
	end
	ledgers[player] = nil
end

local function validateConfig()
	assert(movement.ServerSpeedTolerancePct >= 0, "Movement server tolerance must be non-negative")
	assert(movement.ServerSampleWindow > 0, "Movement sample window must be positive")
	assert(movement.ServerRequestWindow > 0 and movement.ServerRequestRate > 0, "Movement request limit must be positive")
	assert(movement.ServerLogViolationThreshold >= 1, "Movement log threshold must be at least one")
	assert(movement.SlideEndMult <= movement.SlideStartMult, "Slide end speed must not exceed its start speed")
	assert(movement.RollWindow > 0, "Roll input window must be positive")
	assert(movement.RollDuration > 0, "Roll duration must be positive")
	assert(momentum.Cap > 0 and momentum.GlobalSpeedCeiling > 0, "Momentum cap and speed ceiling must be positive")
	assert(momentum.SyncInterval > 0 and momentum.DecayGrace >= 0, "Momentum timing is invalid")
	assert(momentum.ZeroSyncInterval > 0, "Momentum zero sync must be positive")
	assert(momentum.PerfectRollWindow > 0 and momentum.PerfectRollWindow <= movement.RollWindow, "Perfect roll window is invalid")
	assert(momentum.SlideMinSpeedPct > 0 and momentum.SlideMinSpeedPct <= 1, "Slide minimum speed must be a percentage")
	assert(movement.VaultMinH > 0 and movement.VaultMaxH >= movement.VaultMinH, "Vault relative height range is invalid")
	assert(movement.VaultMaxAboveGround >= movement.VaultMaxH, "Vault absolute cap must cover the relative range")
	assert(movement.VaultMinDrop > 0, "Vault landing drop must be positive")
	assert(movement.VaultMinSpeedPct > 0 and movement.VaultMinSpeedPct <= 1, "Vault minimum speed must be a percentage")
	assert(movement.VaultSpeedVariantPct >= movement.VaultMinSpeedPct and movement.VaultSpeedVariantPct <= 1, "Vault variant speed is invalid")
	assert(movement.VaultSpeedKeepPct > 0 and movement.VaultSpeedKeepPct <= 1, "Vault retained speed must be a percentage")
	assert(movement.VaultDuration > 0 and movement.VaultCooldown > 0, "Vault timing is invalid")
	assert(movement.VaultKneeHeight < movement.VaultWaistHeight and movement.VaultWaistHeight < movement.VaultChestHeight, "Vault body probes are invalid")
	assert(movement.VaultSpeedMaxDepth > 0 and movement.VaultMaxDepth >= movement.VaultSpeedMaxDepth, "Vault depth range is invalid")
	assert(movement.VaultGeometryTolerance >= 0, "Vault geometry tolerance must be non-negative")
	assert(movement.VaultLandingNormalMin >= 0 and movement.VaultLandingNormalMin <= 1, "Vault landing normal is invalid")
	assert(movement.VaultProbeDistance > 0 and movement.VaultProbeDistance <= movement.VaultMaxTravelDistance, "Vault probe distance is invalid")
	assert(movement.HardLandHeight > 0 and movement.HardLandPenaltyTime > 0, "Hard landing threshold and timing must be positive")
	assert(movement.HardLandSpeedMult > 0 and movement.HardLandSpeedMult <= 1, "Hard landing speed must be a percentage")
	assert(movement.FallGravityMult >= 1, "Fall gravity multiplier must include normal gravity")
	assert(movement.TerminalFallSpeed > movement.JumpPower, "Terminal fall speed must exceed jump power")
	assert(movement.AirControlPct >= 0 and movement.AirControlPct <= 1, "Air control must be a percentage")
	assert(movement.AirSpeedCapMult >= 1, "Air speed cap multiplier must be at least one")
	assert(movement.CoyoteTime > 0 and movement.JumpBufferTime > 0, "Jump grace windows must be positive")
	assert(movement.ServerTakeoffObservationTime >= movement.CoyoteTime + movement.ServerSampleWindow, "Takeoff observation window is too short")
	assert(movement.ServerMaxAirTime > 0, "Server air-time limit must be positive")
	assert(movement.ServerCorrectionEnabled == false, "Movement authority must remain observation-only")
end

function MovementAuthority.start()
	if started then
		return
	end
	started = true

	local configModule = ReplicatedStorage:WaitForChild("Config", 10)
	assert(configModule ~= nil and configModule:IsA("ModuleScript"), "Config ModuleScript missing")
	local config = require(configModule)
	movement = config.Movement
	momentum = config.Momentum
	validateConfig()

	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	assert(remotes ~= nil and remotes:IsA("Folder"), "Remotes folder missing")
	local requestMovementState = remotes:WaitForChild("RequestMovementState", 10)
	local requestDash = remotes:WaitForChild("RequestDash", 10)
	local dashVfxRemote = remotes:WaitForChild("DashVFXEvent", 10)
	local momentumRemote = remotes:WaitForChild("MomentumUpdate", 10)
	local glideSteerRemote = remotes:FindFirstChild("EquipmentGlideSteer")
	if glideSteerRemote == nil then
		glideSteerRemote = Instance.new("RemoteEvent")
		glideSteerRemote.Name = "EquipmentGlideSteer"
		glideSteerRemote.Parent = remotes
	end
	assert(glideSteerRemote:IsA("RemoteEvent"), "EquipmentGlideSteer must be a RemoteEvent")
	assert(requestMovementState ~= nil and requestMovementState:IsA("RemoteEvent"), "RequestMovementState missing")
	assert(requestDash ~= nil and requestDash:IsA("RemoteEvent"), "RequestDash missing")
	assert(dashVfxRemote ~= nil and dashVfxRemote:IsA("UnreliableRemoteEvent"), "DashVFXEvent missing")
	assert(momentumRemote ~= nil and momentumRemote:IsA("RemoteEvent"), "MomentumUpdate missing")
	momentumUpdate = momentumRemote :: RemoteEvent
	dashVfxEvent = dashVfxRemote :: UnreliableRemoteEvent

	requestMovementState.OnServerEvent:Connect(handleMovementState)
	requestDash.OnServerEvent:Connect(handleDash)
	local steerRemote = glideSteerRemote :: RemoteEvent
	steerRemote.OnServerEvent:Connect(steerEquipmentGlide)
	Players.PlayerAdded:Connect(attachPlayer)
	Players.PlayerRemoving:Connect(detachPlayer)
	ReplicatedStorage:GetAttributeChangedSignal("HRushRoundState"):Connect(function()
		for player, ledger in ledgers do
			if ReplicatedStorage:GetAttribute("HRushRoundState") ~= "MS_04" then
				finishEquipmentGlide(player, "RoundEnd", true)
			end
			resetLedger(player, ledger)
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()
		for player, ledger in ledgers do
			stepEquipmentGlide(player, now, dt)
			observePlayer(player, ledger, now)
		end
	end)

	for _, player in Players:GetPlayers() do
		attachPlayer(player)
	end
end

return MovementAuthority
