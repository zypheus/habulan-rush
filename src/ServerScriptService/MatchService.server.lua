--!strict
-- ServerScriptService/MatchService.server.lua   (v1.2 - queue + lobby/match separation, bots removed)
-- Owner: Project Owner
-- Responsibility: Match phases, mode/map votes, MS_RPS first Taya selection, scoring, and fallback bag.
-- Task/spec: MS_RPS first Taya selection, GDD 3.2 / System Spec 2.1 / T-CORE-03.
-- Task/spec: simple click-to-tag server commit, approved 2026-10-18.
-- Task/spec: Agawan ng Panyo Phase 1 mode selection, approved 2026-10-23.
-- Task/spec: Agawan ng Panyo full mode, approved 2026-10-23.
-- Task/spec: Lihim na Target full mode, approved 2026-10-23.
-- Task/spec: open-experience random round spawns, approved 2026-10-24.
-- Task/spec: tutorial teleport queue guard, approved 2026-10-25.
-- Task/spec: search cancellation state guard, 2026-10-25.
--                 phase timers, disconnect handling, and PLAY queue.
--
-- CHANGED IN v1.2
--   * Test bots are deleted everywhere: no fill, no AI, no bot votes, and no
--     client Workspace.Bots scans. Matches contain queueing players only.
--   * A search that times out starts the match with whatever queued (even one
--     player, a tag sandbox). Config.Match.MinPlayers is no longer read here.
--
-- KEPT IN v1.1
--   * Match no longer auto-starts. A player must press FIND MATCH (client fires
--     Remotes.QueueEvent "Play"). A 10 s search begins.
--   * Only players who queued take part in a match ("inMatch"). Everyone else stays in lobby.
--   * Per-player attributes drive the client UI:
--       HRushInMatch (bool)        -> lobby UI hidden / match HUD (stamina, dash, role) shown
--       HRushQueue   (string)      -> "Idle" | "Searching" | "InMatch" | "Busy"
--       HRushSearchEndsAt (number) -> workspace:GetServerTimeNow() when search ends
--       HRushState   (string)      -> "MS_01" for anyone not in the match, real state otherwise
--   * Participants are Players only; roles/scores are keyed by Player Instance.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")

local Config       = require(ReplicatedStorage:WaitForChild("Config"))
local TagRules = require(ReplicatedStorage:WaitForChild("TagRules"))
local RpsRules = require(ReplicatedStorage:WaitForChild("RpsRules"))
local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent
local TagEvent     = Remotes:WaitForChild("TagEvent") :: RemoteEvent
local RpsStageStart = Remotes:WaitForChild("RpsStageStart") :: RemoteEvent
local RpsReveal = Remotes:WaitForChild("RpsReveal") :: RemoteEvent
local RpsResult = Remotes:WaitForChild("RpsResult") :: RemoteEvent
local RpsSubmitSign = Remotes:WaitForChild("RpsSubmitSign") :: RemoteEvent
local ModeVoteEvent = Remotes:WaitForChild("ModeVoteEvent") :: RemoteEvent
local CommitTag = Instance.new("BindableFunction")
CommitTag.Name = "HRUSH_CommitTag"
CommitTag.Parent = ServerScriptService

local PartyService = require(ServerScriptService:WaitForChild("PartyService"))
local PanyoMode = require(ServerScriptService:WaitForChild("PanyoMode"))
local SecretHuntMode = require(ServerScriptService:WaitForChild("SecretHuntMode"))
local SpawnSelector = require(ServerScriptService:WaitForChild("SpawnSelector"))

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

-- MapVoteEvent
local MapVoteEvent: RemoteEvent
do
	local existing = Remotes:FindFirstChild("MapVoteEvent")
	if existing and existing:IsA("RemoteEvent") then
		MapVoteEvent = existing
	else
		local ev = Instance.new("RemoteEvent")
		ev.Name = "MapVoteEvent"
		ev.Parent = Remotes
		MapVoteEvent = ev
	end
end

-- RoundRecap + MatchRecap (T27 Round End recap modal, MVP podium).
-- Mapped in default.project.json; created here if a setup script missed them.
local RoundRecapEvent: RemoteEvent
do
	local existing = Remotes:FindFirstChild("RoundRecap")
	if existing and existing:IsA("RemoteEvent") then
		RoundRecapEvent = existing
	else
		local ev = Instance.new("RemoteEvent")
		ev.Name = "RoundRecap"
		ev.Parent = Remotes
		RoundRecapEvent = ev
	end
end
local MatchRecapEvent: RemoteEvent
do
	local existing = Remotes:FindFirstChild("MatchRecap")
	if existing and existing:IsA("RemoteEvent") then
		MatchRecapEvent = existing
	else
		local ev = Instance.new("RemoteEvent")
		ev.Name = "MatchRecap"
		ev.Parent = Remotes
		MatchRecapEvent = ev
	end
end

local IS_STUDIO = RunService:IsStudio()
local MATCH = Config.Match
local MAX_PLAYERS: number = MATCH.MaxPlayers or 8
local SEARCH_TIMEOUT: number = MATCH.SearchTimeout or 10
local TAG_IMMUNITY: number = Config.Tag.SafeWindowDuration or 2 -- Safe Window: ex-Taya cannot be re-tagged for this long

