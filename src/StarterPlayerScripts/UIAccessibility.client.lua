--!strict
-- StarterPlayerScripts/UIAccessibility.client.lua
-- Owner: Project Owner
-- Responsibility: Apply text size and high contrast to runtime PlayerGui screens.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ClientSettings = require(script.Parent:WaitForChild("ClientSettings"))
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local textBase: { [Instance]: { number } } = setmetatable({}, { __mode = "k" })
local strokeBase: { [Instance]: { number } } = setmetatable({}, { __mode = "k" })

local function preferredFactor(): number
	local ok, value = pcall(function() return GuiService.PreferredTextSize end)
	if not ok then return 1 end
	local name = tostring(value)
	if string.find(name, "XLarge") then return 1.2 end
	if string.find(name, "Large") then return 1.1 end
	if string.find(name, "Small") then return 0.9 end
	return 1
end

local function apply(instance: Instance)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		local item = instance :: TextLabel
		if item.TextScaled then return end
		local entry = textBase[item]
		if not entry then
			entry = { item.TextSize, item.TextSize }
			textBase[item] = entry
		elseif item.TextSize ~= entry[2] then
			entry[1] = item.TextSize -- A screen reflow chose a new base size.
		end
		local percent = ClientSettings.get("textScale") :: number
		entry[2] = math.clamp(math.floor(entry[1] * percent / 100 * preferredFactor() + 0.5), 8, 120)
		item.TextSize = entry[2]
	elseif instance:IsA("UIStroke") then
		local stroke = instance :: UIStroke
		local base = strokeBase[stroke]
		if not base then base = { stroke.Thickness, stroke.Transparency } strokeBase[stroke] = base end
		if ClientSettings.get("highContrast") == true then
			stroke.Thickness = math.max(base[1], 2)
			stroke.Transparency = math.min(base[2], 0.15)
		else
			stroke.Thickness = base[1]
			stroke.Transparency = base[2]
		end
	end
end

local function refresh()
	for _, descendant in playerGui:GetDescendants() do apply(descendant) end
end

playerGui.DescendantAdded:Connect(function(descendant)
	task.defer(function()
		if descendant.Parent then apply(descendant) end
	end)
end)
ClientSettings.Changed:Connect(function(key: string)
	if key == "textScale" or key == "highContrast" then refresh() end
end)
pcall(function()
	GuiService:GetPropertyChangedSignal("PreferredTextSize"):Connect(refresh)
end)
refresh()
