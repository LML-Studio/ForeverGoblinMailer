local _, M = ...
local U=M.desk
local window, header, rail, footer, footerText, meter, launcher, close, send, stop
local title, identity, pageTitle, pageHelp, banner, seam, badge, dragShade
local nav, refreshing, ticker = {}, false, nil
local viewTips={
    desk="Review bag contents and recipients before approving a dispatch.",
    book="Inspect each profession and assign the current character to a role.",
    rules="Inspect item routing, edit saved exceptions and set the auction floor.",
    returns="See the reserve, postage and timing for this character.",
    activity="Inspect server receipts and reconcile a pending transfer.",
    look="Choose the finish, size, spacing and position of your mail desk.",
}

local function inside(v,lo,hi) return math.max(lo,math.min(v,hi)) end

local function smallButton(parent)
    local b=CreateFrame("Button",nil,parent)
    b.base=U.fill(b)
    b.hover=U.fill(b,"BORDER"); b.hover:Hide()
    b.text=U.font(b)
    b.text:SetJustifyH("CENTER"); b.text:SetJustifyV("MIDDLE")
    U.bind(b)
    return b
end
local function command(b,parent,x,y,w,h,caption,help,action,block,primary)
    U.place(b,parent,x,y,w,h)
    U.place(b.text,b,4,1,w-8,h-2)
    U.type(b.text,caption,13,block and "railSub" or (primary and "footer" or "ivory"),true)
    U.paint(b.base,primary and not block and "gold" or "railCard")
    U.paint(b.hover,primary and not block and "ivory" or "railHover")
    b.caption,b.help,b.action,b.block=caption,help,action,block
    b:Show()
end

