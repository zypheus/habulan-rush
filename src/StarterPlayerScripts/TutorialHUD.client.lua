--!strict
-- StarterPlayerScripts/TutorialHUD.client.lua
-- Owner: Project Owner
-- Responsibility: one-at-a-time tutorial instructions and return/save controls.
-- Task/spec: owner-approved Classic Tag tutorial, 2026-10-25.

local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TutorialEvent") :: RemoteEvent
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local colors = Theme.Colors

local gui = Instance.new("ScreenGui")
gui.Name = "HRUSH_TutorialHUD"
gui.ResetOnSpawn = false
Theme.screen(gui, Theme.Layers.Modal)
gui.Parent = player:WaitForChild("PlayerGui")

local function textLabel(parent: Instance, name: string, content: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = content
	label.TextColor3 = colors.Cream
	label.TextWrapped = true
	label.TextSize = size
	label.Font = Enum.Font.GothamBold
	label.Parent = parent
	return label
end

local function button(parent: Instance, name: string, content: string): TextButton
	local item = Instance.new("TextButton")
	item.Name = name
	item.BackgroundColor3 = colors.Gold
	item.BorderSizePixel = 0
	item.TextColor3 = colors.Navy
	item.Text = content
	item.TextSize = 18
	item.Font = Enum.Font.GothamBold
	item.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = item
	Theme.focus(item)
	return item
end

local card = Instance.new("Frame")
card.Name = "InstructionCard"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 12)
card.Size = UDim2.new(1, -150, 0, 104)
card.Parent = gui
local cardLimit = Instance.new("UISizeConstraint")
cardLimit.MaxSize = Vector2.new(520, 104)
cardLimit.MinSize = Vector2.new(220, 104)
cardLimit.Parent = card
Theme.surface(card, false, colors.Gold)

local title = textLabel(card, "Title", "LEARN TO PLAY", 16)
title.TextColor3 = colors.Gold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.fromOffset(16, 8)
title.Size = UDim2.new(1, -32, 0, 22)
local instruction = textLabel(card, "Instruction", "", 20)
instruction.TextXAlignment = Enum.TextXAlignment.Left
instruction.Position = UDim2.fromOffset(16, 31)
instruction.Size = UDim2.new(1, -32, 0, 43)
local hint = textLabel(card, "Hint", "", 14)
hint.TextColor3 = colors.Muted
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Position = UDim2.fromOffset(16, 76)
hint.Size = UDim2.new(1, -32, 0, 22)

local leave = button(gui, "LeaveTutorial", "LEAVE")
leave.Position = UDim2.fromOffset(12, 12)
leave.Size = UDim2.fromOffset(112, 64)
leave.BackgroundColor3 = colors.Raised
leave.TextColor3 = colors.Cream
leave.Text = if UserInputService.TouchEnabled then "LEAVE" else if UserInputService.GamepadEnabled then "LEAVE (Y)" else "LEAVE (L)"

local finish = Instance.new("Frame")
finish.Name = "FinishCard"
finish.AnchorPoint = Vector2.new(0.5, 0.5)
finish.Position = UDim2.fromScale(0.5, 0.5)
finish.Size = UDim2.new(1, -32, 0, 246)
finish.Visible = false
finish.Parent = gui
local finishLimit = Instance.new("UISizeConstraint")
finishLimit.MaxSize = Vector2.new(490, 246)
finishLimit.Parent = finish
Theme.surface(finish, true, colors.Gold)
local finishTitle = textLabel(finish, "FinishTitle", "YOU'RE READY TO PLAY", 26)
finishTitle.Position = UDim2.fromOffset(16, 15)
finishTitle.Size = UDim2.new(1, -32, 0, 42)
local rule = textLabel(finish, "WinRule", "Tag passes the Taya role. Lowest cumulative Taya time wins.", 20)
rule.Position = UDim2.fromOffset(18, 60)
rule.Size = UDim2.new(1, -36, 0, 72)
local saveText = textLabel(finish, "SaveState", "Saving completion...", 15)
saveText.TextColor3 = colors.Muted
saveText.Position = UDim2.fromOffset(18, 132)
saveText.Size = UDim2.new(1, -36, 0, 28)
local returnButton = button(finish, "ReturnToLobby", "RETURN TO LOBBY")
returnButton.AnchorPoint = Vector2.new(0.5, 1)
returnButton.Position = UDim2.new(0.5, 0, 1, -14)
returnButton.Size = UDim2.new(1, -32, 0, 64)
local retry = button(finish, "RetrySave", "RETRY SAVE")
retry.AnchorPoint = Vector2.new(0.5, 1)
retry.Position = UDim2.new(0.5, 0, 1, -84)
retry.Size = UDim2.new(1, -32, 0, 54)
retry.Visible = false

