--!strict
-- StarterPlayerScripts/RpsUI.client.lua
-- Owner: Project Owner
-- Responsibility: Local MS_RPS cards, sign input, timer, and reveal presentation.
-- Task/spec: MS_RPS first Taya selection, GDD 3.2 / System Spec 2.1.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stageStart = remotes:WaitForChild("RpsStageStart") :: RemoteEvent
local revealEvent = remotes:WaitForChild("RpsReveal") :: RemoteEvent
local resultEvent = remotes:WaitForChild("RpsResult") :: RemoteEvent
local submitSign = remotes:WaitForChild("RpsSubmitSign") :: RemoteEvent
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local timing = Config.Match.Rps
local studio = RunService:IsStudio()
local connections: { RBXScriptConnection } = {}

local function track(connection: RBXScriptConnection)
	table.insert(connections, connection)
end

local function duration(key: string): number
	if studio and timing.Studio[key] then return timing.Studio[key] end
	return timing[key]
end

local navy = Theme.Colors.Navy
local slate = Theme.Colors.Raised
local white = Theme.Colors.Cream
local lime = Theme.Colors.Gold
local red = Theme.Colors.TayaText

local function frame(name: string, parent: Instance, size: UDim2, position: UDim2, color: Color3): Frame
	local obj = Instance.new("Frame")
	obj.Name = name
	obj.Size = size
	obj.Position = position
	obj.BackgroundColor3 = color
	obj.BorderSizePixel = 0
	obj.Parent = parent
	return obj
end

local function label(name: string, parent: Instance, text: string, size: UDim2, position: UDim2, textSize: number): TextLabel
	local obj = Instance.new("TextLabel")
	obj.Name = name
	obj.Size = size
	obj.Position = position
	obj.BackgroundTransparency = 1
	obj.Text = text
	obj.TextColor3 = white
	obj.TextScaled = false
	obj.TextSize = textSize
	obj.TextWrapped = true
	obj.Font = Enum.Font.GothamBold
	obj.Parent = parent
	return obj
end

local old = playerGui:FindFirstChild("RpsUI")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "RpsUI"
gui.ResetOnSpawn = false
Theme.screen(gui, Theme.Layers.Modal)
gui.Enabled = false
gui.Parent = playerGui
local background = frame("Background", gui, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), navy)
local board = frame("Board", background, UDim2.fromOffset(960, 560), UDim2.fromScale(0.5, 0.05), navy)
board.AnchorPoint = Vector2.new(0.5, 0)
board.BackgroundTransparency = 1
local scale = Instance.new("UIScale")
scale.Parent = board
local function resize()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(960, 560)
	if Layout.compact() then
		board.AnchorPoint = Vector2.new(0.5, 0.5)
		board.Position = UDim2.fromScale(0.5, 0.48)
		board.Size = UDim2.new(1, -24, 1, -120)
		scale.Scale = 1
	else
		board.AnchorPoint = Vector2.new(0.5, 0)
		board.Position = UDim2.fromScale(0.5, 0.05)
		board.Size = UDim2.fromOffset(960, 560)
		scale.Scale = math.clamp(math.min(viewport.X / 980, viewport.Y / 600), 0.85, 1.25)
	end
end
resize()
local viewportConnection: RBXScriptConnection? = nil
local function watchViewport()
	if viewportConnection then viewportConnection:Disconnect() end
	local camera = workspace.CurrentCamera
	if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	resize()
end
track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport))
watchViewport()

local title = label("Title", board, "BATO BATO PICK", UDim2.fromOffset(960, 72), UDim2.fromOffset(0, 12), 48)
title.TextColor3 = lime
local subTitle = label("Subtitle", board, "", UDim2.fromOffset(960, 34), UDim2.fromOffset(0, 86), 23)
local activeRow = frame("ActiveRow", board, UDim2.fromOffset(944, 150), UDim2.fromOffset(8, 140), navy)
activeRow.BackgroundTransparency = 1
local activeLayout = Instance.new("UIListLayout")
activeLayout.FillDirection = Enum.FillDirection.Horizontal
activeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
activeLayout.Padding = UDim.new(0, 8)
activeLayout.Parent = activeRow
local safeTitle = label("SafeTitle", board, "SAFE", UDim2.fromOffset(960, 28), UDim2.fromOffset(0, 302), 20)
safeTitle.TextColor3 = lime
local safeRow = frame("SafeRow", board, UDim2.fromOffset(944, 105), UDim2.fromOffset(8, 335), navy)
safeRow.BackgroundTransparency = 1
local safeLayout = Instance.new("UIListLayout")
safeLayout.FillDirection = Enum.FillDirection.Horizontal
safeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
safeLayout.Padding = UDim.new(0, 8)
safeLayout.Parent = safeRow

