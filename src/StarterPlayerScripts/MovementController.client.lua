--!strict
-- Task/spec: Agawan ng Panyo compatible skill presentation, approved 2026-10-23.
-- StarterPlayerScripts/MovementController.client.lua
-- Owner: Project Owner
-- Responsibility: client input, predicted movement, animation, and presentation.
-- Task/spec: simple click-to-tag integration, approved 2026-10-18.
-- Task/spec: movement upgrade Part 2 landing owner and chest-level Vault, approved 2026-10-16.
-- Task/spec: momentum steps 2 to 4, 2026-10-19.
-- Task/spec: slide chaining and entry speed, 2026-10-19.
-- Task/spec: source-owned wind dash VFX and accepted-dash observer presentation, 2026-10-22.
-- Task/spec: local-only confirmed TAG sound ownership, approved 2026-10-24.
-- Task/spec: automatic earned sprint without stamina, approved 2026-10-24.
-- Task/spec: completed local Vault floating card, approved 2026-10-24.
-- T09 [Code/P0] MovementController — Client movement (COMPLETE)
--
-- Responsibilities:
--   • Runner and Taya walk / earned sprint speed via Humanoid.WalkSpeed
--   • Three-second server-confirmed sprint after a two-action movement chain
--   • Post-tag ex-Taya boost: +20% walk+sprint for 2s (F08, via TagEvent)
--   • Dash: 12 studs linear in 0.2s, 5s cooldown, 0.15s tag-action invulnerability (F07),
--     wall-clamped raycast, RequestDash → server (server validates + records)
--   • Slide: 1.0s, 1.25s cooldown, 50% hitbox (HipHeight), momentum gain
--     momentum entry sustained per-Heartbeat, locked heading, both roles (F09)
--   • Roll: slide input buffered for 0.15s before landing, momentum preserved,
--     server-validated momentum gain, normal tag profile, both roles
--   • Slide anim guaranteed: verified load + watchdog retry + one warn/character
--   • Published anims (Config IDs): HRush_Sprint loops while sprinting
--     (playback scaled with WalkSpeed), HRush_SlideLoop holds per slide,
--     HRush_Dash one-shots strictly inside the 0.2s dash window (sprint
--     stops at dash start and resumes at move end via tickSprintAnim).
--     Cosmetic only; a failed load silently keeps the default animations.
--   • Movement lock: MS_03 Countdown WalkSpeed 0; dash/slide open in
--     MS_01 lobby warm-up and MS_04 Round Live, closed otherwise.
--     NOTE (playtest): spawn straight into the lobby and press C — no
--     FIND MATCH needed to test slide; MatchService owns MS_02-MS_06.
--   • Bindings: PC Q/C/E, gamepad B/R1/X, and touch actions; sprint is automatic
--   • Dash VFX: local wind burst and four ribbons; accepted live dashes render for observers.
--   • UI bridge: HRush* attributes on LocalPlayer (UIController reads poll-free)
--   • Skill RS_01 Luksong Baka (T18 slice): request + facing to SkillService,
--     server validates (round/stun/ground/airborne/CD) and broadcasts SkillEvent,
--     caster runs windup (0.1s crouch) -> takeoff (single impulse, CD starts)
--     -> locked-direction flight -> landing recovery (0.2s no sprint).
--   • Skill RS_03 Tsinelas Throw (T18 slice, cosmetics only): TEMP hold G to
--     aim at a target point from the camera view, release to throw; X cancels.
--     Aiming eases the camera into first person and restores it on exit.
--     Server solves the 45 degree parabolic arc and owns the hit test. This client draws
--     the arc dots plus landing marker and flies the slipper on the same arc.
--     Grant list: Config.Skills.testGrant, role gate via Config.Debug flag.
--
-- Does NOT handle: tag detection/validation (TagService owns truth),
-- skill draft/unlocks (T17), remaining skills (RS_02, TS_*) and Diskarte
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
local momentum = {
	rules = require(ReplicatedStorage:WaitForChild("MomentumRules")),
	controller = require(script.Parent:WaitForChild("MomentumController")),
}
local TsinelasArc = require(ReplicatedStorage:WaitForChild("TsinelasArc"))
local Mv     = Config.Movement   -- shorthand
local Animations = Config.Animations

local function isUsableAnimationId(id: any): boolean
	return typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil
end

local function resolveAnimationId(definition: any): string?
	if isUsableAnimationId(definition.Id) then
		return definition.Id
	end
	return nil
end

-- Sibling module (same Rojo sync): routes one-shot sounds into the SFX group.
local AudioRouter = require(script.Parent:WaitForChild("AudioRouter"))
local MatchFeedback = require(script.Parent:WaitForChild("MatchFeedback"))
-- Sibling module (same Rojo sync): cosmetic scale and reduced camera flag.
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))
local WindDash = require(ReplicatedStorage:WaitForChild("VFX"):WaitForChild("WindDash"))

-- ── Player / character refs ──────────────────────────────────────────────────
local LocalPlayer = Players.LocalPlayer
local Character: Model
local Humanoid: Humanoid
local HRP: BasePart  -- HumanoidRootPart

-- ── Remotes ──────────────────────────────────────────────────────────────────
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestDash = Remotes:WaitForChild("RequestDash") :: RemoteEvent
local DashVFXEvent = Remotes:WaitForChild("DashVFXEvent") :: UnreliableRemoteEvent
local RequestMovementState = Remotes:WaitForChild("RequestMovementState") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local TagEvent = Remotes:WaitForChild("TagEvent") :: RemoteEvent
local RequestSkill = Remotes:WaitForChild("RequestSkill") :: RemoteEvent
local SkillEvent = Remotes:WaitForChild("SkillEvent") :: RemoteEvent
local SkillApproved = Remotes:WaitForChild("SkillApproved") :: RemoteEvent
local SkillVFX = Remotes:WaitForChild("SkillVFX") :: RemoteEvent
local SkillLanded = Remotes:WaitForChild("SkillLanded") :: RemoteEvent

-- ── State ────────────────────────────────────────────────────────────────────
-- Server-confirmed chain earns a timed sprint during live rounds.
local isSprinting = false
local lastSprintSent = false -- last sprint state fired on the SprintVFX bridge

-- Dash
local isDashing = false
local dashCooldownLeft = 0.0
local dashConn: RBXScriptConnection? = nil

-- Slide
local isSliding = false
local slideCooldownLeft = 0.0
local slideTimer = 0.0
local slideHipHeight = 0.0 -- HipHeight captured at slide start (restored on end)
local slideConn: RBXScriptConnection? = nil -- Heartbeat sustain: holds momentum-aware slide speed
local slideDir = Vector3.new(0, 0, -1) -- slide heading, fixed at entry (steer lock)
local slideSpeed = 0.0 -- role sprint base; momentum and ex-Taya boost are applied each frame
local slideGen = 0 -- slide generation: watchdog retries only the latest slide
local slideAnimWarned = false -- one warn per character when the clip will not play

-- Landing roll
local roll: any = {
	active = false,
	inputExpiresAt = 0.0,
	inputAt = 0.0,
	timer = 0.0,
	dir = Vector3.new(0, 0, -1),
	speed = 0.0,
	baseSpeed = 0.0,
}

-- Automatic low-obstacle vault. One table avoids exhausting this legacy
-- controller's top-level local-register budget.
local vault: any = {
	active = false,
	cooldown = 0.0,
	probe = 0.0,
	connection = nil,
	autoRotate = true,
	exitDir = Vector3.new(0, 0, -1),
	exitSpeed = 0.0,
	variant = "",
	boundaryObstacle = nil,
	boundaryLoggedAt = 0.0,
	rejectedObstacle = nil,
	landing = nil,
	track = nil,
}

-- Published animation tracks (HRush_Sprint / HRush_Slide / HRush_Dash): cosmetic only.
-- Played on the owned character, so other clients see them too (the Animator
-- replicates owner-played tracks). A failed load (e.g. wrong Creator
-- ownership) leaves the track nil and the game keeps default animations.
local sprintTrack: AnimationTrack? = nil
local slideTrack: AnimationTrack? = nil
local dashTrack: AnimationTrack? = nil
local rollTrack: AnimationTrack? = nil

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

-- Tsinelas Throw (RS_03, T18 slice): TEMP cast path until T17 draft owns skill
-- selection. Hold G to aim, release to throw; the server validates, simulates
-- the projectile, and broadcasts SkillVFX cast/impact/miss phases. Cosmetics
-- only: this client never decides hits. Removed when PickSkill owns unlocks.
local TSINELAS_KEY = Enum.KeyCode.G -- TEMP (T18): test key until T17 draft
local TSINELAS_CANCEL_KEY = Enum.KeyCode.X -- TEMP (T18): explicit aim cancel
local tsinelasHeld = false -- G physically held for release-to-throw
local tsinelasAiming = false -- aim line live, waiting for release
local tsinelasAimHoldLeft = 0.0 -- max hold countdown while aiming
local tsinelasAimDots: { BasePart } = {} -- parabola dots, owner only
local tsinelasAimMarker: BasePart? = nil -- landing marker, owner only
local tsinelasPending = false -- request sent, waiting for the server reply
local tsinelasPendingLeft = 0.0 -- clears a lost reply so input cannot wedge
local tsinelasCooldownLeft = 0.0 -- local mirror of the server cooldown ledger
local activeSlippers: { [number]: { part: BasePart, conn: RBXScriptConnection? } } = {}
local skillDebugLabel: BillboardGui? = nil -- airborne debug label (ShowSkillDebug)
local skillStateConn: RBXScriptConnection? = nil -- shared Humanoid.StateChanged landing hook

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

-- Post-tag boost (Spec §3 / F08): ex-Taya +20% walk+sprint for 2s.
local boostLeft = 0.0

-- Movement lock: MS_03 Countdown locks input; MS_05/MS_06/MS_02 freeze & end slides.
-- MS_01 lobby is a warm-up playground (movement + dash/slide open) so solo
-- Studio tests work without pressing FIND MATCH; MS_04 is Round Live.
local inputLocked = false

local role = "Runner" -- "Runner" | "Taya"; updated by StateChanged
local roundLive = false -- true only during MS_04 Round Live (dash/slide gate)
local lobbyWarmup = true -- true in MS_01 lobby OR before the first StateChanged

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

local function reportMovementState(action: string, active: boolean, direction: any?)
	if roundLive then
		RequestMovementState:FireServer(action, active, direction)
	end
end

-- ── Speed management ─────────────────────────────────────────────────────────
-- Spec §3 + F08: Runner walk 16 / sprint 21. Ex-Taya gets +20% on BOTH base
-- speeds for 2s (PostTagSpeedBoostMult/Duration). Earned sprint is server-owned.
-- Taya walks at base 18. Slide holds its entry speed (momentum).
-- Call this any time role / sprint / boost / lock state changes.
-- Stun gate (RS_03/T13): the server owns HRushStunned. While it is true the
-- client holds speed at 0 and starts no movement action. One helper plus
-- one attribute signal; entry gates also poll it because attribute
-- replication lags the server by a few frames.
local function isStunned(): boolean
	return LocalPlayer:GetAttribute("HRushStunned") == true
end

