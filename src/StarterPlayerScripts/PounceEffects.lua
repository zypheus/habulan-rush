--!strict
-- StarterPlayerScripts/PounceEffects.lua
-- Owner: Project Owner
-- Responsibility: original pounce dust, ribbons, impact rings, and configured audio for all clients.
-- Task/spec: player pounce feedback (test bots removed), approved 2026-10-18.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local AudioRouter = require(script.Parent:WaitForChild("AudioRouter"))
local VfxScale = require(script.Parent:WaitForChild("VfxScale"))
local settings = Config.Pounce.Feedback
local Effects = {}
type Flight = { root: BasePart, objects: { Instance }, trails: { Trail }, sound: Sound? }
local flights: { [Instance]: Flight } = {}
local heartbeat: RBXScriptConnection? = nil

local function part(name: string, color: Color3): Part
	local result = Instance.new("Part")
	result.Name = "HRUSH_Pounce" .. name
	result.Anchored = true
	result.CanCollide = false
	result.CanTouch = false
	result.CanQuery = false
	result.CastShadow = false
	result.Color = color
	return result
end

local function burst(position: Vector3, count: number, color: Color3, radius: number)
	count = VfxScale.count(count)
	for i = 1, count do
		local angle = i * math.pi * 2 / count
		local dust = part("Dust", color)
		dust.Shape = Enum.PartType.Ball
		dust.Size = Vector3.one * settings.DustSize
		dust.Position = position
		dust.Parent = Workspace
		local travel = Vector3.new(math.cos(angle), 0.3 + (i % 3) * 0.15, math.sin(angle)) * radius
		TweenService:Create(dust, TweenInfo.new(settings.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = position + travel, Transparency = 1, Size = Vector3.one * settings.DustSize * 0.25,
		}):Play()
		Debris:AddItem(dust, settings.Lifetime)
	end
end

local function ring(position: Vector3)
	if VfxScale.cosmetic() <= 0 then return end
	for i = 1, settings.RingSegments do
		local angle = i * math.pi * 2 / settings.RingSegments
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local segment = part("Ring", settings.ImpactColor)
		segment.Material = Enum.Material.Neon
		segment.Size = Vector3.new(settings.RingThickness, settings.RingThickness, settings.RingRadius * math.pi * 2 / settings.RingSegments)
		local tangent = Vector3.new(-radial.Z, 0, radial.X)
		segment.CFrame = CFrame.lookAt(position + radial * settings.RingRadius * 0.25, position + radial * settings.RingRadius * 0.25 + tangent)
		segment.Parent = Workspace
		TweenService:Create(segment, TweenInfo.new(settings.Lifetime), {
			CFrame = CFrame.lookAt(position + radial * settings.RingRadius, position + radial * settings.RingRadius + tangent), Transparency = 1,
		}):Play()
		Debris:AddItem(segment, settings.Lifetime)
	end
end

local function streaks(position: Vector3, direction: Vector3, color: Color3)
	local frame = CFrame.lookAt(position, position + direction)
	for i = 1, VfxScale.count(settings.StreakCount) do
		local angle = i * math.pi * 2 / settings.StreakCount
		local lateral = frame.RightVector * math.cos(angle) + frame.UpVector * math.sin(angle)
		local start = position + lateral * 0.5
		local streak = part("Streak", color)
		streak.Material = Enum.Material.Neon
		streak.Size = Vector3.new(settings.StreakThickness, settings.StreakThickness, settings.StreakLength)
		streak.CFrame = CFrame.lookAt(start, start + direction)
		streak.Parent = Workspace
		TweenService:Create(streak, TweenInfo.new(settings.Lifetime), {
			CFrame = streak.CFrame + direction * settings.StreakLength + lateral,
			Transparency = 1,
		}):Play()
		Debris:AddItem(streak, settings.Lifetime)
	end
end

function Effects.cancel(actor: Instance)
	local flight = flights[actor]
	if flight then
		for _, object in flight.objects do object:Destroy() end
		flights[actor] = nil
	end
	if next(flights) == nil and heartbeat then heartbeat:Disconnect(); heartbeat = nil end
end

