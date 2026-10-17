--!strict
-- ServerScriptService/TagService.server.lua
-- Owner: Project Owner
-- Responsibility: authoritative pounce lifecycle, spatial hit validation, and one-hit ledger.
-- Task/spec: moving ground/air pounce; only pounce tags, including bots, approved 2026-10-17.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Pounce = Config.Pounce
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestPounce = Remotes:WaitForChild("RequestPounce") :: RemoteEvent
local PounceEvent = Remotes:WaitForChild("PounceEvent") :: RemoteEvent
local CommitTag = ServerScriptService:WaitForChild("HRUSH_CommitPounceTag") :: BindableFunction

type Attempt = {
	id: number, state: string, character: Model, launchAt: number, direction: Vector3, seenAir: boolean,
	origin: Vector3, previous: Vector3, travel: number, resolved: boolean, hit: boolean,
	contactAt: number, recoveryUntil: number, landingSent: boolean,
	botTrack: AnimationTrack?, botSpeed: number?, botAutoRotate: boolean?,
}
type Ledger = { lastId: number, readyAt: number, lastRequestAt: number, active: Attempt? }
local ledgers: { [Instance]: Ledger } = {}
local hitConeDot = math.cos(math.rad(Pounce.MaxTagAngle))

local function log(message: string)
	if Pounce.Debug and RunService:IsStudio() then print("[Pounce] " .. message) end
end

local function getLedger(player: Instance): Ledger
	local ledger = ledgers[player]
	if not ledger then
		ledger = { lastId = 0, readyAt = 0, lastRequestAt = 0, active = nil }
		ledgers[player] = ledger
	end
	return ledger
end

local function getRig(player: Instance): (Model?, Humanoid?, BasePart?)
	local character = if player:IsA("Player") then player.Character else (if player:IsA("Model") then player else nil)
	if not character then return nil, nil, nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return nil, nil, nil end
	return character, humanoid, root
end

-- FloorMaterial on a client-owned Humanoid can lag its replicated motion.
local function grounded(character: Model, humanoid: Humanoid, root: BasePart): boolean
	if root.AssemblyLinearVelocity.Y > 1 then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local feet = humanoid.HipHeight + root.Size.Y * 0.5
	return Workspace:Raycast(root.Position, -Vector3.yAxis * (feet + Pounce.GroundTolerance), params) ~= nil
end

local function notify(player: Instance, kind: string, id: number, readyIn: number?, target: Instance?)
	local _, _, root = getRig(player)
	local position = root and root.Position or Vector3.zero
	if target then
		local _, _, targetRoot = getRig(target)
		if targetRoot then
			local towardActor = (position - targetRoot.Position) * Vector3.new(1, 0, 1)
			local height = if target:GetAttribute("HRushServerSliding") == true then Pounce.SlidingTargetOffset else Pounce.StandingTargetOffset
			position = targetRoot.Position + Vector3.yAxis * height
			if towardActor.Magnitude > 0.01 then position += towardActor.Unit * targetRoot.Size.Z * 0.5 end
		end
	end
	local remaining = readyIn or 0
	local payload = { actorId = if player:IsA("Player") then player.UserId else 0, actor = player, kind = kind, id = id, readyIn = remaining,
		readyAtServer = Workspace:GetServerTimeNow() + remaining, targetId = if target and target:IsA("Player") then target.UserId else 0, position = position }
	if kind == "Denied" then
		if player:IsA("Player") then PounceEvent:FireClient(player, payload) end
	else PounceEvent:FireAllClients(payload) end
end

local function setState(player: Instance, state: string, active: boolean)
	player:SetAttribute("HRushPouncing", active)
	player:SetAttribute("HRushPounceState", state)
end

local function stopBotPose(attempt: Attempt)
	local track = attempt.botTrack
	if track then
		track:Stop(Pounce.AnimationFade)
		task.delay(Pounce.AnimationFade, function() track:Destroy() end)
		attempt.botTrack = nil
	end
end

local function playBotPose(attempt: Attempt, name: string)
	if attempt.botSpeed == nil then return end
	stopBotPose(attempt)
	local humanoid = attempt.character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then animator = Instance.new("Animator"); animator.Parent = humanoid end
	local animation = Instance.new("Animation")
	animation.AnimationId = Pounce.Animations[name]
	local ok, track = pcall(function() return (animator :: Animator):LoadAnimation(animation) end)
	animation:Destroy()
	if ok then
		attempt.botTrack = track
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		track:Play(Pounce.AnimationFade)
	end
