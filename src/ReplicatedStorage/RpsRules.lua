--!strict
-- ReplicatedStorage/RpsRules.lua
-- Owner: Project Owner
-- Responsibility: Pure bato bato pick stage resolution.
-- Task/spec: MS_RPS first Taya selection, GDD 3.2 / System Spec 2.1.

local RpsRules = {}

local beats = { Rock = "Scissors", Paper = "Rock", Scissors = "Paper" }

function RpsRules.Resolve(signs: { [number]: string }): (boolean, { number })
	local shown: { [string]: boolean } = {}
	local count = 0
	for _, sign in pairs(signs) do
		if not shown[sign] then
			shown[sign] = true
			count += 1
		end
	end
	if count ~= 2 then
		return true, {}
	end

	local winningSign = ""
	for sign, defeated in pairs(beats) do
		if shown[sign] and shown[defeated] then
			winningSign = sign
			break
		end
	end
	local safe: { number } = {}
	for userId, sign in pairs(signs) do
		if sign == winningSign then
			table.insert(safe, userId)
		end
	end
	table.sort(safe)
	return false, safe
end

return RpsRules
