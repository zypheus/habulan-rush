--!strict
-- ServerScriptService/Bootstrap.server.lua
-- Owner: Programmer A (T08 Barangay Kalsada greybox)
-- Responsibility: build the playable arena so the place never loads empty.
--   Street baseplate (150x150), boundary walls, sidewalks, central basketball
--   court, sari-sari store cover blocks, 4 vault-height jeepneys (roof <= 4),
--   4 crate vaults, 2 low gaps for sliding, 8 equidistant spawns (r = 55),
--   world lighting defaults, and StarterPlayer character defaults.
-- Level-design rules encoded here (GDD §9 / T08 / Art Bible):
--   * Metrics derive from Config.Movement: JP50 jump ~7.2 studs -> all vaults
--     <= 4 studs (RM_05); slide halves HipHeight -> 3.5-stud gaps pass a
--     sliding but never a standing character (RM_06); walls at 14 studs are
--     unjumpable so the match stays inside the blockout.
--   * No dead ends smaller than 10 studs (corner-trap rule): every prop either
--     sits >= 10 studs from other blockers / boundary walls, or is merged
--     flush against a wall so no <10-stud pocket can form.
--   * Centre stays open (Art Bible: "keep the center open"; CourtRush = fast
--     open shortcut with no cover).
-- Idempotent: the whole blockout lives in Workspace.KalsadaGreybox and is
-- destroyed + rebuilt on every server start — no duplicates on re-sync.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent

local Map = Config.Maps.Kalsada
local GB = Map.greybox
local ARENA_SIZE = Map.size.X -- 150 studs, square
local SPAWN_COUNT = Map.spawnCount -- 8 equidistant

-- Palette (Art Bible: bright, stylized, readable; court distinct from street)
local COL = {
	asphalt   = Color3.fromRGB(58, 58, 64),
	sidewalk  = Color3.fromRGB(150, 150, 145),
	wall      = Color3.fromRGB(132, 132, 138),
	wallBand  = Color3.fromRGB(60, 120, 200),
	court     = Color3.fromRGB(54, 98, 160),
	courtKey  = Color3.fromRGB(172, 74, 62),
	line      = Color3.fromRGB(240, 240, 240),
	storeWall = Color3.fromRGB(235, 220, 190),
	storeRoof = Color3.fromRGB(150, 90, 70),
	storeSign = Color3.fromRGB(60, 140, 90),
	jeepney   = Color3.fromRGB(240, 210, 80),
	jeepTrim  = Color3.fromRGB(70, 70, 75),
	crate     = Color3.fromRGB(170, 130, 80),
	tunnel    = Color3.fromRGB(178, 178, 172),
	lintel    = Color3.fromRGB(222, 182, 70),
	spawn     = Color3.fromRGB(60, 140, 220),
	spawnRing = Color3.fromRGB(90, 200, 255),
}

local folder: Folder -- KalsadaGreybox, assigned in buildGreybox()

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- Street baseplate: persistent top-level child (name watched by the rebuild
-- listener below); properties are re-applied so a stale grass plate upgrades.
local function ensureBaseplate(): BasePart
	local existing = Workspace:FindFirstChild("KalsadaBaseplate")
	if existing and existing:IsA("BasePart") then
		existing.Size = Vector3.new(ARENA_SIZE, 2, ARENA_SIZE)
		existing.Position = Vector3.new(0, -1, 0) -- top surface at Y=0
		existing.Anchored = true
		existing.Material = Enum.Material.Asphalt -- MP_01: open street
		existing.Color = COL.asphalt
		existing.TopSurface = Enum.SurfaceType.Smooth
		existing.BottomSurface = Enum.SurfaceType.Smooth
		return existing
	end
	local base = Instance.new("Part")
	base.Name = "KalsadaBaseplate"
	base.Size = Vector3.new(ARENA_SIZE, 2, ARENA_SIZE)
	base.Position = Vector3.new(0, -1, 0)
	base.Anchored = true
	base.Material = Enum.Material.Asphalt
	base.Color = COL.asphalt
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent = Workspace
	return base
