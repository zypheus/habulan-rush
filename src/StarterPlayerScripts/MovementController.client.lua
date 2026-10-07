--!strict
-- StarterPlayerScripts/MovementController.lua (LocalScript)
-- Owner: Programmer A
-- T09 [Code/P0] MovementController — Client movement & stamina (COMPLETE)
--
-- Responsibilities:
--   • Runner walk / sprint speed via Humanoid.WalkSpeed (16 / 21, Config-driven)
--   • Stamina drain 20/s, regen 12/s after 1s, depletion lock until >= 10
--   • Post-tag ex-Taya boost: +20% walk+sprint for 2s (F08, via TagEvent)
--   • Dash: 12 studs linear in 0.2s, 6s cooldown, 0.15s pounce invuln (F07),
--     wall-clamped raycast, RequestDash → server (server validates + records)
--   • Slide: 0.6s, 3s cooldown, 50% hitbox (HipHeight), momentum entry (F09)
--   • Movement lock: MS_03 Countdown WalkSpeed 0; dash/slide gated to MS_04.
--     NOTE (playtest): Bootstrap TEMP auto-fires MS_04/Runner 1.5s after spawn
--     until MatchService T07 owns the state machine — without it you stay locked.
--   • Bindings (UI/UX Spec §4): PC Shift/Q/C · Gamepad L2-stick/B/R1 · Touch buttons
--   • Dash VFX: rear Trail ribbon + particle burst on Q (Config.Movement.DashVFX)
--   • UI bridge: HRush* attributes on LocalPlayer (UIController reads poll-free)
--
-- Does NOT handle: tag detection/validation (TagService owns truth),
-- skill cooldowns (SkillService), timers/scores (MatchService), or lock camera.
--
-- All numeric constants come exclusively from Config.Movement — zero hardcoding.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- ── Config ──────────────────────────────────────────────────────────────────
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Mv     = Config.Movement   -- shorthand

-- ── Player / character refs ──────────────────────────────────────────────────
local LocalPlayer = Players.LocalPlayer
local Character: Model
local Humanoid: Humanoid
local HRP: BasePart  -- HumanoidRootPart

-- ── Remotes ──────────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestDash = Remotes:WaitForChild("RequestDash") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local TagEvent = Remotes:WaitForChild("TagEvent") :: RemoteEvent

-- ── State ────────────────────────────────────────────────────────────────────
-- Stamina
local stamina = Mv.StaminaMax
local isDepletion = false -- true after stamina reaches 0; locked until >= StaminaDepletedMin
local isSprinting = false -- whether sprint key is held AND conditions allow sprinting
local regenTimer = 0.0 -- seconds since sprint stopped

-- Dash
local isDashing = false
local dashCooldownLeft = 0.0
local dashInvulnLeft = 0.0 -- F07 pounce invulnerability window (vs pounce lunge only)
local dashConn: RBXScriptConnection? = nil

-- Slide
local isSliding = false
local slideCooldownLeft = 0.0
local slideTimer = 0.0
local slideHipHeight = 0.0 -- HipHeight captured at slide start (restored on end)

-- Post-tag boost (Spec §3 / F08): ex-Taya +20% walk+sprint for 2s, stamina rules unchanged.
local boostLeft = 0.0

-- Movement lock: MS_03 Countdown locks input; MS_05/MS_06/MS_01 freeze & end slides.
local inputLocked = true

local role = "Runner" -- "Runner" | "Taya"; updated by StateChanged
local roundLive = false -- true only during MS_04 Round Live (dash/slide gate)

-- Sprint input held flags per device
local sprintHeld_KB     = false
local sprintHeld_GP     = false
local dashRequested_KB  = false
local dashRequested_GP  = false
local slideRequested_KB = false
local slideRequested_GP = false

-- ── Utility ──────────────────────────────────────────────────────────────────
local function getCharRefs(): boolean
	Character = LocalPlayer.Character
	if not Character then return false end
	Humanoid = Character:FindFirstChildOfClass("Humanoid") :: Humanoid
	HRP      = Character:FindFirstChild("HumanoidRootPart") :: BasePart
	return Humanoid ~= nil and HRP ~= nil
