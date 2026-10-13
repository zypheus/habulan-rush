--!strict
-- tools/AnimationDev/HRush_AnimDev.lua
-- Studio copy: Workspace/AnimationDevelopment/HRush_AnimDev (ModuleScript)
-- Owner: temporary dev tool (no module owner; NOT production gameplay code)
-- Responsibility:
--   * Builds three ORIGINAL animation KeyframeSequences for the project R15 rig:
--       HRush_Sprint (looping athletic run cycle)
--       HRush_Slide  (sprint-to-slide, 4 phases, non-looping)
--       HRush_Dash   (burst-forward dash, non-looping, hands off to sprint)
--   * Preview evaluators for MCP screenshot validation:
--       setJointsEnabled + hardPose/hardReset (Edit mode): Transform writes do
--         NOT render in Edit mode, and with joints active the physics layer
--         reverts any rotation write instantly. Disabling the rig's
--         Motor6D/AnimationConstraint joints frees the parts, so hardPose can
--         solve the posed skeleton (Part0 * C0 * pose * C1i) and write world
--         CFrames that stick. Rest pose captured on first use; re-enable and
--         hardReset after capturing.
--       showAt/reset (play mode): writes joint Transforms, which do render
--         while the run service is stepping.
-- Task refs: animation authoring task Phases 2-5; T09 MovementController.
-- Rebuild safety: buildAll() REPLACES same-named KeyframeSequences inside
--   Workspace/AnimationDevelopment only. Nothing outside that folder changes.
-- Production note: these sequences must be published from the Animation
--   Editor and their asset IDs added to Config before any runtime use; live
--   games cannot load KeyframeSequence instances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type PoseSpec = { name: string, cf: CFrame, children: { PoseSpec } }
export type JointCFs = {
	root: CFrame, waist: CFrame, neck: CFrame,
	lsh: CFrame, lelb: CFrame, rsh: CFrame, relb: CFrame,
	lhip: CFrame, lknee: CFrame, lankle: CFrame,
	rhip: CFrame, rknee: CFrame, rankle: CFrame,
}

local AnimDev = {}

local FOLDER_NAME = "AnimationDevelopment"
local SPRINT_NAME = "HRush_Sprint"
local SLIDE_NAME = "HRush_Slide"
local DASH_NAME = "HRush_Dash"

-- ── Sprint design (v3, AAA pass) ────────────────────────────────────────────
-- Built around Contact / Down / Passing / Up poses per leg at 24 samples
-- (25 keyframes incl. wrap copy) over CycleTime. Tunables first, detail below.
-- Sign conventions (character faces -Z, part-space rotations):
--   pitch +X = limbs swing forward; torso +X = lean back; knee flexion = -X;
--   elbow flexion = +X; ankle plantarflexion (toes down) = -X.
-- Assumptions: standard R15 Motor6D offsets and hip height; Pose CFrames carry
--   rotation only, except a small vertical dip on LowerTorso (BounceHeight).
--   No horizontal root translation: gameplay owns horizontal movement, so the
--   clip cannot cause animation drift or double-applied speed.
local SprintParams = {
	-- ── Style knobs (tune these first) ──
	CycleTime = 0.64, -- s per full stride cycle; range 0.60-0.70 (faster reads more aggressive)
	Samples = 24, -- keyframe intervals per cycle; Knee/Ankle tables must hold exactly this many entries
	LeanAngle = 18, -- forward torso lean in deg; range 14-22 (applied as negative root pitch)
	BounceHeight = 0.08, -- vertical torso dip in studs, deepest on contact, highest on push-off; range 0-0.15 (0 disables; lower it if feet penetrate)
	ArmPumpAmount = 46, -- shoulder swing in deg; range 38-55 (hands reach chin height at the top end)
	KneeDrive = 1.0, -- scales the knee-flexion curve; range 0.8-1.2 (peak 100 at 1.0)
	StrideLength = 44, -- hip swing in deg; range 35-50
	Asymmetry = 1.0, -- master lateral-asymmetry scale; range 0-2 (0 = perfectly mirrored)
	-- ── Fine detail ──
	Bob = 2.0, -- root pitch wobble at double stride rate (deg)
	PelvisYaw = 7, -- pelvis counter-rotation (deg)
	PelvisRoll = 3,
	WaistLean = 3,
	WaistYaw = 13, -- shoulders counter-rotate against the pelvis (deg)
	NeckPitch = 10, -- keeps the head near level over the leaned torso (deg)
	NeckYaw = 3,
	ElbowBase = 90, -- base sprinter elbow flexion carry (deg)
	ElbowVar = 12, -- front arm slightly more closed than the back arm (deg)
	ArmAsym = 2, -- left arm swings slightly wider than right (deg, scaled by Asymmetry)
	HipAsym = 1.5, -- left thigh swings slightly wider than right (deg, scaled by Asymmetry)
	ElbowAsym = 4, -- left elbow carries slightly more open than right (deg, scaled by Asymmetry)
	ShoulderBias = 2, -- constant drive bias so hands never mirror (deg, scaled by Asymmetry)
	RollBias = 1, -- constant pelvis roll trim; loop-safe (s = 0 at the boundary)
	ElbowLag = 1, -- forearm overlap behind the shoulder, in frames
	AnkleLag = 1, -- foot overlap behind the shin, in frames
	HeadLag = 2, -- head yaw overlap behind the torso, in frames
	-- Knee flexion per 1/24-cycle phase; left-leg contact at index 1, right leg
	-- reads the same curve +12. Stance spans idx 22-5, swing idx 6-21.
	-- Peak 100 during swing-through (heel toward glute), min 11 at Down.
	Knee = { 22, 18, 13, 11, 14, 24, 42, 62, 82, 95, 100, 94, 80, 62, 45, 32, 26, 24, 24, 26, 28, 26, 24, 23 },
	-- Ankle (toes-down positive) per phase; dorsiflexed through stance (-10),
	-- plantarflexion spike 26 at toe-off, neutral recovery through swing.
	Ankle = { -6, -8, -10, -8, -2, 8, 18, 26, 18, 8, 0, -4, -6, -8, -8, -6, -4, -2, 0, 0, -2, -4, -5, -6 },
}

