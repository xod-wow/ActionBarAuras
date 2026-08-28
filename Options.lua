--[[----------------------------------------------------------------------------

    LiteButtonAuras
    Copyright 2021 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local _, addon = ...

local defaults = {
    profile = {
        ignoreAbilities = {},
        ignoreAuraSpellIDs = {},
        extraLinkedSpellIDs = {
            [100784]    = { [202090] = true },
            [30455]     = { [1221389] = true },
        },
    },
}

function addon.InitializeOptions()
    addon.db = LibStub("AceDB-3.0"):New("ActionBarAurasDB", defaults, true)
end
