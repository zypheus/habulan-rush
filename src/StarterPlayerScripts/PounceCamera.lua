--!strict
-- StarterPlayerScripts/PounceCamera.lua
-- Owner: Project Owner
-- Responsibility: additive, client-only third-person camera response for pounce.
-- Task/spec: project-owner Pounce / Tag request, 2026-10-16.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local settings = Config.Pounce.Camera
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))

local PounceCamera = {}
local bindName = "HRUSH_PounceCamera"
local phase = "Idle"
local phaseAt = 0.0
local fovDelta = 0.0
local offset = Vector3.zero
local lastFovDelta = 0.0
local bound = false
local lastCamera: Camera? = nil
local lastTransform = CFrame.identity
local lastAppliedFrame: CFrame? = nil
local nearTarget = false

local function removeOffset()
	local camera = lastCamera
	if camera then
		camera.FieldOfView -= lastFovDelta
		if lastAppliedFrame and camera.CFrame == lastAppliedFrame then
			camera.CFrame *= lastTransform:Inverse()
		end
	end
	lastFovDelta = 0
	lastAppliedFrame = nil
end

local function target(now: number): (number, Vector3, Vector3)
	local age = now - phaseAt
	if phase == "Windup" then return settings.WindupFov, settings.WindupOffset, Vector3.zero end
	if phase == "Launch" then return settings.LaunchFov, settings.LaunchOffset, Vector3.zero end
	if phase == "Airborne" then return settings.AirFov, settings.AirOffset - Vector3.zAxis * (if nearTarget then settings.NearPush else 0), Vector3.zero end
	if phase == "Impact" then
		local fade = math.exp(-age * settings.ImpactDecay)
		local wave = math.sin(age * settings.ImpactFrequency) * fade
		return settings.ImpactFov * fade, settings.ImpactPosition * wave - Vector3.zAxis * settings.ImpactPush * fade, settings.ImpactAngles * wave
	end
	if phase == "Land" then
		local fade = math.exp(-age * settings.LandDecay)
		return settings.WindupFov * fade, Vector3.new(0, -settings.LandDip * fade, 0), Vector3.new(-settings.LandPitch * fade, 0, 0)
	end
	return 0, Vector3.zero, Vector3.zero
end

local function update(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then return end
	lastCamera = camera
	local desiredFov, desiredOffset, angles = target(os.clock())
	if VfxScale.reducedCamera() then
		desiredFov = 0
		desiredOffset = Vector3.zero
		angles = Vector3.zero
	end
	local alpha = 1 - math.exp(-dt * settings.SmoothRate)
	fovDelta += (desiredFov - fovDelta) * alpha
	offset = offset:Lerp(desiredOffset, alpha)
	camera.FieldOfView += fovDelta
	lastFovDelta = fovDelta
	local safeOffset = offset
	if offset.Magnitude > settings.CollisionPadding then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local character = Players.LocalPlayer.Character
		params.FilterDescendantsInstances = if character then { character } else {}
		params.RespectCanCollide = true
		local obstruction = Workspace:Raycast(camera.CFrame.Position, camera.CFrame:VectorToWorldSpace(offset), params)
		if obstruction then safeOffset = offset.Unit * math.max(0, obstruction.Distance - settings.CollisionPadding) end
	end
	lastTransform = CFrame.new(safeOffset) * CFrame.Angles(math.rad(angles.X), math.rad(angles.Y), math.rad(angles.Z))
	camera.CFrame *= lastTransform
	lastAppliedFrame = camera.CFrame
	if phase == "Recover" and math.abs(fovDelta) < 0.02 and offset.Magnitude < 0.003 then
		PounceCamera:Cancel()
	end
end

local function enter(name: string)
	if phase == name then return end
	phase = name
	phaseAt = os.clock()
	if not bound then
		bound = true
		RunService:BindToRenderStep(bindName .. "Reset", Enum.RenderPriority.Camera.Value - 1, removeOffset)
		RunService:BindToRenderStep(bindName, Enum.RenderPriority.Camera.Value + 4, update)
	end
end

function PounceCamera:Windup() enter("Windup") end
function PounceCamera:Launch() enter("Launch") end
function PounceCamera:Airborne() enter("Airborne") end
function PounceCamera:Impact() enter("Impact") end
function PounceCamera:Land() enter("Land") end
function PounceCamera:Recover() enter("Recover") end
function PounceCamera:NearTarget(value: boolean) nearTarget = value end
function PounceCamera:Cancel()
	if bound then
		RunService:UnbindFromRenderStep(bindName)
		RunService:UnbindFromRenderStep(bindName .. "Reset")
		bound = false
	end
	removeOffset()
	phase = "Idle"
	fovDelta = 0
	offset = Vector3.zero
	lastFovDelta = 0
	lastCamera = nil
	nearTarget = false
end

return PounceCamera
