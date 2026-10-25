--!strict
-- ServerScriptService/TutorialGateway.server.lua
-- Owner: Project Owner
-- Responsibility: lobby tutorial status, validated entry, and reserved-server teleport.
-- Task/spec: owner-approved Classic Tag tutorial, 2026-10-25.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local function findRemotes(): Folder
	for _, child in ReplicatedStorage:GetChildren() do
		if child.Name == "Remotes" and child:IsA("Folder") and child:FindFirstChild("QueueEvent") then
			return child
		end
	end
	return ReplicatedStorage:WaitForChild("Remotes") :: Folder
end
local remotes = findRemotes()
for _, child in ReplicatedStorage:GetChildren() do
	if child.Name == "Remotes" and child:IsA("Folder") and child ~= remotes then
		child:Destroy()
	end
end
local existingEvent = remotes:FindFirstChild("TutorialEvent")
local TutorialEvent: RemoteEvent
if existingEvent and existingEvent:IsA("RemoteEvent") then
	TutorialEvent = existingEvent
else
	TutorialEvent = Instance.new("RemoteEvent")
	TutorialEvent.Name = "TutorialEvent"
	TutorialEvent.Parent = remotes
end

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Progress = require(ServerScriptService:WaitForChild("TutorialProgress"))
local PartyService = require(ServerScriptService:WaitForChild("PartyService"))

local lastRequest: { [Player]: number } = {}
local teleporting: { [Player]: boolean } = {}

local function errorTo(player: Player, message: string)
	TutorialEvent:FireClient(player, "Error", message)
end

local function load(player: Player)
	player:SetAttribute("HRushTutorialStatus", "Loading")
	player:SetAttribute("HRushTutorialCompleted", false)
	local status = Progress.read(player.UserId)
	if not player.Parent then return end
	player:SetAttribute("HRushTutorialStatus", if status then status else "Unavailable")
	player:SetAttribute("HRushTutorialCompleted", status == "complete")
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(load, player)
end)
for _, player in Players:GetPlayers() do task.spawn(load, player) end

TutorialEvent.OnServerEvent:Connect(function(player: Player, action: unknown)
	if typeof(action) ~= "string" or (action ~= "Start" and action ~= "Later") then return end
	local now = os.clock()
	if now - (lastRequest[player] or -math.huge) < Config.Tutorial.RequestInterval then return end
	lastRequest[player] = now
	local status = player:GetAttribute("HRushTutorialStatus")
	if action == "Later" then
		if status ~= "new" then return end
		player:SetAttribute("HRushTutorialStatus", "later")
		task.spawn(function()
			if not Progress.mark(player.UserId, "later") and player.Parent then
				errorTo(player, "Could not save your choice. The tutorial may appear again next visit.")
			end
		end)
		return
	end
	if teleporting[player] then return end
	if status == "Loading" then
		errorTo(player, "Tutorial status is still loading. Try again shortly.")
		return
	end
	if player:GetAttribute("HRushQueue") ~= "Idle" or player:GetAttribute("HRushInMatch") == true then
		errorTo(player, "Leave the match queue before starting the tutorial.")
		return
	end
	local party = PartyService.GetParty(player)
	if party and #party.members ~= 1 then
		errorTo(player, "Leave your party to start the solo tutorial.")
		return
	end
	if Config.Tutorial.PlaceId <= 0 then
		errorTo(player, "Tutorial place is not published yet.")
		return
	end
	if RunService:IsStudio() then
		errorTo(player, "Studio cannot teleport. Publish both places, then play this experience in Roblox.")
		return
	end
	teleporting[player] = true
	player:SetAttribute("HRushTutorialTeleporting", true)
	if status == "new" then
		player:SetAttribute("HRushTutorialStatus", "later")
		task.spawn(Progress.mark, player.UserId, "later")
	end
	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = true
	local ok, teleportError = pcall(function()
		TeleportService:TeleportAsync(Config.Tutorial.PlaceId, { player }, options)
	end)
	if not ok and player.Parent then
		warn(string.format("[TutorialGateway] TeleportAsync failed for place %d in universe %d: %s", Config.Tutorial.PlaceId, game.GameId, tostring(teleportError)))
		teleporting[player] = nil
		player:SetAttribute("HRushTutorialTeleporting", false)
		errorTo(player, "Could not open the tutorial. Please try again.")
	end
end)

TeleportService.TeleportInitFailed:Connect(function(player: Player, result, message, placeId)
	if placeId ~= Config.Tutorial.PlaceId or not teleporting[player] then return end
	warn(string.format("[TutorialGateway] TeleportInitFailed for place %d in universe %d: %s (%s)", placeId, game.GameId, tostring(result), tostring(message)))
	teleporting[player] = nil
	if player.Parent then
		player:SetAttribute("HRushTutorialTeleporting", false)
		errorTo(player, "Could not open the tutorial. Please try again.")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
	teleporting[player] = nil
end)