local buttons: { [string]: TextButton } = {}
local signs = { "Rock", "Paper", "Scissors" }
local prompts = { "1 / X / LEFT", "2 / Y / UP", "3 / B / RIGHT" }
local controls = frame("Controls", background, UDim2.new(1, -24, 0, 76), UDim2.new(0.5, 0, 1, -20), navy)
controls.AnchorPoint = Vector2.new(0.5, 1)
controls.BackgroundTransparency = 1
local controlsLimit = Instance.new("UISizeConstraint")
controlsLimit.MaxSize = Vector2.new(900, 76)
controlsLimit.Parent = controls
for index, sign in ipairs(signs) do
	local button = Instance.new("TextButton")
	button.Name = sign
	button.Size = UDim2.new(1 / 3, -8, 1, 0)
	button.Position = UDim2.new((index - 1) / 3, 4, 0, 0)
	button.BackgroundColor3 = slate
	button.BorderSizePixel = 0
	button.Text = string.upper(sign) .. "\n" .. prompts[index]
	button.TextColor3 = white
	button.TextSize = 19
	button.TextWrapped = true
	button.Font = Enum.Font.GothamBold
	button.Parent = controls
	Theme.focus(button)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	buttons[sign] = button
end
local safeMessage = label("SafeMessage", controls, "YOU'RE SAFE", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 32)
safeMessage.TextColor3 = lime
safeMessage.Visible = false
local timerBack = frame("TimerBack", background, UDim2.new(1, -24, 0, 10), UDim2.new(0.5, 0, 1, -110), slate)
timerBack.AnchorPoint = Vector2.new(0.5, 1)
local timerLimit = Instance.new("UISizeConstraint")
timerLimit.MaxSize = Vector2.new(900, 10)
timerLimit.Parent = timerBack
local timerFill = frame("TimerFill", timerBack, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), lime)

type Card = { root: Frame, sign: TextLabel, tag: TextLabel, flip: UIScale, stroke: UIStroke, isSafe: boolean }
local cards: { [number]: Card } = {}
local currentPool: { [number]: boolean } = {}
local selected: string? = nil
local confirmed = false
local opensAt = 0
local deadline = 0
local stageNumber = 0
local phaseToken = 0
local timerConnection: RBXScriptConnection? = nil
local inputBound = false
local revealed = false
local resultShown = false
local previousFocus: GuiObject? = nil

local function stopTimer()
	if timerConnection then timerConnection:Disconnect(); timerConnection = nil end
end

local function unbindInput()
	if inputBound then
		ContextActionService:UnbindAction("HRUSH_RpsPick")
		inputBound = false
	end
end

local function close()
	phaseToken += 1
	stopTimer()
	unbindInput()
	for _, card in pairs(cards) do card.root:Destroy() end
	cards = {}
	currentPool = {}
	selected = nil
	confirmed = false
	gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = if Layout.focusAvailable(previousFocus) then previousFocus else nil
	end
	previousFocus = nil
end

local function playSound(soundId: string)
	if soundId == "" then return end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.7
	sound.Parent = gui
	sound:Play()
	Debris:AddItem(sound, 5)
end

local function setButtons(visible: boolean)
	for _, button in pairs(buttons) do button.Visible = visible end
	safeMessage.Visible = not visible
	if not visible and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(controls) then
		GuiService.SelectedObject = nil
	end
end

