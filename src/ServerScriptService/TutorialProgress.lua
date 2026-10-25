--!strict
-- ServerScriptService/TutorialProgress.lua
-- Owner: Project Owner
-- Responsibility: versioned, monotonic tutorial prompt and completion persistence.
-- Task/spec: owner-approved Classic Tag tutorial, 2026-10-25.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local store = DataStoreService:GetDataStore(Config.Tutorial.ProgressStore)

export type Status = "new" | "later" | "complete"

local TutorialProgress = {}

local function key(userId: number): string
	return "User_" .. tostring(userId)
end

local function parse(value: unknown): Status
	if typeof(value) == "table" and (value :: any).version == 1 then
		local status = (value :: any).status
		if status == "later" or status == "complete" then
			return status
		end
	end
	return "new"
end

function TutorialProgress.read(userId: number): Status?
	for attempt = 1, 2 do
		local ok, value = pcall(function()
			return store:GetAsync(key(userId))
		end)
		if ok then
			return parse(value)
		end
		warn("[TutorialProgress] Read failed for " .. tostring(userId))
		if attempt == 1 then task.wait(0.5) end
	end
	return nil
end

function TutorialProgress.mark(userId: number, status: Status): boolean
	if status ~= "later" and status ~= "complete" then return false end
	for attempt = 1, 2 do
		local ok = pcall(function()
			store:UpdateAsync(key(userId), function(current: unknown)
				local previous = parse(current)
				local nextStatus: Status = if previous == "complete" then "complete" else status
				return { version = 1, status = nextStatus }
			end)
		end)
		if ok then return true end
		warn("[TutorialProgress] Save failed for " .. tostring(userId))
		if attempt == 1 then task.wait(0.5) end
	end
	return false
end

return TutorialProgress
