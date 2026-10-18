--!strict
-- StarterPlayerScripts/PounceController.lua
-- Owner: Project Owner
-- Responsibility: predicted pounce input, flight, R15 playback, feedback, and cooldown UI.
-- Task/spec: airborne momentum activation fix and reduced cooldowns, requested 2026-10-17.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Pounce = Config.Pounce
local TagRules = require(ReplicatedStorage:WaitForChild("TagRules"))
local Effects = require(script.Parent:WaitForChild("PounceEffects"))
local PounceCamera = require(script.Parent:WaitForChild("PounceCamera"))
local RequestPounce = ReplicatedStorage.Remotes:WaitForChild("RequestPounce") :: RemoteEvent
local PounceEvent = ReplicatedStorage.Remotes:WaitForChild("PounceEvent") :: RemoteEvent
local localPlayer = Players.LocalPlayer

local PounceController = {}
local allowed: { [string]: { [string]: boolean } } = {
	Ready = { Windup = true }, Windup = { Launching = true, Cooldown = true },
	Launching = { Airborne = true, Cooldown = true },
	Airborne = { Contact = true, Landing = true, Cooldown = true },
	Contact = { Landing = true, Cooldown = true },
	Landing = { Recovery = true, Contact = true, Cooldown = true },
	Recovery = { Cooldown = true, Contact = true }, Cooldown = { Ready = true, Contact = true },
}
local state = "Ready"
local pounceId = 0
local startedAt = 0.0
local launchedAt = 0.0
local contactAt = 0.0
local recoveryEndsAt = 0.0
local hitConfirmed = false
local landingShown = false
local awaitingLanding = false
local acceptResult = false
local running = false
local attachGeneration = 0
local selectedTarget: BasePart? = nil
local readyAt = 0.0
local serverAnswered = false
local seenAir = false
local initialDirection = Vector3.new(0, 0, -1)
local direction = initialDirection
local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local tracks: { [string]: AnimationTrack } = {}
local diedConnection: RBXScriptConnection? = nil
local savedAutoRotate = true
local savedJumpEnabled = true
local capturedMovement = false
local uiAt = 0.0
local serverResult = ""

local function log(message: string)
	if Pounce.Debug and RunService:IsStudio() then print("[PounceClient] " .. message) end
end

local function transition(nextState: string): boolean
	if not (allowed[state] and allowed[state][nextState]) then
		log("invalid transition " .. state .. " -> " .. nextState)
		return false
	end
	state = nextState
	localPlayer:SetAttribute("HRushLocalPounceState", state)
	return true
end

local function play(name: string)
	for key, track in tracks do
		if key ~= name and track.IsPlaying then track:Stop(Pounce.AnimationFade) end
	end
	local track = tracks[name]
	if track then track:Play(Pounce.AnimationFade, 1, 1) end
end

local function stopTracks()
	for _, track in tracks do
		track:Stop(Pounce.AnimationFade)
	end
end

local function restoreMovement()
	local activeHumanoid = humanoid
	if activeHumanoid and capturedMovement then
		activeHumanoid.AutoRotate = savedAutoRotate
		activeHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, savedJumpEnabled)
	end
	capturedMovement = false
	localPlayer:SetAttribute("HRushLocalPouncing", false)
end

local function cancel(reason: string)
	acceptResult = false
	awaitingLanding = false
	Effects.cancel(localPlayer)
	PounceCamera:Cancel()
	if state == "Ready" or state == "Cooldown" then return end
	log("cancel " .. reason)
	local activeRoot = root
	if activeRoot and (state == "Launching" or state == "Airborne") then
		local velocity = activeRoot.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local limit = Config.Movement.TayaSprintSpeed * Config.Movement.SpeedScale
		if flat.Magnitude > limit then
			activeRoot.AssemblyLinearVelocity = flat.Unit * limit + Vector3.new(0, velocity.Y, 0)
		end
	end
	stopTracks()
	restoreMovement()
	if transition("Cooldown") and os.clock() >= readyAt then transition("Ready") end
end

local function movementDirection(activeHumanoid: Humanoid, activeRoot: BasePart): Vector3
	if activeHumanoid.FloorMaterial == Enum.Material.Air then
		-- AirMovement clears MoveDirection to preserve the committed jump trajectory.
		local velocity = activeRoot.AssemblyLinearVelocity
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
		return if horizontal.Magnitude >= Pounce.MinMoveSpeed then horizontal.Unit else Vector3.zero
	end
	local move = activeHumanoid.MoveDirection
	return Vector3.new(move.X, 0, move.Z)
end