end

local function restoreBot(attempt: Attempt)
	stopBotPose(attempt)
	local humanoid = attempt.character:FindFirstChildOfClass("Humanoid")
	if humanoid and attempt.botSpeed ~= nil then
		humanoid.WalkSpeed = attempt.botSpeed
		humanoid.AutoRotate = attempt.botAutoRotate == true
		local root = attempt.character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
		end
	end
end

local function finish(player: Instance, ledger: Ledger, attempt: Attempt, hit: boolean, target: Instance?)
	if ledger.active ~= attempt then return end
	if attempt.resolved then return end
	attempt.resolved = true
	attempt.hit = hit
	attempt.contactAt = os.clock()
	attempt.state = if hit then "Contact" else "Landing"
	ledger.readyAt = math.max(ledger.readyAt, attempt.launchAt + (if hit then Pounce.HitCooldown else Pounce.MissCooldown))
	setState(player, attempt.state, true)
	if attempt.botSpeed ~= nil then
		local _, humanoid, root = getRig(player)
		if humanoid then humanoid.WalkSpeed = attempt.botSpeed * Pounce.RecoverySpeedMult end
		if root then root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0) end
		playBotPose(attempt, if hit then "Tag" else "Recovery")
	end
	notify(player, if hit then "Hit" else "Miss", attempt.id, math.max(0, ledger.readyAt - os.clock()), target)
	log(string.format("%s id=%d %s", player.Name, attempt.id, if hit then "hit" else "miss"))
end

local function cancel(player: Instance, ledger: Ledger, attempt: Attempt)
	if ledger.active ~= attempt then return end
	restoreBot(attempt)
	ledger.active = nil
	ledger.readyAt = math.max(ledger.readyAt, attempt.launchAt + Pounce.MissCooldown)
	setState(player, "Cooldown", false)
	notify(player, "Cancel", attempt.id, math.max(0, ledger.readyAt - os.clock()))
end

local function eligible(player: Instance, ledger: Ledger, now: number): (boolean, Model?, BasePart?)
	local character, humanoid, root = getRig(player)
	if not Pounce.Enabled or now < ledger.readyAt or ledger.active ~= nil then return false, character, root end
	if player:GetAttribute("HRushState") ~= "MS_04" or player:GetAttribute("HRushInMatch") ~= true then return false, character, root end
	if player:GetAttribute("HRushRole") ~= "Taya" or player:GetAttribute("HRushStunned") == true then return false, character, root end
	local skillBusyUntil = player:GetAttribute("HRushSkillBusyUntil")
	if typeof(skillBusyUntil) == "number" and now < skillBusyUntil then return false, character, root end
	if player:GetAttribute("IsAirborne") == true then return false, character, root end
	if player:GetAttribute("HRushServerSliding") == true or player:GetAttribute("HRushServerDashing") == true
		or player:GetAttribute("HRushServerRolling") == true or player:GetAttribute("HRushServerVaulting") == true then return false, character, root end
	if not character or not humanoid or not root or humanoid.Health <= 0 or root.Anchored then return false, character, root end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then return false, character, root end
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if horizontal.Magnitude ~= horizontal.Magnitude or horizontal.Magnitude == math.huge then return false, character, root end
	if horizontal.Magnitude < Pounce.MinMoveSpeed
		or forward.Magnitude < 0.5 or horizontal.Unit:Dot(forward.Unit) < Pounce.MinForwardDot then return false, character, root end
	return true, character, root
end

