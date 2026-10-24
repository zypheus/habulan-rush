--!strict
-- ServerScriptService/SpawnSelector.lua
-- Owner: Project Owner
-- Responsibility: server-only continuous round spawn sampling on authored walkable ground.
-- Task/spec: owner-approved open-experience random spawn plan, 2026-10-24.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local settings = Config.Spawn
local bounds = Config.Maps.Kalsada.arena
local random = Random.new()

local SpawnSelector = {}

-- The open Studio map keeps its authored ground at Workspace root. The full
-- repository map carries these tags in its asset; mark the same surfaces when
-- syncing only the spawn overlay into the existing edit session.
local function markAuthoredGround()
	local map = Workspace:FindFirstChild("Map")
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if instance:IsA("Part") and instance.CanCollide then
			local parent = instance.Parent
			local top = instance.Position.Y + instance.Size.Y / 2
			local area = instance.Size.X * instance.Size.Z
			local isPath = parent ~= nil and parent.Name == "Path"
				and (instance.Name == "LIGHTGREEN" or instance.Name == "LIGHTBROWN")
				and area >= 20 and top >= 0 and top <= 7
			local isRoad = parent ~= nil and parent.Name == "Road"
				and instance.Name == "Part" and math.abs(top - 2.1) < 0.3
			local isPlaza = (parent == Workspace or parent == map)
				and instance.Name == "Part" and area >= 200 and top >= 1.5 and top <= 4.5
			if (isPath or isRoad or isPlaza)
				and not CollectionService:HasTag(instance, settings.GroundTag) then
				CollectionService:AddTag(instance, settings.GroundTag)
			end
		end
	end
end

local function regionFolder(): Folder?
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild(settings.RegionFolder)
	return if folder and folder:IsA("Folder") then folder else nil
end

function SpawnSelector.inArena(position: Vector3): boolean
	return position.X >= bounds.minX and position.X <= bounds.maxX
		and position.Z >= bounds.minZ and position.Z <= bounds.maxZ
		and position.Y >= bounds.minY and position.Y <= bounds.maxY
end

local function regions(): ({ BasePart }, number)
	local folder = regionFolder()
	local list: { BasePart } = {}
	local totalArea = 0
	if folder == nil then return list, totalArea end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			local width = child.Size.X - 2 * settings.RegionEdgeInset
			local depth = child.Size.Z - 2 * settings.RegionEdgeInset
			if width > 0 and depth > 0 and child.Size.Y > 0 then
				table.insert(list, child)
				totalArea += width * depth
			end
		end
	end
	return list, totalArea
end

local function chooseRegion(list: { BasePart }, totalArea: number): BasePart
	local draw = random:NextNumber(0, totalArea)
	for _, region in ipairs(list) do
		draw -= (region.Size.X - 2 * settings.RegionEdgeInset)
			* (region.Size.Z - 2 * settings.RegionEdgeInset)
		if draw <= 0 then return region end
	end
	return list[#list]
end

local function groundHit(origin: Vector3, distance: number): RaycastResult?
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	params.IgnoreWater = false
	return Workspace:Raycast(origin, Vector3.new(0, -distance, 0), params)
end

local function isWalkable(result: RaycastResult?): boolean
	return result ~= nil and result.Material ~= Enum.Material.Water
		and result.Normal.Y >= settings.MinGroundNormalY
		and result.Instance:IsA("BasePart") and result.Instance.CanCollide
		and CollectionService:HasTag(result.Instance, settings.GroundTag)
end

local function hasSupport(floor: Vector3): boolean
	for _, offset in ipairs({
		Vector3.new(-1, 0, -1), Vector3.new(-1, 0, 1),
		Vector3.new(1, 0, -1), Vector3.new(1, 0, 1),
	}) do
		local at = floor + offset * settings.FootprintRadius
		local hit = groundHit(at + Vector3.new(0, 3, 0), 6)
		if not isWalkable(hit) or math.abs((hit :: RaycastResult).Position.Y - floor.Y)
			> settings.MaxFootHeightDifference then
			return false
		end
	end
	return true
end

local function hasClearance(floor: Vector3): boolean
	local size: Vector3 = settings.ClearanceSize
	local center = floor + Vector3.new(0, 0.5 + size.Y / 2, 0)
	for _, part in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(center), size)) do
		if part.CanCollide and not CollectionService:HasTag(part, settings.GroundTag) then
			return false
		end
	end
	local params = RaycastParams.new()
	params.RespectCanCollide = true
	local overhead = Workspace:Raycast(floor + Vector3.new(0, size.Y + 0.5, 0),
		Vector3.new(0, settings.OverheadProbeHeight, 0), params)
	return overhead == nil
end

local function separated(floor: Vector3, chosen: { Vector3 }): boolean
	for _, other in ipairs(chosen) do
		local delta = Vector3.new(floor.X - other.X, 0, floor.Z - other.Z)
		if delta.Magnitude < settings.MinSeparation then return false end
	end
	return true
end

local function sample(list: { BasePart }, totalArea: number, chosen: { Vector3 }): Vector3?
	for _ = 1, settings.MaxAttemptsPerPlayer do
		local region = chooseRegion(list, totalArea)
		local halfX = region.Size.X / 2 - settings.RegionEdgeInset
		local halfZ = region.Size.Z / 2 - settings.RegionEdgeInset
		local origin = region.CFrame:PointToWorldSpace(Vector3.new(
			random:NextNumber(-halfX, halfX), region.Size.Y / 2,
			random:NextNumber(-halfZ, halfZ)
		))
		local hit = groundHit(origin, region.Size.Y)
		if isWalkable(hit) then
			local floor = (hit :: RaycastResult).Position
			if SpawnSelector.inArena(floor) and hasSupport(floor)
				and hasClearance(floor) and separated(floor, chosen) then
				return floor + Vector3.new(0, settings.PivotHeight, 0)
			end
		end
	end
	return nil
end

function SpawnSelector.assignRound(players: { Player }): { [Player]: Vector3 }?
	markAuthoredGround()
	local list, totalArea = regions()
	if #list == 0 or totalArea <= 0 then
		warn("[SpawnSelector] Authored SpawnRegions are missing or unusable")
		return nil
	end
	local chosen: { Vector3 } = {}
	local assignments: { [Player]: Vector3 } = {}
	for _, player in ipairs(players) do
		if player.Parent == Players then
			local pivot = sample(list, totalArea, chosen)
			if pivot == nil then
				warn(string.format("[SpawnSelector] Could not find safe round spawn for %s", player.Name))
				return nil
			end
			assignments[player] = pivot
			table.insert(chosen, pivot)
		end
	end
	return assignments
end

function SpawnSelector.recoveryPosition(player: Player): Vector3?
	markAuthoredGround()
	local list, totalArea = regions()
	if #list == 0 or totalArea <= 0 then return nil end
	local occupied: { Vector3 } = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other:GetAttribute("HRushInMatch") == true then
			local character = other.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				table.insert(occupied, root.Position)
			end
		end
	end
	return sample(list, totalArea, occupied)
end

return SpawnSelector
