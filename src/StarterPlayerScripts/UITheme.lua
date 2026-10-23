--!strict
-- StarterPlayerScripts/UITheme.lua
-- Owner: Project Owner
-- Responsibility: Shared UI colors, type, surfaces, and accessible focus styling.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ClientSettings = require(script.Parent:WaitForChild("ClientSettings"))

local Theme = {}
Theme.Colors = Config.UI.Theme
Theme.Layers = Config.UI.Theme.Layers

function Theme.screen(gui: ScreenGui, layer: number)
	gui.DisplayOrder = layer
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
end

function Theme.surface(frame: GuiObject, modal: boolean?, accent: Color3?)
	frame.BackgroundColor3 = Theme.Colors.Raised
	frame.BorderSizePixel = 0
	local corner = frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, if modal then Theme.Colors.ModalRadius else Theme.Colors.CardRadius)
	corner.Parent = frame
	local stroke = frame:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = accent or Theme.Colors.Muted
	stroke.Thickness = if ClientSettings.get("highContrast") == true then 2 else 1
	stroke.Transparency = if ClientSettings.get("highContrast") == true then 0 else 0.45
	stroke.Parent = frame
end

function Theme.focus(button: GuiButton)
	button.Selectable = true
	local stroke = button:FindFirstChild("HRUSH_Focus") :: UIStroke?
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "HRUSH_Focus"
		stroke.Color = Theme.Colors.Cream
		stroke.Thickness = 3
		stroke.Enabled = false
		stroke.Parent = button
	end
	button.SelectionGained:Connect(function() (stroke :: UIStroke).Enabled = true end)
	button.SelectionLost:Connect(function() (stroke :: UIStroke).Enabled = false end)
end

function Theme.text(label: TextLabel | TextButton, baseSize: number, heading: boolean?)
	label.FontFace = if heading then Font.fromEnum(Enum.Font.Oswald) else Font.new("rbxasset://fonts/families/GothamSSm.json")
	label.TextSize = baseSize
	label.TextColor3 = Theme.Colors.Cream
	label.TextWrapped = true
end

function Theme.reducedMotion(): boolean
	local GuiService = game:GetService("GuiService")
	local ok, enabled = pcall(function() return GuiService.ReducedMotionEnabled end)
	return ClientSettings.get("reducedCamera") == true or (ok and enabled == true)
end

return Theme
