local _, addon = ...

local HostileDispels = {
    [278326] = true,    -- Consume Magic (Demon Hunter)
    [ 19801] = true,    -- Tranquilizing Shot (Hunter)
    [ 30449] = true,    -- Spellsteal (Mage)
    [   528] = true,    -- Dispel Magic (Priest)
    [ 32375] = true,    -- Mass Dispel (Priest)
    [   370] = true,    -- Purge (Shaman)
    [ 19505] = true,    -- Devour Magic (Warlock)
    [ 25046] = true,    -- Arcane Torrent (Blood Elf Rogue)
}

local HostileDispelsByName = {}
for spellID in pairs(HostileDispels) do
    local name = C_Spell.GetSpellName(spellID)
    if name then
        HostileDispelsByName[name] = true
    end
end

function addon.IsHostileDispel(spellID)
    local name = C_Spell.GetSpellName(spellID)
    return HostileDispelsByName[name] == true
end
