--!strict
-- StarterPlayerScripts/TutorialPrompt.client.lua
-- Owner: Project Owner
-- Responsibility: first-join tutorial choice and lobby teleport errors.
-- Task/spec: owner-approved Classic Tag tutorial, 2026-10-25.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TutorialEvent") :: RemoteEvent
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local colors = Theme.Colors

local gui = Instance.new("ScreenGui")
gui.Name = "HRUSH_TutorialPrompt"
gui.ResetOnSpawn = false
Theme.screen(gui, Theme.Layers.Modal)
gui.Parent = player:WaitForChild("PlayerGui")

local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = colors.Navy
shade.BackgroundTransparency = 0.25
shade.Active = true
shade.Visible = false
shade.Parent = gui

local card = Instance.new("Frame")
card.Name = "ChoiceCard"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(1, -24, 0, 254)
card.Parent = shade
local cardLimit = Instance.new("UISizeConstraint")
cardLimit.MaxSize = Vector2.new(500, 254)
cardLimit.Parent = card
Theme.surface(card, true, colors.Gold)

local function label(name: string, content: string, y: number, height: number, size: number): TextLabel
	local item = Instance.new("TextLabel")
	item.Name = name
	item.Position = UDim2.fromOffset(20, y)
	item.Size = UDim2.new(1, -40, 0, height)
	item.BackgroundTransparency = 1
	item.Text = content
	item.TextWrapped = true
	item.TextColor3 = colors.Cream
	item.TextSize = size
	item.Font = Enum.Font.GothamBold
	item.Parent = card
	return item
end

local heading = label("Heading", "LEARN TO PLAY?", 18, 40, 28)
heading.TextColor3 = colors.Gold
label("Body", "Try a short Classic Tag lesson on Kalsada. Practice moving, dashing, earned sprint, and tagging. You can start later from the lobby.", 65, 95, 18)

local function choice(name: string, content: string, x: number, accent: boolean): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(x, 1)
	button.Position = UDim2.new(x, if x == 0 then 20 else -20, 1, -18)
	button.Size = UDim2.new(0.5, -28, 0, 64)
	button.BackgroundColor3 = if accent then colors.Gold else colors.Raised
	button.TextColor3 = if accent then colors.Navy else colors.Cream
	button.Text = content
	button.TextSize = 18
	button.Font = Enum.Font.GothamBold
	button.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	Theme.focus(button)
	return button
end

local later = choice("Later", "LATER", 0, false)
local start = choice("Start", "START TUTORIAL", 1, true)
later.NextSelectionRight = start
start.NextSelectionLeft = later

local toast = Instance.new("TextLabel")
toast.Name = "ErrorToast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 12)
toast.Size = UDim2.new(1, -24, 0, 52)
toast.BackgroundColor3 = colors.Taya
toast.TextColor3 = colors.Cream
toast.TextWrapped = true
toast.Font = Enum.Font.GothamBold
toast.TextSize = 16
toast.Visible = false
toast.Parent = gui
local toastLimit = Instance.new("UISizeConstraint")
toastLimit.MaxSize = Vector2.new(540, 52)
toastLimit.Parent = toast

local shown = false
local oldFocus: GuiObject? = nil
local function close()
	shade.Visible = false
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(shade) then
		GuiService.SelectedObject = if Layout.focusAvailable(oldFocus) then oldFocus else nil
	end
	oldFocus = nil
end

local function maybeShow()
	if shown or shade.Visible then return end
	if player:GetAttribute("HRushTutorialStatus") ~= "new"
		or player:GetAttribute("HRushQueue") ~= "Idle"
		or player:GetAttribute("HRushInMatch") == true then return end
	shown = true
	oldFocus = GuiService.SelectedObject
	shade.Visible = true
	GuiService.SelectedObject = start
end

start.Activated:Connect(function()
	close()
	event:FireServer("Start")
end)
later.Activated:Connect(function()
	close()
	event:FireServer("Later")
end)

for _, name in { "HRushTutorialStatus", "HRushQueue", "HRushInMatch" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		if shade.Visible and (player:GetAttribute("HRushQueue") ~= "Idle"
			or player:GetAttribute("HRushInMatch") == true) then close() end
		maybeShow()
	end)
end
maybeShow()

event.OnClientEvent:Connect(function(kind: unknown, message: unknown)
	if kind ~= "Error" or typeof(message) ~= "string" then return end
	toast.Text = message
	toast.Visible = true
	local current = message
	task.delay(5, function()
		if toast.Text == current then toast.Visible = false end
	end)
end)
