local _, addon = ...

local RaidBuffs = {
    {
        -- Arcane Intellect / Arcane Brilliance
        spellIDs = { 1459, 432778 },
    },
    {
        -- Battle Shout
        spellIDs = { 6673 },
    },
    {
        -- Blessing of the Bronze
        spellIDs = { 364342 },
        linkedSpellIDs = {
            381732,
            381741,
            381746,
            381748,
            381749,
            381750,
            381751,
            381752,
            381753,
            381754,
            381756,
            381757,
            381758,
        },
    },
    {
        -- Mark of the Wild
        spellIDs = { 1126, 432661 },
    },
    {
        -- Power Word: Fortitude
        spellIDs = { 21562 },
    },
    {
        -- Skyfury
        spellIDs = { 462854 },
    },
}

do
    addon.RaidBuffsBySpellID = { }
    for _, info in ipairs(RaidBuffs) do
        local includeSpellIDs = { }
        for _, spellID in ipairs(info.linkedSpellIDs or {}) do
            includeSpellIDs[spellID] = true
        end
        for _, spellID in ipairs(info.spellIDs) do
            includeSpellIDs[spellID] = true
            addon.RaidBuffsBySpellID[spellID] = includeSpellIDs
        end
    end
end
