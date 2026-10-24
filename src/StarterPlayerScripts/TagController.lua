--!strict
-- StarterPlayerScripts/TagController.lua
-- Owner: Project Owner
-- Responsibility: click, R2, and touch tag input plus isolated first-person animation playback.
-- Task/spec: repair the character animation conflict in simple click tagging, approved 2026-10-18.
-- Task/spec: Agawan ng Panyo steal input, approved 2026-10-23.
-- Task/spec: Panyo mobile STEAL button recovery, approved 2026-10-23.
-- Task/spec: Lihim na Target capture input, approved 2026-10-23.
-- Task/spec: complete R15 punch rig before local playback, approved 2026-10-24.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local CameraDirector = require(script.Parent:WaitForChild("CameraDirector"))
local RequestTag = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestTag") :: RemoteEvent
local localPlayer = Players.LocalPlayer

local TagController = {}
local ACTION = "HRUSH_Tag"
local VIEW_MODEL_NAME = "HRUSH_FirstPersonTagViewModel"
local ARM_NAMES: { [string]: boolean } = {
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
}
local ARM_JOINT_NAMES = {
	"LeftShoulder", "LeftElbow", "LeftWrist",
	"RightShoulder", "RightElbow", "RightWrist",
}

local running = false
local activeCharacter: Model? = nil
local viewModel: Model? = nil
local viewModelTrack: AnimationTrack? = nil
local viewModelArms: { BasePart } = {}
local hiddenCharacterArms: { [BasePart]: number } = {}
local firstPersonPlaying = false
local playGeneration = 0
local buildGeneration = 0
local touchRefreshElapsed = 0
local lastTouchButton: Instance? = nil
local lastTouchTitle = ""

local function canTag(): boolean
	local isPanyo = localPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo"
	local isHunt = localPlayer:GetAttribute("HRushGameMode") == "SecretHunt"
	local carrierId = ReplicatedStorage:GetAttribute("HRushPanyoCarrierUserId")
	return localPlayer:GetAttribute("HRushInMatch") == true
		and localPlayer:GetAttribute("HRushState") == "MS_04"
		and (if isPanyo then typeof(carrierId) == "number" and carrierId ~= localPlayer.UserId
			else if isHunt then localPlayer:GetAttribute("HRushHuntTargetReady") == true
			else localPlayer:GetAttribute("HRushRole") == "Taya")
		and localPlayer:GetAttribute("HRushStunned") ~= true
		and localPlayer:GetAttribute("HRushAbilityBusy") ~= true
end

local function restoreCharacterArms()
	for part, transparency in hiddenCharacterArms do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = transparency
		end
	end
	table.clear(hiddenCharacterArms)
end

local function setViewModelVisible(visible: boolean)
	for _, part in viewModelArms do
		part.Transparency = if visible then 0 else 1
	end
	if visible then
		local character = activeCharacter
		if character ~= nil then
			for partName in ARM_NAMES do
				local part = character:FindFirstChild(partName)
				if part ~= nil and part:IsA("BasePart") then
					if hiddenCharacterArms[part] == nil then
						hiddenCharacterArms[part] = part.LocalTransparencyModifier
					end
					part.LocalTransparencyModifier = 1
				end
			end
		end
	else
		restoreCharacterArms()
	end
	firstPersonPlaying = visible
end

local function stopFirstPersonAnimation()
	playGeneration += 1
	local track = viewModelTrack
	if track ~= nil and track.IsPlaying then
		track:Stop(Config.Tag.AnimationFade)
	end
	setViewModelVisible(false)
end

local function clearViewModel()
	stopFirstPersonAnimation()
	if viewModelTrack ~= nil then
		viewModelTrack:Destroy()
		viewModelTrack = nil
	end
	if viewModel ~= nil then
		viewModel:Destroy()
		viewModel = nil
	end
	table.clear(viewModelArms)
	activeCharacter = nil
end

local function playFirstPersonAnimation()
	if CameraDirector.getViewMode() ~= "FirstPerson" then
		return
	end
	local track = viewModelTrack
	local model = viewModel
	local character = activeCharacter
	if track == nil or model == nil or character == nil then
		return
	end

	playGeneration += 1
	local generation = playGeneration
	if track.IsPlaying then
		track:Stop(0)
	end
	model:PivotTo(character:GetPivot())
	setViewModelVisible(true)
	track:Play(Config.Tag.AnimationFade, 1, 1)
	task.spawn(function()
		track.Stopped:Wait()
		if playGeneration == generation then
			setViewModelVisible(false)
		end
	end)
end

local function tryActivate(): boolean
	if not canTag() then
		return false
	end
	playFirstPersonAnimation()
	RequestTag:FireServer()
	return true
end

local function waitForArmRig(character: Model, generation: number): boolean
	local warnAt = os.clock() + 5
	local warned = false
	while buildGeneration == generation and localPlayer.Character == character do
		local missing: string? = nil
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil then
			missing = "Humanoid"
		elseif humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			warn("[TagController] First-person TAG animation requires an R15 character")
			return false
		elseif character:FindFirstChild("UpperTorso") == nil then
			missing = "UpperTorso"
		else
			for partName in ARM_NAMES do
				if character:FindFirstChild(partName) == nil then
					missing = partName
					break
				end
			end
			if missing == nil then
				for _, jointName in ARM_JOINT_NAMES do
					if character:FindFirstChild(jointName, true) == nil then
						missing = jointName
						break
					end
				end
			end
		end
		if missing == nil then
			return true
		end
		if not warned and os.clock() >= warnAt then
			warn("[TagController] Waiting for R15 TAG arm rig: missing " .. missing)
			warned = true
		end
		task.wait(0.1)
	end
	return false
