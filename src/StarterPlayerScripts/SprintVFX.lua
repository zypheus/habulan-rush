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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- Sibling module (same Rojo sync): player VFX scale and reduced camera flag.
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))

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

-- Limb trails (legs plus hands): character-scoped, rebuilt per respawn
-- like the dash trail. Trails toggle Enabled so segments linger and fade.
-- One spec per limb; a hand part that is missing is skipped, so nothing
-- ever lands on the torso.
type LimbSpec = {
	partName: string,
	side: string,
	group: string, -- "Leg" or "Arm"
}
local limbSpecs: { LimbSpec } = {
	{ partName = "LeftLowerLeg", side = "L", group = "Leg" },
	{ partName = "RightLowerLeg", side = "R", group = "Leg" },
	{ partName = "LeftHand", side = "LH", group = "Arm" },
	{ partName = "RightHand", side = "RH", group = "Arm" },
}
local limbTrailBySide: { [string]: Trail } = {}
local lastTrailIntensity: number? = nil
local lastTrailOn: boolean? = nil
local lastFirstPerson: boolean? = nil
local Head: BasePart? = nil
local dustEmit: ParticleEmitter? = nil
local lastFoot: Vector3? = nil
local footTimer = 0.0

-- Remote light rigs (Step 5): one short trail plus footstep dust per fast
-- nearby Runner. No screen effects, no FOV. Scanned on a slow timer.
type RemoteRig = {
	player: Player,
	root: BasePart,
	trail: Trail,
	emit: ParticleEmitter,
	attA: Attachment,
	attB: Attachment,
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
-- touch-only devices. ReducedEffects halves again. The player VFX slider
-- multiplies on top: at 100 percent this reads exactly as before.
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
	return base * VfxScale.player()
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

-- First person reads the camera to head distance against the same Config
-- value the aim camera uses for first person. A missing camera or head
-- reads as third person, so the trails stay on.
local function isFirstPerson(): boolean
	local cam = Workspace.CurrentCamera
	if cam == nil or Head == nil then
		return false
	end
	local dist = (cam.CFrame.Position - (Head :: BasePart).Position).Magnitude
	return dist <= Config.UI.TsinelasCam.FirstPersonDistance
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
	-- Stop drawing immediately: disable first, then destroy the holders.
	-- No Debris delay, so a dropped rig never lingers on screen.
	rig.trail.Enabled = false
	rig.attA:Destroy() -- carries the trail
	rig.attB:Destroy()
	rig.dustAtt:Destroy() -- carries the dust emitter
end

local function clearAllRemoteRigs()
	for player, _ in remoteRigs do
		dropRemoteRig(player)
	end
end

local function buildRemoteRig(player: Player, root: BasePart)
	local cfg = Config.SprintVFX
	local qs = qualityScale()
	local spacing = cfg.Remote.AttachmentSpacing
	local attA = Instance.new("Attachment")
	attA.Name = "SprintRemoteA"
	attA.Position = Vector3.new(0, cfg.Remote.CenterY + spacing / 2, 0)
	attA.Parent = root
	local attB = Instance.new("Attachment")
	attB.Name = "SprintRemoteB"
	attB.Position = Vector3.new(0, cfg.Remote.CenterY - spacing / 2, 0)
	attB.Parent = root
	-- One short trail per remote runner, same cyan to blue palette as the
	-- local leg trails, width scaled by the quality scale.
	local trail = Instance.new("Trail")
	trail.Name = "SprintRemoteTrail"
	trail.Attachment0 = attA
	trail.Attachment1 = attB
	trail.FaceCamera = true
	trail.Lifetime = cfg.Remote.Lifetime
	trail.LightEmission = cfg.Brightness.TrailLightEmission
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cfg.Colors.ElectricCyan),
		ColorSequenceKeypoint.new(cfg.Trail.ColorMid, cfg.Colors.BrightBlue),
		ColorSequenceKeypoint.new(1.0, cfg.Colors.BrightBlue),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.Remote.WidthScaleStart * qs),
		NumberSequenceKeypoint.new(1, cfg.Remote.WidthScaleEnd * qs),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.Remote.Transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Enabled = true
	trail.Parent = attA
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
		trail = trail,
		emit = dust,
		attA = attA,
		attB = attB,
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
				local mv = Config.Movement
				local gate = mv.RunnerWalkSpeed * mv.SpeedScale + cfg.Remote.ThresholdRatio * ((mv.RunnerSprintSpeed - mv.RunnerWalkSpeed) * mv.SpeedScale)
				if dist <= cfg.Remote.Range and remoteRootSpeed(root) >= gate then
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
	for _, spec in limbSpecs do
		local tr = limbTrailBySide[spec.side]
		if tr == nil then
			print("[SprintVFX] " .. spec.side .. " trail MISSING (not built)") -- TODO: remove before submission
		else
			local a0 = tr.Attachment0
			local a1 = tr.Attachment1
			local p0 = if a0 and a0:IsA("Attachment") then a0.WorldPosition else Vector3.zero
			local p1 = if a1 and a1:IsA("Attachment") then a1.WorldPosition else Vector3.zero
			local dist = (p0 - p1).Magnitude
			print(string.format(
				"[SprintVFX] %s trail: intensity=%.2f speed=%.1f suppressed=%s enabled=%s lifetime=%.2f spacing=%.3f att0=(%.1f,%.1f,%.1f) parent=%s",
				spec.side, intensity, speed, tostring(suppressed()),
				tostring(tr.Enabled), tr.Lifetime, dist,
				p0.X, p0.Y, p0.Z,
				tostring(tr.Parent and tr.Parent.Name)
			)) -- TODO: remove before submission
		end
	end
