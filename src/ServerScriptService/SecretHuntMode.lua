--!strict
-- ServerScriptService/SecretHuntMode.lua
-- Owner: Project Owner
-- Responsibility: Private target cycle, captures, protection, streaks, and Hunt phase cues.
-- Task/spec: Lihim na Target full mode, approved 2026-10-23.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local SecretHuntEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SecretHuntEvent") :: RemoteEvent
local rules = Config.SecretHunt

type Score = {
	player: Player,
	userId: number,
	name: string,
	captures: number,
	bestStreak: number,
	streakStartedAt: number?,
	safeUntil: number,
	lastCaptureAt: number,
	spawnIndex: number,
	left: boolean,
}

local SecretHuntMode = {}
local roster: { [Player]: Score } = {}
local targetOf: { [Player]: Player } = {}
local hunterOf: { [Player]: Player } = {}
local previousTarget: { [Player]: Player } = {}
local pairCapturedAt: { [string]: number } = {}
local lastSyncAt: { [Player]: number } = {}
local connections: { RBXScriptConnection } = {}
local deathConnections: { [Player]: RBXScriptConnection } = {}
local heartbeat: RBXScriptConnection? = nil
local rng = Random.new()
local roundNumber = 0
local version = 0
local generation = 0
local phase = "Simula"
local roundEndsAt = 0
local nextHintAt = 0
local stepElapsed = 0
local prepared = false
local active = false

local function nowTime(): number
	return Workspace:GetServerTimeNow()
end

local function send(player: Player, eventType: string, data: { [string]: any }?)
	if player.Parent ~= Players then return end
	local payload: { [string]: any } = { type = eventType, round = roundNumber, version = version }
	if data then
		for key, value in data do payload[key] = value end
	end
	SecretHuntEvent:FireClient(player, payload)
end

local function participants(): { Player }
	local list: { Player } = {}
	for player, score in roster do
		if not score.left and player.Parent == Players then table.insert(list, player) end
	end
	table.sort(list, function(a, b) return a.UserId < b.UserId end)
	return list
end

local function liveRoot(player: Player): BasePart?
	local score = roster[player]
	if score == nil or score.left or player.Parent ~= Players
		or player:GetAttribute("HRushInMatch") ~= true
		or player:GetAttribute("HRushGameMode") ~= "SecretHunt" then
		return nil
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then return nil end
	return root
end

local function finishStreak(player: Player, now: number)
	local score = roster[player]
	if score == nil or score.streakStartedAt == nil then return end
	score.bestStreak = math.max(score.bestStreak, now - score.streakStartedAt)
	score.streakStartedAt = nil
	if player.Parent == Players then
		player:SetAttribute("HRushHuntBestStreak", math.floor(score.bestStreak * 10 + 0.5) / 10)
	end
end

local function pairKey(a: Player, b: Player): string
	return if a.UserId < b.UserId
		then tostring(a.UserId) .. ":" .. tostring(b.UserId)
		else tostring(b.UserId) .. ":" .. tostring(a.UserId)
end

local function shuffled(list: { Player }): { Player }
	local copy = table.clone(list)
	for index = #copy, 2, -1 do
		local choice = rng:NextInteger(1, index)
		copy[index], copy[choice] = copy[choice], copy[index]
	end
	return copy
end

