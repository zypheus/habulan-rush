--!strict
-- ReplicatedStorage/Config.lua
-- Single source of truth for ALL tunable values in Habulan Rush.
-- Zero hardcoding anywhere else in the codebase. All numbers come from here.
-- Locked values from DESIGN_LOCK.md (2026-10-07) are marked [LOCKED].
-- Values marked [SD] are Spec Defaults pending team confirmation.

local Config = {}

-- ============================================================
-- MOVEMENT
-- ============================================================
Config.Movement = {
	-- Runner speeds (studs/s)
	RunnerWalkSpeed   = 16,   -- [LOCKED via TDD §3]
	RunnerSprintSpeed = 21,   -- [LOCKED via TDD §3]

	-- Stamina
	StaminaMax         = 100,
	StaminaDrainRate   = 20,  -- per second while sprinting
	StaminaRegenRate   = 12,  -- per second after RegenDelay
	StaminaRegenDelay  = 1.0, -- seconds without sprinting before regen starts
	StaminaDepletedMin = 10,  -- must reach this before sprint re-enables after depletion [SD]

	-- Dash
	DashDistance           = 12,   -- studs
	DashDuration           = 0.2,  -- seconds
	DashCooldown           = 6.0,  -- seconds
	DashPounceInvulnTime   = 0.15, -- [LOCKED F07] seconds of pounce invulnerability (not touch/Tsinelas)

	-- Slide
	SlideDuration     = 0.6,  -- seconds
	SlideCooldown     = 3.0,  -- seconds
	SlideHitboxScale  = 0.5,  -- [SD] 50% height

	-- Taya
	TayaSpeed         = 18,   -- studs/s constant, no stamina

	-- Post-tag speed boost for ex-Taya [SD F08]
	PostTagSpeedBoostMult     = 1.20, -- multiplies base walk and sprint
	PostTagSpeedBoostDuration = 2.0,  -- seconds

	-- Dash VFX (client-predicted juice; transient — must decay to rest).
	-- Ribbon afterimage + one-shot burst on dash start. All values from here.
	DashVFX = {
		Enabled          = true,
		TrailLifetime    = 0.35,  -- s the ribbon lingers AFTER the dash ends
		BurstCount       = 16,    -- particles spawned at dash start
		ParticleLifetime = 0.30,  -- s each burst particle lives
		ParticleSpeedMin = 8,     -- studs/s backward spread (min)
		ParticleSpeedMax = 18,    -- studs/s backward spread (max)
		ColorStart       = Color3.fromRGB(130, 225, 255), -- cyan flash
		ColorEnd         = Color3.fromRGB(150, 130, 255), -- violet fade
		SizeStart        = 0.7,   -- studs at birth, shrinks to 0
		TransparencyIn   = 0.2,   -- birth transparency (0 = opaque, 1 = invisible)
		LightEmission    = 0.7,   -- glow strength
	},
}

-- ============================================================
-- TAG SYSTEM
-- ============================================================
Config.Tag = {
	TouchTagRange       = 3,    -- studs
	SafeWindowDuration  = 2.0,  -- seconds [LOCKED F06: longest applies, no stack]
	LockDelayDuration   = 1.0,  -- seconds (gates target lock only, not touch/pounce)

	-- Pounce
	PounceWindupTime    = 0.35, -- seconds telegraph on client
	PounceLungeDistance = 14,   -- studs
	PounceLungeSpeed    = 45,   -- studs/s
	PounceHitRadius     = 4,    -- studs
	PounceMissStunTime  = 1.0,  -- seconds self-stun on miss
	PounceCooldown      = 3.0,  -- seconds after miss

	-- Ring buffer for lag rewind
	RewindBufferDuration = 0.5,  -- seconds of Runner position history kept
	RewindDefault        = 0.12, -- [LOCKED F17] default rewind window (seconds)
	RewindMax            = 0.20, -- [LOCKED F17] hard cap (seconds)

	-- Tag validation
	CloseChaseDistance  = 10,   -- [LOCKED F11] studs for Diskarte close-chase-escape reward
}

