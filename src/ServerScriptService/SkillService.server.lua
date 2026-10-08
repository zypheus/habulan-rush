--!strict
-- ServerScriptService/SkillService.server.lua
-- Owner: Programmer B (T18 slice — RS_01 only)
-- Responsibility: validate skill casts (RequestSkill), keep the server-side
--                 cooldown ledger, answer via SkillEvent (accept / deny).
-- See System Specification §5 (skill table) and Config.Skills.
--
-- IN THIS SLICE: RS_01 Luksong Baka only. Grant check reads the TEMP
-- Config.Skills.testGrant list; role is trusted from the client until
-- MatchService (T07) / TagService (T11) give the server real role state.
-- TODO (T17): PickSkill draft + slot validation + timeout auto-pick.
-- TODO (T18/T19): effect execution for RS_02/03 and TS_01–03 (decoy, stun,
--                 slow, reveal), rate limiting and exploit hardening.
-- TODO (T22): Diskarte meter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestSkill = Remotes:WaitForChild("RequestSkill") :: RemoteEvent
local SkillEvent = Remotes:WaitForChild("SkillEvent") :: RemoteEvent

-- readyAt[player][skillId] = os.clock() timestamp when the skill becomes usable.
local readyAt: { [Player]: { [string]: number } } = {}

local function isGranted(skillId: string): boolean
	-- TEMP grant list (T17 draft replaces this with picked slots).
	for _, id in Config.Skills.testGrant do
		if id == skillId then
			return true
		end
	end
	return false
end

local function deny(player: Player, skillId: string, reason: string)
	warn(string.format("[SkillService] Denied %s for %s (%s)", skillId, player.Name, reason))
	SkillEvent:FireClient(player, skillId, false)
end

RequestSkill.OnServerEvent:Connect(function(player: Player, skillId: unknown)
	if typeof(skillId) ~= "string" then
		return
	end
	local sk = Config.Skills[skillId]
	if sk == nil then
		deny(player, skillId, "unknown skill")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not isGranted(skillId) then
		deny(player, skillId, "not granted")
		return
	end
	if humanoid == nil or humanoid.Health <= 0 then
		deny(player, skillId, "dead / no character")
		return
	end

	local now = os.clock()
	local ledger = readyAt[player]
	if ledger == nil then
		ledger = {}
		readyAt[player] = ledger
	end
	local ready = ledger[skillId]
	if ready ~= nil and ready > now then
		deny(player, skillId, "server cooldown active")
		return
	end

	ledger[skillId] = now + sk.cooldown
	SkillEvent:FireClient(player, skillId, true)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	readyAt[player] = nil
end)

print("[SkillService] Loaded — RS_01 slice (validation + server CD). T17 draft, RS_02/03, TS_*, Diskarte: TODO.")