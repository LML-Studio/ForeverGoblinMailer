-- Isolated Lua 5.1 host. All character identities, bags and money are synthetic.
return function()
    local env = setmetatable({}, {__index=_G})
    local M, f = {}, {now=0, timers={}, bags={}, attachments={}, outbox={}, wallet=40000,
        guid="char-main", player="Juniper Silver", limit=2, charged=0, nativeMoney=0}
    assert(loadfile("tests/frame_host.lua"))()(env,f)
    env.NameUtil={GetUnmodifiedUnitFullName=function() return f.player end}
    env.UnitGUID=function() return f.guid end
    env.UnitFullName=function() return f.player, "Fixture" end
    env.GetRealmName=function() return f.realm or "Fixture" end
    env.UnitFactionGroup=function() return f.faction or "Alliance" end
    env.InCombatLockdown=function() return f.combat or false end
    env.NUM_BAG_SLOTS, env.ATTACHMENTS_MAX_SEND=0, f.limit
    env.GetMoney=function() return f.wallet end
    env.GetTime=function() return f.now end
    env.GetServerTime=function() return 1700000000+math.floor(f.now) end
    env.GetBuildInfo=function() return "Fixture", "71139" end
    env.C_Timer={After=function(delta, fn) f.timers[#f.timers+1]={at=f.now+delta, fn=fn} end}
    function f.advance(delta)
        local untilTime=f.now+delta
        while true do
            local nextTimer
            for i,t in ipairs(f.timers) do
                if t.at<=untilTime and (not nextTimer or t.at<f.timers[nextTimer].at) then nextTimer=i end
            end
            if not nextTimer then break end
            local t=table.remove(f.timers,nextTimer)
            f.now=t.at; t.fn()
        end
        f.now=untilTime
    end
    env.C_Mail={IsCommandPending=function() return f.nativePending or false end}
    env.C_Container={}
    env.C_Container.GetContainerNumSlots=function() return 20 end
    env.C_Container.GetContainerItemInfo=function(_, slot) return f.bags[slot] end
    env.C_Container.GetContainerItemQuestInfo=function(_, slot)
        return {isQuestItem=f.bags[slot].quest or false, isActive=false}
    end
    env.C_Container.GetContainerItemEquipmentSetInfo=function(_, slot) return f.bags[slot].inSet or false end
    env.ItemLocation={CreateFromBagAndSlot=function(_, _, slot) return slot end}
    env.C_Item={GetItemGUID=function(slot) return f.bags[slot].guid end,
        CanBeRefunded=function(slot) return f.bags[slot].refund or false end}
    env.C_Item.GetItemInfo=function(link)
        local v=f.data[link]
        if not v or v.cold then return end
        return v.itemName,link,v.quality,1,1,"","","","","",0,v.class,v.sub,v.bind,0,nil,v.reagent
    end
    env.GetCursorInfo=function()
        if f.cursor then return "item",f.cursor.itemID,f.cursor.hyperlink end
    end
    env.C_Container.PickupContainerItem=function(_, slot) f.cursor=f.bags[slot]; f.bags[slot]=nil end
    env.ClickSendMailItemButton=function(i) f.attachments[i]=f.cursor; f.cursor=nil end
    env.GetSendMailItem=function(i)
        local v=f.attachments[i]
        if v then return v.itemName,v.itemID,0,v.stackCount,v.quality end
    end
    env.GetSendMailItemLink=function(i) return f.attachments[i] and f.attachments[i].hyperlink end
    env.HasSendMailItem=function(i) return f.attachments[i]~=nil end
    env.GetSendMailPrice=function() return f.postage or math.max(1,#f.attachments)*30 end
    local function coinBox()
        return {n=0, GetNumber=function(self) return self.n end,
            SetNumber=function(self,n) self.n=n end, IsVisible=function() return true end}
    end
    local coins=env.SendMailMoney
    coins.gold,coins.silver,coins.copper=coinBox(),coinBox(),coinBox()
    env.MoneyInputFrame_GetCopper=function(frame)
        return frame.gold:GetNumber()*10000 + frame.silver:GetNumber()*100 + frame.copper:GetNumber()
    end
    env.MoneyInputFrame_SetCopper=function(frame,n)
        frame.gold:SetNumber(math.floor(n/10000)); frame.silver:SetNumber(math.floor(n/100)%100); frame.copper:SetNumber(n%100)
    end
    function f.coins() return env.MoneyInputFrame_GetCopper(coins) end
    env.GetSendMailMoney=function() return f.charged end
    env.GetSendMailCOD=function() return 0 end
    env.SendMailFrame_SendMail=function()
        env.SendMail(env.SendMailNameEditBox:GetText(),env.SendMailSubjectEditBox:GetText(),env.SendMailBodyEditBox:GetText())
    end
    env.InboxFrame={}; env.InboxFrame_OnClick=function(_,index) env.InboxFrame.openMailID=index; env.OpenMailFrame.visible=true end
    env.hooksecurefunc=function(name,observe)
        local original=env[name]
        env[name]=function(...) original(...); observe(...) end
    end
    function f.nativeSend()
        assert(env.SendMailFrame.visible and not f.nativePending)
        f.charged=f.coins()
        env.SendMailFrame_SendMail()
    end
    env.MailFrameTab_OnClick=function() env.SendMailFrame.visible=true; env.SendMailFrame.sendMode="send" end
    env.SendMail=function(name,subject,body)
        assert(not f.nativePending)
        f.outbox[#f.outbox+1]={to=name,subject=subject,body=body,gold=f.charged,stacks=#f.attachments,fee=env.GetSendMailPrice()}
        f.nativePending=true
    end
    f.data={}
    function f.item(slot,id,options)
        local v={itemName="Item "..id,itemID=id,hyperlink="|cffffffff|Hitem:"..id.."::::|h[Item]|h|r",
            guid="stack-"..slot,stackCount=1,isLocked=false,isBound=false,hasLoot=false,
            quality=1,class=7,sub=0,bind=0,reagent=false}
        for k,value in pairs(options or {}) do v[k]=value end
        f.bags[slot]=v; f.data[v.hyperlink]=v
        return v
    end
    function f.ack()
        local sent=assert(f.outbox[#f.outbox])
        f.wallet=f.wallet-sent.gold-sent.fee
        f.attachments={}; env.MoneyInputFrame_SetCopper(coins,0); f.charged=0; f.nativePending=false
        env.SendMailNameEditBox.text=""; env.SendMailSubjectEditBox.text=""; env.SendMailBodyEditBox.text=""
        M.event("MAIL_SEND_SUCCESS")
    end
    for _,file in ipairs({"Roster","Recipes","Routing","Mailbox","DeliveryCheck","Dispatch","DeskKit","DeskPages","Panel"}) do
        local chunk=assert(loadfile("ForeverGoblinMailer/"..file..".lua"))
        setfenv(chunk,env)("ForeverGoblinMailer",M)
    end
    f.M, f.env=M, env
    local scope=M.context()
    for _,entry in ipairs({{"main","char-main","Juniper Silver"},{"tailor","char-tailor","Thimble Blue"},
        {"enchanter","char-enchant","Ember Vale"},{"auction","char-auction","Penny Gold"}}) do
        assert(M.enroll(scope,entry[2],entry[1],entry[3]))
    end
    f.scope=scope
    return f
end