local function cycleQuality(order: { Player }, recentA: Player?, recentB: Player?): number
	local quality = 0
	for index, hunter in ipairs(order) do
		local target = order[(index % #order) + 1]
		if previousTarget[hunter] ~= target then quality += 3 end
		if recentA == nil or recentB == nil
			or not ((hunter == recentA and target == recentB) or (hunter == recentB and target == recentA)) then
			quality += 2
		end
	end
	return quality
end

local function chooseCycle(list: { Player }, recentA: Player?, recentB: Player?): { Player }
	local best = shuffled(list)
	local bestQuality = cycleQuality(best, recentA, recentB)
	local perfect = #list * 5
	for _ = 2, rules.AssignmentAttempts do
		if bestQuality >= perfect then break end
		local candidate = shuffled(list)
		local quality = cycleQuality(candidate, recentA, recentB)
		if quality > bestQuality then best, bestQuality = candidate, quality end
	end
	return best
end

local function sendAssignment(player: Player)
	local target = targetOf[player]
	send(player, "Assignment", { targetUserId = if target then target.UserId else nil, phase = phase,
		endsAt = if active then roundEndsAt else nil })
end

local function assignAll(recentA: Player?, recentB: Player?)
	version += 1
	table.clear(targetOf)
	table.clear(hunterOf)
	local list = participants()
	if #list >= 2 then
		local order = chooseCycle(list, recentA, recentB)
		for index, hunter in ipairs(order) do
			local target = order[(index % #order) + 1]
			targetOf[hunter] = target
			hunterOf[target] = hunter
			previousTarget[hunter] = target
		end
	end
	for _, player in ipairs(list) do sendAssignment(player) end
end

local function inArena(position: Vector3): boolean
	return math.abs(position.X) <= rules.ArenaXzLimit and math.abs(position.Z) <= rules.ArenaXzLimit
		and position.Y >= rules.ArenaMinY and position.Y <= rules.ArenaMaxY
end

local function recover(player: Player, score: Score, now: number)
	local character = player.Character
	if character == nil then return end
	finishStreak(player, now)
	local folder = Workspace:FindFirstChild("SpawnLocations")
	local spawnName = string.format("Spawn%02d", ((score.spawnIndex - 1) % 8) + 1)
	local spawn = folder and folder:FindFirstChild(spawnName)
	local position = if spawn and spawn:IsA("BasePart") then spawn.Position + Vector3.new(0, 3, 0)
		else Vector3.new(0, 5, 0)
	character:PivotTo(CFrame.new(position))
	score.safeUntil = now + rules.RespawnSafe
	player:SetAttribute("HRushHuntSafeUntil", score.safeUntil)
	score.streakStartedAt = now
	send(player, "Recovered")
end

local function currentPhase(now: number): string
	local remaining = math.max(0, roundEndsAt - now)
	if remaining <= rules.Events.HulingHabol then return "HulingHabol" end
	if remaining <= rules.Events.BarangayRush then return "BarangayRush" end
	return "Simula"
end

local function leaderboard()
	local entries = {}
	for _, player in ipairs(participants()) do
		local score = roster[player]
		table.insert(entries, { userId = player.UserId, name = player.DisplayName, captures = score.captures })
	end
	table.sort(entries, function(a, b)
		if a.captures ~= b.captures then return a.captures > b.captures end
		return a.userId < b.userId
	end)
	for _, player in ipairs(participants()) do send(player, "Leaderboard", { entries = entries }) end
end

local function sendHint(player: Player)
	local target = targetOf[player]
	local hunter = hunterOf[player]
	local myRoot = liveRoot(player)
	local targetRoot = if target then liveRoot(target) else nil
	local hunterRoot = if hunter then liveRoot(hunter) else nil
	local distance: number? = nil
	local sector: number? = nil
	if myRoot and targetRoot then
		local delta = targetRoot.Position - myRoot.Position
		distance = math.floor(delta.Magnitude / rules.DistanceBucket + 0.5) * rules.DistanceBucket
		local angle = math.atan2(delta.X, -delta.Z)
		sector = (math.floor(angle / (2 * math.pi) * 8 + 0.5) % 8) + 1
	end
	local danger = myRoot ~= nil and hunterRoot ~= nil
		and (hunterRoot.Position - myRoot.Position).Magnitude <= rules.DangerDistance
	send(player, "Hint", { distance = distance, sector = sector, danger = danger,
		pulseDuration = rules.HintPulseDuration })
end

local function step(now: number)
	if not active then return end
	local nextPhase = currentPhase(now)
	if nextPhase ~= phase then
		phase = nextPhase
		ReplicatedStorage:SetAttribute("HRushHuntPhase", phase)
		for _, player in ipairs(participants()) do send(player, "Phase", { phase = phase }) end
		nextHintAt = now
		if phase == "HulingHabol" then leaderboard() end
	end
	for _, player in ipairs(participants()) do
		local score = roster[player]
		local root = liveRoot(player)
		if root == nil then
			finishStreak(player, now)
		elseif not inArena(root.Position) then
			recover(player, score, now)
		elseif score.streakStartedAt == nil then
			score.streakStartedAt = now
		end
	end
	if now >= nextHintAt and now < roundEndsAt then
		for _, player in ipairs(participants()) do sendHint(player) end
		nextHintAt = now + rules.Events.HintIntervals[phase]
	end
end

local function disconnectAll()
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	for _, connection in deathConnections do connection:Disconnect() end
	table.clear(deathConnections)
	if heartbeat then heartbeat:Disconnect() heartbeat = nil end
end

local function bindCharacter(player: Player, character: Model)
	if deathConnections[player] then deathConnections[player]:Disconnect() end
	local token = generation
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 5)
		if token ~= generation or roster[player] == nil or humanoid == nil or not humanoid:IsA("Humanoid") then return end
		deathConnections[player] = humanoid.Died:Connect(function()
			finishStreak(player, nowTime())
		end)
	end)
end

function SecretHuntMode.PrepareRound(players: { Player }, round: number): boolean
	SecretHuntMode.EndRound()
	generation += 1
	prepared = true
	roundNumber = round
	phase = "Simula"
	version = 0
	roster = {}
	previousTarget = {}
	pairCapturedAt = {}
	lastSyncAt = {}
	for index, player in ipairs(players) do
		if player.Parent == Players then
			roster[player] = { player = player, userId = player.UserId, name = player.DisplayName,
				captures = 0, bestStreak = 0, streakStartedAt = nil, safeUntil = 0,
				lastCaptureAt = 0, spawnIndex = index, left = false }
			player:SetAttribute("HRushHuntCaptures", 0)
			player:SetAttribute("HRushHuntBestStreak", 0)
			player:SetAttribute("HRushHuntSafeUntil", nil)
			table.insert(connections, player.CharacterAdded:Connect(function(character)
				local score = roster[player]
				if score == nil or score.left then return end
				if active then
					score.safeUntil = nowTime() + rules.RespawnSafe
					player:SetAttribute("HRushHuntSafeUntil", score.safeUntil)
				end
				bindCharacter(player, character)
			end))
			table.insert(connections, player.CharacterRemoving:Connect(function()
				finishStreak(player, nowTime())
			end))
			if player.Character then bindCharacter(player, player.Character) end
		end
	end
	ReplicatedStorage:SetAttribute("HRushHuntPhase", phase)
	ReplicatedStorage:SetAttribute("HRushHuntEndsAt", nil)
	assignAll(nil, nil)
	return #participants() > 0
end

function SecretHuntMode.StartRound(duration: number): boolean
	if not prepared or active then return false end
	local now = nowTime()
	active = true
	roundEndsAt = now + duration
	nextHintAt = now
	stepElapsed = 0
	ReplicatedStorage:SetAttribute("HRushHuntEndsAt", roundEndsAt)
	for _, player in ipairs(participants()) do
		local score = roster[player]
		score.safeUntil = now + rules.RespawnSafe
		player:SetAttribute("HRushHuntSafeUntil", score.safeUntil)
		if liveRoot(player) then score.streakStartedAt = now end
		sendAssignment(player)
	end
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		stepElapsed += dt
		if stepElapsed < rules.WatchInterval then return end
		stepElapsed = 0
		step(nowTime())
	end)
	return true
end

function SecretHuntMode.CanAttemptCapture(hunter: Player): boolean
	local score = roster[hunter]
	local root = liveRoot(hunter)
	return active and score ~= nil and not score.left and nowTime() < roundEndsAt
		and targetOf[hunter] ~= nil and root ~= nil and inArena(root.Position)
		and (hunter:GetAttribute("HRushHuntPractice") == true
			or #participants() >= rules.MinContinuePlayers)
		and hunter:GetAttribute("HRushState") == "MS_04"
		and nowTime() - score.lastCaptureAt >= rules.HunterCaptureCooldown
end

function SecretHuntMode.IsAssignedTarget(hunter: Player, target: Player): boolean
	return active and targetOf[hunter] == target and roster[target] ~= nil and not roster[target].left
end

function SecretHuntMode.CanCaptureTarget(hunter: Player, target: Player): boolean
	if not SecretHuntMode.CanAttemptCapture(hunter) or not SecretHuntMode.IsAssignedTarget(hunter, target) then return false end
	local targetScore = roster[target]
	local targetRoot = liveRoot(target)
	local now = nowTime()
	return targetRoot ~= nil and inArena(targetRoot.Position) and targetScore ~= nil and now >= targetScore.safeUntil
		and now - (pairCapturedAt[pairKey(hunter, target)] or -math.huge) >= rules.PairCaptureCooldown
end

function SecretHuntMode.TryCapture(hunter: Player, target: Player): boolean
	if not SecretHuntMode.CanCaptureTarget(hunter, target) then return false end
	local hunterRoot = liveRoot(hunter)
	local targetRoot = liveRoot(target)
	if hunterRoot == nil or targetRoot == nil
		or (targetRoot.Position - hunterRoot.Position).Magnitude > Config.Tag.ActionRange then return false end
	local now = nowTime()
	local hunterScore = roster[hunter]
	local targetScore = roster[target]
	if hunterScore == nil or targetScore == nil then return false end
	hunterScore.captures += 1
	hunterScore.lastCaptureAt = now
	pairCapturedAt[pairKey(hunter, target)] = now
	finishStreak(target, now)
	targetScore.streakStartedAt = now
	targetScore.safeUntil = now + rules.CaptureSafe
	hunter:SetAttribute("HRushHuntCaptures", hunterScore.captures)
	target:SetAttribute("HRushHuntSafeUntil", targetScore.safeUntil)
	send(hunter, "Capture", { captures = hunterScore.captures })
	send(target, "Caught", { safeUntil = targetScore.safeUntil })
	assignAll(hunter, target)
	if phase == "HulingHabol" then leaderboard() end
	return true
end

function SecretHuntMode.RemovePlayer(player: Player)
	local score = roster[player]
	if score == nil or score.left then return end
	finishStreak(player, nowTime())
	score.left = true
	if deathConnections[player] then deathConnections[player]:Disconnect() deathConnections[player] = nil end
	if prepared then assignAll(nil, nil) end
end

function SecretHuntMode.EndRound(): { Score }
	local results: { Score } = {}
	if prepared then
		local now = nowTime()
		for player, score in roster do
			finishStreak(player, now)
			table.insert(results, score)
			if player.Parent == Players then
				send(player, "Close")
				player:SetAttribute("HRushHuntSafeUntil", nil)
				player:SetAttribute("HRushHuntCaptures", nil)
				player:SetAttribute("HRushHuntBestStreak", nil)
			end
		end
	end
	disconnectAll()
	prepared = false
	active = false
	roundEndsAt = 0
	ReplicatedStorage:SetAttribute("HRushHuntPhase", nil)
	ReplicatedStorage:SetAttribute("HRushHuntEndsAt", nil)
	table.clear(targetOf)
	table.clear(hunterOf)
	table.clear(previousTarget)
	table.clear(pairCapturedAt)
	table.clear(lastSyncAt)
	roster = {}
	return results
end

SecretHuntEvent.OnServerEvent:Connect(function(player: Player, action: unknown)
	if action ~= "Sync" or not prepared then return end
	local score = roster[player]
	if score == nil or score.left or player:GetAttribute("HRushInMatch") ~= true
		or player:GetAttribute("HRushGameMode") ~= "SecretHunt" then return end
	local now = nowTime()
	if now - (lastSyncAt[player] or -math.huge) < rules.SyncRequestInterval then return end
	lastSyncAt[player] = now
	sendAssignment(player)
	if active then sendHint(player) end
	if phase == "HulingHabol" then leaderboard() end
end)

return SecretHuntMode