local function requestPounce(player: Instance, id: unknown)
	local now = os.clock()
	local ledger = getLedger(player)
	if now - ledger.lastRequestAt < Pounce.RequestInterval then return end
	ledger.lastRequestAt = now
	if typeof(id) ~= "number" or id ~= id or id % 1 ~= 0 or id <= ledger.lastId or id > 1000000000 then return end
	ledger.lastId = id
	local valid, character, root = eligible(player, ledger, now)
	if not valid or not character or not root then
		notify(player, "Denied", id, math.max(0, ledger.readyAt - now))
		log(string.format("%s id=%d denied", player.Name, id))
		return
	end
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local attempt: Attempt = {
		id = id, state = "Windup", character = character,
		launchAt = now + Pounce.WindupTime, direction = horizontal.Unit, seenAir = false,
		origin = root.Position, previous = root.Position, travel = 0, resolved = false, hit = false,
		contactAt = 0, recoveryUntil = 0, landingSent = false,
		botTrack = nil, botSpeed = if player:IsA("Model") then humanoid.WalkSpeed else nil,
		botAutoRotate = if player:IsA("Model") then humanoid.AutoRotate else nil,
	}
	ledger.active = attempt
	ledger.readyAt = attempt.launchAt + Pounce.HitCooldown
	setState(player, "Windup", true)
	player:SetAttribute("HRushPounceId", id)
	notify(player, "Approved", id)
	log(string.format("%s id=%d approved", player.Name, id))
	if player:IsA("Model") then
		humanoid.AutoRotate = false
		playBotPose(attempt, "Windup")
	end
end

RequestPounce.OnServerEvent:Connect(requestPounce)
local requestBot = Instance.new("BindableEvent")
requestBot.Name = "HRUSH_RequestBotPounce"
requestBot.Parent = ServerScriptService
requestBot.Event:Connect(function(bot: Instance)
	local bots = Workspace:FindFirstChild("Bots")
	if not bots or not bot:IsA("Model") or bot.Parent ~= bots or bot:GetAttribute("IsBot") ~= true then return end
	requestPounce(bot, getLedger(bot).lastId + 1)
end)

local function queryTarget(player: Instance, attempt: Attempt, root: BasePart): Instance?
	local box = CFrame.lookAt(root.Position, root.Position + attempt.direction) * CFrame.new(Pounce.HitboxOffset)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	local characters: { Instance } = {}
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player and candidate.Character then table.insert(characters, candidate.Character) end
	end
	local bots = Workspace:FindFirstChild("Bots")
	if bots then table.insert(characters, bots) end
	overlap.FilterDescendantsInstances = characters
	local closest: Instance? = nil
	local best = math.huge
	for _, part in Workspace:GetPartBoundsInBox(box, Pounce.HitboxSize, overlap) do
		local model = part:FindFirstAncestorOfClass("Model")
		local target: Instance? = model and Players:GetPlayerFromCharacter(model)
		if not target and model and model.Parent == bots and model:GetAttribute("IsBot") == true then target = model end
		if target and target ~= player and target:GetAttribute("HRushInMatch") == true and target:GetAttribute("HRushRole") == "Runner" then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local targetRoot = model:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and targetRoot and targetRoot:IsA("BasePart") then
				local point = targetRoot.Position + Vector3.new(0, if target:GetAttribute("HRushServerSliding") == true then Pounce.SlidingTargetOffset else Pounce.StandingTargetOffset, 0)
				local localPoint = box:PointToObjectSpace(point)
				local delta = point - root.Position
				local flat = Vector3.new(delta.X, 0, delta.Z)
				local immuneUntil = target:GetAttribute("HRushPounceImmuneUntil")
				if math.abs(localPoint.X) <= Pounce.HitboxSize.X * 0.5
					and math.abs(localPoint.Y) <= Pounce.HitboxSize.Y * 0.5
					and math.abs(localPoint.Z) <= Pounce.HitboxSize.Z * 0.5
					and flat.Magnitude > 0.1 and delta.Magnitude <= Pounce.MaxHitDistance
					and attempt.direction:Dot(flat.Unit) >= hitConeDot
					and (typeof(immuneUntil) ~= "number" or immuneUntil <= os.clock()) then
					local rayParams = RaycastParams.new()
					rayParams.FilterType = Enum.RaycastFilterType.Exclude
					rayParams.FilterDescendantsInstances = { attempt.character }
					local ray = Workspace:Raycast(root.Position, delta, rayParams)
					if (not ray or ray.Instance:IsDescendantOf(model)) and flat.Magnitude < best then
						closest = target
						best = flat.Magnitude
					end
				end
			end
		end
	end
	return closest
end