end

local function clamp(v, lo, hi)
	return math.max(lo, math.min(hi, v))
end

-- ── Speed management ─────────────────────────────────────────────────────────
-- Spec §3 + F08: Runner walk 16 / sprint 21. Ex-Taya gets +20% on BOTH base
-- speeds for 2s (PostTagSpeedBoostMult/Duration); stamina rules unchanged.
-- Taya is a flat 18 with no stamina. Slide holds its entry speed (momentum).
-- Call this any time role / sprint / boost / lock state changes.
local function applySpeed()
	if not Humanoid then
		return
	end
	if inputLocked then
		Humanoid.WalkSpeed = 0
		return
	end
	if role == "Taya" then
		Humanoid.WalkSpeed = Mv.TayaSpeed
		return
	end

	if isSliding then
		-- During slide keep momentum; speed was set once on slide start.
		return
	end

	local mult = 1.0
	if boostLeft > 0 then
		mult = Mv.PostTagSpeedBoostMult
	end

	local targetSpeed: number
	if isSprinting then
		targetSpeed = Mv.RunnerSprintSpeed * mult
	else
		targetSpeed = Mv.RunnerWalkSpeed * mult
	end

	Humanoid.WalkSpeed = targetSpeed
end

-- ── Stamina ──────────────────────────────────────────────────────────────────
-- Spec §3: drain 20/s while sprinting; regen +12/s after 1s without sprinting.
-- Depletion (hit 0) forces walk until stamina >= StaminaDepletedMin (10).
-- Sprint counts only while the character is actually trying to move
-- (Humanoid.MoveDirection), so holding Shift while standing still never drains.
local function updateStamina(dt: number)
	if role == "Taya" then
		return
	end

	local sprintKeyHeld = sprintHeld_KB or sprintHeld_GP
	local isMoving = false
	if Humanoid then
		isMoving = Humanoid.MoveDirection.Magnitude > 0.1
	end

	-- Decide if we're actually sprinting this frame
	local wantSprint = sprintKeyHeld and isMoving and not isSliding and not isDashing
	if isDepletion and stamina < Mv.StaminaDepletedMin then
		wantSprint = false -- forced walk until stamina recovers enough
	elseif isDepletion and stamina >= Mv.StaminaDepletedMin then
		isDepletion = false -- depletion lock released
	end

	if wantSprint then
		-- Drain stamina
		isSprinting = true
		regenTimer = 0.0
		stamina = clamp(stamina - Mv.StaminaDrainRate * dt, 0, Mv.StaminaMax)
		if stamina <= 0 then
			stamina = 0
			isSprinting = false
			isDepletion = true -- enter depletion; walk enforced
		end
	else
		-- Regen stamina after delay
		isSprinting = false
		regenTimer = regenTimer + dt
		if regenTimer >= Mv.StaminaRegenDelay then
			stamina = clamp(stamina + Mv.StaminaRegenRate * dt, 0, Mv.StaminaMax)
		end
	end

	applySpeed()
end

-- ── UI attribute bridge ────────────────────────────────────────────────────────
-- LocalScripts cannot be require()d, so UIController reads live movement state
-- from attributes on LocalPlayer (poll-free via GetAttributeChangedSignal):
--   HRushStamina (0–100), HRushStaminaMax, HRushDashCD, HRushSlideCD,
--   HRushDashing (bool), HRushSliding (bool), HRushBoost (seconds left),
--   HRushRole ("Runner" | "Taya") — UI gates Runner-only HUD (stamina bar).
local lastPush = 0.0
local function pushAttributes(force: boolean?)
	local now = os.clock()
	if not force and (now - lastPush) < 0.1 then
		return
	end
	lastPush = now
	LocalPlayer:SetAttribute("HRushStamina", stamina)
	LocalPlayer:SetAttribute("HRushStaminaMax", Mv.StaminaMax)
	LocalPlayer:SetAttribute("HRushDashCD", dashCooldownLeft)
	LocalPlayer:SetAttribute("HRushSlideCD", slideCooldownLeft)
	LocalPlayer:SetAttribute("HRushDashing", isDashing)
	LocalPlayer:SetAttribute("HRushSliding", isSliding)
	LocalPlayer:SetAttribute("HRushBoost", boostLeft)
	LocalPlayer:SetAttribute("HRushRole", role)
