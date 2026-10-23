--!strict
-- ReplicatedStorage/Config.lua
-- Owner: Project Owner
-- Responsibility: immutable shared gameplay and presentation tuning.
-- Task/spec: simple click-to-tag rework and supplied tag animations, approved 2026-10-18.
-- Task/spec: movement upgrade Part 2 landing owner and chest-level Vault, approved 2026-10-16.
-- Task/spec: MS_RPS first Taya selection, GDD 3.2 / System Spec 2.1.
-- Task/spec: momentum slice 1, server authority and shared tuning, 2026-10-19.
-- Task/spec: slide chaining tuning and entry speed, 2026-10-19.
-- Task/spec: source-owned wind dash VFX, approved 2026-10-22.
-- Task/spec: Agawan ng Panyo Phase 1 mode selection, approved 2026-10-23.
-- Task/spec: Panyo Carrier visual feedback, approved 2026-10-23.
-- Task/spec: Lihim na Target full mode, approved 2026-10-23.
-- Task/spec: owner-approved first-person FOV setting, 2026-10-22.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local Config = {}

Config.Movement = {
	RunnerWalkSpeed   = 16, -- [LOCKED GDD RM_01, DESIGN_LOCK F08]
	RunnerSprintSpeed = 21, -- [LOCKED GDD RM_02, DESIGN_LOCK F08]
	TayaSprintSpeed = 21, -- [LOCKED] Project-owner Taya sprint revision, 2026-10-16
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
	DashTagInvulnTime      = 0.15,
	DashSoundId            = "rbxassetid://115548807322300", -- [SD] dash whoosh (Pixabay Sound Effects, royalty-free, see ASSET_LOG)
	DashSoundVolume        = 0.7, -- [SD] dash whoosh volume 0-1
	SlideMinSpeedPct  = 0.85, -- [SD] Dormant movement entry target; momentum uses Config.Momentum.SlideMinSpeedPct
	SlideStartMult    = 1.15, -- [SD] Step 3 target, dormant until a separate slide rewrite
	SlideEndMult      = 0.45, -- [SD] Step 3 target speed at natural exit
	SlideDuration     = 1.0, -- [SD] current value retained; within the 0.9 to 1.1 second target
	SlideSteerRate    = 12, -- [SD] Step 3 target turn cap in degrees per second
	SlideCooldown     = 1.25, -- [SD] Starts at slide entry; 1.0 s slide leaves 0.25 s before reuse
	SlideJumpKeepPct  = 0.85, -- [SD] Step 5 target retained speed for a slide-hop
	SlideCameraDip    = 0.65, -- [SD] Step 3 target camera dip in studs
	SlideFovKick      = 4, -- [SD] Step 3 target FOV kick in degrees
	SlideHitboxScale  = 0.5,
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
	EquipmentGlideMinGroundClearance = 8.0, -- [SD] kite bridge clearance below feet for airborne entry
	EquipmentGlideGroundProbeDepth = 100.0, -- [SD] kite bridge downward clearance probe
	EquipmentGlideCeilingPadding = 2.0, -- [SD] extra launch headroom above the requested rise
	EquipmentGlideCollisionSkin = 0.05, -- [SD] stop short of solid contact during server motion
	EquipmentGlideLandingTolerance = 0.2, -- [SD] feet-to-floor contact accepted as a landing
	EquipmentGlideMaxDuration = 5.0, -- [SD] maximum accepted glide seconds per request
	EquipmentGlideMaxLaunchRise = 30.0, -- [SD] maximum accepted launch rise in studs
	EquipmentGlideMaxLaunchDuration = 2.0, -- [SD] maximum accepted launch seconds
	EquipmentGlideMaxHorizontalSpeed = 50.0, -- [SD] maximum accepted glide horizontal speed
	EquipmentGlideMaxDownwardSpeed = 50.0, -- [SD] maximum accepted glide descent speed
	EquipmentGlideMaxTravelDistance = 100.0, -- [SD] maximum accepted horizontal travel
	EquipmentGlideMaxTurnDegreesPerSecond = 360.0, -- [SD] maximum accepted steering rate
	EquipmentGlideSteerSendInterval = 0.1, -- [SD] client steer-intent sample period
	EquipmentGlideSteerMinInterval = 0.03, -- [SD] minimum accepted server steer interval
	EquipmentGlideSteerTimeout = 0.5, -- [SD] ignore stale steer intent after this time
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
		Enabled = true, -- [SD] source-owned cosmetic wind dash
		Texture = "rbxassetid://12402893521", -- [SD] owner-cleared VFX Studio wind texture
		TotalTime = 0.35, -- [SD] final clear time after dash input
		BurstTime = 0.03, -- [SD] strongest pulse within the first 0.07 s
		RibbonStart = 0.07, -- [SD] ribbon and first fleck beat
		FleckSecondTime = 0.13, -- [SD] sparse second fleck beat
		RibbonStop = 0.22, -- [SD] stop writing Trail segments
		TrailLifetime = 0.13, -- [SD] last segments clear near TotalTime
		BurstCount = 8, -- [SD] 14 particles total at full intensity
		FleckCount = 3, -- [SD] emitted twice
		FootOffset = -2.65, -- [SD] pulse height relative to HumanoidRootPart
		GuideOffset = -1.25, -- [SD] ribbon height relative to HumanoidRootPart
		BeamStartOffset = Vector3.new(0, 1.3, 0.8), -- [SD] source point above rear foot
		RibbonOffsets = { -- [SD] three separated strips around the moving guide
			{ Vector3.new(-0.95, 0.08, 0), Vector3.new(-0.3, 0.14, 0) },
			{ Vector3.new(0.05, 0.9, 0), Vector3.new(0.65, 0.84, 0) },
			{ Vector3.new(0.85, -0.45, 0), Vector3.new(1.4, -0.38, 0) },
		},
		GuideSway = 0.65, -- [SD] lateral wind bend, studs
		GuideLift = 0.18, -- [SD] vertical wind bend, studs
		WidthFloor = 0.45, -- [SD] minimum nonzero width share at low VFX settings
		TrailWidths = { 0.8, 0.7, 1.8 }, -- [SD] visible peak widths
		BeamWidths = { 0.12, 0.75 }, -- [SD] narrow start, wider moving end
		BeamCurves = { -2.1, 1.4 }, -- [SD] compressed arc, not lightning
		TrailWidthProfile = { -- [SD] broad middle with tapered leading and trailing ends
			{ 0, 0.02 }, { 0.18, 1 }, { 0.55, 0.75 }, { 0.85, 0.3 }, { 1, 0 },
		},
		TrailTransparency = { -- [SD] staggered opacity keeps three strips distinct
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(0.25, 0.48), NumberSequenceKeypoint.new(0.55, 0.7), NumberSequenceKeypoint.new(0.85, 1), NumberSequenceKeypoint.new(1, 1) }),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.46), NumberSequenceKeypoint.new(0.25, 0.55), NumberSequenceKeypoint.new(0.55, 0.76), NumberSequenceKeypoint.new(0.85, 1), NumberSequenceKeypoint.new(1, 1) }),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.28), NumberSequenceKeypoint.new(1, 1) }),
		},
		BeamTransparency = NumberSequence.new({ -- [SD] visible center with thin faded ends
			NumberSequenceKeypoint.new(0, 0.92), NumberSequenceKeypoint.new(0.24, 0.58),
			NumberSequenceKeypoint.new(0.75, 0.35), NumberSequenceKeypoint.new(1, 0.68),
		}),
		BurstSize = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(0.25, 0.95), NumberSequenceKeypoint.new(1, 0) }), -- [SD]
		BurstTransparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.3, 0.15), NumberSequenceKeypoint.new(1, 1) }), -- [SD]
		FleckSize = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(0.6, 0.11), NumberSequenceKeypoint.new(1, 0) }), -- [SD]
		FleckTransparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 1) }), -- [SD]
		BurstSpread = Vector2.new(32, 24), -- [SD] foot burst cone
		FleckSpread = Vector2.new(8, 10), -- [SD] narrow backward flecks
		BurstAcceleration = Vector3.new(0, -26, 0), -- [SD] quick ground settle
		RibbonLightEmission = 0.2, -- [SD] restrained glow
		RibbonBrightness = 1.25, -- [SD] restrained highlight
		White = Color3.fromRGB(255, 255, 255), -- [SD] wind highlight
		PaleCyan = Color3.fromRGB(206, 241, 255), -- [SD] pale wind body
		IcyBlue = Color3.fromRGB(151, 218, 255), -- [SD] blue edge
		BurstSpeed = NumberRange.new(7, 14), -- [SD] foot pulse speed, studs/s
		FleckSpeed = NumberRange.new(12, 20), -- [SD] backward fleck speed, studs/s
		BurstLifetime = NumberRange.new(0.08, 0.13), -- [SD] brief foot pulse
		FleckLifetime = NumberRange.new(0.08, 0.14), -- [SD] brief air flecks
	},
}

