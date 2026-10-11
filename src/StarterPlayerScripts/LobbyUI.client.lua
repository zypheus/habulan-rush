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

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local SocialService = game:GetService("SocialService")

local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 10)
local QueueEvent = Remotes and Remotes:WaitForChild("QueueEvent", 10)
local PartyEvent = Remotes and Remotes:WaitForChild("PartyEvent", 10)

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
	-- Display-only placeholder values (no real currency system is implemented)
	CoinsText = "2,450",
	GemsText = "120",
	PlayerLevel = 12,
	Region = "PHILIPPINES",
	Version = "v. 0.9.2",
	LocationText = "BARANGAY MALIGAYA",
	LocationSub = "LOBBY",
	PlayerNameOverride = nil, -- e.g. "JuanDelaRush". nil = your real Roblox display name

	-- Lobby camera (the character stays a real 3D character)
	EnableLobbyCamera = true,
	DisableMovement = true,
	HideDefaultCoreGui = true,
	CameraDistance = 9.5,
	CameraHeight = 1.4,
	CameraYawDegrees = 18, -- turns the camera so the character is in 3/4 view
	CameraShiftX = 1.5, -- pushes the character left of screen centre (landscape only)
	CameraFOV = 42,
}

local COLORS = {
	Lime = Color3.fromRGB(221, 247, 100),
	LimeLight = Color3.fromRGB(236, 255, 130),
	LimeEdge = Color3.fromRGB(122, 150, 36),
	Navy = Color3.fromRGB(29, 43, 52),
	Slate = Color3.fromRGB(53, 79, 89),
	SlateEdge = Color3.fromRGB(34, 52, 60),
	SlateLight = Color3.fromRGB(78, 106, 117),
	Pill = Color3.fromRGB(46, 70, 82),
	PlusBox = Color3.fromRGB(86, 104, 114),
	Cream = Color3.fromRGB(245, 243, 226),
	CreamEdge = Color3.fromRGB(190, 186, 160),
	Orange = Color3.fromRGB(238, 152, 88),
	White = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(176, 194, 200),
	Shadow = Color3.fromRGB(20, 34, 44),
	Gold = Color3.fromRGB(246, 190, 50),
	GoldDark = Color3.fromRGB(190, 128, 16),
	Cyan = Color3.fromRGB(110, 225, 240),
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
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 5,
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
local playButton, settingsButton, playIcon, playText, cancelHint
local onInvitePressed -- assigned with the party picker below
local gmButton, gmScale
local playModeChipLabel

-- Game modes: GM_01 is playable now; GM_03 / GM_04 are locked stretch goals.
local GAME_MODES = {
	{ id = "GM_01", shortName = "CLASSIC HABULAN", locked = false },
	{ id = "GM_03", shortName = "TEAM HABULAN", locked = true },
	{ id = "GM_04", shortName = "LAST RUNNER", locked = true },
}
local selectedGameMode = "GM_01"

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

createCurrencyPill(0, 148, "Coin", CONFIG.CoinsText)
createCurrencyPill(162, 142, "Gem", CONFIG.GemsText)

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
	local badge = createFrame({
		Position = UDim2.fromOffset(27, 34),
		Size = UDim2.fromOffset(28, 21),
		BackgroundColor3 = COLORS.Slate,
	}, avatar)
	corner(badge, 6)
	stroke(badge, COLORS.Cream, 1.5)
	createLabel({
		Size = UDim2.fromScale(1, 1),
		Text = tostring(CONFIG.PlayerLevel),
		FontFace = FONTS.Heavy,
		TextSize = 13,
	}, badge)
end

--------------------------------------------------------------------------
-- MAIN ACTIONS: [ PLAY ] [ gear ]  + player nameplate
--------------------------------------------------------------------------
local playGroup = createGroup(
	"PlayGroup",
	Vector2.new(420, 172),
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
		Size = UDim2.fromOffset(110, 89),
		Text = "PLAY",
		FontFace = FONTS.Display,
		TextSize = 58,
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
		Text = "GM_01 · CLASSIC HABULAN",
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
	corner(settingsButton, 10)
	stroke(settingsButton, COLORS.CreamEdge, 1.5, 0.2)
	makeIcon("Settings", settingsButton, 26, COLORS.GearGray, COLORS.Cream)

	-- subtitle
	createShadowLabel({
		Name = "Subtitle",
		Position = UDim2.fromOffset(2, 148),
		Size = UDim2.fromOffset(300, 18),
		Text = "One neighborhood. Endless chases.",
		FontFace = FONTS.SemiBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, playGroup, Vector2.new(1, 1))
end

local nameplateGroup = createGroup(
	"NameplateGroup",
	Vector2.new(217, 61),
	Vector2.new(0.5, 0), UDim2.fromScale(0.412, 0.7558),
	Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0.56)
)

do
	local card = createFrame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.Slate,
	}, nameplateGroup)
	corner(card, 9)
	stroke(card, COLORS.SlateLight, 1, 0.5)

	local num = createFrame({
		Position = UDim2.fromOffset(12, 13),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = COLORS.SlateEdge,
	}, card)
	corner(num, 7)
	stroke(num, COLORS.Lime, 1.5)
	createLabel({
		Size = UDim2.fromScale(1, 1),
		Text = tostring(CONFIG.PlayerLevel),
		FontFace = FONTS.Heavy,
		TextSize = 18,
		TextColor3 = COLORS.Lime,
	}, num)

	createLabel({
		Position = UDim2.fromOffset(57, 11),
		Size = UDim2.fromOffset(120, 20),
		Text = displayName,
		FontFace = FONTS.Bold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	createLabel({
		Position = UDim2.fromOffset(57, 33),
		Size = UDim2.fromOffset(120, 14),
		Text = "READY TO RUN",
		FontFace = FONTS.Heavy,
		TextSize = 10,
		TextColor3 = COLORS.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	createLabel({
		Position = UDim2.fromOffset(181, 0),
		Size = UDim2.fromOffset(26, 61),
		Text = "✓",
		FontFace = FONTS.Bold,
		TextSize = 18,
		TextColor3 = COLORS.Lime,
	}, card)
end

--------------------------------------------------------------------------
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
createNavButton("Collection", "COLLECTION", "Collection", 156, 175, false)
createNavButton("Shop", "SHOP", "Shop", 343, 124, true)

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
		Size = UDim2.fromOffset(width - 140, 42),
		Text = title,
		FontFace = FONTS.Display,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, canvas)
	createFrame({
		Position = UDim2.fromOffset(28, 70),
		Size = UDim2.fromOffset(width - 56, 2),
		BackgroundColor3 = COLORS.SlateLight,
		BackgroundTransparency = 0.6,
	}, canvas)

	local closeBtn = createButton({
		Position = UDim2.fromOffset(width - 66, 18),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = COLORS.Slate,
		Text = "X",
		FontFace = FONTS.Heavy,
		TextSize = 16,
	}, canvas)
	corner(closeBtn, 10)
	stroke(closeBtn, COLORS.SlateLight, 1, 0.5)

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
	end
end

local function openPanel(p)
	if currentPanel == p then
		return
	end
	if currentPanel then
		tweenClose(currentPanel)
	else
		showOverlay()
	end
	currentPanel = p
	tweenOpen(p)
end

-- (PLAY panel removed: the PLAY button starts matchmaking directly)

-- SETTINGS PANEL ------------------------------------------------------------
local settingsPanel = createPanel("Settings", "SETTINGS", 520, 360)
do
	local c = settingsPanel.Content -- 464 x 242

	local function createRow(index, labelText)
		local row = createCard(c, 0, (index - 1) * 76, 464, 64)
		createLabel({
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.fromOffset(240, 64),
			Text = labelText,
			FontFace = FONTS.Bold,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		return row
	end

	local function createToggle(row, initial)
		local state = initial
		local track = createButton({
			Position = UDim2.fromOffset(464 - 20 - 64, 16),
			Size = UDim2.fromOffset(64, 32),
			BackgroundColor3 = state and COLORS.Lime or COLORS.SlateEdge,
		}, row)
		corner(track, FULL)
		local knob = createFrame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 18, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = state and COLORS.Navy or COLORS.TextDim,
		}, track)
		corner(knob, FULL)
		track.Activated:Connect(function()
			state = not state
			tween(track, INFO_FAST, { BackgroundColor3 = state and COLORS.Lime or COLORS.SlateEdge })
			tween(knob, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = state and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 18, 0.5, 0),
				BackgroundColor3 = state and COLORS.Navy or COLORS.TextDim,
			})
		end)
	end

	createToggle(createRow(1, "Music"), true)
	createToggle(createRow(2, "Sound Effects"), true)

	local gfxRow = createRow(3, "Graphics")
	local options = { "LOW", "MED", "HIGH" }
	local optButtons = {}
	local function selectGraphics(idx)
		for i, b in ipairs(optButtons) do
			local on = i == idx
			tween(b, INFO_FAST, {
				BackgroundColor3 = on and COLORS.Lime or COLORS.SlateEdge,
				TextColor3 = on and COLORS.Navy or COLORS.TextDim,
			})
		end
	end
	for i, text in ipairs(options) do
		local b = createButton({
			Position = UDim2.fromOffset(464 - 20 - 3 * 66 + (i - 1) * 66, 16),
			Size = UDim2.fromOffset(62, 32),
			BackgroundColor3 = COLORS.SlateEdge,
			Text = text,
			FontFace = FONTS.Heavy,
			TextSize = 12,
			TextColor3 = COLORS.TextDim,
		}, gfxRow)
		corner(b, 8)
		b.Activated:Connect(function()
			selectGraphics(i)
		end)
		optButtons[i] = b
	end
	selectGraphics(3)
end

-- GAME MODES PANEL -----------------------------------------------------------
local function updatePlayModeChip()
	if not playModeChipLabel then
		return
	end
	for _, m in ipairs(GAME_MODES) do
		if m.id == selectedGameMode then
			playModeChipLabel.Text = m.id .. " · " .. m.shortName
			return
		end
	end
end

gameModesPanel = createPanel("GameModes", "GAME MODES", 720, 478)

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
		GM_01 = {
			title = "CLASSIC HABULAN",
			tag = "MVP · CORE MODE",
			art = artCourt,
			desc = "FFA hot-potato tag · 4-8 players · 3 rounds x 150s · Skill Draft each round · fair shuffle-bag Taya · safe windows + post-tag boosts",
			win = "WIN: Lowest total Taya Time takes 1st + MVP.",
		},
		GM_03 = {
			title = "TEAM HABULAN",
			tag = "COMING SOON · P2",
			art = artFreeze,
			desc = "FREEZE TAG · 4v4 street Ice-Water: tagged Runners freeze in place; teammates rescue them by touch.",
			win = "WIN: Freeze them all — or survive to the end.",
		},
		GM_04 = {
			title = "LAST RUNNER STANDING",
			tag = "COMING SOON · P2",
			art = artElimination,
			desc = "ELIMINATION FFA: when the buzzer expires, whoever holds the Taya is out of the match.",
			win = "WIN: Be the last Runner standing.",
		},
	}

	local rows = {}
	local function refreshModeRows()
		for _, row in ipairs(rows) do
			local selected = (row.id == selectedGameMode)
			row.SelectBtn.Text = selected and "✓ SELECTED" or "SELECT"
			row.SelectBtn.BackgroundColor3 = selected and COLORS.Lime or COLORS.Cream
			row.CardStroke.Color = selected and COLORS.Lime or COLORS.SlateLight
			row.CardStroke.Transparency = selected and 0 or 0.6
		end
	end

	local CARD_W, CARD_H = 208, 344
	for idx, m in ipairs(GAME_MODES) do
		local info = MODE_INFO[m.id]
		local card = createCard(c, (idx - 1) * (CARD_W + 20), 0, CARD_W, CARD_H)
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
			Text = info.tag,
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
			local selectBtn = createActionButton(card, "SELECT", "lime", 11, CARD_H - 46, CARD_W - 22, 32, function()
				selectedGameMode = m.id
				refreshModeRows()
				updatePlayModeChip()
				closePanel() -- back to the lobby; PLAY now shows the chosen mode
			end, 14)
			table.insert(rows, { id = m.id, SelectBtn = selectBtn, CardStroke = cardStroke })
		end
	end

	refreshModeRows()
