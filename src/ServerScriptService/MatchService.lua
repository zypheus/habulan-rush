--!strict
-- ServerScriptService/MatchService.server.lua   (v1.1 - queue + bot fill + lobby/match separation)
-- Owner: Programmer A (T07)
-- Responsibility: State machine (MS_01->MS_06), shuffle bag, scoring,
--                 phase timers, disconnect handling, PLAY queue and test bots.
--
-- NEW IN v1.1
--   * Match no longer auto-starts. A player must press FIND MATCH (client fires
--     Remotes.QueueEvent "Play"). A 10 s search begins; if the lobby is not full
--     when it ends, bots fill the match (testing). Set Config.Match.AllowBots=false to disable.
--   * Only players who queued take part in a match ("inMatch"). Everyone else stays in lobby.
--   * Per-player attributes drive the client UI:
--       HRushInMatch (bool)        -> lobby UI hidden / match HUD (stamina, dash, role) shown
--       HRushQueue   (string)      -> "Idle" | "Searching" | "InMatch" | "Busy"
--       HRushSearchEndsAt (number) -> workspace:GetServerTimeNow() when search ends
--       HRushState   (string)      -> "MS_01" for anyone not in the match, real state otherwise
--   * Bots are Models in Workspace.Bots (attribute IsBot=true). Roles/scores are keyed by Instance
--     (Player or bot Model), so everything below treats them as "participants".

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")

local Config       = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local TagEvent     = Remotes:WaitForChild("TagEvent") :: RemoteEvent

-- QueueEvent is created here if your Remotes setup script doesn't define it yet
local QueueEvent: RemoteEvent
do
	local existing = Remotes:FindFirstChild("QueueEvent")
	if existing and existing:IsA("RemoteEvent") then
		QueueEvent = existing
	else
		local ev = Instance.new("RemoteEvent")
		ev.Name = "QueueEvent"
		ev.Parent = Remotes
		QueueEvent = ev
	end
end

local IS_STUDIO = RunService:IsStudio()
local MATCH = Config.Match
local MIN_PLAYERS = IS_STUDIO and 1 or MATCH.MinPlayers
local MAX_PLAYERS: number = MATCH.MaxPlayers or 8
local SEARCH_TIMEOUT: number = MATCH.SearchTimeout or 10
local BOT_FILL_TARGET: number = MATCH.BotFillTarget or 4 -- total participants after bot fill
local ALLOW_BOTS: boolean = (MATCH.AllowBots == nil) and true or MATCH.AllowBots -- set false for release
local TAG_RANGE: number = (Config.Tag.TouchTagRange or 3) + 1.5 -- centre-to-centre studs (HRP distance is larger than hand reach)
local TAG_IMMUNITY: number = Config.Tag.SafeWindowDuration or 2 -- Safe Window: ex-Taya cannot be re-tagged for this long
local ARENA_RADIUS: number = (Config.Maps and Config.Maps.Kalsada and Config.Maps.Kalsada.greybox and Config.Maps.Kalsada.greybox.spawnRadius) or 55

-- ============================================================
-- HELPERS (participants = Player or bot Model)
-- ============================================================
local function isPresent(inst: Instance): boolean
	return inst:IsDescendantOf(Players) or inst:IsDescendantOf(Workspace)
end

local function getRoot(inst: Instance): BasePart?
	if inst:IsA("Player") then
		local c = inst.Character
		return c and c.PrimaryPart
	elseif inst:IsA("Model") then
		return inst.PrimaryPart
	end
	return nil
end

-- ============================================================
-- SHUFFLE BAG CLASS (§2.1 / T-CORE-03)
-- ============================================================
local ShuffleBag = {}
ShuffleBag.__index = ShuffleBag

type ShuffleBagImpl = {
	bag: { Instance },
	Refill: (self: ShuffleBagImpl, active: { Instance }) -> (),
	Draw: (self: ShuffleBagImpl, active: { Instance }) -> Instance?,
	RemovePlayer: (self: ShuffleBagImpl, who: Instance) -> (),
	Reset: (self: ShuffleBagImpl) -> (),
	GetRemainingCount: (self: ShuffleBagImpl) -> number,
}

