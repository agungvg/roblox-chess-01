# Chess Brainrot

**Chess Brainrot: 48 chess pieces, 8 rarities, 8 mutations, 5 rival boards to capture from and lock against, Blitz Storm, Checkmate Rush, En Passant Raid, Golden Runaway, Night Raid, Tidal Wave, Piece Codex, rebirth.**

A 3D Roblox brainrot game for make.fun's "Make the best AI Roblox brainrot game" bounty (roblox-brainrot-01). Chess pieces march the **Grandmaster's Parade** along the board edge with floating labels (name + rarity + mutation + $/s + BUY price). You buy them onto your 8×8 board, they earn money every second, and you climb the ladder: 6 piece types × 8 rarities = 48 pieces in the Piece Codex, 8 mutations up to ×13, 5 AI rival boards to capture from, locks to defend your own board, thieves to whack, 6 timed global events, quests, upgrades, and rebirth (income ×3 per rebirth).

## The loop

1. **Buy** — walk up to a pedestal on the parade and click a piece. The server checks your balance, the price, and the distance, then tweens the piece onto a free square of your board.
2. **Earn** — every piece on your board pays $/s (rarity × mutation × rebirth × Codex milestones × event multipliers). Money counts up, never jumps.
3. **Capture** — click a piece on a rival board (unless it shows `DENIED! LOCKED`), carry it home overhead, and drop it on a free square of your board.
4. **Defend** — press `L` to lock your board for 30s; press `F` (or click a thief) to whack thieves and the Raccoon King boss during raids.
5. **Progress** — quests pay out, upgrades stack income, the Codex fills 48 tiles, and rebirth at $100M multiplies everything.

Movement is TweenService only, at constant speed with eased ends; every resting position is an exact square centre from one `squareToWorld(file, rank)` function. Selecting one of your pieces highlights its real legal chess moves (green = move, red = capture). The server validates every buy, capture, placement, whack, lock, and rebirth.

## Layout

- `default.project.json` — Rojo project: 449 static parts (main 8×8 board, parade lane + 8 pedestals, 5 rival mini-boards, spawn, lamps, trees) + service maps.
- `src/shared/` — `PieceData` (48-piece roster), `Board` (grid + legal moves), `Config` (events, quests, upgrades), `Format` (money strings).
- `src/server/` — `GameServer.server.luau` (authority: economy, parade, rivals, thieves, events, quests, rebirth, saves) + `PieceBuilder.luau` (procedural chess-piece characters, distinct silhouette per type, humanoid proportions).
- `src/client/` — `GameClient.client.luau` (input, selection + highlights, count-up money, keybinds).
- `src/gui/` — `HudBuilder.luau` (formula bar, money, event banner, quests, bottom bar, Codex, upgrades shop).
- `game.rbxl` — the place Rojo builds from `src/` and `default.project.json`.
- `screenshots/` — 4 composed renders of the real game (no Studio on this Linux build machine; the thumbnail, `1-cover.png`, is a composed picture of the game's own world and characters, as the rules allow). `1-cover.png` is also the game's first thumbnail on Roblox.
- `PLAY.json` — placeholder until the place is published (see below).

## Build

    rojo build default.project.json -o game.rbxl
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

## Publish (Lyso's steps in Studio)

1. Open this project in Roblox Studio (Rojo plugin sync, or open `game.rbxl`).
2. Publish as a new experience named **Chess Brainrot**, Public.
3. In the experience description, put the play code exactly: `makefun-parcel-ranch-highland`
4. On the Creator Dashboard, upload the icon (512×512) and thumbnails — `screenshots/1-cover.png` FIRST as the thumbnail — and wait until the experience page shows both past review.
5. Fill in `PLAY.json` with the real `place_id` and `universe_id`, rebuild, and re-run the kit check:
   `node cli/makefun.mjs check --repo ~/workspace/makefun/roblox-chess-01`

## Rules

The rules are on the bounty's page (/bounty/roblox-brainrot-01) and in the kit's RULES.txt.
