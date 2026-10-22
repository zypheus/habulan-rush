--!strict
-- StarterPlayerScripts/TagController.lua
-- Owner: Project Owner
-- Responsibility: click, R2, and touch tag input plus isolated first-person animation playback.
-- Task/spec: repair the character animation conflict in simple click tagging, approved 2026-10-18.
-- Task/spec: Agawan ng Panyo steal input, approved 2026-10-23.
-- Task/spec: Panyo mobile STEAL button recovery, approved 2026-10-23.

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

local running = false
local activeCharacter: Model? = nil
local viewModel: Model? = nil
local viewModelTrack: AnimationTrack? = nil
local viewModelArms: { BasePart } = {}
local hiddenCharacterArms: { [BasePart]: number } = {}
local firstPersonPlaying = false
local playGeneration = 0
local touchRefreshElapsed = 0
local lastTouchButton: Instance? = nil
local lastTouchTitle = ""

local function canTag(): boolean
	local isPanyo = localPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo"
	local carrierId = ReplicatedStorage:GetAttribute("HRushPanyoCarrierUserId")
	return localPlayer:GetAttribute("HRushInMatch") == true
		and localPlayer:GetAttribute("HRushState") == "MS_04"
		and (if isPanyo then typeof(carrierId) == "number" and carrierId ~= localPlayer.UserId else localPlayer:GetAttribute("HRushRole") == "Taya")
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

local function buildViewModel(character: Model)
	clearViewModel()
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid == nil or not humanoid:IsA("Humanoid") or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone() :: Model
	character.Archivable = wasArchivable
	clone.Name = VIEW_MODEL_NAME

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
			if ARM_NAMES[descendant.Name] then
				table.insert(viewModelArms, descendant)
			end
		end
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
		table.clear(viewModelArms)
		warn("[TagController] Failed to load the first-person tag animation")
		return
	end
	loaded.Priority = Enum.AnimationPriority.Action4
	loaded.Looped = false
	activeCharacter = character
	viewModel = clone
	viewModelTrack = loaded
end

local function updateTouchButton()
	local button = ContextActionService:GetButton(ACTION)
	if button == nil then
		lastTouchButton = nil
		return
	end
	local visible = canTag()
	if button.Visible ~= visible then button.Visible = visible end
	local title = if localPlayer:GetAttribute("HRushGameMode") == "AgawanNgPanyo" then "STEAL" else "TAG"
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

	for _, attribute in { "HRushInMatch", "HRushState", "HRushRole", "HRushGameMode", "HRushStunned", "HRushAbilityBusy" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(updateTouchButton)
	end
	ReplicatedStorage:GetAttributeChangedSignal("HRushPanyoCarrierUserId"):Connect(updateTouchButton)
	task.defer(updateTouchButton)
end

return TagController
