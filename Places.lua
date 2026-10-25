-- The clue pool. Each place sits in a zone at the zone-map coordinates a
-- player would see (0-100), and Geo.lua converts that to continent
-- coordinates at runtime.
--
-- Rules:
--   * IDs are permanent and the list is append-only. Never renumber, reuse
--     or delete an ID: the daily puzzle is picked from these lists, so
--     changing them changes everybody's puzzle.
--   * New places get a new edition number, and EDITIONS says from which
--     puzzle that edition is used, so a pool update never changes a day
--     that has already started.
--   * Tiers: 1 capital or major city, 2 large town, 3 dungeon or landmark,
--     4 subzone, 5 obscure spot.
--
-- All coordinates are drafted from memory and still need checking in game
-- (/pa dev near shows how far you are from the closest place).

local _, ns = ...

-- Continents. ids are the Classic uiMapIDs; the name is the English
-- fallback if an ID doesn't resolve.
ns.Continents = {
    KAL = { ids = { 1414 }, name = "Kalimdor" },
    EK = { ids = { 1415 }, name = "Eastern Kingdoms" },
}
ns.CONTINENT_ORDER = { "KAL", "EK" } -- left to right on the guess map

ns.Zones = {
    -- Eastern Kingdoms
    alterac = { cont = "EK", ids = { 1416 }, name = "Alterac Mountains" },
    arathi = { cont = "EK", ids = { 1417 }, name = "Arathi Highlands" },
    badlands = { cont = "EK", ids = { 1418 }, name = "Badlands" },
    blasted = { cont = "EK", ids = { 1419 }, name = "Blasted Lands" },
    tirisfal = { cont = "EK", ids = { 1420 }, name = "Tirisfal Glades" },
    silverpine = { cont = "EK", ids = { 1421 }, name = "Silverpine Forest" },
    wpl = { cont = "EK", ids = { 1422 }, name = "Western Plaguelands" },
    epl = { cont = "EK", ids = { 1423 }, name = "Eastern Plaguelands" },
    hillsbrad = { cont = "EK", ids = { 1424 }, name = "Hillsbrad Foothills" },
    hinterlands = { cont = "EK", ids = { 1425 }, name = "The Hinterlands" },
    dunmorogh = { cont = "EK", ids = { 1426 }, name = "Dun Morogh" },
    searing = { cont = "EK", ids = { 1427 }, name = "Searing Gorge" },
    steppes = { cont = "EK", ids = { 1428 }, name = "Burning Steppes" },
    elwynn = { cont = "EK", ids = { 1429 }, name = "Elwynn Forest" },
    deadwind = { cont = "EK", ids = { 1430 }, name = "Deadwind Pass" },
    duskwood = { cont = "EK", ids = { 1431 }, name = "Duskwood" },
    lochmodan = { cont = "EK", ids = { 1432 }, name = "Loch Modan" },
    redridge = { cont = "EK", ids = { 1433 }, name = "Redridge Mountains" },
    stv = { cont = "EK", ids = { 1434 }, name = "Stranglethorn Vale" },
    swamp = { cont = "EK", ids = { 1435 }, name = "Swamp of Sorrows" },
    westfall = { cont = "EK", ids = { 1436 }, name = "Westfall" },
    wetlands = { cont = "EK", ids = { 1437 }, name = "Wetlands" },
    -- Kalimdor
    durotar = { cont = "KAL", ids = { 1411 }, name = "Durotar" },
    mulgore = { cont = "KAL", ids = { 1412 }, name = "Mulgore" },
    barrens = { cont = "KAL", ids = { 1413 }, name = "The Barrens" },
    teldrassil = { cont = "KAL", ids = { 1438 }, name = "Teldrassil" },
    darkshore = { cont = "KAL", ids = { 1439 }, name = "Darkshore" },
    ashenvale = { cont = "KAL", ids = { 1440 }, name = "Ashenvale" },
    needles = { cont = "KAL", ids = { 1441 }, name = "Thousand Needles" },
    stonetalon = { cont = "KAL", ids = { 1442 }, name = "Stonetalon Mountains" },
    desolace = { cont = "KAL", ids = { 1443 }, name = "Desolace" },
    feralas = { cont = "KAL", ids = { 1444 }, name = "Feralas" },
    dustwallow = { cont = "KAL", ids = { 1445 }, name = "Dustwallow Marsh" },
    tanaris = { cont = "KAL", ids = { 1446 }, name = "Tanaris" },
    azshara = { cont = "KAL", ids = { 1447 }, name = "Azshara" },
    felwood = { cont = "KAL", ids = { 1448 }, name = "Felwood" },
    ungoro = { cont = "KAL", ids = { 1449 }, name = "Un'Goro Crater" },
    moonglade = { cont = "KAL", ids = { 1450 }, name = "Moonglade" },
    silithus = { cont = "KAL", ids = { 1451 }, name = "Silithus" },
    winterspring = { cont = "KAL", ids = { 1452 }, name = "Winterspring" },
}

