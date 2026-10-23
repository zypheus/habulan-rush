--!strict
-- StarterPlayerScripts/MomentumHUD.client.lua
-- Owner: Project Owner
-- Responsibility: local momentum meter, action feedback, and sound cues.
-- Task/spec: momentum step 3, 2026-10-19.
-- Task/spec: slide chaining diagnosis, 2026-10-19.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Rules = require(ReplicatedStorage:WaitForChild("MomentumRules"))
local Momentum = require(script.Parent:WaitForChild("MomentumController"))
local Settings = require(script.Parent:WaitForChild("ClientSettings"))
local AudioRouter = require(script.Parent:WaitForChild("AudioRouter"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local fx = Config.Momentum.Fx
local player = Players.LocalPlayer

local function meterBottom(): number
	return if Layout.compact() then Config.UI.Theme.PhoneMomentumBottom else fx.BarBottom
end

local function meterWidth(): number
	return if Layout.compact() then Config.UI.Theme.PhoneMomentumWidth else fx.BarWidth
end

local gui = Instance.new("ScreenGui")
gui.Name = "HRushMomentumHUD"
gui.DisplayOrder = Config.UI.Theme.Layers.HUD
gui.IgnoreGuiInset = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function frame(name: string, parent: Instance, size: UDim2, position: UDim2, color: Color3): Frame
	local item = Instance.new("Frame")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	item.Parent = parent
	return item
end

local function label(name: string, parent: Instance, size: UDim2, position: UDim2, textSize: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextStrokeTransparency = 0.45
	item.TextSize = textSize
	item.Font = Enum.Font.GothamBold
	item.Text = ""
	item.Visible = false
	item.Parent = parent
	return item
end

local bar = frame("Bar", gui, UDim2.fromOffset(meterWidth(), fx.BarHeight),
	UDim2.new(0.5, -meterWidth() / 2, 1, -meterBottom()), Color3.fromRGB(22, 24, 34))
bar.ClipsDescendants = false
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = bar
local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(120, 120, 140)
barStroke.Transparency = 0.45
barStroke.Thickness = 1
barStroke.Parent = bar

local glow = frame("MaxGlow", bar, UDim2.new(1, 10, 1, 10), UDim2.fromOffset(-5, -5), Color3.fromRGB(202, 128, 255))
glow.BackgroundTransparency = 0.78
glow.Visible = false
glow.ZIndex = 0
local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(1, 0)
glowCorner.Parent = glow

local fill = frame("Fill", bar, UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), Color3.fromRGB(255, 255, 255))
fill.ZIndex = 2
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill
local gradient = Instance.new("UIGradient")
gradient.Parent = fill
local flash = frame("TierFlash", bar, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.new(1, 1, 1))
flash.BackgroundTransparency = 1
flash.ZIndex = 3

local chain = label("Chain", gui, UDim2.fromOffset(180, 28),
	UDim2.new(0.5, -90, 1, -meterBottom() - 37), 17)
local chainScale = Instance.new("UIScale")
chainScale.Parent = chain
local lost = label("Lost", gui, UDim2.fromOffset(240, 30),
	UDim2.new(0.5, -120, 1, -meterBottom() - 68), 18)
lost.Text = "MOMENTUM LOST"
lost.TextColor3 = Color3.fromRGB(255, 75, 75)

local cracks: { Frame } = {}
for index = 1, 4 do
	local piece = frame("Crack" .. index, gui, UDim2.fromOffset(0, fx.BarHeight),
		UDim2.new(0.5, 0, 1, -meterBottom()), Color3.fromRGB(255, 60, 60))
	piece.Visible = false
	piece.ZIndex = 13
	table.insert(cracks, piece)
end

local lastCompact: boolean? = nil
local function layoutMeter()
	local compact = Layout.compact()
	if lastCompact == compact then return end
	lastCompact = compact
	local width = meterWidth()
	local bottom = meterBottom()
	bar.Size = UDim2.fromOffset(width, fx.BarHeight)
	bar.Position = UDim2.new(0.5, -width / 2, 1, -bottom)
	chain.Position = UDim2.new(0.5, -90, 1, -bottom - 37)
	lost.Position = UDim2.new(0.5, -120, 1, -bottom - 68)
	for _, piece in cracks do piece.Position = UDim2.new(0.5, 0, 1, -bottom) end
end
layoutMeter()

local popups: { TextLabel } = {}
local popupTweens: { [TextLabel]: Tween } = {}
for index = 1, fx.MaxPopups do
	local item = label("ActionPopup" .. index, gui, UDim2.fromOffset(260, 34), UDim2.fromOffset(0, 0), 18)
	item.ZIndex = 14
	table.insert(popups, item)
end

local popupCursor = 0
local lastPopup: TextLabel? = nil
local lastPopupAt = -math.huge
local popupWords = ""
local popupGain = 0
local lastActionAt = -math.huge
local chainCount = 0
local shownTier = 0
local confirmedTier = 0
local shownFraction = 0
local lostGeneration = 0

local function isTaya(): boolean
	return player:GetAttribute("HRushRole") == "Taya" and Config.Momentum.TayaBuildsMomentum
end

local function colorForTier(tier: number): Color3
	if isTaya() then
		return ({ Color3.fromRGB(160, 110, 110), Color3.fromRGB(255, 180, 180),
			Color3.fromRGB(255, 95, 95), Color3.fromRGB(255, 50, 90) })[tier + 1]
	end
	return ({ Color3.fromRGB(135, 140, 155), Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 150, 55), Color3.fromRGB(202, 128, 255) })[tier + 1]
end

local function playAsset(key: string, pitch: number)
	if Settings.get("momentumSounds") ~= true then return end
	local id = (Config.MomentumAssets :: any)[key]
	if typeof(id) ~= "string" or id == "" or string.match(id, "^%d+$") == nil then return end
	AudioRouter.playSfxId("rbxassetid://" .. id, fx.SoundVolume, nil, pitch)
end

local function popupPosition(): UDim2
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if root and root:IsA("BasePart") and camera then
		local point, visible = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 3.2, 0))
		if visible then return UDim2.fromOffset(point.X - 130, point.Y - 17) end
	end
	return UDim2.new(0.5, -130, 0.55, 0)
