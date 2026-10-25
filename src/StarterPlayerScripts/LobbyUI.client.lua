--!strict
-- StarterPlayerScripts/LobbyUI.client.lua
-- Owner: Project Owner
-- Responsibility: Lobby, queue, loading screen, and settings presentation.
-- Task/spec: MS_RPS first Taya selection, GDD 3.2 / System Spec 2.1.
-- Task/spec: momentum step 3 presentation toggles, 2026-10-19.
-- Task/spec: owner-approved first-person FOV setting and in-match settings, 2026-10-22.
-- Task/spec: approved UI/UX redesign, 2026-10-23.
-- Task/spec: earned sprint help and loading tips, approved 2026-10-24.
-- Task/spec: first-join Classic Tag tutorial entry, approved 2026-10-25.
-- Task/spec: tutorial lobby visibility and queue cancellation repair, 2026-10-25.
-- Task/spec: free-roaming lobby views and movement, approved 2026-10-25.
--[[
	HABULAN RUSH - Lobby UI
	Place in: StarterPlayer > StarterPlayerScripts > LobbyUI   (LocalScript)

	Builds the whole lobby UI at runtime (no manual hierarchy needed).
	Reference layout: 1380 x 778 mock-up. Every group below is authored in
	"design pixels" of that mock-up, anchored to the screen with scale
	positions, then multiplied by a UIScale so proportions stay consistent.
]]

--------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SocialService = game:GetService("SocialService")
local ContextActionService = game:GetService("ContextActionService")

local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 10)
local QueueEvent = Remotes and Remotes:WaitForChild("QueueEvent", 10)
local PartyEvent = Remotes and Remotes:WaitForChild("PartyEvent", 10)
local TutorialEvent = Remotes and Remotes:WaitForChild("TutorialEvent", 10)

-- Shared tuning (match cover art + BGM). Falls back to silent gradient-only
-- when an older Config has no MatchIntro table.
local SharedConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"))
local INTRO = SharedConfig.UI.MatchIntro or {
	BackgroundImageId = "",
	BgmId = "",
	BgmVolume = 0.5,
	BgmFadeTime = 1.0,
}

-- Sibling module (same Rojo sync): the settings model this screen edits.
local ClientSettings = require(script.Parent:WaitForChild("ClientSettings"))
local Theme = require(script.Parent:WaitForChild("UITheme"))
local Layout = require(script.Parent:WaitForChild("UILayoutCoordinator"))
-- Sibling module (same Rojo sync): shared UI one-shots through the SFX group.
local UIAudio = require(script.Parent:WaitForChild("AudioRouter"))

-- Opens the Roblox friends invite prompt. PartyService puts invitees in your
-- party automatically via JoinData.LaunchData = your UserId.
local function promptGameInvite()
	task.spawn(function()
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can then
			local sent = pcall(function()
				local opts = Instance.new("InviteOptions")
				opts.LaunchData = tostring(player.UserId)
				SocialService:PromptGameInvite(player, opts)
			end)
			if not sent then
				pcall(function()
					SocialService:PromptGameInvite(player)
				end)
			end
		end
	end)
end

local CONFIG = {
	Region = "PHILIPPINES",
	Version = "v. 0.9.2",
	LocationText = "BARANGAY MALIGAYA",
	LocationSub = "LOBBY",
	PlayerNameOverride = nil, -- e.g. "JuanDelaRush". nil = your real Roblox display name

	-- Lobby presentation (the character stays a real 3D character)
	EnableLobbyCamera = true,
	HideDefaultCoreGui = true,
}

local COLORS = {
	Lime = Theme.Colors.Gold,
	LimeLight = Theme.Colors.Cream,
	LimeEdge = Color3.fromRGB(158, 108, 0),
	Navy = Theme.Colors.Navy,
	Slate = Theme.Colors.Raised,
	SlateEdge = Color3.fromRGB(34, 52, 60),
	SlateLight = Color3.fromRGB(78, 106, 117),
	Pill = Color3.fromRGB(46, 70, 82),
	PlusBox = Color3.fromRGB(86, 104, 114),
	Cream = Theme.Colors.Cream,
	CreamEdge = Color3.fromRGB(190, 186, 160),
	Orange = Theme.Colors.Orange,
	White = Theme.Colors.Cream,
	TextDim = Theme.Colors.Muted,
	Shadow = Color3.fromRGB(20, 34, 44),
	Gold = Theme.Colors.Gold,
	GoldDark = Color3.fromRGB(190, 128, 16),
	Cyan = Theme.Colors.Teal,
	PanelBg = Color3.fromRGB(40, 62, 72),
	GearGray = Color3.fromRGB(78, 90, 96),
}

-- FONTS: swap these to change typography later.
-- Logo/labels use GothamSSm (closest bundled font to the reference),
-- PLAY + panel titles use Oswald (condensed display face).
local FONTS = {
	HeavyItalic = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic),
	Heavy = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal),
	Bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
	SemiBold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
	Display = Font.fromEnum(Enum.Font.Oswald), -- change me for a different PLAY / title font
}

-- ASSET PLACEHOLDERS: paste "rbxassetid://123" to replace a drawn icon with your own image.
-- Empty string = the script draws the icon from simple UI shapes.
local ASSETS = {
	Settings = "",
	Profile = "",
	Collection = "",
	Shop = "",
	Coin = "",
	Gem = "",
}

--------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------
local INFO_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(obj, info, goal)
	if Theme.reducedMotion() then info = TweenInfo.new(0.08) end
	local t = TweenService:Create(obj, info, goal)
	t:Play()
	return t
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function createFrame(props, parent)
	local p = { BorderSizePixel = 0, BackgroundColor3 = COLORS.Slate }
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return create("Frame", p, parent)
end

local function createLabel(props, parent)
	local p = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		FontFace = FONTS.Bold,
		TextSize = 14,
		TextColor3 = COLORS.White,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return create("TextLabel", p, parent)
end

local function createButton(props, parent)
	local p = {
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		FontFace = FONTS.Bold,
		TextSize = 14,
		TextColor3 = COLORS.White,
	}
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	return create("TextButton", p, parent)
end

local FULL = UDim.new(0.5, 0)

local function corner(obj, r)
	local radius = typeof(r) == "UDim" and r or UDim.new(0, r)
	return create("UICorner", { CornerRadius = radius }, obj)
end

local function stroke(obj, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, obj)
end

-- Label with a hard offset drop shadow (logo, captions)
local function createShadowLabel(props, parent, offset)
	local sp = table.clone(props)
	sp.Name = "Shadow"
	sp.TextColor3 = COLORS.Shadow
	sp.TextTransparency = 0.35
	sp.Position = props.Position + UDim2.fromOffset(offset.X, offset.Y)
	createLabel(sp, parent)
	return createLabel(props, parent)
end

-- hover / press scale feedback + click callback
local function bindButton(button, scaleObj, onClick, hoverScale, pressScale)
	hoverScale = hoverScale or 1.05
	pressScale = pressScale or 0.94
	local hovered = false
	button.MouseEnter:Connect(function()
		hovered = true
		tween(scaleObj, INFO_FAST, { Scale = hoverScale })
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		tween(scaleObj, INFO_FAST, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		tween(scaleObj, INFO_FAST, { Scale = pressScale })
	end)
	button.MouseButton1Up:Connect(function()
		tween(scaleObj, INFO_FAST, { Scale = hovered and hoverScale or 1 })
	end)
	button.Activated:Connect(function()
		tween(scaleObj, INFO_FAST, { Scale = 1 })
		if onClick then
			onClick()
		end
	end)
end

--------------------------------------------------------------------------
-- ICONS (drawn from UI shapes unless an ASSETS id is provided)
--------------------------------------------------------------------------
local function iconContainer(parent, S, pos)
	return createFrame({
		Name = "Icon",
		Size = UDim2.fromOffset(S, S),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos or UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
	}, parent)
end

local function centered(parent, w, h, color, pos)
	return createFrame({
		Size = UDim2.fromOffset(w, h),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = pos or UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = color,
	}, parent)
end

local function outline(parent, w, h, color, thick, pos, anchor, fill)
	local f = createFrame({
		Size = UDim2.fromOffset(w, h),
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Position = pos or UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = fill or color,
		BackgroundTransparency = fill and 0 or 1,
	}, parent)
	stroke(f, color, thick)
	return f
end

local ICON_BUILDERS = {}

function ICON_BUILDERS.Settings(c, S, color, bg)
	for i = 0, 3 do
		local tooth = centered(c, S * 0.2, S * 0.96, color)
		tooth.Rotation = i * 45
		corner(tooth, 2)
	end
	corner(centered(c, S * 0.66, S * 0.66, color), FULL)
	corner(centered(c, S * 0.3, S * 0.3, bg or COLORS.Cream), FULL)
end

function ICON_BUILDERS.Profile(c, S, color)
	local t = math.max(1.5, S * 0.09)
	corner(outline(c, S * 0.36, S * 0.36, color, t, UDim2.fromScale(0.5, 0.3)), FULL)
	corner(outline(c, S * 0.78, S * 0.42, color, t, UDim2.fromScale(0.5, 0.95), Vector2.new(0.5, 1)), FULL)
end

function ICON_BUILDERS.Collection(c, S, color, bg)
	local t = math.max(1.5, S * 0.08)
	corner(outline(c, S * 0.56, S * 0.68, color, t, UDim2.fromScale(0.6, 0.4)), 3)
	corner(outline(c, S * 0.56, S * 0.68, color, t, UDim2.fromScale(0.42, 0.58), nil, bg or COLORS.Slate), 3)
end

function ICON_BUILDERS.Shop(c, S, color)
	local t = math.max(1.5, S * 0.08)
	corner(outline(c, S * 0.84, S * 0.3, color, t, UDim2.fromScale(0.5, 0.22)), 3)
	corner(outline(c, S * 0.7, S * 0.46, color, t, UDim2.fromScale(0.5, 0.96), Vector2.new(0.5, 1)), 2)
	corner(outline(c, S * 0.22, S * 0.3, color, t, UDim2.fromScale(0.5, 0.96), Vector2.new(0.5, 1)), 2)
end

function ICON_BUILDERS.Coin(c, S)
	local coin = centered(c, S, S, COLORS.Gold)
	corner(coin, FULL)
	stroke(coin, COLORS.GoldDark, math.max(2, S * 0.1))
	createLabel({
		Size = UDim2.fromScale(1, 1),
		Text = "P",
		FontFace = FONTS.Heavy,
		TextSize = S * 0.55,
		TextColor3 = COLORS.GoldDark,
	}, coin)
end

function ICON_BUILDERS.Gem(c, S)
	local d = centered(c, S * 0.62, S * 0.62, COLORS.Cyan)
	d.Rotation = 45
	corner(d, 3)
	corner(centered(d, S * 0.3, S * 0.3, Color3.fromRGB(190, 245, 252)), 2)
end

function ICON_BUILDERS.GameModes(c, S, color)
	-- 2x2 grid = mode select
	for _, pos in ipairs({ Vector2.new(0.29, 0.29), Vector2.new(0.71, 0.29), Vector2.new(0.29, 0.71), Vector2.new(0.71, 0.71) }) do
		local cell = centered(c, S * 0.34, S * 0.34, color)
		cell.Position = UDim2.fromScale(pos.X, pos.Y)
		corner(cell, 3)
	end
end

local function makeIcon(kind, parent, S, color, bg, pos)
	local c = iconContainer(parent, S, pos)
	if ASSETS[kind] and ASSETS[kind] ~= "" then
		create("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = ASSETS[kind],
			ImageColor3 = (kind == "Coin" or kind == "Gem") and COLORS.White or color,
		}, c)
	else
		ICON_BUILDERS[kind](c, S, color, bg)
	end
	return c
end

--------------------------------------------------------------------------
-- CREATE SCREEN GUI
--------------------------------------------------------------------------
local old = playerGui:FindFirstChild("LobbyUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "LobbyUI",
	Enabled = false,
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = Theme.Layers.Lobby,
}, playerGui)

local panels = {}
local groups = {}