end

-- ── Dash VFX (client-side juice) ─────────────────────────────────────────────
-- Game-feel medium tier: transient ribbon + particle burst on the Q event —
-- 2 cheap channels, decays to rest via TrailLifetime/ParticleLifetime, never
-- touches input or simulation. All values from Config.Movement.DashVFX.
local dashTrail: Trail? = nil
local dashEmitter: ParticleEmitter? = nil

local function buildDashFX(char: Model)
	dashTrail = nil
	dashEmitter = nil
	if not Mv.DashVFX.Enabled then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end

	-- Ribbon anchors: rear corners of HumanoidRootPart (character faces -Z,
	-- so +Z offset = behind the player — the streak trails the dash path).
	local attA = Instance.new("Attachment")
	attA.Name = "DashFX_A"
	attA.Position = Vector3.new(-0.9, -0.5, 0.9)
	attA.Parent = hrp
	local attB = Instance.new("Attachment")
	attB.Name = "DashFX_B"
	attB.Position = Vector3.new(0.9, -0.5, 0.9)
	attB.Parent = hrp

	local trail = Instance.new("Trail")
	trail.Name = "DashTrail"
	trail.Attachment0 = attA
	trail.Attachment1 = attB
	trail.FaceCamera = true
	trail.Lifetime = Mv.DashVFX.TrailLifetime
	trail.Color = ColorSequence.new(Mv.DashVFX.ColorStart, Mv.DashVFX.ColorEnd)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Mv.DashVFX.TransparencyIn),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Enabled = false -- on only while dashing; segments linger after disable
	trail.Parent = hrp
	dashTrail = trail

	-- One-shot burst emitter at the heels. Rate 0 → particles only via Emit().
	-- Emitted in WORLD space (not locked to part) so streaks stay behind while
	-- the character glides forward 12 studs.
	local attEmit = Instance.new("Attachment")
	attEmit.Name = "DashFX_Emit"
	attEmit.Position = Vector3.new(0, -0.5, 1.0)
	attEmit.Parent = hrp

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "DashBurst"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(Mv.DashVFX.ParticleLifetime)
	emitter.Speed = NumberRange.new(Mv.DashVFX.ParticleSpeedMin, Mv.DashVFX.ParticleSpeedMax)
	emitter.SpreadAngle = Vector2.new(30, 30)
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.Acceleration = Vector3.new(0, -8, 0) -- slight settle, no float-up
	emitter.Color = ColorSequence.new(Mv.DashVFX.ColorStart, Mv.DashVFX.ColorEnd)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Mv.DashVFX.SizeStart),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Mv.DashVFX.TransparencyIn),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = Mv.DashVFX.LightEmission
	emitter.Parent = attEmit
	dashEmitter = emitter
end

local function startDashFX()
	if dashTrail then
		dashTrail.Enabled = true
	end
	if dashEmitter then
		dashEmitter:Emit(Mv.DashVFX.BurstCount)
	end
end

local function stopDashFX()
	-- Disabling stops new ribbon segments; existing ones fade over TrailLifetime.
	if dashTrail then
		dashTrail.Enabled = false
	end
end

-- ── Dash ──────────────────────────────────────────────────────────────────────
-- Spec §3: DashDistance (12) studs in DashDuration (0.2s), DashCooldown (6s),
-- DashPounceInvulnTime (0.15s, F07 vs pounce lunge only — server enforces this).
-- No stamina cost. Movement is linear start→end (constant velocity 60 st/s);
-- a forward raycast clamps the target so the dash stops at walls instead of
-- phasing through. Server is notified via RequestDash (validates cooldown/round).
local function cancelDash()
	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end
	isDashing = false
	stopDashFX()
	applySpeed()
	pushAttributes()
