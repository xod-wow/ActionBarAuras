--[[----------------------------------------------------------------------------

    ActionBarAuras
    Copyright 2026 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local _, addon = ...

-- local fontPath, fontSize, fontFlags = NumberFontNormal:GetFont()

local DefaultAbility = {
    enable = true,
    enableDefault = true,
    linkedSpellIDs = { },
}

local defaults = {
    profile = {
        overlay = {
            enable = true,
            texture = [[Interface\AddOns\ActionBarAuras\Textures\Overlay]],
            color = {
                buff    = { r=0.00, g=0.70, b=0.00, a=0.50 },
                debuff  = { r=1.00, g=0.00, b=0.00, a=0.50 },
            },
        },
        duration = {
            enable = true,
            font = "NumberFontNormal",
            anchor = { point="BOTTOMLEFT", x=3, y=3 },
        },
        stacks = {
            enable = true,
            font = "NumberFontNormal",
            anchor = { point="TOPLEFT", x=3, y=-3 },
        },
        abilities = {
            ['*'] = DefaultAbility,
        }
    },
}

function addon.InitializeOptions()
    addon.db = LibStub("AceDB-3.0"):New("ActionBarAurasDB", defaults, true)
end
