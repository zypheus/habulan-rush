--!strict
-- StarterPlayerScripts/SprintVFX.lua
-- Owner: Programmer A (sprint feel)
-- Responsibility: premium sprint VFX, visuals only. Reads the sprint state
-- owned by MovementController through the SprintVFXState bridge, never
-- writes speed, stamina, or input. One smoothed intensity (0 to 1) from the
-- real horizontal speed drives every effect. Pooled instances, hard caps,
-- zero per-frame work when idle. See Config.SprintVFX. No server traffic.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local SprintVFX = {}

local LocalPlayer = Players.LocalPlayer

-- TODO: remove before submission (debug prints for sprint VFX testing)
local function debugPrint(msg: string)
	if Config.Debug.ShowSprintVFX then
		print("[SprintVFX] " .. msg)
	end
end

-- Character refs, tracked per spawn.
local Character: Model? = nil
local Humanoid: Humanoid? = nil
local HRP: BasePart? = nil

-- Intensity state: the single value every effect scales from.
local active = false -- last sprint state from the MovementController bridge
local intensity = 0.0 -- smoothed 0 to 1
local startedAt = 0.0 -- os.clock of the current sprint start (Step 4 dust edge)

-- FOV state: only our own applied delta is tracked, so RS_01 kicks and the
-- aim camera capture compose instead of overwriting in both orders.
local fovApplied = 0.0

-- Speed line pool (Step 3): fixed neon streaks, preallocated, reused.
type Streak = {
	part: BasePart,
	on: boolean,
	vel: Vector3,
	life: number,
	maxLife: number,
	birth: number,
}
local vfxFolder: Folder? = nil
local lines: { Streak } = {}
local spawnAcc = 0.0
local debugAcc = 0.0 -- TODO: remove before submission (trail diagnosis timer)

-- Wind trails plus dust (Step 4): character-scoped, rebuilt per respawn
-- like the dash trail. Trails toggle Enabled so segments linger and fade.
local streakL: ParticleEmitter? = nil
local streakR: ParticleEmitter? = nil
local dustEmit: ParticleEmitter? = nil
local lastFoot: Vector3? = nil
local footTimer = 0.0

-- Remote light rigs (Step 5): one short trail plus footstep dust per fast
-- nearby Runner. No screen effects, no FOV. Scanned on a slow timer.
type RemoteRig = {
	player: Player,
	root: BasePart,
	streak: ParticleEmitter,
	emit: ParticleEmitter,
	attA: Attachment,
	dustAtt: Attachment,
	lastPos: Vector3,
	timer: number,
}
local remoteRigs: { [Player]: RemoteRig } = {}
local scanAcc = 0.0

-- Lifecycle: every connection stored, loop bound only while needed.
local conns: { RBXScriptConnection } = {}
local loopConn: RBXScriptConnection? = nil
local charConn: RBXScriptConnection? = nil
local bridgeConn: RBXScriptConnection? = nil

local function disconnectLoop()
	if loopConn ~= nil then
		loopConn:Disconnect()
		loopConn = nil
	end
end

-- Quality scale: High 1, Medium 0.75, Low 0.5. Auto picks Low on
-- touch-only devices. ReducedEffects halves again.
local function qualityScale(): number
	local q = Config.SprintVFX.Quality
	local base = 1.0
	if q == "Auto" then
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			base = 0.5
		end
	elseif q == "Low" then
		base = 0.5
	elseif q == "Medium" then
		base = 0.75
	end
	if Config.SprintVFX.ReducedEffects then
		base *= 0.5
	end
	return base
end

local function readSpeed(): number
	if HRP == nil then
		return 0
	end
	local v = HRP.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- Suppression reads existing attributes only: dash, slide, RS_01 flight,
-- Tsinelas aim, stun, role, and round. Taya reads Runner-only, so the
-- unbuilt chase variant needs no extra gate. No new plumbing.
local function suppressed(): boolean
	if LocalPlayer:GetAttribute("HRushDashing") == true then
		return true
	end
	if LocalPlayer:GetAttribute("HRushSliding") == true then
		return true
	end
	if LocalPlayer:GetAttribute("IsAirborne") == true then
		return true
	end
	if LocalPlayer:GetAttribute("HRushAiming") == "RS_03" then
		return true
	end
	if LocalPlayer:GetAttribute("HRushStunned") == true then
		return true
	end
	if LocalPlayer:GetAttribute("HRushRole") ~= "Runner" then
		return true
	end
	if LocalPlayer:GetAttribute("HRushState") ~= "MS_04" then
		return true
	end
	return false