local function putCard(userId: number, name: string, inSafeRow: boolean, dimmed: boolean): Card
	local root = frame(tostring(userId), if inSafeRow then safeRow else activeRow, UDim2.fromOffset(108, if inSafeRow then 94 else 132), UDim2.fromOffset(0, 0), if inSafeRow then Color3.fromRGB(43, 93, 68) else slate)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = root
	local flip = Instance.new("UIScale")
	flip.Parent = root
	local outline = Instance.new("UIStroke")
	outline.Color = lime
	outline.Thickness = 2
	outline.Transparency = if inSafeRow and not dimmed then 0 else 1
	outline.Parent = root
	local signLabel = label("Sign", root, "?", UDim2.new(1, 0, 0, 55), UDim2.fromOffset(0, 8), 34)
	local nameLabel = label("Name", root, name, UDim2.new(1, -8, 0, 40), UDim2.fromOffset(4, 58), 15)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local tag = label("Tag", root, if inSafeRow then "SAFE" else "", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 1, -22), 15)
	tag.TextColor3 = lime
	if dimmed then
		root.BackgroundColor3 = Color3.fromRGB(35, 48, 56)
		signLabel.Text = "SAFE"
		signLabel.TextSize = 21
		tag.Text = "SAFE"
		tag.TextColor3 = Color3.fromRGB(137, 158, 166)
	end
	return { root = root, sign = signLabel, tag = tag, flip = flip, stroke = outline, isSafe = inSafeRow }
end

local function clearCards()
	for _, card in pairs(cards) do card.root:Destroy() end
	cards = {}
end

local phoneGrid = Instance.new("UIGridLayout")
phoneGrid.CellPadding = UDim2.fromOffset(4, 4)
phoneGrid.CellSize = UDim2.new(0.25, -6, 0, 68)
phoneGrid.FillDirectionMaxCells = 4
phoneGrid.SortOrder = Enum.SortOrder.LayoutOrder
local function layoutCards()
	local compact = Layout.compact()
	if compact then
		activeLayout.Parent = nil
		phoneGrid.Parent = activeRow
		title.Position = UDim2.fromOffset(0, 4)
		title.Size = UDim2.new(1, 0, 0, 36)
		title.TextSize = 28
		subTitle.Position = UDim2.fromOffset(0, 40)
		subTitle.Size = UDim2.new(1, 0, 0, 28)
		subTitle.TextSize = 17
		activeRow.Position = UDim2.fromOffset(8, 70)
		activeRow.Size = UDim2.new(1, -16, 0, 144)
		safeTitle.Visible = false
		safeRow.Visible = false
	else
		phoneGrid.Parent = nil
		activeLayout.Parent = activeRow
		title.Position = UDim2.fromOffset(0, 12)
		title.Size = UDim2.fromOffset(960, 72)
		title.TextSize = 48
		subTitle.Position = UDim2.fromOffset(0, 86)
		subTitle.Size = UDim2.fromOffset(960, 34)
		subTitle.TextSize = 23
		activeRow.Position = UDim2.fromOffset(8, 140)
		activeRow.Size = UDim2.fromOffset(944, 150)
		safeTitle.Visible = #safeRow:GetChildren() > 1
		safeRow.Visible = true
	end
	for _, card in cards do
		card.root.Parent = if compact then activeRow else if card.isSafe then safeRow else activeRow
		card.root.Size = if compact then UDim2.new(0.25, -6, 0, 68) else UDim2.fromOffset(108, if card.isSafe then 94 else 132)
		local name = card.root:FindFirstChild("Name") :: TextLabel?
		if name then
			name.Position = if compact then UDim2.fromOffset(4, 30) else UDim2.fromOffset(4, 58)
			name.Size = if compact then UDim2.new(1, -8, 0, 20) else UDim2.new(1, -8, 0, 40)
			name.TextSize = if compact then 12 else 15
		end
		card.sign.Position = UDim2.fromOffset(0, if compact then 2 else 8)
		card.sign.Size = UDim2.new(1, 0, 0, if compact then 28 else 55)
		card.sign.TextSize = if compact then 22 else 34
		card.tag.Position = UDim2.new(0, 0, 1, if compact then -17 else -22)
		card.tag.TextSize = if compact then 10 else 15
	end
end
track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(layoutCards))
if workspace.CurrentCamera then track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutCards)) end

