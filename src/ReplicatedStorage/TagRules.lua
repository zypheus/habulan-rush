--!strict
-- ReplicatedStorage/TagRules.lua
-- Shared tag validation rules. WHY: the touch tag (TM_08) and the pounce
-- (TM_05) must agree on when a Runner cannot be tagged, so the check lives in
-- ONE module that both server paths call. Server authoritative.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local TagRules = {}

-- Returns true when the character's root part floats higher than
-- `untouchableHeight` above the ground under it. RS_01 makes Runners fly, and
-- a Runner high in the air must not be tagged until they land again.
function TagRules.isUntouchable(character: Model): boolean
	local params = Config.Skills.RS_01.params
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return true -- no root means we cannot place a tag safely: treat as out of reach
	end

	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { character }
	ray.IgnoreWater = true

	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -500, 0), ray)
	if not hit then
		return true -- nothing below to land on: also out of reach
	end
	return hit.Distance > params.untouchableHeight
end

return TagRules