--!strict
-- StarterPlayerScripts/UIController.client.lua
-- Owner: Project Owner
-- Responsibility: HUD (role banner, countdown, scoreboard, movement cooldowns),
-- Task/spec: stamina removal and compact action dock, approved 2026-10-24.
-- Task/spec: Lihim na Target mode HUD and recaps, approved 2026-10-23.
-- Task/spec: simple click-to-tag HUD cleanup, approved 2026-10-18.
-- Task/spec: Agawan ng Panyo recaps and splash, approved 2026-10-23.
-- Task/spec: approved UI/UX redesign, 2026-10-23.
--                 skill bar, Diskarte meter, clutch callouts, recap screens,
--                 and spectator camera UI.
-- See UI/UX Specification and Config.Match / Config.Events.
--
-- HUD v1.1 (T09 playtest slice + RS_01 skill chip):
--   • Dash cooldown chip — "Q" keycap, vertical cooldown wipe + live countdown,
--     pops green the instant it becomes ready
--   • Skill chip — "E" keycap + skill name caption, cooldown wipe/countdown from
--     Config.Skills (RS_01 slice); hides while HRushSkillId == "" (Taya / ungranted)
--   • Tsinelas chip (T18 RS_03 slice) — TEMP keycap + caption from Config.UI,
--     wipe plus ceil-seconds countdown from HRushSkillCD_RS03, gold aiming
--     border from HRushAiming, dimmed while stunned or round not live.
--   • Tsinelas touch button (mobile only) — the slot itself is the button in
--     the right thumb zone, mirroring the chip state including the cooldown
--     fill. Press and hold to aim, release inside to throw, slide off to cancel.
-- Data source: HRush* attribute bridge on LocalPlayer (MovementController pushes
-- at 10 Hz + forced on role/state/tag events). Poll-free via GetAttributeChangedSignal.
--
-- TODO (T14): role banner, round countdown, scoreboard, full skill bar.
-- TODO (T17): Implement Skill Draft UI (slot picks beyond the TEMP test grant).
-- TODO (T27): Implement clutch callouts and recap screens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local AudioRouter = require(script.Parent:WaitForChild("AudioRouter"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local Mv     = Config.Movement
local TS     = Config.UI.Tsinelas -- RS_03 slot sizes, labels, and timings

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
local Workspace   = game:GetService("Workspace")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local TagEvent    = Remotes:WaitForChild("TagEvent") :: RemoteEvent
local RoundRecapEvent = Remotes:WaitForChild("RoundRecap") :: RemoteEvent
local MatchRecapEvent = Remotes:WaitForChild("MatchRecap") :: RemoteEvent
local PickSkill   = Remotes:WaitForChild("PickSkill") :: RemoteEvent

-- GM_01 HUD palette
local HUD_LIME     = Theme.Colors.Gold
local HUD_NAVY     = Theme.Colors.Navy
local HUD_SLATE    = Theme.Colors.Raised
local HUD_SLATE_D  = Theme.Colors.Raised
local HUD_RED      = Theme.Colors.TayaText
local HUD_RED_DARK = Color3.fromRGB(50, 16, 16)
local HUD_CYAN     = Theme.Colors.Teal
local HUD_GOLD     = Theme.Colors.Gold
local HUD_WHITE    = Theme.Colors.Cream
local HUD_DIM      = Theme.Colors.Muted

local function fmtClock(sec: number): string
	sec = math.max(0, math.floor(sec + 0.5))
	local m = math.floor(sec / 60)
	local r = sec - m * 60
	return string.format("%d:%02d", m, r)
end

local function fmtTaya(sec: number): string
	return string.format("%04.1f", math.max(0, sec))
end

-- ── Palette (placeholder; Art Bible pass later in T14) ────────────────────────
local COL_PANEL      = Color3.fromRGB(18, 18, 24)
local COL_TEXT       = Color3.fromRGB(235, 235, 240)
local COL_STROKE_CD  = Color3.fromRGB(90, 90, 100)
local COL_STROKE_RDY = Color3.fromRGB(86, 214, 90)
local COL_COOLDOWN   = Color3.fromRGB(8, 8, 12)

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- ── Root HUD ──────────────────────────────────────────────────────────────────
local gui = Instance.new("ScreenGui")
gui.Name = "HRushHUD"
gui.ResetOnSpawn = false -- survives respawn (attributes re-push on spawn)
Theme.screen(gui, Theme.Layers.HUD)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

-- ── Bottom-left movement and skill chips ────────────────────────────────────
local cluster = Instance.new("Frame")
cluster.Name = "MoveCluster"
cluster.AnchorPoint = Vector2.new(0, 1)
cluster.Position = UDim2.fromScale(0.015, 0.97)
cluster.Size = UDim2.fromOffset(240, 56)
cluster.BackgroundTransparency = 1
cluster.Parent = gui

-- Dash cooldown chip.
local chip = Instance.new("Frame")
chip.Name = "DashChip"
chip.Position = UDim2.fromOffset(2, 10)
chip.Size = UDim2.fromOffset(44, 44)
chip.BackgroundColor3 = COL_PANEL
chip.BackgroundTransparency = 0.15
chip.BorderSizePixel = 0
chip.Parent = cluster
corner(chip, 8)
local chipStroke = stroke(chip, COL_STROKE_CD, 2)

local wipe = Instance.new("Frame") -- dark overlay shrinking top→bottom as CD elapses
wipe.Name = "CooldownWipe"
wipe.AnchorPoint = Vector2.new(0, 0)
wipe.Position = UDim2.fromScale(0, 0)
wipe.Size = UDim2.fromScale(1, 0) -- 0 = ready
wipe.BackgroundColor3 = COL_COOLDOWN
wipe.BackgroundTransparency = 0.25
wipe.BorderSizePixel = 0
wipe.ZIndex = 1
wipe.Parent = chip
corner(wipe, 8)

local keyText = Instance.new("TextLabel")
keyText.Name = "KeyOrCd"
keyText.BackgroundTransparency = 1
keyText.Size = UDim2.fromScale(1, 1)
keyText.Font = Enum.Font.GothamBold
keyText.TextSize = 18
keyText.Text = "Q"
keyText.TextColor3 = COL_TEXT
keyText.TextStrokeTransparency = 0.5
keyText.ZIndex = 2
keyText.Parent = chip

local chipCaption = Instance.new("TextLabel")
chipCaption.Name = "DashCaption"
chipCaption.BackgroundTransparency = 1
chipCaption.Position = UDim2.fromOffset(0, 44)
chipCaption.Size = UDim2.fromOffset(52, 12)
chipCaption.Font = Enum.Font.Gotham
chipCaption.TextSize = 9
chipCaption.Text = "DASH"
chipCaption.TextColor3 = COL_TEXT
chipCaption.TextStrokeTransparency = 0.6
chipCaption.Parent = cluster

-- Skill chip (right of the dash chip): "E" keycap + name caption, CD wipe.
local skillChip = Instance.new("Frame")
skillChip.Name = "SkillChip"
skillChip.Position = UDim2.fromOffset(82, 10)
skillChip.Size = UDim2.fromOffset(44, 44)
skillChip.BackgroundColor3 = COL_PANEL
skillChip.BackgroundTransparency = 0.15
skillChip.BorderSizePixel = 0
skillChip.Parent = cluster
corner(skillChip, 22) -- circle shape: distinct from the dash chip without color
local skillStroke = stroke(skillChip, COL_STROKE_CD, 2)

local skillWipe = Instance.new("Frame") -- dark overlay shrinking top to bottom
skillWipe.Name = "CooldownWipe"
skillWipe.AnchorPoint = Vector2.new(0, 0)
skillWipe.Position = UDim2.fromScale(0, 0)
skillWipe.Size = UDim2.fromScale(1, 0) -- 0 = ready
skillWipe.BackgroundColor3 = COL_COOLDOWN
skillWipe.BackgroundTransparency = 0.25
skillWipe.BorderSizePixel = 0
skillWipe.ZIndex = 1
skillWipe.Parent = skillChip
corner(skillWipe, 22) -- follows the circular chip outline

local skillKey = Instance.new("TextLabel")
skillKey.Name = "KeyOrCd"
skillKey.BackgroundTransparency = 1
skillKey.Size = UDim2.fromScale(1, 1)
skillKey.Font = Enum.Font.GothamBold
skillKey.TextSize = 18
skillKey.Text = "E"
skillKey.TextColor3 = COL_TEXT
skillKey.TextStrokeTransparency = 0.5
skillKey.ZIndex = 2
skillKey.Parent = skillChip

local skillCaption = Instance.new("TextLabel")
skillCaption.Name = "SkillCaption"
skillCaption.BackgroundTransparency = 1
skillCaption.Position = UDim2.fromOffset(74, 44)
skillCaption.Size = UDim2.fromOffset(76, 12)
skillCaption.Font = Enum.Font.Gotham
skillCaption.TextSize = 9
skillCaption.Text = ""
skillCaption.TextColor3 = COL_TEXT
skillCaption.TextStrokeTransparency = 0.6
skillCaption.Parent = cluster

-- Tsinelas chip (right of the skill chip): same circle pattern, all slot
-- values from Config.UI.Tsinelas. KeyLabel moves to E at T17.
local tsinelasChip = Instance.new("Frame")
tsinelasChip.Name = "TsinelasChip"
tsinelasChip.Position = UDim2.fromOffset(TS.SlotOffsetX, 10)
tsinelasChip.Size = UDim2.fromOffset(TS.SlotSize, TS.SlotSize)
tsinelasChip.BackgroundColor3 = COL_PANEL
tsinelasChip.BackgroundTransparency = 0.15
tsinelasChip.BorderSizePixel = 0
tsinelasChip.Parent = cluster
corner(tsinelasChip, TS.SlotSize / 2) -- circle, stays round if size changes
local tsinelasStroke = stroke(tsinelasChip, COL_STROKE_CD, 2)

local tsinelasWipe = Instance.new("Frame") -- dark overlay shrinking top to bottom
tsinelasWipe.Name = "CooldownWipe"
tsinelasWipe.AnchorPoint = Vector2.new(0, 0)
tsinelasWipe.Position = UDim2.fromScale(0, 0)
tsinelasWipe.Size = UDim2.fromScale(1, 0) -- 0 = ready
tsinelasWipe.BackgroundColor3 = COL_COOLDOWN
tsinelasWipe.BackgroundTransparency = 0.25
tsinelasWipe.BorderSizePixel = 0
tsinelasWipe.ZIndex = 1
tsinelasWipe.Parent = tsinelasChip
corner(tsinelasWipe, TS.SlotSize / 2) -- follows the circular chip outline

local tsinelasKey = Instance.new("TextLabel")
tsinelasKey.Name = "KeyOrCd"
tsinelasKey.BackgroundTransparency = 1
tsinelasKey.Size = UDim2.fromScale(1, 1)
tsinelasKey.Font = Enum.Font.GothamBold
tsinelasKey.TextSize = TS.CountdownTextSize
tsinelasKey.Text = TS.KeyLabel
tsinelasKey.TextColor3 = COL_TEXT
tsinelasKey.TextStrokeTransparency = 0.5
tsinelasKey.ZIndex = 2
tsinelasKey.Parent = tsinelasChip

local tsinelasCaption = Instance.new("TextLabel")
tsinelasCaption.Name = "TsinelasCaption"
tsinelasCaption.BackgroundTransparency = 1
tsinelasCaption.Position = UDim2.fromOffset(TS.SlotOffsetX - 12, 44)
tsinelasCaption.Size = UDim2.fromOffset(76, 12)
tsinelasCaption.Font = Enum.Font.Gotham
tsinelasCaption.TextSize = 9
tsinelasCaption.Text = TS.CaptionText
tsinelasCaption.TextColor3 = COL_TEXT
tsinelasCaption.TextStrokeTransparency = 0.6
tsinelasCaption.Parent = cluster

-- Tsinelas touch button (mobile only, created once): bottom-right thumb zone,
-- scale positioned with a physical size above the 64 px spec minimum. The
-- button mirrors the chip state, so the cooldown fill shows on it. Fires the
-- MobileTsinelas bridge event; MovementController hooks it like the legacy
-- buttons. No per-round Instances; state resets come through attributes.
local function mobileTsinelasEvent(): BindableEvent
	local existing = ReplicatedStorage:FindFirstChild("MobileTsinelas")
	if existing and existing:IsA("BindableEvent") then
		return existing
	end
	local be = Instance.new("BindableEvent")
	be.Name = "MobileTsinelas"
	be.Parent = ReplicatedStorage
	return be
end

local tsinelasTouch: TextButton? = nil
local tsinelasTouchStroke: UIStroke? = nil
local tsinelasTouchWipe: Frame? = nil
local tsinelasTouchKey: TextLabel? = nil
if UserInputService.TouchEnabled then
	local btn = Instance.new("TextButton")
	btn.Name = "TsinelasTouch"
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
	btn.Position = TS.TouchPosition
	btn.Size = UDim2.fromOffset(TS.TouchSizePx, TS.TouchSizePx)
	btn.BackgroundColor3 = COL_PANEL
	btn.BackgroundTransparency = 0.15
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.AutoButtonColor = false -- state colors come from updateTsinelasCD
	btn.Parent = gui
	corner(btn, TS.TouchSizePx / 2) -- circle like the chip
	tsinelasTouchStroke = stroke(btn, COL_STROKE_CD, 2)
	local touchWipe = Instance.new("Frame")
	touchWipe.Name = "CooldownWipe"
	touchWipe.AnchorPoint = Vector2.new(0, 0)
	touchWipe.Position = UDim2.fromScale(0, 0)
	touchWipe.Size = UDim2.fromScale(1, 0) -- 0 = ready
	touchWipe.BackgroundColor3 = COL_COOLDOWN
	touchWipe.BackgroundTransparency = 0.25
	touchWipe.BorderSizePixel = 0
	touchWipe.ZIndex = 1
	touchWipe.Parent = btn
	corner(touchWipe, TS.TouchSizePx / 2)
	tsinelasTouchWipe = touchWipe
	local touchKey = Instance.new("TextLabel")
	touchKey.Name = "KeyOrCd"
	touchKey.BackgroundTransparency = 1
	touchKey.Size = UDim2.fromScale(1, 1)
	touchKey.Font = Enum.Font.GothamBold
	touchKey.TextSize = TS.CountdownTextSize
	touchKey.Text = TS.KeyLabel
	touchKey.TextColor3 = COL_TEXT
	touchKey.TextStrokeTransparency = 0.5
	touchKey.ZIndex = 2
	touchKey.Parent = btn
	tsinelasTouchKey = touchKey
	btn.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		mobileTsinelasEvent():Fire("Begin")
	end)
	btn.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		-- Slide-off cancels: the finger left the button, so this is not a
		-- throw. Default to Cancel when uncertain.
		local pos = input.Position
		local absPos = btn.AbsolutePosition
		local absSize = btn.AbsoluteSize
		local inside = pos.X >= absPos.X
			and pos.X <= absPos.X + absSize.X
			and pos.Y >= absPos.Y
			and pos.Y <= absPos.Y + absSize.Y
		mobileTsinelasEvent():Fire(if inside then "End" else "Cancel")
	end)
	tsinelasTouch = btn
