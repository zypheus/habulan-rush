--!strict
-- StarterPlayerScripts/SprintVFX.client.lua
-- Owner: Programmer A (sprint feel)
-- Responsibility: thin entry point. Init and Destroy the SprintVFX module.
local TIMEOUT_SECONDS = 5

local function listChildren(): string
	local names = {}
	for _, child in script.Parent:GetChildren() do
		table.insert(names, child.Name .. " (" .. child.ClassName .. ")")
	end
	return table.concat(names, ", ")
end

local controllerInstance = script.Parent:WaitForChild("SprintVFX", TIMEOUT_SECONDS)
if not controllerInstance or not controllerInstance:IsA("ModuleScript") then
	error(string.format(
		"SprintVFX module missing from %s (stale place file? rebuild with Rojo). Existing children: [%s]",
		script.Parent:GetFullName(),
		listChildren()
	))
end

local controllerModule: ModuleScript = controllerInstance :: ModuleScript
local SprintVFX = require(controllerModule)
SprintVFX:Init()
print("[SprintVFX] Loaded — premium sprint visuals (lines, FOV, streaks, dust, remotes).")
script.Destroying:Connect(function()
	SprintVFX:Destroy()
end)
