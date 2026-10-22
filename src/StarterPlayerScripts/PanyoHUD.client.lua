--!strict
-- StarterPlayerScripts/PanyoHUD.client.lua
-- Owner: Project Owner
-- Responsibility: Local Panyo timer, leaderboard, carrier marker, and event feedback.
-- Task/spec: Agawan ng Panyo presentation, approved 2026-10-23.
-- Task/spec: persistent Carrier highlight and trail, approved 2026-10-23.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local AudioRouter = require(script.Parent:WaitForChild("AudioRouter"))
local CameraDirector = require(script.Parent:WaitForChild("CameraDirector"))
local ClientSettings = require(script.Parent:WaitForChild("ClientSettings"))
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))
local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PanyoEvent") :: RemoteEvent
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local visuals = Config.Panyo.Visuals
local gold = visuals.Color
local cyan = Color3.fromRGB(135, 238, 243)
local white = Color3.fromRGB(250, 248, 239)
local navy = Color3.fromRGB(19, 30, 43)

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
gui.DisplayOrder = 8
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "PanyoStatus"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.fromScale(0.5, 0.045)
panel.Size = UDim2.fromOffset(400, 94)
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
timer.TextXAlignment = Enum.TextXAlignment.Right
timer.TextColor3 = gold
local carrierLabel = label(panel, "Carrier", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 34), 15)
local personal = label(panel, "PersonalScore", UDim2.new(1, -24, 0, 22), UDim2.fromOffset(12, 62), 13)
personal.TextColor3 = cyan

local board = Instance.new("Frame")
board.Name = "PossessionBoard"
board.AnchorPoint = Vector2.new(1, 0)
board.Position = UDim2.new(1, -18, 0, 118)
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

local notice = label(gui, "Notice", UDim2.new(0.9, 0, 0, 50), UDim2.fromScale(0.5, 0.2), 23)
notice.AnchorPoint = Vector2.new(0.5, 0.5)
notice.TextXAlignment = Enum.TextXAlignment.Center
notice.TextColor3 = gold
notice.TextScaled = true
notice.TextWrapped = true
notice.Visible = false
local noticeSize = Instance.new("UITextSizeConstraint")
noticeSize.MinTextSize = 14
noticeSize.MaxTextSize = 23
noticeSize.Parent = notice
local noticeSerial = 0
local marker: BillboardGui? = nil
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
	if marker then marker:Destroy() marker = nil end
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

local function showNotice(message: string, duration: number)
	noticeSerial += 1
	local serial = noticeSerial
	notice.Text = message
	notice.TextTransparency = 0
	notice.Visible = isVisible()
	if ClientSettings.get("vfx") ~= 0 then
		TweenService:Create(notice, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	end
	task.delay(duration, function()
		if noticeSerial == serial then notice.Visible = false end
	end)
end

local function syncMarker(carrier: Player?)
	if marker then marker:Destroy() marker = nil end
	if carrier == nil or carrier == localPlayer or not isVisible() then return end
	local head = carrier.Character and carrier.Character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then return end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HRUSH_PanyoCarrierMarker"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(140, 40)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Parent = playerGui
	local text = label(billboard, "CarrierText", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 16)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextColor3 = gold
	text.Text = "PANYO CARRIER"
	marker = billboard
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
		row.Visible = player ~= nil
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
	local viewport = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	scale.Scale = math.clamp(viewport.X / 900, 0.7, 1)
	boardScale.Scale = math.clamp(viewport.X / 720, 0.65, 1)
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
	personal.Text = string.format("YOU: %.1fs hold | %d points | %d steals", time, points, localPlayer:GetAttribute("HRushPanyoSteals") or 0)
	updateBoard()
	local adornee = marker and marker.Adornee
	local desired = carrier and carrier.Character and carrier.Character:FindFirstChild("Head")
	if (marker ~= nil and adornee ~= desired) or (marker == nil and carrier ~= nil and carrier ~= localPlayer) then
		syncMarker(carrier)
	end
	syncCarrierFx(carrier)
end

event.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.type) ~= "string" or not isVisible() then return end
	local eventType = payload.type
	if eventType == "Pickup" or eventType == "Steal" then
		local carrier = if typeof(payload.toUserId) == "number" then Players:GetPlayerByUserId(payload.toUserId) else nil
		showNotice((carrier and carrier.DisplayName or "Someone") .. (if eventType == "Steal" then " STOLE THE PANYO!" else " GRABBED THE PANYO!"), 1.5)
		AudioRouter.playSfxId(if eventType == "Steal" then Config.Panyo.Sounds.steal else Config.Panyo.Sounds.pickup, 0.7)
	elseif eventType == "Drop" then
		showNotice("PANYO DROPPED!", 1.5)
		AudioRouter.playSfxId(Config.Panyo.Sounds.drop, 0.7)
	elseif eventType == "Phase" then
		if payload.phase == "HulingHabol" then showNotice("HULING HABOL!", 2) end
	elseif eventType == "Reveal" then
		revealCarrierId = if typeof(payload.carrierUserId) == "number" then payload.carrierUserId else nil
		revealUntil = os.clock() + Config.Panyo.RevealDuration
		local carrier = if revealCarrierId then Players:GetPlayerByUserId(revealCarrierId) else nil
		showNotice(if carrier then "PANYO: " .. carrier.DisplayName else "PANYO IS ON THE GROUND", 1.5)
		AudioRouter.playSfxId(Config.Panyo.Sounds.reveal, 0.7)
	elseif eventType == "FinalCue" then
		showNotice(tostring(payload.remaining or "") .. " SECONDS!", 0.9)
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