local function applySpeed()
	if not Humanoid then
		return
	end
	if isStunned() then
		Humanoid.WalkSpeed = 0 -- stunned: hold until the server clears
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
	if isSliding or roll.active or vault.active then
		-- Slide, roll, and vault own their momentum until their state ends.
		return
	end
	local targetSpeed: number
	local boostMult = if role == "Runner" and boostLeft > 0 then Mv.PostTagSpeedBoostMult else 1
	if role == "Taya" then
		targetSpeed = (if isSprinting then Mv.TayaSprintSpeed else Mv.TayaSpeed) * Mv.SpeedScale
	else
		if isSprinting then
			targetSpeed = Mv.RunnerSprintSpeed * Mv.SpeedScale
		else
			targetSpeed = Mv.RunnerWalkSpeed * Mv.SpeedScale
		end
	end
	local landingMult = LocalPlayer:GetAttribute("HRushHardLandingSpeedMult")
	Humanoid.WalkSpeed = momentum.rules.speed(targetSpeed, boostMult,
		if typeof(landingMult) == "number" then landingMult else 1, momentum.controller.value())
end

-- ── Earned sprint ─────────────────────────────────────────────────────────────
local function updateSprint()
	local sprintReadyAt, sprintUntil = momentum.controller.sprintWindow()
	local now = Workspace:GetServerTimeNow()
	local isMoving = false
	if Humanoid then
		isMoving = Humanoid.MoveDirection.Magnitude > 0.1
	end

	isSprinting = roundLive and isMoving and now >= sprintReadyAt and now < sprintUntil
		and not isSliding and not isDashing and not roll.active and not vault.active
		and skillRecoveryLeft <= 0 and skillWindupLeft <= 0 and skillFlightLeft <= 0 and not isStunned()

	-- Sprint VFX bridge: fire only on transitions. SprintVFX owns the event;
	-- this side only finds and fires it, never creates it.
	if isSprinting ~= lastSprintSent then
		lastSprintSent = isSprinting
		reportMovementState("Sprint", isSprinting)
		local bridge = ReplicatedStorage:FindFirstChild("SprintVFXState")
		if bridge and bridge:IsA("BindableEvent") then
			bridge:Fire(isSprinting)
		end
	end

	applySpeed()
end

-- ── UI attribute bridge ────────────────────────────────────────────────────────
-- LocalScripts cannot be require()d, so UIController reads live movement state
-- from attributes on LocalPlayer (poll-free via GetAttributeChangedSignal):
--   HRushDashCD, HRushSlideCD,
--   HRushDashing, HRushSliding, HRushRolling, HRushBoost (seconds left),
--   HRushRole ("Runner" | "Taya") — UI gates Runner-only dash HUD,
--   HRushSkillId (granted skill id, "" = none), HRushSkillCD (seconds left),
--   plus the SprintVFXState bridge event (true/false on sprint transitions).
--   HRushSkillId_RS03 ("RS_03" when granted, "" = none),
--   HRushSkillCD_RS03 (RS_03 seconds left), HRushAiming ("RS_03" while aiming).
-- Grant lookup (TEMP list until T17 draft owns unlocks). The role check stays
-- but is skipped while Config.Debug.AllowAnyRoleForSkills is on, so any role
-- can test skills; flip the flag off to restore the Runner-only rule.
local function grantedSkillId(): string
	local mode = LocalPlayer:GetAttribute("HRushGameMode")
	if LocalPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo" then
		local carrierId = ReplicatedStorage:GetAttribute("HRushPanyoCarrierUserId")
		if carrierId == LocalPlayer.UserId then return "" end
	end
	if role ~= "Runner" and not Config.Debug.AllowAnyRoleForSkills then
		return ""
	end
	for _, id in Config.Skills.testGrant do
		local sk = Config.Skills[id]
		if sk and (Config.Debug.AllowAnyRoleForSkills or sk.role == role)
			and ((mode ~= "AgawanNgPanyo" and mode ~= "SecretHunt") or id == "RS_01") then
			return id
		end
	end
	return ""
end

-- RS_03 grant for the UI slot: same TEMP list and role gate as above, but
-- for Tsinelas Throw specifically (grantedSkillId returns the first grant).
local function grantedTsinelas(): string
	local mode = LocalPlayer:GetAttribute("HRushGameMode")
	if mode == "AgawanNgPanyo" or mode == "SecretHunt" then return "" end
	if role ~= "Runner" and not Config.Debug.AllowAnyRoleForSkills then
		return ""
	end
	for _, id in Config.Skills.testGrant do
		if id == "RS_03" then
			local sk = Config.Skills[id]
			if sk and (Config.Debug.AllowAnyRoleForSkills or sk.role == role) then
				return id
			end
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
	LocalPlayer:SetAttribute("HRushDashCD", dashCooldownLeft)
	LocalPlayer:SetAttribute("HRushSlideCD", slideCooldownLeft)
	LocalPlayer:SetAttribute("HRushDashing", isDashing)
	LocalPlayer:SetAttribute("HRushSliding", isSliding)
	LocalPlayer:SetAttribute("HRushRolling", roll.active)
	LocalPlayer:SetAttribute("HRushVaulting", vault.active)
	LocalPlayer:SetAttribute("HRushSprinting", isSprinting)
	LocalPlayer:SetAttribute("HRushAbilityBusy", skillPending or skillApprovedActive or skillWindupLeft > 0
		or skillFlightLeft > 0 or skillRecoveryLeft > 0 or tsinelasAiming or tsinelasPending)
	LocalPlayer:SetAttribute("HRushVaultCD", vault.cooldown)
	LocalPlayer:SetAttribute("HRushVaultVariant", vault.variant)
	LocalPlayer:SetAttribute("HRushBoost", boostLeft)
	LocalPlayer:SetAttribute("HRushRole", role)
	skillId = grantedSkillId()
	LocalPlayer:SetAttribute("HRushSkillId", skillId)
	LocalPlayer:SetAttribute("HRushSkillCD", skillCooldownLeft)
	LocalPlayer:SetAttribute("HRushSkillCD_RS03", tsinelasCooldownLeft)
	LocalPlayer:SetAttribute("HRushSkillId_RS03", grantedTsinelas())
	LocalPlayer:SetAttribute("HRushAiming", if tsinelasAiming then "RS_03" else "")
end

-- ── Dash VFX ───────────────────────────────────────────────────────────────────
-- WindDash owns all cosmetic instances. A completed glide keeps its brief tail;
-- interruptions and character removal cancel it immediately.
local dashFX: any = nil

local function startDashFX(direction: Vector3, position: Vector3)
	if dashFX then
		dashFX.Cancel()
	end
	dashFX = WindDash.Play(Character, direction, position, 0, VfxScale.cosmetic())
end

local function stopDashFX(completed: boolean?)
	if not completed and dashFX then
		dashFX.Cancel()
		dashFX = nil
	end
end

-- Dash sound hook (declared here, above performDash: Luau single-pass would
-- bind the later playSkillSound as a nil global and wedge the dash). An empty
-- id in Config is skipped, so the dash stays silent until licensed audio lands
-- (ASSET_LOG rule). Fire-and-forget one-shot, like the skill sounds.
local function playDashSound()
	if not HRP then
		return
	end
	local id = Mv.DashSoundId
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Mv.DashSoundVolume
	sound.RollOffMaxDistance = 60
	AudioRouter.route(sound, "sfx")
	sound.Parent = HRP
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- ── Animation one-shot helpers (declared before use) ─────────────────────────
-- Luau compiles locals single-pass: calling a function declared later in this
-- file binds a nil global and throws ("attempt to call a nil value"). A throw
-- inside performDash/cancelDash wedges isDashing and locks sprint plus skills,
-- so these helpers MUST stay above their first caller. Play/Stop are
-- additionally pcall'd so a torn-down Animator can never wedge movement state.
local function stopSprintAnim()
	if sprintTrack and sprintTrack.IsPlaying then
		sprintTrack:Stop(Animations.Sprint.FadeOut)
	end
end

local function stopSlideAnim()
	if slideTrack then
		local track: AnimationTrack = slideTrack
		pcall(function()
			if track.IsPlaying then
				track:Stop(Animations.SlideLoop.FadeOut)
			end
		end)
	end
end

local function playSlideAnim()
	if slideTrack then
		local track: AnimationTrack = slideTrack
		pcall(function()
			track:Play(Animations.SlideLoop.FadeIn, 1, 1)
			-- Fit AFTER play starts (guarded): a re-published clip never overruns
			-- or gets cut, and a zero Length can never freeze frame 0.
			local len = track.Length
			if len > 0.5 and Mv.SlideDuration > 0 then
				track:AdjustSpeed(len / Mv.SlideDuration)
			end
		end)
	end
end

-- Slide feel (dash pattern): heel dust burst + whoosh hook. Declared here above
-- performSlide per the single-pass rule. An empty SlideSoundId stays silent
-- until a licensed asset lands (ASSET_LOG rule).
local function playSlideSound()
	if not HRP then
		return
	end
	local id = Mv.SlideSoundId
	if typeof(id) ~= "string" or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Mv.SlideSoundVolume
	sound.RollOffMaxDistance = 60
	AudioRouter.route(sound, "sfx")
	sound.Parent = HRP
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function emitSlideDust()
	if not HRP then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "SlideDust"
	att.Position = Vector3.new(0, -2, 0) -- near the heels where the slide kicks up
	att.Parent = HRP
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0 -- burst only, never a stream (mobile particle budget)
	emitter.Lifetime = NumberRange.new(Mv.SlideDustLifeMin, Mv.SlideDustLifeMax)
	emitter.Speed = NumberRange.new(Mv.SlideDustSpeedMin, Mv.SlideDustSpeedMax)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -12, 0) -- dust settles, it does not float
	emitter.Color = ColorSequence.new(Color3.fromRGB(214, 200, 176))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, Mv.SlideDustSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = att
	local dust = VfxScale.count(Mv.SlideDustCount)
	if dust > 0 then
		emitter:Emit(dust)
	end
	Debris:AddItem(att, 1.2) -- cleanup margin only, not a gameplay number
end

local function stopDashAnim()
	if dashTrack then
		local track: AnimationTrack = dashTrack
		pcall(function()
			if track.IsPlaying then
				track:Stop(Animations.Dash.FadeOut)
			end
		end)
	end
end

local function playDashAnim()
	if dashTrack then
		local track: AnimationTrack = dashTrack
		pcall(function()
			track:Play(Animations.Dash.FadeIn, 1, 1)
		end)
	end
end

local function stopRollAnim()
	if rollTrack then
		local track: AnimationTrack = rollTrack
		pcall(function()
			if track.IsPlaying then
				track:Stop(Animations.Roll.FadeOut)
			end
		end)
	end
end

local function playRollAnim()
	if rollTrack then
		local track: AnimationTrack = rollTrack
		pcall(function()
			track:Play(Animations.Roll.FadeIn, 1, 1)
		end)
	end
end

function vault.stopAnim()
	if vault.track then
		local track: AnimationTrack = vault.track
		pcall(function()
			if track.IsPlaying then
				track:Stop(Animations.Vault.FadeOut)
			end
		end)
	end
end

function vault.playAnim()
	if vault.track then
		local track: AnimationTrack = vault.track
		pcall(function()
			track:Play(Animations.Vault.FadeIn, 1, 1)
		end)
	end
end

function vault.stopAirAnimations()
	if not Humanoid then
		return
	end
	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	local jumpId = resolveAnimationId(Animations.JumpStart)
	local fallId = resolveAnimationId(Animations.Fall)
	for _, track in animator:GetPlayingAnimationTracks() do
		local animation = track.Animation
		if animation and (animation.AnimationId == jumpId or animation.AnimationId == fallId) then
			pcall(function()
				track:Stop(0)
			end)
		end
	end
end

