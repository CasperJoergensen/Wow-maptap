-- Startup, saved variables and slash commands.

local ADDON_NAME, ns = ...
local L = ns.L

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff6bb8c8Pinpoint Azeroth:|r " .. msg)
end

local function initDB()
    local db = type(PinpointAzerothDB) == "table" and PinpointAzerothDB or {}
    db.history = type(db.history) == "table" and db.history or {}
    db.practice = type(db.practice) == "table" and db.practice or ns.Stats.NewPractice()
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    db.minimap.angle = tonumber(db.minimap.angle) or 210
    PinpointAzerothDB = db
    ns.db = db
end

local function secondsUntilReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        return C_DateAndTime.GetSecondsUntilDailyReset()
    end
    return GetQuestResetTime()
end

-- Today's puzzle number on this realm.
function ns.Today()
    return ns.Puzzle.Number(ns.Puzzle.RealmDay(GetServerTime(), secondsUntilReset()))
end

-- The newest daily that was started but not finished, if any.
function ns.UnfinishedDaily()
    local newest
    for _, record in pairs(ns.db.history) do
        if not record.done and (not newest or record.n > newest.n) then
            newest = record
        end
    end
    return newest
end

function ns.CharacterName()
    local name, realm = UnitFullName("player")
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

---------------------------------------------------------------------------
-- Developer commands for checking the clue pool in game
---------------------------------------------------------------------------

local function devCheck()
    ns.Geo.ready = nil
    if ns.Geo:Init() then
        ns.Print(L["All continents and zones found. %d places."]:format(#ns.Places))
    else
        ns.Print(L["Not found: %s"]:format(table.concat(ns.Geo.missing, ", ")))
    end
    for key, id in pairs(ns.Geo.continents) do
        local size = ns.Geo.sizes[key]
        ns.Print(("  %s = map %d, %.0f x %.0f yd"):format(key, id, size[1], size[2]))
    end
end

local function devMark()
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        ns.Print(L["No map position here."])
        return
    end
    local x, y = pos:GetXY()
    local info = C_Map.GetMapInfo(mapID)
    ns.Print(("%s (map %d): %.1f, %.1f"):format(info and info.name or "?", mapID, x * 100, y * 100))
end

local function devNear()
    local me = ns.Geo:PlayerPos()
    if not me then
        ns.Print(L["No map position here."])
        return
    end
    local results = {}
    for _, place in ipairs(ns.Places) do
        local d = ns.Score.Distance(me, ns.Geo:Locate(place.id), ns.Geo.sizes)
        if d then
            results[#results + 1] = { place = place, d = d }
        end
    end
    table.sort(results, function(a, b)
        return a.d < b.d
    end)
    for i = 1, math.min(3, #results) do
        local r = results[i]
        ns.Print(L["%s (#%d, tier %d): %d yd away, would score %d"]:format(
            r.place.name, r.place.id, r.place.tier, r.d, ns.Score.Points(r.d)))
    end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local HELP = {
    L["/pa - open or close the game"],
    L["/pa history - past dailies"],
    L["/pa stats - your statistics"],
    L["/pa minimap - show or hide the minimap button"],
    L["/pa dev check, /pa dev mark, /pa dev near - tools for checking places in game"],
}

local function handleSlash(input)
    local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd, rest = cmd:lower(), rest:lower()
    if cmd == "" or cmd == "play" then
        ns.Window:Toggle()
    elseif cmd == "history" then
        ns.Window:Open("History")
    elseif cmd == "stats" then
        ns.Window:Open("Stats")
    elseif cmd == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        ns.Minimap:Refresh()
        ns.Print(ns.db.minimap.hide and L["Minimap button hidden."] or L["Minimap button shown."])
    elseif cmd == "dev" and rest == "check" then
        devCheck()
    elseif cmd == "dev" and rest == "mark" then
        devMark()
    elseif cmd == "dev" and rest == "near" then
        devNear()
    else
        for _, line in ipairs(HELP) do
            ns.Print(line)
        end
    end
end

SLASH_PINPOINTAZEROTH1 = "/pinpoint"
SLASH_PINPOINTAZEROTH2 = "/pa"
SlashCmdList.PINPOINTAZEROTH = handleSlash

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        initDB()
    elseif event == "PLAYER_LOGIN" then
        if not ns.Geo:Init() then
            ns.Print(L["Some maps weren't found (%s). Those places can't be played."]:format(table.concat(ns.Geo.missing, ", ")))
        end
        ns.Minimap:Init()
        -- Re-check the glow when the day rolls over while logged in.
        C_Timer.NewTicker(60, function()
            ns.Minimap:Refresh()
        end)
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
