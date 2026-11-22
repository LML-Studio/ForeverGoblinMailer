-- Small WoW UI boundary for Lua 5.1. Never opens a client or reads player saves.
local function newSession(config)
    config = config or {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    local sim = { api = env, namespace = {}, buttons = {}, frames = {}, registrations = 0 }
    local function widget(parent)
        local frame = { parent = parent, shown = true, text = "", scripts = {}, events = {}, regions = {} }
        function frame:SetPoint() end
        function frame:SetSize() end
        function frame:SetHeight() end
        function frame:SetJustifyH() end
        function frame:SetAutoFocus() end
        function frame:ClearFocus() end
        function frame:SetMaxLetters(value) self.maxLetters = value end
        function frame:GetText() return self.text end
        function frame:SetText(value)
            self.text = value
            if self.kind == "Button" then sim.buttons[value] = self end
        end
        function frame:IsShown() return self.shown end
        function frame:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(event, action) self.scripts[event] = action end
        function frame:HookScript(event, action)
            local previous = self.scripts[event]
            self.scripts[event] = function(...)
                if previous then previous(...) end
                action(...)
            end
        end
        function frame:show()
            self.shown = true
            if self:IsVisible() and self.scripts.OnShow then self.scripts.OnShow(self) end
        end
        function frame:CreateFontString()
            local label = widget(self)
            table.insert(self.regions, label)
            return label
        end
        return frame
    end

    function env.CreateFrame(kind, name, parent)
        local frame = widget(parent)
        table.insert(sim.frames, frame)
        frame.kind = kind
        if kind == "EditBox" then sim.editor = frame end
        return frame
    end
    function env.hooksecurefunc(name, after)
        local before = assert(env[name])
        env[name] = function(...)
            before(...)
            after(...)
        end
    end
    env.InCombatLockdown = function() return sim.combat end
    env.print = function(message) sim.message = message end
    env.SlashCmdList = {}
    function sim:makeMail()
        env.MailFrame = widget()
        env.SendMailFrame = widget(env.MailFrame)
        env.SendMailFrame.shown = false
        env.SendMailSubjectEditBox = widget(env.SendMailFrame)
        if config.reset ~= false then
            env.SendMailFrame_Reset = function()
                self.nativeResets = (self.nativeResets or 0) + 1
                env.SendMailSubjectEditBox:SetText("")
            end
        end
    end
    function sim:settings(legacy)
        local function register(panel)
            self.panel = panel
            self.registrations = self.registrations + 1
        end
        if legacy then
            env.InterfaceOptions_AddCategory = register
            env.InterfaceOptionsFrame_OpenToCategory = function(panel) self.opened = panel end
        else
            env.Settings = {
                RegisterCanvasLayoutCategory = function(panel, title)
                    assert(title == "Forever Mail Fix")
                    register(panel)
                    return { GetID = function() return 41 end }
                end,
                RegisterAddOnCategory = function(category) assert(category:GetID() == 41) end,
                OpenToCategory = function(id) self.opened = id end,
            }
        end
    end
    function sim:loaded(name)
        for _, frame in ipairs(self.frames) do
            if frame.events.ADDON_LOADED then
                frame.scripts.OnEvent(frame, "ADDON_LOADED", name)
            end
        end
    end
    if config.mail ~= false then sim:makeMail() end
    if config.settings ~= false then sim:settings(config.legacy) end
    -- Execute only the two release source files in their declared TOC order.
    for _, name in ipairs({"ForeverMailFix.lua", "Options.lua"}) do
        local chunk = assert(loadfile("ForeverMailFix/" .. name))
        setfenv(chunk, env)("ForeverMailFix", sim.namespace)
    end
    env.ForeverMailFixDB = config.saved
    if not config.defer then sim:loaded("ForeverMailFix") end
    return sim
end

return newSession
