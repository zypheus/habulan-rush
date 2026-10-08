--!strict
-- Client-only aim helper. Server tag and pounce checks must never trust it.
-- Integration attributes, set by the server on Player:
-- IsTaya: true for Taya; false or absent for a Runner.
-- LockDelayUntil: server timestamp; T12 blocks acquisition until it expires.
-- LockDisabled: true while TS_03 blocks acquisition and breaks the lock.
-- IsDashing / IsHidden: target flags that break locks (Stage E).
-- RS_02 client effects can require this module and call :BreakLock("DecoySwap").
-- Implemented: acquisition, manual toggle, cycle, reticle, camera assist.
-- Pending: break rules (E), attribute hooks (E).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Settings = Config.TargetLock
local LocalPlayer = Players.LocalPlayer
local TargetLockController = {}
local initialized = false
local connections: { RBXScriptConnection } = {}
local target: Player? = nil
local roundLive = false
local cooldownUntil = 0
local scanElapsed = 0
local acquireRequested = false
local toggleFireCount = 0 -- diagnostic: counts toggle Begin events (Stage A)
-- Camera assist state: a persistent angular offset owned by the lock.
local ASSIST_BIND = "TargetLockAssist"
local assistBound = false
local yawOffset = 0   -- radians, persists across frames
local pitchOffset = 0 -- radians, persists across frames
local steerFlag = false -- set true on any camera input this frame
local stickMag = 0      -- right-stick magnitude, kept while held
local TOGGLE_ACTION = "HRUSH_TargetLockToggle"
local CYCLE_ACTION = "HRUSH_TargetLockCycle"

type Candidate = { player: Player, character: Model, root: BasePart, aimPart: BasePart }
local candidates: { Candidate } = {}
local reticleGui: BillboardGui? = nil
local targetConnections: { RBXScriptConnection } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- Respect CanQuery rather than treating non-collidable cover as invisible.
rayParams.RespectCanCollide = false

local function debugPrint(message: string)
	if Settings.DebugPrint then
		print("[TargetLockController] " .. message)
	end
end

local function livingRoot(character: Model?): BasePart?
	if not character or not character.Parent then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function aimPart(character: Model): BasePart?
	-- Support R15 and R6 without ever aiming at feet.
	local part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		or character:FindFirstChild("Head")
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- Reticle lifecycle helpers. The GUI lives in this client's PlayerGui, so only
-- this player ever sees it.
local function unbindTargetConnections()
	for _, connection in targetConnections do
		connection:Disconnect()
	end
	table.clear(targetConnections)
end

local function destroyReticleNow()
	if reticleGui then
		reticleGui:Destroy()
		reticleGui = nil
	end
end