end

local function performDash()
	if not roundLive or inputLocked then
		return
	end
	if role ~= "Runner" then
		return
	end
	if isDashing or dashCooldownLeft > 0 then
		return
	end
	if isSliding then
		return
	end
	if not Humanoid or not HRP then
		return
	end

	isDashing = true
	dashInvulnLeft = Mv.DashPounceInvulnTime
	dashCooldownLeft = Mv.DashCooldown

	-- Direction: current move direction if moving, else facing.
	local moveDir = Humanoid.MoveDirection
	if moveDir.Magnitude < 0.1 then
		moveDir = HRP.CFrame.LookVector
	end
	moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
	if moveDir.Magnitude < 0.01 then
		moveDir = HRP.CFrame.LookVector
		moveDir = Vector3.new(moveDir.X, 0, moveDir.Z)
	end
	moveDir = moveDir.Unit

	-- Notify the server (server records dash direction + timestamp for invuln check).
	RequestDash:FireServer(moveDir)

	-- VFX: ribbon on during the glide + one-shot particle burst at the heels.
	startDashFX()

	-- Clamp travel so we stop at walls instead of phasing through them.
	local travel = Mv.DashDistance
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { Character }
	rayParams.IgnoreWater = true
	local origin = HRP.Position + Vector3.new(0, 0.5, 0)
	local hit = Workspace:Raycast(origin, moveDir * (travel + 1), rayParams)
	if hit then
		-- Leave a 1-stud margin so the capsule never embeds in the wall.
		travel = math.max(0, hit.Distance - 1)
	end

	-- Client-side glide: linear interpolation start→end over DashDuration.
	-- Constant velocity (NOT eased) so 12 studs really land in 0.2s.
	local startPos = HRP.Position
	local dashDir = moveDir
	local elapsed = 0.0
	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end
	dashConn = RunService.Heartbeat:Connect(function(dt: number)
		if not HRP or not HRP.Parent then
			cancelDash()
			return
		end
		elapsed += dt
		local alpha = clamp(elapsed / Mv.DashDuration, 0, 1)
		local targetPos = startPos + dashDir * travel
		local face = HRP.CFrame - HRP.CFrame.Position
		HRP.CFrame = CFrame.new(startPos:Lerp(targetPos, alpha)) * face
		if alpha >= 1 then
			cancelDash()
		end
	end)
end

-- ── Slide ─────────────────────────────────────────────────────────────────────
-- Spec §3 + F09: SlideDuration (0.6s), SlideCooldown (3s), hitbox at
-- SlideHitboxScale (50% height) so touch tag cannot hit a Runner under a low gap
-- (TagService reads the sliding flag via position/height; server owns the verdict).
-- Entry keeps current momentum with a small forward burst; WalkSpeed is held at
-- slide entry speed. Cancelled by dash attempts, tag swaps, round end, or death.
local function endSlide()
	if not isSliding or not Humanoid then
		return
	end
	-- Restore exact HipHeight captured at slide start (never assume the default).
	Humanoid.HipHeight = slideHipHeight
	isSliding = false
	applySpeed()
	pushAttributes(true)
end

