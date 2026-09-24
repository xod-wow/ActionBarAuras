local _, addon = ...

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

local function InitializeOverlay(f, cf)
    -- AuraButton is not managing the border, it's fixed, since we don't need
    -- the color to change depending on auraData.dispelName.
    f.auraBorder:SetVertexColor(cf.color:GetRGBA())

    f:SetDurationText(f.durationText, durationTextOptions)

    f:SetApplicationCount(f.stacksText)

    f:EnableMouse(false)
end


--[[--------------------------------------------------------------------------]]--

local FilterDefinitions = {
    {
        name = 'PLAYERBUFF',
        filter = 'HELPFUL|INCLUDE_NAME_PLATE_ONLY',
        unit = 'player',
        color = CreateColor(0, 0.7, 0, 0.5),
        templateNames = { 'ABAOverlayAuraTemplate' },
        initializeFrame = InitializeOverlay,
        includeRaidBuffs = true,
        addFilters =
            function (t, cf, actionID)
                t.isHelpful = true
            end,
    },
    {
        name = 'TARGETDEBUFF',
        filter = 'HARMFUL',
        unit = 'target',
        color = CreateColor(1, 0, 0, 0.5),
        templateNames = { 'ABAOverlayAuraTemplate' },
        initializeFrame = InitializeOverlay,
        addFilters =
            function (t, cf, actionID)
                t.isHarmful = true
            end,
    }
--[[
    {
        name = 'TARGETSTEAL',
        filter = 'HELPFUL',
        unit = 'target',
        color = CreateColor(1, 0, 0, 0.5),
        templateNames = { 'ABAOverlayStealableTemplate' },
        addFilters =
            function (t, cf, actionID)
                t.isHarmful = true
                if not IsPurgeAction(actionID) then
                    t.maxDuration = 0
                end
            end,
    }
]]
}


--[[--------------------------------------------------------------------------]]--

local AuraContainerManagerMixin = {}

function AuraContainerManagerMixin:CreateAuraSlot()
    local cf = self.cf
    local options = {
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        templateNames = cf.templateNames,
        initializeFrame = cf.initializeFrame and function (f) cf.initializeFrame(f, cf) end
    }
    local auraSlotFilter = cf.filter .. '|PLAYER'
    self.as = self.c:AddAuraSlot("ABA", auraSlotFilter, options)
    PixelUtil.SetSize(self.as, self.button:GetSize())
    self.as:SetPoint("CENTER", self.button)
    self.as:SetFrameLevel(self.button.cooldown:GetFrameLevel()+1)
end

function AuraContainerManagerMixin:Initialize(cf, button)
    self.cf = cf
    self.button = button
    self.c = CreateFrame('AuraContainer', nil, button, 'CustomAuraContainerTemplate')
    self.c:SetPoint("TOPLEFT")
    self.c:SetUnit(cf.unit)
    self:CreateAuraSlot()
end

function AuraContainerManagerMixin:ApplyFilters(spellID, isRaidBuff)
    local candidateFilters, filter = {}
    if isRaidBuff then
        candidateFilters.includeSpellIDs = addon.GetRaidIncludeSpellIDs(spellID)
        filter = self.cf.filter..'|RAID'
    else
        candidateFilters.includeSpellIDs = addon.GetIncludeSpellIDs(spellID)
        filter = self.cf.filter..'|PLAYER'
    end
    self.cf.addFilters(candidateFilters)
    self.c:SetAuraSlotFilterString("ABA", filter)
    self.c:SetAuraSlotCandidateFilters("ABA", candidateFilters)
end

function AuraContainerManagerMixin:GetActionID()
    return self.button.action
end

function AuraContainerManagerMixin:GetActionSpellID()
    local actionID = self:GetActionID()
    local actionType, id, actionSubType = GetActionInfo(actionID)
    if (actionType =="spell" or actionSubType == "spell") and id then
        return id
    elseif actionType == "item" then
        local _, spellID = C_Item.GetItemSpell(id)
        return spellID
    elseif actionType == "macro" and actionSubType == "item" then
        local actionName = GetActionText(actionID)
        local _, link = GetMacroItem(actionName)
        if link then
            local _, spellID = C_Item.GetItemSpell(link)
            return spellID
        end
    end
end

local function IsSpellDisabled(spellID)
    if not spellID then
        return true
    else
        return not addon.db.profile.abilities[spellID].enable
    end
end

function AuraContainerManagerMixin:ShouldDisable(spellID, isRaidBuff)
    if not self.button:IsVisible() then
        return true
    elseif IsSpellDisabled(spellID) then
        return true
    elseif isRaidBuff and not self.cf.includeRaidBuffs then
        return true
    end
    local canAssist = UnitCanAssist('player', self.cf.unit, true, true)
    if self.cf.filter == 'HARMFUL' and canAssist then
        return true
    elseif self.cf.filter == 'HELPFUL' and not canAssist then
        return true
    else
        return false
    end
end

local function IsRaidBuff(spellID)
    return addon.RaidBuffsBySpellID[spellID] ~= nil
end

function AuraContainerManagerMixin:UpdateFilters()
    local spellID = self:GetActionSpellID()
    local function debug(...) if spellID == 1459 then print(...) end end
    local isRaidBuff = IsRaidBuff(spellID)
    if self:ShouldDisable(spellID, isRaidBuff) then
        self.c:SetEnabled(false)
    else
        self:ApplyFilters(spellID, isRaidBuff)
        self.c:SetEnabled(true)
    end
end

local function CreateAuraContainerManager(cf, button)
    local acm = CreateFromMixins(AuraContainerManagerMixin)
    acm:Initialize(cf, button)
    return acm
end


--[[--------------------------------------------------------------------------]]--

addon.ButtonManagerMixin = {}

function addon.ButtonManagerMixin:Initialize(button)
    self.acm = {}
    for _, cf in ipairs(FilterDefinitions) do
        self.acm[cf.name] = CreateAuraContainerManager(cf, button)
    end
end

function addon.ButtonManagerMixin:UpdateFilters()
    for _, cm in pairs(self.acm) do
        cm:UpdateFilters()
    end
end

function addon.ButtonManagerMixin:Hide()
    for _, cm in pairs(self.acm) do
        cm.c:Hide()
    end
end

function addon.ButtonManagerMixin:Show()
    for _, cm in pairs(self.acm) do
        cm.c:Show()
    end
end
