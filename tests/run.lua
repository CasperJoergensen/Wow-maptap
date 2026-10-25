-- Offline tests for the pure-Lua parts. Run from the repo root:
--   lua5.1 tests/run.lua

local failures, passed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failures = failures + 1
        print("FAIL " .. name .. (detail and (": " .. tostring(detail)) or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, ("got %q, want %q"):format(tostring(got), tostring(want)))
end

local ns = {}
for _, file in ipairs({ "Locales.lua", "Places.lua", "Score.lua", "Puzzle.lua", "Stats.lua", "Geo.lua" }) do
    local chunk = assert(loadfile(file))
    chunk("PinpointAzeroth", ns)
end
local Score, Puzzle, Stats, Geo = ns.Score, ns.Puzzle, ns.Stats, ns.Geo
local ROUNDS = Score.ROUNDS

---------------------------------------------------------------------------
-- Clue pool integrity
---------------------------------------------------------------------------
do
    local ids, names, perTier = {}, {}, {}
    for _, p in ipairs(ns.Places) do
        check("unique id " .. p.id, not ids[p.id])
        ids[p.id] = true
        check("unique name " .. p.name, not names[p.name])
        names[p.name] = true
        check("zone exists for " .. p.name, ns.Zones[p.zone] ~= nil, p.zone)
        check("coords in range for " .. p.name, p.x >= 0 and p.x <= 1 and p.y >= 0 and p.y <= 1)
        check("tier in range for " .. p.name, p.tier >= 1 and p.tier <= ROUNDS)
        check("edition known for " .. p.name, p.edition >= 1 and p.edition <= #ns.EDITIONS)
        perTier[p.tier] = (perTier[p.tier] or 0) + 1
    end
    for id = 1, #ns.Places do
        check("ids have no gaps: " .. id, ids[id])
    end
    for t = 1, ROUNDS do
        check("tier " .. t .. " has places", (perTier[t] or 0) >= 1)
    end
    for key, zone in pairs(ns.Zones) do
        check("zone continent exists: " .. key, ns.Continents[zone.cont] ~= nil)
    end
    eq("tier names", #ns.TIER_NAMES, ROUNDS)
end

---------------------------------------------------------------------------
-- Score
---------------------------------------------------------------------------
local sizes = { KAL = { 1000, 500 }, EK = { 2000, 1000 } }
eq("distance horizontal", Score.Distance({ c = "KAL", x = 0, y = 0 }, { c = "KAL", x = 0.5, y = 0 }, sizes), 500)
eq("distance diagonal", Score.Distance({ c = "EK", x = 0, y = 0 }, { c = "EK", x = 0.3, y = 0.4 }, sizes), math.sqrt(600 ^ 2 + 400 ^ 2))
eq("distance wrong continent", Score.Distance({ c = "EK", x = 0, y = 0 }, { c = "KAL", x = 0, y = 0 }, sizes), nil)
eq("points exact", Score.Points(0), 100)
eq("points bullseye", Score.Points(25), 100)
eq("points just outside bullseye", Score.Points(26), 98)
eq("points at falloff", Score.Points(2000), 36)
eq("points far", Score.Points(20000), 0)
eq("points wrong continent", Score.Points(nil), 0)
eq("max", Score.MAX, 1000)
local perfect = { { p = 100 }, { p = 100 }, { p = 100 }, { p = 100 }, { p = 100 } }
eq("total perfect", Score.Total(perfect), 1000)
eq("total weighted", Score.Total({ { p = 10 }, { p = 20 }, { p = 30 }, { p = 40 }, { p = 50 } }), 10 + 20 + 60 + 120 + 150)
eq("emoji bands", Score.Emoji(95) .. Score.Emoji(70) .. Score.Emoji(40) .. Score.Emoji(10) .. Score.Emoji(9),
    "\240\159\142\175\240\159\148\165\240\159\153\130\240\159\152\172\226\157\140")
check("share line", Score.ShareLine("#3", perfect):find("^Pinpoint Azeroth #3 \226\128\148 1000/1000 ") ~= nil)

---------------------------------------------------------------------------
-- Realm day
---------------------------------------------------------------------------
local DAY = 86400
local launch = Puzzle.LAUNCH_DAY * DAY
-- US-style reset at 15:00 UTC.
local function at(day, hour)
    return launch + day * DAY + hour * 3600
end
local function untilReset(t, resetHour)
    local r = math.floor(t / DAY) * DAY + resetHour * 3600
    if r <= t then
        r = r + DAY
    end
    return r - t
end
eq("after reset", Puzzle.Number(Puzzle.RealmDay(at(0, 16), untilReset(at(0, 16), 15))), 1)
eq("before reset", Puzzle.Number(Puzzle.RealmDay(at(0, 14), untilReset(at(0, 14), 15))), 0)
eq("next day after reset", Puzzle.Number(Puzzle.RealmDay(at(1, 15.01), untilReset(at(1, 15.01), 15))), 2)
eq("jitter early", Puzzle.Number(Puzzle.RealmDay(at(0, 16), untilReset(at(0, 16), 15) - 3)), 1)
eq("jitter late", Puzzle.Number(Puzzle.RealmDay(at(0, 16), untilReset(at(0, 16), 15) + 3)), 1)
-- EU-style reset at 04:00 UTC and Asia-style at 21:00 UTC stay on one day each.
eq("early reset", Puzzle.Number(Puzzle.RealmDay(at(0, 5), untilReset(at(0, 5), 4))), 1)
eq("late reset", Puzzle.Number(Puzzle.RealmDay(at(0, 23), untilReset(at(0, 23), 21))), 1)

---------------------------------------------------------------------------
-- Daily selection
---------------------------------------------------------------------------
do
    local perm = Puzzle.Shuffle(20, 42)
    local seen = {}
    for _, v in ipairs(perm) do
        seen[v] = true
    end
    local count = 0
    for i = 1, 20 do
        count = count + (seen[i] and 1 or 0)
    end
    eq("shuffle is a permutation", count, 20)
    local again = Puzzle.Shuffle(20, 42)
    eq("shuffle is deterministic", table.concat(perm, ","), table.concat(again, ","))
    check("shuffle differs by seed", table.concat(perm, ",") ~= table.concat(Puzzle.Shuffle(20, 43), ","))

    local a = Puzzle.Daily(7, ns.Places, ns.EDITIONS, ROUNDS)
    local b = Puzzle.Daily(7, ns.Places, ns.EDITIONS, ROUNDS)
    eq("daily deterministic", table.concat(a, ","), table.concat(b, ","))
    for t = 1, ROUNDS do
        eq("daily round " .. t .. " uses tier " .. t, ns.PlacesByID[a[t]].tier, t)
    end
    check("daily changes by day", table.concat(a, ",") ~= table.concat(Puzzle.Daily(8, ns.Places, ns.EDITIONS, ROUNDS), ","))

    -- No repeats within a tier until the tier is used up.
    local tiers = Puzzle.Tiers(ns.Places, 1, ROUNDS)
    for t = 1, ROUNDS do
        local n, used, dup = #tiers[t], {}, false
        for day = 1, n do
            local id = Puzzle.Daily(day, ns.Places, ns.EDITIONS, ROUNDS)[t]
            dup = dup or used[id]
            used[id] = true
        end
        check("tier " .. t .. " has no repeats in one cycle", not dup)
    end

    -- Days before launch still work.
    eq("preview daily has 5 places", #Puzzle.Daily(-9, ns.Places, ns.EDITIONS, ROUNDS), ROUNDS)

    -- Editions: a place added in edition 2 isn't used before edition 2 starts.
    local places = {}
    for _, p in ipairs(ns.Places) do
        places[#places + 1] = p
    end
    places[#places + 1] = { id = 9999, tier = 1, name = "New", zone = "elwynn", x = 0.5, y = 0.5, edition = 2 }
    local editions = { 1, 50 }
    eq("edition before", Puzzle.Edition(49, editions), 1)
    eq("edition from", Puzzle.Edition(50, editions), 2)
    local before = false
    for day = 1, 49 do
        before = before or Puzzle.Daily(day, places, editions, ROUNDS)[1] == 9999
    end
    check("new edition place not used early", not before)
    eq("days before edition unchanged", table.concat(Puzzle.Daily(30, places, editions, ROUNDS), ","),
        table.concat(Puzzle.Daily(30, ns.Places, ns.EDITIONS, ROUNDS), ","))

    local practice = Puzzle.Practice(function(n) return n end, ns.Places, ns.EDITIONS, ROUNDS)
    for t = 1, ROUNDS do
        eq("practice round " .. t .. " uses tier " .. t, ns.PlacesByID[practice[t]].tier, t)
    end
end

---------------------------------------------------------------------------
-- Stats
---------------------------------------------------------------------------
do
    local function rec(n, points, done)
        local rounds = {}
        for i = 1, ROUNDS do
            rounds[i] = { p = points }
        end
        return { n = n, rounds = rounds, done = done ~= false }
    end
    local history = { [1] = rec(1, 100), [2] = rec(2, 50), [3] = rec(3, 10), [5] = rec(5, 80), [6] = rec(6, 0, false) }
    eq("streak today unplayed", Stats.CurrentStreak(history, 6), 1)
    eq("streak broken by gap", Stats.CurrentStreak(history, 7), 0)
    eq("streak today played", Stats.CurrentStreak(history, 5), 1)
    eq("streak run", Stats.CurrentStreak(history, 4), 3)
    eq("best streak", Stats.BestStreak(history), 3)
    eq("finished count", #Stats.Finished(history), 4)
    eq("finished newest first", Stats.Finished(history)[1].n, 5)
    eq("bucket 0", Stats.Bucket(0), 1)
    eq("bucket 99", Stats.Bucket(99), 1)
    eq("bucket 100", Stats.Bucket(100), 2)
    eq("bucket 999", Stats.Bucket(999), 10)
    eq("bucket 1000", Stats.Bucket(1000), 10)

    local s = Stats.Summary(history, 6)
    eq("summary played", s.played, 4)
    eq("summary best", s.best, 1000)
    eq("summary worst", s.worst, 100)
    eq("summary average", s.average, (1000 + 500 + 100 + 800) / 4)
    eq("summary histogram top", s.histogram[10], 1)
    eq("summary histogram 500", s.histogram[6], 1)
    eq("summary round average", s.rounds[1], (100 + 50 + 10 + 80) / 4)
    eq("empty summary", Stats.Summary({}, 1).played, 0)

    local practice = Stats.NewPractice()
    Stats.AddPractice(practice, rec(0, 50).rounds)
    Stats.AddPractice(practice, rec(0, 100).rounds)
    eq("practice games", practice.games, 2)
    eq("practice best", practice.best, 1000)
    eq("practice round sum", practice.rounds[3], 150)
end

---------------------------------------------------------------------------
-- Geo
---------------------------------------------------------------------------
do
    local x, y = Geo.ToContinent({ 0.2, 0.4, 0.5, 0.9 }, 0.5, 0.25)
    check("to continent x", math.abs(x - 0.3) < 1e-9, x)
    check("to continent y", math.abs(y - 0.6) < 1e-9, y)
end

---------------------------------------------------------------------------
-- Retail pool (for testing before Forever launches)
---------------------------------------------------------------------------
do
    GetBuildInfo = function() return "12.0.5", "1", "", 120105 end
    local r = {}
    assert(loadfile("Places.lua"))("PinpointAzeroth", r)
    GetBuildInfo = nil
    check("retail detected", r.IS_RETAIL)
    check("classic not retail", not ns.IS_RETAIL)
    local perTier = {}
    for _, p in ipairs(r.Places) do
        check("retail place has a retail zone: " .. p.name, r.Zones[p.zone].retail ~= nil)
        perTier[p.tier] = (perTier[p.tier] or 0) + 1
    end
    for t = 1, ROUNDS do
        check("retail tier " .. t .. " has places", (perTier[t] or 0) >= 10, perTier[t])
    end
    check("retail leaves out reshaped zones", r.PlacesByID[7] == nil) -- Booty Bay
    eq("retail override", r.PlacesByID[33].x, 0.46)
    eq("classic keeps its coords", ns.PlacesByID[33].x, 0.305)
    eq("retail daily has 5 places", #Puzzle.Daily(1, r.Places, r.EDITIONS, ROUNDS), ROUNDS)
end

print(("%d passed, %d failed"):format(passed, failures))
os.exit(failures == 0 and 0 or 1)
