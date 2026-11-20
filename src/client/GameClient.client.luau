--!strict
-- GameClient: input, camera-facing UI, selection + legal-move highlights.
-- The client never decides money or ownership: it sends an intent and
-- renders what the server answers. Money counters count up, never jump.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local Config = require(Shared:WaitForChild("Config"))
local PieceData = require(Shared:WaitForChild("PieceData"))
local HudBuilder = require(StarterGui:WaitForChild("ChessGui"):WaitForChild("HudBuilder"))

local Remotes = ReplicatedStorage:WaitForChild("ChessRemotes")
local ChessRequest = Remotes:WaitForChild("ChessRequest") :: RemoteEvent
local ChessUpdate = Remotes:WaitForChild("ChessUpdate") :: RemoteEvent

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = Workspace.CurrentCamera

local hud = HudBuilder.build(player:WaitForChild("PlayerGui"))

-- ---- cached server state -----------------------------------------------

type CachedPiece = { id: string, pieceType: string, rarity: string, mutation: string, file: number, rank: number, income: number }

local targetMoney = Config.START_MONEY
local shownMoney = Config.START_MONEY
local income = 0
local rebirth = 0
local rebirthCost = Config.REBIRTH_BASE_COST
local pieces: { [string]: CachedPiece } = {}
local codexFound: { [string]: boolean } = {}
local codexCount = 0
local quests: { [string]: number } = {}
local questsDone: { [string]: boolean } = {}
local upgradesOwned: { [string]: boolean } = {}
local carryingId: string? = nil
local lockSeconds = 0
local lockCooldown = 0
local eventName = ""
local eventBanner = ""
local eventEndsIn = 0
local nextEventName = ""
local nextEventIn = 0
local rebirthArmAt = 0
local whackReadyAt = 0

-- ---- highlights ----------------------------------------------------------

local highlightFolder = Instance.new("Folder")
highlightFolder.Name = "Highlights"
highlightFolder.Parent = Workspace

local selectedId: string? = nil

local function clearHighlights()
	highlightFolder:ClearAllChildren()
	selectedId = nil
end

local function highlightSquare(file: number, rank: number, color: Color3)
	local pos = Board.squareToWorld(file, rank)
	local p = Instance.new("Part")
	p.Name = "Highlight"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.45
	p.Size = Vector3.new(3.8, 0.2, 3.8)
	p.Position = pos + Vector3.new(0, 0.15, 0)
	p.Parent = highlightFolder
end

local function selectPiece(rec: CachedPiece)
	clearHighlights()
	selectedId = rec.id
	highlightSquare(rec.file, rec.rank, Color3.fromRGB(255, 220, 60))
	local occupied: { [string]: string } = {}
	for _, other in pairs(pieces) do
		if other.id ~= rec.id then
			occupied[Board.squareKey(other.file, other.rank)] = "own"
		end
	end
	local legal = Board.legalTargets(rec.pieceType, rec.file, rec.rank, occupied)
	for _, sq in ipairs(legal.moves) do
		highlightSquare(sq.file, sq.rank, Color3.fromRGB(60, 220, 90))
	end
	for _, sq in ipairs(legal.captures) do
		highlightSquare(sq.file, sq.rank, Color3.fromRGB(230, 60, 60))
	end
end

-- ---- helpers -------------------------------------------------------------

local function modelOf(part: Instance?): Model?
	local node: Instance? = part
	while node ~= nil do
		if node:IsA("Model") and node:GetAttribute("Kind") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function pieceNameOf(id: string): string
	local rec = pieces[id]
	if rec == nil then
		return "a piece"
	end
	return PieceData.pieceName(rec.pieceType :: PieceData.PieceType, rec.rarity :: PieceData.RarityName)
end

local function refreshBottom()
	local lockText = "READY"
	if lockSeconds > 0 then
		lockText = "LOCKED " .. tostring(math.ceil(lockSeconds)) .. "s"
	elseif lockCooldown > 0 then
		lockText = "READY " .. tostring(math.ceil(lockCooldown)) .. "s"
	end
	local whackText = if os.clock() >= whackReadyAt then "READY" else "…"
	local bought = 0
	for _ in pairs(upgradesOwned) do
		bought += 1
	end
	hud:setBottom(lockText, whackText, bought, rebirthCost, codexCount)
end

local function doRebirth()
	if os.clock() - rebirthArmAt < 3 then
		ChessRequest:FireServer("Rebirth", {})
		rebirthArmAt = 0
	else
		rebirthArmAt = os.clock()
		hud:showToast("Press R again to REBIRTH for " .. tostring(rebirthCost) .. " — money resets, income ×3!")
	end
end

-- ---- clicks --------------------------------------------------------------

