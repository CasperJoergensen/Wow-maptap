-- Translations for Pinpoint Azeroth's own labels and messages.
--
-- Keys are the English strings. A missing translation falls back to English.
-- Place names in Places.lua are English too; they're matched to the map by
-- coordinates, not by name, so other clients still play correctly.

local _, ns = ...

local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L
