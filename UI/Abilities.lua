local addonName, addon = ...

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

    self.Title:SetText("Abilities")

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
            local font = data.isOffSpec and GameFontWhite or GameFontNormal
            if data.numSpellBookItems then
                factory("ABAAbilityHeaderTemplate",
                    function (button)
                        button.Text:SetTextColor(font:GetTextColor())
                        button:SetText(data.name)
                        node:SetCollapsed(not data.expanded)
                        button:SetExpanded(data.expanded)
                        button:SetScript("OnClick",
                            function ()
                                node:ToggleCollapsed()
                                data.expanded = not node:IsCollapsed()
                                button:SetExpanded(data.expanded)
                            end)
                    end)
            else
                factory("ABAAbilityItemTemplate",
                    function (button)
                        local isSelected = self.selectionBehavior:IsSelected(button)
                        button.SelectedTexture:SetShown(isSelected)
                        button.Icon:SetTexture(data.iconID)
                        button.Icon:SetDesaturated(data.isOffSpec)
                        button.Icon:SetScript('OnEnter',
                            function (f)
                                GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
                                GameTooltip:SetSpellByID(data.actionID)
                                GameTooltip:Show()
                            end)
                        button.Icon:SetScript('OnLeave', GameTooltip_Hide)
                        button.Name:SetTextColor(font:GetTextColor())
                        button.Name:SetText(data.name)
                        button:SetAlpha(data.isOffSpec and 0.67 or 1)
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

    local function ShowStripe(f, isShown) f.Stripe:SetShown(isShown) end

    view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("ABASpellItemTemplate", Initializer)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.Settings.DefaultScrollBox, self.Settings.DefaultScrollBar, view)
    ScrollUtil.RegisterAlternateRowBehavior(self.Settings.DefaultScrollBox, ShowStripe)

    view = CreateScrollBoxListLinearView()
    view:SetElementInitializer("ABASpellItemDeleteTemplate", Initializer)
    ScrollUtil.InitScrollBoxListWithScrollBar(self.Settings.ExtraScrollBox, self.Settings.ExtraScrollBar, view)
    ScrollUtil.RegisterAlternateRowBehavior(self.Settings.ExtraScrollBox, ShowStripe)

    self.selectionBehavior = ScrollUtil.AddSelectionBehavior(self.ScrollBox)
    self.selectionBehavior:RegisterCallback(SelectionBehaviorMixin.Event.OnSelectionChanged,
        function (_, node, isSelected)
            local button = self.ScrollBox:FindFrame(node)
            if button then
                button.SelectedTexture:SetShown(isSelected)
            end
            if isSelected then
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
            local enable = b:GetChecked() == true
            addon.db.profile.abilities[self.spellID].enableDefault = enable
            addon.OnOptionsChanged()
        end)

    self.Settings.AddSpell:SetScript('OnTextChanged',
        function (editBox)
            self:CheckAddSpell(editBox:GetText())
        end)

    self.category = Settings.RegisterCanvasLayoutSubcategory(addon.category, self, "Abilities")
end

function addon.AbilitiesPanelMixin:GetAddSpellID()
    local spellIdentifier = self.Settings.AddSpell:GetText()
    local info = C_Spell.GetSpellInfo(spellIdentifier or 0)
    if info then return info.spellID end
end

function addon.AbilitiesPanelMixin:CheckAddSpell()
    local spellID = self:GetAddSpellID()
    self.Settings.AddButton:SetEnabled(spellID ~= nil)
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
            self.Settings.SpellID:SetText('Spell ID: ' .. spell:GetSpellID())
        end)

    local spellIDs = addon.GetLinkedSpellIDs(self.spellID, true)
    local dp = CreateDataProvider(GetKeysArray(spellIDs))
    self.Settings.DefaultScrollBox:SetDataProvider(dp)

    dp = CreateDataProvider(GetKeysArray(conf.linkedSpellIDs))
    self.Settings.ExtraScrollBox:SetDataProvider(dp)

    self.Settings.AddSpell:SetText("")
    self.Settings.AddButton:SetScript('OnClick',
        function ()
            local spellID = self:GetAddSpellID()
            if spellID then
                addon.db.profile.abilities[self.spellID].linkedSpellIDs[spellID] = true
                self:RefreshAbility()
            end
        end)
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
        slInfo.isOffSpec = slInfo.offSpecID ~= nil
        slInfo.expanded = sl > 1 and not slInfo.isOffSpec
        local category = dp:Insert(slInfo)
        for itemIndex = 1, slInfo.numSpellBookItems do
            local offset = slInfo.itemIndexOffset + itemIndex
            local info = C_SpellBook.GetSpellBookItemInfo(offset, bookType)
            if info.itemType == Enum.SpellBookItemType.Spell and not info.isPassive then
                info.skillLineIndex = sl
                category:Insert(info)
            elseif sl > 1 and info.itemType == Enum.SpellBookItemType.Flyout then
                local _, _, numSlots = GetFlyoutInfo(info.actionID)
                for i = 1, numSlots do
                    local spellID, overrideSpellID, isKnown, name = GetFlyoutSlotInfo(info.actionID, i)
                    local iconID = C_Spell.GetSpellTexture(spellID)
                    if isKnown then
                        local data = {
                            skillLineIndex = sl,
                            actionID = spellID,
                            spellID = overrideSpellID,
                            isOffspec = false,
                            name = name,
                            iconID = iconID
                        }
                        category:Insert(data)
                    end
                end
            end
        end
    end
    return dp
end