end

-- ── Boundary: 14-stud walls (unjumpable) + inner sidewalk curbs ──────────────
local function buildWalls()
	local h = GB.wallHeight
	-- N/S walls full width, E/W inset to their inner faces (flush corners,
	-- no overlapping corner blocks to z-fight).
	local sides = {
		{ size = Vector3.new(ARENA_SIZE, h, 2), pos = Vector3.new(0, h / 2, -(ARENA_SIZE / 2)) },
		{ size = Vector3.new(ARENA_SIZE, h, 2), pos = Vector3.new(0, h / 2, ARENA_SIZE / 2) },
		{ size = Vector3.new(2, h, ARENA_SIZE - 4), pos = Vector3.new(-(ARENA_SIZE / 2), h / 2, 0) },
		{ size = Vector3.new(2, h, ARENA_SIZE - 4), pos = Vector3.new(ARENA_SIZE / 2, h / 2, 0) },
	}
	for i, s in sides do
		part("Wall" .. i, s.size, CFrame.new(s.pos), COL.wall, Enum.Material.Concrete)
		-- painted accent band on the inside face (landmark line for readability)
		local bandSize, bandPos
		if math.abs(s.pos.Z) > 0 then
			-- inner face is 1 stud inward; band (0.4 thick) sits proud of it
			bandSize = Vector3.new(ARENA_SIZE, 1, 0.4)
			bandPos = Vector3.new(0, h - 4.5, s.pos.Z - math.sign(s.pos.Z) * 1.2)
		else
			bandSize = Vector3.new(0.4, 1, ARENA_SIZE - 4)
			bandPos = Vector3.new(s.pos.X - math.sign(s.pos.X) * 1.2, h - 4.5, 0)
		end
		part("WallBand" .. i, bandSize, CFrame.new(bandPos), COL.wallBand)
	end
end

local function buildSidewalks()
	local w = GB.sidewalkWidth -- 8 studs
	local inset = ARENA_SIZE / 2 - w / 2 - 1 -- hugging the walls (inner face 74)
	local lift = 0.3 -- height; top sits 0.15 above the street (curb)
	part("SidewalkN", Vector3.new(ARENA_SIZE, lift, w), CFrame.new(0, 0, -inset), COL.sidewalk, Enum.Material.Concrete)
	part("SidewalkS", Vector3.new(ARENA_SIZE, lift, w), CFrame.new(0, 0, inset), COL.sidewalk, Enum.Material.Concrete)
	part("SidewalkW", Vector3.new(w, lift, ARENA_SIZE - 4 - w), CFrame.new(-inset, 0, 0), COL.sidewalk, Enum.Material.Concrete)
	part("SidewalkE", Vector3.new(w, lift, ARENA_SIZE - 4 - w), CFrame.new(inset, 0, 0), COL.sidewalk, Enum.Material.Concrete)
end

