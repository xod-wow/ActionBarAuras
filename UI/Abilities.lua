local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnTitle(addonName)

addon.AbilityHeaderMixin = {}

function addon.AbilityHeaderMixin:SetExpanded(expanded)
    if expanded then
        self.Toggle:SetAtlas("common-button-dropdown-open")
    else
        self.Toggle:SetAtlas("common-button-dropdown-closed")
    end
end

addon.AbilitiesPanelMixin = {}

function addon.AbilitiesPanelMixin:SpellItemInitializer(button, elementData)
    local info = C_Spell.GetSpellInfo(elementData)
    button.Icon:SetTexture(info.iconID)
    button.Icon:SetScript('OnEnter',
        function ()
            GameTooltip:SetOwner(button.Icon, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(info.spellID)
            GameTooltip:Show()
        end)
    button.Icon:SetScript('OnLeave', GameTooltip_Hide)
    button.Name:SetFormattedText('%s (%d)', info.name, info.spellID)
    if button.Delete then
        button.Delete:SetScript('OnClick',
            function ()
                addon.db.profile.abilities[self.spellID].linkedSpellIDs[info.spellID] = nil
                self:RefreshAbility()
            end)
    end
end

function addon.AbilitiesPanelMixin:OnLoad()

    self.Title:SetText(addonTitle)

    local view = CreateScrollBoxListTreeListView()
    view:SetElementIndentCalculator(
        function (node)
            local data = node:GetData()
            if data.numSpellBookItems then
                return 0
            else
                return 16
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
                        local expanded = data.skillLineIndex > 1 and not isOffSpec
                        node:SetCollapsed(not expanded)
                        button:SetExpanded(expanded)
                        button:SetScript("OnClick",
                            function ()
                                node:ToggleCollapsed()
                                button:SetExpanded(not node:IsCollapsed())
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


    local Initializer = function (...) self:SpellItemInitializer(...) end

    ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view)

    view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("ABASpellItemTemplate", Initializer)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.Settings.DefaultScrollBox, self.Settings.DefaultScrollBar, view)

    view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("ABASpellItemDeleteTemplate", Initializer)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.Settings.ExtraScrollBox, self.Settings.ExtraScrollBar, view)

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

    self.Settings.Enable:HookScript('OnClick',
        function (b)
            local enable = b:GetChecked() == true
            addon.db.profile.abilities[self.spellID].enable = enable
            addon.OnOptionsChanged()
        end)

    self.Settings.EnableDefault:HookScript('OnClick',
        function (b)
            local disable = b:GetChecked() == true
            addon.db.profile.abilities[self.spellID].enableDefault = enable
            addon.OnOptionsChanged()
        end)

    self.category = Settings.RegisterCanvasLayoutCategory(self, addonTitle)
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
    self.spellID = node:GetData().spellID

    local conf = addon.db.profile.abilities[self.spellID]

    self.Settings.Enable:SetChecked(conf.enable)
    self.Settings.EnableDefault:SetChecked(conf.enableDefault)

    local spell = Spell:CreateFromSpellID(self.spellID)
    spell:ContinueOnSpellLoad(
        function ()
            self.Settings.Name:SetText(spell:GetSpellName())
            self.Settings.SpellID:SetText('ID: ' .. spell:GetSpellID())
        end)

    local spellIDs = addon.GetLinkedSpellIDs(self.spellID, true)
    local dp = CreateDataProvider(GetKeysArray(spellIDs))
    self.Settings.DefaultScrollBox:SetDataProvider(dp)

    dp = CreateDataProvider(GetKeysArray(conf.linkedSpellIDs))
    self.Settings.ExtraScrollBox:SetDataProvider(dp)
end

local function IsAbility(node)
    local data = node:GetData()
    return data.spellID ~= nil and data.skillLineIndex > 1
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

    -- XXX TODO Flyouts, Items?

    for sl = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local slInfo = C_SpellBook.GetSpellBookSkillLineInfo(sl)
        slInfo.skillLineIndex = sl
        local category = dp:Insert(slInfo)
        for i = 1, slInfo.numSpellBookItems do
            local offset = slInfo.itemIndexOffset + i
            local info = C_SpellBook.GetSpellBookItemInfo(offset, bookType)
            if info.itemType == Enum.SpellBookItemType.Spell and not info.isPassive then
                info.index = offset
                info.bookType = bookType
                info.skillLineIndex = sl
                category:Insert(info)
            end
        end
    end
    return dp
end
