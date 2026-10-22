--!strict
-- StarterPlayerScripts/AirMovement.lua
-- Owner: Project Owner
-- Responsibility: normal jump grace windows, falling physics, and horizontal air limits.
-- Task/spec: simple click-to-tag integration, approved 2026-10-18.
-- Task/spec: movement upgrade Parts 1 and 2 jump priority and committed air direction, approved 2026-10-16.
-- Task/spec: yield air physics and send steer intent during server equipment glide, 2026-10-22.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Movement = Config.Movement
local LocalPlayer = Players.LocalPlayer

type Options = {
	onSlideJump: (() -> Vector3?)?,
	tryVault: (() -> boolean)?,
}

local AirMovement = {}
local started = false
local options: Options = {}
local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local fallForce: VectorForce? = nil
local stateConnection: RBXScriptConnection? = nil
local diedConnection: RBXScriptConnection? = nil
local simulationConnection: RBXScriptConnection? = nil
local glideSteerRemote: RemoteEvent? = nil
local lastGlideSteerAt = 0.0

local wasGrounded = false
local lastGroundedAt = 0.0
local lastJumpRequestAt = -math.huge
local bufferExpiresAt = 0.0
local jumpedSinceGround = false
local groundJumpPending = false
local bufferedThisAir = false
local takeoffSpeed = 0.0
local takeoffHorizontal = Vector3.zero
local requestedAirDirection = Vector3.zero
local wasScripted = false
local pendingTakeoffVelocity: Vector3? = nil

local AIR_CONTROL_BIND = "HRUSH_AirControl"
local FALL_FORCE_ATTACHMENT = "HRUSH_FallForceAttachment"
local FALL_FORCE_NAME = "HRUSH_FallGravity"
local DEBUG_FALL_ATTRIBUTE = "HRushDebugFallGravityMult"
local DEBUG_AIR_ATTRIBUTE = "HRushDebugAirControlPct"

local function finiteNumber(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

local function studioOverride(name: string, minimum: number, maximum: number, fallback: number): number
	if not RunService:IsStudio() then
		return fallback
	end
	local value = LocalPlayer:GetAttribute(name)
	if typeof(value) ~= "number" or not finiteNumber(value) then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
end

local function fallGravityMultiplier(): number
	return studioOverride(
		DEBUG_FALL_ATTRIBUTE,
		Movement.FallGravityDebugMin,
		Movement.FallGravityDebugMax,
		Movement.FallGravityMult
	)
end

local function airControlPercent(): number
	return studioOverride(
		DEBUG_AIR_ATTRIBUTE,
		Movement.AirControlDebugMin,
		Movement.AirControlDebugMax,
		Movement.AirControlPct
	)
end

local function flatVelocity(part: BasePart): Vector3
	local velocity = part.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z)
end

local function movementAllowed(): boolean
	local state = LocalPlayer:GetAttribute("HRushState")
	return LocalPlayer:GetAttribute("HRushStunned") ~= true
		and LocalPlayer:GetAttribute("HRushMovementState") ~= "Glide"
		and LocalPlayer:GetAttribute("HRushVaulting") ~= true
		and LocalPlayer:GetAttribute("HRushRolling") ~= true
		and LocalPlayer:GetAttribute("IsAirborne") ~= true
		and (state == nil or state == "MS_01" or state == "MS_04")
end

local function scriptedMovementActive(): boolean
	return LocalPlayer:GetAttribute("HRushVaulting") == true
		or LocalPlayer:GetAttribute("HRushDashing") == true
		or LocalPlayer:GetAttribute("IsAirborne") == true
		or LocalPlayer:GetAttribute("HRushMovementState") == "Glide"
end

local function applyHorizontalVelocity(part: BasePart, horizontal: Vector3)
	local velocity = part.AssemblyLinearVelocity
	part.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
end

local function requestTakeoff(horizontal: Vector3)
	local activeHumanoid = humanoid
	if activeHumanoid == nil or not activeHumanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping) then
		return
	end
	pendingTakeoffVelocity = horizontal
	takeoffSpeed = horizontal.Magnitude
	takeoffHorizontal = horizontal
	bufferExpiresAt = 0
	jumpedSinceGround = true
	groundJumpPending = true
	activeHumanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

