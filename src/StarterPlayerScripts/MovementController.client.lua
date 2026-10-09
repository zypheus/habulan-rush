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
--   • Bindings (UI/UX Spec §4): PC Shift/Q/C/E · Gamepad L2-stick/B/R1/X · Touch
--   • Dash VFX: rear Trail ribbon + particle burst on Q (Config.Movement.DashVFX)
--   • UI bridge: HRush* attributes on LocalPlayer (UIController reads poll-free)
--   • Skill RS_01 Luksong Baka (T18 slice): request + facing to SkillService,
--     server validates (round/stun/ground/airborne/CD) and broadcasts SkillEvent,
--     caster runs windup (0.1s crouch) -> takeoff (single impulse, CD starts)
--     -> locked-direction flight -> landing recovery (0.2s no sprint).
--     Grant list: Config.Skills.testGrant, role gate via Config.Debug flag.
--
-- Does NOT handle: tag detection/validation (TagService owns truth),
-- skill draft/unlocks (T17), remaining skills (RS_02/03, TS_*) and Diskarte
-- (T18/T19), timers/scores (MatchService), or lock camera.
--
-- All numeric constants come exclusively from Config.Movement — zero hardcoding.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
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
local RequestSkill = Remotes:WaitForChild("RequestSkill") :: RemoteEvent
local SkillEvent = Remotes:WaitForChild("SkillEvent") :: RemoteEvent
local SkillApproved = Remotes:WaitForChild("SkillApproved") :: RemoteEvent
local SkillVFX = Remotes:WaitForChild("SkillVFX") :: RemoteEvent
local SkillLanded = Remotes:WaitForChild("SkillLanded") :: RemoteEvent

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

-- Skill (RS_01; server validates, SkillApproved moves the owning client only)
local skillId = "" -- skill granted to the current role ("" = none)
local skillCooldownLeft = 0.0
local skillFlightLeft = 0.0 -- air time left after takeoff (ballistic window)
local skillRequested = false -- buffered E / ButtonX / touch press
local skillPending = false -- request sent, waiting for the server reply
local skillPendingLeft = 0.0 -- clears a lost reply so input cannot wedge
local skillWindupLeft = 0.0 -- crouch countdown before takeoff (s)
local skillRecoveryLeft = 0.0 -- sprint lockout after landing (s)
local skillCastDir = Vector3.new(0, 0, -1) -- heading fixed by the approved event
local skillCastHip = 0.0 -- HipHeight saved for the crouch restore
local skillWallConn: RBXScriptConnection? = nil -- wall hit ends the jump
local skillFOVOn = false -- owner FOV kick active (restore on landing)
local skillPreviewRing: BasePart? = nil -- owner-only landing preview
-- Leap (Stage B): queued takeoff, flight measurement, wall/landing detection.
local skillPendingVelocity: Vector3? = nil -- set on ChangeState, applied next Heartbeat
local skillFwdSpeed = 0.0 -- locked horizontal launch speed (steering lock + wall check)
local skillFlightStartedAt = 0.0 -- os.clock() at takeoff (min-airtime gate)
local skillWallSlowLeft = 0.0 -- seconds spent below the wall slow threshold
local skillTakeoffPos: Vector3? = nil -- takeoff position for measured distance
local skillPeakY = 0.0 -- highest root Y seen during flight (measured height)
local skillApprovedActive = false -- true from SkillApproved until SkillLanded sent
local skillDebugTick = 0.0 -- throttles the debug label text update
local skillDebugLabel: BillboardGui? = nil -- airborne debug label (ShowSkillDebug)
local skillStateConn: RBXScriptConnection? = nil -- Humanoid.StateChanged landing hook

-- TODO: remove before submission (debug prints for RS_01 testing)
local function debugPrint(msg: string)
	if Config.Debug.ShowSkillDebug then
		print("[RS_01] " .. msg)
	end
end

-- Character mass summed from parts: used in the launch debug print and to
-- document the impulse math (velocity-set method does not need it).
local function characterMass(): number
	local mass = 0
	if Character then
		for _, d in Character:GetDescendants() do
			if d:IsA("BasePart") then
				mass += d.Mass
			end
		end
	end
	return mass
