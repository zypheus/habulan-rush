--!strict
--[[
	HABULAN RUSH - Map Vote UI
	Place in: StarterPlayer > StarterPlayerScripts > MapVoteUI (LocalScript)

	Displays the "VOTE FOR MAP" screen between match found and arena spawn.
	Matches reference mock-up:
	  * Top: HABULAN RUSH logo, MATCH FOUND pill, VOTE FOR MAP title, circular timer
	  * Center: Side-by-side map cards with overhead preview, LEADING/TIE badges,
	            voter avatar chips, vote tally, tagline, event tags, and VOTE button
	  * Bottom: 8 participant roster chips (BOT badge on bots), VOTED X/8 counter,
	            ping/region indicator
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MapVoteEvent = Remotes:WaitForChild("MapVoteEvent") :: RemoteEvent

local Config = require(ReplicatedStorage:WaitForChild("Config"))

local COLORS = {
	Lime = Color3.fromRGB(221, 247, 100),
	LimeLight = Color3.fromRGB(236, 255, 130),
	LimeDark = Color3.fromRGB(152, 180, 40),
	Navy = Color3.fromRGB(20, 32, 40),
	NavyDeep = Color3.fromRGB(13, 22, 28),
	Slate = Color3.fromRGB(44, 66, 76),
	SlateDark = Color3.fromRGB(30, 48, 56),
	SlateLight = Color3.fromRGB(75, 102, 114),
	CardBg = Color3.fromRGB(36, 56, 66),
	CardBgSelected = Color3.fromRGB(45, 72, 85),
	White = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(160, 182, 190),
	TextDark = Color3.fromRGB(22, 34, 42),
	Gold = Color3.fromRGB(246, 190, 50),
	Orange = Color3.fromRGB(238, 152, 88),
	Cyan = Color3.fromRGB(110, 225, 240),
	BlueWater = Color3.fromRGB(40, 100, 140),
	CourtBrown = Color3.fromRGB(140, 95, 60),
	CourtGreen = Color3.fromRGB(50, 100, 60),
}

local FONTS = {
	HeavyItalic = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	Heavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
	Bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	SemiBold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
	Display = Font.fromEnum(Enum.Font.Oswald),
}

local INFO_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(obj: Instance, info: TweenInfo, goal: { [string]: any })
	local t = TweenService:Create(obj, info, goal)
	t:Play()
	return t
end

local function corner(parent: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- ============================================================
-- GUI ROOT
-- ============================================================
local oldGui = PlayerGui:FindFirstChild("MapVoteUI")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MapVoteUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 60
screenGui.Enabled = false
screenGui.Parent = PlayerGui

local rootCanvas = Instance.new("CanvasGroup")
rootCanvas.Name = "RootCanvas"
rootCanvas.Size = UDim2.fromScale(1, 1)
rootCanvas.BackgroundColor3 = COLORS.NavyDeep
rootCanvas.BorderSizePixel = 0
rootCanvas.GroupTransparency = 1
rootCanvas.Parent = screenGui

local bgGrad = Instance.new("UIGradient")
bgGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, COLORS.SlateDark),
	ColorSequenceKeypoint.new(0.5, COLORS.NavyDeep),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 16, 20)),
})
bgGrad.Rotation = 90
bgGrad.Parent = rootCanvas

-- Responsive container
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.fromOffset(1024, 580)
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.fromScale(0.5, 0.5)
container.BackgroundTransparency = 1
container.Parent = rootCanvas

local containerScale = Instance.new("UIScale")
containerScale.Parent = container

local function updateScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1024, 580)
	local s = math.min(vp.X / 1060, vp.Y / 600)
	containerScale.Scale = math.clamp(s, 0.45, 1.4)
end
updateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- ============================================================
-- TOP BAR
-- ============================================================
-- Top Left: Logo + Location
local logoFrame = Instance.new("Frame")
logoFrame.Name = "LogoFrame"
logoFrame.Position = UDim2.fromOffset(24, 20)
logoFrame.Size = UDim2.fromOffset(220, 60)
logoFrame.BackgroundTransparency = 1
logoFrame.Parent = container

local logoLabel = Instance.new("TextLabel")
logoLabel.Size = UDim2.fromOffset(220, 28)
logoLabel.BackgroundTransparency = 1
logoLabel.Text = 'HABULAN <font color="#DDF764">RUSH »</font>'
logoLabel.RichText = true
logoLabel.FontFace = FONTS.HeavyItalic
logoLabel.TextSize = 22
logoLabel.TextColor3 = COLORS.White
logoLabel.TextXAlignment = Enum.TextXAlignment.Left
logoLabel.Parent = logoFrame

