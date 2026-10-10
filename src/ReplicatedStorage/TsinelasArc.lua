--!strict
-- ReplicatedStorage/TsinelasArc.lua
-- Owner: Programmer B (T18)
-- Responsibility: pure parabolic arc math for RS_03 Tsinelas Throw.
-- WHY: the server hit test, the client slipper, and the aim indicator must
-- follow the same curve, so the model lives in ONE module with no side
-- effects that all three call. Server authoritative; the client only reads.
-- Math: fixed 45 degree launch. Flat ground: v = sqrt(g * d), apex d / 4,
-- flight time sqrt(2 * d / g). Height h above launch: v^2 = g * d^2 / (d - h)
-- with g = (0, -G, 0) from Config. Position: x(t) = 0.5*g*t*t + v0*t + x0.
-- Range is the maximum horizontal distance from thrower to landing point.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local TsinelasArc = {}

-- Slipper gravity, always pointing down. Never workspace.Gravity: the throw
-- must feel slow and light and stay tunable from Config.
function TsinelasArc.gravity(): Vector3
	return Vector3.new(0, -Config.Skills.RS_03.params.arcGravity, 0)
end

-- Fixed 45 degree launch solved from distance. Returns the launch velocity,
-- the flight time, true when the target was clamped for reachability
-- ("short": the indicator shows the blocked color), and the effective
-- landing point. Pure math; the server and all clients reach the same
-- answer from the same inputs. The payload carries the landing point so
-- the cosmetic arc matches the sim exactly.
function TsinelasArc.solveArc(origin: Vector3, desired: Vector3): (Vector3, number, boolean, Vector3)
	local params = Config.Skills.RS_03.params
	local g = params.arcGravity -- positive magnitude; gravity points down
	local maxRange: number = Config.Skills.RS_03.range
	local target = TsinelasArc.clampTarget(origin, desired, maxRange)
	local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	local d = flat.Magnitude
	local short = false
	if d < params.minDistance then
		-- Too close: throw to the minimum distance along the same heading
		-- so close range never becomes a tiny hop.
		local push = if d > 0.001 then flat.Unit else Vector3.new(0, 0, -1)
		target = Vector3.new(origin.X + push.X * params.minDistance, target.Y, origin.Z + push.Z * params.minDistance)
		d = params.minDistance
	end
	local h = math.clamp(target.Y - origin.Y, -params.maxHeightDiff, params.maxHeightDiff)
	if h > d - 0.5 then
		-- Too high to reach at 45 degrees: clamp to the highest reachable
		-- height and flag it short.
		h = d - 0.5
		short = true
	end
	-- 45 degree launch: vh equals vy, so v^2 = g * d^2 / (d - h).
	local v = math.sqrt(g * d * d / (d - h))
	local vh = v / math.sqrt(2)
	local dirXZ = Vector3.new(flat.X, 0, flat.Z)
	if dirXZ.Magnitude < 0.001 then
		dirXZ = Vector3.new(0, 0, -1)
	else
		dirXZ = dirXZ.Unit
	end
	local v0 = Vector3.new(dirXZ.X * vh, vh, dirXZ.Z * vh)
	local landed = Vector3.new(target.X, origin.Y + h, target.Z)
	return v0, d / vh, short, landed
end

-- Arc position at time t after launch.
function TsinelasArc.position(x0: Vector3, v0: Vector3, t: number): Vector3
	local g = TsinelasArc.gravity()
	return 0.5 * g * t * t + v0 * t + x0
end

-- Clamps the desired point to maxRange horizontal studs from origin,
-- keeping its height. Pure math; callers supply raycast heights.
function TsinelasArc.clampTarget(origin: Vector3, desired: Vector3, maxRange: number): Vector3
	local flat = Vector3.new(desired.X - origin.X, 0, desired.Z - origin.Z)
	local dist = flat.Magnitude
	if dist <= maxRange or dist < 0.001 then
		return desired
	end
	local clamped = flat.Unit * maxRange
	return Vector3.new(origin.X + clamped.X, desired.Y, origin.Z + clamped.Z)
end

-- Shortest distance from p to the segment a-b. The arc curves, so the hit
-- test measures against segments, not points.
function TsinelasArc.distToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local denom = ab:Dot(ab)
	if denom < 0.000001 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / denom, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

return TsinelasArc