-- A "group" is a fixed design-pixel frame anchored with scale and multiplied by a UIScale.
-- Landscape and portrait placements are both stored; setupResponsiveUI() picks one.
local function createGroup(name, designSize, lAnchor, lPos, pAnchor, pPos)
	local frame = createFrame({
		Name = name,
		Size = UDim2.fromOffset(designSize.X, designSize.Y),
		BackgroundTransparency = 1,
	}, gui)
	local scale = create("UIScale", {}, frame)
	table.insert(groups, {
		Frame = frame,
		Scale = scale,
		LAnchor = lAnchor,
		LPos = lPos,
		PAnchor = pAnchor,
		PPos = pPos,
	})
	return frame
end

local displayName = CONFIG.PlayerNameOverride or player.DisplayName

-- Handles filled in below, wired up in BUTTON EVENTS
local playHolderScale, settingsHolderScale, chevronLabel
local playButton, settingsButton, playIcon, playText, cancelHint, cancelButton
local tutorialButton: TextButton
local onInvitePressed -- assigned with the party picker below
local gmButton, gmScale
local playModeChipLabel

-- These cards describe the live server ballot. The lobby never picks a mode.
local GAME_MODES = {
	{ id = "ClassicTag", shortName = "CLASSIC TAG", locked = SharedConfig.ModeVote.Modes.ClassicTag.enabled ~= true },
	{ id = "AgawanNgPanyo", shortName = "AGAWAN NG PANYO", locked = SharedConfig.ModeVote.Modes.AgawanNgPanyo.enabled ~= true },
	{ id = "SecretHunt", shortName = "LIHIM NA TARGET", locked = SharedConfig.ModeVote.Modes.SecretHunt.enabled ~= true },
}

--------------------------------------------------------------------------
-- TOP BAR (logo + location top-left, currency + avatar top-right)
--------------------------------------------------------------------------
local logoGroup = createGroup(
	"LogoGroup",
	Vector2.new(300, 200),
	Vector2.new(0, 0), UDim2.fromScale(0.029, 0.11),
	Vector2.new(0, 0), UDim2.fromScale(0.05, 0.03)
)

