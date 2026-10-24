--!strict
-- StarterPlayerScripts/CameraDirector.lua (ModuleScript)
-- Owner: Project Owner
-- Responsibility: single client owner of the in-match gameplay camera: base
-- pose, look input (mouse, gamepad, touch), collision, shoulder swap, cursor
-- state, the Phase 2 movement camera effects (sprint, falling, landing,
-- dash, slide, vault, roll) in FOV, position, tilt, and shake channels, the
-- Phase 3 chase awareness set (role camera profiles, Runner hold-to-look-back
-- with a movement-stability assist, chase proximity FOV, tag-transfer
-- feedback), and the Phase 4 view modes: third person stays the default with
-- its exact behavior, first person swaps the base pose for a capsule-anchored
-- eye pose behind a short switch blend, uses a lighter effect set, turns the
-- body with a manual eased yaw, and hides the head locally. Yields to the
-- RS_03 aim camera and the TargetLock assist, defers view switches while
-- scripted movement or a takeover owns the frame, suspends FOV while the
-- RS_01 skill tween runs, and stays a clean base under additive layers
-- (skill shake).
-- Task/spec: camera overhaul Phase 4, approved 2026-10-18.
-- Task/spec: momentum step 4 FOV composition, 2026-10-19.
-- Task/spec: owner-approved first-person FOV setting, 2026-10-22.
-- Task/spec: first-person-only match camera, approved 2026-10-24.
-- Task/spec: removal of manual sprint touch action, approved 2026-10-24.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Cfg = Config.Camera
local Eff = Cfg.Effects
local FP = Cfg.FirstPerson
local Mv = Config.Movement
local ClientSettings = require(script.Parent:WaitForChild("ClientSettings"))
local ChaseState = require(script.Parent:WaitForChild("ChaseState"))
local TargetLockController = require(script.Parent:WaitForChild("TargetLockController"))
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))
local Momentum = require(script.Parent:WaitForChild("MomentumController"))
local MomentumRules = require(ReplicatedStorage:WaitForChild("MomentumRules"))

local localPlayer = Players.LocalPlayer

local CameraDirector = {}
local running = false

-- Ownership. `bound` means the render owner is installed and the camera is
-- ours unless `yielded`; `yielded` means aim or target lock owns the camera
-- right now and we only track its live pose so re-entry never snaps.
local bound = false
local yielded = false
local cursorForced = false

-- Saved-state contract, mirrored from AimCamSaved: we save exactly the
-- properties we mutate (CameraType, FOV, cursor) and restore them on release.
local savedCameraType: Enum.CameraType? = nil
local savedFieldOfView: number? = nil
local savedMouseBehavior: Enum.MouseBehavior? = nil
local savedMouseIcon: boolean? = nil

-- Look state. pitch positive looks up, yaw positive turns left, matching
-- CFrame.fromEulerAnglesYXZ.
local yaw = 0.0
local pitch = 0.0
local stick = Vector2.zero
local lookTouch: InputObject? = nil
local sensCache = 1.0
local aimActive = false

-- Position state.
local camPos = Vector3.zero
local distance = Cfg.ThirdPersonDistance
local shoulder = 1.0
local shoulderSmooth = 1.0
local shoulderFrom = 1.0
local shoulderTo = 1.0
local shoulderT = 1.0
local takeoverLeft = 0.0
local takeoverFrom = Vector3.zero

-- Character state.
local character: Model? = nil
local hrp: BasePart? = nil
local lastHrp: BasePart? = nil

-- Collision. One reused params object; the exclude filter only changes when
-- the character changes.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true
local rayFilterChar: Model? = nil

-- Settings panel detection. The panel's real visibility is the source of
-- truth: the settings events fire paths (X button, match gate close) that a
-- boolean flag would miss, and the panel cannot render while out of match
-- because LobbyUI disables its gui.
local lobbyGui: ScreenGui? = nil
local settingsHolder: GuiObject? = nil

-- Phase 2 effect state: one smoothed envelope per movement effect plus a
-- single landing impulse. Plain numbers only, no per-frame tables.
local sprintSmooth = 0.0
local fallSmooth = 0.0
local dashSmooth = 0.0
local slideSmooth = 0.0
local rollSmooth = 0.0
local vaultPlant = 0.0
local vaultClear = 0.0
local vaultWasActive = false
local vaultStartedAt = 0.0
local vaultAir = false
local landAt = -1000.0
local landHard = false
local fovScaleSmooth = 1.0
local spatialScaleSmooth = 1.0
local skillFovHeld = false
local debugAcc = 0.0

-- Phase 3 state: role profile blend, look-back swing, chase FOV, and the
-- tag-transfer impulse.
local profileFovSmooth = Cfg.BaseFov
local profileDistSmooth = Cfg.ThirdPersonDistance
local lookBackHeld = false
local lookBackTouchHeld = false
local lookBackSmooth = 0.0
local lookBackYawApplied = 0.0
local lookBackYawPrev = 0.0
local chaseFov = 0.0
local extraFov = 0.0
local momentumFov = 0.0
local momentumKickAt = -math.huge
local transferAt = -1000.0
local transferToTaya = false

-- Phase 4 view mode state: the active mode, the deferred request, and the
-- short pose blend between the modes.
local viewMode = "ThirdPerson"
local pendingMode: string? = nil
local blendLeft = 0.0
local blendTotal = 0.0
local blendFrom: CFrame? = nil
local lastWrittenFrame: CFrame? = nil

-- Phase 4 first-person effect output, summed beside the third-person values.
local fpEffFov = 0.0
local fpEffOffsetY = 0.0
local fpEffPitch = 0.0
local fpEffShakeX = 0.0
local fpEffShakeY = 0.0
local jumpAt = -1000.0
local wasGrounded = true

-- Phase 4 body facing state: the saved AutoRotate value while first person
-- owns the turn, and the eased body yaw.
local autoRotateSaved: boolean? = nil
local bodyYaw = 0.0
local bodyActive = false

-- Phase 4 head visibility state: cached head parts and face visuals rebuilt
-- on body or content changes, plus a force-apply flag for resume edges.
local visCharacter: Model? = nil
local visAddConn: RBXScriptConnection? = nil
local visRemoveConn: RBXScriptConnection? = nil
local headParts: { BasePart } = {}
local headVisuals: { (Decal | Texture) } = {}
local visApplied: number? = nil
local visDirty = false
local visRebuild = false

-- Latest effect output, consumed by the render write.
local effFov = 0.0
local effOffsetX = 0.0 -- camera right (studs)
local effOffsetY = 0.0 -- world up (studs)
local effOffsetZ = 0.0 -- toward the focus point (studs)
local effPitch = 0.0 -- view tilt (deg, negative looks down)
local effShakeX = 0.0
local effShakeY = 0.0

local BIND = "HRUSH_CameraDirector"
local SHOULDER_ACTION = "HRUSH_CameraShoulder"
local LOOKBACK_ACTION = "HRUSH_CameraLookBack"
local VIEW_ACTION = "HRUSH_CameraView"
local TOUCH_BUTTON_ACTIONS = {
	"HRUSH_Dash_Touch",
	"HRUSH_Slide_Touch",
	"HRUSH_Skill_Touch",
	"HRUSH_Tag",
}

local onRender: (number) -> ()

local function debugPrint(message: string)
	if Cfg.Debug then
		print("[HRUSH_CameraDirector] " .. message)
	end
end

----------------------------------------------------------------------------
-- Small reads
----------------------------------------------------------------------------