end

-- ── Attribute readers ─────────────────────────────────────────────────────────
-- Role banner (top center)
local roleBanner = Instance.new("Frame")
roleBanner.Name = "RoleBanner"
roleBanner.AnchorPoint = Vector2.new(1, 1)
roleBanner.Position = UDim2.fromScale(0.985, 0.97)
roleBanner.Size = UDim2.fromOffset(200, 52)
roleBanner.BackgroundColor3 = COL_PANEL
roleBanner.BackgroundTransparency = 0.05
roleBanner.BorderSizePixel = 0
roleBanner.Visible = false
roleBanner.Parent = gui
corner(roleBanner, 12)
local roleStroke = stroke(roleBanner, Color3.new(0, 0, 0), 2)

local roleLabel = Instance.new("TextLabel")
roleLabel.BackgroundTransparency = 1
roleLabel.Position = UDim2.fromScale(0, 0)
roleLabel.Size = UDim2.fromScale(1, 0.62)
roleLabel.Font = Enum.Font.GothamBold
roleLabel.TextSize = 24
roleLabel.Text = ""
roleLabel.TextColor3 = COL_TEXT
roleLabel.TextStrokeTransparency = 0.4
roleLabel.Parent = roleBanner

local roleSubLabel = Instance.new("TextLabel")
roleSubLabel.BackgroundTransparency = 1
roleSubLabel.Position = UDim2.fromScale(0, 0.6)
roleSubLabel.Size = UDim2.fromScale(1, 0.4)
roleSubLabel.Font = Enum.Font.Gotham
roleSubLabel.TextSize = 11
roleSubLabel.Text = ""
roleSubLabel.TextColor3 = COL_TEXT
roleSubLabel.TextStrokeTransparency = 0.5
roleSubLabel.Parent = roleBanner

local function updateRoleBanner()
	-- The countdown splash and live objective are the single role owners.
	roleBanner.Visible = false
end

-- Settings stays available during live play.
local settingsGear = Instance.new("TextButton")
settingsGear.Name = "SettingsGear"
settingsGear.AnchorPoint = Vector2.new(1, 0)
settingsGear.Position = UDim2.new(1, -12, 0, 12)
settingsGear.Size = UDim2.fromOffset(64, 64)
settingsGear.BackgroundColor3 = COL_PANEL
settingsGear.BackgroundTransparency = 0.05
settingsGear.BorderSizePixel = 0
settingsGear.Font = Enum.Font.GothamBold
settingsGear.TextSize = 18
settingsGear.Text = "SET"
settingsGear.TextColor3 = HUD_DIM
settingsGear.Parent = gui
corner(settingsGear, 12)
stroke(settingsGear, HUD_DIM, 1)
settingsGear.Activated:Connect(function()
	AudioRouter.playUi("click")
	local ev = ReplicatedStorage:FindFirstChild("HRushSettingsToggle")
	if ev and ev:IsA("BindableEvent") then
		ev:Fire()
	end
end)

