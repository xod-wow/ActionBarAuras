local _, addon = ...

--[[------------------------------------------------------------------------]]--

addon.SelectFontMixin = {}

local LSM = LibStub("LibSharedMedia-3.0")

local function FontFileMenuGenerate(owner, rootDescription)
    local self = owner:GetParent()
    local fontList = LSM:List('font')
    local function IsSelected(file)
        return self.fontFile == file
    end
    local function SetSelected(file)
        self.fontFile = file
        self:Trigger()
    end
    for _, fontName in ipairs(fontList) do
        local fontFile = LSM:Fetch('font', fontName)
        rootDescription:CreateRadio(fontName, IsSelected, SetSelected, fontFile)
    end
end

local function FontFlagsMenuGenerate(owner, rootDescription)
    local self = owner:GetParent()
    local function IsSelected(flags)
        return self.fontFlags == flags
    end
    local function SetSelected(flags)
        self.fontFlags = flags
        self:Trigger()
    end
    rootDescription:CreateRadio("None", IsSelected, SetSelected, "")
    rootDescription:CreateRadio("Outline", IsSelected, SetSelected, "OUTLINE")
    rootDescription:CreateRadio("Thick outline", IsSelected, SetSelected, "THICKOUTLINE")
    rootDescription:CreateRadio("Slug", IsSelected, SetSelected, "SLUG")
end

function addon.SelectFontMixin:Trigger()
    if self.callback then
        self.callback(self.fontFile, self.fontSize, self.fontFlags)
    end
end

function addon.SelectFontMixin:Refresh()
    self.FileDropdown:SetupMenu(FontFileMenuGenerate)
    self.FlagsDropdown:SetupMenu(FontFlagsMenuGenerate)
    self.SizeSlider:SetMinMaxValues(5, 45)
    self.SizeSlider:SetValue(self.fontSize)
end

function addon.SelectFontMixin:Setup(callback, fontFile, fontSize, fontFlags)
    self.fontFile = fontFile
    self.fontSize = fontSize
    self.fontFlags = fontFlags
    self.callback = callback
    self:Refresh()
end