end

function updateTrails()
	local cfg = Config.SprintVFX
	local forced = Config.Debug.ForceTrailsVisible
	local on = forced or intensity >= cfg.Trail.IntensityThreshold
	local firstPerson = isFirstPerson()
	local step = cfg.Trail.IntensityStep
	local lastApplied: number = if lastTrailIntensity == nil then -step * 2 else (lastTrailIntensity :: number)
	local intensityChanged = lastTrailIntensity == nil or math.abs(intensity - lastApplied) >= step
	local onChanged = lastTrailOn == nil or on ~= lastTrailOn
	local viewChanged = lastFirstPerson == nil or firstPerson ~= lastFirstPerson
	if not intensityChanged and not onChanged and not viewChanged then
		return
	end
	lastTrailIntensity = intensity
	lastTrailOn = on
	lastFirstPerson = firstPerson
	local tIn = math.clamp(cfg.Trail.FadeBase - intensity, cfg.Trail.FadeMin, cfg.Trail.FadeMax)
	local transSeq = NumberSequence.new({
		NumberSequenceKeypoint.new(0, tIn),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, spec in limbSpecs do
		local tr = limbTrailBySide[spec.side]
		if tr ~= nil then
			-- Arm trails hide in first person so they never fill the screen.
			local show = on and not (spec.group == "Arm" and firstPerson)
			tr.Enabled = show
			tr.Transparency = transSeq
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
	-- Player reduced-camera toggle joins the Config override: either one eases
	-- the widening back to zero, live, with no snap.
	if not cfg.ReducedEffects and not VfxScale.reducedCamera() then
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
			local drift = (L.DriftMin + math.random() * (L.DriftMax - L.DriftMin)) * Config.Movement.SpeedScale
			s.vel = -f * drift
			s.maxLife = L.LifeMin + math.random() * (L.LifeMax - L.LifeMin)
			s.life = s.maxLife
			s.birth = math.clamp(L.TransMax - (L.TransMax - L.TransMin) * intensity, 0, 1)
			s.part.Size = Vector3.new(thick, thick, len)
			-- Cyan to blue like the leg trails, with icy white on a small
			-- share of lines so the trail stays the focus.
			if math.random() < L.IcyShare then
				s.part.Color = cfg.Colors.IcyWhite
			else
				s.part.Color = cfg.Colors.ElectricCyan:Lerp(cfg.Colors.BrightBlue, math.random())
			end
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

-- Character-scoped effects, rebuilt per respawn. Leg trail anchors sit on
-- the lower legs (R15 LeftLowerLeg and RightLowerLeg, HRP fallback); arm
-- trail anchors sit on the hands (R15 LeftHand and RightHand, skipped when
-- missing so nothing lands on the torso). The parts die with the
-- character, so respawn cannot leak them; refs are re-taken here.
local function buildCharacterFx()
	table.clear(limbTrailBySide)
	dustEmit = nil
	if HRP == nil or Character == nil then
		return
	end
	local cfg = Config.SprintVFX
	local forced = Config.Debug.ForceTrailsVisible
	local colorSeq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, cfg.Colors.ElectricCyan),
		ColorSequenceKeypoint.new(cfg.Trail.ColorMid, cfg.Colors.BrightBlue),
		ColorSequenceKeypoint.new(1.0, cfg.Colors.BrightBlue),
	})
	local tIn = math.clamp(cfg.Trail.FadeBase - intensity, cfg.Trail.FadeMin, cfg.Trail.FadeMax)
	local transSeq = NumberSequence.new({
		NumberSequenceKeypoint.new(0, tIn),
		NumberSequenceKeypoint.new(1, 1),
	})

	for _, spec in limbSpecs do
		local isArm = spec.group == "Arm"
		local set = if isArm then cfg.Trail.Arm else cfg.Trail
		local parentPart: BasePart? = nil
		if isArm then
			local hand = Character:FindFirstChild(spec.partName)
			if hand ~= nil and hand:IsA("BasePart") then
				parentPart = hand
			end
		elseif spec.side == "L" then
			parentPart = (Character:FindFirstChild(spec.partName) or Character:WaitForChild(spec.partName, 1) or Character:FindFirstChild("Left Leg") or HRP) :: BasePart
		else
			parentPart = (Character:FindFirstChild(spec.partName) or Character:WaitForChild(spec.partName, 1) or Character:FindFirstChild("Right Leg") or HRP) :: BasePart
		end
		if parentPart == nil then
			continue -- hand missing: skip, never fall back to the torso
		end
		local widthSeq = NumberSequence.new({
			NumberSequenceKeypoint.new(0, set.WidthScaleStart),
			NumberSequenceKeypoint.new(1, set.WidthScaleEnd),
		})
		-- Positive SideX means outward from the centerline on every limb.
		-- The sign is derived from the part position relative to HRP, so no
		-- assumption about left or right local axes is needed.
		local rootPart = HRP :: BasePart
		local relX = rootPart.CFrame:PointToObjectSpace(parentPart.Position).X
		local dir = if relX > 0.001 then 1 else (if relX < -0.001 then -1 else 0)
		local xOff = dir * set.SideX
		local att0 = Instance.new("Attachment")
		att0.Name = "SprintTrailAtt0_" .. spec.side
		att0.Position = Vector3.new(xOff, set.HeightY + set.AttachmentSpacing / 2, set.DepthZ)
		att0.Parent = parentPart

		local att1 = Instance.new("Attachment")
		att1.Name = "SprintTrailAtt1_" .. spec.side
		att1.Position = Vector3.new(xOff, set.HeightY - set.AttachmentSpacing / 2, set.DepthZ)
		att1.Parent = parentPart

		local trail = Instance.new("Trail")
		trail.Name = "NeonSpeedTrail_" .. spec.side
		trail.Attachment0 = att0
		trail.Attachment1 = att1
		trail.FaceCamera = true
		trail.Lifetime = set.Lifetime
		trail.MaxLength = set.MaxLength * Config.Movement.SpeedScale
		trail.LightEmission = cfg.Brightness.TrailLightEmission
		trail.Color = colorSeq
		trail.WidthScale = widthSeq
		trail.Transparency = transSeq
		trail.Enabled = forced or (intensity >= cfg.Trail.IntensityThreshold)
		trail.Parent = parentPart

		limbTrailBySide[spec.side] = trail
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
	local head = char:FindFirstChild("Head")
	Head = if head ~= nil and head:IsA("BasePart") then head else nil
	-- Reset per spawn first, then build, so a new character never starts with old intensity.
	for _, s in lines do
		parkStreak(s)
	end
	spawnAcc = 0
	lastFoot = nil
	footTimer = 0
	removeFov()
	active = false
	intensity = 0
	lastTrailIntensity = nil
	lastTrailOn = nil
	lastFirstPerson = nil
	disconnectLoop()
	buildCharacterFx()
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
		part.Color = Config.SprintVFX.Colors.ElectricCyan
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
	lastTrailIntensity = nil
	lastTrailOn = nil
	lastFirstPerson = nil
	spawnAcc = 0
	removeFov()
	if vfxFolder ~= nil then
		vfxFolder:Destroy()
		vfxFolder = nil
	end
	table.clear(lines)
	table.clear(limbTrailBySide)
	dustEmit = nil
	Character = nil
	Humanoid = nil
	HRP = nil
	Head = nil
	debugPrint("destroy") -- TODO: remove before submission
end

return SprintVFX
