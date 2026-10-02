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
    rootDescription:CreateRadio("Slug", IsSelected, SetSelected, "SLUG")
    rootDescription:CreateRadio("Outline", IsSelected, SetSelected, "OUTLINE")
    rootDescription:CreateRadio("Outline+Slug", IsSelected, SetSelected, "OUTLINE,SLUG")
end

function addon.SelectFontMixin:Trigger()
    if self.callback then
        self.callback(self.fontFile, self.fontSize, self.fontFlags)
    end
end

function addon.SelectFontMixin:Refresh()
    self.FileDropdown:SetupMenu(FontFileMenuGenerate)
    self.FlagsDropdown:SetupMenu(FontFlagsMenuGenerate)
    self.SizeSlider:SetMinMaxValues(8, 42)
    self.SizeSlider:SetValue(self.fontSize)
end

function addon.SelectFontMixin:Setup(callback, fontFile, fontSize, fontFlags)
    self.fontFile = fontFile
    self.fontSize = fontSize
    self.fontFlags = fontFlags
    self.callback = callback
    self:Refresh()
end

function addon.SelectFontMixin:OnLoad()
    self.SizeSlider:SetScript('OnValueChanged',
        function (slider, value, userInput)
            slider.ValueText:SetFormattedText(slider.valueTextTemplate, value)
            if userInput then
                self.fontSize = value
                self:Trigger()
            end
        end)
end


--[[------------------------------------------------------------------------]]--

addon.SelectAnchorMixin = {}

local function PointMenuGenerate(owner, rootDescription)
    local self = owner:GetParent()
    local function IsSelected(anchorPoint)
        return self.anchorPoint == anchorPoint
    end
    local function SetSelected(anchorPoint)
        self.anchorPoint = anchorPoint
        self:Trigger()
    end
    rootDescription:CreateRadio("Top Left", IsSelected, SetSelected, "TOPLEFT")
    rootDescription:CreateRadio("Top", IsSelected, SetSelected, "TOP")
    rootDescription:CreateRadio("Top Right", IsSelected, SetSelected, "TOPRIGHT")
    rootDescription:CreateRadio("Left", IsSelected, SetSelected, "LEFT")
    rootDescription:CreateRadio("Center", IsSelected, SetSelected, "CENTER")
    rootDescription:CreateRadio("Right", IsSelected, SetSelected, "RIGHT")
    rootDescription:CreateRadio("Bottom Left", IsSelected, SetSelected, "BOTTOMLEFT")
    rootDescription:CreateRadio("Bottom", IsSelected, SetSelected, "BOTTOM")
    rootDescription:CreateRadio("Bottom Right", IsSelected, SetSelected, "BOTTOMRIGHT")
end

function addon.SelectAnchorMixin:Trigger()
    if self.callback then
        self.callback(self.anchorPoint, self.xOffset, self.yOffset)
    end
end

function addon.SelectAnchorMixin:Refresh()
    self.PointDropdown:SetupMenu(PointMenuGenerate)
    self.XSlider:SetMinMaxValues(-16, 16)
    self.XSlider:SetValue(self.xOffset)
    self.YSlider:SetMinMaxValues(-16, 16)
    self.YSlider:SetValue(self.yOffset)
end

function addon.SelectAnchorMixin:Setup(callback, anchorPoint, xOffset, yOffset)
    self.anchorPoint = anchorPoint
    self.xOffset = xOffset
    self.yOffset = yOffset
    self.callback = callback
    self:Refresh()
end

function addon.SelectAnchorMixin:OnLoad()
    self.XSlider:SetScript('OnValueChanged',
        function (slider, value, userInput)
            slider.ValueText:SetFormattedText(slider.valueTextTemplate, value)
            if userInput then
                self.xOffset = value
                self:Trigger()
            end
        end)
    self.YSlider:SetScript('OnValueChanged',
        function (slider, value, userInput)
            slider.ValueText:SetFormattedText(slider.valueTextTemplate, value)
            if userInput then
                self.yOffset = value
                self:Trigger()
            end
        end)
end

