--!strict
-- Task/spec: suppress world nametags during the match showcase, approved 2026-10-25.
-- StarterPlayerScripts/NametagController.client.lua
-- Owner: Project Owner
-- Responsibility: One visible local identity badge per other match character.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
local MatchShowcase = require(script.Parent:WaitForChild("MatchShowcase", 10))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local huntEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SecretHuntEvent") :: RemoteEvent
local guiByPlayer: { [Player]: BillboardGui } = {}
local targetUserId: number? = nil
local assignmentRound = 0
local assignmentVersion = -1

local function clear(player: Player)
	local gui = guiByPlayer[player]
	if gui then gui:Destroy() guiByPlayer[player] = nil end
end

local function badge(player: Player, head: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "HRUSH_Nametag"
	gui.Adornee = head
	gui.AlwaysOnTop = false
	gui.Size = UDim2.fromOffset(if Layout.compact() then 140 else 160, if Layout.compact() then 40 else 42)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.7, 0)
	gui.MaxDistance = Theme.Colors.NametagFar
	gui.Parent = playerGui
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundTransparency = 0.18
	Theme.surface(plate, false)
	plate.Parent = gui
	local text = Instance.new("TextLabel")
	text.Name = "Identity"
	text.Size = UDim2.new(1, -12, 1, -4)
	text.Position = UDim2.fromOffset(6, 2)
	text.BackgroundTransparency = 1
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.TextXAlignment = Enum.TextXAlignment.Center
	Theme.text(text, if Layout.compact() then 13 else 14)
	text.Parent = plate
	guiByPlayer[player] = gui
	return gui
end

huntEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.type) ~= "string" then return end
	if payload.type == "Close" then targetUserId = nil return end
	if payload.type ~= "Assignment" or typeof(payload.round) ~= "number" or typeof(payload.version) ~= "number" then return end
	if payload.round < assignmentRound or (payload.round == assignmentRound and payload.version < assignmentVersion) then return end
	assignmentRound = payload.round
	assignmentVersion = payload.version
	targetUserId = if typeof(payload.targetUserId) == "number" then payload.targetUserId else nil
end)

Players.PlayerRemoving:Connect(clear)
MatchShowcase.Changed:Connect(function(active: boolean)
	if active then
		for player in guiByPlayer do clear(player) end
	end
end)
localPlayer:GetAttributeChangedSignal("HRushGameMode"):Connect(function()
	if localPlayer:GetAttribute("HRushGameMode") ~= "SecretHunt" then
		targetUserId = nil
		assignmentRound = 0
		assignmentVersion = -1
	end
end)
localPlayer:GetAttributeChangedSignal("HRushInMatch"):Connect(function()
	if localPlayer:GetAttribute("HRushInMatch") ~= true then
		targetUserId = nil
		assignmentRound = 0
		assignmentVersion = -1
	end
end)

task.spawn(function()
	while true do
		local camera = Workspace.CurrentCamera
		local state = localPlayer:GetAttribute("HRushState")
		local mode = localPlayer:GetAttribute("HRushGameMode")
		local inRound = localPlayer:GetAttribute("HRushInMatch") == true
			and (state == "MS_03" or state == "MS_04") and not MatchShowcase.isActive()
		local carrierId = ReplicatedStorage:GetAttribute("HRushPanyoCarrierUserId")
		local visibleTags = {}
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer then
				local character = player.Character
				local head = character and character:FindFirstChild("Head")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local valid = inRound and player:GetAttribute("HRushInMatch") == true and head and head:IsA("BasePart") and humanoid and humanoid.Health > 0
				if not valid or not camera then
					clear(player)
				else
					local headPart = head :: BasePart
					local distance = (camera.CFrame.Position - headPart.Position).Magnitude
					local visible = distance <= Theme.Colors.NametagFar
					if visible then
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = if localPlayer.Character then { localPlayer.Character } else {}
						local hit = Workspace:Raycast(camera.CFrame.Position, headPart.Position - camera.CFrame.Position, params)
						visible = hit == nil or (character ~= nil and hit.Instance:IsDescendantOf(character))
					end
					local gui = guiByPlayer[player]
					if not gui or gui.Adornee ~= headPart then clear(player) gui = badge(player, headPart) end
					gui.Enabled = visible
					local plate = gui:FindFirstChild("Plate") :: Frame
					local text = plate:FindFirstChild("Identity") :: TextLabel
					local role = player:GetAttribute("HRushRole")
					local label = player.DisplayName
					local color = Theme.Colors.Muted
					if mode == "AgawanNgPanyo" and player.UserId == carrierId then
						label = "⚑ CARRIER · " .. label
						color = Theme.Colors.Gold
					elseif mode == "SecretHunt" and player.UserId == targetUserId then
						label = "◇ TARGET · " .. label
						color = Theme.Colors.Gold
					elseif mode == "ClassicTag" and role == "Taya" then
						label = "⬡ TAYA · " .. label
						color = Theme.Colors.TayaText
					elseif mode == "ClassicTag" and role == "Runner" then
						label = "○ RUNNER · " .. label
						color = Theme.Colors.RunnerText
					end
					text.Text = label
					text.TextColor3 = color
						local fade = math.clamp((distance - Theme.Colors.NametagNear) / (Theme.Colors.NametagFar - Theme.Colors.NametagNear), 0, 1)
						plate.BackgroundTransparency = 0.18 + 0.65 * fade
						text.TextTransparency = 0.7 * fade
					if visible then
						local point, onScreen = camera:WorldToViewportPoint(headPart.Position + Vector3.new(0, 2.7, 0))
						gui.Enabled = onScreen
						if onScreen then
							local priority = if (mode == "AgawanNgPanyo" and player.UserId == carrierId)
								or (mode == "SecretHunt" and player.UserId == targetUserId)
								or (mode == "ClassicTag" and role == "Taya") then 2 else 1
							table.insert(visibleTags, { gui = gui, x = point.X, y = point.Y, priority = priority, distance = distance })
						end
					end
				end
			end
		end
		table.sort(visibleTags, function(a, b)
			if a.priority ~= b.priority then return a.priority > b.priority end
			return a.distance < b.distance
		end)
		local occupied = {}
		local width = if Layout.compact() then 140 else 160
		for _, tag in visibleTags do
			local overlaps = false
			for _, kept in occupied do
				if math.abs(tag.x - kept.x) < width and math.abs(tag.y - kept.y) < 42 then overlaps = true break end
			end
			tag.gui.Enabled = not overlaps
			if not overlaps then table.insert(occupied, tag) end
		end
		task.wait(0.1)
	end
end)
