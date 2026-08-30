local _, addon = ...

--[[--------------------------------------------------------------------------]]--

-- These are per-spec but there's no point clearing them out I don't think.
-- [BarSpellID] = { [AuraSpellID] = true, ... }

local LinkedSpellIDs = { }

-- TODO equipped items without spellID?
local function ScanLinkedSpells()
    for c = Enum.CooldownViewerCategoryMeta.MinValue, Enum.CooldownViewerCategoryMeta.MaxValue do
        for _, cooldownID in ipairs(C_CooldownViewer.GetCooldownViewerCategorySet(c, true)) do
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
            if info.spellID then
                local name = C_Spell.GetSpellName(info.spellID)
                LinkedSpellIDs[name] = LinkedSpellIDs[info.spellID] or {}
                LinkedSpellIDs[name][info.spellID] = true
                for _, spellID in ipairs(info.linkedSpellIDs) do
                    LinkedSpellIDs[name][spellID] = true
                end
            end
        end
    end
end

local function GetLinkedSpellIDs(spellID)
    local spellIDs = {}
    local name = C_Spell.GetSpellName(spellID)
    if LinkedSpellIDs[name] then
        Mixin(spellIDs, LinkedSpellIDs[name])
    end
    if addon.db.profile.extraLinkedSpellIDs[spellID] then
        Mixin(spellIDs, addon.db.profile.extraLinkedSpellIDs[spellID])
    end
    return spellIDs
end


--[[--------------------------------------------------------------------------]]--

local function EnumerateActionButtons()
    local buttons = {}
    for _, actionBar in ipairs(ActionButtonUtil.ActionBarButtonNames) do
        for i = 1, NUM_ACTIONBAR_BUTTONS do
            local btn = _G[actionBar..i]
            table.insert(buttons, btn)
        end
    end

    local i = 0
    return function ()
        i = i + 1
        return buttons[i]
    end
end


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
        filter = 'HELPFUL',
        unit = 'player',
        color = CreateColor(0, 0.7, 0, 0.5),
        templateNames = { 'ABAOverlayAuraTemplate' },
        initializeFrame = InitializeOverlay,
        addFilters =
            function (t, cf, actionID)
                t.isHelpful = true
            end,
    },
    {
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

local function CreateAuraSlotsForButton(button)
    for _, cf in ipairs(AuraContainers) do
        local name = button:GetName()
        local options = {
            sortMethod = AuraContainerSortMethod.ExpirationOnly,
            sortDirection = AuraContainerSortDirection.Reverse,
            templateNames = cf.templateNames,
            initializeFrame = cf.initializeFrame and function (f) cf.initializeFrame(f, cf) end
        }
        local auraSlotFilter = cf.filter .. '|PLAYER'
        local as = cf.container:AddAuraSlot(name, auraSlotFilter, options)
        PixelUtil.SetSize(as, button:GetSize())
        as:SetPoint("CENTER", button)
        local scale = button:GetEffectiveScale() / cf.container:GetParent():GetEffectiveScale()
        as:SetFrameLevel(button.cooldown:GetFrameLevel()+1)
        cf.auraSlots[name] = as
    end
end

local function HideAuraContainers()
    for _, cf in ipairs(AuraContainers) do
        cf.container:Hide()
    end
end

local function ShowAuraContainers()
    for _, cf in ipairs(AuraContainers) do
        cf.container:Show()
    end
end

local function CreateAuraContainers()
    for _, cf in ipairs(AuraContainers) do
        cf.container = CreateFrame('AuraContainer', nil, UIParent, 'CustomAuraContainerTemplate')
        cf.container:SetUnit(cf.unit)
        cf.auraSlots = {}
    end
end

local function OnTargetChanged()
    for _, cf in ipairs(AuraContainers) do
        if cf.unit == 'target' then
            local enabled = cf.container:IsEnabled()
            if UnitCanAssist('player', 'target', true, true) then
                if enabled then
                    cf.container:SetEnabled(false)
                end
            else
                if not enabled then
                    cf.container:SetEnabled(true)
                else
                    cf.container:UpdateAllAuras()
                end
            end
        end
    end
end

local function CreateAuraSlots()
    for b in EnumerateActionButtons() do
        CreateAuraSlotsForButton(b)
    end
end

local BadRestrictions = { 'Combat', 'Encounter', 'ChallengeMode', 'PvPMatch' }

local function IsSetScaleAllowed()
    for _, r in ipairs(BadRestrictions) do
        if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType[r]) then
            return false
        end
    end
    return true
end

local function ApplyAuraSlotScales(ignoreRestrictions)
    if ignoreRestrictions or IsSetScaleAllowed() then
        for _, cf in ipairs(AuraContainers) do
            for name, as in pairs(cf.auraSlots) do
                local button = _G[name]
                local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
                as:SetScale(scale)
            end
        end
    end
end