-- ── Dash ──────────────────────────────────────────────────────────────────────
-- Spec §3: DashDistance (12) studs in DashDuration (0.2s), DashCooldown (6s),
-- DashTagInvulnTime (0.15s, F07 vs tag actions only; server enforces this).
-- No stamina cost. Movement is linear start→end (constant velocity 60 st/s);
-- a forward raycast clamps the target so the dash stops at walls instead of
-- phasing through. Server is notified via RequestDash (validates cooldown/round).
local function cancelDash(completed: boolean?)
	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end
	isDashing = false
	stopDashAnim() -- dash anim lives strictly inside the dash window
	stopDashFX(completed)
	applySpeed()
	pushAttributes()
end

local function performDash()
	if inputLocked then
		return
	end
	if not (roundLive or lobbyWarmup) then
		return -- MS_02/MS_03/MS_05/MS_06: abilities closed
	end
	if isStunned() then
		return -- stunned: no new actions
	end
	if role ~= "Runner" then
		return
	end
	if isDashing or dashCooldownLeft > 0 then
		return
	end
	if isSliding or roll.active or vault.active then
		return
	end
	if not Humanoid or not HRP then
		return
	end

	isDashing = true
	dashCooldownLeft = Mv.DashCooldown
	pushAttributes(true)

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

	-- Lobby warm-up remains local. Live-round requests are validated and recorded
	-- by MovementAuthority while this client keeps prediction for responsiveness.
	if roundLive then
		RequestDash:FireServer(moveDir)
	end

	-- VFX: ribbon on during the glide + one-shot particle burst at the heels.
	startDashFX(moveDir, HRP.Position)
	playDashSound()

	-- Animation: sprint yields for exactly the dash window, then resumes.
	stopSprintAnim()
	playDashAnim()

	-- Clamp travel so we stop at walls instead of phasing through them.
	local travel = Mv.DashDistance * Mv.SpeedScale
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
			cancelDash(true) -- move done; visual tail fades after the glide
		end
	end)
end

-- ── Slide ─────────────────────────────────────────────────────────────────────
-- Spec §3 + F09: SlideDuration and SlideCooldown from Config, hitbox at
-- SlideHitboxScale (50% height) so touch tag cannot hit a Runner under a low gap
-- (TagService reads the sliding flag via position/height; server owns the verdict).
-- Entry adds predicted momentum and sustains the capped role speed per Heartbeat;
-- heading locks at entry while
-- SlideSteerLock is on. Both roles slide. Dust + whoosh on entry (dash
-- pattern). Cancelled by tag swaps, round end, stun, or death.
local function endSlide()
	if not isSliding or not Humanoid then
		return
	end
	if slideConn then
		slideConn:Disconnect()
		slideConn = nil
	end
	-- Restore exact HipHeight captured at slide start (never assume the default).
	Humanoid.HipHeight = slideHipHeight
	isSliding = false
	reportMovementState("Slide", false)
	stopSlideAnim()
	applySpeed()
	pushAttributes(true)
end

local function performSlide()
	if inputLocked then
		return
	end
	if not (roundLive or lobbyWarmup) then
		return -- MS_02/MS_03/MS_05/MS_06: abilities closed
	end
	if isStunned() then
		return -- stunned: no new actions
	end
	-- Both roles slide (Runner escape + Taya chase through low gaps).
	if isSliding or slideCooldownLeft > 0 then
		return
	end
	if isDashing or roll.active or vault.active then
		return
	end
	if not Humanoid or not HRP then
		return
	end
	if Humanoid.MoveDirection.Magnitude < 0.1 then
		return -- must be moving to slide
	end
	local velocity = HRP.AssemblyLinearVelocity
	local observedEntrySpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local sprintSpeed = (if role == "Taya" then Mv.TayaSprintSpeed else Mv.RunnerSprintSpeed) * Mv.SpeedScale
	local earnsMomentum = momentum.rules.slideEligible(observedEntrySpeed, sprintSpeed)
	if Config.Momentum.Debug then
		print(string.format("[Momentum] client slide detected: role=%s sprint=%s speed=%.2f eligible=%s live=%s",
			role, tostring(isSprinting), observedEntrySpeed, tostring(earnsMomentum), tostring(roundLive)))
	end

	isSliding = true
	if vault.landing then
		vault.landing.cancelPenalty("Slide")
	end
	slideTimer = 0.0
	slideCooldownLeft = Mv.SlideCooldown
	slideHipHeight = Humanoid.HipHeight

	-- Shrink hitbox: halve height (F09 — low-gap evasion).
	Humanoid.HipHeight = slideHipHeight * Mv.SlideHitboxScale

	-- Lock WalkSpeed at the momentum-aware entry speed and sustain it
	-- every Heartbeat (a one-frame burst alone is eaten by humanoid friction).
	-- Velocity-driven so walls still collide normally. Heading locks at entry
	-- while SlideSteerLock is on; MoveDirection steers when it is off.
	if roundLive and earnsMomentum then momentum.controller.predict("Slide") end
	slideSpeed = sprintSpeed
	local entrySpeed = momentum.rules.speed(slideSpeed,
		if role == "Runner" and boostLeft > 0 then Mv.PostTagSpeedBoostMult else 1, 1, momentum.controller.value())
	Humanoid.WalkSpeed = entrySpeed
	-- Send the entry request before the slide velocity burst so the server can
	-- validate the speed observed on entry, not the speed created by the slide.
	reportMovementState("Slide", true, earnsMomentum)
	local hum = Humanoid -- captured: sustain reads this character, never a respawned one
	local burstDir = Vector3.new(Humanoid.MoveDirection.X, 0, Humanoid.MoveDirection.Z)
	if burstDir.Magnitude > 0.01 then
		burstDir = burstDir.Unit
		slideDir = burstDir
		HRP.AssemblyLinearVelocity = Vector3.new(burstDir.X * entrySpeed, HRP.AssemblyLinearVelocity.Y, burstDir.Z * entrySpeed)
		if slideConn then
			slideConn:Disconnect()
			slideConn = nil
		end
		slideConn = RunService.Heartbeat:Connect(function()
			if not isSliding or not HRP or not HRP.Parent then
				return
			end
			local dir = slideDir
			if not Mv.SlideSteerLock and hum.Parent then
				local md = hum.MoveDirection
				if md.Magnitude > 0.1 then
					dir = Vector3.new(md.X, 0, md.Z).Unit
				end
			end
			local v = HRP.AssemblyLinearVelocity
			local speed = momentum.rules.speed(slideSpeed,
				if role == "Runner" and boostLeft > 0 then Mv.PostTagSpeedBoostMult else 1, 1, momentum.controller.value())
			hum.WalkSpeed = speed
			HRP.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
		end)
	end
	pushAttributes(true)
	-- The server validates this entry independently and corrects the predicted gain.
	-- Sprint yields for the whole slide so the loop never fights the one-shot.
	stopSprintAnim()
	emitSlideDust()
	playSlideSound()
	playSlideAnim()
	-- Animation guarantee: the clip MUST run while sliding. Verify shortly
	-- after Play; retry once, then warn once per character (named asset id).
	slideGen += 1
	local gen = slideGen
	task.delay(0.15, function()
		if gen ~= slideGen or not isSliding then
			return -- superseded slide or clean exit: nothing to do
		end
		local t = slideTrack
		local playing = false
		if t then
			pcall(function()
				playing = t.IsPlaying
			end)
		end
		if playing then
			return
		end
		if t then
			pcall(function()
				t:Play(Animations.SlideLoop.FadeIn, 1, 1)
			end)
		end
		if not slideAnimWarned then
			slideAnimWarned = true
			warn("[Slide] animation failed to play (" .. tostring(Animations.SlideLoop.Id) .. ")")
		end
	end)
end

-- ── Landing roll ──────────────────────────────────────────────────────────────
-- The slide input becomes a short pre-landing buffer while airborne. A valid
-- landing consumes it and preserves horizontal momentum. Roll adds the
-- predicted, server-validated gain, keeps the normal tag profile, and grants
-- no invulnerability.
local function endRoll()
	if not roll.active then
		return
	end
	roll.active = false
	roll.timer = 0
	roll.speed = 0
	roll.baseSpeed = 0
	reportMovementState("Roll", false)
	stopRollAnim()
	applySpeed()
	pushAttributes(true)
end

local function performRoll()
	if os.clock() > roll.inputExpiresAt then
		roll.inputExpiresAt = 0
		roll.inputAt = 0
		return
	end
	local perfect = roll.inputAt > 0 and os.clock() - roll.inputAt <= Config.Momentum.PerfectRollWindow
	roll.inputExpiresAt = 0
	roll.inputAt = 0
	if inputLocked or not (roundLive or lobbyWarmup) or isStunned() then
		return
	end
	if roll.active or isSliding or isDashing or vault.active then
		return
	end
	if skillFlightLeft > 0 or skillWindupLeft > 0 or skillApprovedActive then
		return
	end
	if not Humanoid or not HRP or Humanoid.Health <= 0 then
		return
	end

	local flatVelocity = Vector3.new(HRP.AssemblyLinearVelocity.X, 0, HRP.AssemblyLinearVelocity.Z)
	local direction = flatVelocity
	if direction.Magnitude < Mv.ServerDirectionMinMagnitude then
		direction = Vector3.new(Humanoid.MoveDirection.X, 0, Humanoid.MoveDirection.Z)
	end
	if direction.Magnitude < Mv.ServerDirectionMinMagnitude then
		direction = Vector3.new(HRP.CFrame.LookVector.X, 0, HRP.CFrame.LookVector.Z)
	end
	if direction.Magnitude < Mv.ServerDirectionMinMagnitude then
		return
	end

	roll.active = true
	if vault.landing then
		vault.landing.cancelPenalty("Roll")
	end
	roll.timer = 0
	roll.dir = direction.Unit
	local priorMomentum = momentum.controller.value()
	local roleBase = (if role == "Runner" then Mv.RunnerSprintSpeed else Mv.TayaSpeed) * Mv.SpeedScale
	if role == "Runner" and boostLeft > 0 then roleBase *= Mv.PostTagSpeedBoostMult end
	local carriedSpeed = math.min(flatVelocity.Magnitude, roleBase * (1 + Mv.ServerSpeedTolerancePct))
	local walkSpeed = (if role == "Runner" then Mv.RunnerWalkSpeed else Mv.TayaSpeed) * Mv.SpeedScale
	roll.baseSpeed = math.max(walkSpeed, carriedSpeed - priorMomentum)
	if roundLive then momentum.controller.predict("Roll", perfect) end
	roll.speed = momentum.rules.speed(roll.baseSpeed, 1, 1, momentum.controller.value())
	Humanoid.WalkSpeed = roll.speed
	local velocity = HRP.AssemblyLinearVelocity
	HRP.AssemblyLinearVelocity = Vector3.new(roll.dir.X * roll.speed, velocity.Y, roll.dir.Z * roll.speed)
	reportMovementState("Roll", true)
	stopSprintAnim()
	playRollAnim()
	pushAttributes(true)
end