-- ── Slide design (v3, AAA pass) ─────────────────────────────────────────────
-- Slide keyframes as phase fractions of the total duration; the live total
-- comes from Config.Movement.SlideDuration (fallback 0.6 documented below).
-- rp/wp/np = root/waist/neck pitch (+ = lean back), ry/rr = root yaw/roll,
-- hip + = thigh forward, knee = flexion, sh + = arm forward, elbow = flexion.
-- Lead leg is RIGHT (extended, knee ~straight); trailing leg is LEFT (tucked).
-- ee = per-key Pose easing: "L" Linear for decisive snaps and the steady
-- glide, "C" Cubic for anticipation, recovery, and the sprint handoff.
-- Phases: blend-in 0, anticipation 0.08, entry snap 0.16, extension 0.24,
-- glide 0.40-0.55, tuck 0.68, drive 0.80, exit pop 0.90, handoff 1.00.
local SlideParams = {
	LeanDir = 0, -- lateral style lean, -1..1 (adds roll/yaw bias; 0 = centered)
	ExitPop = 4, -- extra forward overshoot applied on the 0.90 pop key (deg)
}

local SlideKeys = {
	{ f = 0.000, ee = "C", rp = -12, ry = 0, rr = 0, wp = -3, wy = 0, np = 9, ny = 0,
		lhip = 40, lknee = 24, lankle = -6, rhip = -28, rknee = 70, rankle = -6,
		lsh = -40, lelb = 80, rsh = 35, relb = 98 }, -- blend-in: stride snapshot = sprint phi 0
	{ f = 0.080, ee = "C", rp = -9, ry = -1, rr = 1, wp = -4, wy = 2, np = 10, ny = -1,
		lhip = 44, lknee = 55, lankle = 0, rhip = -10, rknee = 80, rankle = 2,
		lsh = -34, lelb = 74, rsh = 28, relb = 86 }, -- anticipation: quick dip, weight drops
	{ f = 0.160, ee = "L", rp = 8, ry = 3, rr = 4, wp = 5, wy = 5, np = -8, ny = 2,
		lhip = 30, lknee = 90, lankle = 8, rhip = 50, rknee = 50, rankle = -4,
		lsh = -44, lelb = 66, rsh = 40, relb = 80 }, -- entry snap: fast throw into the slide
	{ f = 0.240, ee = "L", rp = 28, ry = 5, rr = 6, wp = 9, wy = 7, np = -16, ny = 2,
		lhip = 30, lknee = 115, lankle = 13, rhip = 70, rknee = 12, rankle = -8,
		lsh = -54, lelb = 62, rsh = 48, relb = 84 }, -- full extension: lead straight, trail tucked
	{ f = 0.400, ee = "L", rp = 26, ry = 5, rr = 6, wp = 8, wy = 7, np = -16, ny = 2,
		lhip = 31, lknee = 114, lankle = 14, rhip = 69, rknee = 14, rankle = -8,
		lsh = -50, lelb = 64, rsh = 44, relb = 82 }, -- glide: sustained silhouette, slight drift
	{ f = 0.550, ee = "L", rp = 25, ry = 5, rr = 7, wp = 7, wy = 6, np = -15, ny = 2,
		lhip = 31, lknee = 113, lankle = 13, rhip = 68, rknee = 15, rankle = -8,
		lsh = -48, lelb = 65, rsh = 42, relb = 82 }, -- glide end: settle, still alive
	{ f = 0.680, ee = "C", rp = 14, ry = 3, rr = 4, wp = 3, wy = 4, np = -6, ny = 1,
		lhip = 34, lknee = 95, lankle = 10, rhip = 55, rknee = 32, rankle = -6,
		lsh = -34, lelb = 70, rsh = 30, relb = 78 }, -- tuck: legs gather under the body
	{ f = 0.800, ee = "C", rp = 0, ry = 1, rr = 2, wp = -1, wy = 1, np = 2, ny = 0,
		lhip = 10, lknee = 55, lankle = 2, rhip = 20, rknee = 60, rankle = -2,
		lsh = -10, lelb = 80, rsh = 12, relb = 82 }, -- drive up: momentum lifts the torso
	{ f = 0.900, ee = "L", rp = -10, ry = 0, rr = 1, wp = -2, wy = 0, np = 6, ny = 0,
		lhip = 42, lknee = 30, lankle = -4, rhip = -26, rknee = 65, rankle = -6,
		lsh = -42, lelb = 82, rsh = 38, relb = 96 }, -- exit pop: explosive pump into sprint (+ExitPop lean)
	{ f = 1.000, ee = "C", rp = -12, ry = 0, rr = 0, wp = -3, wy = 0, np = 9, ny = 0,
		lhip = 40, lknee = 24, lankle = -6, rhip = -28, rknee = 70, rankle = -6,
		lsh = -40, lelb = 80, rsh = 35, relb = 98 }, -- handoff: identical to blend-in
}

