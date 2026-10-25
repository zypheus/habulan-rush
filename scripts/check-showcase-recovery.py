"""Run the real avatar-copy function against Roblox-like failure fixtures offline."""

from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "src/StarterPlayerScripts/MatchShowcase.lua").read_text(encoding="utf-8")
CONFIG_SOURCE = (ROOT / "src/ReplicatedStorage/Config.lua").read_text(encoding="utf-8")
START = SOURCE.index("local function copyAvatar(player: Player): Avatar?")
END = SOURCE.index("\nlocal function buildLineup(", START)
COPY_AVATAR = SOURCE[START:END].replace("local function copyAvatar", "function copyAvatar", 1)
LUAU = Path(shutil.which("luau") or Path.home() / "AppData/Local/Temp/hrush-showcase-luau/luau.exe")

fixture = r'''
local destroyed = 0
local function part(name, attributes)
    return {
        Name = name, Parent = true, Anchored = false, LocalTransparencyModifier = 1,
        attributes = attributes or {},
        GetAttributes = function(self) return self.attributes end,
        SetAttribute = function(self, key, value)
            if key:sub(1, 3) == "RBX" then error("CoreScript permission required") end
            self.attributes[key] = value
        end,
        IsA = function(_self, kind) return kind == "BasePart" end,
    }
end
local function model()
    local body = part("HumanoidRootPart", {RBXRefinementScale = 1, Gameplay = true})
    local head = part("Head")
    return {
        parts = {body, head}, attributes = {RBXRefinementScale = 1, Gameplay = true},
        GetDescendants = function(self) return self.parts end,
        GetAttributes = function(self) return self.attributes end,
        SetAttribute = function(self, key, value)
            if key:sub(1, 3) == "RBX" then error("CoreScript permission required") end
            self.attributes[key] = value
        end,
        FindFirstChild = function(self, key) for _, value in self.parts do if value.Name == key then return value end end end,
        PivotTo = function() end,
        GetBoundingBox = function() return {Position={Y=4}}, {X=4,Y=8,Z=3} end,
        Destroy = function() destroyed += 1 end,
    }
end
local function player(id, fail, malformed)
    local original = {Archivable=false}
    function original:FindFirstChild(_name) return true end
    function original:Clone()
        if fail then error("appearance unavailable") end
        local copy = model()
        if malformed then table.remove(copy.parts, 1) end
        return copy
    end
    return {UserId=id, Character=original}, original
end
local CollectionService = {GetTags=function() return {} end, RemoveTag=function() end}
local Vector3 = {zero={}}
local CFrame = {identity={}}
local Enum = {HumanoidDisplayDistanceType={None="None"}}
local function warn(...) end
'''

checks = r'''
local good, original = player(1, false, false)
local avatar = copyAvatar(good)
assert(avatar and avatar.size.X == 4 and original.Archivable == false)
assert(avatar.model.attributes.RBXRefinementScale == 1)
assert(avatar.model.attributes.Gameplay == nil)
assert(avatar.model.parts[1].attributes.RBXRefinementScale == 1)
assert(avatar.model.parts[1].attributes.Gameplay == nil)
assert(avatar.model.parts[1].Anchored and not avatar.model.parts[1].CanCollide)
local failing, failingOriginal = player(2, true, false)
assert(copyAvatar(failing) == nil and failingOriginal.Archivable == false)
local malformed, malformedOriginal = player(3, false, true)
assert(copyAvatar(malformed) == nil and malformedOriginal.Archivable == false)
assert(destroyed == 1, "discarded copy must be destroyed")
assert(copyAvatar(good) ~= nil, "remaining lineup must survive another player's failure")
assert(copyAvatar({UserId=4, Character=nil}) == nil, "empty lineup must be safe")
print("[HRUSH_ShowcaseRecovery] Protected attributes, failed and empty copies passed")
'''

