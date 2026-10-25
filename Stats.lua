-- History records, streaks and aggregates. Pure Lua.
--
-- history[puzzleNumber] = {
--     n = puzzle number, date = "YYYY-MM-DD", char = "Name-Realm",
--     places = { id, id, id, id, id },
--     rounds = { { c = continent or nil, x, y, d = yards or nil, p = points }, ... },
--     done = true once all rounds are played,
-- }
-- practice = { games = n, sum = total of totals, best = n, rounds = { sum per round } }

local _, ns = ...

local Stats = {}
ns.Stats = Stats

local Score = ns.Score

function Stats.NewPractice()
    return { games = 0, sum = 0, best = 0, rounds = { 0, 0, 0, 0, 0 } }
end

function Stats.AddPractice(practice, rounds)
    local total = Score.Total(rounds)
    practice.games = practice.games + 1
    practice.sum = practice.sum + total
    practice.best = math.max(practice.best, total)
    for i, r in ipairs(rounds) do
        practice.rounds[i] = (practice.rounds[i] or 0) + r.p
    end
end

-- Finished dailies, newest first.
function Stats.Finished(history)
    local list = {}
    for _, record in pairs(history) do
        if record.done then
            list[#list + 1] = record
        end
    end
    table.sort(list, function(a, b)
        return a.n > b.n
    end)
    return list
end

-- Streak counting back from today. Today not being played yet doesn't
-- break the streak; yesterday not being played does.
function Stats.CurrentStreak(history, today)
    local n = today
    if not (history[n] and history[n].done) then
        n = n - 1
    end
    local streak = 0
    while history[n] and history[n].done do
        streak = streak + 1
        n = n - 1
    end
    return streak
end

function Stats.BestStreak(history)
    local best, run, last = 0, 0, nil
    local list = Stats.Finished(history)
    for i = #list, 1, -1 do -- oldest first
        local n = list[i].n
        run = (last and n == last + 1) and run + 1 or 1
        best = math.max(best, run)
        last = n
    end
    return best
end

-- Histogram bucket (1..10) for a daily total: 0-99 is 1, 900-1000 is 10.
function Stats.Bucket(total)
    return math.min(10, math.floor(total / 100) + 1)
end

function Stats.Summary(history, today)
    local list = Stats.Finished(history)
    local s = {
        played = #list,
        streak = Stats.CurrentStreak(history, today),
        bestStreak = Stats.BestStreak(history),
        histogram = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        rounds = {},
    }
    local sum, roundSums = 0, { 0, 0, 0, 0, 0 }
    for _, record in ipairs(list) do
        local total = Score.Total(record.rounds)
        sum = sum + total
        s.best = math.max(s.best or total, total)
        s.worst = math.min(s.worst or total, total)
        local bucket = Stats.Bucket(total)
        s.histogram[bucket] = s.histogram[bucket] + 1
        for i, r in ipairs(record.rounds) do
            roundSums[i] = roundSums[i] + r.p
        end
    end
    if s.played > 0 then
        s.average = sum / s.played
        for i = 1, #roundSums do
            s.rounds[i] = roundSums[i] / s.played
        end
    end
    return s
end