-- Documented default from Config.Movement.SlideDuration, used only when the
-- live Config module is unavailable (e.g. the module runs in a foreign place).
local SLIDE_DURATION_FALLBACK = 0.6

-- ── Dash design (v1) ─────────────────────────────────────────────────────────
-- ORIGINAL burst-forward dash. Total length DashParams.Duration (0.42s default,
-- in the 0.35-0.50 spec band). This is the ANIMATION length, not the gameplay
-- dash: Config.Movement.DashDuration (0.2s) owns travel time, the clip overruns
-- it and blends into the sprint loop.
-- Tunables live in DashParams (one place, top of section). DashKeys references
-- them, so editing DashParams then rebuilding is enough; touch the keys only
-- to restyle phases. Sign conventions match sprint/slide: pitch +X = limbs
-- forward, torso +X = lean back (forward lean is negative rp), knee flexion is
-- stored positive and negated in dashJoints, elbow flexion positive.
-- ee = style (always "C" Cubic here: no linear snapping per spec); ed = Pose
-- direction ("O" = ease-out on the burst keys, "I" = ease-in-out elsewhere).
-- Key 4 overshoots Key 3 by TorsoOvershoot/ArmOvershoot for punch; Key 5 lets
-- the right arm swing forward early (follow-through) while the torso is still
-- settling. Final handoff is NOT tabled: buildDash appends sprintJoints(phi 0)
-- so the dash always matches the live sprint first frame exactly.
-- No HumanoidRootPart content anywhere: LowerTorso carries rotation only, so
-- dash speed stays 100% script-driven. Elbows stay open (58+) on burst keys
-- so swept-back hands clear the torso.
local DashParams = {
	Duration = 0.42, -- total clip length in s; range 0.35-0.50
	LeanPeak = 30, -- burst torso lean in deg forward; range 25-35
	ArmSweep = 50, -- burst shoulder sweep back in deg; range 40-60
	ArmOvershoot = 6, -- extra back-sweep on the overshoot key; range 0-10 (0 = no arm punch)
	TorsoOvershoot = 4, -- extra lean on the overshoot key; range 0-8
	StrideFront = 55, -- front hip drive in deg; range 45-65
	StrideBack = 48, -- rear hip extension in deg (applied negative); range 40-55
}

local DashKeys = {
	{ f = 0.000, ee = "C", ed = "I", rp = -16, ry = 0, rr = 1, wp = -4, wy = 2, np = 10, ny = 0,
		lhip = 42, lknee = 30, lankle = -4, rhip = -30, rknee = 72, rankle = -4,
		lsh = -42, lelb = 78, rsh = 32, relb = 95 }, -- anticipation start: light crouch off the run
	{ f = 0.190, ee = "C", ed = "I", rp = -(DashParams.LeanPeak - 12), ry = -1, rr = 1, wp = -5, wy = 2, np = 11, ny = 0,
		lhip = 46, lknee = 55, lankle = 0, rhip = -12, rknee = 85, rankle = 2,
		lsh = -38, lelb = 72, rsh = 28, relb = 88 }, -- anticipation dip (~0.08s): weight drops, arms gather
	{ f = 0.405, ee = "C", ed = "O", rp = -DashParams.LeanPeak, ry = 2, rr = 2, wp = -7, wy = 4, np = 15, ny = 0,
		lhip = DashParams.StrideFront, lknee = 75, lankle = 10, rhip = -DashParams.StrideBack, rknee = 18, rankle = -10,
		lsh = -(DashParams.ArmSweep + 2), lelb = 60, rsh = -(DashParams.ArmSweep - 5), relb = 65 }, -- burst peak (~0.17s): full lean, long stride, arms swept
	{ f = 0.524, ee = "C", ed = "O", rp = -(DashParams.LeanPeak + DashParams.TorsoOvershoot), ry = 2, rr = 2, wp = -8, wy = 4, np = 16, ny = 0,
		lhip = DashParams.StrideFront + 3, lknee = 78, lankle = 11, rhip = -(DashParams.StrideBack + 3), rknee = 16, rankle = -11,
		lsh = -(DashParams.ArmSweep + 2 + DashParams.ArmOvershoot), lelb = 58, rsh = -(DashParams.ArmSweep - 5 + DashParams.ArmOvershoot), relb = 62 }, -- overshoot (~0.22s): punch past the peak
	{ f = 0.714, ee = "C", ed = "I", rp = -20, ry = 0, rr = 1, wp = -4, wy = 2, np = 11, ny = 0,
		lhip = 46, lknee = 40, lankle = -2, rhip = -32, rknee = 70, rankle = -5,
		lsh = -46, lelb = 75, rsh = 30, relb = 92 }, -- recovery (~0.30s): torso rises, right arm swings forward first
}

