--!strict
-- ServerScriptService/NametagDefaults.server.lua
-- Owner: Project Owner
-- Responsibility: Suppress duplicate Roblox overhead names and health bars.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local Players = game:GetService("Players")

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then onCharacter(player.Character) end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do onPlayer(player) end
