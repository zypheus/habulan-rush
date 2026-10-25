--!strict
-- StarterPlayerScripts/MatchShowcase.lua
-- Owner: Project Owner
-- Responsibility: Deadline-driven match opening, inert local avatar lineup, and title/fade UI.
-- CameraDirector alone applies the returned camera frame. No gameplay or private role reads.
-- Task/spec: lower full-court Kalsada clip, lineup and five-second countdown, approved 2026-10-25.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Config", 10))
local Theme = require(script.Parent:WaitForChild("UITheme", 10))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator", 10))
local settings = Config.Match.Showcase
local localPlayer = Players.LocalPlayer
local changed = Instance.new("BindableEvent")
local Showcase = { Changed = changed.Event }

assert(settings.Duration > settings.MapShotDuration + settings.TransitionDuration
	and settings.MapShotDuration > 0 and settings.TransitionDuration > 0,
	"Match showcase needs time for the map, lineup, and transition")
assert(settings.FrameMargin > 1 and settings.FieldOfView > 0 and settings.FieldOfView < 180,
	"Match showcase framing settings are invalid")
assert(#settings.Maps.Kalsada.MapClips == 5, "Match showcase needs five Kalsada clips")

type Avatar = { player: Player, model: Model, size: Vector3, center: Vector3, bottom: number }
local avatars: { Avatar } = {}
local hiddenParts: { [BasePart]: number } = {}
local touchScreens: { [ScreenGui]: boolean } = {}
local scene: Folder? = nil
local screen: ScreenGui? = nil
local title: TextLabel? = nil
local subtitle: TextLabel? = nil
local veil: Frame? = nil
local activeDeadline: number? = nil
local lineupSize = Vector3.zero
local started = false
local wasActive = false
local handoffDone = false

function Showcase.isActive(): boolean
	local endsAt = ReplicatedStorage:GetAttribute("HRushShowcaseEndsAt")
	return localPlayer:GetAttribute("HRushInMatch") == true
		and localPlayer:GetAttribute("HRushState") == "MS_03"
		and localPlayer:GetAttribute("HRushRound") == 1
		and typeof(endsAt) == "number" and Workspace:GetServerTimeNow() < endsAt
end

local function restoreCharacters()
	for part, transparency in hiddenParts do
		if part.Parent then part.LocalTransparencyModifier = transparency end
	end
	table.clear(hiddenParts)
end

function Showcase.stop()
	if scene then scene:Destroy() scene = nil end
	if screen then screen:Destroy() screen = nil end
	title, subtitle, veil = nil, nil, nil
	restoreCharacters()
	for gui, enabled in touchScreens do
		if gui.Parent then gui.Enabled = enabled end
	end
	table.clear(touchScreens)
	table.clear(avatars)
	activeDeadline = nil
	handoffDone = false
	if wasActive then wasActive = false changed:Fire(false) end
end

local function copyAvatar(player: Player): Avatar?
	local source = player.Character
	if not source or not source:FindFirstChild("HumanoidRootPart")
		or not source:FindFirstChild("Head") then return nil end
	local archivable = source.Archivable
	local model: Model? = nil
	local ok, result = pcall(function(): Avatar?
		source.Archivable = true
		model = source:Clone()
		if not model then return nil end
		model.Name = "HRUSH_ShowcaseAvatar_" .. tostring(player.UserId)
		for _, item in model:GetDescendants() do
			if item.Parent == nil then continue end
			for _, tag in CollectionService:GetTags(item) do CollectionService:RemoveTag(item, tag) end
			for attribute in item:GetAttributes() do
				if attribute:sub(1, 3) ~= "RBX" then item:SetAttribute(attribute, nil) end
			end
			if item:IsA("LuaSourceContainer") or item:IsA("Tool") or item:IsA("Animator")
				or item:IsA("AnimationController") or item:IsA("Sound") or item:IsA("LayerCollector")
				or item:IsA("Highlight") or item:IsA("ProximityPrompt") or item:IsA("ClickDetector")
				or item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam")
				or item:IsA("ForceField") then
				item:Destroy()
			elseif item:IsA("BasePart") then
				item.Anchored = true
				item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
				item.LocalTransparencyModifier = 0
				item.AssemblyLinearVelocity, item.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			elseif item:IsA("Humanoid") then
				item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				item.AutoRotate, item.PlatformStand = false, true
				item.WalkSpeed = 0
			end
		end
		for _, tag in CollectionService:GetTags(model) do CollectionService:RemoveTag(model, tag) end
		for attribute in model:GetAttributes() do
			if attribute:sub(1, 3) ~= "RBX" then model:SetAttribute(attribute, nil) end
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then return nil end
		model.PrimaryPart = root
		model:PivotTo(CFrame.identity)
		local box, size = model:GetBoundingBox()
		return { player = player, model = model, size = size, center = box.Position, bottom = box.Position.Y - size.Y / 2 }
	end)
	source.Archivable = archivable
	if not ok or not result then
		if model then model:Destroy() end
		if not ok then warn("[HRUSH_MatchShowcase] Avatar copy failed for " .. tostring(player.UserId) .. ": " .. tostring(result)) end
		return nil
	end
	return result
end

local function buildLineup(floor: CFrame)
	local roster = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("HRushInMatch") == true then table.insert(roster, player) end
	end
	table.sort(roster, function(a, b) return a.UserId < b.UserId end)
	local width, height, depth = 0, 0, 0
	for _, player in roster do
		local avatar = copyAvatar(player)
		if avatar then
			table.insert(avatars, avatar)
			width += avatar.size.X + settings.LineupGap
			height, depth = math.max(height, avatar.size.Y), math.max(depth, avatar.size.Z)
		end
	end
	width = math.max(0, width - settings.LineupGap)
	lineupSize = Vector3.new(width, height, depth)
	local cursor = -width / 2
	for _, avatar in avatars do
		avatar.model:PivotTo(floor * CFrame.new(cursor + avatar.size.X / 2 + avatar.center.X, -avatar.bottom, avatar.center.Z)
			* CFrame.Angles(0, math.pi, 0))
		avatar.model.Parent = scene
		cursor += avatar.size.X + settings.LineupGap
	end
end

local function buildScreen()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HRUSH_MatchShowcase"
	gui.ResetOnSpawn = false
	Theme.screen(gui, Theme.Layers.Transition)
	screen = gui
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 1)
	plate.Position = UDim2.new(0.5, 0, 1, -24)
	plate.Size = UDim2.new(0.8, 0, 0, 106)
	Theme.surface(plate, false, Theme.Colors.Gold)
	plate.Parent = gui
	title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 52)
	title.BackgroundTransparency = 1
	Theme.text(title, if Layout.compact() then 23 else 32, true)
	title.Parent = plate
	subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position, subtitle.Size = UDim2.fromOffset(12, 64), UDim2.new(1, -24, 0, 30)
	subtitle.BackgroundTransparency = 1
	Theme.text(subtitle, if Layout.compact() then 13 else 16)
	subtitle.TextColor3 = Theme.Colors.Gold
	subtitle.Parent = plate
	veil = Instance.new("Frame")
	veil.Name = "Fade"
	-- Overscan covers Roblox safe-area insets while the text stays inside them.
	veil.Position, veil.Size = UDim2.new(0, -256, 0, -256), UDim2.new(1, 512, 1, 512)
	veil.BackgroundColor3 = Color3.new(0, 0, 0)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel, veil.ZIndex = 0, 10
	veil.Parent = gui
	gui.Parent = playerGui
