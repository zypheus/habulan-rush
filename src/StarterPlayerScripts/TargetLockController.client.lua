--!strict
-- Each client owns its helper. Target choices never go to the server.
local controllerModule = script.Parent:FindFirstChild("TargetLockController")
assert(controllerModule and controllerModule:IsA("ModuleScript"), "TargetLockController module missing")
local TargetLockController = require(controllerModule)
TargetLockController:Init()
script.Destroying:Connect(function()
	TargetLockController:Destroy()
end)