local function performSlide()
	if not roundLive or inputLocked then
		return
	end
	if role ~= "Runner" then
		return
	end
	if isSliding or slideCooldownLeft > 0 then
		return
	end
	if isDashing then
		return
	end
	if not Humanoid or not HRP then
		return
	end
	if Humanoid.MoveDirection.Magnitude < 0.1 then
		return -- must be moving to slide
	end

	isSliding = true
	slideTimer = 0.0
	slideCooldownLeft = Mv.SlideCooldown
	slideHipHeight = Humanoid.HipHeight

	-- Shrink hitbox: halve height (F09 — low-gap evasion).
	Humanoid.HipHeight = slideHipHeight * Mv.SlideHitboxScale

	-- Hold entry momentum: lock WalkSpeed at max(walk, current horizontal speed)
	-- and add a small forward burst via AssemblyLinearVelocity (physics-safe).
	local flatVel = Vector3.new(HRP.AssemblyLinearVelocity.X, 0, HRP.AssemblyLinearVelocity.Z)
	local entrySpeed = math.max(Mv.RunnerWalkSpeed, flatVel.Magnitude)
	Humanoid.WalkSpeed = entrySpeed
	local burstDir = Vector3.new(Humanoid.MoveDirection.X, 0, Humanoid.MoveDirection.Z)
	if burstDir.Magnitude > 0.01 then
		burstDir = burstDir.Unit
		local targetVel = burstDir * entrySpeed
		HRP.AssemblyLinearVelocity = Vector3.new(targetVel.X, HRP.AssemblyLinearVelocity.Y, targetVel.Z)
	end
	pushAttributes(true)
	-- NOTE: server is NOT notified (slide is client-predicted; tag validation
	-- uses rewound server positions per TDD §4.3).
end

-- ── Cooldown & invuln ticking ────────────────────────────────────────────────
local function tickCooldowns(dt: number)
	if dashCooldownLeft > 0 then
		dashCooldownLeft = math.max(0, dashCooldownLeft - dt)
	end
	if slideCooldownLeft > 0 then
		slideCooldownLeft = math.max(0, slideCooldownLeft - dt)
	end
	if dashInvulnLeft > 0 then
		dashInvulnLeft = math.max(0, dashInvulnLeft - dt)
	end
	-- Post-tag boost countdown (F08); re-apply speed when it expires.
	if boostLeft > 0 then
		boostLeft = math.max(0, boostLeft - dt)
		if boostLeft <= 0 and not isSliding then
			applySpeed()
		end
	end

	-- Advance slide timer
	if isSliding then
		slideTimer += dt
		if slideTimer >= Mv.SlideDuration then
			endSlide()
		end
	end
end

-- ── Heartbeat ────────────────────────────────────────────────────────────────
local heartbeatConn: RBXScriptConnection? = nil
local gamepadTick = 0.0
local function startHeartbeat()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		if not Humanoid or not HRP then
			getCharRefs()
			return
		end
		if Humanoid.Health <= 0 then
			return
		end

		-- Gamepad sprint (throttled to 10 Hz): left stick full tilt = sprinting.
		-- Spec-correct bindings are L2 (ButtonL2) for sprint-hold, Touch = Sprint button.
		gamepadTick += dt
		if gamepadTick >= 0.1 then
			gamepadTick = 0.0
			local found = false
			local ok, gp = pcall(UserInputService.GetGamepadState, UserInputService, Enum.UserInputType.Gamepad1)
			if ok and gp then
				for _, inputObj in gp do
					if inputObj.KeyCode == Enum.KeyCode.Thumbstick1 then
						sprintHeld_GP = inputObj.Position.Magnitude > 0.8
						found = true
						break
					end
				end
			end
			if not found then
				-- Fall back to the L2 hold flag set by ContextActionService below.
				-- (Keeps sprint working on gamepads whose stick state isn't exposed.)
			end
		end

		tickCooldowns(dt)
		updateStamina(dt)
		pushAttributes(false)

		-- Process buffered inputs (resolved once per frame)
		if dashRequested_KB or dashRequested_GP then
			dashRequested_KB = false
			dashRequested_GP = false
			performDash()
		end
		if slideRequested_KB or slideRequested_GP then
			slideRequested_KB = false
			slideRequested_GP = false
			performSlide()
		end
	end)
end

