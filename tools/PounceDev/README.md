# Pounce multiplayer fixtures

Historical fixtures for the 2026-10-16 rules. The 2026-10-17 owner revision removed touch tags and allowed walking/airborne pounces. These fixtures still assume the earlier touch-based bot setup and are not current acceptance tests. The owner requested manual testing; follow the latest handoff note instead.

These scripts are development tools and are deliberately absent from `default.project.json`.

Run against the repository build in Studio using MCP:

1. Mirror `ServerFixture.server.lua` into a temporary Script named `HRUSH_PounceServerFixture` in ServerScriptService.
2. Mirror `ClientFixture.client.lua` into a temporary LocalScript named `HRUSH_PounceClientFixture` in StarterPlayerScripts.
3. Add temporary `MobileSprintBegan` and `MobileSprintEnded` BindableEvents to ReplicatedStorage before starting. They exercise the existing movement input bridge.
4. From the Edit DataModel, call `StudioTestService:ExecuteMultiplayerTestAsync(2, {pounce = true})`. Run it in a spawned task so Studio MCP stays responsive.
5. The fixture queues both real clients, waits for the actual match, builds a flat isolated test platform, and places bots away from the test. MatchService still owns role transfers. Results return through `StudioTestService:EndTest`.
6. Remove the two temporary scripts and BindableEvents from Edit after testing. Restore the default viewport if device simulation was used.

The fixture checks confirmed hits, repeat hits, misses, side targets, walls, held and released sprint, duplicate/old/malformed requests, a fresh request during cooldown, impossible travel, death, respawn, and round-state cancellation. It records the server responses, local states, observed animation IDs, speed, FOV, and cleanup. Setup teleports can produce expected MovementAuthority displacement logs; they are not gameplay motion.

Input movement uses the existing touch sprint bridge and `Humanoid:Move`; activation uses the same `tryActivate` path as CAS. Physical mouse/gamepad/touch interaction and visual quality need separate input/device checks. Config is never mutated by these fixtures.