-- Automatic chest-level Vault. All three body probes are measured from the
-- character's current standing feet height. Ground below the character is used
-- only for the absolute cap, while the top and far-side rays define the route.
function vault.findTarget(direction: Vector3, entrySpeed: number): any?
	if not Character or not Humanoid or not HRP then
		return nil
	end
	local hipHeight = if isSliding then slideHipHeight else Humanoid.HipHeight
	local rootToFeet = HRP.Size.Y * 0.5 + hipHeight
	local feetY = HRP.Position.Y - rootToFeet
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Character }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	local groundHit = Workspace:Raycast(HRP.Position, Vector3.new(0, -Mv.VaultGroundProbeDepth, 0), params)
	if groundHit == nil then
		return nil
	end

	local obstacleHit: RaycastResult? = nil
	for _, probeHeight in { Mv.VaultKneeHeight, Mv.VaultWaistHeight, Mv.VaultChestHeight } do
		local origin = Vector3.new(HRP.Position.X, feetY + probeHeight, HRP.Position.Z)
		local hit = Workspace:Raycast(origin, direction * Mv.VaultProbeDistance, params)
		if hit and hit.Instance:IsA("BasePart") and (obstacleHit == nil or hit.Distance < obstacleHit.Distance) then
			obstacleHit = hit
		end
	end
	if obstacleHit == nil then
		vault.rejectedObstacle = nil
		return nil
	end
	local obstacle = obstacleHit.Instance :: BasePart
	if vault.rejectedObstacle == obstacle then
		return nil
	end

	local topOrigin = Vector3.new(
		obstacleHit.Position.X + direction.X * Mv.VaultTopInset,
		math.max(feetY + Mv.VaultMaxH, groundHit.Position.Y + Mv.VaultMaxAboveGround) + Mv.VaultTopProbeMargin,
		obstacleHit.Position.Z + direction.Z * Mv.VaultTopInset
	)
	local topHit = Workspace:Raycast(
		topOrigin,
		Vector3.new(0, -(
			Mv.VaultMaxAboveGround + Mv.VaultGroundProbeDepth + Mv.VaultTopProbeMargin * 2
		), 0),
		params
	)
	if topHit == nil or topHit.Instance ~= obstacle then
		return nil
	end
	local relativeHeight = topHit.Position.Y - feetY
	if relativeHeight < Mv.VaultMinH - Mv.VaultGeometryTolerance
		or relativeHeight > Mv.VaultMaxH + Mv.VaultGeometryTolerance
	then
		vault.rejectedObstacle = obstacle
		return nil
	end
	if topHit.Position.Y > groundHit.Position.Y + Mv.VaultMaxAboveGround + Mv.VaultGeometryTolerance then
		vault.rejectedObstacle = obstacle
		return nil
	end

	local half = obstacle.Size * 0.5
	local cf = obstacle.CFrame
	local extent = math.abs(direction:Dot(cf.RightVector)) * half.X
		+ math.abs(direction:Dot(cf.UpVector)) * half.Y
		+ math.abs(direction:Dot(cf.LookVector)) * half.Z
	local nearEdge = obstacleHit.Distance
	local farEdge = (obstacle.Position - HRP.Position):Dot(direction) + extent
	local depth = farEdge - nearEdge
	if depth <= 0 or depth > Mv.VaultMaxDepth + Mv.VaultGeometryTolerance then
		return nil
	end
	local travel = farEdge + Mv.VaultLandingMargin
	if travel <= 0 or travel > Mv.VaultMaxTravelDistance then
		return nil
	end

	local landingOrigin = Vector3.new(
		HRP.Position.X + direction.X * travel,
		topHit.Position.Y + Mv.VaultTopProbeMargin,
		HRP.Position.Z + direction.Z * travel
	)
	local landingHit = Workspace:Raycast(
		landingOrigin,
		Vector3.new(0, -Mv.VaultLandingProbeDepth, 0),
		params
	)
	if landingHit == nil then
		return nil
	end
	if topHit.Position.Y - landingHit.Position.Y < Mv.VaultMinDrop - Mv.VaultGeometryTolerance then
		local now = os.clock()
		if RunService:IsStudio()
			and (vault.boundaryObstacle ~= obstacle or now - vault.boundaryLoggedAt >= Mv.VaultBoundaryLogCooldown)
		then
			vault.boundaryObstacle = obstacle
			vault.boundaryLoggedAt = now
			print(string.format("[Vault] mantle boundary: %s has no %.1f-stud far-side drop", obstacle:GetFullName(), Mv.VaultMinDrop))
		end
		return nil
	end
	local endPosition = Vector3.new(landingOrigin.X, landingHit.Position.Y + rootToFeet, landingOrigin.Z)
	local midpointY = (HRP.Position.Y + endPosition.Y) * 0.5
	local peakRootY = topHit.Position.Y + rootToFeet + Mv.VaultClearance
	local variant: string
	if Humanoid.FloorMaterial == Enum.Material.Air then
		variant = "AirVault"
	elseif relativeHeight <= Mv.VaultWaistHeight + Mv.VaultGeometryTolerance then
		variant = "LowHop"
	elseif depth <= Mv.VaultSpeedMaxDepth + Mv.VaultGeometryTolerance
		and entrySpeed >= Mv.RunnerSprintSpeed * Mv.SpeedScale * Mv.VaultSpeedVariantPct
	then
		variant = "SpeedVault"
	else
		variant = "StepVault"
	end
	return {
		endPosition = endPosition,
		arcHeight = math.max(0, peakRootY - midpointY),
		params = params,
		variant = variant,
	}
end

function vault.finish(completed: boolean, interruption: string?, preserveMomentum: boolean?)
	if not vault.active then
		return
	end
	if vault.connection then
		vault.connection:Disconnect()
		vault.connection = nil
	end
	vault.active = false
	if Humanoid then
		Humanoid.AutoRotate = vault.autoRotate
	end
	if HRP and HRP.Parent and (completed or preserveMomentum ~= false) then
		local velocity = HRP.AssemblyLinearVelocity
		HRP.AssemblyLinearVelocity = Vector3.new(
			vault.exitDir.X * vault.exitSpeed,
			velocity.Y,
			vault.exitDir.Z * vault.exitSpeed
		)
	end
	vault.exitSpeed = 0
	if not completed then
		warn("[Vault] interrupted: " .. (interruption or "movement cancelled"))
	end
	reportMovementState("Vault", false)
	vault.stopAnim()
	if completed and roundLive then
		MatchFeedback.showMovement("Vault", nil, nil, nil, Config.UI.Theme.Teal, vault.variant)
	end
	vault.variant = ""
	applySpeed()
	pushAttributes(true)
end

function vault.tryStart(): boolean
	if inputLocked or not (roundLive or lobbyWarmup) or isStunned() or vault.active or roll.active or isDashing then
		return false
	end
	if skillFlightLeft > 0 or skillWindupLeft > 0 or skillApprovedActive then
		return false
	end
	if not Humanoid or not HRP or Humanoid.Health <= 0 or vault.cooldown > 0 then
		return false
	end
	if vault.rejectedObstacle and vault.rejectedObstacle.Parent then
		local offset = vault.rejectedObstacle.Position - HRP.Position
		local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if flatDistance > Mv.VaultMaxTravelDistance + Mv.VaultLandingMargin then
			vault.rejectedObstacle = nil
		end
	end

	local flatVelocity = Vector3.new(HRP.AssemblyLinearVelocity.X, 0, HRP.AssemblyLinearVelocity.Z)
	local minimumSpeed = Mv.RunnerSprintSpeed * Mv.SpeedScale * Mv.VaultMinSpeedPct
	if flatVelocity.Magnitude < minimumSpeed then
		return false
	end
	local moveDirection = Vector3.new(Humanoid.MoveDirection.X, 0, Humanoid.MoveDirection.Z)
	local direction = if moveDirection.Magnitude >= Mv.ServerDirectionMinMagnitude
		then moveDirection.Unit
		else flatVelocity.Unit
	if flatVelocity.Unit:Dot(direction) < Mv.VaultDirectionMinDot then
		return false
	end

	local target = vault.findTarget(direction, flatVelocity.Magnitude)
	if target == nil then
		return false
	end
	local startPosition = HRP.Position
	local entrySpeed = flatVelocity.Magnitude
	if isSliding then
		endSlide()
	end
	if vault.landing then
		vault.landing.cancelPenalty("Vault")
	end

	vault.active = true
	vault.cooldown = Mv.VaultCooldown
	vault.exitDir = direction
	vault.exitSpeed = math.min(entrySpeed, entrySpeed * Mv.VaultSpeedKeepPct)
	vault.variant = target.variant
	vault.autoRotate = Humanoid.AutoRotate
	Humanoid.AutoRotate = false
	Humanoid.WalkSpeed = 0
	HRP.AssemblyLinearVelocity = Vector3.zero
	reportMovementState("Vault", true, direction)
	stopSprintAnim()
	vault.stopAirAnimations()
	vault.playAnim()
	pushAttributes(true)

	local elapsed = 0.0
	if vault.connection then
		vault.connection:Disconnect()
	end
	vault.connection = RunService.Heartbeat:Connect(function(dt: number)
		if not vault.active or not HRP or not HRP.Parent then
			vault.finish(false, "character unavailable")
			return
		end
		elapsed += dt
		local alpha = clamp(elapsed / Mv.VaultDuration, 0, 1)
		local base = startPosition:Lerp(target.endPosition, alpha)
		local lift = 4 * alpha * (1 - alpha) * target.arcHeight
		local position = base + Vector3.new(0, lift, 0)
		local displacement = position - HRP.Position
		if displacement.Magnitude > 0 then
			local collision = Workspace:Blockcast(
				HRP.CFrame,
				HRP.Size * Mv.VaultCollisionBoxScale,
				displacement,
				target.params
			)
			if collision then
				if collision.Normal.Y >= Mv.VaultLandingNormalMin and alpha >= Mv.VaultLandingCollisionAlpha then
					vault.finish(true)
				else
					vault.finish(false, "arc collision with " .. collision.Instance:GetFullName())
				end
				return
			end
		end
		HRP.CFrame = CFrame.lookAt(position, position + direction)
		HRP.AssemblyLinearVelocity = Vector3.zero
		if alpha >= 1 then
			vault.finish(true)
		end
	end)
	return true
end

local function handleSlideInput()
	if Humanoid and Humanoid.FloorMaterial == Enum.Material.Air then
		if not inputLocked
			and (roundLive or lobbyWarmup)
			and not isStunned()
			and not roll.active
			and not isSliding
			and not isDashing
			and not vault.active
			and skillFlightLeft <= 0
			and skillWindupLeft <= 0
			and not skillApprovedActive
		then
			roll.inputAt = os.clock()
			roll.inputExpiresAt = os.clock() + Mv.RollWindow
			reportMovementState("RollIntent", true, Workspace:GetServerTimeNow())
		end
		return
	end
	performSlide()
end

