--!strict
-- tests/MatchShowcase.spec.lua
-- Owner: Project Owner
-- Responsibility: Pure framing assertions for the actual showcase distance function.
-- Task/spec: match opening acceptance, approved 2026-10-25.
-- Owner may run after syncing; these assertions never change match or player state.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local Showcase = require(game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("MatchShowcase"))
local tuning = Config.Match.Showcase
local vertical = math.tan(math.rad(tuning.FieldOfView / 2))
local cases = {
	Vector3.new(4, 7, 3), -- One player.
	Vector3.new(48, 10, 5), -- Eight players with accessories.
	Vector3.new(80, 18, 10), -- Oversized appearance bounds.
}

for _, viewport in { Vector2.new(1920, 1080), Vector2.new(568, 320), Vector2.new(390, 844) } do
	local reserve = math.min(0.5, tuning.TitleReserve / viewport.Y)
	for _, size in cases do
		for _, push in { 1, tuning.PushInScale } do
			local distance = Showcase.fitDistance(size, viewport) * push
			assert(distance > size.Z / 2 and distance < math.huge, "camera must stay outside the avatar bounds")
			local offset = distance * vertical * reserve
			local length = math.sqrt(distance * distance + offset * offset)
			local cosine, sine = distance / length, offset / length
			for _, x in { -size.X / 2, size.X / 2 } do
				for _, y in { -size.Y / 2, size.Y / 2 } do
					for _, z in { -size.Z / 2, size.Z / 2 } do
						local depth = (distance - z) * cosine - y * sine
						local screenX = x / (depth * vertical * viewport.X / viewport.Y)
						local screenY = (y * cosine + (distance - z) * sine) / (depth * vertical)
						assert(math.abs(screenX) < 1 and screenY < 1, "a lineup corner leaves the screen")
						assert(screenY > -1 + 2 * reserve, "the title obscures the lineup")
					end
				end
			end
		end
	end
end

local zeroViewport = Showcase.fitDistance(cases[1], Vector2.zero)
assert(zeroViewport > 0 and zeroViewport < math.huge, "initial zero-size viewport must stay finite")
print("[HRUSH_ShowcaseTest] Framing assertions passed")
