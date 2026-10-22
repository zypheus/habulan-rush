--!strict
-- StarterPlayerScripts/ModeVoteUI.client.lua
-- Owner: Project Owner
-- Responsibility: Present the server-owned match mode ballot on PC, touch, and gamepad.
-- Task/spec: Agawan ng Panyo Phase 1 mode selection, approved 2026-10-23.
-- Task/spec: Lihim na Target three-mode ballot, approved 2026-10-23.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local modeVoteEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ModeVoteEvent") :: RemoteEvent

local oldGui = playerGui:FindFirstChild("ModeVoteUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "ModeVoteUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 120
gui.Enabled = false
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.fromRGB(13, 25, 34)
background.BorderSizePixel = 0
background.Parent = gui

local board = Instance.new("Frame")
board.Name = "Board"
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.5)
board.Size = UDim2.fromOffset(720, 500)
board.BackgroundColor3 = Color3.fromRGB(24, 42, 55)
board.BorderSizePixel = 0
board.Parent = background
Instance.new("UICorner", board).CornerRadius = UDim.new(0, 18)

local scale = Instance.new("UIScale")
scale.Parent = board
local function resize()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(720, 500)
	scale.Scale = math.clamp(math.min(viewport.X / 760, viewport.Y / 540), 0.35, 1.1)
end
local viewportConnection: RBXScriptConnection? = nil
local function watchCamera()
	if viewportConnection then viewportConnection:Disconnect() end
	local camera = Workspace.CurrentCamera
	if camera then viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) end
	resize()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

local function makeLabel(name: string, text: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 250, 252)
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextWrapped = true
	label.Parent = board
	return label
end

makeLabel("Title", "CHOOSE THE GAME MODE", UDim2.fromOffset(32, 22), UDim2.fromOffset(656, 54), 32)
local timerLabel = makeLabel("Timer", "", UDim2.fromOffset(32, 79), UDim2.fromOffset(656, 30), 18)
timerLabel.TextColor3 = Color3.fromRGB(176, 239, 105)
local resultLabel = makeLabel("Result", "", UDim2.fromOffset(32, 432), UDim2.fromOffset(656, 42), 22)
resultLabel.TextColor3 = Color3.fromRGB(176, 239, 105)

local cards = Instance.new("Frame")
cards.Name = "ModeCards"
cards.Position = UDim2.fromOffset(32, 125)
cards.Size = UDim2.fromOffset(656, 292)
cards.BackgroundTransparency = 1
cards.Parent = board
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 12)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = cards

local buttons: { [string]: TextButton } = {}
local labels: { [string]: string } = {}
local voteCounts: { [string]: number } = {}
local selectedMode: string? = nil
local endsAt = 0
local voteOpen = false
local previousSelection: GuiObject? = nil

local function close()
	voteOpen = false
	gui.Enabled = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = previousSelection
	end
	previousSelection = nil
end

local function refreshButtons()
	for modeId, button in buttons do
		local selected = selectedMode == modeId
		button.BackgroundColor3 = if selected then Color3.fromRGB(72, 112, 61) else Color3.fromRGB(44, 67, 79)
		button.Text = string.format("%s%s    %d vote%s", labels[modeId], if selected then "  [VOTED]" else "", voteCounts[modeId] or 0, if (voteCounts[modeId] or 0) == 1 then "" else "s")
		button.Active = voteOpen
	end
end

local function start(payload: { [string]: any })
	close()
	for _, child in cards:GetChildren() do
		if child:IsA("TextButton") then child:Destroy() end
	end
	table.clear(buttons)
	table.clear(labels)
	table.clear(voteCounts)
	selectedMode = nil
	resultLabel.Text = ""
	endsAt = if typeof(payload.endsAt) == "number" then payload.endsAt else Workspace:GetServerTimeNow()
	if typeof(payload.modes) ~= "table" then return end
	for index, mode in ipairs(payload.modes) do
		if typeof(mode) == "table" and typeof(mode.id) == "string" and typeof(mode.name) == "string" then
			local modeId = mode.id
			local button = Instance.new("TextButton")
			button.Name = modeId
			button.Size = UDim2.new(1, 0, 0, if #payload.modes >= 3
				then math.floor((cards.Size.Y.Offset - 24) / #payload.modes) else 112)
			button.LayoutOrder = index
			button.BorderSizePixel = 0
			button.Font = Enum.Font.GothamBold
			button.TextSize = 24
			button.TextColor3 = Color3.fromRGB(245, 250, 252)
			button.TextWrapped = true
			button.Selectable = true
			button.Parent = cards
			Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
			local description = if typeof(mode.description) == "string" then mode.description else ""
			labels[modeId] = mode.name .. "\n" .. description
			buttons[modeId] = button
			voteCounts[modeId] = 0
			button.Activated:Connect(function()
				if not voteOpen or Workspace:GetServerTimeNow() >= endsAt then return end
				modeVoteEvent:FireServer("Vote", modeId)
			end)
		end
	end
	if next(buttons) == nil then return end
	previousSelection = GuiService.SelectedObject
	voteOpen = true
	gui.Enabled = true
	refreshButtons()
	GuiService.SelectedObject = buttons[payload.modes[1].id]
end

modeVoteEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then return end
	if payload.type == "Start" then
		start(payload)
	elseif payload.type == "Update" and gui.Enabled then
		if typeof(payload.votes) == "table" then
			if payload.voterId == player.UserId and typeof(payload.mode) == "string" then
				selectedMode = payload.mode
			end
			for modeId in buttons do
				local count = payload.votes[modeId]
				if typeof(count) == "number" then voteCounts[modeId] = count end
			end
			refreshButtons()
		end
	elseif payload.type == "Winner" and gui.Enabled then
		voteOpen = false
		timerLabel.Text = "MODE CHOSEN"
		local winner = payload.winner
		if typeof(winner) == "string" then
			resultLabel.Text = "SELECTED: " .. (string.upper(labels[winner] and string.match(labels[winner], "^[^\n]+") or winner))
		end
		refreshButtons()
	elseif payload.type == "Close" then
		close()
	end
end)

player:GetAttributeChangedSignal("HRushState"):Connect(function()
	if player:GetAttribute("HRushState") ~= "MS_VOTE" then close() end
end)

task.spawn(function()
	while true do
		if gui.Enabled and voteOpen then
			timerLabel.Text = string.format("VOTING ENDS IN %d", math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())))
		end
		task.wait(0.1)
	end
end)