-- ── Published animation tracks ────────────────────────────────────────────────
-- Loads once per character. Tracks never touch speed or hitbox.
local function loadAnimTracks()
	sprintTrack = nil
	slideTrack = nil
	dashTrack = nil
	rollTrack = nil
	vault.track = nil
	if not Humanoid then
		return
	end
	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local function tryLoad(id: string?, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
		if id == nil then
			return nil
		end
		local ok, track = pcall(function(): AnimationTrack
			local anim = Instance.new("Animation")
			anim.AnimationId = id
			local t = animator:LoadAnimation(anim)
			t.Priority = priority
			t.Looped = looped
			return t
		end)
		if ok and track then
			return track
		end
		return nil
	end
	local sprintId = resolveAnimationId(Animations.Sprint)
	local slideId = resolveAnimationId(Animations.SlideLoop)
	local dashId = resolveAnimationId(Animations.Dash)
	local rollId = resolveAnimationId(Animations.Roll)
	local vaultId = resolveAnimationId(Animations.Vault)
	sprintTrack = tryLoad(sprintId, Animations.Sprint.Priority, Animations.Sprint.Looped)
	slideTrack = tryLoad(slideId, Animations.SlideLoop.Priority, Animations.SlideLoop.Looped)
	dashTrack = tryLoad(dashId, Animations.Dash.Priority, Animations.Dash.Looped)
	rollTrack = tryLoad(rollId, Animations.Roll.Priority, Animations.Roll.Looped)
	vault.track = tryLoad(vaultId, Animations.Vault.Priority, Animations.Vault.Looped)
	if slideTrack == nil and slideId ~= nil then
		warn("[Slide] failed to load animation " .. slideId)
	end
	if slideTrack == nil and slideId ~= nil then
		-- Streaming can fail the first load right after spawn. Retry once a
		-- few seconds later; the guard drops it if a respawn replaced the
		-- character or the track recovered another way.
		local hum = Humanoid
		task.delay(3, function()
			if slideTrack ~= nil or Humanoid ~= hum then
				return
			end
			slideTrack = tryLoad(slideId, Animations.SlideLoop.Priority, Animations.SlideLoop.Looped)
			if slideTrack == nil then
				warn("[Slide] retry failed for animation " .. slideId)
			end
		end)
	end
end

-- Runs every heartbeat: plays the sprint loop on the sprint transition, stops
-- it the moment sprinting ends (role swap, lock, stun, depletion), and scales
-- playback with real WalkSpeed so feet keep up when SpeedScale changes.
local function tickSprintAnim()
	if isSprinting and not isSliding and not roll.active and not vault.active and Humanoid then
		if sprintTrack then
			if not sprintTrack.IsPlaying then
				sprintTrack:Play(Animations.Sprint.FadeIn, 1, 1)
			end
			sprintTrack:AdjustSpeed(math.max(0.1, Humanoid.WalkSpeed / Mv.RunnerSprintSpeed))
		end
	elseif sprintTrack and sprintTrack.IsPlaying then
		sprintTrack:Stop(Animations.Sprint.FadeOut)
	end
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
	if VfxScale.reducedCamera() then
		return -- reduced camera effects: no FOV kick, flight unchanged
	end
	skillFOVBase = cam.FieldOfView
	skillFOVOn = true
	LocalPlayer:SetAttribute("HRushSkillFov", true)
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
	LocalPlayer:SetAttribute("HRushSkillFov", false)
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
	if VfxScale.reducedCamera() then
		return -- reduced camera effects: no landing shake
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
	local n = VfxScale.count(count)
	if n > 0 then
		emitter:Emit(n)
	end
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
	AudioRouter.route(sound, "sfx")
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
	if sk.params.windup == nil then
		return -- only RS_01 has a windup timeline; other skills route elsewhere
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
		local trailLife = sk.vfx.trailLifetime * VfxScale.cosmetic()
		if trailLife > 0.05 then
			startAirTrail(hrp, math.max(0.15, trailLife))
		end
		playSkillSound(hrp, sk.sounds.takeoff)
		if isOwner then
			skillPreviewRing = spawnLandingPreview(hrp.Position, sk.vfx.previewSize, dir, sk.params.distance * Mv.SpeedScale)
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

-- ── Tsinelas Throw cosmetics (RS_03, visuals only, never mechanics) ──────────
-- Game-feel light tier: spinning slipper + ribbon trail on cast, star burst +
-- eased ring pop + impact sound hook on hit. Every channel is transient and
-- self cleans, so the scene always returns to rest. All values from
-- Config.Skills.RS_03. No camera shake: the stun itself is the punishment.
local function tsinelasCleanup(casterId: number)
	local s = activeSlippers[casterId]
	if s == nil then
		return
	end
	activeSlippers[casterId] = nil
	if s.conn ~= nil then
		s.conn:Disconnect()
	end
	if s.part.Parent == nil then
		return
	end
	-- Fade, do not pop: stop new ribbon segments and hide the remnant so the
	-- existing segments decay over trailLifetime. Debris is margin only.
	local ribbon = s.part:FindFirstChild("TsinelasRibbon")
	if ribbon and ribbon:IsA("Trail") then
		ribbon.Enabled = false
	end
	s.part.Transparency = 1
	Debris:AddItem(s.part, Config.Skills.RS_03.vfx.trailLifetime + 0.2)
end

-- Cosmetic slipper: flies the shared arc over the shared flight time, so the
-- visual never disagrees with the server hit. Spin, ribbon, and impact star
-- are kept; the old style-only lift is gone, replaced by the real arc.
local function spawnSlipper(casterId: number, origin: Vector3, target: Vector3, dir: Vector3)
	tsinelasCleanup(casterId) -- one slipper per caster; a re-cast replaces it
	local sk = Config.Skills.RS_03
	if sk == nil then
		return
	end
	local v = sk.vfx
	local v0, flightT = TsinelasArc.solveArc(origin, target)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	local part = Instance.new("Part")
	part.Name = "TsinelasSlipper"
	part.Size = v.slipperSize
	part.Color = v.slipperColor
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	-- Lateral axis for the end-over-end spin (the tell reads at a glance).
	local axis = flat:Cross(Vector3.new(0, 1, 0))
	if axis.Magnitude < 0.01 then
		axis = Vector3.new(1, 0, 0)
	else
		axis = axis.Unit
	end
	part.CFrame = CFrame.new(origin)
	part.Parent = Workspace
	-- Ribbon trail between opposite ends of the slipper (dash trail pattern):
	-- two attachments, one Trail, FaceCamera. The slipper spins end over end
	-- so the ribbon reads as the spinning slipper arc. Cleanup disables it
	-- so segments fade instead of popping.
	local attA = Instance.new("Attachment")
	attA.Name = "TsinelasRibbonA"
	attA.Position = Vector3.new(0, 0, -v.trailWidth / 2)
	attA.Parent = part
	local attB = Instance.new("Attachment")
	attB.Name = "TsinelasRibbonB"
	attB.Position = Vector3.new(0, 0, v.trailWidth / 2)
	attB.Parent = part
	local ribbon = Instance.new("Trail")
	ribbon.Name = "TsinelasRibbon"
	ribbon.Attachment0 = attA
	ribbon.Attachment1 = attB
	ribbon.FaceCamera = true
	ribbon.Lifetime = math.max(0.15, v.trailLifetime * VfxScale.cosmetic())
	ribbon.Color = ColorSequence.new(v.trailColorStart, v.trailColorEnd)
	ribbon.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, v.trailTransparencyIn),
		NumberSequenceKeypoint.new(1, 1),
	})
	ribbon.Enabled = VfxScale.cosmetic() > 0
	ribbon.Parent = part
	local entry: { part: BasePart, conn: RBXScriptConnection? } = { part = part, conn = nil }
	local elapsed = 0
	entry.conn = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if activeSlippers[casterId] == nil or elapsed >= flightT then
			tsinelasCleanup(casterId) -- flight over: ribbon fades via trailLifetime
			return
		end
		local pos = TsinelasArc.position(origin, v0, elapsed)
		part.CFrame = CFrame.new(pos) * CFrame.fromAxisAngle(axis, math.rad(v.spinRate) * elapsed)
	end)
	activeSlippers[casterId] = entry
end

-- Impact star: one-shot burst plus an eased ground ring pop at the position
-- the server reported. Fires for hits; misses get the burst without sound.
local function spawnStarBurst(at: Vector3, withSound: boolean)
	local sk = Config.Skills.RS_03
	if sk == nil then
		return
	end
	local v = sk.vfx
	local anchor = Instance.new("Part")
	anchor.Name = "TsinelasImpact"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(at)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Parent = Workspace
	local att = Instance.new("Attachment")
	att.Parent = anchor
	local stars = Instance.new("ParticleEmitter")
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.Rate = 0 -- burst only, never a stream (mobile particle budget)
	stars.Lifetime = NumberRange.new(v.starLife)
	stars.Speed = NumberRange.new(v.starSpeedMin, v.starSpeedMax)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.Acceleration = Vector3.new(0, -6, 0) -- sparks settle, they do not float
	stars.Color = ColorSequence.new(v.starColor)
	stars.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, v.starSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	stars.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	stars.Parent = att
	local burst = VfxScale.count(v.impactCount)
	if burst > 0 then
		stars:Emit(burst)
	end
	spawnGroundRing(at, v.starSize * 2, sk.params.projectileRadius * 2, v.impactRingTime)
	if withSound then
		playSkillSound(anchor, sk.sounds.impact)
	end
	Debris:AddItem(anchor, 2) -- cleanup margin only, not a gameplay number
end

-- Shared entry for every server SkillVFX with skillId RS_03. Cast spawns the
-- slipper on all clients; impact/miss retires it early and pops the star.
local function playTsinelasFX(payload: any)
	local sk = Config.Skills.RS_03
	if sk == nil then
		return
	end
	if typeof(payload.caster) ~= "number" then
		return
	end
	local casterId: number = payload.caster
	local phase = if typeof(payload.phase) == "string" then payload.phase else "cast"
	local dir = if typeof(payload.dir) == "Vector3" then payload.dir else Vector3.new(0, 0, -1)
	if phase == "cast" then
		local caster = Players:GetPlayerByUserId(casterId)
		local char = caster and caster.Character
		if char == nil then
			return
		end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not (hrp and hrp:IsA("BasePart")) then
			return
		end
		local origin = if typeof(payload.origin) == "Vector3"
			then payload.origin
			else (hrp :: BasePart).Position
		if typeof(payload.target) ~= "Vector3" then
			return -- server always sends the clamped target; no arc without it
		end
		spawnSlipper(casterId, origin, payload.target, dir)
		playSkillSound(hrp :: BasePart, sk.sounds.throw)
		playSkillSound(hrp :: BasePart, sk.sounds.whoosh)
		if casterId == LocalPlayer.UserId then
			debugPrint("RS_03 cast rendered (slipper arc)") -- TODO: remove before submission
		end
		return
	end
	if phase == "impact" or phase == "miss" then
		tsinelasCleanup(casterId)
		if typeof(payload.hitPos) ~= "Vector3" then
			return
		end
		spawnStarBurst(payload.hitPos, phase == "impact")
		if casterId == LocalPlayer.UserId or phase == "impact" then
			debugPrint("RS_03 " .. phase .. " rendered (star burst)") -- TODO: remove before submission
		end
	end
end

-- TEMP (T18): hold G to aim RS_03 until T17 draft owns skill selection.
-- The throw dir reads the camera look flattened to XZ, with HRP facing
-- fallback. The target point comes from a camera raycast to ground or
-- surface, clamped to range by the shared arc module. Same logic on
-- keyboard, gamepad, and mobile: all platforms aim with the camera.
-- Read only: aiming never writes camera state, so it cannot fight the
-- TargetLock assist or the RS_01 camera feel.
-- Returns the throw dir, the clamped target, and true when the aim was
-- limited (clamped to max range). Nil triple when unknown.
local function tsinelasAim(): (Vector3?, Vector3?, boolean)
	if not Humanoid or not HRP then
		return nil, nil, false
	end
	local sk = Config.Skills.RS_03
	if sk == nil then
		return nil, nil, false
	end
	local cam = Workspace.CurrentCamera
	local flat: Vector3? = nil
	if cam then
		local look = cam.CFrame.LookVector
		local f = Vector3.new(look.X, 0, look.Z)
		if f.Magnitude >= 0.01 then
			flat = f.Unit
		end
	end
	if flat == nil then
		local face = HRP.CFrame.LookVector
		local ff = Vector3.new(face.X, 0, face.Z)
		if ff.Magnitude >= 0.01 then
			flat = ff.Unit
		end
	end
	if flat == nil then
		return nil, nil, false
	end
	-- Origin rule shared with the server: root center pushed two studs along
	-- the throw dir, so the indicator solves from the same x0.
	local origin = HRP.Position + Vector3.new(0, sk.params.launchHeight, 0) + flat * 2
	local desired: Vector3? = nil
	if cam then
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { Character }
		rayParams.IgnoreWater = true
		local hit = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * sk.vfx.aimRayLength, rayParams)
		if hit then
			desired = hit.Position
		end
	end
	if desired == nil then
		-- No surface in view: max range along the look, dropped to the
		-- ground under that point (origin height when none is found).
		local farXZ = origin + flat * sk.range
		local downParams = RaycastParams.new()
		downParams.FilterType = Enum.RaycastFilterType.Exclude
		downParams.FilterDescendantsInstances = { Character }
		downParams.IgnoreWater = true
		local ground = Workspace:Raycast(farXZ + Vector3.new(0, 2, 0), Vector3.new(0, -80, 0), downParams)
		if ground then
			desired = Vector3.new(farXZ.X, ground.Position.Y, farXZ.Z)
		else
			desired = Vector3.new(farXZ.X, origin.Y, farXZ.Z)
		end
	end
	local clamped = TsinelasArc.clampTarget(origin, desired, sk.range)
	local limited = Vector3.new(clamped.X - desired.X, 0, clamped.Z - desired.Z).Magnitude > 0.01
	return flat, clamped, limited
