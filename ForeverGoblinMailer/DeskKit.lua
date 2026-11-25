local _, M = ...
local U = {page="desk", state={}, offsets={}, pools={}, used={}, gap=8}
M.desk = U

U.icons = {main=133471, auction=133784, tailor=136249, enchanter=136244, alchemist=136240,
    smith=136241, engineer=136243, leatherworker=136247, cook=133971, miner=136248, herbalist=136246,
    skinner=134366, fisher=136245, firstaid=133678, keep=133639, default=134328,
    desk=133472, book=133741, rules=134939, returns=133785, activity=134376, look=134063,
    route=133639, materials=132889, gold=133784, parcel=134140, missing=134400}

local function rgb(hex)
    return {tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255, tonumber(hex:sub(5,6),16)/255}
end
local palettes = {
    parchment={paper="E8DCC1",card="F6EED9",inset="DDCFB0",line="B5A581",ink="243A32",sub="46564A",accent="155D48",selected="C9DFC8",hover="DFE8CF",warn="87502E"},
    midnight={paper="172722",card="21372F",inset="11231F",line="475D4D",ink="FFF1D5",sub="C2CFBC",accent="F5D38B",selected="355247",hover="2E493E",warn="FFC299"},
    contrast={paper="111616",card="202826",inset="080D0C",line="899A92",ink="FFFFFF",sub="E2EAE4",accent="FFE393",selected="394A43",hover="35453E",warn="FFD3A5"},
}
for _, p in pairs(palettes) do
    p.rail, p.railCard, p.ivory, p.gold = "142E28","204138","FFF2D6","ECCC8E"
    p.railSub, p.railHover, p.footer = "C3D2BF","305644","10231F"
    for k, value in pairs(p) do p[k] = rgb(value) end
end

function U.options()
    local opts = type(ForeverGoblinMailerDB) == "table" and M.display() or {}
    return opts
end

function U.style()
    local opts = U.options()
    U.c = palettes[opts.theme] or palettes.parchment
    U.dense = opts.density == "compact"
    U.gap = U.dense and 5 or 8
end

function U.place(region, parent, x, y, width, height)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if width then region:SetWidth(width) end
    if height then region:SetHeight(height) end
end

function U.paint(texture, token)
    local c = U.c[token]
    texture:SetColorTexture(c[1],c[2],c[3],1)
end

function U.fill(parent, layer)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetAllPoints(parent)
    return t
end

function U.font(parent)
    local t = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetJustifyH("LEFT")
    t:SetJustifyV("TOP")
    t:SetWordWrap(true)
    t:SetShadowOffset(0,0)
    return t
end

function U.type(t, value, size, color, heading)
    local font = heading and GameFontNormalLarge or GameFontHighlight
    local face = font and font:GetFont()
    if face then t:SetFont(face, size, "") end
    t:SetTextColor(unpack(U.c[color]))
    t:SetText(value or "")
end

local function enter(b)
    if b.hover then b.hover:Show() end
    if not GameTooltip or not b.help then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(b.caption or "", 1,.86,.59,1,true)
    GameTooltip:AddLine(b.help,.94,.94,.88,true)
    if b.block then GameTooltip:AddLine(b.block,1,.76,.49,true) end
    GameTooltip:Show()
end
local function leave(b)
    if b.hover then b.hover:Hide() end
    if GameTooltip and GameTooltip:IsOwned(b) then GameTooltip:Hide() end
end
function U.bind(b)
    b:SetScript("OnEnter",enter)
    b:SetScript("OnLeave",leave)
    b:SetScript("OnClick",function(self)
        if self.block then M.say(self.block)
        elseif self.action then self.action() end
    end)
end

local function binding(b, opt)
    b.caption, b.help, b.block, b.action = opt.title, opt.tip or opt.desc, opt.block, opt.action
    b:EnableMouse(b.action ~= nil or opt.tip ~= nil)
end