local function validTravel(attempt: Attempt, root: BasePart, now: number): (boolean, boolean)
	local position = root.Position
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z
		or position.Magnitude == math.huge then return false, false end
	local step = position - attempt.previous
	attempt.travel += Vector3.new(step.X, 0, step.Z).Magnitude
	local elapsed = math.max(0, now - attempt.launchAt) + Pounce.WindupTime
	if attempt.travel > Pounce.ForwardSpeed * elapsed + Pounce.TravelSlack
		or position.Y - attempt.origin.Y > Pounce.MaxRise then return false, false end
	local displacement = (position - attempt.origin) * Vector3.new(1, 0, 1)
	if displacement.Magnitude > Pounce.TravelSlack
		and displacement.Unit:Dot(attempt.direction) < math.cos(math.rad(Pounce.MaxSteerAngle)) then return false, false end
	local filter: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then table.insert(filter, other.Character) end
	end
	local bots = Workspace:FindFirstChild("Bots")
	if bots then table.insert(filter, bots) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = filter
	params.RespectCanCollide = true
	local wall = if step.Magnitude > 0.01 then Workspace:Blockcast(CFrame.new(attempt.previous), Pounce.WallProbeSize, step, params) else nil
	attempt.previous = position
	return true, wall ~= nil and math.abs(wall.Normal.Y) < Pounce.WallMaxNormalY
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for player, ledger in ledgers do
		if not player:IsDescendantOf(game) then
			if ledger.active then restoreBot(ledger.active) end
			ledgers[player] = nil
			continue
		end
		local attempt = ledger.active
		if attempt then
			local character, humanoid, root = getRig(player)
			if character ~= attempt.character or not humanoid or humanoid.Health <= 0 or not root
				or (not attempt.hit and player:GetAttribute("HRushRole") ~= "Taya") or player:GetAttribute("HRushState") ~= "MS_04"
				or player:GetAttribute("HRushStunned") == true then
				cancel(player, ledger, attempt)
			elseif attempt.resolved then
				local onGround = grounded(character :: Model, humanoid, root)
				if onGround and not attempt.landingSent then
					attempt.landingSent = true
					notify(player, if attempt.hit then "Land" else "MissLand", attempt.id)
				end
				if attempt.state == "Contact" and now - attempt.contactAt >= Pounce.TagPoseTime
					and (onGround or now - attempt.launchAt >= Pounce.MaxAirTime) then
					attempt.state = "Landing"
				end
				if attempt.state == "Landing" then
					attempt.state = "Recovery"
					playBotPose(attempt, "Recovery")
					attempt.recoveryUntil = now + (if attempt.hit then Pounce.HitRecovery else Pounce.MissRecovery)
					setState(player, "Recovery", true)
				elseif attempt.state == "Recovery" and now >= attempt.recoveryUntil then
					restoreBot(attempt)
					ledger.active = nil
					setState(player, "Cooldown", false)
				end
			elseif now >= attempt.launchAt then
				if attempt.state == "Windup" then
					setState(player, "Launching", true)
					attempt.state = "Airborne"
					setState(player, "Airborne", true)
					if attempt.botSpeed ~= nil then
						humanoid.WalkSpeed = 0
						humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
						root.AssemblyLinearVelocity = attempt.direction * Pounce.ForwardSpeed + Vector3.yAxis * Pounce.UpwardSpeed
						playBotPose(attempt, "Leap")
					end
					notify(player, "Launch", attempt.id)
				end
				if attempt.botSpeed ~= nil then
					root.AssemblyLinearVelocity = attempt.direction * Pounce.ForwardSpeed + Vector3.yAxis * root.AssemblyLinearVelocity.Y
				end
				local onGround = grounded(character :: Model, humanoid, root)
				if not onGround then attempt.seenAir = true end
				local travelOk, wall = validTravel(attempt, root, now)
				if not travelOk then
					log(player.Name .. " travel rejected")
					cancel(player, ledger, attempt)
				elseif wall or now - attempt.launchAt >= Pounce.MaxAirTime
					or (attempt.seenAir and now - attempt.launchAt > Pounce.MinAirTime and onGround) then
					finish(player, ledger, attempt, false, nil)
				elseif attempt.seenAir then
					local target = queryTarget(player, attempt, root)
					if target and CommitTag:Invoke(player, target) == true then finish(player, ledger, attempt, true, target) end
				end
			end
		elseif now >= ledger.readyAt and player:GetAttribute("HRushPounceState") ~= "Ready" then
			setState(player, "Ready", false)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ledgers[player] = nil
end)