local function choose(sign: string)
	if not gui.Enabled or revealed or selected or not currentPool[player.UserId] then return end
	local now = workspace:GetServerTimeNow()
	if now < opensAt or now > deadline then return end
	selected = sign
	submitSign:FireServer(sign)
	local own = cards[player.UserId]
	if own then
		own.sign.Text = string.upper(sign)
		own.sign.TextSize = 20
		own.tag.Text = "PICKING"
	end
	for _, button in pairs(buttons) do button.BackgroundColor3 = Color3.fromRGB(39, 54, 64) end
	buttons[sign].BackgroundColor3 = lime
	buttons[sign].TextColor3 = navy
end

for sign, button in pairs(buttons) do
	track(button.Activated:Connect(function() choose(sign) end))
end

local keyToSign: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.One] = "Rock", [Enum.KeyCode.Two] = "Paper", [Enum.KeyCode.Three] = "Scissors",
	[Enum.KeyCode.DPadLeft] = "Rock", [Enum.KeyCode.DPadUp] = "Paper", [Enum.KeyCode.DPadRight] = "Scissors",
	[Enum.KeyCode.ButtonX] = "Rock", [Enum.KeyCode.ButtonY] = "Paper", [Enum.KeyCode.ButtonB] = "Scissors",
}
local function onInput(_name: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		local sign = keyToSign[input.KeyCode]
		if sign then choose(sign) end
	end
	return Enum.ContextActionResult.Sink
end

local function bindInput()
	unbindInput()
	ContextActionService:BindActionAtPriority("HRUSH_RpsPick", onInput, false, 3000,
		Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
		Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadRight,
		Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonB)
	inputBound = true
end

track(stageStart.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if typeof(payload.lockedUserId) == "number" then
		if not revealed and payload.lockedUserId == player.UserId then
			confirmed = true
			local own = cards[player.UserId]
			if own and selected then
				own.sign.Text = string.upper(selected)
				own.tag.Text = "LOCKED"
			end
		elseif not revealed then
			local card = cards[payload.lockedUserId]
			if card then card.tag.Text = "LOCKED" end
		end
		return
	end
	if typeof(payload.stage) ~= "number" then return end
	phaseToken += 1
	local token = phaseToken
	stopTimer()
	selected = nil
	confirmed = false
	revealed = false
	resultShown = false
	stageNumber = payload.stage
	opensAt = payload.opensAt
	deadline = payload.deadline
	clearCards()
	currentPool = {}
	local used: { [number]: boolean } = {}
	local safe: { [number]: boolean } = {}
	for _, id in ipairs(payload.pool) do currentPool[id] = true end
	for _, id in ipairs(payload.used) do used[id] = true end
	for _, id in ipairs(payload.safe) do safe[id] = true end
	for index, entry in ipairs(payload.roster) do
		cards[entry.userId] = putCard(entry.userId, entry.name, used[entry.userId] or safe[entry.userId] or false, used[entry.userId] == true)
		cards[entry.userId].root.LayoutOrder = index
	end
	layoutCards()
	gui.Enabled = true
	previousFocus = GuiService.SelectedObject
	GuiService.SelectedObject = if currentPool[player.UserId] then buttons.Rock else nil
	safeTitle.Visible = not Layout.compact() and (next(used) ~= nil or next(safe) ~= nil)
	setButtons(currentPool[player.UserId] == true)
	for _, button in pairs(buttons) do
		button.BackgroundColor3 = slate
		button.TextColor3 = white
	end
	bindInput()
	timerBack.Visible = true
	timerConnection = RunService.RenderStepped:Connect(function()
		if phaseToken ~= token then return end
		local now = workspace:GetServerTimeNow()
		local picking = now >= opensAt
		title.Text = if picking then string.format("STAGE %d", stageNumber) else "BATO BATO PICK"
		subTitle.Text = if picking then "Pick your sign. All signs reveal together." else "Get ready to pick your sign."
		local fraction = if picking then math.clamp((deadline - now) / duration("PickTime"), 0, 1) else 1
		timerFill.Size = UDim2.fromScale(fraction, 1)
		if now > deadline and selected and not confirmed then
			local own = cards[player.UserId]
			if own then own.sign.Text = "?"; own.tag.Text = "AUTO PICK" end
		end
		for _, button in pairs(buttons) do button.Active = picking and now <= deadline and selected == nil end
	end)
end))

