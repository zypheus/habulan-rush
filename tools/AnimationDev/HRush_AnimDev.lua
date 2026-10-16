--!strict
-- tools/AnimationDev/HRush_AnimDev.lua
-- Studio copy: Workspace/AnimationDevelopment/HRush_AnimDev (ModuleScript)
-- Owner: Project Owner
-- Responsibility: data-driven original R15 animation building, validation, and local preview.
-- Task/spec: Movement animation amendment, Batches 0 through C, approved 2026-10-15.

local AnimationClipProvider = game:GetService("AnimationClipProvider")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

export type JointPose = {
	cframe: CFrame,
	intentionalJump: boolean?,
}

export type KeyframeSpec = {
	time: number,
	easingStyle: Enum.PoseEasingStyle,
	easingDirection: Enum.PoseEasingDirection,
	pose: { [string]: JointPose },
}

export type MarkerSpec = {
	name: string,
	time: number,
}

export type AnimationSpec = {
	name: string,
	looped: boolean,
	priority: Enum.AnimationPriority,
	duration: number,
	keyframes: { KeyframeSpec },
	markers: { MarkerSpec },
	developmentOnly: boolean?,
}

local AnimDev = {}

local OUTPUT_FOLDER_NAME = "AnimationDevelopment"
local PREVIEW_RIG_NAME = "HRush_AnimationPreviewRig"
local POSITION_TOLERANCE = 0.0001
local ROTATION_TOLERANCE_DEGREES = 0.1
local MAX_ROTATION_JUMP_DEGREES = 120

local EASE = {
	Linear = {
		style = Enum.PoseEasingStyle.Linear,
		direction = Enum.PoseEasingDirection.InOut,
	},
	CubicIn = {
		style = Enum.PoseEasingStyle.CubicV2,
		direction = Enum.PoseEasingDirection.In,
	},
	CubicOut = {
		style = Enum.PoseEasingStyle.CubicV2,
		direction = Enum.PoseEasingDirection.Out,
	},
	CubicInOut = {
		style = Enum.PoseEasingStyle.CubicV2,
		direction = Enum.PoseEasingDirection.InOut,
	},
}

AnimDev.Ease = EASE

local function rx(degrees: number): CFrame
	return CFrame.Angles(math.rad(degrees), 0, 0)
end

local function ry(degrees: number): CFrame
	return CFrame.Angles(0, math.rad(degrees), 0)
end

local function rz(degrees: number): CFrame
	return CFrame.Angles(0, 0, math.rad(degrees))
end

function AnimDev.rotation(xDegrees: number, yDegrees: number, zDegrees: number): CFrame
	return rx(xDegrees) * ry(yDegrees) * rz(zDegrees)
end