end

-- Same gates as the cast: aiming is only entered and only fires while a
-- throw right now would be valid.
local function tsinelasCanCast(): boolean
	local mode = LocalPlayer:GetAttribute("HRushGameMode")
	if mode == "AgawanNgPanyo" or mode == "SecretHunt" then return false end
	if not roundLive or inputLocked then
		return false
	end
	if isStunned() then
		return false -- stunned: aim exits through the upkeep cancel
	end
	if roll.active or vault.active then
		return false
	end
	if tsinelasPending or tsinelasCooldownLeft > 0 then
		return false
	end
	if not Humanoid or not HRP then
		return false
	end
	return true
end

local function tsinelasHideAim()
	for _, dot in tsinelasAimDots do
		if dot.Parent ~= nil then
			dot:Destroy()
		end
	end
	table.clear(tsinelasAimDots)
	local marker = tsinelasAimMarker
	tsinelasAimMarker = nil
	if marker ~= nil and marker.Parent ~= nil then
		marker:Destroy()
	end
end

local function tsinelasCancelAim(reason: string)
	if not tsinelasAiming then
		return
	end
	tsinelasAiming = false
	tsinelasAimHoldLeft = 0
	tsinelasHideAim()
	tsinelasRestoreCamera() -- every aim exit restores the camera
	pushAttributes(true) -- UI clears the aiming border at once
	debugPrint("RS_03 aim cancelled (" .. reason .. ")") -- TODO: remove before submission
end

-- ── RS_03 first person aim camera ─────────────────────────────────────────
-- While aiming, the camera eases into first person and back out on exit.
-- Technique: a Scriptable blend at Camera priority + 2 (above the
-- TargetLock assist and the RS_01 shake), then a handoff to the default
-- camera with zoom forced to first person, so mouse, stick, and touch all
-- look natively with no custom look code. The assist backs out on its own
-- while CameraType is Scriptable and resumes on the next lock action.
-- One cleanup function restores everything; cancel and release call it,
-- so every aiming exit is covered. The character never turns: aim uses
-- the camera vector and movement is untouched.
local AIMCAM_BIND = "TsinelasAimCam"
type AimCamSaved = {
	cameraType: Enum.CameraType,
	cameraCFrame: CFrame,
	fieldOfView: number,
	maxDistance: number,
	mouseBehavior: Enum.MouseBehavior,
	mouseSensitivity: number,
}
local aimCamActive = false -- an aim session captured state
local aimCamBound = false -- render step bound
local aimCamAlpha = 0.0 -- 0 third person, 1 first person
local aimCamTarget = 0 -- 0 exit, 1 first person
local aimCamStart = 0.0 -- alpha at retarget
local aimCamT = 0.0 -- time since retarget
local aimCamFrom: CFrame? = nil -- live pose at retarget
local aimCamFromRoot: Vector3? = nil -- root pos at entry
local aimCamSaved: AimCamSaved? = nil
local aimReticle: TextLabel? = nil

-- Head pose with the live look direction, so mouse, stick, and touch keep
-- steering through the transition.
local function aimCamHeadPose(): CFrame?
	local cam = Workspace.CurrentCamera
	if cam == nil or Character == nil then
		return nil
	end
	local headPos: Vector3? = nil
	local head = Character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		headPos = head.Position
	elseif HRP then
		headPos = HRP.Position + Vector3.new(0, 2, 0)
	end
	if headPos == nil then
		return nil
	end
	return CFrame.new(headPos, headPos + cam.CFrame.LookVector)
end

-- Client-side head fade so the camera never clips inside the skull. The
-- slipper and the aim dots live in Workspace, so they stay visible.
local function aimCamApplyFade(alpha: number)
	if Character == nil then
		return
	end
	for _, d in Character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = alpha
		end
	end
end

local function aimCamUnbind()
	if aimCamBound then
		RunService:UnbindFromRenderStep(AIMCAM_BIND)
		aimCamBound = false
	end
end

-- Single cleanup: restores every captured state. Safe to call when idle.
local function tsinelasRestoreCamera()
	local saved = aimCamSaved
	aimCamSaved = nil
	aimCamActive = false
	aimCamUnbind()
	aimCamApplyFade(0)
	local cam = Workspace.CurrentCamera
	if saved ~= nil and cam ~= nil then
		-- Return to the entry pose translated by how far the player moved
		-- during the aim, so walking aimers do not snap back.
		local restorePose = saved.cameraCFrame
		if aimCamFromRoot ~= nil and HRP then
			restorePose = restorePose + (HRP.Position - aimCamFromRoot)
		end
		cam.CameraType = saved.cameraType
		cam.CFrame = restorePose
		cam.FieldOfView = saved.fieldOfView
		LocalPlayer.CameraMaxDistance = saved.maxDistance
	end
	if saved ~= nil then
		UserInputService.MouseBehavior = saved.mouseBehavior
		UserInputService.MouseDeltaSensitivity = saved.mouseSensitivity
	end
	aimCamFromRoot = nil
	if aimReticle ~= nil and aimReticle.Parent ~= nil then
		aimReticle.Visible = false
	end
end

local function aimCamStep(dt: number)
	local cam = Workspace.CurrentCamera
	local cfg = Config.UI.TsinelasCam
	if cam == nil then
		return
	end
	local dur = if aimCamTarget == 1 then cfg.InTime else cfg.OutTime
	aimCamT += dt
	local raw = math.clamp(aimCamT / math.max(dur, 0.01), 0, 1)
	local eased: number
	if aimCamTarget == 1 then
		eased = 1 - (1 - raw) * (1 - raw) -- ease out
	else
		eased = if raw < 0.5 -- ease in out
			then 2 * raw * raw
			else 1 - (-2 * raw + 2) * (-2 * raw + 2) / 2
	end
	aimCamAlpha = aimCamStart + (aimCamTarget - aimCamStart) * eased
	local fromPose = aimCamFrom
	if fromPose == nil then
		return
	end
	local goal = aimCamHeadPose()
	if goal == nil then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = fromPose:Lerp(goal, aimCamAlpha)
	aimCamApplyFade(aimCamAlpha)
	if raw >= 1 then
		if aimCamTarget == 1 then
			-- Hand off to the default camera locked in first person.
			cam.CameraType = Enum.CameraType.Custom
			LocalPlayer.CameraMaxDistance = cfg.FirstPersonDistance
			aimCamUnbind()
		else
			tsinelasRestoreCamera()
		end
	end
end

local function aimCamEnsureReticle()
	if aimReticle ~= nil then
		return
	end
	local cfg = Config.UI.TsinelasCam
	local guiParent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if guiParent == nil then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TsinelasAimGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Parent = guiParent
	local dot = Instance.new("TextLabel")
	dot.Name = "AimReticle"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(cfg.ReticleSizePx, cfg.ReticleSizePx)
	dot.BackgroundTransparency = 1
	dot.Font = Enum.Font.GothamBold
	dot.TextSize = cfg.ReticleSizePx
	dot.Text = "+"
	dot.TextColor3 = Config.Skills.RS_03.vfx.aimColor
	dot.TextStrokeTransparency = 0.5
	dot.Visible = false
	dot.Parent = gui
	aimReticle = dot
end

local function tsinelasAimCamTo(target: number)
	local cfg = Config.UI.TsinelasCam
	if not cfg.Enabled or VfxScale.reducedCamera() then
		-- Aim stays third person (reduced camera effects or cam disabled):
		-- dots, marker, and center reticle still telegraph the throw.
		aimCamEnsureReticle()
		if aimReticle ~= nil then
			aimReticle.Visible = true
		end
		return
	end
	local cam = Workspace.CurrentCamera
	if cam == nil or Character == nil then
		return
	end
	if not aimCamActive then
		-- Capture once per aim session; the single cleanup restores this.
		aimCamSaved = {
			cameraType = cam.CameraType,
			cameraCFrame = cam.CFrame,
			fieldOfView = cam.FieldOfView,
			maxDistance = LocalPlayer.CameraMaxDistance,
			mouseBehavior = UserInputService.MouseBehavior,
			mouseSensitivity = UserInputService.MouseDeltaSensitivity,
		}
		aimCamActive = true
		if HRP then
			aimCamFromRoot = HRP.Position
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseDeltaSensitivity = cfg.MouseSensitivity
		if cfg.FovDelta ~= 0 then
			cam.FieldOfView = cam.FieldOfView + cfg.FovDelta
		end
	end
	-- Retarget from the live pose: mid-way reversals never snap.
	aimCamFrom = cam.CFrame
	aimCamStart = aimCamAlpha
	aimCamT = 0
	aimCamTarget = target
	if not aimCamBound then
		RunService:BindToRenderStep(AIMCAM_BIND, Enum.RenderPriority.Camera.Value + 2, aimCamStep)
		aimCamBound = true
	end
	aimCamEnsureReticle()
	if aimReticle ~= nil then
		aimReticle.Visible = true
	end
end

-- Aim indicator: dots along the shared arc plus a landing marker at the end.
-- The march raycasts every dot segment exactly like the server hit test, so
-- a wall cuts the indicator where it cuts the flight, in the blocked color.
-- 12 dots plus 1 marker, 0 emitters: inside Performance budget.
local function tsinelasUpdateAim()
	if #tsinelasAimDots == 0 or tsinelasAimMarker == nil then
		return
	end
	if not HRP then
		return
	end
	local sk = Config.Skills.RS_03
	if sk == nil then
		return
	end
	local v = sk.vfx
	local dir, target, limited = tsinelasAim()
	if dir == nil or target == nil then
		return
	end
	local origin = HRP.Position + Vector3.new(0, sk.params.launchHeight, 0) + dir * 2
	local v0, flightT, short = TsinelasArc.solveArc(origin, target)
	local count = VfxScale.telegraphCount(v.aimDotCount)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { Character }
	rayParams.IgnoreWater = true
	local blocked = short -- unreachable height shows the short color
	local prev = origin
	local placed = 0
	for i = 1, count do
		local p = TsinelasArc.position(origin, v0, flightT * i / count)
		local wall = Workspace:Raycast(prev, p - prev, rayParams)
		if wall ~= nil then
			p = wall.Position
			blocked = true
		end
		placed += 1
		local dot = tsinelasAimDots[placed]
		dot.CFrame = CFrame.new(p)
		dot.Color = if blocked then v.aimBlockedColor else v.aimColor
		prev = p
		if blocked then
			break
		end
	end
	-- Park unused dots past a wall cut far below the map.
	for j = placed + 1, #tsinelasAimDots do
		tsinelasAimDots[j].CFrame = CFrame.new(0, -1000, 0)
	end
	local marker = tsinelasAimMarker
	if marker ~= nil then
		marker.CFrame = CFrame.new(prev.X, prev.Y + 0.12, prev.Z) * CFrame.Angles(0, 0, math.rad(90))
		marker.Color = if blocked then v.aimBlockedColor else v.aimColor
	end
	-- Center reticle follows the same alert rule: red when the aim is
	-- clamped to max range or too high to reach.
	if aimReticle ~= nil then
		aimReticle.TextColor3 = if blocked or limited then v.aimBlockedColor else v.aimColor
	end