do
	local textBlock = createFrame({
		Name = "LogoText",
		Size = UDim2.fromOffset(240, 140),
		BackgroundTransparency = 1,
		Rotation = -3,
	}, logoGroup)

	createShadowLabel({
		Name = "Habulan",
		Position = UDim2.fromOffset(2, 6),
		Size = UDim2.fromOffset(172, 42),
		Text = "HABULAN",
		FontFace = FONTS.HeavyItalic,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, textBlock, Vector2.new(2, 3))

	createShadowLabel({
		Name = "Rush",
		Position = UDim2.fromOffset(4, 44),
		Size = UDim2.fromOffset(150, 72),
		Text = "RUSH",
		FontFace = FONTS.HeavyItalic,
		TextScaled = true,
		TextColor3 = COLORS.Lime,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, textBlock, Vector2.new(3, 4))

	createShadowLabel({
		Name = "Chevrons",
		Position = UDim2.fromOffset(160, 58),
		Size = UDim2.fromOffset(44, 44),
		Text = "»",
		FontFace = FONTS.HeavyItalic,
		TextScaled = true,
		TextColor3 = COLORS.Lime,
	}, textBlock, Vector2.new(2, 3))

	createShadowLabel({
		Name = "Tagline",
		Position = UDim2.fromOffset(14, 120),
		Size = UDim2.fromOffset(190, 14),
		Text = "TAKBO. TAGO. PANALO.",
		FontFace = FONTS.Bold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, textBlock, Vector2.new(1, 1))

	-- location line
	corner(createFrame({
		Position = UDim2.fromOffset(5, 181),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = COLORS.Lime,
	}, logoGroup), FULL)
	createShadowLabel({
		Name = "Location",
		Position = UDim2.fromOffset(20, 176),
		Size = UDim2.fromOffset(280, 16),
		Text = string.format('%s<font color="#9fb6bd">   /   </font>%s', CONFIG.LocationText, CONFIG.LocationSub),
		RichText = true,
		FontFace = FONTS.Heavy,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, logoGroup, Vector2.new(1, 1))
end

local topRightGroup = createGroup(
	"TopRightGroup",
	Vector2.new(376, 50),
	Vector2.new(1, 0), UDim2.fromScale(0.976, 0.049),
	Vector2.new(1, 0), UDim2.fromScale(0.96, 0.235)
)

local function createCurrencyPill(x, w, kind, text)
	local holder = createFrame({
		Name = kind .. "Pill",
		Position = UDim2.fromOffset(x + w / 2, 25),
		Size = UDim2.fromOffset(w, 50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, topRightGroup)

	corner(createFrame({
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.fromOffset(w, 47),
		BackgroundColor3 = COLORS.SlateEdge,
	}, holder), 12)
	local body = createFrame({
		Size = UDim2.fromOffset(w, 47),
		BackgroundColor3 = COLORS.Pill,
	}, holder)
	corner(body, 12)
	stroke(body, COLORS.SlateLight, 1, 0.6)

	makeIcon(kind, body, 32, COLORS.White, nil, UDim2.fromOffset(25, 23))
	createLabel({
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.fromOffset(w - 48 - 38, 47),
		Text = text,
		FontFace = FONTS.Bold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, body)

	local plus = createButton({
		Position = UDim2.fromOffset(w - 33, 9),
		Size = UDim2.fromOffset(24, 29),
		BackgroundColor3 = COLORS.PlusBox,
		Text = "+",
		FontFace = FONTS.Heavy,
		TextSize = 20,
		TextColor3 = COLORS.Navy,
	}, body)
	corner(plus, 5)
	-- UI prototype only: "+" has hover/press feedback but no purchase flow
	bindButton(plus, create("UIScale", {}, plus), nil, 1.1, 0.9)
end

-- Currency is not part of this competition build.

do
	local avatar = createFrame({
		Name = "AvatarBadge",
		Position = UDim2.fromOffset(324, 0),
		Size = UDim2.fromOffset(52, 50),
		BackgroundColor3 = COLORS.Orange,
	}, topRightGroup)
	corner(avatar, 10)
	stroke(avatar, COLORS.Cream, 1.5, 0.4)
	createLabel({
		Size = UDim2.fromScale(1, 1),
		Text = string.upper(string.sub(displayName, 1, 1)),
		FontFace = FONTS.Heavy,
		TextSize = 26,
		TextColor3 = COLORS.Navy,
	}, avatar)
end

--------------------------------------------------------------------------
-- MAIN ACTIONS: [ PLAY ] [ gear ]  + player nameplate
--------------------------------------------------------------------------
local playGroup = createGroup(
	"PlayGroup",
	Vector2.new(420, 230),
	Vector2.new(1, 0), UDim2.fromScale(0.951, 0.553),
	Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.8)
)

do
	-- caption above PLAY
	createFrame({
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.fromOffset(20, 2),
		BackgroundColor3 = Color3.fromRGB(220, 235, 150),
	}, playGroup)
	createShadowLabel({
		Name = "Caption",
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.fromOffset(300, 16),
		Text = "THE STREETS ARE CALLING",
		FontFace = FONTS.Heavy,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, playGroup, Vector2.new(1, 1))

	-- PLAY (large)
	local holder = createFrame({
		Name = "PlayHolder",
		Position = UDim2.fromOffset(140.5, 82),
		Size = UDim2.fromOffset(281, 96),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, playGroup)
	playHolderScale = create("UIScale", {}, holder)

	corner(createFrame({
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.fromOffset(281, 89),
		BackgroundColor3 = COLORS.Shadow,
		BackgroundTransparency = 0.7,
	}, holder), 17)
	corner(createFrame({
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.fromOffset(281, 89),
		BackgroundColor3 = COLORS.LimeEdge,
	}, holder), 17)

	playButton = createButton({
		Name = "PlayButton",
		Size = UDim2.fromOffset(281, 89),
		BackgroundColor3 = COLORS.Lime,
	}, holder)
	Theme.focus(playButton)
	corner(playButton, 17)
	stroke(playButton, COLORS.LimeLight, 2, 0.2)
	create("UIGradient", {
		Color = ColorSequence.new(COLORS.LimeLight, COLORS.Lime),
		Rotation = 90,
	}, playButton)

	playIcon = createLabel({
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.fromOffset(34, 89),
		Text = "▶",
		FontFace = FONTS.Bold,
		TextSize = 28,
		TextColor3 = COLORS.Navy,
	}, playButton)
	playText = createLabel({
		Position = UDim2.fromOffset(88, 0),
		Size = UDim2.fromOffset(186, 89),
		Text = "FIND MATCH",
		FontFace = FONTS.Display,
		TextSize = 32,
		TextColor3 = COLORS.Navy,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, playButton)
	cancelHint = createLabel({
		Position = UDim2.fromOffset(86, 52),
		Size = UDim2.fromOffset(190, 24),
		Text = "TAP TO CANCEL",
		FontFace = FONTS.Heavy,
		TextSize = 13,
		TextColor3 = COLORS.Navy,
		TextTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, playButton)
	cancelHint.Visible = false
	cancelButton = createButton({
		Name = "CancelQueue",
		Position = UDim2.fromOffset(0, 136),
		Size = UDim2.fromOffset(281, 34),
		BackgroundColor3 = COLORS.Slate,
		Text = "CANCEL SEARCH",
		FontFace = FONTS.Heavy,
		TextSize = 16,
		TextColor3 = COLORS.Cream,
		Visible = false,
	}, playGroup)
	corner(cancelButton, 10)

	-- selected game mode chip (top edge of the PLAY button)
	local modeChip = createFrame({
		Name = "PlayModeChip",
		Position = UDim2.fromOffset(281 - 158, -9),
		Size = UDim2.fromOffset(158, 20),
		BackgroundColor3 = COLORS.Lime,
		ZIndex = 5,
	}, holder)
	corner(modeChip, 6)
	stroke(modeChip, COLORS.LimeEdge, 1)
	playModeChipLabel = createLabel({
		Size = UDim2.fromScale(1, 1),
		Text = "VOTE AFTER MATCHMAKING",
		FontFace = FONTS.Heavy,
		TextSize = 10,
		TextColor3 = COLORS.Navy,
		ZIndex = 6,
	}, modeChip)
	chevronLabel = createLabel({
		Position = UDim2.fromOffset(216, 0),
		Size = UDim2.fromOffset(24, 89),
		Text = "›",
		FontFace = FONTS.Bold,
		TextSize = 36,
		TextColor3 = COLORS.LimeEdge,
	}, playButton)

	-- GAME MODES (small, immediately beside PLAY)
	local gmHolder = createFrame({
		Name = "GameModesHolder",
		Position = UDim2.fromOffset(331, 82),
		Size = UDim2.fromOffset(68, 74),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, playGroup)
	gmScale = create("UIScale", {}, gmHolder)

	corner(createFrame({
		Position = UDim2.fromOffset(0, 9),
		Size = UDim2.fromOffset(68, 69),
		BackgroundColor3 = COLORS.Shadow,
		BackgroundTransparency = 0.7,
	}, gmHolder), 15)
	corner(createFrame({
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromOffset(68, 69),
		BackgroundColor3 = COLORS.LimeEdge,
	}, gmHolder), 15)
	gmButton = createButton({
		Name = "GameModesButton",
		Size = UDim2.fromOffset(68, 69),
		BackgroundColor3 = COLORS.Slate,
	}, gmHolder)
	Theme.focus(gmButton)
	corner(gmButton, 15)
	stroke(gmButton, COLORS.SlateLight, 1, 0.6)
	makeIcon("GameModes", gmButton, 30, COLORS.Lime, COLORS.Slate)

	-- SETTINGS (moved to the top bar, left of the currency pills)
	local sHolder = createFrame({
		Name = "SettingsHolder",
		Position = UDim2.fromOffset(-64, 0),
		Size = UDim2.fromOffset(50, 50),
		BackgroundTransparency = 1,
	}, topRightGroup)
	settingsHolderScale = create("UIScale", {}, sHolder)
	settingsButton = createButton({
		Name = "SettingsButton",
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = COLORS.Cream,
	}, sHolder)
	Theme.focus(settingsButton)
	corner(settingsButton, 10)
	stroke(settingsButton, COLORS.CreamEdge, 1.5, 0.2)
	makeIcon("Settings", settingsButton, 26, COLORS.GearGray, COLORS.Cream)

end

-- Replay entry stays beside the main action, including after completion.
tutorialButton = createButton({
	Name = "TutorialButton",
	Position = UDim2.fromOffset(0, 180),
	Size = UDim2.fromOffset(281, 48),
	BackgroundColor3 = COLORS.Slate,
	Text = "LEARN TO PLAY",
	FontFace = FONTS.Heavy,
	TextSize = 18,
	TextColor3 = COLORS.Cream,
}, playGroup) :: TextButton
corner(tutorialButton, 12)
stroke(tutorialButton, COLORS.Lime, 1.5, 0.2)
Theme.focus(tutorialButton)

-- PARTY SLOTS (you + party members + "+" invite buttons)
-- Membership comes from the PartyService attributes:
--   HRushPartyLeader (UserId) / HRushPartySlot (1..4) / HRushPartySize.
--------------------------------------------------------------------------
local partyGroup = createGroup(
	"PartyGroup",
	Vector2.new(280, 56),
	Vector2.new(0.5, 0), UDim2.fromScale(0.412, 0.645),
	Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.44)
)

local partySlots = createFrame({
	Name = "PartySlots",
	Size = UDim2.fromOffset(280, 56),
	BackgroundTransparency = 1,
}, partyGroup)

--------------------------------------------------------------------------
-- STUDIO TEAM-TEST PICKER
-- Roblox never delivers game invites sent from a Studio playtest, so in
-- Studio the "+" buttons open this picker instead: pick anyone on this
-- server to pull into your party (server-side "DebugJoin"). In a published
-- server the "+" buttons use the real PromptGameInvite flow.
--------------------------------------------------------------------------
local pickerHolder = createFrame({
	Name = "PartyPicker",
	Size = UDim2.fromOffset(340, 384),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = COLORS.PanelBg,
	Visible = false,
	ZIndex = 30,
}, gui)
corner(pickerHolder, 14)
stroke(pickerHolder, COLORS.SlateLight, 2, 0.4)

createLabel({
	Position = UDim2.fromOffset(20, 14),
	Size = UDim2.fromOffset(260, 22),
	Text = "ADD PLAYER TO PARTY",
	FontFace = FONTS.Display,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 31,
}, pickerHolder)
createLabel({
	Position = UDim2.fromOffset(20, 40),
	Size = UDim2.fromOffset(300, 26),
	Text = "Studio team test only — real invites work in the published game.",
	FontFace = FONTS.SemiBold,
	TextSize = 10,
	TextColor3 = COLORS.TextDim,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	ZIndex = 31,
}, pickerHolder)

local pickerList = createFrame({
	Name = "List",
	Position = UDim2.fromOffset(16, 72),
	Size = UDim2.fromOffset(308, 244),
	BackgroundTransparency = 1,
	ZIndex = 31,
}, pickerHolder)
create("UIListLayout", {
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, pickerList)

local pickerClose = createButton({
	Position = UDim2.fromOffset(340 - 46, 12),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = COLORS.Slate,
	Text = "X",
	FontFace = FONTS.Heavy,
	TextSize = 13,
	ZIndex = 31,
}, pickerHolder)
corner(pickerClose, 8)

local pickerLeave = createButton({
	Position = UDim2.fromOffset(16, 384 - 52),
	Size = UDim2.fromOffset(308, 36),
	BackgroundColor3 = COLORS.SlateLight,
	Text = "LEAVE PARTY",
	FontFace = FONTS.Heavy,
	TextSize = 13,
	ZIndex = 31,
}, pickerHolder)
corner(pickerLeave, 8)

local function refreshPickerList()
	for _, c in ipairs(pickerList:GetChildren()) do
		if c:IsA("Frame") or c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	local myLeader = player:GetAttribute("HRushPartyLeader") or player.UserId
	local found = 0
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= player and (pl:GetAttribute("HRushPartyLeader") or pl.UserId) ~= myLeader then
			found += 1
			local row = createFrame({
				Name = "Row_" .. pl.UserId,
				Size = UDim2.fromOffset(308, 40),
				BackgroundColor3 = COLORS.Slate,
				LayoutOrder = found,
				ZIndex = 31,
			}, pickerList)
			corner(row, 8)
			local av = createFrame({
				Position = UDim2.fromOffset(6, 5),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = COLORS.Cyan,
				ZIndex = 32,
			}, row)
			corner(av, 15)
			createLabel({
				Size = UDim2.fromScale(1, 1),
				Text = string.upper(string.sub(pl.DisplayName, 1, 1)),
				FontFace = FONTS.Heavy,
				TextSize = 14,
				TextColor3 = COLORS.Navy,
				ZIndex = 33,
			}, av)
			createLabel({
				Position = UDim2.fromOffset(44, 0),
				Size = UDim2.fromOffset(160, 40),
				Text = pl.DisplayName,
				FontFace = FONTS.Bold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				ZIndex = 32,
			}, row)
			local addBtn = createButton({
				Position = UDim2.fromOffset(308 - 86, 5),
				Size = UDim2.fromOffset(78, 30),
				BackgroundColor3 = COLORS.Lime,
				Text = "+ ADD",
				FontFace = FONTS.Heavy,
				TextSize = 12,
				TextColor3 = COLORS.Navy,
				ZIndex = 32,
			}, row)
			corner(addBtn, 8)
			local targetId = pl.UserId
			bindButton(addBtn, create("UIScale", {}, addBtn), function()
				if PartyEvent then
					PartyEvent:FireServer("DebugJoin", targetId)
				end
				pickerHolder.Visible = false
			end, 1.05, 0.95)
		end
	end
	if found == 0 then
		createLabel({
			Size = UDim2.fromOffset(308, 60),
			Text = "No other players on this server.\nUse Test ▸ 2 Players (or Team Test) to add teammates.",
			FontFace = FONTS.SemiBold,
			TextSize = 11,
			TextColor3 = COLORS.TextDim,
			TextWrapped = true,
			ZIndex = 31,
		}, pickerList)
	end
end

onInvitePressed = function()
	if RunService:IsStudio() then
		refreshPickerList()
		pickerHolder.Visible = true
	else
		promptGameInvite()
	end
end

pickerClose.Activated:Connect(function()
	pickerHolder.Visible = false
end)
pickerLeave.Activated:Connect(function()
	if PartyEvent then
		PartyEvent:FireServer("Leave")
	end
	pickerHolder.Visible = false
end)

local function refreshPartyRow()
	for _, c in ipairs(partySlots:GetChildren()) do
		c:Destroy()
	end

	local leaderId = player:GetAttribute("HRushPartyLeader") or player.UserId
	local members = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("HRushPartyLeader") == leaderId then
			table.insert(members, pl)
		end
	end
	table.sort(members, function(a, b)
		return (a:GetAttribute("HRushPartySlot") or 9) < (b:GetAttribute("HRushPartySlot") or 9)
	end)

	for i = 1, 4 do
		local m = members[i]
		local x = (i - 1) * 62
		if m then
			local isSelf = (m == player)
			local chip = createFrame({
				Name = "PartySlot" .. i,
				Position = UDim2.fromOffset(x, 4),
				Size = UDim2.fromOffset(48, 48),
				BackgroundColor3 = isSelf and COLORS.Orange or COLORS.Cyan,
			}, partySlots)
			corner(chip, FULL)
			stroke(chip, isSelf and COLORS.Cream or COLORS.White, 1.5, 0.3)
			createLabel({
				Size = UDim2.fromScale(1, 1),
				Text = string.upper(string.sub(m.DisplayName, 1, 1)),
				FontFace = FONTS.Heavy,
				TextSize = 20,
				TextColor3 = COLORS.Navy,
			}, chip)
			if isSelf then
				createLabel({
					Position = UDim2.fromOffset(0, 52),
					Size = UDim2.fromOffset(48, 14),
					Text = "YOU",
					FontFace = FONTS.Heavy,
					TextSize = 10,
					TextColor3 = COLORS.TextDim,
				}, partySlots)
			end
		else
			local plus = createButton({
				Name = "PartyInvite" .. i,
				Position = UDim2.fromOffset(x, 4),
				Size = UDim2.fromOffset(48, 48),
				BackgroundColor3 = COLORS.Pill,
				Text = "+",
				FontFace = FONTS.Heavy,
				TextSize = 28,
				TextColor3 = COLORS.Lime,
			}, partySlots)
			corner(plus, FULL)
			stroke(plus, COLORS.SlateLight, 1.5, 0.4)
			bindButton(plus, create("UIScale", {}, plus), onInvitePressed, 1.1, 0.92)
		end
	end

	-- Leave button: only meaningful when someone else is in the party.
	if #members > 1 then
		local leaveX = createButton({
			Name = "LeaveParty",
			Position = UDim2.fromOffset(244, 14),
			Size = UDim2.fromOffset(26, 26),
			BackgroundColor3 = COLORS.Pill,
			Text = "✕",
			FontFace = FONTS.Heavy,
			TextSize = 13,
			TextColor3 = COLORS.TextDim,
		}, partySlots)
		corner(leaveX, 13)
		stroke(leaveX, COLORS.SlateLight, 1, 0.6)
		bindButton(leaveX, create("UIScale", {}, leaveX), function()
			if PartyEvent then
				PartyEvent:FireServer("Leave")
			end
		end, 1.1, 0.9)
	end
end
refreshPartyRow()
player:GetAttributeChangedSignal("HRushPartySize"):Connect(refreshPartyRow)
player:GetAttributeChangedSignal("HRushPartyLeader"):Connect(refreshPartyRow)
player:GetAttributeChangedSignal("HRushPartySlot"):Connect(refreshPartyRow)
Players.PlayerAdded:Connect(function()
	task.defer(refreshPartyRow)
end)
Players.PlayerRemoving:Connect(function()
	task.defer(refreshPartyRow)
end)

--------------------------------------------------------------------------
-- BOTTOM NAVIGATION (PROFILE / COLLECTION / SHOP + region/ping/version)
--------------------------------------------------------------------------
local navGroup = createGroup(
	"NavGroup",
	Vector2.new(467, 60),
	Vector2.new(0, 1), UDim2.fromScale(0.033, 0.97),
	Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.975)
)

local navButtons = {}

local function createNavButton(name, text, iconKind, x, w, showDot)
	local holder = createFrame({
		Name = name .. "Holder",
		Position = UDim2.fromOffset(x + w / 2, 28),
		Size = UDim2.fromOffset(w, 56),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, navGroup)
	local scale = create("UIScale", {}, holder)

	corner(createFrame({
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.fromOffset(w, 52),
		BackgroundColor3 = COLORS.Shadow,
		BackgroundTransparency = 0.7,
	}, holder), 11)
	corner(createFrame({
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.fromOffset(w, 52),
		BackgroundColor3 = COLORS.SlateEdge,
	}, holder), 11)
	local btn = createButton({
		Name = name,
		Size = UDim2.fromOffset(w, 52),
		BackgroundColor3 = COLORS.Slate,
	}, holder)
	Theme.focus(btn)
	corner(btn, 11)
	stroke(btn, COLORS.SlateLight, 1, 0.6)

	makeIcon(iconKind, btn, 22, COLORS.White, COLORS.Slate, UDim2.fromOffset(35, 26))
	createLabel({
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.fromOffset(w - 62, 52),
		Text = text,
		FontFace = FONTS.Heavy,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, btn)

	if showDot then
		corner(createFrame({
			Position = UDim2.fromOffset(w - 17, 10),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = COLORS.Lime,
		}, btn), FULL)
	end
	navButtons[name] = { Button = btn, Scale = scale }
end

createNavButton("Profile", "PROFILE", "Profile", 0, 144, false)
createNavButton("Help", "HELP / CONTROLS", "Collection", 156, 220, false)
-- No shop or currency affordance is shown without an approved system.

local infoGroup = createGroup(
	"InfoGroup",
	Vector2.new(340, 20),
	Vector2.new(1, 0.5), UDim2.fromScale(0.976, 0.929),
	Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0.905)
)

local infoLabel = createLabel({
	Size = UDim2.fromScale(1, 1),
	RichText = true,
	FontFace = FONTS.Heavy,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextStrokeColor3 = COLORS.Shadow,
	TextStrokeTransparency = 0.75,
}, infoGroup)

local function refreshInfo()
	local ping = 32
	local ok, v = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and typeof(v) == "number" and v > 0 then
		ping = math.floor(v * 2000)
	end
	infoLabel.Text = string.format(
		'<font color="#DDF764">●</font>  %s   •   %d MS      <font color="#9fb0b6">%s</font>',
		CONFIG.Region,
		ping,
		CONFIG.Version
	)
end
refreshInfo()
task.spawn(function()
	while gui.Parent do
		task.wait(3)
		refreshInfo()
	end
end)

--------------------------------------------------------------------------
-- PANELS
--------------------------------------------------------------------------
local overlay = createButton({
	Name = "Overlay",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 16, 22),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 10,
}, gui)

local currentPanel = nil
local overlayToken = 0
local priorPanelFocus: GuiObject? = nil

local function createPanel(name, title, width, height)
	local holder = createFrame({
		Name = name .. "Panel",
		Size = UDim2.fromOffset(width, height),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 20,
	}, gui)
	local fit = create("UIScale", {}, holder)

	-- NOTE: plain Frame, not CanvasGroup — CanvasGroups render dark in this
	-- environment (~40% brightness). Fading is done by an inner black veil.
	local canvas = createFrame({
		Name = "Canvas",
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = COLORS.PanelBg,
	}, holder)
	local veil = createFrame({
		Name = "FadeVeil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
	}, canvas)
	corner(canvas, 18)
	stroke(canvas, COLORS.SlateLight, 2, 0.4)
	local pop = create("UIScale", { Scale = 0.92 }, canvas)

	corner(createFrame({
		Position = UDim2.fromOffset(28, 24),
		Size = UDim2.fromOffset(6, 30),
		BackgroundColor3 = COLORS.Lime,
	}, canvas), 3)
	createLabel({
		Position = UDim2.fromOffset(46, 18),
		Size = UDim2.new(1, -140, 0, 42),
		Text = title,
		FontFace = FONTS.Display,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, canvas)
	createFrame({
		Position = UDim2.fromOffset(28, 70),
		Size = UDim2.new(1, -56, 0, 2),
		BackgroundColor3 = COLORS.SlateLight,
		BackgroundTransparency = 0.6,
	}, canvas)

	local closeBtn = createButton({
		Position = UDim2.new(1, -72, 0, 8),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = COLORS.Slate,
		Text = "X",
		FontFace = FONTS.Heavy,
		TextSize = 16,
	}, canvas)
	corner(closeBtn, 10)
	stroke(closeBtn, COLORS.SlateLight, 1, 0.5)
	Theme.focus(closeBtn)

	local content = createFrame({
		Name = "Content",
		Position = UDim2.fromOffset(28, 90),
		Size = UDim2.fromOffset(width - 56, height - 90 - 28),
		BackgroundTransparency = 1,
	}, canvas)

	local panel = {
		Name = name,
		Holder = holder,
		Fit = fit,
		Canvas = canvas,
		Veil = veil,
		Pop = pop,
		Content = content,
		Close = closeBtn,
		Width = width,
		Height = height,
		Token = 0,
	}
	panels[name] = panel
	return panel
end

-- generic action button (lime / cream / slate) used inside panels
local function createActionButton(parent, text, style, x, y, w, h, onClick, textSize)
	local face, edge, textColor
	if style == "lime" then
		face, edge, textColor = COLORS.Lime, COLORS.LimeEdge, COLORS.Navy
	elseif style == "cream" then
		face, edge, textColor = COLORS.Cream, COLORS.CreamEdge, COLORS.Navy
	else
		face, edge, textColor = COLORS.SlateLight, COLORS.SlateEdge, COLORS.White
	end
	local holder = createFrame({
		Position = UDim2.fromOffset(x + w / 2, y + (h + 5) / 2),
		Size = UDim2.fromOffset(w, h + 5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	}, parent)
	local scale = create("UIScale", {}, holder)
	corner(createFrame({
		Position = UDim2.fromOffset(0, 5),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = edge,
	}, holder), 12)
	local top = createButton({
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = face,
		Text = text,
		FontFace = FONTS.Heavy,
		TextSize = textSize or 16,
		TextColor3 = textColor,
	}, holder)
	corner(top, 12)
	bindButton(top, scale, onClick, 1.03, 0.96)
	return top
end

local function createCard(parent, x, y, w, h, titleText)
	local card = createFrame({
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = COLORS.Slate,
	}, parent)
	corner(card, 12)
	stroke(card, COLORS.SlateLight, 1, 0.6)
	if titleText then
		createLabel({
			Position = UDim2.fromOffset(16, 10),
			Size = UDim2.fromOffset(w - 32, 18),
			Text = titleText,
			FontFace = FONTS.Heavy,
			TextSize = 12,
			TextColor3 = COLORS.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
	end
	return card
end

-- ANIMATIONS (panel open / close) -----------------------------------------
local function tweenOpen(p)
	p.Token += 1
	p.Holder.Visible = true
	p.Veil.BackgroundTransparency = 0
	p.Canvas.Position = UDim2.fromScale(0.5, 0.54)
	p.Pop.Scale = 0.92
	tween(p.Veil, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	tween(p.Canvas, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) })
	tween(p.Pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

local function tweenClose(p)
	p.Token += 1
	local token = p.Token
	local t = tween(p.Veil, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
	tween(p.Pop, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.94 })
	t.Completed:Connect(function()
		if p.Token == token then
			p.Holder.Visible = false
			p.Veil.BackgroundTransparency = 1
		end
	end)
end

local function showOverlay()
	overlayToken += 1
	overlay.Visible = true
	tween(overlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.45 })
end

local function hideOverlay()
	overlayToken += 1
	local token = overlayToken
	local t = tween(overlay, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
	t.Completed:Connect(function()
		if overlayToken == token then
			overlay.Visible = false
		end
	end)
end

local function closePanel()
	if currentPanel then
		tweenClose(currentPanel)
		currentPanel = nil
		hideOverlay()
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = if player:GetAttribute("HRushInMatch") == true then nil
				else if Layout.focusAvailable(priorPanelFocus) then priorPanelFocus else nil
		end
		priorPanelFocus = nil
	end
end

local function openPanel(p)
	if currentPanel == p then
		return
	end
	if currentPanel then
		tweenClose(currentPanel)
	else
		priorPanelFocus = GuiService.SelectedObject
		showOverlay()
	end
	currentPanel = p
	tweenOpen(p)
	GuiService.SelectedObject = p.Close
end

-- (PLAY panel removed: the PLAY button starts matchmaking directly)

-- SETTINGS SCREEN -----------------------------------------------------------
-- Real settings: audio volumes, VFX intensity, reduced camera effects.
-- Every control writes ClientSettings only. Audio, VFX, and gameplay read
-- the model live, so changes apply with no rejoin. Replaces the old
-- visual-only Music/SFX toggles, which never did anything.
local settingsPanel = createPanel("Settings", "SETTINGS", 520, 812)
local settingsLiveStatus = createLabel({
	Position = UDim2.new(1, -248, 0, 48),
	Size = UDim2.fromOffset(220, 22),
	Text = "",
	FontFace = FONTS.Heavy,
	TextSize = 13,
	TextColor3 = COLORS.Lime,
	TextXAlignment = Enum.TextXAlignment.Right,
}, settingsPanel.Canvas)
local settingsStep = SharedConfig.Settings.SliderStep
task.spawn(function()
	while gui.Parent do
		if currentPanel == settingsPanel and player:GetAttribute("HRushInMatch") == true then
			local endsAt = game:GetService("ReplicatedStorage"):GetAttribute("HRushPhaseEndsAt")
			local remaining = if typeof(endsAt) == "number" then math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow())) else 0
			settingsLiveStatus.Text = string.format("ROUND CONTINUES  %d:%02d", math.floor(remaining / 60), remaining % 60)
		else
			settingsLiveStatus.Text = ""
		end
		task.wait(0.25)
	end
end)
do
	local c = create("ScrollingFrame", {
		Name = "SettingsScroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, settingsPanel.Content)

	local settingsRows: { [string]: any } = {}
	local rowCards: { [string]: Instance } = {}
	local rowOrder = { "master", "music", "sfx", "vfx", "cameraSensitivity", "firstPersonFov", "reducedCamera", "invertCameraY", "showPopups", "momentumBar", "momentumSounds", "textScale", "highContrast" }
	c.CanvasSize = UDim2.fromOffset(0, #rowOrder * 84 + 112)
	local rowTitles: { [string]: string } = {
		master = "Master Volume",
		music = "Music Volume",
		sfx = "SFX Volume",
		vfx = "VFX Intensity",
		cameraSensitivity = "Camera Look Speed",
		firstPersonFov = "First-Person FOV",
		reducedCamera = "Reduce Motion",
		invertCameraY = "Invert Camera Y",
		showPopups = "Show Popups",
		momentumBar = "Momentum Bar",
		momentumSounds = "Momentum Sounds",
		textScale = "Text Size",
		highContrast = "High Contrast",
	}
	local toggleKeys: { [string]: boolean } = {
		reducedCamera = true,
		invertCameraY = true,
		showPopups = true,
		momentumBar = true,
		momentumSounds = true,
		highContrast = true,
	}

	local function sliderBounds(key: string): (number, number)
		if key == "firstPersonFov" then
			return SharedConfig.Settings.FirstPersonFovMin, SharedConfig.Settings.FirstPersonFovMax
		end
		if key == "textScale" then return 80, 130 end
		return 0, 100
	end

	local function valueFromX(key: string, track: Frame, x: number): number
		local size = track.AbsoluteSize.X
		if size <= 0 then
			return ClientSettings.get(key) :: number
		end
		local minValue, maxValue = sliderBounds(key)
		return minValue + math.clamp((x - track.AbsolutePosition.X) / size, 0, 1) * (maxValue - minValue)
	end

	local function refreshSlider(key: string)
		local row = settingsRows[key]
		if row == nil then
			return
		end
		local v = ClientSettings.get(key)
		if typeof(v) ~= "number" then
			return
		end
		-- Plain locals, never a leading parenthesis: a statement starting
		-- with "(" is ambiguous call syntax and kills this whole script.
		local fillFrame: Frame = row.fill
		local knobFrame: Frame = row.knob
		local valueLabel: TextLabel = row.value
		local minValue, maxValue = sliderBounds(key)
		local fraction = (v - minValue) / (maxValue - minValue)
		fillFrame.Size = UDim2.fromScale(fraction, 1)
		knobFrame.Position = UDim2.fromScale(fraction, 0.5)
		valueLabel.Text = tostring(math.floor(v + 0.5)) .. (if key == "firstPersonFov" then "°" else "")
	end

	local function refreshToggle(key: string)
		local row = settingsRows[key]
		if row == nil then
			return
		end
		local on = ClientSettings.get(key) == true
		tween(row.track, INFO_FAST, { BackgroundColor3 = on and COLORS.Lime or COLORS.SlateEdge })
		tween(row.knob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = on and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 18, 0.5, 0),
			BackgroundColor3 = on and COLORS.Navy or COLORS.TextDim,
		})
	end

	local function refreshRow(key: string)
		if toggleKeys[key] then
			refreshToggle(key)
		else
			refreshSlider(key)
		end
	end

	local dragKey: string? = nil
	local dragInput: InputObject? = nil
	local dragTracks: { [string]: Frame } = {}

	local function createSliderRow(index: number, key: string)
		local row = createCard(c, 0, (index - 1) * 84, 464, 76)
		row.Size = UDim2.new(1, 0, 0, 76)
		rowCards[key] = row
		stroke(row, COLORS.Lime, 2, 1) -- focus ring, shown for the selected row
		createLabel({
			Position = UDim2.fromOffset(20, 6),
			Size = UDim2.new(1, -140, 0, 24),
			Text = rowTitles[key],
			FontFace = FONTS.Bold,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local valueLabel = createLabel({
			Position = UDim2.new(1, -120, 0, 6),
			Size = UDim2.fromOffset(100, 24),
			Text = "100",
			FontFace = FONTS.Heavy,
			TextSize = 18,
			TextColor3 = COLORS.Lime,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
		local track = createFrame({
			Position = UDim2.fromOffset(20, 46),
			Size = UDim2.new(1, -40, 0, 8),
			BackgroundColor3 = COLORS.SlateEdge,
		}, row)
		corner(track, FULL)
		local fill = createFrame({
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = COLORS.Lime,
		}, track)
		corner(fill, FULL)
		local knob = createFrame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(28, 28),
			BackgroundColor3 = COLORS.Cream,
		}, track)
		corner(knob, 14)
		-- Whole card is the touch target (76 px tall): drag anywhere on it.
		local hit = createButton({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
		}, row)
		hit.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				dragKey = key
				dragInput = input
				ClientSettings.set(key, valueFromX(key, track, input.Position.X))
			end
		end)
		settingsRows[key] = { fill = fill, knob = knob, value = valueLabel }
		dragTracks[key] = track
		refreshSlider(key)
	end

	local function createToggleRow(index: number, key: string, subtitle: string)
		local row = createCard(c, 0, (index - 1) * 84, 464, 76)
		row.Size = UDim2.new(1, 0, 0, 76)
		rowCards[key] = row
		stroke(row, COLORS.Lime, 2, 1) -- focus ring, shown for the selected row
		createLabel({
			Position = UDim2.fromOffset(20, 6),
			Size = UDim2.new(1, -120, 0, 24),
			Text = rowTitles[key],
			FontFace = FONTS.Bold,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		createLabel({
			Position = UDim2.fromOffset(20, 32),
			Size = UDim2.new(1, -120, 0, 20),
			Text = subtitle,
			FontFace = FONTS.SemiBold,
			TextSize = 13,
			TextColor3 = COLORS.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local track = createButton({
			Position = UDim2.new(1, -84, 0, 22),
			Size = UDim2.fromOffset(64, 32),
			BackgroundColor3 = COLORS.SlateEdge,
			Text = "",
		}, row)
		corner(track, FULL)
		local knob = createFrame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 18, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = COLORS.TextDim,
		}, track)
		corner(knob, FULL)
		settingsRows[key] = { track = track, knob = knob }
		track.Activated:Connect(function()
			UIAudio.playUi("toggle")
			ClientSettings.set(key, not (ClientSettings.get(key) == true))
		end)
		refreshToggle(key)
	end

	for i, key in rowOrder do
		if not toggleKeys[key] then
			createSliderRow(i, key)
		end
	end

	-- Camera and reduced-camera toggle rows (camera look, reduced effects).
	createToggleRow(7, "reducedCamera", "No FOV kicks, shake, or aim camera.")
	createToggleRow(8, "invertCameraY", "Push up to look down.")
	createToggleRow(9, "showPopups", "Show momentum action text near your character.")
	createToggleRow(10, "momentumBar", "Show the bottom-center momentum meter.")
	createToggleRow(11, "momentumSounds", "Play momentum cues at your SFX volume.")
	createToggleRow(13, "highContrast", "Stronger borders and focus outlines.")

	createActionButton(c, "RESET TO DEFAULTS", "cream", 0, #rowOrder * 84 + 8, 464, 56, function()
		UIAudio.playUi("click")
		ClientSettings.reset()
	end, 16)

	createLabel({
		Position = UDim2.fromOffset(0, #rowOrder * 84 + 72),
		Size = UDim2.new(1, 0, 0, 24),
		Text = "H opens settings anywhere. DPad moves, Left and Right adjust.",
		FontFace = FONTS.SemiBold,
		TextSize = 13,
		TextColor3 = COLORS.TextDim,
	}, c)

	-- Live refresh: model changes (drag, gamepad, reset) repaint the rows.
	ClientSettings.Changed:Connect(function(key: unknown, _value: unknown)
		if typeof(key) ~= "string" then
			return
		end
		refreshRow(key)
	end)

	-- Gamepad focus: DPad moves between rows, Left/Right adjusts. Thumbsticks
	-- are never captured, so the character keeps simulating underneath.
	local focused = 1
	local function refreshFocus()
		c.CanvasPosition = Vector2.new(0, math.max(0, (focused - 4) * 84))
		for i, key in rowOrder do
			local card = rowCards[key]
			if card then
				for _, child in card:GetChildren() do
					if child:IsA("UIStroke") then
						child.Transparency = if i == focused then 0 else 1
					end
				end
			end
		end
	end

	-- Cross-script bridge: the HUD gear (UIController) and the H key toggle
	-- through this event; opening fires the aim-cancel event for Movement.
	local function settingsEvent(name: string): BindableEvent
		local rs = game:GetService("ReplicatedStorage")
		local existing = rs:FindFirstChild(name)
		if existing and existing:IsA("BindableEvent") then
			return existing
		end
		local be = Instance.new("BindableEvent")
		be.Name = name
		be.Parent = rs
		return be
	end
	local toggleEvent = settingsEvent("HRushSettingsToggle")
	local openedEvent = settingsEvent("HRushSettingsOpened")

	local function openSettings()
		openPanel(settingsPanel)
		focused = 1
		refreshFocus()
		for _, key in rowOrder do
			refreshRow(key)
		end
		openedEvent:Fire()
	end

	local function toggleSettings()
		if currentPanel == settingsPanel then
			closePanel()
		else
			openSettings()
		end
	end
	toggleEvent.Event:Connect(function()
		toggleSettings()
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragKey == nil then
			return
		end
		if (input.UserInputType == Enum.UserInputType.MouseMovement
			and dragInput ~= nil and dragInput.UserInputType == Enum.UserInputType.MouseButton1)
			or input == dragInput then
			local track = dragTracks[dragKey]
			if track then
				ClientSettings.set(dragKey, valueFromX(dragKey, track, input.Position.X))
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == dragInput then
			dragKey = nil
			dragInput = nil
			UIAudio.playUi("sliderEnd")
		end
	end)

	-- H opens settings anywhere, ButtonSelect on gamepad. Always Pass: movement
	-- input is never sunk, so the match keeps simulating under the panel.
	ContextActionService:BindAction("HRUSH_Settings", function(_name, state, _obj)
		if state == Enum.UserInputState.Begin then
			toggleSettings()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.H, Enum.KeyCode.ButtonSelect)

	ContextActionService:BindAction("HRUSH_SettingsNav", function(_name, state, input)
		if currentPanel ~= settingsPanel then
			return Enum.ContextActionResult.Pass
		end
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Sink
		end
		local kc = input.KeyCode
		if kc == Enum.KeyCode.DPadUp then
			focused = if focused <= 1 then #rowOrder else focused - 1
			refreshFocus()
		elseif kc == Enum.KeyCode.DPadDown then
			focused = if focused >= #rowOrder then 1 else focused + 1
			refreshFocus()
		elseif kc == Enum.KeyCode.DPadLeft or kc == Enum.KeyCode.DPadRight then
			local key = rowOrder[focused]
			local dir = if kc == Enum.KeyCode.DPadRight then 1 else -1
			if toggleKeys[key] then
				ClientSettings.set(key, not (ClientSettings.get(key) == true))
			else
				local v = ClientSettings.get(key)
				if typeof(v) == "number" then
					local step = if key == "firstPersonFov" then SharedConfig.Settings.FirstPersonFovStep else settingsStep
					ClientSettings.set(key, v + dir * step)
				end
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.DPadUp, Enum.KeyCode.DPadDown, Enum.KeyCode.DPadLeft, Enum.KeyCode.DPadRight)
end

-- GAME MODES PANEL -----------------------------------------------------------
local function updatePlayModeChip()
	if playModeChipLabel then
		playModeChipLabel.Text = "VOTE AFTER MATCHMAKING"
	end
end

gameModesPanel = createPanel("GameModes", "GAME MODES", 720, 478)
local desktopModeCards: { Frame } = {}
local mobileModesScroll: ScrollingFrame? = nil

	-- drawn preview art (palette-consistent), one per mode card
	local function artCourt(frame)
		-- barangay street + court for the banner width
		frame.BackgroundColor3 = Color3.fromRGB(62, 124, 74)
		local road = createFrame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 0, 0.34, 0),
			BackgroundColor3 = Color3.fromRGB(70, 74, 78),
		}, frame)
		for i = 0, 7 do
			createFrame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.09 + i * 0.12, 0.5),
				Size = UDim2.fromOffset(22, 4),
				BackgroundColor3 = Color3.fromRGB(240, 236, 210),
				BackgroundTransparency = 0.2,
			}, road)
		end
		local court = createFrame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.32),
			Size = UDim2.fromOffset(150, 44),
			BackgroundColor3 = Color3.fromRGB(160, 110, 72),
		}, frame)
		corner(court, 5)
		createFrame({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Color3.fromRGB(255, 230, 180),
			BackgroundTransparency = 0.4,
		}, court)
		local ring = createFrame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
		}, court)
		stroke(ring, Color3.fromRGB(255, 230, 180), 1.5, 0.4)
		corner(ring, 10)
	end

	local function artFreeze(frame)
		frame.BackgroundColor3 = Color3.fromRGB(88, 150, 192)
		create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(178, 224, 246), Color3.fromRGB(70, 130, 178)),
			Rotation = 60,
		}, frame)
		for _, pos in ipairs({ Vector2.new(0.14, 0.3), Vector2.new(0.84, 0.26), Vector2.new(0.08, 0.76), Vector2.new(0.9, 0.7), Vector2.new(0.3, 0.16), Vector2.new(0.68, 0.84) }) do
			local shard = createFrame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(pos.X, pos.Y),
				Size = UDim2.fromOffset(12, 12),
				BackgroundColor3 = Color3.fromRGB(235, 250, 255),
				Rotation = 45,
			}, frame)
			corner(shard, 3)
		end
		for _, rot in ipairs({ 0, 60, 120 }) do
			local bar = createFrame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(38, 5),
				BackgroundColor3 = Color3.fromRGB(244, 252, 255),
				Rotation = rot,
			}, frame)
			corner(bar, 3)
		end
	end

	local function artElimination(frame)
		frame.BackgroundColor3 = Color3.fromRGB(40, 22, 30)
		create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(64, 32, 42), Color3.fromRGB(22, 12, 18)),
			Rotation = 90,
		}, frame)
		-- faded elimination rings trailing across the banner
		for _, pos in ipairs({ Vector2.new(0.18, 0.5), Vector2.new(0.82, 0.5) }) do
			local faded = createFrame({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(pos.X, pos.Y),
				Size = UDim2.fromOffset(40, 40),
				BackgroundTransparency = 1,
			}, frame)
			stroke(faded, Color3.fromRGB(235, 64, 64), 2, 0.55)
			corner(faded, 20)
		end
		local ring = createFrame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(54, 54),
			BackgroundTransparency = 1,
		}, frame)
		stroke(ring, Color3.fromRGB(235, 64, 64), 4)
		corner(ring, 27)
		createFrame({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.fromOffset(8, 20),
			BackgroundColor3 = Color3.fromRGB(246, 190, 50),
		}, ring)
		local dot = createFrame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.68),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Color3.fromRGB(246, 190, 50),
		}, ring)
		corner(dot, 4)
	end
