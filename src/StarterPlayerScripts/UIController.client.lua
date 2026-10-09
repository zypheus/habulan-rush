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

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Mv     = Config.Movement

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
local Workspace   = game:GetService("Workspace")
local Remotes     = ReplicatedStorage:WaitForChild("Remotes")
local TagEvent    = Remotes:WaitForChild("TagEvent") :: RemoteEvent
local RoundRecapEvent = Remotes:WaitForChild("RoundRecap") :: RemoteEvent
local MatchRecapEvent = Remotes:WaitForChild("MatchRecap") :: RemoteEvent
local PickSkill   = Remotes:WaitForChild("PickSkill") :: RemoteEvent

-- GM_01 HUD palette
local HUD_LIME     = Color3.fromRGB(221, 247, 100)
local HUD_NAVY     = Color3.fromRGB(20, 32, 40)
local HUD_SLATE    = Color3.fromRGB(44, 66, 76)
local HUD_SLATE_D  = Color3.fromRGB(30, 48, 56)
local HUD_RED      = Color3.fromRGB(235, 64, 64)
local HUD_RED_DARK = Color3.fromRGB(50, 16, 16)
local HUD_CYAN     = Color3.fromRGB(110, 225, 240)
local HUD_GOLD     = Color3.fromRGB(246, 190, 50)
local HUD_WHITE    = Color3.fromRGB(255, 255, 255)
local HUD_DIM      = Color3.fromRGB(176, 194, 200)

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
	local inMatch = LocalPlayer:GetAttribute("HRushInMatch") == true
	local st = LocalPlayer:GetAttribute("HRushState")
	-- Do NOT show during MS_04: topBar already shows TAYA tracker + role context.
	local show = inMatch and (st == "MS_03" or st == "MS_05")
	if show then
		roleBanner.Visible = true
		local role = LocalPlayer:GetAttribute("HRushRole")
	if role == "Taya" then
			roleLabel.Text = "TAYA"
			roleLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
			roleSubLabel.Text = "TAG THEM ALL!"
			roleSubLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
			roleStroke.Color = Color3.fromRGB(255, 80, 80)
			roleStroke.Thickness = 3
			roleBanner.BackgroundColor3 = Color3.fromRGB(50, 16, 16)
		else
			roleLabel.Text = "RUNNER"
			roleLabel.TextColor3 = Color3.fromRGB(100, 230, 110)
			roleSubLabel.Text = "DON'T GET TAGGED!"
			roleSubLabel.TextColor3 = Color3.fromRGB(130, 240, 140)
			roleStroke.Color = Color3.fromRGB(80, 214, 90)
			roleStroke.Thickness = 3
			roleBanner.BackgroundColor3 = Color3.fromRGB(16, 36, 20)
		end
	else
		roleBanner.Visible = false
	end
end

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
	cluster.Visible = isRunner or hasSkill
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

-- ══════════════════════════════════════════════════════════════════════════════
-- GM_01 MATCH OVERLAYS (Skill Draft, Role Splash, Live Bar, Tag Feed, Recaps)
-- Lives in its own ScreenGui so the MS_02 draft can show while the base HUD
-- (gated to MS_03..MS_05) stays hidden. Sections toggle by HRushState.
-- ══════════════════════════════════════════════════════════════════════════════
local overlayGui = Instance.new("ScreenGui")
overlayGui.Name = "HRushOverlays"
overlayGui.ResetOnSpawn = false
overlayGui.IgnoreGuiInset = true
overlayGui.DisplayOrder = 12
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

-- ── A. TOP MATCH BAR (MS_04) ─────────────────────────────────────────────────
local topBar = oFrame({
	Name = "TopMatchBar",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.015),
	Size = UDim2.new(0.62, 0, 0, 84),
	BackgroundTransparency = 1,
	Visible = false,
}, overlayGui)

local roundPill = oFrame({
	Name = "RoundPill",
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.fromOffset(118, 30),
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
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.fromOffset(220, 46),
	Text = "2:30",
	Font = Enum.Font.Arcade,
	TextSize = 44,
	TextColor3 = HUD_WHITE,
}, topBar)
local timerStroke = oStroke(timerLabel, HUD_NAVY, 0, 1) -- placeholder; stroke on text needs TextStroke