end

local function buildViewModel(character: Model)
	buildGeneration += 1
	local generation = buildGeneration
	clearViewModel()
	if not waitForArmRig(character, generation) then
		return
	end

	local wasArchivable = character.Archivable
	character.Archivable = true
	local cloned, result = pcall(function(): Model?
		return character:Clone()
	end)
	character.Archivable = wasArchivable
	if not cloned or result == nil then
		warn("[TagController] Failed to clone the first-person TAG arm rig: " .. tostring(result))
		return
	end
	local clone = result :: Model
	clone.Name = VIEW_MODEL_NAME
	local cloneArms: { BasePart } = {}

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Humanoid")
			or descendant:IsA("AnimationController")
			or descendant:IsA("Animator")
			or descendant:IsA("Accessory")
		then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = descendant.Name == "HumanoidRootPart"
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
			descendant.Massless = true
			descendant.Transparency = 1
			if ARM_NAMES[descendant.Name] and descendant.Parent == clone then
				table.insert(cloneArms, descendant)
			end
		end
	end
	if #cloneArms ~= 6 then
		clone:Destroy()
		warn("[TagController] Cloned first-person TAG rig is missing arm parts")
		return
	end

	local animationController = Instance.new("AnimationController")
	animationController.Name = "HRUSH_FirstPersonTagAnimationController"
	local animator = Instance.new("Animator")
	animator.Parent = animationController
	animationController.Parent = clone
	clone:PivotTo(character:GetPivot())
	clone.Parent = Workspace

	local animation = Instance.new("Animation")
	animation.AnimationId = Config.Tag.FirstPersonAnimationId
	local ok, loaded = pcall(function(): AnimationTrack
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok then
		clone:Destroy()
		warn("[TagController] Failed to load first-person TAG animation "
			.. Config.Tag.FirstPersonAnimationId .. ": " .. tostring(loaded))
		return
	end
	loaded.Priority = Enum.AnimationPriority.Action4
	loaded.Looped = false
	if buildGeneration ~= generation or localPlayer.Character ~= character then
		loaded:Destroy()
		clone:Destroy()
		return
	end
	activeCharacter = character
	viewModel = clone
	viewModelTrack = loaded
	viewModelArms = cloneArms
	task.delay(5, function()
		if viewModelTrack == loaded and loaded.Length <= 0 then
			warn("[TagController] First-person TAG animation " .. Config.Tag.FirstPersonAnimationId
				.. " has not loaded; check experience access to this asset")
		end
	end)
end

local function updateTouchButton()
	local button = ContextActionService:GetButton(ACTION)
	if button == nil then
		lastTouchButton = nil
		return
	end
	local visible = canTag()
	if button.Visible ~= visible then button.Visible = visible end
	local mode = localPlayer:GetAttribute("HRushGameMode")
	local title = if mode == "AgawanNgPanyo" then "STEAL" else if mode == "SecretHunt" then "CAPTURE" else "TAG"
	if button ~= lastTouchButton or title ~= lastTouchTitle then
		ContextActionService:SetTitle(ACTION, title)
		lastTouchButton = button
		lastTouchTitle = title
	end
end

function TagController.tryActivate(): boolean
	return tryActivate()
end

function TagController.start()
	if running then
		return
	end
	running = true
	if localPlayer.Character ~= nil then
		task.spawn(buildViewModel, localPlayer.Character)
	end
	localPlayer.CharacterAdded:Connect(buildViewModel)
	localPlayer.CharacterRemoving:Connect(function()
		buildGeneration += 1
		clearViewModel()
	end)

	RunService.RenderStepped:Connect(function(dt)
		touchRefreshElapsed += dt
		if touchRefreshElapsed >= 0.1 then
			touchRefreshElapsed = 0
			if UserInputService.TouchEnabled then updateTouchButton() end
		end
		if not firstPersonPlaying then
			return
		end
		local model = viewModel
		local character = activeCharacter
		if model == nil or character == nil or character.Parent == nil
			or CameraDirector.getViewMode() ~= "FirstPerson"
		then
			stopFirstPersonAnimation()
			return
		end
		model:PivotTo(character:GetPivot())
	end)

	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState, input)
		if inputState ~= Enum.UserInputState.Begin
			or GuiService.MenuIsOpen
			or UserInputService:GetFocusedTextBox() ~= nil
		then
			return Enum.ContextActionResult.Pass
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pointer = UserInputService:GetMouseLocation()
			for _, object in localPlayer.PlayerGui:GetGuiObjectsAtPosition(pointer.X, pointer.Y) do
				if object:IsA("GuiButton") and object.Active then
					return Enum.ContextActionResult.Pass
				end
			end
		end
		return if tryActivate() then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
	end, true, Enum.ContextActionPriority.Default.Value, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION, "TAG")
	ContextActionService:SetPosition(ACTION, UDim2.fromScale(0.84, 0.72))

	for _, attribute in { "HRushInMatch", "HRushState", "HRushRole", "HRushGameMode", "HRushHuntTargetReady", "HRushStunned", "HRushAbilityBusy" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(updateTouchButton)
	end
	ReplicatedStorage:GetAttributeChangedSignal("HRushPanyoCarrierUserId"):Connect(updateTouchButton)
	task.defer(updateTouchButton)
end

return TagController
