--!strict
-- ServerScriptService/PanyoMode.lua
-- Owner: Project Owner
-- Responsibility: One authoritative panyo, pickup, steals, possession clock, and recovery.
-- Task/spec: Agawan ng Panyo gameplay mode, approved 2026-10-23.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PanyoEvents = require(ServerScriptService:WaitForChild("PanyoEvents"))
local PanyoEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PanyoEvent") :: RemoteEvent
local rules = Config.Panyo

type Score = {
	player: Player,
	userId: number,
	name: string,
	time: number,
	steals: number,
	left: boolean,
}

local PanyoMode = {}
local roster: { [Player]: Score } = {}
local priority: { [Player]: number } = {}
local candidateSince: { [Player]: number } = {}
local previousPosition: { [Player]: Vector3 } = {}
local previousPositionAt: { [Player]: number } = {}
local invalidUntil: { [Player]: number } = {}
local stealBlockedUntil: { [Player]: number } = {}
local connections: { RBXScriptConnection } = {}
local heartbeat: RBXScriptConnection? = nil
local cloth: Part? = nil
local ring: Part? = nil
local carryWeld: WeldConstraint? = nil
local groundPosition: Vector3? = nil
local lastSafeGround: Vector3? = nil
local carrier: Player? = nil
local carrierSince = 0
local carrierSafeUntil = 0
local roundEndsAt = 0
local nextScorePublish = 0
local stepElapsed = 0
local version = 0
local generation = 0
local prepared = false
local active = false

local function nowTime(): number
	return Workspace:GetServerTimeNow()
end

local function send(eventType: string, data: { [string]: any })
	data.type = eventType
	data.version = version
	for player, score in roster do
		if not score.left and player:IsDescendantOf(Players) then
			PanyoEvent:FireClient(player, data)
		end
	end
end

local events = PanyoEvents.new(function(eventType: string, data: { [string]: any })
	if not active then return end
	if eventType == "Phase" then
		ReplicatedStorage:SetAttribute("HRushPanyoPhase", data.phase)
	end
	data.carrierUserId = if carrier then carrier.UserId else nil
	data.groundPosition = if carrier then nil else groundPosition
	send(eventType, data)
end)

local function inArena(position: Vector3): boolean
	return math.abs(position.X) <= rules.MaxArenaCoordinate
		and math.abs(position.Z) <= rules.MaxArenaCoordinate
		and position.Y >= rules.MinArenaY
		and position.Y <= rules.MaxArenaY
end

local function liveRoot(player: Player): BasePart?
	local score = roster[player]
	if score == nil or score.left or not player:IsDescendantOf(Players)
		or player:GetAttribute("HRushInMatch") ~= true
		or player:GetAttribute("HRushGameMode") ~= "AgawanNgPanyo"
	then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function floorAt(position: Vector3, character: Model?): Vector3?
	if not inArena(position) then return nil end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclusions: { Instance } = {}
	if character then table.insert(exclusions, character) end
	for participant in roster do
		if participant.Character and participant.Character ~= character then
			table.insert(exclusions, participant.Character)
		end
	end
	if cloth then table.insert(exclusions, cloth) end
	if ring then table.insert(exclusions, ring) end
	params.FilterDescendantsInstances = exclusions
	params.IgnoreWater = true
	local result = Workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -80, 0), params)
	if result == nil or result.Normal.Y < 0.7 or not result.Instance.CanCollide then return nil end
	local grounded = result.Position + Vector3.new(0, 0.4, 0)
	if not inArena(grounded) then return nil end
	return grounded
end

local function resolveSpawn(mapId: string): Vector3?
	if mapId ~= "Kalsada" then return nil end
	local greybox = Workspace:FindFirstChild("KalsadaGreybox")
	local marker = greybox and greybox:FindFirstChild("PanyoSpawn")
	if marker and marker:IsA("BasePart") then
		local position = floorAt(marker.Position, nil)
		if position then return position end
	end
	return floorAt(Vector3.new(0, 3, 0), nil)
end

local function clearVisual()
	if carryWeld then carryWeld:Destroy() carryWeld = nil end
	if cloth then cloth:Destroy() cloth = nil end
	if ring then ring:Destroy() ring = nil end
end

