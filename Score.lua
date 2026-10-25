-- Distance -> points, round weights, totals and the share line. Pure Lua.

local _, ns = ...

local Score = {}
ns.Score = Score

Score.ROUNDS = 5
Score.WEIGHTS = { 1, 1, 2, 3, 3 } -- sums to 10, so the maximum is 1,000
Score.FALLOFF = 2000 -- yards; points = 100 * e^(-d / FALLOFF)
Score.BULLSEYE = 25 -- yards; anything this close scores a full 100

-- pos = { c = continent key, x = 0..1, y = 0..1 }. size = { [key] = { w, h } }
-- in yards. Returns nil when the two are on different continents.
function Score.Distance(a, b, sizes)
    if not a or not b or a.c ~= b.c then
        return nil
    end
    local size = sizes[a.c]
    local dx = (a.x - b.x) * size[1]
    local dy = (a.y - b.y) * size[2]
    return math.sqrt(dx * dx + dy * dy)
end

function Score.Points(distance)
    if not distance then
        return 0
    end
    if distance <= Score.BULLSEYE then
        return 100
    end
    return math.floor(100 * math.exp(-distance / Score.FALLOFF))
end

function Score.Weighted(round, points)
    return points * Score.WEIGHTS[round]
end

-- rounds = array of { p = points }
function Score.Total(rounds)
    local total = 0
    for i, r in ipairs(rounds) do
        total = total + Score.Weighted(i, r.p)
    end
    return total
end

Score.MAX = 0
for _, w in ipairs(Score.WEIGHTS) do
    Score.MAX = Score.MAX + 100 * w
end

local EMOJI = {
    { 90, "\240\159\142\175" }, -- 🎯
    { 70, "\240\159\148\165" }, -- 🔥
    { 40, "\240\159\153\130" }, -- 🙂
    { 10, "\240\159\152\172" }, -- 😬
    { 0, "\226\157\140" }, -- ❌
}

function Score.Emoji(points)
    for _, e in ipairs(EMOJI) do
        if points >= e[1] then
            return e[2]
        end
    end
    return EMOJI[#EMOJI][2]
end

-- In-game colour for a round's points, matching the emoji bands.
function Score.Color(points)
    if points >= 90 then
        return "ff40ff40"
    elseif points >= 70 then
        return "ffffa020"
    elseif points >= 40 then
        return "ffffff40"
    elseif points >= 10 then
        return "ffff8040"
    end
    return "ffff4040"
end

function Score.ShareLine(label, rounds)
    local parts = {}
    for i, r in ipairs(rounds) do
        parts[i] = Score.Emoji(r.p)
    end
    return ("Pinpoint Azeroth %s \226\128\148 %d/%d %s"):format(label, Score.Total(rounds), Score.MAX, table.concat(parts))
end
