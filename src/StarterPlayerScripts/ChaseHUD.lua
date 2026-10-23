--!strict
-- StarterPlayerScripts/ChaseHUD.lua (ModuleScript)
-- Owner: Project Owner
-- Responsibility: Phase 3 chase HUD: the Runner edge chevron toward a near
-- Taya, the Taya advisory tag-target marker, the tag-transfer edge pulse,
-- and the mobile hold-to-look-back button; plus the Phase 4 mobile view mode
-- button (reports and flips the CameraDirector mode). Reads ChaseState,
-- ClientSettings, TargetLockController, and the live camera; writes only its
-- own ScreenGui. Advisory visuals only: no remotes, no game state, no tag
-- validation (the server still decides every tag).
-- Task/spec: camera overhaul Phase 4, approved 2026-10-18.
-- Task/spec: approved UI/UX redesign, 2026-10-23.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Cfg = Config.Camera
local Indicator = Cfg.ChaserIndicator
local Marker = Cfg.TagMarker
local TagRules = require(ReplicatedStorage:WaitForChild("TagRules"))

local ClientSettings = require(script.Parent:WaitForChild("ClientSettings"))
local ChaseState = require(script.Parent:WaitForChild("ChaseState"))
local TargetLockController = require(script.Parent:WaitForChild("TargetLockController"))

local localPlayer = Players.LocalPlayer

local ChaseHUD = {}

local BIND = "HRUSH_ChaseHUD"
local PULSE_TIME = 0.45
local PULSE_START = 0.15
local TRANSFER_DEBOUNCE = 0.5
local MARKER_AMBER = Color3.fromRGB(255, 210, 90)
local MARKER_WHITE = Color3.fromRGB(235, 235, 240)
local CHEVRON_COLOR = Color3.fromRGB(255, 210, 90)

local running = false
local bound = false

local director: any = nil -- CameraDirector module (set at start)
local gui: ScreenGui? = nil
local chevron: Frame? = nil
local marker: Frame? = nil
local markerScale: UIScale? = nil
local pulse: Frame? = nil
local pulseStroke: UIStroke? = nil
local lookButton: TextButton? = nil
local viewButton: TextButton? = nil
local lastViewLabel = ""

local pulseT = math.huge
local pulseAt = -1000.0
local touchHeld = false

local scanAcc = 0.0
local scanInitialized = false
local scanTarget: Instance? = nil
local scanCharacter: Model? = nil
local scanRoot: BasePart? = nil
local scanInReach = false

local onRender: (number) -> ()

local function debugPrint(message: string)
	if Cfg.Debug then
		print("[HRUSH_ChaseHUD] " .. message)
	end
end

local function actionPhase(): boolean
	local state = localPlayer:GetAttribute("HRushState")
	return state == "MS_03" or state == "MS_04"
end

local function topLeftInset(): Vector2
	local topLeft = GuiService:GetGuiInset()
	return topLeft
end

local function clearScan()
	scanTarget = nil
	scanCharacter = nil
	scanRoot = nil
	scanInReach = false
end

local function releaseTouchLook()
	if touchHeld then
		touchHeld = false
		if director ~= nil then
			director.setLookBackTouch(false)
		end
	end
end

----------------------------------------------------------------------------
-- Advisory tag-target scan (Taya side)
----------------------------------------------------------------------------