local subLogo = Instance.new("TextLabel")
subLogo.Position = UDim2.fromOffset(0, 30)
subLogo.Size = UDim2.fromOffset(220, 16)
subLogo.BackgroundTransparency = 1
subLogo.Text = '<font color="#DDF764">●</font> BARANGAY MALIGAYA <font color="#7a929b">/ MATCHMAKING</font>'
subLogo.RichText = true
subLogo.FontFace = FONTS.Heavy
subLogo.TextSize = 10
subLogo.TextColor3 = COLORS.TextDim
subLogo.TextXAlignment = Enum.TextXAlignment.Left
subLogo.Parent = logoFrame

-- Top Center: MATCH FOUND pill + VOTE FOR MAP title
local headerFrame = Instance.new("Frame")
headerFrame.Name = "HeaderFrame"
headerFrame.AnchorPoint = Vector2.new(0.5, 0)
headerFrame.Position = UDim2.fromOffset(512, 16)
headerFrame.Size = UDim2.fromOffset(360, 80)
headerFrame.BackgroundTransparency = 1
headerFrame.Parent = container

local matchFoundPill = Instance.new("Frame")
matchFoundPill.Name = "MatchFoundPill"
matchFoundPill.AnchorPoint = Vector2.new(0.5, 0)
matchFoundPill.Position = UDim2.fromOffset(180, 0)
matchFoundPill.Size = UDim2.fromOffset(130, 22)
matchFoundPill.BackgroundColor3 = COLORS.SlateDark
matchFoundPill.Parent = headerFrame
corner(matchFoundPill, 11)
stroke(matchFoundPill, COLORS.Lime, 1)

local pillText = Instance.new("TextLabel")
pillText.Size = UDim2.fromScale(1, 1)
pillText.BackgroundTransparency = 1
pillText.Text = "✓ MATCH FOUND"
pillText.FontFace = FONTS.Heavy
pillText.TextSize = 11
pillText.TextColor3 = COLORS.Lime
pillText.Parent = matchFoundPill

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Position = UDim2.fromOffset(0, 26)
titleLabel.Size = UDim2.fromOffset(360, 34)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "VOTE FOR MAP"
titleLabel.FontFace = FONTS.Display
titleLabel.TextSize = 34
titleLabel.TextColor3 = COLORS.White
titleLabel.Parent = headerFrame

local subTitleLabel = Instance.new("TextLabel")
subTitleLabel.Name = "SubTitleLabel"
subTitleLabel.Position = UDim2.fromOffset(0, 60)
subTitleLabel.Size = UDim2.fromOffset(360, 16)
subTitleLabel.BackgroundTransparency = 1
subTitleLabel.Text = "Most votes wins. Tie = random."
subTitleLabel.FontFace = FONTS.SemiBold
subTitleLabel.TextSize = 12
subTitleLabel.TextColor3 = COLORS.TextDim
subTitleLabel.Parent = headerFrame

-- Top Right: Circular Timer
local timerFrame = Instance.new("Frame")
timerFrame.Name = "TimerFrame"
timerFrame.AnchorPoint = Vector2.new(1, 0)
timerFrame.Position = UDim2.fromOffset(1000, 18)
timerFrame.Size = UDim2.fromOffset(120, 64)
timerFrame.BackgroundTransparency = 1
timerFrame.Parent = container

local circleBox = Instance.new("Frame")
circleBox.Position = UDim2.fromOffset(60, 4)
circleBox.Size = UDim2.fromOffset(52, 52)
circleBox.BackgroundColor3 = COLORS.SlateDark
circleBox.Parent = timerFrame
corner(circleBox, 26)
local circleStroke = stroke(circleBox, COLORS.Lime, 2.5)

local timerNum = Instance.new("TextLabel")
timerNum.Size = UDim2.fromScale(1, 1)
timerNum.BackgroundTransparency = 1
timerNum.Text = "10"
timerNum.FontFace = FONTS.Display
timerNum.TextSize = 28
timerNum.TextColor3 = COLORS.Lime
timerNum.Parent = circleBox