local REQUIRED_PARTS = {
	"LowerTorso", "UpperTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

-- ── Small helpers ─────────────────────────────────────────────────────────────
local function rx(deg: number): CFrame return CFrame.Angles(math.rad(deg), 0, 0) end
local function ry(deg: number): CFrame return CFrame.Angles(0, math.rad(deg), 0) end
local function rz(deg: number): CFrame return CFrame.Angles(0, 0, math.rad(deg)) end

local function pose(name: string, cf: CFrame): PoseSpec
	return { name = name, cf = cf, children = {} }
end

-- Instantiate a pose tree under the given Keyframe (or parent Pose).
local function assemble(spec: PoseSpec, parent: Instance)
	local p = Instance.new("Pose")
	p.Name = spec.name
	p.CFrame = spec.cf
	p.EasingStyle = Enum.PoseEasingStyle.Linear
	p.Weight = 1
	p.Parent = parent
	for _, child in spec.children do
		assemble(child, p)
	end
end

-- Nest the flat joint set into the R15 pose hierarchy:
-- LowerTorso -> (UpperTorso -> Head/arms -> forearms), thighs -> shins -> feet.
local function makeTree(j: JointCFs): PoseSpec
	local root = pose("LowerTorso", j.root)
	local upper = pose("UpperTorso", j.waist)
	local head = pose("Head", j.neck)
	local lArm = pose("LeftUpperArm", j.lsh)
	local lFore = pose("LeftLowerArm", j.lelb)
	local rArm = pose("RightUpperArm", j.rsh)
	local rFore = pose("RightLowerArm", j.relb)
	local lThigh = pose("LeftUpperLeg", j.lhip)
	local lShin = pose("LeftLowerLeg", j.lknee)
	local lFoot = pose("LeftFoot", j.lankle)
	local rThigh = pose("RightUpperLeg", j.rhip)
	local rShin = pose("RightLowerLeg", j.rknee)
	local rFoot = pose("RightFoot", j.rankle)

	lArm.children = { lFore }
	rArm.children = { rFore }
	lThigh.children = { lShin }
	lShin.children = { lFoot }
	rThigh.children = { rShin }
	rShin.children = { rFoot }
	upper.children = { head, lArm, rArm }
	root.children = { upper, lThigh, rThigh }
	return root
end

local function keyframeAt(time: number, tree: PoseSpec): Keyframe
	local kf = Instance.new("Keyframe")
	kf.Time = time
	assemble(tree, kf)
	return kf
end

-- ── Rig validation ───────────────────────────────────────────────────────────
local function validateRig(rig: Model?): (Model?, Humanoid?, string?)
	if rig == nil then
		return nil, nil, "target rig not found (expected Workspace.Rig)"
	end
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil, nil, rig:GetFullName() .. " has no Humanoid"
	end
	if hum.RigType ~= Enum.HumanoidRigType.R15 then
		return nil, nil, ("rig type is %s, expected R15"):format(hum.RigType.Name)
	end
	for _, partName in REQUIRED_PARTS do
		local p = rig:FindFirstChild(partName)
		if not (p and p:IsA("BasePart")) then
			return nil, nil, ("missing R15 part %s on %s"):format(partName, rig:GetFullName())
		end
	end
	local jointCount = 0
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			jointCount += 1
		end
	end
	if jointCount < 15 then
		return nil, nil, ("found only %d Motor6D/AnimationConstraint joints (expected >= 15)"):format(jointCount)
	end
	return rig, hum, nil
end

-- ── Sprint pose math (v3) ────────────────────────────────────────────────────
-- Left-leg phase phi in [0,1); right leg runs phi + 0.5. Key poses per leg:
-- Contact (phi 0), Down (phi ~0.125), Passing/Push-off (phi ~0.25),
-- Up/fold (phi ~0.375). Overlap: elbows, ankles, and head yaw evaluate on
-- lagged phases so extremities trail their parents by 1-2 frames. Every lag
-- term is periodic in phi, so the phi=0 / phi=1 loop seam stays exact.
-- Samples must be even (legs split N/2 apart); Knee/Ankle length must equal
-- Samples (buildSprint errors otherwise instead of silently misindexing).
local function sprintJoints(phi: number, K: typeof(SprintParams)): JointCFs
	local N = K.Samples
	local c = math.cos(2 * math.pi * phi)
	local c2 = math.cos(4 * math.pi * phi)
	local s = math.sin(2 * math.pi * phi)
	local cE = math.cos(2 * math.pi * (phi - K.ElbowLag / N)) -- forearm overlap
	local cH = math.cos(2 * math.pi * (phi - K.HeadLag / N)) -- head overlap
	local asym = K.Asymmetry
	local idx = math.floor(phi * N + 0.5) % N + 1 -- nearest sample
	local idxR = (idx - 1 + N / 2) % N + 1
	local idxA = (idx - 1 - K.AnkleLag) % N + 1 -- foot overlap
	local idxRA = (idxA - 1 + N / 2) % N + 1
	local dip = K.BounceHeight * (0.5 + 0.5 * c2) -- down on contact, up on push-off
	return {
		root = CFrame.new(0, -dip, 0) * rx(-(K.LeanAngle + K.Bob * c2)) * ry(-K.PelvisYaw * c) * rz(K.PelvisRoll * s + K.RollBias),
		waist = rx(-(K.WaistLean + 0.6 * K.Bob * c2)) * ry(K.WaistYaw * c) * rz(-0.5 * K.PelvisRoll * s),
		neck = rx(K.NeckPitch + K.Bob * c2) * ry(-K.NeckYaw * cH),
		lsh = rx(-(K.ArmPumpAmount + K.ArmAsym * asym) * c - K.ShoulderBias * asym),
		lelb = rx(K.ElbowBase + K.ElbowAsym * 0.5 * asym - K.ElbowVar * cE),
		rsh = rx((K.ArmPumpAmount - K.ArmAsym * asym) * c + K.ShoulderBias * asym),
		relb = rx(K.ElbowBase - K.ElbowAsym * 0.5 * asym + K.ElbowVar * cE),
		lhip = rx((K.StrideLength + K.HipAsym * asym) * c),
		lknee = rx(-K.Knee[idx] * K.KneeDrive),
		lankle = rx(-K.Ankle[idxA]),
		rhip = rx(-(K.StrideLength - K.HipAsym * asym) * c),
		rknee = rx(-K.Knee[idxR] * K.KneeDrive),
		rankle = rx(-K.Ankle[idxRA]),
	}
end

-- ── Slide pose tables ────────────────────────────────────────────────────────
-- LeanDir adds a lateral style lean without re-authoring keys; ExitPop adds
-- an extra forward overshoot only on the 0.90 pop key (exact-fraction match).
local function slideJoints(k: typeof(SlideKeys[1])): JointCFs
	local D = SlideParams.LeanDir
	local pop = if k.f == 0.90 then SlideParams.ExitPop else 0
	return {
		root = rx(k.rp - pop) * ry(k.ry + D * 2) * rz(k.rr + D * 4),
		waist = rx(k.wp) * ry(k.wy + D * 2),
		neck = rx(k.np) * ry(k.ny),
		lsh = rx(k.lsh), lelb = rx(k.lelb), rsh = rx(k.rsh), relb = rx(k.relb),
		lhip = rx(k.lhip), lknee = rx(-k.lknee), lankle = rx(-k.lankle),
		rhip = rx(k.rhip), rknee = rx(-k.rknee), rankle = rx(-k.rankle),
	}
end

-- ── Dash pose tables ─────────────────────────────────────────────────────────
-- Pass-through like slideJoints: base numbers live in DashKeys (which already
-- references DashParams), so no extra math here. Rotation only, no position
-- offset: HumanoidRootPart motion stays script-driven.
local function dashJoints(k: typeof(DashKeys[1])): JointCFs
	return {
		root = rx(k.rp) * ry(k.ry) * rz(k.rr),
		waist = rx(k.wp) * ry(k.wy),
		neck = rx(k.np) * ry(k.ny),
		lsh = rx(k.lsh), lelb = rx(k.lelb), rsh = rx(k.rsh), relb = rx(k.relb),
		lhip = rx(k.lhip), lknee = rx(-k.lknee), lankle = rx(-k.lankle),
		rhip = rx(k.rhip), rknee = rx(-k.rknee), rankle = rx(-k.rankle),
	}
end

-- ── Pose easing ──────────────────────────────────────────────────────────────
-- Pose objects interpolate per joint. Limbs use Cubic (limb swings accelerate
-- and decelerate, so Cubic reads as weight); the core stays Linear (a Cubic-
-- smoothed torso feels mushy and lags direction changes). Elastic/Bounce are avoided
-- (cartoonish); Constant is avoided (it freezes then pops between keys).
-- Snaps come from tight key spacing (e.g. 0.08 gaps at entry), not from
-- Constant easing. Dense sprint keys (every ~27ms) make easing subtle but
-- still visible on the long swings.
local SprintEase: { [string]: Enum.PoseEasingStyle } = {
	LowerTorso = Enum.PoseEasingStyle.Linear,
	UpperTorso = Enum.PoseEasingStyle.Linear,
	Head = Enum.PoseEasingStyle.Linear,
	LeftUpperArm = Enum.PoseEasingStyle.Cubic,
	LeftLowerArm = Enum.PoseEasingStyle.Cubic,
	RightUpperArm = Enum.PoseEasingStyle.Cubic,
	RightLowerArm = Enum.PoseEasingStyle.Cubic,
	LeftUpperLeg = Enum.PoseEasingStyle.Cubic,
	LeftLowerLeg = Enum.PoseEasingStyle.Cubic,
	LeftFoot = Enum.PoseEasingStyle.Cubic,
	RightUpperLeg = Enum.PoseEasingStyle.Cubic,
	RightLowerLeg = Enum.PoseEasingStyle.Cubic,
	RightFoot = Enum.PoseEasingStyle.Cubic,
}

local SlideEaseSmooth: { [string]: Enum.PoseEasingStyle } = {
	LowerTorso = Enum.PoseEasingStyle.Cubic,
	UpperTorso = Enum.PoseEasingStyle.Cubic,
	Head = Enum.PoseEasingStyle.Cubic,
	LeftUpperArm = Enum.PoseEasingStyle.Cubic,
	LeftLowerArm = Enum.PoseEasingStyle.Cubic,
	RightUpperArm = Enum.PoseEasingStyle.Cubic,
	RightLowerArm = Enum.PoseEasingStyle.Cubic,
	LeftUpperLeg = Enum.PoseEasingStyle.Cubic,
	LeftLowerLeg = Enum.PoseEasingStyle.Cubic,
	LeftFoot = Enum.PoseEasingStyle.Cubic,
	RightUpperLeg = Enum.PoseEasingStyle.Cubic,
	RightLowerLeg = Enum.PoseEasingStyle.Cubic,
	RightFoot = Enum.PoseEasingStyle.Cubic,
}

local SlideEaseSnap: { [string]: Enum.PoseEasingStyle } = {
	LowerTorso = Enum.PoseEasingStyle.Linear,
	UpperTorso = Enum.PoseEasingStyle.Linear,
	Head = Enum.PoseEasingStyle.Linear,
	LeftUpperArm = Enum.PoseEasingStyle.Linear,
	LeftLowerArm = Enum.PoseEasingStyle.Linear,
	RightUpperArm = Enum.PoseEasingStyle.Linear,
	RightLowerArm = Enum.PoseEasingStyle.Linear,
	LeftUpperLeg = Enum.PoseEasingStyle.Linear,
	LeftLowerLeg = Enum.PoseEasingStyle.Linear,
	LeftFoot = Enum.PoseEasingStyle.Linear,
	RightUpperLeg = Enum.PoseEasingStyle.Linear,
	RightLowerLeg = Enum.PoseEasingStyle.Linear,
	RightFoot = Enum.PoseEasingStyle.Linear,
}

-- Dash uses CubicV2, not Cubic: Cubic is a legacy alias with a known
-- direction-reversal bug between the Animation Editor and runtime, and the
-- dash spec depends on direction (Out on burst, InOut on recovery).
local DashEase: { [string]: Enum.PoseEasingStyle } = {
	LowerTorso = Enum.PoseEasingStyle.CubicV2,
	UpperTorso = Enum.PoseEasingStyle.CubicV2,
	Head = Enum.PoseEasingStyle.CubicV2,
	LeftUpperArm = Enum.PoseEasingStyle.CubicV2,
	LeftLowerArm = Enum.PoseEasingStyle.CubicV2,
	RightUpperArm = Enum.PoseEasingStyle.CubicV2,
	RightLowerArm = Enum.PoseEasingStyle.CubicV2,
	LeftUpperLeg = Enum.PoseEasingStyle.CubicV2,
	LeftLowerLeg = Enum.PoseEasingStyle.CubicV2,
	LeftFoot = Enum.PoseEasingStyle.CubicV2,
	RightUpperLeg = Enum.PoseEasingStyle.CubicV2,
	RightLowerLeg = Enum.PoseEasingStyle.CubicV2,
	RightFoot = Enum.PoseEasingStyle.CubicV2,
}

local function setPoseEasing(kf: Keyframe, map: { [string]: Enum.PoseEasingStyle })
	for _, d in kf:GetDescendants() do
		if d:IsA("Pose") then
			local e = map[d.Name]
			if e then
				d.EasingStyle = e
			end
		end
	end
end

-- Dash needs EasingDirection too (ease-out burst, ease-in-out recovery); the
-- older sprint/slide path never touched it and keeps its Studio defaults.
local function setPoseEasingDirection(kf: Keyframe, dir: Enum.PoseEasingDirection)
	for _, d in kf:GetDescendants() do
		if d:IsA("Pose") then
			d.EasingDirection = dir
		end
	end
end

local function slideDuration(): (number, string?)
	local cfgModule = ReplicatedStorage:FindFirstChild("Config")
	if cfgModule and cfgModule:IsA("ModuleScript") then
		local ok, cfg = pcall(require, cfgModule)
		if ok and typeof(cfg) == "table" and typeof((cfg :: any).Movement) == "table"
			and typeof((cfg :: any).Movement.SlideDuration) == "number" then
			return (cfg :: any).Movement.SlideDuration, nil
		end
		return SLIDE_DURATION_FALLBACK, "Config present but Movement.SlideDuration unreadable; used fallback 0.6"
	end
	return SLIDE_DURATION_FALLBACK, "ReplicatedStorage.Config not found; used fallback slide duration 0.6"
end

-- ── Builders ─────────────────────────────────────────────────────────────────
function AnimDev.buildSprint(rig: Model?): (KeyframeSequence?, string?)
	local target, hum, err = validateRig(rig)
	if target == nil or hum == nil or err ~= nil then
		return nil, err
	end
	local K = SprintParams
	if #K.Knee ~= K.Samples or #K.Ankle ~= K.Samples then
		return nil, ("Knee/Ankle tables hold %d/%d entries but Samples = %d"):format(#K.Knee, #K.Ankle, K.Samples)
	end
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = SPRINT_NAME
	kfs.Loop = true
	kfs.Priority = Enum.AnimationPriority.Movement
	kfs.AuthoredHipHeight = hum.HipHeight
	for i = 0, K.Samples do -- include phi = 1 wrap copy so the loop is exact
		local phi = i / K.Samples
		local kf = keyframeAt(phi * K.CycleTime, makeTree(sprintJoints(phi, K)))
		setPoseEasing(kf, SprintEase)
		kf.Parent = kfs
	end
	return kfs, nil
end

function AnimDev.buildSlide(rig: Model?): (KeyframeSequence?, string?, string?)
	local target, hum, err = validateRig(rig)
	if target == nil or hum == nil or err ~= nil then
		return nil, nil, err
	end
	local dur, warn = slideDuration()
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = SLIDE_NAME
	kfs.Loop = false
	kfs.Priority = Enum.AnimationPriority.Action
	kfs.AuthoredHipHeight = hum.HipHeight
	for _, k in SlideKeys do
		local kf = keyframeAt(k.f * dur, makeTree(slideJoints(k)))
		setPoseEasing(kf, if k.ee == "L" then SlideEaseSnap else SlideEaseSmooth)
		kf.Parent = kfs
	end
	return kfs, warn, nil
end

function AnimDev.buildDash(rig: Model?): (KeyframeSequence?, string?)
	local target, hum, err = validateRig(rig)
	if target == nil or hum == nil or err ~= nil then
		return nil, err
	end
	local dur = DashParams.Duration
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = DASH_NAME
	kfs.Loop = false
	kfs.Priority = Enum.AnimationPriority.Action
	kfs.AuthoredHipHeight = hum.HipHeight
	for _, k in DashKeys do
		local kf = keyframeAt(k.f * dur, makeTree(dashJoints(k)))
		setPoseEasing(kf, DashEase) -- all CubicV2: no linear snapping
		setPoseEasingDirection(kf, if k.ed == "O" then Enum.PoseEasingDirection.Out else Enum.PoseEasingDirection.InOut)
		kf.Parent = kfs
	end
	-- Handoff: computed from the live sprint first frame so edits to
	-- SprintParams can never desync the blend.
	local hand = keyframeAt(dur, makeTree(sprintJoints(0, SprintParams)))
	setPoseEasing(hand, DashEase)
	setPoseEasingDirection(hand, Enum.PoseEasingDirection.InOut)
	hand.Parent = kfs
	return kfs, nil
end

-- Creates/replaces all three sequences inside Workspace/AnimationDevelopment.
-- Replaces only same-named KeyframeSequences in that folder; returns a report.
function AnimDev.buildAll(): { ok: boolean, created: { string }, replaced: { string }, warnings: { string } }
	local report = { ok = false, created = {}, replaced = {}, warnings = {} }
	local rig, _, err = validateRig(workspace:FindFirstChild("Rig") :: Model?)
	if err ~= nil then
		table.insert(report.warnings, "rig validation failed: " .. err)
		return report
	end
	local folder = workspace:FindFirstChild(FOLDER_NAME)
	if not (folder and folder:IsA("Folder")) then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = workspace
	end

	local function place(kfs: KeyframeSequence)
		local old = folder:FindFirstChild(kfs.Name)
		if old then
			old:Destroy()
			table.insert(report.replaced, kfs.Name)
		end
		kfs.Parent = folder
		table.insert(report.created, ("%s: %d keyframes, %.3gs, loop=%s, priority=%s"):format(
			kfs.Name, #kfs:GetChildren(), kfs.Length, tostring(kfs.Loop), kfs.Priority.Name))
	end

	local sprint, serr = AnimDev.buildSprint(rig)
	if sprint then
		place(sprint)
	else
		table.insert(report.warnings, "sprint: " .. tostring(serr))
	end
	local slide, swarn, slerr = AnimDev.buildSlide(rig)
	if slide then
		place(slide)
		if swarn then
			table.insert(report.warnings, "slide: " .. swarn)
		end
	else
		table.insert(report.warnings, "slide: " .. tostring(slerr))
	end
	local dash, derr = AnimDev.buildDash(rig)
	if dash then
		place(dash)
	else
		table.insert(report.warnings, "dash: " .. tostring(derr))
	end
	report.ok = (sprint ~= nil) and (slide ~= nil) and (dash ~= nil)
	print("[AnimDev] buildAll: " .. table.concat(report.created, " | "))
	return report
end

-- ── Pose evaluation (shared by both preview modes) ───────────────────────────
local function flattenPoses(node: Instance, out: { [string]: CFrame })
	if node:IsA("Pose") then
		out[node.Name] = node.CFrame
	end
	for _, child in node:GetChildren() do
		flattenPoses(child, out)
	end
end

-- Linearly interpolated pose set at time t, exactly as the Animator would
-- blend between the bracketing keyframes (Poses are 1:1 with joints).
local function evalPoses(kfs: KeyframeSequence, t: number): ({ [string]: CFrame }?, string?)
	local frames = {}
	for _, c in kfs:GetChildren() do
		if c:IsA("Keyframe") then
			table.insert(frames, c)
		end
	end
	table.sort(frames, function(a, b)
		return a.Time < b.Time
	end)
	if #frames == 0 then
		return nil, "sequence has no keyframes"
	end
	local tc = math.clamp(t, frames[1].Time, frames[#frames].Time)
	local iA = 1
	for i = 1, #frames do
		if frames[i].Time <= tc then
			iA = i
		end
	end
	local iB = math.min(iA + 1, #frames)
	local posesA: { [string]: CFrame } = {}
	local posesB: { [string]: CFrame } = {}
	flattenPoses(frames[iA], posesA)
	if iB ~= iA then
		flattenPoses(frames[iB], posesB)
	end
	local span = frames[iB].Time - frames[iA].Time
	local alpha = (span > 0) and ((tc - frames[iA].Time) / span) or 0
	local out: { [string]: CFrame } = {}
	for name, cfA in posesA do
		out[name] = cfA:Lerp(posesB[name] or cfA, alpha)
	end
	for name, cfB in posesB do
		if out[name] == nil then
			out[name] = CFrame.identity:Lerp(cfB, alpha)
		end
	end
	return out, nil
end

-- ── Play-mode preview (Transform writes render while stepping) ───────────────
local function jointMap(rig: Model): { [string]: any }
	local map = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			local p1 = (d :: any).Part1
			if p1 then
				map[p1.Name] = d
			end
		end
	end
	return map
end

function AnimDev.reset(rig: Model?): number
	local target = rig or workspace:FindFirstChild("Rig")
	if not target then
		return 0
	end
	local n = 0
	for _, joint in jointMap(target :: Model) do
		joint.Transform = CFrame.identity
		n += 1
	end
	return n
end

function AnimDev.showAt(kfs: KeyframeSequence, t: number, rig: Model?): (number, string?)
	local target = rig or workspace:FindFirstChild("Rig")
	if not target then
		return 0, "no target rig"
	end
	local poses, err = evalPoses(kfs, t)
	if poses == nil then
		return 0, err
	end
	local applied = 0
	for name, joint in jointMap(target :: Model) do
		local cf = poses[name]
		joint.Transform = cf or CFrame.identity
		if cf then
			applied += 1
		end
	end
	return applied, nil
end

-- ── Edit-mode hard pose (direct world CFrame solve) ──────────────────────────
-- Edit mode keeps joint-connected parts at their identity arrangement: any
-- rotation write is reverted instantly (translation writes stick, rotations
-- do not). Disabling the joints first makes hardPose's writes stick; call
-- setJointsEnabled(rig, false) before hardPose and restore after capturing.
local restCF: { [BasePart]: CFrame }? = nil
local restAcc: { { handle: BasePart, rel: CFrame } }? = nil

function AnimDev.setJointsEnabled(rig: Model?, enabled: boolean): number
	local target = rig or workspace:FindFirstChild("Rig")
	if not target then
		return 0
	end
	local n = 0
	for _, d in (target :: Model):GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			(d :: any).Enabled = enabled
			n += 1
		end
	end
	return n
end

local function ensureRest(rig: Model)
	if restCF ~= nil then
		return
	end
	restCF = {}
	restAcc = {}
	local head = rig:FindFirstChild("Head")
	for _, d in rig:GetDescendants() do
		if d:IsA("BasePart") then
			(restCF :: { [BasePart]: CFrame })[d :: BasePart] = (d :: BasePart).CFrame
		elseif d:IsA("Accessory") and head and head:IsA("BasePart") then
			local h = d:FindFirstChild("Handle")
			if h and h:IsA("BasePart") then
				table.insert((restAcc :: { { handle: BasePart, rel: CFrame } }),
					{ handle = h :: BasePart, rel = (head :: BasePart).CFrame:ToObjectSpace((h :: BasePart).CFrame) })
			end
		end
	end
end

function AnimDev.hardReset(rig: Model?): number
	local target = rig or workspace:FindFirstChild("Rig")
	if not target or restCF == nil then
		return 0
	end
	local n = 0
	for part, cf in restCF :: { [BasePart]: CFrame } do
		if part.Parent then
			part.CFrame = cf
			n += 1
		end
	end
	return n
end

function AnimDev.hardPose(kfs: KeyframeSequence, t: number, rig: Model?): (number, string?)
	local target = rig or workspace:FindFirstChild("Rig")
	if not target then
		return 0, "no target rig"
	end
	local r = target :: Model
	local poses, err = evalPoses(kfs, t)
	if poses == nil then
		return 0, err
	end
	ensureRest(r)
	local hrp = r:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then
		return 0, "no HumanoidRootPart"
	end
	local worldOf: { [BasePart]: CFrame } = {}
	worldOf[hrp] = hrp.CFrame
	local pending: { any } = {}
	for _, d in r:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			local j = d :: any
			if j.Part0 and j.Part1 then
				table.insert(pending, j)
			end
		end
	end
	local applied = 0
	repeat
		local progress = false
		for i = #pending, 1, -1 do
			local j = pending[i]
			local p0 = j.Part0 :: BasePart
			local p1 = j.Part1 :: BasePart
			if worldOf[p0] ~= nil and worldOf[p1] == nil then
				local cf = worldOf[p0] * j.C0 * (poses[p1.Name] or CFrame.identity) * (j.C1 :: CFrame):Inverse()
				worldOf[p1] = cf
				p1.CFrame = cf
				applied += 1
				table.remove(pending, i)
				progress = true
			end
		end
	until not progress or #pending == 0
	local head = r:FindFirstChild("Head")
	if head and head:IsA("BasePart") and restAcc ~= nil then
		for _, acc in restAcc :: { { handle: BasePart, rel: CFrame } } do
			if acc.handle.Parent then
				acc.handle.CFrame = (head :: BasePart).CFrame * acc.rel
			end
		end
	end
	return applied, if #pending > 0 then ("%d joints unsolved"):format(#pending) else nil
end

AnimDev.SprintParams = SprintParams
AnimDev.SlideKeys = SlideKeys
AnimDev.SlideParams = SlideParams
AnimDev.DashParams = DashParams
AnimDev.DashKeys = DashKeys
AnimDev.DASH_NAME = DASH_NAME
AnimDev.FOLDER_NAME = FOLDER_NAME

return AnimDev
