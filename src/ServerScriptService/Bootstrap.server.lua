--!strict
-- ServerScriptService/Bootstrap.server.lua
-- Owner: Programmer A (T08 greybox dependency)
-- Responsibility: Build the minimal playable arena so the place never loads
-- empty: 150x150 baseplate (Kalsada greybox footprint), 8 equidistant spawns,
-- world lighting defaults, and StarterPlayer character defaults.
-- Re-runnable and idempotent: safe to re-sync via Rojo without duplicating.
-- Full art pass (court, sari-sari, jeepneys, low gaps) lands in T08.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateChanged = Remotes:WaitForChild("StateChanged") :: RemoteEvent

local ARENA_SIZE = 150 -- studs, square (T08: Barangay Kalsada 150x150)
local SPAWN_COUNT = 8
local SPAWN_RADIUS = 55 -- studs from center, equidistant ring

local function ensureBaseplate(): BasePart
	local existing = Workspace:FindFirstChild("KalsadaBaseplate")
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local base = Instance.new("Part")
	base.Name = "KalsadaBaseplate"
	base.Size = Vector3.new(ARENA_SIZE, 2, ARENA_SIZE)
	base.Position = Vector3.new(0, -1, 0) -- top surface at Y=0
	base.Anchored = true
	base.Material = Enum.Material.Grass
	base.Color = Color3.fromRGB(90, 160, 90)
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent = Workspace
	return base
end

local function ensureSpawns()
	local folder = Workspace:FindFirstChild("SpawnLocations")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpawnLocations"
		folder.Parent = Workspace
	end
	for i = 1, SPAWN_COUNT do
		local name = string.format("Spawn%02d", i)
		local spawn = folder:FindFirstChild(name)
		if not spawn then
			spawn = Instance.new("SpawnLocation")
			spawn.Name = name
			spawn.Parent = folder
		end
		if spawn:IsA("SpawnLocation") then
			local angle = (math.pi * 2 / SPAWN_COUNT) * (i - 1)
			spawn.Position = Vector3.new(
				math.cos(angle) * SPAWN_RADIUS,
				3, -- 3 studs above ground so characters never clip on spawn
				math.sin(angle) * SPAWN_RADIUS
			)
			spawn.Size = Vector3.new(6, 1, 6)
			spawn.Anchored = true
			spawn.Enabled = true
			spawn.AllowTeamChangeOnTouch = false
			spawn.Neutral = true
			spawn.Material = Enum.Material.SmoothPlastic
			spawn.Color = Color3.fromRGB(60, 140, 220)
			spawn.TopSurface = Enum.SurfaceType.Smooth
			spawn.BottomSurface = Enum.SurfaceType.Weld
			-- Hide the decal so the greybox stays clean.
			local decal = spawn:FindFirstChildOfClass("Decal")
			if decal then
				decal:Destroy()
			end
		end
	end
end

local function ensureLighting()
	Lighting.Ambient = Color3.fromRGB(120, 120, 120)
	Lighting.Brightness = 2
	Lighting.ClockTime = 14 -- afternoon, high readability for playtests
	Lighting.GlobalShadows = true
end

local function ensureCharacterDefaults()
	-- T09 tuning relies on WalkSpeed set at runtime, but sane defaults help
	-- before MovementController attaches (avoids 16-vs-default pop).
	StarterPlayer.CharacterWalkSpeed = Config.Movement.RunnerWalkSpeed
	StarterPlayer.CharacterJumpPower = 50 -- Roblox default; vaults <= 4 studs (T08)
end

ensureBaseplate()
ensureSpawns()
ensureLighting()
ensureCharacterDefaults()

-- TEMP DEBUG (remove when MatchService T07 lands): no match state machine exists
-- yet, so nothing ever fires StateChanged MS_04 and MovementController stays in
-- inputLocked (WalkSpeed 0). Auto-unlock shortly after each spawn so T09 movement
-- is testable in Studio Play right now. MatchService will own this event later.
local DEBUG_AUTO_UNLOCK = true
if DEBUG_AUTO_UNLOCK then
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(1.5)
			StateChanged:FireClient(player, { state = "MS_04", role = "Runner" })
		end)
	end)
	-- Cover the player that spawned before this script ran (Play Solo).
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			if not player.Character then
				player.CharacterAdded:Wait()
			end
			task.wait(1.5)
			StateChanged:FireClient(player, { state = "MS_04", role = "Runner" })
		end)
	end
end

-- Late-join safety: if Workspace gets cleared, rebuild once.
Workspace.ChildRemoved:Connect(function(child)
	if child.Name == "KalsadaBaseplate" then
		task.defer(ensureBaseplate)
	end
end)

print(string.format(
	"[Bootstrap] Arena ready — %dx%d baseplate, %d spawns @ r=%d. T09 movement testable.",
	ARENA_SIZE,
	ARENA_SIZE,
	SPAWN_COUNT,
	SPAWN_RADIUS
))