function U.newTile(parent)
    local b = CreateFrame("Button", nil, parent)
    b.base = U.fill(b)
    b.hover = U.fill(b, "BORDER")
    b.hover:Hide()
    b.stripe = b:CreateTexture(nil, "ARTWORK")
    b.edge = b:CreateTexture(nil, "BORDER")
    b.well = b:CreateTexture(nil, "BORDER")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexCoord(.075,.925,.075,.925)
    b.title, b.detail, b.reason = U.font(b), U.font(b), U.font(b)
    b.arrow=U.font(b)
    U.bind(b)
    return b
end

function U.drawTile(b, parent, x, y, width, opt)
    local dark = opt.dark
    local inset = U.dense and 8 or 11
    local icon = opt.icon
    local iconSize = opt.iconSize or (U.dense and 28 or 34)
    U.place(b,parent,x,y,width,1)
    local solid=opt.primary and not opt.block
    U.paint(b.base,opt.surface or (solid and "railCard") or (dark and (opt.selected and "railHover" or "rail") or (opt.selected and "selected" or "card")))
    U.paint(b.hover,(dark or solid) and "railHover" or "hover")
    U.paint(b.stripe,dark and "gold" or "accent")
    b.stripe:SetShown(opt.selected == true)
    local left = inset
    if icon then
        U.paint(b.well,dark and "gold" or "line")
        U.place(b.well,b,inset-1,inset-1,iconSize+2,iconSize+2)
        b.well:Show()
        U.place(b.icon,b,inset,inset,iconSize,iconSize)
        b.icon:SetTexture(icon)
        b.icon:Show()
        b.icon:SetDesaturated(not not opt.block)
        left = left + iconSize + 10
    else b.icon:Hide(); b.well:Hide() end
    local arrow=opt.action and not opt.block and not dark and not opt.small
    local tw = width-left-inset-(arrow and 16 or 0)
    local function line(fs, text, top, size, tone, heading)
        fs:SetShown(text ~= nil and text ~= "")
        if not text or text == "" then return top end
        U.place(fs,b,left,top,tw)
        U.type(fs,text,size,tone,heading)
        return top + math.max(size+1,math.ceil(fs:GetStringHeight())) + 3
    end
    local titleSize = opt.small and 13 or 15
    local top = line(b.title,opt.title,inset,titleSize,(dark or solid) and "ivory" or "ink",true)
    top = line(b.detail,opt.desc,top,opt.small and 11 or 12,(dark or solid) and "railSub" or "sub")
    top = line(b.reason,opt.block or opt.tag,top,11,opt.block and (dark and "gold" or "warn") or (dark and "gold" or "accent"))
    local height = math.max(opt.min or 0, top-3+inset, icon and iconSize+inset*2 or 0)
    if opt.swatch then
        local palette=palettes[opt.swatch]
        b.samples=b.samples or {}
        for i,key in ipairs({"rail","paper","accent","ink"}) do
            local s=b.samples[i] or b:CreateTexture(nil,"ARTWORK")
            b.samples[i]=s
            local c=palette[key]
            s:SetColorTexture(c[1],c[2],c[3],1)
            U.place(s,b,left+(i-1)*19,top+1,17,7)
            s:Show()
        end
        height=height+12
    elseif b.samples then for _,s in ipairs(b.samples) do s:Hide() end end
    b:SetHeight(height)
    U.paint(b.edge,dark and "rail" or "line")
    U.place(b.edge,b,0,height-1,width,1)
    b.edge:SetShown(not dark)
    b.arrow:SetShown(arrow and true or false)
    if arrow then
        U.place(b.arrow,b,width-inset-12,math.floor(height/2)-9,16,20)
        U.type(b.arrow,">",14,solid and "gold" or "accent",true)
    end
    U.place(b.stripe,b,0,1,3,height-2)
    binding(b,opt)
    b:Show()
    return height
end

function U.pool(kind, maker)
    local i=(U.used[kind] or 0)+1
    U.used[kind]=i
    local list=U.pools[kind]
    if not list then list={}; U.pools[kind]=list end
    if not list[i] then list[i]=maker(U.content) end
    local node=list[i]
    node:Show()
    return node
end

