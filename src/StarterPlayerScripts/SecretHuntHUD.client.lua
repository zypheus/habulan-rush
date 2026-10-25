--!strict
-- Task/spec: suppress private Hunt HUD during the match showcase, approved 2026-10-25.
-- Task/spec: floating action card icons, approved 2026-10-24.
-- StarterPlayerScripts/SecretHuntHUD.client.lua
-- Owner: Project Owner
-- Responsibility: Private Secret Hunt target card, timed hints, danger, and capture feedback.
-- Task/spec: Lihim na Target full mode, approved 2026-10-23.
-- Task/spec: approved UI/UX redesign, 2026-10-23.
-- Task/spec: clear arcade feedback for private Hunt events, approved 2026-10-24.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local AudioRouter = require(script.Parent:WaitForChild("AudioRouter"))
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local MatchFeedback = require(script.Parent:WaitForChild("MatchFeedback"))
local MatchShowcase = require(script.Parent:WaitForChild("MatchShowcase", 10))
local huntEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SecretHuntEvent") :: RemoteEvent
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("SecretHuntHUD")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "SecretHuntHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
Theme.screen(gui, Theme.Layers.HUD)
gui.Enabled = false
gui.Parent = playerGui

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

local function label(name: string, parent: Instance, size: UDim2, position: UDim2,
	content: string, textSize: number, color: Color3): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Size = size
	item.Position = position
	item.BackgroundTransparency = 1
	item.Text = content
	item.TextSize = textSize
	item.TextColor3 = color
	item.Font = Enum.Font.GothamBold
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.TextTruncate = Enum.TextTruncate.AtEnd
	item.Parent = parent
	return item
end

local navy = Theme.Colors.Navy
local gold = Theme.Colors.Gold
local white = Theme.Colors.Cream
local muted = Theme.Colors.Muted
local red = Theme.Colors.TayaText

local targetCard = frame("TargetCard", gui, UDim2.fromOffset(350, 170), UDim2.fromOffset(24, 92), navy)
Instance.new("UICorner", targetCard).CornerRadius = UDim.new(0, 14)
local cardStroke = Instance.new("UIStroke")
cardStroke.Color = gold
cardStroke.Thickness = 2
cardStroke.Parent = targetCard
local cardScale = Instance.new("UIScale")
cardScale.Parent = targetCard
label("Heading", targetCard, UDim2.fromOffset(322, 28), UDim2.fromOffset(14, 7), "LIHIM NA TARGET", 18, gold)

local portrait = Instance.new("ImageLabel")
portrait.Name = "TargetPortrait"
portrait.Size = UDim2.fromOffset(76, 76)
portrait.Position = UDim2.fromOffset(14, 42)
portrait.BackgroundColor3 = Color3.fromRGB(45, 65, 75)
portrait.BorderSizePixel = 0
portrait.Image = ""
portrait.Parent = targetCard
Instance.new("UICorner", portrait).CornerRadius = UDim.new(0, 10)

local targetName = label("TargetName", targetCard, UDim2.fromOffset(235, 32), UDim2.fromOffset(102, 44),
	"WAITING FOR TARGET", 18, white)
local distanceLabel = label("Distance", targetCard, UDim2.fromOffset(235, 25), UDim2.fromOffset(102, 79),
	"Distance: --", 15, muted)
local directionLabel = label("Direction", targetCard, UDim2.fromOffset(320, 24), UDim2.fromOffset(14, 121),
	"Direction pulse: waiting", 14, gold)
local capturesLabel = label("Captures", targetCard, UDim2.fromOffset(170, 22), UDim2.fromOffset(14, 145),
	"CAPTURES  0", 15, white)
local function setCaptureText(value: number)
	capturesLabel.Text = if Layout.compact() then "CAP " .. tostring(value) else "CAPTURES  " .. tostring(value)
end
local phaseLabel = label("Phase", targetCard, UDim2.fromOffset(163, 22), UDim2.fromOffset(178, 145),
	"SIMULA", 14, muted)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Right

local timer = label("Timer", gui, UDim2.fromOffset(180, 52), UDim2.fromScale(0.5, 0.12),
	"2:00", 34, white)
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.TextXAlignment = Enum.TextXAlignment.Center
timer.Visible = false -- Shared timer is owned by UIController.