end

-- PROFILE PANEL -------------------------------------------------------------
local profilePanel = createPanel("Profile", "PROFILE", 600, 400)
do
	local c = profilePanel.Content -- 544 x 282
	local left = createCard(c, 0, 0, 190, 282)
	local avatarBox = createFrame({
		Position = UDim2.fromOffset(25, 24),
		Size = UDim2.fromOffset(140, 140),
		BackgroundColor3 = COLORS.Orange,
	}, left)
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
	createLabel({
		Position = UDim2.fromOffset(10, 180),
		Size = UDim2.fromOffset(170, 26),
		Text = displayName,
		FontFace = FONTS.Bold,
		TextSize = 18,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, left)
	createLabel({
		Position = UDim2.fromOffset(10, 208),
		Size = UDim2.fromOffset(170, 18),
		Text = "LEVEL " .. CONFIG.PlayerLevel,
		FontFace = FONTS.Heavy,
		TextSize = 12,
		TextColor3 = COLORS.Lime,
	}, left)

	local stats = { "STAT 1", "STAT 2", "STAT 3" }
	for i, s in ipairs(stats) do
		local card = createCard(c, 206, (i - 1) * 96, 338, 86, s .. "  (PLACEHOLDER)")
		createLabel({
			Position = UDim2.fromOffset(16, 34),
			Size = UDim2.fromOffset(300, 40),
			Text = "—",
			FontFace = FONTS.Display,
			TextSize = 32,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, card)
	end
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
-- PLAY starts matchmaking directly; tapping it again while searching cancels.
bindButton(playButton, playHolderScale, function()
	local q = player:GetAttribute("HRushQueue") or "Idle"
	if QueueEvent then
		QueueEvent:FireServer(q == "Searching" and "Cancel" or "Play")
	end
end, 1.04, 0.96)

bindButton(settingsButton, settingsHolderScale, function()
	openPanel(settingsPanel)
end, 1.08, 0.92)

bindButton(gmButton, gmScale, function()
	openPanel(gameModesPanel)
end, 1.08, 0.92)

bindButton(navButtons.Profile.Button, navButtons.Profile.Scale, function()
	openPanel(profilePanel)
end, 1.06, 0.94)
bindButton(navButtons.Collection.Button, navButtons.Collection.Scale, function()
	openPanel(collectionPanel)
end, 1.06, 0.94)
bindButton(navButtons.Shop.Button, navButtons.Shop.Scale, function()
	openPanel(shopPanel)
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
local function refreshPlayButton()
	queueStateToken += 1
	local token = queueStateToken
	local q = player:GetAttribute("HRushQueue") or "Idle"

	if q == "Searching" then
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
		playText.Position = UDim2.fromOffset(84, 0)
		playText.Size = UDim2.fromOffset(190, 89)
		playText.TextSize = 40
		playText.Text = "STARTING..."
		cancelHint.TextTransparency = 1
		chevronLabel.TextTransparency = 1
	elseif q == "Busy" then
		playText.Position = UDim2.fromOffset(66, 0)
		playText.Size = UDim2.fromOffset(220, 89)
		playText.TextSize = 30
		playText.Text = "MATCH IN PROGRESS"
		cancelHint.TextTransparency = 1
		chevronLabel.TextTransparency = 1
	else
		playText.Position = UDim2.fromOffset(88, 0)
		playText.Size = UDim2.fromOffset(110, 89)
		playText.TextSize = 58
		playText.Text = "PLAY"
		cancelHint.TextTransparency = 1
		chevronLabel.TextTransparency = 0
	end
end
player:GetAttributeChangedSignal("HRushQueue"):Connect(refreshPlayButton)
player:GetAttributeChangedSignal("HRushSearchEndsAt"):Connect(refreshPlayButton)
refreshPlayButton()

--------------------------------------------------------------------------
-- CAMERA
--------------------------------------------------------------------------
local isPortrait = false

local function setupLobbyCamera()
	if not CONFIG.EnableLobbyCamera then
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

	if CONFIG.DisableMovement then
		task.spawn(function()
			local ok, module = pcall(function()
				return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5))
			end)
			if ok and module then
				pcall(function()
					module:GetControls():Disable()
				end)
			end
		end)
	end

	RunService:BindToRenderStep("HabulanLobbyCamera", Enum.RenderPriority.Camera.Value + 1, function()
		local cam = workspace.CurrentCamera
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not cam or not hrp then
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.FieldOfView = CONFIG.CameraFOV

		local sway = math.sin(os.clock() * 0.45) * 1.5
		local yaw = math.rad(CONFIG.CameraYawDegrees + sway)
		local focus = hrp.Position + Vector3.new(0, 0.6, 0)
		local dir = (CFrame.Angles(0, yaw, 0) * hrp.CFrame.LookVector.Unit)
		local camPos = focus + dir * CONFIG.CameraDistance + Vector3.new(0, CONFIG.CameraHeight, 0)
		local base = CFrame.lookAt(camPos, focus)
		local shift = isPortrait and 0 or CONFIG.CameraShiftX
		cam.CFrame = base * CFrame.new(shift, 0, 0)
	end)
end

--------------------------------------------------------------------------
-- RESPONSIVE UI
--------------------------------------------------------------------------
local function setupResponsiveUI()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1380, 778)
	isPortrait = vp.Y > vp.X
	local touch = UserInputService.TouchEnabled

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
		g.Scale.Scale = s
		g.Frame.AnchorPoint = isPortrait and g.PAnchor or g.LAnchor
		g.Frame.Position = isPortrait and g.PPos or g.LPos
	end

	for _, p in pairs(panels) do
		p.Fit.Scale = math.clamp(math.min(vp.X * 0.94 / p.Width, vp.Y * 0.9 / p.Height), 0.35, 1.4)
	end
