--!strict
-- ServerScriptService/SkillService.server.lua
-- Owner: Programmer B (T18 slice, RS_01 Escape + RS_03 Stun)
-- Responsibility: validate skill casts (RequestSkill), keep the server-side
--                 cooldown ledger, then split the reply: SkillApproved goes
--                 ONLY to the requesting player, SkillVFX goes to ALL players
--                 for visuals. Denies are silent.
--                 RS_01: sets IsAirborne; the client reports landing via SkillLanded.
--                 RS_03: the server simulates the slipper projectile and owns
--                 the hit test; on hit it stuns the Taya via HRushStunned.
-- See System Specification section 5 and Config.Skills.
--
-- IN THIS SLICE: RS_01 + RS_03. Server role authority arrives with TagService
-- (T11); until then the role gate and the Taya lookup use the debug flag.
-- TODO (T17): PickSkill draft + slot validation + timeout auto-pick.
-- TODO (T18/T19): effect execution for RS_02 and TS_01-03, Diskarte counter (T21).

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
-- RS_01 only. Backstop only: the authoritative flag is the IsAirborne attribute,
-- cleared when the client reports landing (or by this timer if lost).
local airborneUntil: { [Player]: number } = {}

-- Taya stun state for RS_03. The token guards overlapping stuns so a stale
-- timer can never restore speed or clear a newer stun.
type StunState = {
	token: number,
	prevSpeed: number,
	diedConn: RBXScriptConnection?,
	roundConn: RBXScriptConnection?,
}
local tayaStun: { [Player]: StunState } = {}
local stunTokenCounter = 0

-- TODO: remove before submission (debug prints for skill testing)
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

-- Shared cooldown ledger: the single source of truth; spam after a cast is
-- denied here regardless of what the client thinks.
local function checkAndSetCooldown(player: Player, skillId: string, cooldown: number, now: number): boolean
	local ledger = readyAt[player]
	if ledger == nil then
		ledger = {}
		readyAt[player] = ledger
	end
	local ready = ledger[skillId]
	if ready ~= nil and ready > now then
		deny(player, skillId, "cooldown " .. string.format("%.1f", ready - now) .. "s left")
		return false
	end
	ledger[skillId] = now + cooldown
	return true
end

-- Shared direction sanitize: trust the client when it sent a sane vector,
-- otherwise fall back to the character look direction on the server (never
-- trust garbage, but never fail the cast because of it either).
local function sanitizeDir(dir: unknown, root: BasePart): Vector3
	if typeof(dir) == "Vector3" and dir.Magnitude > 0.01 then
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude > 0.01 then
			return flat.Unit
		end
	end
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.01 then
		return flatLook.Unit
	end
	return Vector3.new(0, 0, -1)
end

-- Returns the live root part of a player, or nil when dead or missing.
local function getLiveRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or (humanoid :: Humanoid).Health <= 0 then
		return nil
	end
	if root ~= nil and (root :: Instance):IsA("BasePart") then
		return root :: BasePart
	end
	return nil
end

-- Idempotent stun clear: restores WalkSpeed and removes HRushStunned.
-- Safe to call from expiry, death, leave, or round-end paths.
local function clearTayaStun(taya: Player, token: number)
	local st = tayaStun[taya]
	if st == nil or st.token ~= token then
		return
	end
	tayaStun[taya] = nil
	local died = st.diedConn
	if died ~= nil then
		died:Disconnect()
	end
	st.diedConn = nil
	local round = st.roundConn
	if round ~= nil then
		round:Disconnect()
	end
	st.roundConn = nil
	local character = taya.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		(humanoid :: Humanoid).WalkSpeed = st.prevSpeed
	end
	taya:SetAttribute("HRushStunned", nil)
	debugPrint("Tsinelas stun cleared for " .. taya.Name) -- TODO: remove before submission
end

