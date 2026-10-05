local _, addon = ...

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
        templateNames = { 'ABAOverlayBuffTemplate' },
        StyleFrame =
            function (f)
                f:Style()
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
                local candidateFilters, filterString = { isHelpful = true }
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
        templateNames = { 'ABAOverlayDebuffTemplate' },
        StyleFrame =
            function (f)
                f:Style()
            end,
        GetEnabled =
            function (spellID)
                local canAssist = UnitCanAssist('player', 'target', true, true)
                return canAssist == false
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
        StyleFrame =
            function (f) f:Style() end,
        GetEnabled =
            function (spellID)
                local canAssist = UnitCanAssist('player', 'target', true, true)
                if canAssist then
                    return false
                else
                    addon.IsHostileDispel(spellID)
                end
            end,
        GetFilters =
            function (spellID)
                local candidateFilters = { isHelpful = true, isStealable = true }
                return 'HELPFUL', candidateFilters
            end,
    },
    {
        name = 'TARGETSOOTHE',
        unit = 'target',
        templateNames = { 'ABAOverlayHighlightTemplate' },
        StyleFrame =
            function (f) f:Style() end,
        GetEnabled =
            function (spellID)
                local canAssist = UnitCanAssist('player', 'target', true, true)
                if canAssist then
                    return false
                else
                    addon.IsDeenrage(spellID)
                end
            end,
        GetFilters =
            function (spellID)
                local candidateFilters = {
                    isHelpful = true,
                    includeDispelTypes = { Enrage = true }
                }
                return 'HELPFUL', candidateFilters
            end,
    },
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
        initializeFrame =
            function (f)
                f:Initialize()
                -- In 12.1.5 replace with GetAuraSlotFrame or GetAuraFrame
                self.auraFrame = f
            end
    }
    self.as = self.c:AddAuraSlot("ABA", "", options)
end

function AuraContainerManagerMixin:Initialize(fd)
    self.fd = fd
    self.c = CreateFrame('AuraContainer', nil, nil, 'CustomAuraContainerTemplate')
    self.c:SetUnit(fd.unit)
    self.c:SetEnabled(false)
    self:CreateAuraSlot()
end

function AuraContainerManagerMixin:AssignToButton(button)
    self.button = button
    self.c:SetParent(button)
    self.c:SetPoint("TOPLEFT")
    PixelUtil.SetSize(self.as, self.button:GetSize())
    self.as:SetPoint("CENTER", self.button)
    self.as:SetFrameLevel(self.button.cooldown:GetFrameLevel()+1)
end

function AuraContainerManagerMixin:Reset()
    self.button = nil
    self.c:SetParent(nil)
    self.c:ClearAllPoints()
    self.c:SetEnabled(false)
    self.c:SetAuraSlotCandidateFilters("ABA", {})
    self.as:ClearAllPoints()
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

function AuraContainerManagerMixin:Style()
    self.fd.StyleFrame(self.auraFrame)
end

local function CreateAuraContainerManager(fd, button)
    local acm = CreateFromMixins(AuraContainerManagerMixin)
    acm:Initialize(fd)
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
    self.acm = {}
    for _, fd in ipairs(FilterDefinitions) do
        self.acm[fd.name] = CreateAuraContainerManager(fd)
    end
end

function addon.ButtonManagerMixin:AssignToButton(button)
    self.button = button
    for _, fd in ipairs(FilterDefinitions) do
        self.acm[fd.name]:AssignToButton(button)
    end
end

function addon.ButtonManagerMixin:Reset()
    self.button = nil
    for _, fd in ipairs(FilterDefinitions) do
        self.acm[fd.name]:Reset()
    end
end

function addon.ButtonManagerMixin:UpdateFilters()
    local spellID = self:GetActionSpellID()
    for _, auraContainerManager in pairs(self.acm) do
        auraContainerManager:UpdateFilters(spellID)
    end
end

function addon.ButtonManagerMixin:Style()
    for _, auraContainerManager in pairs(self.acm) do
        auraContainerManager:Style()
    end
end