-- Attribute readers
local function attrNum(name: string, fallback: number): number
	local v = LocalPlayer:GetAttribute(name)
	if typeof(v) == "number" then
		return v
	end
	return fallback
end

local function attrStr(name: string, fallback: string): string
	local v = LocalPlayer:GetAttribute(name)
	if typeof(v) == "string" then
		return v
	end
	return fallback
end

-- ── Movement chip visibility ────────────────────────────────────────────────
local curRole = attrStr("HRushRole", "Runner")
local curSkillId = "" -- granted skill id (declared early so visibility logic sees it)

local function updateVisibility()
	-- Dash stays Runner-only; the skill chip follows the grant list
	-- instead, so Config.Debug.AllowAnyRoleForSkills can show it on Taya too.
	-- The chip is also a circle (not a rounded square), so it reads apart from
	-- the dash chip by SHAPE, not only by color.
	local isRunner = (curRole == "Runner")
	local hasSkill = (curSkillId ~= "")
	chip.Visible = isRunner
	chipCaption.Visible = isRunner
	cluster.Visible = isRunner or hasSkill or attrStr("HRushSkillId_RS03", "") ~= ""
end

-- ── Dash cooldown chip logic ──────────────────────────────────────────────────
local lastDashCD = 0.0

local function popReady()
	-- Game-feel: brief overshoot pop on the ready transition, then rest.
	keyText.Text = "Q"
	chipStroke.Color = COL_STROKE_RDY
	local up = TweenService:Create(
		chip,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(52, 52) }
	)
	up:Play()
	up.Completed:Connect(function()
		TweenService:Create(
			chip,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(44, 44) }
		):Play()
	end)
end

local function updateDashCD()
	local cd = attrNum("HRushDashCD", 0)
	local total = math.max(0.01, Mv.DashCooldown)
	local ratio = math.clamp(cd / total, 0, 1)

	wipe.Size = UDim2.fromScale(1, ratio)
	if cd > 0 then
		keyText.Text = string.format("%.1f", cd)
		chipStroke.Color = COL_STROKE_CD
	elseif lastDashCD > 0 then
		popReady() -- transition to 0: flash ready state
	end
	lastDashCD = cd
end

-- ── Skill cooldown chip logic (RS_01 slice) ───────────────────────────────────
local lastSkillCD = 0.0

local function popSkillReady()
	skillKey.Text = "E"
	skillStroke.Color = COL_STROKE_RDY
	-- Ready pulse: the border thickens once, so the state reads even in
	-- grayscale (shape/motion, not color alone).
	skillStroke.Thickness = 2
	local pulse = TweenService:Create(
		skillStroke,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Thickness = 4 }
	)
	pulse:Play()
	pulse.Completed:Connect(function()
		TweenService:Create(
			skillStroke,
			TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Thickness = 2 }
		):Play()
	end)
	local up = TweenService:Create(
		skillChip,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(52, 52) }
	)
	up:Play()
	up.Completed:Connect(function()
		TweenService:Create(
			skillChip,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(44, 44) }
		):Play()
	end)
end

local function updateSkillCD()
	curSkillId = attrStr("HRushSkillId", "")
	-- Role gating already happened in MovementController.grantedSkillId, so
	-- "has a skill id" alone decides visibility here (debug flag aware).
	local granted = (curSkillId ~= "")
	skillChip.Visible = granted
	skillCaption.Visible = granted
	updateVisibility() -- refresh the cluster when only the skill chip remains
	if not granted then
		return
	end
	local sk = Config.Skills[curSkillId]
	skillCaption.Text = sk and string.upper(sk.name) or ""
	local cd = attrNum("HRushSkillCD", 0)
	local total = math.max(0.01, sk and sk.cooldown or 1)
	local ratio = math.clamp(cd / total, 0, 1)

	skillWipe.Size = UDim2.fromScale(1, ratio)
	if cd > 0 then
		skillKey.Text = string.format("%.1f", cd)
		skillStroke.Color = COL_STROKE_CD
		skillStroke.Thickness = 2 -- cooldown state uses the resting border
	elseif lastSkillCD > 0 then
		popSkillReady() -- transition to 0: flash ready state
	end
	lastSkillCD = cd
end


-- ── Tsinelas cooldown chip logic (RS_03 slice) ─────────────────────────────────
-- Four states on one slot: hidden (ungranted), dimmed (stunned or round not
-- live), gold border (aiming), wipe plus ceil seconds (cooling), keycap plus
-- green border (ready, with a one-time pulse on the transition).
local lastTsinelasCD = 0.0

local function popTsinelasReady()
	tsinelasKey.Text = TS.KeyLabel
	tsinelasStroke.Color = COL_STROKE_RDY
	-- Ready pulse: the border thickens once, so the state reads even in
	-- grayscale (shape/motion, not color alone).
	tsinelasStroke.Thickness = 2
	local pulse = TweenService:Create(
		tsinelasStroke,
		TweenInfo.new(TS.ReadyPulseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Thickness = 4 }
	)
	pulse:Play()
	pulse.Completed:Connect(function()
		TweenService:Create(
			tsinelasStroke,
			TweenInfo.new(TS.ReadyPulseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Thickness = 2 }
		):Play()
	end)
	local up = TweenService:Create(
		tsinelasChip,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(TS.ReadyPulseGrow, TS.ReadyPulseGrow) }
	)
	up:Play()
	up.Completed:Connect(function()
		TweenService:Create(
			tsinelasChip,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(TS.SlotSize, TS.SlotSize) }
		):Play()
	end)
end

local function updateTsinelasCD()
	local granted = attrStr("HRushSkillId_RS03", "") == "RS_03"
		and LocalPlayer:GetAttribute("HRushGameMode") ~= "SecretHunt"
	tsinelasChip.Visible = granted
	tsinelasCaption.Visible = granted
	local showTouch = granted and tsinelasTouch ~= nil
	if tsinelasTouch ~= nil then
		tsinelasTouch.Visible = showTouch
	end
	if not granted then
		return
	end
	tsinelasCaption.Text = TS.CaptionText
	-- Resolve one visual state, then apply it to the chip and the touch
	-- button together so they can never disagree.
	local keyText = TS.KeyLabel
	local strokeColor = COL_STROKE_RDY
	local strokeThickness = 2
	local wipeRatio = 0
	local dimmed = false
	local stunned = LocalPlayer:GetAttribute("HRushStunned") == true
	if stunned or attrStr("HRushState", "") ~= "MS_04" then
		dimmed = true
		strokeColor = COL_STROKE_CD
	elseif attrStr("HRushAiming", "") == "RS_03" then
		strokeColor = TS.AimStrokeColor
		strokeThickness = TS.AimStrokeThickness
	else
		local cd = attrNum("HRushSkillCD_RS03", 0)
		local sk = Config.Skills.RS_03
		local total = math.max(0.01, sk and sk.cooldown or 1)
		wipeRatio = math.clamp(cd / total, 0, 1)
		if cd > 0 then
			keyText = tostring(math.ceil(cd))
			strokeColor = COL_STROKE_CD
		elseif lastTsinelasCD > 0 then
			popTsinelasReady() -- transition to 0: flash ready state
		end
		lastTsinelasCD = cd
	end
	tsinelasChip.BackgroundTransparency = if dimmed then TS.UnavailableTransparency else 0.15
	tsinelasKey.Text = keyText
	tsinelasStroke.Color = strokeColor
	tsinelasStroke.Thickness = strokeThickness
	tsinelasWipe.Size = UDim2.fromScale(1, wipeRatio)
	if tsinelasTouch ~= nil and tsinelasTouchStroke ~= nil and tsinelasTouchWipe ~= nil and tsinelasTouchKey ~= nil then
		tsinelasTouch.BackgroundTransparency = if dimmed then TS.UnavailableTransparency else 0.15
		tsinelasTouchKey.Text = keyText
		tsinelasTouchStroke.Color = strokeColor
		tsinelasTouchStroke.Thickness = strokeThickness
		tsinelasTouchWipe.Size = UDim2.fromScale(1, wipeRatio)
	end
end



-- ══════════════════════════════════════════════════════════════════════════════
-- GM_01 MATCH OVERLAYS (Skill Draft, Role Splash, Live Bar, Tag Feed, Recaps)
-- Lives in its own ScreenGui so the MS_02 draft can show while the base HUD
-- (gated to MS_03..MS_05) stays hidden. Sections toggle by HRushState.
-- ══════════════════════════════════════════════════════════════════════════════
local overlayGui = Instance.new("ScreenGui")
overlayGui.Name = "HRushOverlays"
overlayGui.ResetOnSpawn = false
Theme.screen(overlayGui, Theme.Layers.Transition)
overlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
overlayGui.Enabled = false
overlayGui.Parent = PlayerGui

