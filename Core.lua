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
                LinkedSpellIDs[name] = LinkedSpellIDs[name] or {}
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
        includeRaidBuffs = true,
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

local function HideAuraContainers()
    for _, cf in ipairs(AuraContainers) do
        for _, c in pairs(cf.buttonContainers) do
            c:Hide()
        end
    end
end

local function ShowAuraContainers()
    for _, cf in ipairs(AuraContainers) do
        for _, c in pairs(cf.buttonContainers) do
            c:Show()
        end
    end
end

-- This creates an insane amount of AuraContainers, two per ActionButton.
--
-- I don't know if this is necessarily less computationally efficient in any
-- way, it might make no difference.
--
-- I tried making one for each target/auratype combo with an AuraSlot per
-- button, but it was a big hassle (a) getting the scaling right since you
-- can't SetParent the AuraSlot, and (b) doing the disabling since
-- SetEnabled() is only on containers not slots.
--
-- This also scales properly if the actionbars change in combat or in M+, which
-- is impossible to do with the other approach.
--
-- If it's necessary to go back to one container multiple slots, make sure
-- to test it with actions on bars/buttons that aren't shown.
--
-- In theory in 12.1.5 we will get SetUnit per slot, which will allow one
-- container per button with a slot for each category. Can then also
-- prioritize them and not double up if we have both a buff and a debuff.

local function CreateAuraContainers()
    for _, cf in ipairs(AuraContainers) do
        cf.buttonContainers = {}
        for button in EnumerateActionButtons() do
            local name = button:GetName() ..'ABAContainer'
            local c = CreateFrame('AuraContainer', name, button, 'CustomAuraContainerTemplate')
            c:SetPoint("TOPLEFT")
            c:SetUnit(cf.unit)
            CreateButtonAuraSlot(cf, c, button)
            cf.buttonContainers[button:GetName()] = c
        end
    end
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

local BadRestrictions = { 'Combat', 'Encounter', 'ChallengeMode', 'PvPMatch' }

local function IsModifyAllowed()
    for _, r in ipairs(BadRestrictions) do
        if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType[r]) then
            return false
        end
    end
    return true
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

local function GetFilters(cf, spellID)
    if cf.includeRaidBuffs and addon.RaidBuffsBySpellID[spellID] then
        local candidateFilters = {
            includeSpellIDs = addon.RaidBuffsBySpellID[spellID]
        }
        Mixin(candidateFilters.includeSpellIDs, addon.RaidBuffsBySpellID[spellID])
        cf.addFilters(candidateFilters)
        return cf.filter, candidateFilters
    else
        local candidateFilters = {
            includeSpellIDs = {}
        }
        -- Spell itself and its linked spellds
        candidateFilters.includeSpellIDs[spellID] = true
        Mixin(candidateFilters.includeSpellIDs, GetLinkedSpellIDs(spellID))
        -- Base spell if it's different
        local baseSpellID = C_Spell.GetBaseSpell(spellID)
        if baseSpellID ~= spellID then
            candidateFilters.includeSpellIDs[baseSpellID] = true
            Mixin(candidateFilters.includeSpellIDs, GetLinkedSpellIDs(baseSpellID))
        end
        cf.addFilters(candidateFilters)
        return cf.filter..'|PLAYER', candidateFilters
    end
end

local function UpdateOverlayFilters(matchfunc)
    for _, cf in ipairs(AuraContainers) do
        if not matchfunc or matchfunc(cf) then
            local canEnable = CanEnable(cf)
            for name, c in pairs(cf.buttonContainers) do
                local b = _G[name]
                local spellID = GetActionSpellID(b.action)
                if not canEnable or not spellID or not b:IsVisible() then
                    c:SetEnabled(false)
                else
                    local filterString, candidateFilters = GetFilters(cf, spellID)
                    c:SetAuraSlotFilterString("ABA", filterString)
                    c:SetAuraSlotCandidateFilters("ABA", candidateFilters)
                    c:SetEnabled(true)
                end
            end
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
    ShowAuraContainers()
end

local function Initialize()
    addon.InitializeOptions()
    FrameUtil.RegisterFrameForEvents(EventFrame, GetKeysArray(AllEvents))
    EventRegistry:RegisterCallback("EditMode.Enter", OnEditModeEnter)
    EventRegistry:RegisterCallback("EditMode.Exit", OnEditModeExit)
    ScanLinkedSpells()
    UpdateOverlayFilters()
end

local function OnEvent(_, event, ...)
    local function cfmatchtarget(cf) return cf.unit == 'target' end
    if event == 'PLAYER_LOGIN' then
        Initialize()
    elseif UpdateFiltersEvents[event] then
        UpdateOverlayFilters()
    elseif ScanLinkedSpellsEvents[event] then
        ScanLinkedSpells()
        UpdateOverlayFilters()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        UpdateOverlayFilters(cfmatchtarget)
    elseif event == 'UNIT_FACTION' then
        -- Maybe what's fired when you get MC and previously attackable target
        -- becomes friendly?
        local unitToken = ...
        if unitToken == 'target' then
            UpdateOverlayFilters(cfmatchtarget)
        end
    end
end

-- PLAYER_LOGIN is too late for creating AuraContainer during restrictions
do
    EventFrame:RegisterEvent('PLAYER_LOGIN')
    EventFrame:SetScript('OnEvent', OnEvent)
    CreateAuraContainers()
end
