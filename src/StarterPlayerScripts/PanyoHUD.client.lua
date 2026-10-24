--!strict
-- Task/spec: floating action card icons, approved 2026-10-24.
-- StarterPlayerScripts/PanyoHUD.client.lua
-- Owner: Project Owner
-- Responsibility: Local Panyo timer, leaderboard, carrier marker, and event feedback.
-- Task/spec: Agawan ng Panyo presentation, approved 2026-10-23.
-- Task/spec: persistent Carrier highlight and trail, approved 2026-10-23.
-- Task/spec: approved UI/UX redesign, 2026-10-23.
-- Task/spec: clear arcade feedback for confirmed Panyo changes, approved 2026-10-24.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local AudioRouter = require(script.Parent:WaitForChild("AudioRouter"))
local CameraDirector = require(script.Parent:WaitForChild("CameraDirector"))
local ClientSettings = require(script.Parent:WaitForChild("ClientSettings"))
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local MatchFeedback = require(script.Parent:WaitForChild("MatchFeedback"))
local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PanyoEvent") :: RemoteEvent
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local visuals = Config.Panyo.Visuals
local gold = visuals.Color
local cyan = Theme.Colors.Teal
local white = Theme.Colors.Cream
local navy = Theme.Colors.Navy

for _, name in { "HRUSH_PanyoHUD", "HRUSH_PanyoCarrierMarker" } do
	local old = playerGui:FindFirstChild(name)
	if old then old:Destroy() end
end

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.GothamBold
	item.TextSize = textSize
	item.TextColor3 = white
	item.TextStrokeTransparency = 0.65
	item.Text = ""
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = parent
	return item
end

local gui = Instance.new("ScreenGui")
gui.Name = "HRUSH_PanyoHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Enabled = false
Theme.screen(gui, Theme.Layers.HUD)
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "PanyoStatus"
panel.AnchorPoint = Vector2.new(0, 0)
panel.Position = UDim2.fromOffset(24, 92)
panel.Size = UDim2.fromOffset(300, 96)
panel.BackgroundColor3 = navy
panel.BackgroundTransparency = 0.12
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 13)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = gold
panelStroke.Thickness = 2
panelStroke.Parent = panel
local scale = Instance.new("UIScale")
scale.Parent = panel

local title = label(panel, "Phase", UDim2.new(0.65, -12, 0, 25), UDim2.fromOffset(12, 5), 16)
title.TextColor3 = gold
local timer = label(panel, "Timer", UDim2.new(0.3, -6, 0, 30), UDim2.new(0.7, 0, 0, 3), 24)
timer.Visible = false -- Shared timer is owned by UIController.
timer.TextXAlignment = Enum.TextXAlignment.Right
timer.TextColor3 = gold
local carrierLabel = label(panel, "Carrier", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 34), 15)
carrierLabel.TextTruncate = Enum.TextTruncate.AtEnd
local personal = label(panel, "PersonalScore", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 62), 13)
personal.TextColor3 = cyan
personal.TextTruncate = Enum.TextTruncate.AtEnd

local board = Instance.new("Frame")
board.Name = "PossessionBoard"
board.AnchorPoint = Vector2.new(1, 0)
board.Position = UDim2.new(1, -24, 0, 92)
board.Size = UDim2.fromOffset(224, 239)
board.BackgroundColor3 = navy
board.BackgroundTransparency = 0.18
board.Parent = gui
local boardCorner = Instance.new("UICorner")
boardCorner.CornerRadius = UDim.new(0, 10)
boardCorner.Parent = board
local boardScale = Instance.new("UIScale")
boardScale.Parent = board
local boardTitle = label(board, "BoardTitle", UDim2.new(1, -12, 0, 25), UDim2.fromOffset(8, 4), 13)
boardTitle.Text = "PANYO HOLD TIME"
boardTitle.TextColor3 = gold
local boardRows: { TextLabel } = {}
for index = 1, 8 do
	local row = label(board, "Row" .. index, UDim2.new(1, -16, 0, 24), UDim2.fromOffset(8, 28 + (index - 1) * 25), 12)
	row.TextTruncate = Enum.TextTruncate.AtEnd
	row.Visible = false
	boardRows[index] = row
end

local carrierCharacter: Model? = nil
local carrierRoot: BasePart? = nil
local carrierHighlight: Highlight? = nil
local carrierTrail: Trail? = nil
local trailLeft: Attachment? = nil
local trailRight: Attachment? = nil
local trailIntensity = -1
local revealUntil = 0
local revealCarrierId: number? = nil

local function clearCarrierFx()
	if carrierHighlight then carrierHighlight:Destroy() carrierHighlight = nil end
	if trailLeft then trailLeft:Destroy() trailLeft = nil end
	if trailRight then trailRight:Destroy() trailRight = nil end
	carrierTrail = nil
	carrierCharacter = nil
	carrierRoot = nil
	trailIntensity = -1
end