local function onJumpRequest()
	local activeHumanoid = humanoid
	local activeRoot = root
	if activeHumanoid == nil or activeRoot == nil or activeHumanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - lastJumpRequestAt < Movement.JumpBufferTime then
		return
	end
	lastJumpRequestAt = now
	if LocalPlayer:GetAttribute("HRushVaulting") == true then
		bufferExpiresAt = now + Movement.JumpBufferTime
		return
	end
	if not movementAllowed() then
		return
	end

	local grounded = activeHumanoid.FloorMaterial ~= Enum.Material.Air
	local horizontal = flatVelocity(activeRoot)
	if grounded then
		if LocalPlayer:GetAttribute("HRushSliding") == true and options.onSlideJump ~= nil then
			local retained = options.onSlideJump()
			if retained ~= nil then
				horizontal = retained
				applyHorizontalVelocity(activeRoot, retained)
			end
		end
		pendingTakeoffVelocity = horizontal
		takeoffSpeed = horizontal.Magnitude
		takeoffHorizontal = horizontal
		bufferExpiresAt = 0
		jumpedSinceGround = true
		groundJumpPending = true
		return
	end

	if not jumpedSinceGround and now - lastGroundedAt <= Movement.CoyoteTime then
		requestTakeoff(horizontal)
		return
	end
	if not bufferedThisAir then
		bufferExpiresAt = now + Movement.JumpBufferTime
	end
end