mouse.Button1Down:Connect(function()
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		return
	end
	local target = mouse.Target
	local model = modelOf(target)
	if model ~= nil then
		local kind = model:GetAttribute("Kind")
		if kind == "parade" then
			local primary = model.PrimaryPart
			if primary ~= nil then
				local slot = math.floor((primary.Position.X - Config.PARADE_X_START) / Config.PARADE_X_STEP) + 1
				ChessRequest:FireServer("Buy", { slot = slot })
			end
			return
		elseif kind == "rival" then
			local rivalIndex = model:GetAttribute("RivalIndex")
			local pieceId = model:GetAttribute("PieceId")
			if typeof(rivalIndex) == "number" and typeof(pieceId) == "string" then
				ChessRequest:FireServer("Capture", { rivalIndex = rivalIndex, pieceId = pieceId })
			end
			return
		elseif kind == "thief" or kind == "boss" then
			ChessRequest:FireServer("Whack", {})
			return
		elseif kind == "runaway" then
			ChessRequest:FireServer("CatchRunaway", {})
			return
		elseif kind == "board" then
			if carryingId ~= nil then
				return
			end
			local pieceId = model:GetAttribute("PieceId")
			if typeof(pieceId) == "string" then
				local rec = pieces[pieceId]
				if rec ~= nil then
					selectPiece(rec)
				end
			end
			return
		end
	end
	-- Clicked empty space: move the selected piece, or deposit a carried one.
	if target ~= nil then
		local sq = Board.worldToSquare(target.Position)
		if sq ~= nil then
			if carryingId ~= nil then
				ChessRequest:FireServer("Deposit", { file = sq.file, rank = sq.rank })
				return
			end
			if selectedId ~= nil then
				local rec = pieces[selectedId]
				if rec ~= nil then
					local occupied: { [string]: string } = {}
					for _, other in pairs(pieces) do
						if other.id ~= rec.id then
							occupied[Board.squareKey(other.file, other.rank)] = "own"
						end
					end
					local legal = Board.legalTargets(rec.pieceType, rec.file, rec.rank, occupied)
					for _, move in ipairs(legal.moves) do
						if move.file == sq.file and move.rank == sq.rank then
							ChessRequest:FireServer("SelectMove", { pieceId = rec.id, file = sq.file, rank = sq.rank })
							clearHighlights()
							return
						end
					end
				end
			end
		end
	end
	clearHighlights()
end)

-- ---- keys + buttons ------------------------------------------------------

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		hud:toggleCodex()
	elseif input.KeyCode == Enum.KeyCode.U then
		hud:toggleUpgrades()
	elseif input.KeyCode == Enum.KeyCode.L then
		ChessRequest:FireServer("Lock", {})
	elseif input.KeyCode == Enum.KeyCode.F then
		ChessRequest:FireServer("Whack", {})
		whackReadyAt = os.clock() + Config.WHACK_COOLDOWN
	elseif input.KeyCode == Enum.KeyCode.R then
		doRebirth()
	end
end)

hud.lockButton.Activated:Connect(function()
	ChessRequest:FireServer("Lock", {})
end)
hud.whackButton.Activated:Connect(function()
	ChessRequest:FireServer("Whack", {})
	whackReadyAt = os.clock() + Config.WHACK_COOLDOWN
end)
hud.upgradesButton.Activated:Connect(function()
	hud:toggleUpgrades()
end)
hud.rebirthButton.Activated:Connect(doRebirth)
hud.codexButton.Activated:Connect(function()
	hud:toggleCodex()
end)

-- Quest claim buttons.
for i, q in ipairs(Config.QUESTS) do
	local row = hud.questRows[i]
	if row ~= nil then
		local claim = row:FindFirstChild("Claim")
		if claim ~= nil and claim:IsA("TextButton") then
			claim.Activated:Connect(function()
				ChessRequest:FireServer("Quest", { id = q.id })
			end)
		end
	end
end

-- Upgrade buy buttons.
for _, u in ipairs(Config.UPGRADES) do
	local row = hud.upgradesList:FindFirstChild("Upgrade_" .. u.id)
	if row ~= nil then
		local buy = row:FindFirstChild("Buy")
		if buy ~= nil and buy:IsA("TextButton") then
			buy.Activated:Connect(function()
				ChessRequest:FireServer("Upgrade", { id = u.id })
			end)
		end
	end
end

-- Codex tiles: tap a tile to read its joke/flavour line.
for row, pieceType in ipairs(PieceData.TYPE_ORDER) do
	for _, rarity in ipairs(PieceData.RARITIES) do
		local tile = hud.codexGrid:FindFirstChild("Tile_" .. pieceType .. "_" .. rarity.name)
		if tile ~= nil and tile:IsA("TextButton") then
			tile.Activated:Connect(function()
				local info = PieceData.TYPES[pieceType]
				hud:showToast(PieceData.pieceName(pieceType, rarity.name) .. " — " .. info.flavour)
			end)
		end
	end
end

-- ---- server updates ------------------------------------------------------