-- ── Central basketball court (CourtRush zone: open, no cover) ────────────────
local function buildCourt()
	local cl, cw = GB.courtLength, GB.courtWidth -- 56 x 32
	local top = 0.05 -- slab top; just above the street to avoid z-fighting
	local keyLen, keyWide = 9, 12

	part("Court", Vector3.new(cl, 0.1, cw), CFrame.new(0, top - 0.05, 0), COL.court, Enum.Material.Concrete)

	for _, sgn in { 1, -1 } do
		-- painted key (red) under the basket
		part("CourtKey", Vector3.new(keyLen, 0.05, keyWide),
			CFrame.new(sgn * (cl / 2 - keyLen / 2), top + 0.02, 0), COL.courtKey, Enum.Material.Concrete)
		-- baseline (under the rim) + free-throw line + two key sidelines
		part("CourtLine", Vector3.new(0.5, 0.04, keyWide + 0.5),
			CFrame.new(sgn * (cl / 2 - 0.25), top + 0.05, 0), COL.line)
		part("CourtLine", Vector3.new(0.5, 0.04, keyWide + 0.5),
			CFrame.new(sgn * (cl / 2 - keyLen), top + 0.05, 0), COL.line)
		for _, z in { -keyWide / 2, keyWide / 2 } do
			part("CourtLine", Vector3.new(keyLen, 0.04, 0.5),
				CFrame.new(sgn * (cl / 2 - keyLen / 2), top + 0.05, z), COL.line)
		end

		-- hoop: pole outside the baseline, backboard + rim facing the court
		part("HoopPole", Vector3.new(1, 8, 1),
			CFrame.new(sgn * (cl / 2 + 2), 4, 0), COL.wall, Enum.Material.Metal)
		part("HoopBoard", Vector3.new(0.5, 4, 6),
			CFrame.new(sgn * (cl / 2 + 1.2), 6.5, 0), COL.line)
		local rim = part("HoopRim", Vector3.new(0.3, 3, 3),
			CFrame.new(sgn * (cl / 2 + 0.5), 5.5, 0), COL.courtKey, Enum.Material.Metal)
		rim.Shape = Enum.PartType.Cylinder -- cylinder axis X faces the court
	end

	-- halfway line + centre circle (flat disc: cylinder rotated onto its face)
	part("CourtLine", Vector3.new(0.5, 0.04, cw), CFrame.new(0, top + 0.05, 0), COL.line)
	local circle = part("CourtCircle", Vector3.new(0.04, 12, 12),
		CFrame.new(0, top + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), COL.line)
	circle.Shape = Enum.PartType.Cylinder
end

-- ── Cover & traversal props ─────────────────────────────────────────────────
-- Sari-sari blocks N/S of the court: 10-stud LOS cover, not vaultable.
-- Placement audit: z[26,38] vs court edge z=16 -> 10-stud gap (>= 10 rule);
-- nearest spawn (0,±55) -> 17 studs; max radius ~39 < spawn ring safety.
local function buildBuildings()
	for _, sgn in { 1, -1 } do
		local cz = sgn * 32
		part("SariSari", Vector3.new(GB.buildingX, GB.buildingHeight, GB.buildingZ),
			CFrame.new(0, GB.buildingHeight / 2, cz), COL.storeWall, Enum.Material.Brick)
		part("SariSariRoof", Vector3.new(GB.buildingX + 1.5, 0.6, GB.buildingZ + 1.5),
			CFrame.new(0, GB.buildingHeight + 0.3, cz), COL.storeRoof, Enum.Material.Metal)
		-- sign faces the court (readable landmark from the open centre)
		part("SariSariSign", Vector3.new(6, 2, 0.4),
			CFrame.new(0, 7, cz - sgn * (GB.buildingZ / 2 + 0.2)), COL.storeSign, Enum.Material.Neon)
	end
end

-- 4 jeepneys parked tangent to the ring road at r=48, angles 22.5+90k (midway
-- between spawn spokes: ~21 studs from any spawn centre). Roof top exactly
-- GB.jeepneyHeight = 4 -> RM_05 vaultable (jump ~7.2 clears, can also land on it).
local function buildJeepneys()
	for k = 0, 3 do
		local theta = math.rad(22.5 + k * 90)
		local pos = Vector3.new(math.cos(theta) * 48, 0, math.sin(theta) * 48)
		local cf = CFrame.new(pos) * CFrame.Angles(0, -theta - math.pi / 2, 0) -- long axis = tangent
		part("Jeepney", Vector3.new(GB.jeepneyLength, GB.jeepneyHeight, GB.jeepneyWidth),
			cf * CFrame.new(0, GB.jeepneyHeight / 2, 0), COL.jeepney, Enum.Material.Metal)
		part("JeepneyTrim", Vector3.new(GB.jeepneyLength - 0.5, 1, GB.jeepneyWidth + 0.2),
			cf * CFrame.new(0, 0.6, 0), COL.jeepTrim) -- dark skirt grounds the silhouette
	end
end