local function inMatch(): boolean
	return localPlayer:GetAttribute("HRushInMatch") == true
end

local function refreshSensitivity()
	local percent: number = Config.Settings.CameraSensitivityDefault
	local value = ClientSettings.get("cameraSensitivity")
	if typeof(value) == "number" then
		percent = value
	end
	sensCache = math.clamp(
		percent / 100 * Cfg.SensitivityScaleMax,
		Cfg.SensitivityScaleMin,
		Cfg.SensitivityScaleMax
	)
end

local function invertedY(): boolean
	return ClientSettings.get("invertCameraY") == true
end

-- Look input and the cursor lock are live only during the countdown (MS_03)
-- and the live round (MS_04). The draft (MS_02), map vote, and recaps (MS_05,
-- MS_06) click through a free cursor, so the base camera keeps its pose but
-- stops taking input there.
local function actionPhase(): boolean
	local state = localPlayer:GetAttribute("HRushState")
	return state == "MS_03" or state == "MS_04"
end

-- Looks one step. dx positive turns right and dy positive looks down, the
-- mouse convention; invertCameraY flips only the vertical axis.
local function lookStep(dx: number, dy: number, step: number)
	local ySign = if invertedY() then -1.0 else 1.0
	yaw -= dx * step
	pitch = math.clamp(pitch - dy * step * ySign, Cfg.PitchMin, Cfg.PitchMax)
	if yaw > 180 then
		yaw -= 360
	elseif yaw < -180 then
		yaw += 360
	end
end

-- Adopts the live camera as our own state. Used while yielded (track aim and
-- lock output) and at re-entry (start exactly where the other writer ended).
local function adopt(cam: Camera)
	local look = cam.CFrame.LookVector
	pitch = math.clamp(math.deg(math.asin(math.clamp(look.Y, -1, 1))), Cfg.PitchMin, Cfg.PitchMax)
	yaw = math.deg(math.atan2(-look.X, -look.Z))
	camPos = cam.CFrame.Position
	distance = profileDistSmooth
	takeoverFrom = camPos
	takeoverLeft = Cfg.TakeoverTime
end

local function refreshCharacter(): BasePart?
	if localPlayer.Character ~= character then
		character = localPlayer.Character
		hrp = nil
	end
	if hrp ~= nil and hrp.Parent == nil then
		hrp = nil
	end
	if hrp == nil and character ~= nil then
		local found = character:FindFirstChild("HumanoidRootPart")
		if found ~= nil and found:IsA("BasePart") then
			hrp = found
		end
	end
	return hrp
end

local function settingsOpen(): boolean
	if lobbyGui == nil or lobbyGui.Parent == nil then
		lobbyGui = nil
		settingsHolder = nil
		local guiParent = localPlayer:FindFirstChildOfClass("PlayerGui")
		if guiParent ~= nil then
			local found = guiParent:FindFirstChild("LobbyUI")
			if found ~= nil and found:IsA("ScreenGui") then
				lobbyGui = found
			end
		end
	end
	if lobbyGui == nil or not lobbyGui.Enabled then
		return false
	end
	if settingsHolder == nil or settingsHolder.Parent == nil then
		settingsHolder = nil
		local found = lobbyGui:FindFirstChild("SettingsPanel")
		if found ~= nil and found:IsA("GuiObject") then
			settingsHolder = found
		end
	end
	if settingsHolder == nil then
		return false
	end
	return settingsHolder.Visible
end

----------------------------------------------------------------------------
-- Phase 2 movement effects
----------------------------------------------------------------------------

-- Frame-rate independent exponential approach; `time` covers about 95
-- percent of the gap, matching the existing 3 / seconds convention.
local function approach(current: number, target: number, time: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-(3 / math.max(time, 0.01)) * dt))
end

local function horizontalSpeed(part: BasePart): number
	local v = part.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

-- The preferred input device scales every effect. Touch-only devices read
-- the touch profile constantly; otherwise the last input type picks the
-- gamepad profile while the player is actively using a controller.
local function deviceScale(): number
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return Eff.Device.Touch
	end
	local lastName = UserInputService:GetLastInputType().Name
	if string.sub(lastName, 1, 7) == "Gamepad" then
		return Eff.Device.Gamepad
	end
	return Eff.Device.Default
end

-- Scripted states own their own camera feel: skills and stun both
-- suppress the generic movement effects for their duration.
local function effectsBusy(): boolean
	return localPlayer:GetAttribute("HRushAbilityBusy") == true
		or localPlayer:GetAttribute("HRushStunned") == true
end

local function grounded(): boolean
	local ch = character
	if ch == nil then
		return false
	end
	local humanoid = ch:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid:IsA("Humanoid") then
		return humanoid.FloorMaterial ~= Enum.Material.Air
	end
	return false
end

-- Role camera profile currently requested. Unknown roles fall back to the
-- Phase 1 neutral values.
local function roleProfileFov(): number
	local role = localPlayer:GetAttribute("HRushRole")
	if role == "Taya" then
		return Cfg.RoleProfiles.Taya.Fov
	elseif role == "Runner" then
		return Cfg.RoleProfiles.Runner.Fov
	end
	return Cfg.BaseFov
end

local function roleProfileDistance(): number
	local role = localPlayer:GetAttribute("HRushRole")
	if role == "Taya" then
		return Cfg.RoleProfiles.Taya.Distance
	elseif role == "Runner" then
		return Cfg.RoleProfiles.Runner.Distance
	end
	return Cfg.ThirdPersonDistance
end

-- Look-back is a Runner free-movement camera: not while the camera is
-- yielded to aim or lock, not while scripted movement owns the character
-- (skill, stun, dash, vault, roll), and not in the settings pause.
-- Standing still, running, sliding, and airborne are allowed; the movement
-- assist only has an effect while actually moving.
local function lookBackAllowed(): boolean
	if not bound or yielded then
		return false
	end
	if viewMode == "FirstPerson" then
		return false
	end
	if Cfg.LookBack.Enabled ~= true or ClientSettings.get("lookBackEnabled") ~= true then
		return false
	end
	if not actionPhase() or settingsOpen() or GuiService.MenuIsOpen then
		return false
	end
	if localPlayer:GetAttribute("HRushRole") == "Taya" then
		return false
	end
	if effectsBusy() then
		return false
	end
	if localPlayer:GetAttribute("HRushDashing") == true
		or localPlayer:GetAttribute("HRushVaulting") == true
		or localPlayer:GetAttribute("HRushRolling") == true then
		return false
	end
	return true
end

local function resetEffects()
	sprintSmooth = 0.0
	fallSmooth = 0.0
	dashSmooth = 0.0
	slideSmooth = 0.0
	rollSmooth = 0.0
	vaultPlant = 0.0
	vaultClear = 0.0
	vaultWasActive = false
	landAt = -1000.0
	landHard = false
	fovScaleSmooth = 1.0
	spatialScaleSmooth = 1.0
	chaseFov = 0.0
	extraFov = 0.0
	momentumFov = 0.0
	momentumKickAt = -math.huge
	transferAt = -1000.0
	transferToTaya = false
	lookBackHeld = false
	lookBackTouchHeld = false
	lookBackSmooth = 0.0
	lookBackYawApplied = 0.0
	lookBackYawPrev = 0.0
	profileFovSmooth = roleProfileFov()
	profileDistSmooth = roleProfileDistance()
	effFov = 0.0
	effOffsetX = 0.0
	effOffsetY = 0.0
	effOffsetZ = 0.0
	effPitch = 0.0
	effShakeX = 0.0
	effShakeY = 0.0
	jumpAt = -1000.0
	wasGrounded = true
	fpEffFov = 0.0
	fpEffOffsetY = 0.0
	fpEffPitch = 0.0
	fpEffShakeX = 0.0
	fpEffShakeY = 0.0
	blendLeft = 0.0
	blendFrom = nil
	lastWrittenFrame = nil
	visDirty = true
