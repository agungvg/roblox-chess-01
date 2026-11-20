--!strict
-- Config: every tunable number for Chess Brainrot in one place.
-- Server and client read the same values so labels never lie.

local Config = {}

Config.GAME_NAME = "Chess Brainrot"
Config.PARADE_SLOTS = 8
Config.PARADE_Z = -24
Config.PARADE_X_START = -28
Config.PARADE_X_STEP = 8
Config.PARADE_SPAWN_INTERVAL = 5 -- seconds between parade spawns
Config.PARADE_LIFETIME = 45 -- seconds before an unbought piece marches off
Config.PARADE_WALK_SPEED = 6 -- studs per second, constant; easing only at ends
Config.BUY_RANGE = 14 -- studs from a pedestal to buy
Config.CAPTURE_RANGE = 12 -- studs from a rival piece to capture it
Config.WHACK_RANGE = 8 -- studs to land a whack
Config.WHACK_COOLDOWN = 0.35 -- seconds
Config.CAPTURE_COOLDOWN = 3 -- seconds between captures
Config.LOCK_DURATION = 30 -- seconds a board stays locked
Config.LOCK_COOLDOWN = 60 -- seconds before it can lock again
Config.INCOME_TICK = 1 -- seconds between income payouts
Config.START_MONEY = 500
Config.REBIRTH_BASE_COST = 100_000_000
Config.REBIRTH_MULT = 3 -- income multiplier per rebirth
Config.MAX_PIECES_PER_BOARD = 32
Config.SAVE_INTERVAL = 60 -- seconds between autosaves

Config.RIVAL_NAMES = {
	"BIG LOU RIVAL",
	"Leo Tamer-Tamer",
	"Rook Ruby",
	"Bishop Bea",
	"Pawn Pete",
} :: { string }

-- Rival mini-board centres, matching default.project.json.
Config.RIVAL_CENTRES = {
	Vector3.new(-46, 0, -8),
	Vector3.new(46, 0, -8),
	Vector3.new(-46, 0, 26),
	Vector3.new(46, 0, 26),
	Vector3.new(0, 0, -44),
} :: { Vector3 }

export type EventInfo = {
	name: string,
	banner: string,
	duration: number,
	incomeMult: number,
}

Config.EVENTS = {
	{ name = "Blitz Storm", banner = "BLITZ STORM! 2x INCOME, 2x PARADE SPEED", duration = 20, incomeMult = 2 },
	{ name = "Checkmate Rush", banner = "CHECKMATE RUSH! A KING MARCHES THE PARADE", duration = 20, incomeMult = 1 },
	{ name = "En Passant Raid", banner = "EN PASSANT RAID! THIEVES ON YOUR BOARD — WHACK THEM!", duration = 20, incomeMult = 1 },
	{ name = "Golden Runaway", banner = "GOLDEN RUNAWAY! CATCH THE GOLDEN PIECE!", duration = 20, incomeMult = 1 },
	{ name = "Night Raid", banner = "NIGHT RAID WITH THE RACCOON KING!", duration = 20, incomeMult = 1 },
	{ name = "Tidal Wave", banner = "TIDAL WAVE! BACK RANK PAYS 3x!", duration = 20, incomeMult = 3 },
} :: { EventInfo }

Config.EVENT_CYCLE = 50 -- seconds between event starts
Config.THIEF_REWARD = 25000
Config.RUNAWAY_REWARD = 500000
Config.BOSS_REWARD = 1000000
Config.BOSS_WHACKS = 3

Config.UPGRADES = {
	{ id = "income1", name = "Polished Pieces", desc = "+25% income", price = 5000, incomeMult = 1.25 },
	{ id = "income2", name = "Gilded Board", desc = "+25% income", price = 50000, incomeMult = 1.25 },
	{ id = "income3", name = "Grandmaster Hall", desc = "+50% income", price = 500000, incomeMult = 1.5 },
	{ id = "luck1", name = "Lucky Dice", desc = "Rarer parade pieces", price = 20000, incomeMult = 1 },
	{ id = "speed1", name = "Clockwork Parade", desc = "Parade spawns 2x faster", price = 15000, incomeMult = 1 },
	{ id = "lock1", name = "Iron Gate", desc = "Lock lasts 2x longer", price = 30000, incomeMult = 1 },
} :: { { id: string, name: string, desc: string, price: number, incomeMult: number } }

export type QuestInfo = {
	id: string,
	text: string,
	target: number,
	reward: number,
}

Config.QUESTS = {
	{ id = "buy_queen", text = "Buy a Queen", target = 1, reward = 25000 },
	{ id = "capture_2", text = "Capture 2 rival pieces", target = 2, reward = 30000 },
	{ id = "whack_3", text = "Whack 3 thieves", target = 3, reward = 20000 },
	{ id = "own_8", text = "Own 8 pieces", target = 8, reward = 40000 },
	{ id = "earn_1m", text = "Earn $1M total", target = 1000000, reward = 50000 },
	{ id = "survive_blitz", text = "Survive a Blitz Storm unhit", target = 1, reward = 25000 },
	{ id = "row_8", text = "Fill a full row of 8", target = 1, reward = 60000 },
	{ id = "rebirth_1", text = "Rebirth once", target = 1, reward = 100000 },
} :: { QuestInfo }

return Config
