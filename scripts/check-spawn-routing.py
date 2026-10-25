"""Exercise production spawn routing decisions without running Roblox Studio."""

from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
ROUTING = (ROOT / "src/ServerScriptService/SpawnRouting.lua").read_text(encoding="utf-8")
MATCH = (ROOT / "src/ServerScriptService/MatchService.server.lua").read_text(encoding="utf-8")
TUTORIAL = (ROOT / "src/ServerScriptService/TutorialService.lua").read_text(encoding="utf-8")
CONFIG = (ROOT / "src/ReplicatedStorage/Config.lua").read_text(encoding="utf-8")
LUAU = Path(shutil.which("luau") or Path.home() / "AppData/Local/Temp/hrush-showcase-luau/luau.exe")

assert 'LobbyPath = { "BarangayMaligayaLobby", "CentralPlaza", "PlazaSpawn" }' in CONFIG
assert 'ArenaPath = { "Map", "Spawn" }' in CONFIG
assert MATCH.index("SpawnRouting.setLobby(player)") < MATCH.index("local existingCharacter = player.Character")
assert MATCH.index("SpawnRouting.setArena(player)") > MATCH.index("local selectedMap = runMapVote(currentMode)")
assert MATCH.index("SpawnRouting.setArena(player)") < MATCH.index("teleportToPositions(getParticipants() :: { Player }, roundSpawns)")
assert MATCH.index("SpawnRouting.setLobby(p)") < MATCH.index("p:LoadCharacter()")
assert 'if embedded then\n\t\tif character then SpawnRouting.placeLobbyCharacter(player, character)' in TUTORIAL

logic = ROUTING[ROUTING.index("local SpawnRouting = {}"):].rsplit("return SpawnRouting", 1)[0]
fixture = r'''
local paths = {LobbyPath={"BarangayMaligayaLobby","CentralPlaza","PlazaSpawn"}, ArenaPath={"Map","Spawn"}}
local warningCount = 0
local function warn(_message) warningCount += 1 end
local function node(class, children, cf)
    return {class=class, children=children or {}, CFrame=cf, Enabled=true,
        FindFirstChild=function(self,name) return self.children[name] end,
        IsA=function(self,kind) return self.class == kind end}
end
local plaza = node("SpawnLocation", {}, 100)
local arena = node("SpawnLocation", {}, 0)
local Workspace = node("Workspace", {
    BarangayMaligayaLobby=node("Model", {CentralPlaza=node("Model", {PlazaSpawn=plaza})}),
    Map=node("Model", {Spawn=arena}),
})
local Vector3 = {new=function(_x,y,_z) return y end}
local attrs = {HRushState="MS_01", HRushInMatch=false, HRushTutorialActive=false}
local character = {PivotTo=function(self,cf) self.pivot=cf end}
local player = {Character=character,
    GetAttribute=function(self,key) return attrs[key] end}
'''
checks = r'''
assert(SpawnRouting.setLobby(player) == plaza and player.RespawnLocation == plaza,
    "join, lobby deaths, queued players and voting must use island spawn")
assert(SpawnRouting.placeLobbyCharacter(player, character) and character.pivot == 103,
    "an already-present lobby character must move to the island")
attrs.HRushInMatch = true
attrs.HRushState = "MS_VOTE"
character.pivot = nil
assert(not SpawnRouting.placeLobbyCharacter(player, character) and character.pivot == nil,
    "late lobby correction must not pull a match participant back")
assert(player.RespawnLocation == plaza, "voting stays on the island until selection ends")
assert(SpawnRouting.setArena(player) == arena and player.RespawnLocation == arena,
    "after voting, match respawns must use Kalsada")
attrs.HRushInMatch = false
attrs.HRushState = "MS_01"
assert(SpawnRouting.setLobby(player) == plaza and player.RespawnLocation == plaza,
    "match return must restore the island before LoadCharacter")
attrs.HRushTutorialActive = true
character.pivot = nil
assert(not SpawnRouting.placeLobbyCharacter(player, character) and character.pivot == nil,
    "tutorial-active characters must stay on the training strip")
attrs.HRushTutorialActive = false
assert(SpawnRouting.placeLobbyCharacter(player, character) and character.pivot == 103,
    "tutorial exit must place an existing character on the island")
Workspace.children.BarangayMaligayaLobby = nil
assert(SpawnRouting.setLobby(player) == arena and player.RespawnLocation == arena,
    "missing island must use Kalsada fallback")
SpawnRouting.setLobby(player)
assert(warningCount == 1, "missing island warning must be emitted once")
Workspace.children.BarangayMaligayaLobby = node("Model", {CentralPlaza=node("Model", {PlazaSpawn=plaza})})
plaza.Enabled = false
assert(SpawnRouting.setLobby(player) == arena, "disabled plaza spawn must use Kalsada fallback")
print("[HRUSH_SpawnRouting] Join, voting, match, return, tutorial and fallback passed")
'''

with tempfile.TemporaryDirectory(prefix="hrush-spawn-routing-") as temp_dir:
    script = Path(temp_dir) / "check.luau"
    script.write_text(fixture + logic + checks, encoding="utf-8")
    subprocess.run([str(LUAU), str(script)], check=True)
