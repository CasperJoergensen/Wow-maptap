# In-game test checklist

The addon was built without access to the game. Scoring, daily selection and stats are covered by offline tests (`lua5.1 tests/run.lua`), and `lua5.1 tests/smoke.lua` plays a full game against stubbed frames, but nothing has been seen in WoW Forever yet. Items marked ⚠️ are the least certain. Turn on `/console scriptErrors 1` first.

## Basics

- [ ] Pinpoint Azeroth shows in the AddOns list and loads without Lua errors.
- [ ] No "Some maps weren't found" message at login.
- [ ] `/pa dev check` says all continents and zones were found, and prints the map IDs and sizes. ⚠️ Copy the output: the sizes should be in the tens of thousands of yards, roughly 36,800 × 24,500 (Kalimdor) and 40,700 × 27,100 (Eastern Kingdoms).
- [ ] The minimap button shows, glows, opens the window, and can be dragged around the minimap.

## The map

- [ ] ⚠️ Both continents are drawn side by side (Kalimdor left), with no zone names, tooltips or player arrow. If a panel says "Map art unavailable", copy any error.
- [ ] ⚠️ The art lines up with no gaps between tiles and nothing spilling outside the panels.
- [ ] Clicking puts the yellow pin exactly under the cursor, also with a different UI scale.

## A game

- [ ] Play daily: round 1 shows a city name, the tier and ×1.
- [ ] Confirm is greyed out until you click the map; clicking again moves the pin.
- [ ] After Confirm: green pin with the place name, a line to your pin, the distance and points. ⚠️ The line is drawn between the two pins, also across continents.
- [ ] Quit after round 2, `/reload`, open again: "Resume daily" carries on at round 3.
- [ ] After round 5: all five places with lines, the total and your streak.
- [ ] Share: the box is selected; Ctrl+C and paste into Discord shows the emoji. ⚠️ The emoji may look like boxes inside WoW; that's fine if the pasted text is right.
- [ ] Opening the window again shows "You scored … today", and the minimap glow is gone.
- [ ] Practice plays five rounds and only changes the Practice part of Stats.

## History & stats

- [ ] History lists the daily with date, total, per-round points and character; clicking it shows it on the map.
- [ ] Stats shows played, streaks, average/best/worst, per-round averages and the histogram with today's bar in green.
- [ ] On an alt, today's daily shows as already played (it counts once per account).

## Daily reset

- [ ] ⚠️ After the daily reset, the puzzle number goes up by one, the minimap button glows again and the streak carries on.
- [ ] Two players on the same ruleset get the same five places.

## Checking places

For each place you visit: stand at it and run `/pa dev near`. It should be the closest place and well under 300 yd away. If it isn't, run `/pa dev mark` and send the zone coordinates so `Places.lua` can be fixed.