function Effects.emit(actor: Instance, phase: string, position: Vector3?)
	local character = if actor:IsA("Player") then actor.Character else actor :: Model
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then Effects.cancel(actor); return end
	local at = position or root.Position
	local soundKey = phase
	if phase == "Windup" then
		Effects.cancel(actor)
		burst(at - Vector3.yAxis * 2, settings.WindupCount, settings.DustColor, settings.DustRadius * 0.5)
	elseif phase == "Launch" then
		Effects.cancel(actor)
		burst(at - Vector3.yAxis * 2, settings.LaunchCount, settings.DustColor, settings.DustRadius)
		burst(at - root.CFrame.LookVector, settings.WindupCount, settings.WindColor, settings.DustRadius)
		streaks(at, -root.CFrame.LookVector, settings.WindColor)
		local flight: Flight = { root = root, objects = {}, trails = {}, sound = nil }
		flights[actor] = flight
		for _, handName in { "LeftHand", "RightHand" } do
			local hand = character:FindFirstChild(handName)
			if hand and hand:IsA("BasePart") then
				local a, b = Instance.new("Attachment"), Instance.new("Attachment")
				a.Name = "HRUSH_PounceTrailA"; b.Name = "HRUSH_PounceTrailB"
				a.Position = Vector3.new(-0.1, 0, 0); b.Position = Vector3.new(0.1, 0, 0)
				a.Parent = hand; b.Parent = hand
				local trail = Instance.new("Trail")
				trail.Name = "HRUSH_PounceWind"
				trail.Attachment0 = a; trail.Attachment1 = b
				trail.FaceCamera = true
				trail.Lifetime = settings.TrailLifetime
				trail.Color = ColorSequence.new(settings.WindColor)
				trail.Transparency = NumberSequence.new(0.3, 1)
				trail.Parent = hand
				table.insert(flight.objects, a); table.insert(flight.objects, b); table.insert(flight.objects, trail)
				table.insert(flight.trails, trail)
			end
		end
		if Config.Pounce.Sounds.AirRush ~= "" then
			local rush = Instance.new("Sound")
			rush.Name = "HRUSH_PounceAirRush"
			rush.SoundId = Config.Pounce.Sounds.AirRush
			rush.Volume = settings.SoundVolume
			rush.Looped = true
			AudioRouter.route(rush, "sfx")
			rush.Parent = root
			rush:Play()
			flight.sound = rush
			table.insert(flight.objects, rush)
		end
		if not heartbeat then
			heartbeat = RunService.Heartbeat:Connect(function()
				for player, active in flights do
					local humanoid = active.root.Parent and active.root.Parent:FindFirstChildOfClass("Humanoid")
					if not active.root:IsDescendantOf(Workspace) or not humanoid or humanoid.Health <= 0 then
						Effects.cancel(player)
					else
						local visible = active.root.AssemblyLinearVelocity.Magnitude >= settings.TrailMinSpeed and VfxScale.cosmetic() > 0
						for _, trail in active.trails do trail.Enabled = visible end
						if active.sound then active.sound.Volume = if visible then settings.SoundVolume else 0 end
					end
				end
			end)
		end
	elseif phase == "TagImpact" then
		Effects.cancel(actor)
		if VfxScale.cosmetic() > 0 then
			local flash = part("Flash", settings.ImpactColor)
			flash.Shape = Enum.PartType.Ball
			flash.Material = Enum.Material.Neon
			flash.Size = Vector3.one * settings.FlashSize
			flash.Position = at
			flash.Parent = Workspace
			TweenService:Create(flash, TweenInfo.new(settings.Lifetime), { Transparency = 1, Size = Vector3.one * settings.FlashSize * 2 }):Play()
			Debris:AddItem(flash, settings.Lifetime)
		end
		burst(at, settings.HitCount, settings.ImpactColor, settings.ImpactRadius)
		streaks(at, root.CFrame.LookVector, settings.ImpactColor)
		ring(at)
	elseif phase == "Landing" or phase == "MissLanding" then
		Effects.cancel(actor)
		burst(at - Vector3.yAxis * 2, if phase == "Landing" then settings.LandCount else settings.MissCount, settings.DustColor, settings.DustRadius)
	else
		return
	end
	AudioRouter.playSfxId(Config.Pounce.Sounds[soundKey], settings.SoundVolume, root)
end

Players.PlayerRemoving:Connect(Effects.cancel)

local debugFolder: Folder? = nil
local debugParts: { [string]: Part } = {}
local debugText: TextLabel? = nil
local debugTarget: Highlight? = nil

function Effects.debug(root: BasePart?, direction: Vector3, state: string, id: number, cooldown: number, target: BasePart?, result: string)
	if not Config.Pounce.Debug or not RunService:IsStudio() then return end
	if not root or not root:IsDescendantOf(Workspace) then
		if debugFolder then debugFolder:Destroy(); debugFolder = nil end
		debugParts = {}
		return
	end
	if not debugFolder then
		local folder = Instance.new("Folder")
		folder.Name = "HRUSH_PounceDebug"
		folder.Parent = Workspace
		debugFolder = folder
		for _, name in { "Hitbox", "Direction", "ConeLeft", "ConeRight" } do
			local object = part(name, Color3.fromRGB(80, 220, 255))
			object.Material = Enum.Material.Neon
			object.Transparency = if name == "Hitbox" then 0.8 else 0.25
			object.Parent = folder
			debugParts[name] = object
		end
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(360, 54)
		billboard.StudsOffset = Vector3.new(0, 4, 0)
		billboard.AlwaysOnTop = true
		billboard.Adornee = debugParts.Hitbox
		billboard.Parent = folder
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 0.25
		text.BackgroundColor3 = Color3.new(0, 0, 0)
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextSize = 12
		text.Font = Enum.Font.Code
		text.Parent = billboard
		debugText = text
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 0.7
		highlight.Parent = folder
		debugTarget = highlight
	end
	local frame = CFrame.lookAt(root.Position, root.Position + direction)
	debugParts.Hitbox.CFrame = frame * CFrame.new(Config.Pounce.HitboxOffset)
	debugParts.Hitbox.Size = Config.Pounce.HitboxSize
	for name, angle in { Direction = 0, ConeLeft = Config.Pounce.MaxTagAngle, ConeRight = -Config.Pounce.MaxTagAngle } do
		local rayFrame = frame * CFrame.Angles(0, math.rad(angle), 0)
		local length = Config.Pounce.MaxHitDistance
		debugParts[name].Size = Vector3.new(0.05, 0.05, length)
		debugParts[name].CFrame = rayFrame * CFrame.new(0, 0, -length / 2)
	end
	if debugTarget then debugTarget.Adornee = target and target.Parent or nil end
	if debugText then debugText.Text = string.format("%s  id=%d  cooldown=%.2f\nserver=%s  target=%s", state, id, cooldown, result, if target and target.Parent then target.Parent.Name else "none") end
end

return Effects
