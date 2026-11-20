--!strict
-- HudBuilder: builds the whole Chess Brainrot HUD in code (ScreenGui over
-- the 3D world). Dense like the rank-1 reference: one-line formula bar,
-- big money counter, event banner, quests panel, bottom action bar,
-- carrying bar, Piece Codex grid, upgrades shop, toasts, floating +$ text.
-- HUD text stays clear of the top-left corner (Roblox menu buttons live there).

local PieceData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PieceData"))
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Format"))

local HudBuilder = {}

local TITLE_FONT = Enum.Font.GothamBold
local BODY_FONT = Enum.Font.Gotham

local function bar(parent: Instance, name: string, pos: UDim2, size: UDim2, bg: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = pos
	t.Size = size
	t.BackgroundColor3 = bg
	t.BackgroundTransparency = 0.15
	t.BorderSizePixel = 0
	t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.Font = TITLE_FONT
	t.TextScaled = true
	t.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = t
	return t
end

local function actionButton(parent: Instance, name: string, x: number, title: string, sub: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Position = UDim2.new(0, x, 0, 0)
	b.Size = UDim2.new(0, 150, 0, 56)
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = ""
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = b
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 28)
	titleLabel.Position = UDim2.new(0, 0, 0, 4)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Font = TITLE_FONT
	titleLabel.TextSize = 20
	titleLabel.Text = title
	titleLabel.Parent = b
	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Sub"
	subLabel.Size = UDim2.new(1, 0, 0, 20)
	subLabel.Position = UDim2.new(0, 0, 0, 30)
	subLabel.BackgroundTransparency = 1
	subLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
	subLabel.Font = BODY_FONT
	subLabel.TextSize = 15
	subLabel.Text = sub
	subLabel.Parent = b
	return b
end

export type Hud = {
	gui: ScreenGui,
	moneyLabel: TextLabel,
	incomeLabel: TextLabel,
	rebirthLabel: TextLabel,
	eventBanner: TextLabel,
	nextEventLabel: TextLabel,
	questsPanel: Frame,
	questRows: { Frame },
	bottomBar: Frame,
	lockButton: TextButton,
	whackButton: TextButton,
	upgradesButton: TextButton,
	rebirthButton: TextButton,
	codexButton: TextButton,
	carryingBar: TextLabel,
	toastLabel: TextLabel,
	codexFrame: Frame,
	codexTitle: TextLabel,
	codexGrid: Frame,
	codexMilestones: TextLabel,
	upgradesFrame: Frame,
	upgradesList: Frame,
	setMoney: (self: Hud, money: number, income: number, rebirth: number) -> (),
	setEvent: (self: Hud, name: string, banner: string, endsIn: number, nextName: string, nextIn: number) -> (),
	setQuests: (self: Hud, quests: { [string]: number }, done: { [string]: boolean }) -> (),
	setCodex: (self: Hud, found: { [string]: boolean }, count: number) -> (),
	setUpgrades: (self: Hud, owned: { [string]: boolean }, money: number) -> (),
	setBottom: (self: Hud, lockText: string, whackText: string, upgradesBought: number, rebirthCost: number, codexFound: number) -> (),
	setCarrying: (self: Hud, name: string) -> (),
	showToast: (self: Hud, text: string) -> (),
	spawnFloat: (self: Hud, screenPos: Vector2, text: string, color: Color3) -> (),
	toggleCodex: (self: Hud) -> (),
	toggleUpgrades: (self: Hud) -> (),
	isCodexOpen: (self: Hud) -> boolean,
}

function HudBuilder.build(playerGui: PlayerGui): Hud
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChessHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	-- Top formula bar (centred; top-left corner stays empty for Roblox menus).
	local formula = bar(gui, "FormulaBar", UDim2.new(0.5, 0, 0, 6), UDim2.new(0, 980, 0, 30), Color3.fromRGB(120, 20, 30))
	formula.Text = "48 PIECES · 6 TYPES · 8 RARITIES · 8 MUTATIONS · 6 BOARDS · 6 EVENTS · CAPTURE · LOCK · REBIRTH"
	formula.TextColor3 = Color3.fromRGB(255, 220, 100)

	-- Money block.
	local moneyFrame = Instance.new("Frame")
	moneyFrame.Name = "MoneyFrame"
	moneyFrame.AnchorPoint = Vector2.new(0.5, 0)
	moneyFrame.Position = UDim2.new(0.5, 0, 0, 42)
	moneyFrame.Size = UDim2.new(0, 560, 0, 56)
	moneyFrame.BackgroundColor3 = Color3.fromRGB(250, 245, 220)
	moneyFrame.BackgroundTransparency = 0.05
	moneyFrame.BorderSizePixel = 0
	moneyFrame.Parent = gui
	local moneyCorner = Instance.new("UICorner")
	moneyCorner.CornerRadius = UDim.new(0, 10)
	moneyCorner.Parent = moneyFrame

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "Money"
	moneyLabel.Size = UDim2.new(0.55, 0, 1, 0)
	moneyLabel.Position = UDim2.new(0, 10, 0, 0)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.TextColor3 = Color3.fromRGB(30, 30, 30)
	moneyLabel.Font = TITLE_FONT
	moneyLabel.TextSize = 38
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.Text = "$500"
	moneyLabel.Parent = moneyFrame

	local incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Income"
	incomeLabel.Size = UDim2.new(0.45, -10, 0, 28)
	incomeLabel.Position = UDim2.new(0.55, 0, 0, 4)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.TextColor3 = Color3.fromRGB(20, 120, 40)
	incomeLabel.Font = TITLE_FONT
	incomeLabel.TextSize = 22
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Right
	incomeLabel.Text = "+$0/s"
	incomeLabel.Parent = moneyFrame

	local rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "Rebirth"
	rebirthLabel.Size = UDim2.new(0.45, -10, 0, 22)
	rebirthLabel.Position = UDim2.new(0.55, 0, 0, 30)
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.TextColor3 = Color3.fromRGB(120, 60, 0)
	rebirthLabel.Font = BODY_FONT
	rebirthLabel.TextSize = 16
	rebirthLabel.TextXAlignment = Enum.TextXAlignment.Right
	rebirthLabel.Text = "REBIRTH 0 · ×1"
	rebirthLabel.Parent = moneyFrame

	-- Event banner (green, herz-style) + next-event teaser.
	local eventBanner = bar(gui, "EventBanner", UDim2.new(0.5, 0, 0, 104), UDim2.new(0, 980, 0, 40), Color3.fromRGB(30, 160, 60))
	eventBanner.Text = ""
	eventBanner.Visible = false
	local nextEventLabel = Instance.new("TextLabel")
	nextEventLabel.Name = "NextEvent"
	nextEventLabel.AnchorPoint = Vector2.new(0.5, 0)
	nextEventLabel.Position = UDim2.new(0.5, 0, 0, 148)
	nextEventLabel.Size = UDim2.new(0, 500, 0, 22)
	nextEventLabel.BackgroundTransparency = 1
	nextEventLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextEventLabel.Font = BODY_FONT
	nextEventLabel.TextSize = 16
	nextEventLabel.TextStrokeTransparency = 0.2
	nextEventLabel.Text = ""
	nextEventLabel.Parent = gui

	-- Quests panel, right side.
	local questsPanel = Instance.new("Frame")
	questsPanel.Name = "QuestsPanel"
	questsPanel.AnchorPoint = Vector2.new(1, 0)
	questsPanel.Position = UDim2.new(1, -12, 0, 180)
	questsPanel.Size = UDim2.new(0, 300, 0, 300)
	questsPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	questsPanel.BackgroundTransparency = 0.25
	questsPanel.BorderSizePixel = 0
	questsPanel.Parent = gui
	local qCorner = Instance.new("UICorner")
	qCorner.CornerRadius = UDim.new(0, 8)
	qCorner.Parent = questsPanel
	local questsTitle = Instance.new("TextLabel")
	questsTitle.Name = "Title"
	questsTitle.Size = UDim2.new(1, 0, 0, 28)
	questsTitle.BackgroundTransparency = 1
	questsTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	questsTitle.Font = TITLE_FONT
	questsTitle.TextSize = 18
	questsTitle.Text = "QUESTS  0/8 done"
	questsTitle.Parent = questsPanel

	local questRows: { Frame } = {}
	for i, q in ipairs(Config.QUESTS) do
		local row = Instance.new("Frame")
		row.Name = "Quest_" .. q.id
		row.Size = UDim2.new(1, -12, 0, 30)
		row.Position = UDim2.new(0, 6, 0, 30 + (i - 1) * 33)
		row.BackgroundTransparency = 1
		row.Parent = questsPanel
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.new(1, -70, 1, 0)
		text.BackgroundTransparency = 1
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.Font = BODY_FONT
		text.TextSize = 14
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = q.text .. "  0/" .. tostring(q.target)
		text.Parent = row
		local claim = Instance.new("TextButton")
		claim.Name = "Claim"
		claim.Size = UDim2.new(0, 62, 0, 24)
		claim.Position = UDim2.new(1, -62, 0, 3)
		claim.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
		claim.TextColor3 = Color3.fromRGB(255, 255, 255)
		claim.Font = TITLE_FONT
		claim.TextSize = 13
		claim.Text = "CLAIM"
		claim.Visible = false
		claim.Parent = row
		table.insert(questRows, row)
	end

	-- Bottom action bar.
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.AnchorPoint = Vector2.new(0.5, 1)
	bottomBar.Position = UDim2.new(0.5, 0, 1, -10)
	bottomBar.Size = UDim2.new(0, 790, 0, 56)
	bottomBar.BackgroundTransparency = 1
	bottomBar.Parent = gui
	local lockButton = actionButton(bottomBar, "LockButton", 0, "LOCK [L]", "READY", Color3.fromRGB(40, 160, 60))
	local whackButton = actionButton(bottomBar, "WhackButton", 160, "WHACK [F]", "READY", Color3.fromRGB(230, 130, 30))
	local upgradesButton = actionButton(bottomBar, "UpgradesButton", 320, "UPGRADES [U]", "0/6 bought", Color3.fromRGB(60, 120, 230))
	local rebirthButton = actionButton(bottomBar, "RebirthButton", 480, "REBIRTH [R]", "$100M", Color3.fromRGB(160, 60, 200))
	local codexButton = actionButton(bottomBar, "CodexButton", 640, "CODEX [B]", "0/48 found", Color3.fromRGB(200, 160, 40))

	-- Carrying bar above the bottom bar.
	local carryingBar = bar(gui, "CarryingBar", UDim2.new(0.5, 0, 1, -78), UDim2.new(0, 640, 0, 30), Color3.fromRGB(120, 40, 20))
	carryingBar.Text = ""
	carryingBar.Visible = false

	-- Toast, centre screen.
	local toastLabel = bar(gui, "Toast", UDim2.new(0.5, 0, 0.5, 120), UDim2.new(0, 640, 0, 34), Color3.fromRGB(20, 20, 30))
	toastLabel.Text = ""
	toastLabel.Visible = false

	-- Piece Codex (press B).
	local codexFrame = Instance.new("Frame")
	codexFrame.Name = "CodexFrame"
	codexFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	codexFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	codexFrame.Size = UDim2.new(0, 780, 0, 540)
	codexFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	codexFrame.BorderSizePixel = 0
	codexFrame.Visible = false
	codexFrame.Parent = gui
	local cCorner = Instance.new("UICorner")
	cCorner.CornerRadius = UDim.new(0, 10)
	cCorner.Parent = codexFrame
	local codexTitle = Instance.new("TextLabel")
	codexTitle.Name = "Title"
	codexTitle.Size = UDim2.new(1, -60, 0, 36)
	codexTitle.Position = UDim2.new(0, 12, 0, 6)
	codexTitle.BackgroundTransparency = 1
	codexTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	codexTitle.Font = TITLE_FONT
	codexTitle.TextSize = 22
	codexTitle.TextXAlignment = Enum.TextXAlignment.Left
	codexTitle.Text = "PIECE CODEX  0/48 found"
	codexTitle.Parent = codexFrame
	local codexClose = Instance.new("TextButton")
	codexClose.Name = "Close"
	codexClose.Size = UDim2.new(0, 40, 0, 32)
	codexClose.Position = UDim2.new(1, -48, 0, 6)
	codexClose.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	codexClose.TextColor3 = Color3.fromRGB(255, 255, 255)
	codexClose.Font = TITLE_FONT
	codexClose.TextSize = 18
	codexClose.Text = "X"
	codexClose.Parent = codexFrame
	local codexGrid = Instance.new("Frame")
	codexGrid.Name = "Grid"
	codexGrid.Size = UDim2.new(1, -24, 0, 420)
	codexGrid.Position = UDim2.new(0, 12, 0, 48)
	codexGrid.BackgroundTransparency = 1
	codexGrid.Parent = codexFrame
	local codexMilestones = Instance.new("TextLabel")
	codexMilestones.Name = "Milestones"
	codexMilestones.Size = UDim2.new(1, -24, 0, 56)
	codexMilestones.Position = UDim2.new(0, 12, 0, 476)
	codexMilestones.BackgroundTransparency = 1
	codexMilestones.TextColor3 = Color3.fromRGB(200, 220, 255)
	codexMilestones.Font = BODY_FONT
	codexMilestones.TextSize = 14
	codexMilestones.TextWrapped = true
	codexMilestones.Text = "Milestones — 6: income ×1.1 · 12: ×1.25 · 18: ×1.5 · 24: ×1.75 · 36: ×2 · 48: ×3"
	codexMilestones.Parent = codexFrame

	-- 48 tiles: 6 type rows x 8 rarity columns.
	for row, pieceType in ipairs(PieceData.TYPE_ORDER) do
		for col, rarity in ipairs(PieceData.RARITIES) do
			local tile = Instance.new("TextButton")
			tile.Name = "Tile_" .. pieceType .. "_" .. rarity.name
			tile.Size = UDim2.new(0, 88, 0, 62)
			tile.Position = UDim2.new(0, (col - 1) * 94, 0, (row - 1) * 68)
			tile.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			tile.TextColor3 = Color3.fromRGB(150, 150, 160)
			tile.Font = TITLE_FONT
			tile.TextSize = 26
			tile.Text = "?"
			tile.Parent = codexGrid
			local tCorner = Instance.new("UICorner")
			tCorner.CornerRadius = UDim.new(0, 6)
			tCorner.Parent = tile
		end
	end

	-- Upgrades shop (press U).
	local upgradesFrame = Instance.new("Frame")
	upgradesFrame.Name = "UpgradesFrame"
	upgradesFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	upgradesFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	upgradesFrame.Size = UDim2.new(0, 520, 0, 380)
	upgradesFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	upgradesFrame.BorderSizePixel = 0
	upgradesFrame.Visible = false
	upgradesFrame.Parent = gui
	local uCorner = Instance.new("UICorner")
	uCorner.CornerRadius = UDim.new(0, 10)
	uCorner.Parent = upgradesFrame
	local upgradesTitle = Instance.new("TextLabel")
	upgradesTitle.Name = "Title"
	upgradesTitle.Size = UDim2.new(1, -60, 0, 36)
	upgradesTitle.Position = UDim2.new(0, 12, 0, 6)
	upgradesTitle.BackgroundTransparency = 1
	upgradesTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	upgradesTitle.Font = TITLE_FONT
	upgradesTitle.TextSize = 22
	upgradesTitle.TextXAlignment = Enum.TextXAlignment.Left
	upgradesTitle.Text = "UPGRADES"
	upgradesTitle.Parent = upgradesFrame
	local upgradesClose = Instance.new("TextButton")
	upgradesClose.Name = "Close"
	upgradesClose.Size = UDim2.new(0, 40, 0, 32)
	upgradesClose.Position = UDim2.new(1, -48, 0, 6)
	upgradesClose.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	upgradesClose.TextColor3 = Color3.fromRGB(255, 255, 255)
	upgradesClose.Font = TITLE_FONT
	upgradesClose.TextSize = 18
	upgradesClose.Text = "X"
	upgradesClose.Parent = upgradesFrame
	local upgradesList = Instance.new("Frame")
	upgradesList.Name = "List"
	upgradesList.Size = UDim2.new(1, -24, 0, 320)
	upgradesList.Position = UDim2.new(0, 12, 0, 48)
	upgradesList.BackgroundTransparency = 1
	upgradesList.Parent = upgradesFrame
	for i, u in ipairs(Config.UPGRADES) do
		local row = Instance.new("Frame")
		row.Name = "Upgrade_" .. u.id
		row.Size = UDim2.new(1, 0, 0, 46)
		row.Position = UDim2.new(0, 0, 0, (i - 1) * 52)
		row.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		row.BorderSizePixel = 0
		row.Parent = upgradesList
		local name = Instance.new("TextLabel")
		name.Name = "Name"
		name.Size = UDim2.new(1, -130, 0, 24)
		name.Position = UDim2.new(0, 10, 0, 2)
		name.BackgroundTransparency = 1
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.Font = TITLE_FONT
		name.TextSize = 16
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = u.name .. " — " .. u.desc
		name.Parent = row
		local price = Instance.new("TextLabel")
		price.Name = "Price"
		price.Size = UDim2.new(1, -130, 0, 18)
		price.Position = UDim2.new(0, 10, 0, 24)
		price.BackgroundTransparency = 1
		price.TextColor3 = Color3.fromRGB(255, 220, 100)
		price.Font = BODY_FONT
		price.TextSize = 14
		price.TextXAlignment = Enum.TextXAlignment.Left
		price.Text = Format.money(u.price)
		price.Parent = row
		local buy = Instance.new("TextButton")
		buy.Name = "Buy"
		buy.Size = UDim2.new(0, 110, 0, 32)
		buy.Position = UDim2.new(1, -120, 0, 7)
		buy.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
		buy.TextColor3 = Color3.fromRGB(255, 255, 255)
		buy.Font = TITLE_FONT
		buy.TextSize = 15
		buy.Text = "BUY"
		buy.Parent = row
	end

	local hud = {} :: Hud
	hud.gui = gui
	hud.moneyLabel = moneyLabel
	hud.incomeLabel = incomeLabel
	hud.rebirthLabel = rebirthLabel
	hud.eventBanner = eventBanner
	hud.nextEventLabel = nextEventLabel
	hud.questsPanel = questsPanel
	hud.questRows = questRows
	hud.bottomBar = bottomBar
	hud.lockButton = lockButton
	hud.whackButton = whackButton
	hud.upgradesButton = upgradesButton
	hud.rebirthButton = rebirthButton
	hud.codexButton = codexButton
	hud.carryingBar = carryingBar
	hud.toastLabel = toastLabel
	hud.codexFrame = codexFrame
	hud.codexTitle = codexTitle
	hud.codexGrid = codexGrid
	hud.codexMilestones = codexMilestones
	hud.upgradesFrame = upgradesFrame
	hud.upgradesList = upgradesList

	local toastToken = 0
	function hud:setMoney(money: number, income: number, rebirth: number)
		self.moneyLabel.Text = Format.money(money)
		self.incomeLabel.Text = "+" .. Format.rate(income)
		self.rebirthLabel.Text = "REBIRTH " .. tostring(rebirth) .. " · ×" .. tostring(3 ^ rebirth)
	end

	function hud:setEvent(name: string, banner: string, endsIn: number, nextName: string, nextIn: number)
		if name ~= "" then
			self.eventBanner.Visible = true
			self.eventBanner.Text = banner .. "  " .. tostring(math.ceil(endsIn)) .. "s"
			self.nextEventLabel.Text = "NEXT: " .. nextName .. " in " .. tostring(math.ceil(nextIn)) .. "s"
		else
			self.eventBanner.Visible = false
			self.nextEventLabel.Text = "NEXT: " .. nextName .. " in " .. tostring(math.ceil(nextIn)) .. "s"
		end
	end

	function hud:setQuests(quests: { [string]: number }, done: { [string]: boolean })
		local doneCount = 0
		for i, q in ipairs(Config.QUESTS) do
			local row = self.questRows[i]
			if row ~= nil then
				local text = row:FindFirstChild("Text")
				local claim = row:FindFirstChild("Claim")
				local progress = quests[q.id] or 0
				if done[q.id] then
					doneCount += 1
					if text ~= nil and text:IsA("TextLabel") then
						text.Text = "✓ " .. q.text .. "  DONE"
						text.TextColor3 = Color3.fromRGB(120, 255, 140)
					end
					if claim ~= nil and claim:IsA("TextButton") then
						claim.Visible = false
					end
				else
					if text ~= nil and text:IsA("TextLabel") then
						text.Text = q.text .. "  " .. tostring(math.min(progress, q.target)) .. "/" .. tostring(q.target) .. " · " .. Format.money(q.reward)
					end
					if claim ~= nil and claim:IsA("TextButton") then
						claim.Visible = progress >= q.target
					end
				end
			end
		end
		local title = self.questsPanel:FindFirstChild("Title")
		if title ~= nil and title:IsA("TextLabel") then
			title.Text = "QUESTS  " .. tostring(doneCount) .. "/8 done"
		end
	end

	function hud:setCodex(found: { [string]: boolean }, count: number)
		self.codexTitle.Text = "PIECE CODEX  " .. tostring(count) .. "/48 found"
		for row, pieceType in ipairs(PieceData.TYPE_ORDER) do
			for col, rarity in ipairs(PieceData.RARITIES) do
				local tile = self.codexGrid:FindFirstChild("Tile_" .. pieceType .. "_" .. rarity.name)
				if tile ~= nil and tile:IsA("TextButton") then
					local key = pieceType .. "_" .. rarity.name
					if found[key] then
						tile.Text = PieceData.TYPES[pieceType].glyph
						tile.TextColor3 = Color3.fromRGB(255, 255, 255)
						tile.BackgroundColor3 = rarity.color
					else
						tile.Text = "?"
						tile.TextColor3 = Color3.fromRGB(150, 150, 160)
						tile.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
					end
				end
			end
		end
	end

	function hud:setUpgrades(owned: { [string]: boolean }, money: number)
		for _, u in ipairs(Config.UPGRADES) do
			local row = self.upgradesList:FindFirstChild("Upgrade_" .. u.id)
			if row ~= nil then
				local buy = row:FindFirstChild("Buy")
				if buy ~= nil and buy:IsA("TextButton") then
					if owned[u.id] then
						buy.Text = "OWNED"
						buy.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
					elseif money >= u.price then
						buy.Text = "BUY"
						buy.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
					else
						buy.Text = "BUY"
						buy.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
					end
				end
			end
		end
	end

	function hud:setBottom(lockText: string, whackText: string, upgradesBought: number, rebirthCost: number, codexFound: number)
		local lockSub = self.lockButton:FindFirstChild("Sub")
		if lockSub ~= nil and lockSub:IsA("TextLabel") then
			lockSub.Text = lockText
		end
		local whackSub = self.whackButton:FindFirstChild("Sub")
		if whackSub ~= nil and whackSub:IsA("TextLabel") then
			whackSub.Text = whackText
		end
		local upSub = self.upgradesButton:FindFirstChild("Sub")
		if upSub ~= nil and upSub:IsA("TextLabel") then
			upSub.Text = tostring(upgradesBought) .. "/6 bought"
		end
		local rbSub = self.rebirthButton:FindFirstChild("Sub")
		if rbSub ~= nil and rbSub:IsA("TextLabel") then
			rbSub.Text = Format.money(rebirthCost)
		end
		local cxSub = self.codexButton:FindFirstChild("Sub")
		if cxSub ~= nil and cxSub:IsA("TextLabel") then
			cxSub.Text = tostring(codexFound) .. "/48 found"
		end
	end

	function hud:setCarrying(name: string)
		if name ~= "" then
			self.carryingBar.Visible = true
			self.carryingBar.Text = "CARRYING: " .. name .. "  ->  DROP AT YOUR BOARD"
		else
			self.carryingBar.Visible = false
		end
	end

	function hud:showToast(text: string)
		toastToken += 1
		local token = toastToken
		self.toastLabel.Visible = true
		self.toastLabel.Text = text
		task.delay(3, function()
			if token == toastToken then
				self.toastLabel.Visible = false
			end
		end)
	end

	function hud:spawnFloat(screenPos: Vector2, text: string, color: Color3)
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
		label.Size = UDim2.new(0, 300, 0, 34)
		label.BackgroundTransparency = 1
		label.TextColor3 = color
		label.Font = TITLE_FONT
		label.TextSize = 26
		label.TextStrokeTransparency = 0.1
		label.Text = text
		label.Parent = self.gui
		local tween = game:GetService("TweenService"):Create(
			label,
			TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, screenPos.X, 0, screenPos.Y - 70), TextTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Connect(function()
			label:Destroy()
		end)
	end

	function hud:toggleCodex()
		self.codexFrame.Visible = not self.codexFrame.Visible
		if self.codexFrame.Visible then
			self.upgradesFrame.Visible = false
		end
	end

	function hud:toggleUpgrades()
		self.upgradesFrame.Visible = not self.upgradesFrame.Visible
		if self.upgradesFrame.Visible then
			self.codexFrame.Visible = false
		end
	end

	function hud:isCodexOpen(): boolean
		return self.codexFrame.Visible
	end

	codexClose.Activated:Connect(function()
		codexFrame.Visible = false
	end)
	upgradesClose.Activated:Connect(function()
		upgradesFrame.Visible = false
	end)

	return hud
end

return HudBuilder