do
	local c = gameModesPanel.Content -- 664 x 352

	local MODE_INFO = {
		ClassicTag = {
			title = "CLASSIC TAG", tag = "PLAYABLE", art = artCourt,
			desc = "Tag changes the Taya. Three rounds with a Bato Bato Pick start.",
			win = "WIN: Lowest total Taya time.",
		},
		AgawanNgPanyo = {
			title = "AGAWAN NG PANYO", tag = "PLAYABLE", art = artCourt,
			desc = "Pick up the panyo, hold it, and steal it from the carrier.",
			win = "WIN: Most possession time, then steals.",
		},
		SecretHunt = {
			title = "LIHIM NA TARGET", tag = "PLAYABLE", art = artCourt,
			desc = "Find your private target and capture them to get new assignments.",
			win = "WIN: Most captures, then best streak.",
		},
	}

	-- Mode choice happens only on the server ballot after matchmaking.

	local CARD_W, CARD_H = 208, 344
	for idx, m in ipairs(GAME_MODES) do
		local info = MODE_INFO[m.id]
		local card = createCard(c, (idx - 1) * (CARD_W + 20), 0, CARD_W, CARD_H)
		table.insert(desktopModeCards, card)
		local cardStroke = stroke(card, COLORS.SlateLight, 1, 0.6)

		-- preview banner across the top of the card (map-vote style)
		local picture = createFrame({
			Position = UDim2.fromOffset(11, 11),
			Size = UDim2.fromOffset(CARD_W - 22, 84),
			BackgroundColor3 = COLORS.SlateEdge,
			ClipsDescendants = true,
		}, card)
		corner(picture, 10)
		info.art(picture)

		-- status chip riding the banner (top-right)
		local chip = createFrame({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromOffset(CARD_W - 17, 17),
			Size = UDim2.fromOffset(96, 16),
			BackgroundColor3 = m.locked and COLORS.SlateDark or COLORS.Lime,
			ZIndex = 7,
		}, card)
		corner(chip, 8)
		createLabel({
			Size = UDim2.fromScale(1, 1),
			Text = if m.locked then "UNAVAILABLE" else info.tag,
			FontFace = FONTS.Heavy,
			TextSize = 8,
			TextColor3 = m.locked and COLORS.TextDim or COLORS.Navy,
			ZIndex = 8,
		}, chip)

		if m.locked then
			local dim = createFrame({
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = COLORS.Navy,
				BackgroundTransparency = 0.45,
				ZIndex = 5,
			}, picture)
			createLabel({
				Size = UDim2.fromScale(1, 1),
				Text = "COMING SOON",
				FontFace = FONTS.Heavy,
				TextSize = 13,
				TextColor3 = COLORS.TextDim,
				ZIndex = 6,
			}, dim)
		end

		-- mode name (no GM_ prefix), wraps to two lines on a portrait card
		createLabel({
			Position = UDim2.fromOffset(12, 102),
			Size = UDim2.fromOffset(CARD_W - 24, 46),
			Text = info.title,
			FontFace = FONTS.Display,
			TextSize = 19,
			TextColor3 = m.locked and COLORS.TextDim or COLORS.White,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		}, card)

		-- rule summary
		createLabel({
			Position = UDim2.fromOffset(12, 152),
			Size = UDim2.fromOffset(CARD_W - 24, 74),
			Text = info.desc,
			FontFace = FONTS.SemiBold,
			TextSize = 10,
			TextColor3 = COLORS.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		}, card)

		-- win condition
		createLabel({
			Position = UDim2.fromOffset(12, 230),
			Size = UDim2.fromOffset(CARD_W - 24, 40),
			Text = info.win,
			FontFace = FONTS.Heavy,
			TextSize = 9,
			TextColor3 = m.locked and COLORS.TextDim or COLORS.Lime,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		}, card)

		-- full-width action at the bottom; locked modes show a chip
		if m.locked then
			local lockedChip = createFrame({
				Position = UDim2.fromOffset(11, CARD_H - 42),
				Size = UDim2.fromOffset(CARD_W - 22, 30),
				BackgroundColor3 = COLORS.SlateEdge,
			}, card)
			corner(lockedChip, 8)
			createLabel({
				Size = UDim2.fromScale(1, 1),
				Text = "LOCKED",
				FontFace = FONTS.Heavy,
				TextSize = 11,
				TextColor3 = COLORS.TextDim,
			}, lockedChip)
		else
			createLabel({
				Position = UDim2.fromOffset(11, CARD_H - 46),
				Size = UDim2.fromOffset(CARD_W - 22, 36),
				Text = "VOTE AFTER MATCHMAKING",
				FontFace = FONTS.Heavy,
				TextSize = 12,
				TextColor3 = COLORS.Lime,
			}, card)
		end
	end
	local scroll = create("ScrollingFrame", {
		Name = "PhoneModeList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, c) :: ScrollingFrame
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	for index, mode in ipairs(GAME_MODES) do
		local info = MODE_INFO[mode.id]
		local row = createCard(scroll, 0, 0, 1, 112)
		row.LayoutOrder = index
		row.Size = UDim2.new(1, -8, 0, 112)
		createLabel({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), Text = info.title,
			FontFace = FONTS.Display, TextSize = 18, TextColor3 = COLORS.Cream, TextXAlignment = Enum.TextXAlignment.Left }, row)
		createLabel({ Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 40), Text = info.desc,
			FontFace = FONTS.SemiBold, TextSize = 13, TextColor3 = COLORS.TextDim, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left }, row)
		createLabel({ Position = UDim2.fromOffset(12, 79), Size = UDim2.new(1, -24, 0, 26), Text = info.win,
			FontFace = FONTS.Heavy, TextSize = 13, TextColor3 = COLORS.Lime, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left }, row)
	end
	mobileModesScroll = scroll

