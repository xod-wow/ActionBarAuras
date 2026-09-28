local _, addon = ...

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


local BadRestrictions = {
    Enum.AddOnRestrictionType.Combat,
    Enum.AddOnRestrictionType.Encounter,
    Enum.AddOnRestrictionType.ChallengeMode,
    Enum.AddOnRestrictionType.PvPMatch,
}

local function IsModifyAllowed()
    for _, r in ipairs(BadRestrictions) do
        if C_RestrictedActions.IsAddOnRestrictionActive(r) then
            return false
        end
    end
    return true
end


--[[--------------------------------------------------------------------------]]--

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

-- In 12.1.5 the UNIT_ parts of this will be handled automatically
local UpdateAllAurasEvents = {
    ['PLAYER_TARGET_CHANGED'] = true,
    ['UNIT_FACTION'] = true,
    ['UNIT_FLAGS'] = true,
}

local function CreateButtonManager(button)
    local bm = CreateFromMixins(addon.ButtonManagerMixin)
    bm:Initialize(button)
    return bm
end

addon.Controller = CreateFrame('Frame')

function addon.Controller:CreateButtonManagers()
    self.buttonManagers = {}
    for button in EnumerateActionButtons() do
        self.buttonManagers[button:GetName()] = CreateButtonManager(button)
    end
end

function addon.Controller:UpdateOverlayFilters()
    for _, buttonManager in pairs(self.buttonManagers) do
        buttonManager:UpdateFilters()
    end
end

function addon.Controller:StyleAllOverlays()
    for _, buttonManager in pairs(self.buttonManagers) do
        buttonManager:Style()
    end
end

function addon.Controller:Initialize()
    addon.InitializeOptions()
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(UpdateFiltersEvents))
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(ScanLinkedSpellsEvents))
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(UpdateAllAurasEvents))
    addon.ScanLinkedSpells()
    self:StyleAllOverlays()
    self:UpdateOverlayFilters()
end

local needsStyle = false

function addon.Controller:OnEvent(event, ...)
    if event == 'PLAYER_LOGIN' then
        self:Initialize()
    elseif UpdateFiltersEvents[event] then
        self:UpdateOverlayFilters()
    elseif ScanLinkedSpellsEvents[event] then
        addon.ScanLinkedSpells()
        self:UpdateOverlayFilters()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        self:UpdateOverlayFilters()
    elseif event == 'UNIT_FACTION' or event == 'UNIT_FLAGS' then
        -- Maybe what's fired when you get MC and previously attackable target
        -- becomes friendly?
        local unitToken = ...
        if unitToken == 'target' then
            self:UpdateOverlayFilters()
        end
    elseif event == 'ADDON_RESTRICTION_STATE_CHANGED' then
        -- local type, state = ...
        if needsStyle and IsModifyAllowed() then
            addon.Controller:StyleAllOverlays()
            needsStyle = false
        end
    end
end

function addon.OnOptionsChanged()
    if IsModifyAllowed() then
        addon.Controller:StyleAllOverlays()
    else
        needsStyle = true
    end
    addon.Controller:UpdateOverlayFilters()
end

-- PLAYER_LOGIN is too late for creating AuraContainer during restrictions
do
    addon.Controller:RegisterEvent('PLAYER_LOGIN')
    addon.Controller:RegisterEvent('ADDON_RESTRICTION_STATE_CHANGED')
    addon.Controller:SetScript('OnEvent', addon.Controller.OnEvent)
    addon.Controller:CreateButtonManagers()
end

--@debug@
ABA = addon
--@end-debug@