end

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
	if skillFlightLeft > 0 or skillWindupLeft > 0 then
		-- Windup: hold still while crouched on the ground. During FLIGHT we do
		-- NOT zero WalkSpeed (it fights the launch); direction is locked by
		-- re-applying the takeoff velocity each Heartbeat instead.
		if skillWindupLeft > 0 then
			Humanoid.WalkSpeed = 0
			return
		end
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

	-- Decide if we're actually sprinting this frame.
	-- Landing recovery (RS_01) keeps sprint off briefly without blocking walk.
	local wantSprint = sprintKeyHeld and isMoving and not isSliding and not isDashing
		and skillRecoveryLeft <= 0
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
--   HRushRole ("Runner" | "Taya") — UI gates Runner-only HUD (stamina bar),
--   HRushSkillId (granted skill id, "" = none), HRushSkillCD (seconds left).
-- Grant lookup (TEMP list until T17 draft owns unlocks). The role check stays
-- but is skipped while Config.Debug.AllowAnyRoleForSkills is on, so any role
-- can test skills; flip the flag off to restore the Runner-only rule.
local function grantedSkillId(): string
	if role ~= "Runner" and not Config.Debug.AllowAnyRoleForSkills then
		return ""
	end
	for _, id in Config.Skills.testGrant do
		local sk = Config.Skills[id]
		if sk and (Config.Debug.AllowAnyRoleForSkills or sk.role == role) then
			return id
		end
	end
	return ""
end

-- Params of the currently granted skill (nil when nothing is granted).
local function skillParams(): any?
	if skillId == "" then
		skillId = grantedSkillId()
	end
	local sk = Config.Skills[skillId]
	if sk then
		return sk.params
	end
	return nil
end

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
	skillId = grantedSkillId()
	LocalPlayer:SetAttribute("HRushSkillId", skillId)
	LocalPlayer:SetAttribute("HRushSkillCD", skillCooldownLeft)
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

-- ── Skill: RS_01 Luksong Baka (T18 vertical slice) ───────────────────────────
-- Spec section 5: height 14, distance 18, NO air steering, 12s cooldown,
-- 0.1s windup crouch, 0.2s landing recovery, untouchable above 6 studs.
-- Ballistics derive from Config + engine gravity so the numbers stay tunable.
-- Flow: client sends request + facing -> SkillService validates -> broadcast
-- SkillEvent -> caster runs windup/launch, every client plays the VFX.
-- Cast is ground-only (v1 assumption: air-cast is a T18 balance question).
-- Camera feel (owner only): FOV kick at takeoff, eased back on landing, tiny
-- shake after touchdown. The shake never adds vertical motion, so the camera
-- can never snap upward (spec rule).
local skillFOVBase: number? = nil
local SHAKE_BIND = "HRUSH_SkillShake"

local function startSkillFOV()
	local cam = Workspace.CurrentCamera
	local p = skillParams()
	if cam == nil or p == nil then
		return
	end
	skillFOVBase = cam.FieldOfView
	skillFOVOn = true
	-- fovTime lives in the vfx table (the Stage A crash was reading it from
	-- params; always take the tween seconds from vfx like stopSkillFOV does).
	local fx = Config.Skills.RS_01.vfx
	TweenService:Create(
		cam,
		TweenInfo.new(fx.fovTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = skillFOVBase + p.fovBoost }
	):Play()
end

local function stopSkillFOV(withShake: boolean)
	local cam = Workspace.CurrentCamera
	local p = skillParams()
	skillFOVOn = false
	if cam ~= nil and skillFOVBase ~= nil and p ~= nil then
		TweenService:Create(
			cam,
			TweenInfo.new(p.fovBackTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ FieldOfView = skillFOVBase }
		):Play()
	end
	skillFOVBase = nil
	if not withShake or cam == nil or p == nil then
		return
	end
	local duration = p.shakeDuration
	local amp = Config.Skills.RS_01.vfx.shakeAmp
	local endTime = os.clock() + duration
	RunService:BindToRenderStep(SHAKE_BIND, Enum.RenderPriority.Camera.Value + 1, function()
		local left = endTime - os.clock()
		if left <= 0 then
			RunService:UnbindFromRenderStep(SHAKE_BIND)
			return
		end
		-- Horizontal jitter plus tiny roll, decaying to rest. Vertical offset
		-- is deliberately zero so the camera never moves sharply upward.
		local k = (left / duration) * amp
		cam.CFrame = cam.CFrame
			* CFrame.Angles(
				(math.random() - 0.5) * k * 0.05,
				(math.random() - 0.5) * k * 0.05,
				(math.random() - 0.5) * k * 0.08
			)
			* CFrame.new((math.random() - 0.5) * k, 0, (math.random() - 0.5) * k)
	end)