end

-- PROFILE PANEL -------------------------------------------------------------
local profilePanel = createPanel("Profile", "PROFILE", 600, 400)
local profileCard: Frame? = nil
local profileAvatar: Frame? = nil
local profileName: TextLabel? = nil
local profileUsername: TextLabel? = nil
local profileDescription: TextLabel? = nil
do
	local c = profilePanel.Content -- 544 x 282
	local left = createCard(c, 0, 0, 190, 282)
	profileCard = left
	local avatarBox = createFrame({
		Position = UDim2.fromOffset(25, 24),
		Size = UDim2.fromOffset(140, 140),
		BackgroundColor3 = COLORS.Orange,
	}, left)
	profileAvatar = avatarBox
	corner(avatarBox, 16)
	local img = create("ImageLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = "",
	}, avatarBox)
	corner(img, 16)
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and content then
			img.Image = content
		end
	end)
	profileName = createLabel({
		Position = UDim2.fromOffset(10, 180),
		Size = UDim2.fromOffset(170, 26),
		Text = displayName,
		FontFace = FONTS.Bold,
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, left)
	profileUsername = createLabel({
		Position = UDim2.fromOffset(10, 208),
		Size = UDim2.fromOffset(170, 18),
		Text = "@" .. player.Name,
		FontFace = FONTS.Heavy,
		TextSize = 12,
		TextColor3 = COLORS.Lime,
	}, left)

	profileDescription = createLabel({
		Position = UDim2.fromOffset(210, 26),
		Size = UDim2.fromOffset(320, 64),
		Text = "Your Roblox identity is used in matches. Match stats are shown in round and match results.",
		FontFace = FONTS.SemiBold,
		TextSize = 16,
		TextColor3 = COLORS.TextDim,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, c)
end

-- COLLECTION PANEL ----------------------------------------------------------
local collectionPanel = createPanel("Collection", "COLLECTION", 680, 460)
do
	local c = collectionPanel.Content -- 624 x 342
	local scroll = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.SlateLight,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, c)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(112, 112),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)
	create("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, scroll)
	for i = 1, 15 do
		local slot = createFrame({ LayoutOrder = i, BackgroundColor3 = COLORS.Slate }, scroll)
		corner(slot, 12)
		stroke(slot, COLORS.SlateLight, 1, 0.6)
		createLabel({
			Size = UDim2.new(1, 0, 0.6, 0),
			Text = "?",
			FontFace = FONTS.Display,
			TextSize = 40,
			TextColor3 = COLORS.SlateLight,
		}, slot)
		createLabel({
			Position = UDim2.fromScale(0, 0.62),
			Size = UDim2.new(1, 0, 0.3, 0),
			Text = "LOCKED",
			FontFace = FONTS.Heavy,
			TextSize = 11,
			TextColor3 = COLORS.TextDim,
		}, slot)
	end
end

-- SHOP PANEL ----------------------------------------------------------------
local shopPanel = createPanel("Shop", "SHOP", 680, 460)
do
	local c = shopPanel.Content
	local scroll = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = COLORS.SlateLight,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, c)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(196, 160),
		CellPadding = UDim2.fromOffset(18, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, scroll)
	for i = 1, 6 do
		local card = createFrame({ LayoutOrder = i, BackgroundColor3 = COLORS.Slate }, scroll)
		corner(card, 12)
		stroke(card, COLORS.SlateLight, 1, 0.6)
		local preview = createFrame({
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 78),
			BackgroundColor3 = COLORS.SlateEdge,
			BackgroundTransparency = 0.3,
		}, card)
		corner(preview, 8)
		createLabel({
			Position = UDim2.fromOffset(12, 94),
			Size = UDim2.new(1, -24, 0, 18),
			Text = "ITEM " .. i,
			FontFace = FONTS.Bold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
		local tag = createFrame({
			Position = UDim2.fromOffset(12, 118),
			Size = UDim2.new(1, -24, 0, 28),
			BackgroundColor3 = COLORS.SlateLight,
		}, card)
		corner(tag, 8)
		createLabel({
			Size = UDim2.fromScale(1, 1),
			Text = "COMING SOON",
			FontFace = FONTS.Heavy,
			TextSize = 11,
			TextColor3 = COLORS.TextDim,
		}, tag)
	end
end

--------------------------------------------------------------------------
-- BUTTON EVENTS
--------------------------------------------------------------------------
local helpPanel = createPanel("Help", "HELP / CONTROLS", 640, 520)
do
	local scroll = create("ScrollingFrame", {
		Name = "HelpScroll", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, helpPanel.Content)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	local help = {
		"FIND MATCH opens the real mode ballot. The lobby cards describe the modes.",
		"Lobby: walk and jump freely. Press Z, gamepad Y, or tap VIEW to switch camera. DPad Down focuses the menu; B returns to roaming.",
		"Classic Tag: click, R2, or TAG to tag. Lowest total Taya time wins.",
		"Agawan ng Panyo: hold near the cloth to pick it up; STEAL the carrier. Longest hold wins.",
		"Lihim na Target: CAPTURE only your private target. Most captures wins.",
		"Chain two slides or landing rolls to sprint automatically for three seconds.",
	}
	for index, line in help do
		local card = createCard(scroll, 0, 0, 584, 66)
		card.LayoutOrder = index
		card.Size = UDim2.new(1, -8, 0, 66)
		createLabel({
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -24, 1, -16),
			Text = line,
			FontFace = FONTS.SemiBold,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
	end
end
-- The main action starts matchmaking and cancels while searching.
bindButton(playButton, playHolderScale, function()
	UIAudio.playUi("click")
	local q = player:GetAttribute("HRushQueue") or "Idle"
	if QueueEvent and q == "Idle" then
		QueueEvent:FireServer("Play")
	elseif QueueEvent and q == "Searching" then
		QueueEvent:FireServer("Cancel")
	end
end, 1.04, 0.96)
bindButton(tutorialButton, create("UIScale", {}, tutorialButton), function()
	if TutorialEvent then TutorialEvent:FireServer("Start") end
end, 1.04, 0.96)
bindButton(cancelButton, create("UIScale", {}, cancelButton), function()
	if QueueEvent then QueueEvent:FireServer("Cancel") end
end, 1.04, 0.96)

bindButton(settingsButton, settingsHolderScale, function()
	UIAudio.playUi("click")
	openPanel(settingsPanel)
end, 1.08, 0.92)

bindButton(gmButton, gmScale, function()
	openPanel(gameModesPanel)
end, 1.08, 0.92)

bindButton(navButtons.Profile.Button, navButtons.Profile.Scale, function()
	openPanel(profilePanel)
end, 1.06, 0.94)
bindButton(navButtons.Help.Button, navButtons.Help.Scale, function()
	openPanel(helpPanel)
end, 1.06, 0.94)

overlay.Activated:Connect(closePanel)
for _, p in pairs(panels) do
	p.Close.Activated:Connect(closePanel)
end

-- gentle idle nudge on the PLAY chevron
tween(chevronLabel, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	Position = UDim2.fromOffset(222, 0),
})

--------------------------------------------------------------------------
-- PLAY BUTTON QUEUE STATE
-- Idle -> "PLAY" | Searching -> "SEARCHING Ns / TAP TO CANCEL" | InMatch / Busy.
-- Driven by the MatchService attributes (HRushQueue / HRushSearchEndsAt).
--------------------------------------------------------------------------
local queueStateToken = 0
local prevQueue = "Idle"
local function refreshPlayButton()
	queueStateToken += 1
	local token = queueStateToken
	local q = player:GetAttribute("HRushQueue") or "Idle"
	if prevQueue ~= q then
		if q == "Idle" and prevQueue == "Searching" then
			UIAudio.playUi("queueCancel")
		elseif q == "InMatch" then
			UIAudio.playUi("matchFound")
		end
		prevQueue = q
	end
	if q == "Searching" then
		cancelButton.Visible = true
		playButton.Active = true
		playText.Position = UDim2.fromOffset(84, 10)
		playText.Size = UDim2.fromOffset(190, 44)
		playText.TextSize = 36
		cancelHint.TextTransparency = 0.25
		chevronLabel.TextTransparency = 1
		task.spawn(function()
			while token == queueStateToken and gui.Parent do
				local endsAt = player:GetAttribute("HRushSearchEndsAt")
				local left = (typeof(endsAt) == "number") and math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow())) or 10
				playText.Text = "SEARCHING " .. left .. "s"
				task.wait(0.25)
			end
		end)
	elseif q == "InMatch" then
		cancelButton.Visible = false
		playText.Position = UDim2.fromOffset(84, 0)
		playText.Size = UDim2.fromOffset(190, 89)
		playText.TextSize = 40
		playText.Text = "STARTING..."
		cancelHint.TextTransparency = 1
		chevronLabel.TextTransparency = 1
	elseif q == "Busy" then
		cancelButton.Visible = false
		playText.Position = UDim2.fromOffset(66, 0)
		playText.Size = UDim2.fromOffset(220, 89)
		playText.TextSize = 30
		playText.Text = "MATCH IN PROGRESS"
		cancelHint.TextTransparency = 1
		chevronLabel.TextTransparency = 1
	else
		cancelButton.Visible = false
		playButton.Active = true
		playText.Position = UDim2.fromOffset(88, 0)
		playText.Size = UDim2.fromOffset(186, 89)
		playText.TextSize = 32
		playText.Text = "FIND MATCH"
		cancelHint.TextTransparency = 1
		chevronLabel.TextTransparency = 0
	end
end
player:GetAttributeChangedSignal("HRushQueue"):Connect(refreshPlayButton)
player:GetAttributeChangedSignal("HRushSearchEndsAt"):Connect(refreshPlayButton)
refreshPlayButton()

-- Compact lobby uses full-size touch targets while leaving the world visible.
local phoneLobby = createFrame({
	Name = "PhoneLobby",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
local function phoneButton(name: string, caption: string, position: UDim2, size: UDim2, accent: boolean): TextButton
	local button = createButton({
		Name = name, Position = position, Size = size, BackgroundColor3 = if accent then COLORS.Lime else COLORS.Slate,
		Text = caption, FontFace = FONTS.Heavy, TextSize = 16,
		TextColor3 = if accent then COLORS.Navy else COLORS.Cream,
	}, phoneLobby) :: TextButton
	corner(button, 12)
	stroke(button, accent and COLORS.Cream or COLORS.TextDim, 2, 0.15)
	Theme.focus(button)
	return button
end
createLabel({
	Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(220, 44), Text = "HABULAN RUSH",
	FontFace = FONTS.Display, TextSize = 27, TextColor3 = COLORS.Lime,
	TextXAlignment = Enum.TextXAlignment.Left,
}, phoneLobby)
local phoneSettings = phoneButton("Settings", "SET", UDim2.new(1, -12, 0, 8), UDim2.fromOffset(64, 64), false)
phoneSettings.AnchorPoint = Vector2.new(1, 0)
local phoneProfile = phoneButton("Profile", "ME", UDim2.new(1, -84, 0, 8), UDim2.fromOffset(64, 64), false)
phoneProfile.AnchorPoint = Vector2.new(1, 0)
local phoneHelp = phoneButton("Help", "?", UDim2.new(1, -156, 0, 8), UDim2.fromOffset(64, 64), false)
phoneHelp.AnchorPoint = Vector2.new(1, 0)
local phoneModeInfo = phoneButton("ModeInfo", "VOTE AFTER MATCHMAKING\nCLASSIC  /  PANYO  /  HUNT",
	UDim2.new(0.5, 0, 0, 78), UDim2.fromOffset(280, 64), false)
phoneModeInfo.AnchorPoint = Vector2.new(0.5, 0)
phoneModeInfo.TextSize = 14
phoneModeInfo.TextWrapped = true
local phonePlay = phoneButton("FindMatch", "FIND MATCH", UDim2.fromScale(0.5, 0.56), UDim2.fromOffset(250, 64), true)
phonePlay.AnchorPoint = Vector2.new(0.5, 0.5)
phonePlay.FontFace = FONTS.Display
phonePlay.TextSize = 28
local phoneTutorial = phoneButton("Tutorial", "LEARN TO PLAY", UDim2.fromScale(0.5, 0.75), UDim2.fromOffset(250, 56), false)
phoneTutorial.AnchorPoint = Vector2.new(0.5, 0.5)
local phoneCancel = phoneButton("CancelSearch", "CANCEL SEARCH", UDim2.fromScale(0.5, 0.76), UDim2.fromOffset(250, 64), false)
phoneCancel.AnchorPoint = Vector2.new(0.5, 0.5)
phoneCancel.Visible = false
local phoneParty = createLabel({
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -82), Size = UDim2.fromOffset(190, 24),
	Text = "PARTY", FontFace = FONTS.Heavy, TextSize = 14, TextColor3 = COLORS.Cream,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, phoneLobby)
local phoneInvite = phoneButton("Invite", "INV", UDim2.new(0, 12, 1, -12), UDim2.fromOffset(64, 64), false)
phoneInvite.AnchorPoint = Vector2.new(0, 1)
local phoneLeave = phoneButton("Leave", "EXIT", UDim2.new(0, 84, 1, -12), UDim2.fromOffset(64, 64), false)
phoneLeave.AnchorPoint = Vector2.new(0, 1)
local viewTouch = createButton({
	Name = "LobbyView", Position = UDim2.fromOffset(12, 156), Size = UDim2.fromOffset(72, 52),
	BackgroundColor3 = COLORS.Slate, Text = "VIEW\n3RD", TextWrapped = true,
	FontFace = FONTS.Heavy, TextSize = 14, TextColor3 = COLORS.Cream,
	Visible = false,
}, gui) :: TextButton
corner(viewTouch, 10)
stroke(viewTouch, COLORS.TextDim, 2, 0.15)
Theme.focus(viewTouch)
phonePlay.Activated:Connect(function()
	if not QueueEvent then return end
	local queue = player:GetAttribute("HRushQueue")
	if queue == "Idle" then QueueEvent:FireServer("Play")
	elseif queue == "Searching" then QueueEvent:FireServer("Cancel") end
end)
phoneTutorial.Activated:Connect(function()
	if TutorialEvent then TutorialEvent:FireServer("Start") end
end)
phoneCancel.Activated:Connect(function()
	if QueueEvent then QueueEvent:FireServer("Cancel") end
end)
phoneSettings.Activated:Connect(function() openPanel(settingsPanel) end)
phoneProfile.Activated:Connect(function() openPanel(profilePanel) end)
phoneHelp.Activated:Connect(function() openPanel(helpPanel) end)
phoneModeInfo.Activated:Connect(function() openPanel(gameModesPanel) end)
phoneInvite.Activated:Connect(function() onInvitePressed() end)
phoneLeave.Activated:Connect(function()
	if PartyEvent then PartyEvent:FireServer("Leave") end
end)
phoneModeInfo.NextSelectionDown = phonePlay
phonePlay.NextSelectionUp = phoneModeInfo
phonePlay.NextSelectionDown = phoneCancel
phoneCancel.NextSelectionUp = phonePlay
phoneTutorial.NextSelectionUp = phonePlay
phoneTutorial.NextSelectionDown = phoneInvite
task.spawn(function()
	while phoneLobby.Parent do
		local queue = player:GetAttribute("HRushQueue") or "Idle"
		phoneCancel.Visible = queue == "Searching"
		phoneTutorial.Visible = queue == "Idle" and player:GetAttribute("HRushTutorialTeleporting") ~= true
		tutorialButton.Visible = phoneTutorial.Visible
		phonePlay.NextSelectionDown = if phoneCancel.Visible then phoneCancel else phoneTutorial
		phonePlay.Active = queue == "Idle" or queue == "Searching"
		phonePlay.TextSize = if queue == "Busy" then 20 else 28
		if queue == "Searching" then
			local endsAt = player:GetAttribute("HRushSearchEndsAt")
			local seconds = if typeof(endsAt) == "number" then math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow())) else 0
			phonePlay.Text = "CANCEL SEARCH (" .. tostring(seconds) .. "s)"
			phonePlay.TextSize = 19
		elseif queue == "Idle" then phonePlay.Text = "FIND MATCH"
		elseif queue == "Busy" then phonePlay.Text = "MATCH IN PROGRESS"
		else phonePlay.Text = "MATCH STARTING" end
		local leader = player:GetAttribute("HRushPartyLeader") or player.UserId
		local names = {}
		for _, member in Players:GetPlayers() do
			if (member:GetAttribute("HRushPartyLeader") or member.UserId) == leader then table.insert(names, member.DisplayName) end
		end
		phoneParty.Text = "PARTY: " .. table.concat(names, ", ")
		phoneLeave.Visible = #names > 1
		task.wait(0.25)
	end
end)

--------------------------------------------------------------------------
-- CAMERA
--------------------------------------------------------------------------
local isPortrait = false
local originalCameraMode = player.CameraMode
local originalMinZoom = player.CameraMinZoomDistance
local originalMaxZoom = player.CameraMaxZoomDistance

local function setupLobbyCamera()
	if not CONFIG.EnableLobbyCamera or player:GetAttribute("HRushInMatch") == true then
		return
	end

	if CONFIG.HideDefaultCoreGui then
		task.spawn(function()
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
		end)
	end

	local firstPerson = ClientSettings.get("cameraViewMode") == "FirstPerson"
	local distance = SharedConfig.Camera.ThirdPersonDistance
	player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, distance)
	player.CameraMinZoomDistance = distance
	player.CameraMaxZoomDistance = distance
	player.CameraMode = if firstPerson then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
	viewTouch.Text = if firstPerson then "VIEW\n1ST" else "VIEW\n3RD"
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.FieldOfView = if firstPerson then ClientSettings.get("firstPersonFov") :: number
			else SharedConfig.Camera.BaseFov
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid then cam.CameraSubject = humanoid end
	end
