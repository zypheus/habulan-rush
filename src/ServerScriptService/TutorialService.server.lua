--!strict
-- ServerScriptService/TutorialService.server.lua
-- Owner: Project Owner
-- Responsibility: isolated Classic Tag lesson state, practice target, and completion.
-- Task/spec: owner-approved Classic Tag tutorial, 2026-10-25.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Progress = require(ServerScriptService:WaitForChild("TutorialProgress"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TutorialEvent = Remotes:WaitForChild("TutorialEvent") :: RemoteEvent
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local RequestTag = Remotes:WaitForChild("RequestTag") :: RemoteEvent
local scene = Workspace:WaitForChild("TutorialScene", 10)

type Step = "Move" | "Dash" | "Sprint" | "Tag" | "Finish" | "Unavailable"
type Session = {
	step: Step,
	jumped: boolean,
	dashed: boolean,
	dashAcceptedAt: number,
	slideCount: number,
	lastSlideAt: number,
	lastAction: number,
	lastTag: number,
	returnPlaceId: number,
	beacon: BasePart?,
	gate: Model?,
	target: Model?,
	connections: { RBXScriptConnection },
}

local sessions: { [Player]: Session } = {}
local markers: { [string]: BasePart } = {}
local required = { "Start", "MoveGoal", "DashGoal", "SlideStart", "SlideEnd", "TagPathA", "TagPathB" }
local sceneReady = scene ~= nil and scene:IsA("Folder")
if sceneReady then
	for _, name in required do
		local part = (scene :: Folder):FindFirstChild(name)
		if not part or not part:IsA("BasePart") then
			sceneReady = false
			warn("[TutorialService] Missing tutorial marker " .. name)
			break
		end
		markers[name] = part
	end
else
	warn("[TutorialService] TutorialScene is missing")
end

StarterPlayer.CharacterWalkSpeed = Config.Movement.RunnerWalkSpeed * Config.Movement.SpeedScale
StarterPlayer.CharacterJumpPower = Config.Movement.JumpPower
Lighting.ClockTime = 14
Lighting.Brightness = 2
ReplicatedStorage:SetAttribute("HRushRoundState", "MS_04")
ReplicatedStorage:SetAttribute("HRushMatchState", "MS_04")
ReplicatedStorage:SetAttribute("HRushGameMode", "ClassicTag")

if sceneReady then
	local map = Workspace:FindFirstChild("Map")
	local oldSpawn = map and map:FindFirstChild("Spawn")
	if oldSpawn and oldSpawn:IsA("SpawnLocation") then oldSpawn.Enabled = false end
	local tutorialSpawn = Instance.new("SpawnLocation")
	tutorialSpawn.Name = "HRUSH_TutorialSpawn"
	tutorialSpawn.Size = Vector3.new(8, 1, 8)
	tutorialSpawn.CFrame = markers.Start.CFrame
	tutorialSpawn.Anchored = true
	tutorialSpawn.Neutral = true
	tutorialSpawn.Parent = Workspace
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then return root end
	return nil
end

local function notifyState(player: Player, session: Session)
	StateChanged:FireClient(player, {
		state = if session.step == "Finish" or session.step == "Unavailable" then "MS_05" else "MS_04",
		role = if session.step == "Tag" or session.step == "Finish" then "Taya" else "Runner",
		mode = "ClassicTag", round = 1, timer = Workspace:GetServerTimeNow(),
	})
end

local function makeBeacon(): BasePart
	local part = Instance.new("Part")
	part.Name = "HRUSH_TutorialBeacon"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(2, 2, 2)
	part.Material = Enum.Material.Neon
	part.Color = Config.UI.Theme.Gold
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = Workspace
	return part
end

local function makeGate(): Model
	local gate = Instance.new("Model")
	gate.Name = "HRUSH_TutorialDashGate"
	for _, piece in {
		{ name = "Left", size = Vector3.new(0.5, 8, 0.5), offset = CFrame.new(-5, 4, 0) },
		{ name = "Right", size = Vector3.new(0.5, 8, 0.5), offset = CFrame.new(5, 4, 0) },
		{ name = "Top", size = Vector3.new(10.5, 0.5, 0.5), offset = CFrame.new(0, 8, 0) },
	} do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Size = piece.size
		part.CFrame = markers.DashGoal.CFrame * piece.offset
		part.Material = Enum.Material.Neon
		part.Color = Config.UI.Theme.Gold
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Parent = gate
	end
	gate.Parent = Workspace
	return gate
end

local function makeTarget(): Model
	local model = Instance.new("Model")
	model.Name = "HRUSH_TutorialRunner"
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 3, 1)
	torso.Anchored = true
	torso.CanCollide = false
	torso.CanTouch = false
	torso.Color = Config.UI.Theme.Runner
	torso.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.Anchored = true
	head.CanCollide = false
	head.CanTouch = false
	head.Color = Config.UI.Theme.Cream
	head.CFrame = torso.CFrame * CFrame.new(0, 2.25, 0)
	head.Parent = model
	local label = Instance.new("BillboardGui")
	label.Name = "RunnerLabel"
	label.Size = UDim2.fromOffset(130, 36)
	label.StudsOffset = Vector3.new(0, 2.3, 0)
	label.AlwaysOnTop = true
	label.Parent = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Config.UI.Theme.Navy
	text.BackgroundTransparency = 0.15
	text.TextColor3 = Config.UI.Theme.Cream
	text.Font = Enum.Font.GothamBold
	text.TextSize = 20
	text.Text = "RUNNER"
	text.Parent = label
	model.PrimaryPart = torso
	model.Parent = Workspace
	return model
end

local function setStep(player: Player, session: Session, step: Step)
	session.step = step
	player:SetAttribute("HRushTutorialStep", step)
	if step == "Finish" or step == "Unavailable" then
		player:SetAttribute("HRushState", "MS_05")
		notifyState(player, session)
	end
	if step == "Tag" then
		player:SetAttribute("HRushRole", "Taya")
		if not session.target then session.target = makeTarget() end
		notifyState(player, session)
	end
	if step == "Dash" then session.gate = makeGate()
	elseif session.gate then session.gate:Destroy(); session.gate = nil end
	local beacon = session.beacon
	if beacon then
		local destination = if step == "Move" then markers.MoveGoal
			else if step == "Dash" then markers.DashGoal
			else if step == "Sprint" then markers.SlideEnd else nil
		beacon.Transparency = if destination then 0.15 else 1
		if destination then beacon.Position = destination.Position + Vector3.new(0, 3, 0) end
	end
	if step == "Finish" then
		if session.target then session.target:Destroy(); session.target = nil end
		player:SetAttribute("HRushTutorialSaveState", "Saving")
		task.spawn(function()
			local saved = Progress.mark(player.UserId, "complete")
			if player.Parent and sessions[player] == session then
				player:SetAttribute("HRushTutorialSaveState", if saved then "Saved" else "Failed")
				player:SetAttribute("HRushTutorialCompleted", saved)
			end
		end)
	end
end

local function placeCharacter(player: Player, session: Session, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or not root:IsA("BasePart") or sessions[player] ~= session then return end
	local startName = if session.step == "Tag" or session.step == "Finish" then "SlideEnd"
		else if session.step == "Sprint" then "DashGoal"
		else if session.step == "Dash" then "MoveGoal" else "Start"
	local start = markers[startName]
	if not start then return end
	local nextPoint = if session.step == "Tag" then markers.TagPathA else markers.MoveGoal
	character:PivotTo(CFrame.lookAt(start.Position + Vector3.new(0, 3, 0), nextPoint.Position + Vector3.new(0, 3, 0)))
	notifyState(player, session)
end

local function startPlayer(player: Player)
	local joinData = player:GetJoinData()
	local source = joinData.SourcePlaceId
	local returnPlaceId = if typeof(source) == "number" and joinData.SourceGameId == game.GameId
		then source else Config.Tutorial.MainPlaceId
	local session: Session = {
		step = "Move", jumped = false, dashed = false, dashAcceptedAt = -math.huge,
		slideCount = 0, lastSlideAt = -math.huge, lastAction = -math.huge,
		lastTag = -math.huge, returnPlaceId = returnPlaceId,
		beacon = nil, gate = nil, target = nil, connections = {},
	}
	sessions[player] = session
	player:SetAttribute("HRushTutorialActive", true)
	player:SetAttribute("HRushTutorialSaveState", "Pending")
	player:SetAttribute("HRushTutorialCompleted", false)
	player:SetAttribute("HRushQueue", "InMatch")
	player:SetAttribute("HRushInMatch", true)
	player:SetAttribute("HRushState", "MS_04")
	player:SetAttribute("HRushGameMode", "ClassicTag")
	player:SetAttribute("HRushRole", "Runner")
	if not sceneReady or (not RunService:IsStudio() and game.PrivateServerId == "") then
		setStep(player, session, "Unavailable")
		TutorialEvent:FireClient(player, "Error", "Tutorial session is unavailable. Return to the lobby.")
		return
	end
	session.beacon = makeBeacon()
	setStep(player, session, "Move")
	table.insert(session.connections, player:GetAttributeChangedSignal("HRushServerAirborne"):Connect(function()
		if session.step == "Move" and player:GetAttribute("HRushServerAirborne") == true then session.jumped = true end
	end))
	table.insert(session.connections, player:GetAttributeChangedSignal("HRushServerDashing"):Connect(function()
		if session.step == "Dash" and player:GetAttribute("HRushServerDashing") == true then
			session.dashed = true
			session.dashAcceptedAt = os.clock()
		end
	end))
	table.insert(session.connections, player:GetAttributeChangedSignal("HRushServerSliding"):Connect(function()
		if session.step ~= "Sprint" or player:GetAttribute("HRushServerSliding") ~= true then return end
		local now = os.clock()
		session.slideCount = if now - session.lastSlideAt <= Config.Momentum.ChainWindow then session.slideCount + 1 else 1
		session.lastSlideAt = now
	end))
	table.insert(session.connections, player.CharacterAdded:Connect(function(character)
		task.defer(placeCharacter, player, session, character)
	end))
	if player.Character then task.defer(placeCharacter, player, session, player.Character) end
end

local lastSample = 0
RunService.Heartbeat:Connect(function(dt)
	lastSample += dt
	if lastSample < 0.1 then return end
	lastSample = 0
	local pathA = markers.TagPathA
	local pathB = markers.TagPathB
	for player, session in sessions do
		local root = rootOf(player)
		if root then
			if session.step == "Move" and session.jumped
				and horizontalDistance(root.Position, markers.MoveGoal.Position) <= Config.Tutorial.MoveGoalRadius then
				setStep(player, session, "Dash")
			elseif session.step == "Dash" and session.dashed and os.clock() - session.dashAcceptedAt <= 1
				and horizontalDistance(root.Position, markers.DashGoal.Position) <= Config.Tutorial.DashGoalRadius then
				setStep(player, session, "Sprint")
			elseif session.step == "Sprint" and session.slideCount >= Config.Movement.AutoSprintChainCount
				and os.clock() - session.lastSlideAt <= Config.Movement.SlideDuration + Config.Movement.AutoSprintDuration
				and player:GetAttribute("HRushMovementState") == "Sprint" then
				setStep(player, session, "Tag")
			end
		end
		if session.step == "Tag" and session.target and pathA and pathB then
			local alpha = (math.sin(os.clock() * Config.Tutorial.TagTravelSpeed / 3) + 1) * 0.5
			local position = pathA.Position:Lerp(pathB.Position, alpha) + Vector3.new(0, 3, 0)
			session.target:PivotTo(CFrame.new(position))
		end
	end
end)

RequestTag.OnServerEvent:Connect(function(player: Player)
	local session = sessions[player]
	if not session or session.step ~= "Tag" or not session.target then return end
	local now = os.clock()
	if now - session.lastTag < Config.Tag.ActionRequestInterval then return end
	session.lastTag = now
	if player:GetAttribute("HRushInMatch") ~= true or player:GetAttribute("HRushState") ~= "MS_04"
		or player:GetAttribute("HRushRole") ~= "Taya" or player:GetAttribute("HRushStunned") == true
		or player:GetAttribute("HRushAbilityBusy") == true then return end
	local character = player.Character
	local root = rootOf(player)
	local target = session.target.PrimaryPart
	if not character or not root or not target then return end
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if facing.Magnitude < 0.05 then return end
	local box = CFrame.lookAt(root.Position, root.Position + facing.Unit) * CFrame.new(Config.Tag.ActionHitboxOffset)
	local point = target.Position + Vector3.new(0, Config.Tag.StandingTargetOffset, 0)
	local localPoint = box:PointToObjectSpace(point)
	local half = Config.Tag.ActionHitboxSize * 0.5
	if math.abs(localPoint.X) > half.X or math.abs(localPoint.Y) > half.Y or math.abs(localPoint.Z) > half.Z then return end
	local delta = point - root.Position
	if delta.Magnitude > Config.Tag.ActionRange then return end
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude < 0.05 or flat.Unit:Dot(facing.Unit) < math.cos(math.rad(Config.Tag.ActionMaxAngle)) then return end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { character, session.target }
	ray.IgnoreWater = true
	if Workspace:Raycast(root.Position + Vector3.new(0, 1, 0), point - root.Position - Vector3.new(0, 1, 0), ray) then return end
	setStep(player, session, "Finish")
end)

TutorialEvent.OnServerEvent:Connect(function(player: Player, action: unknown)
	if typeof(action) ~= "string" then return end
	local session = sessions[player]
	if not session then return end
	local now = os.clock()
	if now - session.lastAction < Config.Tutorial.RequestInterval then return end
	session.lastAction = now
	if action == "Ready" then
		notifyState(player, session)
		return
	end
	if action == "RetrySave" and session.step == "Finish"
		and player:GetAttribute("HRushTutorialSaveState") == "Failed" then
		player:SetAttribute("HRushTutorialSaveState", "Saving")
		task.spawn(function()
			local saved = Progress.mark(player.UserId, "complete")
			if player.Parent and sessions[player] == session then
				player:SetAttribute("HRushTutorialSaveState", if saved then "Saved" else "Failed")
				player:SetAttribute("HRushTutorialCompleted", saved)
			end
		end)
	elseif action == "Leave" then
		if session.step == "Finish" and player:GetAttribute("HRushTutorialSaveState") == "Saving" then
			TutorialEvent:FireClient(player, "Error", "Completion is saving. Please wait a moment.")
			return
		end
		if session.returnPlaceId <= 0 or session.returnPlaceId == game.PlaceId then
			TutorialEvent:FireClient(player, "Error", "Lobby destination is unavailable.")
			return
		end
		local ok = pcall(function()
			TeleportService:TeleportAsync(session.returnPlaceId, { player })
		end)
		if not ok then TutorialEvent:FireClient(player, "Error", "Return failed. Please try again.") end
	end
end)

TeleportService.TeleportInitFailed:Connect(function(player: Player)
	if sessions[player] then TutorialEvent:FireClient(player, "Error", "Return failed. Please try again.") end
end)

Players.PlayerRemoving:Connect(function(player)
	local session = sessions[player]
	if not session then return end
	for _, connection in session.connections do connection:Disconnect() end
	if session.beacon then session.beacon:Destroy() end
	if session.gate then session.gate:Destroy() end
	if session.target then session.target:Destroy() end
	sessions[player] = nil
end)

Players.PlayerAdded:Connect(startPlayer)
for _, player in Players:GetPlayers() do startPlayer(player) end