end

-- Forward declarations: tick runs above these five definitions, so they are
-- declared here once and each later definition assigns (function X) instead
-- of creating a second local. This keeps the main loop readable at the top
-- without moving large blocks.
local updateFov: (number) -> ()
local updateLines: (number) -> ()
local updateTrails: () -> ()
local updateDust: (number) -> ()
local dumpTrailState: (number) -> ()

local function tick(dt: number)
	local cfg = Config.SprintVFX
	if not cfg.Enabled then
		intensity = 0
		disconnectLoop()
		return
	end
	local Mv = Config.Movement
	local speed = readSpeed()
	local raw = math.clamp((speed - Mv.RunnerWalkSpeed) / math.max(0.01, Mv.RunnerSprintSpeed - Mv.RunnerWalkSpeed), 0, 1)
	local supp = suppressed()
	local target = if active and not supp then raw else 0
	local rate = if target > intensity then cfg.RiseRate else (if supp then cfg.FallRate * 3 else cfg.FallRate)
	intensity = math.clamp(intensity + math.clamp(target - intensity, -rate * dt, rate * dt), 0, 1)
	if intensity <= 0 and not active then
		disconnectLoop() -- idle: zero per-frame work
	end
	-- TODO: remove before submission (diagnosis only: while the bridge says
	-- sprinting, the loop stays up even suppressed so the dump keeps printing)
	updateFov(dt)
	updateLines(dt)
	updateTrails()
	updateDust(dt)
	if active then
		debugAcc += dt
		if debugAcc >= 0.5 and Config.Debug.ShowSprintVFX then
			debugAcc = 0
			dumpTrailState(speed)
		end
	else
		debugAcc = 0
	end
end

-- Remote rigs run on their own slow loop, independent of our sprint loop,
-- so other runners read even while we stand still. 4 Hz scan, trivial cost.
local remoteConn: RBXScriptConnection? = nil
local stateConn: RBXScriptConnection? = nil

local function remoteRootSpeed(root: BasePart): number
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function dropRemoteRig(player: Player)
	local rig = remoteRigs[player]
	if rig == nil then
		return
	end
	remoteRigs[player] = nil
	Debris:AddItem(rig.attA, 1.0) -- margin only; carries the streak emitter
	Debris:AddItem(rig.dustAtt, 1.0) -- carries the dust emitter
end

local function clearAllRemoteRigs()
	for player, _ in remoteRigs do
		dropRemoteRig(player)
	end
end

local function buildRemoteRig(player: Player, root: BasePart)
	local cfg = Config.SprintVFX
	local attA = Instance.new("Attachment")
	attA.Name = "SprintRemoteA"
	attA.Position = Vector3.new(-0.5, -1.5, 0)
	attA.Parent = root
	local streak = Instance.new("ParticleEmitter")
	streak.Name = "SprintRemoteStreak"
	streak.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	streak.Rate = cfg.Streaks.RateMax
	streak.Lifetime = NumberRange.new(cfg.Streaks.Lifetime)
	streak.Speed = NumberRange.new(cfg.Streaks.SpeedMin, cfg.Streaks.SpeedMax)
	streak.SpreadAngle = Vector2.new(15, 15)
	streak.Orientation = Enum.ParticleOrientation.VelocityParallel
	streak.EmissionDirection = Enum.NormalId.Back
	streak.Acceleration = Vector3.new(0, -2, 0)
	streak.Color = ColorSequence.new(cfg.Trails.Color)
	streak.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.Streaks.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	streak.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.Streaks.TransparencyIn),
		NumberSequenceKeypoint.new(1, 1),
	})
	streak.Parent = attA
	local dustAtt = Instance.new("Attachment")
	dustAtt.Name = "SprintRemoteDust"
	dustAtt.Position = Vector3.new(0, -2.5, 0)
	dustAtt.Parent = root
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "SprintRemotePuff"
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Rate = 0 -- bursts only, never a stream
	dust.Lifetime = NumberRange.new(cfg.Dust.Life)
	dust.Speed = NumberRange.new(cfg.Dust.SpeedMin, cfg.Dust.SpeedMax)
	dust.SpreadAngle = Vector2.new(55, 55)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, -12, 0)
	dust.Color = ColorSequence.new(cfg.Dust.Color)
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.Dust.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Parent = dustAtt
	remoteRigs[player] = {
		player = player,
		root = root,
		streak = streak,
		emit = dust,
		attA = attA,
		dustAtt = dustAtt,
		lastPos = root.Position,
		timer = 0,
	}
