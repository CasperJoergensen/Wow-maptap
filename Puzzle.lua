-- Realm day, daily selection and practice selection. Pure Lua: everything
-- that must match between players lives here and is unit-tested.

local _, ns = ...

local Puzzle = {}
ns.Puzzle = Puzzle

-- Day index (days since 1970-01-01 UTC) of WoW Forever's launch,
-- 2026-11-04. That day's puzzle is #1.
Puzzle.LAUNCH_DAY = 20761

-- Mixed into every shuffle seed so our order isn't trivially guessable.
local SALT = 1337

-- The day index of the current realm day: the UTC date of the most recent
-- daily reset. Reset times are rounded to the minute so the second-level
-- jitter in "seconds until reset" can't flip the day.
function Puzzle.RealmDay(serverTime, secondsUntilReset)
    local nextReset = serverTime + secondsUntilReset
    local lastReset = math.floor((nextReset - 86400) / 60 + 0.5) * 60
    return math.floor(lastReset / 86400)
end

function Puzzle.Number(realmDay)
    return realmDay - Puzzle.LAUNCH_DAY + 1
end

-- Park-Miller "minimal standard" generator. The products stay below 2^53,
-- so plain Lua 5.1 numbers give the same sequence on every client.
local MOD = 2147483647
local function makeRandom(seed)
    local state = seed % MOD
    if state <= 0 then
        state = state + MOD - 1
    end
    return function(n)
        state = (state * 16807) % MOD
        return state % n + 1
    end
end
Puzzle.MakeRandom = makeRandom

-- A permutation of 1..n, fixed for a given seed.
function Puzzle.Shuffle(n, seed)
    local rand = makeRandom(seed)
    local perm = {}
    for i = 1, n do
        perm[i] = i
    end
    for i = n, 2, -1 do
        local j = rand(i)
        perm[i], perm[j] = perm[j], perm[i]
    end
    return perm
end

-- The pool edition in force for a puzzle number.
function Puzzle.Edition(number, editions)
    local edition = 1
    for e, from in ipairs(editions) do
        if number >= from then
            edition = e
        end
    end
    return edition
end

-- Place lists per tier for an edition, in ID order.
function Puzzle.Tiers(places, edition, roundCount)
    local tiers = {}
    for t = 1, roundCount do
        tiers[t] = {}
    end
    for _, place in ipairs(places) do
        if place.edition <= edition and tiers[place.tier] then
            local list = tiers[place.tier]
            list[#list + 1] = place
        end
    end
    for t = 1, roundCount do
        table.sort(tiers[t], function(a, b)
            return a.id < b.id
        end)
    end
    return tiers
end

-- The daily's places, one per tier. Each tier is walked through in a
-- shuffled order, so a place doesn't come back until its whole tier has.
function Puzzle.Daily(number, places, editions, roundCount)
    local tiers = Puzzle.Tiers(places, Puzzle.Edition(number, editions), roundCount)
    local picked = {}
    for t = 1, roundCount do
        local list = tiers[t]
        local n = #list
        local cycle = math.floor((number - 1) / n)
        local index = (number - 1) % n + 1
        local perm = Puzzle.Shuffle(n, SALT + t * 7919 + cycle * 104729)
        picked[t] = list[perm[index]].id
    end
    return picked
end

-- A practice game: one random place per tier from the newest edition.
-- rand(n) returns 1..n.
function Puzzle.Practice(rand, places, editions, roundCount)
    local tiers = Puzzle.Tiers(places, #editions, roundCount)
    local picked = {}
    for t = 1, roundCount do
        local list = tiers[t]
        picked[t] = list[rand(#list)].id
    end
    return picked
end