-- 4 crates merged FLUSH against the sari-sari side faces: merging leaves no
-- gap at all, so no sub-10-stud pocket can form beside them. Height 3.5 -> vault.
local function buildCrates()
	for _, sgn in { 1, -1 } do
		for _, xOff in { 12, -12 } do
			part("Crate", Vector3.new(GB.crateSize, GB.crateHeight, GB.crateSize),
				CFrame.new(xOff, GB.crateHeight / 2, sgn * 32), COL.crate, Enum.Material.WoodPlanks)
		end
	end
end

-- 2 low gaps: pillared lintels at r=50, angles 67.5/247.5 (between spokes;
-- ~15.7 studs from the nearest spawn). Clearance = GB.lowGapHeight (3.5):
-- a sliding Runner (HipHeight x0.5) passes, a standing one (5 studs) cannot.
-- Tangent orientation -> slide flows along the ring road (~0.2s of a 0.6s slide).
local function buildLowGaps()
	local depth = 4
	for _, deg in { 67.5, 247.5 } do
		local theta = math.rad(deg)
		local pos = Vector3.new(math.cos(theta) * 50, 0, math.sin(theta) * 50)
		local tangent = Vector3.new(-math.sin(theta), 0, math.cos(theta))
		local cf = CFrame.lookAt(pos, pos + tangent) -- -Z = travel, X = span
		local gap = GB.lowGapHeight
		local span = GB.lowGapSpan
		local pillarH = gap + 1 -- lintel sits flush on top of the pillars
		part("GapPillar", Vector3.new(1, pillarH, depth),
			cf * CFrame.new(-span / 2 + 0.5, pillarH / 2, 0), COL.tunnel, Enum.Material.Concrete)
		part("GapPillar", Vector3.new(1, pillarH, depth),
			cf * CFrame.new(span / 2 - 0.5, pillarH / 2, 0), COL.tunnel, Enum.Material.Concrete)
		part("GapLintel", Vector3.new(span, 1, depth),
			cf * CFrame.new(0, gap + 0.5, 0), COL.lintel, Enum.Material.Metal) -- hazard yellow = "go under"
	end
end

-- ── Spawns: 8 equidistant pads @ r=55, facing the centre, neon ground rings ──
local function ensureSpawns()
	local spawnFolder = Workspace:FindFirstChild("SpawnLocations")
	if not spawnFolder then
		spawnFolder = Instance.new("Folder")
		spawnFolder.Name = "SpawnLocations"
		spawnFolder.Parent = Workspace
	end
	for i = 1, SPAWN_COUNT do
		local angle = (math.pi * 2 / SPAWN_COUNT) * (i - 1)
		local cx = math.cos(angle) * GB.spawnRadius
		local cz = math.sin(angle) * GB.spawnRadius
		local name = string.format("Spawn%02d", i)

		local spawn = spawnFolder:FindFirstChild(name)
		if not spawn then
			spawn = Instance.new("SpawnLocation")
			spawn.Name = name
			spawn.Parent = spawnFolder
		end
		if spawn:IsA("SpawnLocation") then
			spawn.Position = Vector3.new(cx, 3, cz) -- 3 studs up: never clips the floor
			spawn.Size = Vector3.new(GB.spawnPadSize, 1.2, GB.spawnPadSize)
			spawn.Anchored = true
			spawn.Enabled = true
			spawn.AllowTeamChangeOnTouch = false
			spawn.Neutral = true
			spawn.Material = Enum.Material.SmoothPlastic
			spawn.Color = COL.spawn
			spawn.TopSurface = Enum.SurfaceType.Smooth
			spawn.BottomSurface = Enum.SurfaceType.Weld
			-- face the court (derived: forward = -Z -> yaw = 90deg - theta)
			spawn.Orientation = Vector3.new(0, 90 - math.deg(angle), 0)
			local decal = spawn:FindFirstChildOfClass("Decal")
			if decal then
				decal:Destroy()
			end
		end

		-- neon ground ring: visible from anywhere on the street (readability)
		local ring = Instance.new("Part")
		ring.Name = "SpawnRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, 16, 16) -- cylinder axis X -> rotate flat
		ring.CFrame = CFrame.new(cx, 0, cz) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = true
		ring.CanCollide = false
		ring.Color = COL.spawnRing
		ring.Material = Enum.Material.Neon
		ring.Parent = folder
	end
