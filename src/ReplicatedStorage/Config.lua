--!strict
-- ReplicatedStorage/Config.lua
-- Owner: Project Owner
-- Responsibility: immutable shared gameplay and presentation tuning.
-- Task/spec: approved Pounce / Tag integration and Taya sprint revision, 2026-10-16.
-- Task/spec: movement upgrade Part 2 landing owner and chest-level Vault, approved 2026-10-16.

local Config = {}

Config.Movement = {
	RunnerWalkSpeed   = 16, -- [LOCKED GDD RM_01, DESIGN_LOCK F08]
	RunnerSprintSpeed = 21, -- [LOCKED GDD RM_02, DESIGN_LOCK F08]
	TayaSprintSpeed = 21, -- [LOCKED] Project-owner pounce sprint revision, 2026-10-16
	SpeedScale = 1.2, -- [SD] approved 2026-10-15; multiplies every movement speed and speed-derived distance (1 = locked bases)
	JumpPower = 50, -- [SD] existing Bootstrap value moved here without behavior change
	FallGravityMult = 1.6, -- [SD] Part 1 total gravity multiplier while falling
	TerminalFallSpeed = 100, -- [SD] Part 1 cap, above the measured 71.94 studs/s tallest-map drop
	AirSpeedCapMult = 1.15, -- [SD] Part 1 cap relative to effective Runner sprint speed
	FallGravityDebugMin = 1.0, -- [SD] Studio-only HRushDebugFallGravityMult lower bound
	FallGravityDebugMax = 3.0, -- [SD] Studio-only HRushDebugFallGravityMult upper bound
	AirControlDebugMin = 0.0, -- [SD] Studio-only HRushDebugAirControlPct lower bound
	AirControlDebugMax = 1.0, -- [SD] Studio-only HRushDebugAirControlPct upper bound
	SprintAccelTime = 0.25, -- [SD] Step 2 target, not live until the sprint ramp lands
	SprintFovBoost = 10, -- [SD] reserved; Phase 2 sprint FOV lives in Config.Camera.Effects.Sprint
	FovTweenTime = 0.2, -- [SD] reserved; Phase 2 sprint FOV easing lives in Config.Camera.Effects.Sprint
	SprintVfxMinSpeedPct = 0.9, -- [SD] share of effective sprint speed that starts the sprint camera widen
	StaminaMax         = 100,
	StaminaDrainRate   = 20,
	StaminaRegenRate   = 16, -- [SD] was 12; recharges one dash in ~1.9 s with the 0.6 s delay
	StaminaRegenDelay  = 0.6, -- [SD] was 1.0
	StaminaDepletedMin = 10,
	DashDistance           = 12,
	DashDuration           = 0.2,
	DashCooldown           = 1.5, -- [SD] was 6.0; stamina cost governs spam now
	DashStaminaCost        = 20, -- [SD] stamina per dash; 5 dashes empty a full tank
	DashPounceInvulnTime   = 0.15,
	DashSoundId            = "rbxassetid://115548807322300", -- [SD] dash whoosh (Pixabay Sound Effects, royalty-free, see ASSET_LOG)
	DashSoundVolume        = 0.7, -- [SD] dash whoosh volume 0-1
	SlideMinSpeedPct  = 0.85, -- [SD] Step 3 entry threshold as a share of effective sprint speed
	SlideStartMult    = 1.15, -- [SD] Step 3 target; current slide keeps SlideSpeedMult until rewritten
	SlideEndMult      = 0.45, -- [SD] Step 3 target speed at natural exit
	SlideDuration     = 1.0, -- [SD] current value retained; within the 0.9 to 1.1 second target
	SlideSteerRate    = 12, -- [SD] Step 3 target turn cap in degrees per second
	SlideCooldown     = 3.0, -- [SD] current behavior retained; Step 3 will tune post-exit cooldown
	SlideJumpKeepPct  = 0.85, -- [SD] Step 5 target retained speed for a slide-hop
	SlideCameraDip    = 0.65, -- [SD] Step 3 target camera dip in studs
	SlideFovKick      = 4, -- [SD] Step 3 target FOV kick in degrees
	SlideHitboxScale  = 0.5,
	SlideSpeedMult    = 1.25, -- [SD] aggressive escape entry boost; sign-off pending vs spec + pounce band
	SlideSteerLock    = true, -- [SD] heading fixed at entry; false = MoveDirection steers mid-slide
	SlideDustCount    = 12, -- [SD] heel dust burst on slide entry (dash pattern)
	SlideDustLifeMin  = 0.3, -- [SD] dust particle lifetime low (s)
	SlideDustLifeMax  = 0.5, -- [SD] dust particle lifetime high (s)
	SlideDustSpeedMin = 4, -- [SD] dust kick speed low (studs/s)
	SlideDustSpeedMax = 9, -- [SD] dust kick speed high (studs/s)
	SlideDustSize     = 0.7, -- [SD] dust particle start size (studs)
	SlideSoundId      = "rbxassetid://75817307201002", -- [SD] slide whoosh (see ASSET_LOG)
	SlideSoundVolume  = 0.7, -- [SD] slide whoosh volume 0-1
	RollWindow = 0.15, -- [SD] Batch C approved pre-landing input window in seconds
	RollDuration = 0.45, -- [SD] Batch C approved state duration matching HRush_Roll
	RollSpeedBonus = 0.10, -- [SD] Batch C approved bonus as a share of effective Runner sprint speed
	VaultMinH = 1.5, -- [SD] Part 2 minimum obstacle top above the character's current feet
	VaultMaxH = 3.5, -- [SD] Part 2 maximum obstacle top above the character's current feet
	VaultMaxAboveGround = 7.0, -- [SD] Part 2 absolute obstacle-top cap above ground below the character
	VaultMinDrop = 1.5, -- [SD] Part 2 minimum drop from obstacle top to the landing side
	VaultMinSpeedPct = 0.80, -- [SD] Part 2 entry threshold as a share of effective Runner sprint speed
	VaultSpeedVariantPct = 0.90, -- [SD] Part 2 SpeedVault threshold as a share of effective Runner sprint speed
	VaultSpeedKeepPct = 0.95, -- [SD] Part 2 share of entry speed kept on exit
	VaultDuration = 0.40, -- [SD] Batch D approved state duration matching HRush_Vault
	VaultCooldown = 0.25, -- [SD] Part 2 debounce against immediate retriggers
	VaultProbeInterval = 0.05, -- [SD] Batch D automatic contact probe interval in seconds
	VaultProbeDistance = 4.5, -- [SD] Batch D forward obstacle probe distance in studs
	VaultKneeHeight = 1.0, -- [SD] Batch D knee probe height above the feet in studs
	VaultWaistHeight = 2.5, -- [SD] Part 2 waist probe height above the current feet in studs
	VaultChestHeight = 3.75, -- [SD] Part 2 chest probe height above the current feet in studs
	VaultSpeedMaxDepth = 2.0, -- [SD] Part 2 maximum obstacle depth for SpeedVault
	VaultMaxDepth = 5.0, -- [SD] Part 2 maximum obstacle depth for any Vault
	VaultGeometryTolerance = 0.10, -- [SD] Part 2 contact-settling tolerance for height, depth, and drop rays
	VaultGroundProbeDepth = 20.0, -- [SD] Part 2 ground-below ray depth for airborne absolute-cap checks
	VaultCollisionBoxScale = 0.75, -- [SD] Part 2 root blockcast scale during the scripted arc
	VaultLandingNormalMin = 0.50, -- [SD] Part 2 minimum upward normal for an arc-end landing contact
	VaultLandingCollisionAlpha = 0.85, -- [SD] Part 2 earliest arc fraction that can settle on landing ground
	VaultBoundaryLogCooldown = 1.0, -- [SD] Part 2 throttle for repeated mantle-boundary diagnostics
	VaultTopInset = 0.10, -- [SD] Part 2 inward offset for the obstacle top-surface ray
	VaultTopProbeMargin = 1.0, -- [SD] Batch D top and landing ray margin in studs
	VaultLandingMargin = 1.5, -- [SD] Batch D landing distance beyond the obstacle edge in studs
	VaultLandingProbeDepth = 20.0, -- [SD] Part 2 landing-side ray depth in studs
	VaultClearance = 0.5, -- [SD] Batch D root arc clearance above the obstacle in studs
	VaultMaxTravelDistance = 8.0, -- [SD] Batch D maximum accepted scripted travel in studs
	VaultDirectionMinDot = 0.5, -- [SD] Batch D minimum agreement between request and observed travel
	CoyoteTime = 0.10, -- [SD] Part 1 live ledge-exit grace in seconds
	JumpBufferTime = 0.12, -- [SD] Part 1 live pre-landing input grace in seconds
	AirControlPct = 0.0, -- [SD] Part 2 committed takeoff direction; Studio override can compare 0.0 to 1.0
	LandBumpMax = 0.35, -- [SD] Step 7 target maximum camera offset in studs
	HardLandHeight = 12, -- [SD] Part 2 hard-landing fall-height threshold in studs
	HardLandPenaltyTime = 0.10, -- [SD] Part 2 hard-landing speed-penalty duration in seconds
	HardLandSpeedMult = 0.85, -- [SD] Part 2 hard-landing speed multiplier
	ServerSpeedTolerancePct = 0.15, -- [SD] passive horizontal speed tolerance
	ServerSampleWindow = 0.25, -- [SD] passive displacement observation window in seconds
	ServerDisplacementSlack = 2.0, -- [SD] per-window physics and replication slack in studs
	ServerCorrectionViolationThreshold = 4, -- [SD] reserved for Step 10; correction is disabled in Step 1
	ServerRequestWindow = 1.0, -- [SD] request rate-limit window in seconds
	ServerRequestRate = 12, -- [SD] maximum movement requests per window
	ServerCharacterWaitTimeout = 5.0, -- [SD] bounded respawn dependency wait in seconds
	ServerDirectionMinMagnitude = 0.05, -- [SD] lower bound for dash direction input
	ServerDirectionMaxMagnitude = 1.1, -- [SD] upper bound for dash direction input
	ServerLogViolationThreshold = 1, -- [SD] log the first observation or rejected request
	ServerTakeoffObservationTime = 0.35, -- [SD] Part 1 replication window for vertical takeoff samples
	ServerMaxAirTime = 2.0, -- [SD] Part 1 normal-air limit before tolerance; scripted skills and Vault are exempt
	ServerLogsEnabled = true, -- [SD] Studio telemetry for Steps 1 to 10; disable for release
	ServerCorrectionEnabled = false, -- [SD] Step 1 observes and logs only
	TayaSpeed         = 18, -- [LOCKED GDD TM_01]
	PostTagSpeedBoostMult     = 1.20,
	PostTagSpeedBoostDuration = 2.0,
	DashVFX = {
		Enabled          = true,
		TrailLifetime    = 0.35,
		BurstCount       = 16,
		ParticleLifetime = 0.30,
		ParticleSpeedMin = 8,
		ParticleSpeedMax = 18,
		ColorStart       = Color3.fromRGB(130, 225, 255),
		ColorEnd         = Color3.fromRGB(150, 130, 255),
		SizeStart        = 0.7,
		TransparencyIn   = 0.2,
		LightEmission    = 0.7,
	},
}