local function oFrame(props: { [string]: any }, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = HUD_SLATE
	for k, v in pairs(props) do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function oLabel(props: { [string]: any }, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = Enum.Font.GothamBold
	l.TextSize = 14
	l.TextColor3 = HUD_WHITE
	l.Text = ""
	for k, v in pairs(props) do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function oCorner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function oStroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = thickness or 1
	st.Transparency = transparency or 0
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = parent
	return st
end

-- shared phase state (set from attribute listeners at the bottom)
local phaseState: string? = nil
local respawnLabel = oLabel({
	Name = "RespawningNotice",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(280, 52),
	Text = "RESPAWNING...",
	TextSize = 24,
	TextColor3 = HUD_WHITE,
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.12,
	Visible = false,
}, overlayGui)
oCorner(respawnLabel, 12)

-- ── A. TOP MATCH BAR (MS_04) ─────────────────────────────────────────────────
local topBar = oFrame({
	Name = "TopMatchBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(240, 64),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)

local roundPill = oFrame({
	Name = "RoundPill",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(118, 24),
	BackgroundColor3 = HUD_SLATE_D,
	BackgroundTransparency = 0.15,
}, topBar)
oCorner(roundPill, 15)
oStroke(roundPill, HUD_LIME, 1.5, 0.25)
local roundLabel = oLabel({
	Size = UDim2.fromScale(1, 1),
	Text = "ROUND 1 / 3",
	TextSize = 13,
	TextColor3 = HUD_LIME,
}, roundPill)

local timerLabel = oLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 23),
	Size = UDim2.fromOffset(220, 40),
	Text = "2:30",
	Font = Enum.Font.GothamBold,
	TextSize = 36,
	TextColor3 = HUD_WHITE,
}, topBar)
local timerStroke = oStroke(timerLabel, HUD_NAVY, 0, 1) -- placeholder; stroke on text needs TextStroke

local tayaTracker = oFrame({
	Name = "TayaTracker",
	Position = UDim2.fromOffset(12, 46),
	Size = UDim2.fromOffset(276, 32),
	BackgroundColor3 = HUD_RED_DARK,
	BackgroundTransparency = 0.1,
}, gui)
oCorner(tayaTracker, 14)
oStroke(tayaTracker, HUD_RED, 1.5, 0.15)
local tayaTrackerLabel = oLabel({
	Size = UDim2.fromScale(1, 1),
	Text = "TAYA: —",
	TextSize = 13,
	TextColor3 = Color3.fromRGB(255, 120, 120),
}, tayaTracker)
tayaTrackerLabel.TextTruncate = Enum.TextTruncate.AtEnd
local classicObjective = oFrame({
	Name = "ClassicObjective",
	Position = UDim2.fromOffset(24, 92),
	Size = UDim2.fromOffset(300, 96),
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.12,
	Visible = false,
}, gui)
oCorner(classicObjective, 12)
oStroke(classicObjective, HUD_RED, 2, 0)
tayaTracker.Parent = classicObjective
local classicRole = oLabel({
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.fromOffset(276, 32),
	Text = "RUNNER · AVOID TAYA",
	TextSize = 17,
	TextColor3 = HUD_WHITE,
}, classicObjective)
local classicStandings = oFrame({
	Name = "ClassicStandings",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -24, 0, 92),
	Size = UDim2.fromOffset(260, 112),
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.12,
	Visible = false,
}, gui)
oCorner(classicStandings, 12)
local classicBoardText = oLabel({
	Position = UDim2.fromOffset(10, 8),
	Size = UDim2.new(1, -20, 1, -16),
	Text = "TAYA TIME",
	TextSize = 13,
	TextColor3 = HUD_WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
}, classicStandings)

-- ── D. LIVE TAG FEED (below the round pill) ──────────────────────────────────
local tagFeed = oFrame({
	Name = "TagFeed",
	Position = UDim2.new(0, 12, 0, 92),
	Size = UDim2.fromOffset(320, 160),
	BackgroundTransparency = 1,
}, overlayGui)
local feedLayout = Instance.new("UIListLayout")
feedLayout.Padding = UDim.new(0, 6)
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Parent = tagFeed

local feedOrder = 0
local function pushTagFeed(taggerName: string, targetName: string, iAmTagger: boolean, iAmTarget: boolean)
	feedOrder += 1
	local pill = oFrame({
		LayoutOrder = feedOrder,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = HUD_SLATE_D,
		BackgroundTransparency = 0.1,
	}, tagFeed)
	oCorner(pill, 15)
	local accent = iAmTagger and HUD_RED or (iAmTarget and Color3.fromRGB(238, 152, 88) or HUD_SLATE)
	oStroke(pill, accent, 2, 0)
	local text = oLabel({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Text = taggerName .. " tagged " .. targetName .. "!",
		TextSize = 12,
		TextColor3 = iAmTarget and Color3.fromRGB(255, 170, 120) or HUD_WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, pill)
	pill.Position = UDim2.fromOffset(-340, 0)
	local slideIn = game:GetService("TweenService"):Create(pill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, 0) })
	slideIn:Play()
	task.delay(3.5, function()
		if pill.Parent then
			local out = game:GetService("TweenService"):Create(pill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(-340, 0) })
			out:Play()
			out.Completed:Once(function()
				pill:Destroy()
			end)
		end
	end)
	-- Phone screens keep two short feed items below the objective card.
	local kids = {}
	for _, c in ipairs(tagFeed:GetChildren()) do
		if c:IsA("Frame") then table.insert(kids, c) end
	end
	if #kids > (if Layout.compact() then 2 else 4) then
		kids[1]:Destroy()
	end
end

TagEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then return end
	local taggerName = typeof(payload.taggerName) == "string" and payload.taggerName or "Taya"
	local targetName = typeof(payload.targetName) == "string" and payload.targetName or "Runner"
	local iAmTagger = payload.taggerId == LocalPlayer.UserId
	local iAmTarget = payload.targetId == LocalPlayer.UserId
	pushTagFeed(taggerName, targetName, iAmTagger, iAmTarget)
end)

-- ── B. ROLE SPLASH + COUNTDOWN (MS_03) ───────────────────────────────────────
local splash = oFrame({
	Name = "RoleSplash",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.fromOffset(420, 76),
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.08,
	Visible = false,
	ZIndex = 20,
}, overlayGui)
oCorner(splash, 16)
local splashStroke = oStroke(splash, HUD_RED, 3)
local splashTitle = oLabel({
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.new(1, 0, 0, 42),
	Text = "RUNNER!",
	Font = Enum.Font.Oswald,
	TextSize = 34,
	TextColor3 = HUD_CYAN,
	ZIndex = 21,
}, splash)
local splashSub = oLabel({
	Position = UDim2.fromOffset(0, 45),
	Size = UDim2.new(1, 0, 0, 24),
	Text = "Outrun the Taya and survive!",
	TextSize = 16,
	TextColor3 = HUD_DIM,
	ZIndex = 21,
}, splash)

