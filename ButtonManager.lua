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

local AuraContainers = {
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

local function CreateButtonAuraSlot(cf, container, button)
    local options = {
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        templateNames = cf.templateNames,
        initializeFrame = cf.initializeFrame and function (f) cf.initializeFrame(f, cf) end
    }
    local auraSlotFilter = cf.filter .. '|PLAYER'
    local as = container:AddAuraSlot("ABA", auraSlotFilter, options)
    PixelUtil.SetSize(as, button:GetSize())
    as:SetPoint("CENTER", button)
    as:SetFrameLevel(button.cooldown:GetFrameLevel()+1)
end

local function CanEnable(cf)
    local canAssist = UnitCanAssist('player', cf.unit, true, true)
    if cf.filter == 'HARMFUL' and canAssist then
        return false
    elseif cf.filter == 'HELPFUL' and not canAssist then
        return false
    else
        return true
    end
end

local function GetActionSpellID(actionID)
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

local function IsRaidBuff(spellID)
    return addon.RaidBuffsBySpellID[spellID] ~= nil
end

local function ApplyRaidFilters(cm, spellID)
    local candidateFilters = {
        includeSpellIDs = addon.GetRaidIncludeSpellIDs(spellID)
    }
    cm.cf.addFilters(candidateFilters)
    cm.c:SetAuraSlotFilterString("ABA", cm.cf.filter..'|RAID')
    cm.c:SetAuraSlotCandidateFilters("ABA", candidateFilters)
end

local function ApplyFilters(cm, spellID)
    local candidateFilters = {
        includeSpellIDs = addon.GetIncludeSpellIDs(spellID)
    }
    cm.cf.addFilters(candidateFilters)
    cm.c:SetAuraSlotFilterString("ABA", cm.cf.filter..'|PLAYER')
    cm.c:SetAuraSlotCandidateFilters("ABA", candidateFilters)
end

local function IsSpellDisabled(spellID)
    if not spellID then
        return true
    else
        return not addon.db.profile.abilities[spellID].enable
    end
end

addon.ButtonManagerMixin = {}

function addon.ButtonManagerMixin:Initialize(button)
    self.button = button
    self.controllers = {}
    for _, cf in ipairs(AuraContainers) do
        local c = CreateFrame('AuraContainer', nil, button, 'CustomAuraContainerTemplate')
        c:SetPoint("TOPLEFT")
        c:SetUnit(cf.unit)
        local as = CreateButtonAuraSlot(cf, c, button)
        self.controllers[cf.name] = { cf=cf, c=c, as=as }
    end
end

function addon.ButtonManagerMixin:UpdateFilters(matchfunc)
    local b = self.button
    local spellID = GetActionSpellID(b.action)
    local isRaidBuff = IsRaidBuff(spellID)
    local isDisabled = IsSpellDisabled(spellID) or not b:IsVisible()
    for _, cm in pairs(self.controllers) do
        if not matchfunc or matchfunc(cm.cf) then
            if isDisabled or not CanEnable(cm.cf) then
                cm.c:SetEnabled(false)
            elseif isRaidBuff and not cm.cf.includeRaidBuffs then
                cm.c:SetEnabled(false)
            elseif isRaidBuff then
                ApplyRaidFilters(cm, spellID)
                cm.c:SetEnabled(true)
            else
                ApplyFilters(cm, spellID)
                cm.c:SetEnabled(true)
            end
        end
    end
end

function addon.ButtonManagerMixin:Hide()
    for _, cm in pairs(bm.controllers) do
        cm.c:Hide()
    end
end

function addon.ButtonManagerMixin:Show()
    for _, cm in pairs(self.controllers) do
        cm.c:Show()
    end
end
