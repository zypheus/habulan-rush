--!strict
-- StarterPlayerScripts/SecretHuntHUD.client.lua
-- Owner: Project Owner
-- Responsibility: Private Secret Hunt target card, timed hints, danger, and capture feedback.
-- Task/spec: Lihim na Target full mode, approved 2026-10-23.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local AudioRouter = require(script.Parent:WaitForChild("AudioRouter"))
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))
local huntEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SecretHuntEvent") :: RemoteEvent
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("SecretHuntHUD")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "SecretHuntHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 35
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

local navy = Color3.fromRGB(22, 39, 54)
local gold = Color3.fromRGB(255, 221, 116)
local white = Color3.fromRGB(247, 249, 250)
local muted = Color3.fromRGB(181, 199, 208)
local red = Color3.fromRGB(255, 110, 94)

local targetCard = frame("TargetCard", gui, UDim2.fromOffset(350, 170), UDim2.fromScale(0.02, 0.16), navy)
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
local phaseLabel = label("Phase", targetCard, UDim2.fromOffset(163, 22), UDim2.fromOffset(178, 145),
	"SIMULA", 14, muted)
phaseLabel.TextXAlignment = Enum.TextXAlignment.Right

local timer = label("Timer", gui, UDim2.fromOffset(180, 52), UDim2.fromScale(0.5, 0.12),
	"2:00", 34, white)
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.TextXAlignment = Enum.TextXAlignment.Center

local danger = label("Danger", gui, UDim2.fromOffset(350, 34), UDim2.fromScale(0.5, 0.19),
	"A HUNTER IS NEAR", 20, red)
danger.AnchorPoint = Vector2.new(0.5, 0)
danger.TextXAlignment = Enum.TextXAlignment.Center
danger.Visible = false

local notice = label("Notice", gui, UDim2.fromOffset(460, 56), UDim2.fromScale(0.5, 0.31),
	"", 30, gold)
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.TextXAlignment = Enum.TextXAlignment.Center
notice.Visible = false

local flash = frame("CaptureFlash", gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), gold)
flash.BackgroundTransparency = 1
flash.ZIndex = 1

local leaderboard = frame("Leaderboard", gui, UDim2.fromOffset(220, 260), UDim2.fromScale(0.98, 0.18), navy)
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
local noticeUntil = 0
local noticeToken = 0
local thumbnailToken = 0
local lastSyncAt = 0
local directions = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

local function resize()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local scale = math.clamp(math.min(viewport.X / 1050, viewport.Y / 700), 0.58, 1)
	cardScale.Scale = scale
	boardScale.Scale = scale
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
	local visible = inHunt() and (state == "MS_03" or state == "MS_04")
	gui.Enabled = visible
	localPlayer:SetAttribute("HRushHuntTargetReady", visible and targetId ~= nil)
	if not visible then
		leaderboard.Visible = false
		danger.Visible = false
		notice.Visible = false
	end
	if visible and Workspace:GetServerTimeNow() - lastSyncAt >= Config.SecretHunt.SyncRequestInterval then
		lastSyncAt = Workspace:GetServerTimeNow()
		huntEvent:FireServer("Sync")
	end
end

local function setNotice(content: string, color: Color3, seconds: number)
	noticeToken += 1
	local token = noticeToken
	notice.Text = content
	notice.TextColor3 = color
	notice.TextTransparency = 0
	notice.Visible = gui.Enabled
	noticeUntil = Workspace:GetServerTimeNow() + seconds
	if VfxScale.cosmetic() > 0 then
		notice.Position = UDim2.fromScale(0.5, 0.32)
		TweenService:Create(notice, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.29) }):Play()
	end
	task.delay(seconds, function()
		if token ~= noticeToken then return end
		TweenService:Create(notice, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
		task.delay(0.26, function()
			if token == noticeToken then notice.Visible = false end
		end)
	end)
end

local function updateTarget()
	thumbnailToken += 1
	local token = thumbnailToken
	portrait.Image = ""
	distanceLabel.Text = "Distance: --"
	directionLabel.Text = "Direction pulse: waiting"
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
		if index > 8 then break end
		if typeof(entry) == "table" and typeof(entry.name) == "string"
			and typeof(entry.captures) == "number" then
			local row = label("Rank" .. tostring(index), boardRows, UDim2.fromOffset(198, 24),
				UDim2.fromOffset(0, 0), string.format("%d. %s   %d", index, entry.name, entry.captures),
				13, if entry.userId == localPlayer.UserId then gold else white)
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
			setNotice("NEW TARGET", gold, 2)
			AudioRouter.playSfxId(Config.SecretHunt.Sounds.assignment, 0.7)
		end
	elseif payload.type == "Capture" then
		capturesLabel.Text = "CAPTURES  " .. tostring(payload.captures or 0)
		setNotice("CAPTURE +1", gold, 2)
		AudioRouter.playSfxId(Config.SecretHunt.Sounds.capture, 1)
		if VfxScale.cosmetic() > 0 then
			flash.BackgroundTransparency = 0.82
			TweenService:Create(flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
	elseif payload.type == "Caught" then
		setNotice("CAUGHT - PROTECTED", red, 2)
	elseif payload.type == "Hint" then
		if typeof(payload.distance) == "number" then
			distanceLabel.Text = "Distance: about " .. tostring(payload.distance) .. " studs"
		else
			distanceLabel.Text = "Distance: unavailable"
		end
		if typeof(payload.sector) == "number" and directions[payload.sector] then
			directionLabel.Text = "Direction pulse: " .. directions[payload.sector]
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
			if phase == "BarangayRush" then setNotice("BARANGAY RUSH", gold, 2)
			elseif phase == "HulingHabol" then
				setNotice("HULING HABOL", red, 2)
				AudioRouter.playSfxId(Config.SecretHunt.Sounds.final, 0.8)
			end
		end
	elseif payload.type == "Leaderboard" and typeof(payload.entries) == "table" then
		updateBoard(payload.entries)
	elseif payload.type == "Recovered" then
		setNotice("BACK IN THE HUNT", gold, 1.5)
	elseif payload.type == "Close" then
		targetId = nil
		localPlayer:SetAttribute("HRushHuntTargetReady", false)
		gui.Enabled = false
	end
end)

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
	capturesLabel.Text = "CAPTURES  " .. tostring(localPlayer:GetAttribute("HRushHuntCaptures") or 0)
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
		directionLabel.Text = "Direction pulse: waiting"
	end
	if dangerUntil > 0 and now >= dangerUntil then
		dangerUntil = 0
		danger.Visible = false
	end
	if noticeUntil > 0 and now >= noticeUntil + 0.3 then notice.Visible = false end
end)

refreshGate()
