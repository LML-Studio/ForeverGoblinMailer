-- Run from the repository root with Lua 5.1. --probe tests desired edge behavior.
local session = dofile("tests/fixture.lua")
local original = "Goblin Co. Intra-Company Transfert"
local checks = {}
local function test(name, fn) table.insert(checks, {name, fn}) end
local function equal(actual, expected)
    if actual ~= expected then
        error(string.format("expected %q, observed %q", tostring(expected), tostring(actual)), 2)
    end
end
local function save(s, text)
    s.editor:SetText(text)
    s.buttons.Save.scripts.OnClick(s.buttons.Save)
end

if arg and arg[1] == "--probe" then
    test("A hidden parent keeps its empty draft untouched when saving settings", function()
        local s = session()
        s.api.SendMailFrame:show()
        s.api.MailFrame.shown = false
        s.api.SendMailSubjectEditBox:SetText("")  -- Native close clears the draft.
        assert(s.api.SendMailFrame:IsShown() and not s.api.SendMailFrame:IsVisible())
        save(s, "Ore deliveries")
        equal(s.api.SendMailSubjectEditBox:GetText(), "")
    end)
    test("A pasted nonbreaking space alone restores the default", function()
        local s = session()
        save(s, string.char(194, 160))  -- U+00A0 in UTF-8
        equal(s.api.ForeverMailFixDB.subject, original)
    end)
    test("A restored oversized subject reaches the native field within the 64-character budget", function()
        local s = session({saved = {subject = string.rep("A", 80)}})
        s.api.SendMailFrame:show()
        -- The fixture records the value passed to SetText before any renderer truncation.
        equal(#s.api.SendMailSubjectEditBox.text <= 64, true)
    end)
else
    test("First open prefills before the first attachment", function()
        local s = session()
        equal(s.api.SendMailSubjectEditBox.text, "")
        s.api.SendMailFrame:show()
        equal(s.api.SendMailSubjectEditBox.text, original)
    end)
    test("Typed and reply subjects survive reopening", function()
        local s = session()
        for _, draft in ipairs({"Bank materials", "Re: Thank you"}) do
            s.api.SendMailSubjectEditBox:SetText(draft)
            s.api.SendMailFrame:show()
            equal(s.api.SendMailSubjectEditBox.text, draft)
        end
    end)
    test("Saving changes the next empty composition and preserves a current draft", function()
        local s = session()
        s.api.SendMailFrame:show()
        s.api.SendMailSubjectEditBox:SetText("One-off gift")
        save(s, "Guild supplies")
        equal(s.api.SendMailSubjectEditBox.text, "One-off gift")
        s.api.SendMailFrame_Reset()
        equal(s.nativeResets, 1)
        equal(s.api.SendMailSubjectEditBox.text, "Guild supplies")
    end)
    test("Locally hidden send tab stays empty after a reset", function()
        local s = session()
        s.api.SendMailFrame_Reset()
        equal(s.api.SendMailSubjectEditBox.text, "")
    end)
    test("Settings and mail can arrive after the addon", function()
        local s = session({settings = false, mail = false, defer = true})
        s:loaded("Other")
        equal(s.api.ForeverMailFixDB, nil)
        s:loaded("ForeverMailFix")
        s:settings()
        s:loaded("Settings")
        s:makeMail()
        s:loaded("Mail")
        s:loaded("Other")
        equal(s.registrations, 1)
        s.api.SendMailFrame:show()
        equal(s.api.SendMailSubjectEditBox.text, original)
        equal(s.frames[1].events.ADDON_LOADED, nil)
    end)
    test("An absent native reset helper still permits first composition", function()
        local s = session({reset = false})
        s.api.SendMailFrame:show()
        equal(s.api.SendMailSubjectEditBox.text, original)
    end)
    test("Saved Unicode default survives a fresh Lua session", function()
        local custom = "Herbes d’été"
        local first = session()
        save(first, custom)
        local nextLogin = session({saved = {subject = first.api.ForeverMailFixDB.subject, keep = 7}})
        nextLogin.api.SendMailFrame:show()
        equal(nextLogin.editor.text, custom)
        equal(nextLogin.api.SendMailSubjectEditBox.text, custom)
        equal(nextLogin.api.ForeverMailFixDB.keep, 7)
    end)
    test("First paint includes the current setting, credit, and native character-limit request", function()
        local s = session()
        equal(s.editor.text, original)
        equal(s.editor.maxLetters, 64)
        for _, label in ipairs(s.panel.regions) do
            if label.text == "Made with <3 by Mini Il - Forever - PvE" then return end
        end
        error("missing options credit")
    end)
    test("Enter saves, Escape cancels, Restore Default takes effect", function()
        local s = session()
        s.editor:SetText("Craft orders")
        s.editor.scripts.OnEnterPressed(s.editor)
        equal(s.api.ForeverMailFixDB.subject, "Craft orders")
        s.editor:SetText("Discard")
        s.editor.scripts.OnEscapePressed(s.editor)
        equal(s.editor.text, "Craft orders")
        s.buttons["Restore Default"].scripts.OnClick()
        equal(s.api.ForeverMailFixDB.subject, original)
    end)
    test("Blank or invalid saved values recover", function()
        for _, saved in ipairs({12, {subject = 42}, {subject = "   "}, {}}) do
            local s = session({saved = saved})
            equal(s.api.ForeverMailFixDB.subject, original)
            save(s, "  ")
            equal(s.api.ForeverMailFixDB.subject, original)
        end
    end)
    test("Settings opens by category and defers the slash route during combat", function()
        local s = session()
        equal(s.api.SLASH_FOREVERMAILFIX1, "/fmf")
        equal(s.api.SLASH_FOREVERMAILFIX2, "/forevermailfix")
        s.combat = true
        s.api.SlashCmdList.FOREVERMAILFIX()
        equal(s.opened, nil)
        s.combat = false
        s.api.SlashCmdList.FOREVERMAILFIX()
        equal(s.opened, 41)
    end)
    test("Legacy settings routes to the registered panel", function()
        local s = session({legacy = true})
        s.api.SlashCmdList.FOREVERMAILFIX()
        equal(s.opened, s.panel)
    end)
end

local failures = 0
for _, row in ipairs(checks) do
    local ok, problem = pcall(row[2])
    if not ok then failures = failures + 1 end
    print((ok and "PASS  " or "FAIL  ") .. row[1])
    if not ok then print("      " .. problem) end
end
print(string.format("%d passed, %d failed", #checks - failures, failures))
if failures > 0 then os.exit(1) end