Config.Momentum = {
	Debug = false, -- [SD] Temporary slide gain and HUD trace; keep false outside diagnosis
	Cap = 6, -- [SD] Maximum stored speed bonus, studs/s
	GainSlide = 1.5, -- [SD] Accepted slide entry gain
	GainRoll = 2.5, -- [SD] Accepted landing roll gain
	GainRollPerfect = 3.5, -- [SD] Validated pre-landing roll intent followed by an accepted roll
	GainVault = 1.5, -- [SD] Disabled in momentum steps 1 to 4
	SlideMinSpeedPct = 0.8, -- [SD] Minimum entry speed as a share of role sprint speed to earn slide momentum
	PerfectRollWindow = 0.05, -- [SD] Final third of the existing 0.15 s roll window
	DiminishingMult = { 1.0, 0.6, 0.3 }, -- [SD] Repeated gain for each move
	DiminishWindow = 2.0, -- [SD] Seconds between same-move gains
	DecayGrace = 0.75, -- [SD] Seconds after a gain before decay starts
	DecayMoving = 1.5, -- [SD] Studs/s of bonus lost per second while moving
	DecayIdle = 6.0, -- [SD] Studs/s of bonus lost per second while idle
	MovingThreshold = 0.1, -- [SD] Horizontal studs/s treated as movement
	SyncInterval = 0.2, -- [SD] Server correction cadence while momentum decays
	ZeroSyncInterval = 1.0, -- [SD] Correction cadence when rejected local actions predict momentum from zero
	ChainWindow = 2.5, -- [SD] Cosmetic action chain window
	TierThresholds = { 0.25, 0.50, 0.85 }, -- [SD] Fractions of Cap
	GlobalSpeedCeiling = 30, -- [SD] Maximum ordinary movement speed after modifiers
	TayaBuildsMomentum = true, -- [SD] Taya uses the same gains and decay
	Fx = {
		FovBonus = { 2, 5, 8 }, -- [SD] Tier FOV additions
		PopupMergeWindow = 0.25, -- [SD] Seconds between merged action popups
		MaxPopups = 3, -- [SD] Maximum simultaneous action popups
		BarWidth = 208, -- [SD] Bottom-center bar width in pixels
		BarHeight = 8, -- [SD] Bottom-center bar height in pixels
		BarBottom = 88, -- [SD] Desktop distance above the viewport bottom; compact layout uses UI.Theme.PhoneMomentumBottom
		TierFlashTime = 0.18, -- [SD] One tier-change flash duration
		CrackTime = 0.3, -- [SD] Hard-zero split-frame fall duration
		PopupRisePx = 40, -- [SD] Action popup travel in pixels
		PopupTime = 0.6, -- [SD] Action popup lifetime
		RollPopupTime = 3.0, -- [SD] Total visible time for normal and perfect roll popups
		LostTime = 0.8, -- [SD] Momentum-lost text lifetime
		ChainPopTime = 0.18, -- [SD] Chain label scale bounce
		GainPitchStep = 0.07, -- [SD] Per-chain gain tick pitch rise
		GainPitchCap = 1.35, -- [SD] Highest gain tick pitch
		TierPitchStep = 0.1, -- [SD] Per-tier chime pitch rise
		SoundVolume = 0.45, -- [SD] Momentum one-shot loudness before SFX group volume
		FovInTime = 0.25, -- [SD] Tier FOV rise time
		FovOutTime = 0.5, -- [SD] Tier FOV fall time
		PerfectFovKick = 3, -- [SD] Perfect-roll transient FOV addition
		PerfectFovKickTime = 0.1, -- [SD] Perfect-roll transient duration
	},
}

