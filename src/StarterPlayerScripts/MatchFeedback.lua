--!strict
-- Task/spec: suppress match notices during the showcase, approved 2026-10-25.
-- StarterPlayerScripts/MatchFeedback.lua
-- Owner: Project Owner
-- Responsibility: Floating match and movement action cards, plus involved-player gamepad haptics.
-- Task/spec: clear arcade feedback and floating action notifications, approved 2026-10-24.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Settings = require(script.Parent:WaitForChild("ClientSettings"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))
local MatchShowcase = require(script.Parent:WaitForChild("MatchShowcase", 10))

type Kind = "major" | "followup" | "minor"
type Entry = { title: string, subtitle: string, kind: Kind, accent: Color3, icon: string }
type Card = {
	root: CanvasGroup, badge: Frame, art: Frame, title: TextLabel, detail: TextLabel,
	scale: UIScale, base: UDim2, token: number, tweens: { Tween }, shownAt: number,
	mergeCount: number, totalGain: number, action: string, hasRoll: boolean,
}

local MatchFeedback = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("HRUSH_MatchFeedback")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "HRUSH_MatchFeedback"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Theme.screen(gui, Theme.Layers.Feedback)
gui.Parent = playerGui

local tuning = Config.MatchFeedback
local momentumFx = Config.Momentum.Fx
assert(tuning.EntrySeconds + tuning.ExitSeconds < momentumFx.PopupTime, "Feedback motion exceeds slide duration")
assert(momentumFx.MaxPopups >= 1, "Feedback needs a movement card")

local function line(parent: Instance, x: number, y: number, width: number, rotation: number)
	local shape = Instance.new("Frame")
	shape.AnchorPoint = Vector2.new(0.5, 0.5)
	shape.Position = UDim2.fromOffset(x, y)
	shape.Size = UDim2.fromOffset(width, 2)
	shape.Rotation = rotation
	shape.BackgroundColor3 = Theme.Colors.Cream
	shape.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = shape
	shape.Parent = parent
end

local function ring(parent: Instance, size: number)
	local shape = Instance.new("Frame")
	shape.AnchorPoint = Vector2.new(0.5, 0.5)
	shape.Position = UDim2.fromOffset(16, 16)
	shape.Size = UDim2.fromOffset(size, size)
	shape.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = shape
	local outline = Instance.new("UIStroke")
	outline.Color = Theme.Colors.Cream
	outline.Thickness = 2
	outline.Parent = shape
	shape.Parent = parent
end

local function drawIcon(art: Frame, icon: string)
	for _, child in art:GetChildren() do child:Destroy() end
	if icon == "slide" then
		line(art, 11, 10, 13, -20); line(art, 17, 16, 20, -20); line(art, 21, 22, 13, -20)
	elseif icon == "roll" then
		ring(art, 18); line(art, 24, 9, 8, -45); line(art, 26, 13, 8, 45)
	elseif icon == "vault" then
		line(art, 11, 20, 13, -42); line(art, 21, 20, 13, 42)
		line(art, 11, 13, 13, -42); line(art, 21, 13, 13, 42)
	elseif icon == "tag" then
		line(art, 16, 7, 8, 90); line(art, 16, 25, 8, 90)
		line(art, 7, 16, 8, 0); line(art, 25, 16, 8, 0); ring(art, 7)
	elseif icon == "panyo" then
		local cloth = Instance.new("Frame")
		cloth.AnchorPoint = Vector2.new(0.5, 0.5)
		cloth.Position = UDim2.fromOffset(16, 16)
		cloth.Size = UDim2.fromOffset(15, 15)
		cloth.Rotation = 45
		cloth.BackgroundTransparency = 1
		local outline = Instance.new("UIStroke")
		outline.Color = Theme.Colors.Cream
		outline.Thickness = 2
		outline.Parent = cloth
		cloth.Parent = art
		line(art, 16, 16, 12, 45)
	elseif icon == "hunt" then
		ring(art, 17)
		line(art, 16, 5, 7, 90); line(art, 16, 27, 7, 90)
		line(art, 5, 16, 7, 0); line(art, 27, 16, 7, 0)
	elseif icon == "phase" then
		ring(art, 19); line(art, 16, 12, 8, 90); line(art, 19, 17, 8, 30)
	elseif icon == "lost" then
		line(art, 16, 16, 20, 45); line(art, 16, 16, 20, -45)
	else
		ring(art, 14)
	end
