--!strict
-- ServerScriptService/SpawnRouting.lua
-- Owner: Project Owner
-- Responsibility: choose server-owned lobby and arena respawn locations without changing round spawn sampling.
-- Task/spec: owner-approved lobby island and Kalsada spawn routing, 2026-10-25.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local paths = Config.Spawn

local SpawnRouting = {}
local missingLobbyWarned = false
local missingArenaWarned = false

local function resolve(path: { string }): SpawnLocation?
	local current: Instance = Workspace
	for _, name in ipairs(path) do
		local child = current:FindFirstChild(name)
		if child == nil then return nil end
		current = child
	end
	return if current:IsA("SpawnLocation") and current.Enabled then current else nil
end

function SpawnRouting.arenaSpawn(): SpawnLocation?
	local spawn = resolve(paths.ArenaPath)
	if spawn == nil and not missingArenaWarned then
		missingArenaWarned = true
		warn("[HRUSH_SpawnRouting] Kalsada Map.Spawn is missing or disabled")
	end
	return spawn
end

function SpawnRouting.lobbySpawn(): SpawnLocation?
	local spawn = resolve(paths.LobbyPath)
	if spawn then return spawn end
	if not missingLobbyWarned then
		missingLobbyWarned = true
		warn("[HRUSH_SpawnRouting] Lobby island spawn is missing or disabled; using Kalsada Map.Spawn")
	end
	return SpawnRouting.arenaSpawn()
end

function SpawnRouting.setLobby(player: Player): SpawnLocation?
	local spawn = SpawnRouting.lobbySpawn()
	player.RespawnLocation = spawn
	return spawn
end

function SpawnRouting.setArena(player: Player): SpawnLocation?
	local spawn = SpawnRouting.arenaSpawn()
	player.RespawnLocation = spawn
	return spawn
end

function SpawnRouting.placeLobbyCharacter(player: Player, character: Model): boolean
	if player.Character ~= character or player:GetAttribute("HRushInMatch") == true
		or player:GetAttribute("HRushState") ~= "MS_01"
		or player:GetAttribute("HRushTutorialActive") == true then
		return false
	end
	local spawn = SpawnRouting.setLobby(player)
	if spawn == nil then return false end
	character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
	return true
end

return SpawnRouting
