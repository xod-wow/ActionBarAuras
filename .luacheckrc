exclude_files = {
    ".luacheckrc",
    "Tests/",
    "Libs/",
}

-- https://luacheck.readthedocs.io/en/stable/warnings.html

ignore = {
    "11./BINDING_.*", -- Setting an undefined (Keybinding) global variable
    "211", -- Unused local variable
    "212", -- Unused argument
    "213", -- Unused loop variable
    "432/self", -- Shadowing a local variable
    "542", -- empty if branch
    "631", -- line too long
}

globals = {
    'SlashCmdList',
}

read_globals = {
    'ActionButtonUtil',
    'AuraContainerSortDirection',
    'AuraContainerSortMethod',
    'CreateColor',
    'CreateDataProvider',
    'CreateTreeDataProvider',
    'CreateFrame',
    'CreateFromMixins',
    'C_AddOns',
    'C_CooldownViewer',
    'C_CurveUtil',
    'C_Item',
    'C_RestrictedActions',
    'C_Spell',
    'C_SpellBook',
    'C_StringUtil',
    'CreateScrollBoxListLinearView',
    'CreateScrollBoxListTreeListView',
    'Dominos',
    'Enum',
    'EventRegistry',
    'FrameUtil',
    'GameFontWhite',
    'GameFontNormal',
    'GameTooltip',
    'GameTooltip_Hide',
    'GetActionInfo',
    'GetActionText',
    'GetFlyoutInfo',
    'GetFlyoutSlotInfo',
    'GetKeysArray',
    'GetMacroItem',
    'InCombatLockdown',
    'LibStub',
    'Mixin',
    'NUM_ACTIONBAR_BUTTONS',
    'NumberFontNormal',
    'PixelUtil',
    'PlayerUtil',
    'ScrollBoxConstants',
    'ScrollUtil',
    'SelectionBehaviorMixin',
    'Settings',
    'SettingsPanel',
    'Spell',
    'UIParent',
    'UnitCanAssist',
}
