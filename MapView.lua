-- The guess map: Kalimdor and the Eastern Kingdoms side by side, drawn from
-- the continent map art in our own frames. No WorldMapFrame hooks, so there
-- are no zone labels, tooltips or player arrow to give answers away.

local _, ns = ...
local L = ns.L

local MapView = {}
ns.MapView = MapView

local PANEL_WIDTH = 440
local GAP = 8
local LABEL_HEIGHT = 18
local PIN_SIZE = 16
local PIN_TEXTURES = {
    guess = "Interface\\COMMON\\Indicator-Yellow",
    truth = "Interface\\COMMON\\Indicator-Green",
}

-- Tiles the continent's first art layer into the panel. Returns the height.
local function drawArt(panel, mapID, width)
    local layers = mapID and C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[1]
    local textures = layer and C_Map.GetMapArtLayerTextures(mapID, 1)
    if not textures or #textures == 0 then
        local height = width * 2 / 3
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.12, 0.16, 0.22, 1)
        local text = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        text:SetPoint("CENTER")
        text:SetText(L["Map art unavailable"])
        return height
    end
    local scale = width / layer.layerWidth
    local tileW, tileH = layer.tileWidth * scale, layer.tileHeight * scale
    local cols = math.ceil(layer.layerWidth / layer.tileWidth)
    for i, fileID in ipairs(textures) do
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        local tex = panel:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture(fileID)
        tex:SetSize(tileW, tileH)
        tex:SetPoint("TOPLEFT", col * tileW, -row * tileH)
    end
    return layer.layerHeight * scale
end

local function cursorIn(frame)
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    local nx = (x / scale - frame:GetLeft()) / frame:GetWidth()
    local ny = (frame:GetTop() - y / scale) / frame:GetHeight()
    return math.max(0, math.min(1, nx)), math.max(0, math.min(1, ny))
end

local View = {}
View.__index = View

function MapView:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    local view = setmetatable({ frame = frame, panels = {}, pins = {}, lines = {}, labels = {}, used = {} }, View)

    local x, maxHeight = 0, 0
    for _, key in ipairs(ns.CONTINENT_ORDER) do
        local panel = CreateFrame("Frame", nil, frame)
        panel:SetClipsChildren(true)
        local height = drawArt(panel, ns.Geo.continents[key], PANEL_WIDTH)
        panel:SetSize(PANEL_WIDTH, height)
        panel:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -LABEL_HEIGHT)
        panel:EnableMouse(true)
        panel:SetScript("OnMouseUp", function(self, button)
            if button == "LeftButton" and view.interactive and view.onClick then
                local nx, ny = cursorIn(self)
                view.onClick({ c = key, x = nx, y = ny })
            end
        end)
        local label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 2, 4)
        label:SetText(ns.Continents[key].name)
        view.panels[key] = panel
        x = x + PANEL_WIDTH + GAP
        maxHeight = math.max(maxHeight, height)
    end
    frame:SetSize(x - GAP, maxHeight + LABEL_HEIGHT)

    -- Marks go on an overlay above both panels so lines can cross between them.
    view.overlay = CreateFrame("Frame", nil, frame)
    view.overlay:SetAllPoints()
    view.overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
    return view
end

function View:SetClickHandler(fn)
    self.onClick = fn
end

function View:SetInteractive(on)
    self.interactive = on
end

local function take(view, kind, create)
    local pool = view[kind]
    view.used[kind] = (view.used[kind] or 0) + 1
    local item = pool[view.used[kind]]
    if not item then
        item = create()
        pool[#pool + 1] = item
    end
    item:Show()
    return item
end

function View:Clear()
    for _, kind in ipairs({ "pins", "lines", "labels" }) do
        for _, item in ipairs(self[kind]) do
            item:Hide()
        end
        self.used[kind] = 0
    end
end

function View:Point(pos)
    local panel = self.panels[pos.c]
    return panel, pos.x * panel:GetWidth(), -pos.y * panel:GetHeight()
end

-- kind: "guess" or "truth". label is optional text beside the pin.
function View:AddPin(pos, kind, label)
    local pin = take(self, "pins", function()
        return self.overlay:CreateTexture(nil, "OVERLAY")
    end)
    pin:SetTexture(PIN_TEXTURES[kind])
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    local panel, px, py = self:Point(pos)
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", panel, "TOPLEFT", px, py)
    if label then
        local text = take(self, "labels", function()
            local fs = self.overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetShadowOffset(1, -1)
            return fs
        end)
        text:ClearAllPoints()
        text:SetPoint("BOTTOM", pin, "TOP", 0, 0)
        text:SetText(label)
    end
end

function View:AddLine(a, b)
    local line = take(self, "lines", function()
        local l = self.overlay:CreateLine(nil, "ARTWORK")
        l:SetThickness(2)
        l:SetColorTexture(1, 0.82, 0.2, 0.9)
        return l
    end)
    local pa, ax, ay = self:Point(a)
    local pb, bx, by = self:Point(b)
    line:SetStartPoint("TOPLEFT", pa, ax, ay)
    line:SetEndPoint("TOPLEFT", pb, bx, by)
end
