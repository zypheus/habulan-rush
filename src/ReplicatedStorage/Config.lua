--!strict
-- ReplicatedStorage/Config.lua
-- Single source of truth for ALL tunable values in Habulan Rush.

local Config = {}

Config.Movement = {
	RunnerWalkSpeed   = 16,
	RunnerSprintSpeed = 21,
	StaminaMax         = 100,
	StaminaDrainRate   = 20,
	StaminaRegenRate   = 12,
	StaminaRegenDelay  = 1.0,
	StaminaDepletedMin = 10,
	DashDistance           = 12,
	DashDuration           = 0.2,
	DashCooldown           = 6.0,
	DashPounceInvulnTime   = 0.15,
	SlideDuration     = 0.6,
	SlideCooldown     = 3.0,
	SlideHitboxScale  = 0.5,
	TayaSpeed         = 18,
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
	RS_03 = { id="RS_03", name="Tsinelas Throw", role="Runner", type="Stun", cooldown=25, duration=1.0, range=25, params={}, tell={vfx="SlipperArc",sfx="Whoosh"}, weakness="Linear projectile; short stun only", counterCondition="Hit on Taya mid-wind-up or mid-skill cast" },
	TS_01 = { id="TS_01", name="Sigaw", role="Taya", type="Detection", cooldown=20, duration=2.0, range=40, params={}, tell={vfx="ShoutWave",sfx="Sigaw"}, weakness="Only reveals; does not slow or stun", counterCondition="Tag a Runner who used Pekeng Takbo within the reveal window" },
	TS_02 = { id="TS_02", name="Lambat", role="Taya", type="Area", cooldown=22, duration=5.0, range=8, params={slowMult=0.60}, tell={vfx="NetGrid",sfx="Whomp"}, weakness="Runners can dash or jump out of the net", counterCondition="Tag a Runner slowed by the net" },
	TS_03 = { id="TS_03", name="Hatak", role="Taya", type="Speed", cooldown=15, duration=1.5, range=0, params={speedMult=1.35,lockDisabled=true}, tell={vfx="SpeedLines",sfx="Dash"}, weakness="Lock disabled; small window; commits Taya forward", counterCondition="Tag a Runner within 2 s of using Hatak" },
	testGrant = { "RS_01" },
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

return Config