local function applyState(payload: { [string]: any })
	targetMoney = tonumber(payload.money) or targetMoney
	income = tonumber(payload.income) or 0
	rebirth = tonumber(payload.rebirth) or 0
	rebirthCost = tonumber(payload.rebirthCost) or rebirthCost
	pieces = {}
	if type(payload.pieces) == "table" then
		for _, p in ipairs(payload.pieces) do
			pieces[p.id] = {
				id = p.id,
				pieceType = p.pieceType,
				rarity = p.rarity,
				mutation = p.mutation,
				file = tonumber(p.file) or 1,
				rank = tonumber(p.rank) or 1,
				income = tonumber(p.income) or 0,
			}
		end
	end
	codexFound = {}
	if type(payload.codexKeys) == "table" then
		codexFound = payload.codexKeys
	end
	codexCount = tonumber(payload.codexFound) or 0
	if type(payload.quests) == "table" then
		quests = payload.quests
	end
	if type(payload.questsDone) == "table" then
		questsDone = payload.questsDone
	end
	if type(payload.upgrades) == "table" then
		upgradesOwned = payload.upgrades
	end
	lockSeconds = tonumber(payload.lockSeconds) or 0
	lockCooldown = tonumber(payload.lockCooldown) or 0
	carryingId = payload.carrying
	hud:setQuests(quests, questsDone)
	hud:setCodex(codexFound, codexCount)
	hud:setUpgrades(upgradesOwned, targetMoney)
	refreshBottom()
	if carryingId ~= nil then
		hud:setCarrying(pieceNameOf(carryingId))
	else
		hud:setCarrying("")
	end
end

ChessUpdate.OnClientEvent:Connect(function(kind: string, payload: { [string]: any })
	if kind == "State" then
		applyState(payload)
	elseif kind == "Money" then
		targetMoney = tonumber(payload.money) or targetMoney
		income = tonumber(payload.income) or income
		hud:setUpgrades(upgradesOwned, targetMoney)
		refreshBottom()
	elseif kind == "Event" then
		eventName = tostring(payload.name or "")
		eventBanner = tostring(payload.banner or "")
		eventEndsIn = tonumber(payload.endsIn) or 0
		nextEventName = tostring(payload.nextName or "")
		nextEventIn = tonumber(payload.nextIn) or 0
		hud:setEvent(eventName, eventBanner, eventEndsIn, nextEventName, nextEventIn)
	elseif kind == "Toast" then
		hud:showToast(tostring(payload.text or ""))
	elseif kind == "Denied" then
		hud:showToast("DENIED! LOCKED")
	elseif kind == "Carrying" then
		local name = tostring(payload.name or "")
		hud:setCarrying(name)
		if name == "" then
			carryingId = nil
		end
	elseif kind == "Float" then
		local pos = payload.pos
		if typeof(pos) == "Vector3" and camera ~= nil then
			local screenPos, onScreen = camera:WorldToViewportPoint(pos)
			if onScreen then
				local color = payload.color
				if typeof(color) ~= "Color3" then
					color = Color3.fromRGB(255, 210, 60)
				end
				hud:spawnFloat(Vector2.new(screenPos.X, screenPos.Y), tostring(payload.text or ""), color)
			end
		end
	end
end)

-- ---- per-frame: money count-up + event countdown -------------------------

local lastTick = os.clock()
RunService.RenderStepped:Connect(function(_dt: number)
	-- Money counts up toward the server value, never jumps.
	if shownMoney ~= targetMoney then
		local gap = targetMoney - shownMoney
		local step = math.max(math.abs(gap) * 0.12, math.max(1, income * 0.02))
		if math.abs(gap) <= step then
			shownMoney = targetMoney
		else
			shownMoney += if gap > 0 then step else -step
		end
		hud:setMoney(math.floor(shownMoney + 0.5), income, rebirth)
	end
	-- Event countdown, refreshed twice a second.
	if os.clock() - lastTick >= 0.5 then
		lastTick = os.clock()
		if eventEndsIn > 0 then
			eventEndsIn -= 0.5
		end
		if nextEventIn > 0 then
			nextEventIn -= 0.5
		end
		if lockSeconds > 0 then
			lockSeconds -= 0.5
		end
		if lockCooldown > 0 then
			lockCooldown -= 0.5
		end
		hud:setEvent(eventName, eventBanner, math.max(0, eventEndsIn), nextEventName, math.max(0, nextEventIn))
		refreshBottom()
	end
end)

-- A gentle camera nudge: pull the default camera back a touch on spawn so
-- the board and the parade both fit the first frame.
task.delay(1, function()
	local character = player.Character
	if character ~= nil then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") then
			root.CFrame = CFrame.new(0, 2, 30)
		end
	end
end)

ChessRequest:FireServer("Hello", {})
hud:showToast("Welcome to Chess Brainrot! Buy pieces on the Grandmaster's Parade.")
print("Chess Brainrot client ready.")
