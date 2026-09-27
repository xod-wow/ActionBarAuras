local _, addon = ...

local HostileDispelSpells = {
    [278326] = true,    -- Consume Magic (Demon Hunter)
    [ 19801] = true,    -- Tranquilizing Shot (Hunter)
    [ 30449] = true,    -- Spellsteal (Mage)
    [   528] = true,    -- Dispel Magic (Priest)
    [ 32375] = true,    -- Mass Dispel (Priest)
    [   370] = true,    -- Purge (Shaman)
    [ 19505] = true,    -- Devour Magic (Warlock)
    [ 25046] = true,    -- Arcane Torrent (Blood Elf Rogue)
}

local HostileDispelSpellsByName = {}
for spellID in pairs(HostileDispelSpells) do
    local name = C_Spell.GetSpellName(spellID)
    if name then
        HostileDispelSpellsByName[name] = true
    end
end

function addon.IsHostileDispel(spellID)
    local name = C_Spell.GetSpellName(spellID)
    return HostileDispelSpellsByName[name] == true
end
