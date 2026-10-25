--!strict
-- ServerScriptService/TutorialGateway.server.lua
-- Owner: Project Owner
-- Responsibility: lobby tutorial status, validated entry, and admission into
-- the in-place lesson. When the module detects the main place it runs the
-- session on the training strip far from Kalsada; the separate tutorial place
-- teleport flow exists only in the standalone build.
-- Task/spec: owner-approved Classic Tag tutorial in the main place, 2026-10-25.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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
local TutorialModule = require(ServerScriptService:WaitForChild("TutorialService") :: ModuleScript)
local Tutorial = TutorialModule :: { Admit: (player: Player) -> (boolean, string?) }

local lastRequest: { [Player]: number } = {}
local admitting: { [Player]: boolean } = {}

local function errorTo(player: Player, message: string)
	TutorialEvent:FireClient(player, "Error", message)
end

local function load(player: Player)
	-- An active lesson writes the save attributes itself; the status read must
	-- not stomp them.
	if player:GetAttribute("HRushTutorialActive") == true then return end
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
	if admitting[player] then return end
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
	admitting[player] = true
	player:SetAttribute("HRushTutorialTeleporting", true)
	local ok, message = Tutorial.Admit(player)
	if not ok then
		admitting[player] = nil
		player:SetAttribute("HRushTutorialTeleporting", false)
		if player.Parent then
			errorTo(player, message or "Could not open the tutorial. Please try again.")
		end
		return
	end
	-- Only mark the prompt dismissed after admission so a failed start can be
	-- retried immediately.
	if status == "new" then
		player:SetAttribute("HRushTutorialStatus", "later")
		task.spawn(Progress.mark, player.UserId, "later")
	end
	admitting[player] = nil
	player:SetAttribute("HRushTutorialTeleporting", false)
end)

Players.PlayerRemoving:Connect(function(player)
	lastRequest[player] = nil
	admitting[player] = nil
end)
