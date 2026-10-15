--!strict
-- ServerScriptService/MovementAuthority.lua
-- Owner: Project Owner
-- Responsibility: server movement request validation, state ledger, and passive observation.
-- Task/spec: T09 movement upgrade Step 1, approved 2026-10-15.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

type Ledger = {
	state: string,
	dashUntil: number,
	dashReadyAt: number,
	slideUntil: number,
	slideReadyAt: number,
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
end

local function resetLedger(player: Player, ledger: Ledger)
	ledger.dashUntil = 0
	ledger.dashReadyAt = 0
	ledger.slideUntil = 0
	ledger.slideReadyAt = 0
	ledger.boostUntil = 0
	ledger.lastPosition = nil
	ledger.lastSampleAt = os.clock()
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
		return movement.TayaSpeed * movement.SpeedScale
	end
	local base = if sprinting then movement.RunnerSprintSpeed else movement.RunnerWalkSpeed
	return base * movement.SpeedScale
end

local function allowedSpeed(player: Player, ledger: Ledger, now: number): number
	if ledger.state == "Dash" and now < ledger.dashUntil then
		return movement.DashDistance * movement.SpeedScale / movement.DashDuration
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

local function handleMovementState(player: Player, action: unknown, active: unknown)
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
	if action ~= "Sprint" and action ~= "Slide" then
		recordViolation(player, ledger, "request_action", action)
		return
	end

	if not active then
		if ledger.state == action then
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
		if role ~= "Runner" then
			recordViolation(player, ledger, "sprint_role", tostring(role))
			return
		end
		setState(player, ledger, "Sprint")
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
	local minimumSpeed = roleSpeed(player, role == "Runner") * movement.SlideMinSpeedPct
	local observedSpeed = horizontalSpeed(root)
	if observedSpeed < minimumSpeed * (1 - movement.ServerSpeedTolerancePct) then
		recordViolation(player, ledger, "slide_speed", string.format("%.2f < %.2f", observedSpeed, minimumSpeed))
		return
	end

	ledger.slideReadyAt = now + movement.SlideCooldown
	ledger.slideUntil = now + movement.SlideDuration
	setState(player, ledger, "Slide")
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

	ledger.dashReadyAt = now + movement.DashCooldown
	ledger.dashUntil = now + movement.DashDuration
	setState(player, ledger, "Dash")
end

local function observePlayer(player: Player, ledger: Ledger, now: number)
	if ledger.state == "Dash" and now >= ledger.dashUntil then
		setState(player, ledger, "Walk")
	elseif ledger.state == "Slide" and now >= ledger.slideUntil then
		setState(player, ledger, "Walk")
	end

	if not isLiveParticipant(player)
		or player:GetAttribute("HRushStunned") == true
		or player:GetAttribute("IsAirborne") == true
	then
		ledger.lastPosition = nil
		ledger.lastSampleAt = now
		return
	end

	local _, root = liveCharacter(player)
	if root == nil or root.Anchored then
		ledger.lastPosition = nil
		ledger.lastSampleAt = now
		return
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
	assert(movement.ServerCorrectionEnabled == false, "Step 1 must remain observation-only")
end

function MovementAuthority.start()
	if started then
		return
	end
	started = true

	local configModule = ReplicatedStorage:WaitForChild("Config", 10)
	assert(configModule ~= nil and configModule:IsA("ModuleScript"), "Config ModuleScript missing")
	movement = require(configModule).Movement
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