local splashToken = 0
local function playRoleSplash()
	splashToken += 1
	local token = splashToken
	local isTaya = LocalPlayer:GetAttribute("HRushRole") == "Taya"
	if LocalPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo" then
		splashTitle.Text = "AGAWAN NG PANYO!"
		splashTitle.TextColor3 = HUD_GOLD
		splashSub.Text = "Grab it, then hold it for points!"
		splash.BackgroundColor3 = HUD_RED_DARK
		splashStroke.Color = HUD_GOLD
	elseif LocalPlayer:GetAttribute("HRushGameMode") == "SecretHunt" then
		splashTitle.Text = "LIHIM NA TARGET!"
		splashTitle.TextColor3 = HUD_GOLD
		splashSub.Text = "Find your target. Stay ahead of your Hunter."
		splash.BackgroundColor3 = HUD_RED_DARK
		splashStroke.Color = HUD_GOLD
	elseif isTaya then
		splashTitle.Text = "IKAW ANG TAYA!"
		splashTitle.TextColor3 = Color3.fromRGB(255, 110, 80)
		splashSub.Text = "Tag a runner before time runs out!"
		splash.BackgroundColor3 = HUD_RED_DARK
		splashStroke.Color = HUD_RED
	else
		splashTitle.Text = "RUNNER!"
		splashTitle.TextColor3 = HUD_CYAN
		splashSub.Text = "Outrun the Taya and survive!"
		splash.BackgroundColor3 = Color3.fromRGB(12, 34, 44)
		splashStroke.Color = HUD_CYAN
	end
	splash.Visible = true
	splash.BackgroundTransparency = 0.08
	splashTitle.TextTransparency = 0
	splashSub.TextTransparency = 0
	local compact = Layout.compact()
	splash.Size = UDim2.fromOffset(if compact then 260 else 420, if compact then 60 else 76)
	splashTitle.TextSize = if compact then 23 else 34
	splashSub.TextSize = if compact then 12 else 16
	splashSub.Position = UDim2.fromOffset(0, if compact then 34 else 45)
	local finishY = if compact then 46 else 72
	splash.Position = UDim2.new(0.5, 0, 0, finishY - 12)
	local ts = game:GetService("TweenService")
	if Theme.reducedMotion() then splash.Position = UDim2.new(0.5, 0, 0, finishY)
	else ts:Create(splash, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, finishY) }):Play() end
	task.delay(3, function()
		if splashToken == token then
			local fade = ts:Create(splash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
			ts:Create(splashTitle, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			ts:Create(splashSub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			fade:Play()
			fade.Completed:Once(function()
				if splashToken == token then
					splash.Visible = false
					splash.BackgroundTransparency = 0.08
					splashTitle.TextTransparency = 0
					splashSub.TextTransparency = 0
				end
			end)
		end
	end)
end

local countdownLabel = oLabel({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(160, 120),
	Text = "",
	Font = Enum.Font.Oswald,
	TextSize = 72,
	TextColor3 = HUD_LIME,
	Visible = false,
	ZIndex = 20,
}, overlayGui)
oStroke(countdownLabel, HUD_NAVY, 0, 1)

local lastCountNum = -1
local function updateCountdown()
	local st = phaseState
	if st ~= "MS_03" then
		countdownLabel.Visible = false
		lastCountNum = -1
		return
	end
	local endsAt = ReplicatedStorage:GetAttribute("HRushPhaseEndsAt")
	local remaining = typeof(endsAt) == "number" and math.ceil(endsAt - Workspace:GetServerTimeNow()) or -1
	if remaining > 0 then
		countdownLabel.Visible = true
		if remaining ~= lastCountNum then
			lastCountNum = remaining
			countdownLabel.Text = tostring(remaining)
			countdownLabel.TextColor3 = HUD_LIME
			countdownLabel.Size = UDim2.fromOffset(if Layout.compact() then 120 else 160, if Layout.compact() then 90 else 120)
			countdownLabel.TextSize = if Layout.compact() then 56 else 72
			AudioRouter.playSfxId(Config.Sfx.Countdown.tick, Config.Sfx.Countdown.volume)
		end
	else
		-- 0: the launch moment
		countdownLabel.Visible = true
		if lastCountNum ~= 0 then
			lastCountNum = 0
			countdownLabel.Text = "GO!"
			countdownLabel.TextSize = if Layout.compact() then 40 else 56
			countdownLabel.TextColor3 = HUD_RED
			AudioRouter.playSfxId(Config.Sfx.Countdown.go, Config.Sfx.Countdown.volume)
		end
	end
end

-- ── C. PERSONAL TAYA BADGE (MS_04, Taya only) ────────────────────────────────
local tayaBadge = oFrame({
	Name = "TayaBadge",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.fromScale(0.985, 0.97),
	Size = UDim2.fromOffset(280, 52),
	BackgroundColor3 = HUD_RED_DARK,
	BackgroundTransparency = 0.05,
	Visible = false,
}, overlayGui)
oCorner(tayaBadge, 12)
oStroke(tayaBadge, HUD_RED, 2.5)
local badgeSkull = oLabel({
	Position = UDim2.fromOffset(10, 0),
	Size = UDim2.fromOffset(40, 58),
	Text = "☠",
	Font = Enum.Font.GothamBold,
	TextSize = 30,
	TextColor3 = HUD_WHITE,
}, tayaBadge)
local badgeLabel = oLabel({
	Position = UDim2.fromOffset(56, 0),
	Size = UDim2.new(1, -66, 1, 0),
	Text = "ORAS MO BILANG TAYA: 00:00.0s",
	TextSize = 15,
	TextColor3 = Color3.fromRGB(255, 140, 120),
	TextXAlignment = Enum.TextXAlignment.Left,
}, tayaBadge)

local function updateTayaBadge()
	-- Live role and time now use the shared top-left objective card.
	tayaBadge.Visible = false
end

-- ── E. SKILL DRAFT MODAL (MS_02, 12 s) ───────────────────────────────────────
local draftModal = oFrame({
	Name = "SkillDraft",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(660, 400),
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 20,
}, overlayGui)
oCorner(draftModal, 18)
oStroke(draftModal, HUD_LIME, 2, 0.3)
oLabel({
	Position = UDim2.fromOffset(0, 16),
	Size = UDim2.new(1, 0, 0, 40),
	Text = "SKILL DRAFT",
	Font = Enum.Font.Oswald,
	TextSize = 38,
	TextColor3 = HUD_LIME,
	ZIndex = 21,
}, draftModal)
local draftSub = oLabel({
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 0, 20),
	Text = "Pumili ng isa...",
	TextSize = 14,
	TextColor3 = HUD_DIM,
	ZIndex = 21,
}, draftModal)

local draftCardsHolder = oFrame({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.16),
	Size = UDim2.fromOffset(630, 300),
	BackgroundTransparency = 1,
	ZIndex = 21,
}, draftModal)
local draftLayout = Instance.new("UIListLayout")
draftLayout.FillDirection = Enum.FillDirection.Horizontal
draftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
draftLayout.VerticalAlignment = Enum.VerticalAlignment.Top
draftLayout.Padding = UDim.new(0, 14)
draftLayout.Parent = draftCardsHolder

local draftEndsAt = 0
local myDraftPick: string? = nil
local draftCardRefs: { { frame: Frame, stroke: UIStroke, id: string } } = {}

local function buildDraft()
	for _, child in ipairs(draftCardsHolder:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	table.clear(draftCardRefs)
	myDraftPick = LocalPlayer:GetAttribute("HRushSkillId")
	draftEndsAt = tonumber(ReplicatedStorage:GetAttribute("HRushPhaseEndsAt")) or (Workspace:GetServerTimeNow() + 12)

	local myRole = LocalPlayer:GetAttribute("HRushRole") or "Runner"
	local pool: { any } = {}
	for id, sk in pairs(Config.Skills :: any) do
		if typeof(id) == "string" and typeof(sk) == "table" and sk.id == id and sk.role == myRole then
			table.insert(pool, sk)
		end
	end
	table.sort(pool, function(a, b) return a.id < b.id end)

	for slot, sk in ipairs(pool) do
		local card = oFrame({
			Size = UDim2.fromOffset(196, 280),
			BackgroundColor3 = HUD_SLATE,
			LayoutOrder = slot,
			ZIndex = 21,
		}, draftCardsHolder)
		oCorner(card, 14)
		local cardStroke = oStroke(card, HUD_SLATE, 2, 0.2)

		local typeColor = HUD_CYAN
		if sk.type == "Stun" then typeColor = Color3.fromRGB(238, 152, 88)
		elseif sk.type == "Decoy" then typeColor = HUD_GOLD
		elseif sk.type == "Speed" or sk.type == "Area" or sk.type == "Detection" then typeColor = Color3.fromRGB(170, 150, 255) end

		oLabel({
			Position = UDim2.fromOffset(0, 14),
			Size = UDim2.new(1, 0, 0, 56),
			Text = sk.name,
			TextSize = 20,
			TextColor3 = HUD_WHITE,
			TextWrapped = true,
			ZIndex = 22,
		}, card)

		local typeBadge = oFrame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.26),
			Size = UDim2.fromOffset(110, 20),
			BackgroundColor3 = typeColor,
			ZIndex = 22,
		}, card)
		oCorner(typeBadge, 10)
		oLabel({
			Size = UDim2.fromScale(1, 1),
			Text = string.upper(sk.type),
			TextSize = 11,
			TextColor3 = HUD_NAVY,
			ZIndex = 23,
		}, typeBadge)

		oLabel({
			Position = UDim2.fromOffset(0, 96),
			Size = UDim2.new(1, 0, 0, 18),
			Text = "COOLDOWN: " .. tostring(sk.cooldown) .. "s",
			TextSize = 12,
			TextColor3 = HUD_LIME,
			ZIndex = 22,
		}, card)

		oLabel({
			Position = UDim2.fromOffset(10, 120),
			Size = UDim2.new(1, -20, 0, 92),
			Text = sk.weakness or "",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = HUD_DIM,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 22,
		}, card)

		local pickBtn = Instance.new("TextButton")
		pickBtn.AnchorPoint = Vector2.new(0.5, 1)
		pickBtn.Position = UDim2.fromScale(0.5, 0.94)
		pickBtn.Size = UDim2.fromOffset(150, 40)
		pickBtn.BackgroundColor3 = HUD_LIME
		pickBtn.Text = "PICK"
		pickBtn.Font = Enum.Font.GothamBold
		pickBtn.TextSize = 16
		pickBtn.TextColor3 = HUD_NAVY
		pickBtn.AutoButtonColor = false
		pickBtn.ZIndex = 22
		pickBtn.Parent = card
		oCorner(pickBtn, 10)

		local skId = sk.id
		pickBtn.Activated:Once(function()
			if myDraftPick then return end
			myDraftPick = skId
			PickSkill:FireServer(skId)
			for _, ref in ipairs(draftCardRefs) do
				local chosen = ref.id == skId
				ref.stroke.Color = chosen and HUD_LIME or HUD_SLATE_D
				ref.stroke.Thickness = chosen and 3 or 2
				ref.stroke.Transparency = chosen and 0 or 0.4
			end
			draftSub.Text = "Lock si " .. sk.name .. "!"
		end)

		table.insert(draftCardRefs, { frame = card, stroke = cardStroke, id = skId })
	end
