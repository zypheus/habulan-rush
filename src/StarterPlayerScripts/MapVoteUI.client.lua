--!strict
-- StarterPlayerScripts/MapVoteUI.client.lua
-- Owner: Project Owner
-- Responsibility: Server-offered Classic map ballot on desktop, phone, and gamepad.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MapVoteEvent") :: RemoteEvent
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("MapVoteUI")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "MapVoteUI"
gui.ResetOnSpawn = false
gui.Enabled = false
Theme.screen(gui, Theme.Layers.Modal)
gui.Parent = playerGui
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Theme.Colors.Navy
backdrop.BorderSizePixel = 0
backdrop.Parent = gui
local board = Instance.new("Frame")
board.Name = "Ballot"
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.5)
Theme.surface(board, true, Theme.Colors.Gold)
board.Parent = backdrop
local function makeText(parent: Instance, name: string, value: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = value
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	Theme.text(label, size, name == "Title")
	label.Parent = parent
	return label
end
local title = makeText(board, "Title", "VOTE FOR MAP", 32)
local timer = makeText(board, "Timer", "", 18)
timer.TextColor3 = Theme.Colors.Gold
local progress = makeText(board, "Progress", "", 17)
local result = makeText(board, "Result", "", 20)
result.TextColor3 = Theme.Colors.Gold
local dots = makeText(board, "Position", "", 15)
dots.TextColor3 = Theme.Colors.Muted
local previous = Instance.new("TextButton")
previous.Name = "Previous"
previous.Text = "<"
Theme.text(previous, 24)
Theme.surface(previous, false)
Theme.focus(previous)
previous.Parent = board
local nextButton = previous:Clone()
nextButton.Name = "Next"
nextButton.Text = ">"
nextButton.Parent = board
Theme.focus(nextButton)

local order: { string } = {}
local cards: { [string]: TextButton } = {}
local descriptions: { [string]: string } = {}
local counts: { [string]: number } = {}
local selected: string? = nil
local winner: string? = nil
local viewed = 1
local endsAt = 0
local participantCount = 0
local open = false
local previousFocus: GuiObject? = nil

local function displayName(key: string): string
	if key == "Kalsada" then return "BARANGAY KALSADA" end
	if key == "Binaha" then return "BINAHA NA BARYO" end
	return string.upper(key)
end

local function arrange()
	local compact = Layout.compact()
	local viewport = Layout.viewport()
	board.Size = if compact then UDim2.new(1, -24, 1, -24) else UDim2.fromOffset(math.min(960, viewport.X - 48), math.min(600, viewport.Y - 48))
	local width, height = board.AbsoluteSize.X, board.AbsoluteSize.Y
	if width < 1 or height < 1 then return end
	title.Position = UDim2.fromOffset(12, if compact then 8 else 20)
	title.Size = UDim2.new(1, -24, 0, if compact then 36 else 50)
	title.TextSize = if compact then 25 else 32
	timer.Position = UDim2.fromOffset(12, if compact then 45 else 74)
	timer.Size = UDim2.new(1, -24, 0, 26)
	progress.Position = UDim2.new(0, 12, 1, if compact then -92 else -100)
	progress.Size = UDim2.new(1, -24, 0, 24)
	result.Position = UDim2.new(0, 12, 1, -44)
	result.Size = UDim2.new(1, -24, 0, 30)
	dots.Visible = compact
	dots.Position = UDim2.new(0, 12, 1, -68)
	dots.Size = UDim2.new(1, -24, 0, 22)
	previous.Visible = compact and #order > 1
	nextButton.Visible = previous.Visible
	previous.Size = UDim2.fromOffset(64, 64)
	nextButton.Size = UDim2.fromOffset(64, 64)
	previous.Position = UDim2.new(0, 8, 0.5, -20)
	nextButton.Position = UDim2.new(1, -72, 0.5, -20)
	local top = if compact then 78 else 122
	local cardHeight = math.max(120, height - top - (if compact then 180 else 240))
	local gap = 16
	local cardWidth = if compact then math.max(160, width - 160) else (width - 64 - gap * (#order - 1)) / math.max(1, #order)
	for index, key in order do
		local card = cards[key]
		card.NextSelectionLeft = if compact then previous else cards[order[index - 1]]
		card.NextSelectionRight = if compact then nextButton else cards[order[index + 1]]
		card.Visible = not compact or index == viewed
		card.Position = if compact then UDim2.new(0.5, -cardWidth / 2, 0, top) else UDim2.fromOffset(32 + (index - 1) * (cardWidth + gap), top)
		card.Size = UDim2.fromOffset(cardWidth, cardHeight)
		card.TextSize = if compact then 18 else 22
		local info = card:FindFirstChild("Info") :: TextLabel?
		if info then info.TextSize = if compact then 16 else 21 end
	end
	dots.Text = string.format("%d / %d", viewed, #order)
	previous.NextSelectionRight = cards[order[viewed]]
	nextButton.NextSelectionLeft = cards[order[viewed]]
end

local function refresh()
	local total = 0
	for _, count in counts do total += count end
	progress.Text = string.format("VOTED %d / %d", total, participantCount)
	for key, card in cards do
		local count = counts[key] or 0
		local info = card:FindFirstChild("Info") :: TextLabel?
		if info then info.Text = string.format("%s\n%s\n%d VOTE%s%s", displayName(key), descriptions[key] or "", count,
			if count == 1 then "" else "S", if selected == key then "  [VOTED]" else "")
		end
		card.BackgroundColor3 = if selected == key then Theme.Colors.Navy else Theme.Colors.Raised
		local stroke = card:FindFirstChild("CardStroke") :: UIStroke?
		if stroke then
			stroke.Color = if key == winner then Theme.Colors.Teal else if selected == key then Theme.Colors.Cream else Theme.Colors.Gold
			stroke.Thickness = if key == winner or selected == key then 3 else 2
		end
		card.Active = open
	end
end

local function close()
	open = false
	gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = if Layout.focusAvailable(previousFocus) then previousFocus else nil
	end
	previousFocus = nil
end
local function step(delta: number)
	if #order == 0 then return end
	viewed = ((viewed - 1 + delta) % #order) + 1
	arrange()
	GuiService.SelectedObject = cards[order[viewed]]
end
previous.Activated:Connect(function() step(-1) end)
nextButton.Activated:Connect(function() step(1) end)

local function start(payload: { [string]: any })
	close()
	for _, card in cards do card:Destroy() end
	table.clear(order)
	table.clear(cards)
	table.clear(counts)
	table.clear(descriptions)
	selected = nil
	winner = nil
	viewed = 1
	result.Text = ""
	participantCount = 0
	if typeof(payload.participants) == "table" then for _ in payload.participants do participantCount += 1 end end
	endsAt = if typeof(payload.endsAt) == "number" then payload.endsAt else Workspace:GetServerTimeNow() + 10
	local pool = payload.pool
	if typeof(pool) ~= "table" then return end
	for _, key in pool do
		if typeof(key) == "string" then
			local card = Instance.new("TextButton")
			card.Name = "Map_" .. key
			card.Text = ""
			card.BorderSizePixel = 0
			card.TextWrapped = true
			Theme.text(card, 22, true)
			Theme.surface(card, false, Theme.Colors.Gold)
			local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Name = "CardStroke"
			stroke.Thickness = 2
			stroke.Transparency = 0
			Theme.focus(card)
			card.Parent = board
			local preview = Instance.new("Frame")
			preview.Name = "Preview"
			preview.Size = UDim2.new(1, -24, 0.28, 0)
			preview.Position = UDim2.fromOffset(12, 12)
			preview.BackgroundColor3 = if key == "Kalsada" then Theme.Colors.Teal else Theme.Colors.Runner
			preview.BorderSizePixel = 0
			preview.Parent = card
			local road = Instance.new("Frame")
			road.Name = "Street"
			road.AnchorPoint = Vector2.new(0.5, 0.5)
			road.Position = UDim2.fromScale(0.5, 0.5)
			road.Size = UDim2.new(0.72, 0, 0, 14)
			road.BackgroundColor3 = Theme.Colors.Navy
			road.BorderSizePixel = 0
			road.Parent = preview
			local stripe = Instance.new("Frame")
			stripe.Size = UDim2.new(1, 0, 0, 2)
			stripe.Position = UDim2.new(0, 0, 0.5, -1)
			stripe.BackgroundColor3 = Theme.Colors.Cream
			stripe.BorderSizePixel = 0
			stripe.Parent = road
			local infoText = makeText(card, "Info", "", 21)
			infoText.Position = UDim2.new(0, 12, 0.31, 4)
			infoText.Size = UDim2.new(1, -24, 0.67, -12)
			card.Activated:Connect(function()
				if open and Workspace:GetServerTimeNow() < endsAt then event:FireServer("Vote", key) end
			end)
			cards[key] = card
			counts[key] = 0
			local info = if typeof(payload.info) == "table" then payload.info[key] else nil
			descriptions[key] = if typeof(info) == "table" and typeof(info.tagline) == "string" then info.tagline else "Play this map"
			table.insert(order, key)
		end
	end
	if #order == 0 then return end
	previousFocus = GuiService.SelectedObject
	open = true
	gui.Enabled = true
	refresh()
	task.defer(arrange)
	GuiService.SelectedObject = cards[order[1]]
end

event.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then return end
	if payload.type == "Start" then start(payload)
	elseif payload.type == "Update" and gui.Enabled then
		if typeof(payload.votes) == "table" then
			for key in cards do
				local count = payload.votes[key]
				if typeof(count) == "number" then counts[key] = count end
			end
		end
		if tostring(payload.voterId) == tostring(player.UserId) and typeof(payload.map) == "string" then selected = payload.map end
		refresh()
	elseif payload.type == "Winner" and gui.Enabled then
		open = false
		winner = if typeof(payload.winner) == "string" then payload.winner else nil
		result.Text = if winner then "WINNER: " .. displayName(winner) else "MAP SELECTED"
		refresh()
	elseif payload.type == "Close" then close() end
end)
player:GetAttributeChangedSignal("HRushState"):Connect(function()
	if player:GetAttribute("HRushState") ~= "MS_VOTE" then close() end
end)
board:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrange)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(arrange)
if Workspace.CurrentCamera then Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(arrange) end

task.spawn(function()
	while true do
		if gui.Enabled and open then timer.Text = string.format("VOTING ENDS IN %d", math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow()))) end
		task.wait(0.1)
	end
end)
