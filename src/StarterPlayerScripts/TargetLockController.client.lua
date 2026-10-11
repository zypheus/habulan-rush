--!strict
-- StarterPlayerScripts/TargetLockController.client.lua
-- Owner: Programmer B (T16 soft lock)
-- Responsibility: thin entry point. Init and Destroy the TargetLockController module.
local TIMEOUT_SECONDS = 5

local function listChildren(): string
	local names = {}
	for _, child in script.Parent:GetChildren() do
		table.insert(names, child.Name .. " (" .. child.ClassName .. ")")
	end
	return table.concat(names, ", ")
end

local controllerInstance = script.Parent:WaitForChild("TargetLockController", TIMEOUT_SECONDS)
if not controllerInstance or not controllerInstance:IsA("ModuleScript") then
	error(string.format(
		"TargetLockController module missing from %s (stale place file? rebuild with Rojo). Existing children: [%s]",
		script.Parent:GetFullName(),
		listChildren()
	))
end

local controllerModule: ModuleScript = controllerInstance :: ModuleScript
local TargetLockController = require(controllerModule)
TargetLockController:Init()
script.Destroying:Connect(function()
	TargetLockController:Destroy()
end)
