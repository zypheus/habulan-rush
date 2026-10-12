--!strict
-- tools/AnimationDev/HRush_AnimDev.lua
-- Studio copy: Workspace/AnimationDevelopment/HRush_AnimDev (ModuleScript)
-- Owner: temporary dev tool (no module owner; NOT production gameplay code)
-- Responsibility:
--   * Builds two ORIGINAL animation KeyframeSequences for the project R15 rig:
--       HRush_Sprint (looping athletic run cycle)
--       HRush_Slide  (sprint-to-slide, 4 phases, non-looping)
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

-- ── Centralized design parameters (degrees / seconds) ────────────────────────
-- Sign conventions for this rig (character faces -Z, part-space rotations):
--   pitch +X = limbs swing forward; torso +X = lean back; knee flexion = -X;
--   elbow flexion = +X; ankle plantarflexion (toes down) = -X.
local SprintParams = {
	Cycle = 0.72, -- s per full stride cycle (both legs); target band 0.65-0.85
	Samples = 12, -- keyframe intervals per cycle (13 keyframes incl. wrap copy)
	HipAmp = 40, -- thigh swing amplitude
	Lean = 12, -- forward torso lean (root pitch, negative rx applied)
	Bob = 2.5, -- lean oscillation at double stride rate
	PelvisYaw = 7, -- pelvis counter-rotation
	PelvisRoll = 2,
	WaistLean = 2,
	WaistYaw = 14, -- shoulders counter-rotate against the pelvis
	NeckPitch = 8, -- keeps the head near level over the leaned torso
	NeckYaw = 4,
	ArmAmp = 42, -- shoulder swing (opposite the same-side leg)
	Elbow = 84, -- base sprinter elbow flexion carry
	ElbowVar = 8, -- front arm slightly more closed than the back arm
	-- Knee flexion per 1/12-cycle phase; phase 0 = left-leg contact.
	-- Peak 95 deg during swing-through (phase 7/12), near-extended mid-stance.
	Knee = { 22, 18, 11, 14, 34, 55, 78, 95, 92, 68, 38, 26 },
	-- Ankle plantarflexion (+ = toes down) per phase; push-off spike at 5/12.
	Ankle = { 4, -4, -6, 0, 14, 26, 18, 4, -8, -10, -6, 0 },
}

-- Slide keyframes as phase fractions of the total duration; the live total
-- comes from Config.Movement.SlideDuration (fallback 0.6 documented below).
-- rp/wp/np = root/waist/neck pitch (+ = lean back), ry/rr = root yaw/roll,
-- hip + = thigh forward, knee = flexion, sh + = arm forward, elbow = flexion.
-- Phases: 0-.15 anticipation, .15-.35 entry, .35-.75 sustain, .75-1 recovery.
local SlideKeys = {
	{ f = 0.000, rp = -10, ry = 0, rr = 0, wp = -2, wy = 0, np = 8, ny = 0,
		lhip = 20, lknee = 40, lankle = 0, rhip = 30, rknee = 60, rankle = 0,
		lsh = -20, lelb = 78, rsh = 20, relb = 86 }, -- sprint-average blend-in
	{ f = 0.150, rp = -6, ry = -2, rr = 2, wp = -4, wy = 4, np = 12, ny = -2,
		lhip = 48, lknee = 78, lankle = 8, rhip = 58, rknee = 84, rankle = 10,
		lsh = -30, lelb = 70, rsh = 30, relb = 74 }, -- anticipation crouch
	{ f = 0.250, rp = 10, ry = 3, rr = 4, wp = 6, wy = 6, np = -10, ny = 2,
		lhip = 26, lknee = 108, lankle = 12, rhip = 64, rknee = 30, rankle = -6,
		lsh = -42, lelb = 66, rsh = 38, relb = 80 }, -- slide entry
	{ f = 0.350, rp = 24, ry = 5, rr = 6, wp = 8, wy = 7, np = -18, ny = 2,
		lhip = 30, lknee = 115, lankle = 14, rhip = 72, rknee = 14, rankle = -10,
		lsh = -52, lelb = 62, rsh = 46, relb = 84 }, -- full slide (sustain start)
	{ f = 0.550, rp = 22, ry = 5, rr = 7, wp = 7, wy = 7, np = -18, ny = 2,
		lhip = 31, lknee = 114, lankle = 14, rhip = 71, rknee = 15, rankle = -10,
		lsh = -49, lelb = 64, rsh = 43, relb = 82 }, -- sustain hold (micro-motion)
	{ f = 0.750, rp = 14, ry = 3, rr = 4, wp = 2, wy = 4, np = -4, ny = 1,
		lhip = 34, lknee = 98, lankle = 10, rhip = 58, rknee = 30, rankle = -6,
		lsh = -36, lelb = 70, rsh = 30, relb = 78 }, -- rise begins
	{ f = 0.875, rp = -2, ry = -1, rr = 1, wp = -2, wy = 1, np = 6, ny = 0,
		lhip = -12, lknee = 38, lankle = 0, rhip = 28, rknee = 48, rankle = 0,
		lsh = 16, lelb = 80, rsh = -14, relb = 82 }, -- gather to run stance
	{ f = 1.000, rp = -10, ry = 0, rr = 0, wp = -2, wy = 0, np = 8, ny = 0,
		lhip = 20, lknee = 40, lankle = 0, rhip = 30, rknee = 60, rankle = 0,
		lsh = -20, lelb = 78, rsh = 20, relb = 86 }, -- run-neutral handoff
}