local function applyTayaStun(taya: Player, duration: number): boolean
	local character = taya.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return false
	end
	-- Safe Window does NOT protect against this stun. Safe Window (DESIGN_LOCK
	-- F06, TagService T12) is defined for tags only, so it is ignored here.
	-- F07 dash invulnerability protects against pounce lunges only, so it is
	-- ignored here too. No F07 interaction by design.
	stunTokenCounter += 1
	local token = stunTokenCounter
	local typedHumanoid = humanoid :: Humanoid
	local prevSpeed = typedHumanoid.WalkSpeed
	-- A second hit refreshes instead of stacking: clear the old state first.
	local old = tayaStun[taya]
	if old ~= nil then
		clearTayaStun(taya, old.token)
	end
	local st: StunState = { token = token, prevSpeed = prevSpeed, diedConn = nil, roundConn = nil }
	tayaStun[taya] = st
	taya:SetAttribute("HRushStunned", true)
	typedHumanoid.WalkSpeed = 0
	st.diedConn = typedHumanoid.Died:Connect(function()
		clearTayaStun(taya, token)
	end)
	st.roundConn = ReplicatedStorage:GetAttributeChangedSignal("HRushRoundState"):Connect(function()
		if ReplicatedStorage:GetAttribute("HRushRoundState") ~= "MS_04" then
			clearTayaStun(taya, token)
		end
	end)
	task.delay(duration, function()
		clearTayaStun(taya, token)
	end)
	debugPrint("Tsinelas stun applied to " .. taya.Name .. " for " .. tostring(duration) .. "s") -- TODO: remove before submission
	return true
end

-- Taya lookup. Primary source is the ServerRole attribute set by TagService.
-- Until TagService T11 lands no role is ever set, so a temporary debug path
-- falls back to the nearest live target in front of the caster.
-- TODO: remove before submission (delete the fallback once T11 sets ServerRole).
local function resolveTayaTarget(caster: Player, origin: Vector3, dir: Vector3, maxRange: number): Player?
	for _, other in Players:GetPlayers() do
		if other ~= caster and other:GetAttribute("ServerRole") == "Taya" then
			if getLiveRoot(other) ~= nil then
				return other
			end
		end
	end
	if Config.Debug.AllowAnyRoleForSkills then
		local best: Player? = nil
		local bestDist = maxRange + 1
		for _, other in Players:GetPlayers() do
			if other ~= caster then
				local root = getLiveRoot(other)
				if root ~= nil then
					local to = root.Position - origin
					local dist = to.Magnitude
					if dist <= maxRange and dist < bestDist then
						local flat = Vector3.new(to.X, 0, to.Z)
						if flat.Magnitude < 0.01 or flat.Unit:Dot(dir) > 0 then
							best = other
							bestDist = dist
						end
					end
				end
			end
		end
		if best ~= nil then
			debugPrint("Tsinelas debug fallback target: " .. (best :: Player).Name) -- TODO: remove before submission
		end
		return best
	end
	return nil
end

-- Server-owned projectile simulation. The loop below is the only hit test;
-- no client claim is trusted. Walls block the slipper; only the resolved
-- Taya can be hit; anything else is a miss.
local function simulateTsinelas(caster: Player, target: Player?, origin: Vector3, dir: Vector3)
	local sk = Config.Skills.RS_03
	local speed: number = sk.params.projectileSpeed
	local radius: number = sk.params.projectileRadius
	local maxRange: number = sk.range
	local maxLifetime: number = sk.params.maxLifetime
	local stepDt: number = sk.params.stepDt
	task.spawn(function()
		local pos = origin
		local traveled = 0
		local elapsed = 0
		local hitPos: Vector3? = nil
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.IgnoreWater = true
		while traveled < maxRange and elapsed < maxLifetime do
			if caster.Parent == nil then
				break -- caster left mid flight: miss
			end
			if ReplicatedStorage:GetAttribute("HRushRoundState") ~= "MS_04" then
				break -- round ended mid flight: miss, stun never applies
			end
			local step = speed * stepDt
			local nextPos = pos + dir * step
			-- Wall check so cover blocks the slipper. Both characters are
			-- excluded; the Taya uses the distance check below instead.
			local ignore: { Instance } = {}
			local casterChar = caster.Character
			if casterChar ~= nil then
				table.insert(ignore, casterChar)
			end
			if target ~= nil then
				local targetChar = (target :: Player).Character
				if targetChar ~= nil then
					table.insert(ignore, targetChar)
				end
			end
			rayParams.FilterDescendantsInstances = ignore
			local wall = Workspace:Raycast(pos, dir * step, rayParams)
			if wall ~= nil then
				pos = wall.Position
				break -- blocked by cover: miss
			end
			pos = nextPos
			traveled += step
			elapsed += stepDt
			if target ~= nil then
				local targetRoot = getLiveRoot(target :: Player)
				if targetRoot == nil then
					break -- Taya died or left mid flight: miss
				end
				if (pos - targetRoot.Position).Magnitude <= radius then
					hitPos = targetRoot.Position
					break
				end
			end
			task.wait(stepDt)
		end
		if hitPos ~= nil and target ~= nil then
			applyTayaStun(target :: Player, sk.duration)
			SkillVFX:FireAllClients({
				caster = caster.UserId,
				skillId = "RS_03",
				dir = dir,
				phase = "impact",
				hitPos = hitPos,
			})
			debugPrint("Tsinelas HIT on " .. (target :: Player).Name) -- TODO: remove before submission
		else
			SkillVFX:FireAllClients({
				caster = caster.UserId,
				skillId = "RS_03",
				dir = dir,
				phase = "miss",
				hitPos = pos,
			})
			debugPrint("Tsinelas miss (range, wall, or no target)") -- TODO: remove before submission
		end
	end)