local function ensureVisual()
	if cloth == nil or cloth.Parent == nil then
		local part = Instance.new("Part")
		part.Name = "HRUSH_Panyo"
		part.Size = Vector3.new(1.15, 0.08, 1.15)
		part.Color = Color3.fromRGB(255, 239, 160)
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Anchored = true
		part.Parent = Workspace
		local surface = Instance.new("SurfaceGui")
		surface.Name = "PanyoPattern"
		surface.Face = Enum.NormalId.Top
		surface.AlwaysOnTop = false
		surface.Parent = part
		local pattern = Instance.new("TextLabel")
		pattern.Size = UDim2.fromScale(1, 1)
		pattern.BackgroundTransparency = 1
		pattern.Font = Enum.Font.GothamBold
		pattern.Text = "P"
		pattern.TextScaled = true
		pattern.TextColor3 = Color3.fromRGB(226, 86, 79)
		pattern.Parent = surface
		cloth = part
	end
	if ring == nil or ring.Parent == nil then
		local part = Instance.new("Part")
		part.Name = "HRUSH_PanyoPickupRing"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(rules.PickupRadius * 2, 0.08, rules.PickupRadius * 2)
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 221, 100)
		part.Transparency = 0.72
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Parent = Workspace
		ring = part
	end
end

local function showOnGround(position: Vector3)
	ensureVisual()
	if carryWeld then carryWeld:Destroy() carryWeld = nil end
	local part = cloth :: Part
	part.Anchored = true
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(45), math.rad(5))
	local glow = ring :: Part
	glow.CFrame = CFrame.new(position.X, position.Y - 0.32, position.Z)
	glow.Transparency = 0.72
	groundPosition = position
	ReplicatedStorage:SetAttribute("HRushPanyoState", "Neutral")
end

