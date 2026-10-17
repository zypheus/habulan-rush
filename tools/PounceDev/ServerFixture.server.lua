--!strict
-- tools/PounceDev/ServerFixture.server.lua
-- Owner: Project Owner
-- Responsibility: temporary real two-client match fixtures; not Rojo mapped.
-- Task/spec: Pounce / Tag acceptance, 2026-10-16.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local testService=game:GetService("StudioTestService")
local HttpService=game:GetService("HttpService")
local remote=Instance.new("RemoteFunction")
remote.Name="HRUSH_PounceFixture"; remote.Parent=RS
remote.OnServerInvoke=function(player: Player, command: string)
	if command=="die" and player.Character then player.Character:FindFirstChildOfClass("Humanoid").Health=0 end
	if command=="roundEnd" then player:SetAttribute("HRushState","MS_05") end
	return true
end
local results: {[string]: any}={}
local requests: {any}={}
RS.Remotes.RequestPounce.OnServerEvent:Connect(function(p,id)
	local c=p.Character
	if not c then return end
	local h=c:FindFirstChildOfClass("Humanoid") :: Humanoid
	local r=c.HumanoidRootPart :: BasePart
	local par=RaycastParams.new(); par.FilterDescendantsInstances={c}; par.FilterType=Enum.RaycastFilterType.Exclude; par.RespectCanCollide=true
	local ray=workspace:Raycast(r.Position,Vector3.new(0,-20,0),par)
	if typeof(id)=="number" and id==id then table.insert(requests,{id=id,hip=h.HipHeight,y=r.Position.Y,ground=ray and ray.Distance,vy=r.AssemblyLinearVelocity.Y,move=p:GetAttribute("HRushMovementState")}) end
end)
local finished=false
local function finish()
	if finished then return end
	finished=true
	print("[PounceFixture] "..HttpService:JSONEncode(results))
	testService:EndTest(results)
end
task.delay(180,function() results.timeout=true; finish() end)
local function root(p: Instance): BasePart
	local character=if p:IsA("Player") then p.Character else p
	return (character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
end
local function position(p: Player, at: Vector3, anchored: boolean)
	local r=root(p)
	r.Anchored=anchored
	r.CFrame=CFrame.lookAt(at,at+Vector3.xAxis)
	r.AssemblyLinearVelocity=Vector3.zero
	r.AssemblyAngularVelocity=Vector3.zero
end
local ok,err=pcall(function()
	repeat task.wait(0.25) until #Players:GetPlayers()==2
	local players=Players:GetPlayers()
	for _, p in players do repeat task.wait(0.1) until p.Character and root(p) end
	task.wait(4)
	for _, p in players do remote:InvokeClient(p,"queue") end
	repeat task.wait(0.25) until players[1]:GetAttribute("HRushState")=="MS_04"
	local floor=Instance.new("Part")
	floor.Name="HRUSH_PounceFixtureFloor"; floor.Anchored=true; floor.Size=Vector3.new(1000,2,1000); floor.Position=Vector3.new(0,300,0); floor.Parent=workspace
	for i,p in players do position(p,Vector3.new(i*80,304,0),false) end
	local bots=workspace:FindFirstChild("Bots")
	if bots then
		for i,bot in bots:GetChildren() do
			local r=root(bot)
			if bot:GetAttribute("HRushRole")=="Taya" then
				r.CFrame=root(players[1]).CFrame
				task.wait(0.4)
			end
			r.Anchored=true; r.CFrame=CFrame.new(300,304,i*15)
		end
	end
	local function taya(): Player
		for _,p in players do if p:GetAttribute("HRushRole")=="Taya" then return p end end
		error("No real-player Taya after setup")
	end
	local function scenario(name: string, offset: Vector3, option: string?)
		requests={}
		for _,p in players do remote:InvokeClient(p,"stop") end
		for i,p in players do position(p,Vector3.new(-100*i,304,100),true) end
		task.wait(0.3)
		local actor=taya()
		local target=if players[1]==actor then players[2] else players[1]
		position(actor,Vector3.new(-20,304,0),false)
		position(target,Vector3.new(0,304,0)+offset,true)
		task.wait(2.4)
		local result=remote:InvokeClient(actor,"run",option)
		result.serverState=actor:GetAttribute("HRushPounceState")
		result.requests=requests
		result.serverBusy=actor:GetAttribute("HRushPouncing")
		result.actorRole=actor:GetAttribute("HRushRole")
		result.targetRole=target:GetAttribute("HRushRole")
		result.observerEvents=remote:InvokeClient(target,"events")
		results[name]=result
		print("[PounceFixture] "..name.." "..HttpService:JSONEncode(result))
		assert(result.activated,name..": activation failed")
		assert(result.overlaps==0 and result.busy==false and result.serverBusy==false,name..": incomplete cleanup or overlapping attempt")
		assert(result.leftover==0,name..": leftover pounce trails")
		local hits=0
		for _, event in result.events do if event.kind=="Hit" then hits+=1 end end
		assert(hits<=1,name..": duplicate hit")
		if name=="hit" or name=="repeatHit" then
			assert(hits==1 and result.tracks["rbxassetid://88403484239291"],name..": missing confirmed Tag animation")
			assert(result.sprinting,name..": held sprint did not resume")
		else
			assert(hits==0 and not result.tracks["rbxassetid://88403484239291"],name..": unexpected tag")
		end
		return actor,target
	end
	results.stationary=remote:InvokeClient(taya(),"probe")
	local actor=scenario("miss",Vector3.new(0,0,50))
	remote:InvokeClient(actor,"abuse")
	results.abuseState=actor:GetAttribute("HRushPounceState")
	scenario("hit",Vector3.zero)
	scenario("repeatHit",Vector3.zero)
	scenario("side",Vector3.new(-12,0,7))
	local wall=Instance.new("Part")
	wall.Name="HRUSH_PounceFixtureWall"; wall.Anchored=true; wall.Size=Vector3.new(1,18,30); wall.Position=Vector3.new(-4,309,0); wall.Parent=workspace
	scenario("wall",Vector3.zero)
	wall:Destroy()
	scenario("releasedSprint",Vector3.new(0,0,50),"release")
	scenario("teleport",Vector3.new(0,0,50),"teleport")
	scenario("roundEnd",Vector3.new(0,0,50),"roundEnd")
	-- Restore the client-only cancellation fixture using the real state remote.
	for _,p in players do p:SetAttribute("HRushState","MS_04");remote:InvokeClient(p,"restoreRound"); RS.Remotes.StateChanged:FireClient(p,{state="MS_04",role=p:GetAttribute("HRushRole")}) end
	local dead=scenario("death",Vector3.new(0,0,50),"death")
	dead:LoadCharacterAsync()
	task.wait(1)
	scenario("respawn",Vector3.new(0,0,50))
	results.freshCooldownRequest=remote:InvokeClient(taya(),"freshCooldown")
	assert(results.freshCooldownRequest.denied,"fresh request bypassed cooldown")
end)
if not ok then results.error=tostring(err) end
finish()