local function canPounce(): boolean
	local activeHumanoid, activeRoot = humanoid, root
	if not Pounce.Enabled or state ~= "Ready" or os.clock() < readyAt then return false end
	if localPlayer:GetAttribute("HRushState") ~= "MS_04" or localPlayer:GetAttribute("HRushRole") ~= "Taya" then return false end
	if localPlayer:GetAttribute("HRushInMatch") ~= true
		or localPlayer:GetAttribute("HRushStunned") == true or localPlayer:GetAttribute("HRushAbilityBusy") == true then return false end
	for _, attribute in { "HRushSliding", "HRushDashing", "HRushRolling", "HRushVaulting", "HRushLocalPouncing", "IsAirborne" } do
		if localPlayer:GetAttribute(attribute) == true then return false end
	end
	if localPlayer:GetAttribute("HRushAiming") == "RS_03" then return false end
	if not character or not activeHumanoid or not activeRoot or activeHumanoid.Health <= 0 or activeRoot.Anchored then return false end
	if activeHumanoid.RigType ~= Enum.HumanoidRigType.R15 then return false end
	local move = movementDirection(activeHumanoid, activeRoot)
	local facing = Vector3.new(activeRoot.CFrame.LookVector.X, 0, activeRoot.CFrame.LookVector.Z)
	return move.Magnitude > 0.2 and facing.Magnitude > 0.5 and move.Unit:Dot(facing.Unit) > Pounce.MinForwardDot
end

local function assistedDirection(base: Vector3, origin: Vector3): Vector3
	local best: Vector3? = nil
	selectedTarget = nil
	local bestDistance = Pounce.AimAssistDistance
	local threshold = math.cos(math.rad(Pounce.AimAssistAngle))
	local candidates: { Instance } = Players:GetPlayers() :: { Instance }
	for _, player in candidates do
		if player ~= localPlayer and player:GetAttribute("HRushRole") == "Runner" and player:GetAttribute("HRushInMatch") == true then
			local targetCharacter = player.Character
			local targetRoot = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")
			local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
			local safeUntil = player:GetAttribute("HRushTagSafeUntil")
			if targetRoot and targetRoot:IsA("BasePart") and targetHumanoid and targetHumanoid.Health > 0
				and (typeof(safeUntil) ~= "number" or safeUntil <= Workspace:GetServerTimeNow())
				and not TagRules.isUntouchable(targetCharacter :: Model) then
				local delta = targetRoot.Position - origin
				local flat = Vector3.new(delta.X, 0, delta.Z)
				local rayParams = RaycastParams.new()
				rayParams.FilterType = Enum.RaycastFilterType.Exclude
				rayParams.FilterDescendantsInstances = { character :: Model }
				local obstruction = Workspace:Raycast(origin, delta, rayParams)
				if flat.Magnitude > 0.1 and flat.Magnitude < bestDistance and math.abs(delta.Y) <= Pounce.HitboxSize.Y
					and base:Dot(flat.Unit) > threshold and (not obstruction or obstruction.Instance:IsDescendantOf(targetCharacter :: Model)) then
					best = flat.Unit
					selectedTarget = targetRoot
					bestDistance = flat.Magnitude
				end
			end
		end
	end
	return if best then base:Lerp(best, Pounce.AimAssistStrength).Unit else base
end

local function launch()
	local activeHumanoid, activeRoot = humanoid, root
	if state ~= "Windup" or not activeHumanoid or not activeRoot then return end
	if not transition("Launching") then return end
	direction = assistedDirection(initialDirection, activeRoot.Position)
	launchedAt = os.clock()
	readyAt = launchedAt + Pounce.HitCooldown
	seenAir = false
	activeHumanoid.AutoRotate = false
	activeHumanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	activeRoot.AssemblyLinearVelocity = direction * Pounce.ForwardSpeed + Vector3.new(0, Pounce.UpwardSpeed, 0)
	play("Leap")
	PounceCamera:Launch()
	Effects.emit(localPlayer, "Launch")
	transition("Airborne")

end

local function landingFeedback()
	if landingShown then return end
	landingShown = true
	awaitingLanding = false
	PounceCamera:Land()
	Effects.emit(localPlayer, if hitConfirmed then "Landing" else "MissLanding")
end

