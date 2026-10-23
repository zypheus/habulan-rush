--!strict
-- StarterPlayerScripts/UILayoutCoordinator.lua
-- Owner: Project Owner
-- Responsibility: Shared safe-area breakpoints, modal focus, and touch reservations.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))

local Layout = {}
local savedFocus: { [ScreenGui]: GuiObject? } = {}

function Layout.focusAvailable(object: GuiObject?): boolean
	if not object or not object.Parent then return false end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local current: Instance? = object
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then return false end
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		current = current.Parent
	end
	return current == playerGui
end

function Layout.viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

function Layout.compact(): boolean
	local size = Layout.viewport()
	return size.X < Config.UI.Theme.PhoneWidth or size.Y < Config.UI.Theme.PhoneHeight
end

function Layout.fit(frame: GuiObject, desktop: Vector2, phone: Vector2, gutter: number?)
	local size = Layout.viewport()
	local margin = gutter or 12
	local wanted = if Layout.compact() then phone else desktop
	frame.Size = UDim2.fromOffset(math.min(wanted.X, size.X - margin * 2), math.min(wanted.Y, size.Y - margin * 2))
end

function Layout.openModal(gui: ScreenGui, first: GuiObject?)
	savedFocus[gui] = GuiService.SelectedObject
	gui.Enabled = true
	if first and first:IsDescendantOf(gui) then GuiService.SelectedObject = first end
end

function Layout.closeModal(gui: ScreenGui)
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(gui) then
		local previous = savedFocus[gui]
		GuiService.SelectedObject = if Layout.focusAvailable(previous) then previous else nil
	end
	savedFocus[gui] = nil
	gui.Enabled = false
end

function Layout.touchBottom(): number
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local touch = playerGui and playerGui:FindFirstChild("TouchGui")
	local jump = touch and touch:FindFirstChild("JumpButton", true)
	if jump and jump:IsA("GuiObject") and jump.AbsoluteSize.Y > 0 then
		return math.max(116, Layout.viewport().Y - jump.AbsolutePosition.Y + 8)
	end
	return 116
end

return Layout