end

---------------------------------------------------------------------------
-- Phase 4 view mode: switching gate and presence
---------------------------------------------------------------------------

local function modeEnabled(): boolean
	return FP.Enabled == true
end

-- A mode switch waits for a frame no other owner needs: not yielded, not
-- paused, and not mid slide, vault, roll, stun, or skill. Dash is
-- exempt on purpose; the body facing yields to it instead of holding the
-- switch.
local function canSwitchMode(): boolean
	if not bound or yielded or settingsOpen() or not actionPhase() or GuiService.MenuIsOpen then
		return false
	end
	if aimActive or TargetLockController:GetTarget() ~= nil then
		return false
	end
	if localPlayer:GetAttribute("HRushSliding") == true
		or localPlayer:GetAttribute("HRushVaulting") == true
		or localPlayer:GetAttribute("HRushRolling") == true
		or localPlayer:GetAttribute("HRushStunned") == true
		or localPlayer:GetAttribute("HRushAbilityBusy") == true then
		return false
	end
	return true
end

-- Manual body facing owns the turn only while first person is active and no
-- yield, pause, or scripted movement should have it.
local function fpFacingOwned(): boolean
	return bound and viewMode == "FirstPerson" and not yielded and actionPhase()
		and not settingsOpen() and not GuiService.MenuIsOpen
end

local function mechanicsOwnFacing(): boolean
	return effectsBusy()
		or localPlayer:GetAttribute("HRushDashing") == true
		or localPlayer:GetAttribute("HRushSliding") == true
		or localPlayer:GetAttribute("HRushVaulting") == true
		or localPlayer:GetAttribute("HRushRolling") == true
end

local function humanoidOf(): Humanoid?
	local ch = character
	if ch == nil then
		return nil
	end
	local humanoid = ch:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil and humanoid:IsA("Humanoid") then
		return humanoid
	end
	return nil
end

local function setAutoRotate(on: boolean)
	local humanoid = humanoidOf()
	if humanoid ~= nil and humanoid.AutoRotate ~= on then
		humanoid.AutoRotate = on
	end
end

local function characterYaw(part: BasePart): number
	local look = part.CFrame.LookVector
	return math.deg(math.atan2(-look.X, -look.Z))
end

-- Ease an angle along the shortest arc; same 3 / seconds convention as
-- approach, wrapping at 180 degrees.
local function approachAngle(current: number, target: number, time: number, dt: number): number
	local diff = (target - current + 180) % 360 - 180
	return current + diff * (1 - math.exp(-(3 / math.max(time, 0.01)) * dt))
end

-- Body facing. First person drops humanoid AutoRotate and eases the root
-- yaw toward the camera yaw each frame, so the avatar turns with the view
-- instead of the default movement-facing.
--
-- While a scripted mechanic owns the body in first person (dash, slide,
-- vault, roll, skill, stun) this step hands off completely: it writes
-- nothing and keeps the saved AutoRotate value. Vault captures and restores
-- AutoRotate itself, so a mid-mechanic restore here could leave third person
-- stuck with AutoRotate false and a body that never turns toward movement.
--
-- Every camera-side exit (mode switch, yield, menu, pause, death)
-- restores the saved value once, so third person and all scripted
-- movement behave exactly as before.
local function stepFacing(dt: number, root: BasePart?)
	if viewMode == "FirstPerson" and mechanicsOwnFacing() then
		bodyActive = false
		return
	end
	if fpFacingOwned() and root ~= nil then
		if autoRotateSaved == nil then
			local humanoid = humanoidOf()
			autoRotateSaved = if humanoid ~= nil then humanoid.AutoRotate else true
		end
		setAutoRotate(false)
		if not bodyActive then
			bodyActive = true
			bodyYaw = characterYaw(root)
		end
		bodyYaw = approachAngle(bodyYaw, yaw, FP.YawAlignTime, dt)
		root.CFrame = CFrame.new(root.Position) * CFrame.fromEulerAnglesYXZ(0, math.rad(bodyYaw), 0)
	else
		bodyActive = false
		if autoRotateSaved ~= nil then
			setAutoRotate(autoRotateSaved)
			autoRotateSaved = nil
		end
	end
end

-- Head visibility. In first person the head, its accessories, and the face
-- decals are hidden locally with LocalTransparencyModifier so the camera
-- never renders the skull interior; authored transparency is never touched,
-- so the RS_03 aim fade and everything else stay intact. Lists rebuild on
-- body or content changes, and every exit (release, death, leaving first
-- person, taking a lock) shows the head again.
local function rebuildHeadParts()
	visCharacter = character
	visRebuild = false
	headParts = {}
	headVisuals = {}
	visApplied = nil
	local ch = character
	if ch == nil then
		return
	end
	local head = ch:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	table.insert(headParts, head)
	for _, d in head:GetDescendants() do
		if d:IsA("Decal") or d:IsA("Texture") then
			table.insert(headVisuals, d)
		end
	end
	for _, child in ch:GetChildren() do
		if child:IsA("Accessory") then
			for _, d in child:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(headParts, d)
				end
			end
		end
	end
end

local function trackCharacterContent(ch: Model?)
	if visAddConn ~= nil then
		visAddConn:Disconnect()
		visAddConn = nil
	end
	if visRemoveConn ~= nil then
		visRemoveConn:Disconnect()
		visRemoveConn = nil
	end
	if ch ~= nil then
		visAddConn = ch.DescendantAdded:Connect(function()
			visRebuild = true
		end)
		visRemoveConn = ch.DescendantRemoving:Connect(function()
			visRebuild = true
		end)
	end
end

local function applyHeadHidden(hidden: boolean)
	local value = if hidden then 1 else 0
	if visApplied == value and not visDirty then
		return
	end
	visApplied = value
	visDirty = false
	for _, part in headParts do
		part.LocalTransparencyModifier = value
	end
	for _, item in headVisuals do
		item.LocalTransparencyModifier = value
	end
end