end

local function updateRemoteScan()
	local cfg = Config.SprintVFX
	if not cfg.Enabled or HRP == nil or LocalPlayer:GetAttribute("HRushState") ~= "MS_04" then
		clearAllRemoteRigs()
		return
	end
	type Candidate = { player: Player, root: BasePart, dist: number }
	local found: { Candidate } = {}
	for _, player in Players:GetPlayers() do
		if player ~= LocalPlayer and player:GetAttribute("HRushRole") == "Runner" then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local dist = (root.Position - (HRP :: BasePart).Position).Magnitude
				if dist <= cfg.Remote.Range and remoteRootSpeed(root) >= cfg.Remote.SpeedThreshold then
					table.insert(found, { player = player, root = root, dist = dist })
				end
			end
		end
	end
	table.sort(found, function(a, b)
		return a.dist < b.dist
	end)
	local cap = math.max(1, math.floor(cfg.Remote.Cap * qualityScale()))
	local wanted: { [Player]: BasePart } = {}
	for i = 1, math.min(cap, #found) do
		wanted[found[i].player] = found[i].root
	end
	for player, rig in remoteRigs do
		local root = wanted[player]
		if root == nil or rig.root ~= root then
			dropRemoteRig(player) -- respawned or fell out; rebuild is cheap
		end
	end
	for player, root in wanted do
		if remoteRigs[player] == nil then
			buildRemoteRig(player, root)
		end
	end
	-- Footstep dust for kept rigs, tinted by their floor, never airborne.
	for _, rig in remoteRigs do
		rig.timer += 1 / cfg.Remote.ScanRate
		local hum = rig.player.Character and rig.player.Character:FindFirstChildOfClass("Humanoid")
		local mat = hum and (hum :: Humanoid).FloorMaterial or Enum.Material.Air
		if mat == Enum.Material.Air then
			rig.lastPos = rig.root.Position
		elseif (rig.root.Position - rig.lastPos).Magnitude >= cfg.Dust.FootstepDistance
			and rig.timer >= 1 / cfg.Dust.FootstepRate then
			local tints = cfg.Dust.Tints
			rig.emit.Color = ColorSequence.new(tints[mat.Name] or cfg.Dust.Color)
			rig.emit:Emit(math.max(1, math.floor(cfg.Dust.PuffCount * qualityScale())))
			rig.lastPos = rig.root.Position
			rig.timer = 0
		end
	end
end

local function remoteTick(dt: number)
	scanAcc += dt
	if scanAcc < 1 / Config.SprintVFX.Remote.ScanRate then
		return
	end
	scanAcc = 0
	updateRemoteScan()
end

local function ensureRemoteLoop()
	if remoteConn ~= nil or not Config.SprintVFX.Enabled then
		return
	end
	remoteConn = RunService.Heartbeat:Connect(remoteTick)
end

local function disconnectRemoteLoop()
	clearAllRemoteRigs()
	if remoteConn ~= nil then
		remoteConn:Disconnect()
		remoteConn = nil
	end
	scanAcc = 0
end

-- TODO: remove before submission (temporary streak diagnosis dump)
function dumpTrailState(speed: number)
	for _, streak in { streakL, streakR } do
		if streak == nil then
			print("[SprintVFX] streak MISSING (not built)") -- TODO: remove before submission
		else
			local anchor = streak.Parent
			local pp = if anchor and anchor:IsA("Attachment") then anchor.WorldPosition else Vector3.zero
			print(string.format(
				"[SprintVFX] intensity=%.2f speed=%.1f suppressed=%s enabled=%s rate=%.0f lifetime=%.2f orient=%s anchor=(%.1f,%.1f,%.1f)",
				intensity, speed, tostring(suppressed()),
				tostring(streak.Enabled), streak.Rate, streak.Lifetime.Min,
				tostring(streak.Orientation),
				pp.X, pp.Y, pp.Z
			)) -- TODO: remove before submission
		end
	end
end

function updateTrails()
	local cfg = Config.SprintVFX
	local forced = Config.Debug.ForceTrailsVisible
	local on = forced or intensity >= cfg.Trails.IntensityOn
	local rate = if forced
		then cfg.Streaks.RateMax
		else (cfg.Streaks.RateMin + (cfg.Streaks.RateMax - cfg.Streaks.RateMin) * intensity) * qualityScale()
	for _, streak in { streakL, streakR } do
		if streak ~= nil then
			streak.Enabled = on
			streak.Rate = rate
		end
	end
end

-- Floor tint from the material name, no raycasts. Air means no dust.
local function dustTint(): Color3?
	if Humanoid == nil then
		return nil
	end
	local mat = Humanoid.FloorMaterial
	if mat == Enum.Material.Air then
		return nil
	end
	local tints = Config.SprintVFX.Dust.Tints
	return tints[mat.Name] or Config.SprintVFX.Dust.Color
end

function updateDust(dt: number)
	if dustEmit == nil or HRP == nil or intensity <= 0.5 then
		return
	end
	local tint = dustTint()
	if tint == nil then
		lastFoot = HRP.Position
		return -- airborne: feet leave no dust
	end
	footTimer += dt
	if lastFoot == nil then
		lastFoot = HRP.Position
		return
	end
	local moved = (HRP.Position - lastFoot).Magnitude
	local cfg = Config.SprintVFX
	if moved >= cfg.Dust.FootstepDistance and footTimer >= 1 / cfg.Dust.FootstepRate then
		dustEmit.Color = ColorSequence.new(tint)
		dustEmit:Emit(math.max(1, math.floor(cfg.Dust.PuffCount * qualityScale())))
		lastFoot = HRP.Position
		footTimer = 0
	end
end

local function ensureLoop()
	if loopConn ~= nil then
		return
	end
	loopConn = RunService.Heartbeat:Connect(tick)
end

-- FOV widen driven only by intensity through our own delta. Adding and
-- removing just the difference means concurrent RS_01 kicks and aim camera
-- captures keep working; nothing is ever overwritten.
function updateFov(dt: number)
	local cfg = Config.SprintVFX
	local want = 0.0
	if not cfg.ReducedEffects then
		want = cfg.FovDelta * intensity
	end
	if want == fovApplied then
		return
	end
	local dur = if want > fovApplied then cfg.FovInTime else cfg.FovOutTime
	local k = 3 / math.max(dur, 0.01)
	local nextFov = fovApplied + (want - fovApplied) * (1 - math.exp(-k * dt))
	if math.abs(nextFov - want) < 0.05 then
		nextFov = want
	end
	local cam = Workspace.CurrentCamera
	if cam ~= nil then
		cam.FieldOfView += (nextFov - fovApplied)
	end
	fovApplied = nextFov
end

local function removeFov()
	local cam = Workspace.CurrentCamera
	if cam ~= nil and fovApplied ~= 0 then
		cam.FieldOfView -= fovApplied
	end
	fovApplied = 0
end

-- Travel facing: real motion first, character facing as fallback.
local function facingDir(): Vector3
	if Humanoid then
		local m = Humanoid.MoveDirection
		if m.Magnitude > 0.1 then
			return Vector3.new(m.X, 0, m.Z).Unit
		end
	end
	if HRP then
		local l = HRP.CFrame.LookVector
		local f = Vector3.new(l.X, 0, l.Z)
		if f.Magnitude > 0.01 then
			return f.Unit
		end
	end
	return Vector3.new(0, 0, -1)
end

local function parkStreak(s: Streak)
	s.on = false
	s.life = 0
	s.part.Transparency = 1
	s.part.CFrame = CFrame.new(0, -1000, 0)
end

local function activeLineCount(): number
	local n = 0
	for _, s in lines do
		if s.on then
			n += 1
		end
	end
	return n
end

-- One recycled streak: ring band beside or behind the character, never in
-- the forward cone, drifting backward along the travel direction.
local function spawnStreak()
	local cfg = Config.SprintVFX
	local L = cfg.Lines
	local qs = qualityScale()
	if activeLineCount() >= math.floor(L.Max * qs) then
		return
	end
	if HRP == nil then
		return
	end
	for _, s in lines do
		if not s.on then
			local f = facingDir()
			local half = math.rad(L.CenterConeDeg / 2)
			local ang = half + math.random() * math.rad(360 - L.CenterConeDeg)
			local off = CFrame.Angles(0, ang, 0) * f
			local radius = L.InnerRadius + math.random() * (L.OuterRadius - L.InnerRadius)
			local yOff = (math.random() - 0.5) * (L.OuterRadius - L.InnerRadius)
			local pos = HRP.Position + off * radius + Vector3.new(0, yOff, 0)
			local len = L.LengthMin + math.random() * (L.LengthMax - L.LengthMin)
			local thick = L.ThickMin + math.random() * (L.ThickMax - L.ThickMin)
			local drift = L.DriftMin + math.random() * (L.DriftMax - L.DriftMin)
			s.vel = -f * drift
			s.maxLife = L.LifeMin + math.random() * (L.LifeMax - L.LifeMin)
			s.life = s.maxLife
			s.birth = math.clamp(L.TransMax - (L.TransMax - L.TransMin) * intensity, 0, 1)
			s.part.Size = Vector3.new(thick, thick, len)
			s.part.Color = cfg.Colors.LineStart:Lerp(cfg.Colors.LineEnd, math.random())
			s.part.Transparency = s.birth
			s.part.CFrame = CFrame.lookAt(pos, pos + s.vel)
			s.on = true
			return
		end
	end
end

function updateLines(dt: number)
	local cfg = Config.SprintVFX
	local qs = qualityScale()
	if intensity > 0.02 and HRP ~= nil then
		spawnAcc += (cfg.Lines.SpawnMin + (cfg.Lines.SpawnMax - cfg.Lines.SpawnMin) * intensity) * qs * dt
		while spawnAcc >= 1 do
			spawnAcc -= 1
			spawnStreak()
		end
	else
		spawnAcc = 0
	end
	for _, s in lines do
		if s.on then
			s.life -= dt
			if s.life <= 0 then
				parkStreak(s)
			else
				s.part.CFrame += s.vel * dt
				s.part.Transparency = s.birth + (1 - s.birth) * (1 - s.life / s.maxLife)
			end
		end
	end
end

local function onSprint(state: unknown)
	if typeof(state) ~= "boolean" then
		return
	end
	active = state
	if state then
		startedAt = os.clock()
		-- Sprint start edge: one outward puff when grounded, never in air.
		local tint = dustTint()
		if dustEmit ~= nil and tint ~= nil then
			dustEmit.Color = ColorSequence.new(tint)
			dustEmit:Emit(math.floor(Config.SprintVFX.Dust.StartBurst * qualityScale()))
		end
		ensureLoop()
	end
	debugPrint("sprint " .. (if state then "start" else "stop")) -- TODO: remove before submission
end

-- Character-scoped effects, rebuilt per respawn. Anchors sit on the root
-- part because it exists on every rig at torso height. The parts die with
-- the character, so respawn cannot leak them; refs are re-taken here.
local function buildCharacterFx()
	streakL = nil
	streakR = nil
	dustEmit = nil
	if HRP == nil then
		return
	end
	local cfg = Config.SprintVFX
	local forced = Config.Debug.ForceTrailsVisible
	for _, side in { -cfg.Trails.SideX, cfg.Trails.SideX } do
		local attA = Instance.new("Attachment")
		attA.Name = "SprintTrailA"
		attA.Position = Vector3.new(side, cfg.Trails.HeightY, 0)
		attA.Parent = HRP
		-- Wind streak (Trail fallback): rate-scaled emitter, particles
		-- oriented along their backward drift, world-locked so the running
		-- character streams through them.
		local streak = Instance.new("ParticleEmitter")
		streak.Name = "SprintWindStreak"
		streak.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		streak.Rate = 0
		streak.Lifetime = NumberRange.new(cfg.Streaks.Lifetime)
		streak.Speed = NumberRange.new(cfg.Streaks.SpeedMin, cfg.Streaks.SpeedMax)
		streak.SpreadAngle = Vector2.new(15, 15)
		streak.Orientation = Enum.ParticleOrientation.VelocityParallel
		streak.EmissionDirection = Enum.NormalId.Back
		streak.Acceleration = Vector3.new(0, -2, 0)
		streak.Color = ColorSequence.new(cfg.Trails.Color)
		streak.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, cfg.Streaks.Size),
			NumberSequenceKeypoint.new(1, 0),
		})
		streak.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, cfg.Streaks.TransparencyIn),
			NumberSequenceKeypoint.new(1, 1),
		})
		streak.Parent = attA
		if side < 0 then
			streakL = streak
		else
			streakR = streak
		end
	end
	local dustAtt = Instance.new("Attachment")
	dustAtt.Name = "SprintDust"
	dustAtt.Position = Vector3.new(0, -2.5, 0) -- at the feet where dust kicks up
	dustAtt.Parent = HRP
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "SprintDustBurst"
	dust.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	dust.Rate = 0 -- bursts only, never a stream (mobile particle budget)
	dust.Lifetime = NumberRange.new(cfg.Dust.Life)
	dust.Speed = NumberRange.new(cfg.Dust.SpeedMin, cfg.Dust.SpeedMax)
	dust.SpreadAngle = Vector2.new(55, 55)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, -12, 0) -- dust settles, it does not float
	dust.Color = ColorSequence.new(cfg.Dust.Color)
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.Dust.Size),
		NumberSequenceKeypoint.new(1, 0),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Parent = dustAtt
	dustEmit = dust