end

local function tsinelasShowAim()
	tsinelasHideAim()
	if not Humanoid or not HRP then
		return
	end
	local sk = Config.Skills.RS_03
	if sk == nil then
		return
	end
	local v = sk.vfx
	local dotCount = VfxScale.telegraphCount(v.aimDotCount)
	for _ = 1, dotCount do
		local dot = Instance.new("Part")
		dot.Name = "TsinelasAimDot"
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(v.aimDotSize, v.aimDotSize, v.aimDotSize)
		dot.Color = v.aimColor
		dot.Material = Enum.Material.Neon
		dot.Transparency = v.aimTransparency
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Parent = Workspace
		table.insert(tsinelasAimDots, dot)
	end
	local marker = Instance.new("Part")
	marker.Name = "TsinelasAimMarker"
	marker.Shape = Enum.PartType.Cylinder
	marker.Size = Vector3.new(0.2, v.aimMarkerSize, v.aimMarkerSize)
	marker.Color = v.aimColor
	marker.Material = Enum.Material.Neon
	marker.Transparency = v.aimTransparency
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.CFrame = CFrame.new(0, -1000, 0) * CFrame.Angles(0, 0, math.rad(90))
	marker.Parent = Workspace
	tsinelasAimMarker = marker
	tsinelasUpdateAim()
end

local function tsinelasBeginAim()
	if tsinelasAiming or not tsinelasCanCast() then
		return -- on cooldown, busy, or round not live: ignore the press
	end
	tsinelasAiming = true
	tsinelasAimHoldLeft = Config.Skills.RS_03.params.maxHoldTime
	tsinelasShowAim()
	tsinelasAimCamTo(1) -- ease into first person
	pushAttributes(true) -- UI shows the aiming border at once
	debugPrint("RS_03 aiming") -- TODO: remove before submission
end

-- Release path: exit aiming first, then throw only if the cast is still
-- valid. A release after cooldown started, stun, or round end cancels
-- silently without firing.
local function tsinelasReleaseThrow()
	if not tsinelasAiming then
		return
	end
	tsinelasAiming = false
	tsinelasAimHoldLeft = 0
	tsinelasHideAim()
	tsinelasRestoreCamera() -- every throw exit restores the camera
	pushAttributes(true) -- UI clears the aiming border at once
	if not tsinelasCanCast() then
		debugPrint("RS_03 release no longer valid; cancelled") -- TODO: remove before submission
		return
	end
	local dir, target = tsinelasAim()
	if dir == nil or target == nil then
		return
	end
	tsinelasPending = true
	tsinelasPendingLeft = Config.Skills.RS_03.params.pendingTimeout
	RequestSkill:FireServer("RS_03", dir, target)
	debugPrint("RS_03 request sent (aimed)") -- TODO: remove before submission
end

-- ── Stun enter/exit (server-owned HRushStunned) ──────────────────────────────
-- Enter cancels every movement state through the existing exit paths, so no
-- dash, slide, roll, flight, aim, or camera state outlives the stun. Exit hands
-- speed back to applySpeed, which recomputes the role speed from scratch.
-- The server clears WalkSpeed to its stored value first and nils the
-- attribute second; both orders land on the same role speed here.
local function onStunChanged()
	if isStunned() then
		momentum.controller.hardZero("stun")
		cancelDash()
		if isSliding then
			endSlide()
		end
		endRoll()
		vault.finish(false, "stunned", false)
		endSkillFlight(false) -- covers windup, queued takeoff, and flight
		tsinelasCancelAim("stun")
		if Humanoid then
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		end
		applySpeed() -- hold 0 at once, ahead of the next heartbeat
		pushAttributes(true)
		debugPrint("stunned: actions cancelled, speed held at 0") -- TODO: remove before submission
	else
		if Humanoid then
			Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		applySpeed() -- normal path: 16/21xboost Runner, 18 Taya
		pushAttributes(true)
		debugPrint("stun cleared: speed recomputed") -- TODO: remove before submission
	end
end

LocalPlayer:GetAttributeChangedSignal("HRushStunned"):Connect(onStunChanged)

local function launchSkill()
	local sk = Config.Skills[skillId]
	if sk == nil or not Humanoid or not HRP then
		cancelWindup()
		return
	end
	if isStunned() then
		cancelWindup() -- stunned mid-windup: never take off
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
	local vh = (sk.params.distance * Mv.SpeedScale) / sk.params.airtime

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
	if LocalPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo"
		and ReplicatedStorage:GetAttribute("HRushPanyoCarrierUserId") == LocalPlayer.UserId then
		return
	end
	if not roundLive or inputLocked then
		return -- round gate (countdown, lobby, round end)
	end
	if isStunned() then
		return -- stunned: no new actions (server would deny anyway)
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
	if isDashing or isSliding or roll.active or vault.active then
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
		if payload.skillId == "RS_03" then
			tsinelasPending = false
			tsinelasCancelAim("deny")
			debugPrint("RS_03 denied by server (pending cleared)") -- TODO: remove before submission
			return
		end
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
	-- RS_03 approval: nothing to animate locally (the server simulates the
	-- projectile). Start the local cooldown mirror and clear pending.
	if payload.skillId == "RS_03" then
		tsinelasPending = false
		tsinelasCancelAim("approved")
		local sk = Config.Skills.RS_03
		if sk then
			tsinelasCooldownLeft = sk.cooldown
		end
		pushAttributes(true)
		debugPrint("RS_03 approved; local CD started") -- TODO: remove before submission
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
	if payload.skillId == "RS_03" then
		playTsinelasFX(payload)
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
	if vault.cooldown > 0 then
		vault.cooldown = math.max(0, vault.cooldown - dt)
	end
	vault.probe = math.max(0, vault.probe - dt)
	if vault.probe <= 0 then
		vault.probe = Mv.VaultProbeInterval
		vault.tryStart()
	end
	if skillCooldownLeft > 0 then
		skillCooldownLeft = math.max(0, skillCooldownLeft - dt)
	end
	if tsinelasCooldownLeft > 0 then
		tsinelasCooldownLeft = math.max(0, tsinelasCooldownLeft - dt)
	end
	if tsinelasPending then
		tsinelasPendingLeft = math.max(0, tsinelasPendingLeft - dt)
		if tsinelasPendingLeft <= 0 then
			tsinelasPending = false -- a lost server reply must never wedge input
		end
	end
	if tsinelasAiming then
		tsinelasAimHoldLeft = math.max(0, tsinelasAimHoldLeft - dt)
		if tsinelasAimHoldLeft <= 0 then
			tsinelasCancelAim("hold expired")
		end
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
	if roll.inputExpiresAt > 0 then
		if os.clock() > roll.inputExpiresAt then
			roll.inputExpiresAt = 0
			roll.inputAt = 0
		elseif Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air and not roll.active then
			-- StateChanged and FloorMaterial can settle in either order. Consume
			-- the same buffered input once both agree the character is grounded.
			performRoll()
		end
	end
	if roll.active then
		roll.timer += dt
		roll.speed = momentum.rules.speed(roll.baseSpeed, 1, 1, momentum.controller.value())
		if HRP and HRP.Parent then
			Humanoid.WalkSpeed = roll.speed
			local velocity = HRP.AssemblyLinearVelocity
			HRP.AssemblyLinearVelocity = Vector3.new(
				roll.dir.X * roll.speed,
				velocity.Y,
				roll.dir.Z * roll.speed
			)
		end
		if roll.timer >= Mv.RollDuration then
			endRoll()
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

		tickCooldowns(dt)
		updateSprint()
		tickSprintAnim()
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
			handleSlideInput()
		end
		if skillRequested then
			skillRequested = false
			requestSkill()
		end
		if tsinelasAiming then
			if not tsinelasCanCast() then
				tsinelasCancelAim("no longer valid")
			else
				tsinelasUpdateAim()
			end
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
			momentum.controller.hardZero("role changed")
			-- Tag swap cleanup: cancel movement visuals and the prior sprint window.
			if isSliding then
				endSlide()
			end
			if isDashing then
				cancelDash()
			end
			endRoll()
			vault.finish(false, "role changed", false)
			isSprinting = false
			role = newRole
		end
	end
	if typeof(state) == "string" then
		roundLive = (state == "MS_04")
		lobbyWarmup = (state == "MS_01")
		inputLocked = (state == "MS_03") or (not roundLive and not lobbyWarmup)
		if state == "MS_03" then
			-- Countdown: lock in place and clear earned sprint.
			isSprinting = false
		end
		if not roundLive then
			momentum.controller.hardZero("round ended")
			-- End active movement and skill-flight states when the round is not live.
			if isSliding then
				endSlide()
			end
			if isDashing then
				cancelDash()
			end
			endRoll()
			vault.finish(false, "round ended", false)
			if skillFlightLeft > 0 then
				endSkillFlight(false)
			end
			cancelWindup()
			skillPendingVelocity = nil -- a queued takeoff must not fire after round end
			reportLanded() -- windup cancelled mid-approval: still clear IsAirborne
			skillPending = false -- round over: drop any request still in flight
			tsinelasPending = false -- round over: drop any RS_03 request too
			tsinelasHeld = false
			tsinelasCancelAim("round end")
			for id, _ in activeSlippers do
				tsinelasCleanup(id) -- round over: retire cosmetic slippers
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
		momentum.controller.hardZero("tagged")
		-- We are the new Taya: no boost, Taya speed applies via role update.
		boostLeft = 0.0
		if isSliding then
			endSlide()
		end
		endRoll()
		vault.finish(false, "tagged", false)
		applySpeed()
		pushAttributes(true)
	elseif payload.taggerId == myId and role == "Runner" then
		momentum.controller.hardZero("tagged")
		-- We were Taya and just tagged someone: ex-Taya boost starts now.
		boostLeft = Mv.PostTagSpeedBoostDuration
		applySpeed()
		pushAttributes(true)
	end
end)

-- ── PC Keyboard bindings ──────────────────────────────────────────────────────
-- Move WASD, Dash Q, Slide or landing roll C. Sprint is earned automatically.
local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	local kc = input.KeyCode
	if kc == Enum.KeyCode.Q then
		dashRequested_KB = true
	elseif kc == Enum.KeyCode.C then
		slideRequested_KB = true
	elseif kc == Enum.KeyCode.E then
		skillRequested = true -- Skill cast (UI/UX Spec §4)
	elseif kc == TSINELAS_KEY then
		tsinelasHeld = true -- TEMP (T18): RS_03 test key until T17 draft
		tsinelasBeginAim()
	elseif kc == TSINELAS_CANCEL_KEY then
		tsinelasCancelAim("X key") -- TEMP (T18): explicit aim cancel
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	local kc = input.KeyCode
	if kc == TSINELAS_KEY then
		tsinelasHeld = false
		tsinelasReleaseThrow()
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)
-- A release outside the window never fires InputEnded: cancel instead of
-- wedging the aim state.
UserInputService.WindowFocusReleased:Connect(function()
	tsinelasHeld = false
	tsinelasCancelAim("focus lost")
end)

