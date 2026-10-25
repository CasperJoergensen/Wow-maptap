-- Ties the clue pool to the game's maps: resolves continent and zone map
-- IDs, converts zone coordinates to continent coordinates, and measures
-- continents in yards.

local _, ns = ...

local Geo = {}
ns.Geo = Geo

Geo.continents = {} -- key -> uiMapID
Geo.zones = {} -- zone key -> { id = uiMapID, rect = { minX, maxX, minY, maxY } }
Geo.sizes = {} -- key -> { width, height } in yards
Geo.missing = {} -- names that couldn't be resolved

-- Used only if the client can't tell us a continent's size (yards).
Geo.FALLBACK_SIZES = {
    KAL = { 36799.81, 24533.20 },
    EK = { 40741.18, 27149.69 },
}

-- Zone coordinates (0..1) -> continent coordinates (0..1). Pure.
function Geo.ToContinent(rect, x, y)
    return rect[1] + x * (rect[2] - rect[1]), rect[3] + y * (rect[4] - rect[3])
end

local function isContinent(id)
    local info = C_Map.GetMapInfo(id)
    return info and info.mapType == Enum.UIMapType.Continent, info
end

local function resolveContinent(def)
    for _, id in ipairs(def.ids) do
        if isContinent(id) then
            return id
        end
    end
    for id = 1, 3000 do
        local ok, info = isContinent(id)
        if ok and info.name == def.name then
            return id
        end
    end
end

local function zoneRect(id, continentID)
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(id, continentID)
    if minX and maxX > minX and maxY > minY then
        return { minX, maxX, minY, maxY }
    end
end

local function resolveZone(def, continentID)
    for _, id in ipairs(def.ids) do
        local rect = zoneRect(id, continentID)
        if rect then
            return id, rect
        end
    end
    for _, info in ipairs(C_Map.GetMapChildrenInfo(continentID, nil, true) or {}) do
        if info.name == def.name then
            local rect = zoneRect(info.mapID, continentID)
            if rect then
                return info.mapID, rect
            end
        end
    end
end

local function worldSize(id, key)
    if C_Map.GetMapWorldSize then
        local w, h = C_Map.GetMapWorldSize(id)
        if w and w > 0 and h and h > 0 then
            return { w, h }
        end
    end
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local _, a = C_Map.GetWorldPosFromMapPos(id, CreateVector2D(0, 0))
        local _, b = C_Map.GetWorldPosFromMapPos(id, CreateVector2D(1, 1))
        if a and b then
            -- World X runs north-south (the map's vertical axis), world Y east-west.
            local w, h = math.abs(a.y - b.y), math.abs(a.x - b.x)
            if w > 0 and h > 0 then
                return { w, h }
            end
        end
    end
    return Geo.FALLBACK_SIZES[key]
end

-- Resolves everything once. Returns true if every continent and zone was found.
function Geo:Init()
    if self.ready ~= nil then
        return self.ready
    end
    wipe(self.missing)
    for key, def in pairs(ns.Continents) do
        local id = resolveContinent(def)
        if id then
            self.continents[key] = id
            self.sizes[key] = worldSize(id, key)
        else
            self.missing[#self.missing + 1] = def.name
        end
    end
    for key, def in pairs(ns.Zones) do
        local continentID = self.continents[def.cont]
        local id, rect
        if continentID then
            id, rect = resolveZone(def, continentID)
        end
        if id then
            self.zones[key] = { id = id, rect = rect }
        else
            self.missing[#self.missing + 1] = def.name
        end
    end
    self.ready = #self.missing == 0
    return self.ready
end

-- Continent position { c, x, y } of a place, or nil if its zone isn't known.
function Geo:Locate(placeID)
    local place = ns.PlacesByID[placeID]
    local zone = place and self.zones[place.zone]
    if not zone then
        return nil
    end
    local x, y = Geo.ToContinent(zone.rect, place.x, place.y)
    return { c = ns.Zones[place.zone].cont, x = x, y = y }
end

-- The player's continent position, or nil (e.g. in an instance).
function Geo:PlayerPos()
    for key, id in pairs(self.continents) do
        local pos = C_Map.GetPlayerMapPosition(id, "player")
        if pos then
            local x, y = pos:GetXY()
            if x and (x > 0 or y > 0) then
                return { c = key, x = x, y = y }
            end
        end
    end
end
