-- Minimap button: left-click opens the game, drag to move it around the
-- minimap. It glows while today's daily is unplayed.

local _, ns = ...
local L = ns.L

local Minimap = {}
ns.Minimap = Minimap

local RADIUS = 80

local function place(button, angle)
    local rad = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", _G.Minimap, "CENTER", math.cos(rad) * RADIUS, math.sin(rad) * RADIUS)
end

local function dragUpdate(button)
    local mx, my = _G.Minimap:GetCenter()
    local x, y = GetCursorPosition()
    local scale = _G.Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(y / scale - my, x / scale - mx))
    ns.db.minimap.angle = angle
    place(button, angle)
end

function Minimap:Init()
    local b = CreateFrame("Button", "PinpointAzerothMinimapButton", _G.Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local glow = b:CreateTexture(nil, "OVERLAY", nil, 1)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.85, 0.2)
    glow:SetSize(52, 52)
    glow:SetPoint("CENTER", icon, "CENTER")
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.8)
    b.glow, b.pulse = glow, pulse

    b:SetScript("OnClick", function()
        ns.Window:Toggle()
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", dragUpdate)
    end)
    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["Pinpoint Azeroth"])
        GameTooltip:AddLine(Minimap.unplayed and L["Today's daily is waiting."] or L["Today's daily is done."], 1, 1, 1)
        GameTooltip:AddLine(L["Click to open. Drag to move."], 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)

    self.button = b
    place(b, ns.db.minimap.angle)
    self:Refresh()
end

function Minimap:Refresh()
    local b = self.button
    if not b then
        return
    end
    b:SetShown(not ns.db.minimap.hide)
    local record = ns.db.history[ns.Today()]
    self.unplayed = not (record and record.done)
    b.glow:SetShown(self.unplayed)
    if self.unplayed then
        b.pulse:Play()
    else
        b.pulse:Stop()
    end
end
