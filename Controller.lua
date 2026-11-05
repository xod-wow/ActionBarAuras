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

local UpdateAllAurasEvents = {
    ['PLAYER_TARGET_CHANGED'] = true,
}

addon.Controller = CreateFrame('Frame')

-- Try to handle the fact that you can't create CustomAuraContainerTemplate at
-- PLAYER_LOGIN during various lockdowns, but you can reparent them, setpoint
-- them and do various other things to configure them.
--
-- Create the maximum number required up front in an object pool, so they can
-- be Aquire()d later in the game loading process.

local function CreateButtonManager()
    local bm = CreateFromMixins(addon.ButtonManagerMixin)
    bm:Initialize()
    return bm
end

local function ResetButtonManager(_, bm)
    bm:Reset()
end

function addon.Controller:CreateButtonManagers()
    self.buttonManagerPool = CreateObjectPool(CreateButtonManager, ResetButtonManager)
    for i = 1, MAX_ACTIONS do
        self.buttonManagerPool:Acquire()
    end
    self.buttonManagerPool:ReleaseAll()
end

function addon.Controller:AssignButtonManagers()
    self.buttonManagerPool:ReleaseAll()
    for button in EnumerateActionButtons() do
        local bm = self.buttonManagerPool:Acquire()
        bm:AssignToButton(button)
    end
end

function addon.Controller:UpdateOverlayFilters()
    for buttonManager in self.buttonManagerPool:EnumerateActive() do
        buttonManager:UpdateFilters()
    end
end

function addon.Controller:StyleAllOverlays()
    for buttonManager in self.buttonManagerPool:EnumerateActive() do
        buttonManager:Style()
    end
end

function addon.Controller:Initialize()
    self:SetScript('OnEvent', self.OnEvent)
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(UpdateFiltersEvents))
    FrameUtil.RegisterFrameForEvents(self, GetKeysArray(UpdateAllAurasEvents))
    self:AssignButtonManagers()
    self:StyleAllOverlays()
    self:UpdateOverlayFilters()
end

-- Events seem to be dispatched in order of registration, but we should
-- assume it's random. Give buttons a chance to do all their stuff
-- first in their event handlers and trigger next frame.

function addon.Controller:ScheduleUpdate()
    self:SetScript('OnUpdate', self.OnUpdateOneShot)
end

function addon.Controller:OnUpdateOneShot()
    self:UpdateOverlayFilters()
    self:SetScript('OnUpdate', nil)
end

function addon.Controller:OnEvent(event, ...)
    if UpdateFiltersEvents[event] then
        self:ScheduleUpdate()
    elseif event == 'PLAYER_TARGET_CHANGED' then
        self:ScheduleUpdate()
    elseif event == 'UNIT_FACTION' or event == 'UNIT_FLAGS' then
        -- Maybe what's fired when you get MC and previously attackable target
        -- becomes friendly?
        local unitToken = ...
        if unitToken == 'target' then
            self:ScheduleUpdate()
        end
    end
end