local danger = label("Danger", gui, UDim2.fromOffset(350, 34), UDim2.fromScale(0.5, 0.19),
	"A HUNTER IS NEAR", 20, red)
danger.AnchorPoint = Vector2.new(0.5, 0)
danger.TextXAlignment = Enum.TextXAlignment.Center
danger.Visible = false

local flash = frame("CaptureFlash", gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), gold)
flash.BackgroundTransparency = 1
flash.ZIndex = 1

local leaderboard = frame("Leaderboard", gui, UDim2.fromOffset(220, 260), UDim2.new(1, -24, 0, 92), navy)
leaderboard.AnchorPoint = Vector2.new(1, 0)
leaderboard.Visible = false
Instance.new("UICorner", leaderboard).CornerRadius = UDim.new(0, 10)
local boardScale = Instance.new("UIScale")
boardScale.Parent = leaderboard
label("Title", leaderboard, UDim2.fromOffset(198, 28), UDim2.fromOffset(10, 8), "CAPTURE LEADERS", 16, gold)
local boardRows = frame("Rows", leaderboard, UDim2.fromOffset(200, 216), UDim2.fromOffset(10, 38), navy)
boardRows.BackgroundTransparency = 1
local rowLayout = Instance.new("UIListLayout")
rowLayout.Padding = UDim.new(0, 2)
rowLayout.Parent = boardRows

local currentRound = 0
local currentVersion = -1
local targetId: number? = nil
local phase = "Simula"
local pulseUntil = 0
local dangerUntil = 0
local thumbnailToken = 0
local lastSyncAt = 0
local directions = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

local function resize()
	local compact = Layout.compact()
	targetCard.Position = if compact then UDim2.fromOffset(12, 56) else UDim2.fromOffset(24, 92)
	targetCard.Size = UDim2.fromOffset(if compact then 210 else 350, if compact then 100 else 170)
	local heading = targetCard:FindFirstChild("Heading") :: TextLabel
	heading.Size = UDim2.new(1, -20, 0, 24)
	heading.Position = UDim2.fromOffset(10, 6)
	heading.TextSize = if compact then 13 else 18
	portrait.Size = UDim2.fromOffset(if compact then 40 else 76, if compact then 40 else 76)
	portrait.Position = UDim2.fromOffset(if compact then 10 else 14, if compact then 28 else 42)
	targetName.Position = UDim2.fromOffset(if compact then 56 else 102, if compact then 26 else 44)
	targetName.Size = UDim2.fromOffset(if compact then 145 else 235, if compact then 24 else 32)
	targetName.TextSize = if compact then 14 else 18
	distanceLabel.Position = UDim2.fromOffset(if compact then 56 else 102, if compact then 48 else 79)
	distanceLabel.Size = UDim2.fromOffset(if compact then 145 else 235, if compact then 18 else 25)
	distanceLabel.TextSize = if compact then 12 else 15
	directionLabel.Position = UDim2.fromOffset(if compact then 10 else 14, if compact then 74 else 121)
	directionLabel.Size = UDim2.fromOffset(if compact then 126 else 320, if compact then 18 else 24)
	directionLabel.TextSize = if compact then 11 else 14
	capturesLabel.Position = UDim2.fromOffset(if compact then 142 else 14, if compact then 74 else 145)
	capturesLabel.Size = UDim2.fromOffset(if compact then 58 else 170, if compact then 18 else 22)
	capturesLabel.TextSize = if compact then 11 else 15
	setCaptureText(localPlayer:GetAttribute("HRushHuntCaptures") or 0)
	phaseLabel.Visible = not compact
	leaderboard.Position = if compact then UDim2.new(0.5, 80, 0, 80) else UDim2.new(1, -24, 0, 92)
	leaderboard.Size = UDim2.fromOffset(if compact then 160 else 220, if compact then 112 else 260)
	local leaderboardTitle = leaderboard:FindFirstChild("Title") :: TextLabel
	leaderboardTitle.TextSize = if compact then 13 else 16
	leaderboardTitle.Size = UDim2.new(1, -20, 0, 24)
	boardRows.Size = UDim2.new(1, -20, 1, -38)
	for _, row in boardRows:GetChildren() do
		if row:IsA("TextLabel") then
			row.Size = UDim2.new(1, 0, 0, 24)
			row.TextSize = if compact then 11 else 13
			row.Visible = not compact or row.LayoutOrder <= 3
		end
	end
	danger.Position = UDim2.new(0.5, 0, 0, if compact then 200 else 88)
	danger.Size = UDim2.fromOffset(if compact then 200 else 350, if compact then 36 else 40)
	cardScale.Scale = 1
	boardScale.Scale = 1