-- Advances every effect envelope. Runs every frame even while yielded or
-- paused, so re-entry and unpausing never replay a stale kick. Writes only
-- plain module numbers; the render step owns every camera write.
local function stepEffects(dt: number)
	local now = os.clock()
	local root = refreshCharacter()
	local busy = effectsBusy()

	-- Phase 3 chase state advances even while yielded, so re-entry and the
	-- FOV catch-up always read this frame's numbers.
	ChaseState.update(dt)
	local reduceMotion = ClientSettings.get("reducedCamera") == true
	if reduceMotion or localPlayer:GetAttribute("HRushState") ~= "MS_04" then
		momentumFov = 0
		momentumKickAt = -math.huge
	else
		local tier = MomentumRules.tier(Momentum.value())
		local target = if tier > 0 then Config.Momentum.Fx.FovBonus[tier] else 0
		local duration = if target > momentumFov then Config.Momentum.Fx.FovInTime else Config.Momentum.Fx.FovOutTime
		momentumFov = approach(momentumFov, target, duration, dt)
		if math.abs(momentumFov - target) < 0.01 then momentumFov = target end
	end

	-- Role profile blend: ease FOV and distance between the Runner and Taya
	-- identities instead of snapping on a tag transfer.
	profileFovSmooth = approach(profileFovSmooth, roleProfileFov(), Cfg.RoleProfiles.BlendTime, dt)
	profileDistSmooth = approach(profileDistSmooth, roleProfileDistance(), Cfg.RoleProfiles.BlendTime, dt)

	-- Look-back ease. The hold input is gated per frame, so a stun,
	-- yield, or settings pause always swings the camera back out.
	local lookBackTarget = if (lookBackHeld or lookBackTouchHeld) and lookBackAllowed() then 1.0 else 0.0
	lookBackSmooth = approach(lookBackSmooth, lookBackTarget, Cfg.LookBack.BlendTime, dt)

	-- Sprint: the attribute gate plus real speed, so a held key while
	-- standing still never widens the camera. The role picks its FOV at the
	-- sum below.
	local sprintTarget = 0.0
	if not busy and localPlayer:GetAttribute("HRushSprinting") == true and root ~= nil then
		local taya = localPlayer:GetAttribute("HRushRole") == "Taya"
		local full = (if taya then Mv.TayaSprintSpeed else Mv.RunnerSprintSpeed) * Mv.SpeedScale
		local start = full * Mv.SprintVfxMinSpeedPct
		sprintTarget = math.clamp((horizontalSpeed(root) - start) / math.max(0.01, full - start), 0, 1)
	end
	sprintSmooth = approach(sprintSmooth, sprintTarget,
		if sprintTarget > sprintSmooth then Eff.Sprint.AttackTime else Eff.Sprint.ReleaseTime, dt)

	-- Falling: downward speed only; ground contact or a scripted state ends
	-- it. HRushAirborne is Studio-only, so this reads the root velocity.
	-- The grounding read is shared with the first-person jump edge below.
	local isGrounded = grounded()
	local fallTarget = 0.0
	if not busy and not isGrounded and root ~= nil and localPlayer:GetAttribute("HRushVaulting") ~= true then
		local fallSpeed = math.max(0, -root.AssemblyLinearVelocity.Y)
		fallTarget = math.clamp(
			(fallSpeed - Eff.Fall.SpeedMin) / math.max(0.01, Eff.Fall.SpeedMax - Eff.Fall.SpeedMin), 0, 1)
	end
	fallSmooth = approach(fallSmooth, fallTarget,
		if fallTarget > fallSmooth then Eff.Fall.AttackTime else Eff.Fall.ReleaseTime, dt)

	-- Dash, slide, roll: attribute edges with their own attack and release.
	local dashTarget = if not busy and localPlayer:GetAttribute("HRushDashing") == true then 1.0 else 0.0
	dashSmooth = approach(dashSmooth, dashTarget,
		if dashTarget > dashSmooth then Eff.Dash.AttackTime else Eff.Dash.ReleaseTime, dt)
	local slideTarget = if not busy and localPlayer:GetAttribute("HRushSliding") == true then 1.0 else 0.0
	slideSmooth = approach(slideSmooth, slideTarget,
		if slideTarget > slideSmooth then Eff.Slide.AttackTime else Eff.Slide.ReleaseTime, dt)
	local rollTarget = if not busy and localPlayer:GetAttribute("HRushRolling") == true then 1.0 else 0.0
	rollSmooth = approach(rollSmooth, rollTarget,
		if rollTarget > rollSmooth then Eff.Roll.AttackTime else Eff.Roll.ReleaseTime, dt)

	-- Vault: time-based plant and clear bumps inside the vault duration.
	local vaulting = not busy and localPlayer:GetAttribute("HRushVaulting") == true
	local plantTarget = 0.0
	local clearTarget = 0.0
	if vaulting then
		if not vaultWasActive then
			vaultStartedAt = now
			vaultAir = localPlayer:GetAttribute("HRushVaultVariant") == "AirVault"
		end
		local f = math.clamp((now - vaultStartedAt) / Mv.VaultDuration, 0, 1)
		local scale = if vaultAir then Eff.Vault.AirScale else 1.0
		plantTarget = math.sin(math.pi * math.clamp(f / Eff.Vault.PlantEnd, 0, 1)) * scale
		clearTarget = math.sin(math.pi * math.clamp((f - Eff.Vault.ClearStart) / (1 - Eff.Vault.ClearStart), 0, 1)) * scale
	end
	vaultWasActive = vaulting
	vaultPlant = approach(vaultPlant, plantTarget, 0.08, dt)
	vaultClear = approach(vaultClear, clearTarget, 0.1, dt)

	-- First-person jump pitch: one edge when the feet leave the ground with
	-- real upward speed. Scripted lifts (vault, skill, stun) never
	-- trigger it.
	if wasGrounded and not isGrounded and not busy and not vaulting and root ~= nil
		and root.AssemblyLinearVelocity.Y > 2 then
		jumpAt = now
	end
	wasGrounded = isGrounded
	local jumpEnv = 0.0
	local jumpAge = now - jumpAt
	if jumpAge >= 0 then
		local t = math.clamp(jumpAge / math.max(0.01, FP.Effects.JumpPitchTime), 0, 1)
		jumpEnv = (1 - t) * (1 - t)
	end

	-- Landing impulse from LandingController (Soft or Hard). Time-based, so
	-- it expires on its own even when the body vanishes mid-recovery.
	local landEnv = 0.0
	local shakeEnv = 0.0
	local age = now - landAt
	if age >= 0 then
		local attack = math.min(1, age / math.max(0.01, Eff.Landing.AttackTime))
		local release = math.max(0, 1 - math.max(0, age - Eff.Landing.AttackTime) / math.max(0.01, Eff.Landing.RecoveryTime))
		landEnv = attack * release * release
		if landHard then
			local s = math.max(0, 1 - age / math.max(0.01, Eff.Landing.ShakeTime))
			shakeEnv = s * s
		end
	end

	-- Tag-transfer impulse: a short pop when the local role changes mid-round.
	local transferEnv = 0.0
	local transferAge = now - transferAt
	if transferAge >= 0 then
		local attack = math.min(1, transferAge / math.max(0.01, Cfg.TagTransfer.AttackTime))
		local release = math.max(0, 1 - math.max(0, transferAge - Cfg.TagTransfer.AttackTime) / math.max(0.01, Cfg.TagTransfer.ReleaseTime))
		transferEnv = attack * release * release
	end

	-- One smoothed scale for settings, device, and reduced camera, so every
	-- transition eases live instead of popping.
	local intensityScale = 1.0
	local settingValue = ClientSettings.get("cameraEffectsIntensity")
	if typeof(settingValue) == "number" then
		intensityScale = settingValue / 100
	end
	local reduced = VfxScale.reducedCamera()
	fovScaleSmooth = approach(fovScaleSmooth,
		intensityScale * deviceScale() * (if reduced then 0.5 else 1.0), Eff.ScaleSmoothTime, dt)
	spatialScaleSmooth = approach(spatialScaleSmooth,
		if reduced then 0.0 else intensityScale * deviceScale(), Eff.ScaleSmoothTime, dt)

	-- Sum the channels. The caps apply to the sums, not to each effect, so
	-- long combos stay inside one feel budget.
	local roleFov = if localPlayer:GetAttribute("HRushRole") == "Taya" then Eff.Sprint.TayaFov else Eff.Sprint.RunnerFov
	local fovSum = roleFov * sprintSmooth
		+ Eff.Fall.Fov * fallSmooth
		+ Eff.Dash.Fov * dashSmooth
		+ Eff.Slide.Fov * slideSmooth
		+ Eff.Vault.ClearFov * vaultClear
		+ Eff.Roll.Fov * rollSmooth
	fovSum = math.clamp(fovSum, 0, Eff.MaxFovBoostTotal)
	effFov = fovSum * fovScaleSmooth

	effOffsetX = 0.0
	effOffsetY = -(Eff.Slide.Dip * slideSmooth + Eff.Roll.Dip * rollSmooth
		+ (if landHard then Eff.Landing.HardDip else Eff.Landing.SoftDip) * landEnv)
	effOffsetZ = -Eff.Sprint.PullBack * sprintSmooth
		- Eff.Fall.PullBack * fallSmooth
		+ Eff.Dash.PullIn * dashSmooth
		+ Eff.Vault.PlantPullIn * vaultPlant
	local offsetMag = math.sqrt(effOffsetX * effOffsetX + effOffsetY * effOffsetY + effOffsetZ * effOffsetZ)
	if offsetMag > Eff.MaxPositionOffset then
		local shrink = Eff.MaxPositionOffset / offsetMag
		effOffsetX *= shrink
		effOffsetY *= shrink
		effOffsetZ *= shrink
	end
	effOffsetX *= spatialScaleSmooth
	effOffsetY *= spatialScaleSmooth
	effOffsetZ *= spatialScaleSmooth

	effPitch = -(Eff.Slide.Pitch * slideSmooth + Eff.Vault.PlantPitch * vaultPlant
		+ (if landHard then Eff.Landing.HardPitch else 0.0) * landEnv)
	effPitch = math.clamp(effPitch * spatialScaleSmooth, -Eff.MaxRotationDegrees, Eff.MaxRotationDegrees)

	local shakeAmp = (Eff.Landing.ShakeAmp * shakeEnv + Cfg.TagTransfer.ShakeAmp * transferEnv) * spatialScaleSmooth
	if shakeAmp > 0 then
		effShakeX = (math.random() * 2 - 1) * shakeAmp
		effShakeY = (math.random() * 2 - 1) * shakeAmp * 0.6
	else
		effShakeX = 0.0
		effShakeY = 0.0
	end

	-- First-person sums: lighter magnitudes, dip and pitch channels only, no
	-- pull-backs or lateral lean. Dips and shake scale with the FOV channel
	-- so reduced camera halves them instead of removing them (the third
	-- person spatial channel is untouched).
	local fpFovSum = FP.Effects.SprintFov * sprintSmooth
		+ FP.Effects.FallFov * fallSmooth
		+ FP.Effects.DashFov * dashSmooth
		+ FP.Effects.SlideFov * slideSmooth
		+ FP.Effects.VaultFov * vaultClear
	fpFovSum = math.clamp(fpFovSum, 0, Eff.MaxFovBoostTotal)
	fpEffFov = fpFovSum * fovScaleSmooth
	fpEffOffsetY = -(FP.Effects.SlideDip * slideSmooth + FP.Effects.RollDip * rollSmooth
		+ (if landHard then FP.Effects.LandHardDip else FP.Effects.LandSoftDip) * landEnv) * fovScaleSmooth
	fpEffPitch = -(FP.Effects.SlidePitch * slideSmooth + FP.Effects.VaultPitch * vaultPlant
		+ (if landHard then FP.Effects.LandHardPitch else 0.0) * landEnv
		+ FP.Effects.JumpPitch * jumpEnv) * fovScaleSmooth
	fpEffPitch = math.clamp(fpEffPitch, -Eff.MaxRotationDegrees, Eff.MaxRotationDegrees)
	local fpShakeAmp = (FP.Effects.LandShakeAmp * shakeEnv + Cfg.TagTransfer.ShakeAmp * transferEnv) * fovScaleSmooth
	if fpShakeAmp > 0 then
		fpEffShakeX = (math.random() * 2 - 1) * fpShakeAmp
		fpEffShakeY = (math.random() * 2 - 1) * fpShakeAmp * 0.6
	else
		fpEffShakeX = 0.0
		fpEffShakeY = 0.0
	end

	-- The RS_01 skill tween owns FOV while it runs; the render step resumes
	-- with a rate-limited catch-up instead of a snap.
	skillFovHeld = localPlayer:GetAttribute("HRushSkillFov") == true

	-- Phase 3 FOV contributions follow the same intensity, device, and
	-- reduced-camera scaling as the movement effects.
	chaseFov = ChaseState.get().intensity * Cfg.Chase.MaxFov * fovScaleSmooth
	local transferFov = (if transferToTaya then Cfg.TagTransfer.ToTayaFov else Cfg.TagTransfer.ToRunnerFov) * transferEnv * fovScaleSmooth
	extraFov = chaseFov + transferFov

	if Cfg.Debug then
		debugAcc += dt
		if debugAcc >= 0.5 then
			debugAcc = 0.0
			debugPrint(string.format(
				"fx fov=%.2f chase=%.2f lb=%.2f/%.0f prof=%.1f/%.2f off=(%.2f, %.2f, %.2f) pitch=%.2f sprint=%.2f fall=%.2f dash=%.2f slide=%.2f roll=%.2f vault=%.2f/%.2f scale=%.2f/%.2f",
				effFov, chaseFov, lookBackSmooth, lookBackYawApplied, profileFovSmooth, profileDistSmooth,
				effOffsetX, effOffsetY, effOffsetZ, effPitch,
				sprintSmooth, fallSmooth, dashSmooth, slideSmooth, rollSmooth,
				vaultPlant, vaultClear, fovScaleSmooth, spatialScaleSmooth
			))
			debugPrint(string.format(
				"fp mode=%s pend=%s blend=%.2f body=%s yaw=%.0f/%.0f err=%.1f hidden=%s head=%d dip=%.2f fov=%.2f anchor=%.1f ext=%s",
				viewMode, tostring(pendingMode), blendLeft, tostring(bodyActive),
				bodyYaw, yaw, math.abs((yaw - bodyYaw + 180) % 360 - 180),
				tostring(visApplied == 1), #headParts, fpEffOffsetY, fpEffFov, FP.CameraHeight,
				if aimActive then "aim" elseif TargetLockController:GetTarget() ~= nil then "lock" else "none"
			))
		end
	end