end

-- ── F. ROUND SCOREBOARD MODAL (MS_05) ────────────────────────────────────────
local resultsGui = Instance.new("ScreenGui")
resultsGui.Name = "HRUSH_Results"
resultsGui.ResetOnSpawn = false
resultsGui.Enabled = false
Theme.screen(resultsGui, Theme.Layers.Modal)
resultsGui.Parent = PlayerGui
local scoreboard = oFrame({
	Name = "RoundScoreboard",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(580, 440),
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.06,
	Visible = false,
	ZIndex = 20,
}, resultsGui)
oCorner(scoreboard, 18)
oStroke(scoreboard, HUD_LIME, 2, 0.35)
local panyoScoreboardScale = Instance.new("UIScale")
panyoScoreboardScale.Parent = scoreboard
local scoreboardTitle = oLabel({
	Position = UDim2.fromOffset(0, 14),
	Size = UDim2.new(1, 0, 0, 34),
	Text = "ROUND 1 RESULTS",
	Font = Enum.Font.Oswald,
	TextSize = 30,
	TextColor3 = HUD_LIME,
	ZIndex = 21,
}, scoreboard)
local scoreboardSub = oLabel({
	Position = UDim2.new(0, 0, 1, -42),
	Size = UDim2.new(1, 0, 0, 18),
	Text = "Next round starting soon...",
	TextSize = 13,
	TextColor3 = HUD_DIM,
	ZIndex = 21,
}, scoreboard)
local practiceLabel = oLabel({
	Position = UDim2.fromOffset(0, 52),
	Size = UDim2.new(1, 0, 0, 22),
	Text = "PRACTICE: NO MATCH POINTS",
	TextSize = 15,
	TextColor3 = HUD_GOLD,
	Visible = false,
	ZIndex = 21,
}, scoreboard)
local scoreboardRows = Instance.new("ScrollingFrame")
scoreboardRows.Name = "Rows"
scoreboardRows.AnchorPoint = Vector2.new(0.5, 0)
scoreboardRows.Position = UDim2.new(0.5, 0, 0, 82)
scoreboardRows.Size = UDim2.new(1, -32, 1, -136)
scoreboardRows.BackgroundTransparency = 1
scoreboardRows.BorderSizePixel = 0
scoreboardRows.ScrollBarThickness = 5
scoreboardRows.AutomaticCanvasSize = Enum.AutomaticSize.Y
scoreboardRows.ZIndex = 21
scoreboardRows.Parent = scoreboard
local sbLayout = Instance.new("UIListLayout")
sbLayout.Padding = UDim.new(0, 5)
sbLayout.SortOrder = Enum.SortOrder.LayoutOrder
sbLayout.Parent = scoreboardRows
local scoreboardNextIn = 0
local scoreboardHasData = false

local function fmtTayaCell(sec: number): string
	local whole = math.floor(sec)
	local tenth = math.floor((sec - whole) * 10 + 0.5)
	if tenth >= 10 then whole += 1 tenth = 0 end
	return string.format("%02d.%d", whole, tenth)
end

local huntMatchEnding = false
local function buildScoreboard(entries: { any }, round: number, totalRounds: number, nextIn: number, mode: string?, practice: boolean)
	local isPanyo = mode == "AgawanNgPanyo"
	local isHunt = mode == "SecretHunt"
	local compact = Layout.compact()
	scoreboard.Position = UDim2.fromScale(0.5, 0.5)
	scoreboard.Size = if compact then UDim2.new(1, -24, 1, -24) else UDim2.fromOffset(680, 480)
	panyoScoreboardScale.Scale = 1
	practiceLabel.Visible = practice
	scoreboardTitle.TextSize = if compact then 24 else 30
	for _, child in ipairs(scoreboardRows:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	scoreboardTitle.Text = if isHunt
		then string.format("HUNT ROUND %d / %d%s", round, totalRounds, if practice then " - PRACTICE" else "")
		else if isPanyo
		then string.format("PANYO ROUND %d / %d%s", round, totalRounds, if practice then " - PRACTICE" else "")
		else string.format("ROUND %d / %d RESULTS", round, totalRounds)
	scoreboardNextIn = nextIn
	for _, e in ipairs(entries) do
		local row = oFrame({
			Size = UDim2.new(1, 0, 0, if compact then 54 else 42),
			BackgroundColor3 = (e.rank == 1) and Color3.fromRGB(56, 48, 18) or HUD_SLATE_D,
			BackgroundTransparency = (e.rank == 1) and 0 or 0.25,
			LayoutOrder = e.rank,
			ZIndex = 21,
		}, scoreboardRows)
		oCorner(row, 8)
		if e.rank == 1 then
			oStroke(row, HUD_GOLD, 2)
		end
		oLabel({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.fromOffset(40, 34),
			Text = "#" .. tostring(e.rank),
			TextSize = 13,
			TextColor3 = (e.rank == 1) and HUD_GOLD or HUD_DIM,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, row)
		oLabel({
			Position = UDim2.fromOffset(54, 0),
			Size = UDim2.fromOffset(200, 34),
			Text = e.name .. (if e.left then "  [LEFT]" else if e.isBot then "  [BOT]" else ""),
			TextSize = 13,
			TextColor3 = (e.rank == 1) and HUD_GOLD or HUD_WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 22,
		}, row)
		oLabel({
			Position = UDim2.fromOffset(260, 0),
			Size = UDim2.fromOffset(110, 34),
			Text = if isHunt
				then tostring(e.captures or 0) .. "C / " .. fmtTayaCell(e.bestStreak or 0) .. "s"
				else if isPanyo
				then fmtTayaCell(e.possessionTime or 0) .. "s/" .. tostring(e.steals or 0) .. "S"
				else fmtTayaCell(e.tayaTime or 0) .. "s",
			TextSize = 13,
			TextColor3 = HUD_DIM,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, row)
		oLabel({
			Position = UDim2.fromOffset(378, 0),
			Size = UDim2.fromOffset(70, 34),
			Text = "+" .. tostring(e.pointsAwarded) .. " pts",
			TextSize = 13,
			TextColor3 = HUD_LIME,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, row)
		oLabel({
			Position = UDim2.fromOffset(458, 0),
			Size = UDim2.fromOffset(70, 34),
			Text = tostring(e.totalPoints) .. " total",
			TextSize = 13,
			TextColor3 = HUD_WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, row)
		if e.userId == LocalPlayer.UserId then oStroke(row, HUD_CYAN, 2) end
		if compact then
			for _, item in row:GetChildren() do
				if item:IsA("TextLabel") then item.Visible = false end
			end
			local stat = if isHunt then tostring(e.captures or 0) .. " captures / " .. fmtTayaCell(e.bestStreak or 0) .. "s streak"
				else if isPanyo then fmtTayaCell(e.possessionTime or 0) .. "s hold / " .. tostring(e.steals or 0) .. " steals"
				else fmtTayaCell(e.tayaTime or 0) .. "s Taya"
			oLabel({
				Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 1, -4),
				Text = string.format("#%s  %s\n%s  |  +%s pts  |  %s total", tostring(e.rank), e.name, stat, tostring(e.pointsAwarded or 0), tostring(e.totalPoints or 0)),
				TextSize = 13, TextWrapped = true, TextColor3 = HUD_WHITE,
				TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
			}, row)
		end
	end
	scoreboardHasData = true
	scoreboard.Visible = (phaseState == "MS_05")
end

RoundRecapEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.entries) ~= "table" then return end
	huntMatchEnding = payload.mode == "SecretHunt" and payload.matchEnding == true
	buildScoreboard(payload.entries, tonumber(payload.round) or 1, tonumber(payload.totalRounds) or 3, tonumber(payload.nextIn) or 8,
		payload.mode, payload.practice == true)
end)

-- ── G. MATCH MVP PODIUM (MS_06) ──────────────────────────────────────────────
local podium = oFrame({
	Name = "MatchPodium",
	Position = UDim2.fromScale(0, 0),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.04,
	Visible = false,
	ZIndex = 20,
}, resultsGui)
local podiumTitle = oLabel({
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 0, 46),
	Text = "MATCH MVP",
	Font = Enum.Font.Oswald,
	TextSize = 44,
	TextColor3 = HUD_GOLD,
	ZIndex = 21,
}, podium)
local mvpCard = oFrame({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.14),
	Size = UDim2.fromOffset(420, 150),
	BackgroundColor3 = Color3.fromRGB(56, 48, 18),
	ZIndex = 21,
}, podium)
oCorner(mvpCard, 16)
oStroke(mvpCard, HUD_GOLD, 3)
local panyoMvpScale = Instance.new("UIScale")
panyoMvpScale.Parent = mvpCard
oLabel({
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 30),
	Text = "★ ★ ★  MVP  ★ ★ ★",
	Font = Enum.Font.Oswald,
	TextSize = 24,
	TextColor3 = HUD_GOLD,
	ZIndex = 22,
}, mvpCard)
local mvpName = oLabel({
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.new(1, 0, 0, 44),
	Text = "—",
	Font = Enum.Font.Oswald,
	TextSize = 40,
	TextColor3 = HUD_WHITE,
	ZIndex = 22,
}, mvpCard)
local mvpStats = oLabel({
	Position = UDim2.fromOffset(0, 92),
	Size = UDim2.new(1, 0, 0, 40),
	Text = "",
	TextSize = 15,
	TextColor3 = HUD_DIM,
	TextWrapped = true,
	ZIndex = 22,
}, mvpCard)
local podiumRows = Instance.new("ScrollingFrame")
podiumRows.Name = "Standings"
podiumRows.AnchorPoint = Vector2.new(0.5, 0)
podiumRows.Position = UDim2.fromScale(0.5, 0.42)
podiumRows.Size = UDim2.new(1, -32, 0.44, 0)
podiumRows.BackgroundTransparency = 1
podiumRows.BorderSizePixel = 0
podiumRows.ScrollBarThickness = 5
podiumRows.AutomaticCanvasSize = Enum.AutomaticSize.Y
podiumRows.ZIndex = 21
podiumRows.Parent = podium
local podLayout = Instance.new("UIListLayout")
podLayout.Padding = UDim.new(0, 4)
podLayout.SortOrder = Enum.SortOrder.LayoutOrder
podLayout.Parent = podiumRows
local panyoPodiumRowsScale = Instance.new("UIScale")
panyoPodiumRowsScale.Parent = podiumRows
local podiumFooter = oLabel({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.97),
	Size = UDim2.new(1, 0, 0, 26),
	Text = "Returning to party lobby...",
	TextSize = 15,
	TextColor3 = HUD_LIME,
	ZIndex = 21,
}, podium)
local podiumNextIn = 0
local podiumHasData = false

