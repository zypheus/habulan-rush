--!strict
-- ServerScriptService/PartyService   (ModuleScript, NEW)
-- Owns parties in the shared lobby server.
--
--  * Every player is ALWAYS in a party (solo = party of 1). Attributes replicate to every client:
--      HRushPartyLeader (number UserId)  HRushPartySlot (1..4)  HRushPartySize (number)
--  * Friends invited with SocialService:PromptGameInvite carry LaunchData = leader UserId.
--    When they join the server, GetJoinData().LaunchData puts them in that party automatically.
--  * Members are teleported beside the leader ("lobby formation") so they stand next to each other.
--  * MatchService locks a party while it is searching / in a match (no joins, leaves or formation).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local PARTY = Config.Party

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PartyEvent: RemoteEvent
do
	local existing = Remotes:FindFirstChild("PartyEvent")
	if existing and existing:IsA("RemoteEvent") then
		PartyEvent = existing
	else
		local ev = Instance.new("RemoteEvent")
		ev.Name = "PartyEvent"
		ev.Parent = Remotes
		PartyEvent = ev
	end
end

export type Party = {
	leader: Player,
	members: { Player },
	locked: boolean,
}

local PartyService = {}
local partyOf: { [Player]: Party } = {}

local function publish(party: Party)
	for i, m in ipairs(party.members) do
		m:SetAttribute("HRushPartyLeader", party.leader.UserId)
		m:SetAttribute("HRushPartySlot", i)
		m:SetAttribute("HRushPartySize", #party.members)
	end
end

local function getRoot(p: Player): BasePart?
	local c = p.Character
	if not c then
		return nil
	end
	return c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Stand every non-leader member beside the leader (leader's local +X, which is screen-left for the lobby camera).
local function formation(party: Party)
	if party.locked then
		return
	end
	local leaderRoot = getRoot(party.leader)
	if not leaderRoot then
		return
	end
	for i = 2, #party.members do
		local m = party.members[i]
		if m.Character and getRoot(m) then
			m.Character:PivotTo(leaderRoot.CFrame * CFrame.new(PARTY.SlotSpacing * (i - 1), 0, 0))
		end
	end
end

local function createSolo(player: Player)
	local party: Party = { leader = player, members = { player }, locked = false }
	partyOf[player] = party
	publish(party)
end

local function detach(player: Player)
	local party = partyOf[player]
	if not party then
		return
	end
	local idx = table.find(party.members, player)
	if idx then
		table.remove(party.members, idx)
	end
	partyOf[player] = nil
	if #party.members > 0 then
		if party.leader == player then
			party.leader = party.members[1]
		end
		publish(party)
		formation(party)
	end
end

-- ---------------------------------------------------------------- public API
function PartyService.GetParty(player: Player): Party?
	return partyOf[player]
end

function PartyService.SetLocked(party: Party, locked: boolean)
	party.locked = locked
end

function PartyService.Join(member: Player, leader: Player): boolean
	if member == leader then
		return false
	end
	local target = partyOf[leader]
	local own = partyOf[member]
	if not target or not own then
		return false
	end
	if target == own then
		return true
	end
	if target.locked or own.locked or #own.members > 1 then
		return false
	end
	if #target.members >= PARTY.MaxSize then
		return false
	end
	detach(member)
	table.insert(target.members, member)
	partyOf[member] = target
	publish(target)
	formation(target)
	return true
end

function PartyService.Leave(player: Player)
	local party = partyOf[player]
	if not party or party.locked or #party.members <= 1 then
		return
	end
	detach(player)
	createSolo(player)
end

-- ---------------------------------------------------------------- players
local function onPlayerAdded(player: Player)
	createSolo(player)

	-- (re)form the lobby line-up whenever a member's character appears
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		local party = partyOf[player]
		if party then
			formation(party)
		end
	end)

	-- joined through a friend's invite? LaunchData = the leader's UserId
	task.spawn(function()
		local ok, joinData = pcall(function()
			return player:GetJoinData()
		end)
		if not ok or typeof(joinData) ~= "table" then
			return
		end
		local launch = (joinData :: any).LaunchData
		local leaderId: number? = if typeof(launch) == "string" then tonumber(launch) else nil
		if not leaderId then
			return
		end
		local leader = Players:GetPlayerByUserId(leaderId)
		if not leader then
			return
		end
		if not player.Character then
			player.CharacterAdded:Wait()
		end
		task.wait(0.6)
		if not PartyService.Join(player, leader) then
			warn(string.format("[PartyService] %s could not join %s's party (full / locked).", player.Name, leader.Name))
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	detach(player)
end)

-- Client -> server: "Leave" (member leaves party), "Kick", userId (leader removes a member)
PartyEvent.OnServerEvent:Connect(function(player: Player, action: any, arg: any)
	if action == "Leave" then
		PartyService.Leave(player)
	elseif action == "Kick" and typeof(arg) == "number" then
		local party = partyOf[player]
		if party and party.leader == player and not party.locked then
			local target = Players:GetPlayerByUserId(arg)
			if target and target ~= player and partyOf[target] == party then
				PartyService.Leave(target)
			end
		end
	end
end)

print("[PartyService] Ready.")
return PartyService