Config.MomentumAssets = {
	Sfx_GainTick = "114295533790228", -- [SD] Project-owner supplied; provenance review pending
	Sfx_TierUp = "112103056657102", -- [SD] Project-owner supplied; provenance review pending
	Sfx_PerfectRoll = "125907380174659", -- [SD] Project-owner supplied; provenance review pending
	Sfx_WindLoop = "", -- [SD] Not used in this run
	Sfx_MomentumLost = "", -- [SD] Not used in this run
	Tex_Trail = "", -- [SD] Later slice
	Tex_Spark = "", -- [SD] Later slice
	Tex_Dust = "", -- [SD] Later slice
	Tex_SpeedLine = "", -- [SD] Later slice
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
		Id = "rbxassetid://74829353930740", -- [SD] project-owner replacement 2026-10-18, supersedes the Batch A ID
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
		Id = "rbxassetid://74307357863566", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] project-owner replacement 2026-10-18, supersedes the Batch A ID
	Fall = {
		Id = "rbxassetid://84863749801510", Priority = Enum.AnimationPriority.Movement, Looped = true,
		FadeIn = 0.10, FadeOut = 0.10, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] project-owner replacement 2026-10-18, supersedes the Batch A ID
	Land = {
		Id = "rbxassetid://88319270506819", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] project-owner replacement 2026-10-18, supersedes the Batch A ID
	LandHard = {
		Id = "rbxassetid://104821646839230", Priority = Enum.AnimationPriority.Action, Looped = false,
		FadeIn = 0.08, FadeOut = 0.12, SpeedMin = 0.75, SpeedMax = 1.5,
	}, -- [SD] project-owner replacement 2026-10-18, supersedes the Batch A ID
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
	ActionRange = 6.5, -- [SD] short server-owned tag reach
	ActionHitboxSize = Vector3.new(6, 5.5, 6), -- [SD]
	ActionHitboxOffset = Vector3.new(0, 0.5, -3), -- [SD]
	ActionMaxAngle = 70, -- [SD]
	ActionRequestInterval = 0.10, -- [SD] packet guard, not a gameplay cooldown
	StandingTargetOffset = 0.5, -- [SD]
	SlidingTargetOffset = -1.1, -- [SD]
	FirstPersonAnimationId = "rbxassetid://105436702082738", -- [SD] project-owner supplied 2026-10-18
	ThirdPersonAnimationId = "rbxassetid://132133679924288", -- [SD] project-owner supplied replacement 2026-10-22
	AnimationFade = 0.05, -- [SD]
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
	Rps = {
		IntroTime = 1.5, -- [SD] Opening card before the first pick
		PickTime = 5, -- [SD] Server-owned input window per stage
		RevealTime = 1, -- [SD] Simultaneous sign reveal
		ResolveTime = 1, -- [SD] Safe card movement or tie banner
		ResultTime = 1.5, -- [SD] Starting Taya highlight
		MaxStages = 5, -- [SD] Random sudden pick after this many stages
		Studio = { IntroTime = 0.4, PickTime = 3, RevealTime = 0.45, ResolveTime = 0.45, ResultTime = 0.7 }, -- [SD] Studio test timings
		RevealSoundId = "", -- [SD] TODO: add an approved reveal sound asset ID
		ResultSoundId = "", -- [SD] TODO: add an approved result sting asset ID
	},
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
	TeamSize      = 4,
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
		counterCondition = "Escapes a tag action or Lambat while airborne",
	},
	RS_02 = { id="RS_02", name="Pekeng Takbo", role="Runner", type="Decoy", cooldown=18, duration=4, range=0, params={breakLock=true}, tell={vfx="SmokePuff",sfx="Psssh"}, weakness="Decoy has no stamina and runs in a straight line", counterCondition="Taya locks onto or tags the decoy" },
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
		LockBreak=15, TagDodge=25, Counter=20, CloseChaseEscape=15,
		Tag=15, CatchAfterEscape=20, TayaCounter=20,
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

