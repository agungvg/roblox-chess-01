--!strict
-- Board: the one true grid. Every resting position in the game is a square
-- centre computed by squareToWorld; nothing eyeballs an offset.
-- Files a..h = 1..8 (west to east), ranks 1..8 (south to north).
-- Main board centre is the world origin; squares are 4 studs wide.
-- Rival mini-boards use 2-stud squares around their own centres.

local Board = {}

Board.SQUARE = 4
Board.MINI_SQUARE = 2
Board.FILES = 8
Board.RANKS = 8

export type Square = { file: number, rank: number }

function Board.isSquare(file: number, rank: number): boolean
	return file >= 1 and file <= 8 and rank >= 1 and rank <= 8
end

-- Exact centre of a main-board square, top of the square surface (y = 1).
function Board.squareToWorld(file: number, rank: number): Vector3
	local x = (file - 1) * Board.SQUARE - 14
	local z = 14 - (rank - 1) * Board.SQUARE
	return Vector3.new(x, 1, z)
end

function Board.worldToSquare(pos: Vector3): Square?
	local file = math.floor((pos.X + 16) / Board.SQUARE) + 1
	local rank = 8 - math.floor((pos.Z + 16) / Board.SQUARE)
	if not Board.isSquare(file, rank) then
		return nil
	end
	return { file = file, rank = rank }
end

function Board.squareKey(file: number, rank: number): string
	return tostring(file) .. "," .. tostring(rank)
end

-- Centre of a rival mini-board square (2-stud squares, centre cx, cz).
function Board.miniSquareToWorld(cx: number, cz: number, file: number, rank: number): Vector3
	local x = cx + (file - 1) * Board.MINI_SQUARE - 7
	local z = cz + 7 - (rank - 1) * Board.MINI_SQUARE
	return Vector3.new(x, 0.8, z)
end

function Board.isOnMainBoard(pos: Vector3): boolean
	return math.abs(pos.X) <= 16 and math.abs(pos.Z) <= 16
end

-- Real chess moves for one piece type from a square. `occupied` maps
-- squareKey -> "own" | "enemy". Returns { moves = {Square}, captures = {Square} }.
-- Pawns move north (toward rank 8) and capture diagonally north.
function Board.legalTargets(
	pieceType: string,
	file: number,
	rank: number,
	occupied: { [string]: string }
): { moves: { Square }, captures: { Square } }
	local moves: { Square } = {}
	local captures: { Square } = {}

	local function consider(f: number, r: number, slide: boolean): boolean
		-- Returns false when a sliding piece must stop.
		if not Board.isSquare(f, r) then
			return false
		end
		local occ = occupied[Board.squareKey(f, r)]
		if occ == nil then
			table.insert(moves, { file = f, rank = r })
			return slide
		elseif occ == "enemy" then
			table.insert(captures, { file = f, rank = r })
			return false
		else
			return false
		end
	end

	local function slide(df: number, dr: number)
		local f, r = file + df, rank + dr
		while Board.isSquare(f, r) do
			if not consider(f, r, true) then
				break
			end
			f += df
			r += dr
		end
	end

	if pieceType == "Pawn" then
		local fwd = Board.squareKey(file, rank + 1)
		if Board.isSquare(file, rank + 1) and occupied[fwd] == nil then
			table.insert(moves, { file = file, rank = rank + 1 })
			if rank == 2 then
				local fwd2 = Board.squareKey(file, rank + 2)
				if occupied[fwd2] == nil then
					table.insert(moves, { file = file, rank = rank + 2 })
				end
			end
		end
		for _, df in ipairs({ -1, 1 }) do
			if Board.isSquare(file + df, rank + 1) then
				local key = Board.squareKey(file + df, rank + 1)
				if occupied[key] == "enemy" then
					table.insert(captures, { file = file + df, rank = rank + 1 })
				end
			end
		end
	elseif pieceType == "Knight" then
		for _, step in ipairs({
			{ 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 },
			{ -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 },
		}) do
			consider(file + step[1], rank + step[2], false)
		end
	elseif pieceType == "Bishop" then
		slide(1, 1)
		slide(1, -1)
		slide(-1, 1)
		slide(-1, -1)
	elseif pieceType == "Rook" then
		slide(1, 0)
		slide(-1, 0)
		slide(0, 1)
		slide(0, -1)
	elseif pieceType == "Queen" then
		slide(1, 1)
		slide(1, -1)
		slide(-1, 1)
		slide(-1, -1)
		slide(1, 0)
		slide(-1, 0)
		slide(0, 1)
		slide(0, -1)
	elseif pieceType == "King" then
		for df = -1, 1 do
			for dr = -1, 1 do
				if df ~= 0 or dr ~= 0 then
					consider(file + df, rank + dr, false)
				end
			end
		end
	end

	return { moves = moves, captures = captures }
end

return Board