end

local function makeCard(name: string): Card
	local root = Instance.new("CanvasGroup")
	root.Name = name
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.BackgroundTransparency = 0.06
	root.Visible = false
	Theme.surface(root, false, Theme.Colors.Gold)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local badge = Instance.new("Frame")
	badge.Name = "IconBadge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 10, 0.5, 0)
	badge.Size = UDim2.fromOffset(34, 34)
	badge.BackgroundTransparency = 0.72
	badge.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badge
	badge.Parent = root
	local art = Instance.new("Frame")
	art.Name = "OriginalIcon"
	art.Position = UDim2.fromOffset(1, 1)
	art.Size = UDim2.fromOffset(32, 32)
	art.BackgroundTransparency = 1
	art.Parent = badge
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextTruncate = Enum.TextTruncate.AtEnd
	Theme.text(title, 18, true)
	title.Parent = root
	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.TextYAlignment = Enum.TextYAlignment.Center
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	Theme.text(detail, 12, false)
	detail.Parent = root
	return { root = root, badge = badge, art = art, title = title, detail = detail,
		scale = scale, base = UDim2.new(), token = 0, tweens = {}, shownAt = 0,
		mergeCount = 0, totalGain = 0, action = "", hasRoll = false }
end

local matchCard = makeCard("MatchNotice")
local movementCards: { Card } = {}
for index = 1, momentumFx.MaxPopups do
	table.insert(movementCards, makeCard("MovementNotice" .. index))
end

local active: Entry? = nil
local pending: Entry? = nil
local movementCursor = 0
local lastMovement: Card? = nil
local lastMovementAt = -math.huge

local function priority(kind: Kind): number
	return if kind == "major" then 3 else if kind == "followup" then 2 else 1
end

local function duration(kind: Kind): number
	return if kind == "major" then tuning.MajorSeconds
		else if kind == "followup" then tuning.FollowupSeconds else tuning.MinorSeconds
end

local function stopTweens(card: Card)
	for _, motion in card.tweens do motion:Cancel() end
	card.tweens = {}
end

local function hide(card: Card)
	card.token += 1
	stopTweens(card)
	card.root.Visible = false
end

local function tween(card: Card, object: Instance, seconds: number, goal: { [string]: any })
	local motion = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	table.insert(card.tweens, motion)
	motion:Play()
end

local function render(card: Card, titleText: string, detailText: string, icon: string, accent: Color3,
		movement: boolean, minor: boolean, rank: number?)
	local compact = Layout.compact()
	local height = if movement then (if compact then 52 else 56)
		else if minor then (if compact then 48 else 46) else (if compact then 62 else 68)
	height = math.max(height, card.title.TextSize + (if detailText ~= "" then card.detail.TextSize else 0) + 22)
	local width = if movement then (if compact then 250 else 270)
		else if compact then 300 else if minor then 310 else 360
	Layout.fit(card.root, Vector2.new(width, height), Vector2.new(width, height), 12)
	if movement then
		card.root.AnchorPoint = Vector2.new(0.5, 1)
		local bottom = if compact then 90 else momentumFx.BarBottom + 92
		card.base = UDim2.new(0.5, 0, 1, -bottom - ((rank or 1) - 1) * (height + 8))
	else
		card.root.AnchorPoint = Vector2.new(0.5, 0)
		card.base = UDim2.new(0.5, 0, 0, if compact then 114 else 164)
	end
	Theme.surface(card.root, false, accent)
	card.badge.BackgroundColor3 = accent
	card.title.Text = titleText
	card.title.TextColor3 = accent
	card.detail.Text = detailText
	card.detail.TextColor3 = Theme.Colors.Cream
	card.title.Position = UDim2.fromOffset(52, if detailText == "" then 5 else if movement and compact then 3 else 7)
	card.title.Size = UDim2.new(1, -60, 0, if detailText == "" then height - 10 else math.max(23, card.title.TextSize + 3))
	card.detail.Position = UDim2.fromOffset(52, math.max(29, card.title.TextSize + 12))
	card.detail.Size = UDim2.new(1, -60, 0, math.max(20, card.detail.TextSize + 2))
	card.detail.Visible = detailText ~= ""
	drawIcon(card.art, icon)
