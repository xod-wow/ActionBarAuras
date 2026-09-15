local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnTitle(addonName)

addon.CorePanelMixin = {}

function addon.CorePanelMixin:OnLoad()

    self.Title:SetText(addonTitle)

    addon.category = Settings.RegisterCanvasLayoutCategory(self, addonTitle)
    Settings.RegisterAddOnCategory(addon.category)

    SlashCmdList[addonName] =
        function ()
            if not InCombatLockdown() then
                SettingsPanel:Open()
                SettingsPanel:SelectCategory(addon.category, true)
            end
        end
    _G["SLASH_"..addonName.."1"] = "/aba"
end

function addon.CorePanelMixin:OnShow()
end