local function onStateChanged(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
	local activeRoot = root
	if new == Enum.HumanoidStateType.Jumping and activeRoot ~= nil then
		local horizontal = pendingTakeoffVelocity or flatVelocity(activeRoot)
		pendingTakeoffVelocity = nil
		takeoffSpeed = horizontal.Magnitude
		takeoffHorizontal = horizontal
		jumpedSinceGround = true
		groundJumpPending = false
		local current = flatVelocity(activeRoot)
		if current.Magnitude + Movement.ServerDirectionMinMagnitude < horizontal.Magnitude then
			applyHorizontalVelocity(activeRoot, horizontal)
		end
	end
end

local function updateAirControl()
	local activeHumanoid = humanoid
	if activeHumanoid == nil or activeHumanoid.FloorMaterial ~= Enum.Material.Air or scriptedMovementActive() then
		return
	end
	local percent = airControlPercent()
	if percent < Movement.AirControlDebugMax then
		requestedAirDirection = Vector3.new(activeHumanoid.MoveDirection.X, 0, activeHumanoid.MoveDirection.Z)
		activeHumanoid:Move(Vector3.zero, false)
	end
end

local function clearCharacter()
	if stateConnection ~= nil then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	if diedConnection ~= nil then
		diedConnection:Disconnect()
		diedConnection = nil
	end
	if simulationConnection ~= nil then
		simulationConnection:Disconnect()
		simulationConnection = nil
	end
	if fallForce ~= nil then
		fallForce:Destroy()
		fallForce = nil
	end
	character = nil
	humanoid = nil
	root = nil
end

local function bindCharacter(newCharacter: Model)
	clearCharacter()
	character = newCharacter
	local newHumanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	local newRoot = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	humanoid = newHumanoid
	root = newRoot
	wasGrounded = newHumanoid.FloorMaterial ~= Enum.Material.Air
	lastGroundedAt = os.clock()
	lastJumpRequestAt = -math.huge
	bufferExpiresAt = 0
	jumpedSinceGround = false
	groundJumpPending = false
	bufferedThisAir = false
	takeoffSpeed = flatVelocity(newRoot).Magnitude
	takeoffHorizontal = flatVelocity(newRoot)
	requestedAirDirection = Vector3.zero
	wasScripted = false
	pendingTakeoffVelocity = nil

	local oldAttachment = newRoot:FindFirstChild(FALL_FORCE_ATTACHMENT)
	if oldAttachment ~= nil then
		oldAttachment:Destroy()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = FALL_FORCE_ATTACHMENT
	attachment.Parent = newRoot
	local force = Instance.new("VectorForce")
	force.Name = FALL_FORCE_NAME
	force.Attachment0 = attachment
	force.ApplyAtCenterOfMass = true
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.Force = Vector3.zero
	force.Enabled = false
	force.Parent = newRoot
	fallForce = force

	stateConnection = newHumanoid.StateChanged:Connect(onStateChanged)
	diedConnection = newHumanoid.Died:Connect(clearCharacter)
	simulationConnection = RunService.PostSimulation:Connect(function(_deltaTime: number)
		if humanoid ~= newHumanoid or root ~= newRoot or fallForce ~= force then
			return
		end
		local now = os.clock()
		if LocalPlayer:GetAttribute("HRushMovementState") == "Glide"
			and glideSteerRemote ~= nil
			and now - lastGlideSteerAt >= Movement.EquipmentGlideSteerSendInterval
		then
			lastGlideSteerAt = now
			local move = newHumanoid.MoveDirection
			glideSteerRemote:FireServer(Vector3.new(move.X, 0, move.Z))
		end
		local grounded = newHumanoid.FloorMaterial ~= Enum.Material.Air
		if grounded then
			lastGroundedAt = now
			if not wasGrounded then
				jumpedSinceGround = false
				groundJumpPending = false
				bufferedThisAir = false
				takeoffHorizontal = flatVelocity(newRoot)
				takeoffSpeed = takeoffHorizontal.Magnitude
			end
			if bufferExpiresAt >= now and movementAllowed() then
				local horizontal = flatVelocity(newRoot)
				bufferExpiresAt = 0
				bufferedThisAir = true
				local vaultStarted = options.tryVault ~= nil and options.tryVault()
				if not vaultStarted then
					requestTakeoff(horizontal)
				end
			elseif bufferExpiresAt > 0 and bufferExpiresAt < now then
				bufferExpiresAt = 0
			end
		elseif wasGrounded and not groundJumpPending and newHumanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
			jumpedSinceGround = false
			bufferedThisAir = false
			takeoffHorizontal = flatVelocity(newRoot)
			takeoffSpeed = takeoffHorizontal.Magnitude
		end
		wasGrounded = grounded

		local velocity = newRoot.AssemblyLinearVelocity
		local scripted = scriptedMovementActive()
		if scripted then
			wasScripted = true
		elseif not grounded and wasScripted then
			takeoffHorizontal = flatVelocity(newRoot)
			takeoffSpeed = takeoffHorizontal.Magnitude
			wasScripted = false
		elseif grounded then
			wasScripted = false
		end
		if not grounded and not scripted and velocity.Y < 0 then
			local gravityMultiplier = fallGravityMultiplier()
			local extraGravity = (gravityMultiplier - 1) * Workspace.Gravity
			if velocity.Y < -Movement.TerminalFallSpeed then
				newRoot.AssemblyLinearVelocity = Vector3.new(velocity.X, -Movement.TerminalFallSpeed, velocity.Z)
			end
			force.Force = Vector3.new(0, -extraGravity * newRoot.AssemblyMass, 0)
			force.Enabled = extraGravity > 0
		else
			force.Enabled = false
			force.Force = Vector3.zero
		end

		if not grounded and not scripted then
			local horizontal = flatVelocity(newRoot)
			local control = airControlPercent()
			if control < Movement.AirControlDebugMax and takeoffSpeed > Movement.ServerDirectionMinMagnitude then
				local steeringTarget = takeoffHorizontal
				if requestedAirDirection.Magnitude >= Movement.ServerDirectionMinMagnitude then
					steeringTarget = requestedAirDirection.Unit * takeoffSpeed
				end
				horizontal = takeoffHorizontal:Lerp(steeringTarget, control)
				applyHorizontalVelocity(newRoot, horizontal)
			end
			local cap = math.max(
				takeoffSpeed,
				Movement.RunnerSprintSpeed * Movement.SpeedScale * Movement.AirSpeedCapMult
			)
			if horizontal.Magnitude > cap then
				applyHorizontalVelocity(newRoot, horizontal.Unit * cap)
			end
			if RunService:IsStudio() then
				LocalPlayer:SetAttribute("HRushAirSpeedCap", cap)
			end
		end
		if RunService:IsStudio() then
			LocalPlayer:SetAttribute("HRushAirborne", not grounded)
			LocalPlayer:SetAttribute("HRushEffectiveFallGravityMult", fallGravityMultiplier())
			LocalPlayer:SetAttribute("HRushEffectiveAirControlPct", airControlPercent())
		end
	end)
end

function AirMovement.start(startOptions: Options?)
	if started then
		return
	end
	started = true
	options = startOptions or {}
	task.spawn(function()
		local remotes = ReplicatedStorage:WaitForChild("Remotes")
		local remote = remotes:WaitForChild("EquipmentGlideSteer")
		if remote:IsA("RemoteEvent") then glideSteerRemote = remote end
	end)
	UserInputService.JumpRequest:Connect(onJumpRequest)
	RunService:BindToRenderStep(AIR_CONTROL_BIND, Enum.RenderPriority.Character.Value + 1, updateAirControl)
	LocalPlayer.CharacterAdded:Connect(bindCharacter)
	if LocalPlayer.Character ~= nil then
		task.spawn(bindCharacter, LocalPlayer.Character)
	end
end

return AirMovement