local tayaTracker = oFrame({
	Name = "TayaTracker",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.56),
	Size = UDim2.fromOffset(190, 28),
	BackgroundColor3 = HUD_RED_DARK,
	BackgroundTransparency = 0.1,
}, topBar)
oCorner(tayaTracker, 14)
oStroke(tayaTracker, HUD_RED, 1.5, 0.15)
local tayaTrackerLabel = oLabel({
	Size = UDim2.fromScale(1, 1),
	Text = "TAYA: —",
	TextSize = 13,
	TextColor3 = Color3.fromRGB(255, 120, 120),
}, tayaTracker)

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
	-- keep at most 4 pills
	local kids = {}
	for _, c in ipairs(tagFeed:GetChildren()) do
		if c:IsA("Frame") then table.insert(kids, c) end
	end
	if #kids > 4 then
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
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.38),
	Size = UDim2.new(0.7, 0, 0, 110),
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.08,
	Visible = false,
	ZIndex = 20,
}, overlayGui)
oCorner(splash, 16)
local splashStroke = oStroke(splash, HUD_RED, 3)
local splashTitle = oLabel({
	Position = UDim2.fromOffset(0, 12),
	Size = UDim2.new(1, 0, 0, 52),
	Text = "RUNNER!",
	Font = Enum.Font.Bangers,
	TextSize = 52,
	TextColor3 = HUD_CYAN,
	ZIndex = 21,
}, splash)
local splashSub = oLabel({
	Position = UDim2.fromOffset(0, 68),
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
	if isTaya then
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
	splash.Position = UDim2.fromScale(0.5, 0.30)
	local ts = game:GetService("TweenService")
	ts:Create(splash, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.38) }):Play()
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
	Position = UDim2.fromScale(0.5, 0.65),
	Size = UDim2.fromOffset(450, 90),
	Text = "",
	Font = Enum.Font.Bangers,
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
			countdownLabel.Size = UDim2.fromOffset(560, 120)
			local ts = game:GetService("TweenService")
			ts:Create(countdownLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(500, 110) }):Play()
		end
	else
		-- 0: the launch moment
		countdownLabel.Visible = true
		if lastCountNum ~= 0 then
			lastCountNum = 0
			countdownLabel.Text = "HABULAN NA!"
			countdownLabel.TextSize = 72
			countdownLabel.TextColor3 = HUD_RED
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
	local isTaya = LocalPlayer:GetAttribute("HRushRole") == "Taya"
	tayaBadge.Visible = isTaya and phaseState == "MS_04"
	if tayaBadge.Visible then
		local t = tonumber(LocalPlayer:GetAttribute("HRushTayaTime")) or 0
	badgeLabel.Text = "ORAS MO BILANG TAYA: " .. fmtTaya(t) .. "s"
	end
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
	Font = Enum.Font.Bangers,
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
local scoreboard = oFrame({
	Name = "RoundScoreboard",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(580, 440),
	BackgroundColor3 = HUD_NAVY,
	BackgroundTransparency = 0.06,
	Visible = false,
	ZIndex = 20,
}, overlayGui)
oCorner(scoreboard, 18)
oStroke(scoreboard, HUD_LIME, 2, 0.35)
local scoreboardTitle = oLabel({
	Position = UDim2.fromOffset(0, 14),
	Size = UDim2.new(1, 0, 0, 34),
	Text = "ROUND 1 RESULTS",
	Font = Enum.Font.Bangers,
	TextSize = 30,
	TextColor3 = HUD_LIME,
	ZIndex = 21,
}, scoreboard)
local scoreboardSub = oLabel({
	Position = UDim2.fromOffset(0, 50),
	Size = UDim2.new(1, 0, 0, 18),
	Text = "Next round starting soon...",
	TextSize = 13,
	TextColor3 = HUD_DIM,
	ZIndex = 21,
}, scoreboard)
local scoreboardRows = oFrame({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.16),
	Size = UDim2.fromOffset(540, 330),
	BackgroundTransparency = 1,
	ZIndex = 21,
}, scoreboard)
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