local function beginRecovery(hit: boolean)
	if state == "Airborne" then transition("Landing") end
	if state == "Contact" then transition("Landing") end
	if state ~= "Landing" then return end
	hitConfirmed = hit
	if not hit then readyAt = math.max(readyAt, launchedAt + Pounce.MissCooldown) end
	Effects.cancel(localPlayer)
	local activeHumanoid = humanoid
	if activeHumanoid and activeHumanoid.FloorMaterial ~= Enum.Material.Air then
		landingFeedback()
	else
		awaitingLanding = true
		PounceCamera:Recover()
	end
	transition("Recovery")
	recoveryEndsAt = os.clock() + (if hit then Pounce.HitRecovery else Pounce.MissRecovery)
	play("Recovery")
end

local function start(): boolean
	if not canPounce() or not transition("Windup") then return false end
	pounceId += 1
	startedAt = os.clock()
	serverAnswered = false
	acceptResult = true
	hitConfirmed = false
	landingShown = false
	awaitingLanding = false
	serverResult = "pending"
	local activeHumanoid = humanoid :: Humanoid
	initialDirection = movementDirection(activeHumanoid, root :: BasePart).Unit
	savedAutoRotate = activeHumanoid.AutoRotate
	savedJumpEnabled = activeHumanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
	capturedMovement = true
	activeHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	localPlayer:SetAttribute("HRushLocalPouncing", true)
	play("Windup")
	PounceCamera:Windup()
	Effects.emit(localPlayer, "Windup")
	RequestPounce:FireServer(pounceId)
	return true
end

-- All devices and Studio fixtures use the same eligibility and activation path.
function PounceController.tryActivate(): boolean
	return start()
end

local function attach(newCharacter: Model)
	attachGeneration += 1
	local generation = attachGeneration
	cancel("respawn")
	if diedConnection then diedConnection:Disconnect(); diedConnection = nil end
	for _, track in tracks do track:Stop(0); track:Destroy() end
	tracks = {}
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	local animator = (humanoid :: Humanoid):WaitForChild("Animator") :: Animator
	if generation ~= attachGeneration or localPlayer.Character ~= newCharacter then return end
	for name, id in Pounce.Animations do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
		animation:Destroy()
		if ok then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			tracks[name] = track
		else
			warn("[Pounce] Failed to load " .. name .. " animation")
		end
	end
	diedConnection = (humanoid :: Humanoid).Died:Connect(function() cancel("death") end)
	localPlayer:SetAttribute("HRushLocalPouncing", false)
	state = if os.clock() < readyAt then "Cooldown" else "Ready"
	localPlayer:SetAttribute("HRushLocalPounceState", state)
end

