--!strict
-- StarterPlayerScripts/UIController.lua
-- Owner: UI Dev (T05)
-- Responsibility: HUD (role banner, countdown, scoreboard, stamina bar),
--                 skill bar, Diskarte meter, clutch callouts, recap screens,
--                 and spectator camera UI.
-- See UI/UX Specification and Config.Match / Config.Events.
--
-- HUD v1 (T09 playtest slice):
--   • Stamina bar — bottom left, Runner-only (UI/UX Spec §2), fill tween-smoothed
--     at the bridge's 10 Hz rate, pulses red when depleted (≤ StaminaDepletedMin)
--   • Dash cooldown chip — "Q" keycap, vertical cooldown wipe + live countdown,
--     pops green the instant it becomes ready
-- Data source: HRush* attribute bridge on LocalPlayer (MovementController pushes
-- at 10 Hz + forced on role/state/tag events). Poll-free via GetAttributeChangedSignal.
--
-- TODO (T14): role banner, round countdown, scoreboard, skill bar.
-- TODO (T17): Implement Skill Draft UI.
-- TODO (T27): Implement clutch callouts and recap screens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Mv     = Config.Movement

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
cluster.Size = UDim2.fromOffset(300, 56)
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
	-- UI/UX Spec §2: stamina cluster is Runner-only.
	cluster.Visible = (curRole == "Runner")
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

-- ── Bridge wiring (poll-free) ─────────────────────────────────────────────────
local function hookAttr(name: string, fn: () -> ())
	local signal = LocalPlayer:GetAttributeChangedSignal(name)
	signal:Connect(fn)
	fn() -- apply current value immediately (covers late UI load)
end

hookAttr("HRushStamina", updateStamina)
hookAttr("HRushStaminaMax", updateStamina)
hookAttr("HRushDashCD", updateDashCD)
hookAttr("HRushRole", function()
	curRole = attrStr("HRushRole", curRole)
	updateVisibility()
	updateStamina()
end)
hookAttr("HRushBoost", updateStamina) -- reserve: boost-active bar highlight (T14)

updateVisibility()
updateStamina()
updateDashCD()

print("[UIController] Loaded — HUD v1 (stamina bar + dash cooldown). T14 partial; T17, T27 TODO.")
