-- The main window: Play, History and Stats tabs.

local _, ns = ...
local L = ns.L
local Score, Stats, Puzzle, Geo = ns.Score, ns.Stats, ns.Puzzle, ns.Geo

local Window = {}
ns.Window = Window

local WIDTH = 920
local ROUNDS = Score.ROUNDS

local function color(points, text)
    return ("|c%s%s|r"):format(Score.Color(points), text)
end

local function formatYards(d)
    if d >= 1000 then
        return ("%.1fk yd"):format(d / 1000)
    end
    return ("%d yd"):format(d)
end

function ns.PuzzleLabel(n)
    if n < 1 then
        return L["Preview"]
    end
    return "#" .. n
end

---------------------------------------------------------------------------
-- Frame and tabs
---------------------------------------------------------------------------

local function button(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 110, 24)
    b:SetText(text)
    return b
end

function Window:Build()
    if self.frame then
        return
    end
    local f = CreateFrame("Frame", "PinpointAzerothFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(WIDTH, 470)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    tinsert(UISpecialFrames, f:GetName())
    self.frame = f

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText(L["Pinpoint Azeroth"])

    self.tabs, self.pages = {}, {}
    local prev
    for _, name in ipairs({ "Play", "History", "Stats" }) do
        local tab = button(f, L[name], 90)
        tab:SetPoint("TOPLEFT", prev or f, prev and "TOPRIGHT" or "TOPLEFT", prev and 4 or 12, prev and 0 or -30)
        tab:SetScript("OnClick", function()
            self:ShowTab(name)
        end)
        self.tabs[name] = tab
        local page = CreateFrame("Frame", nil, f)
        page:SetPoint("TOPLEFT", 12, -60)
        page:SetPoint("BOTTOMRIGHT", -12, 10)
        page:Hide()
        self.pages[name] = page
        prev = tab
    end

    self:BuildPlay(self.pages.Play)
    self:BuildHistory(self.pages.History)
    self:BuildStats(self.pages.Stats)
    self:ShowTab("Play")
end

function Window:ShowTab(name)
    for tabName, page in pairs(self.pages) do
        page:SetShown(tabName == name)
        if tabName == name then
            self.tabs[tabName]:LockHighlight()
        else
            self.tabs[tabName]:UnlockHighlight()
        end
    end
    if name == "Play" and not self.game and self.state ~= "summary" then
        self:ShowHome()
    elseif name == "History" then
        self:RefreshHistory()
    elseif name == "Stats" then
        self:RefreshStats()
    end
end

function Window:Toggle()
    self:Build()
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:ShowTab("Play")
    end
end

function Window:Open(tab)
    self:Build()
    self.frame:Show()
    self:ShowTab(tab or "Play")
end

---------------------------------------------------------------------------
-- Play tab
---------------------------------------------------------------------------

function Window:BuildPlay(page)
    self.clue = page:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    self.clue:SetPoint("TOPLEFT", 0, -2)
    self.sub = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.sub:SetPoint("TOPLEFT", self.clue, "BOTTOMLEFT", 0, -4)

    self.map = ns.MapView:Create(page)
    self.map.frame:SetPoint("TOP", page, "TOP", 0, -48)
    self.map:SetClickHandler(function(pos)
        self:OnMapClick(pos)
    end)

    self.status = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.status:SetPoint("BOTTOMLEFT", 0, 8)
    self.status:SetJustifyH("LEFT")

    -- Buttons, right to left.
    self.primary = button(page, "", 130)
    self.primary:SetPoint("BOTTOMRIGHT", 0, 2)
    self.secondary = button(page, "", 130)
    self.secondary:SetPoint("RIGHT", self.primary, "LEFT", -6, 0)
end

local function setButton(b, text, fn)
    if not text then
        b:Hide()
        return
    end
    b:SetText(text)
    b:SetScript("OnClick", fn)
    b:Enable()
    b:Show()
end

function Window:SetButtons(primaryText, primaryFn, secondaryText, secondaryFn)
    setButton(self.primary, primaryText, primaryFn)
    setButton(self.secondary, secondaryText, secondaryFn)
end

function Window:ShowHome()
    self.state, self.game = "home", nil
    self.map:Clear()
    self.map:SetInteractive(false)
    local today = ns.Today()
    local record = ns.db.history[today]
    local unfinished = ns.UnfinishedDaily()
    self.clue:SetText(L["Daily %s"]:format(ns.PuzzleLabel(today)))
    if record and record.done then
        local total = Score.Total(record.rounds)
        self.sub:SetText(L["You scored %d/%d today. Come back after the daily reset."]:format(total, Score.MAX))
        self:SetButtons(L["Today's result"], function()
            self:ShowSummary(record, true)
        end, L["Practice"], function()
            self:StartPractice()
        end)
    elseif unfinished then
        self.sub:SetText(L["Your daily %s isn't finished yet."]:format(ns.PuzzleLabel(unfinished.n)))
        self:SetButtons(L["Resume daily"], function()
            self:StartDaily(unfinished.n)
        end, L["Practice"], function()
            self:StartPractice()
        end)
    else
        self.sub:SetText(L["Five places, one try. Tap where you think each one is."])
        self:SetButtons(L["Play daily"], function()
            self:StartDaily(today)
        end, L["Practice"], function()
            self:StartPractice()
        end)
    end
    local streak = Stats.CurrentStreak(ns.db.history, today)
    self.status:SetText(streak > 0 and L["Streak: %d"]:format(streak) or "")
end

-- Looks up every place on the map before a game starts.
local function locateAll(placeIDs)
    local truths = {}
    for i, id in ipairs(placeIDs) do
        truths[i] = Geo:Locate(id)
        if not truths[i] then
            ns.Print(L["Couldn't find %s on the map. Try /pa dev check."]:format(ns.PlacesByID[id].name))
            return nil
        end
    end
    return truths
end

function Window:StartDaily(number)
    local record = ns.db.history[number]
    local places = record and record.places or Puzzle.Daily(number, ns.Places, ns.EDITIONS, ROUNDS)
    local truths = locateAll(places)
    if not truths then
        return
    end
    self.game = { daily = true, number = number, places = places, truths = truths, record = record,
                  rounds = record and record.rounds or {} }
    self:NextRound()
end

function Window:StartPractice()
    local places = Puzzle.Practice(math.random, ns.Places, ns.EDITIONS, ROUNDS)
    local truths = locateAll(places)
    if not truths then
        return
    end
    self.game = { daily = false, places = places, truths = truths, rounds = {} }
    self:NextRound()
end

function Window:NextRound()
    local game = self.game
    local round = #game.rounds + 1
    if round > ROUNDS then
        return self:Finish()
    end
    self.state, self.pending = "guess", nil
    local place = ns.PlacesByID[game.places[round]]
    self.clue:SetText(place.name)
    self.sub:SetText(L["%s round %d of %d \194\183 %s \194\183 points \195\151%d"]:format(
        game.daily and L["Daily"] or L["Practice"], round, ROUNDS, L[ns.TIER_NAMES[place.tier]], Score.WEIGHTS[round]))
    self.status:SetText(L["Click the map to place your pin."])
    self.map:Clear()
    self.map:SetInteractive(true)
    self:SetButtons(L["Confirm"], function()
        self:Confirm()
    end, L["Quit"], function()
        self:ShowHome()
    end)
    self.primary:Disable()
end

function Window:OnMapClick(pos)
    if self.state ~= "guess" then
        return
    end
    self.pending = pos
    self.map:Clear()
    self.map:AddPin(pos, "guess")
    self.status:SetText(L["Click again to move the pin, or Confirm."])
    self.primary:Enable()
end

function Window:Confirm()
    local game, guess = self.game, self.pending
    if self.state ~= "guess" or not guess then
        return
    end
    local round = #game.rounds + 1
    local truth = game.truths[round]
    local d = Score.Distance(guess, truth, Geo.sizes)
    local result = { c = guess.c, x = guess.x, y = guess.y, d = d and math.floor(d + 0.5), p = Score.Points(d) }
    game.rounds[round] = result

    if game.daily then
        -- The first confirmed tap makes this the attempt that counts.
        if not game.record then
            game.record = { n = game.number, date = date("%Y-%m-%d"), char = ns.CharacterName(),
                            places = game.places, rounds = game.rounds, done = false }
            ns.db.history[game.number] = game.record
        end
        game.record.done = #game.rounds == ROUNDS
    end

    self.state = "reveal"
    self.map:SetInteractive(false)
    self.map:Clear()
    self.map:AddLine(guess, truth)
    self.map:AddPin(guess, "guess")
    self.map:AddPin(truth, "truth", ns.PlacesByID[game.places[round]].name)
    local weighted = Score.Weighted(round, result.p)
    local text = d and L["%s away"]:format(formatYards(result.d)) or L["Wrong continent"]
    self.status:SetText(("%s \226\128\148 %s"):format(text,
        color(result.p, L["%d points (\195\151%d = %d)"]:format(result.p, Score.WEIGHTS[round], weighted))))
    local last = round == ROUNDS
    self:SetButtons(last and L["See results"] or L["Next"], function()
        self:NextRound()
    end)
end

function Window:Finish()
    local game = self.game
    self.game = nil
    if game.daily then
        ns.Minimap:Refresh()
        self:ShowSummary(game.record, true)
    else
        Stats.AddPractice(ns.db.practice, game.rounds)
        self:ShowSummary({ places = game.places, rounds = game.rounds }, false)
    end
end

-- All five rounds on the map at once. Used after a game and for history.
function Window:ShowSummary(record, isDaily)
    self:Build()
    self.state = "summary"
    self.map:SetInteractive(false)
    self.map:Clear()
    local parts = {}
    for i, r in ipairs(record.rounds) do
        local truth = Geo:Locate(record.places[i])
        local place = ns.PlacesByID[record.places[i]]
        if truth then
            if r.c then
                self.map:AddLine(r, truth)
                self.map:AddPin(r, "guess")
            end
            self.map:AddPin(truth, "truth", i .. ". " .. place.name)
        end
        parts[i] = color(r.p, tostring(Score.Weighted(i, r.p)))
    end
    local total = Score.Total(record.rounds)
    if isDaily then
        self.clue:SetText(L["Daily %s: %d/%d"]:format(ns.PuzzleLabel(record.n), total, Score.MAX))
        self.sub:SetText(L["Played %s by %s"]:format(record.date or "?", record.char or "?"))
        local streak = Stats.CurrentStreak(ns.db.history, ns.Today())
        self.status:SetText(table.concat(parts, "  ") .. "   " .. L["Streak: %d"]:format(streak))
    else
        self.clue:SetText(L["Practice: %d/%d"]:format(total, Score.MAX))
        self.sub:SetText(L["Practice games don't count toward your daily stats."])
        self.status:SetText(table.concat(parts, "  "))
    end
    local label = isDaily and ns.PuzzleLabel(record.n) or L["practice"]
    self:SetButtons(L["Share"], function()
        self:ShowShare(Score.ShareLine(label, record.rounds))
    end, L["Back"], function()
        self:ShowHome()
    end)
    self:ShowTabOnly("Play")
end

-- Switches the visible page without resetting the Play tab.
function Window:ShowTabOnly(name)
    for tabName, page in pairs(self.pages) do
        page:SetShown(tabName == name)
        if tabName == name then
            self.tabs[tabName]:LockHighlight()
        else
            self.tabs[tabName]:UnlockHighlight()
        end
    end
end

function Window:ShowShare(text)
    if not self.share then
        local s = CreateFrame("Frame", "PinpointAzerothShare", self.frame, "BasicFrameTemplateWithInset")
        s:SetSize(460, 90)
        s:SetPoint("CENTER")
        s:SetFrameStrata("DIALOG")
        local hint = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOP", 0, -30)
        hint:SetText(L["Press Ctrl+C to copy, then paste it anywhere."])
        local box = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
        box:SetSize(420, 24)
        box:SetPoint("TOP", hint, "BOTTOM", 0, -8)
        box:SetAutoFocus(true)
        box:SetScript("OnEscapePressed", function()
            s:Hide()
        end)
        box:SetScript("OnTextChanged", function(b, user)
            if user then
                b:SetText(s.text)
                b:HighlightText()
            end
        end)
        s.box = box
        self.share = s
    end
    self.share.text = text
    self.share.box:SetText(text)
    self.share:Show()
    self.share.box:SetFocus()
    self.share.box:HighlightText()
end

---------------------------------------------------------------------------
-- History tab
---------------------------------------------------------------------------

local ROW_HEIGHT = 20

function Window:BuildHistory(page)
    local header = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText(L["Past dailies \226\128\148 click one to see it on the map"])
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -24)
    scroll:SetPoint("BOTTOMRIGHT", -26, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(WIDTH - 60, 1)
    scroll:SetScrollChild(child)
    self.historyChild, self.historyRows = child, {}
    self.historyEmpty = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    self.historyEmpty:SetPoint("TOP", 0, -60)
    self.historyEmpty:SetText(L["No dailies played yet."])
end

function Window:RefreshHistory()
    local list = Stats.Finished(ns.db.history)
    for i, record in ipairs(list) do
        local row = self.historyRows[i]
        if not row then
            row = CreateFrame("Button", nil, self.historyChild)
            row:SetSize(WIDTH - 60, ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetPoint("LEFT", 4, 0)
            self.historyRows[i] = row
        end
        local parts = {}
        for r, round in ipairs(record.rounds) do
            parts[r] = color(round.p, ("%3d"):format(round.p))
        end
        row.text:SetText(("%-6s  %s   |cffffd200%4d|r   %s   |cff999999%s|r"):format(
            ns.PuzzleLabel(record.n), record.date or "", Score.Total(record.rounds), table.concat(parts, " "), record.char or ""))
        row:SetScript("OnClick", function()
            self:ShowSummary(record, true)
        end)
        row:Show()
    end
    for i = #list + 1, #self.historyRows do
        self.historyRows[i]:Hide()
    end
    self.historyChild:SetHeight(math.max(1, #list * ROW_HEIGHT))
    self.historyEmpty:SetShown(#list == 0)
end

---------------------------------------------------------------------------
-- Stats tab
---------------------------------------------------------------------------

local BAR_MAX = 300

function Window:BuildStats(page)
    self.statsLeft = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.statsLeft:SetPoint("TOPLEFT", 0, 0)
    self.statsLeft:SetJustifyH("LEFT")
    self.statsLeft:SetSpacing(4)

    local histTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    histTitle:SetPoint("TOPLEFT", 440, 0)
    histTitle:SetText(L["Daily score distribution"])
    self.bars = {}
    for i = 10, 1, -1 do
        local row = 10 - i
        local label = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("TOPLEFT", histTitle, "BOTTOMLEFT", 0, -8 - row * 22)
        label:SetWidth(70)
        label:SetJustifyH("RIGHT")
        label:SetText(i == 10 and "900\226\128\1471000" or ("%d\226\128\147%d"):format((i - 1) * 100, i * 100 - 1))
        local bar = page:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("LEFT", label, "RIGHT", 8, 0)
        bar:SetHeight(16)
        local count = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        count:SetPoint("LEFT", bar, "RIGHT", 4, 0)
        self.bars[i] = { bar = bar, count = count }
    end
end

function Window:RefreshStats()
    local today = ns.Today()
    local s = Stats.Summary(ns.db.history, today)
    local lines = {
        "|cffffd200" .. L["Daily"] .. "|r",
        L["Played: %d"]:format(s.played),
        L["Current streak: %d"]:format(s.streak),
        L["Best streak: %d"]:format(s.bestStreak),
    }
    if s.played > 0 then
        lines[#lines + 1] = L["Average: %d   Best: %d   Worst: %d"]:format(s.average + 0.5, s.best, s.worst)
        lines[#lines + 1] = " "
        lines[#lines + 1] = "|cffffd200" .. L["Average points per round"] .. "|r"
        for i = 1, ROUNDS do
            lines[#lines + 1] = ("%d. %s: %s"):format(i, L[ns.TIER_NAMES[i]], color(s.rounds[i], ("%.0f"):format(s.rounds[i])))
        end
    end
    local p = ns.db.practice
    lines[#lines + 1] = " "
    lines[#lines + 1] = "|cffffd200" .. L["Practice"] .. "|r"
    lines[#lines + 1] = L["Games: %d"]:format(p.games)
    if p.games > 0 then
        lines[#lines + 1] = L["Average: %d   Best: %d"]:format(p.sum / p.games + 0.5, p.best)
        local perRound = {}
        for i = 1, ROUNDS do
            perRound[i] = ("%.0f"):format((p.rounds[i] or 0) / p.games)
        end
        lines[#lines + 1] = L["Per round: %s"]:format(table.concat(perRound, " / "))
    end
    self.statsLeft:SetText(table.concat(lines, "\n"))

    -- Histogram, with today's bucket highlighted once today's daily is done.
    local record = ns.db.history[today]
    local todayBucket = record and record.done and Stats.Bucket(Score.Total(record.rounds))
    local most = 1
    for i = 1, 10 do
        most = math.max(most, s.histogram[i])
    end
    for i = 1, 10 do
        local b = self.bars[i]
        local n = s.histogram[i]
        b.bar:SetWidth(math.max(2, BAR_MAX * n / most))
        if i == todayBucket then
            b.bar:SetColorTexture(0.25, 0.85, 0.3, 1)
        else
            b.bar:SetColorTexture(0.45, 0.45, 0.5, 1)
        end
        b.count:SetText(n)
    end
end
