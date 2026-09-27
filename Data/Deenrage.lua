local _, addon = ...

local DeenrageSpells = {
    [  2908] = true,                -- Deenrage (Druid)
    [ 19801] = true,                -- Tranquilizing Shot (Hunter)
    [  5938] = true,                -- Shiv (Rogue)
    [115078] = function ()          -- Paralysis (Monk) with Pressure Points
        return C_SpellBook.IsSpellKnown(450432)
    end,
}

local DeenrageSpellsByName = {}
for spellID in pairs(DeenrageSpells) do
    local name = C_Spell.GetSpellName(spellID)
    if name then
        DeenrageSpellsByName[name] = true
    end
end

function addon.IsDeenrage(spellID)
    local name = C_Spell.GetSpellName(spellID)
    local v = DeenrageSpellsByName[name]
    if type(v) == 'function' then
        return v()
    else
        return v
    end
end