end

local function watchViewport()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(setupResponsiveUI)
	end
end

watchViewport()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	watchViewport()
	setupResponsiveUI()
end)
setupResponsiveUI()
setupLobbyCamera()

--------------------------------------------------------------------------
-- MATCH INTEGRATION (lobby <-> match gate)
-- Lobby UI + lobby camera exist only while NOT in a match (HRushInMatch).
-- The in-match HUD (HRushHUD from UIController) hides itself; we don't touch it.
--------------------------------------------------------------------------
local function setControlsEnabled(enabled)
	task.spawn(function()
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5))
		end)
		if ok and module then
			pcall(function()
				local controls = module:GetControls()
				if enabled then
					controls:Enable()
				else
					controls:Disable()
				end
			end)
		end
	end)
end

local function applyMatchGate()
	local inMatch = player:GetAttribute("HRushInMatch") == true

	gui.Enabled = not inMatch

	pcall(function()
		RunService:UnbindFromRenderStep("HabulanLobbyCamera")
	end)

	if inMatch then
		closePanel()
		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Custom
			cam.FieldOfView = 70
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				cam.CameraSubject = hum
			end
		end
		setControlsEnabled(true)
	else
		setupLobbyCamera() -- re-binds the lobby camera and disables movement
	end
end

player:GetAttributeChangedSignal("HRushInMatch"):Connect(applyMatchGate)
player.CharacterAdded:Connect(function()
	task.wait(0.2)
	applyMatchGate()
end)
applyMatchGate()