end

-- Full blockout rebuild: destroy + regenerate (idempotent on every boot/resync).
-- `rebuilding` suppresses the ChildRemoved listener while we destroy our own
-- folder, otherwise self-destruction would schedule an infinite rebuild loop.
local rebuilding = false
local function buildGreybox()
	rebuilding = true
	local old = Workspace:FindFirstChild("KalsadaGreybox")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "KalsadaGreybox"
	folder.Parent = Workspace

	buildWalls()
	buildSidewalks()
	buildCourt()
	buildBuildings()
	buildJeepneys()
	buildCrates()
	buildLowGaps()
	ensureSpawns()
	rebuilding = false
end

local function ensureLighting()
	Lighting.Ambient = Color3.fromRGB(120, 120, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
	Lighting.Brightness = 2
	Lighting.ClockTime = 14 -- afternoon, high readability for playtests
	Lighting.GlobalShadows = true
end

local function ensureCharacterDefaults()
	-- T09 tuning relies on WalkSpeed set at runtime, but sane defaults help
	-- before MovementController attaches (avoids 16-vs-default pop).
	StarterPlayer.CharacterWalkSpeed = Config.Movement.RunnerWalkSpeed
	StarterPlayer.CharacterJumpPower = 50 -- RM_05: vaults obstacles <= 4 studs
end

-- ── Boot ─────────────────────────────────────────────────────────────────────
ensureBaseplate()
buildGreybox()
ensureLighting()
ensureCharacterDefaults()

-- DISABLED: MatchService v1.1 owns all match state machine events (StateChanged).
-- [DISABLED] -- TEMP DEBUG (remove when MatchService T07 lands): no match state machine exists
-- [DISABLED] -- yet, so nothing ever fires StateChanged MS_04 and MovementController stays in
-- [DISABLED] -- inputLocked (WalkSpeed 0). Auto-unlock shortly after each spawn so T09 movement
-- [DISABLED] -- is testable in Studio Play right now. MatchService will own this event later.
-- [DISABLED] local DEBUG_AUTO_UNLOCK = false
-- [DISABLED] if DEBUG_AUTO_UNLOCK then
-- [DISABLED] 	Players.PlayerAdded:Connect(function(player)
-- [DISABLED] 		player.CharacterAdded:Connect(function()
-- [DISABLED] 			task.wait(1.5)
-- [DISABLED] 			StateChanged:FireClient(player, { state = "MS_04", role = "Runner" })
-- [DISABLED] 		end)
-- [DISABLED] 	end)
-- [DISABLED] 	-- Cover the player that spawned before this script ran (Play Solo).
-- [DISABLED] 	for _, player in Players:GetPlayers() do
-- [DISABLED] 		task.spawn(function()
-- [DISABLED] 			if not player.Character then
-- [DISABLED] 				player.CharacterAdded:Wait()
-- [DISABLED] 			end
-- [DISABLED] 			task.wait(1.5)
-- [DISABLED] 			StateChanged:FireClient(player, { state = "MS_04", role = "Runner" })
-- [DISABLED] 		end)
-- [DISABLED] 	end
-- [DISABLED] end

-- Late-join safety: if Workspace gets cleared, rebuild once.
Workspace.ChildRemoved:Connect(function(child)
	if child.Name == "KalsadaBaseplate" then
		task.defer(ensureBaseplate)
	end
	if child.Name == "KalsadaGreybox" and not rebuilding then
		task.defer(buildGreybox)
	end
end)

print(string.format(
	"[Bootstrap] Kalsada greybox ready — %dx%d street, walls h=%d, court %dx%d, "
		.. "4 jeepneys + 4 crates (vaults <=4), 2 low gaps (%.1f studs), "
		.. "%d spawns @ r=%d, dead-end rule >=10 studs audited. T09 movement testable.",
	ARENA_SIZE, ARENA_SIZE, GB.wallHeight, GB.courtLength, GB.courtWidth,
	GB.lowGapHeight, SPAWN_COUNT, GB.spawnRadius
))