end

-- RS_03 cast path. No airborne or grounded checks: a Runner may throw midair,
-- and the throw never grants tag immunity, so IsAirborne is untouched.
local function handleTsinelas(caster: Player, sk: any, skillId: string, dir: unknown, root: BasePart, now: number)
	if not checkAndSetCooldown(caster, skillId, sk.cooldown, now) then
		return
	end
	local castDir = sanitizeDir(dir, root)
	local origin = root.Position + Vector3.new(0, sk.params.launchHeight, 0) + castDir * 2
	-- Split reply (spec architecture): approved event ONLY to the caster,
	-- VFX event to ALL clients. Clients render cosmetics only.
	SkillApproved:FireClient(caster, {
		skillId = skillId,
		dir = castDir,
		params = sk.params,
	})
	SkillVFX:FireAllClients({
		caster = caster.UserId,
		skillId = skillId,
		dir = castDir,
		phase = "cast",
		origin = origin,
	})
	debugPrint("validation APPROVED for " .. caster.Name .. " (RS_03); SkillApproved to caster, SkillVFX to all") -- TODO: remove before submission
	local target = resolveTayaTarget(caster, origin, castDir, sk.range)
	if target == nil then
		debugPrint("Tsinelas cast with no live Taya; cosmetic flight only") -- TODO: remove before submission
	end
	simulateTsinelas(caster, target, origin, castDir)
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

	-- Stun: HRushStunned is set by pounce/skill effects (T13/T18/T19).
	if player:GetAttribute("HRushStunned") == true then
		deny(player, skillId, "stunned")
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or not ((root :: any) and (root :: any):IsA("BasePart")) then
		deny(player, skillId, "no character")
		return
	end
	if (humanoid :: Humanoid).Health <= 0 then
		deny(player, skillId, "dead")
		return
	end

	local now = os.clock()
	local typedRoot = root :: BasePart

	-- Per-type branch. RS_02 and TS_01-03 are not implemented yet: deny
	-- instead of falling into a path that reads params they do not have.
	if skillId == "RS_03" then
		handleTsinelas(player, sk, skillId, dir, typedRoot, now)
		return
	end
	if skillId ~= "RS_01" then
		deny(player, skillId, "not implemented")
		return
	end

	-- RS_01 original path below, unchanged order: airborne gate, grounded
	-- check, cooldown ledger, direction, mark airborne, split reply.
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
	local ground = Workspace:Raycast(typedRoot.Position, Vector3.new(0, -100, 0), ray)
	if ground == nil or ground.Distance > (sk.params.untouchableHeight - 2) then
		deny(player, skillId, "not grounded")
		return
	end

	if not checkAndSetCooldown(player, skillId, sk.cooldown, now) then
		return
	end
	local castDir = sanitizeDir(dir, typedRoot)

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
	local st = tayaStun[player]
	if st ~= nil then
		clearTayaStun(player, st.token)
	end
end)

debugPrint("Loaded - RS_01 + RS_03 slice (validation + SkillApproved/SkillVFX split + SkillLanded + Tsinelas stun).") -- TODO: remove before submission
print("[SkillService] Loaded - RS_01 + RS_03 slice (validation + server CD + approved/VFX split + Tsinelas sim/stun). T17 draft, RS_02, TS_*: TODO.")