local function clearWorldFeedback()
	clearCarrierFx()
	revealUntil = 0
	revealCarrierId = nil
end

local function isVisible(): boolean
	local state = localPlayer:GetAttribute("HRushState")
	return localPlayer:GetAttribute("HRushInMatch") == true
		and localPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo"
		and (state == "MS_03" or state == "MS_04")
end

local function syncCarrierFx(carrier: Player?)
	local character = carrier and carrier.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character == nil or character.Parent == nil or root == nil or not root:IsA("BasePart")
		or (carrier == localPlayer and CameraDirector.getViewMode() == "FirstPerson") then
		clearCarrierFx()
		return
	end
	if carrierCharacter ~= character or carrierRoot ~= root or carrierHighlight == nil
		or carrierHighlight.Parent == nil or carrierTrail == nil or carrierTrail.Parent == nil then
		clearCarrierFx()
		local highlight = Instance.new("Highlight")
		highlight.Name = "HRUSH_PanyoCarrierHighlight"
		highlight.Adornee = character
		highlight.FillColor = visuals.Color
		highlight.OutlineColor = visuals.Color
		highlight.OutlineTransparency = 0
		highlight.Parent = character
		carrierHighlight = highlight

		local left = Instance.new("Attachment")
		left.Name = "HRUSH_PanyoTrailLeft"
		left.Position = visuals.TrailLeftOffset
		left.Parent = root
		local right = Instance.new("Attachment")
		right.Name = "HRUSH_PanyoTrailRight"
		right.Position = visuals.TrailRightOffset
		right.Parent = root
		local trail = Instance.new("Trail")
		trail.Name = "HRUSH_PanyoCarrierTrail"
		trail.Attachment0 = left
		trail.Attachment1 = right
		trail.FaceCamera = true
		trail.Lifetime = visuals.TrailLifetime
		trail.MinLength = 0.05
		trail.LightEmission = visuals.TrailLightEmission
		trail.Color = ColorSequence.new(visuals.Color, visuals.TrailEndColor)
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		trail.Enabled = false
		trail.Parent = left
		carrierCharacter = character
		carrierRoot = root
		carrierTrail = trail
		trailLeft = left
		trailRight = right
	end
	local pulse = carrier ~= nil and carrier.UserId == revealCarrierId and os.clock() < revealUntil
	local highlight = carrierHighlight :: Highlight
	highlight.DepthMode = if pulse then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
	local fill = if pulse then visuals.RevealFillTransparency else visuals.IdleFillTransparency
	highlight.FillTransparency = math.min(0.75, 1 - (1 - fill) * VfxScale.telegraph())
	local intensity = VfxScale.cosmetic()
	local trail = carrierTrail :: Trail
	trail.Enabled = intensity > 0
	if intensity ~= trailIntensity then
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - (1 - visuals.TrailBirthTransparency) * intensity),
			NumberSequenceKeypoint.new(1, 1),
		})
		trailIntensity = intensity
	end
end

local function updateBoard()
	local ranked = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("HRushInMatch") == true and player:GetAttribute("HRushGameMode") == "AgawanNgPanyo" then
			table.insert(ranked, player)
		end
	end
	table.sort(ranked, function(a, b)
		local aTime = a:GetAttribute("HRushPanyoTime") or 0
		local bTime = b:GetAttribute("HRushPanyoTime") or 0
		if aTime ~= bTime then return aTime > bTime end
		return a.UserId < b.UserId
	end)
	local carrierId = ReplicatedStorage:GetAttribute("HRushPanyoCarrierUserId")
	for index, row in boardRows do
		local player = ranked[index]
		row.Visible = player ~= nil and (not Layout.compact() or index <= 3)
		if player then
			local time = player:GetAttribute("HRushPanyoTime") or 0
			row.Text = string.format("%d  %s  %.1fs", index, player.DisplayName, time)
			row.TextColor3 = if player.UserId == carrierId then gold else if player == localPlayer then cyan else white
		end
	end
end