-- Draw the ring with UI instances only (Frame + UICorner + UIStroke + notches)
-- so it needs no image asset and still reads without colour.
local function createReticle(aim: BasePart?)
	destroyReticleNow()
	if not aim then
		return
	end
	local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end
	local rc = Settings.Reticle

	local gui = Instance.new("BillboardGui")
	gui.Name = "HRUSH_TargetLockReticle"
	gui.ResetOnSpawn = false
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(rc.SizePx, rc.SizePx)
	gui.StudsOffset = rc.StudsOffset
	gui.Adornee = aim

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(1, 1)
	ring.BackgroundTransparency = 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0) -- full radius turns the square frame into a circle
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Color = rc.RingColor
	stroke.Thickness = rc.RingThickness
	stroke.Transparency = rc.RingTransparency
	stroke.Parent = ring

	-- Four notch marks keep the ring readable in grayscale.
	local function makeNotch(name: string, x: number, y: number, ax: number, ay: number)
		local mark = Instance.new("Frame")
		mark.Name = name
		mark.AnchorPoint = Vector2.new(ax, ay)
		mark.Position = UDim2.fromScale(x, y)
		mark.Size = UDim2.fromOffset(rc.NotchSizePx, rc.NotchSizePx)
		mark.BackgroundColor3 = rc.NotchColor
		mark.BorderSizePixel = 0
		mark.Parent = ring
	end
	makeNotch("Top", 0.5, 0, 0.5, 0)
	makeNotch("Bottom", 0.5, 1, 0.5, 1)
	makeNotch("Left", 0, 0.5, 0, 0.5)
	makeNotch("Right", 1, 0.5, 1, 0.5)

	local scale = Instance.new("UIScale")
	scale.Scale = rc.StartScale
	scale.Parent = ring

	ring.Parent = gui
	gui.Parent = playerGui
	reticleGui = gui

	if Config.Debug.ShowLockDebug then
		print("[TargetLock] reticle created on " .. aim.Name)
	end

	if rc.Animate then
		TweenService:Create(
			scale,
			TweenInfo.new(rc.ScaleInTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	else
		scale.Scale = 1
	end
end

-- Remove the reticle, fading it first when animated. The reference is cleared
-- immediately so a fresh lock can build a new one while the old fades out.
local function destroyReticle(animated: boolean?)
	local gui = reticleGui
	reticleGui = nil
	if not gui then
		return
	end
	if animated ~= true or Settings.Reticle.Animate ~= true then
		gui:Destroy()
		return
	end
	local rc = Settings.Reticle
	local ring = gui:FindFirstChild("Ring")
	local stroke = ring and ring:FindFirstChildOfClass("UIStroke")
	local scale = ring and ring:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, TweenInfo.new(rc.FadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = rc.EndScale }):Play()
	end
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(rc.FadeOutTime), { Transparency = 1 }):Play()
	end
	if ring then
		for _, child in ring:GetChildren() do
			if child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(rc.FadeOutTime), { BackgroundTransparency = 1 }):Play()
			end
		end
	end
	task.delay(rc.FadeOutTime + 0.05, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

-- Break the lock when the target dies, leaves, or its character is removed.
local function bindTargetLifecycle(targetPlayer: Player)
	local character = targetPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(targetConnections, humanoid.Died:Once(function()
			TargetLockController:BreakLock("TargetDied")
		end))
	end
	if character then
		table.insert(targetConnections, character.AncestryChanged:Connect(function(_child, parent)
			if parent == nil then
				TargetLockController:BreakLock("TargetCharacterRemoved")
			end
		end))
	end
	table.insert(targetConnections, Players.PlayerRemoving:Connect(function(leaver)
		if leaver == targetPlayer then
			TargetLockController:BreakLock("TargetLeft")
		end
	end))
end

-- ===== Camera soft assist (Stage C) =====
-- A persistent yaw/pitch offset owned by the lock. The default camera runs first
-- at Camera priority and resets camera.CFrame each frame, so we read its fresh
-- output at Camera + 1, rotate it by our stored offsets, and write it back.
-- We never persist camera.CFrame itself (the default would overwrite it); we
-- persist yawOffset/pitchOffset and re-apply them to the fresh default every frame.
local assistPrintAcc = 0

local function unbindAssist()
	if not assistBound then
		return
	end
	RunService:UnbindFromRenderStep(ASSIST_BIND)
	assistBound = false
	yawOffset = 0
	pitchOffset = 0
	if Config.Debug.ShowLockDebug then
		print("[TargetLock] assist render step unbound")
	end
end

local function onAssistRender(dt: number)
	local ca = Settings.CameraAssist
	if not ca.Enabled then
		unbindAssist()
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	-- Only assist while the DEFAULT camera is driving (CameraType == Custom). In
	-- that state the default camera rewrites camera.CFrame at Camera priority every
	-- frame, so the base we read here is clean and rotating it cannot compound.
	-- In Scriptable (or any other) mode nothing resets camera.CFrame, so rotating
	-- what we read would compound our own previous write into a shake. LobbyUI's
	-- lobby camera forces Scriptable, so back out cleanly if it is still active.
	if camera.CameraType ~= Enum.CameraType.Custom then
		if Config.Debug.ShowLockDebug then
			print("[TargetLock] assist off, CameraType=" .. tostring(camera.CameraType))
		end
		unbindAssist()
		return
	end

	-- Where the locked target's aim point is this frame, if any.
	local aimPoint: Vector3? = nil
	local tp = target
	if tp then
		local char = tp.Character
		local part = char and aimPart(char)
		if part then
			aimPoint = part.Position + Settings.AimPointOffset
		end
	end

	local base = camera.CFrame -- the default camera's fresh output this frame

	if aimPoint then
		local toTarget = aimPoint - base.Position
		if toTarget.Magnitude > 1e-3 then
			-- Aim point in the camera's local space. Local yaw = atan2(-X, -Z),
			-- local pitch = asin(Y); these are the offsets that point look at target.
			local localDir = base:VectorToObjectSpace(toTarget.Unit)
			local errYaw = math.atan2(-localDir.X, -localDir.Z)
			local errPitch = math.asin(math.clamp(localDir.Y, -1, 1)) * ca.PitchWeight

			-- Frame-rate independent blend; weaken it while the player steers so
			-- they can always look away.
			local alpha = 1 - math.exp(-ca.AssistStrength * dt)
			local steering = steerFlag or stickMag > ca.InputDampenThreshold
			steerFlag = false
			if steering then
				alpha = alpha * ca.InputDampenFactor
			end

			local maxStep = math.rad(ca.MaxTurnRateDegPerSec) * dt
			local dYaw = math.clamp((errYaw - yawOffset) * alpha, -maxStep, maxStep)
			local dPitch = math.clamp((errPitch - pitchOffset) * alpha, -maxStep, maxStep)
			yawOffset = yawOffset + dYaw
			pitchOffset = math.clamp(
				pitchOffset + dPitch,
				-math.rad(ca.MaxPitchDeg),
				math.rad(ca.MaxPitchDeg)
			)

			-- TODO: remove before submission (prove the render step runs and show
			-- the angle to the target before and after assist, once per second).
			if Config.Debug.ShowLockDebug then
				assistPrintAcc += dt
				if assistPrintAcc >= 1.0 then
					assistPrintAcc = 0
					local afterLook = (base * CFrame.Angles(pitchOffset, yawOffset, 0)).LookVector
					local residual = math.deg(math.acos(math.clamp(afterLook:Dot(toTarget.Unit), -1, 1)))
					print(("[TargetLock] assist yawBefore=%.1fdeg residual=%.1fdeg off=(%.2f,%.2f)")
						:format(math.deg(errYaw), residual, yawOffset, pitchOffset))
				end
			end
		end
	else
		-- No target (unlocking): ease offsets back to zero so there is no snap.
		local alpha = 1 - math.exp(-ca.AssistStrength * dt)
		yawOffset = yawOffset * (1 - alpha)
		pitchOffset = pitchOffset * (1 - alpha)
		steerFlag = false
	end

	-- Rotate the default camera's fresh CFrame by the persistent offsets. Keeping
	-- base.Position means zoom and wall collision from the default camera still work.
	camera.CFrame = base * CFrame.Angles(pitchOffset, yawOffset, 0)

	-- Once fully decayed with no target, release the render step (no leak).
	if not target and math.abs(yawOffset) < 1e-4 and math.abs(pitchOffset) < 1e-4 then
		unbindAssist()
	end
end

local function bindAssist()
	local ca = Settings.CameraAssist
	if not ca.Enabled or assistBound then
		return
	end
	RunService:BindToRenderStep(ASSIST_BIND, Enum.RenderPriority.Camera.Value + 1, onAssistRender)
	assistBound = true
	if Config.Debug.ShowLockDebug then
		local cam = Workspace.CurrentCamera
		print("[TargetLock] assist render step bound, CameraType=" .. tostring(cam and cam.CameraType))
	end
end

-- Clear the active target and tear down its reticle and connections.
-- Returns true if a target was actually cleared.
local function clearTarget(_reason: string, animated: boolean?): boolean
	acquireRequested = false
	local wasLocked = target ~= nil
	target = nil
	unbindTargetConnections()
	destroyReticle(animated)
	return wasLocked
end

local function lockOn(best: Player)
	unbindTargetConnections()
	target = best
	local character = best.Character
	local part = character and aimPart(character)
	createReticle(part)
	bindTargetLifecycle(best)
	bindAssist()
	debugPrint("Locked " .. best.Name)
end

-- Move the lock to the next nearest candidate; lockOn re-adorns the reticle.
local function cycleTarget()
	if not target then
		return
	end
	local root = livingRoot(LocalPlayer.Character)
	if not root or #candidates < 2 then
		debugPrint("Cycle: only one target")
		return
	end
	-- Sort by distance; candidates is at most the player count, so this is cheap.
	local order: { Candidate } = {}
	for _, candidate in candidates do
		table.insert(order, candidate)
	end
	table.sort(order, function(a, b)
		return (a.root.Position - root.Position).Magnitude < (b.root.Position - root.Position).Magnitude
	end)
	local index = 0
	for i, candidate in order do
		if candidate.player == target then
			index = i
			break
		end
	end
	if index == 0 then
		lockOn(order[1].player)
		return
	end
	local nextCandidate = order[(index % #order) + 1]
	if nextCandidate.player ~= target then
		lockOn(nextCandidate.player)
		debugPrint("Cycle -> " .. nextCandidate.player.Name)
	end
end

local function passesRole(player: Player): boolean
	if Config.Debug.AllowAnyRoleTargetLock then
		return true
	end
	return LocalPlayer:GetAttribute("IsTaya") == true and player:GetAttribute("IsTaya") ~= true
end

local function refreshCandidates()
	table.clear(candidates)
	local character = LocalPlayer.Character
	local root = livingRoot(character)
	if not roundLive or not character or not root then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	for _, player in Players:GetPlayers() do
		if player == LocalPlayer or not passesRole(player) then
			continue
		end
		local otherCharacter = player.Character
		local otherRoot = livingRoot(otherCharacter)
		if not otherCharacter or not otherRoot then
			continue
		end
		local part = aimPart(otherCharacter)
		if not part or (otherRoot.Position - root.Position).Magnitude > Settings.AcquireRange then
			continue
		end
		-- Exclude both avatars so accessories do not count as walls.
		rayParams.FilterDescendantsInstances = { character, otherCharacter }
		local direction = part.Position + Settings.AimPointOffset - head.Position
		if Workspace:Raycast(head.Position, direction, rayParams) == nil then
			table.insert(candidates, { player = player, character = otherCharacter, root = otherRoot, aimPart = part })
		end
	end
end

local function acquire()
	local camera = Workspace.CurrentCamera
	local root = livingRoot(LocalPlayer.Character)
	if not camera or not root or not roundLive or Workspace:GetServerTimeNow() < cooldownUntil then
		-- TODO: remove before submission (explains a silent R press: round state / cooldown).
		if Config.Debug.ShowLockDebug then
			print(("[TargetLock] acquire BLOCKED  roundLive=%s  onCooldown=%s  hasRoot=%s")
				:format(tostring(roundLive), tostring(Workspace:GetServerTimeNow() < cooldownUntil), tostring(root ~= nil)))
		end
		return
	end
	local best: Player? = nil
	local bestDot = -math.huge
	local bestDistance = math.huge
	for _, candidate in candidates do
		local direction = candidate.aimPart.Position + Settings.AimPointOffset - camera.CFrame.Position
		if direction.Magnitude == 0 then
			continue
		end
		-- Larger dot product means a smaller angle to the camera centre.
		local dot = camera.CFrame.LookVector:Dot(direction.Unit)
		local distance = (candidate.root.Position - root.Position).Magnitude
		if dot > bestDot or (dot == bestDot and distance < bestDistance) then
			best = candidate.player
			bestDot = dot
			bestDistance = distance
		end
	end
	if best then
		lockOn(best)
	else
		debugPrint("No target")
	end
end

function TargetLockController:GetTarget(): Player?
	return target
end

function TargetLockController:BreakLock(reason: string)
	local wasLocked = clearTarget(reason, true)
	if wasLocked then
		cooldownUntil = Workspace:GetServerTimeNow() + Settings.BreakCooldown
		debugPrint("Broken: " .. reason)
	end
end

function TargetLockController:Init()
	if initialized then
		return
	end
	assert(RunService:IsClient(), "TargetLockController is client-only")
	local remotes = ReplicatedStorage:WaitForChild("Remotes", Settings.DependencyTimeout)
	assert(remotes, "TargetLockController: Remotes missing")
	local stateChanged = remotes:WaitForChild("StateChanged", Settings.DependencyTimeout)
	assert(stateChanged and stateChanged:IsA("RemoteEvent"), "TargetLockController: StateChanged missing")
	initialized = true
	roundLive = ReplicatedStorage:GetAttribute("HRushRoundState") == "MS_04"
	table.insert(connections, stateChanged.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and typeof(payload.state) == "string" then
			roundLive = payload.state == "MS_04"
		end
	end))
	table.insert(connections, LocalPlayer.CharacterRemoving:Connect(function()
		if target then
			clearTarget("LocalRespawn", false)
			debugPrint("Broken: LocalRespawn")
		end
	end))
	-- Track when the player steers the camera so the assist can step aside.
	table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject)
		local ut = input.UserInputType
		if ut == Enum.UserInputType.MouseMovement or ut == Enum.UserInputType.Touch then
			if input.Delta.Magnitude > Settings.CameraAssist.InputDampenThreshold then
				steerFlag = true
			end
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			stickMag = input.Position.Magnitude
		end
	end))
	ContextActionService:BindAction(TOGGLE_ACTION, function(_name, state, _input)
		if state == Enum.UserInputState.Begin then
			toggleFireCount += 1
			-- TODO: remove before submission (proves one press fires Begin exactly once)
			if Config.Debug.ShowLockDebug then
				print(("[TargetLock] toggle Begin #%d  t=%.3f  key=%s")
					:format(toggleFireCount, tick(), tostring(_input.KeyCode)))
			end
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			if target then
				clearTarget("ManualUnlock", true)
				debugPrint("Unlocked manually (no cooldown)")
			else
				acquireRequested = not acquireRequested
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Settings.Keybinds.Toggle, Settings.Keybinds.GamepadToggle)
	ContextActionService:BindAction(CYCLE_ACTION, function(_name, state, _input)
		if state == Enum.UserInputState.Begin and target then
			cycleTarget()
		end
		return Enum.ContextActionResult.Sink
	end, false, Settings.Keybinds.Cycle, Settings.Keybinds.GamepadCycle)
	-- Queue input until the next scan rather than raycasting on key spam.
	scanElapsed = 1 / Settings.CandidateRefreshRate
	table.insert(connections, RunService.Heartbeat:Connect(function(dt: number)
		scanElapsed += dt
		local interval = 1 / Settings.CandidateRefreshRate
		if scanElapsed < interval then
			return
		end
		scanElapsed %= interval
		refreshCandidates()
		if acquireRequested then
			acquireRequested = false
			acquire()
		end
	end))
	debugPrint("Stage B ready: " .. Settings.Keybinds.Toggle.Name .. " toggle, " .. Settings.Keybinds.Cycle.Name .. " cycle reserved")
end

function TargetLockController:Destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(candidates)
	unbindTargetConnections()
	destroyReticleNow()
	unbindAssist()
	ContextActionService:UnbindAction(TOGGLE_ACTION)
	ContextActionService:UnbindAction(CYCLE_ACTION)
	target = nil
	acquireRequested = false
	cooldownUntil = 0
	roundLive = false
	initialized = false
end

return TargetLockController
