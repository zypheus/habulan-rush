--!strict
-- ServerScriptService/TutorialService.server.lua
-- Owner: Project Owner
-- Responsibility: start the Classic Tag lesson service lifecycle.
-- Task/spec: owner-approved Classic Tag tutorial in the main place, 2026-10-25.

-- The module hosts every connection at top level, so requiring it starts the
-- service. The entry stays thin like MovementAuthority.server.lua.
require(script.Parent:WaitForChild("TutorialService"))