end

local function cancelWindup()
	if skillWindupLeft > 0 and Humanoid then
		Humanoid.HipHeight = skillCastHip -- undo the crouch before anything else
	end
	skillWindupLeft = 0
end

-- Tell the server the jump is over: clears IsAirborne (tag immunity + re-cast
-- gate). One shot per approval, safe to call from every end path.
local function reportLanded()
	if skillApprovedActive then
		skillApprovedActive = false
		SkillLanded:FireServer(skillId)
		debugPrint("landing reported to server (SkillLanded)") -- TODO: remove before submission
	end
end

local function endSkillFlight(withShake: boolean?)
	reportLanded() -- clear server IsAirborne before local cleanup
	skillFlightLeft = 0
	skillPendingVelocity = nil -- a queued launch must not fire after cleanup
	skillFwdSpeed = 0.0
	skillFlightStartedAt = 0.0
	skillWallSlowLeft = 0.0
	skillTakeoffPos = nil
	cancelWindup() -- never leave a crouch behind on cancel paths
	if skillPreviewRing then
		skillPreviewRing:Destroy()
		skillPreviewRing = nil
	end
	if skillFOVOn then
		stopSkillFOV(withShake == true)
	end
	-- Landing recovery keeps sprint off for a short beat (Config: landingRecovery).
	local sk = Config.Skills[skillId]
	if sk then
		skillRecoveryLeft = sk.params.landingRecovery
	end
	applySpeed() -- restores walk/sprint (or 0 when inputLocked)
	pushAttributes(true)
end

-- One dust puff burst at the character (windup or landing). Uses the engine
-- builtin sparkle texture, so no Toolbox asset and no license risk.
local function emitBurst(hrp: BasePart, count: number)
	local fx = Config.Skills.RS_01.vfx
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, -2, 0) -- near the feet where dust kicks up
	att.Parent = hrp
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0 -- burst only, never a stream (mobile particle budget)
	emitter.Lifetime = NumberRange.new(fx.dustLifeMin, fx.dustLifeMax)
	emitter.Speed = NumberRange.new(fx.dustSpeedMin, fx.dustSpeedMax)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -12, 0) -- dust settles, it does not float
	emitter.Color = ColorSequence.new(Color3.fromRGB(214, 200, 176))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, fx.dustSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = att
	emitter:Emit(count)
	Debris:AddItem(att, 1.2) -- cleanup margin only, not a gameplay number
end

-- Flat neon ring on the ground: grows and fades with TweenService (spec asked
-- for a tweened cylinder instead of more particles, so mobile stays cheap).
local function spawnGroundRing(at: Vector3, sizeA: number, sizeB: number, duration: number, exclude: Model?)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { Character }
	if exclude then
		table.insert(skip, exclude)
	end
	ray.FilterDescendantsInstances = skip
	ray.IgnoreWater = true
	local hit = Workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -80, 0), ray)
	local y = if hit then hit.Position.Y + 0.1 else at.Y - 2.9
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.25, sizeA, sizeA)
	ring.CFrame = CFrame.new(at.X, y, at.Z) * CFrame.Angles(0, 0, math.rad(90)) -- lie flat
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(226, 214, 190)
	ring.Transparency = 0.3
	ring.Parent = Workspace
	TweenService:Create(
		ring,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.25, sizeB, sizeB), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, duration + 0.2)
end