-- Nearest eligible Runner within TagMarker.MaxDistance with line of sight.
-- Eligibility mirrors TagService's candidate rules (Runner, in
-- match, alive, not tag-immune, not RS_01 untouchable); the outcome is
-- advisory only, the server still validates the actual tag.
local function rescan()
	scanAcc = 0.0
	clearScan()
	if Marker.Enabled ~= true then
		return
	end
	if localPlayer:GetAttribute("HRushRole") ~= "Taya" then
		return
	end
	if localPlayer:GetAttribute("HRushStunned") == true then
		return
	end
	local camera = Workspace.CurrentCamera
	local character = localPlayer.Character
	local root: BasePart? = nil
	if character ~= nil then
		local found = character:FindFirstChild("HumanoidRootPart")
		if found ~= nil and found:IsA("BasePart") then
			root = found
		end
	end
	if camera == nil or character == nil or root == nil then
		return
	end

	local bestTarget: Instance? = nil
	local bestCharacter: Model? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = math.huge
	local now = Workspace:GetServerTimeNow()

	local function consider(targetInst: Instance, targetCharacter: Model?)
		if targetCharacter == nil then
			return
		end
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		if targetRoot == nil or not targetRoot:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
			return
		end
		local safeUntil = targetInst:GetAttribute("HRushTagSafeUntil")
		if typeof(safeUntil) == "number" and safeUntil > now then
			return
		end
		if TagRules.isUntouchable(targetCharacter) then
			return
		end
		local anchor = targetRoot.Position + Vector3.new(0, 1, 0)
		local delta = anchor - camera.CFrame.Position
		if delta.Magnitude > Marker.MaxDistance then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, targetCharacter }
		params.IgnoreWater = true
		if Workspace:Raycast(camera.CFrame.Position, delta, params) ~= nil then
			return
		end
		local distance = (targetRoot.Position - root.Position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			bestTarget = targetInst
			bestCharacter = targetCharacter
			bestRoot = targetRoot
		end
	end

	for _, other in Players:GetPlayers() do
		if other ~= localPlayer
			and other:GetAttribute("HRushRole") == "Runner"
			and other:GetAttribute("HRushInMatch") == true then
			consider(other, other.Character)
		end
	end

	if bestTarget == nil or bestRoot == nil then
		return
	end
	if TargetLockController:GetTarget() == bestTarget then
		-- The lock reticle already marks that Runner; leave the marker off.
		return
	end
	scanTarget = bestTarget
	scanCharacter = bestCharacter
	scanRoot = bestRoot
	scanInReach = bestDistance <= Config.Tag.ActionRange
	debugPrint(string.format(
		"marker %s at %.1f studs",
		if scanInReach then "in reach" else "candidate",
		bestDistance
	))
end

----------------------------------------------------------------------------
-- Per-frame presentation
----------------------------------------------------------------------------

-- Viewport points map to GUI positions by adding the topbar inset, because
-- this ScreenGui ignores the inset.
function onRender(dt: number)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return
	end
	local info = ChaseState.get()
	local inset = topLeftInset()
	local viewport = camera.ViewportSize

	-- Runner chevron: clamped to an edge, rotated to point at the Taya; hidden
	-- once the Taya is comfortably on screen (the marker is the eye's job
	-- then) and while the RS_03 aim camera owns the view.
	local showChevron = Indicator.Enabled == true
		and ClientSettings.get("chaserIndicatorEnabled") == true
		and actionPhase()
		and not info.isTaya
		and info.near
		and info.tayaRoot ~= nil
		and localPlayer:GetAttribute("HRushAiming") ~= "RS_03"
	local chevronVisible = false
	if showChevron and info.tayaRoot ~= nil and chevron ~= nil then
		local anchor = info.tayaRoot.Position + Vector3.new(0, 2, 0)
		local point, onScreen = camera:WorldToViewportPoint(anchor)
		local marginX = viewport.X * Indicator.VisibleMargin
		local marginY = viewport.Y * Indicator.VisibleMargin
		local inside = onScreen and point.Z > 0
			and point.X > marginX and point.X < viewport.X - marginX
			and point.Y > marginY and point.Y < viewport.Y - marginY
		if not inside then
			local cx = viewport.X * 0.5
			local cy = viewport.Y * 0.5
			local dx: number
			local dy: number
			if point.Z > 0 then
				dx = point.X - cx
				dy = point.Y - cy
			else
				-- Behind the camera: mirror the direction so the chevron
				-- still points at the correct side of the screen.
				dx = cx - point.X
				dy = cy - point.Y
			end
			local mag = math.sqrt(dx * dx + dy * dy)
			if mag < 1 then
				dx, dy = 0, 1
			else
				dx /= mag
				dy /= mag
			end
			local reach = math.max(viewport.X, viewport.Y)
			local px = math.clamp(cx + dx * reach, Indicator.EdgePadding, viewport.X - Indicator.EdgePadding)
			local py = math.clamp(cy + dy * reach, Indicator.EdgePadding, viewport.Y - Indicator.EdgePadding)
			chevron.Position = UDim2.fromOffset(px + inset.X, py + inset.Y)
			chevron.Rotation = math.deg(math.atan2(dy, dx)) + 90
			chevronVisible = true
		end
	end
	if chevron ~= nil then
		chevron.Visible = chevronVisible
	end

	-- Taya advisory tag marker: a diamond over the nearest eligible Runner,
	-- amber and pulsing when inside tag range.
	scanAcc += dt
	if not scanInitialized or scanAcc >= Marker.ScanInterval then
		scanInitialized = true
		rescan()
	end
	local markerVisible = false
	if marker ~= nil
		and scanRoot ~= nil
		and scanRoot.Parent ~= nil
		and actionPhase()
		and localPlayer:GetAttribute("HRushRole") == "Taya" then
		local anchor = scanRoot.Position + Vector3.new(0, 1, 0)
		local point, onScreen = camera:WorldToViewportPoint(anchor)
		if onScreen and point.Z > 0 then
			marker.Position = UDim2.fromOffset(point.X + inset.X, point.Y + inset.Y)
			marker.BackgroundColor3 = if scanInReach then MARKER_AMBER else MARKER_WHITE
			if markerScale ~= nil then
				markerScale.Scale = if scanInReach then 1 + 0.12 * math.sin(os.clock() * 7.0) else 1
			end
			markerVisible = true
		end
	end
	if marker ~= nil then
		marker.Visible = markerVisible
	end

	-- Tag-transfer edge pulse: a short amber frame flash on a local role
	-- change; fully procedural, no tweens to leak.
	if pulse ~= nil and pulseStroke ~= nil and pulseT < math.huge then
		pulseT += dt
		local a = math.clamp(pulseT / PULSE_TIME, 0, 1)
		pulseStroke.Transparency = PULSE_START + (1 - PULSE_START) * a
		if a >= 1 then
			pulseT = math.huge
			pulse.Visible = false
		end
	end

	-- Mobile view mode button (Phase 4) and hold-to-look-back button. The
	-- view button reports and flips the CameraDirector mode; look-back hides
	-- in first person because the swing is a third-person camera feature.
	local viewMode = "ThirdPerson"
	if director ~= nil then
		local got = director.getViewMode()
		if typeof(got) == "string" then
			viewMode = got
		end
	end
	local showView = UserInputService.TouchEnabled
		and Cfg.FirstPerson.Enabled == true
		and actionPhase()
	if viewButton ~= nil then
		viewButton.Visible = showView
		if showView then
			local label = if viewMode == "FirstPerson" then "1P" else "3P"
			if label ~= lastViewLabel then
				lastViewLabel = label
				viewButton.Text = label
			end
		end
	end
	local role = localPlayer:GetAttribute("HRushRole")
	local showLook = UserInputService.TouchEnabled
		and localPlayer:GetAttribute("HRushGameMode") == "ClassicTag"
		and Cfg.LookBack.Enabled == true
		and ClientSettings.get("lookBackEnabled") == true
		and actionPhase()
		and role == "Runner"
		and viewMode ~= "FirstPerson"
	if lookButton ~= nil then
		lookButton.Visible = showLook
	end
	if not showLook then
		releaseTouchLook()
	end
end

----------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------

local function syncBound()
	local active = Cfg.Enabled and localPlayer:GetAttribute("HRushInMatch") == true
	if gui ~= nil then
		gui.Enabled = active
	end
	if active and not bound then
		bound = true
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 5, onRender)
	elseif not active and bound then
		bound = false
		RunService:UnbindFromRenderStep(BIND)
		if chevron ~= nil then
			chevron.Visible = false
		end
		if marker ~= nil then
			marker.Visible = false
		end
		if pulse ~= nil then
			pulse.Visible = false
		end
		if viewButton ~= nil then
			viewButton.Visible = false
		end
		pulseT = math.huge
		clearScan()
		releaseTouchLook()
	end
