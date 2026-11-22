local addonName, addon = ...
local DEFAULT_SUBJECT = "Goblin Co. Intra-Company Transfert"
local loader = CreateFrame("Frame")
local initialized = false
local mailHooked = false

addon.DEFAULT_SUBJECT = DEFAULT_SUBJECT

local function ValidSubject(text)
    return type(text) == "string" and text:find("%S")
end

function addon.GetSubject()
    if initialized then
        return ForeverMailFixDB.subject
    end
    return DEFAULT_SUBJECT
end

local function FillSubject()
    local sendFrame = _G.SendMailFrame
    local subject = _G.SendMailSubjectEditBox

    if sendFrame and sendFrame:IsShown() and subject and subject:GetText() == "" then
        subject:SetText(addon.GetSubject())
    end
end

function addon.SetSubject(text)
    ForeverMailFixDB.subject = ValidSubject(text) and text or DEFAULT_SUBJECT
    FillSubject()
end

local function InstallHooks()
    local sendFrame = _G.SendMailFrame
    if mailHooked or not sendFrame or not _G.SendMailSubjectEditBox then
        return
    end

    sendFrame:HookScript("OnShow", FillSubject)

    -- Refill after Blizzard clears a successfully sent message.
    if type(_G.SendMailFrame_Reset) == "function" then
        hooksecurefunc("SendMailFrame_Reset", FillSubject)
    end

    mailHooked = true
    FillSubject()
end

-- SavedVariables are ready at this addon's ADDON_LOADED event.
-- The mail interface may load later; wait for its actual frames.
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        if type(ForeverMailFixDB) ~= "table" then
            ForeverMailFixDB = {}
        end
        if not ValidSubject(ForeverMailFixDB.subject) then
            ForeverMailFixDB.subject = DEFAULT_SUBJECT
        end
        initialized = true
    end

    if initialized then
        local optionsReady = addon.CreateOptions()
        InstallHooks()
        if optionsReady and mailHooked then
            self:UnregisterEvent("ADDON_LOADED")
        end
    end
end)