-- ============================================================
-- HELPERS (participants = Player)
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
-- SHUFFLE BAG FALLBACK (System Spec 2.1 / T-CORE-03)
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
local matchState: string = "MS_01" -- MS_02 retired; MS_VOTE and MS_RPS are non-numbered states
local currentMode: string = "ClassicTag"
local currentRound: number = 1
local currentTaya: Instance? = nil
local playerRoles: { [Instance]: string } = {}
local tayaTimeThisRound: { [Instance]: number } = {}
local totalTayaTime: { [Instance]: number } = {}
local matchPoints: { [Instance]: number } = {}
local immuneUntil: { [Instance]: number } = {}
local matchRunning = false
local roundActive = false
local rpsChosen: { [Player]: boolean } = {}
local rpsPool: { [Player]: boolean } = {}
local rpsSigns: { [Player]: string } = {}
local rpsOpensAt = 0
local rpsDeadline = 0
local rpsLastRequest: { [Player]: number } = {}

local queued: { [Player]: boolean } = {}   -- pressed FIND MATCH, waiting for search to finish
local inMatch: { [Player]: boolean } = {}  -- real players taking part in the current match
local searchEndsAt: number? = nil

local function getParticipants(): { Instance }
	local list: { Instance } = {}
	for p in pairs(inMatch) do
		if p:IsDescendantOf(Players) then
			table.insert(list, p)
		end
	end
	return list
end