-- ============================================================
-- TAYA (role)
-- ============================================================
Config.Taya = {
	TargetLockAcquireRange = 40, -- studs
	TargetLockBreakRange   = 55, -- studs
	TargetLockCoverTimeout = 1.0, -- seconds behind cover before lock breaks
	TargetLockCooldown     = 4.0, -- seconds after lock break
}

-- ============================================================
-- MATCH
-- ============================================================
Config.Match = {
	MinPlayers        = 4,  -- [LOCKED F18]
	MaxPlayers        = 8,

	-- State durations (seconds)
	LobbyReadyTimeout = 0,    -- 0 = host-start; set > 0 for auto-start countdown
	DraftDuration     = 12,   -- MS_02
	CountdownDuration = 5,    -- MS_03
	RoundDuration     = 150,  -- MS_04 Round Live
	RoundEndDuration  = 8,    -- MS_05
	MatchEndDuration  = 15,   -- MS_06

	TotalRounds       = 3,

	-- Draft runs before EVERY round [LOCKED F01]
	DraftEveryRound   = true,

	-- Scoring: points by rank (1st = index 1). Covers up to 8 players.
	RoundPoints       = { 8, 6, 5, 4, 3, 2, 1, 0 },

	-- Disconnect rules [LOCKED F18]
	OnTayaDisconnect  = "NearestRunner", -- nearest Runner becomes Taya
	OnRunnerDisconnect = "RankLast",     -- ranked last for the round
	BelowMinPlayersAction = "PauseEndRound", -- pause 10 s then end round without points [SD]
	BelowMinPauseDuration = 10,

	-- Event phases (time remaining in Round Live)
	SimulaEnd       = 100, -- seconds left when SIMULA ends
	BarangayRushEnd = 50,  -- seconds left when BARANGAY RUSH ends / HULING HABOL starts

	-- Barangay Rush event warning
	EventWarningTime = 2.5, -- seconds before phase change
}

-- ============================================================
-- EVENTS (Huling Habol escalation thresholds)
-- ============================================================
Config.Events = {
	HulingHabolEscalation = { 50, 30, 15, 10, 5 }, -- seconds remaining triggers
}

-- ============================================================
-- SKILLS
-- ============================================================
-- Schema per skill entry (see TDD §3.1):
--   id, role, type, cooldown, duration, range, params, tell, weakness

-- Debug switches for playtesting only.
Config.Debug = {
	-- TODO: set to false before submission
	AllowAnyRoleForSkills = true, -- while true the skill role gate is skipped
	-- TODO: remove before submission (delete this flag and all ShowSkillDebug blocks)
	ShowSkillDebug = true, -- prints + airborne label for RS_01 testing
}

