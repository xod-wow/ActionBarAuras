--[[----------------------------------------------------------------------------

    ActionBarAruas
    Copyright 2026 Mike "Xodiv" Battersby

----------------------------------------------------------------------------]]--

local _, addon = ...

-- local fontPath, fontSize, fontFlags = NumberFontNormal:GetFont()

local defaults = {
    profile = {
        overlay = {
            enabled = true,
            texture = [[Interface\AddOns\ActionBarAuras\Textures\Overlay]],
            color = {
                buff    = { r=0.00, g=0.70, b=0.00, a=0.50 },
                debuff  = { r=1.00, g=0.00, b=0.00, a=0.50 },
            },
        },
        duration = {
            enabled = true,
            font = "NumberFontNormal",
            anchor = { point="BOTTOMLEFT", x=3, y=3 },
        },
        stacks = {
            enabled = true,
            font = "NumberFontNormal",
            anchor = { point="TOPLEFT", x=3, y=-3 },
        },
        abilities = {
            [100784] = {
                enabled = true,
                linkedSpellIDs = {
                    [202090] = true
                }
            },
            [30455] = {
                enabled = true,
                linkedSpellIDs = {
                    [1221389] = true
                }
            },
        }
    },
}

function addon.InitializeOptions()
    addon.db = LibStub("AceDB-3.0"):New("ActionBarAurasDB", defaults, true)
end
