--!strict
-- ServerScriptService/SkillService.server.lua
-- Owner: Programmer B (T18 slice, RS_01 only)
-- Responsibility: validate skill casts (RequestSkill), keep the server-side
--                 cooldown ledger, set IsAirborne, then split the reply:
--                 SkillApproved goes ONLY to the requesting player (locked
--                 direction + params, the owning client applies movement),
--                 SkillVFX goes to ALL players for visuals. Denies are silent.
--                 The client reports landing via SkillLanded.
-- See System Specification section 5 and Config.Skills.
--
-- IN THIS SLICE: RS_01 only. Server role authority arrives with TagService
-- (T11); until then the role gate is the client-side check plus the debug flag.
-- TODO (T17): PickSkill draft + slot validation + timeout auto-pick.
-- TODO (T18/T19): effect execution for RS_02/03 and TS_01-03, stun wiring (T13).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestSkill = Remotes:WaitForChild("RequestSkill") :: RemoteEvent
local SkillEvent = Remotes:WaitForChild("SkillEvent") :: RemoteEvent
local SkillApproved = Remotes:WaitForChild("SkillApproved") :: RemoteEvent
local SkillVFX = Remotes:WaitForChild("SkillVFX") :: RemoteEvent
local SkillLanded = Remotes:WaitForChild("SkillLanded") :: RemoteEvent

-- readyAt[player][skillId] = os.clock() when the cooldown finishes.
local readyAt: { [Player]: { [string]: number } } = {}
-- airborneUntil[player] = os.clock() covering windup + flight + landing slack.
-- Backstop only: the authoritative flag is the IsAirborne attribute, cleared
-- when the client reports landing (or by this timer if the report never comes).
local airborneUntil: { [Player]: number } = {}

-- TODO: remove before submission (debug prints for RS_01 testing)
local function debugPrint(msg: string)
	if Config.Debug.ShowSkillDebug then
		print("[SkillService] " .. msg)
	end
end

local function isGranted(skillId: string): boolean
	-- TEMP grant list (T17 draft replaces this with picked slots).
	for _, id in Config.Skills.testGrant do
		if id == skillId then
			return true
		end
	end
	return false
end

-- Silent deny: a player mashing the key must never flood the output with
-- warnings or errors (spec: reject spam without errors).
local function deny(player: Player, skillId: string, reason: string)
	debugPrint("validation DENIED for " .. player.Name .. " (" .. reason .. ")") -- TODO: remove before submission
	SkillEvent:FireClient(player, { type = "deny", skillId = skillId })
end

