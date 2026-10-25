-- Loads every addon file against permissive WoW stubs and plays a daily
-- and a practice game end to end. It catches nil calls and typos in the UI
-- code; it can't tell whether anything looks right. Run from the repo root:
--   lua5.1 tests/smoke.lua

local printed = {}
local function stubObject(name)
    local obj = { _name = name, _shown = true, _scripts = {}, _events = {} }
    local numbers = { GetWidth = 440, GetHeight = 293, GetLeft = 0, GetTop = 293, GetEffectiveScale = 1, GetFrameLevel = 1 }
    local creators = { CreateTexture = true, CreateFontString = true, CreateLine = true, CreateAnimationGroup = true, CreateAnimation = true }
    return setmetatable(obj, {
        __index = function(t, key)
            if numbers[key] then
                return function() return numbers[key] end
            elseif creators[key] then
                return function() return stubObject() end
            elseif key == "GetName" then
                return function() return t._name end
            elseif key == "SetScript" then
                return function(self, event, fn) self._scripts[event] = fn end
            elseif key == "GetScript" then
                return function(self, event) return self._scripts[event] end
            elseif key == "Show" then
                return function(self) self._shown = true end
            elseif key == "Hide" then
                return function(self) self._shown = false end
            elseif key == "SetShown" then
                return function(self, on) self._shown = not not on end
            elseif key == "IsShown" then
                return function(self) return self._shown end
            elseif key == "GetCenter" then
                return function() return 100, 100 end
            elseif key == "SetText" then
                return function(self, text) self._text = text end
            elseif key == "GetText" then
                return function(self) return self._text end
            elseif key == "RegisterEvent" then
                return function(self, e) self._events[e] = true end
            end
            return function() end
        end,
    })
end

local frames = {}
function CreateFrame(_, name)
    local f = stubObject(name)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = stubObject("UIParent")
Minimap = stubObject("Minimap")
GameTooltip = stubObject("GameTooltip")
GameTooltip_Hide = function() end
UISpecialFrames = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) printed[#printed + 1] = msg end }
SlashCmdList = {}
C_Timer = { NewTicker = function() end, After = function() end }
GetLocale = function() return "enUS" end
GetCursorPosition = function() return 220, 150 end
UnitFullName = function() return "Tester", "Forever" end
local serverTime = (20761 + 3) * 86400 + 16 * 3600 -- puzzle #4, after a 15:00 reset
GetServerTime = function() return serverTime end
C_DateAndTime = { GetSecondsUntilDailyReset = function() return 23 * 3600 end }
Enum = { UIMapType = { Continent = 2, Zone = 3 } }
C_Map = {
    GetMapInfo = function(id)
        if id == 1414 or id == 1415 then
            return { mapID = id, name = id == 1414 and "Kalimdor" or "Eastern Kingdoms", mapType = 2 }
        end
        return { mapID = id, name = "Zone " .. id, mapType = 3 }
    end,
    GetMapRectOnMap = function(id) local o = (id % 7) / 10 return o, o + 0.2, o, o + 0.2 end,
    GetMapChildrenInfo = function() return {} end,
    GetMapWorldSize = function() return 36000, 24000 end,
    GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end,
    GetMapArtLayerTextures = function() local t = {} for i = 1, 12 do t[i] = 1000 + i end return t end,
    GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.4, 0.6 end } end,
}
date = os.date

local ns = {}
local toc = io.open("PinpointAzeroth.toc"):read("*a")
for file in toc:gmatch("\n([%w_]+%.lua)") do
    assert(loadfile(file))("PinpointAzeroth", ns)
end

local function fire(event, ...)
    for _, f in ipairs(frames) do
        local fn = f._scripts.OnEvent
        if fn and f._events and f._events[event] then fn(f, event, ...) end
    end
end
fire("ADDON_LOADED", "PinpointAzeroth")
fire("PLAYER_LOGIN")
assert(ns.Geo.ready, "geo should resolve with stubs")

local W = ns.Window
SlashCmdList.PINPOINTAZEROTH("")
assert(W.frame:IsShown(), "window opens")
assert(ns.Today() == 4, "today is #4, got " .. ns.Today())

local function playRound()
    local panel = W.map.panels.EK
    panel._scripts.OnMouseUp(panel, "LeftButton")
    W.primary._scripts.OnClick() -- Confirm
    W.primary._scripts.OnClick() -- Next / See results
end

W.primary._scripts.OnClick() -- Play daily
assert(W.state == "guess", "daily started")
playRound()
playRound()
assert(ns.db.history[4] and not ns.db.history[4].done, "partial daily saved")
W.secondary._scripts.OnClick() -- Quit mid-game
assert(W.state == "home")
W.primary._scripts.OnClick() -- Resume daily
assert(#W.game.rounds == 2, "resumed at round 3")
for _ = 3, 5 do playRound() end
assert(ns.db.history[4].done, "daily finished")
assert(W.state == "summary", "summary shown")
W.primary._scripts.OnClick() -- Share
assert(W.share.text:find("^Pinpoint Azeroth #4"), "share line")

W.secondary._scripts.OnClick() -- Back
W.secondary._scripts.OnClick() -- Practice
for _ = 1, 5 do playRound() end
assert(ns.db.practice.games == 1, "practice recorded")

W:ShowTab("History")
W:ShowTab("Stats")
SlashCmdList.PINPOINTAZEROTH("dev check")
SlashCmdList.PINPOINTAZEROTH("dev mark")
SlashCmdList.PINPOINTAZEROTH("dev near")
SlashCmdList.PINPOINTAZEROTH("minimap")
SlashCmdList.PINPOINTAZEROTH("help")
ns.Minimap:Refresh()

for _, l in ipairs(printed) do print("  " .. l) end
print("smoke ok (" .. #printed .. " chat lines)")
