--!strict
-- tools/PounceDev/ClientFixture.client.lua
-- Owner: Project Owner
-- Responsibility: temporary Studio multiplayer pounce measurements; not Rojo mapped.
-- Task/spec: Pounce / Tag acceptance, 2026-10-16.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
for _, name in { "MobileSprintBegan", "MobileSprintEnded" } do
	if not RS:FindFirstChild(name) then
		local event = Instance.new("BindableEvent")
		event.Name = name
		event.Parent = RS
	end
end
local remote = RS:WaitForChild("HRUSH_PounceFixture") :: RemoteFunction
local controller = require(player.PlayerScripts:WaitForChild("PounceController"))
local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
controls:Disable()
local moving = false
local samples: {any} = {}
local events: {any} = {}
local states: {string} = {}
local tracks: {[string]: boolean} = {}
local peakSpeed, peakFov = 0, 0
local origin: Vector3? = nil
local maxRise = 0
local remotes = RS:WaitForChild("Remotes")
remotes.PounceEvent.OnClientEvent:Connect(function(payload)
	table.insert(events, {kind=payload.kind, actor=payload.actorId, id=payload.id, readyIn=payload.readyIn})
end)
player:GetAttributeChangedSignal("HRushLocalPounceState"):Connect(function()
	table.insert(states, player:GetAttribute("HRushLocalPounceState"))
end)
RunService:BindToRenderStep("HRUSH_PounceFixtureMove", Enum.RenderPriority.Input.Value + 1, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:Move(if moving then Vector3.xAxis else Vector3.zero, false) end
end)
RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and origin then
		local v=root.AssemblyLinearVelocity
		peakSpeed=math.max(peakSpeed,Vector3.new(v.X,0,v.Z).Magnitude)
		maxRise=math.max(maxRise,root.Position.Y-origin.Y)
		peakFov=math.max(peakFov,workspace.CurrentCamera.FieldOfView)
		for _, track in humanoid:GetPlayingAnimationTracks() do tracks[track.Animation.AnimationId]=true end
	end
end)
local function sprint(value: boolean)
	moving = value
	local event = RS:FindFirstChild(if value then "MobileSprintBegan" else "MobileSprintEnded") :: BindableEvent
	event:Fire()
end
remote.OnClientInvoke = function(command: string, argument: any)
	if command == "queue" then remotes.QueueEvent:FireServer("Play"); return true end
	if command == "stop" then sprint(false); return true end
	if command == "restoreRound" then player:SetAttribute("HRushState","MS_04"); return true end
	if command == "probe" then return {accepted=controller.tryActivate(),state=player:GetAttribute("HRushLocalPounceState")} end
	if command == "run" then
		events={}; states={}; tracks={}; peakSpeed=0; peakFov=0; maxRise=0
		local character=player.Character :: Model
		local root=character:WaitForChild("HumanoidRootPart") :: BasePart
		local humanoid=character:WaitForChild("Humanoid") :: Humanoid
		sprint(true)
		task.wait(0.4)
		origin=root.Position
		local before={sprint=player:GetAttribute("HRushSprinting"),state=player:GetAttribute("HRushLocalPounceState"),floor=humanoid.FloorMaterial.Name,speed=root.AssemblyLinearVelocity.Magnitude,role=player:GetAttribute("HRushRole")}
		local baseline=workspace.CurrentCamera.FieldOfView
		local activated=controller.tryActivate()
		local overlaps=0
		for _=1,20 do if controller.tryActivate() then overlaps+=1 end end
		if argument=="teleport" then task.delay(0.11,function() root.CFrame+=Vector3.new(100,0,0) end) end
		if argument=="death" then task.delay(0.11,function() remote:InvokeServer("die") end) end
		if argument=="release" then task.delay(0.1,function() sprint(false) end) end
		if argument=="roundEnd" then task.delay(0.11,function() remote:InvokeServer("roundEnd") end) end
		task.wait(1.15)
		local leftover=0
		for _, object in character:GetDescendants() do if string.find(object.Name,"HRUSH_Pounce") then leftover+=1 end end
		local result={activated=activated,overlaps=overlaps,before=before,events=events,states=states,tracks=tracks,
			peakSpeed=peakSpeed,maxRise=maxRise,peakFov=peakFov,baseline=baseline,fov=workspace.CurrentCamera.FieldOfView,
			busy=player:GetAttribute("HRushLocalPouncing"),state=player:GetAttribute("HRushLocalPounceState"),
			cooldown=player:GetAttribute("HRushPounceCD"),sprinting=player:GetAttribute("HRushSprinting"),walkSpeed=humanoid.WalkSpeed,
			autoRotate=humanoid.AutoRotate,jumpEnabled=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),leftover=leftover}
		origin=nil
		sprint(false)
		return result
	end
	if command=="abuse" then
		local id=player:GetAttribute("HRushPounceId") or 0
		for _=1,30 do remotes.RequestPounce:FireServer(id) end
		task.wait(0.1); remotes.RequestPounce:FireServer(0/0)
		task.wait(0.1); remotes.RequestPounce:FireServer({hit=player.UserId})
		task.wait(0.1); remotes.RequestPounce:FireServer(id-1)
		return true
	end
	if command=="events" then return events end
	if command=="freshCooldown" then
		events={}
		remotes.RequestPounce:FireServer((player:GetAttribute("HRushPounceId") or 0)+1)
		task.wait(0.3)
		local denied=false
		for _,event in events do if event.kind=="Denied" then denied=true end end
		return {denied=denied,events=events}
	end
	return false
end
player:SetAttribute("HRUSH_FixtureReady",true)