local errorText = textLabel(gui, "Error", "", 16)
errorText.AnchorPoint = Vector2.new(0.5, 1)
errorText.Position = UDim2.new(0.5, 0, 1, -14)
errorText.Size = UDim2.new(1, -32, 0, 46)
errorText.TextColor3 = colors.Cream
errorText.BackgroundColor3 = colors.Taya
errorText.BackgroundTransparency = 0.1
errorText.Visible = false
local errorLimit = Instance.new("UISizeConstraint")
errorLimit.MaxSize = Vector2.new(520, 46)
errorLimit.Parent = errorText

local function inputHint(step: string): string
	if UserInputService.TouchEnabled then
		if step == "Move" then return "Use the thumbstick and jump button."
		elseif step == "Dash" then return "Tap DASH while moving."
		elseif step == "Sprint" then return "Tap SLIDE twice while moving."
		else return "Move close and tap TAG." end
	elseif UserInputService.GamepadEnabled then
		if step == "Move" then return "Move with the left stick. Jump with A."
		elseif step == "Dash" then return "Press B while moving."
		elseif step == "Sprint" then return "Press R1 twice while moving."
		else return "Move close and press R2." end
	end
	if step == "Move" then return "Move with WASD and jump with Space."
	elseif step == "Dash" then return "Press Q while moving."
	elseif step == "Sprint" then return "Press C twice while moving."
	else return "Move close and click to tag." end
end

local enteredAt = os.clock()
local function applyLayout()
	local narrow = Layout.viewport().X < 640
	card.Size = UDim2.new(1, if narrow then -24 else -150, 0, 104)
	leave.Position = if narrow then UDim2.fromOffset(12, 126) else UDim2.fromOffset(12, 12)
end
local function refresh()
	local step = player:GetAttribute("HRushTutorialStep")
	if typeof(step) ~= "string" then return end
	local complete = step == "Finish"
	finish.Visible = complete or step == "Unavailable"
	card.Visible = not finish.Visible
	leave.Visible = not finish.Visible
	if step == "Move" then instruction.Text = "RUNNER: Move to the gold marker and jump."
	elseif step == "Dash" then instruction.Text = "Dash toward the next gold marker."
	elseif step == "Sprint" then instruction.Text = "Slide twice quickly to earn sprint."
	elseif step == "Tag" then instruction.Text = "TAYA: Chase and tag the RUNNER."
	elseif step == "Unavailable" then
		finishTitle.Text = "TUTORIAL UNAVAILABLE"
		rule.Text = "The practice area could not load. Return to the lobby."
	else finishTitle.Text = "YOU'RE READY TO PLAY" end
	hint.Text = inputHint(step)
	if step == "Finish" then
		local state = player:GetAttribute("HRushTutorialSaveState")
		saveText.Text = if state == "Saved" then "Completion saved."
			else if state == "Failed" then "Save failed. Retry or return; you may be prompted again."
			else "Saving completion..."
		retry.Visible = state == "Failed"
	elseif step == "Unavailable" then saveText.Text = ""; retry.Visible = false end
	if finish.Visible and UserInputService.GamepadEnabled then GuiService.SelectedObject = returnButton end
end

player:GetAttributeChangedSignal("HRushTutorialStep"):Connect(function()
	enteredAt = os.clock()
	refresh()
end)
player:GetAttributeChangedSignal("HRushTutorialSaveState"):Connect(refresh)
refresh()
applyLayout()

task.spawn(function()
	while gui.Parent do
		applyLayout()
		local step = player:GetAttribute("HRushTutorialStep")
		if typeof(step) == "string" and step ~= "Finish" and step ~= "Unavailable"
			and os.clock() - enteredAt > 12 then
			hint.Text = inputHint(step) .. (if step == "Tag" then " Chase the moving RUNNER." else " Follow the gold marker.")
		end
		task.wait(0.5)
	end
end)

local function leaveSession()
	event:FireServer("Leave")
end
ContextActionService:BindAction("HRUSH_TutorialLeave", function(_, inputState)
	if inputState ~= Enum.UserInputState.Begin or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() ~= nil then return Enum.ContextActionResult.Pass end
	leaveSession()
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.L, Enum.KeyCode.ButtonY)
leave.Activated:Connect(leaveSession)
returnButton.Activated:Connect(leaveSession)
retry.Activated:Connect(function() event:FireServer("RetrySave") end)
event.OnClientEvent:Connect(function(kind: unknown, message: unknown)
	if kind ~= "Error" or typeof(message) ~= "string" then return end
	errorText.Text = message
	errorText.Visible = true
	local current = message
	task.delay(5, function()
		if errorText.Text == current then errorText.Visible = false end
	end)
end)
task.delay(1, function() event:FireServer("Ready") end)