local function footerState()
    if not window or not window:IsShown() then return end
    local r,seconds=M.activity()
    local right=128
    local canSend=M.preview and #M.preview.parcels>0 and U.page=="desk" and M.open and not r
    local message=M.status
    if seconds then message=("Automatic return in %ds   •   %s"):format(seconds, U.prefs.withMats and "Materials and surplus gold" or "Surplus gold")
    elseif U.identityProblem then message=U.identityProblem end
    U.type(footerText,message or "Ready.",12,"ivory")
    local paused=r~=nil or seconds~=nil or M.preview~=nil
    command(stop,footer,U.width-right-12,9,right,34,seconds and "Cancel countdown" or "Stop queue",
        "Cancel this countdown, review or remaining queue. A letter already submitted may still arrive.",M.cancel,
        not paused and "There is no countdown or queue to stop." or nil)
    local label=canSend and ("Send "..#M.preview.parcels..(#M.preview.parcels==1 and " parcel" or " parcels")) or "Send reviewed parcels"
    local reason
    if not canSend then reason=r and "Wait for the current parcel." or (U.page~="desk" and "Return to Mail desk to review and send." or "Prepare and inspect a parcel first.") end
    if r and r.phase=="native" then
        label="Use WoW's Send"
        reason="Your coins are in the native form. Verify the amount there, then click Send."
    end
    if U.page=="desk" and M.preview and M.preview.goldReason then
        label=M.preview.goldAmount==0 and "No gold to send" or "Quote unavailable"
        reason=M.preview.goldReason
    end
    if U.page=="desk" then
        local help="Submit reviewed items. When a letter carries gold, confirm the filled amount with WoW's Send button."
        if canSend and M.preview.goldLetter then
            label="Fill gold draft"
            help="Fill the native recipient, subject and coin fields with the amount shown. Click Send in WoW to finish."
        end
        command(send,footer,U.width-right-184,9,166,34,label,help,M.dispatch,reason,true)
    elseif U.page=="rules" and U.state.ruleID then
        command(send,footer,U.width-right-184,9,166,34,"Apply item rule",
            "Save the highlighted destination for the inspected item across this realm and faction.",U.saveRule,U.locked(),true)
    else
        command(send,footer,U.width-right-184,9,166,34,"Back to mail desk",
            "Return to the dispatch actions and your reviewed parcels.",function() U.navigate("desk") end)
    end
    if r or seconds then
        local fraction=r and (r.index-1)/math.max(1,#r.plan.parcels) or (1-seconds/M.delay(U.prefs))
        meter:SetWidth(math.max(2,U.width*inside(fraction,0,1))); meter:Show()
    else meter:Hide() end
    if seconds and not ticker then
        local ticket={}
        ticker=ticket
        C_Timer.After(.25,function()
            if ticker~=ticket then return end
            ticker=nil
            if window:IsShown() then footerState() end
        end)
    end
end

local function applyScroll()
    local max=math.max(0,U.content:GetHeight()-U.scroll:GetHeight())
    local current=inside(U.offsets[U.page] or 0,0,max)
    U.bar:SetMinMaxValues(0,max)
    U.bar:SetValue(current)
    U.bar:SetShown(max>1)
    U.scroll:SetVerticalScroll(current)
end
function U.top()
    U.offsets[U.page]=0
    U.scroll:SetVerticalScroll(0)
    M.refresh()
end

function U.navigate(page,top)
    local oldPage=U.page
    if oldPage~=page then
        U.offsets[oldPage]=U.scroll:GetVerticalScroll()
        for _,e in pairs(U.edits) do e:ClearFocus() end
    end
    local _,seconds=M.activity()
    if page~="desk" and seconds then M.cancelAuto(); M.status="Automatic return canceled for this visit." end
    if not seconds and not M.busy() and not M.preview and not (U.prefs and U.prefs.pending) then M.status=viewTips[page] end
    U.page,U.confirm=page,nil
    if top then U.offsets[page]=0 end
    M.refresh()
end

function M.refresh()
    if not window or not window:IsShown() or refreshing then return end
    refreshing=true
    U.scope,U.prefs,U.guid,U.identityProblem,U.network=M.context()
    U.prefs=U.prefs or {}
    U.style()
    U.paint(window.bg,"paper"); U.paint(rail.bg,"rail"); U.paint(footer.bg,"footer")
    U.paint(seam,"gold"); U.paint(meter,"gold"); U.paint(dragShade,"rail")
    U.paint(U.bar:GetThumbTexture(),"accent"); U.paint(U.bar.track,"line")
    U.type(title,"Forever Goblin Mailer",U.width<620 and 22 or 27,"ivory",true)
    local name=M.currentName() or "Character name unavailable"
    U.type(identity,name.."   /   "..(M.open and "Mailbox open" or "Mailbox closed"),12,"gold")
    local y=12
    for i,entry in ipairs(U.nav) do
        local k=entry[1]
        local opt={title=entry[2],desc=U.railWidth>=155 and entry[3] or nil,tip=viewTips[k],dark=true,selected=U.page==k,
            icon=U.icons[k],iconSize=U.railWidth<155 and 17 or 23,small=true,action=function() U.navigate(k) end}
        y=y+U.drawTile(nav[i],rail,5,y,U.railWidth-10,opt)+4
        if U.page==k then
            U.type(pageTitle,entry[2],22,"ink",true)
            U.type(pageHelp,viewTips[k],12,"sub")
        end
    end
    U.used={}
    U.y=0
    for _,e in pairs(U.edits) do e.live=false end
    U.pages[U.page]()
    U.finish()
    refreshing=false
    applyScroll()
    footerState()
end

function U.layout(reposition)
    if not window then return end
    U.style()
    local options=U.options()
    local request=({[85]=.85,[100]=1,[115]=1.15})[options.scale] or 1
    local sw,sh=UIParent:GetWidth(),UIParent:GetHeight()
    U.width=inside(math.floor((sw-30)/request),530,872)
    U.height=inside(math.floor((sh-28)/request),465,636)
    local scale=math.min(request,(sw-12)/U.width,(sh-12)/U.height)
    window:SetSize(U.width,U.height)
    window:SetScale(scale)
    if reposition then
        window:ClearAllPoints()
        if type(options.x)=="number" and type(options.y)=="number" then
            window:SetPoint("CENTER",UIParent,"BOTTOMLEFT",sw*inside(options.x,0,1)/scale,sh*inside(options.y,0,1)/scale)
        elseif M.open and MailFrame and MailFrame:IsVisible() and MailFrame:GetRight()
            and sw-MailFrame:GetRight()*MailFrame:GetEffectiveScale()/UIParent:GetEffectiveScale()>=U.width*scale+10 then
            window:SetPoint("TOPLEFT",MailFrame,"TOPRIGHT",6,0)
        else window:SetPoint("CENTER",UIParent,"CENTER",0,0) end
    end
    local narrow=U.width<730
    U.railWidth=narrow and 133 or 184
    U.place(header,window,0,0,U.width,73)
    U.place(banner,header,0,0,U.width,73)
    U.place(dragShade,header,0,0,math.min(U.width*.53,430),73)
    U.place(badge,header,18,15,42,42)
    U.place(title,header,72,10,U.width-132,32)
    U.place(identity,header,73,45,U.width-139,22)
    command(close,header,U.width-74,12,60,30,"Close","Hide the desk. An armed automatic return or active queue continues. Use Stop queue to cancel it.",
        function() window:Hide() end)
    U.place(seam,window,0,73,U.width,2)
    U.place(rail,window,0,75,U.railWidth,U.height-128)
    U.place(pageTitle,window,U.railWidth+18,85,U.width-U.railWidth-44,29)
    U.place(pageHelp,window,U.railWidth+19,118,U.width-U.railWidth-48,32)
    U.innerWidth=U.width-U.railWidth-56
    local vh=U.height-202
    U.place(U.scroll,window,U.railWidth+18,145,U.innerWidth,vh)
    U.content:SetWidth(U.innerWidth)
    U.place(U.bar,window,U.width-20,145,8,vh)
    U.place(footer,window,0,U.height-53,U.width,53)
    U.place(footerText,footer,14,8,U.width-340,40)
    U.place(meter,footer,0,0,1,2)
    M.refresh()
end

local function makeWindow()
    if window then return end
    U.style()
    window=CreateFrame("Frame","ForeverGoblinMailerPanel",UIParent)
    U.window=window
    window:Hide()
    window:SetFrameStrata("DIALOG")
    window:EnableMouse(true); window:SetMovable(true); window:SetClampedToScreen(true)
    window.bg=U.fill(window)
    header=CreateFrame("Frame",nil,window)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() window:StartMoving() end)
    header:SetScript("OnDragStop",function()
        window:StopMovingOrSizing()
        local x,y=window:GetCenter()
        if x and U.scope then
            local o=U.options()
            local ratio=window:GetEffectiveScale()/UIParent:GetEffectiveScale()
            o.x=inside(x*ratio/UIParent:GetWidth(),0,1); o.y=inside(y*ratio/UIParent:GetHeight(),0,1)
        end
    end)
    header:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
        GameTooltip:SetText("Move the mail desk")
        GameTooltip:AddLine("Drag this header to save a position. Appearance restores automatic docking.",1,1,1,true)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave",function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    banner=header:CreateTexture(nil,"BACKGROUND")
    banner:SetTexture("Interface\\AddOns\\ForeverGoblinMailer\\Mailroom.tga")
    dragShade=header:CreateTexture(nil,"BORDER")
    badge=header:CreateTexture(nil,"ARTWORK"); badge:SetTexture(U.icons.desk); badge:SetTexCoord(.07,.93,.07,.93)
    title,identity=U.font(header),U.font(header)
    close=smallButton(header)
    seam=window:CreateTexture(nil,"BORDER")
    rail=CreateFrame("Frame",nil,window); rail.bg=U.fill(rail)
    for i=1,#U.nav do nav[i]=U.newTile(rail) end
    pageTitle,pageHelp=U.font(window),U.font(window)
    U.scroll=CreateFrame("ScrollFrame",nil,window)
    U.content=CreateFrame("Frame",nil,U.scroll)
    U.content:SetSize(500,1)
    U.scroll:SetScrollChild(U.content)
    U.edits={}
    U.bar=CreateFrame("Slider",nil,window)
    U.bar:SetOrientation("VERTICAL")
    U.bar:SetMinMaxValues(0,1)
    U.bar:SetValueStep(1)
    U.bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    U.bar:GetThumbTexture():SetSize(8,28)
    U.paint(U.bar:GetThumbTexture(),"accent")
    U.bar.track=U.fill(U.bar); U.paint(U.bar.track,"line")
    U.bar:SetScript("OnValueChanged",function(_,n) U.scroll:SetVerticalScroll(n); U.offsets[U.page]=n end)
    U.bar:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_LEFT"); GameTooltip:SetText("Scroll this page")
        GameTooltip:AddLine("Drag the thumb or use the mouse wheel to see more.",1,1,1,true); GameTooltip:Show()
    end)
    U.bar:SetScript("OnLeave",function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    U.scroll:EnableMouseWheel(true)
    U.scroll:SetScript("OnMouseWheel",function(_,d) U.bar:SetValue(U.scroll:GetVerticalScroll()-d*(U.dense and 46 or 60)) end)
    footer=CreateFrame("Frame",nil,window); footer.bg=U.fill(footer)
    footerText=U.font(footer)
    meter=footer:CreateTexture(nil,"ARTWORK")
    send,stop=smallButton(footer),smallButton(footer)
    window:SetScript("OnHide",function()
        ticker=nil; U.confirm=nil
        for _,e in pairs(U.edits) do e:ClearFocus() end
    end)
end

local function show(page)
    if InCombatLockdown() then return end
    makeWindow()
    window:Show()
    U.page=page or "desk"
    U.layout(true)
    U.navigate(U.page)
end

local function addLauncher()
    if launcher or not MailFrame then return end
    launcher=smallButton(MailFrame)
    command(launcher,MailFrame,0,0,132,24,"Goblin Mailer","Show or hide the visual mail desk beside your native mailbox.",
        function() if window and window:IsShown() then window:Hide() else show("desk") end end)
    launcher:ClearAllPoints()
    launcher:SetPoint("TOPLEFT",MailFrame,"BOTTOMLEFT",197,2)
end

local events=CreateFrame("Frame")
for _,event in ipairs({"MAIL_SHOW","MAIL_CLOSED","MAIL_SEND_SUCCESS","MAIL_FAILED","MAIL_LOCK_SEND_ITEMS",
    "PLAYER_REGEN_DISABLED","PLAYER_ENTERING_WORLD","DISPLAY_SIZE_CHANGED","UI_SCALE_CHANGED","PLAYER_MONEY","MAIL_SEND_INFO_UPDATE","MAIL_INBOX_UPDATE","UNIT_NAME_UPDATE","PLAYER_LOGIN"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
    M.event(event)
    if event=="PLAYER_MONEY" then M.check.walletChanged() end
    if event=="MAIL_INBOX_UPDATE" or event=="MAIL_SHOW" then M.check.observeInbox() end
    if event=="MAIL_SHOW" then
        M.check.watchInbox()
        C_Timer.After(0,function() if M.open then U.style(); addLauncher(); show("desk") end end)
    elseif event=="MAIL_CLOSED" or event=="PLAYER_REGEN_DISABLED" then
        if window then window:Hide() end
    elseif window and window:IsShown() then
        if event=="DISPLAY_SIZE_CHANGED" or event=="UI_SCALE_CHANGED" then U.layout(true)
        elseif event=="PLAYER_ENTERING_WORLD" or (U.identityProblem and (event=="PLAYER_LOGIN" or (event=="UNIT_NAME_UPDATE" and unit=="player"))) or ((event=="PLAYER_MONEY" or event=="MAIL_SEND_INFO_UPDATE") and U.page=="returns") then M.refresh() end
    end
end)
SLASH_FOREVERGOBLINMAILER1="/fgm"
SLASH_FOREVERGOBLINMAILER2="/goblinmail"
SlashCmdList.FOREVERGOBLINMAILER=function(message)
    if M.trim(message):lower()=="check" then
        show("activity")
        if not InCombatLockdown() then M.check.start() end
    else show("book") end
end
