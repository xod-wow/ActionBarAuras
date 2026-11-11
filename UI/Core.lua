local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnTitle(addonName)

addon.CorePanelMixin = {}

function addon.CorePanelMixin:OpenColorPicker(owner, colorTable)
    local info = {
        r = colorTable.r,
        g = colorTable.g,
        b = colorTable.b,
        opacity = colorTable.a,
        hasOpacity = true,
    }
    info.swatchFunc =
        function ()
            colorTable.r, colorTable.g, colorTable.b = ColorPickerFrame:GetColorRGB()
            colorTable.a = ColorPickerFrame:GetColorAlpha()
            self:Setup()
            addon.OnOptionsChanged()
        end
    info.cancelFunc =
        function ()
            colorTable.r, colorTable.g, colorTable.b, colorTable.a = ColorPickerFrame:GetPreviousValues()
            self:Setup()
            addon.OnOptionsChanged()
        end
    ColorPickerFrame:SetupColorPickerAndShow(info)
end

function addon.CorePanelMixin:Setup()
    local p = addon.db.profile

    self:UpdateDemo()

    local function SetStacksAnchor(point, x, y)
        p.stacks.point = point
        p.stacks.x = x
        p.stacks.y = y
        self:UpdateDemo()
        addon.OnOptionsChanged()
    end

    local function SetStacksFont(fontFile, fontSize, fontFlags)
        p.stacks.fontFile = fontFile
        p.stacks.fontSize = fontSize
        p.stacks.fontFlags = fontFlags
        self:UpdateDemo()
        addon.OnOptionsChanged()
    end

    self.StacksEnable:SetChecked(p.stacks.enable)
    self.StacksEnable:SetScript('OnClick',
        function (checkButton)
            p.stacks.enable = checkButton:GetChecked()
            self:UpdateDemo()
            addon.OnOptionsChanged()
        end)

    self.StacksFont:Setup(SetStacksFont, p.stacks.fontFile, p.stacks.fontSize, p.stacks.fontFlags)
    self.StacksAnchor:Setup(SetStacksAnchor, p.stacks.point, p.stacks.x, p.stacks.y)

    local function SetDurationAnchor(point, x, y)
        p.duration.point = point
        p.duration.x = x
        p.duration.y = y
        self:UpdateDemo()
        addon.OnOptionsChanged()
    end

    local function SetDurationFont(fontFile, fontSize, fontFlags)
        p.duration.fontFile = fontFile
        p.duration.fontSize = fontSize
        p.duration.fontFlags = fontFlags
        self:UpdateDemo()
        addon.OnOptionsChanged()
    end

    self.DurationEnable:SetChecked(p.duration.enable)
    self.DurationEnable:SetScript('OnClick',
        function (checkButton)
            p.duration.enable = checkButton:GetChecked()
            self:UpdateDemo()
            addon.OnOptionsChanged()
        end)

    self.DurationFont:Setup(SetDurationFont, p.duration.fontFile, p.duration.fontSize, p.duration.fontFlags)
    self.DurationAnchor:Setup(SetDurationAnchor, p.duration.point, p.duration.x, p.duration.y)

    self.DurationShadow:SetChecked(p.duration.shadow)
    self.DurationShadow:SetScript("OnClick", function(checkButton)
        p.duration.shadow = checkButton:GetChecked()
        self:UpdateDemo()
        addon.OnOptionsChanged()
    end)

    self.OverlayEnable:SetChecked(p.overlay.enable)
    self.OverlayEnable:SetScript('OnClick',
        function (checkButton)
            p.overlay.enable = checkButton:GetChecked()
            self:UpdateDemo()
            addon.OnOptionsChanged()
        end)

    -- Possible textures?
    -- Round: talents-node-choiceflyout-circle-sheenmask

    self.OverlayTexture:SetText(p.overlay.texture)
    self.OverlayTexture:SetScript('OnEnterPressed',
        function (editBox)
            local tex = editBox:GetText()
            if tex == "" then
                tex = addon.defaults.profile.overlay.texture
                editBox:SetText(tex)
            end
            p.overlay.texture = tex
            self:UpdateDemo()
            addon.OnOptionsChanged()
        end)

    local buff = p.overlay.color.buff
    self.BuffColor.Color:SetVertexColor(buff.r, buff.g, buff.b, buff.a)
    self.BuffColor.Text:SetTextColor(buff.r, buff.g, buff.b)
    self.BuffColor:SetScript('OnClick', function (button) self:OpenColorPicker(button, buff) end)
    local debuff = p.overlay.color.debuff
    self.DebuffColor.Color:SetVertexColor(debuff.r, debuff.g, debuff.b, debuff.a)
    self.DebuffColor.Text:SetTextColor(debuff.r, debuff.g, debuff.b)
    self.DebuffColor:SetScript('OnClick', function (button) self:OpenColorPicker(button, debuff) end)
end

function addon.CorePanelMixin:UpdateDemo()
    self.DemoBuff:SetTexture(135992)
    self.DemoBuffOverlay.durationText:SetText("2.6")
    self.DemoBuffOverlay.stacksText:SetText("3")
    self.DemoBuffOverlay:Style()

    self.DemoDebuff:SetTexture(136118)
    self.DemoDebuffOverlay.durationText:SetText("15.1")
    self.DemoDebuffOverlay.stacksText:SetText("7")
    self.DemoDebuffOverlay:Style()
end

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
            return true
        end
    _G["SLASH_"..addonName.."1"] = "/aba"
end

function addon.CorePanelMixin:OnShow()
    self:Setup()
end
