--!strict
-- StarterPlayerScripts/ModeVoteUI.client.lua
-- Owner: Project Owner
-- Responsibility: Server-owned mode ballot with desktop cards and phone carousel.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ModeVoteEvent") :: RemoteEvent
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("ModeVoteUI")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "ModeVoteUI"
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
local function label(name: string, value: string, size: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.BackgroundTransparency = 1
	item.Text = value
	item.TextXAlignment = Enum.TextXAlignment.Center
	Theme.text(item, size, name == "Title")
	item.Parent = board
	return item
end
local title = label("Title", "CHOOSE THE GAME MODE", 32)
local timer = label("Timer", "", 18)
timer.TextColor3 = Theme.Colors.Gold
local result = label("Result", "", 20)
result.TextColor3 = Theme.Colors.Gold
local dots = label("Position", "", 16)
dots.TextColor3 = Theme.Colors.Muted
local previous = Instance.new("TextButton")
previous.Name = "Previous"
previous.Text = "<"
previous.BackgroundColor3 = Theme.Colors.Navy
Theme.text(previous, 24)
Theme.surface(previous, false)
Theme.focus(previous)
previous.Parent = board
local nextButton = previous:Clone()
nextButton.Name = "Next"
nextButton.Text = ">"
nextButton.Parent = board
Theme.focus(nextButton)

local buttons: { [string]: TextButton } = {}
local names: { [string]: string } = {}
local counts: { [string]: number } = {}
local order: { string } = {}
local viewed = 1
local selected: string? = nil
local winnerId: string? = nil
local endsAt = 0
local open = false
local previousFocus: GuiObject? = nil

local function accent(id: string): Color3
	if id == "ClassicTag" then return Theme.Colors.TayaText end
	if id == "AgawanNgPanyo" then return Theme.Colors.Gold end
	return Theme.Colors.Teal
end

local function arrange()
	local compact = Layout.compact()
	local size = Layout.viewport()
	board.Size = if compact then UDim2.new(1, -24, 1, -24) else UDim2.fromOffset(math.min(960, size.X - 48), math.min(600, size.Y - 48))
	local width = board.AbsoluteSize.X
	local height = board.AbsoluteSize.Y
	if width < 1 or height < 1 then return end
	title.Position = UDim2.fromOffset(12, if compact then 8 else 20)
	title.Size = UDim2.new(1, -24, 0, if compact then 36 else 50)
	title.TextSize = if compact then 24 else 32
	timer.Position = UDim2.fromOffset(12, if compact then 44 else 74)
	timer.Size = UDim2.new(1, -24, 0, 28)
	result.Position = UDim2.new(0, 12, 1, if compact then -46 else -66)
	result.Size = UDim2.new(1, -24, 0, 35)
	dots.Visible = compact
	dots.Position = UDim2.new(0, 12, 1, -75)
	dots.Size = UDim2.new(1, -24, 0, 22)
	previous.Visible = compact and #order > 1
	nextButton.Visible = previous.Visible
	previous.Size = UDim2.fromOffset(64, 64)
	nextButton.Size = UDim2.fromOffset(64, 64)
	previous.Position = UDim2.new(0, 8, 0.5, -20)
	nextButton.Position = UDim2.new(1, -72, 0.5, -20)
	local top = if compact then 82 else 126
	local cardHeight = math.max(120, height - top - (if compact then 168 else 210))
	local gap = 16
	local cardWidth = if compact then math.max(160, width - 160) else (width - 64 - gap * math.max(0, #order - 1)) / math.max(1, #order)
	for index, id in order do
		local button = buttons[id]
		button.NextSelectionLeft = if compact then previous else buttons[order[index - 1]]
		button.NextSelectionRight = if compact then nextButton else buttons[order[index + 1]]
		button.Visible = not compact or index == viewed
		button.Position = if compact then UDim2.new(0.5, -cardWidth / 2, 0, top) else UDim2.fromOffset(32 + (index - 1) * (cardWidth + gap), top)
		button.Size = UDim2.fromOffset(cardWidth, cardHeight)
		button.TextSize = if compact then 20 else 24
	end
	dots.Text = string.format("%d / %d", viewed, #order)
	previous.NextSelectionRight = buttons[order[viewed]]
	nextButton.NextSelectionLeft = buttons[order[viewed]]
end

local function refresh()
	for id, button in buttons do
		local voted = selected == id
		button.BackgroundColor3 = if voted then Theme.Colors.Navy else Theme.Colors.Raised
		button.Text = string.format("%s\n\n%s\n\n%d VOTE%s%s", string.upper(names[id]),
			if id == "ClassicTag" then "Lowest Taya time wins" else if id == "AgawanNgPanyo" then "Hold and steal the panyo" else "Capture your secret target",
			counts[id] or 0, if (counts[id] or 0) == 1 then "" else "S", if voted then "  [VOTED]" else "")
		local stroke = button:FindFirstChild("CardStroke") :: UIStroke?
		if stroke then
			stroke.Color = if winnerId == id then Theme.Colors.Teal else if voted then Theme.Colors.Cream else accent(id)
			stroke.Thickness = if winnerId == id or voted then 3 else 2
		end
		button.Active = open
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
	GuiService.SelectedObject = buttons[order[viewed]]
end
previous.Activated:Connect(function() step(-1) end)
nextButton.Activated:Connect(function() step(1) end)

local function start(payload: { [string]: any })
	close()
	for _, button in buttons do button:Destroy() end
	table.clear(buttons)
	table.clear(names)
	table.clear(counts)
	table.clear(order)
	selected = nil
	winnerId = nil
	viewed = 1
	result.Text = ""
	endsAt = if typeof(payload.endsAt) == "number" then payload.endsAt else Workspace:GetServerTimeNow()
	if typeof(payload.modes) ~= "table" then return end
	for _, mode in payload.modes do
		if typeof(mode) == "table" and typeof(mode.id) == "string" and typeof(mode.name) == "string" then
			local id = mode.id
			local button = Instance.new("TextButton")
			button.Name = id
			button.BorderSizePixel = 0
			button.TextWrapped = true
			button.Selectable = true
			button.Parent = board
			Theme.text(button, 24, true)
			Theme.surface(button, false, accent(id))
			local stroke = button:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Name = "CardStroke"
			stroke.Thickness = 2
			stroke.Transparency = 0
			Theme.focus(button)
			button.Activated:Connect(function()
				if open and Workspace:GetServerTimeNow() < endsAt then event:FireServer("Vote", id) end
			end)
			buttons[id] = button
			names[id] = mode.name
			counts[id] = 0
			table.insert(order, id)
		end
	end
	if #order == 0 then return end
	previousFocus = GuiService.SelectedObject
	open = true
	gui.Enabled = true
	refresh()
	task.defer(arrange)
	GuiService.SelectedObject = buttons[order[1]]
end

event.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then return end
	if payload.type == "Start" then start(payload)
	elseif payload.type == "Update" and gui.Enabled then
		if typeof(payload.voterId) == "number" and payload.voterId == player.UserId and typeof(payload.mode) == "string" then selected = payload.mode end
		if typeof(payload.votes) == "table" then
			for id in buttons do
				local count = payload.votes[id]
				if typeof(count) == "number" then counts[id] = count end
			end
		end
		refresh()
	elseif payload.type == "Winner" and gui.Enabled then
		open = false
		timer.Text = "MODE CHOSEN"
		local winner = payload.winner
		if typeof(winner) == "string" then
			winnerId = winner
			result.Text = "SELECTED: " .. string.upper(names[winner] or winner)
		end
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
		if gui.Enabled and open then
			local votes = 0
			for _, count in counts do votes += count end
			local participants = 0
			for _, candidate in Players:GetPlayers() do
				if candidate:GetAttribute("HRushInMatch") == true then participants += 1 end
			end
			timer.Text = string.format("%ds  |  VOTED %d / %d", math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())), votes, participants)
		end
		task.wait(0.1)
	end
end)
