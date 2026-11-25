local _, M = ...
local window, launcher, routes, setup, status, manifest, scroll, sendButton
local roleMenu, ruleMenu, address, floor, itemInput, auto, withMats, rosterLine, clearButton
local routeButtons = {}
local confirmation

local function label(parent, x, y, width, font, value)
    local t = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    t:SetPoint("TOPLEFT", x, -y)
    t:SetWidth(width)
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    t:SetText(value or "")
    return t
end

local function button(parent, caption, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT", x, -y)
    b:SetSize(width, 24)
    b:SetText(caption)
    b:SetScript("OnClick", callback)
    return b
end

local function edit(parent, x, y, width, max)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetPoint("TOPLEFT", x, -y)
    e:SetSize(width, 22)
    e:SetMaxLetters(max)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    return e
end

local function check(parent, x, y, caption, callback)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", x, -y)
    c:SetSize(25, 25)
    label(parent, x + 29, y + 5, 309, "GameFontHighlightSmall", caption)
    c:SetScript("OnClick", function(self) callback(self:GetChecked() == true) end)
    return c
end

local function selector(parent, x, y, width, choices, onChange)
    local s = {choice = choices[1][1]}
    local function choose(entry)
        s.choice = entry[1]
        s.button:SetText(entry[2] .. "  v")
        confirmation = nil
        if onChange then onChange() end
    end
    if MenuUtil and MenuUtil.CreateContextMenu then
        s.button = button(parent, "", x, y, width, function(owner)
            MenuUtil.CreateContextMenu(owner, function(_, menu)
                for _, entry in ipairs(choices) do
                    local pick = entry
                    menu:CreateButton(pick[2], function() choose(pick) end)
                end
            end)
        end)
    else
        local index = 1
        s.button = button(parent, "", x, y, width, function()
            index = index % #choices + 1
            choose(choices[index])
        end)
    end
    s.button:SetText(choices[1][2] .. "  v")
    return s
end

local function settings()
    M.cancelAuto()
    if M.busy() then M.say("Finish or stop the queue before editing Setup."); return end
    M.preview, confirmation = nil, nil
    routes:Hide()
    setup:Show()
    local scope, prefs, guid = M.context()
    if not scope then return end
    address:SetText(M.currentName() or "Native name unavailable")
    floor:SetText(tostring(M.threshold(scope)))
    auto:SetChecked(prefs.auto ~= false)
    withMats:SetChecked(prefs.withMats == true)
    M.refresh()
end

local function routesPage()
    confirmation = nil
    setup:Hide()
    routes:Show()
    M.refresh()
end

local function saveRole()
    local scope, _, guid = M.context()
    if not scope then return end
    local role, name = roleMenu.choice, M.currentName()
    local existing = M.member(scope, role)
    if not name then return M.say("The client has not supplied a full name. Open Setup again outside combat.") end
    local key = role .. "/" .. name
    if confirmation ~= key then
        confirmation = key
        local replace = existing and (" (currently " .. existing.name .. ")") or ""
        return M.say("Click Register again to confirm " .. M.labels[role] .. " = " .. name .. replace .. ".")
    end
    confirmation = nil
    local ok, why = M.enroll(scope, guid, role, name)
    M.say(ok and ("Registered " .. name .. " for " .. M.labels[role] .. ".") or why)
end

local function removeRole()
    local scope, _, guid = M.context()
    if not scope then return end
    local role = roleMenu.choice
    local member = M.member(scope, role)
    if not member or member.guid ~= guid then return M.say("Only the enrolled character can remove its own role.") end
    local key = "remove/" .. role
    if confirmation ~= key then confirmation = key; return M.say("Click Remove again to release " .. M.labels[role] .. ".") end
    confirmation, scope.roles[role] = nil, nil
    M.say("Role removed.")
end

local function saveRule()
    local scope = M.context()
    if not scope then return end
    local text = M.trim(itemInput:GetText())
    local id = tonumber(text:match("^%d+$") or text:match("item:(%d+)"))
    if not id or id < 1 or id > 2147483647 then return M.say("Enter a numeric item ID or paste an item link.") end
    local role = ruleMenu.choice
    scope.rules[id] = role ~= "default" and role or nil
    itemInput:ClearFocus()
    M.say(("Item %d now uses %s."):format(id, M.labels[role] or "automatic routing"))
end

local function clearHold()
    local _, prefs = M.context()
    if not prefs or not prefs.pending or M.busy() then return end
    if confirmation ~= "clear" then confirmation = "clear"; return M.say("Check the recipient and your inventory first. Click again to clear the hold.") end
    prefs.pending, confirmation = nil, nil
    M.say("Hold cleared. Choose a fresh review when ready.")
end

local function makeSetup(parent)
    label(parent, 2, 0, 350, "GameFontNormal", "Enroll the character you are playing")
    label(parent, 2, 20, 350, "GameFontHighlightSmall", "Forever supplies your mailing name and surname.")
    roleMenu = selector(parent, 0, 41, 126, M.roles, function() M.refresh() end)
    address = label(parent, 138, 46, 208, "GameFontHighlight")
    button(parent, "Register", 0, 72, 88, saveRole)
    button(parent, "Remove", 92, 72, 78, removeRole)
    rosterLine = label(parent, 2, 106, 350, "GameFontHighlightSmall")
    label(parent, 2, 143, 350, "GameFontNormal", "Profession alt at mailbox open")
    auto = check(parent, 0, 163, "Return surplus gold after 8 seconds", function(v)
        local _, p = M.context(); if p then p.auto = v end
    end)
    withMats = check(parent, 0, 188, "Include bag materials with automatic gold", function(v)
        local _, p = M.context(); if p then p.withMats = v end
    end)
    label(parent, 2, 224, 350, "GameFontNormal", "Auction floor per item (gold)")
    floor = edit(parent, 6, 246, 78, 7)
    button(parent, "Save floor", 98, 244, 94, function()
        local scope = M.context()
        local n = tonumber(floor:GetText())
        if not scope or not n or n ~= math.floor(n) or n < 1 or n > 1000000 then return M.say("Use a whole number from 1 to 1,000,000 gold.") end
        scope.floorGold = n; floor:ClearFocus(); M.say("Auction floor saved.")
    end)
    label(parent, 2, 281, 350, "GameFontNormal", "Item rule (item ID or link)")
    itemInput = edit(parent, 6, 305, 92, 255)
    local choices = {{"default", "Automatic"}, {"keep", "Keep in bags"}}
    for i = 2, #M.roles do choices[#choices + 1] = M.roles[i] end
    ruleMenu = selector(parent, 111, 302, 142, choices)
    button(parent, "Save rule", 258, 302, 88, saveRule)
    clearButton = button(parent, "Clear delivery hold", 0, 337, 156, clearHold)
    label(parent, 2, 376, 350, "GameFontHighlightSmall", "Made with <3 by Mini Il - Forever - PvE")
end

function M.refresh()
    if not window or not window:IsShown() then return end
    status:SetText(M.status or "")
    local scope, prefs, guid = M.context()
    if not scope then sendButton:Disable(); return end
    if setup:IsShown() then
        local assigned = M.member(scope, roleMenu.choice)
        rosterLine:SetText(M.labels[roleMenu.choice] .. "  /  " .. (assigned and assigned.name or "Unassigned"))
        clearButton:SetShown(prefs.pending and true or false)
        return
    end
    local main = M.member(scope, "main")
    local isMain = main and main.guid == guid
    local alt = main and not isMain and M.isProfession(scope, guid)
    for mode, b in pairs(routeButtons) do
        local eligible = ((mode == "route" or mode == "auction") and isMain) or ((mode == "materials" or mode == "gold") and alt)
        b:SetEnabled(eligible and M.open and not M.busy() and not prefs.pending or false)
    end
    local plan, lines = M.preview, {}
    if plan then
        for i, parcel in ipairs(plan.parcels) do
            lines[#lines + 1] = ("|cffffd58a%d. %s|r"):format(i, parcel.name)
            for _, it in ipairs(parcel.items) do lines[#lines + 1] = ("    %s  x%d"):format(it.name, it.count) end
            if plan.sweep and i == #plan.parcels then lines[#lines + 1] = "    Surplus gold after postage and 1g reserve" end
        end
        if #plan.held > 0 then lines[#lines + 1] = "|cffc7bcabHeld in bags|r" end
        for _, held in ipairs(plan.held) do lines[#lines + 1] = held.item.name .. "  /  " .. held.reason end
    else
        lines[1] = "Address book"
        for _, role in ipairs(M.roles) do
            local member = M.member(scope, role[1])
            if member then lines[#lines + 1] = role[2] .. "   " .. member.name end
        end
        if #lines == 1 then lines[2] = "Open Setup on your main, then on each alt you want to enroll." end
    end
    manifest:SetText(table.concat(lines, "\n"))
    manifest:GetParent():SetHeight(math.max(20, manifest:GetStringHeight() + 6))
    sendButton:SetEnabled(plan and #plan.parcels > 0 and not M.busy() or false)
end

local function makeWindow()
    if window then return end
    window = CreateFrame("Frame", "ForeverGoblinMailerPanel", UIParent, "BackdropTemplate")
    window:SetSize(384, 536)
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize=18, insets={left=4,right=4,top=4,bottom=4}})
    window:Hide()
    label(window, 16, 15, 320, "GameFontNormalLarge", "Forever Goblin Mailer")
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() window:Hide() end)
    button(window, "Dispatch", 14, 42, 99, routesPage)
    button(window, "Setup", 116, 42, 84, settings)
    button(window, "Stop", 203, 42, 72, function() M.cancel() end)
    status = label(window, 16, 77, 349, "GameFontHighlightSmall")
    routes, setup = CreateFrame("Frame", nil, window), CreateFrame("Frame", nil, window)
    for _, p in ipairs({routes, setup}) do p:SetPoint("TOPLEFT", 16, -118); p:SetSize(352, 398) end
    setup:Hide()
    local actions = {{"route","Route my bags"}, {"auction","Auction stock only"}, {"materials","Materials to main"}, {"gold","Gold to main"}}
    for i, entry in ipairs(actions) do
        local mode = entry[1]
        routeButtons[mode] = button(routes, entry[2], (i - 1) % 2 * 175, math.floor((i - 1) / 2) * 29, 171, function()
            local _, prefs = M.context()
            M.review(mode, mode == "materials" and prefs and prefs.auto ~= false)
            scroll:SetVerticalScroll(0)
        end)
    end
    scroll = CreateFrame("ScrollFrame", nil, routes, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 2, -69)
    scroll:SetSize(314, 278)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(313, 30)
    manifest = label(content, 0, 0, 311, "GameFontHighlightSmall")
    scroll:SetScrollChild(content)
    sendButton = button(routes, "Send reviewed parcels", 0, 362, 196, M.dispatch)
    makeSetup(setup)
end

local function show(setupFirst)
    if InCombatLockdown() then return end
    makeWindow()
    window:ClearAllPoints()
    if M.open and MailFrame and MailFrame:IsVisible() then window:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 5, 0)
    else window:SetPoint("CENTER") end
    window:Show()
    if setupFirst then settings() else routesPage() end
end

local function addLauncher()
    if launcher or not MailFrame then return end
    launcher = CreateFrame("Button", nil, MailFrame, "UIPanelButtonTemplate")
    launcher:SetPoint("TOPLEFT", MailFrame, "BOTTOMLEFT", 197, 2)
    launcher:SetSize(128, 24)
    launcher:SetText("Goblin Mailer")
    launcher:SetScript("OnClick", function() if window and window:IsShown() then window:Hide() else show(false) end end)
end

local events = CreateFrame("Frame")
for _, event in ipairs({"MAIL_SHOW","MAIL_CLOSED","MAIL_SEND_SUCCESS","MAIL_FAILED","MAIL_LOCK_SEND_ITEMS","PLAYER_REGEN_DISABLED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    M.event(event)
    if event == "MAIL_SHOW" then
        C_Timer.After(0, function() if M.open then addLauncher(); show(false) end end)
    elseif (event == "MAIL_CLOSED" or event == "PLAYER_REGEN_DISABLED") and window then window:Hide() end
end)
SLASH_FOREVERGOBLINMAILER1 = "/fgm"
SLASH_FOREVERGOBLINMAILER2 = "/goblinmail"
SlashCmdList.FOREVERGOBLINMAILER = function() show(true) end