Config.Skills = {
	RS_01 = {
		id       = "RS_01",
		name     = "Luksong Baka",
		role     = "Runner",
		type     = "Escape",
		cooldown = 12,
		duration = 0,
		range    = 18,
		params   = {
			height = 14,            -- impulse: apex height in studs
			distance = 18,          -- impulse: horizontal reach in studs
			windup = 0.1,           -- crouch time before takeoff (s)
			airtime = 0.76,         -- flight time (s); matches height/distance at g=196.2
			untouchableHeight = 6,  -- root higher than this cannot be tagged (TM_05/TM_08)
			landingRecovery = 0.2,  -- sprint disabled after touchdown (s)
			lockDirection = true,   -- heading frozen at takeoff: no air steering
			fovBoost = 8,           -- owner camera FOV kick at takeoff
			shakeDuration = 0.2,    -- owner landing camera shake (s)
			fovBackTime = 0.25,     -- FOV ease-back time on landing (s)
			crouchScale = 0.6,      -- HipHeight multiplier during windup crouch
			pendingTimeout = 1.0,   -- drop a lost server reply after this (s)
			flightSlack = 0.25,     -- landing-poll safety margin over airtime (s)
			minAirtime = 0.2,       -- ignore landings shorter than this after takeoff (s)
			wallSpeedPct = 0.2,     -- jump ends if horizontal speed < pct of launch speed
			wallSlowTime = 0.1,     -- ...and stays that slow for this long (s)
		},
		vfx = { -- every burst stays under 30 particles (mobile budget)
			windupCount = 10,
			landingCount = 16,
			ringStart = 3,          -- takeoff ring start diameter (studs)
			ringEnd = 11,           -- takeoff ring end diameter (studs)
			ringTime = 0.35,        -- ring grow duration (s)
			trailLifetime = 0.5,    -- air trail segment fade (s)
			previewSize = 4,        -- owner-only landing preview ring (studs)
			shakeAmp = 0.15,        -- landing shake offset (studs)
			fovTime = 0.15,         -- FOV tween-in time (s)
			landingRingTime = 0.25, -- landing ring grow/fade (s)
			dustLifeMin = 0.35,     -- dust particle lifetime low (s)
			dustLifeMax = 0.5,      -- dust particle lifetime high (s)
			dustSpeedMin = 4,       -- dust kick speed low (studs/s)
			dustSpeedMax = 9,       -- dust kick speed high (studs/s)
			dustSize = 0.7,         -- dust particle start size (studs)
		},
		sounds = { -- placeholder ids: swap licensed audio here (ASSET_LOG rule)
			windup = "",            -- "Hup!" voice
			takeoff = "",           -- launch whoosh
			landing = "",           -- soft thud
		},
		tell     = { vfx = "DustRing",   sfx = "Hup" },
		weakness = "No air steering",
		counterCondition = "Escapes a pounce or Lambat while airborne",
	},
	RS_02 = {
		id       = "RS_02",
		name     = "Pekeng Takbo",
		role     = "Runner",
		type     = "Decoy",
		cooldown = 18,
		duration = 4, -- decoy active seconds
		range    = 0,
		params   = { breakLock = true },
		tell     = { vfx = "SmokePuff",  sfx = "Psssh" },
		weakness = "Decoy has no stamina and runs in a straight line",
		counterCondition = "Taya locks onto or pounces the decoy",
	},
	RS_03 = {
		id       = "RS_03",
		name     = "Tsinelas Throw",
		role     = "Runner",
		type     = "Stun",
		cooldown = 25,
		duration = 1.0, -- stun duration on hit
		range    = 25,  -- max projectile range (studs)
		params   = {},
		tell     = { vfx = "SlipperArc", sfx = "Whoosh" },
		weakness = "Linear projectile; short stun only",
		counterCondition = "Hit on Taya mid-wind-up or mid-skill cast",
	},
	TS_01 = {
		id       = "TS_01",
		name     = "Sigaw",
		role     = "Taya",
		type     = "Detection",
		cooldown = 20,
		duration = 2.0, -- reveal duration
		range    = 40,  -- radial reveal range (studs)
		params   = {},
		tell     = { vfx = "ShoutWave",  sfx = "Sigaw" },
		weakness = "Only reveals; does not slow or stun",
		counterCondition = "Tag a Runner who used Pekeng Takbo within the reveal window",
	},
	TS_02 = {
		id       = "TS_02",
		name     = "Lambat",
		role     = "Taya",
		type     = "Area",
		cooldown = 22,
		duration = 5.0, -- slow duration on hit Runner
		range    = 8,   -- net zone radius (studs)
		params   = { slowMult = 0.60 }, -- Runner moves at 60% speed
		tell     = { vfx = "NetGrid",   sfx = "Whomp" },
		weakness = "Runners can dash or jump out of the net",
		counterCondition = "Tag a Runner slowed by the net",
	},
	TS_03 = {
		id       = "TS_03",
		name     = "Hatak",
		role     = "Taya",
		type     = "Speed",
		cooldown = 15,
		duration = 1.5, -- speed boost duration
		range    = 0,
		params   = { speedMult = 1.35, lockDisabled = true }, -- +35%, disables target lock
		tell     = { vfx = "SpeedLines", sfx = "Dash" },
		weakness = "Lock disabled; small window; commits Taya forward",
		counterCondition = "Tag a Runner within 2 s of using Hatak",
	},
	-- TEMP (T17 Skill Draft absent): skills granted for immediate playtesting.
	-- Single source of truth — read by MovementController (client gates + HUD)
	-- and SkillService (server validation). Remove when PickSkill owns unlocks.
	testGrant = { "RS_01" },
}

