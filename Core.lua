local _, addon = ...

local MAX_ACTIONS = 180

--[[--------------------------------------------------------------------------]]--

-- Does not support bar addons that don't use actionID but keep their own
-- SABT configs completely separately.

local function EnumerateActionButtons()
    local buttonsByAction = {}

    -- Blizzard
    for _, actionBar in ipairs(ActionButtonUtil.ActionBarButtonNames) do
        for i = 1, NUM_ACTIONBAR_BUTTONS do
            local actionButton = _G[actionBar..i]
            local actionID = actionButton.action
            buttonsByAction[actionID] = actionButton
        end
    end

    -- Dominos
    if Dominos then
        for actionButton, actionID in Dominos.ActionButtons:GetAll() do
            buttonsByAction[actionID] = actionButton
        end
    end

    -- LibActionButton-1.0, notably Bartender4
    --
    -- The %- here is a literal - instead of "zero or more repetitions". A
    -- few addons (most noteably ElvUI) use their own private version of
    -- LibActionButton with a suffix added to the name.

    for name, lib in LibStub:IterateLibraries() do
        if name:match('^LibActionButton%-1.0') then
            for actionButton in pairs(lib:GetAllButtons()) do
                local actionType, actionID = actionButton:GetAction()
                if actionType == "action" then
                    buttonsByAction[actionID] = actionButton
                end
            end
        end
    end

    -- EUI and EUIStandaloneActionBars
    for actionID = 1, MAX_ACTIONS do
        local actionButton = _G["EABButton"..actionID]
        if actionButton then
            buttonsByAction[actionID] = actionButton
        end
    end

    local buttons = GetValuesArray(buttonsByAction)

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

-- To support various action bar addons, this might need to hook the buttons
-- themselves for filter update on change, since plenty of them use all the SGH
-- stuff rather than the Blizzard bar paging. See BarIntegrations.lua in LBA.

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

local StyleOverlaysEvents = {
    ['ADDON_RESTRICTION_STATE_CHANGED'] = true,
}

local function CreateButtonManager()
    local bm = CreateFromMixins(addon.ButtonManagerMixin)
    bm:Initialize()
    return bm
end

local function ResetButtonManager(_, bm)
    bm:Reset()
end

addon.Controller = CreateFrame('Frame')

-- Try to handle the fact that you can't create CustomAuraContainerTemplate at
-- PLAYER_LOGIN during various lockdowns, but you can reparent them, setpoint
-- them and do various other things to configure them.
--
-- Create the maximum number required up front in an object pool, so they can
-- be Aquire()d later in the game loading process.

function addon.Controller:CreateButtonManagers()
    self.buttonManagers = CreateObjectPool(CreateButtonManager, ResetButtonManager)
    for i = 1, MAX_ACTIONS do
        self.buttonManagers:Acquire()
    end
    self.buttonManagers:ReleaseAll()
end

function addon.Controller:AssignButtonManagers()
    self.buttonManagers:ReleaseAll()
    for button in EnumerateActionButtons() do
        local bm = self.buttonManagers:Acquire()
        bm:AssignToButton(button)
    end
end

function addon.Controller:UpdateOverlayFilters()
    for buttonManager in self.buttonManagers:EnumerateActive() do
        buttonManager:UpdateFilters()
    end
end

function addon.Controller:StyleAllOverlays()
    for buttonManager in self.buttonManagers:EnumerateActive() do
        buttonManager:Style()
    end
end

function addon.Controller:Initialize()
    addon.InitializeOptions()
    addon.Controller:AssignButtonManagers()
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(UpdateFiltersEvents))
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(ScanLinkedSpellsEvents))
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(UpdateAllAurasEvents))
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(StyleOverlaysEvents))
    addon.ScanLinkedSpells()
    self:StyleAllOverlays()
    self:UpdateOverlayFilters()
end

local needsStyle = false

-- Events seem to be dispatched in order of registration, but we should
-- assume it's random. Give buttons a chance to do all their stuff
-- first in their event handlers and trigger next frame.

function addon.Controller:OnEvent(event, ...)
    if event == 'PLAYER_LOGIN' then
        -- In an ideal world we would delay this until all the bar addons had
        -- a chance to make their buttons, instead of having to list them all
        -- as OptionalDeps in the ToC to ensure event ordering. But next frame
        -- is too late and combat restrictions have begun.
        self:Initialize()
    elseif UpdateFiltersEvents[event] then
        RunNextFrame(function () self:UpdateOverlayFilters() end)
    elseif ScanLinkedSpellsEvents[event] then
        addon.ScanLinkedSpells()
        self:UpdateOverlayFilters()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        RunNextFrame(function () self:UpdateOverlayFilters() end)
    elseif event == 'UNIT_FACTION' or event == 'UNIT_FLAGS' then
        -- Maybe what's fired when you get MC and previously attackable target
        -- becomes friendly?
        local unitToken = ...
        if unitToken == 'target' then
            RunNextFrame(function () self:UpdateOverlayFilters() end)
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
    addon.Controller:SetScript('OnEvent', addon.Controller.OnEvent)
    addon.Controller:CreateButtonManagers()
end

--@debug@
ABA = addon
--@end-debug@
