--!strict
-- ReplicatedStorage/Config.lua
-- Single source of truth for ALL tunable values in Habulan Rush.

local Config = {}

Config.Movement = {
	RunnerWalkSpeed   = 16, -- [LOCKED GDD RM_01, DESIGN_LOCK F08]
	RunnerSprintSpeed = 21, -- [LOCKED GDD RM_02, DESIGN_LOCK F08]
	SpeedScale = 1.5, -- [SD] multiplies every movement speed and speed-derived distance (1 = locked bases)
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
	SlideDuration     = 1.0, -- [SD] matches the HRush_Slide v4 clip length (was 0.6)
	SlideCooldown     = 3.0,
	SlideHitboxScale  = 0.5,
	SlideSpeedMult    = 1.25, -- [SD] aggressive escape entry boost; sign-off pending vs spec + pounce band
	SlideSteerLock    = true, -- [SD] heading fixed at entry; false = MoveDirection steers mid-slide
	SlideDustCount    = 12, -- [SD] heel dust burst on slide entry (dash pattern)
	SlideDustLifeMin  = 0.3, -- [SD] dust particle lifetime low (s)
	SlideDustLifeMax  = 0.5, -- [SD] dust particle lifetime high (s)
	SlideDustSpeedMin = 4, -- [SD] dust kick speed low (studs/s)
	SlideDustSpeedMax = 9, -- [SD] dust kick speed high (studs/s)
	SlideDustSize     = 0.7, -- [SD] dust particle start size (studs)
	SlideSoundId      = "", -- [SD] slide whoosh hook, silent until a licensed ID lands (ASSET_LOG rule)
	SlideSoundVolume  = 0.7, -- [SD] slide whoosh volume 0-1
	SprintAnimId = "rbxassetid://92487449831774", -- [SD] published HRush_Sprint (loops while sprinting)
	SlideAnimId  = "rbxassetid://129414076083716", -- [SD] published HRush_Slide v4 (one-shot per slide)
	DashAnimId   = "rbxassetid://126630478624602", -- [SD] published HRush_Dash (one-shot, cut at the 0.2s move end)
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

-- ============================================================
-- SPRINT VFX (visuals only; sprint behavior lives in MovementController)
-- ============================================================
-- One smoothed intensity (0 to 1) from real horizontal speed drives every
-- effect. Pooled instances, hard caps, zero per-frame work when idle.
Config.SprintVFX = {
	Enabled = true, -- [SD] master switch
	ReducedEffects = false, -- [SD] no FOV change, halved counts (T33 setting drives later)
	Quality = "Auto", -- [SD] Low/Medium/High; Auto picks Low on touch-only devices
	TayaEffect = false, -- [SD] reserved chase variant; not built
	RiseRate = 3.0, -- [SD] intensity units per second rising
	FallRate = 4.5, -- [SD] intensity units per second falling
	FovDelta = 5, -- [SD] FOV widen at full intensity (deg)
	FovInTime = 0.25, -- [SD] FOV ease in (s)
	FovOutTime = 0.3, -- [SD] FOV ease out (s)
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
	TouchTagRange       = 3,
	SafeWindowDuration  = 2.0,
	LockDelayDuration   = 1.0,
	PounceWindupTime    = 0.35,
	PounceLungeDistance = 14,
	PounceLungeSpeed    = 45,
	PounceHitRadius     = 4,
	PounceMissStunTime  = 1.0,
	PounceCooldown      = 3.0,
	RewindBufferDuration = 0.5,
	RewindDefault        = 0.12,
	RewindMax            = 0.20,
	CloseChaseDistance  = 10,
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
}

return Config