end

local function trackCharacter(char: Model)
	Character = char
	Humanoid = char:WaitForChild("Humanoid") :: Humanoid
	HRP = char:WaitForChild("HumanoidRootPart") :: BasePart
	buildCharacterFx()
	-- Reset per spawn: park the pool, drop our FOV delta, drain silently.
	for _, s in lines do
		parkStreak(s)
	end
	spawnAcc = 0
	lastFoot = nil
	footTimer = 0
	removeFov()
	active = false
	intensity = 0
	disconnectLoop()
end

local function buildPool()
	if vfxFolder ~= nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SprintVFX"
	folder.Parent = Workspace
	vfxFolder = folder
	for _ = 1, Config.SprintVFX.Lines.Max do
		local part = Instance.new("Part")
		part.Name = "SprintLine"
		part.Shape = Enum.PartType.Block
		part.Size = Vector3.new(0.1, 0.1, 2)
		part.Color = Config.SprintVFX.Colors.LineStart
		part.Material = Enum.Material.Neon
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.new(0, -1000, 0)
		part.Parent = folder
		table.insert(lines, {
			part = part,
			on = false,
			vel = Vector3.zero,
			life = 0,
			maxLife = 1,
			birth = 1,
		})
	end
end

function SprintVFX:Init()
	buildPool()
	charConn = LocalPlayer.CharacterAdded:Connect(trackCharacter)
	table.insert(conns, charConn)
	if LocalPlayer.Character then
		trackCharacter(LocalPlayer.Character)
	end
	-- Bridge owned here; MovementController only fires it (find, never create).
	local existing = ReplicatedStorage:FindFirstChild("SprintVFXState")
	local bridge: BindableEvent
	if existing and existing:IsA("BindableEvent") then
		bridge = existing
	else
		local be = Instance.new("BindableEvent")
		be.Name = "SprintVFXState"
		be.Parent = ReplicatedStorage
		bridge = be
	end
	bridgeConn = bridge.Event:Connect(onSprint)
	table.insert(conns, bridgeConn)
	-- Remote loop follows the round, not our sprint.
	stateConn = LocalPlayer:GetAttributeChangedSignal("HRushState"):Connect(function()
		if LocalPlayer:GetAttribute("HRushState") == "MS_04" then
			ensureRemoteLoop()
		else
			disconnectRemoteLoop()
		end
	end)
	table.insert(conns, stateConn)
	if LocalPlayer:GetAttribute("HRushState") == "MS_04" then
		ensureRemoteLoop()
	end
	debugPrint("init, quality scale " .. tostring(qualityScale())) -- TODO: remove before submission
end

function SprintVFX:Destroy()
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	bridgeConn = nil
	charConn = nil
	stateConn = nil
	disconnectLoop()
	disconnectRemoteLoop()
	active = false
	intensity = 0
	spawnAcc = 0
	removeFov()
	if vfxFolder ~= nil then
		vfxFolder:Destroy()
		vfxFolder = nil
	end
	table.clear(lines)
	Character = nil
	Humanoid = nil
	HRP = nil
	debugPrint("destroy") -- TODO: remove before submission
end

return SprintVFX