-- Edition -> first puzzle number that uses it.
ns.EDITIONS = { 1 }

ns.TIER_NAMES = { "Cities", "Towns", "Dungeons & landmarks", "Subzones", "Hidden corners" }

ns.Places = {}
ns.PlacesByID = {}
local function P(id, tier, name, zone, x, y, edition)
    local place = { id = id, tier = tier, name = name, zone = zone, x = x / 100, y = y / 100, edition = edition or 1 }
    ns.Places[#ns.Places + 1] = place
    ns.PlacesByID[id] = place
end

-- Tier 1: capitals and major cities
P(1, 1, "Stormwind City", "elwynn", 32.0, 49.0)
P(2, 1, "Ironforge", "dunmorogh", 53.0, 35.0)
P(3, 1, "Darnassus", "teldrassil", 29.0, 46.0)
P(4, 1, "Orgrimmar", "durotar", 45.5, 11.5)
P(5, 1, "Thunder Bluff", "mulgore", 37.0, 31.0)
P(6, 1, "Undercity", "tirisfal", 61.8, 65.0)
P(7, 1, "Booty Bay", "stv", 27.0, 77.0)
P(8, 1, "Gadgetzan", "tanaris", 52.0, 28.0)
P(9, 1, "Ratchet", "barrens", 62.5, 37.0)
P(10, 1, "Goldshire", "elwynn", 42.0, 65.0)
P(11, 1, "Razor Hill", "durotar", 52.0, 43.0)
P(12, 1, "The Crossroads", "barrens", 52.0, 30.0)
P(13, 1, "Southshore", "hillsbrad", 51.0, 52.0)
P(14, 1, "Tarren Mill", "hillsbrad", 62.0, 20.0)
P(15, 1, "Menethil Harbor", "wetlands", 10.0, 59.0)
P(16, 1, "Astranaar", "ashenvale", 36.5, 49.5)
P(17, 1, "Sentinel Hill", "westfall", 56.0, 47.0)
P(18, 1, "Lakeshire", "redridge", 28.0, 45.0)
P(19, 1, "Darkshire", "duskwood", 74.0, 46.0)
P(20, 1, "Theramore Isle", "dustwallow", 66.5, 49.0)

-- Tier 2: large towns and hubs
P(21, 2, "Brill", "tirisfal", 60.5, 52.5)
P(22, 2, "Kharanos", "dunmorogh", 46.5, 52.0)
P(23, 2, "Thelsamar", "lochmodan", 35.0, 47.0)
P(24, 2, "Bloodhoof Village", "mulgore", 47.0, 58.0)
P(25, 2, "Dolanaar", "teldrassil", 56.0, 60.0)
P(26, 2, "Auberdine", "darkshore", 37.0, 44.0)
P(27, 2, "The Sepulcher", "silverpine", 43.0, 41.0)
P(28, 2, "Camp Taurajo", "barrens", 45.0, 58.0)
P(29, 2, "Sun Rock Retreat", "stonetalon", 47.0, 61.0)
P(30, 2, "Splintertree Post", "ashenvale", 73.0, 61.0)
P(31, 2, "Nijel's Point", "desolace", 66.0, 10.0)
P(32, 2, "Shadowprey Village", "desolace", 24.0, 70.0)
P(33, 2, "Feathermoon Stronghold", "feralas", 30.5, 43.5)
P(34, 2, "Camp Mojache", "feralas", 75.0, 44.0)
P(35, 2, "Grom'gol Base Camp", "stv", 32.0, 28.0)
P(36, 2, "Refuge Pointe", "arathi", 45.5, 47.0)
P(37, 2, "Hammerfall", "arathi", 73.5, 33.0)
P(38, 2, "Everlook", "winterspring", 61.0, 38.0)
P(39, 2, "Kargath", "badlands", 3.0, 47.0)
P(40, 2, "Stonard", "swamp", 46.0, 55.0)

-- Tier 3: dungeon entrances and landmarks
P(41, 3, "The Deadmines", "westfall", 42.5, 71.5)
P(42, 3, "Wailing Caverns", "barrens", 46.0, 36.0)
P(43, 3, "Shadowfang Keep", "silverpine", 44.5, 67.5)
P(44, 3, "Blackfathom Deeps", "ashenvale", 14.0, 14.0)
P(45, 3, "Gnomeregan", "dunmorogh", 24.5, 39.5)
P(46, 3, "Razorfen Kraul", "barrens", 42.5, 90.0)
P(47, 3, "Razorfen Downs", "barrens", 49.0, 93.5)
P(48, 3, "Scarlet Monastery", "tirisfal", 83.0, 32.0)
P(49, 3, "Uldaman", "badlands", 44.0, 12.0)
P(50, 3, "Zul'Farrak", "tanaris", 39.0, 20.0)
P(51, 3, "Maraudon", "desolace", 29.0, 62.5)
P(52, 3, "The Temple of Atal'Hakkar", "swamp", 69.5, 53.5)
P(53, 3, "Dire Maul", "feralas", 59.0, 44.0)
P(54, 3, "Scholomance", "wpl", 69.5, 73.0)
P(55, 3, "Stratholme", "epl", 30.0, 13.0)
P(56, 3, "Blackrock Mountain", "steppes", 29.0, 38.0)
P(57, 3, "The Dark Portal", "blasted", 58.5, 55.5)
P(58, 3, "Karazhan", "deadwind", 47.0, 75.0)
P(59, 3, "Onyxia's Lair", "dustwallow", 52.5, 76.5)
P(60, 3, "Zul'Gurub", "stv", 53.0, 17.0)

-- Tier 4: subzones
P(61, 4, "Northshire Abbey", "elwynn", 48.0, 42.0)
P(62, 4, "Moonbrook", "westfall", 42.0, 66.0)
P(63, 4, "Raven Hill", "duskwood", 18.0, 56.0)
P(64, 4, "Stonewatch Keep", "redridge", 64.0, 48.0)
P(65, 4, "Valley of Trials", "durotar", 43.0, 68.0)
P(66, 4, "Sen'jin Village", "durotar", 55.5, 74.5)
P(67, 4, "Camp Narache", "mulgore", 44.5, 77.0)
P(68, 4, "Shadowglen", "teldrassil", 58.5, 44.0)
P(69, 4, "Deathknell", "tirisfal", 32.0, 65.0)
P(70, 4, "Coldridge Valley", "dunmorogh", 28.5, 72.0)
P(71, 4, "Ambermill", "silverpine", 63.0, 64.0)
P(72, 4, "Stromgarde Keep", "arathi", 20.0, 62.0)
P(73, 4, "The Great Lift", "needles", 32.0, 22.0)
P(74, 4, "Freewind Post", "needles", 46.0, 51.0)
P(75, 4, "Steamwheedle Port", "tanaris", 67.0, 22.0)
P(76, 4, "Marshal's Refuge", "ungoro", 43.5, 8.0)
P(77, 4, "Cenarion Hold", "silithus", 51.0, 38.5)
P(78, 4, "Nighthaven", "moonglade", 51.0, 44.0)
P(79, 4, "Light's Hope Chapel", "epl", 81.0, 59.0)
P(80, 4, "Aerie Peak", "hinterlands", 14.0, 45.0)

-- Tier 5: hidden corners
P(81, 5, "Jerod's Landing", "elwynn", 48.0, 86.5)
P(82, 5, "Thandol Span", "arathi", 48.0, 88.0)
P(83, 5, "Mirage Raceway", "needles", 78.0, 77.0)
P(84, 5, "Ravenholdt Manor", "alterac", 86.0, 79.0)
P(85, 5, "Mistmantle Manor", "duskwood", 77.0, 36.0)
P(86, 5, "The Altar of Zul", "hinterlands", 48.0, 67.0)
P(87, 5, "Nethergarde Keep", "blasted", 66.0, 20.0)
P(88, 5, "Morgan's Vigil", "steppes", 85.0, 69.0)
P(89, 5, "Thorium Point", "searing", 38.0, 27.0)
P(90, 5, "Bough Shadow", "ashenvale", 93.0, 36.0)
P(91, 5, "Talrendis Point", "azshara", 22.0, 52.0)
P(92, 5, "Valormok", "azshara", 21.0, 62.0)
P(93, 5, "Bloodvenom Post", "felwood", 34.5, 52.5)
P(94, 5, "Talonbranch Glade", "felwood", 62.0, 25.0)
P(95, 5, "Ghost Walker Post", "desolace", 56.0, 75.0)
P(96, 5, "Kodo Graveyard", "desolace", 50.0, 61.0)
P(97, 5, "Brackenwall Village", "dustwallow", 36.0, 31.5)
P(98, 5, "Lost Rigger Cove", "tanaris", 72.0, 46.0)
P(99, 5, "Fargodeep Mine", "elwynn", 39.0, 82.0)
P(100, 5, "Gol'Bolar Quarry", "dunmorogh", 70.0, 56.0)