function U.text(value,size,tone,spacing,heading)
    local t=U.pool("text",U.font)
    U.place(t,U.content,0,U.y,U.innerWidth)
    U.type(t,value,size,tone,heading)
    U.y=U.y+math.max(size+1,math.ceil(t:GetStringHeight()))+(spacing or U.gap)
end
function U.section(title,desc)
    if U.y>0 then U.y=U.y+6 end
    U.text(title,18,"ink",3,true)
    if desc then U.text(desc,12,"sub",8) end
end

function U.grid(entries,columns)
    columns = math.min(#entries, columns or 1)
    if columns == 0 then return end
    if U.innerWidth < 480 then columns = 1 end
    local width=math.floor((U.innerWidth-(columns-1)*U.gap)/columns)
    local height=0
    for i,opt in ipairs(entries) do
        local col=(i-1)%columns
        local b=U.pool("tiles",U.newTile)
        local h=U.drawTile(b,U.content,col*(width+U.gap),U.y,width,opt)
        height=math.max(height,h)
        if col==columns-1 or i==#entries then U.y=U.y+height+U.gap; height=0 end
    end
end

-- Edits are keyed so an item search or gold amount retains its own text and focus.
function U.edit(key, caption, hint, value, onCommit)
    U.text(caption,14,"ink",2,true)
    U.text(hint,12,"sub",4)
    local entry=U.edits[key]
    if not entry then
        entry=CreateFrame("EditBox",nil,U.content)
        entry.bg=U.fill(entry)
        entry.focusLine=entry:CreateTexture(nil,"BORDER")
        entry:SetScript("OnEditFocusGained",function(self) U.paint(self.focusLine,"accent") end)
        entry:SetScript("OnEditFocusLost",function(self) U.paint(self.focusLine,"line") end)
        entry:SetAutoFocus(false)
        entry:SetFontObject(GameFontHighlight)
        entry:SetTextInsets(9,9,2,2)
        entry:SetMaxLetters(255)
        entry:SetScript("OnEnter",enter); entry:SetScript("OnLeave",leave)
        entry:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
        entry:SetScript("OnEnterPressed",function(self) self:ClearFocus(); if self.commit then self.commit() end end)
        entry:SetScript("OnTextChanged",function(self,user)
            if user then U.state[key]=self:GetText() end
        end)
        U.edits[key]=entry
    end
    entry.live=true
    entry.caption,entry.help,entry.commit=caption,hint,onCommit
    U.paint(entry.bg,"inset")
    entry:SetTextColor(unpack(U.c.ink))
    U.place(entry,U.content,0,U.y,U.innerWidth,30)
    U.place(entry.focusLine,entry,0,29,U.innerWidth,1)
    U.paint(entry.focusLine,entry:HasFocus() and "accent" or "line")
    local shown = tostring(U.state[key] or value or "")
    if entry:GetText()~=shown then entry:SetText(shown) end
    entry:Show()
    U.y=U.y+30+U.gap
end

function U.finish()
    for kind,pool in pairs(U.pools) do
        for i=(U.used[kind] or 0)+1,#pool do pool[i]:Hide() end
    end
    for _,e in pairs(U.edits) do if not e.live then e:ClearFocus(); e:Hide() end end
    U.content:SetHeight(math.max(1,U.y+10))
end

function U.item(id)
    if not id then return "Unknown item",U.icons.missing end
    local name, icon
    if C_Item and C_Item.GetItemInfo then name=C_Item.GetItemInfo(id) end
    if C_Item and C_Item.GetItemIconByID then icon=C_Item.GetItemIconByID(id) end
    return name or ("Item #"..id), icon or U.icons.missing
end

function U.change(message)
    M.preview=nil
    M.cancelAuto()
    U.confirm=nil
    M.say(message)
end
function U.confirmAction(key, message, callback)
    if U.confirm==key then U.confirm=nil; callback()
    else U.confirm=key; M.say(message) end
end
function U.locked()
    if M.busy() then return "Finish or stop the current queue before changing mail settings." end
    if not U.scope then return U.identityProblem or "Character identity is unavailable." end
end
