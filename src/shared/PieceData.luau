--!strict
-- PieceData: the 48-piece roster (6 types x 8 rarities) + 8 mutations.
-- Original data for Chess Brainrot. Income and price scale with rarity;
-- mutations multiply income. One source of truth for server and client.

export type PieceType = "Pawn" | "Knight" | "Bishop" | "Rook" | "Queen" | "King"
export type RarityName =
	"Common" | "Uncommon" | "Rare" | "Epic" | "Mythic" | "Legendary" | "Secret" | "Divine"

export type RarityInfo = {
	name: RarityName,
	color: Color3,
	priceMult: number,
	incomeMult: number,
	odds: number, -- spawn weight out of 1000
}

export type TypeInfo = {
	name: PieceType,
	basePrice: number,
	baseIncome: number, -- $/s before rarity / mutation / rebirth
	height: number, -- studs tall, drives the silhouette scale
	glyph: string, -- chess glyph used by the Codex + labels
	flavour: string,
}

export type MutationInfo = {
	name: string,
	mult: number,
	color: Color3,
}

local PieceData = {}

PieceData.TYPES = {
	Pawn = { name = "Pawn", basePrice = 120, baseIncome = 12, height = 2.6, glyph = "♟", flavour = "Marches one square at a time, dreams of promotion." },
	Knight = { name = "Knight", basePrice = 900, baseIncome = 95, height = 3.4, glyph = "♞", flavour = "Jumps in an L and lands like it meant to." },
	Bishop = { name = "Bishop", basePrice = 2600, baseIncome = 260, height = 3.8, glyph = "♝", flavour = "Slides diagonally. Never leaves its own colour." },
	Rook = { name = "Rook", basePrice = 7000, baseIncome = 640, height = 3.6, glyph = "♜", flavour = "A castle that learned to walk. Slow, loud, fair." },
	Queen = { name = "Queen", basePrice = 25000, baseIncome = 2100, height = 4.6, glyph = "♛", flavour = "Moves any way she likes. So do you, now." },
	King = { name = "King", basePrice = 120000, baseIncome = 8800, height = 5.0, glyph = "♚", flavour = "Checkmate is not a threat. It is a schedule." },
} :: { [PieceType]: TypeInfo }

PieceData.RARITIES = {
	{ name = "Common", color = Color3.fromRGB(190, 195, 200), priceMult = 1, incomeMult = 1, odds = 380 },
	{ name = "Uncommon", color = Color3.fromRGB(90, 200, 110), priceMult = 3, incomeMult = 3, odds = 260 },
	{ name = "Rare", color = Color3.fromRGB(70, 140, 255), priceMult = 8, incomeMult = 8, odds = 160 },
	{ name = "Epic", color = Color3.fromRGB(170, 90, 240), priceMult = 20, incomeMult = 20, odds = 100 },
	{ name = "Mythic", color = Color3.fromRGB(255, 90, 200), priceMult = 55, incomeMult = 55, odds = 55 },
	{ name = "Legendary", color = Color3.fromRGB(255, 190, 40), priceMult = 150, incomeMult = 150, odds = 30 },
	{ name = "Secret", color = Color3.fromRGB(40, 230, 220), priceMult = 450, incomeMult = 450, odds = 12 },
	{ name = "Divine", color = Color3.fromRGB(255, 255, 255), priceMult = 1200, incomeMult = 1200, odds = 3 },
} :: { RarityInfo }

PieceData.MUTATIONS = {
	{ name = "Sprinkled", mult = 2, color = Color3.fromRGB(255, 150, 200) },
	{ name = "Gold-Plated", mult = 3, color = Color3.fromRGB(255, 200, 40) },
	{ name = "Neon", mult = 4, color = Color3.fromRGB(80, 255, 140) },
	{ name = "Deep-Fried", mult = 5, color = Color3.fromRGB(255, 130, 30) },
	{ name = "Inflated", mult = 6, color = Color3.fromRGB(150, 200, 255) },
	{ name = "Glitched", mult = 7, color = Color3.fromRGB(200, 80, 255) },
	{ name = "Cosmic", mult = 10, color = Color3.fromRGB(120, 90, 255) },
	{ name = "Haunted", mult = 13, color = Color3.fromRGB(180, 255, 90) },
} :: { MutationInfo }

PieceData.TYPE_ORDER = { "Pawn", "Knight", "Bishop", "Rook", "Queen", "King" } :: { PieceType }
PieceData.PIECE_COUNT = 48
PieceData.RARITY_COUNT = 8
PieceData.MUTATION_COUNT = 8
PieceData.BOARD_COUNT = 6
PieceData.EVENT_COUNT = 6

-- First names for the 48 pieces: type + rarity gives a distinct character.
local TITLES = {
	Common = "Peasant",
	Uncommon = "Squire",
	Rare = "Captain",
	Epic = "Baron",
	Mythic = "Duchess",
	Legendary = "Grandmaster",
	Secret = "Shadow",
	Divine = "Immortal",
} :: { [RarityName]: string }

function PieceData.pieceName(pieceType: PieceType, rarity: RarityName): string
	local title = TITLES[rarity]
	return title .. " " .. pieceType
end

function PieceData.rarityInfo(rarity: RarityName): RarityInfo
	for _, info in ipairs(PieceData.RARITIES) do
		if info.name == rarity then
			return info
		end
	end
	return PieceData.RARITIES[1]
end

function PieceData.priceFor(pieceType: PieceType, rarity: RarityName): number
	local t = PieceData.TYPES[pieceType]
	local r = PieceData.rarityInfo(rarity)
	return t.basePrice * r.priceMult
end

function PieceData.incomeFor(pieceType: PieceType, rarity: RarityName, mutationMult: number): number
	local t = PieceData.TYPES[pieceType]
	local r = PieceData.rarityInfo(rarity)
	return t.baseIncome * r.incomeMult * mutationMult
end

-- Weighted rarity roll (odds sum to 1000).
function PieceData.rollRarity(): RarityName
	local roll = math.random(1, 1000)
	local acc = 0
	for _, info in ipairs(PieceData.RARITIES) do
		acc += info.odds
		if roll <= acc then
			return info.name
		end
	end
	return "Common"
end

function PieceData.rollType(): PieceType
	-- Pawns parade most often; Kings almost never.
	local roll = math.random(1, 100)
	if roll <= 42 then
		return "Pawn"
	elseif roll <= 64 then
		return "Knight"
	elseif roll <= 80 then
		return "Bishop"
	elseif roll <= 90 then
		return "Rook"
	elseif roll <= 97 then
		return "Queen"
	else
		return "King"
	end
end

-- 1 in 4 pieces is mutated; the mutation is uniform across the 8.
function PieceData.rollMutation(): (string, number)
	if math.random(1, 4) ~= 1 then
		return "Plain", 1
	end
	local m = PieceData.MUTATIONS[math.random(1, #PieceData.MUTATIONS)]
	return m.name, m.mult
end

function PieceData.mutationColor(name: string): Color3
	for _, m in ipairs(PieceData.MUTATIONS) do
		if m.name == name then
			return m.color
		end
	end
	return Color3.fromRGB(255, 255, 255)
end

return PieceData