-- ── Gamepad bindings (UI/UX Spec §4) ─────────────────────────────────────────
-- Dash:   B (ButtonB). Slide: Right bumper (ButtonR1). Skill: X (ButtonX).
-- Diskarte Y (ButtonY) is owned by UIController (T22).
local DASH_GP_ACTION = "HRUSH_Dash_GP"
local SLIDE_GP_ACTION = "HRUSH_Slide_GP"

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

-- TEMP (T18): RS_03 hold-to-aim until T17 draft. ButtonA is the only free
-- face button (X skill, B dash, Y Diskarte, bumpers and triggers reserved
-- by the spec for lock and tag). Same three calls as the G key.
local TSINELAS_GP_ACTION = "HRUSH_Tsinelas_GP"
ContextActionService:BindAction(TSINELAS_GP_ACTION, function(_name, state, _obj)
	if state == Enum.UserInputState.Begin then
		tsinelasBeginAim()
	elseif state == Enum.UserInputState.End then
		tsinelasReleaseThrow()
	elseif state == Enum.UserInputState.Cancel then
		tsinelasCancelAim("gamepad cancel")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonA)

-- ── Mobile touch buttons (UI/UX Spec §4) ───────────────────────────────────────
-- ContextActionService creates on-screen Dash / Slide / Skill buttons.
-- They fire BindableEvents in ReplicatedStorage; we hook them once they exist
-- (retry loop covers UIController loading after us).
local mobileHooked = false
local function hookMobileBindables()
	if mobileHooked then
		return
	end
	mobileHooked = true

	-- Touch buttons via ContextActionService (creates touch UI automatically).
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
			local tsinelasBe = ReplicatedStorage:FindFirstChild("MobileTsinelas")
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
			-- RS_03 touch bridge (UIController touch button): one event
			-- carrying Begin/End/Cancel, same three calls as G and gamepad.
			if tsinelasBe and tsinelasBe:IsA("BindableEvent") then
				tsinelasBe.Event:Connect(function(action: unknown)
					if typeof(action) ~= "string" then
						return
					end
					if action == "Begin" then
						tsinelasBeginAim()
					elseif action == "End" then
						tsinelasReleaseThrow()
					elseif action == "Cancel" then
						tsinelasCancelAim("touch cancel")
					end
				end)
			end
			if dashBe or slideBe or skillBe or tsinelasBe then
				break
			end
			task.wait(0.2)
		end
	end)

	-- Settings-opened bridge (LobbyUI-owned event): opening the settings panel
	-- cancels RS_03 aim through the existing exit path, so camera, mouse lock,
	-- FOV, and body transparency all restore. Separate retry: LobbyUI may load
	-- after this controller.
	task.spawn(function()
		for _ = 1, 50 do
			local ev = ReplicatedStorage:FindFirstChild("HRushSettingsOpened")
			if ev and ev:IsA("BindableEvent") then
				ev.Event:Connect(function()
					tsinelasCancelAim("settings opened")
				end)
				break
			end
			task.wait(0.2)
		end
	end)
end

-- ── Character lifecycle ───────────────────────────────────────────────────────
function vault.onCharacterAdded(char: Model)
	Character = char
	-- Cancel any in-flight dash tied to the old character.
	stopDashFX(false)
	if dashConn then
		dashConn:Disconnect()
		dashConn = nil
	end
	if vault.connection then
		vault.connection:Disconnect()
		vault.connection = nil
	end
	Humanoid = char:WaitForChild("Humanoid") :: Humanoid
	HRP = char:WaitForChild("HumanoidRootPart") :: BasePart
	loadAnimTracks() -- sprint/slide tracks (rebuilt per respawn)

	-- Reset state on respawn
	isSprinting = false
	isDashing = false
	dashCooldownLeft = 0.0
	isSliding = false
	slideCooldownLeft = 0.0
	slideTimer = 0.0
	slideHipHeight = 0.0
	if slideConn then
		slideConn:Disconnect()
		slideConn = nil
	end
	slideDir = Vector3.new(0, 0, -1)
	slideSpeed = 0.0
	slideAnimWarned = false -- new character: warn again if its clip will not play
	roll.active = false
	roll.inputExpiresAt = 0
	roll.inputAt = 0
	roll.timer = 0
	roll.dir = Vector3.new(0, 0, -1)
	roll.speed = 0
	roll.baseSpeed = 0
	momentum.controller.hardZero("respawn")
	vault.active = false
	vault.cooldown = 0
	vault.probe = 0
	vault.autoRotate = true
	vault.exitDir = Vector3.new(0, 0, -1)
	vault.exitSpeed = 0
	vault.variant = ""
	vault.boundaryObstacle = nil
	vault.boundaryLoggedAt = 0
	vault.rejectedObstacle = nil
	local standingFeetOffset = HRP.Size.Y * 0.5 + Humanoid.HipHeight
	print(string.format(
		"[Vault] standing feet offset %.2f studs (root half-height %.2f + HipHeight %.2f)",
		standingFeetOffset,
		HRP.Size.Y * 0.5,
		Humanoid.HipHeight
	))
	boostLeft = 0.0
	dashRequested_KB = false
	dashRequested_GP = false
	slideRequested_KB = false
	slideRequested_GP = false
	skillCooldownLeft = 0
	skillFlightLeft = 0
	skillRequested = false
	skillPending = false
	tsinelasHeld = false -- respawn drops any held G press
	tsinelasCancelAim("respawn")
	tsinelasPending = false
	tsinelasPendingLeft = 0
	-- The local cooldown mirror survives death like the server ledger does,
	-- so the slot cannot show ready early (deny stays the backstop).
	do
		local ids: { number } = {}
		for id, _ in activeSlippers do
			table.insert(ids, id)
		end
		for _, id in ids do
			tsinelasCleanup(id) -- new character: retire stale cosmetic slippers
		end
	end
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
	LocalPlayer:SetAttribute("HRushSkillFov", false)
	if skillPreviewRing then
		skillPreviewRing:Destroy()
		skillPreviewRing = nil
	end

	-- Shared landing detection: a buffered roll starts on the accepted landing
	-- transition. RS_01 still requires its own minimum airtime below.
	-- StateChanged IS a confirmed Humanoid event (checked against the engine
	-- API dump; the invalid ones were Landed and GetStateChangedSignal).
	if skillStateConn then
		skillStateConn:Disconnect()
		skillStateConn = nil
	end
	skillStateConn = Humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
		if roll.active and (new == Enum.HumanoidStateType.Freefall or new == Enum.HumanoidStateType.Jumping) then
			endRoll()
		end
		local landed = new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running
		if landed and roll.inputExpiresAt >= os.clock() then
			performRoll()
		end
		if skillFlightLeft <= 0 or skillFlightStartedAt == 0 then
			return -- not flying: normal ground states, ignore
		end
		local p = skillParams()
		local minAir = if p then p.minAirtime else 0.2
		if os.clock() - skillFlightStartedAt < minAir then
			return -- launch frames still touching ground: not a landing yet
		end
		if not landed then
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
		momentum.controller.hardZero("death")
		tsinelasHeld = false
		tsinelasCancelAim("death") -- death ends aiming and restores the camera
		stopSprintAnim()
		stopSlideAnim()
		stopDashAnim()
		endRoll()
		vault.finish(false, "character died", false)
		if isSliding then
			isSliding = false
		end
		if slideConn then
			slideConn:Disconnect()
			slideConn = nil
		end
		skillFlightLeft = 0 -- a flight cannot outlive its character
		skillPendingVelocity = nil
		skillWindupLeft = 0
		skillRecoveryLeft = 0
		skillPending = false
		skillFOVOn = false
		LocalPlayer:SetAttribute("HRushSkillFov", false)
		reportLanded() -- death mid-jump still clears server IsAirborne
		if dashConn then
			dashConn:Disconnect()
			dashConn = nil
		end
		isDashing = false
		stopDashFX(false)
		boostLeft = 0.0
	end)

	-- Diagnostic marker: if this line is missing from the log, onCharacterAdded
	-- aborted before finishing (check CreatorError above it).
	print("[MovementController] character attached — heartbeat + input hooks live")
end

momentum.controller.start()

if LocalPlayer.Character then
	task.spawn(vault.onCharacterAdded, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(vault.onCharacterAdded)

local function finiteVFXVector(value: any): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X and value.Y == value.Y and value.Z == value.Z
		and math.abs(value.X) < 100000 and math.abs(value.Y) < 100000 and math.abs(value.Z) < 100000
end

DashVFXEvent.OnClientEvent:Connect(function(userId: any, direction: any, startPosition: any, serverTime: any)
	if typeof(userId) ~= "number" or userId % 1 ~= 0 or userId == LocalPlayer.UserId then
		return
	end
	if not finiteVFXVector(direction) or not finiteVFXVector(startPosition) then
		return
	end
	if typeof(serverTime) ~= "number" or serverTime ~= serverTime or math.abs(serverTime) == math.huge then
		return
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if math.abs(direction.Y) > 0.05 or flat.Magnitude < 0.95 or flat.Magnitude > 1.05 then
		return
	end
	local age = Workspace:GetServerTimeNow() - serverTime
	if age < -0.1 or age >= Mv.DashVFX.TotalTime then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return
	end
	WindDash.Play(character, flat.Unit, startPosition, math.max(0, age), VfxScale.cosmetic())
end)

-- LandingController is the single client owner for normal landing classification,
-- landing animation, impact events, and the short hard-landing speed penalty.
vault.landing = require(script.Parent:WaitForChild("LandingController"))
vault.landing.start({
	onPenaltyChanged = applySpeed,
})

-- AirMovement owns normal jump buffering, coyote time, falling force, and
-- air caps. Slide remains owned here, so the module asks this controller to
-- close Slide and returns the configured retained horizontal velocity.
require(script.Parent:WaitForChild("AirMovement")).start({
	onSlideJump = function(): Vector3?
		if not isSliding or not HRP or not HRP.Parent then
			return nil
		end
		local velocity = HRP.AssemblyLinearVelocity
		local retained = Vector3.new(velocity.X, 0, velocity.Z) * Mv.SlideJumpKeepPct
		endSlide()
		return retained
	end,
	tryVault = function(): boolean
		return vault.tryStart()
	end,
})

-- Animation preload (slide load fix): streaming can fail the first
-- LoadAnimation right after spawn, which used to leave slideTrack nil with
-- only a warn. Preloading once at startup puts the bytes local before any
-- character needs them. Failure here only warns; loadAnimTracks plus its
-- delayed retry remain the backstops.
task.spawn(function()
	local ok = pcall(function()
		local anims: { Animation } = {}
		for _, definition in { Animations.Sprint, Animations.SlideLoop, Animations.Dash, Animations.Roll, Animations.Vault } do
			local id = resolveAnimationId(definition)
			if id then
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				table.insert(anims, anim)
			end
		end
		if #anims > 0 then
			game:GetService("ContentProvider"):PreloadAsync(anims)
		end
		for _, anim in anims do
			anim:Destroy()
		end
	end)
	if not ok then
		warn("[MovementController] animation preload failed")
	end
end)

pushAttributes(true)
print("[MovementController] Loaded: T09 + Part 2 landing and Vault + RS_01 slice.")