RequestSkill.OnServerEvent:Connect(function(player: Player, skillId: unknown, dir: unknown)
	if typeof(skillId) ~= "string" then
		return
	end
	debugPrint("request received from " .. player.Name .. " skill=" .. skillId) -- TODO: remove before submission
	local sk = Config.Skills[skillId]
	if sk == nil then
		deny(player, skillId, "unknown skill")
		return
	end

	-- Role gate: only enforced while the debug flag is off. The server cannot
	-- see roles yet (client attributes do not replicate up), so the real check
	-- lands with TagService T11. Flag on = skip for playtesting.
	if not Config.Debug.AllowAnyRoleForSkills then
		local serverRole = player:GetAttribute("ServerRole")
		if serverRole ~= nil and serverRole ~= sk.role then
			deny(player, skillId, "wrong role")
			return
		end
	end

	if not isGranted(skillId) then
		deny(player, skillId, "not granted")
		return
	end

	-- Round state: Bootstrap mirrors MS_04 here until MatchService (T07) owns
	-- the state machine. Missing attribute = no round = deny (fail closed).
	local state = ReplicatedStorage:GetAttribute("HRushRoundState")
	if state ~= "MS_04" then
		deny(player, skillId, "round state " .. tostring(state))
		return
	end

	-- Stun: attribute will be set by pounce/skill effects (T13/T18/T19).
	if player:GetAttribute("HRushStunned") == true then
		deny(player, skillId, "stunned")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or not (root and root:IsA("BasePart")) then
		deny(player, skillId, "no character")
		return
	end
	if humanoid.Health <= 0 then
		deny(player, skillId, "dead")
		return
	end

	local now = os.clock()

	-- Not already airborne: the IsAirborne attribute is the source of truth
	-- (set at approval, cleared on SkillLanded report); the timer is backstop.
	if player:GetAttribute("IsAirborne") == true then
		deny(player, skillId, "already airborne (IsAirborne)")
		return
	end
	local airUntil = airborneUntil[player]
	if airUntil ~= nil and airUntil > now then
		deny(player, skillId, "airborne window active")
		return
	end

	-- Grounded check: a standing root sits about 3 studs above the floor, so
	-- anything further down than (untouchableHeight - 2) counts as airborne.
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { character }
	ray.IgnoreWater = true
	local ground = Workspace:Raycast(root.Position, Vector3.new(0, -100, 0), ray)
	if ground == nil or ground.Distance > (sk.params.untouchableHeight - 2) then
		deny(player, skillId, "not grounded")
		return
	end

	-- Cooldown ledger: the single source of truth; spam after a cast is denied
	-- here regardless of what the client thinks.
	local ledger = readyAt[player]
	if ledger == nil then
		ledger = {}
		readyAt[player] = ledger
	end
	local ready = ledger[skillId]
	if ready ~= nil and ready > now then
		deny(player, skillId, "cooldown " .. string.format("%.1f", ready - now) .. "s left")
		return
	end
	ledger[skillId] = now + sk.cooldown

	-- Facing direction: trust the client when it sent a sane vector, otherwise
	-- fall back to the character's look direction on the server (never trust
	-- garbage, but never fail the cast because of it either).
	local castDir: Vector3
	if typeof(dir) == "Vector3" and dir.Magnitude > 0.01 then
		castDir = Vector3.new(dir.X, 0, dir.Z).Unit
	else
		local look = root.CFrame.LookVector
		castDir = Vector3.new(look.X, 0, look.Z).Unit
	end

	-- Mark the player airborne (attribute = tag immunity + re-cast gate).
	-- Backstop timer clears it if the landing report never arrives.
	player:SetAttribute("IsAirborne", true)
	airborneUntil[player] = now + sk.params.windup + sk.params.airtime + 1.0
	task.delay(sk.params.windup + sk.params.airtime + 1.0, function()
		if player.Parent and player:GetAttribute("IsAirborne") == true then
			player:SetAttribute("IsAirborne", false) -- landing report lost: self-heal
			airborneUntil[player] = nil
			debugPrint("IsAirborne backstop cleared for " .. player.Name) -- TODO: remove before submission
		end
	end)

	-- Split reply (spec architecture): approved event ONLY to the caster with
	-- locked direction + params (owning client moves itself), VFX event to ALL.
	SkillApproved:FireClient(player, {
		skillId = skillId,
		dir = castDir,
		params = sk.params,
	})
	SkillVFX:FireAllClients({
		caster = player.UserId,
		skillId = skillId,
		dir = castDir,
	})
	debugPrint("validation APPROVED for " .. player.Name .. "; SkillApproved to caster, SkillVFX to all") -- TODO: remove before submission
end)

-- Owning client reports landing; server clears IsAirborne so tag immunity and
-- the re-cast gate end exactly when the character touches down.
SkillLanded.OnServerEvent:Connect(function(player: Player, skillId: unknown)
	if typeof(skillId) ~= "string" then
		return
	end
	if player:GetAttribute("IsAirborne") == true then
		player:SetAttribute("IsAirborne", false)
		airborneUntil[player] = nil
		debugPrint("landing reported by " .. player.Name .. " (" .. skillId .. "), IsAirborne=false") -- TODO: remove before submission
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	readyAt[player] = nil
	airborneUntil[player] = nil
end)

debugPrint("Loaded - RS_01 slice (validation + SkillApproved/SkillVFX split + SkillLanded).") -- TODO: remove before submission
print("[SkillService] Loaded - RS_01 slice (validation + server CD + approved/VFX split). T17 draft, RS_02/03, TS_*: TODO.")