function ShuffleBag.new(): ShuffleBagImpl
	local self = setmetatable({}, ShuffleBag)
	self.bag = {}
	return (self :: any) :: ShuffleBagImpl
end

function ShuffleBag:Refill(active: { Instance })
	self.bag = {}
	for _, p in ipairs(active) do
		if isPresent(p) then
			table.insert(self.bag, p)
		end
	end
	local rng = Random.new()
	for i = #self.bag, 2, -1 do
		local j = rng:NextInteger(1, i)
		self.bag[i], self.bag[j] = self.bag[j], self.bag[i]
	end
	print(string.format("[MatchService.ShuffleBag] Refilled and shuffled bag with %d participants.", #self.bag))
end

function ShuffleBag:Draw(active: { Instance }): Instance?
	for i = #self.bag, 1, -1 do
		if not isPresent(self.bag[i]) then
			table.remove(self.bag, i)
		end
	end
	if #self.bag == 0 then
		self:Refill(active)
	end
	if #self.bag == 0 then
		return nil
	end
	local picked = table.remove(self.bag) :: Instance
	print(string.format("[MatchService.ShuffleBag] Picked '%s' as initial Taya (%d remaining in bag).", picked.Name, #self.bag))
	return picked
end

function ShuffleBag:RemovePlayer(who: Instance)
	for i = #self.bag, 1, -1 do
		if self.bag[i] == who then
			table.remove(self.bag, i)
			print(string.format("[MatchService.ShuffleBag] Removed leaver '%s' from bag (%d left).", who.Name, #self.bag))
		end
	end
end

function ShuffleBag:Reset()
	self.bag = {}
end

function ShuffleBag:GetRemainingCount(): number
	return #self.bag
end

-- ============================================================
-- STATE
-- ============================================================
local tayaBag = ShuffleBag.new()
local matchState: string = "MS_01" -- MS_01 Lobby, MS_02 Draft, MS_03 Countdown, MS_04 Live, MS_05 RoundEnd, MS_06 MatchEnd
local currentRound: number = 1
local currentTaya: Instance? = nil
local playerRoles: { [Instance]: string } = {}
local tayaTimeThisRound: { [Instance]: number } = {}
local totalTayaTime: { [Instance]: number } = {}
local matchPoints: { [Instance]: number } = {}
local immuneUntil: { [Instance]: number } = {}
local matchRunning = false
local roundActive = false

local queued: { [Player]: boolean } = {}   -- pressed FIND MATCH, waiting for search to finish
local inMatch: { [Player]: boolean } = {}  -- real players taking part in the current match
local bots: { Model } = {}
local searchEndsAt: number? = nil

local botsFolder = Workspace:FindFirstChild("Bots")
if not botsFolder then
	local f = Instance.new("Folder")
	f.Name = "Bots"
	f.Parent = Workspace
	botsFolder = f
end
local botsFolderRef = botsFolder :: Instance

local function getParticipants(): { Instance }
	local list: { Instance } = {}
	for p in pairs(inMatch) do
		if p:IsDescendantOf(Players) then
			table.insert(list, p)
		end
	end
	for _, b in ipairs(bots) do
		if b.Parent then
			table.insert(list, b)
		end
	end
	return list
end

local function realParticipantCount(): number
	local n = 0
	for p in pairs(inMatch) do
		if p:IsDescendantOf(Players) then
			n += 1
		end
	end
	return n
end

local function countQueued(): number
	local n = 0
	for p in pairs(queued) do
		if p:IsDescendantOf(Players) then
			n += 1
		else
			queued[p] = nil
		end
	end
	return n
end

-- Broadcast state & roles. Players outside the match always see MS_01 (lobby).
local function broadcastState(targetPlayer: Player?, optionalTimer: number?)
	local serverTime = optionalTimer or workspace:GetServerTimeNow()
	local targets = targetPlayer and { targetPlayer } or Players:GetPlayers()
	ReplicatedStorage:SetAttribute("HRushMatchState", matchState)
	ReplicatedStorage:SetAttribute("HRushRoundState", matchState)

	for _, p in ipairs(targets) do
		local isIn = inMatch[p] == true
		local shownState = isIn and matchState or "MS_01"
		local role = isIn and (playerRoles[p] or "Runner") or "Runner"
		p:SetAttribute("HRushInMatch", isIn)
		p:SetAttribute("HRushState", shownState)
		p:SetAttribute("HRushRole", role)
		p:SetAttribute("HRushRound", currentRound)

		StateChanged:FireClient(p, {
			state = shownState,
			role = role,
			round = currentRound,
			timer = serverTime,
		})
	end
end

local function setRoles(initialTaya: Instance)
	currentTaya = initialTaya
	for _, p in ipairs(getParticipants()) do
		local role = (p == initialTaya) and "Taya" or "Runner"
		playerRoles[p] = role
		p:SetAttribute("HRushRole", role)
	end
	broadcastState(nil)
	print(string.format("[MatchService] Round %d roles assigned: Taya = %s", currentRound, initialTaya.Name))
end

local function transferTaya(from: Instance, to: Instance)
	playerRoles[from] = "Runner"
	playerRoles[to] = "Taya"
	currentTaya = to
	immuneUntil[from] = os.clock() + TAG_IMMUNITY
	from:SetAttribute("HRushRole", "Runner")
	to:SetAttribute("HRushRole", "Taya")
	broadcastState(nil)

	-- MovementController listens for { taggerId, targetId } to give the ex-Taya the +20% boost (F08).
	-- Bots have no UserId, so they are sent as 0.
	local payload = {
		taggerId = from:IsA("Player") and from.UserId or 0,
		targetId = to:IsA("Player") and to.UserId or 0,
	}
	for p in pairs(inMatch) do
		if p:IsDescendantOf(Players) then
			TagEvent:FireClient(p, payload)
		end
	end
	print(string.format("[MatchService] Tag transfer: %s tagged %s (new Taya)", from.Name, to.Name))
end

-- ============================================================
-- BOTS (testing only)
-- ============================================================
local BOT_NAMES = { "Bot_Juan", "Bot_Maria", "Bot_Pedro", "Bot_Ana", "Bot_Lito", "Bot_Cora", "Bot_Dodong" }

-- The rig is built ONCE (a web call that can take seconds) and cloned per bot,
-- so spawning bots at match start is instant. It is also pre-built at server start.
local botTemplate: Model? = nil
local function getBotTemplate(): Model?
	if botTemplate then
		return botTemplate
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		botTemplate = model
	else
		warn("[MatchService] Failed to create bot template: " .. tostring(model))
	end
	return botTemplate
end

if ALLOW_BOTS then
	task.spawn(getBotTemplate)
end

local function spawnBots(count: number)
	local template = getBotTemplate()
	if not template then
		return
	end
	for i = 1, count do
		local model = template:Clone()
		model.Name = BOT_NAMES[i] or ("Bot_" .. i)
		model:SetAttribute("IsBot", true)
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayName = model.Name
		end
		model.Parent = botsFolderRef
		pcall(function()
			local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart
			hrp:SetNetworkOwner(nil)
		end)
		table.insert(bots, model)
	end
	print(string.format("[MatchService] Spawned %d bot(s).", #bots))
end

local function clearBots()
	for _, b in ipairs(bots) do
		b:Destroy()
	end
	bots = {}
end

local wanderUntil: { [Model]: number } = {}

local function updateBots(now: number)
	for _, bot in ipairs(bots) do
		local hum = bot:FindFirstChildOfClass("Humanoid")
		local root = bot.PrimaryPart
		if bot.Parent and hum and root then
			if playerRoles[bot] == "Taya" then
				local best: Instance? = nil
				local bestDist = math.huge
				for _, other in ipairs(getParticipants()) do
					if other ~= bot and playerRoles[other] == "Runner" and (immuneUntil[other] or 0) < now then
						local r = getRoot(other)
						if r then
							local d = (r.Position - root.Position).Magnitude
							if d < bestDist then
								bestDist = d
								best = other
							end
						end
					end
				end
				if best then
					local br = getRoot(best)
					hum.WalkSpeed = Config.Movement.TayaSpeed
					if br then
						hum:MoveTo(br.Position)
					end
					if bestDist <= TAG_RANGE and (immuneUntil[bot] or 0) < now then
						transferTaya(bot, best)
					end
				end
			else
				hum.WalkSpeed = Config.Movement.RunnerWalkSpeed
				local tayaRoot = currentTaya and getRoot(currentTaya)
				if tayaRoot and (tayaRoot.Position - root.Position).Magnitude < 28 then
					-- flee from Taya, clamped to the arena
					local away = (root.Position - tayaRoot.Position) * Vector3.new(1, 0, 1)
					local dir = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
					local target = root.Position + dir * 18
					local flat = Vector3.new(target.X, 0, target.Z)
					if flat.Magnitude > ARENA_RADIUS then
						flat = flat.Unit * ARENA_RADIUS
						target = Vector3.new(flat.X, root.Position.Y, flat.Z)
					end
					hum:MoveTo(target)
				elseif (wanderUntil[bot] or 0) < now then
					local ang = math.random() * math.pi * 2
					local rad = math.random() * ARENA_RADIUS * 0.8
					hum:MoveTo(Vector3.new(math.cos(ang) * rad, root.Position.Y, math.sin(ang) * rad))
					wanderUntil[bot] = now + 3
				end
			end
		end
	end
end

-- ============================================================
-- TELEPORT
-- ============================================================
local function teleportToSpawns(list: { Instance })
	local spawnFolder = Workspace:FindFirstChild("SpawnLocations")
	local n = #list

	for idx, inst in ipairs(list) do
		task.spawn(function()
			local model: Model? = nil
			if inst:IsA("Player") then
				local char = inst.Character
				if not char then
					char = inst.CharacterAdded:Wait()
				end
				model = char
			elseif inst:IsA("Model") then
				model = inst
			end

			if model then
				model:WaitForChild("HumanoidRootPart", 5)
				local spawnName = string.format("Spawn%02d", ((idx - 1) % 8) + 1)
				local spawnObj = spawnFolder and spawnFolder:FindFirstChild(spawnName)
				local spawnPos: Vector3
				if spawnObj and spawnObj:IsA("BasePart") then
					spawnPos = spawnObj.Position + Vector3.new(0, 3, 0)
				else
					local angle = math.rad((idx - 1) * (360 / math.max(1, n)))
					spawnPos = Vector3.new(math.cos(angle) * ARENA_RADIUS, 3, math.sin(angle) * ARENA_RADIUS)
				end
				model:PivotTo(CFrame.new(spawnPos, Vector3.new(0, 3, 0)))
			end
		end)
	end
end

-- ============================================================
-- DISCONNECT / JOIN HANDLING (§8 / F18)
-- ============================================================
local function promoteNearestRunnerToTaya(gone: Instance)
	if not roundActive then return end

	local nearest: Instance? = nil
	local shortest = math.huge
	local goneRoot = getRoot(gone)
	local lastPos = goneRoot and goneRoot.Position or Vector3.zero

	for _, p in ipairs(getParticipants()) do
		if p ~= gone and playerRoles[p] == "Runner" then
			local r = getRoot(p)
			if r then
				local d = (r.Position - lastPos).Magnitude
				if d < shortest then
					shortest = d
					nearest = p
				end
			end
		end
	end

	if nearest then
		print(string.format("[MatchService] Taya left! Nearest Runner '%s' promoted to Taya.", nearest.Name))
		currentTaya = nearest
		playerRoles[nearest] = "Taya"
		nearest:SetAttribute("HRushRole", "Taya")
		broadcastState(nil)
	end
end

local function initPlayer(player: Player)
	player:SetAttribute("HRushInMatch", false)
	player:SetAttribute("HRushQueue", "Idle")
	player:SetAttribute("HRushState", "MS_01")
	player:SetAttribute("HRushRole", "Runner")
end

Players.PlayerAdded:Connect(initPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	initPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	tayaBag:RemovePlayer(player)
	queued[player] = nil

	if currentTaya == player and matchState == "MS_04" then
		promoteNearestRunnerToTaya(player)
	end

	inMatch[player] = nil
	playerRoles[player] = nil
end)

-- ============================================================
-- REMOTES
-- ============================================================
QueueEvent.OnServerEvent:Connect(function(player, action)
	if action == "Play" then
		if matchState ~= "MS_01" or inMatch[player] then
			-- match already running: tell the client, then reset
			player:SetAttribute("HRushQueue", "Busy")
			task.delay(2, function()
				if player.Parent and player:GetAttribute("HRushQueue") == "Busy" then
					player:SetAttribute("HRushQueue", "Idle")
				end
			end)
			return
		end
		queued[player] = true
		player:SetAttribute("HRushQueue", "Searching")
		player:SetAttribute("HRushSearchEndsAt", searchEndsAt)
	elseif action == "Cancel" then
		if queued[player] then
			queued[player] = nil
			player:SetAttribute("HRushQueue", "Idle")
			player:SetAttribute("HRushSearchEndsAt", nil)
		end
	end
end)

-- Tag requests from the Taya's client. Validated on the server (sender must be the Taya, in range).
-- Payload: { targetId = UserId } for players, or { targetBot = "Bot_Juan" } for bots.
TagEvent.OnServerEvent:Connect(function(player, payload)
	if matchState ~= "MS_04" or typeof(payload) ~= "table" then return end
	if currentTaya ~= player or playerRoles[player] ~= "Taya" then return end

	local target: Instance? = nil
	if payload.targetId then
		target = Players:GetPlayerByUserId(payload.targetId)
	elseif typeof(payload.targetBot) == "string" then
		target = botsFolderRef:FindFirstChild(payload.targetBot)
	end

	if not target or playerRoles[target] ~= "Runner" then return end
	if (immuneUntil[target] or 0) > os.clock() then return end

	local a, b = getRoot(player), getRoot(target)
	if a and b and (a.Position - b.Position).Magnitude > TAG_RANGE * 3 then return end

	transferTaya(player, target)
end)

-- ============================================================
-- MATCH LOOP (MS_01 -> MS_06)
-- ============================================================
-- TEMPORARY server-side touch tag for a real-player Taya (bots tag inside updateBots).
-- TagService (T11) is still a stub; when it is implemented, delete this and have TagService
-- call the transfer logic instead.
local function checkPlayerTouchTag(now: number)
	local taya = currentTaya
	if not taya or not taya:IsA("Player") or playerRoles[taya] ~= "Taya" then
		return
	end
	local tr = getRoot(taya)
	if not tr then
		return
	end

	local best: Instance? = nil
	local bestDist = TAG_RANGE
	for _, other in ipairs(getParticipants()) do
		if other ~= taya and playerRoles[other] == "Runner" and (immuneUntil[other] or 0) < now then
			local r = getRoot(other)
			if r then
				local d = (r.Position - tr.Position).Magnitude
				if d <= bestDist then
					bestDist = d
					best = other
				end
			end
		end
	end
	if best then
		transferTaya(taya, best)
	end
end

-- Waits for a phase and publishes its end time so the client loading screen can show an accurate countdown.
local function waitPhase(seconds: number)
	ReplicatedStorage:SetAttribute("HRushPhaseEndsAt", workspace:GetServerTimeNow() + seconds)
	task.wait(seconds)
end

local function returnToLobby()
	local returning: { Player } = {}
	for p in pairs(inMatch) do
		table.insert(returning, p)
	end

	matchState = "MS_01"
	currentRound = 1
	currentTaya = nil
	roundActive = false
	searchEndsAt = nil
	tayaBag:Reset()
	totalTayaTime = {}
	matchPoints = {}
	tayaTimeThisRound = {}
	playerRoles = {}
	immuneUntil = {}
	inMatch = {}
	clearBots()

	for _, p in ipairs(Players:GetPlayers()) do
		if not queued[p] then
			p:SetAttribute("HRushQueue", "Idle")
		end
		p:SetAttribute("HRushSearchEndsAt", nil)
	end
	broadcastState(nil)

	-- respawn finished players at the lobby spawn
	for _, p in ipairs(returning) do
		if p.Parent then
			task.spawn(function()
				pcall(function()
					p:LoadCharacter()
				end)
			end)
		end
	end
end

local function runMatch()
	if matchRunning then return end
	matchRunning = true
	print("[MatchService] Match loop initialized.")

	while true do
		returnToLobby()
		print("[MatchService] In Lobby. Waiting for a player to press FIND MATCH...")

		-- wait for someone to queue
		while countQueued() == 0 do
			task.wait(0.25)
		end

		-- ===== SEARCH PHASE =====
		searchEndsAt = workspace:GetServerTimeNow() + SEARCH_TIMEOUT
		local searchStart = os.clock()
		local botsNeeded = 0
		local aborted = false

		while true do
			task.wait(0.25)
			local q = countQueued()
			if q == 0 then
				aborted = true
				break
			end
			for p in pairs(queued) do
				p:SetAttribute("HRushSearchEndsAt", searchEndsAt)
			end
			if q >= MAX_PLAYERS then
				break
			end
			if os.clock() - searchStart >= SEARCH_TIMEOUT then
				if ALLOW_BOTS then
					botsNeeded = math.max(0, BOT_FILL_TARGET - q)
					break
				elseif q >= MIN_PLAYERS then
					break
				else
					-- not enough real players and no bots: keep searching
					searchStart = os.clock()
					searchEndsAt = workspace:GetServerTimeNow() + SEARCH_TIMEOUT
				end
			end
		end
		searchEndsAt = nil
		if aborted then
			continue
		end

		-- ===== BUILD THE MATCH =====
		for p in pairs(queued) do
			if p:IsDescendantOf(Players) then
				inMatch[p] = true
				p:SetAttribute("HRushQueue", "InMatch")
				p:SetAttribute("HRushSearchEndsAt", nil)
			end
		end
		queued = {}
		broadcastState(nil) -- clients show the LOADING SCREEN immediately (HRushInMatch = true)
		if botsNeeded > 0 then
			print(string.format("[MatchService] Search timed out. Filling with %d bot(s).", botsNeeded))
			spawnBots(botsNeeded)
		end
		-- Place everyone in the arena while the loading screen still covers the view.
		teleportToSpawns(getParticipants())
		task.wait(0.5)

		local totalRounds: number = MATCH.TotalRounds or 3
		local abort = false

		for roundNum = 1, totalRounds do
			currentRound = roundNum
			tayaTimeThisRound = {}
			for _, p in ipairs(getParticipants()) do
				tayaTimeThisRound[p] = 0
				totalTayaTime[p] = totalTayaTime[p] or 0
				matchPoints[p] = matchPoints[p] or 0
			end

			-- MS_02 SKILL DRAFT
			matchState = "MS_02"
			broadcastState(nil)
			local draftDuration: number = MATCH.DraftDuration or 12
			print(string.format("[MatchService] Round %d: MS_02 Skill Draft (%d s)", currentRound, draftDuration))
			waitPhase(IS_STUDIO and 2 or draftDuration)

			-- MS_03 COUNTDOWN
			matchState = "MS_03"
			local participants = getParticipants()
			if realParticipantCount() == 0 then
				print("[MatchService] No real players left; aborting match.")
				abort = true
				break
			end

			teleportToSpawns(participants)

			-- randomized Taya via shuffle bag (§2.1 / T-CORE-03)
			local startingTaya = tayaBag:Draw(participants) or participants[1]
			setRoles(startingTaya)
			local cdDuration: number = MATCH.CountdownDuration or 5
			print(string.format("[MatchService] Round %d: MS_03 Countdown (%d s). Starting Taya: %s", currentRound, cdDuration, startingTaya.Name))
			waitPhase(IS_STUDIO and 3 or cdDuration)

			-- MS_04 ROUND LIVE
			matchState = "MS_04"
			roundActive = true
			broadcastState(nil)
			local roundDuration: number = MATCH.RoundDuration or 150
			print(string.format("[MatchService] Round %d: MS_04 Round Live (%d s)!", currentRound, roundDuration))

			local startTime = os.clock()
			local lastBotThink = 0.0

			while (os.clock() - startTime) < roundDuration do
				task.wait(0.1)
				local now = os.clock()

				local taya = currentTaya
				if taya and playerRoles[taya] == "Taya" then
					tayaTimeThisRound[taya] = (tayaTimeThisRound[taya] or 0) + 0.1
					totalTayaTime[taya] = (totalTayaTime[taya] or 0) + 0.1
					taya:SetAttribute("HRushTayaTime", math.floor(tayaTimeThisRound[taya] * 10) / 10)
				end

				checkPlayerTouchTag(now)

				if #bots > 0 and now - lastBotThink >= 0.25 then
					lastBotThink = now
					updateBots(now)
				end

				if realParticipantCount() == 0 then
					print("[MatchService] All real players left during Round Live; aborting match.")
					abort = true
					break
				end
			end
			roundActive = false
			if abort then
				break
			end

			-- MS_05 ROUND END
			matchState = "MS_05"
			broadcastState(nil)
			local roundEndDuration: number = MATCH.RoundEndDuration or 8
			print(string.format("[MatchService] Round %d: MS_05 Round End (%d s). Calculating scores...", currentRound, roundEndDuration))

			local ranked: { { player: Instance, tayaTime: number } } = {}
			for _, p in ipairs(getParticipants()) do
				table.insert(ranked, { player = p, tayaTime = tayaTimeThisRound[p] or 0 })
			end
			table.sort(ranked, function(a, b)
				return a.tayaTime < b.tayaTime
			end)

			local pointsTable: { number } = MATCH.RoundPoints or { 8, 6, 5, 4, 3, 2, 1, 0 }
			for rankIdx, entry in ipairs(ranked) do
				local pts = pointsTable[rankIdx] or 0
				matchPoints[entry.player] = (matchPoints[entry.player] or 0) + pts
				print(string.format("  Rank %d: %s (TayaTime: %.1fs, +%d pts, total: %d)", rankIdx, entry.player.Name, entry.tayaTime, pts, matchPoints[entry.player]))
			end

			task.wait(IS_STUDIO and 3 or roundEndDuration)
		end

		-- MS_06 MATCH END
		if not abort then
			matchState = "MS_06"
			broadcastState(nil)
			local matchEndDuration: number = MATCH.MatchEndDuration or 15
			print(string.format("[MatchService] MS_06 Match End (%d s). Determining Match MVP...", matchEndDuration))

			local finalRankings: { { player: Instance, points: number, totalTaya: number } } = {}
			for _, p in ipairs(getParticipants()) do
				table.insert(finalRankings, {
					player = p,
					points = matchPoints[p] or 0,
					totalTaya = totalTayaTime[p] or 0,
				})
			end
			table.sort(finalRankings, function(a, b)
				if a.points ~= b.points then
					return a.points > b.points
				end
				return a.totalTaya < b.totalTaya
			end)

			if #finalRankings > 0 then
				local winner = finalRankings[1]
				print(string.format("[MatchService] MATCH WINNER: %s with %d points!", winner.player.Name, winner.points))
			end

			task.wait(IS_STUDIO and 5 or matchEndDuration)
		end
		print("[MatchService] Returning to lobby.")
	end
end

task.defer(runMatch)
print("[MatchService] MatchService v1.1 initialized (queue + bot fill + ShuffleBag Taya selection).")
