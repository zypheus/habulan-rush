--!strict
-- StarterPlayerScripts/UIController.lua
-- Owner: UI Dev (T05)
-- Responsibility: HUD (role banner, countdown, scoreboard, stamina bar),
--                 skill bar, Diskarte meter, clutch callouts, recap screens,
--                 and spectator camera UI.
-- See UI/UX Specification and Config.Match / Config.Events.
--
-- HUD v1.1 (T09 playtest slice + RS_01 skill chip):
--   • Stamina bar — bottom left, Runner-only (UI/UX Spec §2), fill tween-smoothed
--     at the bridge's 10 Hz rate, pulses red when depleted (≤ StaminaDepletedMin)
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
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Mv     = Config.Movement
local TS     = Config.UI.Tsinelas -- RS_03 slot sizes, labels, and timings

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

-- ── Palette (placeholder; Art Bible pass later in T14) ────────────────────────
local COL_FILL_OK    = Color3.fromRGB(86, 214, 90)
local COL_LOW        = Color3.fromRGB(226, 61, 61)
local COL_LOW_DARK   = Color3.fromRGB(96, 24, 24)
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
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

-- ── Bottom-left cluster: stamina bar + dash chip ──────────────────────────────
local cluster = Instance.new("Frame")
cluster.Name = "MoveCluster"
cluster.AnchorPoint = Vector2.new(0, 1)
cluster.Position = UDim2.fromScale(0.015, 0.97)
cluster.Size = UDim2.fromOffset(364, 56) -- room for stamina + dash chip + skill chip
cluster.BackgroundTransparency = 1
cluster.Parent = gui

local title = Instance.new("TextLabel")
title.Name = "StaminaLabel"
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(2, 0)
title.Size = UDim2.fromOffset(140, 14)
title.Font = Enum.Font.GothamBold
title.TextSize = 11
title.Text = "STAMINA"
title.TextColor3 = COL_TEXT
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextStrokeTransparency = 0.6
title.Parent = cluster

local barBg = Instance.new("Frame")
barBg.Name = "BarBG"
barBg.Position = UDim2.fromOffset(2, 18)
barBg.Size = UDim2.fromOffset(220, 16)
barBg.BackgroundColor3 = COL_PANEL
barBg.BackgroundTransparency = 0.25
barBg.BorderSizePixel = 0
barBg.ClipsDescendants = true
barBg.Parent = cluster
corner(barBg, 4)
stroke(barBg, Color3.new(0, 0, 0), 1)

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(1, 1) -- corrected on first attribute read
fill.BackgroundColor3 = COL_FILL_OK
fill.BorderSizePixel = 0
fill.Parent = barBg
corner(fill, 4)

local pct = Instance.new("TextLabel")
pct.Name = "Pct"
pct.BackgroundTransparency = 1
pct.Size = UDim2.fromScale(1, 1)
pct.Font = Enum.Font.GothamBold
pct.TextSize = 10
pct.Text = "100"
pct.TextColor3 = Color3.new(1, 1, 1)
pct.TextStrokeTransparency = 0.5
pct.ZIndex = 3
pct.Parent = barBg

-- Dash cooldown chip (right of the bar).
local chip = Instance.new("Frame")
chip.Name = "DashChip"
chip.Position = UDim2.fromOffset(236, 10)
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
chipCaption.Position = UDim2.fromOffset(232, 44)
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
skillChip.Position = UDim2.fromOffset(296, 10)
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
skillCaption.Position = UDim2.fromOffset(284, 44)
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

-- ── Stamina bar logic ─────────────────────────────────────────────────────────
local fillTween: Tween? = nil
local flashConn: RBXScriptConnection? = nil
local curRole = attrStr("HRushRole", "Runner")
local curSkillId = "" -- granted skill id (declared early so visibility logic sees it)

local function setFlash(on: boolean)
	if on and not flashConn then
		-- Fast red pulse while depleted (~2 Hz); stops when stamina recovers.
		flashConn = RunService.Heartbeat:Connect(function(t: number)
			local a = math.sin(t * 12) * 0.5 + 0.5 -- 0..1
			fill.BackgroundColor3 = COL_LOW:Lerp(COL_LOW_DARK, a)
		end)
	elseif not on and flashConn then
		flashConn:Disconnect()
		flashConn = nil
		fill.BackgroundColor3 = COL_FILL_OK
	end
end

local function updateStamina()
	local stamina = attrNum("HRushStamina", Mv.StaminaMax)
	local max = math.max(1, attrNum("HRushStaminaMax", Mv.StaminaMax))
	local ratio = math.clamp(stamina / max, 0, 1)

	-- Tween-smoothed fill: 10 Hz bridge + 0.12 s tween = continuous-looking bar.
	if fillTween then
		fillTween:Cancel()
	end
	fillTween = TweenService:Create(
		fill,
		TweenInfo.new(0.12, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(ratio, 1) }
	)
	fillTween:Play()

	pct.Text = tostring(math.floor(stamina + 0.5))
	setFlash(stamina <= Mv.StaminaDepletedMin and curRole == "Runner")
end

local function updateVisibility()
	-- Stamina and dash stay Runner-only; the skill chip follows the grant list
	-- instead, so Config.Debug.AllowAnyRoleForSkills can show it on Taya too.
	-- The chip is also a circle (not a rounded square), so it reads apart from
	-- the dash chip by SHAPE, not only by color.
	local isRunner = (curRole == "Runner")
	local hasSkill = (curSkillId ~= "")
	title.Visible = isRunner
	barBg.Visible = isRunner
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

-- ── Bridge wiring (poll-free) ─────────────────────────────────────────────────
local function hookAttr(name: string, fn: () -> ())
	local signal = LocalPlayer:GetAttributeChangedSignal(name)
	signal:Connect(fn)
	fn() -- apply current value immediately (covers late UI load)
end

hookAttr("HRushStamina", updateStamina)
hookAttr("HRushStaminaMax", updateStamina)
hookAttr("HRushDashCD", updateDashCD)
hookAttr("HRushSkillCD", updateSkillCD)
hookAttr("HRushSkillId", updateSkillCD)
hookAttr("HRushSkillCD_RS03", updateTsinelasCD)
hookAttr("HRushSkillId_RS03", updateTsinelasCD)
hookAttr("HRushAiming", updateTsinelasCD)
hookAttr("HRushStunned", updateTsinelasCD)
hookAttr("HRushRole", function()
	curRole = attrStr("HRushRole", curRole)
	updateVisibility()
	updateStamina()
	updateSkillCD()
	updateTsinelasCD()
end)
hookAttr("HRushBoost", updateStamina) -- reserve: boost-active bar highlight (T14)
hookAttr("HRushState", updateTsinelasCD) -- round transitions refresh the dimmed state

updateVisibility()
updateStamina()
updateDashCD()
updateSkillCD()
updateTsinelasCD()

print("[UIController] Loaded — HUD v1.1 (stamina bar + dash CD + RS_01 skill chip + RS_03 tsinelas chip). T14 partial; T17, T27 TODO.")

-- ============================================================
-- MATCH GATE: HUD only exists during a match (MS_03..MS_05)
-- ============================================================
local function applyHudGate()
	local inMatch = LocalPlayer:GetAttribute("HRushInMatch") == true
	local st = LocalPlayer:GetAttribute("HRushState")
	gui.Enabled = inMatch and (st == "MS_03" or st == "MS_04" or st == "MS_05")
end

LocalPlayer:GetAttributeChangedSignal("HRushInMatch"):Connect(applyHudGate)
LocalPlayer:GetAttributeChangedSignal("HRushState"):Connect(applyHudGate)
applyHudGate()