end

local function hideCharacters()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if player:GetAttribute("HRushInMatch") == true and character then
			for _, item in character:GetDescendants() do
				if item:IsA("BasePart") then
					if hiddenParts[item] == nil then hiddenParts[item] = item.LocalTransparencyModifier end
					item.LocalTransparencyModifier = 1
				end
			end
		end
	end
end

local function suppressTouch()
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local touch = playerGui and playerGui:FindFirstChild("TouchGui")
	if touch and touch:IsA("ScreenGui") then
		if touchScreens[touch] == nil then touchScreens[touch] = touch.Enabled end
		touch.Enabled = false
	end
end

local function smooth(t: number): number
	return t * t * (3 - 2 * t)
end

local function fitMapFrame(position: Vector3, focus: Vector3, clip: any, viewport: Vector2): Vector3
	local bounds = clip.FrameBounds
	if bounds == nil then return position end
	local aspect = math.max(1, viewport.X) / math.max(1, viewport.Y)
	local halfFov = math.tan(math.rad(settings.FieldOfView / 2)) * bounds.ScreenMargin
	local function fits(shift: number): boolean
		local view = CFrame.lookAt(position + bounds.Pullback * shift, focus)
		for _, x in { bounds.Min.X, bounds.Max.X } do
			for _, y in { bounds.Min.Y, bounds.Max.Y } do
				for _, z in { bounds.Min.Z, bounds.Max.Z } do
					local point = view:PointToObjectSpace(Vector3.new(x, y, z))
					local depth = -point.Z
					if depth <= 0 or math.abs(point.X) > depth * halfFov * aspect
						or math.abs(point.Y) > depth * halfFov then
						return false
					end
				end
			end
		end
		return true
	end
	if fits(0) then return position end
	local near, far = 0, bounds.MaxPullback
	for _ = 1, 12 do
		local middle = (near + far) / 2
		if fits(middle) then far = middle else near = middle end
	end
	return position + bounds.Pullback * far
end

-- Fits the actual avatar bounds in both axes, including on narrow screens.
function Showcase.fitDistance(size: Vector3, viewport: Vector2): number
	local vertical = math.tan(math.rad(settings.FieldOfView / 2))
	local horizontal = vertical * math.max(0.1, viewport.X / math.max(1, viewport.Y))
	local usableHeight = 1 - math.min(0.5, settings.TitleReserve / math.max(1, viewport.Y))
	return math.max(size.Y / (2 * vertical * usableHeight), size.X / (2 * horizontal))
		* settings.FrameMargin + size.Z / 2