end

local function onLanding(payload: unknown)
	if not bound or typeof(payload) ~= "table" then
		return
	end
	local class = (payload :: { [string]: any }).class
	if typeof(class) ~= "string" then
		return
	end
	landAt = os.clock()
	landHard = class == "Hard"
	if Cfg.Debug then
		debugPrint("landing impulse: " .. class)
	end
end

----------------------------------------------------------------------------
-- Cursor
----------------------------------------------------------------------------

-- Forces LockCenter and hides the icon while we own the match camera, and
-- self-heals after Alt+Tab or a textbox focus. Never fights a focused chat
-- box or the platform menu.
local function maintainCursor(paused: boolean)
	if paused then
		if cursorForced then
			cursorForced = false
			if savedMouseBehavior ~= nil then
				UserInputService.MouseBehavior = savedMouseBehavior
			end
			if savedMouseIcon ~= nil then
				UserInputService.MouseIconEnabled = savedMouseIcon
			end
		end
		return
	end
	if UserInputService:GetFocusedTextBox() ~= nil or GuiService.MenuIsOpen then
		return
	end
	cursorForced = true
	if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	if UserInputService.MouseIconEnabled then
		UserInputService.MouseIconEnabled = false
	end
end

local function restoreCursor()
	if not cursorForced then
		return
	end
	cursorForced = false
	if savedMouseBehavior ~= nil then
		UserInputService.MouseBehavior = savedMouseBehavior
	end
	if savedMouseIcon ~= nil then
		UserInputService.MouseIconEnabled = savedMouseIcon
	end