local function buildPodium(entries: { any }, nextIn: number, mode: string?)
	local isPanyo = mode == "AgawanNgPanyo"
	local isHunt = mode == "SecretHunt"
	local compact = Layout.compact()
	panyoMvpScale.Scale = 1
	panyoPodiumRowsScale.Scale = 1
	mvpCard.Size = if compact then UDim2.new(1, -32, 0, 108) else UDim2.fromOffset(420, 150)
	mvpCard.Position = if compact then UDim2.new(0.5, 0, 0, 64) else UDim2.fromScale(0.5, 0.14)
	mvpName.TextSize = if compact then 25 else 40
	mvpName.Position = if compact then UDim2.fromOffset(0, 28) else UDim2.fromOffset(0, 40)
	mvpStats.Position = if compact then UDim2.fromOffset(0, 62) else UDim2.fromOffset(0, 92)
	podiumRows.Position = if compact then UDim2.new(0.5, 0, 0, 180) else UDim2.fromScale(0.5, 0.42)
	podiumRows.Size = if compact then UDim2.new(1, -32, 1, -230) else UDim2.new(1, -32, 0.44, 0)
	mvpName.Text = if isHunt then "NO HUNT MVP" else if isPanyo then "NO PANYO MVP" else ""
	mvpStats.Text = if isHunt then "No captures recorded" else if isPanyo then "No possession recorded" else ""
	local tiedPanyoMvp = false
	if isPanyo or isHunt then
		local winners = {}
		for _, entry in ipairs(entries) do
			if entry.isMVP then table.insert(winners, entry.name) end
		end
		if #winners > 1 then
			tiedPanyoMvp = true
			mvpName.Text = "TIED MVP (" .. tostring(#winners) .. ")"
			mvpStats.Text = if isHunt then "Equal captures, streak, and match points"
				else "Equal hold time, steals, and match points"
		end
	end
	local hasWinner = false
	for _, entry in entries do if entry.isMVP then hasWinner = true break end end
	podiumTitle.Text = if not hasWinner then "NO MVP" else if tiedPanyoMvp then "TIED MVP" else "MATCH MVP"
	podiumTitle.TextSize = if compact then 28 else 44
	for _, child in ipairs(podiumRows:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	podiumNextIn = nextIn
	for _, e in ipairs(entries) do
		if e.isMVP and not tiedPanyoMvp then
			mvpName.Text = e.name
			mvpStats.Text = if isHunt
				then string.format("%d captures | %.1fs streak | %d match pts", e.captures or 0, e.bestStreak or 0, e.points or 0)
				else if isPanyo then string.format("%.1fs hold | %d steals | %d match pts", e.possessionTime or 0, e.steals or 0, e.points or 0)
				else string.format("%d points | %.1fs total Taya time", e.points or 0, e.totalTayaTime or 0)
		end
		local row = oFrame({
			Size = UDim2.new(1, 0, 0, if compact then 44 else 30),
			BackgroundColor3 = e.isMVP and Color3.fromRGB(56, 48, 18) or HUD_SLATE_D,
			BackgroundTransparency = e.isMVP and 0 or 0.3,
			LayoutOrder = e.rank,
			ZIndex = 21,
		}, podiumRows)
		oCorner(row, 6)
		if e.isMVP then oStroke(row, HUD_GOLD, 2) end
		oLabel({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.fromOffset(44, 26),
			Text = "#" .. tostring(e.rank) .. (e.isMVP and " ★" or ""),
			TextSize = 12,
			TextColor3 = e.isMVP and HUD_GOLD or HUD_DIM,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, row)
		oLabel({
			Position = UDim2.fromOffset(60, 0),
			Size = UDim2.fromOffset(230, 26),
			Text = e.name .. (e.isBot and "  [BOT]" or ""),
			TextSize = 12,
			TextColor3 = e.isMVP and HUD_GOLD or HUD_WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 22,
		}, row)
		oLabel({
			Position = UDim2.fromOffset(300, 0),
			Size = UDim2.fromOffset(120, 26),
			Text = tostring(e.points or 0) .. " pts",
			TextSize = 12,
			TextColor3 = HUD_LIME,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, row)
		oLabel({
			Position = UDim2.fromOffset(430, 0),
			Size = UDim2.fromOffset(120, 26),
			Text = if isHunt then tostring(e.captures or 0) .. " captures"
				else if isPanyo then fmtTayaCell(e.possessionTime or 0) .. "s hold"
				else fmtTayaCell(e.totalTayaTime or 0) .. "s taya",
			TextSize = 12,
			TextColor3 = HUD_DIM,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, row)
		if compact then
			for _, item in row:GetChildren() do if item:IsA("TextLabel") then item.Visible = false end end
			oLabel({
				Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
				Text = string.format("#%s  %s  |  %s pts", tostring(e.rank), e.name, tostring(e.points or 0)),
				TextSize = 14, TextColor3 = if e.isMVP then HUD_GOLD else HUD_WHITE,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22,
			}, row)
		end
	end
	podium.Visible = (phaseState == "MS_06")
	podiumHasData = true
end

MatchRecapEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.entries) ~= "table" then return end
	buildPodium(payload.entries, tonumber(payload.nextIn) or 15, payload.mode)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- GM_01 WIRING: state gate, phase transitions, live timers
-- ══════════════════════════════════════════════════════════════════════════════
local totalRounds = (Config.Match and Config.Match.TotalRounds) or 3
local lastTimerSecond = -1

local function applyOverlayGate()
	local inMatch = LocalPlayer:GetAttribute("HRushInMatch") == true
	local st = phaseState
	local mode = LocalPlayer:GetAttribute("HRushGameMode")
	overlayGui.Enabled = inMatch and st ~= nil and st ~= "MS_01"
	resultsGui.Enabled = inMatch and (st == "MS_05" or st == "MS_06")
	topBar.Visible = inMatch and st == "MS_04"
	classicObjective.Visible = topBar.Visible and mode == "ClassicTag"
	classicStandings.Visible = classicObjective.Visible and not Layout.compact()
	tagFeed.Visible = classicObjective.Visible
	draftModal.Visible = false -- The skill draft state is retired.
	scoreboard.Visible = (st == "MS_05") and scoreboardHasData
	podium.Visible = (st == "MS_06") and podiumHasData
	if st ~= "MS_05" then scoreboardHasData = false end
	if st ~= "MS_06" then podiumHasData = false end
	if st ~= "MS_04" then
		tayaBadge.Visible = false
		countdownLabel.Visible = false
		respawnLabel.Visible = false
		lastCountNum = -1
	end
	roundLabel.Text = string.format("ROUND %d / %d", tonumber(LocalPlayer:GetAttribute("HRushRound")) or 1, totalRounds)
	local compact = Layout.compact()
	settingsGear.Position = UDim2.new(1, if UserInputService.TouchEnabled then -92 else -12, 0, 8)
	topBar.Position = UDim2.new(0.5, 0, 0, if compact then 8 else 12)
	topBar.Size = UDim2.fromOffset(if compact then 154 else 240, if compact then 48 else 64)
	classicObjective.Position = UDim2.fromOffset(if compact then 12 else 24, if compact then 56 else 92)
	classicObjective.Size = UDim2.fromOffset(if compact then 180 else 300, if compact then 80 else 96)
	classicRole.Size = UDim2.new(1, -24, 0, 30)
	classicRole.TextSize = if compact then 14 else 17
	tayaTracker.Position = UDim2.fromOffset(12, if compact then 38 else 46)
	tayaTracker.Size = UDim2.new(1, -24, 0, 28)
	classicStandings.Position = UDim2.new(1, if compact then -12 else -24, 0, if compact then 80 else 92)
	classicStandings.Size = UDim2.fromOffset(if compact then 160 else 260, if compact then 112 else 112)
	tagFeed.Position = UDim2.fromOffset(if compact then 12 else 24, if compact then 148 else 202)
	tagFeed.Size = UDim2.fromOffset(if compact then 190 else 320, if compact then 74 else 160)
	cluster.Position = if compact then UDim2.fromOffset(12, 160) else UDim2.fromScale(0.015, 0.97)
	cluster.AnchorPoint = if compact then Vector2.new(0, 0) else Vector2.new(0, 1)
	cluster.Size = UDim2.fromOffset(240, if compact then 44 else 56)
	cluster.ClipsDescendants = compact
	chip.Position = UDim2.fromOffset(2, if compact then 0 else 10)
	skillChip.Position = UDim2.fromOffset(82, if compact then 0 else 10)
	tsinelasChip.Position = UDim2.fromOffset(TS.SlotOffsetX, if compact then 0 else 10)
end

local function setPhase(st: string?)
	local prev = phaseState
	phaseState = st
	if prev == "MS_03" and st ~= "MS_03" then
		splashToken += 1
		splash.Visible = false
		countdownLabel.Visible = false
	end
	applyOverlayGate()
	if st == "MS_02" and prev ~= "MS_02" then
		buildDraft()
	end
	if st == "MS_03" and prev ~= "MS_03" then
		playRoleSplash()
	end
end

LocalPlayer:GetAttributeChangedSignal("HRushState"):Connect(function()
	setPhase(LocalPlayer:GetAttribute("HRushState"))
end)
LocalPlayer:GetAttributeChangedSignal("HRushInMatch"):Connect(function()
	setPhase(LocalPlayer:GetAttribute("HRushState"))
end)
LocalPlayer:GetAttributeChangedSignal("HRushGameMode"):Connect(function()
	applyOverlayGate()
	updateRoleBanner()
	if phaseState == "MS_03" then playRoleSplash() end
end)
LocalPlayer:GetAttributeChangedSignal("HRushRole"):Connect(function()
	updateTayaBadge()
end)
ReplicatedStorage:GetAttributeChangedSignal("HRushCurrentTayaName"):Connect(function()
	local name = ReplicatedStorage:GetAttribute("HRushCurrentTayaName")
	tayaTrackerLabel.Text = "TAYA: " .. (typeof(name) == "string" and name or "—")
end)
setPhase(LocalPlayer:GetAttribute("HRushState"))
local layoutCameraConnection: RBXScriptConnection? = nil
local function watchLayoutCamera()
	if layoutCameraConnection then layoutCameraConnection:Disconnect() layoutCameraConnection = nil end
	local camera = Workspace.CurrentCamera
	if camera then layoutCameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyOverlayGate) end
	applyOverlayGate()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchLayoutCamera)
watchLayoutCamera()

game:GetService("RunService").Heartbeat:Connect(function()
	if not overlayGui.Enabled then return end
	local now = Workspace:GetServerTimeNow()
	local endsAt = ReplicatedStorage:GetAttribute("HRushPhaseEndsAt")
	local remaining = (typeof(endsAt) == "number") and (endsAt - now) or 0

	if phaseState == "MS_04" then
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		respawnLabel.Visible = humanoid == nil or humanoid.Health <= 0 or character:FindFirstChild("HumanoidRootPart") == nil
		timerLabel.Text = fmtClock(remaining)
		local mode = LocalPlayer:GetAttribute("HRushGameMode")
		if mode == "ClassicTag" then
			local role = LocalPlayer:GetAttribute("HRushRole")
			classicRole.Text = if role == "Taya" then "⬡ TAYA · TAG A RUNNER" else "○ RUNNER · AVOID TAYA"
			classicRole.TextColor3 = if role == "Taya" then Theme.Colors.TayaText else Theme.Colors.RunnerText
			local currentTaya = ReplicatedStorage:GetAttribute("HRushCurrentTayaName")
			tayaTrackerLabel.Text = if role == "Taya" then string.format("YOUR TAYA TIME: %.1fs", LocalPlayer:GetAttribute("HRushTayaTime") or 0)
				else "TAYA: " .. (if typeof(currentTaya) == "string" then currentTaya else "--")
			local ranked = {}
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("HRushInMatch") == true then table.insert(ranked, player) end
			end
			table.sort(ranked, function(a, b)
				return (a:GetAttribute("HRushTayaTime") or 0) < (b:GetAttribute("HRushTayaTime") or 0)
			end)
			local lines = { "LOWEST TAYA TIME" }
			for index = 1, math.min(3, #ranked) do
				local player = ranked[index]
				table.insert(lines, string.format("%d  %s  %.1fs", index, player.DisplayName, player:GetAttribute("HRushTayaTime") or 0))
			end
			classicBoardText.Text = table.concat(lines, "\n")
		end
		local sec = math.ceil(remaining)
		if sec ~= lastTimerSecond then
			lastTimerSecond = sec
			if sec < 30 and sec > 0 then
				timerLabel.TextColor3 = HUD_RED
				if not Theme.reducedMotion() then
					timerLabel.Size = UDim2.fromOffset(240, 50)
					game:GetService("TweenService"):Create(timerLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(220, 46) }):Play()
				end
			else
				timerLabel.TextColor3 = HUD_WHITE
			end
		end
		updateTayaBadge()
	elseif phaseState == "MS_03" then
		updateCountdown()
	elseif phaseState == "MS_02" then
		draftSub.Text = "Pumili ng isa — " .. math.max(0, math.ceil(remaining)) .. "s left"
	elseif phaseState == "MS_05" then
		local seconds = math.max(0, math.ceil(remaining))
		if (LocalPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo"
			and LocalPlayer:GetAttribute("HRushPanyoPractice") == true)
			or (LocalPlayer:GetAttribute("HRushGameMode") == "SecretHunt"
				and LocalPlayer:GetAttribute("HRushHuntPractice") == true) then
			scoreboardSub.Text = string.format("Practice complete. Returning in %ds...", seconds)
		elseif LocalPlayer:GetAttribute("HRushGameMode") == "SecretHunt" and huntMatchEnding then
			scoreboardSub.Text = string.format("Match results in %ds...", seconds)
		elseif LocalPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo"
			and (tonumber(LocalPlayer:GetAttribute("HRushRound")) or 1) >= (Config.Match.TotalRounds or 3) then
			scoreboardSub.Text = string.format("Match results in %ds...", seconds)
		else
			scoreboardSub.Text = string.format("Next round starting in %ds...", seconds)
		end
	elseif phaseState == "MS_06" then
		podiumFooter.Text = string.format("Returning to party lobby in %ds...", math.max(0, math.ceil(remaining)))
	end
end)


-- ── Bridge wiring (poll-free) ─────────────────────────────────────────────────
local function hookAttr(name: string, fn: () -> ())
	local signal = LocalPlayer:GetAttributeChangedSignal(name)
	signal:Connect(fn)
	fn() -- apply current value immediately (covers late UI load)
end

hookAttr("HRushDashCD", updateDashCD)
hookAttr("HRushSkillCD", updateSkillCD)
hookAttr("HRushSkillId", updateSkillCD)
hookAttr("HRushSkillCD_RS03", updateTsinelasCD)
hookAttr("HRushSkillId_RS03", updateTsinelasCD)
hookAttr("HRushGameMode", updateTsinelasCD)
hookAttr("HRushAiming", updateTsinelasCD)
hookAttr("HRushStunned", updateTsinelasCD)
hookAttr("HRushRole", function()
	curRole = attrStr("HRushRole", curRole)
	updateVisibility()
	updateSkillCD()
	updateRoleBanner()
	updateTsinelasCD()
end)
hookAttr("HRushState", updateTsinelasCD) -- round transitions refresh the dimmed state

updateVisibility()
updateDashCD()
updateSkillCD()
updateTsinelasCD()

-- ============================================================
-- MATCH GATE: HUD only exists during a match (MS_03..MS_05)
-- ============================================================
local function applyHudGate()
	local inMatch = LocalPlayer:GetAttribute("HRushInMatch") == true
	local st = LocalPlayer:GetAttribute("HRushState")
	gui.Enabled = inMatch and (st == "MS_03" or st == "MS_04" or st == "MS_05")
	updateRoleBanner()
end

LocalPlayer:GetAttributeChangedSignal("HRushInMatch"):Connect(applyHudGate)
LocalPlayer:GetAttributeChangedSignal("HRushState"):Connect(applyHudGate)
LocalPlayer:GetAttributeChangedSignal("HRushRole"):Connect(updateRoleBanner)
applyHudGate()
