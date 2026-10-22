--!strict
-- Path: ReplicatedStorage/VFX/WindDash.lua
-- Owner: Project Owner
-- Responsibility: client-only, source-owned wind dash presentation for local and observed characters.
-- Task/spec: approved Wind Dash VFX Preview and runtime replacement, 2026-10-22.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local movement = Config.Movement
local fx = movement.DashVFX

export type Handle = { Cancel: () -> () }

local WindDash = {}
local active: { [Model]: Handle } = {}

local function scaledTransparency(source: NumberSequence, intensity: number, fade: number?): NumberSequence
	local opacity = intensity * (1 - (fade or 0))
	local points = {}
	for _, keypoint in source.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(keypoint.Time, 1 - (1 - keypoint.Value) * opacity))
	end
	return NumberSequence.new(points)
end

local function scaledWidth(width: number, intensity: number): NumberSequence
	local scale = fx.WidthFloor + (1 - fx.WidthFloor) * intensity
	local points = {}
	for _, point in fx.TrailWidthProfile do
		table.insert(points, NumberSequenceKeypoint.new(point[1], point[2] * width * scale))
	end
	return NumberSequence.new(points)
end

local function invisiblePart(name: string, cframe: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = parent
	return part
end

local function attachment(name: string, position: Vector3, parent: Instance): Attachment
	local item = Instance.new("Attachment")
	item.Name = name
	item.Position = position
	item.Parent = parent
	return item
end

local function particle(name: string, parent: Instance, intensity: number, isBurst: boolean): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = name
	emitter.Texture = fx.Texture
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.LockedToPart = false
	emitter.Orientation = Enum.ParticleOrientation.VelocityParallel
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.LightEmission = if isBurst then fx.RibbonLightEmission else 0
	emitter.Brightness = 1
	if isBurst then
		emitter.Color = ColorSequence.new(fx.PaleCyan, fx.IcyBlue)
		emitter.Size = fx.BurstSize
		emitter.Transparency = scaledTransparency(fx.BurstTransparency, intensity)
		emitter.Lifetime = fx.BurstLifetime
		emitter.Speed = fx.BurstSpeed
		emitter.SpreadAngle = fx.BurstSpread
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Acceleration = fx.BurstAcceleration
	else
		emitter.Color = ColorSequence.new(fx.White, fx.IcyBlue)
		emitter.Size = fx.FleckSize
		emitter.Transparency = scaledTransparency(fx.FleckTransparency, intensity)
		emitter.Lifetime = fx.FleckLifetime
		emitter.Speed = fx.FleckSpeed
		emitter.SpreadAngle = fx.FleckSpread
		emitter.EmissionDirection = Enum.NormalId.Back
	end
	emitter.Parent = parent
	return emitter
end

local function createRig(startPosition: Vector3, basis: CFrame, intensity: number)
	local model = Instance.new("Model")
	model.Name = "WindDashFX"
	local pulsePosition = startPosition + Vector3.yAxis * fx.FootOffset
	local pulse = invisiblePart("PulseCore", CFrame.new(pulsePosition) * basis, model)
	local guide = invisiblePart("RibbonGuide", CFrame.new(startPosition + Vector3.yAxis * fx.GuideOffset) * basis, model)
	local pulseAttachment = attachment("FootPulse", Vector3.new(0, -0.08, 0), pulse)
	local burst = particle("FootBurst", pulseAttachment, intensity, true)
	local flecks = particle("AirFlecks", guide, intensity, false)

	local beam = Instance.new("Beam")
	beam.Name = "WindRibbon"
	beam.Attachment0 = attachment("BeamStart", fx.BeamStartOffset, pulse)
	beam.Attachment1 = attachment("BeamEnd", Vector3.zero, guide)
	beam.Texture = fx.Texture
	beam.TextureMode = Enum.TextureMode.Stretch
	beam.Width0 = fx.BeamWidths[1] * intensity
	beam.Width1 = fx.BeamWidths[2] * intensity
	beam.CurveSize0 = fx.BeamCurves[1]
	beam.CurveSize1 = fx.BeamCurves[2]
	beam.Segments = 16
	beam.FaceCamera = true
	beam.LightEmission = fx.RibbonLightEmission
	beam.Brightness = fx.RibbonBrightness
	beam.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, fx.PaleCyan),
		ColorSequenceKeypoint.new(0.65, fx.White),
		ColorSequenceKeypoint.new(1, fx.IcyBlue),
	})
	beam.Transparency = scaledTransparency(fx.BeamTransparency, intensity)
	beam.Enabled = false
	beam.Parent = pulse

	local trails: { Trail } = {}
	for index, offsets in fx.RibbonOffsets do
		local trail = Instance.new("Trail")
		trail.Name = "RibbonTrail" .. index
		trail.Attachment0 = attachment("Ribbon" .. index .. "A", offsets[1], guide)
		trail.Attachment1 = attachment("Ribbon" .. index .. "B", offsets[2], guide)
		trail.Texture = if index == 3 then fx.Texture else ""
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.Lifetime = fx.TrailLifetime
		trail.MinLength = 0.05
		trail.FaceCamera = true
		trail.LightEmission = fx.RibbonLightEmission
		trail.Brightness = fx.RibbonBrightness
		trail.Color = ColorSequence.new(fx.White, fx.IcyBlue)
		trail.WidthScale = scaledWidth(fx.TrailWidths[index], intensity)
		trail.Transparency = scaledTransparency(fx.TrailTransparency[index], intensity)
		trail.Enabled = false
		trail.Parent = guide
		table.insert(trails, trail)
	end
	model.Parent = Workspace
	return model, guide, beam, trails, burst, flecks