Config.ModeVote = {
	Duration = 10, -- [SD] server-owned mode ballot window when more than one mode is enabled
	RevealTime = 1.5, -- [SD] selected mode reveal before the map vote
	RequestInterval = 0.1, -- [SD] minimum interval between a player's mode vote requests
	TieFallback = "ClassicTag", -- [SD] preserve Classic Tag on a split or empty ballot
	Order = { "ClassicTag", "AgawanNgPanyo", "SecretHunt" }, -- [SD] display and tie-independent mode order
	Modes = {
		ClassicTag = { name = "Classic Tag", description = "Lowest Taya time wins", enabled = true }, -- [SD]
		AgawanNgPanyo = { name = "Agawan ng Panyo", description = "Grab, steal, and hold the panyo", enabled = true }, -- [SD] available in the server-owned mode ballot
		SecretHunt = { name = "Lihim na Target", description = "Find your secret target and capture them", enabled = true }, -- [SD] enabled after the full mode is wired
	},
}

Config.Panyo = {
	RoundDuration = 120, -- [SD] live competitive and solo practice round length
	PickupHold = 0.4, -- [SD] continuous server-observed proximity before collection
	PickupRadius = 4, -- [SD] studs from the neutral panyo
	PickupPollInterval = 0.1, -- [SD] server collection and carrier watchdog cadence
	NewCarrierSafe = 1.0, -- [SD] protection after a pickup or steal
	PreviousCarrierBlock = 2.0, -- [SD] previous carrier cannot steal back immediately
	MaxArenaCoordinate = 70, -- [SD] Kalsada bounds inside the walls
	MinArenaY = -10, -- [SD] invalid low position recovery threshold
	MaxArenaY = 35, -- [SD] invalid high position recovery threshold
	MaxObservedSpeed = 65, -- [SD] pickup plausibility speed in studs per second
	PositionSlack = 10, -- [SD] network update allowance for the pickup plausibility check
	InvalidMoveCooldown = 1.5, -- [SD] wait after an impossible pickup displacement
	DropBlock = 2.0, -- [SD] former carrier cannot immediately reclaim a self-caused drop
	ScorePublishInterval = 1.0, -- [SD] replicated possession score cadence
	RevealDuration = 2.0, -- [SD] brief Carrier locator lifetime
	Visuals = { -- [SD] client-only Carrier identification
		Color = Color3.fromRGB(255, 225, 116), -- [SD] gold matches the Panyo HUD
		TrailEndColor = Color3.fromRGB(255, 244, 192), -- [SD] pale cloth-colored trail tip
		IdleFillTransparency = 0.55, -- [SD] visible Carrier fill between reveals
		RevealFillTransparency = 0.2, -- [SD] stronger fill during timed reveals
		TrailLifetime = 0.45, -- [SD] short movement ribbon behind the Carrier
		TrailLeftOffset = Vector3.new(-0.55, -1.1, 0.4), -- [SD] waist-level left attachment
		TrailRightOffset = Vector3.new(0.55, -1.1, 0.4), -- [SD] waist-level right attachment
		TrailBirthTransparency = 0.2, -- [SD] opaque near the Carrier, fading to clear
		TrailLightEmission = 0.7, -- [SD] visible ribbon without overpowering the marker
	},
	Events = { -- [SD] seconds left in the 120-second round
		BarangayRush = 80,
		HulingHabol = 30,
		Reveals = { 80, 65, 50, 35, 30, 20, 10 },
		FinalCues = { 30, 15, 10, 5 },
	},
	Sounds = { pickup = "", steal = "", drop = "", reveal = "", final = "" }, -- [SD] silent until competition-safe audio is supplied
}

