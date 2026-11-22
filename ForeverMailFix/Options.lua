local _, addon = ...
local panel, subjectBox, status, category
local legacyRegistered = false

local function RefreshOptions()
    subjectBox:SetText(addon.GetSubject())
    subjectBox:ClearFocus()
    status:SetText("Press Enter or click Save. A blank value restores the original default.")
end

local function SaveSubject(text)
    addon.SetSubject(text)
    subjectBox:SetText(addon.GetSubject())
    subjectBox:ClearFocus()
    status:SetText("Saved. Applies to the next empty mail subject.")
end

function addon.CreateOptions()
    if category or legacyRegistered then
        return true
    end

    if not panel then
        panel = CreateFrame("Frame")
        panel.name = "Forever Mail Fix"
        panel:SetSize(650, 320)

        local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 20, -20)
        title:SetText(panel.name)

        local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        description:SetPoint("TOPLEFT", 20, -52)
        description:SetPoint("TOPRIGHT", -20, -52)
        description:SetJustifyH("LEFT")
        description:SetText("Choose the subject used for new mail. Existing subjects stay unchanged.\nThis setting is shared across your characters.")

        local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20, -100)
        label:SetText("Default subject (up to 64 characters)")

        subjectBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        subjectBox:SetPoint("TOPLEFT", 25, -122)
        subjectBox:SetPoint("TOPRIGHT", -25, -122)
        subjectBox:SetHeight(30)
        subjectBox:SetAutoFocus(false)
        subjectBox:SetMaxLetters(64)
        subjectBox:SetScript("OnEnterPressed", function(self) SaveSubject(self:GetText()) end)
        subjectBox:SetScript("OnEscapePressed", function(self)
            self:SetText(addon.GetSubject())
            self:ClearFocus()
        end)

        local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        save:SetPoint("TOPLEFT", 20, -166)
        save:SetSize(100, 26)
        save:SetText("Save")
        save:SetScript("OnClick", function() SaveSubject(subjectBox:GetText()) end)

        local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        reset:SetPoint("LEFT", save, "RIGHT", 10, 0)
        reset:SetSize(160, 26)
        reset:SetText("Restore Default")
        reset:SetScript("OnClick", function() SaveSubject(addon.DEFAULT_SUBJECT) end)

        status = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        status:SetPoint("TOPLEFT", 20, -204)
        status:SetPoint("TOPRIGHT", -20, -204)
        status:SetJustifyH("LEFT")

        local credit = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        credit:SetPoint("TOPLEFT", 20, -254)
        credit:SetPoint("TOPRIGHT", -20, -254)
        credit:SetJustifyH("LEFT")
        credit:SetText("Made with <3 by Mini Il - Forever - PvE")

        panel:SetScript("OnShow", RefreshOptions)
        RefreshOptions()
    end

    local settings = _G.Settings
    if settings and type(settings.RegisterCanvasLayoutCategory) == "function"
        and type(settings.RegisterAddOnCategory) == "function" then
        category = settings.RegisterCanvasLayoutCategory(panel, panel.name)
        settings.RegisterAddOnCategory(category)
    elseif type(InterfaceOptions_AddCategory) == "function" then
        InterfaceOptions_AddCategory(panel)
        legacyRegistered = true
    end

    return category ~= nil or legacyRegistered
end

SLASH_FOREVERMAILFIX1 = "/fmf"
SLASH_FOREVERMAILFIX2 = "/forevermailfix"
SlashCmdList.FOREVERMAILFIX = function()
    if InCombatLockdown() then
        print("Forever Mail Fix: open the options after combat.")
        return
    end

    addon.CreateOptions()
    if category and _G.Settings and type(Settings.OpenToCategory) == "function" then
        Settings.OpenToCategory(category:GetID())
    elseif legacyRegistered and type(InterfaceOptionsFrame_OpenToCategory) == "function" then
        InterfaceOptionsFrame_OpenToCategory(panel)
    else
        print("Forever Mail Fix: the game's AddOns settings are not available yet.")
    end
end
