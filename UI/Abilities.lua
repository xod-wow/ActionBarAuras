local addonName, addon = ...

addon.AbilitiesPanelMixin = {}

function addon.AbilitiesPanelMixin:OnLoad()
    local view = CreateScrollBoxListTreeListView()
    view:SetElementIndentCalculator(
        function (node)
            local data = node:GetData()
            if data.numSpellBookItems then
                return 0
            else
                return 8
            end
        end)
    view:SetElementFactory(
        function (factory, node)
            local data = node:GetData()
            local specID = PlayerUtil.GetCurrentSpecID()
            local isOffSpec = data.isOffSpec or (data.specID ~= nil and data.specID ~= specID)
            local font = isOffSpec and GameFontWhite or GameFontNormal
            if data.numSpellBookItems then
                factory("ABAAbilityHeaderTemplate",
                    function (button)
                        button.Text:SetTextColor(font:GetTextColor())
                        button:SetText(data.name)
                        button:SetScript("OnClick",
                            function ()
                                node:ToggleCollapsed()
                                -- button:SetCollapsedState(node:IsCollapsed())
                            end)
                    end)
            else
                factory("ABAAbilityItemTemplate",
                    function (button)
                        local data = node:GetData()
                        local isSelected = self.selectionBehavior:IsSelected(button)
                        button.SelectedTexture:SetShown(isSelected)
                        button.Icon:SetTexture(data.iconID)
                        button.Icon:SetDesaturated(data.isOffSpec)
                        button.Icon:SetScript('OnEnter',
                            function (f)
                                GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
                                GameTooltip:SetSpellBookItem(data.index, data.bookType)
                                GameTooltip:Show()
                            end)
                        button.Icon:SetScript('OnLeave', GameTooltip_Hide)
                        button.Name:SetTextColor(font:GetTextColor())
                        button.Name:SetText(data.name)
                        button:SetAlpha(isOffSpec and 0.67 or 1)
                        button:SetScript('OnClick',
                            function ()
                                self.selectionBehavior:Select(button)
                                self:RefreshAbility()
                            end)
                    end)
            end
        end)


    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)

    view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("ABALinkedSpellItemTemplate",
        function (button, elementData)
            local info = C_Spell.GetSpellInfo(elementData)
            button.Icon:SetTexture(info.iconID)
            button.Name:SetText(info.name)
        end)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.Settings.ScrollBox, self.Settings.ScrollBar, view)

    self.selectionBehavior = ScrollUtil.AddSelectionBehavior(self.ScrollBox)
    self.selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged,
        function (_, node, isSelected)
            local button = self.ScrollBox:FindFrame(node)
            if button then
                button.SelectedTexture:SetShown(isSelected)
            end
            if selected then
                self.ScrollBox:ScrollToElementData(node, ScrollBoxConstants.AlignNearest);
            end
        end,
        self)

    self.category = Settings.RegisterCanvasLayoutCategory(self, addonName)
    Settings.RegisterAddOnCategory(self.category)

    SlashCmdList[addonName] =
        function ()
            SettingsPanel:Open()
            SettingsPanel:SelectCategory(self.category, true)
        end
    _G["SLASH_"..addonName.."1"] = "/aba"
end

function addon.AbilitiesPanelMixin:RefreshAbility()
    local node = self.selectionBehavior:GetFirstSelectedElementData()
    local spellID = node:GetData().actionID
    local spellIDs = addon.GetIncludeSpellIDs(spellID, true)
    local dp = CreateDataProvider(GetKeysArray(spellIDs))
    self.Settings.ScrollBox:SetDataProvider(dp)
end

local function IsAbility(node)
    local data = node:GetData()
    return data.actionID ~= nil
end

function addon.AbilitiesPanelMixin:OnShow()
    local dp = self:GetAbilitiesDataProvider()
    self.ScrollBox:SetDataProvider(dp, ScrollBoxConstants.RetainScrollPosition)
    if not self.selectionBehavior:HasSelection() then
        self.selectionBehavior:SelectFirstElementData(IsAbility)
    end
    self:RefreshAbility()
end

function addon.AbilitiesPanelMixin:GetAbilitiesDataProvider()
    local bookType = Enum.SpellBookSpellBank.Player

    local dp = CreateTreeDataProvider()

    for sl = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local slInfo = C_SpellBook.GetSpellBookSkillLineInfo(sl)
        local category = dp:Insert(slInfo)
        for i = 1, slInfo.numSpellBookItems do
            local offset = slInfo.itemIndexOffset + i
            local info = C_SpellBook.GetSpellBookItemInfo(offset, bookType)
            if info.itemType == Enum.SpellBookItemType.Spell and not info.isPassive then
                info.index = offset
                info.bookType = bookType
                category:Insert(info)
            end
        end
    end
    return dp
end
