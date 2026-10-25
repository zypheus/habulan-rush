--!strict
-- Task/spec: preserve showcase character hiding, approved 2026-10-25.
-- StarterPlayerScripts/FirstPersonTorsoHider.lua (ModuleScript)
-- Owner: Project Owner
-- Responsibility: local-only first-person torso hiding. While the camera sits
-- within Config.Camera.FirstPerson.FirstPersonDistance of the character head,
-- an allowlist of torso parts (R15 UpperTorso/LowerTorso, R6 Torso) is hidden
-- with BasePart.LocalTransparencyModifier, which never replicates and never
-- touches the authored Transparency. Every other part, including the head,
-- accessories, arms, hands, legs, and feet, is left untouched, so the default
-- camera head behavior and the RS_03 aim fade stay intact. Third person and
-- missing parts restore the authored visibility. Bind sits one priority above
-- the default camera scripts, which also write LocalTransparencyModifier.
-- Task/spec: owner request 2026-10-19, hide only the torso in first person.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local FP = Config.Camera.FirstPerson
local MatchShowcase = require(script.Parent:WaitForChild("MatchShowcase", 10))

local localPlayer = Players.LocalPlayer

local BIND = "HRUSH_FirstPersonTorsoHider"

local FirstPersonTorsoHider = {}
local running = false

local character: Model? = nil
local head: BasePart? = nil
local torsoParts: { BasePart } = {}
local contentConn: RBXScriptConnection? = nil
local dirty = false

-- Resolve the character once per spawn. The allowlist names come from Config
-- by rig type, and a missing part is skipped instead of erroring. Character
-- content streams in after CharacterAdded, so the caller rebuilds once the
-- dirty flag is set by a later-added part.
local function rebuild()
	dirty = false
	torsoParts = {}
	head = nil
	local ch = character
	if ch == nil then
		return
	end
	local headPart = ch:FindFirstChild("Head")
	if headPart ~= nil and headPart:IsA("BasePart") then
		head = headPart
	end
	local humanoid = ch:FindFirstChildOfClass("Humanoid")
	local names: { string } = if humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
		then FP.HideInFirstPersonR6
		else FP.HideInFirstPerson
	for _, name in names do
		local part = ch:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			table.insert(torsoParts, part)
		end
	end
end

-- Runs at Enum.RenderPriority.Camera + 1, after the default camera scripts.
-- The cached allowlist is rewritten every frame on purpose: the RS_03 aim
-- fade also writes LocalTransparencyModifier on every part and resets it to 0
-- on aim exit, and this pass must re-assert the torso state after that.
local function onRender()
	if MatchShowcase.isActive() then return end
	if dirty then
		rebuild()
	end
	local ch = character
	local headPart = head
	local cam = Workspace.CurrentCamera
	if ch == nil or headPart == nil or cam == nil then
		return
	end
	local firstPerson = (cam.CFrame.Position - headPart.Position).Magnitude <= FP.FirstPersonDistance
	local value = if firstPerson then 1 else 0
	for _, part in torsoParts do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = value
		end
	end
end

local function onCharacterAdded(ch: Model)
	if contentConn ~= nil then
		contentConn:Disconnect()
	end
	contentConn = ch.DescendantAdded:Connect(function()
		dirty = true
	end)
	character = ch
	dirty = true
	rebuild()
end

function FirstPersonTorsoHider.start()
	if running then
		return
	end
	running = true
	localPlayer.CharacterAdded:Connect(onCharacterAdded)
	localPlayer.CharacterRemoving:Connect(function()
		if contentConn ~= nil then
			contentConn:Disconnect()
			contentConn = nil
		end
		character = nil
		torsoParts = {}
		head = nil
		dirty = false
	end)
	local current = localPlayer.Character
	if current ~= nil then
		onCharacterAdded(current)
	end
	RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, onRender)
end

return FirstPersonTorsoHider