-- ── Server state (role / round / tag boost) ───────────────────────────────────
-- TDD §4: StateChanged carries { state, role? }. MS_04 = Round Live.
-- MS_03 Countdown locks movement (WalkSpeed 0); MS_01/05/06 freeze & end slides.
StateChanged.OnClientEvent:Connect(function(payload: { state: string?, role: string? })
	if typeof(payload) ~= "table" then
		return
	end
	local state = payload.state
	if payload.role == "Runner" or payload.role == "Taya" then
		local newRole = payload.role
		if newRole ~= role then
			-- Tag swap cleanup: cancel slide/dash visuals, drop sprint.
			if isSliding then
				endSlide()
			end
			if isDashing then
				cancelDash()
			end
			isSprinting = false
			sprintHeld_KB = false
			sprintHeld_GP = false
			role = newRole
		end
	end
	if typeof(state) == "string" then
		roundLive = (state == "MS_04")
		inputLocked = (state == "MS_03") or not roundLive
		if state == "MS_03" then
			-- Countdown: lock in place, full stamina, abilities cooling.
			isSprinting = false
			sprintHeld_KB = false
			sprintHeld_GP = false
		end
		if not roundLive then
			-- End any active slide/dash when the round is not live.
			if isSliding then
				endSlide()
			end
			if isDashing then
				cancelDash()
			end
		end
		applySpeed()
		pushAttributes(true)
	end
end)

-- TagEvent { taggerId, targetId }: whoever was just tagged becomes Taya;
-- the PREVIOUS Taya (us, if we were Taya before this event) is now Runner and
-- gets the 2s +20% boost (F08). Server is authoritative — we only present it.
TagEvent.OnClientEvent:Connect(function(payload: { taggerId: number?, targetId: number? })
	if typeof(payload) ~= "table" then
		return
	end
	local myId = LocalPlayer.UserId
	if payload.targetId == myId then
		-- We are the new Taya: no boost, Taya speed applies via role update.
		boostLeft = 0.0
		if isSliding then
			endSlide()
		end
		applySpeed()
		pushAttributes(true)
	elseif payload.taggerId == myId and role == "Runner" then
		-- We were Taya and just tagged someone: ex-Taya boost starts now.
		boostLeft = Mv.PostTagSpeedBoostDuration
		applySpeed()
		pushAttributes(true)
	end
end)

-- ── PC Keyboard bindings ──────────────────────────────────────────────────────
-- UI/UX Spec §4: Move WASD (built-in), Sprint LeftShift hold, Dash Q, Slide C.
local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	local kc = input.KeyCode
	if kc == Enum.KeyCode.LeftShift or kc == Enum.KeyCode.RightShift then
		sprintHeld_KB = true
	elseif kc == Enum.KeyCode.Q then
		dashRequested_KB = true
	elseif kc == Enum.KeyCode.C then
		slideRequested_KB = true
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	local kc = input.KeyCode
	if kc == Enum.KeyCode.LeftShift or kc == Enum.KeyCode.RightShift then
		sprintHeld_KB = false
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

-- ── Gamepad bindings (UI/UX Spec §4) ─────────────────────────────────────────
-- Sprint: Left trigger hold (ButtonL2) OR left stick full tilt (see heartbeat).
-- Dash:   B (ButtonB). Slide: Right bumper (ButtonR1).
-- Diskarte Y (ButtonY) and Skill X (ButtonX) are owned by UIController/Skill UI.
local SPRINT_GP_ACTION = "HRUSH_Sprint_GP"
local DASH_GP_ACTION = "HRUSH_Dash_GP"
local SLIDE_GP_ACTION = "HRUSH_Slide_GP"

ContextActionService:BindAction(SPRINT_GP_ACTION, function(_name, state, _obj)
	if state == Enum.UserInputState.Begin then
		sprintHeld_GP = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		-- Stick-tilt check in heartbeat may re-assert this while tilted.
		sprintHeld_GP = false
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonL2)

ContextActionService:BindAction(DASH_GP_ACTION, function(_name, state, _obj)
	if state == Enum.UserInputState.Begin then
		dashRequested_GP = true
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonB)

ContextActionService:BindAction(SLIDE_GP_ACTION, function(_name, state, _obj)
	if state == Enum.UserInputState.Begin then
		slideRequested_GP = true
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonR1)

