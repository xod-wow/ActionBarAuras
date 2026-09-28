local _, addon = ...

-- AuraButton is not managing the border, it's fixed, since we don't need
-- the color to change depending on auraData.dispelName.


--[[--------------------------------------------------------------------------]]--

local AuraDurationFormatter = C_StringUtil.CreateSecondsFormatter()
AuraDurationFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
AuraDurationFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
AuraDurationFormatter:SetDesiredUnitCount(1)
AuraDurationFormatter:SetMillisecondsThreshold(3)
AuraDurationFormatter:SetStripIntervalWhitespace(Enum.SecondsFormatterIntervalWhitespace.Strip)

local AuraColorCurve = C_CurveUtil.CreateColorCurve()
AuraColorCurve:SetType(Enum.LuaCurveType.Cosine)
AuraColorCurve:AddPoint(0.0, CreateColor(1, 0.5, 0.5))
AuraColorCurve:AddPoint(3.0, CreateColor(1, 1, 0.5))
AuraColorCurve:AddPoint(10.0, CreateColor(1, 1, 1))

local durationTextOptions = {
    textFormatter = AuraDurationFormatter,
    textColor = {
        curve = AuraColorCurve,
        property = Enum.DurationTextBindingProperty.RemainingDuration
    }
}


--[[--------------------------------------------------------------------------]]--

addon.OverlayAuraMixin = {}

function addon.OverlayAuraMixin:Initialize()
    self:SetDurationText(self.durationText, durationTextOptions)
    self:SetApplicationCount(self.stacksText)
    self:EnableMouse(false)
end

function addon.OverlayAuraMixin:Style()
    local p = addon.db.profile
    if p.overlay.enable then
        self.auraBorder:SetTexture(p.overlay.texture)
        local c = p.overlay.color[self.colorKey]
        self.auraBorder:SetVertexColor(c.r, c.g, c.b, c.a)
        self.auraBorder:Show()
    else
        self.auraBorder:Hide()
    end
    if p.duration.enable then
        self.stacksText:SetFontObject(_G[p.duration.font])
        local anchor = p.duration.anchor
        self.durationText:ClearAllPoints()
        self.durationText:SetPoint(anchor.point, self, anchor.point, anchor.x, anchor.y)
        self.durationText:Show()
    else
        self.durationText:Hide()
    end
    if p.stacks.enable then
        self.stacksText:SetFontObject(_G[p.stacks.font])
        local anchor = p.stacks.anchor
        self.stacksText:ClearAllPoints()
        self.stacksText:SetPoint(anchor.point, self, anchor.point, anchor.x, anchor.y)
        self.stacksText:Show()
    else
        self.stacksText:Hide()
    end
end


--[[--------------------------------------------------------------------------]]--

addon.OverlayHighlightMixin = {}

function addon.OverlayHighlightMixin:Initialize()
    self:SetDurationText(self.durationText, durationTextOptions)
    self:AddAuraShownAnimation(self.ProcLoop)
    self:EnableMouse(false)
end

function addon.OverlayHighlightMixin:Style()
    local p = addon.db.profile
    if p.duration.enable then
        self.stacksText:SetFontObject(_G[p.duration.font])
        local anchor = p.duration.anchor
        self.durationText:ClearAllPoints()
        self.durationText:SetPoint(anchor.point, self, anchor.point, anchor.x, anchor.y)
        self.durationText:Show()
    else
        self.durationText:Hide()
    end
    local w, h = self:GetSize()
    self.ProcLoopFlipbook:SetSize(w * 1.4, h * 1.4)
end
