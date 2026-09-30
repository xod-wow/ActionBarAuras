local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnTitle(addonName)

addon.CorePanelMixin = {}

function addon.CorePanelMixin:Refresh()
    self.DemoOverlay:Style()
    self.StacksFont:Setup(function (...) print(...) end, NumberFontNormal:GetFont())
    self.DurationFont:Setup(function (...) print(...) end, NumberFontNormal:GetFont())
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
    self:Refresh()
end