end

function Showcase.step(camera: Camera): CFrame?
	if not Showcase.isActive() then Showcase.stop() return nil end
	local endsAt = ReplicatedStorage:GetAttribute("HRushShowcaseEndsAt") :: number
	local mapId = ReplicatedStorage:GetAttribute("HRushSelectedMap")
	-- Preserve the live five-map ballot; unauthored shot rigs use the current Kalsada scene.
	local map = settings.Maps[if typeof(mapId) == "string" then mapId else "Kalsada"] or settings.Maps.Kalsada
	if activeDeadline ~= endsAt then
		if activeDeadline ~= nil then Showcase.stop() end
		activeDeadline = endsAt
		scene = Instance.new("Folder")
		scene.Name = "HRUSH_MatchShowcaseScene"
		scene.Parent = Workspace
		if map then buildLineup(map.LineupFloor) end
		buildScreen()
		if not wasActive then wasActive = true changed:Fire(true) end
	end
	suppressTouch()
	local elapsed = settings.Duration - (endsAt - Workspace:GetServerTimeNow())
	local transitionStart = settings.Duration - settings.TransitionDuration
	local transition = math.clamp((elapsed - transitionStart) / settings.TransitionDuration, 0, 1)
	local mapShot = elapsed < settings.MapShotDuration or #avatars == 0
	if title and subtitle then
		local mode = localPlayer:GetAttribute("HRushGameMode")
		local definition = if typeof(mode) == "string" then Config.ModeVote.Modes[mode] else nil
		local count = 0
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("HRushInMatch") == true then count += 1 end
		end
		title.Text = if mapShot then "BARANGAY KALSADA" else string.upper(if definition then definition.name else "HABULAN RUSH")
		subtitle.Text = if mapShot then "HABULAN RUSH"
			else string.format("%d %s  /  ROUND 1", count, if count == 1 then "PLAYER" else "PLAYERS")
		title.TextTransparency, subtitle.TextTransparency = transition, transition
	end
	if veil then veil.BackgroundTransparency = math.abs(2 * transition - 1) end
	if transition >= 0.5 then
		if not handoffDone then
			handoffDone = true
			if veil then veil.BackgroundTransparency = 0 end
			restoreCharacters()
			if scene then scene:Destroy() scene = nil end
		end
		return nil
	end
	hideCharacters()
	if not map then return nil end
	if mapShot then
		local clips = map.MapClips
		local clipDuration = settings.MapShotDuration / #clips
		local index = math.clamp(math.floor(elapsed / clipDuration) + 1, 1, #clips)
		local clip = clips[index]
		local t = if Theme.reducedMotion() then 0 else smooth(math.clamp(
			(elapsed - (index - 1) * clipDuration) / clipDuration, 0, 1))
		local first = clip.Start.Position:Lerp(clip.Control, t)
		local second = clip.Control:Lerp(clip.Finish.Position, t)
		local position = first:Lerp(second, t)
		local focus = clip.Focus:Lerp(clip.FocusFinish or clip.Focus, t)
		return CFrame.lookAt(fitMapFrame(position, focus, clip, camera.ViewportSize), focus)
	end
	local t = if Theme.reducedMotion() then 0 else smooth(math.clamp(
		(elapsed - settings.MapShotDuration) / (transitionStart - settings.MapShotDuration), 0, 1))
	local distance = Showcase.fitDistance(lineupSize, camera.ViewportSize) * (settings.PushInScale + (1 - settings.PushInScale) * t)
	local target = map.LineupFloor:PointToWorldSpace(Vector3.new(0, lineupSize.Y / 2, 0))
	local position = map.LineupFloor:PointToWorldSpace(Vector3.new(0, lineupSize.Y / 2, distance))
	local titleOffset = distance * math.tan(math.rad(settings.FieldOfView / 2))
		* math.min(0.5, settings.TitleReserve / math.max(1, camera.ViewportSize.Y))
	return CFrame.lookAt(position, target - Vector3.new(0, titleOffset, 0))
end

function Showcase.start()
	if started then return end
	started = true
	local function checkExit()
		if not Showcase.isActive() then Showcase.stop() end
	end
	for _, attribute in { "HRushInMatch", "HRushState", "HRushRound" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(checkExit)
	end
	ReplicatedStorage:GetAttributeChangedSignal("HRushShowcaseEndsAt"):Connect(checkExit)
	RunService.Heartbeat:Connect(function()
		if Showcase.isActive() then
			if not wasActive then wasActive = true changed:Fire(true) end
		elseif wasActive or scene or screen then
			Showcase.stop()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		for index = #avatars, 1, -1 do
			if avatars[index].player == player then avatars[index].model:Destroy() table.remove(avatars, index) end
		end
	end)
end

return Showcase
