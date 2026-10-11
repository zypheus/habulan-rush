local RunService = game:GetService("RunService")

local Dash = {}

local TILT = math.rad(35)
local leaning = setmetatable({}, { __mode = "k" })

local function getRootJoint(character)
	local lower = character:FindFirstChild("LowerTorso") -- R15
	if lower then return lower:FindFirstChild("Root") end
	local hrp = character:FindFirstChild("HumanoidRootPart") -- R6
	return hrp and hrp:FindFirstChild("RootJoint")
end

function Dash.Lean(character, duration)
	if not character then return end
	local joint = getRootJoint(character)
	if not joint or leaning[joint] then return end
	leaning[joint] = true

	local success, err = pcall(function()
		local original = joint.C0
		local target = CFrame.Angles(-TILT, 0, 0) * original
		local startTime = os.clock()
		local leanDuration = 0.06

		local conn: RBXScriptConnection? = nil
		conn = RunService.RenderStepped:Connect(function()
			if not joint.Parent then
				if conn then conn:Disconnect() end
				leaning[joint] = nil
				return
			end
			local elapsed = os.clock() - startTime
			local alpha = math.clamp(elapsed / leanDuration, 0, 1)
			joint.C0 = original:Lerp(target, alpha)
			if alpha >= 1 then
				if conn then conn:Disconnect() end
			end
		end)

		task.delay(duration, function()
			if not joint.Parent then leaning[joint] = nil return end
			local backStart = os.clock()
			local backDuration = 0.15
			local backConn: RBXScriptConnection? = nil
			backConn = RunService.RenderStepped:Connect(function()
				if not joint.Parent then
					if backConn then backConn:Disconnect() end
					leaning[joint] = nil
					return
				end
				local elapsed = os.clock() - backStart
				local alpha = math.clamp(elapsed / backDuration, 0, 1)
				joint.C0 = target:Lerp(original, alpha)
				if alpha >= 1 then
					if backConn then backConn:Disconnect() end
					leaning[joint] = nil
				end
			end)
		end)
	end)

	if not success then
		leaning[joint] = nil
	end
end

return Dash