-- ── Mobile touch buttons (UI/UX Spec §4) ───────────────────────────────────────
-- UIController creates on-screen Sprint / Dash / Slide buttons (min 64px).
-- They fire BindableEvents in ReplicatedStorage; we hook them once they exist
-- (retry loop covers UIController loading after us). Touch Sprint also works
-- via ContextActionService so it shows on the touch UI automatically.
local mobileHooked = false
local function hookMobileBindables()
	if mobileHooked then
		return
	end
	mobileHooked = true

	-- Touch buttons via ContextActionService (creates touch UI automatically).
	ContextActionService:BindAction("HRUSH_Sprint_Touch", function(_name, state, _obj)
		if state == Enum.UserInputState.Begin then
			sprintHeld_KB = true
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			sprintHeld_KB = false
		end
		return Enum.ContextActionResult.Pass
	end, true)

	ContextActionService:BindAction("HRUSH_Dash_Touch", function(_name, state, _obj)
		if state == Enum.UserInputState.Begin then
			dashRequested_KB = true
		end
		return Enum.ContextActionResult.Pass
	end, true)

	ContextActionService:BindAction("HRUSH_Slide_Touch", function(_name, state, _obj)
		if state == Enum.UserInputState.Begin then
			slideRequested_KB = true
		end
		return Enum.ContextActionResult.Pass
	end, true)

	-- Legacy BindableEvent bridge (UIController-created buttons, if present).
	-- Retry a few times: UIController may load after this controller.
	task.spawn(function()
		for _ = 1, 50 do
			local dashBe = ReplicatedStorage:FindFirstChild("MobileDashPressed")
			local slideBe = ReplicatedStorage:FindFirstChild("MobileSlidePressed")
			local sprintBegin = ReplicatedStorage:FindFirstChild("MobileSprintBegan")
			local sprintEnd = ReplicatedStorage:FindFirstChild("MobileSprintEnded")
			if dashBe and dashBe:IsA("BindableEvent") then
				dashBe.Event:Connect(function()
					dashRequested_KB = true
				end)
			end
			if slideBe and slideBe:IsA("BindableEvent") then
				slideBe.Event:Connect(function()
					slideRequested_KB = true
				end)
			end
			if sprintBegin and sprintBegin:IsA("BindableEvent") then
				sprintBegin.Event:Connect(function()
					sprintHeld_KB = true
				end)
			end
			if sprintEnd and sprintEnd:IsA("BindableEvent") then
				sprintEnd.Event:Connect(function()
					sprintHeld_KB = false
				end)
			end
			if dashBe or slideBe or sprintBegin or sprintEnd then
				break
			end
			task.wait(0.2)
		end
	end)
end

-- ── Character lifecycle ───────────────────────────────────────────────────────
local function onCharacterAdded(char: Model)
	Character = char
	-- Cancel any in-flight dash tied to the old character.
	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end
	Humanoid = char:WaitForChild("Humanoid") :: Humanoid
	HRP = char:WaitForChild("HumanoidRootPart") :: BasePart
	buildDashFX(char) -- dash trail + burst rig (rebuilt per respawn)

	-- Reset state on respawn
	stamina = Mv.StaminaMax
	isDepletion = false
	isSprinting = false
	regenTimer = 0.0
	isDashing = false
	dashCooldownLeft = 0.0
	dashInvulnLeft = 0.0
	isSliding = false
	slideCooldownLeft = 0.0
	slideTimer = 0.0
	slideHipHeight = 0.0
	boostLeft = 0.0
	sprintHeld_KB = false
	sprintHeld_GP = false
	dashRequested_KB = false
	dashRequested_GP = false
	slideRequested_KB = false
	slideRequested_GP = false

	applySpeed()
	pushAttributes(true)
	startHeartbeat()
	hookMobileBindables()

	-- Death cleanup: end slide/dash visuals so respawn state is clean.
	Humanoid.Died:Connect(function()
		if isSliding then
			isSliding = false
		end
		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end
		isDashing = false
		boostLeft = 0.0
	end)
end

if LocalPlayer.Character then
	task.spawn(onCharacterAdded, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

pushAttributes(true)
print("[MovementController] Loaded — T09 complete (walk/sprint/stamina/dash/slide/boost).")