end

local cameraSizeConnection: RBXScriptConnection? = nil
local function watchCamera()
	if cameraSizeConnection then cameraSizeConnection:Disconnect() end
	local camera = Workspace.CurrentCamera
	if camera then cameraSizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	resize()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

local function inHunt(): boolean
	return localPlayer:GetAttribute("HRushInMatch") == true
		and localPlayer:GetAttribute("HRushGameMode") == "SecretHunt"
end

local function refreshGate()
	local state = localPlayer:GetAttribute("HRushState")
	local visible = inHunt() and (state == "MS_03" or state == "MS_04") and not MatchShowcase.isActive()
	gui.Enabled = visible
	localPlayer:SetAttribute("HRushHuntTargetReady", visible and targetId ~= nil)
	if not visible then
		leaderboard.Visible = false
		danger.Visible = false
	end
	if visible and Workspace:GetServerTimeNow() - lastSyncAt >= Config.SecretHunt.SyncRequestInterval then
		lastSyncAt = Workspace:GetServerTimeNow()
		huntEvent:FireServer("Sync")
	end
end

local function updateTarget()
	thumbnailToken += 1
	local token = thumbnailToken
	portrait.Image = ""
	distanceLabel.Text = "Distance: --"
	directionLabel.Text = if Layout.compact() then "DIRECTION: WAITING" else "Direction pulse: waiting"
	if targetId == nil then
		targetName.Text = "NO TARGET (PRACTICE)"
		return
	end
	local player = Players:GetPlayerByUserId(targetId)
	targetName.Text = if player then player.DisplayName else "TARGET " .. tostring(targetId)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(targetId :: number, Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100)
		end)
		if ok and token == thumbnailToken and targetId ~= nil then portrait.Image = image end
	end)
end

local function updateBoard(entries: { any })
	for _, child in boardRows:GetChildren() do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	for index, entry in ipairs(entries) do
		if index > (if Layout.compact() then 3 else 8) then break end
		if typeof(entry) == "table" and typeof(entry.name) == "string"
			and typeof(entry.captures) == "number" then
			local row = label("Rank" .. tostring(index), boardRows, UDim2.new(1, 0, 0, 24),
				UDim2.fromOffset(0, 0), string.format("%d. %s   %d", index, entry.name, entry.captures),
				if Layout.compact() then 11 else 13, if entry.userId == localPlayer.UserId then gold else white)
			row.LayoutOrder = index
		end
	end
	leaderboard.Visible = gui.Enabled and phase == "HulingHabol"
end

huntEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.type) ~= "string"
		or typeof(payload.round) ~= "number" or typeof(payload.version) ~= "number" then return end
	if not inHunt() then return end
	if payload.round < currentRound or (payload.round == currentRound and payload.version < currentVersion) then return end
	if payload.round > currentRound then
		currentRound = payload.round
		currentVersion = -1
		targetId = nil
		leaderboard.Visible = false
	end
	currentVersion = math.max(currentVersion, payload.version)
	if payload.type == "Assignment" then
		local newTarget = if typeof(payload.targetUserId) == "number" then payload.targetUserId else nil
		local changed = targetId ~= newTarget
		targetId = newTarget
		if typeof(payload.phase) == "string" then phase = payload.phase end
		phaseLabel.Text = string.upper(phase)
		updateTarget()
		refreshGate()
		if changed and targetId ~= nil then
			MatchFeedback.show("BAGONG TARGET", "TINGNAN ANG TARGET CARD", "followup", gold, nil, "hunt")
			AudioRouter.playSfxId(Config.SecretHunt.Sounds.assignment, 0.7)
		end
	elseif payload.type == "Capture" then
		setCaptureText(payload.captures or 0)
		MatchFeedback.show("HULI! +1", "NADAGDAGAN ANG HULI", "major", gold, true, "hunt")
		AudioRouter.playSfxId(Config.SecretHunt.Sounds.capture, 1)
		if VfxScale.cosmetic() > 0 and not Theme.reducedMotion() then
			flash.BackgroundTransparency = 0.82
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
	elseif payload.type == "Caught" then
		MatchFeedback.show("NAHULI KA", "LIGTAS MUNA", "major", red, true, "hunt")
	elseif payload.type == "Hint" then
		if typeof(payload.distance) == "number" then
			distanceLabel.Text = if Layout.compact() then "~" .. tostring(payload.distance) .. " studs"
				else "Distance: about " .. tostring(payload.distance) .. " studs"
		else
			distanceLabel.Text = if Layout.compact() then "Distance: --" else "Distance: unavailable"
		end
		if typeof(payload.sector) == "number" and directions[payload.sector] then
			directionLabel.Text = if Layout.compact() then "DIRECTION: " .. directions[payload.sector]
				else "Direction pulse: " .. directions[payload.sector]
			pulseUntil = Workspace:GetServerTimeNow() + Config.SecretHunt.HintPulseDuration
		end
		local wasDanger = danger.Visible
		dangerUntil = if payload.danger == true then Workspace:GetServerTimeNow() + 2.5 else 0
		danger.Visible = gui.Enabled and dangerUntil > 0
		if danger.Visible and not wasDanger then AudioRouter.playSfxId(Config.SecretHunt.Sounds.danger, 0.7) end
	elseif payload.type == "Phase" then
		if typeof(payload.phase) == "string" then
			phase = payload.phase
			phaseLabel.Text = string.upper(phase)
			if phase == "BarangayRush" then MatchFeedback.show("BARANGAY RUSH", "", "minor", gold, nil, "phase")
			elseif phase == "HulingHabol" then
				MatchFeedback.show("HULING HABOL", "", "minor", red, nil, "phase")
				AudioRouter.playSfxId(Config.SecretHunt.Sounds.final, 0.8)
			end
		end
	elseif payload.type == "Leaderboard" and typeof(payload.entries) == "table" then
		updateBoard(payload.entries)
	elseif payload.type == "Recovered" then
		MatchFeedback.show("BALIK SA HABULAN", "", "minor", gold, nil, "hunt")
	elseif payload.type == "Close" then
		targetId = nil
		localPlayer:SetAttribute("HRushHuntTargetReady", false)
		MatchFeedback.clear()
		gui.Enabled = false
	end
end)

MatchShowcase.Changed:Connect(refreshGate)
for _, attribute in { "HRushInMatch", "HRushState", "HRushGameMode" } do
	localPlayer:GetAttributeChangedSignal(attribute):Connect(function()
		if not inHunt() then
			targetId = nil
			currentRound = 0
			currentVersion = -1
			updateTarget()
		end
		refreshGate()
	end)
end
localPlayer:GetAttributeChangedSignal("HRushHuntCaptures"):Connect(function()
	setCaptureText(localPlayer:GetAttribute("HRushHuntCaptures") or 0)
end)

RunService.Heartbeat:Connect(function()
	if not gui.Enabled then return end
	local now = Workspace:GetServerTimeNow()
	local state = localPlayer:GetAttribute("HRushState")
	local endsAt = ReplicatedStorage:GetAttribute("HRushHuntEndsAt")
	if state == "MS_04" and typeof(endsAt) == "number" then
		local remaining = math.max(0, math.ceil(endsAt - now))
		timer.Text = string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
		timer.TextColor3 = if remaining <= 10 then red else white
	else
		timer.Text = "GET READY"
		timer.TextColor3 = white
	end
	if pulseUntil > 0 and now >= pulseUntil then
		pulseUntil = 0
		directionLabel.Text = if Layout.compact() then "DIRECTION: WAITING" else "Direction pulse: waiting"
	end
	if dangerUntil > 0 and now >= dangerUntil then
		dangerUntil = 0
		danger.Visible = false
	end
end)

refreshGate()
