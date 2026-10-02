local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnTitle(addonName)

addon.CorePanelMixin = {}

function addon.CorePanelMixin:Setup()
    local p = addon.db.profile

    self.DemoOverlay:Style()

    local function SetStacksAnchor(point, x, y)
        p.stacks.point = point
        p.stacks.x = x
        p.stacks.y = y
        self.DemoOverlay:Style()
    end

    local function SetStacksFont(fontFile, fontSize, fontFlags)
        p.stacks.fontFile = fontFile
        p.stacks.fontSize = fontSize
        p.stacks.fontFlags = fontFlags
        self.DemoOverlay:Style()
    end

    self.StacksFont:Setup(SetStacksFont, p.stacks.fontFile, p.stacks.fontSize, p.stacks.fontFlags)
    self.StacksAnchor:Setup(SetStacksAnchor, p.stacks.point, p.stacks.x, p.stacks.y)

    local function SetDurationAnchor(point, x, y)
        p.duration.point = point
        p.duration.x = x
        p.duration.y = y
        self.DemoOverlay:Style()
    end

    local function SetDurationFont(fontFile, fontSize, fontFlags)
        p.duration.fontFile = fontFile
        p.duration.fontSize = fontSize
        p.duration.fontFlags = fontFlags
        self.DemoOverlay:Style()
    end

    self.DurationFont:Setup(SetDurationFont, p.duration.fontFile, p.duration.fontSize, p.duration.fontFlags)
    self.DurationAnchor:Setup(SetDurationAnchor, p.duration.point, p.duration.x, p.duration.y)
end

function addon.CorePanelMixin:OnLoad()

    self.Title:SetText(addonTitle)

    self.DemoButton:SetTexture(135992)
    self.DemoOverlay.durationText:SetText("2.6")
    self.DemoOverlay.stacksText:SetText("2")

    addon.category = Settings.RegisterCanvasLayoutCategory(self, addonTitle)
    Settings.RegisterAddOnCategory(addon.category)

    SlashCmdList[addonName] =
        function ()
            if not InCombatLockdown() then
                SettingsPanel:Open()
                SettingsPanel:SelectCategory(addon.category, true)
            end
            return true
        end
    _G["SLASH_"..addonName.."1"] = "/aba"
end

function addon.CorePanelMixin:OnShow()
    self:Setup()
end