end

local function toggleLobbyView()
	if player:GetAttribute("HRushInMatch") == true or player:GetAttribute("HRushState") ~= "MS_01"
		or currentPanel ~= nil or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil then return end
	local nextMode = if ClientSettings.get("cameraViewMode") == "FirstPerson" then "ThirdPerson" else "FirstPerson"
	ClientSettings.set("cameraViewMode", nextMode)
end

viewTouch.Activated:Connect(toggleLobbyView)
ClientSettings.Changed:Connect(function(key: unknown)
	if key == "cameraViewMode" or key == "firstPersonFov" then setupLobbyCamera() end
end)

ContextActionService:BindAction("HRUSH_LobbyView", function(_name, state, _input)
	if state ~= Enum.UserInputState.Begin or player:GetAttribute("HRushInMatch") == true
		or player:GetAttribute("HRushState") ~= "MS_01" then
		return Enum.ContextActionResult.Pass
	end
	if currentPanel ~= nil or GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end
	toggleLobbyView()
	return Enum.ContextActionResult.Sink
end, false, SharedConfig.Camera.FirstPerson.ToggleKey, SharedConfig.Camera.FirstPerson.ToggleGamepad)

ContextActionService:BindAction("HRUSH_LobbyMenuFocus", function(_name, state, input)
	if state ~= Enum.UserInputState.Begin or player:GetAttribute("HRushInMatch") == true
		or player:GetAttribute("HRushState") ~= "MS_01" or currentPanel ~= nil then
		return Enum.ContextActionResult.Pass
	end
	if input.KeyCode == Enum.KeyCode.DPadDown and GuiService.SelectedObject == nil then
		GuiService.SelectedObject = if Layout.compact() then phonePlay else playButton
		return Enum.ContextActionResult.Sink
	elseif input.KeyCode == Enum.KeyCode.ButtonB and GuiService.SelectedObject ~= nil
		and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.DPadDown, Enum.KeyCode.ButtonB)

