--!strict
-- GameServer: Chess Brainrot server authority.
-- Owns money, inventory, parade, rival boards, captures, locks, whacks,
-- events, quests, rebirth, upgrades and saves. The client only sends an
-- intent ("Buy", "Capture", ...); this script validates everything and
-- decides. Movement is TweenService at constant speed, never a teleport.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Board"))
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local PieceData = require(Shared:WaitForChild("PieceData"))
local PieceBuilder = require(script.Parent:WaitForChild("PieceBuilder"))

local Remotes = ReplicatedStorage:WaitForChild("ChessRemotes")
local ChessRequest = Remotes:WaitForChild("ChessRequest") :: RemoteEvent
local ChessUpdate = Remotes:WaitForChild("ChessUpdate") :: RemoteEvent

local SAVE_STORE = DataStoreService:GetDataStore("ChessBrainrotV1")

export type PieceRecord = {
	id: string,
	pieceType: PieceData.PieceType,
	rarity: PieceData.RarityName,
	mutation: string,
	mult: number,
	price: number,
	income: number,
	location: string, -- "parade" | "board" | "rival" | "carried" | "thief"
	slot: number,
	file: number,
	rank: number,
	rivalIndex: number,
	model: Model?,
	owner: Player?,
}

export type PlayerState = {
	money: number,
	totalEarned: number,
	rebirth: number,
	pieces: { [string]: PieceRecord },
	codex: { [string]: boolean },
	quests: { [string]: number },
	questsDone: { [string]: boolean },
	upgrades: { [string]: boolean },
	lockUntil: number,
	lockCooldownUntil: number,
	carrying: string?,
	lastWhack: number,
	lastCapture: number,
	lastRequest: number,
	hitDuringEvent: boolean,
	thiefHits: number,
}

local states: { [Player]: PlayerState } = {}
local parade: { [number]: PieceRecord? } = {}
local rivals: { [number]: { name: string, centre: Vector3, lockUntil: number, lockEnds: number, pieces: { [string]: PieceRecord } } } = {}
local thieves: { { model: Model, piece: PieceRecord?, homeFile: number, homeRank: number, whacks: number, isBoss: boolean } } = {}
local runaway: PieceRecord? = nil

local eventIndex = 0
local eventActiveUntil = 0
local nextEventAt = os.clock() + 20
local pieceCounter = 0

local function now(): number
	return os.clock()
end

local function nextPieceId(): string
	pieceCounter += 1
	return "P" .. tostring(pieceCounter) .. "_" .. tostring(math.random(1000, 9999))
end

-- Click identity: the client finds a piece by these attributes, never by name.
local function tagModel(model: Model, kind: string, id: string, rivalIndex: number?)
	model:SetAttribute("Kind", kind)
	model:SetAttribute("PieceId", id)
	if rivalIndex ~= nil then
		model:SetAttribute("RivalIndex", rivalIndex)
	end
end

local function codexKey(pieceType: PieceData.PieceType, rarity: PieceData.RarityName): string
	return pieceType .. "_" .. rarity
end

local function codexMult(state: PlayerState): number
	local found = 0
	for _ in pairs(state.codex) do
		found += 1
	end
	if found >= 48 then
		return 3
	elseif found >= 36 then
		return 2
	elseif found >= 24 then
		return 1.75
	elseif found >= 18 then
		return 1.5
	elseif found >= 12 then
		return 1.25
	else
		return 1.1
	end
end

local function currentEvent(): Config.EventInfo?
	if now() < eventActiveUntil then
		return Config.EVENTS[eventIndex]
	end
	return nil
end

local function upgradeIncomeMult(state: PlayerState): number
	local mult = 1
	for id in pairs(state.upgrades) do
		for _, u in ipairs(Config.UPGRADES) do
			if u.id == id then
				mult *= u.incomeMult
			end
		end
	end
	return mult
end

local function pieceIncome(state: PlayerState, rec: PieceRecord): number
	local ev = currentEvent()
	local mult = (Config.REBIRTH_MULT ^ state.rebirth) * upgradeIncomeMult(state) * codexMult(state)
	if ev ~= nil then
		mult *= ev.incomeMult
		if ev.name == "Tidal Wave" and rec.rank == 8 then
			mult *= 3
		end
	end
	if rec.location == "board" then
		return rec.income * mult
	end
	return 0
end

local function totalIncome(state: PlayerState): number
	local sum = 0
	for _, rec in pairs(state.pieces) do
		sum += pieceIncome(state, rec)
	end
	return sum
end

local function countPieces(state: PlayerState): number
	local n = 0
	for _ in pairs(state.pieces) do
		n += 1
	end
	return n
end

local function codexCount(state: PlayerState): number
	local n = 0
	for _ in pairs(state.codex) do
		n += 1
	end
	return n
end

-- ---- outbound -------------------------------------------------------------

