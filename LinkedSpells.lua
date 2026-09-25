local _, addon = ...

-- These are per-spec but there's no point clearing them out I don't think.
-- [BarSpellID] = { [AuraSpellID] = true, ... }

local LinkedSpellIDs = { }

local function AddLinkedSpell(name, linkedSpellID)
    if name then
        LinkedSpellIDs[name] = LinkedSpellIDs[name] or {}
        LinkedSpellIDs[name][linkedSpellID] = true
    end
end

-- TODO equipped items without spellID?
function addon.ScanLinkedSpells()
    for c = Enum.CooldownViewerCategoryMeta.MinValue, Enum.CooldownViewerCategoryMeta.MaxValue do
        for _, cooldownID in ipairs(C_CooldownViewer.GetCooldownViewerCategorySet(c, true)) do
            local info = C_CooldownViewer.GetCooldownViewerCooldownInfo(cooldownID)
            if info.spellID then
                local name = C_Spell.GetSpellName(info.spellID)
                AddLinkedSpell(name, info.spellID)
                for _, spellID in ipairs(info.linkedSpellIDs) do
                    AddLinkedSpell(name, spellID)
                    -- Also attach linked spells to anything with the same name.
                    -- E.g., the Whirlwind buff is attached to Improved Whirlwind
                    -- in the CDM but attach it to Whirlwind.
                    local linkedName = C_Spell.GetSpellName(spellID)
                    AddLinkedSpell(linkedName, spellID)
                end
            end
        end
    end
end

function addon.GetLinkedSpellIDs(spellID)
    local spellIDs = { [spellID] = true }
    local name = C_Spell.GetSpellName(spellID)
    Mixin(spellIDs, LinkedSpellIDs[name] or {})
    return spellIDs
end

function addon.GetRaidIncludeSpellIDs(spellID)
    local conf = addon.db.profile.abilities[spellID]
    local spellIDs = {}
    if conf.enableDefault then
        Mixin(spellIDs, addon.RaidBuffsBySpellID[spellID])
    end
    return spellIDs
end

function addon.GetIncludeSpellIDs(spellID)
    local conf = addon.db.profile.abilities[spellID]

    local spellIDs = {}

    if conf.enableDefault then
        Mixin(spellIDs, addon.GetLinkedSpellIDs(spellID))

        -- Base spell if it's different
        local baseSpellID = C_Spell.GetBaseSpell(spellID)
        if baseSpellID ~= spellID then
            Mixin(spellIDs, addon.GetLinkedSpellIDs(baseSpellID))
        end
    end

    Mixin(spellIDs, addon.db.profile.abilities[spellID].linkedSpellIDs)

    return spellIDs
end