Config.Animations = { -- [SD] movement animation runtime metadata and original-asset placeholders
	Markers = {
		FootstepL = "FootstepL", -- [SD]
		FootstepR = "FootstepR", -- [SD]
		LandImpact = "LandImpact", -- [SD]
		RollImpact = "RollImpact", -- [SD]
		VaultPlant = "VaultPlant", -- [SD]
		VaultClear = "VaultClear", -- [SD]
	},
	Walk = {
		Id = "rbxassetid://89956272220101", Priority = Enum.AnimationPriority.Movement, Looped = true,
		FadeIn = 0.12, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch A published original
	Sprint = {
		Id = "rbxassetid://132688446420207", -- [SD] Batch A published original
		Priority = Enum.AnimationPriority.Movement,
		Looped = true,
		FadeIn = 0.15,
		FadeOut = 0.15,
		SpeedMin = 0.75,
		SpeedMax = 1.5,
	},
	Dash = {
		Id = "rbxassetid://118315275767975", -- [SD] Batch B published original
		Priority = Enum.AnimationPriority.Action,
		Looped = false,
		FadeIn = 0.08,
		FadeOut = 0.10,
		SpeedMin = 0.75,
		SpeedMax = 1.5,
	},
	JumpStart = {
		Id = "rbxassetid://115591963738630", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch A published original
	Fall = {
		Id = "rbxassetid://106234834891508", Priority = Enum.AnimationPriority.Movement, Looped = true,
		FadeIn = 0.10, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch A published original
	Land = {
		Id = "rbxassetid://83446879560399", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch A published original
	LandHard = {
		Id = "rbxassetid://93067099789487", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch A published original
	SlideEnter = {
		Id = "rbxassetid://89876839852879", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch B published original
	SlideLoop = {
		Id = "rbxassetid://106056699835668", Priority = Enum.AnimationPriority.Action, Looped = true,
		FadeIn = 0.10, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch B published original
	SlideExit = {
		Id = "rbxassetid://110417300002501", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.10, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch B published original
	SlideJump = {
		Id = "rbxassetid://77860783763073", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch B published original
	Roll = {
		Id = "rbxassetid://97323662606589", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch C published original
	Vault = {
		Id = "rbxassetid://88476053772200", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch D published original
	ClimbGrab = {
		Id = "REPLACE_ME_HRush_ClimbGrab", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch E original placeholder
	ClimbLoop = {
		Id = "REPLACE_ME_HRush_ClimbLoop", Priority = Enum.AnimationPriority.Movement, Looped = true,
		FadeIn = 0.10, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch E original placeholder
	ClimbMantle = {
		Id = "REPLACE_ME_HRush_ClimbMantle", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch E original placeholder
	SwingGrab = {
		Id = "REPLACE_ME_HRush_SwingGrab", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch F original placeholder
	SwingLoop = {
		Id = "REPLACE_ME_HRush_SwingLoop", Priority = Enum.AnimationPriority.Movement, Looped = true,
		FadeIn = 0.10, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch F original placeholder
	SwingRelease = {
		Id = "REPLACE_ME_HRush_SwingRelease", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch F original placeholder
	ZipHang = {
		Id = "REPLACE_ME_HRush_ZipHang", Priority = Enum.AnimationPriority.Movement, Looped = true,
		FadeIn = 0.10, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch F original placeholder
	ZipRelease = {
		Id = "REPLACE_ME_HRush_ZipRelease", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] Batch F original placeholder
}

-- ============================================================
-- SPRINT VFX (visuals only; sprint behavior lives in MovementController)
-- ============================================================
-- One smoothed intensity (0 to 1) from real horizontal speed drives every
-- effect. Pooled instances, hard caps, zero per-frame work when idle.
Config.SprintVFX = {
	Enabled = true, -- [SD] master switch
	ReducedEffects = false, -- [SD] halved counts; camera FOV is owned by Config.Camera.Effects now
	Quality = "Auto", -- [SD] Low/Medium/High; Auto picks Low on touch-only devices
	TayaEffect = false, -- [SD] reserved chase variant; not built
	RiseRate = 3.0, -- [SD] intensity units per second rising
	FallRate = 4.5, -- [SD] intensity units per second falling
	MaxInstances = 52, -- [SD] hard Instance cap for this feature (14 local + 21 pool + 15 remote = 50, plus 2 spare)
	-- Color palette [SD]
	Colors = {
		ElectricCyan = Color3.fromRGB(0, 220, 255), -- [SD] Primary
		BrightBlue = Color3.fromRGB(50, 130, 255), -- [SD] Secondary
		IcyWhite = Color3.fromRGB(225, 250, 255), -- [SD] Highlight (used sparingly)
	},

	-- Brightness ranking [SD]: Trail is rank 1 (foreground focus)
	Brightness = {
		TrailLightEmission = 0.9, -- [SD] intense energy glow
	},

	-- Neon Speed Trail (Option A) [SD]
	-- Real world width = AttachmentSpacing * WidthScale
	Trail = {
		Lifetime = 1.0, -- [SD] trail segment lifetime in seconds (about 21 studs at sprint speed 21)
		MaxLength = 21, -- [SD] maximum leg trail ribbon length (studs)
		AttachmentSpacing = 0.35, -- [SD] studs distance between Attachment0 and Attachment1
		WidthScaleStart = 4.0, -- [SD] multiplier at start (1.4 studs real world width)
		WidthScaleEnd = 0.05, -- [SD] multiplier at tip (0.0175 studs real world needle tip)
		IntensityThreshold = 0.2, -- [SD] intensity at which trail starts fading in
		IntensityStep = 0.05, -- [SD] minimum intensity delta before updating trail properties
		SideX = 0, -- [SD] lateral offset from lower leg center, positive means outward from the centerline (studs)
		HeightY = -0.5, -- [SD] vertical center of the trail segment within the lower leg (studs)
		DepthZ = -0.2, -- [SD] posterior offset behind the lower leg center (studs)
		ColorMid = 0.6, -- [SD] position of the middle color keypoint (0 to 1)
		FadeBase = 1.0, -- [SD] transparency mapping base: birth transparency before clamp is FadeBase minus intensity
		FadeMin = 0.0, -- [SD] minimum birth transparency (0 is opaque)
		FadeMax = 0.95, -- [SD] maximum birth transparency (1 is invisible)

		-- Arm Trails (hands) [SD]
		-- Same palette and fade as the leg trails, about half the width and
		-- lifetime. Real world width = AttachmentSpacing * WidthScale.
		Arm = {
			AttachmentSpacing = 0.35, -- [SD] studs distance between Attachment0 and Attachment1
			WidthScaleStart = 2.0, -- [SD] multiplier at start (0.7 studs real world width)
			WidthScaleEnd = 0.025, -- [SD] multiplier at tip (0.00875 studs real world needle tip)
			Lifetime = 0.5, -- [SD] trail segment lifetime in seconds (about 10 studs at sprint speed)
			MaxLength = 10, -- [SD] maximum arm trail ribbon length (studs)
			SideX = 0, -- [SD] lateral offset from hand center, positive means outward from the centerline (studs)
			HeightY = 0, -- [SD] vertical center of the trail segment within the hand (studs)
			DepthZ = -0.15, -- [SD] posterior offset behind the hand center (studs)
		},
	},

	-- Speed Lines (improved pooled system) [SD]
	Lines = {
		Max = 20, -- [SD] pooled streak parts
		SpawnMin = 6, -- [SD] streaks per second at intensity 0
		SpawnMax = 24, -- [SD] streaks per second at intensity 1
		LifeMin = 0.2, -- [SD] streak lifetime low (s)
		LifeMax = 0.4, -- [SD] streak lifetime high (s)
		LengthMin = 2.0, -- [SD] streak length low (studs)
		LengthMax = 4.5, -- [SD] streak length high (studs)
		ThickMin = 0.05, -- [SD] streak thickness low (studs)
		ThickMax = 0.10, -- [SD] streak thickness high (studs)
		TransMin = 0.50, -- [SD] birth transparency at full intensity (dimmer than the leg trail so the trail stays the focus)
		TransMax = 0.80, -- [SD] birth transparency at min intensity
		IcyShare = 0.12, -- [SD] share of speed lines drawn icy white, the rest blend cyan to blue (0 to 1)
		InnerRadius = 2.5, -- [SD] spawn ring inner edge, safely clears character (studs)
		OuterRadius = 5.5, -- [SD] spawn ring outer edge (studs)
		CenterConeDeg = 50, -- [SD] excluded forward cone, preserves screen center and reticle (deg)
		DriftMin = 10, -- [SD] backward drift speed low (studs/s)
		DriftMax = 20, -- [SD] backward drift speed high (studs/s)
	},

	-- Dust (preserved exactly from current balance)
	Dust = {
		StartBurst = 14, -- [SD] puff count at sprint start (under 30)
		Life = 0.4, -- [SD] dust lifetime (s)
		Size = 0.6, -- [SD] dust particle start size (studs)
		SpeedMin = 3, -- [SD] dust kick speed low (studs/s)
		SpeedMax = 7, -- [SD] dust kick speed high (studs/s)
		PuffCount = 2, -- [SD] puffs per footstep
		FootstepDistance = 3.5, -- [SD] studs between footstep puffs
		FootstepRate = 8, -- [SD] max footstep puffs per second
		Color = Color3.fromRGB(214, 200, 176), -- [SD] default dust
		Tints = { -- [SD] FloorMaterial name keys
			Default = Color3.fromRGB(214, 200, 176),
			Grass = Color3.fromRGB(120, 170, 90),
			Concrete = Color3.fromRGB(150, 150, 145),
			Wood = Color3.fromRGB(170, 130, 80),
			Sand = Color3.fromRGB(225, 205, 150),
		},
	},

	-- Remote runner light rigs [SD]
	Remote = {
		Range = 40, -- [SD] max distance for remote effects (studs)
		Cap = 3, -- [SD] max remote players with effects
		ScanRate = 4, -- [SD] scans per second
		ThresholdRatio = 0.6, -- [SD] remote effect speed gate as a share from walk to sprint: walk + ratio * (sprint - walk), using scaled speeds (19 at scale 1)
		AttachmentSpacing = 0.25, -- [SD] studs distance between remote attachments
		WidthScaleStart = 0.8, -- [SD] 0.20 studs real world width
		WidthScaleEnd = 0.05, -- [SD] 0.0125 studs real world needle tip
		Lifetime = 0.2, -- [SD] shorter remote trail lifetime
		CenterY = -1.5, -- [SD] vertical center of the remote trail segment relative to the root (studs)
		Transparency = 0.3, -- [SD] remote trail birth transparency (dimmer than the local trail)
	},
}

Config.Tag = {
	SafeWindowDuration  = 2.0,
	LockDelayDuration   = 1.0,
	RewindBufferDuration = 0.5,
	RewindDefault        = 0.12,
	RewindMax            = 0.20,
	CloseChaseDistance  = 10,
}

Config.Pounce = { -- [LOCKED] Project-owner revision, 2026-10-17: moving ground/air activation; pounce-only tags including bots
	Enabled = true,
	WindupTime = 0.07,
	HitRecovery = 0.15,
	MissRecovery = 0.28,
	HitCooldown = 0.8, -- [LOCKED] reduced at project-owner request, 2026-10-17
	MissCooldown = 1.05, -- [LOCKED] reduced at project-owner request, 2026-10-17
	MaxAirTime = 0.70,
	ForwardSpeed = 55,
	UpwardSpeed = 13,
	AirControl = 0.12,
	HitboxSize = Vector3.new(5, 5, 6),
	MaxTagAngle = 40,
	AimAssistDistance = 14,
	AimAssistAngle = 18,
	AimAssistStrength = 0.10,
	MinAirTime = 0.10, -- [SD] exclude the launch frame from landing detection
	GroundTolerance = 0.12, -- [SD] server ground-ray tolerance for client-owned R15 rigs
	MinForwardDot = 0.5, -- [SD] moving within 60 degrees of character facing
	MinMoveSpeed = 1, -- [SD] minimum server-observed horizontal movement; sprint and ground contact are not required
	BotAttemptRange = 12, -- [SD] AI begins a validated pounce within this range
	MaxSteerAngle = 30, -- [SD] steering input cone relative to launch
	SteerRate = 0.8, -- [SD] frame-independent heading blend
	AnimationFade = 0.06, -- [SD]
	TagPoseTime = 0.10, -- [SD] minimum confirmed contact pose
	RequestInterval = 0.08, -- [SD] packet guard independent of gameplay cooldown
	ReplyTimeout = 1.2, -- [SD]
	HitboxOffset = Vector3.new(0, 0.65, -3), -- [SD] hands/upper-torso region
	StandingTargetOffset = 0.5, -- [SD]
	SlidingTargetOffset = -1.1, -- [SD] lowered target profile
	MaxHitDistance = 9, -- [SD] broad distance guard; box and cone remain mandatory
	TravelSlack = 4, -- [SD] server-observed replication slack in studs
	MaxRise = 4, -- [SD] vertical envelope for the small 13 studs/s impulse
	WallProbeSize = Vector3.new(1.5, 1.5, 1.5), -- [SD]
	WallLookAhead = 2, -- [SD]
	WallMaxNormalY = 0.35, -- [SD]
	RecoverySpeedMult = 0.35, -- [SD] heavier committed recovery instead of full sprint
	Camera = { -- [SD] additive presentation, after existing camera owners
		CollisionPadding = 0.05,
		WindupFov = 3, LaunchFov = 8, AirFov = 6, ImpactFov = 10,
		WindupOffset = Vector3.new(0, -0.05, 0.3),
		LaunchOffset = Vector3.new(0, 0.15, 0.8), AirOffset = Vector3.new(0, 0.12, 0.55),
		NearPush = 0.3, NearDistance = 7,
		ImpactPush = 0.25, ImpactPosition = Vector3.new(0.04, 0.06, 0.03),
		ImpactAngles = Vector3.new(1.5, 0.8, 1), ImpactDecay = 25, ImpactFrequency = 85,
		LandDip = 0.13, LandPitch = 1.5, LandDecay = 18, SmoothRate = 28,
		LaunchHold = 0.08,
		FirstPersonFovScale = 0.6, -- [SD] Phase 4 pounce FOV layer scale in first person
		FirstPersonOffsetScale = 0.35, -- [SD] Phase 4 pounce positional layer scale in first person
	},
	Feedback = { -- [SD] original primitive geometry and ribbons; no third-party assets
		DustColor = Color3.fromRGB(185, 166, 140), WindColor = Color3.fromRGB(170, 232, 255),
		ImpactColor = Color3.fromRGB(255, 231, 115),
		WindupCount = 4, LaunchCount = 10, HitCount = 16, LandCount = 6, MissCount = 12,
		Lifetime = 0.24, DustSize = 0.14, DustRadius = 2, ImpactRadius = 3,
		StreakCount = 4, StreakLength = 1.2, StreakThickness = 0.035, FlashSize = 0.6,
		RingSegments = 16, RingThickness = 0.06, RingRadius = 2,
		TrailLifetime = 0.14, TrailMinSpeed = 25, SoundVolume = 0.8,
	},
	Debug = false, -- [SD] Development visualization; off for release
	Animations = {
		Windup = "rbxassetid://112019342280579",
		Leap = "rbxassetid://94945585012531",
		Tag = "rbxassetid://88403484239291",
		Recovery = "rbxassetid://115358409009409",
	},
	Sounds = { Windup = "", Launch = "", AirRush = "", TagImpact = "", Landing = "", MissLanding = "" }, -- [SD] Original audio hooks
}

Config.Taya = {
	TargetLockAcquireRange = 40,
	TargetLockBreakRange   = 55,
	TargetLockCoverTimeout = 1.0,
	TargetLockCooldown     = 4.0,
}

-- T16: TargetLockController reads this table
Config.TargetLock = {
	AcquireRange = 40,
	BreakRange = 55,
	LosBreakTime = 1.0,
	BreakCooldown = 4.0,
	CandidateRefreshRate = 10,
	AimPointOffset = Vector3.new(0, 0.5, 0),
	CameraAssist = {
		AssistStrength = 8.0,
		MaxTurnRateDegPerSec = 720, -- unused in Scriptable mode (no ClassicCamera fight)
		AimAnchorHeight = 1.2,      -- studs above the HumanoidRootPart (stable, unlike the animated torso)
		AimPointSmoothing = 25,     -- EMA rate for aim point (fast, no ClassicCamera to fight)
		AssistDeadzoneDeg = 1.0,   -- unused in Scriptable mode (kept for reference)
		PitchWeight = 0.35,
		InputDampenFactor = 0.25,
		InputDampenThreshold = 0.1,
		MaxPitchDeg = 80,
		Enabled = true,
	},
	Reticle = {
		SizePx = 64,
		StudsOffset = Vector3.new(0, 0.5, 0),
		RingColor = Color3.fromRGB(235, 64, 64),
		RingThickness = 2,
		RingTransparency = 0,
		NotchColor = Color3.fromRGB(255, 255, 255),
		NotchSizePx = 6,
		StartScale = 0.2,
		EndScale = 0.2,
		ScaleInTime = 0.15,
		FadeOutTime = 0.12,
		Animate = true,
	},
	Keybinds = {
		Toggle = Enum.KeyCode.R,
		Cycle = Enum.KeyCode.T,
		GamepadToggle = Enum.KeyCode.ButtonR3,
		GamepadCycle = Enum.KeyCode.DPadRight,
	},
	DebugPrint = true,
	DependencyTimeout = 10,
}

Config.Match = {
	MinPlayers        = 4,
	MaxPlayers        = 8,
	LobbyReadyTimeout = 0,
	DraftDuration     = 12,
	CountdownDuration = 5,
	RoundDuration     = 150,
	RoundEndDuration  = 8,
	MatchEndDuration  = 15,
	TotalRounds       = 3,
	DraftEveryRound   = true,
	RoundPoints       = { 8, 6, 5, 4, 3, 2, 1, 0 },
	OnTayaDisconnect  = "NearestRunner",
	OnRunnerDisconnect = "RankLast",
	BelowMinPlayersAction = "PauseEndRound",
	BelowMinPauseDuration = 10,
	SimulaEnd       = 100,
	BarangayRushEnd = 50,
	EventWarningTime = 2.5,
	SearchTimeout = 10,
	BotFillTarget = 8,
	TeamSize      = 4,
	AllowBots     = true,
}

Config.Events = {
	HulingHabolEscalation = { 50, 30, 15, 10, 5 },
}

Config.Debug = {
	AllowAnyRoleTargetLock = false, -- target lock is Taya-only (F-feature role gate)
	ShowLockDebug = true,
	AllowAnyRoleForSkills = true,
	ShowSkillDebug = true,
	ShowSprintVFX = true, -- sprint VFX state prints
	ForceTrailsVisible = false, -- sprint trail test override
	SettingsTestTone = false, -- TODO: remove before submission (debug loop proving the Music slider)
}

Config.Skills = {
	RS_01 = {
		id = "RS_01", name = "Luksong Baka", role = "Runner", type = "Escape",
		cooldown = 12, duration = 0, range = 18,
		params = {
			height = 14, distance = 18, windup = 0.1, airtime = 0.76,
			untouchableHeight = 6, landingRecovery = 0.2, lockDirection = true,
			fovBoost = 8, shakeDuration = 0.2, fovBackTime = 0.25, crouchScale = 0.6,
			pendingTimeout = 1.0, flightSlack = 0.25, minAirtime = 0.2,
			wallSpeedPct = 0.2, wallSlowTime = 0.1,
		},
		vfx = {
			windupCount = 10, landingCount = 16,
			ringStart = 3, ringEnd = 11, ringTime = 0.35,
			trailLifetime = 0.5, previewSize = 4, shakeAmp = 0.15,
			fovTime = 0.15, landingRingTime = 0.25,
			dustLifeMin = 0.35, dustLifeMax = 0.5,
			dustSpeedMin = 4, dustSpeedMax = 9, dustSize = 0.7,
		},
		sounds = { windup = "", takeoff = "", landing = "" },
		tell = { vfx = "DustRing", sfx = "Hup" },
		weakness = "No air steering",
		counterCondition = "Escapes a pounce or Lambat while airborne",
	},
	RS_02 = { id="RS_02", name="Pekeng Takbo", role="Runner", type="Decoy", cooldown=18, duration=4, range=0, params={breakLock=true}, tell={vfx="SmokePuff",sfx="Psssh"}, weakness="Decoy has no stamina and runs in a straight line", counterCondition="Taya locks onto or pounces the decoy" },
	RS_03 = {
		id       = "RS_03",
		name     = "Tsinelas Throw",
		role     = "Runner",
		type     = "Stun",
		cooldown = 25,
		duration = 1.0,
		range    = 40,
		params   = {
			projectileRadius = 3,
			launchHeight = 0,
			stepDt = 1 / 60,
			arcGravity = 80,
			minDistance = 3,
			maxHeightDiff = 6,
			pendingTimeout = 1.5,
			maxHoldTime = 3.0,
		},
		vfx = {
			impactCount = 16,
			spinRate = 720,
			slipperColor = Color3.fromRGB(70, 140, 255),
			slipperSize = Vector3.new(0.8, 0.35, 1.6),
			trailLifetime = 0.4,
			trailColorStart = Color3.fromRGB(150, 220, 255),
			trailColorEnd = Color3.fromRGB(60, 120, 230),
			trailWidth = 1.6,
			trailTransparencyIn = 0.2,
			aimDotCount = 12,
			aimDotSize = 0.4,
			aimMarkerSize = 2.0,
			aimColor = Color3.fromRGB(255, 230, 150),
			aimBlockedColor = Color3.fromRGB(226, 61, 61),
			aimTransparency = 0.5,
			aimRayLength = 100,
			starColor = Color3.fromRGB(255, 220, 80),
			starSize = 0.6,
			starLife = 0.5,
			starSpeedMin = 6,
			starSpeedMax = 14,
			impactRingTime = 0.25,
		},
		sounds = {
			throw = "",
			whoosh = "",
			impact = "",
		},
		tell     = { vfx = "SlipperArc", sfx = "Whoosh" },
		weakness = "Linear projectile; short stun only",
		counterCondition = "Hit on Taya mid-wind-up or mid-skill cast",
	},
	TS_01 = { id="TS_01", name="Sigaw", role="Taya", type="Detection", cooldown=20, duration=2.0, range=40, params={}, tell={vfx="ShoutWave",sfx="Sigaw"}, weakness="Only reveals; does not slow or stun", counterCondition="Tag a Runner who used Pekeng Takbo within the reveal window" },
	TS_02 = { id="TS_02", name="Lambat", role="Taya", type="Area", cooldown=22, duration=5.0, range=8, params={slowMult=0.60}, tell={vfx="NetGrid",sfx="Whomp"}, weakness="Runners can dash or jump out of the net", counterCondition="Tag a Runner slowed by the net" },
	TS_03 = { id="TS_03", name="Hatak", role="Taya", type="Speed", cooldown=15, duration=1.5, range=0, params={speedMult=1.35,lockDisabled=true}, tell={vfx="SpeedLines",sfx="Dash"}, weakness="Lock disabled; small window; commits Taya forward", counterCondition="Tag a Runner within 2 s of using Hatak" },
	testGrant = { "RS_01", "RS_03" },
}

Config.Diskarte = {
	MeterMax = 100,
	Gain = {
		LockBreak=15, PounceDouge=25, Counter=20, CloseChaseEscape=15,
		PounceTag=25, Tag=15, CatchAfterEscape=20, TayaCounter=20,
	},
	SamePairCooldown = 6.0,
	RepeatedTagCooldown = 3.0,
	Moves = {
		LIKSI = { role="Runner", effect="NextSkillCooldownReduction", params={reduction=0.50,window=8.0} },
		BANTAY = { role="Taya", effect="DirectionalRunnerClue", params={duration=2.0,wallReveal=false} },
		PUSO = { role="Both", effect="SafeWindowOnNextTagInteraction", params={safeWindow=0.75,expiry=10.0} },
	},
	ActivateKey = Enum.KeyCode.F,
	ActivateMobile = "DiskarteButton",
	ActivateGamepad = Enum.KeyCode.ButtonX,
}

Config.Network = { RateLimit = 10 }
Config.Performance = { MaxPartsPerMap=6000, MaxActiveEmitters=30, ServerFrameBudgetMs=4, MemoryBudgetMB=1024, NetworkBudgetKBs=20 }

Config.Maps = {
	Kalsada = {
		id="Kalsada", name="Barangay Kalsada", size=Vector2.new(150,150), spawnCount=8, rushEvent="CourtRush",
		greybox = { wallHeight=14, sidewalkWidth=8, spawnRadius=55, spawnPadSize=8, courtLength=56, courtWidth=32, buildingX=20, buildingZ=12, buildingHeight=10, jeepneyLength=12, jeepneyWidth=5, jeepneyHeight=4, crateSize=4, crateHeight=3.5, lowGapHeight=3.5, lowGapSpan=12 },
	},
	Binaha = { id="Binaha", name="Binaha na Baryo", size=Vector2.new(150,150), spawnCount=8, rushEvent="TubigTumataas", floodSpeedMult=0.80, evacSafeWindowDuration=1.5 },
}

Config.Party = { MaxSize=4, SlotSpacing=3.2 }

Config.MapVote = {
	Pool = { "Kalsada", "Binaha" },
	Duration = 10, RevealTime = 1.5,
	Info = {
		Kalsada = { tagline="Own the court. Outrun the neighborhood.", event="EVENT · COURT RUSH" },
		Binaha  = { tagline="Find high ground. Stay ahead of the flood.", event="EVENT · TUBIG TUMATAAS" },
	},
}

-- ============================================================
-- CAMERA (client presentation; CameraDirector Phase 1 + 2, 2026-10-18)
-- ============================================================
-- Base in-match third-person shoulder camera plus the Phase 2 movement
-- effects (sprint, falling, landing, dash, slide, vault, roll) and the
-- Phase 3 chase awareness set (role camera profiles, Runner look-back,
-- chase proximity FOV, chaser indicator, Taya tag-target marker, and
-- tag-transfer feedback). PounceCamera, the TargetLock assist, the skill
-- shake, and the RS_03 aim camera stay additive layers on top. CameraDirector
-- yields to aim and TargetLock and suspends its FOV channel while the RS_01
-- skill tween is active (HRushSkillFov attribute), so every layer composes
-- without fighting.
-- Phase 4 adds FirstPerson: an optional second view mode inside the same
-- director. Third person stays the default and keeps its exact behavior;
-- first person swaps the base pose for a capsule-anchored eye pose behind a
-- short switch blend, uses a lighter effect set, and turns the body with a
-- manual eased yaw while AutoRotate is off. Mode switches defer while
-- scripted movement or a camera takeover owns the frame.
Config.Camera = {
	Enabled = true, -- [SD] master switch for director ownership
	ThirdPersonDistance = 10, -- [SD] studs behind the focus point
	ShoulderOffset = 1.5, -- [SD] studs toward the open side
	CameraHeight = 1.5, -- [SD] focus height above the HumanoidRootPart
	PitchMin = -80, -- [SD] look limit down (degrees)
	PitchMax = 80, -- [SD] look limit up (degrees)
	BaseFov = 70, -- [SD] base FOV; matches the current match FOV
	MouseDegPerPixel = 0.12, -- [SD] look degrees per mouse pixel at 100 percent
	GamepadLookDegPerSec = 260, -- [SD] full-stick look speed
	GamepadDeadzone = 0.12, -- [SD] right-stick deadzone
	TouchLookDegPerPixel = 0.25, -- [SD] touch drag look degrees per pixel
	TouchMinScreenXScale = 0.5, -- [SD] touch look only starts on the right half
	CollisionPadding = 0.4, -- [SD] keep the camera off surfaces (studs)
	CollisionReturnRate = 6, -- [SD] ease-out rate after an obstruction clears
	TakeoverTime = 0.2, -- [SD] positional blend after aim, lock, or respawn
	ShoulderSwapTime = 0.15, -- [SD] seconds to cross the shoulder
	ShoulderSwapKey = Enum.KeyCode.V, -- [SD] free key verified 2026-10-17
	ShoulderSwapGamepad = Enum.KeyCode.ButtonL3, -- [SD] free; R3 cycles lock
	SensitivityScaleMax = 2.0, -- [SD] look scale at 100 percent
	SensitivityScaleMin = 0.25, -- [SD] floor; 0 percent still turns slowly
	Debug = false, -- [SD] tagged director prints
	Effects = { -- [SD] Phase 2 movement camera effects; magnitudes scale with the player setting, device profile, and reduced camera
		MaxFovBoostTotal = 12, -- [SD] cap on the summed movement FOV boost (deg)
		MaxPositionOffset = 1.5, -- [SD] cap on the summed camera offset (studs)
		MaxRotationDegrees = 6, -- [SD] cap on the summed view tilt (deg)
		FovCatchupRate = 40, -- [SD] max FOV move per second after yields and skill kicks (deg/s)
		ScaleSmoothTime = 0.4, -- [SD] ease time for intensity, device, and reduced changes (s)
		Sprint = {
			RunnerFov = 7, -- [SD] full-sprint FOV widen, Runner (deg)
			TayaFov = 5, -- [SD] full-sprint FOV widen, Taya (deg)
			PullBack = 0.6, -- [SD] full-sprint camera pull back (studs)
			AttackTime = 0.25, -- [SD] FOV ease in (s)
			ReleaseTime = 0.3, -- [SD] FOV ease out (s)
		},
		Fall = {
			Fov = 3, -- [SD] FOV widen at full fall speed (deg)
			PullBack = 0.3, -- [SD] camera pull back at full fall speed (studs)
			SpeedMin = 12, -- [SD] downward speed where the fall effect starts (studs/s)
			SpeedMax = 45, -- [SD] downward speed for full fall strength (studs/s)
			AttackTime = 0.2, -- [SD] strength ease in (s)
			ReleaseTime = 0.35, -- [SD] strength ease out (s)
		},
		Landing = {
			SoftDip = 0.12, -- [SD] Soft landing camera dip (studs)
			HardDip = 0.38, -- [SD] Hard landing camera dip (studs)
			HardPitch = 1.5, -- [SD] Hard landing downward view tilt (deg)
			ShakeAmp = 0.06, -- [SD] Hard landing positional shake amplitude (studs)
			ShakeTime = 0.11, -- [SD] Hard landing shake duration (s)
			AttackTime = 0.05, -- [SD] dip attack (s)
			RecoveryTime = 0.18, -- [SD] dip recovery (s)
		},
		Dash = {
			Fov = 5, -- [SD] FOV widen at the dash envelope peak (deg)
			PullIn = 0.7, -- [SD] camera pull in toward the character (studs)
			AttackTime = 0.08, -- [SD] envelope ease in (s)
			ReleaseTime = 0.25, -- [SD] envelope ease out (s)
		},
		Slide = {
			Dip = 0.6, -- [SD] camera lower while sliding (studs)
			Fov = 4, -- [SD] FOV widen while sliding (deg)
			Pitch = 3.5, -- [SD] downward view tilt while sliding (deg)
			AttackTime = 0.12, -- [SD] ease in (s)
			ReleaseTime = 0.15, -- [SD] ease out (s)
		},
		Vault = {
			PlantPullIn = 0.45, -- [SD] plant-phase pull in (studs)
			PlantPitch = 2.5, -- [SD] plant-phase downward view tilt (deg)
			ClearFov = 3, -- [SD] clear-phase FOV widen (deg)
			AirScale = 0.6, -- [SD] AirVault magnitude scale
			PlantEnd = 0.6, -- [SD] plant bump ends at this fraction of the vault duration
			ClearStart = 0.3, -- [SD] clear bump starts at this fraction of the vault duration
		},
		Roll = {
			Dip = 0.18, -- [SD] camera lower while rolling (studs)
			Fov = 2, -- [SD] FOV widen while rolling (deg)
			AttackTime = 0.08, -- [SD] ease in (s)
			ReleaseTime = 0.15, -- [SD] ease out (s)
		},
		Device = { -- [SD] effect scale by preferred input device
			Touch = 0.75,
			Gamepad = 0.9,
			Default = 1.0,
		},
	},
	RoleProfiles = { -- [SD] Phase 3 role camera identity; eased on a role change
		BlendTime = 0.3, -- [SD] seconds to ease between the role profiles
		Runner = {
			Fov = 72, -- [SD] base FOV for the Runner (wider awareness)
			Distance = 10.25, -- [SD] studs behind the focus point
		},
		Taya = {
			Fov = 68, -- [SD] base FOV for the Taya (tighter focus)
			Distance = 9.25, -- [SD] studs behind the focus point
		},
	},
	LookBack = { -- [SD] Phase 3 Runner hold-to-look-back
		Enabled = true, -- [SD] master switch
		Angle = 160, -- [SD] orbit yaw swing from the current look direction (deg)
		BlendTime = 0.15, -- [SD] swing ease in and out (s)
		Key = Enum.KeyCode.B, -- [SD] free key verified 2026-10-18
		GamepadKey = Enum.KeyCode.ButtonL1, -- [SD] free; R3 lock, L3 shoulder, L2 sprint
	},
	Chase = { -- [SD] Phase 3 proximity tension response (Runner, Taya closing in)
		MaxDistance = 20, -- [SD] distance where the response is zero (studs)
		MinDistance = 2, -- [SD] distance where the response is full (studs)
		MaxFov = 3, -- [SD] full-intensity FOV widen (deg)
		RiseTime = 0.35, -- [SD] ease in while the Taya closes (s)
		FallTime = 0.6, -- [SD] ease out when the distance opens (s)
		ClosingGain = 0.12, -- [SD] extra intensity per stud/s of approach
		ClosingMax = 0.35, -- [SD] cap on the closing-speed bonus
		VisibleModifier = 0.8, -- [SD] intensity multiplier while the Taya is on screen
		ClosingSmoothTime = 0.25, -- [SD] closing-speed smoothing (s)
	},
	ChaserIndicator = { -- [SD] Phase 3 Runner edge chevron toward a near Taya
		Enabled = true, -- [SD] master switch
		MaxDistance = 14, -- [SD] show range (studs)
		VisibleMargin = 0.06, -- [SD] hidden once the Taya is inside this viewport margin (fraction)
		EdgePadding = 56, -- [SD] keep the chevron this far inside the screen edges (px)
	},
	TagMarker = { -- [SD] Phase 3 Taya advisory tag-target marker
		Enabled = true, -- [SD] master switch
		MaxDistance = 18, -- [SD] show range for the nearest eligible target (studs)
		ScanInterval = 0.15, -- [SD] candidate and line-of-sight refresh (s)
	},
	TagTransfer = { -- [SD] Phase 3 camera feedback on a local role change
		ToTayaFov = -1.5, -- [SD] FOV tighten when becoming the Taya (deg)
		ToRunnerFov = 2, -- [SD] FOV widen when escaping (deg)
		ShakeAmp = 0.07, -- [SD] positional shake amplitude (studs)
		AttackTime = 0.06, -- [SD] pop attack (s)
		ReleaseTime = 0.35, -- [SD] pop release (s)
	},
	FirstPerson = { -- [SD] Phase 4 optional first-person view; second mode of the same director
		Enabled = true, -- [SD] master switch for the first-person mode
		CameraHeight = 1.6, -- [SD] eye height above the HumanoidRootPart (studs)
		ForwardOffset = 0.12, -- [SD] eye offset toward the look direction (studs)
		BaseFov = 72, -- [SD] first-person base FOV; role profiles stay third-person only
		SwitchTime = 0.2, -- [SD] pose blend between the view modes (s)
		YawAlignTime = 0.12, -- [SD] body yaw ease toward the camera yaw (s)
		ToggleKey = Enum.KeyCode.Z, -- [SD] free key verified 2026-10-18
		ToggleGamepad = Enum.KeyCode.DPadUp, -- [SD] free; DPadRight cycles lock, DPad nav is settings-only
		Effects = { -- [SD] lighter first-person effect set; offsets stay inside the capsule, no pull-backs
			SprintFov = 4, -- [SD] full-sprint FOV widen (deg)
			FallFov = 3, -- [SD] FOV widen at full fall speed (deg)
			DashFov = 5, -- [SD] FOV widen at the dash envelope peak (deg)
			SlideFov = 4, -- [SD] FOV widen while sliding (deg)
			SlideDip = 0.85, -- [SD] camera lower while sliding (studs)
			SlidePitch = 3, -- [SD] downward view tilt while sliding (deg)
			VaultFov = 3, -- [SD] clear-phase FOV widen (deg)
			VaultDip = 0.4, -- [SD] plant-phase camera lower (studs)
			VaultPitch = 5, -- [SD] plant-phase downward view tilt (deg)
			RollDip = 0.12, -- [SD] camera lower while rolling (studs)
			JumpPitch = 1, -- [SD] downward view tilt at jump start (deg)
			JumpPitchTime = 0.25, -- [SD] jump pitch ease out (s)
			LandSoftDip = 0.22, -- [SD] soft landing camera dip (studs)
			LandHardDip = 0.55, -- [SD] hard landing camera dip (studs)
			LandHardPitch = 0.8, -- [SD] hard landing downward view tilt (deg)
			LandShakeAmp = 0.05, -- [SD] hard landing positional shake amplitude (studs)
		},
	},
}

-- ============================================================
-- SETTINGS (client presentation only; never gameplay)
-- ============================================================
-- Defaults, ranges, and steps live here. Player choices live in
-- ClientSettings (StarterPlayerScripts) and never write back here.
Config.Settings = {
	MasterDefault = 100, -- [SD] master volume 0-100
	MusicDefault = 60, -- [SD] music volume 0-100
	SfxDefault = 100, -- [SD] SFX volume 0-100
	VfxDefault = 100, -- [SD] cosmetic VFX intensity percent 0-100
	ReducedCameraDefault = false, -- [SD] reduced camera effects off
	CameraSensitivityDefault = 50, -- [SD] camera look speed percent 0-100 (50 = neutral)
	InvertCameraYDefault = false, -- [SD] inverted vertical camera look off
	CameraEffectsDefault = 100, -- [SD] camera effects intensity percent 0-100
	LookBackDefault = true, -- [SD] Runner hold-to-look-back on
	ChaserIndicatorDefault = true, -- [SD] chaser edge indicator on
	CameraViewModeDefault = "ThirdPerson", -- [SD] Phase 4 starting view mode (first person is opt-in)
	VolumeCurve = 2, -- [SD] loudness curve power for slider mapping
	SliderStep = 5, -- [SD] slider snap step for keyboard and gamepad
	TelegraphFloor = 0.35, -- [SD] minimum visibility kept for telegraph effects
}

-- Per-match-state music tracks. All IDs stay "" until licensed audio is
-- logged in ASSET_LOG.md. The MusicController skips empty entries.
Config.Audio = {
	Music = {
		lobby = "", -- [SD] MS_01
		draft = "", -- [SD] MS_02
		countdown = "", -- [SD] MS_03
		round = "", -- [SD] MS_04
		roundEnd = "", -- [SD] MS_05
		matchEnd = "", -- [SD] MS_06
	},
}

-- One-shot SFX IDs. All "" until licensed audio is logged in ASSET_LOG.md.
-- Every hook skips empty IDs, so the game stays silent but wired.
Config.Sfx = {
	UI = {
		click = "rbxassetid://89121173273417", -- [SD] button presses
		toggle = "rbxassetid://130394308198775", -- [SD] toggle flips
		sliderEnd = "rbxassetid://134203145736891", -- [SD] slider release tick
		error = "", -- [SD] invalid actions (unhooked until draft UI)
		queueCancel = "rbxassetid://120812370100773", -- [SD] matchmaking cancel
		matchFound = "rbxassetid://127385873459389", -- [SD] match built
		volume = 0.7, -- [SD] UI one-shot volume 0-1
	},
	Countdown = {
		tick = "rbxassetid://84745673202062", -- [SD] MS_03 per-second tick
		go = "rbxassetid://123128040491688", -- [SD] MS_03 launch moment
		volume = 0.8, -- [SD] countdown volume 0-1
	},
	Tag = {
		slap = "rbxassetid://138862668790692", -- [SD] touch tag confirmation
		volume = 1.0, -- [SD] tag slap volume 0-1
	},
	Movement = {
		footstep = "rbxassetid://139613878484113", -- [SD] sprint footstep tap (positional, throttled by dust rate)
		staminaEmpty = "rbxassetid://81474882182684", -- [SD] stamina depletion cue (once per entry)
		volume = 0.5, -- [SD] movement one-shot volume 0-1
		pitchMin = 0.95, -- [SD] footstep pitch variation low
		pitchMax = 1.05, -- [SD] footstep pitch variation high
	},
}
-- ============================================================
-- UI (T18 RS_03 slot; full skill bar lands at T14/T17)
-- ============================================================
Config.UI = {
	Tsinelas = {
		SlotSize = 44,
		SlotOffsetX = 356,
		KeyLabel = "G",
		CaptionText = "TSINELAS",
		ReadyPulseTime = 0.16,
		ReadyPulseGrow = 52,
		AimStrokeColor = Color3.fromRGB(255, 210, 90),
		AimStrokeThickness = 3,
		UnavailableTransparency = 0.6,
		CountdownTextSize = 18,
		TouchSizePx = 76,
		TouchPosition = UDim2.new(0.88, 0, 0.68, 0),
	},
	TsinelasCam = {
		Enabled = true,
		InTime = 0.25,
		OutTime = 0.2,
		FirstPersonDistance = 0.5,
		MouseSensitivity = 0.7,
		FovDelta = 0,
		ReticleSizePx = 12,
	},
	MatchIntro = {
		BackgroundImageId = "", -- [SD] match-start cover art; empty = gradient only until the art ID lands
		BgmId = "rbxassetid://94984747143473", -- [SD] match BGM loop, see ASSET_LOG
		BgmVolume = 0.5, -- [SD] match BGM volume 0-1
		BgmFadeTime = 1.0, -- [SD] fade in/out on match enter/exit (s)
	},
}

return Config