--------------------------------------------------------------------------
-- LOADING SCREEN (match found -> arena reveal)
-- Shown while you are in a match but the arena isn't ready yet (MS_01 right after
-- match creation, and MS_02 draft). It fades out when the countdown (MS_03) begins.
-- When the Skill Draft UI (T17) exists, change LOADING_WAIT_STATES to { MS_01 = true }.
--------------------------------------------------------------------------
local LOADING_WAIT_STATES = { MS_01 = true, MS_02 = true }
local LOADING_MIN_SECONDS = 1.5
local LOADING_TIPS = {
	"Hold Shift to sprint. Watch your stamina.",
	"Press Q to dash. 6 second cooldown.",
	"Press C to slide under low gaps.",
	"Taya time counts against you. Lowest wins.",
}

local loadingGui = create("ScreenGui", {
	Name = "LobbyLoading",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 100,
	Enabled = false,
}, playerGui)

-- NOTE: plain Frame, not CanvasGroup — CanvasGroups render dark in this
-- environment. Fading is done by an inner black veil instead.
local loadingGroup = createFrame({
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.Navy,
}, loadingGui)
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
			tipIndex = (tipIndex % #LOADING_TIPS) + 1
			loadingTip.Text = LOADING_TIPS[tipIndex]
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
		loadingTip.Text = LOADING_TIPS[math.random(1, #LOADING_TIPS)]
		tween(loadingVeil, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
		task.spawn(runLoadingAnimation, token)
	else
		-- never flash: keep it up for a minimum time, then fade out.
		-- Exception: into MS_VOTE — the vote screen must be visible immediately.
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

local function refreshLoading()
	local inMatch = player:GetAttribute("HRushInMatch") == true
	local st = player:GetAttribute("HRushState")
	setLoadingVisible(inMatch and typeof(st) == "string" and LOADING_WAIT_STATES[st] == true)
end

player:GetAttributeChangedSignal("HRushInMatch"):Connect(refreshLoading)
player:GetAttributeChangedSignal("HRushState"):Connect(refreshLoading)
refreshLoading()