local function sendState(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	local pieceList: { { id: string, pieceType: string, rarity: string, mutation: string, file: number, rank: number, income: number } } = {}
	for _, rec in pairs(state.pieces) do
		table.insert(pieceList, {
			id = rec.id,
			pieceType = rec.pieceType,
			rarity = rec.rarity,
			mutation = rec.mutation,
			file = rec.file,
			rank = rec.rank,
			income = pieceIncome(state, rec),
		})
	end
	local rivalLocks: { number } = {}
	for i = 1, #rivals do
		rivalLocks[i] = math.max(0, rivals[i].lockUntil - now())
	end
	ChessUpdate:FireClient(player, "State", {
		money = state.money,
		income = totalIncome(state),
		rebirth = state.rebirth,
		rebirthCost = Config.REBIRTH_BASE_COST * (state.rebirth + 1),
		pieces = pieceList,
		codexFound = codexCount(state),
		codexKeys = state.codex,
		quests = state.quests,
		questsDone = state.questsDone,
		upgrades = state.upgrades,
		lockSeconds = math.max(0, state.lockUntil - now()),
		lockCooldown = math.max(0, state.lockCooldownUntil - now()),
		carrying = state.carrying,
		rivalLocks = rivalLocks,
	})
end

local function toast(player: Player, text: string)
	ChessUpdate:FireClient(player, "Toast", { text = text })
end

local function floatText(player: Player, worldPos: Vector3, text: string, color: Color3)
	ChessUpdate:FireClient(player, "Float", { pos = worldPos, text = text, color = color })
end

local function broadcastEvent()
	local ev = currentEvent()
	if ev ~= nil then
		ChessUpdate:FireAllClients("Event", {
			name = ev.name,
			banner = ev.banner,
			endsIn = math.max(0, eventActiveUntil - now()),
			nextName = Config.EVENTS[(eventIndex % #Config.EVENTS) + 1].name,
			nextIn = math.max(0, nextEventAt - now()),
		})
	else
		ChessUpdate:FireAllClients("Event", {
			name = "",
			banner = "",
			endsIn = 0,
			nextName = Config.EVENTS[(eventIndex % #Config.EVENTS) + 1].name,
			nextIn = math.max(0, nextEventAt - now()),
		})
	end
end

-- ---- quests ---------------------------------------------------------------

local function questProgress(player: Player, id: string, amount: number)
	local state = states[player]
	if state == nil or state.questsDone[id] then
		return
	end
	state.quests[id] = (state.quests[id] or 0) + amount
	for _, q in ipairs(Config.QUESTS) do
		if q.id == id and state.quests[id] >= q.target then
			toast(player, "QUEST COMPLETE: " .. q.text .. " — claim " .. Format.money(q.reward) .. "!")
		end
	end
end

local function checkRowQuest(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	local perRank: { [number]: number } = {}
	for _, rec in pairs(state.pieces) do
		perRank[rec.rank] = (perRank[rec.rank] or 0) + 1
	end
	for _, n in pairs(perRank) do
		if n >= 8 then
			questProgress(player, "row_8", 1)
			return
		end
	end
end

-- ---- board helpers --------------------------------------------------------

local function firstFreeSquare(state: PlayerState): (number, number)
	local taken: { [string]: boolean } = {}
	for _, rec in pairs(state.pieces) do
		taken[Board.squareKey(rec.file, rec.rank)] = true
	end
	for rank = 1, 2 do
		for file = 1, 8 do
			if not taken[Board.squareKey(file, rank)] then
				return file, rank
			end
		end
	end
	for rank = 3, 8 do
		for file = 1, 8 do
			if not taken[Board.squareKey(file, rank)] then
				return file, rank
			end
		end
	end
	return 0, 0
end

local function addToCodex(player: Player, rec: PieceRecord)
	local state = states[player]
	if state == nil then
		return
	end
	local key = codexKey(rec.pieceType, rec.rarity)
	if not state.codex[key] then
		state.codex[key] = true
		toast(player, "CODEX: new entry " .. PieceData.pieceName(rec.pieceType, rec.rarity) .. " (" .. tostring(codexCount(state)) .. "/48)")
	end
end

-- ---- parade ---------------------------------------------------------------

local function paradeSlotPos(slot: number): Vector3
	return Vector3.new(Config.PARADE_X_START + (slot - 1) * Config.PARADE_X_STEP, 1.85, Config.PARADE_Z)
end

local function spawnParadePiece(slot: number, forceType: PieceData.PieceType?)
	local ev = currentEvent()
	local pieceType = forceType or PieceData.rollType()
	local rarity = PieceData.rollRarity()
	if ev ~= nil and ev.name == "Checkmate Rush" and forceType == nil then
		pieceType = "King"
		rarity = "Legendary"
	end
	local mutation, mult = PieceData.rollMutation()
	if ev ~= nil and ev.name == "Blitz Storm" then
		mutation, mult = "Neon", 4
	end
	local income = PieceData.incomeFor(pieceType, rarity, mult)
	local price = PieceData.priceFor(pieceType, rarity)
	local rec: PieceRecord = {
		id = nextPieceId(),
		pieceType = pieceType,
		rarity = rarity,
		mutation = mutation,
		mult = mult,
		price = price,
		income = income,
		location = "parade",
		slot = slot,
		file = 0,
		rank = 0,
		rivalIndex = 0,
		model = nil,
		owner = nil,
	}
	local entry = Vector3.new(-36, 1.85, Config.PARADE_Z)
	local model = PieceBuilder.buildPiece(pieceType, rarity, mutation, CFrame.new(entry))
	local mutText = if mutation == "Plain" then "Plain" else mutation .. " x" .. tostring(mult)
	PieceBuilder.attachLabel(model, {
		PieceData.pieceName(pieceType, rarity),
		rarity .. " · " .. mutText,
		Format.rate(income) .. " · BUY " .. Format.money(price),
	}, PieceData.rarityInfo(rarity).color)
	model.Parent = workspace
	tagModel(model, "parade", rec.id)
	rec.model = model
	parade[slot] = rec
	local speed = Config.PARADE_WALK_SPEED
	if ev ~= nil and ev.name == "Blitz Storm" then
		speed *= 2
	end
	PieceBuilder.tweenPieceTo(model, paradeSlotPos(slot), speed, pieceType)
	-- Lifetime: march off the east end unbought.
	task.delay(Config.PARADE_LIFETIME, function()
		if parade[slot] == rec and rec.location == "parade" then
			parade[slot] = nil
			local m = rec.model
			if m ~= nil then
				PieceBuilder.tweenPieceTo(m, Vector3.new(36, 1.85, Config.PARADE_Z), speed, pieceType)
				task.delay(4, function()
					m:Destroy()
				end)
			end
		end
	end)
end

local function startParade()
	for slot = 1, Config.PARADE_SLOTS do
		task.spawn(function()
			task.wait((slot - 1) * 1.2)
			spawnParadePiece(slot)
		end)
	end
	task.spawn(function()
		while true do
			local interval = Config.PARADE_SPAWN_INTERVAL
			local hasSpeed = false
			for _, u in ipairs(Config.UPGRADES) do
				-- speed upgrade is checked per-player; parade uses the base rate.
			end
			_ = hasSpeed
			task.wait(interval)
			for slot = 1, Config.PARADE_SLOTS do
				if parade[slot] == nil then
					spawnParadePiece(slot)
					break
				end
			end
		end
	end)
end

-- ---- rivals ---------------------------------------------------------------

local function spawnRivalPiece(boardIndex: number, file: number, rank: number)
	local centre = Config.RIVAL_CENTRES[boardIndex]
	local pieceType = PieceData.rollType()
	local rarity = PieceData.rollRarity()
	local mutation, mult = PieceData.rollMutation()
	local rec: PieceRecord = {
		id = nextPieceId(),
		pieceType = pieceType,
		rarity = rarity,
		mutation = mutation,
		mult = mult,
		price = PieceData.priceFor(pieceType, rarity),
		income = PieceData.incomeFor(pieceType, rarity, mult),
		location = "rival",
		slot = 0,
		file = file,
		rank = rank,
		rivalIndex = boardIndex,
		model = nil,
		owner = nil,
	}
	local at = Board.miniSquareToWorld(centre.X, centre.Z, file, rank)
	local model = PieceBuilder.buildPiece(pieceType, rarity, mutation, CFrame.new(at))
	local mutText = if mutation == "Plain" then "Plain" else mutation .. " x" .. tostring(mult)
	PieceBuilder.attachLabel(model, {
		PieceData.pieceName(pieceType, rarity),
		rarity .. " · " .. mutText,
		Format.rate(rec.income) .. " · STEAL",
	}, PieceData.rarityInfo(rarity).color)
	model.Parent = workspace
	tagModel(model, "rival", rec.id, boardIndex)
	rec.model = model
	rivals[boardIndex].pieces[rec.id] = rec
	return rec
end

local function initRivals()
	for i, name in ipairs(Config.RIVAL_NAMES) do
		rivals[i] = {
			name = name,
			centre = Config.RIVAL_CENTRES[i],
			lockUntil = now() + 30 + i * 12,
			lockEnds = 0,
			pieces = {},
		}
		for _, sq in ipairs({ { 2, 7 }, { 4, 7 }, { 6, 7 }, { 8, 6 } }) do
			spawnRivalPiece(i, sq[1], sq[2])
		end
		-- Lock / open sign above the board frame.
		local frame = workspace:FindFirstChild("Rival" .. tostring(i) .. "_FrameN")
		if frame ~= nil and frame:IsA("BasePart") then
			local gui = Instance.new("BillboardGui")
			gui.Name = "RivalSign"
			gui.Size = UDim2.fromOffset(240, 44)
			gui.StudsOffset = Vector3.new(0, 3, 0)
			gui.Parent = frame
			local label = Instance.new("TextLabel")
			label.Name = "Sign"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 0.3
			label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
			label.TextColor3 = Color3.fromRGB(255, 220, 90)
			label.TextScaled = true
			label.Font = Enum.Font.SourceSansBold
			label.Text = name
			label.Parent = gui
		end
	end
	-- Rival lock cycle: each board locks 20s, then opens 40s, staggered.
	task.spawn(function()
		while true do
			task.wait(5)
			for i, r in ipairs(rivals) do
				local locked = now() < r.lockUntil
				local frame = workspace:FindFirstChild("Rival" .. tostring(i) .. "_FrameN")
				if frame ~= nil then
					local gui = frame:FindFirstChild("RivalSign")
					if gui ~= nil then
						local label = gui:FindFirstChild("Sign")
						if label ~= nil and label:IsA("TextLabel") then
							if locked then
								label.Text = r.name .. " · LOCKED " .. tostring(math.floor(r.lockUntil - now())) .. "s"
								label.TextColor3 = Color3.fromRGB(255, 80, 80)
							else
								label.Text = r.name .. " · OPEN — STEAL!"
								label.TextColor3 = Color3.fromRGB(120, 255, 140)
							end
						end
					end
				end
				if not locked and r.lockEnds == 0 then
					r.lockEnds = now()
				end
				if not locked and now() - (r.lockEnds or now()) > 40 then
					r.lockUntil = now() + 20
					r.lockEnds = 0
				end
			end
		end
	end)
end

-- ---- thieves --------------------------------------------------------------

local function spawnThief(isBoss: boolean)
	local pieceType: PieceData.PieceType = if isBoss then "King" else "Pawn"
	local at = Vector3.new(math.random(-50, 50), 1, math.random(-40, 40))
	local model = PieceBuilder.buildPiece(pieceType, "Common", "Plain", CFrame.new(at))
	-- Thieves wear dark metal so they read as enemies at a glance.
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "EyeL" and d.Name ~= "EyeR" then
			d.Color = if isBoss then Color3.fromRGB(120, 20, 40) else Color3.fromRGB(40, 40, 50)
		end
	end
	model.Name = if isBoss then "Raccoon King" else "Thief Pawn"
	model.Parent = workspace
	tagModel(model, if isBoss then "boss" else "thief", "thief_" .. tostring(math.random(1000, 9999)))
	local thief = { model = model, piece = nil :: PieceRecord?, homeFile = 0, homeRank = 0, whacks = 0, isBoss = isBoss }
	table.insert(thieves, thief)
	-- Walk to a random own-board square of the target player and grab a piece.
	local targetSquare = Vector3.new(math.random(-14, 14), 1, math.random(-14, 14))
	local speed = if isBoss then 3 else 5
	PieceBuilder.tweenPieceTo(model, targetSquare, speed, pieceType)
	task.delay(8, function()
		-- Arrived: steal the cheapest board piece if any player owns one.
		local victim: Player? = nil
		local victimRec: PieceRecord? = nil
		for p, st in pairs(states) do
			for _, rec in pairs(st.pieces) do
				if victimRec == nil or rec.income < victimRec.income then
					victim, victimRec = p, rec
				end
			end
		end
		if victim ~= nil and victimRec ~= nil and thief.piece == nil then
			local vst = states[victim]
			if vst ~= nil and now() < vst.lockUntil then
				-- Board is locked: the thief bounces off, empty-handed.
				PieceBuilder.tweenPieceTo(model, Vector3.new(50, 1, 50), speed, pieceType)
				task.delay(6, function()
					model:Destroy()
					for i, t in ipairs(thieves) do
						if t == thief then
							table.remove(thieves, i)
							break
						end
					end
				end)
				return
			end
			thief.piece = victimRec
			thief.homeFile = victimRec.file
			thief.homeRank = victimRec.rank
			if vst ~= nil then
				vst.pieces[victimRec.id] = nil
				vst.hitDuringEvent = true
				sendState(victim)
			end
			local pm = victimRec.model
			if pm ~= nil and pm.PrimaryPart ~= nil then
				pm.PrimaryPart.Anchored = false
				local weld = Instance.new("Weld")
				weld.Part0 = model.PrimaryPart
				weld.Part1 = pm.PrimaryPart
				weld.C0 = CFrame.new(0, 3.5, 0)
				weld.Parent = model.PrimaryPart
			end
			PieceBuilder.tweenPieceTo(model, Vector3.new(50, 1, 50), speed, pieceType)
			task.delay(9, function()
				-- Escaped with the piece: it is gone for good.
				if thief.piece ~= nil then
					local stolen = thief.piece
					thief.piece = nil
					local sm = stolen.model
					if sm ~= nil then
						sm:Destroy()
					end
				end
				model:Destroy()
				for i, t in ipairs(thieves) do
					if t == thief then
						table.remove(thieves, i)
						break
					end
				end
			end)
		else
			model:Destroy()
			for i, t in ipairs(thieves) do
				if t == thief then
					table.remove(thieves, i)
					break
				end
			end
		end
	end)
end

local function spawnRunaway()
	local model = PieceBuilder.buildPiece("Queen", "Divine", "Gold-Plated", CFrame.new(Vector3.new(36, 1, 34)))
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "EyeL" and d.Name ~= "EyeR" then
			d.Color = Color3.fromRGB(255, 210, 60)
		end
	end
	model.Name = "Golden Runaway"
	PieceBuilder.attachLabel(model, { "Golden Runaway Queen", "Divine · Gold-Plated x3", "CATCH ME! +" .. Format.money(Config.RUNAWAY_REWARD) }, Color3.fromRGB(255, 210, 60))
	model.Parent = workspace
	tagModel(model, "runaway", "runaway")
	local rec: PieceRecord = {
		id = nextPieceId(),
		pieceType = "Queen",
		rarity = "Divine",
		mutation = "Gold-Plated",
		mult = 3,
		price = 0,
		income = PieceData.incomeFor("Queen", "Divine", 3),
		location = "parade",
		slot = 0,
		file = 0,
		rank = 0,
		rivalIndex = 0,
		model = model,
		owner = nil,
	}
	runaway = rec
	-- Flee around the board edge on a loop until caught or the event ends.
	task.spawn(function()
		local waypoints = {
			Vector3.new(20, 1, 20), Vector3.new(-20, 1, 20),
			Vector3.new(-20, 1, -20), Vector3.new(20, 1, -20),
		}
		local i = 1
		while runaway == rec and now() < eventActiveUntil do
			local m = rec.model
			if m == nil then
				break
			end
			PieceBuilder.tweenPieceTo(m, waypoints[i], 9, "Queen")
			i = i % #waypoints + 1
			task.wait(4)
		end
	end)
	task.delay(20, function()
		if runaway == rec then
			runaway = nil
			local m = rec.model
			if m ~= nil then
				m:Destroy()
			end
		end
	end)
end

-- ---- events ---------------------------------------------------------------

local function startEvent()
	eventIndex = eventIndex % #Config.EVENTS + 1
	local ev = Config.EVENTS[eventIndex]
	eventActiveUntil = now() + ev.duration
	nextEventAt = now() + Config.EVENT_CYCLE
	broadcastEvent()
	for _, p in ipairs(Players:GetPlayers()) do
		local st = states[p]
		if st ~= nil then
			st.hitDuringEvent = false
		end
	end
	if ev.name == "En Passant Raid" then
		for _ = 1, 3 do
			spawnThief(false)
			task.wait(1)
		end
	elseif ev.name == "Night Raid" then
		spawnThief(true)
	elseif ev.name == "Golden Runaway" then
		spawnRunaway()
	elseif ev.name == "Checkmate Rush" then
		for slot = 1, Config.PARADE_SLOTS do
			if parade[slot] == nil then
				spawnParadePiece(slot, "King")
				break
			end
		end
	end
	task.delay(ev.duration, function()
		-- Survivors of a Blitz Storm with no thief hit complete the quest.
		if ev.name == "Blitz Storm" then
			for _, p in ipairs(Players:GetPlayers()) do
				local st = states[p]
				if st ~= nil and not st.hitDuringEvent then
					questProgress(p, "survive_blitz", 1)
				end
			end
		end
		broadcastEvent()
	end)
end

local function startEventLoop()
	task.spawn(function()
		while true do
			task.wait(1)
			if now() >= nextEventAt and now() >= eventActiveUntil then
				startEvent()
			end
		end
	end)
end

-- ---- income + saves -------------------------------------------------------

local function startIncomeLoop()
	task.spawn(function()
		while true do
			task.wait(Config.INCOME_TICK)
			for player, state in pairs(states) do
				local gain = totalIncome(state)
				if gain > 0 then
					state.money += gain
					state.totalEarned += gain
					questProgress(player, "earn_1m", gain)
				end
				ChessUpdate:FireClient(player, "Money", { money = state.money, income = gain > 0 and totalIncome(state) or totalIncome(state) })
			end
		end
	end)
end

local function saveState(player: Player)
	local state = states[player]
	if state == nil then
		return
	end
	local pieceList: { { pieceType: string, rarity: string, mutation: string, file: number, rank: number } } = {}
	for _, rec in pairs(state.pieces) do
		table.insert(pieceList, {
			pieceType = rec.pieceType,
			rarity = rec.rarity,
			mutation = rec.mutation,
			file = rec.file,
			rank = rec.rank,
		})
	end
	local data = {
		version = 1,
		money = state.money,
		rebirth = state.rebirth,
		totalEarned = state.totalEarned,
		pieces = pieceList,
		codex = state.codex,
		quests = state.quests,
		questsDone = state.questsDone,
		upgrades = state.upgrades,
	}
	pcall(function()
		SAVE_STORE:SetAsync("player_" .. tostring(player.UserId), data)
	end)
end

local function startSaveLoop()
	task.spawn(function()
		while true do
			task.wait(Config.SAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				saveState(player)
			end
		end
	end)
end

-- ---- player lifecycle -----------------------------------------------------

local function newState(): PlayerState
	local quests: { [string]: number } = {}
	for _, q in ipairs(Config.QUESTS) do
		quests[q.id] = 0
	end
	return {
		money = Config.START_MONEY,
		totalEarned = 0,
		rebirth = 0,
		pieces = {},
		codex = {},
		quests = quests,
		questsDone = {},
		upgrades = {},
		lockUntil = 0,
		lockCooldownUntil = 0,
		carrying = nil,
		lastWhack = 0,
		lastCapture = 0,
		lastRequest = 0,
		hitDuringEvent = false,
		thiefHits = 0,
	}
end

local function onPlayerAdded(player: Player)
	local state = newState()
	states[player] = state
	local ok, data = pcall(function()
		return SAVE_STORE:GetAsync("player_" .. tostring(player.UserId))
	end)
	if ok and type(data) == "table" and data.version == 1 then
		state.money = tonumber(data.money) or Config.START_MONEY
		state.rebirth = tonumber(data.rebirth) or 0
		state.totalEarned = tonumber(data.totalEarned) or 0
		if type(data.codex) == "table" then
			state.codex = data.codex
		end
		if type(data.quests) == "table" then
			state.quests = data.quests
		end
		if type(data.questsDone) == "table" then
			state.questsDone = data.questsDone
		end
		if type(data.upgrades) == "table" then
			state.upgrades = data.upgrades
		end
		if type(data.pieces) == "table" then
			for _, saved in ipairs(data.pieces) do
				local pieceType = saved.pieceType :: PieceData.PieceType
				local rarity = saved.rarity :: PieceData.RarityName
				local mutation = saved.mutation :: string
				local mult = 1
				for _, m in ipairs(PieceData.MUTATIONS) do
					if m.name == mutation then
						mult = m.mult
					end
				end
				local rec: PieceRecord = {
					id = nextPieceId(),
					pieceType = pieceType,
					rarity = rarity,
					mutation = mutation,
					mult = mult,
					price = PieceData.priceFor(pieceType, rarity),
					income = PieceData.incomeFor(pieceType, rarity, mult),
					location = "board",
					slot = 0,
					file = tonumber(saved.file) or 1,
					rank = tonumber(saved.rank) or 1,
					rivalIndex = 0,
					model = nil,
					owner = player,
				}
				local at = Board.squareToWorld(rec.file, rec.rank)
				local model = PieceBuilder.buildPiece(pieceType, rarity, mutation, CFrame.new(at))
				model.Parent = workspace
				tagModel(model, "board", rec.id)
				rec.model = model
				state.pieces[rec.id] = rec
			end
		end
	end
	task.delay(2, function()
		if states[player] ~= nil then
			sendState(player)
			broadcastEvent()
		end
	end)
end

local function onPlayerRemoving(player: Player)
	saveState(player)
	local state = states[player]
	if state ~= nil then
		for _, rec in pairs(state.pieces) do
			local m = rec.model
			if m ~= nil then
				m:Destroy()
			end
		end
	end
	states[player] = nil
end

-- ---- remote actions -------------------------------------------------------

local function nearestThief(player: Player)
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local best: any = nil
	local bestDist = Config.WHACK_RANGE
	for _, t in ipairs(thieves) do
		local m = t.model
		if m ~= nil and m.PrimaryPart ~= nil then
			local d = (m.PrimaryPart.Position - root.Position).Magnitude
			if d <= bestDist then
				best, bestDist = t, d
			end
		end
	end
	return best, bestDist
end

local function handleRequest(player: Player, action: string, args: { [string]: any })
	local state = states[player]
	if state == nil then
		return
	end
	-- Cheap per-player rate limit: one request per 0.1s.
	if now() - state.lastRequest < 0.1 and action ~= "Hello" then
		return
	end
	state.lastRequest = now()

	if action == "Hello" then
		sendState(player)
		broadcastEvent()
		return
	end

	local character = player.Character
	local root: BasePart? = nil
	if character ~= nil then
		local found = character:FindFirstChild("HumanoidRootPart")
		if found ~= nil and found:IsA("BasePart") then
			root = found
		end
	end
	local function distTo(pos: Vector3): number
		if root == nil then
			return 1e9
		end
		return (root.Position - pos).Magnitude
	end

	if action == "Buy" then
		local slot = tonumber(args.slot)
		if slot == nil or slot < 1 or slot > Config.PARADE_SLOTS then
			return
		end
		local rec = parade[slot]
		if rec == nil or rec.location ~= "parade" then
			toast(player, "That piece already marched off!")
			return
		end
		if distTo(paradeSlotPos(slot)) > Config.BUY_RANGE then
			toast(player, "Walk up to the pedestal to buy!")
			return
		end
		if state.money < rec.price then
			toast(player, "Not enough money! Need " .. Format.money(rec.price))
			return
		end
		if countPieces(state) >= Config.MAX_PIECES_PER_BOARD then
			toast(player, "Your board is full!")
			return
		end
		local file, rank = firstFreeSquare(state)
		if file == 0 or rank == 0 then
			toast(player, "No free square!")
			return
		end
		state.money -= rec.price
		parade[slot] = nil
		rec.location = "board"
		rec.file = file
		rec.rank = rank
		rec.owner = player
		state.pieces[rec.id] = rec
		addToCodex(player, rec)
		questProgress(player, "buy_queen", if rec.pieceType == "Queen" then 1 else 0)
		questProgress(player, "own_8", 1)
		checkRowQuest(player)
		local model = rec.model
		if model ~= nil then
			tagModel(model, "board", rec.id)
			local label = model.PrimaryPart ~= nil and model.PrimaryPart:FindFirstChild("PieceLabel")
			if label ~= nil then
				label:Destroy()
			end
			PieceBuilder.tweenPieceTo(model, Board.squareToWorld(file, rank), Config.PARADE_WALK_SPEED, rec.pieceType)
		end
		toast(player, "Bought " .. PieceData.pieceName(rec.pieceType, rec.rarity) .. " for " .. Format.money(rec.price))
		sendState(player)
	elseif action == "Capture" then
		local rivalIndex = tonumber(args.rivalIndex)
		local pieceId = tostring(args.pieceId or "")
		if rivalIndex == nil or rivalIndex < 1 or rivalIndex > #rivals then
			return
		end
		if state.carrying ~= nil then
			toast(player, "Already carrying a piece — drop it on your board first!")
			return
		end
		if now() - state.lastCapture < Config.CAPTURE_COOLDOWN then
			return
		end
		local rival = rivals[rivalIndex]
		if now() < rival.lockUntil then
			toast(player, "DENIED! LOCKED — " .. rival.name .. " is locked for " .. tostring(math.floor(rival.lockUntil - now())) .. "s")
			ChessUpdate:FireClient(player, "Denied", { text = "DENIED! LOCKED" })
			return
		end
		local rec = rival.pieces[pieceId]
		if rec == nil or rec.location ~= "rival" then
			return
		end
		local model = rec.model
		if model == nil or model.PrimaryPart == nil then
			return
		end
		if distTo(model.PrimaryPart.Position) > Config.CAPTURE_RANGE then
			toast(player, "Get closer to capture it!")
			return
		end
		state.lastCapture = now()
		rival.pieces[pieceId] = nil
		rec.location = "carried"
		rec.owner = player
		state.carrying = rec.id
		state.pieces[rec.id] = rec
		-- Weld the stolen piece above the carrier's head.
		local primary = model.PrimaryPart
		tagModel(model, "carried", rec.id)
		primary.Anchored = false
		if root ~= nil then
			local weld = Instance.new("Weld")
			weld.Part0 = root
			weld.Part1 = primary
			weld.C0 = CFrame.new(0, 3.5, 0)
			weld.Parent = root
		end
		ChessUpdate:FireClient(player, "Carrying", { name = PieceData.pieceName(rec.pieceType, rec.rarity) })
		toast(player, "CARRYING: " .. PieceData.pieceName(rec.pieceType, rec.rarity) .. " -> DROP AT YOUR BOARD")
		-- The rival restocks after 20s so boards never sit empty.
		task.delay(20, function()
			spawnRivalPiece(rivalIndex, rec.file, rec.rank)
		end)
		sendState(player)
	elseif action == "Deposit" then
		local file = tonumber(args.file)
		local rank = tonumber(args.rank)
		if file == nil or rank == nil or not Board.isSquare(file, rank) then
			return
		end
		local carriedId = state.carrying
		if carriedId == nil then
			return
		end
		local rec = state.pieces[carriedId]
		if rec == nil then
			return
		end
		for _, other in pairs(state.pieces) do
			if other.id ~= rec.id and other.location == "board" and other.file == file and other.rank == rank then
				toast(player, "That square is taken!")
				return
			end
		end
		if root ~= nil and distTo(Board.squareToWorld(file, rank)) > 16 then
			toast(player, "Walk onto your board to drop it!")
			return
		end
		local model = rec.model
		if model ~= nil and model.PrimaryPart ~= nil then
			tagModel(model, "board", rec.id)
			for _, d in ipairs(model.PrimaryPart:GetChildren()) do
				if d:IsA("Weld") then
					d:Destroy()
				end
			end
			if root ~= nil then
				for _, d in ipairs(root:GetChildren()) do
					if d:IsA("Weld") and d.Part1 == model.PrimaryPart then
						d:Destroy()
					end
				end
			end
			model.PrimaryPart.Anchored = true
			PieceBuilder.tweenPieceTo(model, Board.squareToWorld(file, rank), Config.PARADE_WALK_SPEED, rec.pieceType)
		end
		rec.location = "board"
		rec.file = file
		rec.rank = rank
		state.carrying = nil
		addToCodex(player, rec)
		questProgress(player, "capture_2", 1)
		questProgress(player, "own_8", 1)
		checkRowQuest(player)
		ChessUpdate:FireClient(player, "Carrying", { name = "" })
		toast(player, "Captured! " .. PieceData.pieceName(rec.pieceType, rec.rarity) .. " joins your board")
		sendState(player)
	elseif action == "SelectMove" then
		local pieceId = tostring(args.pieceId or "")
		local file = tonumber(args.file)
		local rank = tonumber(args.rank)
		if file == nil or rank == nil then
			return
		end
		local rec = state.pieces[pieceId]
		if rec == nil or rec.location ~= "board" then
			return
		end
		local occupied: { [string]: string } = {}
		for _, other in pairs(state.pieces) do
			if other.id ~= rec.id and other.location == "board" then
				occupied[Board.squareKey(other.file, other.rank)] = "own"
			end
		end
		local legal = Board.legalTargets(rec.pieceType, rec.file, rec.rank, occupied)
		local ok = false
		for _, sq in ipairs(legal.moves) do
			if sq.file == file and sq.rank == rank then
				ok = true
			end
		end
		if not ok then
			toast(player, "Illegal move for a " .. rec.pieceType .. "!")
			return
		end
		rec.file = file
		rec.rank = rank
		local model = rec.model
		if model ~= nil then
			PieceBuilder.tweenPieceTo(model, Board.squareToWorld(file, rank), Config.PARADE_WALK_SPEED, rec.pieceType)
		end
		checkRowQuest(player)
		sendState(player)
	elseif action == "Whack" then
		if now() - state.lastWhack < Config.WHACK_COOLDOWN then
			return
		end
		state.lastWhack = now()
		local thief, dist = nearestThief(player)
		if thief == nil then
			return
		end
		thief.whacks += 1
		local needed = if thief.isBoss then Config.BOSS_WHACKS else 1
		local reward = if thief.isBoss then Config.BOSS_REWARD else Config.THIEF_REWARD
		local model = thief.model
		if thief.whacks >= needed then
			-- Return a stolen piece to its home square.
			if thief.piece ~= nil then
				local stolen = thief.piece
				local sm = stolen.model
				if sm ~= nil and sm.PrimaryPart ~= nil then
					for _, d in ipairs(sm.PrimaryPart:GetChildren()) do
						if d:IsA("Weld") then
							d:Destroy()
						end
					end
					sm.PrimaryPart.Anchored = true
					PieceBuilder.tweenPieceTo(sm, Board.squareToWorld(stolen.homeFile, stolen.homeRank), 8, stolen.pieceType)
				end
				thief.piece = nil
			end
			if model ~= nil and model.PrimaryPart ~= nil then
				local fling = TweenService:Create(
					model.PrimaryPart,
					TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = model.PrimaryPart.CFrame * CFrame.new(0, 6, 0) * CFrame.Angles(math.rad(180), 0, 0) }
				)
				fling:Play()
			end
			task.delay(0.45, function()
				if model ~= nil then
					model:Destroy()
				end
				for i, t in ipairs(thieves) do
					if t == thief then
						table.remove(thieves, i)
						break
					end
				end
			end)
			state.money += reward
			state.thiefHits += 1
			questProgress(player, "whack_3", 1)
			local pos = if model ~= nil and model.PrimaryPart ~= nil then model.PrimaryPart.Position else Vector3.new(0, 4, 0)
			floatText(player, pos, "WHACKED +" .. Format.money(reward), Color3.fromRGB(255, 210, 60))
			toast(player, if thief.isBoss then "RACCOON KING WHACKED! +" .. Format.money(reward) else "WHACKED! +" .. Format.money(reward))
			sendState(player)
		else
			toast(player, "Raccoon King: " .. tostring(thief.whacks) .. "/" .. tostring(needed) .. " whacks!")
		end
	elseif action == "CatchRunaway" then
		local rec = runaway
		if rec == nil or rec.model == nil or rec.model.PrimaryPart == nil then
			return
		end
		if distTo(rec.model.PrimaryPart.Position) > 10 then
			toast(player, "Get closer to catch the Golden Runaway!")
			return
		end
		runaway = nil
		state.money += Config.RUNAWAY_REWARD
		rec.model:Destroy()
		local floatPos = Vector3.new(0, 4, 0)
		if root ~= nil then
			floatPos = root.Position
		end
		floatText(player, floatPos, "CAUGHT! +" .. Format.money(Config.RUNAWAY_REWARD), Color3.fromRGB(255, 210, 60))
		toast(player, "Golden Runaway caught! +" .. Format.money(Config.RUNAWAY_REWARD))
		sendState(player)
	elseif action == "Lock" then
		if now() < state.lockCooldownUntil then
			toast(player, "Lock recharging: " .. tostring(math.floor(state.lockCooldownUntil - now())) .. "s")
			return
		end
		local duration = Config.LOCK_DURATION
		if state.upgrades["lock1"] then
			duration *= 2
		end
		state.lockUntil = now() + duration
		state.lockCooldownUntil = now() + Config.LOCK_COOLDOWN
		toast(player, "Board LOCKED for " .. tostring(duration) .. "s — thieves bounce off!")
		sendState(player)
	elseif action == "Rebirth" then
		local cost = Config.REBIRTH_BASE_COST * (state.rebirth + 1)
		if state.money < cost then
			toast(player, "Rebirth needs " .. Format.money(cost) .. " — you have " .. Format.money(state.money))
			return
		end
		state.money = 0
		state.rebirth += 1
		questProgress(player, "rebirth_1", 1)
		toast(player, "REBIRTH " .. tostring(state.rebirth) .. "! Income x" .. tostring(Config.REBIRTH_MULT ^ state.rebirth))
		sendState(player)
	elseif action == "Upgrade" then
		local id = tostring(args.id or "")
		if state.upgrades[id] then
			return
		end
		for _, u in ipairs(Config.UPGRADES) do
			if u.id == id then
				if state.money < u.price then
					toast(player, "Need " .. Format.money(u.price) .. " for " .. u.name)
					return
				end
				state.money -= u.price
				state.upgrades[id] = true
				toast(player, "Upgrade bought: " .. u.name .. " — " .. u.desc)
				sendState(player)
				return
			end
		end
	elseif action == "Quest" then
		local id = tostring(args.id or "")
		if state.questsDone[id] then
			return
		end
		for _, q in ipairs(Config.QUESTS) do
			if q.id == id then
				if (state.quests[id] or 0) >= q.target then
					state.questsDone[id] = true
					state.money += q.reward
					toast(player, "Quest claimed: " .. q.text .. " +" .. Format.money(q.reward))
					sendState(player)
				else
					toast(player, "Quest not done yet: " .. q.text .. " " .. tostring(state.quests[id] or 0) .. "/" .. tostring(q.target))
				end
				return
			end
		end
	end
end

ChessRequest.OnServerEvent:Connect(function(player: Player, action: any, args: any)
	if typeof(action) ~= "string" then
		return
	end
	if type(args) ~= "table" then
		args = {}
	end
	handleRequest(player, action, args)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveState(player)
	end
end)

-- ---- arena decor ----------------------------------------------------------
-- Lyso: the arena must not look plain. Corner pillars, parade flags,
-- bushes, and two giant statue pieces (King + Queen) flanking the parade.
local function decorPart(name: string, size: Vector3, color: Color3, pos: Vector3, shape: Enum.PartType?, rot: CFrame?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	if shape ~= nil then
		p.Shape = shape
	end
	p.CFrame = CFrame.new(pos) * (rot or CFrame.new())
	p.Parent = workspace
	return p
end

local function buildArenaDecor()
	local gold = Color3.fromRGB(212, 175, 55)
	local dark = Color3.fromRGB(45, 45, 55)
	local marble = Color3.fromRGB(245, 235, 210)
	local upright = CFrame.Angles(0, 0, math.rad(90))
	-- Four corner pillars with gold caps.
	for _, c in ipairs({ { -40, -40 }, { 40, -40 }, { -40, 40 }, { 40, 40 } }) do
		decorPart("PillarBase", Vector3.new(2.6, 0.8, 2.6), marble, Vector3.new(c[1], 0.4, c[2]))
		decorPart("Pillar", Vector3.new(1.6, 10, 1.6), dark, Vector3.new(c[1], 5, c[2]))
		decorPart("PillarCap", Vector3.new(2.0, 2.0, 2.0), gold, Vector3.new(c[1], 11, c[2]), Enum.PartType.Ball)
	end
	-- Five flag poles with coloured flags behind the parade.
	local flagColors = {
		Color3.fromRGB(255, 190, 40),
		Color3.fromRGB(70, 140, 255),
		Color3.fromRGB(90, 200, 110),
		Color3.fromRGB(255, 90, 200),
		Color3.fromRGB(170, 90, 240),
	}
	for i, x in ipairs({ -24, -12, 0, 12, 24 }) do
		decorPart("FlagPole", Vector3.new(0.3, 7, 0.3), dark, Vector3.new(x, 3.5, -31), Enum.PartType.Cylinder, upright)
		decorPart("ParadeFlag", Vector3.new(2.2, 1.2, 0.1), flagColors[i], Vector3.new(x + 1.2, 6.4, -31))
	end
	-- Bushes near the corners, clear of all boards.
	for _, b in ipairs({ { -58, 38 }, { 58, 38 }, { -58, -38 }, { 58, -38 } }) do
		decorPart("Bush", Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(60, 160, 80), Vector3.new(b[1], 1.2, b[2]), Enum.PartType.Ball)
	end
	-- Two giant statues flanking the parade (real pieces, extra scale).
	local king = PieceBuilder.buildPiece("King", "Legendary", "Plain", CFrame.new(-38, 0, -30), 1.6)
	king.Name = "StatueKing"
	king.Parent = workspace
	local queen = PieceBuilder.buildPiece("Queen", "Legendary", "Plain", CFrame.new(38, 0, -30), 1.6)
	queen.Name = "StatueQueen"
	queen.Parent = workspace
	-- Gold plinths under the statues.
	decorPart("StatuePlinth", Vector3.new(7, 0.6, 7), marble, Vector3.new(-38, 0.3, -30))
	decorPart("StatuePlinth", Vector3.new(7, 0.6, 7), marble, Vector3.new(38, 0.3, -30))
end

math.randomseed(os.time())
buildArenaDecor()
initRivals()
startParade()
startEventLoop()
startIncomeLoop()
startSaveLoop()
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
print("Chess Brainrot server ready: parade, 5 rival boards, events, quests, rebirth.")
