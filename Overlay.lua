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
        if tonumber(p.overlay.texture) or p.overlay.texture:find('\\', nil, true) then
            self.auraBorder:SetTexture(p.overlay.texture)
        else
            self.auraBorder:SetAtlas(p.overlay.texture)
        end
        local c = p.overlay.color[self.colorKey]
        self.auraBorder:SetVertexColor(c.r, c.g, c.b, c.a)
        self.auraBorder:Show()
    else
        self.auraBorder:Hide()
    end
    if p.duration.enable then
        self.durationText:SetFont(p.duration.fontFile, p.duration.fontSize, p.duration.fontFlags)
        self.durationText:ClearAllPoints()
        self.durationText:SetPoint(p.duration.point, self, p.duration.point, p.duration.x, p.duration.y)
        self.durationText:Show()
    else
        self.durationText:Hide()
    end
    if p.stacks.enable then
        self.stacksText:SetFont(p.stacks.fontFile, p.stacks.fontSize, p.stacks.fontFlags)
        self.stacksText:ClearAllPoints()
        self.stacksText:SetPoint(p.stacks.point, self, p.stacks.point, p.stacks.x, p.stacks.y)
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
        self.durationText:SetFont(p.stacks.fontFile, p.stacks.fontSize, p.stacks.fontFlags)
        self.durationText:ClearAllPoints()
        self.durationText:SetPoint(p.stacks.point, self, p.stacks.point, p.stacks.x, p.stacks.y)
        self.durationText:Show()
    else
        self.durationText:Hide()
    end
    local w, h = self:GetSize()
    self.ProcLoopFlipbook:SetSize(w * 1.4, h * 1.4)
end