end

local function animate(card: Card, seconds: number): number
	card.token += 1
	local token = card.token
	stopTweens(card)
	card.root.Visible = true
	if Theme.reducedMotion() or VfxScale.cosmetic() <= 0 then
		card.root.Position = card.base
		card.root.GroupTransparency = 0
		card.scale.Scale = 1
		return token
	end
	card.root.Position = card.base + UDim2.fromOffset(0, 12)
	card.root.GroupTransparency = 1
	card.scale.Scale = 0.94
	tween(card, card.root, tuning.EntrySeconds, { Position = card.base, GroupTransparency = 0 })
	tween(card, card.scale, tuning.EntrySeconds, { Scale = 1 })
	task.delay(tuning.EntrySeconds, function()
		if card.token ~= token then return end
		tween(card, card.root, math.max(0.01, seconds - tuning.EntrySeconds - tuning.ExitSeconds),
			{ Position = card.base + UDim2.fromOffset(0, -8) })
	end)
	task.delay(math.max(0, seconds - tuning.ExitSeconds), function()
		if card.token ~= token then return end
		tween(card, card.root, tuning.ExitSeconds,
			{ Position = card.base + UDim2.fromOffset(0, -tuning.FloatPx), GroupTransparency = 1 })
	end)
	return token
end

local function refreshMovementLayout(preserveNewest: boolean?)
	local visible: { Card } = {}
	for _, card in movementCards do if card.root.Visible then table.insert(visible, card) end end
	table.sort(visible, function(a, b) return a.shownAt > b.shownAt end)
	local limit = if Layout.compact() then 1 else math.min(2, momentumFx.MaxPopups)
	for rank, card in visible do
		if rank > limit then
			hide(card)
		else
			render(card, card.title.Text, card.detail.Text, string.lower(card.action),
				card.title.TextColor3, true, false, rank)
			if rank ~= 1 or not preserveNewest then
				stopTweens(card)
				card.root.Position = card.base
				card.root.GroupTransparency = 0
				card.scale.Scale = 1
			end
		end
	end
end

local function playHaptic()
	if not string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) then return end
	local ok = pcall(function()
		local effect = Instance.new("HapticEffect")
		effect.Name = "HRUSH_ActionHaptic"
		effect.Type = Enum.HapticEffectType.Custom
		effect.Parent = Workspace
		Debris:AddItem(effect, 1)
		effect:SetWaveformKeys({
			FloatCurveKey.new(0, 0, Enum.KeyInterpolationMode.Linear),
			FloatCurveKey.new(20, Config.MatchFeedback.HapticPeak, Enum.KeyInterpolationMode.Linear),
			FloatCurveKey.new(Config.MatchFeedback.HapticMillis, 0, Enum.KeyInterpolationMode.Linear),
		})
		effect:Play()
	end)
	if not ok then return end -- Unsupported devices still get the full visual notice.
end

local function display(entry: Entry)
	active = entry
	render(matchCard, entry.title, entry.subtitle, entry.icon, entry.accent, false, entry.kind == "minor")
	local token = animate(matchCard, duration(entry.kind))
	gui.Enabled = true
	task.delay(duration(entry.kind), function()
		if token ~= matchCard.token then return end
		active = nil
		hide(matchCard)
		local nextEntry = pending
		pending = nil
		if nextEntry then display(nextEntry) end
		if not matchCard.root.Visible then
			local anyMovement = false
			for _, card in movementCards do if card.root.Visible then anyMovement = true break end end
			if not anyMovement then gui.Enabled = false end
		end
	end)
end

function MatchFeedback.clear()
	active = nil
	pending = nil
	hide(matchCard)
	for _, card in movementCards do hide(card) end
	lastMovement = nil
	lastMovementAt = -math.huge
	gui.Enabled = false
end

function MatchFeedback.show(message: string, detail: string, kind: Kind, accent: Color3, haptic: boolean?, icon: string?)
	if MatchShowcase.isActive() then return end
	local state = player:GetAttribute("HRushState")
	if player:GetAttribute("HRushInMatch") ~= true or (state ~= "MS_03" and state ~= "MS_04") then return end
	local entry: Entry = { title = message, subtitle = detail, kind = kind, accent = accent, icon = icon or "phase" }
	if haptic == true then playHaptic() end
	if active == nil or priority(kind) >= priority(active.kind) then
		pending = nil
		display(entry)
	elseif pending == nil or priority(kind) >= priority(pending.kind) then
		pending = entry
	end