local function refresh()
	gui.Enabled = isVisible()
	if not gui.Enabled then
		clearWorldFeedback()
		return
	end
	local compact = Layout.compact()
	panel.Position = if compact then UDim2.fromOffset(12, 56) else UDim2.fromOffset(24, 92)
	panel.Size = UDim2.fromOffset(if compact then 200 else 300, if compact then 84 else 96)
	scale.Scale = 1
	board.Position = if compact then UDim2.new(0.5, 80, 0, 80) else UDim2.new(1, -24, 0, 92)
	board.Size = UDim2.fromOffset(if compact then 160 else 224, if compact then 112 else 239)
	boardScale.Scale = 1
	title.TextSize = if compact then 13 else 16
	carrierLabel.TextSize = if compact then 12 else 15
	personal.TextSize = if compact then 11 else 13
	boardTitle.TextSize = if compact then 12 else 13
	for index, row in boardRows do
		row.TextSize = if compact then 11 else 12
		row.Position = UDim2.fromOffset(8, if compact then 28 + (index - 1) * 24 else 28 + (index - 1) * 25)
	end
	local state = localPlayer:GetAttribute("HRushState")
	local phase = ReplicatedStorage:GetAttribute("HRushPanyoPhase")
	title.Text = if state == "MS_03" then "AGAWAN NG PANYO"
		else if phase == "BarangayRush" then "BARANGAY RUSH"
		else if phase == "HulingHabol" then "HULING HABOL"
		else "SIMULA"
	local endsAt = ReplicatedStorage:GetAttribute("HRushPanyoEndsAt")
	timer.Text = if state == "MS_04" and typeof(endsAt) == "number"
		then string.format("%d", math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))) else "READY"
	local carrierId = ReplicatedStorage:GetAttribute("HRushPanyoCarrierUserId")
	local carrier = if typeof(carrierId) == "number" then Players:GetPlayerByUserId(carrierId) else nil
	carrierLabel.Text = if carrier then "CARRIER: " .. carrier.DisplayName else "PANYO ON THE GROUND"
	local time = localPlayer:GetAttribute("HRushPanyoTime") or 0
	local points = localPlayer:GetAttribute("HRushPanyoPoints") or 0
	personal.Text = if compact then string.format("YOU: %.1fs | %d pts | %d steals", time, points, localPlayer:GetAttribute("HRushPanyoSteals") or 0)
		else string.format("YOU: %.1fs hold | %d points | %d steals", time, points, localPlayer:GetAttribute("HRushPanyoSteals") or 0)
	updateBoard()
	syncCarrierFx(carrier)
end

event.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.type) ~= "string" or not isVisible() then return end
	local eventType = payload.type
	if eventType == "Pickup" or eventType == "Steal" then
		local carrier = if typeof(payload.toUserId) == "number" then Players:GetPlayerByUserId(payload.toUserId) else nil
		if payload.toUserId == localPlayer.UserId then
			MatchFeedback.show("HAWAK MO ANG PANYO", "HAWAKAN PARA UMISKOR", "major", gold, true, "panyo")
		elseif eventType == "Steal" and payload.fromUserId == localPlayer.UserId then
			MatchFeedback.show("NAGAW ANG PANYO!", "HABULIN ANG MAY HAWAK", "major", Theme.Colors.TayaText, true, "panyo")
		else
			MatchFeedback.show((carrier and carrier.DisplayName or "IBA") .. (if eventType == "Steal" then " NANGAGAW NG PANYO" else " KUMUHA NG PANYO"), "", "minor", gold, nil, "panyo")
		end
		if payload.toUserId == localPlayer.UserId or payload.fromUserId == localPlayer.UserId then
			AudioRouter.playSfxId(if eventType == "Steal" then Config.Panyo.Sounds.steal else Config.Panyo.Sounds.pickup, 0.7)
		end
	elseif eventType == "Drop" then
		if payload.fromUserId == localPlayer.UserId then
			MatchFeedback.show("NAHULOG ANG PANYO", "KUNIN ITO MULI", "major", gold, nil, "panyo")
		else
			MatchFeedback.show("NAHULOG ANG PANYO", "", "minor", gold, nil, "panyo")
		end
		AudioRouter.playSfxId(Config.Panyo.Sounds.drop, 0.7)
	elseif eventType == "Phase" then
		if payload.phase == "HulingHabol" then MatchFeedback.show("HULING HABOL!", "", "followup", gold, nil, "phase") end
	elseif eventType == "Reveal" then
		revealCarrierId = if typeof(payload.carrierUserId) == "number" then payload.carrierUserId else nil
		revealUntil = os.clock() + Config.Panyo.RevealDuration
		local carrier = if revealCarrierId then Players:GetPlayerByUserId(revealCarrierId) else nil
		MatchFeedback.show(if carrier then "PANYO: " .. carrier.DisplayName else "NASA LUPA ANG PANYO", "", "minor", gold, nil, "panyo")
		AudioRouter.playSfxId(Config.Panyo.Sounds.reveal, 0.7)
	elseif eventType == "FinalCue" then
		MatchFeedback.show(tostring(payload.remaining or "") .. " SEGUNDO!", "", "followup", gold, nil, "phase")
		AudioRouter.playSfxId(Config.Panyo.Sounds.final, 0.7)
	end
	refresh()
end)

for _, attribute in { "HRushInMatch", "HRushGameMode", "HRushState", "HRushPanyoTime", "HRushPanyoPoints", "HRushPanyoSteals" } do
	localPlayer:GetAttributeChangedSignal(attribute):Connect(refresh)
end
for _, attribute in { "HRushPanyoCarrierUserId", "HRushPanyoPhase", "HRushPanyoEndsAt" } do
	ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(refresh)
end
ClientSettings.Changed:Connect(function(key)
	if key == "vfx" or key == "cameraViewMode" then refresh() end
end)
task.spawn(function()
	while gui.Parent do
		refresh()
		task.wait(0.25)
	end
end)
