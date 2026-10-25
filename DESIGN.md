# Pinpoint Azeroth — design

A WoW Forever addon, published on CurseForge, inspired by the daily geography game [MapTap](https://maptap.gg): every day you get five place names and tap where you think each one is on a label-free map of Azeroth. The closer you are, the more points you score.

## Decisions

| Topic | Decision |
|---|---|
| Game | WoW Forever only: Blizzard's Classic+ branch on the modern client (Interface `16001`, Lua 5.1), with vanilla geography. Map IDs are the Classic ones (Kalimdor `1414`, Eastern Kingdoms `1415`, zones `1411`–`1458`), with an English name lookup as fallback. |
| Name | **Pinpoint Azeroth**. Not "MapTap", to stay clear of their brand. Slash `/pinpoint`, `/pa`. |
| Clues | Place names: capitals, towns, dungeons, landmarks, subzones. Drawn from a hand-curated pool of **500+** places, each with exact coordinates and a difficulty tier. Places from both factions, so everyone shares the same pool. |
| Map | Eastern Kingdoms and Kalimdor only. |
| Guess frame | Our own window showing both continents side by side (like the Azeroth map), with no zone names, tooltips or player arrow. A tap on the wrong continent scores 0. |
| Rounds | 5 per game, harder each round: capital or major city → large town → dungeon or landmark → subzone → obscure spot. |
| Scoring | MapTap's structure: 0–100 per round by distance, later rounds weighted more, total out of 1,000. Generous curve: you still score when you're a few zones off. |
| Reveal | After each tap: your tap, the true spot, a line between them, the distance in yards and the points. Click **Next** to continue. |
| Timer | None. Close the window mid-game and resume later. |
| Modes | **Daily:** the same 5 clues for everyone, picked from the realm day. Rolls over at the realm's daily reset. One attempt per account, then view-only. **Practice:** unlimited random games, unscored for the daily. |
| Sharing | A copyable result line, e.g. `Pinpoint Azeroth #142 — 873/1000 🎯🎯🔥🙂😬`. |
| Guild board | Shared over guild addon messages. Scores are sent when you finish and synced at login. Shows today's ranking and monthly totals. Spoiler-safe: guildmates' scores stay hidden until you've played today's daily. |
| History & stats | Account-wide. Every daily kept forever with full replay. Personal stats only (see below). Practice tracked separately. |
| Alts | The daily counts once per account. Your score shows on every guild board you log in to, under the character that's online. |
| Entry | `/pinpoint` (`/pa`) and a minimap button that glows while today's daily is unplayed. |
| UI | One window with tabs: **Play / History / Stats / Guild**. |
| Distribution | Same as Lorecaster: CurseForge, MIT license, public GitHub repo. Tag `v*` → BigWigs packager uploads for Forever. |

## Game rules

### Daily puzzle

- **Realm day.** A day starts at the realm's daily quest reset. The puzzle number is the count of realm days since a fixed launch date (puzzle `#1`).
- **Picking clues.** Each tier has its own deterministic shuffle of its places, seeded by the tier and the "cycle" (`floor(puzzleNumber / tierSize)`). Round *n* takes the place at `puzzleNumber mod tierSize` in tier *n*'s shuffle. So every client with the same pool gets the same five places, and a place doesn't repeat in its tier until the whole tier has been used.
- **Pool stability.** Place IDs are permanent and the pool is append-only. A new pool edition takes effect from a puzzle number written into the data file, so it applies on a future day rather than mid-day. Guild messages carry the pool edition; scores from a different edition are marked on the board as "different puzzle".
- **One attempt.** Once you tap round 1 of the daily, that attempt is the one that counts. You can leave and resume, but not restart. A finished daily is view-only.
- **Day ends mid-game.** An unfinished daily stays playable after the reset and still counts for its own day. The streak uses the day the puzzle belongs to.

### Scoring

- **Distance** is measured in yards between your tap and the place, converted from map coordinates to world positions.
- **Points per round:** `floor(100 · e^(−d / 2000))`, where `d` is the distance in yards. That gives about 100 near the spot, ~60 one zone away, ~37 at 2,000 yd and ~13 at 4,000 yd. The constant is a starting point and gets tuned in the prototype. Wrong continent = 0.
- **Round weights:** ×1, ×1, ×2, ×3, ×3 (total weight 10, so the maximum is 1,000).
- **Result emoji** per round: 🎯 90+, 🔥 70+, 🙂 40+, 😬 10+, ❌ under 10.

### Practice

- 5 rounds with the same tier ramp, places drawn at random (no repeats within a game), same scoring.
- Unlimited, available before or after the daily. Never affects daily stats, streaks or the guild board.

## History & statistics

All stored account-wide in `PinpointAzerothDB`.

- **History** keeps every daily: puzzle number, date, the character who played it, and per round the place ID, your tap (continent + x/y), the distance and the points. Each day is a few hundred bytes, so it's kept forever. The History tab lists past dailies; opening one replays it on the map (taps, true spots and lines).
- **Daily stats:** days played, current and best streak, average, best and worst total, a histogram of daily totals (100-point buckets), and average points per round and per tier.
- **Streaks:** play every realm day or the streak resets to 0 (no grace days).
- **Practice stats** are separate: games played, average total, average points per round and per tier. Only aggregates are kept, no per-game replays.
- **After the daily**, a results screen shows your total, the share line, your updated streak and the histogram with today's bucket highlighted.
- Stats are personal. Guildmates appear only on the guild board.

## Guild board

- **Transport:** `C_ChatInfo.SendAddonMessage` on the `GUILD` channel, prefix `PinpointAz`. Messages are small serialized tables, throttled. ⚠️ Forever inherits Midnight-era chat restrictions: if addon messages are blocked (e.g. in instances), outgoing ones are queued until they're allowed again.
- **Score message:** puzzle number, pool edition, character name, total and per-round points. Taps are not sent.
- **On finish:** you broadcast your score.
- **At login / joining a guild:** you send a sync request with the current month. Online members reply with the entries they know for this month, staggered randomly so they don't all reply at once. You merge them by (character, puzzle number).
- **Spoilers:** until your account has finished today's daily, the Guild tab shows who has played today, not their scores. Past days and the monthly totals are always visible.
- **Today view:** ranking by total, with the emoji line per player.
- **Month view:** sum of daily totals per player for the calendar month, plus days played.
- **Storage:** entries are stored per guild (realm + guild name) in the saved variables. Months older than the previous one are dropped.

## UI

- **Window:** movable, closes with Escape, tabs **Play / History / Stats / Guild**.
- **Play tab:** a clue header ("Round 3 of 5 — The Deadmines", tier label, multiplier), the two-continent map, and buttons for Daily and Practice. Click to place a pin, click again to move it, and **Confirm** to lock it in. Then the reveal, then **Next**.
- **Map art:** continent textures drawn in our own frame. No `WorldMapFrame` hooks (avoids taint and label leaks).
- **Minimap button:** left-click opens the window, right-click opens settings. Glows while today's daily is unplayed. Can be hidden.
- **Settings** (Options → AddOns → Pinpoint Azeroth): show or hide the minimap button, show your score in guild-board messages (opt-out), and reset practice stats.

## Clue pool

- A data file of places: stable ID, display name, tier (1–5), continent, x/y in continent map coordinates (0–1), and an optional alternate name.
- Target **500+** places, roughly 100 per tier, built in batches. The first batch is ~100 places (20 per tier), enough to play. Claude drafts coordinates; every place is spot-checked in game before it ships.
- Rules for a fair place: a name a player could reasonably know, a single clear location (no names that appear in two zones), and a point at the place's centre or entrance.
- In-game dev commands make verifying places fast: `/pa dev near` shows the closest places and how far you are from them, `/pa dev mark` prints your zone coordinates, and `/pa dev check` confirms every map resolved.

## Retail (testing only)

Until Forever launches, the addon also loads in retail (Interface `120105`) so it can be tested. The client is detected from the TOC version (`GetBuildInfo()` ≥ 100000 means retail). Retail uses its own continent and zone IDs, has no name lookup, and leaves out the zones Cataclysm reshaped (Alterac, the Barrens, Stranglethorn, Hillsbrad, Badlands, Dun Morogh, Eastern Plaguelands), along with their places. A place that moved on the retail map can carry a retail coordinate override (Feathermoon Stronghold does). Retail dailies use that smaller pool, so they differ from Forever's.

## MVP scope

The first build covers the game itself and history/stats. Left for later:

- **Guild board** (the whole section above).
- **Options panel.** For now `/pa minimap` toggles the minimap button.
- **Results screen extras.** The summary shows the total, per-round points and streak; the histogram with today's bar is on the Stats tab.
- **Pool size.** 100 places (20 per tier) instead of 500+, all still to be checked in game.
- **Places are stored in zone coordinates**, converted to continent coordinates at runtime with `C_Map.GetMapRectOnMap`, because zone coordinates are what players (and guides) know.

## Code layout

```
PinpointAzeroth.toc  Interface 16001, SavedVariables PinpointAzerothDB
Locales.lua          Translatable UI strings (L["English text"])
Places.lua           Clue pool data (append-only, with pool editions)
Puzzle.lua           Realm day, daily selection, practice selection (pure Lua, unit-tested)
Score.lua            Distance → points, weights, emoji, share line (pure Lua, unit-tested)
Stats.lua            History records, streaks, aggregates (pure Lua, unit-tested)
Geo.lua              Map ID resolution, zone -> continent coordinates, continent sizes in yards
MapView.lua          Two-continent map frame, pins, reveal lines
Window.lua           Main window and tabs (Play / History / Stats; Guild later)
Minimap.lua          Minimap button
Core.lua             Saved variables, slash commands, dev commands, startup
Guild.lua            (later) Addon-message protocol, sync, board storage
Settings.lua         (later) Options panel (modern Settings API)
tests/run.lua        Offline tests for the pure-Lua parts (lua5.1 tests/run.lua)
tests/smoke.lua      Plays a full game against stubbed frames (lua5.1 tests/smoke.lua)
```

The repo root is the addon folder; `.pkgmeta` excludes docs and tests from the release zip.

## Open questions (prototype first)

The first build is a small prototype that answers these before the full pool is written:

1. ⚠️ **Map art:** can our own frame draw the Eastern Kingdoms and Kalimdor continent art (via `C_Map` / map art textures) without zone labels, and line the two up side by side?
2. ⚠️ **Realm day:** does `GetServerTime() + C_DateAndTime.GetSecondsUntilDailyReset()` (or `GetQuestResetTime()`) give a stable day boundary that's the same for everyone on the realm?
3. ⚠️ **Distance:** does `C_Map.GetWorldPosFromMapPos` return consistent yard positions for both continents on Forever, and do the scoring constants feel right?
4. **Addon messages:** do guild addon messages work out of instances on Forever, and what are the throttle limits?