local function attachTo(player: Player): boolean
	local character = player.Character
	local hand = character and (character:FindFirstChild("LeftHand") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart"))
	if hand == nil or not hand:IsA("BasePart") then return false end
	ensureVisual()
	if carryWeld then carryWeld:Destroy() carryWeld = nil end
	local part = cloth :: Part
	part.Anchored = false
	part.CFrame = hand.CFrame * CFrame.new(0, -0.35, -0.15) * CFrame.Angles(0, math.rad(45), 0)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "HRUSH_PanyoCarryWeld"
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
	carryWeld = weld
	local groundRing = ring :: Part
	groundRing.Transparency = 1
	groundPosition = nil
	ReplicatedStorage:SetAttribute("HRushPanyoState", "Carried")
	return true
end

local function closeCarrierInterval(atTime: number)
	if carrier == nil then return end
	local score = roster[carrier]
	if score then
		score.time += math.max(0, math.min(atTime, roundEndsAt) - carrierSince)
	end
	carrierSince = 0
end

local function publishScores(atTime: number)
	for player, score in roster do
		if not score.left and player:IsDescendantOf(Players) then
			local held = score.time
			if active and player == carrier then
				held += math.max(0, math.min(atTime, roundEndsAt) - carrierSince)
			end
			player:SetAttribute("HRushPanyoTime", math.floor(held * 10) / 10)
			player:SetAttribute("HRushPanyoPoints", math.floor(held + 0.000001))
			player:SetAttribute("HRushPanyoSteals", score.steals)
		end
	end
end

local function drop(reason: string, atTime: number)
	local previous = carrier
	if previous == nil then return end
	closeCarrierInterval(atTime)
	stealBlockedUntil[previous] = atTime + rules.DropBlock
	carrier = nil
	carrierSafeUntil = 0
	version += 1
	local position = if lastSafeGround and lastSafeGround.Y <= 5 then lastSafeGround else resolveSpawn("Kalsada")
	if position then showOnGround(position) end
	ReplicatedStorage:SetAttribute("HRushPanyoCarrierUserId", nil)
	ReplicatedStorage:SetAttribute("HRushPanyoVersion", version)
	table.clear(candidateSince)
	publishScores(atTime)
	send("Drop", { fromUserId = previous.UserId, reason = reason, groundPosition = position })
end

local function claim(player: Player, reason: string, atTime: number): boolean
	local previous = carrier
	if previous == player then return false end
	if not attachTo(player) then return false end
	if previous then
		closeCarrierInterval(atTime)
		stealBlockedUntil[previous] = atTime + rules.PreviousCarrierBlock
	end
	carrier = player
	carrierSince = atTime
	carrierSafeUntil = atTime + rules.NewCarrierSafe
	lastSafeGround = floorAt((liveRoot(player) :: BasePart).Position, player.Character) or lastSafeGround
	version += 1
	ReplicatedStorage:SetAttribute("HRushPanyoCarrierUserId", player.UserId)
	ReplicatedStorage:SetAttribute("HRushPanyoVersion", version)
	if reason == "Steal" then
		local score = roster[player]
		if score then score.steals += 1 end
	end
	table.clear(candidateSince)
	publishScores(atTime)
	send(reason, {
		fromUserId = if previous then previous.UserId else nil,
		toUserId = player.UserId,
		carrierSafeUntil = carrierSafeUntil,
	})
	return true
end

local function hasPickupLine(root: BasePart, position: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local excluded: { Instance } = { cloth :: Part, ring :: Part }
	for participant in roster do
		if participant.Character then table.insert(excluded, participant.Character) end
	end
	params.FilterDescendantsInstances = excluded
	params.IgnoreWater = true
	local origin = root.Position + Vector3.new(0, 1, 0)
	return Workspace:Raycast(origin, position - origin, params) == nil
end

local function samplePickup(now: number)
	local position = groundPosition
	if position == nil then return end
	local chosen: Player? = nil
	local chosenSince = math.huge
	for player, score in roster do
		if not score.left then
			local root = liveRoot(player)
			if root then
				local previous = previousPosition[player]
				local previousAt = previousPositionAt[player]
				if previous and previousAt then
					local allowance = rules.MaxObservedSpeed * math.max(0.05, now - previousAt) + rules.PositionSlack
					if (root.Position - previous).Magnitude > allowance then
						invalidUntil[player] = now + rules.InvalidMoveCooldown
						candidateSince[player] = nil
					end
				end
				previousPosition[player] = root.Position
				previousPositionAt[player] = now
				if now >= (invalidUntil[player] or 0)
					and now >= (stealBlockedUntil[player] or 0)
					and inArena(root.Position)
					and (root.Position - position).Magnitude <= rules.PickupRadius
					and hasPickupLine(root, position)
				then
					candidateSince[player] = candidateSince[player] or now
					local entered = candidateSince[player]
					if now - entered >= rules.PickupHold
						and (entered < chosenSince - 0.0001
							or (math.abs(entered - chosenSince) <= 0.0001 and (priority[player] or math.huge) < (if chosen then priority[chosen] or math.huge else math.huge)))
					then
						chosen = player
						chosenSince = entered
					end
				else
					candidateSince[player] = nil
				end
			else
				candidateSince[player] = nil
			end
		end
	end
	if chosen then claim(chosen, "Pickup", now) end
end

local function step(now: number)
	if not active then return end
	if now >= roundEndsAt then return end
	local current = carrier
	if current then
		local root = liveRoot(current)
		if root == nil or not inArena(root.Position) then
			drop("Unavailable", now)
		else
			local oldPosition = previousPosition[current]
			local oldTime = previousPositionAt[current]
			previousPosition[current] = root.Position
			previousPositionAt[current] = now
			local allowance = rules.MaxObservedSpeed * math.max(0.05, now - (oldTime or now)) + rules.PositionSlack
			if oldPosition and (root.Position - oldPosition).Magnitude > allowance then
				invalidUntil[current] = now + rules.InvalidMoveCooldown
				drop("Teleport", now)
			else
				local safe = floorAt(root.Position, current.Character)
				if safe then lastSafeGround = safe end
				if cloth == nil or cloth.Parent == nil or carryWeld == nil or carryWeld.Parent == nil then
					attachTo(current)
				end
			end
		end
	else
		if groundPosition == nil then
			local fallback = resolveSpawn("Kalsada")
			if fallback then showOnGround(fallback) end
		elseif cloth == nil or cloth.Parent == nil or ring == nil or ring.Parent == nil then
			showOnGround(groundPosition)
		end
		samplePickup(now)
	end
	events:step(now)
	if now >= nextScorePublish then
		publishScores(now)
		nextScorePublish = now + rules.ScorePublishInterval
	end
end

local function disconnectAll()
	if heartbeat then heartbeat:Disconnect() heartbeat = nil end
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
end

function PanyoMode.PrepareRound(players: { Player }, mapId: string, roundNumber: number): boolean
	PanyoMode.EndRound()
	generation += 1
	local token = generation
	local spawnPosition = resolveSpawn(mapId)
	if spawnPosition == nil then return false end
	roster = {}
	priority = {}
	candidateSince = {}
	previousPosition = {}
	previousPositionAt = {}
	invalidUntil = {}
	stealBlockedUntil = {}
	carrier = nil
	groundPosition = spawnPosition
	lastSafeGround = spawnPosition
	version = 0
	local sorted = table.clone(players)
	table.sort(sorted, function(a, b) return a.UserId < b.UserId end)
	for index, player in ipairs(sorted) do
		roster[player] = {
			player = player, userId = player.UserId, name = player.DisplayName,
			time = 0, steals = 0, left = false,
		}
		priority[player] = ((index + roundNumber - 2) % #sorted) + 1
		player:SetAttribute("HRushPanyoTime", 0)
		player:SetAttribute("HRushPanyoPoints", 0)
		player:SetAttribute("HRushPanyoSteals", 0)
		table.insert(connections, player.CharacterRemoving:Connect(function()
			if generation == token and active and carrier == player then drop("Reset", nowTime()) end
		end))
		local function watchCharacter(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if generation ~= token or humanoid == nil or not humanoid:IsA("Humanoid") then return end
			table.insert(connections, humanoid.Died:Connect(function()
				if generation == token and active and carrier == player then drop("Death", nowTime()) end
			end))
		end
		table.insert(connections, player.CharacterAdded:Connect(watchCharacter))
		if player.Character then task.spawn(watchCharacter, player.Character) end
	end
	showOnGround(spawnPosition)
	ReplicatedStorage:SetAttribute("HRushPanyoCarrierUserId", nil)
	ReplicatedStorage:SetAttribute("HRushPanyoVersion", version)
	ReplicatedStorage:SetAttribute("HRushPanyoPhase", "Simula")
	ReplicatedStorage:SetAttribute("HRushPanyoEndsAt", nil)
	prepared = true
	return true
end

function PanyoMode.StartRound(duration: number): boolean
	if not prepared or active or groundPosition == nil then return false end
	local now = nowTime()
	roundEndsAt = now + duration
	nextScorePublish = now
	stepElapsed = 0
	active = true
	for player in roster do
		local root = liveRoot(player)
		if root then
			previousPosition[player] = root.Position
			previousPositionAt[player] = now
		end
	end
	ReplicatedStorage:SetAttribute("HRushPanyoEndsAt", roundEndsAt)
	events:start(roundEndsAt)
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		stepElapsed += dt
		if stepElapsed < rules.PickupPollInterval then return end
		stepElapsed = 0
		step(nowTime())
	end)
	return true
end

function PanyoMode.GetCarrier(): Player?
	return if active then carrier else nil
end

function PanyoMode.CanAttemptSteal(player: Player): boolean
	local now = nowTime()
	return active and now < roundEndsAt and player ~= carrier
		and liveRoot(player) ~= nil and now >= (stealBlockedUntil[player] or 0)
end

function PanyoMode.CanBeStolen(player: Player): boolean
	local now = nowTime()
	return active and now < roundEndsAt and player == carrier
		and now >= carrierSafeUntil and liveRoot(player) ~= nil
end

function PanyoMode.TrySteal(tagger: Player, target: Player): boolean
	if not PanyoMode.CanAttemptSteal(tagger) or not PanyoMode.CanBeStolen(target) then return false end
	return claim(tagger, "Steal", nowTime())
end

function PanyoMode.RemovePlayer(player: Player)
	local score = roster[player]
	if score == nil or score.left then return end
	if carrier == player and active then drop("Disconnect", nowTime()) end
	score.left = true
	candidateSince[player] = nil
	previousPosition[player] = nil
	previousPositionAt[player] = nil
	invalidUntil[player] = nil
	stealBlockedUntil[player] = nil
end

function PanyoMode.EndRound(): { Score }
	if active then
		closeCarrierInterval(math.min(nowTime(), roundEndsAt))
	end
	active = false
	prepared = false
	events:stop()
	disconnectAll()
	publishScores(nowTime())
	local results: { Score } = {}
	for _, score in roster do
		score.time = math.floor(score.time * 1000 + 0.5) / 1000
		table.insert(results, table.clone(score))
	end
	carrier = nil
	groundPosition = nil
	lastSafeGround = nil
	clearVisual()
	ReplicatedStorage:SetAttribute("HRushPanyoCarrierUserId", nil)
	ReplicatedStorage:SetAttribute("HRushPanyoState", "Inactive")
	ReplicatedStorage:SetAttribute("HRushPanyoPhase", nil)
	ReplicatedStorage:SetAttribute("HRushPanyoEndsAt", nil)
	roster = {}
	priority = {}
	candidateSince = {}
	previousPosition = {}
	previousPositionAt = {}
	invalidUntil = {}
	stealBlockedUntil = {}
	return results
end

return PanyoMode