-- Owner-only landing preview: a soft ring where the arc will end. Parts made
-- by this client never replicate, so other players cannot see it.
local function spawnLandingPreview(at: Vector3, size: number, dir: Vector3, distance: number)
	local predicted = at + Vector3.new(dir.X, 0, dir.Z) * distance
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { Character }
	ray.IgnoreWater = true
	local hit = Workspace:Raycast(predicted + Vector3.new(0, 2, 0), Vector3.new(0, -80, 0), ray)
	local y = if hit then hit.Position.Y + 0.12 else predicted.Y - 2.9
	local ring = Instance.new("Part")
	ring.Name = "SkillPreviewRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, size, size)
	ring.CFrame = CFrame.new(predicted.X, y, predicted.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(140, 220, 255)
	ring.Transparency = 0.55
	ring.Parent = Workspace
	return ring
end

-- Air trail: attachments sit on HumanoidRootPart because it exists on every
-- rig (R6 and R15) at torso height, unlike torso parts which differ per rig.
local function startAirTrail(hrp: BasePart, lifetime: number)
	if hrp:FindFirstChild("SkillTrail") then
		return -- duplicate broadcast must not double the trail
	end
	local attA = Instance.new("Attachment")
	attA.Name = "SkillTrailA"
	attA.Position = Vector3.new(-0.7, 0.4, 0.6) -- rear edge of the torso block
	attA.Parent = hrp
	local attB = Instance.new("Attachment")
	attB.Name = "SkillTrailB"
	attB.Position = Vector3.new(0.7, 0.4, 0.6)
	attB.Parent = hrp
	local trail = Instance.new("Trail")
	trail.Name = "SkillTrail"
	trail.Attachment0 = attA
	trail.Attachment1 = attB
	trail.FaceCamera = true
	trail.Lifetime = lifetime
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 244, 214))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Enabled = true
	trail.Parent = hrp
end

local function stopAirTrail(hrp: BasePart)
	local trail = hrp:FindFirstChild("SkillTrail")
	if trail and trail:IsA("Trail") then
		trail.Enabled = false -- remaining segments fade out over Lifetime
		Debris:AddItem(trail, 1.0) -- cleanup margin only
	end
	for _, name in { "SkillTrailA", "SkillTrailB" } do
		local att = hrp:FindFirstChild(name)
		if att then
			Debris:AddItem(att, 1.0)
		end
	end
end

-- Sound hook: an empty id in Config is skipped, so the game stays silent but
-- the hook is ready until licensed audio lands (ASSET_LOG rule).
local function playSkillSound(hrp: BasePart, soundId: unknown)
	if typeof(soundId) ~= "string" or soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.RollOffMaxDistance = 60
	sound.Parent = hrp
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- Shared cast timeline: runs on EVERY client from the server SkillEvent, so
-- windup puff, takeoff ring, air trail and landing burst match for all viewers.
-- Delays come from Config, so clients agree without extra messages. An early
-- wall landing can drift remote FX by a few frames; that part is cosmetic.
local function playSkillCastFX(casterId: number, sid: string, dir: Vector3)
	local sk = Config.Skills[sid]
	if sk == nil then
		return
	end
	local caster = Players:GetPlayerByUserId(casterId)
	local char = caster and caster.Character
	if char == nil then
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return
	end
	local isOwner = casterId == LocalPlayer.UserId

	task.delay(0, function()
		if not hrp.Parent then
			return
		end
		emitBurst(hrp, sk.vfx.windupCount) -- windup dust puff
		playSkillSound(hrp, sk.sounds.windup)
	end)

	task.delay(sk.params.windup, function()
		if not hrp.Parent then
			return
		end
		spawnGroundRing(hrp.Position, sk.vfx.ringStart, sk.vfx.ringEnd, sk.vfx.ringTime, char)
		startAirTrail(hrp, sk.vfx.trailLifetime)
		playSkillSound(hrp, sk.sounds.takeoff)
		if isOwner then
			skillPreviewRing = spawnLandingPreview(hrp.Position, sk.vfx.previewSize, dir, sk.params.distance)
		end
	end)

	task.delay(sk.params.windup + sk.params.airtime, function()
		if not hrp.Parent then
			return
		end
		stopAirTrail(hrp)
		emitBurst(hrp, sk.vfx.landingCount) -- landing dust burst
		spawnGroundRing(hrp.Position, sk.vfx.previewSize, sk.vfx.previewSize * 1.8, sk.vfx.landingRingTime, char)
		playSkillSound(hrp, sk.sounds.landing)
		if isOwner and skillPreviewRing then
			skillPreviewRing:Destroy()
			skillPreviewRing = nil
		end
	end)
end