end

local function onRoleChanged()
	if not bound then
		return
	end
	if localPlayer:GetAttribute("HRushState") ~= "MS_04" then
		return
	end
	local role = localPlayer:GetAttribute("HRushRole")
	if role ~= "Taya" and role ~= "Runner" then
		return
	end
	local now = os.clock()
	if now - pulseAt < TRANSFER_DEBOUNCE then
		return
	end
	pulseAt = now
	pulseT = 0.0
	if pulse ~= nil then
		pulse.Visible = true
	end
	if pulseStroke ~= nil then
		pulseStroke.Transparency = PULSE_START
	end
	debugPrint("tag transfer pulse: now " .. role)
end

local function build()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild("HRushChaseHUD") ~= nil then
		return
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HRushChaseHUD"
	screen.DisplayOrder = Config.UI.Theme.Layers.HUD
	screen.IgnoreGuiInset = false
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ResetOnSpawn = false
	screen.Enabled = false

	local chevronFrame = Instance.new("Frame")
	chevronFrame.Name = "ChaserChevron"
	chevronFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	chevronFrame.Size = UDim2.fromOffset(44, 44)
	chevronFrame.BackgroundTransparency = 1
	chevronFrame.Visible = false
	chevronFrame.ZIndex = 2

	local barLeft = Instance.new("Frame")
	barLeft.Name = "BarLeft"
	barLeft.AnchorPoint = Vector2.new(0.5, 0.5)
	barLeft.Position = UDim2.fromScale(0.32, 0.56)
	barLeft.Size = UDim2.fromOffset(4, 16)
	barLeft.Rotation = 35
	barLeft.BackgroundColor3 = CHEVRON_COLOR
	barLeft.BorderSizePixel = 0
	barLeft.Parent = chevronFrame

	local barRight = Instance.new("Frame")
	barRight.Name = "BarRight"
	barRight.AnchorPoint = Vector2.new(0.5, 0.5)
	barRight.Position = UDim2.fromScale(0.68, 0.56)
	barRight.Size = UDim2.fromOffset(4, 16)
	barRight.Rotation = -35
	barRight.BackgroundColor3 = CHEVRON_COLOR
	barRight.BorderSizePixel = 0
	barRight.Parent = chevronFrame

	local markerFrame = Instance.new("Frame")
	markerFrame.Name = "TagMarker"
	markerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	markerFrame.Size = UDim2.fromOffset(16, 16)
	markerFrame.Rotation = 45
	markerFrame.BackgroundColor3 = MARKER_WHITE
	markerFrame.BorderSizePixel = 0
	markerFrame.Visible = false
	markerFrame.ZIndex = 3
	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(0, 3)
	markerCorner.Parent = markerFrame
	local markerStroke = Instance.new("UIStroke")
	markerStroke.Thickness = 2
	markerStroke.Color = Color3.fromRGB(20, 20, 25)
	markerStroke.Transparency = 0.25
	markerStroke.Parent = markerFrame
	local markerScaleObj = Instance.new("UIScale")
	markerScaleObj.Parent = markerFrame

	local pulseFrame = Instance.new("Frame")
	pulseFrame.Name = "TransferPulse"
	pulseFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	pulseFrame.Position = UDim2.fromScale(0.5, 0.5)
	pulseFrame.Size = UDim2.fromScale(1, 1)
	pulseFrame.BackgroundTransparency = 1
	pulseFrame.Visible = false
	pulseFrame.ZIndex = 1
	local pulseStrokeObj = Instance.new("UIStroke")
	pulseStrokeObj.Thickness = 6
	pulseStrokeObj.Color = MARKER_AMBER
	pulseStrokeObj.Transparency = 1
	pulseStrokeObj.Parent = pulseFrame

	local button = Instance.new("TextButton")
	button.Name = "LookBackButton"
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.Position = UDim2.fromScale(0.94, 0.55)
	button.Size = UDim2.fromOffset(56, 56)
	button.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	button.BackgroundTransparency = 0.35
	button.Text = "LOOK"
	button.TextColor3 = Color3.fromRGB(235, 235, 240)
	button.TextSize = 13
	button.Font = Enum.Font.GothamBold
	button.AutoButtonColor = false
	button.Visible = false
	button.ZIndex = 4
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(1, 0)
	buttonCorner.Parent = button
	local buttonStroke = Instance.new("UIStroke")
	buttonStroke.Thickness = 2
	buttonStroke.Color = MARKER_AMBER
	buttonStroke.Transparency = 0.4
	buttonStroke.Parent = button

	local viewBtn = Instance.new("TextButton")
	viewBtn.Name = "ViewModeButton"
	viewBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	viewBtn.Position = UDim2.fromScale(0.94, 0.40)
	viewBtn.Size = UDim2.fromOffset(48, 48)
	viewBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	viewBtn.BackgroundTransparency = 0.35
	viewBtn.Text = "3P"
	viewBtn.TextColor3 = Color3.fromRGB(235, 235, 240)
	viewBtn.TextSize = 14
	viewBtn.Font = Enum.Font.GothamBold
	viewBtn.AutoButtonColor = false
	viewBtn.Visible = false
	viewBtn.ZIndex = 4
	local viewCorner = Instance.new("UICorner")
	viewCorner.CornerRadius = UDim.new(1, 0)
	viewCorner.Parent = viewBtn
	local viewStroke = Instance.new("UIStroke")
	viewStroke.Thickness = 2
	viewStroke.Color = MARKER_WHITE
	viewStroke.Transparency = 0.4
	viewStroke.Parent = viewBtn

	pulseFrame.Parent = screen
	chevronFrame.Parent = screen
	markerFrame.Parent = screen
	button.Parent = screen
	viewBtn.Parent = screen
	screen.Parent = playerGui

	gui = screen
	chevron = chevronFrame
	marker = markerFrame
	markerScale = markerScaleObj
	pulse = pulseFrame
	pulseStroke = pulseStrokeObj
	lookButton = button
	viewButton = viewBtn

	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch or not button.Visible then
			return
		end
		touchHeld = true
		if director ~= nil then
			director.setLookBackTouch(true)
		end
	end)
	button.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		releaseTouchLook()
	end)

	viewBtn.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch or not viewBtn.Visible then
			return
		end
		if director ~= nil then
			director.toggleViewMode()
		end
	end)
end

function ChaseHUD.start()
	if running then
		return
	end
	running = true
	director = require(script.Parent:WaitForChild("CameraDirector"))
	build()
	localPlayer:GetAttributeChangedSignal("HRushInMatch"):Connect(syncBound)
	localPlayer:GetAttributeChangedSignal("HRushRole"):Connect(onRoleChanged)
	syncBound()
end

return ChaseHUD