-- Documented default from Config.Movement.SlideDuration, used only when the
-- live Config module is unavailable (e.g. the module runs in a foreign place).
local SLIDE_DURATION_FALLBACK = 0.6

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

-- ── Sprint pose math ─────────────────────────────────────────────────────────
-- Left-leg phase phi in [0,1); right leg runs phi + 0.5. Contact at phi = 0.
local function sprintJoints(phi: number, K: typeof(SprintParams)): JointCFs
	local c = math.cos(2 * math.pi * phi) -- +1: left leg forward
	local c2 = math.cos(4 * math.pi * phi)
	local s = math.sin(2 * math.pi * phi)
	local idx = math.floor(phi * K.Samples + 0.5) % K.Samples + 1 -- nearest sample
	local idxR = (idx - 1 + K.Samples / 2) % K.Samples + 1
	return {
		root = rx(-(K.Lean + K.Bob * c2)) * ry(-K.PelvisYaw * c) * rz(K.PelvisRoll * s),
		waist = rx(-(K.WaistLean + 0.6 * K.Bob * c2)) * ry(K.WaistYaw * c) * rz(-0.5 * K.PelvisRoll * s),
		neck = rx(K.NeckPitch + K.Bob * c2) * ry(-K.NeckYaw * c),
		lsh = rx(-K.ArmAmp * c), lelb = rx(K.Elbow - K.ElbowVar * c),
		rsh = rx(K.ArmAmp * c), relb = rx(K.Elbow + K.ElbowVar * c),
		lhip = rx(K.HipAmp * c), lknee = rx(-K.Knee[idx]), lankle = rx(-K.Ankle[idx]),
		rhip = rx(-K.HipAmp * c), rknee = rx(-K.Knee[idxR]), rankle = rx(-K.Ankle[idxR]),
	}
end

-- ── Slide pose tables ────────────────────────────────────────────────────────
local function slideJoints(k: typeof(SlideKeys[1])): JointCFs
	return {
		root = rx(k.rp) * ry(k.ry) * rz(k.rr),
		waist = rx(k.wp) * ry(k.wy),
		neck = rx(k.np) * ry(k.ny),
		lsh = rx(k.lsh), lelb = rx(k.lelb), rsh = rx(k.rsh), relb = rx(k.relb),
		lhip = rx(k.lhip), lknee = rx(-k.lknee), lankle = rx(-k.lankle),
		rhip = rx(k.rhip), rknee = rx(-k.rknee), rankle = rx(-k.rankle),
	}
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
	local kfs = Instance.new("KeyframeSequence")
	kfs.Name = SPRINT_NAME
	kfs.Loop = true
	kfs.Priority = Enum.AnimationPriority.Movement
	kfs.AuthoredHipHeight = hum.HipHeight
	for i = 0, K.Samples do -- include phi = 1 wrap copy so the loop is exact
		local phi = i / K.Samples
		keyframeAt(phi * K.Cycle, makeTree(sprintJoints(phi, K))).Parent = kfs
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
		keyframeAt(k.f * dur, makeTree(slideJoints(k))).Parent = kfs
	end
	return kfs, warn, nil
end

-- Creates/replaces both sequences inside Workspace/AnimationDevelopment.
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
	report.ok = (sprint ~= nil) and (slide ~= nil)
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
AnimDev.FOLDER_NAME = FOLDER_NAME

return AnimDev
