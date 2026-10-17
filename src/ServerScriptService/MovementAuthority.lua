--!strict
-- ServerScriptService/MovementAuthority.lua
-- Owner: Project Owner
-- Responsibility: server movement request validation, state ledger, and passive observation.
-- Task/spec: approved Pounce / Tag integration and Taya sprint revision, 2026-10-16.
-- Task/spec: movement upgrade Part 2 landing and Vault validation, approved 2026-10-16.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

type Ledger = {
	state: string,
	dashUntil: number,
	dashReadyAt: number,
	slideUntil: number,
	slideReadyAt: number,
	rollUntil: number,
	rollAllowedSpeed: number,
	rollRequestUntil: number,
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

local MovementAuthority = {}

local started = false
local movement: any = nil
local pounce: any = nil
local ledgers: { [Player]: Ledger } = {}

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
	ledger.rollAllowedSpeed = 0
	ledger.rollRequestUntil = 0
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
	if player:GetAttribute("HRushPouncing") == true then
		return pounce.ForwardSpeed
	end
	if ledger.state == "Dash" and now < ledger.dashUntil then
		return movement.DashDistance * movement.SpeedScale / movement.DashDuration
	end
	if ledger.state == "Roll" and now < ledger.rollUntil then
		return ledger.rollAllowedSpeed
	end
	if ledger.state == "Vault" and now < ledger.vaultUntil then
		return ledger.vaultAllowedSpeed
	end

	local speed: number
	if ledger.state == "Slide" and now < ledger.slideUntil then
		speed = roleSpeed(player, player:GetAttribute("HRushRole") ~= "Taya") * movement.SlideSpeedMult
	else
		speed = roleSpeed(player, ledger.state == "Sprint")
	end
	if now < ledger.boostUntil and player:GetAttribute("HRushRole") == "Runner" then
		speed *= movement.PostTagSpeedBoostMult
	end
	if now < ledger.hardLandUntil then
		speed *= movement.HardLandSpeedMult
	end
	return speed
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
	local bonus = movement.RunnerSprintSpeed * movement.SpeedScale * movement.RollSpeedBonus
	ledger.rollRequestUntil = 0
	ledger.hardLandUntil = 0
	player:SetAttribute("HRushServerHardLandUntil", 0)
	ledger.rollAllowedSpeed = math.max(walkSpeed, carriedSpeed) + bonus
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
	if action ~= "Sprint" and action ~= "Slide" and action ~= "Roll" and action ~= "Vault" then
		recordViolation(player, ledger, "request_action", action)
		return
	end

	if not active then
		if action == "Roll" then
			ledger.rollRequestUntil = 0
		end
		if ledger.state == action then
			if action == "Roll" then
				ledger.rollUntil = 0
				ledger.rollAllowedSpeed = 0
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
		if humanoid.FloorMaterial == Enum.Material.Air then
			-- Character ownership can make the client's confirmed landing arrive
			-- before FloorMaterial replicates to the server. Hold the request, then
			-- let the server's own observer accept only a prompt landing.
			ledger.rollRequestUntil = now + movement.RollWindow + movement.ServerSampleWindow
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
	if role == "Runner" and ledger.state ~= "Sprint" then
		recordViolation(player, ledger, "slide_state", ledger.state)
		return
	end
	if ledger.state == "Roll" or ledger.state == "Dash" or ledger.state == "Vault" then
		recordViolation(player, ledger, "slide_state", ledger.state)
		return
	end
	local minimumSpeed = roleSpeed(player, role == "Runner") * movement.SlideMinSpeedPct
	local observedSpeed = horizontalSpeed(root)
	if observedSpeed < minimumSpeed * (1 - movement.ServerSpeedTolerancePct) then
		recordViolation(player, ledger, "slide_speed", string.format("%.2f < %.2f", observedSpeed, minimumSpeed))
		return
	end

	ledger.slideReadyAt = now + movement.SlideCooldown
	ledger.slideUntil = now + movement.SlideDuration
	ledger.hardLandUntil = 0
	player:SetAttribute("HRushServerHardLandUntil", 0)
	setState(player, ledger, "Slide")
end

local function handleDash(player: Player, direction: unknown)
	if player:GetAttribute("HRushPouncing") == true then return end
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

	ledger.dashReadyAt = now + movement.DashCooldown
	ledger.dashUntil = now + movement.DashDuration
	player:SetAttribute("HRushPounceImmuneUntil", now + movement.DashPounceInvulnTime)
	setState(player, ledger, "Dash")
end

local function observePlayer(player: Player, ledger: Ledger, now: number)
	if ledger.state == "Dash" and now >= ledger.dashUntil then
		setState(player, ledger, "Walk")
	elseif ledger.state == "Slide" and now >= ledger.slideUntil then
		setState(player, ledger, "Walk")
	elseif ledger.state == "Roll" and now >= ledger.rollUntil then
		ledger.rollAllowedSpeed = 0
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
		local scriptedAir = player:GetAttribute("IsAirborne") == true or ledger.state == "Vault"
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
	then
		ledger.lastPosition = nil
		ledger.lastSampleAt = now
		return
	end

	if ledger.rollRequestUntil > 0 then
		if now > ledger.rollRequestUntil then
			ledger.rollRequestUntil = 0
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
			end
		end
	end

	if root == nil or root.Anchored then
		ledger.lastPosition = nil
		ledger.lastSampleAt = now
		return
	end
	if now < ledger.hardLandUntil then
		local penaltyLimit = roleSpeed(player, ledger.state == "Sprint")
			* movement.HardLandSpeedMult
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
	resetLedger(player, ledger)
	if ledger.diedConnection ~= nil then
		ledger.diedConnection:Disconnect()
		ledger.diedConnection = nil
	end
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", movement.ServerCharacterWaitTimeout)
		if humanoid ~= nil and humanoid:IsA("Humanoid") and player.Character == character then
			ledger.diedConnection = humanoid.Died:Connect(function()
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
		rollAllowedSpeed = 0,
		rollRequestUntil = 0,
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
	table.insert(ledger.connections, player:GetAttributeChangedSignal("HRushRole"):Connect(function()
		local previousRole = ledger.lastRole
		local nextRole = tostring(player:GetAttribute("HRushRole") or "Runner")
		resetLedger(player, ledger)
		if previousRole == "Taya" and nextRole == "Runner" then
			ledger.boostUntil = os.clock() + movement.PostTagSpeedBoostDuration
		end
		ledger.lastRole = nextRole
	end))
	table.insert(ledger.connections, player:GetAttributeChangedSignal("HRushStunned"):Connect(function()
		resetLedger(player, ledger)
	end))
	table.insert(ledger.connections, player:GetAttributeChangedSignal("HRushInMatch"):Connect(function()
		resetLedger(player, ledger)
	end))
	table.insert(ledger.connections, player:GetAttributeChangedSignal("HRushState"):Connect(function()
		resetLedger(player, ledger)
	end))

	if player.Character ~= nil then
		bindCharacter(player, ledger, player.Character :: Model)
	end
end

local function detachPlayer(player: Player)
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
	assert(movement.RollSpeedBonus >= 0 and movement.RollSpeedBonus <= 1, "Roll speed bonus must be between 0 and 1")
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
	pounce = config.Pounce
	validateConfig()

	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	assert(remotes ~= nil and remotes:IsA("Folder"), "Remotes folder missing")
	local requestMovementState = remotes:WaitForChild("RequestMovementState", 10)
	local requestDash = remotes:WaitForChild("RequestDash", 10)
	assert(requestMovementState ~= nil and requestMovementState:IsA("RemoteEvent"), "RequestMovementState missing")
	assert(requestDash ~= nil and requestDash:IsA("RemoteEvent"), "RequestDash missing")

	requestMovementState.OnServerEvent:Connect(handleMovementState)
	requestDash.OnServerEvent:Connect(handleDash)
	Players.PlayerAdded:Connect(attachPlayer)
	Players.PlayerRemoving:Connect(detachPlayer)
	ReplicatedStorage:GetAttributeChangedSignal("HRushRoundState"):Connect(function()
		for player, ledger in ledgers do
			resetLedger(player, ledger)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, ledger in ledgers do
			observePlayer(player, ledger, now)
		end
	end)

	for _, player in Players:GetPlayers() do
		attachPlayer(player)
	end
end

return MovementAuthority
