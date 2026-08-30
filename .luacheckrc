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
}

read_globals =  {
    'ActionButtonUtil',
    'AuraContainerSortDirection',
    'AuraContainerSortMethod',
    'CreateColor',
    'CreateFrame',
    'CreateFromMixins',
    'C_CooldownViewer',
    'C_CurveUtil',
    'C_Item',
    'C_RestrictedActions',
    'C_Spell',
    'C_StringUtil',
    'Dominos',
    'Enum',
    'EventRegistry',
    'FrameUtil',
    'GetActionInfo',
    'GetActionText',
    'GetKeysArray',
    'GetMacroItem',
    'LibStub',
    'Mixin',
    'NUM_ACTIONBAR_BUTTONS',
    'PixelUtil',
    'UIParent',
    'UnitCanAssist',
}