-- ============================================================
-- DISKARTE
-- ============================================================
Config.Diskarte = {
	MeterMax = 100,

	-- Gain values (per trigger)
	Gain = {
		-- Runner gains
		LockBreak          = 15,
		PounceDouge        = 25,
		Counter            = 20,
		CloseChaseEscape   = 15, -- within CloseChaseDistance studs

		-- Taya gains
		PounceTag          = 25,
		Tag                = 15,  -- regular touch tag
		CatchAfterEscape   = 20,  -- catch after Runner used escape skill
		TayaCounter        = 20,  -- Taya counter
	},

	-- Anti-snowball guards [SD F13]
	SamePairCooldown      = 6.0, -- seconds before the same pair can grant each other gains again
	RepeatedTagCooldown   = 3.0, -- seconds before same tag grants gain again

	-- Moves
	Moves = {
		LIKSI = {
			role   = "Runner",
			effect = "NextSkillCooldownReduction",
			params = { reduction = 0.50, window = 8.0 }, -- 50% CD reduction within 8 s
		},
		BANTAY = {
			role   = "Taya",
			effect = "DirectionalRunnerClue",
			params = { duration = 2.0, wallReveal = false },
		},
		PUSO = {
			role   = "Both",
			effect = "SafeWindowOnNextTagInteraction",
			params = { safeWindow = 0.75, expiry = 10.0 }, -- does not stack with other windows
		},
	},

	-- Input bindings [SD F14]
	ActivateKey     = Enum.KeyCode.F,       -- PC
	ActivateMobile  = "DiskarteButton",     -- near skill bar
	ActivateGamepad = Enum.KeyCode.ButtonX, -- console face button
}

-- ============================================================
-- NETWORK / PERFORMANCE
-- ============================================================
Config.Network = {
	RateLimit = 10, -- max requests per second per player per remote
}

Config.Performance = {
	MaxPartsPerMap     = 6000,
	MaxActiveEmitters  = 30,
	ServerFrameBudgetMs = 4,
	MemoryBudgetMB     = 1024, -- 1 GB
	NetworkBudgetKBs   = 20,  -- KB/s per client
}

-- ============================================================
-- MAPS (placeholder; map data will expand here)
-- ============================================================
Config.Maps = {
	Kalsada = {
		id         = "Kalsada",
		name       = "Barangay Kalsada",
		size       = Vector2.new(150, 150),
		spawnCount = 8,
		rushEvent  = "CourtRush",
		-- T08 greybox blockout metrics. Level-design derived from
		-- Config.Movement: JumpPower 50 ~ 7.2 studs -> vaults <= 4 (RM_05);
		-- slide 50% hitbox -> 3.5-stud gap clears a sliding but not a
		-- standing character (RM_06). Centre stays open for CourtRush.
		greybox = {
			wallHeight     = 14,  -- jump (JP50 ~7.2) cannot clear
			sidewalkWidth  = 8,
			spawnRadius    = 55,  -- equidistant ring (Bootstrap)
			spawnPadSize   = 8,
			courtLength    = 56,  -- court X (long axis)
			courtWidth     = 32,  -- court Z
			buildingX      = 20,  -- sari-sari block footprint X
			buildingZ      = 12,  -- sari-sari block footprint Z
			buildingHeight = 10,  -- LOS cover (not vaultable)
			jeepneyLength  = 12,  -- RM_05: roof <= 4 studs => vaultable
			jeepneyWidth   = 5,
			jeepneyHeight  = 4,
			crateSize      = 4,   -- extra vault obstacle (GDD: >= 3)
			crateHeight    = 3.5,
			lowGapHeight   = 3.5, -- RM_06 slide clearance
			lowGapSpan     = 12,  -- lintel length across the gap
		},
	},
	Binaha = {
		id         = "Binaha",
		name       = "Binaha na Baryo",
		size       = Vector2.new(150, 150),
		spawnCount = 8,
		rushEvent  = "TubigTumataas",
		floodSpeedMult       = 0.80, -- -20% in submerged low areas
		evacSafeWindowDuration = 1.5, -- [SD] one-time per visit
	},
}

return Config