end

function MatchFeedback.showMovement(action: string, gain: number?, count: number?, perfect: boolean?, accent: Color3?, variant: string?)
	if player:GetAttribute("HRushState") ~= "MS_04" or Settings.get("showPopups") ~= true then return end
	local now = Workspace:GetServerTimeNow()
	local merging = (action == "Slide" or action == "Roll")
		and lastMovement ~= nil and lastMovement.root.Visible
		and (lastMovement.action == "Slide" or lastMovement.action == "Roll")
		and now - lastMovementAt <= momentumFx.PopupMergeWindow
	local card: Card
	if merging then
		card = lastMovement :: Card
		card.mergeCount += 1
		card.totalGain += gain or 0
	else
		movementCursor = movementCursor % #movementCards + 1
		card = movementCards[movementCursor]
		card.mergeCount = 1
		card.totalGain = gain or 0
		card.hasRoll = false
	end
	card.action = action
	card.hasRoll = card.hasRoll or action == "Roll"
	card.shownAt = now
	lastMovement = card
	lastMovementAt = now
	local word = if action == "Lost" then "MOMENTUM LOST"
		else if action == "Vault" then (if variant == "SpeedVault" then "SPEED VAULT" else if variant == "AirVault" then "AIR VAULT" else "VAULT")
		else if perfect then "PERFECT ROLL" else string.upper(action)
	if card.mergeCount > 1 then word ..= " ×" .. tostring(card.mergeCount) end
	local detail = if action == "Lost" or action == "Vault" then ""
		else if card.totalGain <= 0 then "MAX"
		else "+" .. string.format("%g", card.totalGain) .. " MOMENTUM"
	local color = if action == "Lost" then Theme.Colors.TayaText
		else if (count or 1) > 1 and (gain or 0) > 0 then Theme.Colors.Muted
		else accent or Theme.Colors.Gold
	render(card, word, detail, string.lower(action), color, true, false, 1)
	local seconds = if card.hasRoll then momentumFx.RollPopupTime
		else if action == "Lost" then momentumFx.LostTime
		else if action == "Vault" then tuning.VaultSeconds else momentumFx.PopupTime
	local token = animate(card, seconds)
	gui.Enabled = true
	refreshMovementLayout(true)
	task.delay(seconds, function()
		if card.token ~= token then return end
		hide(card)
		refreshMovementLayout()
		if not matchCard.root.Visible then
			local anyMovement = false
			for _, other in movementCards do if other.root.Visible then anyMovement = true break end end
			if not anyMovement then gui.Enabled = false end
		end
	end)
end

Settings.Changed:Connect(function(key: string)
	if key == "showPopups" and Settings.get("showPopups") ~= true then
		for _, card in movementCards do hide(card) end
		lastMovement = nil
		if not matchCard.root.Visible then gui.Enabled = false end
	end
end)

player.CharacterRemoving:Connect(MatchFeedback.clear)

for _, attribute in { "HRushInMatch", "HRushState", "HRushGameMode", "HRushRound" } do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		local state = player:GetAttribute("HRushState")
		if attribute ~= "HRushState" or (state ~= "MS_03" and state ~= "MS_04") then
			MatchFeedback.clear()
		end
	end)
end

local viewportConnection: RBXScriptConnection? = nil
local function watchViewport()
	if viewportConnection then viewportConnection:Disconnect() viewportConnection = nil end
	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if active then
				render(matchCard, active.title, active.subtitle, active.icon, active.accent, false, active.kind == "minor")
				stopTweens(matchCard)
				matchCard.root.Position = matchCard.base
				matchCard.root.GroupTransparency = 0
				matchCard.scale.Scale = 1
			end
			refreshMovementLayout()
		end)
	end
	if active then
		render(matchCard, active.title, active.subtitle, active.icon, active.accent, false, active.kind == "minor")
		matchCard.root.Position = matchCard.base
	end
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
watchViewport()

return MatchFeedback