end

-- Cosmetic only. The anchored guide reads the character position and never writes to it.
function WindDash.Play(character: Model, direction: Vector3, startPosition: Vector3, age: number, intensity: number): Handle?
	if not fx.Enabled or intensity <= 0 or age >= fx.TotalTime then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and root:IsA("BasePart") and humanoid and humanoid.Health > 0) then
		return nil
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 then
		return nil
	end
	local basis = CFrame.lookAt(Vector3.zero, flat.Unit)
	local previous = active[character]
	if previous then
		previous.Cancel()
	end
	intensity = math.clamp(intensity, 0, 1)
	local model, guide, beam, trails, burst, flecks = createRig(startPosition, basis, intensity)
	local started = os.clock() - math.max(0, age)
	local burstDone = false
	local firstFlecksDone = false
	local secondFlecksDone = false
	local guideFrozen = false
	local connection: RBXScriptConnection? = nil
	local handle: Handle

	local function cancel()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if active[character] == handle then
			active[character] = nil
		end
		model:Destroy()
	end

	handle = { Cancel = cancel }
	active[character] = handle
	local function step()
		if character.Parent == nil or root.Parent ~= character or humanoid.Health <= 0 then
			cancel()
			return
		end
		local elapsed = os.clock() - started
		if elapsed >= fx.TotalTime then
			cancel()
			return
		end
		if not guideFrozen then
			local progress = math.clamp(elapsed / movement.DashDuration, 0, 1)
			local bend = math.sin(progress * math.pi * 2)
			local guidePosition = root.Position + Vector3.yAxis * (fx.GuideOffset + bend * fx.GuideLift)
				+ basis.RightVector * (bend * fx.GuideSway)
			guide.CFrame = CFrame.new(guidePosition) * basis
			guideFrozen = progress >= 1
		end

		if not burstDone and elapsed >= fx.BurstTime then
			burstDone = true
			if elapsed <= fx.RibbonStart then
				burst:Emit(math.floor(fx.BurstCount * intensity + 0.5))
			end
		end
		beam.Enabled = elapsed >= fx.RibbonStart
		if elapsed >= fx.RibbonStart and elapsed < fx.RibbonStop then
			for _, trail in trails do
				trail.Enabled = true
			end
			if not firstFlecksDone then
				firstFlecksDone = true
				if elapsed <= fx.FleckSecondTime then
					flecks:Emit(math.floor(fx.FleckCount * intensity + 0.5))
				end
			end
		else
			for _, trail in trails do
				trail.Enabled = false
			end
		end
		if not secondFlecksDone and elapsed >= fx.FleckSecondTime then
			secondFlecksDone = true
			if elapsed <= fx.RibbonStop then
				flecks:Emit(math.floor(fx.FleckCount * intensity + 0.5))
			end
		end
		if elapsed >= fx.RibbonStop then
			local fade = math.clamp((elapsed - fx.RibbonStop) / (fx.TotalTime - fx.RibbonStop), 0, 1)
			beam.Transparency = scaledTransparency(fx.BeamTransparency, intensity, fade)
		end
	end

	connection = RunService.RenderStepped:Connect(step)
	step()
	return handle
end

return WindDash
