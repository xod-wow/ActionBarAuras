local _, addon = ...

--[[----------------------------------------------------------------------]]--

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


--[[----------------------------------------------------------------------]]--

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

addon.Core = CreateFrame('Frame')

function addon.Core:Initialize()
    addon.InitializeOptions()
    addon.ScanLinkedSpells()
    addon.Controller:Initialize()
    self:RegisterEvent('ADDON_RESTRICTION_STATE_CHANGED')
end

local needsStyle = false

function addon.Core:OnEvent(event, ...)
    if event == 'PLAYER_LOGIN' then
        self:Initialize()
    elseif ScanLinkedSpellsEvents[event] then
        addon.ScanLinkedSpells()
        addon.Controller:UpdateOverlayFilters()
    elseif event == 'ADDON_RESTRICTION_STATE_CHANGED' then
        -- local type, state = ...
        if needsStyle and IsModifyAllowed() then
            addon.Controller:StyleAllOverlays()
            needsStyle = false
        end
    end
end

function addon.Core:OnOptionsChanged()
    if IsModifyAllowed() then
        addon.Controller:StyleAllOverlays()
    else
        needsStyle = true
    end
    addon.Controller:UpdateOverlayFilters()
end

-- PLAYER_LOGIN is too late for creating AuraContainer during restrictions
do
    addon.Core:SetScript('OnEvent', addon.Core.OnEvent)
    addon.Core:RegisterEvent('PLAYER_LOGIN')
    addon.Controller:CreateButtonManagers()
end

--@debug@
ABA = addon
--@end-debug@