local function launchSkill()
	local sk = Config.Skills[skillId]
	if sk == nil or not Humanoid or not HRP then
		cancelWindup()
		return
	end
	if skillCastHip > 0 then
		Humanoid.HipHeight = skillCastHip -- stand up from the crouch
	end
	-- Ballistics only from Config and engine gravity: with airtime t,
	-- vy = g*t/2 reaches the configured height and vh = distance/t the reach.
	-- Measured at g=196.2, t=0.76: vy ~74.6 (spec 74), vh ~23.7 (spec 24),
	-- apex ~14.1 (spec 14), range 18.0 (spec 18): all within 10 percent.
	local g = Workspace.Gravity
	local vy = g * sk.params.airtime / 2
	local vh = sk.params.distance / sk.params.airtime

	-- Heading: frozen from the approved direction when lockDirection.
	local dir = skillCastDir
	if not sk.params.lockDirection then
		local look = HRP.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.01 then
			dir = flat.Unit
		end
	end
	skillCastDir = dir
	skillFwdSpeed = vh
	skillWallSlowLeft = 0

	-- Spec architecture: leave the Running state FIRST with ChangeState, then
	-- apply the velocity on the NEXT heartbeat. Writing velocity while still
	-- grounded lets the humanoid snap the character back to the floor (the
	-- Stage A class of "crouch but no leap" bugs).
	Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	skillPendingVelocity = Vector3.new(dir.X * vh, vy, dir.Z * vh)
	debugPrint(string.format("takeoff queued: ChangeState(Jumping), vel next heartbeat (up=%.1f fwd=%.1f)", vy, vh)) -- TODO: remove before submission
end

local function requestSkill()
	if not roundLive or inputLocked then
		return -- round gate (countdown, lobby, round end)
	end
	if skillPending or skillApprovedActive or skillPendingVelocity ~= nil then
		return -- one cast in flight at a time (covers the windup->takeoff gap)
	end
	if skillWindupLeft > 0 or skillFlightLeft > 0 then
		return -- already jumping
	end
	if skillCooldownLeft > 0 then
		return
	end
	if isDashing or isSliding then
		return
	end
	if not Humanoid or not HRP then
		return
	end
	if Humanoid.Health <= 0 then
		return
	end
	if Humanoid.FloorMaterial == Enum.Material.Air then
		return -- ground cast only (v1)
	end
	if skillId == "" then
		skillId = grantedSkillId()
	end
	local p = skillParams()
	if p == nil then
		return -- no grant for this role (role check lives in grantedSkillId)
	end

	-- The approved direction is what the jump uses (lockDirection).
	local dir = HRP.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return
	end

	skillCastDir = dir.Unit
	skillPending = true
	skillPendingLeft = p.pendingTimeout -- a lost reply must not wedge input
	RequestSkill:FireServer(skillId, skillCastDir)
	debugPrint("request sent to server (" .. skillId .. ")") -- TODO: remove before submission
end


-- Deny only: quiet reset of the pending flag (the server already said no and
-- the local cooldown never started).
SkillEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.type == "deny" then
		if payload.skillId == skillId then
			skillPending = false
			debugPrint("denied by server (pending cleared)") -- TODO: remove before submission
		end
		return
	end
end)

-- Approval goes ONLY to the requesting client (spec architecture): this is
-- what starts the windup. Movement is applied later by launchSkill on this
-- same owning client; no other client runs mechanics from this event.
SkillApproved.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.skillId) ~= "string" or payload.skillId ~= skillId then
		return
	end
	if not (Humanoid and HRP) then
		return
	end
	skillPending = false
	skillApprovedActive = true
	if typeof(payload.dir) == "Vector3" and payload.dir.Magnitude > 0.01 then
		skillCastDir = Vector3.new(payload.dir.X, 0, payload.dir.Z).Unit
	end
	local p: any? = if typeof(payload.params) == "table" then payload.params else skillParams()
	if p == nil then
		return
	end
	-- Windup: crouch in place. tickCooldowns launches when the timer hits
	-- zero, and the cooldown starts at that takeoff moment (spec).
	skillCastHip = Humanoid.HipHeight
	Humanoid.HipHeight = skillCastHip * p.crouchScale
	skillWindupLeft = p.windup
	applySpeed() -- windup guard immediately locks WalkSpeed at 0
	pushAttributes(true)
	debugPrint(string.format("SkillApproved received: windup=%.2fs dir=(%.2f, %.2f)", p.windup, skillCastDir.X, skillCastDir.Z)) -- TODO: remove before submission
end)

-- VFX goes to ALL players (spec): visuals only, never mechanics.
SkillVFX.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.skillId) ~= "string" or typeof(payload.caster) ~= "number" then
		return
	end
	local dir = if typeof(payload.dir) == "Vector3" then payload.dir else Vector3.new(0, 0, -1)
	playSkillCastFX(payload.caster, payload.skillId, dir)
