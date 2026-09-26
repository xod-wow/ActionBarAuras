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

local function InitializeAuraOverlay(f)
    -- AuraButton is not managing the border, it's fixed, since we don't need
    -- the color to change depending on auraData.dispelName.
    f:SetDurationText(f.durationText, durationTextOptions)
    f:SetApplicationCount(f.stacksText)
    f:EnableMouse(false)
end

local function InitializeHighlightOverlay(f)
    f:SetDurationText(f.durationText, durationTextOptions)
    f:AddAuraShownAnimation(f.ProcLoop)
    f:EnableMouse(false)
end


--[[--------------------------------------------------------------------------]]--

-- Notes about raid buffs.
--
-- Mostly they match 'HELPFUL|RAID' and canApplyAura=true.
--
-- But, Blessing of the Bronze is all over the place. It has a different spell ID
-- per class, doesn't match 'RAID' and has canApplyAura=false.
--
-- If it worked properly we could have a separate filter definition for raid buffs
-- and not have to manually maintain all the spell data. I.e., add '!RAID' to
-- PLAYERBUFF and have a separate 'RAIDBUFF' with 'HELPFUL|RAID' (don't need
-- canApplyAura to be right since we are matching the spell on the bar by ID).
--
-- Could probably have one for RAID and a specific one for BotB, but I'm really
-- not liking how many of these AuraButtons I'm making already, and don't want
-- to add more FilterDefinitions unless they can be pulled out of a pool and only
-- applied to specific buttons.
--
-- Then again maybe it's not a big deal to have thousands of them if they are
-- mostly disabled.

local FilterDefinitions = {
    {
        name = 'PLAYERBUFF',
        unit = 'player',
        templateNames = { 'ABAOverlayAuraTemplate' },
        InitializeFrame =
            function (f)
                InitializeAuraOverlay(f)
                f.auraBorder:SetVertexColor(0, 0.7, 0, 0.5)
            end,
        GetEnabled =
            function (spellID)
                local canAssist = UnitCanAssist('player', 'player', true, true)
                if canAssist then
                    return true
                else
                    return false
                end
            end,
        GetFilters =
            function (spellID)
                local candidateFilters, filterString = { isHelpful = true}
                if addon.IsRaidBuff(spellID) then
                    -- Note no 'RAID' on purpose (see commentary above).
                    filterString = 'HELPFUL|INCLUDE_NAME_PLATE_ONLY'
                    candidateFilters.includeSpellIDs = addon.GetRaidIncludeSpellIDs(spellID)
                else
                    filterString = 'HELPFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER'
                    candidateFilters.includeSpellIDs = addon.GetIncludeSpellIDs(spellID)
                end
                return filterString, candidateFilters
            end
    },
    {
        name = 'TARGETDEBUFF',
        unit = 'target',
        templateNames = { 'ABAOverlayAuraTemplate' },
        InitializeFrame =
            function (f)
                InitializeAuraOverlay(f)
                f.auraBorder:SetVertexColor(1, 0, 0, 0.5)
            end,
        GetEnabled =
            function (spellID)
                local canAssist = UnitCanAssist('player', 'target', true, true)
                if addon.IsRaidBuff(spellID) then
                    return false
                elseif canAssist then
                    return false
                else
                    return true
                end
            end,
        GetFilters =
            function (spellID)
                local candidateFilters = { isHarmful = true }
                candidateFilters.includeSpellIDs = addon.GetIncludeSpellIDs(spellID)
                return 'HARMFUL|PLAYER', candidateFilters
            end
    },
--[[
    {
        name = 'TARGETSTEAL',
        unit = 'target',
        templateNames = { 'ABAOverlayHighlightTemplate' },
        InitializeFrame = InitializeHighlightOverlay,
        GetEnabled =
            function (spellID)
                local canAssist = UnitCanAssist('player', 'target', true, true)
                if canAssist then
                    return false
                else
                    IsPurgeSpell(spellID)
                end
            end,
        GetFilters =
            function (spellID)
                local candidateFilters = { isHelpful = true, isStealable = true }
                return 'HELPFUL', candidateFilters
            end,
    }
]]
}


--[[--------------------------------------------------------------------------]]--

local AuraContainerManagerMixin = {}

function AuraContainerManagerMixin:CreateAuraSlot()
    local fd = self.fd
    local options = {
        sortMethod = AuraContainerSortMethod.ExpirationOnly,
        sortDirection = AuraContainerSortDirection.Reverse,
        templateNames = fd.templateNames,
        initializeFrame = function (f) fd.InitializeFrame(f, fd) end
    }
    self.as = self.c:AddAuraSlot("ABA", "", options)
    PixelUtil.SetSize(self.as, self.button:GetSize())
    self.as:SetPoint("CENTER", self.button)
    self.as:SetFrameLevel(self.button.cooldown:GetFrameLevel()+1)
end

function AuraContainerManagerMixin:Initialize(fd, button)
    self.fd = fd
    self.button = button
    self.c = CreateFrame('AuraContainer', nil, button, 'CustomAuraContainerTemplate')
    self.c:SetPoint("TOPLEFT")
    self.c:SetUnit(fd.unit)
    self:CreateAuraSlot()
end

function AuraContainerManagerMixin:ApplyFilters(spellID)
    local filterString, candidateFilters = self.fd.GetFilters(spellID)
    self.c:SetAuraSlotFilterString("ABA", filterString)
    self.c:SetAuraSlotCandidateFilters("ABA", candidateFilters)
end

local function IsSpellDisabled(spellID)
    if not spellID then
        return true
    else
        return not addon.db.profile.abilities[spellID].enable
    end
end

function AuraContainerManagerMixin:ShouldDisable(spellID)
    if not self.button:IsVisible() then
        return true
    elseif IsSpellDisabled(spellID) then
        return true
    elseif not self.fd.GetEnabled(spellID) then
        return true
    end
end

function AuraContainerManagerMixin:UpdateFilters(spellID)
    if self:ShouldDisable(spellID) then
        self.c:SetEnabled(false)
    else
        self:ApplyFilters(spellID)
        self.c:SetEnabled(true)
    end
end

local function CreateAuraContainerManager(fd, button)
    local acm = CreateFromMixins(AuraContainerManagerMixin)
    acm:Initialize(fd, button)
    return acm
end


--[[--------------------------------------------------------------------------]]--

addon.ButtonManagerMixin = {}

function addon.ButtonManagerMixin:GetActionID()
    return self.button.action
end

function addon.ButtonManagerMixin:GetActionSpellID()
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

function addon.ButtonManagerMixin:Initialize(button)
    self.button = button
    self.acm = {}
    for _, fd in ipairs(FilterDefinitions) do
        self.acm[fd.name] = CreateAuraContainerManager(fd, button)
    end
end

function addon.ButtonManagerMixin:UpdateFilters()
    local spellID = self:GetActionSpellID()
    for _, auraContainerManager in pairs(self.acm) do
        auraContainerManager:UpdateFilters(spellID)
    end
end