--------------------------------------------------------------------------
-- RESPONSIVE UI
--------------------------------------------------------------------------
local function setupResponsiveUI()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1380, 778)
	isPortrait = vp.Y > vp.X
	local touch = UserInputService.TouchEnabled
	viewTouch.Position = if isPortrait then UDim2.fromOffset(12, 156) else UDim2.fromOffset(12, 80)

	local s
	if isPortrait then
		s = vp.X / 520
	else
		s = math.min(vp.X / 1380, vp.Y / 778)
		if touch then
			s = s * 1.3
		end
	end
	s = math.clamp(s, 0.4, 2)

	for _, g in ipairs(groups) do
		g.Scale.Scale = if touch and g.Frame == playGroup then math.max(s, 0.73) else s
		g.Frame.AnchorPoint = isPortrait and g.PAnchor or g.LAnchor
		g.Frame.Position = isPortrait and g.PPos or g.LPos
		g.Frame.Visible = player:GetAttribute("HRushInMatch") ~= true and not Layout.compact()
	end
	phoneLobby.Visible = player:GetAttribute("HRushInMatch") ~= true and Layout.compact()
	cancelButton.Size = UDim2.fromOffset(281, if touch then 88 else 34)

	for _, p in pairs(panels) do
		if (p == settingsPanel or p == gameModesPanel or p == helpPanel or p == profilePanel) and Layout.compact() then
			p.Fit.Scale = 1
			p.Holder.Size = UDim2.new(1, -24, 1, -24)
			p.Content.Size = UDim2.new(1, -56, 1, -118)
		else
			p.Holder.Size = UDim2.fromOffset(p.Width, p.Height)
			p.Content.Size = UDim2.fromOffset(p.Width - 56, p.Height - 118)
			p.Fit.Scale = math.clamp(math.min(vp.X * 0.94 / p.Width, vp.Y * 0.9 / p.Height), 0.35, 1.4)
		end
	end
	local compact = Layout.compact()
	for _, card in desktopModeCards do card.Visible = not compact end
	if mobileModesScroll then mobileModesScroll.Visible = compact end
	if profileCard and profileAvatar and profileName and profileUsername and profileDescription then
		profileCard.Size = if compact then UDim2.new(1, 0, 0, 128) else UDim2.fromOffset(190, 282)
		profileAvatar.Position = if compact then UDim2.fromOffset(12, 12) else UDim2.fromOffset(25, 24)
		profileAvatar.Size = UDim2.fromOffset(if compact then 80 else 140, if compact then 80 else 140)
		profileName.Position = if compact then UDim2.fromOffset(104, 22) else UDim2.fromOffset(10, 180)
		profileName.Size = if compact then UDim2.new(1, -116, 0, 30) else UDim2.fromOffset(170, 26)
		profileUsername.Position = if compact then UDim2.fromOffset(104, 55) else UDim2.fromOffset(10, 208)
		profileUsername.Size = if compact then UDim2.new(1, -116, 0, 24) else UDim2.fromOffset(170, 18)
		profileDescription.Position = if compact then UDim2.fromOffset(0, 145) else UDim2.fromOffset(210, 26)
		profileDescription.Size = if compact then UDim2.new(1, 0, 0, 64) else UDim2.fromOffset(320, 64)
	end