end

----------------------------------------------------------------------------
-- Acquire and release
----------------------------------------------------------------------------

local function acquire()
	if bound or not Cfg.Enabled then
		return
	end
	if not inMatch() then
		return
	end
	viewMode = "FirstPerson"
	pendingMode = nil
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return
	end
	if refreshCharacter() == nil then
		return
	end

	-- Capture exactly what we are about to mutate.
	savedCameraType = cam.CameraType
	savedFieldOfView = cam.FieldOfView
	savedMouseBehavior = UserInputService.MouseBehavior
	savedMouseIcon = UserInputService.MouseIconEnabled

	-- Start from the pose another writer left behind.
	adopt(cam)
	lastHrp = hrp
	lookTouch = nil
	stick = Vector2.zero
	resetEffects()
	distance = profileDistSmooth

	-- Take over synchronously so the engine camera never writes again this
	-- frame (Scriptable stops it entirely).
	cam.CameraType = Enum.CameraType.Scriptable
	if math.abs(cam.FieldOfView - Cfg.BaseFov) > 0.01 then
		cam.FieldOfView = Cfg.BaseFov
	end
	bound = true
	yielded = false
	maintainCursor(false)
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value, onRender)
	debugPrint(
		"acquired (CameraType was " .. tostring(savedCameraType) .. ", FOV " .. tostring(savedFieldOfView) .. ")"
	)
end

local function release(restoreSaved: boolean)
	if not bound then
		return
	end
	bound = false
	yielded = false
	lookTouch = nil
	stick = Vector2.zero
	-- Phase 4: hand AutoRotate and the head back before the state clears.
	if autoRotateSaved ~= nil then
		setAutoRotate(autoRotateSaved)
		autoRotateSaved = nil
	end
	bodyActive = false
	applyHeadHidden(false)
	visCharacter = nil
	trackCharacterContent(nil)
	headParts = {}
	headVisuals = {}
	resetEffects()
	RunService:UnbindFromRenderStep(BIND)

	local cam = Workspace.CurrentCamera
	if restoreSaved and cam ~= nil then
		-- Restore the mutated bundle. The pose is deliberately not restored:
		-- the next base owner (lobby camera or the engine camera) writes its
		-- own pose on the next frame.
		if savedCameraType ~= nil then
			cam.CameraType = savedCameraType
		end
		if savedFieldOfView ~= nil then
			cam.FieldOfView = savedFieldOfView
		end
	end
	restoreCursor()
	savedCameraType = nil
	savedFieldOfView = nil
	savedMouseBehavior = nil
	savedMouseIcon = nil
	debugPrint("released")
end

----------------------------------------------------------------------------
-- Render
----------------------------------------------------------------------------

local function handleShoulder(dt: number)
	if shoulderT < 1 then
		shoulderT = math.min(1, shoulderT + dt / math.max(Cfg.ShoulderSwapTime, 0.01))
		local a = shoulderT * shoulderT * (3 - 2 * shoulderT)
		shoulderSmooth = shoulderFrom + (shoulderTo - shoulderFrom) * a
	else
		shoulderSmooth = shoulder
	end
end

local function handleLook(dt: number)
	-- Mouse: per-frame delta, already scaled by the platform settings.
	local mouseDelta = UserInputService:GetMouseDelta()
	if mouseDelta.Magnitude > 0 then
		lookStep(mouseDelta.X, mouseDelta.Y, Cfg.MouseDegPerPixel * sensCache)
	end
	-- Gamepad: right stick, frame-rate independent.
	if stick.Magnitude > Cfg.GamepadDeadzone then
		local mag = stick.Magnitude
		local unit = stick / mag
		local strength = (mag - Cfg.GamepadDeadzone) / (1 - Cfg.GamepadDeadzone)
		local step = Cfg.GamepadLookDegPerSec * dt * sensCache * strength
		-- stick Y positive is up, our dy positive looks down.
		lookStep(unit.X, -unit.Y, step)
	end
end

