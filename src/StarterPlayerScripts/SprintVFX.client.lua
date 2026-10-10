--!strict
-- StarterPlayerScripts/SprintVFX.client.lua
-- Owner: Programmer A (sprint feel)
-- Responsibility: thin entry point. Init and Destroy the SprintVFX module.
local controllerModule = script.Parent:FindFirstChild("SprintVFX")
assert(controllerModule and controllerModule:IsA("ModuleScript"), "SprintVFX module missing from StarterPlayerScripts (stale place file? rebuild with Rojo)")
local SprintVFX = require(controllerModule)
SprintVFX:Init()
print("[SprintVFX] Loaded — premium sprint visuals (lines, FOV, streaks, dust, remotes).")
script.Destroying:Connect(function()
	SprintVFX:Destroy()
end)
