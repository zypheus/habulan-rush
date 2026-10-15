--!strict
-- ServerScriptService/MovementAuthority.server.lua
-- Owner: Project Owner
-- Responsibility: start the dedicated server movement authority lifecycle.
-- Task/spec: T09 movement upgrade Step 1, approved 2026-10-15.

local MovementAuthority = require(script.Parent:WaitForChild("MovementAuthority"))

MovementAuthority.start()