Config.SecretHunt = {
	RoundDuration = 120, -- [SD] competitive and practice round length
	MinCompetitivePlayers = 4, -- [SD] three-or-fewer-player lobbies are practice only
	MinContinuePlayers = 3, -- [SD] a competitive round ends when only two remain
	CaptureSafe = 2, -- [SD] tagged target protection
	RespawnSafe = 2, -- [SD] protection after a respawn or arena recovery
	HunterCaptureCooldown = 1, -- [SD] delay between one Hunter's successful captures
	PairCaptureCooldown = 4, -- [SD] blocks rapid reciprocal capture farming
	AssignmentAttempts = 128, -- [SD] bounded randomized cycle search
	SyncRequestInterval = 1, -- [SD] client snapshot request guard
	WatchInterval = 0.25, -- [SD] server arena and hint cadence
	ArenaXzLimit = 70, -- [SD] Kalsada bounds inside the walls
	ArenaMinY = -10, -- [SD] recovery below arena
	ArenaMaxY = 35, -- [SD] recovery above arena
	DistanceBucket = 10, -- [SD] approximate target distance in studs
	DangerDistance = 22, -- [SD] private nearby-Hunter warning distance
	HintPulseDuration = 1.25, -- [SD] brief directional hint lifetime
	Events = { -- [SD] seconds remaining in a 120-second round
		BarangayRush = 80,
		HulingHabol = 40,
		HintIntervals = { Simula = 5, BarangayRush = 3, HulingHabol = 2 },
	},
	Sounds = { capture = "", assignment = "", danger = "", final = "" }, -- [SD] silent until competition-safe cues are approved
}

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
-- tag-transfer feedback). The TargetLock assist and skill
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
		FirstPersonDistance = 1, -- [SD] camera-to-head distance counted as first person for the torso hider (studs)
		HideInFirstPerson = { "UpperTorso", "LowerTorso" }, -- [SD] R15 torso allowlist; local-only hide, never Transparency
		HideInFirstPersonR6 = { "Torso" }, -- [SD] R6 fallback: a single torso part
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
-- Defaults, ranges, and steps live in Config. Player choices live in
-- ClientSettings (StarterPlayerScripts) and never write back here.
Config.Settings = {
	TextScaleDefault = 100, -- [SD] UI text size preference, percent
	HighContrastDefault = false, -- [SD] stronger card and focus borders
	MasterDefault = 100, -- [SD] master volume 0-100
	MusicDefault = 60, -- [SD] music volume 0-100
	SfxDefault = 100, -- [SD] SFX volume 0-100
	VfxDefault = 100, -- [SD] cosmetic VFX intensity percent 0-100
	ReducedCameraDefault = false, -- [SD] reduced camera effects off
	ShowPopupsDefault = true, -- [SD] show local momentum action popups
	MomentumBarDefault = true, -- [SD] show the local momentum bar
	MomentumSoundsDefault = true, -- [SD] play local momentum sounds through the SFX group
	CameraSensitivityDefault = 50, -- [SD] camera look speed percent 0-100 (50 = neutral)
	FirstPersonFovMin = 50, -- [SD] first-person FOV slider lower bound (degrees)
	FirstPersonFovMax = 95, -- [SD] first-person FOV slider and final camera upper bound (degrees)
	FirstPersonFovStep = 1, -- [SD] first-person FOV slider precision (degrees)
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
	Theme = { -- [SD] shared Filipino street arcade presentation
		Navy = Color3.fromRGB(18, 43, 58), -- [SD]
		Raised = Color3.fromRGB(32, 63, 81), -- [SD]
		Cream = Color3.fromRGB(255, 248, 236), -- [SD]
		Muted = Color3.fromRGB(175, 196, 205), -- [SD]
		Gold = Color3.fromRGB(247, 181, 0), -- [SD]
		Orange = Color3.fromRGB(239, 139, 82), -- [SD]
		Teal = Color3.fromRGB(20, 184, 166), -- [SD]
		Taya = Color3.fromRGB(214, 40, 40), -- [SD]
		TayaText = Color3.fromRGB(255, 138, 130), -- [SD]
		Runner = Color3.fromRGB(29, 111, 224), -- [SD]
		RunnerText = Color3.fromRGB(139, 184, 255), -- [SD]
		Disabled = Color3.fromRGB(96, 119, 133), -- [SD]
		PhoneWidth = 900, -- [SD]
		PhoneHeight = 500, -- [SD]
		TouchTarget = 64, -- [SD]
		CardRadius = 12, -- [SD]
		ModalRadius = 16, -- [SD]
		NametagNear = 50, -- [SD]
		NametagFar = 70, -- [SD]
		PhoneMomentumBottom = 18, -- [SD] distance above the phone safe-area bottom
		PhoneMomentumWidth = 150, -- [SD] compact momentum meter width
		Layers = { -- [SD] one shared display-order contract
			Lobby = 5, -- [SD]
			HUD = 10, -- [SD]
			Feedback = 20, -- [SD]
			Transition = 30, -- [SD]
			Settings = 60, -- [SD]
			Modal = 80, -- [SD]
			Loading = 100, -- [SD]
		},
	},
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