local function participantCount(): number
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
	ReplicatedStorage:SetAttribute("HRushGameMode", currentMode)

	for _, p in ipairs(targets) do
		local isIn = inMatch[p] == true
		local shownState = isIn and matchState or "MS_01"
		local role = isIn and (playerRoles[p] or "Runner") or "Runner"
		p:SetAttribute("HRushInMatch", isIn)
		p:SetAttribute("HRushGameMode", if isIn then currentMode else nil)
		p:SetAttribute("HRushState", shownState)
		p:SetAttribute("HRushRole", role)
		p:SetAttribute("HRushRound", currentRound)

		StateChanged:FireClient(p, {
			state = shownState,
			role = role,
			mode = if isIn then currentMode else nil,
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
	from:SetAttribute("HRushTagSafeUntil", Workspace:GetServerTimeNow() + TAG_IMMUNITY)
	from:SetAttribute("HRushRole", "Runner")
	to:SetAttribute("HRushRole", "Taya")
	broadcastState(nil)

	-- MovementController listens for { taggerId, targetId } to give the ex-Taya the +20% boost (F08).
	local payload = {
		taggerId = from.UserId,
		targetId = to.UserId,
	}
	for p in pairs(inMatch) do
		if p:IsDescendantOf(Players) then
			TagEvent:FireClient(p, payload)
		end
	end
	print(string.format("[MatchService] Tag transfer: %s tagged %s (new Taya)", from.Name, to.Name))
end

CommitTag.OnInvoke = function(tagger: Instance, target: Instance): boolean
	if currentMode == "AgawanNgPanyo" then
		return matchState == "MS_04" and tagger:IsA("Player") and target:IsA("Player")
			and PanyoMode.TrySteal(tagger, target)
	end
	if currentMode == "SecretHunt" then
		return matchState == "MS_04" and tagger:IsA("Player") and target:IsA("Player")
			and SecretHuntMode.TryCapture(tagger, target)
	end
	if matchState ~= "MS_04" or currentTaya ~= tagger or playerRoles[tagger] ~= "Taya" then return false end
	if tagger == target or not table.find(getParticipants(), target) or playerRoles[target] ~= "Runner" then return false end
	if (immuneUntil[target] or 0) > os.clock() then return false end
	local taggerRoot, targetRoot = getRoot(tagger), getRoot(target)
	local targetCharacter = if target:IsA("Player") then target.Character else target :: Model
	local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
	if not taggerRoot or not targetRoot or not targetHumanoid or targetHumanoid.Health <= 0 then return false end
	if (targetRoot.Position - taggerRoot.Position).Magnitude > Config.Tag.ActionRange then return false end
	if TagRules.isUntouchable(targetCharacter :: Model) then return false end
	transferTaya(tagger, target)
	return true
end

-- ============================================================
-- TELEPORT
-- ============================================================
local function teleportToPositions(list: { Player }, assignments: { [Player]: Vector3 }): boolean
	local ready: { { character: Model, position: Vector3 } } = {}
	for _, player in ipairs(list) do
		if player.Parent == Players then
			local position = assignments[player]
			local character: Model? = nil
			local deadline = os.clock() + 5
			repeat
				local candidate = player.Character
				local root = candidate and candidate:FindFirstChild("HumanoidRootPart")
				local humanoid = candidate and candidate:FindFirstChildOfClass("Humanoid")
				if candidate and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
					character = candidate
					break
				end
				task.wait(0.1)
			until os.clock() >= deadline or player.Parent ~= Players
			if character == nil or position == nil then
				warn(string.format("[MatchService] Round spawn unavailable for %s", player.Name))
				return false
			end
			table.insert(ready, { character = character, position = position })
		end
	end
	for _, entry in ipairs(ready) do
		entry.character:PivotTo(CFrame.new(entry.position))
	end
	return true
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
	player:SetAttribute("HRushGameMode", nil)
	-- Late joiners never see returnToLobby's broadcast, so push the lobby
	-- state directly: without this the client keeps its pre-first-message
	-- defaults and movement stays frozen until the next full match cycle.
	task.defer(function()
		if player.Parent then
			pcall(function()
				StateChanged:FireClient(player, {
					state = "MS_01",
					role = "Runner",
					mode = nil,
					round = currentRound,
					timer = workspace:GetServerTimeNow(),
				})
			end)
		end
	end)
end

Players.PlayerAdded:Connect(initPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	initPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	if currentMode == "AgawanNgPanyo" then PanyoMode.RemovePlayer(player) end
	if currentMode == "SecretHunt" then SecretHuntMode.RemovePlayer(player) end
	tayaBag:RemovePlayer(player)
	rpsChosen[player] = nil
	rpsPool[player] = nil
	rpsSigns[player] = nil
	rpsLastRequest[player] = nil
	queued[player] = nil

	if currentMode == "ClassicTag" and currentTaya == player and matchState == "MS_04" then
		promoteNearestRunnerToTaya(player)
	end

	inMatch[player] = nil
	playerRoles[player] = nil
end)

-- ============================================================
-- REMOTES
-- ============================================================
RpsSubmitSign.OnServerEvent:Connect(function(player, sign)
	local now = Workspace:GetServerTimeNow()
	if now - (rpsLastRequest[player] or 0) < 0.08 then return end
	rpsLastRequest[player] = now
	if matchState ~= "MS_RPS" or not inMatch[player] or not rpsPool[player] then return end
	if typeof(sign) ~= "string" or (sign ~= "Rock" and sign ~= "Paper" and sign ~= "Scissors") then return end
	if now < rpsOpensAt or now > rpsDeadline or rpsSigns[player] then return end
	rpsSigns[player] = sign
	for target in pairs(inMatch) do
		if target:IsDescendantOf(Players) then
			RpsStageStart:FireClient(target, { lockedUserId = player.UserId })
		end
	end
end)

QueueEvent.OnServerEvent:Connect(function(player, action)
	if action == "Play" then
		if player:GetAttribute("HRushTutorialTeleporting") == true then return end
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

		local party = PartyService.GetParty(player)
		if party then
			if party.leader == player then
				PartyService.SetLocked(party, true)
				for _, m in ipairs(party.members) do
					if m.Parent then
						queued[m] = true
						m:SetAttribute("HRushQueue", "Searching")
						m:SetAttribute("HRushSearchEndsAt", searchEndsAt or (workspace:GetServerTimeNow() + SEARCH_TIMEOUT))
					end
				end
			else
				-- non-leader cannot queue party
				return
			end
		else
			queued[player] = true
			player:SetAttribute("HRushQueue", "Searching")
			player:SetAttribute("HRushSearchEndsAt", searchEndsAt or (workspace:GetServerTimeNow() + SEARCH_TIMEOUT))
		end
	elseif action == "Cancel" then
		if matchState ~= "MS_01" or inMatch[player] or not queued[player] then return end
		local party = PartyService.GetParty(player)
		if party then
			if party.leader ~= player then return end
			PartyService.SetLocked(party, false)
			for _, m in ipairs(party.members) do
				queued[m] = nil
				m:SetAttribute("HRushQueue", "Idle")
				m:SetAttribute("HRushSearchEndsAt", nil)
			end
		else
			queued[player] = nil
			player:SetAttribute("HRushQueue", "Idle")
			player:SetAttribute("HRushSearchEndsAt", nil)
		end
	end
end)

-- TagEvent is server-to-client only. Only a validated TagService request commits a tag.

-- ============================================================
-- MATCH LOOP (MS_01 -> MS_06)
-- ============================================================
-- Waits for a phase and publishes its end time so the client loading screen can show an accurate countdown.
local function waitPhase(seconds: number)
	ReplicatedStorage:SetAttribute("HRushPhaseEndsAt", workspace:GetServerTimeNow() + seconds)
	task.wait(seconds)
end

local function rpsTiming(key: string): number
	local rps = MATCH.Rps
	if IS_STUDIO and rps.Studio[key] then
		return rps.Studio[key]
	end
	return rps[key]
end

local function playerIds(players: { Player }): { number }
	local ids: { number } = {}
	for _, player in ipairs(players) do
		table.insert(ids, player.UserId)
	end
	return ids
end

local function drawFallbackTaya(): Player?
	local candidates: { Instance } = {}
	for _, player in ipairs(getParticipants() :: { Player }) do
		if not rpsChosen[player] then table.insert(candidates, player) end
	end
	if #candidates == 0 then candidates = getParticipants() end
	tayaBag:Reset()
	return tayaBag:Draw(candidates) :: Player?
end

local function runRps(): Player?
	local participants = getParticipants() :: { Player }
	local remaining: { Player } = {}
	for _, player in ipairs(participants) do
		if not rpsChosen[player] then
			table.insert(remaining, player)
		end
	end
	if #remaining == 0 then
		rpsChosen = {}
		remaining = participants
	end
	if #remaining == 0 then return nil end
	if #remaining == 1 then
		rpsChosen[remaining[1]] = true
		return remaining[1]
	end

	matchState = "MS_RPS"
	broadcastState(nil)
	local safeThisRound: { [Player]: boolean } = {}
	local rng = Random.new()
	local sudden = false
	for stage = 1, MATCH.Rps.MaxStages do
		local present: { Player } = {}
		for _, player in ipairs(remaining) do
			if inMatch[player] and player:IsDescendantOf(Players) then
				table.insert(present, player)
			end
		end
		remaining = present
		if #remaining < 2 then break end

		rpsPool = {}
		rpsSigns = {}
		for _, player in ipairs(remaining) do
			rpsPool[player] = true
		end
		local now = Workspace:GetServerTimeNow()
		rpsOpensAt = now + (if stage == 1 then rpsTiming("IntroTime") else 0)
		rpsDeadline = rpsOpensAt + rpsTiming("PickTime")
		local roster = {}
		local usedIds: { number } = {}
		local safeIds: { number } = {}
		for _, player in ipairs(getParticipants() :: { Player }) do
			table.insert(roster, { userId = player.UserId, name = player.DisplayName })
			if rpsChosen[player] then table.insert(usedIds, player.UserId) end
			if safeThisRound[player] then table.insert(safeIds, player.UserId) end
		end
		table.sort(roster, function(a, b) return a.userId < b.userId end)
		local startPayload = { stage = stage, roster = roster, pool = playerIds(remaining), used = usedIds, safe = safeIds, opensAt = rpsOpensAt, deadline = rpsDeadline }
		for _, player in ipairs(getParticipants() :: { Player }) do
			RpsStageStart:FireClient(player, startPayload)
		end

		while Workspace:GetServerTimeNow() < rpsDeadline do
			local presentCount = 0
			for _, player in ipairs(remaining) do
				if inMatch[player] and player:IsDescendantOf(Players) then presentCount += 1 end
			end
			if presentCount < 2 then break end
			task.wait(0.05)
		end
		rpsPool = {}
		local active: { Player } = {}
		local signsById: { [number]: string } = {}
		local revealed = {}
		for _, player in ipairs(remaining) do
			if inMatch[player] and player:IsDescendantOf(Players) then
				table.insert(active, player)
				local sign = rpsSigns[player] or ({ "Rock", "Paper", "Scissors" })[rng:NextInteger(1, 3)]
				signsById[player.UserId] = sign
				table.insert(revealed, { userId = player.UserId, sign = sign })
			end
		end
		remaining = active
		if #remaining < 2 then break end
		local tie, safe = RpsRules.Resolve(signsById)
		if not tie then
			local safeSet: { [number]: boolean } = {}
			for _, userId in ipairs(safe) do safeSet[userId] = true end
			local survivors: { Player } = {}
			for _, player in ipairs(remaining) do
				if safeSet[player.UserId] then
					safeThisRound[player] = true
				else
					table.insert(survivors, player)
				end
			end
			remaining = survivors
		end
		local revealPayload = { stage = stage, signs = revealed, safe = safe, remaining = playerIds(remaining), tie = tie }
		for _, player in ipairs(getParticipants() :: { Player }) do
			RpsReveal:FireClient(player, revealPayload)
		end
		task.wait(rpsTiming("RevealTime") + rpsTiming("ResolveTime"))
		if #remaining <= 1 then break end
	end
	rpsPool = {}
	rpsSigns = {}
	local present: { Player } = {}
	for _, player in ipairs(remaining) do
		if inMatch[player] and player:IsDescendantOf(Players) then table.insert(present, player) end
	end
	remaining = present
	local selected: Player?
	if #remaining == 1 then
		selected = remaining[1]
	elseif #remaining > 1 then
		selected = remaining[rng:NextInteger(1, #remaining)]
		sudden = true
	else
		selected = drawFallbackTaya()
	end
	while selected do
		rpsChosen[selected] = true
		for _, player in ipairs(getParticipants() :: { Player }) do
			RpsResult:FireClient(player, { userId = selected.UserId, sudden = sudden })
		end
		task.wait(rpsTiming("ResultTime"))
		if inMatch[selected] and selected:IsDescendantOf(Players) then break end
		selected = drawFallbackTaya()
		sudden = true
	end
	return selected
end

local function returnToLobby()
	PanyoMode.EndRound()
	SecretHuntMode.EndRound()
	local returning: { Player } = {}
	for p in pairs(inMatch) do
		table.insert(returning, p)
	end

	matchState = "MS_01"
	currentMode = "ClassicTag"
	currentRound = 1
	currentTaya = nil
	roundActive = false
	searchEndsAt = nil
	tayaBag:Reset()
	rpsChosen = {}
	rpsPool = {}
	rpsSigns = {}
	rpsLastRequest = {}
	totalTayaTime = {}
	matchPoints = {}
	tayaTimeThisRound = {}
	playerRoles = {}
	immuneUntil = {}
	inMatch = {}

	for _, p in ipairs(Players:GetPlayers()) do
		if not queued[p] then
			p:SetAttribute("HRushQueue", "Idle")
		end
		p:SetAttribute("HRushSearchEndsAt", nil)
		p:SetAttribute("HRushHuntPractice", nil)
	end
	broadcastState(nil)

	for _, p in ipairs(returning) do
		local party = PartyService.GetParty(p)
		if party then
			PartyService.SetLocked(party, false)
		end
		if p.Parent then
			task.spawn(function()
				pcall(function()
					p:LoadCharacter()
				end)
			end)
		end
	end
end

-- ============================================================
-- MODE VOTE
-- ============================================================
local function runModeVote(): string
	local voteConfig = Config.ModeVote
	local available = {}
	for _, modeId in ipairs(voteConfig.Order) do
		local definition = voteConfig.Modes[modeId]
		if definition and definition.enabled == true then
			table.insert(available, {
				id = modeId,
				name = definition.name,
				description = definition.description,
			})
		end
	end
	assert(#available > 0, "At least one game mode must be enabled")
	if #available == 1 then
		return available[1].id
	end

	local duration: number = voteConfig.Duration
	local revealTime: number = voteConfig.RevealTime
	local endsAt = Workspace:GetServerTimeNow() + duration
	local votes: { [string]: number } = {}
	local choices: { [Player]: string } = {}
	local lastRequestAt: { [Player]: number } = {}
	for _, mode in ipairs(available) do
		votes[mode.id] = 0
	end
	local startPayload = { type = "Start", modes = available, endsAt = endsAt }
	for _, player in ipairs(getParticipants() :: { Player }) do
		ModeVoteEvent:FireClient(player, startPayload)
	end

	local voteConnection = ModeVoteEvent.OnServerEvent:Connect(function(player: Player, action: unknown, modeId: unknown)
		local now = Workspace:GetServerTimeNow()
		if now >= endsAt or not inMatch[player] then return end
		if now - (lastRequestAt[player] or 0) < voteConfig.RequestInterval then return end
		lastRequestAt[player] = now
		if action ~= "Vote" or typeof(modeId) ~= "string" or votes[modeId] == nil then return end
		local previous = choices[player]
		if previous == modeId then return end
		if previous ~= nil then votes[previous] -= 1 end
		choices[player] = modeId
		votes[modeId] += 1
		for _, target in ipairs(getParticipants() :: { Player }) do
			ModeVoteEvent:FireClient(target, {
				type = "Update", votes = votes, voterId = player.UserId, mode = modeId,
			})
		end
	end)

	while Workspace:GetServerTimeNow() < endsAt do
		task.wait(0.1)
		local participants = getParticipants() :: { Player }
		if #participants == 0 then break end
		local allVoted = true
		for _, player in ipairs(participants) do
			if choices[player] == nil then allVoted = false break end
		end
		if allVoted then break end
	end
	voteConnection:Disconnect()

	-- Departed players do not decide a mode for the remaining roster.
	votes = {}
	for _, mode in ipairs(available) do votes[mode.id] = 0 end
	for _, player in ipairs(getParticipants() :: { Player }) do
		local choice = choices[player]
		if choice ~= nil then votes[choice] += 1 end
	end
	local winner = voteConfig.TieFallback
	local bestCount = 0
	for _, mode in ipairs(available) do
		local count = votes[mode.id]
		if count > bestCount then
			bestCount = count
			winner = mode.id
		elseif count == bestCount and mode.id == voteConfig.TieFallback then
			winner = mode.id
		end
	end
	if bestCount == 0 or votes[winner] ~= bestCount then
		winner = voteConfig.TieFallback
	end
	for _, player in ipairs(getParticipants() :: { Player }) do
		ModeVoteEvent:FireClient(player, { type = "Winner", winner = winner, votes = votes })
	end
	task.wait(revealTime)
	for _, player in ipairs(getParticipants() :: { Player }) do
		ModeVoteEvent:FireClient(player, { type = "Close" })
	end
	return winner
end

-- ============================================================
-- MAP VOTE
-- ============================================================
local function runMapVote(): string
	local pool = (Config.MapVote and Config.MapVote.Pool) or { "Kalsada", "Binaha" }
	local duration = (Config.MapVote and Config.MapVote.Duration) or 10
	local revealTime = (Config.MapVote and Config.MapVote.RevealTime) or 1.5
	local endsAt = workspace:GetServerTimeNow() + duration

	local votes: { [string]: number } = {}
	for _, mapKey in ipairs(pool) do
		votes[mapKey] = 0
	end
	local voterChoices: { [string]: string } = {}

	local participants = getParticipants()
	local participantList: { { id: any, name: string, isBot: boolean } } = {}
	for _, p in ipairs(participants) do
		if p:IsA("Player") then
			table.insert(participantList, {
				id = p.UserId,
				name = p.DisplayName or p.Name,
				isBot = false,
			})
		end
	end

	local startPayload = {
		type = "Start",
		pool = pool,
		duration = duration,
		endsAt = endsAt,
		participants = participantList,
		info = Config.MapVote and Config.MapVote.Info,
	}
	for p in pairs(inMatch) do
		if p:IsDescendantOf(Players) then
			MapVoteEvent:FireClient(p, startPayload)
		end
	end

	local voteConn: RBXScriptConnection? = nil
	voteConn = MapVoteEvent.OnServerEvent:Connect(function(player, action, mapKey)
		if action == "Vote" and typeof(mapKey) == "string" and votes[mapKey] ~= nil then
			if inMatch[player] then
				local oldChoice = voterChoices[tostring(player.UserId)]
				if oldChoice then
					votes[oldChoice] = math.max(0, votes[oldChoice] - 1)
				end
				voterChoices[tostring(player.UserId)] = mapKey
				votes[mapKey] = votes[mapKey] + 1

				local updatePayload = {
					type = "Update",
					votes = votes,
					voterId = player.UserId,
					map = mapKey,
				}
				for target in pairs(inMatch) do
					if target:IsDescendantOf(Players) then
						MapVoteEvent:FireClient(target, updatePayload)
					end
				end
			end
		end
	end)

	local voteStart = os.clock()
	while (os.clock() - voteStart) < duration do
		task.wait(0.2)
		local count = 0
		for _ in pairs(voterChoices) do
			count += 1
		end
		if count >= #participants then
			task.wait(0.4)
			break
		end
	end

	if voteConn then
		voteConn:Disconnect()
	end

	local bestCount = -1
	local candidates: { string } = {}
	for _, mapKey in ipairs(pool) do
		local c = votes[mapKey] or 0
		if c > bestCount then
			bestCount = c
			candidates = { mapKey }
		elseif c == bestCount then
			table.insert(candidates, mapKey)
		end
	end
	local winner = candidates[math.random(1, #candidates)]

	local winnerPayload = {
		type = "Winner",
		winner = winner,
		votes = votes,
		revealEndsAt = workspace:GetServerTimeNow() + revealTime,
	}
	for target in pairs(inMatch) do
		if target:IsDescendantOf(Players) then
			MapVoteEvent:FireClient(target, winnerPayload)
		end
	end
	task.wait(revealTime)

	for target in pairs(inMatch) do
		if target:IsDescendantOf(Players) then
			MapVoteEvent:FireClient(target, { type = "Close" })
		end
	end

	return winner
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
			-- Bots no longer fill the match: the search ends and the match
			-- starts with whatever queued, even a single player (tag sandbox).
			if os.clock() - searchStart >= SEARCH_TIMEOUT then
				break
			end
		end
		searchEndsAt = nil
		if aborted or countQueued() == 0 then
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

		-- ===== MODE AND MAP VOTE PHASE =====
		matchState = "MS_VOTE"
		broadcastState(nil)
		local selectedMode = runModeVote()
		if selectedMode ~= currentMode then
			currentMode = selectedMode
			broadcastState(nil)
		end
		local selectedMap = if currentMode == "AgawanNgPanyo" or currentMode == "SecretHunt"
			then "Kalsada" else runMapVote()
		ReplicatedStorage:SetAttribute("HRushSelectedMap", selectedMap)
		print(string.format("[MatchService] Map vote completed. Selected map: %s", selectedMap))

		-- Sample once at match entry; the first round reuses these positions.
		local roundSpawns = SpawnSelector.assignRound(getParticipants() :: { Player })
		if roundSpawns == nil or not teleportToPositions(getParticipants() :: { Player }, roundSpawns) then
			warn("[MatchService] Safe authored-map spawns unavailable; ending match")
			continue
		end
		task.wait(0.5)

		local practiceSolo = currentMode == "AgawanNgPanyo" and participantCount() == 1
		local huntPractice = currentMode == "SecretHunt"
			and participantCount() < Config.SecretHunt.MinCompetitivePlayers
		local totalRounds: number = if practiceSolo or huntPractice then 1 else MATCH.TotalRounds or 3
		local panyoTotalTime: { [Player]: number } = {}
		local panyoTotalSteals: { [Player]: number } = {}
		local panyoValidRounds = 0
		local huntTotalCaptures: { [Player]: number } = {}
		local huntBestStreak: { [Player]: number } = {}
		local huntValidRounds = 0
		local abort = false

		for roundNum = 1, totalRounds do
			if roundNum > 1 then
				roundSpawns = SpawnSelector.assignRound(getParticipants() :: { Player })
				if roundSpawns == nil then abort = true break end
			end
			currentRound = roundNum
			tayaTimeThisRound = {}
			for _, p in ipairs(getParticipants()) do
				tayaTimeThisRound[p] = 0
				totalTayaTime[p] = totalTayaTime[p] or 0
				matchPoints[p] = matchPoints[p] or 0
			end

			-- MS_RPS picks the starting Taya before MS_03 (System Spec 2.1 / T-CORE-03).
			local participants = getParticipants()
			if participantCount() == 0 then
				print("[MatchService] No real players left; aborting match.")
				abort = true
				break
			end

			local startingTaya: Instance? = nil
			if currentMode == "ClassicTag" then
				startingTaya = runRps()
				if not startingTaya or not inMatch[startingTaya] then
					startingTaya = drawFallbackTaya()
					if startingTaya then rpsChosen[startingTaya] = true end
				end
				if not startingTaya then abort = true break end
			else
				currentTaya = nil
				for _, player in ipairs(participants :: { Player }) do
					playerRoles[player] = "Runner"
					player:SetAttribute("HRushPanyoPractice", if currentMode == "AgawanNgPanyo" then practiceSolo else nil)
					player:SetAttribute("HRushHuntPractice", if currentMode == "SecretHunt" then huntPractice else nil)
				end
			end
			-- MS_03 COUNTDOWN
			matchState = "MS_03"
			if not teleportToPositions(getParticipants() :: { Player }, roundSpawns :: { [Player]: Vector3 }) then
				abort = true
				break
			end
			if currentMode == "ClassicTag" then
				setRoles(startingTaya :: Instance)
			elseif currentMode == "AgawanNgPanyo" then
				broadcastState(nil)
				if not PanyoMode.PrepareRound(getParticipants() :: { Player }, selectedMap, currentRound) then
					warn("[MatchService] Panyo spawn unavailable; ending match safely")
					abort = true
					break
				end
			else
				broadcastState(nil)
				if not SecretHuntMode.PrepareRound(getParticipants() :: { Player }, currentRound,
					roundSpawns :: { [Player]: Vector3 }) then
					warn("[MatchService] Secret Hunt roster unavailable; ending match safely")
					abort = true
					break
				end
			end
			local cdDuration: number = MATCH.CountdownDuration or 5
			if currentMode == "ClassicTag" then
				print(string.format("[MatchService] Round %d: MS_03 Countdown (%d s). Starting Taya: %s", currentRound, cdDuration, (startingTaya :: Instance).Name))
			end
			waitPhase(IS_STUDIO and 3 or cdDuration)
			if participantCount() == 0 then abort = true break end
			if currentMode == "SecretHunt" and not huntPractice
				and participantCount() < Config.SecretHunt.MinCompetitivePlayers then
				if roundNum > 1 then
					SecretHuntMode.EndRound()
					break
				end
				huntPractice = true
				totalRounds = 1
				for _, player in ipairs(getParticipants() :: { Player }) do
					player:SetAttribute("HRushHuntPractice", true)
				end
			end

			-- MS_04 ROUND LIVE
			matchState = "MS_04"
			roundActive = true
			broadcastState(nil)
			local roundDuration: number = if currentMode == "AgawanNgPanyo" then Config.Panyo.RoundDuration
				else if currentMode == "SecretHunt" then Config.SecretHunt.RoundDuration
				else MATCH.RoundDuration or 150
			print(string.format("[MatchService] Round %d: MS_04 Round Live (%d s)!", currentRound, roundDuration))
			ReplicatedStorage:SetAttribute("HRushPhaseEndsAt", workspace:GetServerTimeNow() + roundDuration)
			if currentMode == "AgawanNgPanyo" and not PanyoMode.StartRound(roundDuration) then
				warn("[MatchService] Panyo round could not start")
				abort = true
				break
			end
			if currentMode == "SecretHunt" and not SecretHuntMode.StartRound(roundDuration) then
				warn("[MatchService] Secret Hunt round could not start")
				abort = true
				break
			end

			local startTime = os.clock()

			while (os.clock() - startTime) < roundDuration do
				task.wait(0.1)
				local now = os.clock()

				local taya = currentTaya
				if currentMode == "ClassicTag" and taya and playerRoles[taya] == "Taya" then
					tayaTimeThisRound[taya] = (tayaTimeThisRound[taya] or 0) + 0.1
					totalTayaTime[taya] = (totalTayaTime[taya] or 0) + 0.1
					taya:SetAttribute("HRushTayaTime", math.floor(tayaTimeThisRound[taya] * 10) / 10)
				end

				if participantCount() == 0 then
					print("[MatchService] All players left during Round Live; aborting match.")
					abort = true
					break
				end
				if currentMode == "AgawanNgPanyo" and not practiceSolo and participantCount() < 2 then
					break
				end
				if currentMode == "SecretHunt" and not huntPractice
					and participantCount() < Config.SecretHunt.MinContinuePlayers then break end
			end
			roundActive = false
			local panyoResults = if currentMode == "AgawanNgPanyo" then PanyoMode.EndRound() else nil
			local huntResults = if currentMode == "SecretHunt" then SecretHuntMode.EndRound() else nil
			if abort then
				break
			end

			-- MS_05 ROUND END
			matchState = "MS_05"
			broadcastState(nil)
			local roundEndDuration: number = MATCH.RoundEndDuration or 8
			print(string.format("[MatchService] Round %d: MS_05 Round End (%d s). Calculating scores...", currentRound, roundEndDuration))

			if currentMode == "AgawanNgPanyo" then
				local results = panyoResults :: { any }
				local validRound = not practiceSolo and participantCount() >= 2
				if validRound then panyoValidRounds += 1 end
				table.sort(results, function(a, b)
					if a.left ~= b.left then return not a.left end
					if a.time ~= b.time then return a.time > b.time end
					if a.steals ~= b.steals then return a.steals > b.steals end
					return a.userId < b.userId
				end)
				local pointsTable: { number } = MATCH.RoundPoints or { 8, 6, 5, 4, 3, 2, 1, 0 }
				local entries = {}
				local rank = 0
				for index, result in ipairs(results) do
					if index == 1 or result.left ~= results[index - 1].left
						or result.time ~= results[index - 1].time or result.steals ~= results[index - 1].steals then
						rank = index
					end
					local points = if validRound and not result.left and result.time > 0 then pointsTable[rank] or 0 else 0
					if validRound and not result.left then
						panyoTotalTime[result.player] = (panyoTotalTime[result.player] or 0) + result.time
						panyoTotalSteals[result.player] = (panyoTotalSteals[result.player] or 0) + result.steals
						matchPoints[result.player] = (matchPoints[result.player] or 0) + points
					end
					table.insert(entries, {
						rank = rank, name = result.name, userId = result.userId, left = result.left,
						possessionTime = result.time, possessionPoints = math.floor(result.time + 0.000001),
						steals = result.steals, pointsAwarded = points,
						totalPoints = matchPoints[result.player] or 0,
					})
				end
				local recapWait = if IS_STUDIO then 3 else roundEndDuration
				for _, player in ipairs(getParticipants() :: { Player }) do
					RoundRecapEvent:FireClient(player, {
						mode = currentMode, entries = entries, round = currentRound,
						totalRounds = totalRounds, nextIn = recapWait,
						practice = practiceSolo, validRound = validRound,
					})
				end
				waitPhase(recapWait)
				if not practiceSolo and participantCount() < 2 then break end
				continue
			end
			if currentMode == "SecretHunt" then
				local results = huntResults :: { any }
				local validRound = not huntPractice
				if validRound then huntValidRounds += 1 end
				table.sort(results, function(a, b)
					if a.left ~= b.left then return not a.left end
					if a.captures ~= b.captures then return a.captures > b.captures end
					local aStreak = math.floor(a.bestStreak * 10 + 0.5)
					local bStreak = math.floor(b.bestStreak * 10 + 0.5)
					if aStreak ~= bStreak then return aStreak > bStreak end
					return a.userId < b.userId
				end)
				local pointsTable: { number } = MATCH.RoundPoints or { 8, 6, 5, 4, 3, 2, 1, 0 }
				local entries = {}
				local rank = 0
				for index, result in ipairs(results) do
					local streak = math.floor(result.bestStreak * 10 + 0.5) / 10
					local previous = results[index - 1]
					if previous == nil or result.left ~= previous.left or result.captures ~= previous.captures
						or streak ~= math.floor(previous.bestStreak * 10 + 0.5) / 10 then rank = index end
					local points = if validRound and not result.left and result.captures > 0
						then pointsTable[rank] or 0 else 0
					if validRound and not result.left then
						huntTotalCaptures[result.player] = (huntTotalCaptures[result.player] or 0) + result.captures
						huntBestStreak[result.player] = math.max(huntBestStreak[result.player] or 0, streak)
						matchPoints[result.player] = (matchPoints[result.player] or 0) + points
					end
					table.insert(entries, {
						rank = rank, userId = result.userId, name = result.name, left = result.left,
						captures = result.captures, bestStreak = streak, pointsAwarded = points,
						totalPoints = matchPoints[result.player] or 0,
					})
				end
				local recapWait = if IS_STUDIO then 3 else roundEndDuration
				local matchEnding = huntPractice or participantCount() < Config.SecretHunt.MinCompetitivePlayers
					or roundNum >= totalRounds
				for _, player in ipairs(getParticipants() :: { Player }) do
					RoundRecapEvent:FireClient(player, {
						mode = currentMode, entries = entries, round = currentRound, totalRounds = totalRounds,
						nextIn = recapWait, practice = huntPractice, validRound = validRound,
						matchEnding = matchEnding,
					})
				end
				waitPhase(recapWait)
				if matchEnding or participantCount() < Config.SecretHunt.MinCompetitivePlayers then break end
				continue
			end

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

		-- T27 recap: feed the client scoreboard modal (entries, round, totals, wait).
		local recapEntries: { { rank: number, name: string, isBot: boolean, tayaTime: number, pointsAwarded: number, totalPoints: number } } = {}
		for rankIdx, entry in ipairs(ranked) do
			local pts = pointsTable[rankIdx] or 0
			table.insert(recapEntries, {
				rank = rankIdx,
				name = entry.player.Name,
				isBot = entry.player:GetAttribute("IsBot") == true,
				tayaTime = entry.tayaTime,
				pointsAwarded = pts,
				totalPoints = matchPoints[entry.player] or 0,
			})
		end
		local recapWait = if IS_STUDIO then 3 else roundEndDuration
		RoundRecapEvent:FireAllClients({
			entries = recapEntries,
			round = currentRound,
			totalRounds = MATCH.TotalRounds or 3,
			nextIn = recapWait,
		})

		waitPhase(recapWait)
		end

		-- MS_06 MATCH END
		if not abort and (currentMode == "ClassicTag"
			or (currentMode == "AgawanNgPanyo" and not practiceSolo and panyoValidRounds > 0)
			or (currentMode == "SecretHunt" and huntValidRounds > 0)) then
			matchState = "MS_06"
			broadcastState(nil)
			local matchEndDuration: number = MATCH.MatchEndDuration or 15
			print(string.format("[MatchService] MS_06 Match End (%d s). Determining Match MVP...", matchEndDuration))
			if currentMode == "SecretHunt" then
				local finalRankings = {}
				for _, player in ipairs(getParticipants() :: { Player }) do
					table.insert(finalRankings, {
						player = player, captures = huntTotalCaptures[player] or 0,
						bestStreak = huntBestStreak[player] or 0, points = matchPoints[player] or 0,
					})
				end
				table.sort(finalRankings, function(a, b)
					if a.captures ~= b.captures then return a.captures > b.captures end
					if a.bestStreak ~= b.bestStreak then return a.bestStreak > b.bestStreak end
					if a.points ~= b.points then return a.points > b.points end
					return a.player.UserId < b.player.UserId
				end)
				local entries = {}
				local rank = 0
				for index, entry in ipairs(finalRankings) do
					local previous = finalRankings[index - 1]
					if previous == nil or entry.captures ~= previous.captures
						or entry.bestStreak ~= previous.bestStreak or entry.points ~= previous.points then rank = index end
					table.insert(entries, {
						rank = rank, isMVP = rank == 1 and entry.captures > 0,
						name = entry.player.DisplayName, userId = entry.player.UserId,
						captures = entry.captures, bestStreak = entry.bestStreak, points = entry.points,
					})
				end
				local podiumWait = if IS_STUDIO then 5 else matchEndDuration
				for _, player in ipairs(getParticipants() :: { Player }) do
					MatchRecapEvent:FireClient(player, { mode = currentMode, entries = entries, nextIn = podiumWait })
				end
				waitPhase(podiumWait)
			elseif currentMode == "AgawanNgPanyo" then
				local finalRankings = {}
				for _, player in ipairs(getParticipants() :: { Player }) do
					table.insert(finalRankings, {
						player = player, possessionTime = panyoTotalTime[player] or 0,
						steals = panyoTotalSteals[player] or 0, points = matchPoints[player] or 0,
					})
				end
				table.sort(finalRankings, function(a, b)
					if a.possessionTime ~= b.possessionTime then return a.possessionTime > b.possessionTime end
					if a.steals ~= b.steals then return a.steals > b.steals end
					if a.points ~= b.points then return a.points > b.points end
					return a.player.UserId < b.player.UserId
				end)
				local entries = {}
				local rank = 0
				for index, entry in ipairs(finalRankings) do
					if index == 1 or entry.possessionTime ~= finalRankings[index - 1].possessionTime
						or entry.steals ~= finalRankings[index - 1].steals
						or entry.points ~= finalRankings[index - 1].points then
						rank = index
					end
					table.insert(entries, {
						rank = rank, isMVP = rank == 1 and entry.possessionTime > 0, name = entry.player.DisplayName,
						userId = entry.player.UserId, possessionTime = entry.possessionTime,
						possessionPoints = math.floor(entry.possessionTime + 0.000001),
						steals = entry.steals, points = entry.points,
					})
				end
				local podiumWait = if IS_STUDIO then 5 else matchEndDuration
				for _, player in ipairs(getParticipants() :: { Player }) do
					MatchRecapEvent:FireClient(player, { mode = currentMode, entries = entries, nextIn = podiumWait })
				end
				waitPhase(podiumWait)
			else

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

		-- T27 podium: feed the client MVP modal (ranked rows, MVP flagged).
		local podiumEntries: { { rank: number, isMVP: boolean, name: string, isBot: boolean, points: number, totalTayaTime: number } } = {}
		for rankIdx, entry in ipairs(finalRankings) do
			table.insert(podiumEntries, {
				rank = rankIdx,
				isMVP = rankIdx == 1,
				name = entry.player.Name,
				isBot = entry.player:GetAttribute("IsBot") == true,
				points = entry.points,
				totalTayaTime = entry.totalTaya,
			})
		end
		local podiumWait = if IS_STUDIO then 5 else matchEndDuration
		MatchRecapEvent:FireAllClients({
			entries = podiumEntries,
			nextIn = podiumWait,
		})

		waitPhase(podiumWait)
			end
		end
		print("[MatchService] Returning to lobby.")
	end
end

task.defer(runMatch)
