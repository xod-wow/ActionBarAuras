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


local BadRestrictions = { 'Combat', 'Encounter', 'ChallengeMode', 'PvPMatch' }

local function IsModifyAllowed()
    for _, r in ipairs(BadRestrictions) do
        if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType[r]) then
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

-- In 12.1.5 this will be handled natively by CustomAuraContainerTemplate
local UpdateAllAurasEvents = {
    ['PLAYER_TARGET_CHANGED'] = true,
    ['UNIT_FACTION'] = true,
}

local function CreateButtonManager(button)
    local bm = CreateFromMixins(addon.ButtonManagerMixin)
    bm:Initialize(button)
    return bm
end

local Controller = CreateFrame('Frame')

function Controller:CreateButtonManagers()
    self.buttonManagers = {}
    for button in EnumerateActionButtons() do
        self.buttonManagers[button:GetName()] = CreateButtonManager(button)
    end
end

function Controller:UpdateOverlayFilters()
    for _, buttonManager in pairs(self.buttonManagers) do
        buttonManager:UpdateFilters()
    end
end

function Controller:Initialize()
    addon.InitializeOptions()
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(UpdateFiltersEvents))
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(ScanLinkedSpellsEvents))
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(UpdateAllAurasEvents))
    addon.ScanLinkedSpells()
    self:UpdateOverlayFilters()
end

function Controller:OnEvent(event, ...)
    if event == 'PLAYER_LOGIN' then
        self:Initialize()
    elseif UpdateFiltersEvents[event] then
        self:UpdateOverlayFilters()
    elseif ScanLinkedSpellsEvents[event] then
        addon.ScanLinkedSpells()
        self:UpdateOverlayFilters()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        self:UpdateOverlayFilters()
    elseif event == 'UNIT_FACTION' then
        -- Maybe what's fired when you get MC and previously attackable target
        -- becomes friendly?
        local unitToken = ...
        if unitToken == 'target' then
            self:UpdateOverlayFilters()
        end
    end
end

function addon.OnOptionsChanged()
    Controller:UpdateOverlayFilters()
end

-- PLAYER_LOGIN is too late for creating AuraContainer during restrictions
do
    Controller:RegisterEvent('PLAYER_LOGIN')
    Controller:SetScript('OnEvent', Controller.OnEvent)
    Controller:CreateButtonManagers()
end