end

local function showPopup(action: string, gain: number, count: number, perfect: boolean, tier: number)
	if Config.Momentum.Debug and action == "Slide" then
		print(string.format("[Momentum] slide popup requested: gain=%.2f", gain))
	end
	if Settings.get("showPopups") ~= true then return end
	local now = Workspace:GetServerTimeNow()
	local word = if perfect then "PERFECT ROLL" else string.upper(action)
	local merging = lastPopup ~= nil and lastPopup.Visible and now - lastPopupAt <= fx.PopupMergeWindow
	local item: TextLabel
	if merging then
		item = lastPopup :: TextLabel
		popupWords ..= " + " .. word
		popupGain += gain
	else
		popupCursor = popupCursor % #popups + 1
		item = popups[popupCursor]
		popupWords = word
		popupGain = gain
	end
	if popupTweens[item] then popupTweens[item]:Cancel() end
	item.Text = if popupGain <= 0 then "MAX" else popupWords .. " +" .. string.format("%g", popupGain)
	item.TextColor3 = if count > 1 and gain > 0 then Color3.fromRGB(160, 160, 170) else colorForTier(tier)
	item.TextSize = if perfect then 22 else 18
	item.TextTransparency = 0
	item.TextStrokeTransparency = 0.45
	item.Position = popupPosition()
	item.Visible = true
	if Config.Momentum.Debug and action == "Slide" then
		print(string.format("[Momentum] slide popup shown: %s", item.Text))
	end
	local start = item.Position
	local rollPopup = string.find(popupWords, "ROLL", 1, true) ~= nil
	local fadeDelay = if rollPopup then math.max(0, fx.RollPopupTime - fx.PopupTime) else 0
	local tween = TweenService:Create(item, TweenInfo.new(fx.PopupTime, Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out, 0, false, fadeDelay), {
		Position = UDim2.new(start.X.Scale, start.X.Offset, start.Y.Scale, start.Y.Offset - fx.PopupRisePx),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	popupTweens[item] = tween
	tween.Completed:Connect(function()
		if popupTweens[item] == tween then item.Visible = false end
	end)
	tween:Play()
	lastPopup = item
	lastPopupAt = now
end

local function crackBar()
	if Settings.get("momentumBar") ~= true then return end
	flash.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	flash.BackgroundTransparency = 0
	TweenService:Create(flash, TweenInfo.new(fx.CrackTime), { BackgroundTransparency = 1 }):Play()
	for index, piece in cracks do
		local width = meterWidth() * shownFraction / #cracks
		piece.Size = UDim2.fromOffset(width, fx.BarHeight)
		piece.Position = UDim2.new(0.5, -meterWidth() / 2 + (index - 1) * width, 1, -meterBottom())
		piece.Rotation = 0
		piece.BackgroundTransparency = 0
		piece.Visible = width > 0
		local direction = if index <= 2 then -1 else 1
		local tween = TweenService:Create(piece, TweenInfo.new(fx.CrackTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = piece.Position + UDim2.fromOffset(direction * 16, 32),
			Rotation = direction * (index + 4),
			BackgroundTransparency = 1,
		})
		tween.Completed:Connect(function() piece.Visible = false end)
		tween:Play()
	end
end

local function showLost()
	chainCount = 0
	chain.Visible = false
	crackBar()
	if Settings.get("showPopups") ~= true then return end
	lostGeneration += 1
	local generation = lostGeneration
	lost.TextTransparency = 0
	lost.TextStrokeTransparency = 0.45
	lost.Visible = true
	TweenService:Create(lost, TweenInfo.new(fx.LostTime), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
	task.delay(fx.LostTime, function()
		if generation == lostGeneration then lost.Visible = false end
	end)
end

Momentum.Changed:Connect(function(value: number, reason: string, action: string?, gain: number?, payload: any?)
	if reason == "lost" then
		showLost()
		confirmedTier = 0
		return
	end
	if reason ~= "confirmed" or action == nil or typeof(gain) ~= "number" then
		if reason == "reconcile" then confirmedTier = Rules.tier(value) end
		return
	end
	local now = Workspace:GetServerTimeNow()
	chainCount = Rules.nextChainCount(chainCount, lastActionAt, now)
	lastActionAt = now
	if Config.Momentum.Debug then
		print(string.format("[Momentum] chain count changed: %d after %s", chainCount, action))
	end
	local tier = Rules.tier(value)
	local perfect = payload ~= nil and payload.perfect == true
	showPopup(action, gain, if payload and typeof(payload.count) == "number" then payload.count else 1, perfect, tier)
	if chainCount >= 2 and Settings.get("momentumBar") == true then
		chain.Text = "x" .. chainCount .. " CHAIN"
		chain.TextColor3 = colorForTier(tier)
		chain.Visible = true
		chainScale.Scale = 1.25
		TweenService:Create(chainScale, TweenInfo.new(fx.ChainPopTime, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	if gain > 0 then
		playAsset("Sfx_GainTick", math.min(fx.GainPitchCap, 1 + (chainCount - 1) * fx.GainPitchStep))
	end
	if tier > confirmedTier then playAsset("Sfx_TierUp", 1 + (tier - 1) * fx.TierPitchStep) end
	if perfect then playAsset("Sfx_PerfectRoll", 1) end
	confirmedTier = tier
end)

RunService.RenderStepped:Connect(function()
	layoutMeter()
	local live = player:GetAttribute("HRushState") == "MS_04"
	bar.Visible = live and Settings.get("momentumBar") == true
	chain.Visible = chain.Visible and bar.Visible and Workspace:GetServerTimeNow() - lastActionAt <= Config.Momentum.ChainWindow
	if not live then return end
	local value = Momentum.value()
	local tier = Rules.tier(value)
	shownFraction = value / Config.Momentum.Cap
	fill.Size = UDim2.fromScale(shownFraction, 1)
	fill.BackgroundColor3 = colorForTier(tier)
	gradient.Color = if tier == 3 and not isTaya()
		then ColorSequence.new(Color3.fromRGB(176, 90, 255), Color3.fromRGB(255, 218, 90))
		else ColorSequence.new(fill.BackgroundColor3, fill.BackgroundColor3)
	glow.Visible = tier == 3 and bar.Visible
	glow.BackgroundColor3 = colorForTier(tier)
	if tier ~= shownTier then
		shownTier = tier
		flash.BackgroundColor3 = colorForTier(tier)
		flash.BackgroundTransparency = 0.55
		TweenService:Create(flash, TweenInfo.new(fx.TierFlashTime), { BackgroundTransparency = 1 }):Play()
	end
end)
