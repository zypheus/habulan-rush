"""Exercise the lobby camera and music decisions from the production Luau offline."""

from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
LOBBY = (ROOT / "src/StarterPlayerScripts/LobbyUI.client.lua").read_text(encoding="utf-8")
MOVEMENT = (ROOT / "src/StarterPlayerScripts/MovementController.client.lua").read_text(encoding="utf-8")
MUSIC = (ROOT / "src/StarterPlayerScripts/MusicController.lua").read_text(encoding="utf-8")
CONFIG = (ROOT / "src/ReplicatedStorage/Config.lua").read_text(encoding="utf-8")
LUAU = Path(shutil.which("luau") or Path.home() / "AppData/Local/Temp/hrush-showcase-luau/luau.exe")


def section(source: str, start: str, end: str) -> str:
    first = source.index(start)
    return source[first : source.index(end, first)]


camera = section(LOBBY, "local function setupLobbyCamera()", "\nviewTouch.Activated:Connect")
camera_fixture = r'''
local attrs = {HRushInMatch=false, HRushState="MS_01"}
local humanoid = {}
local player = {
    CameraMode="Original", CameraMinZoomDistance=0.5, CameraMaxZoomDistance=400,
    Character={FindFirstChildOfClass=function() return humanoid end},
    GetAttribute=function(_self,key) return attrs[key] end,
}
local settings = {cameraViewMode="ThirdPerson",firstPersonFov=95}
local ClientSettings = {
    get=function(key) return settings[key] end,
    set=function(key,value) settings[key]=value end,
}
local SharedConfig = {Camera={ThirdPersonDistance=10,BaseFov=70}}
local CONFIG = {EnableLobbyCamera=true,HideDefaultCoreGui=false}
local Enum = {CameraMode={Classic="Classic",LockFirstPerson="FirstPerson"},
    CameraType={Custom="Custom"}}
local viewTouch = {Text=""}
local camera = {CameraType="Scriptable",FieldOfView=42}
local workspace = {CurrentCamera=camera}
local currentPanel = nil
local GuiService = {MenuIsOpen=false}
local UserInputService = {GetFocusedTextBox=function() return nil end}
'''
camera_checks = r'''
setupLobbyCamera()
assert(player.CameraMode == "Classic" and player.CameraMinZoomDistance == 10
    and player.CameraMaxZoomDistance == 10 and camera.CameraType == "Custom"
    and camera.CameraSubject == humanoid and camera.FieldOfView == 70
    and viewTouch.Text == "VIEW\n3RD", "lobby must begin in a 10-stud third-person follow view")
toggleLobbyView()
setupLobbyCamera()
assert(settings.cameraViewMode == "FirstPerson" and player.CameraMode == "FirstPerson"
    and camera.FieldOfView == 95 and viewTouch.Text == "VIEW\n1ST",
    "lobby first person must use the FOV setting")
settings.firstPersonFov = 72
setupLobbyCamera()
assert(camera.FieldOfView == 72, "lobby FOV change must apply immediately")
local nextHumanoid = {}
player.Character = {FindFirstChildOfClass=function() return nextHumanoid end}
setupLobbyCamera()
assert(camera.CameraSubject == nextHumanoid, "respawn must retarget the follow camera")
attrs.HRushState = "MS_03"
toggleLobbyView()
assert(settings.cameraViewMode == "FirstPerson", "countdown must not toggle views")
attrs.HRushState = "MS_01"
attrs.HRushInMatch = true
toggleLobbyView()
assert(settings.cameraViewMode == "FirstPerson", "match must not toggle views")
attrs.HRushInMatch = false
toggleLobbyView()
setupLobbyCamera()
assert(settings.cameraViewMode == "ThirdPerson" and camera.FieldOfView == 70,
    "returning to lobby must restore the player's in-session choice")
print("[HRUSH_LobbyRoam] Lobby camera, FOV, respawn and phase gates passed")
'''

music_logic = section(MUSIC, "local function keyForState(", "\nlocal function fadeOut(")
music_fixture = r'''
local MUSIC = {lobby="",draft="",countdown="",round="",roundEnd="",matchEnd=""}
local INTRO = {BgmId="rbxassetid://94984747143473"}
'''
music_checks = r'''
for _,state in {"MS_01","MS_VOTE","MS_RPS","MS_03","MS_04","MS_05","MS_06"} do
    assert(idForState(state) == INTRO.BgmId, "every empty state slot must use the current BGM")
end
MUSIC.lobby = "rbxassetid://future-lobby"
assert(idForState("MS_01") == MUSIC.lobby, "a future lobby track must override the fallback")
MUSIC.lobby = ""
INTRO.BgmId = ""
assert(idForState("MS_01") == "", "empty fallback must remain silent")
print("[HRUSH_LobbyRoam] Lobby BGM fallback and future override passed")
'''

for function_name in ("performDash", "performSlide", "vault.tryStart", "handleSlideInput"):
    marker = f"local function {function_name}()" if function_name != "vault.tryStart" else "function vault.tryStart(): boolean"
    assert marker in MOVEMENT, f"missing {function_name}"
assert "roundLive or lobbyWarmup" not in MOVEMENT, "abilities must never open during lobby roam"
assert "inputLocked = (state == \"MS_03\") or (not roundLive and not lobbyWarmup)" in MOVEMENT
assert "controls:Enable()" in LOBBY and "controls:Disable()" not in LOBBY
assert 'CameraViewModeDefault = "ThirdPerson"' in CONFIG
assert "ToggleGamepad = Enum.KeyCode.ButtonY" in CONFIG
assert 'viewTouch.Activated:Connect(toggleLobbyView)' in LOBBY
assert 'GuiService.SelectedObject = if Layout.compact() then phonePlay else playButton' in LOBBY
assert "if currentId == id and s.IsPlaying then" in MUSIC, "same BGM must not restart on match entry"
assert 'router.route(s, "music")' in MUSIC, "lobby BGM must obey music/master volume"

with tempfile.TemporaryDirectory(prefix="hrush-lobby-roam-") as temp_dir:
    script = Path(temp_dir) / "check.luau"
    script.write_text(camera_fixture + camera + camera_checks, encoding="utf-8")
    subprocess.run([str(LUAU), str(script)], check=True)
    script.write_text(music_fixture + music_logic + music_checks, encoding="utf-8")
    subprocess.run([str(LUAU), str(script)], check=True)

print("[HRUSH_LobbyRoam] Live-only abilities, controls, input bindings and track reuse passed")