end)

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
	if skillCooldownLeft > 0 then
		skillCooldownLeft = math.max(0, skillCooldownLeft - dt)
	end
	if skillWindupLeft > 0 then
		-- Crouch countdown; the launch happens once it reaches zero.
		skillWindupLeft = math.max(0, skillWindupLeft - dt)
		if skillWindupLeft <= 0 then
			launchSkill()
		end
	end
	if skillFlightLeft > 0 then
		-- Flight window countdown. Real landings are caught by the Humanoid
		-- StateChanged hook (Landed/Running + min airtime) in onCharacterAdded;
		-- this timeout is the fallback if that signal never arrives (spec).
		skillFlightLeft = math.max(0, skillFlightLeft - dt)
		if skillFlightLeft <= 0 then
			debugPrint("flight timeout fallback: ending jump") -- TODO: remove before submission
			endSkillFlight(false)
		end
	end
	if skillRecoveryLeft > 0 then
		skillRecoveryLeft = math.max(0, skillRecoveryLeft - dt)
	end
	if skillPending then
		skillPendingLeft = math.max(0, skillPendingLeft - dt)
		if skillPendingLeft <= 0 then
			skillPending = false -- a lost server reply must never wedge input
		end
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

		-- Takeoff: ChangeState happened in launchSkill; the velocity is applied
		-- HERE, on the next heartbeat, so the humanoid cannot snap back down.
		-- This is the single place the leap impulse is written (spec).
		if skillPendingVelocity then
			local v = skillPendingVelocity
			skillPendingVelocity = nil
			HRP.AssemblyLinearVelocity = v -- one impulse, never per-frame
			skillFlightStartedAt = os.clock()
			skillTakeoffPos = HRP.Position
			skillPeakY = HRP.Position.Y
			local sk = Config.Skills[skillId]
			if sk then
				skillCooldownLeft = sk.cooldown -- CD starts at takeoff (spec)
				skillFlightLeft = sk.params.airtime + sk.params.flightSlack
			end
			startSkillFOV() -- camera AFTER the physics write: cosmetics can never kill the leap
			pushAttributes(true)
			debugPrint(string.format(
				"launch applied: up=%.1f fwd=%.1f mass=%.1f",
				v.Y, skillFwdSpeed, characterMass()
			)) -- TODO: remove before submission
			-- Fallback cleanup: even if landing detection fails, the flight
			-- window cannot stay open past airtime + 1s (spec).
			task.delay((sk and sk.params.airtime or 0.76) + 1, function()
				if skillFlightLeft > 0 then
					debugPrint("cleanup fallback fired (airtime + 1s)") -- TODO: remove before submission
					endSkillFlight(false)
				end
			end)
		end

		-- Flight frame: track peak, enforce locked direction (no air steering),
		-- and end the jump early if a wall crushes horizontal speed below
		-- wallSpeedPct of launch speed for wallSlowTime seconds (spec).
		if skillFlightLeft > 0 then
			if HRP.Position.Y > skillPeakY then
				skillPeakY = HRP.Position.Y
			end
			local p = skillParams()
			local vel = HRP.AssemblyLinearVelocity
			local hSpeed = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
			if p and skillFwdSpeed > 0 then
				if hSpeed < skillFwdSpeed * p.wallSpeedPct then
					skillWallSlowLeft += dt
					if skillWallSlowLeft >= p.wallSlowTime then
						debugPrint(string.format(
							"wall hit: hSpeed %.1f < %.1f%% of %.1f for %.2fs, ending jump",
							hSpeed, p.wallSpeedPct * 100, skillFwdSpeed, p.wallSlowTime
						)) -- TODO: remove before submission
						endSkillFlight(false) -- wall ends the jump, airborne state cleared
						skillWallSlowLeft = 0
					end
				else
					skillWallSlowLeft = 0
				end
				-- Direction lock: re-apply ONLY the locked horizontal velocity;
				-- vertical stays physics driven (spec: no WalkSpeed tricks).
				HRP.AssemblyLinearVelocity = Vector3.new(
					skillCastDir.X * skillFwdSpeed,
					vel.Y,
					skillCastDir.Z * skillFwdSpeed
				)
			end
		end

		-- Debug label (ShowSkillDebug): refresh 10x per second, not per frame.
		if Config.Debug.ShowSkillDebug and skillDebugLabel then
			skillDebugTick += dt
			if skillDebugTick >= 0.1 then
				skillDebugTick = 0
				local txt = skillDebugLabel:FindFirstChild("DebugText")
				if txt and txt:IsA("TextLabel") then
					local ray = RaycastParams.new()
					ray.FilterType = Enum.RaycastFilterType.Exclude
					ray.FilterDescendantsInstances = { Character }
					ray.IgnoreWater = true
					local hit = Workspace:Raycast(HRP.Position, Vector3.new(0, -200, 0), ray)
					local height = if hit then (HRP.Position.Y - hit.Position.Y) else 0
					local vel = HRP.AssemblyLinearVelocity
					local hSpeed = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
					txt.Text = string.format(
						"IsAirborne: %s\nHeight: %.1f  HSpeed: %.1f",
						tostring(skillFlightLeft > 0),
						height,
						hSpeed
					)
				end
			end
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
		if skillRequested then
			skillRequested = false
			requestSkill()
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
			-- End any active slide/dash/skill-flight when the round is not live.
			if isSliding then
				endSlide()
			end
			if isDashing then
				cancelDash()
			end
			if skillFlightLeft > 0 then
				endSkillFlight(false)
			end
			cancelWindup()
			skillPendingVelocity = nil -- a queued takeoff must not fire after round end
			reportLanded() -- windup cancelled mid-approval: still clear IsAirborne
			skillPending = false -- round over: drop any request still in flight
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
	elseif kc == Enum.KeyCode.E then
		skillRequested = true -- Skill cast (UI/UX Spec §4)
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
-- Dash:   B (ButtonB). Slide: Right bumper (ButtonR1). Skill: X (ButtonX).
-- Diskarte Y (ButtonY) is owned by UIController (T22).
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

