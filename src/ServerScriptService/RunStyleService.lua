local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Cosmetics = ReplicatedStorage:WaitForChild("Cosmetics")
local RunStyles = require(Cosmetics:WaitForChild("RunStyles"))

local remote = Instance.new("RemoteEvent")
remote.Name = "SetRunStyle"
remote.Parent = Cosmetics

-- MatchService fires this once when the match starts.
local trigger = Instance.new("BindableEvent")
trigger.Name = "RandomizeRunStyles"
trigger.Parent = ServerStorage

local SLOTS = { "Idle", "Walk", "Run", "Jump", "Fall" }
local chosen = {}
local lastRequest = {}
local defaults = setmetatable({}, { __mode = "k" })
local rng = Random.new()
local deck = {}

local function toId(str)
	return tonumber(string.match(str or "", "%d+")) or 0
end

local function nextStyle()
	if #deck == 0 then
		for name in RunStyles do
			if name ~= "Default" then
				table.insert(deck, name)
			end
		end
		for i = #deck, 2, -1 do
			local j = rng:NextInteger(1, i)
			deck[i], deck[j] = deck[j], deck[i]
		end
	end
	return table.remove(deck)
end

local function applyStyle(player, character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local ok, desc = pcall(function()
		return hum:GetAppliedDescription()
	end)
	if not ok or not desc then
		warn("[RunStyle] GetAppliedDescription failed:", desc)
		return
	end

	defaults[character] = defaults[character] or {}
	local style = RunStyles[chosen[player] or "Default"] or {}

	for _, slot in SLOTS do
		local prop = slot .. "Animation"
		defaults[character][slot] = defaults[character][slot] or desc[prop]
		local id = toId(style[slot])
		desc[prop] = (id ~= 0) and id or defaults[character][slot]
	end

	local applied, err = pcall(function()
		hum:ApplyDescription(desc)
	end)
	if not applied then
		warn("[RunStyle] ApplyDescription failed:", err)
	end
end

local function randomizeAll()
	for _, player in Players:GetPlayers() do
		chosen[player] = nextStyle()
		print("[RunStyle]", player.Name, "->", chosen[player])
		if player.Character then
			applyStyle(player, player.Character)
		end
	end
end

trigger.Event:Connect(randomizeAll)

local function setup(player)
	player.CharacterAdded:Connect(function(character)
		if chosen[player] then
			character:WaitForChild("Humanoid")
			task.wait(0.5) -- let the character finish loading
			applyStyle(player, character)
		end
	end)
end

Players.PlayerAdded:Connect(setup)
for _, p in Players:GetPlayers() do
	setup(p)
end

remote.OnServerEvent:Connect(function(player, styleName)
	if typeof(styleName) ~= "string" or not RunStyles[styleName] then return end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 1 then return end -- rate limit
	lastRequest[player] = now
	chosen[player] = styleName
	if player.Character then
		applyStyle(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(p)
	chosen[p] = nil
	lastRequest[p] = nil
end)