local timerLabel = Instance.new("TextLabel")
timerLabel.Position = UDim2.fromOffset(0, 14)
timerLabel.Size = UDim2.fromOffset(54, 30)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "VOTING\nENDS"
timerLabel.FontFace = FONTS.Heavy
timerLabel.TextSize = 10
timerLabel.TextColor3 = COLORS.TextDim
timerLabel.TextXAlignment = Enum.TextXAlignment.Right
timerLabel.Parent = timerFrame

-- ============================================================
-- MAP CARDS (CENTER)
-- ============================================================
local cardsHolder = Instance.new("Frame")
cardsHolder.Name = "CardsHolder"
cardsHolder.Position = UDim2.fromOffset(24, 106)
cardsHolder.Size = UDim2.fromOffset(976, 374)
cardsHolder.BackgroundTransparency = 1
cardsHolder.Parent = container

type MapCardUI = {
	Card: Frame,
	Key: string,
	Stroke: UIStroke,
	Badge: Frame,
	BadgeText: TextLabel,
	VoteCountLabel: TextLabel,
	VoteBtn: TextButton,
	VotersFrame: Frame,
	TitleLabel: TextLabel,
	TaglineLabel: TextLabel,
	EventTag: TextLabel,
}

local mapCards: { [string]: MapCardUI } = {}
local myVote: string? = nil