-- Movement-stability assist while look-back is active. Default movement is
-- camera-relative (PlayerModule ControlModule, priority Input + 1), so a
-- swung camera would otherwise steer the character toward it. Re-issuing the
-- MoveDirection rotated by the offset the camera carried when ControlModule
-- read it (the previous frame's write) keeps steering world-consistent. In
-- the air AirMovement clears MoveDirection after this camera step, which
-- preserves the committed jump vector. No movement value, speed, or
-- AutoRotate is changed; this only removes the camera swing from the input
-- frame while the hold lasts.
local function applyLookBackAssist()
	local prev = lookBackYawPrev
	if math.abs(prev) < 0.01 then
		return
	end
	local ch = character
	if ch == nil then
		return
	end
	local humanoid = ch:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local moveDir = humanoid.MoveDirection
	if moveDir.Magnitude < 0.01 then
		return
	end
	humanoid:Move(CFrame.Angles(0, math.rad(-prev), 0) * moveDir, false)
end

function onRender(dt: number)
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return
	end

	-- Effects advance before the yield check: envelopes stay live while aim
	-- or lock owns the camera, so re-entry never replays a stale kick.
	stepEffects(dt)

	-- Track the yaw offset the PlayerModule ControlModule saw: its input read
	-- used the camera written at the end of the previous frame, so the
	-- movement assist below must rotate by that value, not this frame's.
	lookBackYawPrev = lookBackYawApplied
	lookBackYawApplied = Cfg.LookBack.Angle * lookBackSmooth

	-- Yield to the aim camera and the target lock assist: track their live
	-- pose so re-entry continues from it with no snap.
	local lockActive = TargetLockController:GetTarget() ~= nil
	local shouldYield = aimActive or lockActive
	if shouldYield or yielded then
		adopt(cam)
		if shouldYield then
			yielded = true
			-- Presence still runs while yielded: body facing always hands
			-- AutoRotate back and keep the head hidden while either eye-height
			-- aim or target lock owns the first-person camera.
			stepFacing(dt, nil)
			applyHeadHidden(viewMode == "FirstPerson" and (aimActive or lockActive))
			return
		end
		yielded = false
		visDirty = true
		if viewMode == "FirstPerson" then
			-- First person has no orbit-takeover path, so re-entry eases from
			-- the live takeover pose (aim or lock) with the same short blend.
			-- Third person keeps its existing takeover behavior untouched.
			blendFrom = cam.CFrame
			blendTotal = math.max(0.01, FP.SwitchTime)
			blendLeft = blendTotal
		end
	end

	local paused = settingsOpen() or not actionPhase()
	maintainCursor(paused)

	local root = refreshCharacter()
	if root == nil then
		-- No body (respawn gap): hold the last written pose.
		stepFacing(dt, nil)
		return
	end

	-- Resolve a deferred view mode request the moment nothing else owns the
	-- frame. The pose blend starts from the frame that was written when the
	-- request landed, so the switch is continuous from whatever the last
	-- writer left on screen.
	if pendingMode ~= nil and canSwitchMode() then
		local nextMode = pendingMode
		pendingMode = nil
		if nextMode ~= viewMode then
			viewMode = nextMode
			takeoverLeft = 0
			blendFrom = lastWrittenFrame
			blendTotal = math.max(0.01, FP.SwitchTime)
			blendLeft = if blendFrom ~= nil then blendTotal else 0.0
			visDirty = true
			debugPrint("view mode -> " .. viewMode)
		end
	end

	if not paused and not GuiService.MenuIsOpen then
		handleLook(dt)
	end
	handleShoulder(dt)
	stepFacing(dt, root)

	if character ~= rayFilterChar then
		rayFilterChar = character
		rayParams.FilterDescendantsInstances = if character ~= nil then { character } else {}
	end

	-- Pose. Third person keeps the Phase 1-3 pipeline exactly: orbit plus
	-- collision plus takeover. First person is an eye-anchored pose inside
	-- the capsule with its own effect sums and no ray (the capsule keeps it
	-- out of walls).
	local pose: CFrame
	if viewMode == "FirstPerson" then
		local anchor = root.Position + Vector3.new(0, FP.CameraHeight, 0)
		local fpPitch = math.clamp(pitch + fpEffPitch, Cfg.PitchMin, Cfg.PitchMax)
		local fpRot = CFrame.fromEulerAnglesYXZ(math.rad(fpPitch), math.rad(yaw + lookBackYawApplied), 0)
		local fpPos = anchor
			+ fpRot.LookVector * FP.ForwardOffset
			+ Vector3.new(0, fpEffOffsetY, 0)
		pose = CFrame.new(fpPos) * fpRot
		if fpEffShakeX ~= 0 or fpEffShakeY ~= 0 then
			pose *= CFrame.new(fpEffShakeX, fpEffShakeY, 0)
		end
	else
		local rot = CFrame.fromEulerAnglesYXZ(math.rad(pitch), math.rad(yaw + lookBackYawApplied), 0)
		local focus = root.Position + Vector3.new(0, Cfg.CameraHeight, 0)
		-- Effect offsets ride inside `desired`, so the collision ray keeps every
		-- dip, pull-in, and pull-back off walls exactly like the base pose.
		local effectOffset = rot.RightVector * effOffsetX
			+ Vector3.new(0, effOffsetY, 0)
			+ rot.LookVector * effOffsetZ
		local desired = -rot.LookVector * profileDistSmooth
			+ rot.RightVector * (shoulderSmooth * Cfg.ShoulderOffset)
			+ effectOffset

		-- Collision: one ray from the focus point to the wanted position. Snap in
		-- so walls never clip, ease back out so leaving cover is smooth.
		local length = desired.Magnitude
		local allowed = length
		if length > 0.05 then
			local hit = Workspace:Raycast(focus, desired, rayParams)
			if hit ~= nil then
				allowed = math.max(Cfg.CollisionPadding, hit.Distance - Cfg.CollisionPadding)
			end
		end
		if allowed < distance then
			distance = allowed
		else
			local k = 1 - math.exp(-dt * Cfg.CollisionReturnRate)
			distance += (allowed - distance) * k
			if distance > allowed then
				distance = allowed
			end
		end

		local orbit = focus + desired.Unit * distance
		if root ~= lastHrp then
			-- Respawn teleported the body; snap like the default camera instead
			-- of sweeping across the map.
			lastHrp = root
			takeoverLeft = 0
			distance = profileDistSmooth
			camPos = focus + desired.Unit * distance
		elseif takeoverLeft > 0 then
			takeoverLeft = math.max(0, takeoverLeft - dt)
			local a = 1 - takeoverLeft / math.max(Cfg.TakeoverTime, 0.01)
			a = a * a * (3 - 2 * a)
			camPos = takeoverFrom:Lerp(orbit, a)
		else
			camPos = orbit
		end

		pose = CFrame.lookAt(camPos, focus) * CFrame.Angles(math.rad(effPitch), 0, 0)
		if effShakeX ~= 0 or effShakeY ~= 0 then
			pose *= CFrame.new(effShakeX, effShakeY, 0)
		end
	end

	-- Mode switch blend: smoothstep from the frame written when the request
	-- landed to the new mode's pose. Both end poses sit inside the
	-- collision-safe envelope, so the straight lerp between them needs no
	-- extra ray.
	if blendLeft > 0 and blendFrom ~= nil then
		blendLeft = math.max(0, blendLeft - dt)
		local t = 1 - blendLeft / math.max(blendTotal, 0.01)
		t = t * t * (3 - 2 * t)
		pose = blendFrom:Lerp(pose, t)
		if blendLeft <= 0 then
			blendFrom = nil
		end
	end

	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = pose
	lastWrittenFrame = pose

	-- FOV is written absolutely. First person uses its own flat base instead
	-- of the role profile; both modes keep the rate-limited catch-up, so a
	-- switch, a yield, an RS_01 kick, or a role change eases back instead of
	-- snapping.
	if not skillFovHeld then
		local targetFov: number
		local kickElapsed = Workspace:GetServerTimeNow() - momentumKickAt
		local kick = if kickElapsed >= 0 and kickElapsed < Config.Momentum.Fx.PerfectFovKickTime
			then Config.Momentum.Fx.PerfectFovKick else 0
		if viewMode == "FirstPerson" then
			targetFov = (ClientSettings.get("firstPersonFov") :: number)
				+ math.clamp(fpEffFov + extraFov, -Eff.MaxFovBoostTotal, Eff.MaxFovBoostTotal)
		else
			targetFov = profileFovSmooth + math.clamp(effFov + extraFov, -Eff.MaxFovBoostTotal, Eff.MaxFovBoostTotal)
		end
		targetFov += momentumFov + kick
		if viewMode == "FirstPerson" then
			targetFov = math.clamp(targetFov, 1, Config.Settings.FirstPersonFovMax)
		end
		local diff = targetFov - cam.FieldOfView
		local maxStep = Eff.FovCatchupRate * dt
		if math.abs(diff) <= maxStep then
			cam.FieldOfView = targetFov
		else
			cam.FieldOfView += (if diff > 0 then maxStep else -maxStep)
		end
	end

	-- Head visibility: rebuild on body or content changes, then derive the
	-- hidden state from the mode and the switch blend. Entering first person
	-- hides at 60 percent of the blend; leaving shows it again at 50 percent.
	if character ~= visCharacter then
		rebuildHeadParts()
		trackCharacterContent(character)
	elseif visRebuild then
		rebuildHeadParts()
	end
	local blendFrac = 1.0
	if blendLeft > 0 then
		blendFrac = 1 - blendLeft / math.max(blendTotal, 0.01)
	end
	local hidden = false
	if viewMode == "FirstPerson" then
		hidden = blendLeft <= 0 or blendFrac >= 0.6
	else
		hidden = blendLeft > 0 and blendFrac < 0.5
	end
	applyHeadHidden(hidden)

	-- Movement-stability assist for the look-back swing (see definition).
	applyLookBackAssist()
end

----------------------------------------------------------------------------
-- Input routing
----------------------------------------------------------------------------

local function overCasButton(pos: Vector2): boolean
	for _, action in TOUCH_BUTTON_ACTIONS do
		local button = ContextActionService:GetButton(action)
		if button ~= nil and button:IsA("GuiObject") and button.Visible then
			local at = button.AbsolutePosition
			local size = button.AbsoluteSize
			if pos.X >= at.X and pos.X <= at.X + size.X and pos.Y >= at.Y and pos.Y <= at.Y + size.Y then
				return true
			end
		end
	end
	return false
end

local function overGuiButton(pos: Vector2): boolean
	local guiParent = localPlayer:FindFirstChildOfClass("PlayerGui")
	if guiParent == nil then
		return false
	end
	for _, object in guiParent:GetGuiObjectsAtPosition(pos.X, pos.Y) do
		if object:IsA("GuiButton") then
			return true
		end
	end
	return false
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if not bound or yielded or not Cfg.Enabled or not actionPhase() then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if gameProcessed or lookTouch ~= nil then
		return
	end
	local cam = Workspace.CurrentCamera
	if cam == nil then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if pos.X < cam.ViewportSize.X * Cfg.TouchMinScreenXScale then
		return
	end
	if overGuiButton(pos) or overCasButton(pos) then
		return
	end
	lookTouch = input
end

local function onInputChanged(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Thumbstick2 then
		stick = Vector2.new(input.Position.X, input.Position.Y)
		return
	end
	if input ~= lookTouch or not bound or yielded or not actionPhase() then
		return
	end
	if input.UserInputType == Enum.UserInputType.Touch then
		local delta = input.Delta
		lookStep(delta.X, delta.Y, Cfg.TouchLookDegPerPixel * sensCache)
	end
end

local function onInputEnded(input: InputObject)
	if input == lookTouch then
		lookTouch = nil
	end
end

local function swapShoulder()
	shoulderFrom = shoulderSmooth
	shoulderTo = -shoulder
	shoulder = shoulderTo
	shoulderT = 0
end

-- Hold-to-look-back input. The action sinks so the key never leaks to
-- another system, but the per-frame gate in stepEffects decides whether it
-- engages, so a hold during a stun simply waits.
local function onLookBackAction(_name: string, inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		if UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		lookBackHeld = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		lookBackHeld = false
	end
	return Enum.ContextActionResult.Sink
end

----------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------

local function onMatchChanged()
	if inMatch() and Cfg.Enabled then
		-- Set the required view before the deferred lobby-camera handoff.
		viewMode = "FirstPerson"
		pendingMode = nil
		blendLeft = 0
		blendFrom = nil
		visDirty = true
		-- One frame later, so the lobby gate has finished its own handoff
		-- (Custom, FOV 70, CameraSubject) before we capture it.
		task.spawn(function()
			RunService.RenderStepped:Wait()
			acquire()
		end)
	else
		release(true)
		pendingMode = nil
		viewMode = if ClientSettings.get("cameraViewMode") == "FirstPerson" and modeEnabled()
			then "FirstPerson" else "ThirdPerson"
	end
end

-- Phase 3 tag-transfer feedback: a local role change during the live round
-- fires one short FOV pop and shake. The initial round assignment and the
-- round-start re-assignments happen outside MS_04, and acquire() only binds
-- after the match starts, so only real transfers trigger the pop.
local function onRoleChanged()
	if not bound then
		return
	end
	if localPlayer:GetAttribute("HRushState") ~= "MS_04" then
		return
	end
	local role = localPlayer:GetAttribute("HRushRole")
	if role ~= "Taya" and role ~= "Runner" then
		return
	end
	if os.clock() - transferAt < 0.5 then
		return
	end
	transferAt = os.clock()
	transferToTaya = role == "Taya"
	debugPrint("tag transfer feedback: now " .. role)
end

function CameraDirector.start()
	if running then
		return
	end
	running = true
	Momentum.start()
	Momentum.Changed:Connect(function(_value: number, reason: string, _action: string?, _gain: number?, payload: any?)
		if reason == "confirmed" and payload ~= nil and payload.perfect == true
			and ClientSettings.get("reducedCamera") ~= true then
			momentumKickAt = Workspace:GetServerTimeNow()
		end
	end)
	refreshSensitivity()
	-- The lobby retains its saved preference; a match always starts in first person.
	local savedMode = ClientSettings.get("cameraViewMode")
	if savedMode == "FirstPerson" and modeEnabled() then
		viewMode = "FirstPerson"
	end
	if inMatch() then
		viewMode = "FirstPerson"
	end
	if localPlayer:GetAttribute("HRushAiming") == "RS_03" then
		aimActive = true
	end

	localPlayer:GetAttributeChangedSignal("HRushAiming"):Connect(function()
		aimActive = localPlayer:GetAttribute("HRushAiming") == "RS_03"
	end)
	localPlayer:GetAttributeChangedSignal("HRushInMatch"):Connect(onMatchChanged)
	localPlayer.CharacterAdded:Connect(function()
		task.spawn(function()
			RunService.RenderStepped:Wait()
			acquire()
		end)
	end)

	-- LandingController owns landing classification and fires
	-- HRushLandingEvent; connect late so startup never depends on another
	-- module's load order.
	task.spawn(function()
		local landingEvent = ReplicatedStorage:WaitForChild("HRushLandingEvent", 15)
		if landingEvent ~= nil and landingEvent:IsA("BindableEvent") then
			landingEvent.Event:Connect(onLanding)
		end
	end)

	ClientSettings.Changed:Connect(function(key: unknown, value: unknown)
		if key == "cameraSensitivity" then
			refreshSensitivity()
		elseif key == "cameraViewMode" then
			-- A preference change cannot override the required match view.
			if not inMatch() then
				pendingMode = nil
				viewMode = if value == "FirstPerson" and modeEnabled() then "FirstPerson" else "ThirdPerson"
			end
		end
	end)

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)

	ContextActionService:BindActionAtPriority(SHOULDER_ACTION, function(_, inputState, _input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if not bound or yielded or settingsOpen() or not actionPhase() then
			return Enum.ContextActionResult.Pass
		end
		if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		swapShoulder()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Cfg.ShoulderSwapKey, Cfg.ShoulderSwapGamepad)

	ContextActionService:BindActionAtPriority(LOOKBACK_ACTION, onLookBackAction, false,
		Enum.ContextActionPriority.Default.Value, Cfg.LookBack.Key, Cfg.LookBack.GamepadKey)

	-- Match view is fixed. Pass these keys through so settings and other
	-- controls can still use them.
	ContextActionService:BindActionAtPriority(VIEW_ACTION, function(_name, inputState, _input)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if UserInputService:GetFocusedTextBox() ~= nil then
			return Enum.ContextActionResult.Pass
		end
		if inMatch() or not bound or not actionPhase() or settingsOpen() or not modeEnabled() then
			return Enum.ContextActionResult.Pass
		end
		CameraDirector.toggleViewMode()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, FP.ToggleKey, FP.ToggleGamepad)

	localPlayer:GetAttributeChangedSignal("HRushRole"):Connect(onRoleChanged)

	if inMatch() then
		task.spawn(function()
			RunService.RenderStepped:Wait()
			acquire()
		end)
	end
end

-- Mobile hold-to-look-back button (owned by ChaseHUD) feeds input here.
function CameraDirector.setLookBackTouch(held: boolean)
	lookBackTouchHeld = held == true
end

-- Preserve the view-mode API for callers outside a match. Match requests do
-- nothing; getViewMode reports the active mode for local animation playback.
function CameraDirector.toggleViewMode()
	if inMatch() or not modeEnabled() then
		return
	end
	local current = if pendingMode ~= nil then pendingMode else viewMode
	local target = if current == "FirstPerson" then "ThirdPerson" else "FirstPerson"
	ClientSettings.set("cameraViewMode", target)
end

function CameraDirector.getViewMode(): string
	return viewMode
end

return CameraDirector
