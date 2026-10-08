--!strict
-- Client-only aim helper. Server tag and pounce checks must never trust it.
-- Integration attributes, set by the server on Player:
-- IsTaya: true for Taya; false or absent for a Runner.
-- LockDelayUntil: server timestamp; T12 blocks acquisition until it expires.
-- LockDisabled: true while TS_03 blocks acquisition and breaks the lock.
-- IsDashing / IsHidden: target flags that break locks (Stage E).
-- RS_02 client effects can require this module and call :BreakLock("DecoySwap").
-- Stage B: acquisition only. Attribute gates and automatic breaks follow in E.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Settings = Config.TargetLock
local LocalPlayer = Players.LocalPlayer
local TargetLockController = {}
local initialized = false
local connections: { RBXScriptConnection } = {}
local target: Player? = nil
local roundLive = false
local cooldownUntil = 0
local scanElapsed = 0
local acquireRequested = false
local TOGGLE_ACTION = "HRUSH_TargetLockToggle"
local CYCLE_ACTION = "HRUSH_TargetLockCycle"

type Candidate = { player: Player, character: Model, root: BasePart, aimPart: BasePart }
local candidates: { Candidate } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- Respect CanQuery rather than treating non-collidable cover as invisible.
rayParams.RespectCanCollide = false

local function debugPrint(message: string)
	if Settings.DebugPrint then
		print("[TargetLockController] " .. message)
	end
end

local function livingRoot(character: Model?): BasePart?
	if not character or not character.Parent then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function aimPart(character: Model): BasePart?
	-- Support R15 and R6 without ever aiming at feet.
	local part = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		or character:FindFirstChild("Head")
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function passesRole(player: Player): boolean
	if Config.Debug.AllowAnyRoleTargetLock then
		return true
	end
	return LocalPlayer:GetAttribute("IsTaya") == true and player:GetAttribute("IsTaya") ~= true
end

local function refreshCandidates()
	table.clear(candidates)
	local character = LocalPlayer.Character
	local root = livingRoot(character)
	if not roundLive or not character or not root then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	for _, player in Players:GetPlayers() do
		if player == LocalPlayer or not passesRole(player) then
			continue
		end
		local otherCharacter = player.Character
		local otherRoot = livingRoot(otherCharacter)
		if not otherCharacter or not otherRoot then
			continue
		end
		local part = aimPart(otherCharacter)
		if not part or (otherRoot.Position - root.Position).Magnitude > Settings.AcquireRange then
			continue
		end
		-- Exclude both avatars so accessories do not count as walls.
		rayParams.FilterDescendantsInstances = { character, otherCharacter }
		local direction = part.Position + Settings.AimPointOffset - head.Position
		if Workspace:Raycast(head.Position, direction, rayParams) == nil then
			table.insert(candidates, { player = player, character = otherCharacter, root = otherRoot, aimPart = part })
		end
	end
end

local function acquire()
	local camera = Workspace.CurrentCamera
	local root = livingRoot(LocalPlayer.Character)
	if not camera or not root or not roundLive or Workspace:GetServerTimeNow() < cooldownUntil then
		return
	end
	local best: Player? = nil
	local bestDot = -math.huge
	local bestDistance = math.huge
	for _, candidate in candidates do
		local direction = candidate.aimPart.Position + Settings.AimPointOffset - camera.CFrame.Position
		if direction.Magnitude == 0 then
			continue
		end
		-- Larger dot product means a smaller angle to the camera centre.
		local dot = camera.CFrame.LookVector:Dot(direction.Unit)
		local distance = (candidate.root.Position - root.Position).Magnitude
		if dot > bestDot or (dot == bestDot and distance < bestDistance) then
			best = candidate.player
			bestDot = dot
			bestDistance = distance
		end
	end
	target = best
	if best then
		debugPrint("Locked " .. best.Name)
	else
		-- Output feedback for Stage B. Player-facing feedback comes with the UI.
		debugPrint("No target")
	end
end

function TargetLockController:GetTarget(): Player?
	return target
end

function TargetLockController:BreakLock(reason: string)
	acquireRequested = false
	if not target then
		return
	end
	target = nil
	cooldownUntil = Workspace:GetServerTimeNow() + Settings.BreakCooldown
	debugPrint("Broken: " .. reason)
end

function TargetLockController:Init()
	if initialized then
		return
	end
	assert(RunService:IsClient(), "TargetLockController is client-only")
	local remotes = ReplicatedStorage:WaitForChild("Remotes", Settings.DependencyTimeout)
	assert(remotes, "TargetLockController: Remotes missing")
	local stateChanged = remotes:WaitForChild("StateChanged", Settings.DependencyTimeout)
	assert(stateChanged and stateChanged:IsA("RemoteEvent"), "TargetLockController: StateChanged missing")
	initialized = true
	roundLive = ReplicatedStorage:GetAttribute("HRushRoundState") == "MS_04"
	table.insert(connections, stateChanged.OnClientEvent:Connect(function(payload: any)
		if typeof(payload) == "table" and typeof(payload.state) == "string" then
			roundLive = payload.state == "MS_04"
		end
	end))
	ContextActionService:BindAction(TOGGLE_ACTION, function(_name, state, _input)
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			if target then
				target = nil
				acquireRequested = false
				debugPrint("Unlocked manually (no cooldown)")
			else
				acquireRequested = not acquireRequested
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Settings.Keybinds.Toggle, Settings.Keybinds.GamepadToggle)
	ContextActionService:BindAction(CYCLE_ACTION, function(_name, state, _input)
		if state == Enum.UserInputState.Begin and target then
			debugPrint("Cycle arrives in Stage C")
		end
		return Enum.ContextActionResult.Sink
	end, false, Settings.Keybinds.Cycle, Settings.Keybinds.GamepadCycle)
	-- Queue input until the next scan rather than raycasting on key spam.
	scanElapsed = 1 / Settings.CandidateRefreshRate
	table.insert(connections, RunService.Heartbeat:Connect(function(dt: number)
		scanElapsed += dt
		local interval = 1 / Settings.CandidateRefreshRate
		if scanElapsed < interval then
			return
		end
		scanElapsed %= interval
		refreshCandidates()
		if acquireRequested then
			acquireRequested = false
			acquire()
		end
	end))
	debugPrint("Stage B ready: " .. Settings.Keybinds.Toggle.Name .. " toggle, " .. Settings.Keybinds.Cycle.Name .. " cycle reserved")
end

function TargetLockController:Destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	table.clear(candidates)
	ContextActionService:UnbindAction(TOGGLE_ACTION)
	ContextActionService:UnbindAction(CYCLE_ACTION)
	target = nil
	acquireRequested = false
	cooldownUntil = 0
	roundLive = false
	initialized = false
end

return TargetLockController