function PounceController.start()
	if running then return end
	running = true
	if localPlayer.Character then task.spawn(attach, localPlayer.Character) end
	localPlayer.CharacterAdded:Connect(attach)
	localPlayer.CharacterRemoving:Connect(function()
		attachGeneration += 1
		cancel("character removed")
	end)
	localPlayer:GetAttributeChangedSignal("HRushState"):Connect(function()
		if localPlayer:GetAttribute("HRushState") ~= "MS_04" then cancel("round ended") end
	end)
	localPlayer:GetAttributeChangedSignal("HRushStunned"):Connect(function()
		if localPlayer:GetAttribute("HRushStunned") == true then cancel("stunned") end
	end)
	ContextActionService:BindActionAtPriority("HRUSH_Pounce", function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pointer = UserInputService:GetMouseLocation()
			for _, object in localPlayer.PlayerGui:GetGuiObjectsAtPosition(pointer.X, pointer.Y) do
				if object:IsA("GuiButton") and object.Active then return Enum.ContextActionResult.Pass end
			end
		end
		return if start() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end, true, Enum.ContextActionPriority.Default.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("HRUSH_Pounce", "POUNCE")
	ContextActionService:SetPosition("HRUSH_Pounce", UDim2.fromScale(0.84, 0.72))
	PounceEvent.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) ~= "table" then return end
		local kind = payload.kind
		if payload.actorId ~= localPlayer.UserId then
			local actor: Instance? = if typeof(payload.actorId) == "number" then Players:GetPlayerByUserId(payload.actorId) else nil
			if not actor then return end
			if kind == "Approved" then Effects.emit(actor, "Windup")
			elseif kind == "Launch" then Effects.emit(actor, "Launch")
			elseif kind == "Hit" then Effects.emit(actor, "TagImpact", payload.position)
			elseif kind == "Land" then Effects.emit(actor, "Landing", payload.position)
			elseif kind == "MissLand" then Effects.emit(actor, "MissLanding", payload.position)
			elseif kind == "Miss" or kind == "Cancel" then Effects.cancel(actor) end
			return
		end
		if payload.id ~= pounceId or not acceptResult then return end
		serverResult = tostring(kind)
		if kind == "Approved" then
			serverAnswered = true
		elseif kind == "Denied" or kind == "Cancel" then
			serverAnswered = true
			readyAt = os.clock() + math.max(0, payload.readyAtServer - Workspace:GetServerTimeNow())
			cancel(kind)
		elseif kind == "Hit" and not hitConfirmed then
			serverAnswered = true
			readyAt = os.clock() + math.max(0, payload.readyAtServer - Workspace:GetServerTimeNow())
			-- A server hit can reconcile a locally predicted landing/miss.
			if transition("Contact") then
				hitConfirmed = true
				contactAt = os.clock()
				localPlayer:SetAttribute("HRushLocalPouncing", true)
				play("Tag")
				PounceCamera:Impact()
				Effects.emit(localPlayer, "TagImpact", payload.position)
			end
		elseif kind == "Miss" and not hitConfirmed then
			serverAnswered = true
			readyAt = os.clock() + math.max(0, payload.readyAtServer - Workspace:GetServerTimeNow())
			if state == "Airborne" or state == "Landing" then beginRecovery(false) end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local activeHumanoid, activeRoot = humanoid, root
		if state == "Windup" and now - startedAt >= Pounce.WindupTime then launch() end
		if state == "Airborne" then
			if not activeHumanoid or not activeRoot or activeHumanoid.Health <= 0 then cancel("rig lost"); return end
			if activeHumanoid.FloorMaterial == Enum.Material.Air then seenAir = true end
			if now - launchedAt >= Pounce.Camera.LaunchHold then PounceCamera:Airborne() end
			local move = activeHumanoid.MoveDirection
			if move.Magnitude > 0.1 and move.Unit:Dot(initialDirection) > math.cos(math.rad(Pounce.MaxSteerAngle)) then
				direction = direction:Lerp(move.Unit, math.min(Pounce.AirControl, dt * Pounce.SteerRate)).Unit
			end
			local velocity = activeRoot.AssemblyLinearVelocity
			activeRoot.AssemblyLinearVelocity = direction * Pounce.ForwardSpeed + Vector3.new(0, velocity.Y, 0)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
		local exclude: { Instance } = { character :: Model }
		for _, other in Players:GetPlayers() do
			if other.Character then table.insert(exclude, other.Character) end
		end
		params.FilterDescendantsInstances = exclude
			params.RespectCanCollide = true
			local wall = Workspace:Blockcast(activeRoot.CFrame, Pounce.WallProbeSize, direction * Pounce.WallLookAhead, params)
			if wall and math.abs(wall.Normal.Y) < Pounce.WallMaxNormalY then
				activeRoot.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
				beginRecovery(false)
			elseif now - launchedAt >= Pounce.MaxAirTime
				or (seenAir and now - launchedAt > Pounce.MinAirTime and activeHumanoid.FloorMaterial ~= Enum.Material.Air) then
				beginRecovery(false)
			end
			local near = selectedTarget and selectedTarget.Parent and (selectedTarget.Position - activeRoot.Position).Magnitude < Pounce.Camera.NearDistance
			PounceCamera:NearTarget(near == true)
		elseif state == "Contact" and now - contactAt >= Pounce.TagPoseTime then
			if not activeHumanoid or activeHumanoid.FloorMaterial ~= Enum.Material.Air or now - launchedAt >= Pounce.MaxAirTime then beginRecovery(true) end
		elseif state == "Recovery" and now >= recoveryEndsAt then
			stopTracks()
			restoreMovement()
			PounceCamera:Recover()
			transition("Cooldown")
		elseif state == "Cooldown" and now >= readyAt then
			transition("Ready")
		end
		if awaitingLanding and activeHumanoid and activeHumanoid.Health > 0 and activeHumanoid.FloorMaterial ~= Enum.Material.Air then
			landingFeedback()
			local id = pounceId
			task.delay(Pounce.Camera.LaunchHold, function()
				if pounceId == id and acceptResult then PounceCamera:Recover() end
			end)
		end
		if state ~= "Ready" and state ~= "Cooldown" and not serverAnswered and now - startedAt > Pounce.ReplyTimeout then cancel("server timeout") end
		if now - uiAt >= Pounce.MinAirTime then
			uiAt = now
			localPlayer:SetAttribute("HRushPounceCD", math.max(0, readyAt - now))
			local button = ContextActionService:GetButton("HRUSH_Pounce")
			if button then button.Visible = localPlayer:GetAttribute("HRushRole") == "Taya" and localPlayer:GetAttribute("HRushState") == "MS_04" end
		end
		Effects.debug(activeRoot, direction, state, pounceId, math.max(0, readyAt - now), selectedTarget, serverResult)

	end)
end

return PounceController