local SKILL_GP_ACTION = "HRUSH_Skill_GP"
ContextActionService:BindAction(SKILL_GP_ACTION, function(_name, state, _obj)
	if state == Enum.UserInputState.Begin then
		skillRequested = true
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonX)

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

	ContextActionService:BindAction("HRUSH_Skill_Touch", function(_name, state, _obj)
		if state == Enum.UserInputState.Begin then
			skillRequested = true
		end
		return Enum.ContextActionResult.Pass
	end, true)

	-- Legacy BindableEvent bridge (UIController-created buttons, if present).
	-- Retry a few times: UIController may load after this controller.
	task.spawn(function()
		for _ = 1, 50 do
			local dashBe = ReplicatedStorage:FindFirstChild("MobileDashPressed")
			local slideBe = ReplicatedStorage:FindFirstChild("MobileSlidePressed")
			local skillBe = ReplicatedStorage:FindFirstChild("MobileSkillPressed")
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
			if skillBe and skillBe:IsA("BindableEvent") then
				skillBe.Event:Connect(function()
					skillRequested = true
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
			if dashBe or slideBe or skillBe or sprintBegin or sprintEnd then
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
	skillCooldownLeft = 0
	skillFlightLeft = 0
	skillRequested = false
	skillPending = false
	skillWindupLeft = 0
	skillRecoveryLeft = 0
	skillPendingVelocity = nil -- a queued takeoff belongs to the old character
	skillFwdSpeed = 0.0
	skillFlightStartedAt = 0.0
	skillWallSlowLeft = 0.0
	skillTakeoffPos = nil
	skillPeakY = 0.0
	skillApprovedActive = false -- respawn drops any prior approval
	skillFOVOn = false
	if skillPreviewRing then
		skillPreviewRing:Destroy()
		skillPreviewRing = nil
	end

	-- Landing detection (spec): StateChanged to Landed/Running plus a minimum
	-- airtime, so the launch frame itself can never count as a landing.
	-- StateChanged IS a confirmed Humanoid event (checked against the engine
	-- API dump; the invalid ones were Landed and GetStateChangedSignal).
	if skillStateConn then
		skillStateConn:Disconnect()
		skillStateConn = nil
	end
	skillStateConn = Humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if skillFlightLeft <= 0 or skillFlightStartedAt == 0 then
			return -- not flying: normal ground states, ignore
		end
		local p = skillParams()
		local minAir = if p then p.minAirtime else 0.2
		if os.clock() - skillFlightStartedAt < minAir then
			return -- launch frames still touching ground: not a landing yet
		end
		if new ~= Enum.HumanoidStateType.Landed and new ~= Enum.HumanoidStateType.Running then
			return
		end
		-- Measured values vs Config targets (ShowSkillDebug).
		if Config.Debug.ShowSkillDebug and skillTakeoffPos then
			-- TODO: remove before submission
			local pos = HRP.Position
			local measuredH = skillPeakY - skillTakeoffPos.Y
			local measuredD = Vector3.new(pos.X - skillTakeoffPos.X, 0, pos.Z - skillTakeoffPos.Z).Magnitude
			local targetH = if p then p.height else 14
			local targetD = if p then p.distance else 18
			debugPrint(string.format(
				"landing detected: height %.1f (target %.0f, %+.0f%%), distance %.1f (target %.0f, %+.0f%%)",
				measuredH, targetH, (measuredH - targetH) / targetH * 100,
				measuredD, targetD, (measuredD - targetD) / targetD * 100
			)) -- TODO: remove before submission
		end
		endSkillFlight(true) -- real touchdown: shake + recovery + SkillLanded
	end)

	-- Debug label above the player (spec, ShowSkillDebug only).
	if skillDebugLabel then
		skillDebugLabel:Destroy()
		skillDebugLabel = nil
	end
	if Config.Debug.ShowSkillDebug then
		-- TODO: remove before submission
		local bb = Instance.new("BillboardGui")
		bb.Name = "SkillDebugLabel"
		bb.Size = UDim2.fromOffset(180, 56)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.AlwaysOnTop = true
		local txt = Instance.new("TextLabel")
		txt.Name = "DebugText"
		txt.Size = UDim2.fromScale(1, 1)
		txt.BackgroundColor3 = Color3.new(0, 0, 0)
		txt.BackgroundTransparency = 0.4
		txt.TextColor3 = Color3.fromRGB(255, 255, 120)
		txt.Font = Enum.Font.Code
		txt.TextSize = 12
		txt.TextWrapped = true
		txt.Text = "IsAirborne: false"
		txt.Parent = bb
		bb.Parent = HRP
		skillDebugLabel = bb
	end

	-- Wall contact mid-air ends the jump at once (spec: never clip through
	-- cover). Anchored world geometry only; floors are skipped by normal.y.
	if skillWallConn then
		skillWallConn:Disconnect()
		skillWallConn = nil
	end
	skillWallConn = HRP.Touched:Connect(function(hit: BasePart)
		if skillFlightLeft <= 0 then
			return
		end
		if not hit.Anchored then
			return -- other players and debris are not walls
		end
		-- Check if contact is vertical (floor or ceiling) rather than a wall
		local deltaY = hit.Position.Y - HRP.Position.Y
		if math.abs(deltaY) > (hit.Size.Y * 0.5 + 1.0) then
			return -- floor and ceiling contacts are normal landings
		end
		local castDir = (hit.Position - HRP.Position)
		if castDir.Magnitude > 0.1 then
			local ray = Workspace:Raycast(HRP.Position, castDir.Unit * (castDir.Magnitude + 2))
			if ray and math.abs(ray.Normal.Y) > 0.5 then
				return -- floor and ceiling contacts are normal landings
			end
		end
		local vel = HRP.AssemblyLinearVelocity
		HRP.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0) -- kill horizontal push
		endSkillFlight(false)
	end)

	applySpeed()
	pushAttributes(true)
	startHeartbeat()
	hookMobileBindables()

	-- Death cleanup: end slide/dash/skill visuals so respawn state is clean.
	Humanoid.Died:Connect(function()
		if isSliding then
			isSliding = false
		end
		skillFlightLeft = 0 -- a flight cannot outlive its character
		skillPendingVelocity = nil
		skillWindupLeft = 0
		skillRecoveryLeft = 0
		skillPending = false
		skillFOVOn = false
		reportLanded() -- death mid-jump still clears server IsAirborne
		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end
		isDashing = false
		boostLeft = 0.0
	end)

	-- Diagnostic marker: if this line is missing from the log, onCharacterAdded
	-- aborted before finishing (check CreatorError above it).
	print("[MovementController] character attached — heartbeat + input hooks live")
end

if LocalPlayer.Character then
	task.spawn(onCharacterAdded, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

pushAttributes(true)
print("[MovementController] Loaded — T09 + RS_01 slice (walk/sprint/stamina/dash/slide/boost/skill).")
