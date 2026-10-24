--!strict
-- StarterPlayerScripts/TouchLayoutController.client.lua
-- Owner: Project Owner
-- Responsibility: Place existing touch actions above the measured Roblox jump control.
-- Task/spec: approved UI/UX redesign, 2026-10-23.
-- Task/spec: automatic sprint touch layout, approved 2026-10-24.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local Theme = require(script.Parent:WaitForChild("UITheme"))

if UserInputService.TouchEnabled then
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local player = Players.LocalPlayer
	local slots = {
		{ action = "HRUSH_Skill_Touch", column = 0, row = 0, title = "SKILL", cooldown = "HRushSkillCD" },
		{ action = "HRUSH_Tag", column = 2, row = 0 },
		{ action = "HRUSH_Dash_Touch", column = 0, row = 1, title = "DASH", cooldown = "HRushDashCD" },
		{ action = "HRUSH_Slide_Touch", column = 1, row = 1, title = "SLIDE", cooldown = "HRushSlideCD" },
	}
	local function place()
		local size = Layout.viewport()
		local bottom = Layout.touchBottom()
		local left = size.X - 236
		local top = math.max(72, size.Y - bottom - 132)
		local live = player:GetAttribute("HRushInMatch") == true and player:GetAttribute("HRushState") == "MS_04"
		for _, slot in slots do
			local x = left + 32 + slot.column * 76
			local y = top + 32 + slot.row * 68
			local button = ContextActionService:GetButton(slot.action)
			if button then
				ContextActionService:SetPosition(slot.action, UDim2.fromScale(x / size.X, y / size.Y))
				button.Size = UDim2.fromOffset(Theme.Colors.TouchTarget, Theme.Colors.TouchTarget)
				if slot.action ~= "HRUSH_Tag" then
					local granted = player:GetAttribute("HRushSkillId")
					button.Visible = live and (slot.action ~= "HRUSH_Skill_Touch" or (typeof(granted) == "string" and granted ~= ""))
					local seconds = if slot.cooldown then player:GetAttribute(slot.cooldown) else 0
					local cooling = typeof(seconds) == "number" and seconds > 0
					local blocked = player:GetAttribute("HRushStunned") == true
					local caption = if blocked then "STUN" else if cooling then tostring(math.ceil(seconds)) .. "s"
						else (slot.title or "ACTION")
					ContextActionService:SetTitle(slot.action, caption)
					button.ImageColor3 = if blocked or cooling then Theme.Colors.Disabled else Theme.Colors.Gold
				end
			end
		end
		local panyoHud = playerGui:FindFirstChild("HRushHUD")
		local tsinelas = panyoHud and panyoHud:FindFirstChild("TsinelasTouch")
		if tsinelas and tsinelas:IsA("GuiObject") then
			tsinelas.Position = UDim2.fromScale((left + 108) / size.X, (top + 32) / size.Y)
			tsinelas.Size = UDim2.fromOffset(Theme.Colors.TouchTarget, Theme.Colors.TouchTarget)
		end
		local chase = playerGui:FindFirstChild("HRushChaseHUD")
		if chase then
			local view = chase:FindFirstChild("ViewModeButton")
			local look = chase:FindFirstChild("LookBackButton")
			if view and view:IsA("GuiObject") then
				view.Position = UDim2.fromScale((size.X - 44) / size.X, 40 / size.Y)
				view.Size = UDim2.fromOffset(Theme.Colors.TouchTarget, Theme.Colors.TouchTarget)
			end
			if look and look:IsA("GuiObject") then
				look.Position = UDim2.fromScale((size.X - 192) / size.X, 40 / size.Y)
				look.Size = UDim2.fromOffset(Theme.Colors.TouchTarget, Theme.Colors.TouchTarget)
			end
		end
	end
	task.spawn(function()
		while playerGui.Parent do
			place()
			task.wait(0.25)
		end
	end)
end