local function GetActionCandidateFilters(actionID)
    local actionType, id, actionSubType = GetActionInfo(actionID)
    local filters = {
        isFromPlayerOrPlayerPet = true,
        includeSpellIDs = {},
    }
    if (actionType =="spell" or actionSubType == "spell") and id then
        filters.includeSpellIDs[id] = true
        -- Handle spells like Zenith which change to a completely different
        -- spell when active that is not linked.
        local baseSpellID = C_Spell.GetBaseSpell(id)
        filters.includeSpellIDs[baseSpellID] = true
    elseif actionType == "item" then
        local _, spellID = C_Item.GetItemSpell(id)
        filters.includeSpellIDs[id] = true
    elseif actionType == "macro" and actionSubType == "item" then
        local actionName = GetActionText(actionID)
        local _, link = GetMacroItem(actionName)
        if link then
            local _, spellID = C_Item.GetItemSpell(link)
            if spellID then
                filters.includeSpellIDs[spellID] = true
            end
        end
    end
    for spellID in pairs(filters.includeSpellIDs) do
        Mixin(filters.includeSpellIDs, GetLinkedSpellIDs(spellID))
    end
    return filters
end

-- Because the AuraSlots can't be reparented they don't get their shown state
-- managed by their associated ActionButton, and will appear in seemingly
-- random spots for hidden ActionButtons. As a fairly bad work-around for this
-- we set their action to 0 which ends up with a blank includeSpellIDs which
-- matches nothing and never shows.
--
-- The other way to do this is to create one AuraContainer per AuraSlot, since
-- the AuraContainers can be reparented to the button. This also solves the
-- scale problem, but the cost is having over a thousand AuraContainer and
-- I don't know how well this scales.

local function UpdateOverlayFilters()
    for b in EnumerateActionButtons() do
        local name = b:GetName()
        local action = b:IsVisible() and b.action or 0
        for _, cf in ipairs(AuraContainers) do
            local candidateFilters = GetActionCandidateFilters(action, cf.filter)
            cf.addFilters(candidateFilters, cf, action)
            cf.container:SetAuraSlotCandidateFilters(name, candidateFilters)
        end
    end
end

local EventFrame = CreateFrame('Frame')

local UpdateFiltersEvents = {
    ['ACTIONBAR_PAGE_CHANGED'] = true,
    ['ACTIONBAR_SLOT_CHANGED'] = true,
    ['PLAYER_ENTERING_WORLD'] = true,
    ['UPDATE_BONUS_ACTIONBAR'] = true,
    ['UPDATE_VEHICLE_ACTIONBAR'] = true,
}

-- From CooldownViewerSettingsDataProvider.lua
local ScanLinkedSpellsEvents = {
    ['ACTIVE_COMBAT_CONFIG_CHANGED'] = true,
    ['ACTIVE_PLAYER_SPECIALIZATION_CHANGED'] = true,
    ['ACTIVE_TALENT_GROUP_CHANGED'] = true,
    ['COOLDOWN_VIEWER_TABLE_HOTFIXED'] = true,
    ['PLAYER_EQUIPMENT_CHANGED'] = true,
    ['PLAYER_PVP_TALENT_UPDATE'] = true,
    ['SPELLS_CHANGED'] = true,
    ['TRAIT_CONFIG_UPDATED'] = true,
}

local UpdateAllAurasEvents = {
    ['PLAYER_TARGET_CHANGED'] = true,
    ['UNIT_FACTION'] = true,
}

local AllEvents = CreateFromMixins(UpdateFiltersEvents, ScanLinkedSpellsEvents, UpdateAllAurasEvents)

local function OnEditModeEnter()
    HideAuraContainers()
end

local function OnEditModeExit()
    ApplyAuraSlotScales()
    ShowAuraContainers()
end

local function Initialize()
    addon.InitializeOptions()
    EventFrame:RegisterEvent('ADDON_RESTRICTION_STATE_CHANGED')
    EventFrame:RegisterEvent('EDIT_MODE_LAYOUTS_UPDATED')
    FrameUtil.RegisterFrameForEvents(EventFrame, GetKeysArray(AllEvents))
    EventRegistry:RegisterCallback("EditMode.Enter", OnEditModeEnter)
    EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit)
    -- Buttons haven't been scaled at addon loaded, need to scale after. This
    -- is safe at PLAYER_LOGIN even under restrictions.
    ApplyAuraSlotScales(true)
    ScanLinkedSpells()
    UpdateOverlayFilters()
end

local function OnEvent(_, event, ...)
    if event == 'PLAYER_LOGIN' then
        Initialize()
    elseif event == 'ADDON_RESTRICTION_STATE_CHANGED' then
        ApplyAuraSlotScales()
    elseif event == 'EDIT_MODE_LAYOUTS_UPDATED' then
        ApplyAuraSlotScales()
    elseif UpdateFiltersEvents[event] then
        UpdateOverlayFilters()
    elseif ScanLinkedSpellsEvents[event] then
        ScanLinkedSpells()
        UpdateOverlayFilters()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        OnTargetChanged()
    elseif event == 'UNIT_FACTION' then
        -- Maybe what's fired when you get MC and previously attackable target
        -- becomes friendly?
        local unitToken = ...
        if unitToken == 'target' then
            OnTargetChanged()
        end
    end
end

-- PLAYER_LOGIN is too late for creating AuraContainer during restrictions
do
    EventFrame:RegisterEvent('PLAYER_LOGIN')
    EventFrame:SetScript('OnEvent', OnEvent)
    CreateAuraContainers()
    CreateAuraSlots()
end