local function createMapCard(x: number, key: string, name: string, tagline: string, eventName: string, isCourt: boolean): MapCardUI
	local card = Instance.new("Frame")
	card.Name = "Card_" .. key
	card.Position = UDim2.fromOffset(x, 0)
	card.Size = UDim2.fromOffset(472, 374)
	card.BackgroundColor3 = COLORS.CardBg
	card.Parent = cardsHolder
	corner(card, 16)
	local cStroke = stroke(card, COLORS.SlateLight, 1.5, 0.5)

	-- Upper Banner Preview
	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.Position = UDim2.fromOffset(12, 12)
	preview.Size = UDim2.fromOffset(448, 148)
	preview.BackgroundColor3 = isCourt and COLORS.CourtGreen or COLORS.BlueWater
	preview.ClipsDescendants = true
	preview.Parent = card
	corner(preview, 12)

	-- Stylized overhead court/street lines inside preview
	if isCourt then
		-- Basketball court outline
		local courtRect = Instance.new("Frame")
		courtRect.AnchorPoint = Vector2.new(0.5, 0.5)
		courtRect.Position = UDim2.fromScale(0.5, 0.5)
		courtRect.Size = UDim2.fromOffset(280, 110)
		courtRect.BackgroundColor3 = COLORS.CourtBrown
		courtRect.Parent = preview
		corner(courtRect, 6)
		stroke(courtRect, Color3.fromRGB(255, 230, 180), 1.5, 0.4)

		local midLine = Instance.new("Frame")
		midLine.AnchorPoint = Vector2.new(0.5, 0)
		midLine.Position = UDim2.fromScale(0.5, 0)
		midLine.Size = UDim2.new(0, 2, 1, 0)
		midLine.BackgroundColor3 = Color3.fromRGB(255, 230, 180)
		midLine.BackgroundTransparency = 0.4
		midLine.BorderSizePixel = 0
		midLine.Parent = courtRect

		local centerCircle = Instance.new("Frame")
		centerCircle.AnchorPoint = Vector2.new(0.5, 0.5)
		centerCircle.Position = UDim2.fromScale(0.5, 0.5)
		centerCircle.Size = UDim2.fromOffset(40, 40)
		centerCircle.BackgroundTransparency = 1
		centerCircle.Parent = courtRect
		corner(centerCircle, 20)
		stroke(centerCircle, Color3.fromRGB(255, 230, 180), 1.5, 0.4)
	else
		-- Water flood waves & rooftops
		local flood = Instance.new("Frame")
		flood.Size = UDim2.fromScale(1, 1)
		flood.BackgroundColor3 = Color3.fromRGB(28, 70, 95)
		flood.Parent = preview
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(Color3.fromRGB(45, 120, 160), Color3.fromRGB(20, 50, 70))
		grad.Rotation = 45
		grad.Parent = flood

		-- Floating platforms / rooftops
		for i = 1, 3 do
			local roof = Instance.new("Frame")
			roof.Position = UDim2.fromOffset(40 + (i - 1) * 130, 30 + (i % 2) * 25)
			roof.Size = UDim2.fromOffset(90, 55)
			roof.BackgroundColor3 = Color3.fromRGB(150, 90, 70)
			roof.Parent = flood
			corner(roof, 4)
			stroke(roof, Color3.fromRGB(180, 120, 90), 1)
		end
	end

	-- Badge (top-right of preview): LEADING / TIE / WINNER
	local badge = Instance.new("Frame")
	badge.Name = "StatusBadge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.fromOffset(436, 20)
	badge.Size = UDim2.fromOffset(80, 24)
	badge.BackgroundColor3 = COLORS.Lime
	badge.Visible = false
	badge.Parent = card
	corner(badge, 12)

	local badgeText = Instance.new("TextLabel")
	badgeText.Size = UDim2.fromScale(1, 1)
	badgeText.BackgroundTransparency = 1
	badgeText.Text = "LEADING"
	badgeText.FontFace = FONTS.Heavy
	badgeText.TextSize = 11
	badgeText.TextColor3 = COLORS.TextDark
	badgeText.Parent = badge

	-- Voter avatar chips container (row of circular chips)
	local votersFrame = Instance.new("Frame")
	votersFrame.Name = "VotersFrame"
	votersFrame.Position = UDim2.fromOffset(20, 120)
	votersFrame.Size = UDim2.fromOffset(260, 32)
	votersFrame.BackgroundTransparency = 1
	votersFrame.Parent = card

	local votersLayout = Instance.new("UIListLayout")
	votersLayout.FillDirection = Enum.FillDirection.Horizontal
	votersLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	votersLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	votersLayout.Padding = UDim.new(0, -6) -- overlapping chips
	votersLayout.Parent = votersFrame

	-- Vote Count display (Right of voters)
	local voteCountBox = Instance.new("Frame")
	voteCountBox.AnchorPoint = Vector2.new(1, 1)
	voteCountBox.Position = UDim2.fromOffset(448, 150)
	voteCountBox.Size = UDim2.fromOffset(80, 36)
	voteCountBox.BackgroundTransparency = 1
	voteCountBox.Parent = card

	local voteCountLabel = Instance.new("TextLabel")
	voteCountLabel.Size = UDim2.fromOffset(44, 36)
	voteCountLabel.BackgroundTransparency = 1
	voteCountLabel.Text = "0"
	voteCountLabel.FontFace = FONTS.Display
	voteCountLabel.TextSize = 36
	voteCountLabel.TextColor3 = COLORS.White
	voteCountLabel.TextXAlignment = Enum.TextXAlignment.Right
	voteCountLabel.Parent = voteCountBox

	local votesSubLabel = Instance.new("TextLabel")
	votesSubLabel.Position = UDim2.fromOffset(48, 14)
	votesSubLabel.Size = UDim2.fromOffset(32, 16)
	votesSubLabel.BackgroundTransparency = 1
	votesSubLabel.Text = "VOTES"
	votesSubLabel.FontFace = FONTS.Heavy
	votesSubLabel.TextSize = 10
	votesSubLabel.TextColor3 = COLORS.TextDim
	votesSubLabel.TextXAlignment = Enum.TextXAlignment.Left
	votesSubLabel.Parent = voteCountBox

	-- Map Title & Tagline
	local title = Instance.new("TextLabel")
	title.Name = "MapTitle"
	title.Position = UDim2.fromOffset(20, 168)
	title.Size = UDim2.fromOffset(430, 26)
	title.BackgroundTransparency = 1
	title.Text = string.upper(name)
	title.FontFace = FONTS.Display
	title.TextSize = 26
	title.TextColor3 = COLORS.White
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local tag = Instance.new("TextLabel")
	tag.Name = "MapTagline"
	tag.Position = UDim2.fromOffset(20, 196)
	tag.Size = UDim2.fromOffset(430, 16)
	tag.BackgroundTransparency = 1
	tag.Text = tagline
	tag.FontFace = FONTS.SemiBold
	tag.TextSize = 12
	tag.TextColor3 = COLORS.TextDim
	tag.TextXAlignment = Enum.TextXAlignment.Left
	tag.Parent = card

	-- Metadata Chips (EVENT · ..., 4v4, SIZE)
	local metaRow = Instance.new("Frame")
	metaRow.Position = UDim2.fromOffset(20, 222)
	metaRow.Size = UDim2.fromOffset(430, 26)
	metaRow.BackgroundTransparency = 1
	metaRow.Parent = card

	local function makeChip(x: number, text: string, isHighlight: boolean): (Frame, TextLabel)
		local chip = Instance.new("Frame")
		chip.Position = UDim2.fromOffset(x, 0)
		chip.Size = UDim2.fromOffset(#text * 7 + 18, 22)
		chip.BackgroundColor3 = isHighlight and COLORS.SlateDark or COLORS.Slate
		chip.Parent = metaRow
		corner(chip, 6)
		stroke(chip, isHighlight and COLORS.Lime or COLORS.SlateLight, 1, isHighlight and 0.2 or 0.6)

		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = text
		l.FontFace = FONTS.Heavy
		l.TextSize = 10
		l.TextColor3 = isHighlight and COLORS.Lime or COLORS.TextDim
		l.Parent = chip
		return chip, l
	end

	local evChip, evLabel = makeChip(0, eventName, true)
	local pChip = makeChip(evChip.Size.X.Offset + 8, "4V4", false)
	makeChip(evChip.Size.X.Offset + pChip.Size.X.Offset + 16, isCourt and "MEDIUM" or "OPEN", false)

	-- Full Width VOTE Button
	local voteHolder = Instance.new("Frame")
	voteHolder.Position = UDim2.fromOffset(20, 264)
	voteHolder.Size = UDim2.fromOffset(432, 54)
	voteHolder.BackgroundTransparency = 1
	voteHolder.Parent = card

	corner(Instance.new("Frame", voteHolder), 14) -- shadow
	local voteBtn = Instance.new("TextButton")
	voteBtn.Name = "VoteButton"
	voteBtn.Size = UDim2.fromScale(1, 1)
	voteBtn.BackgroundColor3 = COLORS.Lime
	voteBtn.Text = "VOTE"
	voteBtn.FontFace = FONTS.Display
	voteBtn.TextSize = 26
	voteBtn.TextColor3 = COLORS.TextDark
	voteBtn.AutoButtonColor = false
	voteBtn.Parent = voteHolder
	corner(voteBtn, 14)
	stroke(voteBtn, COLORS.LimeLight, 1.5, 0.4)

	local btnScale = Instance.new("UIScale")
	btnScale.Parent = voteHolder

	voteBtn.MouseEnter:Connect(function()
		tween(btnScale, INFO_FAST, { Scale = 1.02 })
	end)
	voteBtn.MouseLeave:Connect(function()
		tween(btnScale, INFO_FAST, { Scale = 1.0 })
	end)
	voteBtn.MouseButton1Down:Connect(function()
		tween(btnScale, INFO_FAST, { Scale = 0.96 })
	end)
	voteBtn.MouseButton1Up:Connect(function()
		tween(btnScale, INFO_FAST, { Scale = 1.0 })
	end)
	voteBtn.Activated:Connect(function()
		myVote = key
		MapVoteEvent:FireServer("Vote", key)
		-- Local immediate feedback
		voteBtn.Text = "✓ VOTED"
		voteBtn.BackgroundColor3 = COLORS.Lime
		voteBtn.TextColor3 = COLORS.TextDark
		cStroke.Color = COLORS.Lime
		cStroke.Transparency = 0
		card.BackgroundColor3 = COLORS.CardBgSelected
	end)

	local cardObj: MapCardUI = {
		Card = card,
		Key = key,
		Stroke = cStroke,
		Badge = badge,
		BadgeText = badgeText,
		VoteCountLabel = voteCountLabel,
		VoteBtn = voteBtn,
		VotersFrame = votersFrame,
		TitleLabel = title,
		TaglineLabel = tag,
		EventTag = evLabel,
	}
	mapCards[key] = cardObj
	return cardObj
end

-- ============================================================
-- BOTTOM BAR (Roster Chips + Status + Ping)
-- ============================================================
local bottomFrame = Instance.new("Frame")
bottomFrame.Name = "BottomFrame"
bottomFrame.Position = UDim2.fromOffset(24, 492)
bottomFrame.Size = UDim2.fromOffset(976, 70)
bottomFrame.BackgroundTransparency = 1
bottomFrame.Parent = container

-- Left: [SELECT] ENTER VOTE hint
local selectHint = Instance.new("Frame")
selectHint.Position = UDim2.fromOffset(0, 16)
selectHint.Size = UDim2.fromOffset(140, 32)
selectHint.BackgroundColor3 = COLORS.SlateDark
selectHint.Parent = bottomFrame
corner(selectHint, 8)
stroke(selectHint, COLORS.SlateLight, 1, 0.6)

local selectText = Instance.new("TextLabel")
selectText.Size = UDim2.fromScale(1, 1)
selectText.BackgroundTransparency = 1
selectText.Text = '<font color="#DDF764">[SELECT]</font> ENTER VOTE'
selectText.RichText = true
selectText.FontFace = FONTS.Heavy
selectText.TextSize = 11
selectText.TextColor3 = COLORS.White
selectText.Parent = selectHint

-- Center: Participant Roster Chips + Counter
local rosterCenter = Instance.new("Frame")
rosterCenter.AnchorPoint = Vector2.new(0.5, 0)
rosterCenter.Position = UDim2.fromOffset(488, 4)
rosterCenter.Size = UDim2.fromOffset(420, 60)
rosterCenter.BackgroundTransparency = 1
rosterCenter.Parent = bottomFrame

local votedCounterLabel = Instance.new("TextLabel")
votedCounterLabel.Name = "VotedCounter"
votedCounterLabel.Size = UDim2.fromOffset(420, 16)
votedCounterLabel.BackgroundTransparency = 1
votedCounterLabel.Text = "VOTED 0/8"
votedCounterLabel.FontFace = FONTS.Heavy
votedCounterLabel.TextSize = 11
votedCounterLabel.TextColor3 = COLORS.Lime
votedCounterLabel.Parent = rosterCenter

local chipsContainer = Instance.new("Frame")
chipsContainer.Name = "ChipsContainer"
chipsContainer.Position = UDim2.fromOffset(0, 20)
chipsContainer.Size = UDim2.fromOffset(420, 36)
chipsContainer.BackgroundTransparency = 1
chipsContainer.Parent = rosterCenter

local chipsLayout = Instance.new("UIListLayout")
chipsLayout.FillDirection = Enum.FillDirection.Horizontal
chipsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
chipsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
chipsLayout.Padding = UDim.new(0, 8)
chipsLayout.Parent = chipsContainer

-- Right: Settings & Ping indicator
local rightInfo = Instance.new("Frame")
rightInfo.AnchorPoint = Vector2.new(1, 0)
rightInfo.Position = UDim2.fromOffset(976, 16)
rightInfo.Size = UDim2.fromOffset(180, 32)
rightInfo.BackgroundTransparency = 1
rightInfo.Parent = bottomFrame

local pingLabel = Instance.new("TextLabel")
pingLabel.Size = UDim2.fromScale(1, 1)
pingLabel.BackgroundTransparency = 1
pingLabel.Text = '<font color="#DDF764">●</font> PHILIPPINES · 22 MS'
pingLabel.RichText = true
pingLabel.FontFace = FONTS.Heavy
pingLabel.TextSize = 11
pingLabel.TextColor3 = COLORS.TextDim
pingLabel.TextXAlignment = Enum.TextXAlignment.Right
pingLabel.Parent = rightInfo

local function refreshPing()
	local p = 24
	local ok, v = pcall(function()
		return LocalPlayer:GetNetworkPing()
	end)
	if ok and typeof(v) == "number" and v > 0 then
		p = math.floor(v * 2000)
	end
	pingLabel.Text = string.format('<font color="#DDF764">●</font> PHILIPPINES · %d MS', p)
end
task.spawn(function()
	while screenGui.Parent do
		refreshPing()
		task.wait(3)
	end
end)

-- ============================================================
-- PARTICIPANTS & VOTES STATE
-- ============================================================
type ParticipantInfo = {
	id: any,
	name: string,
	isBot: boolean,
	voted: boolean,
	chipFrame: Frame?,
}

local participants: { [string]: ParticipantInfo } = {}
local currentTallies: { [string]: number } = {}
local totalParticipants = 8
local endsAtServerTime = 0
local timerRunning = false

local CHIP_COLORS = {
	Color3.fromRGB(240, 100, 80),
	Color3.fromRGB(80, 160, 240),
	Color3.fromRGB(240, 180, 60),
	Color3.fromRGB(140, 220, 100),
	Color3.fromRGB(180, 120, 240),
	Color3.fromRGB(240, 130, 180),
	Color3.fromRGB(90, 210, 200),
	Color3.fromRGB(220, 150, 90),
}

local function buildRosterChips(list: { { id: any, name: string, isBot: boolean } })
	-- Clear existing chips
	for _, child in ipairs(chipsContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	participants = {}
	totalParticipants = #list

	for idx, item in ipairs(list) do
		local key = tostring(item.id)
		local pInfo: ParticipantInfo = {
			id = item.id,
			name = item.name,
			isBot = item.isBot,
			voted = false,
		}

		local chip = Instance.new("Frame")
		chip.Name = "Chip_" .. key
		chip.Size = UDim2.fromOffset(34, 34)
		chip.BackgroundColor3 = CHIP_COLORS[((idx - 1) % #CHIP_COLORS) + 1]
		chip.Parent = chipsContainer
		corner(chip, 17)
		local cStroke = stroke(chip, COLORS.SlateLight, 1.5, 0.4)

		local initial = string.upper(string.sub(item.name, 1, 1))
		local initialLabel = Instance.new("TextLabel")
		initialLabel.Size = UDim2.fromScale(1, 1)
		initialLabel.BackgroundTransparency = 1
		initialLabel.Text = initial
		initialLabel.FontFace = FONTS.Heavy
		initialLabel.TextSize = 15
		initialLabel.TextColor3 = COLORS.NavyDeep
		initialLabel.Parent = chip

		if item.isBot then
			local botBadge = Instance.new("Frame")
			botBadge.AnchorPoint = Vector2.new(0.5, 1)
			botBadge.Position = UDim2.new(0.5, 0, 1, 4)
			botBadge.Size = UDim2.fromOffset(26, 12)
			botBadge.BackgroundColor3 = COLORS.SlateDark
			botBadge.Parent = chip
			corner(botBadge, 4)
			stroke(botBadge, COLORS.SlateLight, 1)

			local botText = Instance.new("TextLabel")
			botText.Size = UDim2.fromScale(1, 1)
			botText.BackgroundTransparency = 1
			botText.Text = "BOT"
			botText.FontFace = FONTS.Heavy
			botText.TextSize = 8
			botText.TextColor3 = COLORS.TextDim
			botText.Parent = botBadge
		end

		pInfo.chipFrame = chip
		participants[key] = pInfo
	end
end

local function addVoterAvatarChip(mapKey: string, voterId: any, isBot: boolean, name: string)
	local card = mapCards[mapKey]
	if not card then return end

	local existing = card.VotersFrame:FindFirstChild("Voter_" .. tostring(voterId))
	if existing then return end

	local chip = Instance.new("Frame")
	chip.Name = "Voter_" .. tostring(voterId)
	chip.Size = UDim2.fromOffset(28, 28)
	chip.BackgroundColor3 = isBot and COLORS.SlateLight or COLORS.Orange
	chip.Parent = card.VotersFrame
	corner(chip, 14)
	stroke(chip, COLORS.White, 1.5, 0.3)

	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = string.upper(string.sub(name, 1, 1))
	l.FontFace = FONTS.Heavy
	l.TextSize = 13
	l.TextColor3 = COLORS.NavyDeep
	l.Parent = chip

	-- Pop animation
	local pop = Instance.new("UIScale")
	pop.Scale = 0.5
	pop.Parent = chip
	tween(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

local function updateVoteTallies(tallies: { [string]: number })
	currentTallies = tallies

	local maxCount = -1
	local leaders: { string } = {}
	local totalVoted = 0

	for key, count in pairs(tallies) do
		totalVoted += count
		local card = mapCards[key]
		if card then
			card.VoteCountLabel.Text = tostring(count)
		end
		if count > maxCount then
			maxCount = count
			leaders = { key }
		elseif count == maxCount and count > 0 then
			table.insert(leaders, key)
		end
	end

	votedCounterLabel.Text = string.format("VOTED %d/%d", totalVoted, totalParticipants)

	-- Update badges (LEADING / TIE)
	for key, card in pairs(mapCards) do
		if maxCount > 0 then
			if #leaders > 1 and table.find(leaders, key) then
				card.Badge.Visible = true
				card.Badge.BackgroundColor3 = COLORS.SlateLight
				card.BadgeText.Text = "TIE"
				card.BadgeText.TextColor3 = COLORS.White
			elseif #leaders == 1 and leaders[1] == key then
				card.Badge.Visible = true
				card.Badge.BackgroundColor3 = COLORS.Lime
				card.BadgeText.Text = "LEADING"
				card.BadgeText.TextColor3 = COLORS.TextDark
			else
				card.Badge.Visible = false
			end
		else
			card.Badge.Visible = false
		end
	end
end

local function runCountdownLoop()
	if timerRunning then return end
	timerRunning = true
	task.spawn(function()
		while timerRunning and screenGui.Enabled do
			local remaining = math.max(0, math.ceil(endsAtServerTime - workspace:GetServerTimeNow()))
			timerNum.Text = tostring(remaining)
			if remaining <= 3 then
				timerNum.TextColor3 = Color3.fromRGB(255, 100, 100)
				circleStroke.Color = Color3.fromRGB(255, 100, 100)
			else
				timerNum.TextColor3 = COLORS.Lime
				circleStroke.Color = COLORS.Lime
			end
			if remaining <= 0 then
				break
			end
			task.wait(0.2)
		end
	end)
end

-- ============================================================
-- EVENT LISTENERS
-- ============================================================
local function showUI()
	screenGui.Enabled = true
	rootCanvas.GroupTransparency = 1
	tween(rootCanvas, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 })
end

local function hideUI()
	timerRunning = false
	local t = tween(rootCanvas, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
	t.Completed:Connect(function()
		screenGui.Enabled = false
	end)
end

MapVoteEvent.OnClientEvent:Connect(function(payload: any)
	if typeof(payload) ~= "table" then return end

	local actionType = payload.type
	if actionType == "Start" then
		myVote = nil

		-- Clear previous voter chips on cards
		for _, card in pairs(mapCards) do
			for _, child in ipairs(card.VotersFrame:GetChildren()) do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
			card.VoteBtn.Text = "VOTE"
			card.VoteBtn.BackgroundColor3 = COLORS.Lime
			card.VoteBtn.TextColor3 = COLORS.TextDark
			card.Stroke.Color = COLORS.SlateLight
			card.Stroke.Transparency = 0.5
			card.Card.BackgroundColor3 = COLORS.CardBg
			card.Badge.Visible = false
			card.VoteCountLabel.Text = "0"
		end

		-- Build cards if not built yet
		local pool = payload.pool or Config.MapVote.Pool or { "Kalsada", "Binaha" }
		local info = payload.info or Config.MapVote.Info or {}
		if not mapCards[pool[1]] then
			createMapCard(0, pool[1], "Barangay Kalsada", (info[pool[1]] and info[pool[1]].tagline) or "Own the court. Outrun the neighborhood.", (info[pool[1]] and info[pool[1]].event) or "EVENT · COURT RUSH", true)
		end
		if pool[2] and not mapCards[pool[2]] then
			createMapCard(504, pool[2], "Binaha Na Baryo", (info[pool[2]] and info[pool[2]].tagline) or "Find high ground. Stay ahead of the flood.", (info[pool[2]] and info[pool[2]].event) or "EVENT · TUBIG TUMATAAS", false)
		end

		if payload.participants then
			buildRosterChips(payload.participants)
		end

		endsAtServerTime = payload.endsAt or (workspace:GetServerTimeNow() + (payload.duration or 10))
		updateVoteTallies({ [pool[1]] = 0, [pool[2]] = 0 })
		runCountdownLoop()
		showUI()

	elseif actionType == "Update" then
		if payload.votes then
			updateVoteTallies(payload.votes)
		end

		local voterId = payload.voterId
		local mapKey = payload.map
		if voterId and mapKey then
			local key = tostring(voterId)
			local pInfo = participants[key]
			local isBot = pInfo and pInfo.isBot or (typeof(voterId) == "string")
			local name = pInfo and pInfo.name or tostring(voterId)

			addVoterAvatarChip(mapKey, voterId, isBot, name)

			-- Highlight roster chip
			if pInfo and pInfo.chipFrame then
				pInfo.voted = true
				stroke(pInfo.chipFrame, COLORS.Lime, 2, 0)
			end
		end

	elseif actionType == "Winner" then
		timerRunning = false
		timerNum.Text = "✓"
		timerLabel.Text = "WINNER\nCHOSEN"

		local winner = payload.winner
		for key, card in pairs(mapCards) do
			if key == winner then
				card.Badge.Visible = true
				card.Badge.BackgroundColor3 = COLORS.Lime
				card.BadgeText.Text = "WINNER!"
				card.BadgeText.TextColor3 = COLORS.TextDark
				card.Stroke.Color = COLORS.Lime
				card.Stroke.Transparency = 0
				card.Card.BackgroundColor3 = COLORS.CardBgSelected
				tween(card.Card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.fromOffset(480, 380),
				})
			else
				card.Badge.Visible = false
				tween(card.Card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 0.4,
				})
			end
		end

	elseif actionType == "Close" then
		hideUI()
	end
end)

-- Clean exit if match state moves past MS_VOTE
LocalPlayer:GetAttributeChangedSignal("HRushState"):Connect(function()
	local st = LocalPlayer:GetAttribute("HRushState")
	if st ~= "MS_VOTE" and screenGui.Enabled then
		hideUI()
	end
end)

print("[MapVoteUI] Initialized.")