track(revealEvent.OnClientEvent:Connect(function(payload)
	if not gui.Enabled or resultShown or typeof(payload) ~= "table" or payload.stage ~= stageNumber then return end
	phaseToken += 1
	local token = phaseToken
	stopTimer()
	unbindInput()
	revealed = true
	timerBack.Visible = false
	setButtons(false)
	safeMessage.Visible = false
	title.Text = string.format("STAGE %d", payload.stage)
	subTitle.Text = "REVEAL!"
	local flipTime = if Theme.reducedMotion() then 0 else 0.09
	for _, entry in ipairs(payload.signs) do
		local card = cards[entry.userId]
		if card and flipTime > 0 then TweenService:Create(card.flip, TweenInfo.new(flipTime), { Scale = 0.05 }):Play() end
	end
	task.delay(flipTime, function()
		if phaseToken ~= token then return end
		for _, entry in ipairs(payload.signs) do
			local card = cards[entry.userId]
			if card then
				card.sign.Text = string.upper(entry.sign)
				card.sign.TextSize = 20
				card.tag.Text = ""
				if flipTime > 0 then TweenService:Create(card.flip, TweenInfo.new(flipTime), { Scale = 1 }):Play() end
			end
		end
		playSound(timing.RevealSoundId)
	end)
	task.delay(duration("RevealTime"), function()
		if phaseToken ~= token then return end
		if payload.tie then
			title.Text = "TIE, AGAIN!"
			subTitle.Text = "Everyone stays in. Pick again."
		else
			title.Text = string.format("STAGE %d", payload.stage)
			subTitle.Text = "Winning signs are safe!"
			for _, id in ipairs(payload.safe) do
				local card = cards[id]
				if card then
					card.isSafe = true
					card.root.Parent = safeRow
					card.root.Size = UDim2.fromOffset(108, 94)
					card.root.BackgroundColor3 = Color3.fromRGB(43, 93, 68)
					card.tag.Text = "SAFE"
					card.stroke.Color = lime
					card.stroke.Transparency = 0
				end
			end
			safeTitle.Visible = true
			layoutCards()
		end
	end)
end))

track(resultEvent.OnClientEvent:Connect(function(payload)
	if not gui.Enabled or typeof(payload) ~= "table" then return end
	resultShown = true
	phaseToken += 1
	stopTimer()
	unbindInput()
	timerBack.Visible = false
	setButtons(false)
	safeMessage.Visible = false
	title.Text = if payload.sudden then "SUDDEN PICK" else "STARTING TAYA"
	subTitle.Text = if payload.userId == player.UserId then "YOU'RE TAYA!" else "RUN!"
	for id, card in pairs(cards) do
		if id == payload.userId then
			card.root.BackgroundColor3 = red
			card.root.Size = UDim2.fromOffset(122, 150)
			card.tag.Text = "TAYA"
			card.tag.TextColor3 = white
			card.stroke.Color = red
			card.stroke.Thickness = 3
			card.stroke.Transparency = 0
		else
			card.root.BackgroundColor3 = Color3.fromRGB(35, 48, 56)
		end
	end
	playSound(timing.ResultSoundId)
end))

track(player:GetAttributeChangedSignal("HRushState"):Connect(function()
	local state = player:GetAttribute("HRushState")
	if gui.Enabled and (state == "MS_01" or state == "MS_03" or state == "MS_04" or state == "MS_06") then close() end
end))

local disposed = false
local function dispose(destroyGui: boolean)
	if disposed then return end
	disposed = true
	close()
	if viewportConnection then viewportConnection:Disconnect(); viewportConnection = nil end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	if destroyGui then gui:Destroy() end
end

track(Players.PlayerRemoving:Connect(function(leaver)
	if leaver == player then
		dispose(true)
		return
	end
	local card = cards[leaver.UserId]
	if card then card.root:Destroy(); cards[leaver.UserId] = nil end
	currentPool[leaver.UserId] = nil
end))
gui.Destroying:Connect(function() dispose(false) end)
script.Destroying:Connect(function() dispose(true) end)