function AnimDev.offset(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local AnimationSpecs: { [string]: AnimationSpec } = {
	HRush_Walk = {
		name = "HRush_Walk",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		duration = 0.70,
		keyframes = {
			{
				time = 0.00,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.02, 0) * rx(-5) * ry(-2) },
					Waist = { cframe = ry(5) * rz(1) },
					Neck = { cframe = ry(-3) * rz(-1) },
					LeftShoulder = { cframe = rx(-20) * rz(-3) },
					LeftElbow = { cframe = rx(18) },
					RightShoulder = { cframe = rx(22) * rz(3) },
					RightElbow = { cframe = rx(24) },
					LeftHip = { cframe = rx(25) * rz(-1) },
					LeftKnee = { cframe = rx(-8) },
					LeftAnkle = { cframe = rx(-5) },
					RightHip = { cframe = rx(-22) * rz(1) },
					RightKnee = { cframe = rx(-28) },
					RightAnkle = { cframe = rx(10) },
				},
			},
			{
				time = 0.12,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.07, 0) * rx(-6) * ry(-1) },
					Waist = { cframe = ry(3) },
					Neck = { cframe = ry(-2) },
					LeftShoulder = { cframe = rx(-12) * rz(-2) },
					LeftElbow = { cframe = rx(22) },
					RightShoulder = { cframe = rx(14) * rz(2) },
					RightElbow = { cframe = rx(28) },
					LeftHip = { cframe = rx(14) },
					LeftKnee = { cframe = rx(-18) },
					LeftAnkle = { cframe = rx(2) },
					RightHip = { cframe = rx(-14) },
					RightKnee = { cframe = rx(-34) },
					RightAnkle = { cframe = rx(13) },
				},
			},
			{
				time = 0.23,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.01, 0) * rx(-4) },
					Waist = { cframe = ry(1) },
					Neck = { cframe = ry(-1) },
					LeftShoulder = { cframe = rx(3) },
					LeftElbow = { cframe = rx(18) },
					RightShoulder = { cframe = rx(-2) },
					RightElbow = { cframe = rx(23) },
					LeftHip = { cframe = rx(-4) },
					LeftKnee = { cframe = rx(-8) },
					LeftAnkle = { cframe = rx(-3) },
					RightHip = { cframe = rx(5) },
					RightKnee = { cframe = rx(-42) },
					RightAnkle = { cframe = rx(11) },
				},
			},
			{
				time = 0.35,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.02, 0) * rx(-5) * ry(2) },
					Waist = { cframe = ry(-5) * rz(-1) },
					Neck = { cframe = ry(3) * rz(1) },
					LeftShoulder = { cframe = rx(22) * rz(-3) },
					LeftElbow = { cframe = rx(24) },
					RightShoulder = { cframe = rx(-20) * rz(3) },
					RightElbow = { cframe = rx(18) },
					LeftHip = { cframe = rx(-22) * rz(-1) },
					LeftKnee = { cframe = rx(-28) },
					LeftAnkle = { cframe = rx(10) },
					RightHip = { cframe = rx(25) * rz(1) },
					RightKnee = { cframe = rx(-8) },
					RightAnkle = { cframe = rx(-5) },
				},
			},
			{
				time = 0.47,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.07, 0) * rx(-6) * ry(1) },
					Waist = { cframe = ry(-3) },
					Neck = { cframe = ry(2) },
					LeftShoulder = { cframe = rx(14) * rz(-2) },
					LeftElbow = { cframe = rx(28) },
					RightShoulder = { cframe = rx(-12) * rz(2) },
					RightElbow = { cframe = rx(22) },
					LeftHip = { cframe = rx(-14) },
					LeftKnee = { cframe = rx(-34) },
					LeftAnkle = { cframe = rx(13) },
					RightHip = { cframe = rx(14) },
					RightKnee = { cframe = rx(-18) },
					RightAnkle = { cframe = rx(2) },
				},
			},
			{
				time = 0.58,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.01, 0) * rx(-4) },
					Waist = { cframe = ry(-1) },
					Neck = { cframe = ry(1) },
					LeftShoulder = { cframe = rx(-2) },
					LeftElbow = { cframe = rx(23) },
					RightShoulder = { cframe = rx(3) },
					RightElbow = { cframe = rx(18) },
					LeftHip = { cframe = rx(5) },
					LeftKnee = { cframe = rx(-42) },
					LeftAnkle = { cframe = rx(11) },
					RightHip = { cframe = rx(-4) },
					RightKnee = { cframe = rx(-8) },
					RightAnkle = { cframe = rx(-3) },
				},
			},
			{
				time = 0.70,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.02, 0) * rx(-5) * ry(-2) },
					Waist = { cframe = ry(5) * rz(1) },
					Neck = { cframe = ry(-3) * rz(-1) },
					LeftShoulder = { cframe = rx(-20) * rz(-3) },
					LeftElbow = { cframe = rx(18) },
					RightShoulder = { cframe = rx(22) * rz(3) },
					RightElbow = { cframe = rx(24) },
					LeftHip = { cframe = rx(25) * rz(-1) },
					LeftKnee = { cframe = rx(-8) },
					LeftAnkle = { cframe = rx(-5) },
					RightHip = { cframe = rx(-22) * rz(1) },
					RightKnee = { cframe = rx(-28) },
					RightAnkle = { cframe = rx(10) },
				},
			},
		},
		markers = {},
	},
	HRush_Sprint = {
		name = "HRush_Sprint",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		duration = 0.45,
		keyframes = {
			{
				time = 0.000,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(-4) * rz(-1) },
					Waist = { cframe = ry(9) * rz(2) },
					Neck = { cframe = rx(5) * ry(-6) * rz(-1) },
					LeftShoulder = { cframe = rx(-46) * ry(-4) * rz(-6) },
					LeftElbow = { cframe = rx(86) * rz(-4) },
					LeftWrist = { cframe = rx(-8) },
					RightShoulder = { cframe = rx(52) * ry(4) * rz(7) },
					RightElbow = { cframe = rx(92) * rz(4) },
					RightWrist = { cframe = rx(-10) },
					LeftHip = { cframe = rx(44) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-12) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(-38) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-48) },
					RightAnkle = { cframe = rx(17) },
				},
			},
			{
				time = 0.060,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.14, 0) * rx(-17) * ry(-2) },
					Waist = { cframe = ry(6) },
					Neck = { cframe = rx(6) * ry(-4) },
					LeftShoulder = { cframe = rx(-28) * rz(-4) },
					LeftElbow = { cframe = rx(91) },
					RightShoulder = { cframe = rx(34) * rz(5) },
					RightElbow = { cframe = rx(96) },
					LeftHip = { cframe = rx(22) },
					LeftKnee = { cframe = rx(-37) },
					LeftAnkle = { cframe = rx(7) },
					RightHip = { cframe = rx(-24) },
					RightKnee = { cframe = rx(-62) },
					RightAnkle = { cframe = rx(21) },
				},
			},
			{
				time = 0.115,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.11, 0) * rx(-16) * ry(1) * rz(1) },
					Waist = { cframe = ry(-3) * rz(-2) },
					Neck = { cframe = rx(5) * ry(2) * rz(1) },
					LeftShoulder = { cframe = rx(20) * rz(-3) },
					LeftElbow = { cframe = rx(82) },
					RightShoulder = { cframe = rx(-18) * rz(4) },
					RightElbow = { cframe = rx(88) },
					LeftHip = { cframe = rx(-27) * rz(-2) },
					LeftKnee = { cframe = rx(-23) },
					LeftAnkle = { cframe = rx(-12) },
					RightHip = { cframe = rx(33) * rz(2) },
					RightKnee = { cframe = rx(-88) },
					RightAnkle = { cframe = rx(20) },
				},
			},
			{
				time = 0.225,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(4) * rz(1) },
					Waist = { cframe = ry(-9) * rz(-2) },
					Neck = { cframe = rx(5) * ry(6) * rz(1) },
					LeftShoulder = { cframe = rx(52) * ry(-4) * rz(-7) },
					LeftElbow = { cframe = rx(92) * rz(-4) },
					LeftWrist = { cframe = rx(-10) },
					RightShoulder = { cframe = rx(-46) * ry(4) * rz(6) },
					RightElbow = { cframe = rx(86) * rz(4) },
					RightWrist = { cframe = rx(-8) },
					LeftHip = { cframe = rx(-38) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-48) },
					LeftAnkle = { cframe = rx(17) },
					RightHip = { cframe = rx(44) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-12) },
					RightAnkle = { cframe = rx(-9) },
				},
			},
			{
				time = 0.285,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.14, 0) * rx(-17) * ry(2) },
					Waist = { cframe = ry(-6) },
					Neck = { cframe = rx(6) * ry(4) },
					LeftShoulder = { cframe = rx(34) * rz(-5) },
					LeftElbow = { cframe = rx(96) },
					RightShoulder = { cframe = rx(-28) * rz(4) },
					RightElbow = { cframe = rx(91) },
					LeftHip = { cframe = rx(-24) },
					LeftKnee = { cframe = rx(-62) },
					LeftAnkle = { cframe = rx(21) },
					RightHip = { cframe = rx(22) },
					RightKnee = { cframe = rx(-37) },
					RightAnkle = { cframe = rx(7) },
				},
			},
			{
				time = 0.340,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.11, 0) * rx(-16) * ry(-1) * rz(-1) },
					Waist = { cframe = ry(3) * rz(2) },
					Neck = { cframe = rx(5) * ry(-2) * rz(-1) },
					LeftShoulder = { cframe = rx(-18) * rz(-4) },
					LeftElbow = { cframe = rx(88) },
					RightShoulder = { cframe = rx(20) * rz(3) },
					RightElbow = { cframe = rx(82) },
					LeftHip = { cframe = rx(33) * rz(-2) },
					LeftKnee = { cframe = rx(-88) },
					LeftAnkle = { cframe = rx(20) },
					RightHip = { cframe = rx(-27) * rz(2) },
					RightKnee = { cframe = rx(-23) },
					RightAnkle = { cframe = rx(-12) },
				},
			},
			{
				time = 0.450,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(-4) * rz(-1) },
					Waist = { cframe = ry(9) * rz(2) },
					Neck = { cframe = rx(5) * ry(-6) * rz(-1) },
					LeftShoulder = { cframe = rx(-46) * ry(-4) * rz(-6) },
					LeftElbow = { cframe = rx(86) * rz(-4) },
					LeftWrist = { cframe = rx(-8) },
					RightShoulder = { cframe = rx(52) * ry(4) * rz(7) },
					RightElbow = { cframe = rx(92) * rz(4) },
					RightWrist = { cframe = rx(-10) },
					LeftHip = { cframe = rx(44) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-12) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(-38) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-48) },
					RightAnkle = { cframe = rx(17) },
				},
			},
		},
		markers = {
			{ name = "FootstepL", time = 0.00 },
			{ name = "FootstepR", time = 0.225 },
		},
	},
	HRush_Dash = {
		name = "HRush_Dash",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.25,
		keyframes = {
			{
				time = 0.000,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(-4) * rz(-1) },
					Waist = { cframe = ry(9) * rz(2) },
					Neck = { cframe = rx(5) * ry(-6) * rz(-1) },
					LeftShoulder = { cframe = rx(-46) * ry(-4) * rz(-6) },
					LeftElbow = { cframe = rx(86) * rz(-4) },
					LeftWrist = { cframe = rx(-8) },
					RightShoulder = { cframe = rx(52) * ry(4) * rz(7) },
					RightElbow = { cframe = rx(92) * rz(4) },
					RightWrist = { cframe = rx(-10) },
					LeftHip = { cframe = rx(44) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-12) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(-38) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-48) },
					RightAnkle = { cframe = rx(17) },
				},
			},
			{
				time = 0.035,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.13, 0) * rx(-19) * ry(-2) },
					Waist = { cframe = rx(2) * ry(5) },
					Neck = { cframe = rx(6) * ry(-3) },
					LeftShoulder = { cframe = rx(-55) * rz(-8) },
					LeftElbow = { cframe = rx(65) },
					RightShoulder = { cframe = rx(18) * rz(8) },
					RightElbow = { cframe = rx(70) },
					LeftHip = { cframe = rx(31) },
					LeftKnee = { cframe = rx(-30) },
					RightHip = { cframe = rx(-29) },
					RightKnee = { cframe = rx(-61) },
					LeftAnkle = { cframe = rx(4) },
					RightAnkle = { cframe = rx(20) },
				},
			},
			{
				time = 0.075,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.03, 0) * rx(-31) * ry(2) * rz(1) },
					Waist = { cframe = rx(5) * ry(-4) * rz(-2) },
					Neck = { cframe = rx(12) * ry(3) * rz(1) },
					LeftShoulder = { cframe = rx(-68) * ry(-4) * rz(-12) },
					LeftElbow = { cframe = rx(34) * rz(-5) },
					LeftWrist = { cframe = rx(-13) },
					RightShoulder = { cframe = rx(-62) * ry(5) * rz(13) },
					RightElbow = { cframe = rx(29) * rz(5) },
					RightWrist = { cframe = rx(-11) },
					LeftHip = { cframe = rx(54) * ry(-4) * rz(-3) },
					LeftKnee = { cframe = rx(-24) },
					LeftAnkle = { cframe = rx(-16) },
					RightHip = { cframe = rx(-43) * ry(4) * rz(3) },
					RightKnee = { cframe = rx(-56) },
					RightAnkle = { cframe = rx(18) },
				},
			},
			{
				time = 0.140,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.06, 0) * rx(-34) * ry(3) },
					Waist = { cframe = rx(6) * ry(-5) },
					Neck = { cframe = rx(13) * ry(4) },
					LeftShoulder = { cframe = rx(-72) * ry(-4) * rz(-13) },
					LeftElbow = { cframe = rx(27) * rz(-5) },
					LeftWrist = { cframe = rx(-15) },
					RightShoulder = { cframe = rx(-66) * ry(5) * rz(14) },
					RightElbow = { cframe = rx(24) * rz(5) },
					RightWrist = { cframe = rx(-13) },
					LeftHip = { cframe = rx(58) * ry(-4) * rz(-3) },
					LeftKnee = { cframe = rx(-20) },
					LeftAnkle = { cframe = rx(-18) },
					RightHip = { cframe = rx(-46) * ry(4) * rz(3) },
					RightKnee = { cframe = rx(-52) },
					RightAnkle = { cframe = rx(16) },
				},
			},
			{
				time = 0.205,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.01, 0) * rx(-23) * ry(1) },
					Waist = { cframe = rx(3) * ry(-2) },
					Neck = { cframe = rx(8) * ry(2) },
					LeftShoulder = { cframe = rx(-43) * rz(-8) },
					LeftElbow = { cframe = rx(55) },
					RightShoulder = { cframe = rx(-38) * rz(9) },
					RightElbow = { cframe = rx(51) },
					LeftHip = { cframe = rx(27) },
					LeftKnee = { cframe = rx(-37) },
					RightHip = { cframe = rx(-22) },
					RightKnee = { cframe = rx(-63) },
					LeftAnkle = { cframe = rx(1) },
					RightAnkle = { cframe = rx(20) },
				},
			},
			{
				time = 0.250,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(4) * rz(1) },
					Waist = { cframe = ry(-9) * rz(-2) },
					Neck = { cframe = rx(5) * ry(6) * rz(1) },
					LeftShoulder = { cframe = rx(52) * ry(-4) * rz(-7) },
					LeftElbow = { cframe = rx(92) * rz(-4) },
					LeftWrist = { cframe = rx(-10) },
					RightShoulder = { cframe = rx(-46) * ry(4) * rz(6) },
					RightElbow = { cframe = rx(86) * rz(4) },
					RightWrist = { cframe = rx(-8) },
					LeftHip = { cframe = rx(-38) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-48) },
					LeftAnkle = { cframe = rx(17) },
					RightHip = { cframe = rx(44) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-12) },
					RightAnkle = { cframe = rx(-9) },
				},
			},
		},
		markers = {},
	},
	HRush_JumpStart = {
		name = "HRush_JumpStart",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.20,
		keyframes = {
			{
				time = 0.00,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = rx(-4) },
					Waist = { cframe = rx(2) },
					Neck = { cframe = rx(2) },
					LeftShoulder = { cframe = rx(-8) * rz(-3) },
					RightShoulder = { cframe = rx(-8) * rz(3) },
					LeftElbow = { cframe = rx(18) },
					RightElbow = { cframe = rx(18) },
					LeftHip = { cframe = rx(-5) },
					RightHip = { cframe = rx(-5) },
					LeftKnee = { cframe = rx(-12) },
					RightKnee = { cframe = rx(-12) },
				},
			},
			{
				time = 0.045,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.16, 0) * rx(-8) },
					Waist = { cframe = rx(4) },
					Neck = { cframe = rx(4) },
					LeftShoulder = { cframe = rx(-27) * rz(-5) },
					RightShoulder = { cframe = rx(-24) * rz(5) },
					LeftElbow = { cframe = rx(32) },
					RightElbow = { cframe = rx(29) },
					LeftHip = { cframe = rx(-18) },
					RightHip = { cframe = rx(-16) },
					LeftKnee = { cframe = rx(-52) },
					RightKnee = { cframe = rx(-48) },
					LeftAnkle = { cframe = rx(16) },
					RightAnkle = { cframe = rx(15) },
				},
			},
			{
				time = 0.090,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.36, 0) * rx(-12) },
					Waist = { cframe = rx(7) },
					Neck = { cframe = rx(6) },
					LeftShoulder = { cframe = rx(-47) * rz(-7) },
					RightShoulder = { cframe = rx(-43) * rz(7) },
					LeftElbow = { cframe = rx(42) },
					RightElbow = { cframe = rx(38) },
					LeftHip = { cframe = rx(-32) * rz(-2) },
					RightHip = { cframe = rx(-29) * rz(2) },
					LeftKnee = { cframe = rx(-86) },
					RightKnee = { cframe = rx(-80) },
					LeftAnkle = { cframe = rx(24) },
					RightAnkle = { cframe = rx(22) },
				},
			},
			{
				time = 0.145,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.08, 0) * rx(-9) },
					Waist = { cframe = rx(-2) },
					Neck = { cframe = rx(2) },
					LeftShoulder = { cframe = rx(52) * rz(-9) },
					RightShoulder = { cframe = rx(58) * rz(9) },
					LeftElbow = { cframe = rx(24) },
					RightElbow = { cframe = rx(20) },
					LeftHip = { cframe = rx(11) * rz(-2) },
					RightHip = { cframe = rx(8) * rz(2) },
					LeftKnee = { cframe = rx(-14) },
					RightKnee = { cframe = rx(-11) },
					LeftAnkle = { cframe = rx(-18) },
					RightAnkle = { cframe = rx(-17) },
				},
			},
			{
				time = 0.20,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.13, 0) * rx(-7) * ry(-2) },
					Waist = { cframe = rx(-3) * ry(2) },
					Neck = { cframe = rx(1) * ry(-1) },
					LeftShoulder = { cframe = rx(62) * rz(-10) },
					RightShoulder = { cframe = rx(68) * rz(10) },
					LeftElbow = { cframe = rx(16) },
					RightElbow = { cframe = rx(13) },
					LeftHip = { cframe = rx(-9) * rz(-3) },
					RightHip = { cframe = rx(13) * rz(3) },
					LeftKnee = { cframe = rx(-22) },
					RightKnee = { cframe = rx(-8) },
					LeftAnkle = { cframe = rx(-13) },
					RightAnkle = { cframe = rx(-16) },
				},
			},
		},
		markers = {},
	},
	HRush_Fall = {
		name = "HRush_Fall",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		duration = 0.60,
		keyframes = {
			{
				time = 0.00,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = rx(-9) * ry(-2) * rz(-1) },
					Waist = { cframe = rx(3) * ry(3) },
					Neck = { cframe = rx(6) * ry(-2) },
					LeftShoulder = { cframe = rx(18) * ry(-6) * rz(-42) },
					LeftElbow = { cframe = rx(24) * rz(-8) },
					LeftWrist = { cframe = ry(-8) },
					RightShoulder = { cframe = rx(12) * ry(6) * rz(45) },
					RightElbow = { cframe = rx(28) * rz(8) },
					RightWrist = { cframe = ry(8) },
					LeftHip = { cframe = rx(-8) * ry(-6) * rz(-10) },
					LeftKnee = { cframe = rx(-25) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(12) * ry(6) * rz(12) },
					RightKnee = { cframe = rx(-18) },
					RightAnkle = { cframe = rx(-12) },
				},
			},
			{
				time = 0.15,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.03, 0) * rx(-8) * ry(2) * rz(2) },
					Waist = { cframe = rx(2) * ry(-3) * rz(-2) },
					Neck = { cframe = rx(5) * ry(3) * rz(-1) },
					LeftShoulder = { cframe = rx(14) * ry(-5) * rz(-48) },
					LeftElbow = { cframe = rx(29) * rz(-7) },
					RightShoulder = { cframe = rx(19) * ry(5) * rz(39) },
					RightElbow = { cframe = rx(22) * rz(7) },
					LeftHip = { cframe = rx(8) * ry(-5) * rz(-13) },
					LeftKnee = { cframe = rx(-17) },
					RightHip = { cframe = rx(-10) * ry(5) * rz(10) },
					RightKnee = { cframe = rx(-28) },
					LeftAnkle = { cframe = rx(-12) },
					RightAnkle = { cframe = rx(-8) },
				},
			},
			{
				time = 0.30,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = rx(-10) * ry(3) * rz(1) },
					Waist = { cframe = rx(4) * ry(-4) },
					Neck = { cframe = rx(7) * ry(3) },
					LeftShoulder = { cframe = rx(10) * ry(-4) * rz(-40) },
					LeftElbow = { cframe = rx(31) * rz(-6) },
					RightShoulder = { cframe = rx(22) * ry(4) * rz(47) },
					RightElbow = { cframe = rx(25) * rz(6) },
					LeftHip = { cframe = rx(14) * ry(-5) * rz(-9) },
					LeftKnee = { cframe = rx(-21) },
					RightHip = { cframe = rx(-12) * ry(5) * rz(14) },
					RightKnee = { cframe = rx(-31) },
					LeftAnkle = { cframe = rx(-10) },
					RightAnkle = { cframe = rx(-7) },
				},
			},
			{
				time = 0.45,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.03, 0) * rx(-10) * ry(-2) * rz(-2) },
					Waist = { cframe = rx(4) * ry(3) * rz(2) },
					Neck = { cframe = rx(6) * ry(-3) * rz(1) },
					LeftShoulder = { cframe = rx(21) * ry(-5) * rz(-38) },
					LeftElbow = { cframe = rx(22) * rz(-7) },
					RightShoulder = { cframe = rx(11) * ry(5) * rz(49) },
					RightElbow = { cframe = rx(30) * rz(7) },
					LeftHip = { cframe = rx(-11) * ry(-5) * rz(-14) },
					LeftKnee = { cframe = rx(-29) },
					RightHip = { cframe = rx(9) * ry(5) * rz(9) },
					RightKnee = { cframe = rx(-16) },
					LeftAnkle = { cframe = rx(-7) },
					RightAnkle = { cframe = rx(-12) },
				},
			},
			{
				time = 0.60,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = rx(-9) * ry(-2) * rz(-1) },
					Waist = { cframe = rx(3) * ry(3) },
					Neck = { cframe = rx(6) * ry(-2) },
					LeftShoulder = { cframe = rx(18) * ry(-6) * rz(-42) },
					LeftElbow = { cframe = rx(24) * rz(-8) },
					LeftWrist = { cframe = ry(-8) },
					RightShoulder = { cframe = rx(12) * ry(6) * rz(45) },
					RightElbow = { cframe = rx(28) * rz(8) },
					RightWrist = { cframe = ry(8) },
					LeftHip = { cframe = rx(-8) * ry(-6) * rz(-10) },
					LeftKnee = { cframe = rx(-25) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(12) * ry(6) * rz(12) },
					RightKnee = { cframe = rx(-18) },
					RightAnkle = { cframe = rx(-12) },
				},
			},
		},
		markers = {},
	},
	HRush_Land = {
		name = "HRush_Land",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.25,
		keyframes = {
			{
				time = 0.00,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.08, 0) * rx(-7) },
					Waist = { cframe = rx(2) },
					Neck = { cframe = rx(4) },
					LeftShoulder = { cframe = rx(22) * rz(-17) },
					RightShoulder = { cframe = rx(18) * rz(17) },
					LeftElbow = { cframe = rx(22) },
					RightElbow = { cframe = rx(20) },
					LeftHip = { cframe = rx(7) * rz(-2) },
					RightHip = { cframe = rx(4) * rz(2) },
					LeftKnee = { cframe = rx(-12) },
					RightKnee = { cframe = rx(-10) },
					LeftAnkle = { cframe = rx(-8) },
					RightAnkle = { cframe = rx(-8) },
				},
			},
			{
				time = 0.05,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.05, 0) * rx(-9) },
					Waist = { cframe = rx(4) },
					Neck = { cframe = rx(5) },
					LeftShoulder = { cframe = rx(8) * rz(-12) },
					RightShoulder = { cframe = rx(5) * rz(12) },
					LeftElbow = { cframe = rx(27) },
					RightElbow = { cframe = rx(25) },
					LeftHip = { cframe = rx(-9) },
					RightHip = { cframe = rx(-8) },
					LeftKnee = { cframe = rx(-32) },
					RightKnee = { cframe = rx(-30) },
					LeftAnkle = { cframe = rx(10) },
					RightAnkle = { cframe = rx(9) },
				},
			},
			{
				time = 0.08,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.29, 0) * rx(-14) },
					Waist = { cframe = rx(8) },
					Neck = { cframe = rx(7) },
					LeftShoulder = { cframe = rx(-18) * rz(-8) },
					RightShoulder = { cframe = rx(-14) * rz(8) },
					LeftElbow = { cframe = rx(38) },
					RightElbow = { cframe = rx(35) },
					LeftHip = { cframe = rx(-24) * rz(-2) },
					RightHip = { cframe = rx(-22) * rz(2) },
					LeftKnee = { cframe = rx(-68) },
					RightKnee = { cframe = rx(-64) },
					LeftAnkle = { cframe = rx(21) },
					RightAnkle = { cframe = rx(20) },
				},
			},
			{
				time = 0.16,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.10, 0) * rx(-8) },
					Waist = { cframe = rx(3) },
					Neck = { cframe = rx(3) },
					LeftShoulder = { cframe = rx(4) * rz(-5) },
					RightShoulder = { cframe = rx(1) * rz(5) },
					LeftElbow = { cframe = rx(24) },
					RightElbow = { cframe = rx(22) },
					LeftHip = { cframe = rx(-11) },
					RightHip = { cframe = rx(-10) },
					LeftKnee = { cframe = rx(-37) },
					RightKnee = { cframe = rx(-35) },
					LeftAnkle = { cframe = rx(12) },
					RightAnkle = { cframe = rx(11) },
				},
			},
			{
				time = 0.25,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = rx(-5) },
					Waist = { cframe = rx(1) },
					Neck = { cframe = rx(1) },
					LeftShoulder = { cframe = rx(-7) * rz(-3) },
					RightShoulder = { cframe = rx(9) * rz(3) },
					LeftElbow = { cframe = rx(18) },
					RightElbow = { cframe = rx(20) },
					LeftHip = { cframe = rx(8) },
					RightHip = { cframe = rx(-7) },
					LeftKnee = { cframe = rx(-11) },
					RightKnee = { cframe = rx(-18) },
				},
			},
		},
		markers = {
			{ name = "LandImpact", time = 0.08 },
		},
	},
	HRush_LandHard = {
		name = "HRush_LandHard",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.40,
		keyframes = {
			{
				time = 0.00,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.10, 0) * rx(-10) },
					Waist = { cframe = rx(4) },
					Neck = { cframe = rx(5) },
					LeftShoulder = { cframe = rx(26) * rz(-25) },
					RightShoulder = { cframe = rx(30) * rz(28) },
					LeftElbow = { cframe = rx(24) },
					RightElbow = { cframe = rx(21) },
					LeftHip = { cframe = rx(9) * rz(-4) },
					RightHip = { cframe = rx(3) * rz(5) },
					LeftKnee = { cframe = rx(-15) },
					RightKnee = { cframe = rx(-11) },
				},
			},
			{
				time = 0.07,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.14, 0) * rx(-18) * ry(3) },
					Waist = { cframe = rx(9) * ry(-3) },
					Neck = { cframe = rx(8) * ry(2) },
					LeftShoulder = { cframe = rx(4) * rz(-18) },
					RightShoulder = { cframe = rx(10) * rz(21) },
					LeftElbow = { cframe = rx(33) },
					RightElbow = { cframe = rx(29) },
					LeftHip = { cframe = rx(-17) * rz(-4) },
					RightHip = { cframe = rx(-12) * rz(5) },
					LeftKnee = { cframe = rx(-49) },
					RightKnee = { cframe = rx(-43) },
					LeftAnkle = { cframe = rx(15) },
					RightAnkle = { cframe = rx(13) },
				},
			},
			{
				time = 0.10,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.66, 0) * rx(-29) * ry(7) * rz(3) },
					Waist = { cframe = rx(17) * ry(-7) * rz(-3) },
					Neck = { cframe = rx(13) * ry(4) },
					LeftShoulder = { cframe = rx(-30) * ry(-6) * rz(-12) },
					LeftElbow = { cframe = rx(62) * rz(-4) },
					RightShoulder = { cframe = CFrame.new(0, -0.08, 0) * rx(-14) * ry(8) * rz(8) },
					RightElbow = { cframe = rx(7) * rz(5) },
					RightWrist = { cframe = rx(22) * rz(7) },
					LeftHip = { cframe = rx(-38) * ry(-5) * rz(-8) },
					LeftKnee = { cframe = rx(-104) * rz(-3) },
					LeftAnkle = { cframe = rx(29) },
					RightHip = { cframe = rx(-28) * ry(6) * rz(10) },
					RightKnee = { cframe = rx(-83) * rz(3) },
					RightAnkle = { cframe = rx(24) },
				},
			},
			{
				time = 0.16,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.70, 0) * rx(-31) * ry(6) * rz(2) },
					Waist = { cframe = rx(18) * ry(-6) * rz(-2) },
					Neck = { cframe = rx(14) * ry(4) },
					LeftShoulder = { cframe = rx(-34) * ry(-5) * rz(-10) },
					LeftElbow = { cframe = rx(66) },
					RightShoulder = { cframe = CFrame.new(0, -0.10, 0) * rx(-18) * ry(7) * rz(7) },
					RightElbow = { cframe = rx(5) * rz(4) },
					RightWrist = { cframe = rx(25) * rz(6) },
					LeftHip = { cframe = rx(-40) * ry(-5) * rz(-8) },
					LeftKnee = { cframe = rx(-108) * rz(-3) },
					LeftAnkle = { cframe = rx(31) },
					RightHip = { cframe = rx(-31) * ry(6) * rz(10) },
					RightKnee = { cframe = rx(-88) * rz(3) },
					RightAnkle = { cframe = rx(26) },
				},
			},
			{
				time = 0.25,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.38, 0) * rx(-20) * ry(3) },
					Waist = { cframe = rx(10) * ry(-3) },
					Neck = { cframe = rx(8) * ry(2) },
					LeftShoulder = { cframe = rx(-20) * rz(-7) },
					LeftElbow = { cframe = rx(47) },
					RightShoulder = { cframe = rx(8) * rz(7) },
					RightElbow = { cframe = rx(15) },
					RightWrist = { cframe = rx(12) },
					LeftHip = { cframe = rx(-26) * rz(-4) },
					LeftKnee = { cframe = rx(-77) },
					LeftAnkle = { cframe = rx(23) },
					RightHip = { cframe = rx(-19) * rz(5) },
					RightKnee = { cframe = rx(-63) },
					RightAnkle = { cframe = rx(18) },
				},
			},
			{
				time = 0.33,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.13, 0) * rx(-10) },
					Waist = { cframe = rx(4) },
					Neck = { cframe = rx(4) },
					LeftShoulder = { cframe = rx(-9) * rz(-4) },
					LeftElbow = { cframe = rx(29) },
					RightShoulder = { cframe = rx(14) * rz(5) },
					RightElbow = { cframe = rx(23) },
					LeftHip = { cframe = rx(-12) },
					LeftKnee = { cframe = rx(-41) },
					LeftAnkle = { cframe = rx(13) },
					RightHip = { cframe = rx(-8) },
					RightKnee = { cframe = rx(-34) },
					RightAnkle = { cframe = rx(10) },
				},
			},
			{
				time = 0.40,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = rx(-5) },
					Waist = { cframe = rx(1) },
					Neck = { cframe = rx(1) },
					LeftShoulder = { cframe = rx(-7) * rz(-3) },
					RightShoulder = { cframe = rx(9) * rz(3) },
					LeftElbow = { cframe = rx(18) },
					RightElbow = { cframe = rx(20) },
					LeftHip = { cframe = rx(8) },
					RightHip = { cframe = rx(-7) },
					LeftKnee = { cframe = rx(-11) },
					RightKnee = { cframe = rx(-18) },
				},
			},
		},
		markers = {
			{ name = "LandImpact", time = 0.10 },
		},
	},
	HRush_SlideEnter = {
		name = "HRush_SlideEnter",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.12,
		keyframes = {
			{
				time = 0.000,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(-4) * rz(-1) },
					Waist = { cframe = ry(9) * rz(2) },
					Neck = { cframe = rx(5) * ry(-6) * rz(-1) },
					LeftShoulder = { cframe = rx(-46) * ry(-4) * rz(-6) },
					LeftElbow = { cframe = rx(86) * rz(-4) },
					LeftWrist = { cframe = rx(-8) },
					RightShoulder = { cframe = rx(52) * ry(4) * rz(7) },
					RightElbow = { cframe = rx(92) * rz(4) },
					RightWrist = { cframe = rx(-10) },
					LeftHip = { cframe = rx(44) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-12) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(-38) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-48) },
					RightAnkle = { cframe = rx(17) },
				},
			},
			{
				time = 0.030,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.18, 0) * rx(-19) * ry(-2) },
					Waist = { cframe = rx(4) * ry(5) },
					Neck = { cframe = rx(6) * ry(-3) },
					LeftShoulder = { cframe = rx(-26) * rz(-18) },
					LeftElbow = { cframe = rx(63) },
					RightShoulder = { cframe = rx(25) * rz(19) },
					RightElbow = { cframe = rx(66) },
					LeftHip = { cframe = rx(27) * rz(-3) },
					LeftKnee = { cframe = rx(-37) },
					RightHip = { cframe = rx(-25) * rz(4) },
					RightKnee = { cframe = rx(-67) },
					LeftAnkle = { cframe = rx(8) },
					RightAnkle = { cframe = rx(22) },
				},
			},
			{
				time = 0.075,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.52, 0) * rx(10) * ry(3) * rz(2) },
					Waist = { cframe = rx(-5) * ry(-4) * rz(-3) },
					Neck = { cframe = rx(-5) * ry(3) },
					LeftShoulder = { cframe = rx(-18) * ry(-4) * rz(-34) },
					LeftElbow = { cframe = rx(53) * rz(-5) },
					RightShoulder = { cframe = rx(-12) * ry(5) * rz(38) },
					RightElbow = { cframe = rx(59) * rz(5) },
					LeftHip = { cframe = rx(46) * ry(-4) * rz(-6) },
					LeftKnee = { cframe = rx(-18) },
					LeftAnkle = { cframe = rx(-11) },
					RightHip = { cframe = rx(-31) * ry(5) * rz(8) },
					RightKnee = { cframe = rx(-91) },
					RightAnkle = { cframe = rx(24) },
				},
			},
			{
				time = 0.120,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.70, 0) * rx(24) * ry(4) * rz(2) },
					Waist = { cframe = rx(-8) * ry(-5) * rz(-3) },
					Neck = { cframe = rx(-11) * ry(4) * rz(1) },
					LeftShoulder = { cframe = rx(-16) * ry(-5) * rz(-43) },
					LeftElbow = { cframe = rx(49) * rz(-8) },
					LeftWrist = { cframe = ry(-9) },
					RightShoulder = { cframe = rx(-10) * ry(6) * rz(46) },
					RightElbow = { cframe = rx(56) * rz(8) },
					RightWrist = { cframe = ry(9) },
					LeftHip = { cframe = rx(59) * ry(-5) * rz(-8) },
					LeftKnee = { cframe = rx(-9) },
					LeftAnkle = { cframe = rx(-18) },
					RightHip = { cframe = rx(-36) * ry(6) * rz(11) },
					RightKnee = { cframe = rx(-102) },
					RightAnkle = { cframe = rx(27) },
				},
			},
		},
		markers = {},
	},
	HRush_SlideLoop = {
		name = "HRush_SlideLoop",
		looped = true,
		priority = Enum.AnimationPriority.Action,
		duration = 0.45,
		keyframes = {
			{
				time = 0.000,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.70, 0) * rx(24) * ry(4) * rz(2) },
					Waist = { cframe = rx(-8) * ry(-5) * rz(-3) },
					Neck = { cframe = rx(-11) * ry(4) * rz(1) },
					LeftShoulder = { cframe = rx(-16) * ry(-5) * rz(-43) },
					LeftElbow = { cframe = rx(49) * rz(-8) },
					LeftWrist = { cframe = ry(-9) },
					RightShoulder = { cframe = rx(-10) * ry(6) * rz(46) },
					RightElbow = { cframe = rx(56) * rz(8) },
					RightWrist = { cframe = ry(9) },
					LeftHip = { cframe = rx(59) * ry(-5) * rz(-8) },
					LeftKnee = { cframe = rx(-9) },
					LeftAnkle = { cframe = rx(-18) },
					RightHip = { cframe = rx(-36) * ry(6) * rz(11) },
					RightKnee = { cframe = rx(-102) },
					RightAnkle = { cframe = rx(27) },
				},
			},
			{
				time = 0.110,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.73, 0) * rx(26) * ry(2) * rz(1) },
					Waist = { cframe = rx(-9) * ry(-3) * rz(-2) },
					Neck = { cframe = rx(-12) * ry(3) },
					LeftShoulder = { cframe = rx(-18) * ry(-4) * rz(-46) },
					LeftElbow = { cframe = rx(52) * rz(-9) },
					LeftWrist = { cframe = ry(-10) },
					RightShoulder = { cframe = rx(-8) * ry(5) * rz(43) },
					RightElbow = { cframe = rx(53) * rz(7) },
					RightWrist = { cframe = ry(8) },
					LeftHip = { cframe = rx(61) * ry(-5) * rz(-9) },
					LeftKnee = { cframe = rx(-8) },
					LeftAnkle = { cframe = rx(-19) },
					RightHip = { cframe = rx(-38) * ry(6) * rz(10) },
					RightKnee = { cframe = rx(-104) },
					RightAnkle = { cframe = rx(28) },
				},
			},
			{
				time = 0.225,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.68, 0) * rx(23) * ry(-2) * rz(-1) },
					Waist = { cframe = rx(-7) * ry(2) * rz(1) },
					Neck = { cframe = rx(-10) * ry(-2) },
					LeftShoulder = { cframe = rx(-13) * ry(-4) * rz(-41) },
					LeftElbow = { cframe = rx(47) * rz(-7) },
					LeftWrist = { cframe = ry(-8) },
					RightShoulder = { cframe = rx(-13) * ry(5) * rz(48) },
					RightElbow = { cframe = rx(58) * rz(9) },
					RightWrist = { cframe = ry(10) },
					LeftHip = { cframe = rx(57) * ry(-5) * rz(-7) },
					LeftKnee = { cframe = rx(-11) },
					LeftAnkle = { cframe = rx(-17) },
					RightHip = { cframe = rx(-34) * ry(6) * rz(12) },
					RightKnee = { cframe = rx(-100) },
					RightAnkle = { cframe = rx(26) },
				},
			},
			{
				time = 0.340,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.72, 0) * rx(25) * ry(3) * rz(2) },
					Waist = { cframe = rx(-9) * ry(-4) * rz(-2) },
					Neck = { cframe = rx(-12) * ry(3) * rz(1) },
					LeftShoulder = { cframe = rx(-17) * ry(-5) * rz(-45) },
					LeftElbow = { cframe = rx(51) * rz(-9) },
					LeftWrist = { cframe = ry(-10) },
					RightShoulder = { cframe = rx(-9) * ry(6) * rz(44) },
					RightElbow = { cframe = rx(54) * rz(7) },
					RightWrist = { cframe = ry(8) },
					LeftHip = { cframe = rx(60) * ry(-5) * rz(-9) },
					LeftKnee = { cframe = rx(-8) },
					LeftAnkle = { cframe = rx(-19) },
					RightHip = { cframe = rx(-37) * ry(6) * rz(10) },
					RightKnee = { cframe = rx(-103) },
					RightAnkle = { cframe = rx(28) },
				},
			},
			{
				time = 0.450,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.70, 0) * rx(24) * ry(4) * rz(2) },
					Waist = { cframe = rx(-8) * ry(-5) * rz(-3) },
					Neck = { cframe = rx(-11) * ry(4) * rz(1) },
					LeftShoulder = { cframe = rx(-16) * ry(-5) * rz(-43) },
					LeftElbow = { cframe = rx(49) * rz(-8) },
					LeftWrist = { cframe = ry(-9) },
					RightShoulder = { cframe = rx(-10) * ry(6) * rz(46) },
					RightElbow = { cframe = rx(56) * rz(8) },
					RightWrist = { cframe = ry(9) },
					LeftHip = { cframe = rx(59) * ry(-5) * rz(-8) },
					LeftKnee = { cframe = rx(-9) },
					LeftAnkle = { cframe = rx(-18) },
					RightHip = { cframe = rx(-36) * ry(6) * rz(11) },
					RightKnee = { cframe = rx(-102) },
					RightAnkle = { cframe = rx(27) },
				},
			},
		},
		markers = {},
	},
	HRush_SlideExit = {
		name = "HRush_SlideExit",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.15,
		keyframes = {
			{
				time = 0.000,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.70, 0) * rx(24) * ry(4) * rz(2) },
					Waist = { cframe = rx(-8) * ry(-5) * rz(-3) },
					Neck = { cframe = rx(-11) * ry(4) * rz(1) },
					LeftShoulder = { cframe = rx(-16) * ry(-5) * rz(-43) },
					LeftElbow = { cframe = rx(49) * rz(-8) },
					LeftWrist = { cframe = ry(-9) },
					RightShoulder = { cframe = rx(-10) * ry(6) * rz(46) },
					RightElbow = { cframe = rx(56) * rz(8) },
					RightWrist = { cframe = ry(9) },
					LeftHip = { cframe = rx(59) * ry(-5) * rz(-8) },
					LeftKnee = { cframe = rx(-9) },
					LeftAnkle = { cframe = rx(-18) },
					RightHip = { cframe = rx(-36) * ry(6) * rz(11) },
					RightKnee = { cframe = rx(-102) },
					RightAnkle = { cframe = rx(27) },
				},
			},
			{
				time = 0.045,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.75, 0) * rx(18) * ry(2) },
					Waist = { cframe = rx(-5) * ry(-2) },
					Neck = { cframe = rx(-7) * ry(2) },
					LeftShoulder = { cframe = rx(-7) * rz(-37) },
					LeftElbow = { cframe = rx(55) * rz(-6) },
					RightShoulder = { cframe = rx(-3) * rz(39) },
					RightElbow = { cframe = rx(61) * rz(6) },
					LeftHip = { cframe = rx(45) * rz(-6) },
					LeftKnee = { cframe = rx(-24) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(-29) * rz(8) },
					RightKnee = { cframe = rx(-91) },
					RightAnkle = { cframe = rx(24) },
				},
			},
			{
				time = 0.095,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.31, 0) * rx(-3) * ry(-1) * rz(-1) },
					Waist = { cframe = rx(3) * ry(2) },
					Neck = { cframe = rx(4) * ry(-1) },
					LeftShoulder = { cframe = rx(24) * rz(-20) },
					LeftElbow = { cframe = rx(72) },
					RightShoulder = { cframe = rx(-29) * rz(22) },
					RightElbow = { cframe = rx(70) },
					LeftHip = { cframe = rx(8) * rz(-3) },
					LeftKnee = { cframe = rx(-51) },
					LeftAnkle = { cframe = rx(13) },
					RightHip = { cframe = rx(18) * rz(4) },
					RightKnee = { cframe = rx(-49) },
					RightAnkle = { cframe = rx(8) },
				},
			},
			{
				time = 0.150,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(4) * rz(1) },
					Waist = { cframe = ry(-9) * rz(-2) },
					Neck = { cframe = rx(5) * ry(6) * rz(1) },
					LeftShoulder = { cframe = rx(52) * ry(-4) * rz(-7) },
					LeftElbow = { cframe = rx(92) * rz(-4) },
					LeftWrist = { cframe = rx(-10) },
					RightShoulder = { cframe = rx(-46) * ry(4) * rz(6) },
					RightElbow = { cframe = rx(86) * rz(4) },
					RightWrist = { cframe = rx(-8) },
					LeftHip = { cframe = rx(-38) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-48) },
					LeftAnkle = { cframe = rx(17) },
					RightHip = { cframe = rx(44) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-12) },
					RightAnkle = { cframe = rx(-9) },
				},
			},
		},
		markers = {},
	},
	HRush_SlideJump = {
		name = "HRush_SlideJump",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.30,
		keyframes = {
			{
				time = 0.000,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.70, 0) * rx(24) * ry(4) * rz(2) },
					Waist = { cframe = rx(-8) * ry(-5) * rz(-3) },
					Neck = { cframe = rx(-11) * ry(4) * rz(1) },
					LeftShoulder = { cframe = rx(-16) * ry(-5) * rz(-43) },
					LeftElbow = { cframe = rx(49) * rz(-8) },
					LeftWrist = { cframe = ry(-9) },
					RightShoulder = { cframe = rx(-10) * ry(6) * rz(46) },
					RightElbow = { cframe = rx(56) * rz(8) },
					RightWrist = { cframe = ry(9) },
					LeftHip = { cframe = rx(59) * ry(-5) * rz(-8) },
					LeftKnee = { cframe = rx(-9) },
					LeftAnkle = { cframe = rx(-18) },
					RightHip = { cframe = rx(-36) * ry(6) * rz(11) },
					RightKnee = { cframe = rx(-102) },
					RightAnkle = { cframe = rx(27) },
				},
			},
			{
				time = 0.060,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.79, 0) * rx(20) * ry(2) },
					Waist = { cframe = rx(-5) * ry(-2) },
					Neck = { cframe = rx(-7) * ry(2) },
					LeftShoulder = { cframe = rx(-5) * rz(-35) },
					LeftElbow = { cframe = rx(61) * rz(-6) },
					RightShoulder = { cframe = rx(2) * rz(37) },
					RightElbow = { cframe = rx(65) * rz(6) },
					LeftHip = { cframe = rx(29) * rz(-6) },
					LeftKnee = { cframe = rx(-72) },
					LeftAnkle = { cframe = rx(19) },
					RightHip = { cframe = rx(-23) * rz(8) },
					RightKnee = { cframe = rx(-108) },
					RightAnkle = { cframe = rx(29) },
				},
			},
			{
				time = 0.120,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.04, 0) * rx(-11) * ry(-2) * rz(-1) },
					Waist = { cframe = rx(3) * ry(3) },
					Neck = { cframe = rx(5) * ry(-2) },
					LeftShoulder = { cframe = rx(44) * ry(-4) * rz(-20) },
					LeftElbow = { cframe = rx(42) * rz(-5) },
					RightShoulder = { cframe = rx(49) * ry(4) * rz(22) },
					RightElbow = { cframe = rx(38) * rz(5) },
					LeftHip = { cframe = rx(19) * ry(-4) * rz(-7) },
					LeftKnee = { cframe = rx(-96) },
					LeftAnkle = { cframe = rx(22) },
					RightHip = { cframe = rx(24) * ry(4) * rz(8) },
					RightKnee = { cframe = rx(-101) },
					RightAnkle = { cframe = rx(24) },
				},
			},
			{
				time = 0.200,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.17, 0) * rx(-16) * ry(-1) },
					Waist = { cframe = rx(5) * ry(2) },
					Neck = { cframe = rx(7) * ry(-1) },
					LeftShoulder = { cframe = rx(57) * ry(-4) * rz(-17) },
					LeftElbow = { cframe = rx(34) * rz(-4) },
					RightShoulder = { cframe = rx(62) * ry(4) * rz(19) },
					RightElbow = { cframe = rx(31) * rz(4) },
					LeftHip = { cframe = rx(31) * ry(-4) * rz(-8) },
					LeftKnee = { cframe = rx(-106) },
					LeftAnkle = { cframe = rx(25) },
					RightHip = { cframe = rx(36) * ry(4) * rz(9) },
					RightKnee = { cframe = rx(-112) },
					RightAnkle = { cframe = rx(27) },
				},
			},
			{
				time = 0.300,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.10, 0) * rx(-10) * ry(2) * rz(1) },
					Waist = { cframe = rx(4) * ry(-3) },
					Neck = { cframe = rx(6) * ry(2) },
					LeftShoulder = { cframe = rx(16) * ry(-5) * rz(-39) },
					LeftElbow = { cframe = rx(28) * rz(-7) },
					RightShoulder = { cframe = rx(21) * ry(5) * rz(43) },
					RightElbow = { cframe = rx(25) * rz(7) },
					LeftHip = { cframe = rx(13) * ry(-5) * rz(-10) },
					LeftKnee = { cframe = rx(-38) },
					LeftAnkle = { cframe = rx(-8) },
					RightHip = { cframe = rx(-10) * ry(5) * rz(12) },
					RightKnee = { cframe = rx(-47) },
					RightAnkle = { cframe = rx(-10) },
				},
			},
		},
		markers = {},
	},
	HRush_Roll = {
		name = "HRush_Roll",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.45,
		keyframes = {
			{
				time = 0.00,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.12, 0) * rx(-18) * ry(2) },
					Waist = { cframe = rx(8) * ry(-3) },
					Neck = { cframe = rx(9) * ry(2) },
					LeftShoulder = { cframe = rx(-28) * ry(-5) * rz(-14) },
					LeftElbow = { cframe = rx(38) * rz(-4) },
					LeftWrist = { cframe = rx(12) },
					RightShoulder = { cframe = rx(-20) * ry(5) * rz(17) },
					RightElbow = { cframe = rx(31) * rz(4) },
					RightWrist = { cframe = rx(10) },
					LeftHip = { cframe = rx(-23) * rz(-5) },
					LeftKnee = { cframe = rx(-62) },
					LeftAnkle = { cframe = rx(20) },
					RightHip = { cframe = rx(-16) * rz(6) },
					RightKnee = { cframe = rx(-51) },
					RightAnkle = { cframe = rx(17) },
				},
			},
			{
				time = 0.07,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.53, 0) * rx(-65) * ry(3) * rz(2) },
					Waist = { cframe = rx(24) * ry(-4) },
					Neck = { cframe = rx(32) * ry(3) },
					LeftShoulder = { cframe = rx(-63) * ry(-7) * rz(-9) },
					LeftElbow = { cframe = rx(24) * rz(-5) },
					LeftWrist = { cframe = rx(24) },
					RightShoulder = { cframe = rx(-55) * ry(7) * rz(11) },
					RightElbow = { cframe = rx(19) * rz(5) },
					RightWrist = { cframe = rx(22) },
					LeftHip = { cframe = rx(-53) * ry(-4) * rz(-7) },
					LeftKnee = { cframe = rx(-101) },
					LeftAnkle = { cframe = rx(30) },
					RightHip = { cframe = rx(-47) * ry(5) * rz(8) },
					RightKnee = { cframe = rx(-94) },
					RightAnkle = { cframe = rx(27) },
				},
			},
			{
				time = 0.14,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.82, 0) * rx(-125) * ry(3) },
					Waist = { cframe = rx(29) * ry(-3) },
					Neck = { cframe = rx(41) * ry(2) },
					LeftShoulder = { cframe = rx(-88) * ry(-5) * rz(-5) },
					LeftElbow = { cframe = rx(39) * rz(-4) },
					LeftWrist = { cframe = rx(28) },
					RightShoulder = { cframe = rx(-81) * ry(6) * rz(7) },
					RightElbow = { cframe = rx(35) * rz(4) },
					RightWrist = { cframe = rx(27) },
					LeftHip = { cframe = rx(-77) * ry(-5) * rz(-6) },
					LeftKnee = { cframe = rx(-116) * rz(-3) },
					LeftAnkle = { cframe = rx(34) },
					RightHip = { cframe = rx(-71) * ry(6) * rz(7) },
					RightKnee = { cframe = rx(-111) * rz(3) },
					RightAnkle = { cframe = rx(32) },
				},
			},
			{
				time = 0.22,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.86, 0) * rx(-190) * ry(1) },
					Waist = { cframe = rx(32) * ry(-2) },
					Neck = { cframe = rx(46) },
					LeftShoulder = { cframe = rx(-43) * ry(-7) * rz(-16) },
					LeftElbow = { cframe = rx(79) * rz(-8) },
					LeftWrist = { cframe = rx(18) },
					RightShoulder = { cframe = rx(-37) * ry(7) * rz(18) },
					RightElbow = { cframe = rx(74) * rz(8) },
					RightWrist = { cframe = rx(17) },
					LeftHip = { cframe = rx(-96) * ry(-4) * rz(-8) },
					LeftKnee = { cframe = rx(-119) * rz(-3) },
					LeftAnkle = { cframe = rx(36) },
					RightHip = { cframe = rx(-91) * ry(5) * rz(9) },
					RightKnee = { cframe = rx(-116) * rz(3) },
					RightAnkle = { cframe = rx(35) },
				},
			},
			{
				time = 0.30,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.72, 0) * rx(-255) * ry(-2) * rz(-1) },
					Waist = { cframe = rx(24) * ry(3) },
					Neck = { cframe = rx(35) * ry(-2) },
					LeftShoulder = { cframe = rx(8) * ry(-5) * rz(-12) },
					LeftElbow = { cframe = rx(84) * rz(-5) },
					LeftWrist = { cframe = rx(7) },
					RightShoulder = { cframe = rx(15) * ry(5) * rz(14) },
					RightElbow = { cframe = rx(80) * rz(5) },
					RightWrist = { cframe = rx(6) },
					LeftHip = { cframe = rx(-67) * ry(-5) * rz(-7) },
					LeftKnee = { cframe = rx(-104) },
					LeftAnkle = { cframe = rx(31) },
					RightHip = { cframe = rx(-61) * ry(6) * rz(8) },
					RightKnee = { cframe = rx(-98) },
					RightAnkle = { cframe = rx(29) },
				},
			},
			{
				time = 0.38,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.18, 0) * rx(-345) * ry(-4) * rz(-1) },
					Waist = { cframe = rx(5) * ry(7) * rz(1) },
					Neck = { cframe = rx(8) * ry(-5) * rz(-1) },
					LeftShoulder = { cframe = rx(-35) * ry(-4) * rz(-7) },
					LeftElbow = { cframe = rx(80) * rz(-4) },
					LeftWrist = { cframe = rx(-6) },
					RightShoulder = { cframe = rx(42) * ry(4) * rz(8) },
					RightElbow = { cframe = rx(85) * rz(4) },
					RightWrist = { cframe = rx(-7) },
					LeftHip = { cframe = rx(35) * ry(-3) * rz(-3) },
					LeftKnee = { cframe = rx(-35) },
					LeftAnkle = { cframe = rx(8) },
					RightHip = { cframe = rx(-32) * ry(4) * rz(4) },
					RightKnee = { cframe = rx(-57) },
					RightAnkle = { cframe = rx(18) },
				},
			},
			{
				time = 0.45,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-375) * ry(-4) * rz(-1) },
					Waist = { cframe = ry(9) * rz(2) },
					Neck = { cframe = rx(5) * ry(-6) * rz(-1) },
					LeftShoulder = { cframe = rx(-46) * ry(-4) * rz(-6) },
					LeftElbow = { cframe = rx(86) * rz(-4) },
					LeftWrist = { cframe = rx(-8) },
					RightShoulder = { cframe = rx(52) * ry(4) * rz(7) },
					RightElbow = { cframe = rx(92) * rz(4) },
					RightWrist = { cframe = rx(-10) },
					LeftHip = { cframe = rx(44) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-12) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(-38) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-48) },
					RightAnkle = { cframe = rx(17) },
				},
			},
		},
		markers = {
			{ name = "RollImpact", time = 0.14 },
		},
	},
	HRush_Vault = {
		name = "HRush_Vault",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.40,
		keyframes = {
			{
				time = 0.00,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(-4) * rz(-1) },
					Waist = { cframe = ry(9) * rz(2) },
					Neck = { cframe = rx(5) * ry(-6) * rz(-1) },
					LeftShoulder = { cframe = rx(-46) * ry(-4) * rz(-6) },
					LeftElbow = { cframe = rx(86) * rz(-4) },
					LeftWrist = { cframe = rx(-8) },
					RightShoulder = { cframe = rx(52) * ry(4) * rz(7) },
					RightElbow = { cframe = rx(92) * rz(4) },
					RightWrist = { cframe = rx(-10) },
					LeftHip = { cframe = rx(44) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-12) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(-38) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-48) },
					RightAnkle = { cframe = rx(17) },
				},
			},
			{
				time = 0.06,
				easingStyle = EASE.CubicIn.style,
				easingDirection = EASE.CubicIn.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.16, 0) * rx(-28) * ry(-8) * rz(-5) },
					Waist = { cframe = rx(8) * ry(14) * rz(5) },
					Neck = { cframe = rx(13) * ry(-8) * rz(-3) },
					LeftShoulder = { cframe = rx(44) * ry(-10) * rz(-30) },
					LeftElbow = { cframe = rx(42) * rz(-8) },
					LeftWrist = { cframe = rx(-22) * rz(-5) },
					RightShoulder = { cframe = rx(-35) * ry(9) * rz(18) },
					RightElbow = { cframe = rx(67) * rz(6) },
					RightWrist = { cframe = rx(-6) },
					LeftHip = { cframe = rx(-8) * ry(-8) * rz(-9) },
					LeftKnee = { cframe = rx(-72) },
					LeftAnkle = { cframe = rx(24) },
					RightHip = { cframe = rx(29) * ry(8) * rz(10) },
					RightKnee = { cframe = rx(-31) },
					RightAnkle = { cframe = rx(-8) },
				},
			},
			{
				time = 0.10,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.06, 0) * rx(-35) * ry(-13) * rz(-8) },
					Waist = { cframe = rx(12) * ry(20) * rz(8) },
					Neck = { cframe = rx(19) * ry(-12) * rz(-5) },
					LeftShoulder = { cframe = rx(96) * ry(-14) * rz(-38) },
					LeftElbow = { cframe = rx(18) * rz(-10) },
					LeftWrist = { cframe = rx(-31) * rz(-8) },
					RightShoulder = { cframe = rx(-54) * ry(12) * rz(25) },
					RightElbow = { cframe = rx(51) * rz(8) },
					RightWrist = { cframe = rx(-3) },
					LeftHip = { cframe = rx(-22) * ry(-12) * rz(-14) },
					LeftKnee = { cframe = rx(-92) },
					LeftAnkle = { cframe = rx(29) },
					RightHip = { cframe = rx(48) * ry(11) * rz(15) },
					RightKnee = { cframe = rx(-52) },
					RightAnkle = { cframe = rx(-12) },
				},
			},
			{
				time = 0.18,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.38, 0) * rx(-21) * ry(-18) * rz(-15) },
					Waist = { cframe = rx(10) * ry(27) * rz(13) },
					Neck = { cframe = rx(12) * ry(-17) * rz(-9) },
					LeftShoulder = { cframe = rx(108) * ry(-17) * rz(-42) },
					LeftElbow = { cframe = rx(12) * rz(-11) },
					LeftWrist = { cframe = rx(-35) * rz(-10) },
					RightShoulder = { cframe = rx(-25) * ry(17) * rz(35) },
					RightElbow = { cframe = rx(73) * rz(10) },
					RightWrist = { cframe = rx(5) },
					LeftHip = { cframe = rx(49) * ry(-18) * rz(-39) },
					LeftKnee = { cframe = rx(-111) * rz(-8) },
					LeftAnkle = { cframe = rx(31) },
					RightHip = { cframe = rx(57) * ry(17) * rz(-28) },
					RightKnee = { cframe = rx(-103) * rz(8) },
					RightAnkle = { cframe = rx(27) },
				},
			},
			{
				time = 0.26,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, 0.29, 0) * rx(-12) * ry(-9) * rz(-8) },
					Waist = { cframe = rx(6) * ry(16) * rz(7) },
					Neck = { cframe = rx(8) * ry(-10) * rz(-4) },
					LeftShoulder = { cframe = rx(39) * ry(-12) * rz(-30) },
					LeftElbow = { cframe = rx(48) * rz(-8) },
					LeftWrist = { cframe = rx(-18) * rz(-6) },
					RightShoulder = { cframe = rx(24) * ry(10) * rz(28) },
					RightElbow = { cframe = rx(79) * rz(8) },
					RightWrist = { cframe = rx(-4) },
					LeftHip = { cframe = rx(64) * ry(-12) * rz(-23) },
					LeftKnee = { cframe = rx(-62) * rz(-5) },
					LeftAnkle = { cframe = rx(12) },
					RightHip = { cframe = rx(17) * ry(11) * rz(-18) },
					RightKnee = { cframe = rx(-78) * rz(5) },
					RightAnkle = { cframe = rx(21) },
				},
			},
			{
				time = 0.33,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.10, 0) * rx(-22) * ry(3) * rz(3) },
					Waist = { cframe = rx(7) * ry(-7) * rz(-3) },
					Neck = { cframe = rx(10) * ry(5) * rz(2) },
					LeftShoulder = { cframe = rx(-21) * ry(-6) * rz(-11) },
					LeftElbow = { cframe = rx(74) * rz(-5) },
					LeftWrist = { cframe = rx(-7) },
					RightShoulder = { cframe = rx(43) * ry(6) * rz(12) },
					RightElbow = { cframe = rx(88) * rz(5) },
					RightWrist = { cframe = rx(-8) },
					LeftHip = { cframe = rx(36) * ry(-5) * rz(-5) },
					LeftKnee = { cframe = rx(-21) },
					LeftAnkle = { cframe = rx(-7) },
					RightHip = { cframe = rx(-29) * ry(5) * rz(6) },
					RightKnee = { cframe = rx(-61) },
					RightAnkle = { cframe = rx(20) },
				},
			},
			{
				time = 0.40,
				easingStyle = EASE.CubicOut.style,
				easingDirection = EASE.CubicOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.04, 0) * rx(-15) * ry(-4) * rz(-1) },
					Waist = { cframe = ry(9) * rz(2) },
					Neck = { cframe = rx(5) * ry(-6) * rz(-1) },
					LeftShoulder = { cframe = rx(-46) * ry(-4) * rz(-6) },
					LeftElbow = { cframe = rx(86) * rz(-4) },
					LeftWrist = { cframe = rx(-8) },
					RightShoulder = { cframe = rx(52) * ry(4) * rz(7) },
					RightElbow = { cframe = rx(92) * rz(4) },
					RightWrist = { cframe = rx(-10) },
					LeftHip = { cframe = rx(44) * ry(-3) * rz(-2) },
					LeftKnee = { cframe = rx(-12) },
					LeftAnkle = { cframe = rx(-9) },
					RightHip = { cframe = rx(-38) * ry(3) * rz(2) },
					RightKnee = { cframe = rx(-48) },
					RightAnkle = { cframe = rx(17) },
				},
			},
		},
		markers = {
			{ name = "VaultPlant", time = 0.10 },
			{ name = "VaultClear", time = 0.26 },
		},
	},
	HRush_ClimbGrab = {
		name = "HRush_ClimbGrab",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.15,
		keyframes = {},
		markers = {},
	},
	HRush_ClimbLoop = {
		name = "HRush_ClimbLoop",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		duration = 0.60,
		keyframes = {},
		markers = {},
	},
	HRush_ClimbMantle = {
		name = "HRush_ClimbMantle",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.50,
		keyframes = {},
		markers = {},
	},
	HRush_SwingGrab = {
		name = "HRush_SwingGrab",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.15,
		keyframes = {},
		markers = {},
	},
	HRush_SwingLoop = {
		name = "HRush_SwingLoop",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		duration = 0.80,
		keyframes = {},
		markers = {},
	},
	HRush_SwingRelease = {
		name = "HRush_SwingRelease",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.30,
		keyframes = {},
		markers = {},
	},
	HRush_ZipHang = {
		name = "HRush_ZipHang",
		looped = true,
		priority = Enum.AnimationPriority.Movement,
		duration = 0.80,
		keyframes = {},
		markers = {},
	},
	HRush_ZipRelease = {
		name = "HRush_ZipRelease",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.25,
		keyframes = {},
		markers = {},
	},
	HRush_PipelineSelfTest = {
		name = "HRush_PipelineSelfTest",
		looped = false,
		priority = Enum.AnimationPriority.Action,
		duration = 0.50,
		developmentOnly = true,
		keyframes = {
			{
				time = 0,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {},
			},
			{
				time = 0.25,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {
					Root = { cframe = CFrame.new(0, -0.12, 0) * rx(-8) },
					Waist = { cframe = ry(12) },
					Neck = { cframe = ry(-12) },
					LeftShoulder = { cframe = rx(35) * rz(-12) },
					LeftElbow = { cframe = rx(70) },
					LeftWrist = { cframe = rz(-18) },
					RightShoulder = { cframe = rx(-35) * rz(12) },
					RightElbow = { cframe = rx(70) },
					RightWrist = { cframe = rz(18) },
					LeftHip = { cframe = rx(-20) },
					LeftKnee = { cframe = rx(-35) },
					LeftAnkle = { cframe = rx(12) },
					RightHip = { cframe = rx(20) },
					RightKnee = { cframe = rx(-18) },
					RightAnkle = { cframe = rx(-8) },
				},
			},
			{
				time = 0.50,
				easingStyle = EASE.CubicInOut.style,
				easingDirection = EASE.CubicInOut.direction,
				pose = {},
			},
		},
		markers = {
			{ name = "PipelineMidpoint", time = 0.25 },
		},
	},
}