with tempfile.TemporaryDirectory(prefix="hrush-showcase-") as temp_dir:
    script = Path(temp_dir) / "check.luau"
    script.write_text(fixture + "\n" + COPY_AVATAR + "\n" + checks, encoding="utf-8")
    subprocess.run([str(LUAU), str(script)], check=True)

    ui_source = (ROOT / "src/StarterPlayerScripts/UIController.client.lua").read_text(encoding="utf-8")
    ui_start = ui_source.index("local lastCountNum = -1")
    ui_end = ui_source.index("\n-- ── C. PERSONAL TAYA BADGE", ui_start)
    countdown = ui_source[ui_start:ui_end]
    ui_fixture = r'''
local now, deadline, phaseState = 105.9, 111, "MS_03"
local ticks, go = 0, 0
local countdownLabel = {Visible=false}
local MatchShowcase = {isActive=function() return now < 106 end}
local ReplicatedStorage = {GetAttribute=function(_self, key) if key == "HRushPhaseEndsAt" then return deadline end end}
local Workspace = {GetServerTimeNow=function() return now end}
local Config = {Match={CountdownDuration=5, Showcase={GoDisplayDuration=0.65}}, Sfx={Countdown={tick=1,go=2,volume=1}}}
local AudioRouter = {playSfxId=function(id) if id == 1 then ticks += 1 else go += 1 end end}
local Layout = {compact=function() return false end}
local UDim2 = {fromOffset=function() return {} end}
local HUD_LIME, HUD_RED = "lime", "red"
local task = {delay=function() end}
'''
    ui_checks = r'''
updateCountdown()
assert(ticks == 0 and not countdownLabel.Visible, "showcase must hide countdown")
for second = 106, 110 do
    now = second + 0.01
    updateCountdown()
    updateCountdown()
    assert(countdownLabel.Text == tostring(111 - second), "countdown number out of order")
end
assert(ticks == 5 and go == 0, "five ticks, no early GO")
now = 111
updateCountdown()
assert(go == 0 and not countdownLabel.Visible, "deadline alone must not release gameplay")
phaseState = "MS_04"
showCountdownGo()
showCountdownGo()
assert(go == 1 and countdownLabel.Text == "GO!", "one live GO cue")
deadline = nil
phaseState = "MS_03"
updateCountdown()
assert(go == 1 and not countdownLabel.Visible, "missing deadline must stay silent")
print("[HRUSH_ShowcaseRecovery] Countdown and GO assertions passed")
'''
    script.write_text(ui_fixture + "\n" + countdown + "\n" + ui_checks, encoding="utf-8")
    subprocess.run([str(LUAU), str(script)], check=True)

    stop_start = SOURCE[SOURCE.index("function Showcase.stop()") : SOURCE.index("\nlocal function copyAvatar(")]
    start = SOURCE[SOURCE.index("function Showcase.start()") : SOURCE.index("\nreturn Showcase", SOURCE.index("function Showcase.start()"))]
    lifecycle_fixture = r'''
local active, starts, exits, heartbeat = false, 0, 0, nil
local function signal() return {Connect=function() end} end
local localPlayer = {GetAttributeChangedSignal=function() return signal() end}
local ReplicatedStorage = {GetAttributeChangedSignal=function() return signal() end}
local Players = {PlayerRemoving=signal()}
local RunService = {Heartbeat={Connect=function(_self, callback) heartbeat=callback end}}
local changed = {Fire=function(_self, value) if value then starts += 1 else exits += 1 end end}
local Showcase = {isActive=function() return active end}
local avatars, hiddenParts, touchScreens = {}, {}, {}
local scene, screen = nil, nil
local title, subtitle, veil, activeDeadline = nil, nil, nil, nil
local handoffDone, wasActive, started = false, false, false
local function restoreCharacters() table.clear(hiddenParts) end
'''
    lifecycle_checks = r'''
Showcase.start()
active=true
heartbeat()
heartbeat()
assert(starts == 1 and exits == 0, "one entry signal")
scene = {Destroy=function() end}
screen = {Destroy=function() end}
activeDeadline = 106
active=false
heartbeat()
heartbeat()
assert(starts == 1 and exits == 1 and scene == nil and screen == nil and activeDeadline == nil,
    "abort must clean partial scene once")
active=true
heartbeat()
assert(starts == 2, "repeat match gets a new entry")
active=false
heartbeat()
assert(exits == 2, "repeat match exits once")
print("[HRUSH_ShowcaseRecovery] Deadline lifecycle and partial cleanup passed")
'''
    script.write_text(lifecycle_fixture + "\n" + stop_start + "\n" + start + "\n" + lifecycle_checks, encoding="utf-8")
    subprocess.run([str(LUAU), str(script)], check=True)

    assert "Duration = 14," in CONFIG_SOURCE and "MapShotDuration = 10," in CONFIG_SOURCE
    assert CONFIG_SOURCE.count("Start = CFrame.lookAt(") == 5
    assert CONFIG_SOURCE.count("Finish = CFrame.lookAt(") == 5
    map_config = CONFIG_SOURCE.split("MapClips = {", 1)[1].split("LineupFloor =", 1)[0]
    point = r"Vector3\.new\(([-\d., ]+)\)"
    pattern = re.compile(
        rf"\{{\s*Start = CFrame\.lookAt\({point}, {point}\),\s*"
        rf"Control = {point},\s*Finish = CFrame\.lookAt\({point}, {point}\),\s*"
        rf"Focus = {point}(?:, FocusFinish = {point})?\s*\}}"
    )
    clips = pattern.findall(map_config)
    assert len(clips) == 5, "all five camera paths must have start, control, finish and focus"
    expected_positions = [
        ((-60, 90, 125), (-66, 83, 116.5), (-72, 76, 108)),
        ((-140, 40, 140), (-143, 42, 150), (-150, 40, 150)),
        ((-80, 31, 73), (-72, 39, 64), (-68, 37, 54)),
        ((-152, 28, -18), (-146, 30, -22), (-143, 28, -31)),
        ((105, 25, 113), (96, 27, 122), (93, 30, 125)),
    ]
    coordinates = lambda raw: tuple(float(value.strip()) for value in raw.split(","))
    for index, clip in enumerate(clips):
        assert (coordinates(clip[0]), coordinates(clip[2]), coordinates(clip[3])) == expected_positions[index]
        assert coordinates(clip[1]) == coordinates(clip[5]), "start aim must match focus"
        assert coordinates(clip[4]) == coordinates(clip[6] or clip[5]), "finish aim must match focus"
    map_start = SOURCE.index("\tif mapShot then\n", SOURCE.index("function Showcase.step("))
    map_end = SOURCE.index("\n\tlocal t = if Theme.reducedMotion()", map_start)
    map_branch = SOURCE[map_start:map_end]
    clip_fixture = r'''
local settings = {MapShotDuration=10}
local reduced = false
local Theme = {reducedMotion=function() return reduced end}
local function smooth(t) return t*t*(3-2*t) end
local function vector(x,y,z)
    return {X=x,Y=y,Z=z,Lerp=function(self,other,t)
        return vector(self.X+(other.X-self.X)*t,self.Y+(other.Y-self.Y)*t,self.Z+(other.Z-self.Z)*t)
    end}
end
local CFrame = {lookAt=function(position,focus) return {Position=position,Focus=focus} end}
local map = {MapClips={}}
'''
    def luau_vector(raw):
        return f"vector({raw})"

    clip_data = []
    for clip in clips:
        start, start_focus, control, finish, finish_focus, focus, focus_finish = clip
        clip_data.append(
            "table.insert(map.MapClips, {"
            f"Start={{Position={luau_vector(start)}}}, Control={luau_vector(control)}, "
            f"Finish={{Position={luau_vector(finish)}}}, Focus={luau_vector(focus)}, "
            f"FocusFinish={luau_vector(focus_finish or focus)}"
            "})"
        )
    clip_fixture += "\n".join(clip_data) + r'''
local function close(a,b) return math.abs(a-b) < 0.001 end
local function same(a,b) return close(a.X,b.X) and close(a.Y,b.Y) and close(a.Z,b.Z) end
local function distance(a,b)
    local x,y,z = a.X-b.X,a.Y-b.Y,a.Z-b.Z
    return math.sqrt(x*x+y*y+z*z)
end
local function shot(at, still)
    local elapsed = at
    reduced = still
    local mapShot = true
'''
    clip_checks = r'''
end
for i=1,5 do
    local start = (i-1)*2
    local first = shot(start, false)
    local last = shot(start+1.999, false)
    local clip = map.MapClips[i]
    assert(same(first.Position, clip.Start.Position) and same(first.Focus, clip.Focus),
        "clip must cut to its start pose at the two-second boundary")
    assert(distance(last.Position, clip.Finish.Position) < 0.001,
        "clip must reach its finish before the next cut")
    local middle = shot(start+1, false)
    local expected = clip.Start.Position:Lerp(clip.Control, 0.5):Lerp(
        clip.Control:Lerp(clip.Finish.Position, 0.5), 0.5)
    assert(same(middle.Position, expected), "camera must follow the quadratic path")
    assert(same(shot(start+1, true).Position, first.Position),
        "reduced motion holds each clip's first frame")
end
assert(same(shot(10,false).Position, map.MapClips[5].Finish.Position)
    and same(shot(13.5,false).Position, map.MapClips[5].Finish.Position),
    "empty lineup keeps the last map view through the handoff")
assert(distance(map.MapClips[5].Start.Position,map.MapClips[5].Focus)
    < distance(map.MapClips[5].Finish.Position,map.MapClips[5].Focus),
    "street clip must pull back")
print("[HRUSH_ShowcaseRecovery] Curved paths, five cuts, reduced motion and empty lineup passed")
'''
    script.write_text(clip_fixture + "\n" + map_branch + "\n" + clip_checks, encoding="utf-8")
    subprocess.run([str(LUAU), str(script)], check=True)