local function buildScoreboard(entries: { any }, round: number, totalRounds: number, nextIn: number)
	for _, child in ipairs(scoreboardRows:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	scoreboardTitle.Text = string.format("ROUND %d / %d RESULTS", round, totalRounds)
	scoreboardNextIn = nextIn
	for _, e in ipairs(entries) do
		local row = oFrame({
			Size = UDim2.new(1, 0, 0, 34),
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
			Text = e.name .. (e.isBot and "  [BOT]" or ""),
			TextSize = 13,
			TextColor3 = (e.rank == 1) and HUD_GOLD or HUD_WHITE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 22,
		}, row)
		oLabel({
			Position = UDim2.fromOffset(260, 0),
			Size = UDim2.fromOffset(110, 34),
			Text = fmtTayaCell(e.tayaTime) .. "s",
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
	end
	scoreboardHasData = true
	scoreboard.Visible = (phaseState == "MS_05")
end

RoundRecapEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.entries) ~= "table" then return end
	buildScoreboard(payload.entries, tonumber(payload.round) or 1, tonumber(payload.totalRounds) or 3, tonumber(payload.nextIn) or 8)
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
}, overlayGui)
local podiumTitle = oLabel({
	Position = UDim2.fromOffset(0, 24),
	Size = UDim2.new(1, 0, 0, 46),
	Text = "MATCH MVP",
	Font = Enum.Font.Bangers,
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
oLabel({
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 30),
	Text = "★ ★ ★  MVP  ★ ★ ★",
	Font = Enum.Font.Bangers,
	TextSize = 24,
	TextColor3 = HUD_GOLD,
	ZIndex = 22,
}, mvpCard)
local mvpName = oLabel({
	Position = UDim2.fromOffset(0, 40),
	Size = UDim2.new(1, 0, 0, 44),
	Text = "—",
	Font = Enum.Font.Bangers,
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
local podiumRows = oFrame({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(560, 240),
	BackgroundTransparency = 1,
	ZIndex = 21,
}, podium)
local podLayout = Instance.new("UIListLayout")
podLayout.Padding = UDim.new(0, 4)
podLayout.SortOrder = Enum.SortOrder.LayoutOrder
podLayout.Parent = podiumRows
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

local function buildPodium(entries: { any }, nextIn: number)
	for _, child in ipairs(podiumRows:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	podiumNextIn = nextIn
	for _, e in ipairs(entries) do
		if e.isMVP then
			mvpName.Text = e.name
			mvpStats.Text = string.format("%d points · %.1fs total Taya time", e.points or 0, e.totalTayaTime or 0)
		end
		local row = oFrame({
			Size = UDim2.new(1, 0, 0, 26),
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
			Text = fmtTayaCell(e.totalTayaTime or 0) .. "s taya",
			TextSize = 12,
			TextColor3 = HUD_DIM,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 22,
		}, row)
	end
	podium.Visible = (phaseState == "MS_06")
end

MatchRecapEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.entries) ~= "table" then return end
	buildPodium(payload.entries, tonumber(payload.nextIn) or 15)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- GM_01 WIRING: state gate, phase transitions, live timers
-- ══════════════════════════════════════════════════════════════════════════════
local totalRounds = (Config.Match and Config.Match.TotalRounds) or 3
local lastTimerSecond = -1

local function applyOverlayGate()
	local inMatch = LocalPlayer:GetAttribute("HRushInMatch") == true
	local st = phaseState
	overlayGui.Enabled = inMatch and st ~= nil and st ~= "MS_01"
	topBar.Visible = (st == "MS_04")
	draftModal.Visible = (st == "MS_02")
	scoreboard.Visible = (st == "MS_05") and scoreboardHasData
	podium.Visible = (st == "MS_06") and podiumHasData
	if st ~= "MS_05" then scoreboardHasData = false end
	if st ~= "MS_06" then podiumHasData = false end
	if st ~= "MS_04" then
		tayaBadge.Visible = false
		countdownLabel.Visible = false
		lastCountNum = -1
	end
	roundLabel.Text = string.format("ROUND %d / %d", tonumber(LocalPlayer:GetAttribute("HRushRound")) or 1, totalRounds)
end

local function setPhase(st: string?)
	local prev = phaseState
	phaseState = st
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
LocalPlayer:GetAttributeChangedSignal("HRushRole"):Connect(function()
	updateTayaBadge()
end)
ReplicatedStorage:GetAttributeChangedSignal("HRushCurrentTayaName"):Connect(function()
	local name = ReplicatedStorage:GetAttribute("HRushCurrentTayaName")
	tayaTrackerLabel.Text = "TAYA: " .. (typeof(name) == "string" and name or "—")
end)
setPhase(LocalPlayer:GetAttribute("HRushState"))

game:GetService("RunService").Heartbeat:Connect(function()
	if not overlayGui.Enabled then return end
	local now = Workspace:GetServerTimeNow()
	local endsAt = ReplicatedStorage:GetAttribute("HRushPhaseEndsAt")
	local remaining = (typeof(endsAt) == "number") and (endsAt - now) or 0

	if phaseState == "MS_04" then
		timerLabel.Text = fmtClock(remaining)
		local sec = math.ceil(remaining)
		if sec ~= lastTimerSecond then
			lastTimerSecond = sec
			if sec < 30 and sec > 0 then
				timerLabel.TextColor3 = HUD_RED
				timerLabel.Size = UDim2.fromOffset(240, 50)
				game:GetService("TweenService"):Create(timerLabel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(220, 46) }):Play()
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
		scoreboardSub.Text = string.format("Next round starting in %ds...", math.max(0, math.ceil(remaining)))
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

hookAttr("HRushStamina", updateStamina)
hookAttr("HRushStaminaMax", updateStamina)
hookAttr("HRushDashCD", updateDashCD)
hookAttr("HRushSkillCD", updateSkillCD)
hookAttr("HRushSkillId", updateSkillCD)
hookAttr("HRushRole", function()
	curRole = attrStr("HRushRole", curRole)
	updateVisibility()
	updateStamina()
	updateSkillCD()
	updateRoleBanner()
end)
hookAttr("HRushBoost", updateStamina) -- reserve: boost-active bar highlight (T14)

updateVisibility()
updateStamina()
updateDashCD()
updateSkillCD()

print("[UIController] Loaded — HUD v1.1 (stamina bar + dash CD + RS_01 skill chip). T14 partial; T17, T27 TODO.")

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