AnimDev.Animations = AnimationSpecs

local JOINT_NAMES = {
	Root = true,
	Waist = true,
	Neck = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftHip = true,
	LeftKnee = true,
	LeftAnkle = true,
	RightHip = true,
	RightKnee = true,
	RightAnkle = true,
}

local MIRRORED_JOINT = {
	LeftShoulder = "RightShoulder",
	LeftElbow = "RightElbow",
	LeftWrist = "RightWrist",
	RightShoulder = "LeftShoulder",
	RightElbow = "LeftElbow",
	RightWrist = "LeftWrist",
	LeftHip = "RightHip",
	LeftKnee = "RightKnee",
	LeftAnkle = "RightAnkle",
	RightHip = "LeftHip",
	RightKnee = "LeftKnee",
	RightAnkle = "LeftAnkle",
}

local function copyJointPose(value: JointPose): JointPose
	return {
		cframe = value.cframe,
		intentionalJump = value.intentionalJump,
	}
end

local function mirrorCFrame(value: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
	return CFrame.new(
		-x,
		y,
		z,
		r00,
		-r01,
		-r02,
		-r10,
		r11,
		r12,
		-r20,
		r21,
		r22
	)
end

function AnimDev.mirrorPose(source: { [string]: JointPose }): { [string]: JointPose }
	local mirrored: { [string]: JointPose } = {}
	for jointName, value in source do
		local targetName = MIRRORED_JOINT[jointName] or jointName
		mirrored[targetName] = {
			cframe = mirrorCFrame(value.cframe),
			intentionalJump = value.intentionalJump,
		}
	end
	return mirrored
end

function AnimDev.mirrorCycleKeyframes(
	source: { KeyframeSpec },
	duration: number,
	phaseOffset: number
): { KeyframeSpec }
	assert(duration > 0, "duration must be positive")
	local mirrored: { KeyframeSpec } = {}
	for _, frame in source do
		local shifted = (frame.time + phaseOffset) % duration
		table.insert(mirrored, {
			time = shifted,
			easingStyle = frame.easingStyle,
			easingDirection = frame.easingDirection,
			pose = AnimDev.mirrorPose(frame.pose),
		})
	end
	table.sort(mirrored, function(a, b)
		return a.time < b.time
	end)
	return mirrored
end

function AnimDev.copyPose(source: { [string]: JointPose }): { [string]: JointPose }
	local copied: { [string]: JointPose } = {}
	for jointName, value in source do
		copied[jointName] = copyJointPose(value)
	end
	return copied
end

local function poseCFrame(frame: KeyframeSpec, jointName: string): CFrame
	local value = frame.pose[jointName]
	if value then
		return value.cframe
	end
	return CFrame.new()
end

local function rotationDeltaDegrees(a: CFrame, b: CFrame): number
	local _, radians = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	return math.deg(math.abs(radians))
end

local function sameCFrame(a: CFrame, b: CFrame): boolean
	if (a.Position - b.Position).Magnitude > POSITION_TOLERANCE then
		return false
	end
	return rotationDeltaDegrees(a, b) <= ROTATION_TOLERANCE_DEGREES
end

local function sortedFrames(spec: AnimationSpec): { KeyframeSpec }
	local frames = table.clone(spec.keyframes)
	table.sort(frames, function(a, b)
		return a.time < b.time
	end)
	return frames
end

function AnimDev.validate(name: string): (boolean, { string })
	local spec = AnimationSpecs[name]
	if not spec then
		return false, { "unknown animation " .. name }
	end

	local errors: { string } = {}
	if spec.name ~= name then
		table.insert(errors, "table key and animation name must match")
	end
	if spec.duration <= 0 then
		table.insert(errors, "duration must be positive")
	end
	if #spec.keyframes == 0 then
		table.insert(errors, "placeholder has no keyframes")
	end

	local frames = sortedFrames(spec)
	local previousDeclaredTime = -math.huge
	local seenTimes: { [number]: boolean } = {}
	for _, frame in spec.keyframes do
		if frame.time < previousDeclaredTime then
			table.insert(errors, "keyframes must be ordered by time")
		end
		previousDeclaredTime = frame.time
	end
	for _, frame in frames do
		if frame.time < 0 or frame.time > spec.duration then
			table.insert(errors, string.format("keyframe %.3f is outside duration %.3f", frame.time, spec.duration))
		end
		if seenTimes[frame.time] then
			table.insert(errors, string.format("duplicate keyframe time %.3f", frame.time))
		end
		seenTimes[frame.time] = true

		for jointName, value in frame.pose do
			if not JOINT_NAMES[jointName] then
				table.insert(errors, "unknown joint " .. jointName)
			end
			if typeof(value.cframe) ~= "CFrame" then
				table.insert(errors, "joint " .. jointName .. " does not contain a CFrame")
			end
		end

		local rootValue = frame.pose.Root
		if rootValue then
			local rootPosition = rootValue.cframe.Position
			if math.abs(rootPosition.X) > POSITION_TOLERANCE or math.abs(rootPosition.Z) > POSITION_TOLERANCE then
				table.insert(errors, string.format("Root at %.3f moves horizontally; only LowerTorso Y offset is allowed", frame.time))
			end
		end
	end

	for index = 2, #frames do
		local previous = frames[index - 1]
		local current = frames[index]
		for jointName in JOINT_NAMES do
			local previousValue = previous.pose[jointName]
			local currentValue = current.pose[jointName]
			local intentional = (previousValue and previousValue.intentionalJump == true)
				or (currentValue and currentValue.intentionalJump == true)
			local delta = rotationDeltaDegrees(poseCFrame(previous, jointName), poseCFrame(current, jointName))
			if delta > MAX_ROTATION_JUMP_DEGREES and not intentional then
				table.insert(errors, string.format(
					"%s jumps %.1f degrees between %.3f and %.3f; flag intentionalJump if required",
					jointName,
					delta,
					previous.time,
					current.time
				))
			end
		end
	end

	if spec.looped and #frames > 0 then
		local first = frames[1]
		local last = frames[#frames]
		if math.abs(first.time) > POSITION_TOLERANCE then
			table.insert(errors, "loop must start at time 0")
		end
		if math.abs(last.time - spec.duration) > POSITION_TOLERANCE then
			table.insert(errors, "loop must end at its duration")
		end
		for jointName in JOINT_NAMES do
			if not sameCFrame(poseCFrame(first, jointName), poseCFrame(last, jointName)) then
				table.insert(errors, "loop start and end differ at " .. jointName)
			end
		end
	end

	for _, marker in spec.markers do
		if marker.name == "" then
			table.insert(errors, "marker name cannot be empty")
		end
		if marker.time < 0 or marker.time > spec.duration then
			table.insert(errors, string.format("marker %s is outside duration %.3f", marker.name, spec.duration))
		end
	end

	return #errors == 0, errors
end

local function newPose(name: string, value: CFrame, frame: KeyframeSpec, weight: number?): Pose
	local result = Instance.new("Pose")
	result.Name = name
	result.CFrame = value
	result.EasingStyle = frame.easingStyle
	result.EasingDirection = frame.easingDirection
	result.Weight = weight or 1
	return result
end

local function addPoseTree(keyframe: Keyframe, frame: KeyframeSpec)
	local humanoidRootPart = newPose("HumanoidRootPart", CFrame.new(), frame, 0)
	local lowerTorso = newPose("LowerTorso", poseCFrame(frame, "Root"), frame)
	local upperTorso = newPose("UpperTorso", poseCFrame(frame, "Waist"), frame)
	local head = newPose("Head", poseCFrame(frame, "Neck"), frame)

	local leftUpperArm = newPose("LeftUpperArm", poseCFrame(frame, "LeftShoulder"), frame)
	local leftLowerArm = newPose("LeftLowerArm", poseCFrame(frame, "LeftElbow"), frame)
	local leftHand = newPose("LeftHand", poseCFrame(frame, "LeftWrist"), frame)
	local rightUpperArm = newPose("RightUpperArm", poseCFrame(frame, "RightShoulder"), frame)
	local rightLowerArm = newPose("RightLowerArm", poseCFrame(frame, "RightElbow"), frame)
	local rightHand = newPose("RightHand", poseCFrame(frame, "RightWrist"), frame)

	local leftUpperLeg = newPose("LeftUpperLeg", poseCFrame(frame, "LeftHip"), frame)
	local leftLowerLeg = newPose("LeftLowerLeg", poseCFrame(frame, "LeftKnee"), frame)
	local leftFoot = newPose("LeftFoot", poseCFrame(frame, "LeftAnkle"), frame)
	local rightUpperLeg = newPose("RightUpperLeg", poseCFrame(frame, "RightHip"), frame)
	local rightLowerLeg = newPose("RightLowerLeg", poseCFrame(frame, "RightKnee"), frame)
	local rightFoot = newPose("RightFoot", poseCFrame(frame, "RightAnkle"), frame)

	leftLowerArm:AddSubPose(leftHand)
	leftUpperArm:AddSubPose(leftLowerArm)
	rightLowerArm:AddSubPose(rightHand)
	rightUpperArm:AddSubPose(rightLowerArm)
	upperTorso:AddSubPose(head)
	upperTorso:AddSubPose(leftUpperArm)
	upperTorso:AddSubPose(rightUpperArm)

	leftLowerLeg:AddSubPose(leftFoot)
	leftUpperLeg:AddSubPose(leftLowerLeg)
	rightLowerLeg:AddSubPose(rightFoot)
	rightUpperLeg:AddSubPose(rightLowerLeg)
	lowerTorso:AddSubPose(upperTorso)
	lowerTorso:AddSubPose(leftUpperLeg)
	lowerTorso:AddSubPose(rightUpperLeg)
	humanoidRootPart:AddSubPose(lowerTorso)
	keyframe:AddPose(humanoidRootPart)
end

local function markerKeyframe(sequence: KeyframeSequence, keyframesByTime: { [number]: Keyframe }, time: number): Keyframe
	local existing = keyframesByTime[time]
	if existing then
		return existing
	end
	local created = Instance.new("Keyframe")
	created.Name = string.format("Marker_%.3f", time)
	created.Time = time
	sequence:AddKeyframe(created)
	keyframesByTime[time] = created
	return created
end

function AnimDev.build(name: string): (KeyframeSequence?, string?)
	local spec = AnimationSpecs[name]
	if not spec then
		return nil, "unknown animation " .. name
	end
	local valid, errors = AnimDev.validate(name)
	if not valid then
		return nil, table.concat(errors, "; ")
	end

	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = spec.name
	sequence.Loop = spec.looped
	sequence.Priority = spec.priority
	local keyframesByTime: { [number]: Keyframe } = {}
	for _, frame in sortedFrames(spec) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Name = if math.abs(frame.time - spec.duration) <= POSITION_TOLERANCE then "End" else string.format("Key_%.3f", frame.time)
		keyframe.Time = frame.time
		addPoseTree(keyframe, frame)
		sequence:AddKeyframe(keyframe)
		keyframesByTime[frame.time] = keyframe
	end

	for _, markerSpec in spec.markers do
		local keyframe = markerKeyframe(sequence, keyframesByTime, markerSpec.time)
		local marker = Instance.new("KeyframeMarker")
		marker.Name = markerSpec.name
		marker.Parent = keyframe
	end

	return sequence, nil
end

local function outputFolder(): Folder
	local existing = Workspace:FindFirstChild(OUTPUT_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = OUTPUT_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

function AnimDev.buildAll(includeDevelopment: boolean?): { KeyframeSequence }
	local folder = outputFolder()
	local built: { KeyframeSequence } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("KeyframeSequence") and string.match(child.Name, "^HRush_") then
			child:Destroy()
		end
	end
	for name, spec in AnimationSpecs do
		if (includeDevelopment or not spec.developmentOnly) and #spec.keyframes > 0 then
			local sequence, buildError = AnimDev.build(name)
			assert(sequence, buildError)
			sequence.Parent = folder
			table.insert(built, sequence)
		end
	end
	table.sort(built, function(a, b)
		return a.Name < b.Name
	end)
	return built
end

function AnimDev.validateAll(): boolean
	local allValid = true
	local names: { string } = {}
	for name in AnimationSpecs do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local spec = AnimationSpecs[name]
		if #spec.keyframes == 0 then
			print("[HRush AnimDev] PLACEHOLDER " .. name)
		else
			local valid, errors = AnimDev.validate(name)
			if valid then
				print("[HRush AnimDev] OK " .. name)
			else
				allValid = false
				warn("[HRush AnimDev] INVALID " .. name .. ": " .. table.concat(errors, "; "))
			end
		end
	end
	return allValid
end

function AnimDev.spawnPreviewRig(position: Vector3?): Model
	local existing = Workspace:FindFirstChild(PREVIEW_RIG_NAME)
	if existing then
		existing:Destroy()
	end
	local rig = Players:CreateHumanoidModelFromDescriptionAsync(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R15
	)
	rig.Name = PREVIEW_RIG_NAME
	rig:PivotTo(CFrame.new(position or Vector3.new(0, 4, 0)))
	local humanoidRootPart = rig:FindFirstChild("HumanoidRootPart")
	if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
		humanoidRootPart.Anchored = true
	end
	rig.Parent = Workspace
	return rig
end

local activePreviewTrack: AnimationTrack? = nil

local function previewAnimator(rig: Model): Animator
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	assert(humanoid, rig:GetFullName() .. " has no Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end
	local created = Instance.new("Animator")
	created.Parent = humanoid
	return created
end

function AnimDev.stopPreview(fadeTime: number?)
	if activePreviewTrack then
		activePreviewTrack:Stop(fadeTime or 0.08)
		activePreviewTrack = nil
	end
end

function AnimDev.preview(name: string, speed: number?, rig: Model?): AnimationTrack
	local sequence, buildError = AnimDev.build(name)
	assert(sequence, buildError)
	local targetRig = rig or Workspace:FindFirstChild(PREVIEW_RIG_NAME)
	if not (targetRig and targetRig:IsA("Model")) then
		targetRig = AnimDev.spawnPreviewRig()
	end
	AnimDev.stopPreview(0)
	local temporaryId = AnimationClipProvider:RegisterAnimationClip(sequence)
	local animation = Instance.new("Animation")
	animation.Name = name .. "_Preview"
	animation.AnimationId = temporaryId
	local track = previewAnimator(targetRig):LoadAnimation(animation)
	track.Priority = sequence.Priority
	track.Looped = sequence.Loop
	track:Play(0.08, 1, speed or 1)
	animation:Destroy()
	sequence:Destroy()
	activePreviewTrack = track
	return track
end

function AnimDev.previewQuarterSpeed(name: string, rig: Model?): AnimationTrack
	return AnimDev.preview(name, 0.25, rig)
end

function AnimDev.scrub(name: string, time: number, rig: Model?): AnimationTrack
	local spec = AnimationSpecs[name]
	assert(spec, "unknown animation " .. name)
	local track = AnimDev.preview(name, 0, rig)
	track.TimePosition = math.clamp(time, 0, spec.duration)
	track:AdjustSpeed(0)
	track:AdjustWeight(1, 0)
	return track
end

function AnimDev.destroyPreviewRig()
	AnimDev.stopPreview(0)
	local existing = Workspace:FindFirstChild(PREVIEW_RIG_NAME)
	if existing then
		existing:Destroy()
	end
end

return AnimDev