end

local lobbyViewportConnection: RBXScriptConnection? = nil
local function watchViewport()
	if lobbyViewportConnection then lobbyViewportConnection:Disconnect() lobbyViewportConnection = nil end
	local cam = workspace.CurrentCamera
	if cam then
		lobbyViewportConnection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(setupResponsiveUI)
	end
end

watchViewport()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchViewport()
	setupResponsiveUI()
	setupLobbyCamera()
end)
setupResponsiveUI()

--------------------------------------------------------------------------
-- MATCH INTEGRATION (lobby <-> match gate)
-- Keep only the settings panel available during a match; lobby controls stay hidden.
--------------------------------------------------------------------------
local function enableControls()
	task.spawn(function()
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5))
		end)
		if ok and module then
			pcall(function()
				local controls = module:GetControls()
				controls:Enable()
			end)
		end
	end)
end

local function applyMatchGate()
	local inMatch = player:GetAttribute("HRushInMatch") == true

	for _, group in groups do
		group.Frame.Visible = not inMatch and not Layout.compact()
	end
	phoneLobby.Visible = not inMatch and Layout.compact()
	viewTouch.Visible = not inMatch and UserInputService.TouchEnabled
	pickerHolder.Visible = false
	for _, panel in pairs(panels) do
		panel.Token += 1
		panel.Holder.Visible = false
	end
	currentPanel = nil
	priorPanelFocus = nil
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	overlayToken += 1
	overlay.Visible = false
	gui.DisplayOrder = if inMatch then Theme.Layers.Settings else Theme.Layers.Lobby
	gui.Enabled = true

	pcall(function()
		RunService:UnbindFromRenderStep("HabulanLobbyCamera")
	end)

	if inMatch then
		closePanel()
		player.CameraMode = originalCameraMode
		player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, originalMaxZoom)
		player.CameraMinZoomDistance = originalMinZoom
		player.CameraMaxZoomDistance = originalMaxZoom
		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Custom
			cam.FieldOfView = SharedConfig.Camera.BaseFov
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
		end
	else
		setupLobbyCamera()
		task.defer(setupLobbyCamera) -- run after CameraDirector releases its match camera
	end
	enableControls()
end

player:GetAttributeChangedSignal("HRushInMatch"):Connect(applyMatchGate)
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	applyMatchGate()
end)
applyMatchGate()

--------------------------------------------------------------------------
-- LOADING SCREEN (match found -> arena reveal)
-- Shown while match creation is in progress. It closes for map vote and MS_RPS.
--------------------------------------------------------------------------
local LOADING_WAIT_STATES = { MS_01 = true }
local LOADING_MIN_SECONDS = 1.5
local LOADING_TIPS = {
	"Chain two slides or landing rolls within 2.5 seconds to earn sprint.",
	"Dash and slide are shown in the ability dock when ready.",
}
local MODE_TIPS = {
	ClassicTag = "Classic Tag: avoid holding the Taya role.",
	AgawanNgPanyo = "Panyo: hold near the cloth to pick it up, then protect your hold.",
	SecretHunt = "Lihim na Target: only your private target awards a capture.",
}
local function activeLoadingTips(): { string }
	local mode = player:GetAttribute("HRushGameMode")
	local modeTip = if typeof(mode) == "string" then MODE_TIPS[mode] else nil
	if modeTip then return { LOADING_TIPS[1], LOADING_TIPS[2], modeTip } end
	return LOADING_TIPS
end

local loadingGui = create("ScreenGui", {
	Name = "LobbyLoading",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = Theme.Layers.Loading,
	Enabled = false,
}, playerGui)

-- NOTE: plain Frame, not CanvasGroup — CanvasGroups render dark in this
-- environment. Fading is done by an inner black veil instead.
local loadingGroup = createFrame({
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.Navy,
}, loadingGui)
-- Match cover art: full-screen crop behind the loading content. Empty
-- BackgroundImageId hides it (gradient only) until the art ID lands.
local loadingBg = create("ImageLabel", {
	Name = "MatchBackground",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Image = INTRO.BackgroundImageId,
	ScaleType = Enum.ScaleType.Crop,
	Visible = INTRO.BackgroundImageId ~= "",
}, loadingGroup)
local loadingVeil = createFrame({
	Name = "FadeVeil",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	ZIndex = 100,
}, loadingGroup)
create("UIGradient", {
	Color = ColorSequence.new(COLORS.Slate, COLORS.Navy),
	Rotation = 90,
}, loadingGroup)

local loadingCenter = createFrame({
	Size = UDim2.fromOffset(600, 360),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundTransparency = 1,
}, loadingGroup)
local loadingScale = create("UIScale", {}, loadingCenter)

createLabel({
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromOffset(600, 60),
	Text = "HABULAN",
	FontFace = FONTS.HeavyItalic,
	TextSize = 54,
}, loadingCenter)
createLabel({
	Position = UDim2.fromOffset(0, 50),
	Size = UDim2.fromOffset(600, 100),
	Text = "RUSH »",
	FontFace = FONTS.HeavyItalic,
	TextSize = 88,
	TextColor3 = COLORS.Lime,
}, loadingCenter)
createLabel({
	Position = UDim2.fromOffset(0, 170),
	Size = UDim2.fromOffset(600, 20),
	Text = "MATCH FOUND",
	FontFace = FONTS.Heavy,
	TextSize = 14,
	TextColor3 = COLORS.Lime,
}, loadingCenter)
local loadingStatus = createLabel({
	Position = UDim2.fromOffset(0, 194),
	Size = UDim2.fromOffset(600, 34),
	Text = "GETTING READY...",
	FontFace = FONTS.Display,
	TextSize = 30,
}, loadingCenter)

local barTrack = createFrame({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromOffset(300, 244),
	Size = UDim2.fromOffset(360, 8),
	BackgroundColor3 = COLORS.SlateEdge,
	ClipsDescendants = true,
}, loadingCenter)
corner(barTrack, FULL)
local barFill = createFrame({
	Size = UDim2.fromScale(0.3, 1),
	Position = UDim2.fromScale(-0.3, 0),
	BackgroundColor3 = COLORS.Lime,
}, barTrack)
corner(barFill, FULL)

local loadingTip = createLabel({
	Position = UDim2.fromOffset(0, 280),
	Size = UDim2.fromOffset(600, 20),
	Text = LOADING_TIPS[1],
	FontFace = FONTS.SemiBold,
	TextSize = 14,
	TextColor3 = COLORS.TextDim,
}, loadingCenter)

local function updateLoadingScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1380, 778)
	loadingScale.Scale = math.clamp(math.min(vp.X / 700, vp.Y / 420), 0.5, 1.6)
end
updateLoadingScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLoadingScale)
end

local loadingVisible = false
local loadingShownAt = 0
local loadingToken = 0

local function runLoadingAnimation(token)
	local tipIndex = 1
	local lastTipChange = os.clock()
	local lastBar = 0
	while loadingToken == token and loadingVisible do
		-- sliding progress segment
		if os.clock() - lastBar >= 1.0 then
			lastBar = os.clock()
			barFill.Position = UDim2.fromScale(-0.3, 0)
			tween(barFill, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(1, 0),
			})
		end

		-- countdown to arena reveal (server-published phase end, only meaningful during MS_02)
		local text = "GETTING READY..."
		if player:GetAttribute("HRushState") == "MS_02" then
			local endsAt = game:GetService("ReplicatedStorage"):GetAttribute("HRushPhaseEndsAt")
			if typeof(endsAt) == "number" then
				local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
				text = "STARTING IN " .. left .. "s"
			end
		end
		loadingStatus.Text = text

		if os.clock() - lastTipChange >= 3 then
			lastTipChange = os.clock()
			local tips = activeLoadingTips()
			tipIndex = (tipIndex % #tips) + 1
			loadingTip.Text = tips[tipIndex]
		end
		task.wait(0.2)
	end
end

local function setLoadingVisible(visible)
	if visible == loadingVisible then
		return
	end
	loadingVisible = visible
	loadingToken += 1
	local token = loadingToken

	if visible then
		loadingShownAt = os.clock()
		loadingGui.Enabled = true
		loadingVeil.BackgroundTransparency = 0
		local tips = activeLoadingTips()
		loadingTip.Text = tips[math.random(1, #tips)]
		tween(loadingVeil, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		task.spawn(runLoadingAnimation, token)
	else
		-- never flash: keep it up for a minimum time, then fade out.
		-- MS_RPS must show immediately so the short intro is visible.
		if player:GetAttribute("HRushState") == "MS_RPS" then
			loadingGui.Enabled = false
			loadingVeil.BackgroundTransparency = 1
			return
		end
		-- Exception: into MS_VOTE, the vote screen must be visible immediately.
		local remaining
		if player:GetAttribute("HRushState") == "MS_VOTE" then
			remaining = 0
		else
			remaining = math.max(0, LOADING_MIN_SECONDS - (os.clock() - loadingShownAt))
		end
		task.delay(remaining, function()
			if loadingToken ~= token then
				return
			end
			local t = tween(loadingVeil, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
			t.Completed:Connect(function()
				if loadingToken == token then
					loadingGui.Enabled = false
					loadingVeil.BackgroundTransparency = 1
				end
			end)
		end)
	end
end

-- Match music now lives in MusicController (per-state tracks with crossfades,
-- test tone, and the Music SoundGroup). It subscribes to the same attributes.
local MusicController = require(script.Parent:WaitForChild("MusicController"))
MusicController.Init()

local function refreshLoading()
	local inMatch = player:GetAttribute("HRushInMatch") == true
	local st = player:GetAttribute("HRushState")
	setLoadingVisible(inMatch and typeof(st) == "string" and LOADING_WAIT_STATES[st] == true)
end

player:GetAttributeChangedSignal("HRushInMatch"):Connect(refreshLoading)
player:GetAttributeChangedSignal("HRushState"):Connect(refreshLoading)
refreshLoading()
