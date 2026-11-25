local fixture = assert(loadfile("tests/fixture.lua"))()
local passed=0
local function eq(a,b) assert(a==b,tostring(a).." differs from "..tostring(b)) end
local function test(name, fn)
    local ok, why=pcall(fn)
    if not ok then error(name.." -- "..tostring(why),0) end
    passed=passed+1; print("ok "..passed.." - "..name)
end
local function main()
    local f=fixture(); f.M.event("MAIL_SHOW"); return f
end
local function alt(mats)
    local f=fixture(); f.guid="char-tailor"; local _,p=f.M.context(); p.withMats=mats
    f.M.event("MAIL_SHOW"); return f,p
end
test("cloth and enchant materials resolve even with generic legacy subclasses",function()
    local f=main(); f.item(1,2589); f.item(2,10940)
    local p=f.M.review("route"); eq(#p.parcels,2); eq(p.parcels[1].name,"Thimble Blue"); eq(p.parcels[2].name,"Ember Vale")
end)
test("shared materials require assignment and per-item keep wins",function()
    local f=main(); f.item(1,90001,{sub=7}); f.item(2,2589); f.scope.rules[2589]="keep"
    eq(f.M.review("route").stacks,0)
    f.scope.rules[90001]="tailor"; eq(f.M.review("route").stacks,1)
end)
test("each physical stack appears once, split at the native limit",function()
    local f=main(); for i=1,5 do f.item(i,2589) end
    local p=f.M.review("route"); eq(p.stacks,5); eq(#p.parcels,3); eq(#p.parcels[3].items,1)
end)
test("auction values are per unit and missing quotes stay in bags",function()
    local f=main(); for i=1,3 do f.item(i,700+i,{class=4,quality=2,stackCount=20}) end
    f.env.Auctionator={API={v1={GetAuctionPriceByItemLink=function(_,link)
        if link:find("701") then return 50000 elseif link:find("702") then return 49999 end
    end}}}
    local p=f.M.review("auction"); eq(p.stacks,1); eq(p.parcels[1].items[1].id,701)
    f.scope.rules[703]="auction"; eq(f.M.review("auction").stacks,2)
end)
test("auction-only excludes profession stock and duplicate roles share an envelope",function()
    local f=main(); assert(f.M.enroll(f.scope,"char-tailor","enchanter","Thimble Blue"))
    f.item(1,2589); f.item(2,10940); eq(#f.M.review("route").parcels,1); eq(f.M.review("auction").stacks,0)
end)
test("binding, quest, refundable, equipment-set, loot and cold-cache guards precede overrides",function()
    local f=main()
    for i,extra in ipairs({{isBound=true},{quest=true},{refund=true},{inSet=true},{hasLoot=true},{cold=true},{bind=1},{isLocked=true}}) do
        f.item(i,1000+i,extra); f.scope.rules[1000+i]="auction"
    end
    local p=f.M.review("route"); eq(#p.held,8); eq(p.stacks,0)
end)
test("realm, faction, self and duplicate address protections",function()
    local f=main(); eq(f.M.enroll(f.scope,"else","cook","Thimble Blue"),nil)
    eq(f.M.enroll(f.scope,"char-main","cook","|Hbad|h"),nil)
    assert(f.M.enroll(f.scope,"char-main","cook","Juniper Silver")); f.item(1,2672); eq(f.M.review("route").stacks,0)
    f.realm="Elsewhere"; eq(f.M.review("route"),nil); f.realm=nil; f.faction="Horde"; eq(f.M.review("route"),nil)
end)
test("missing addresses and wrong character roles cannot dispatch",function()
    local f=main(); f.scope.roles.tailor=nil; f.item(1,2589)
    eq(f.M.review("route").stacks,0); eq(f.M.review("gold"),nil)
    f.guid="unregistered"; eq(f.M.review("materials"),nil)
end)
test("manual drafts, replies, cursor, COD, pending commands and manual attachments hold",function()
    for _,block in ipairs({"subject","recipient","body","money","reply","cursor","cod","attached","pending","openmail"}) do
        local f=main(); f.item(1,2589)
        if block=="subject" then f.env.SendMailSubjectEditBox.text="Mine"
        elseif block=="recipient" then f.env.SendMailNameEditBox.text="Mine"
        elseif block=="body" then f.env.SendMailBodyEditBox.text="Mine"
        elseif block=="money" then f.nativeMoney=1
        elseif block=="reply" then f.env.SendMailFrame.sendMode="reply"
        elseif block=="cursor" then f.cursor=f.bags[1]
        elseif block=="cod" then f.env.SendMailCODButton.checked=true
        elseif block=="attached" then f.attachments[1]=f.bags[1]
        elseif block=="pending" then f.nativePending=true else f.env.OpenMailFrame.visible=true end
        eq(f.M.review("route"),nil); eq(#f.outbox,0)
    end
end)
test("review and duplicate clicks cannot send extra parcels",function()
    local f=main(); for i=1,3 do f.item(i,2589) end
    f.M.review("route"); eq(#f.outbox,0); f.M.dispatch(); f.M.dispatch(); f.advance(1)
    eq(#f.outbox,1); eq(f.outbox[1].stacks,2); f.M.event("MAIL_SUCCESS"); f.advance(2); eq(#f.outbox,1)
    f.ack(); f.advance(1); eq(#f.outbox,2); f.ack(); eq(f.M.busy(),false)
end)
test("stack GUID, variant and quantity drift stop before pickup",function()
    for _,k in ipairs({"guid","hyperlink","stackCount"}) do
        local f=main(); local v=f.item(1,2589); f.M.review("route")
        v[k]= k=="stackCount" and 2 or "changed"; f.M.dispatch(); f.advance(5); eq(#f.outbox,0)
    end
end)
test("recipient changes and extra native attachments abort during staging",function()
    for _,field in ipairs({"recipient","extra","quantity","membership"}) do
        local f=main(); f.item(1,2589); f.M.review("route"); f.M.dispatch()
        if field=="recipient" then f.env.SendMailNameEditBox.text="Elsewhere"
        elseif field=="extra" then f.attachments[2]=f.attachments[1]
        elseif field=="membership" then f.scope.roles.tailor.name="Another Alt"
        else f.attachments[1].stackCount=2 end
        f.advance(4); eq(#f.outbox,0)
    end
end)
test("automatic gold uses real postage and leaves exactly one gold",function()
    local f,p=alt(); f.wallet=28976; f.postage=73; f.advance(7.9); eq(#f.outbox,0)
    f.advance(.2); eq(#f.outbox,1); eq(f.outbox[1].to,"Juniper Silver"); eq(f.outbox[1].gold,18903)
    assert(p.pending); f.ack(); eq(f.wallet,10000); eq(p.pending,nil)
    f.M.event("MAIL_SHOW"); f.advance(10); eq(#f.outbox,1)
end)
test("at the reserve, below it, or with only postage there is no transfer",function()
    for _,n in ipairs({0,9999,10000,10029,10030}) do local f=alt(); f.wallet=n; f.advance(10); eq(#f.outbox,0) end
end)
test("optional multi-parcel material return puts surplus on the final envelope",function()
    local f=alt(true); for i=1,3 do f.item(i,9000+i,{class=7,sub=0}) end
    f.scope.rules[9004]="keep"; f.item(4,9004); f.advance(9); eq(f.outbox[1].gold,0)
    f.ack(); f.advance(1); eq(f.outbox[2].stacks,1); eq(f.outbox[2].gold,29910); f.ack(); eq(f.wallet,10000)
end)
test("manual material-only returns preserve the reserve and auction assignments",function()
    local f=alt(); f.item(1,2589); f.item(2,10940); f.scope.rules[10940]="auction"; f.wallet=10040
    eq(f.M.review("materials",false).stacks,1); f.M.dispatch(); f.advance(1)
    eq(f.outbox[1].gold,0); f.ack(); eq(f.wallet,10010); f.advance(10); eq(#f.outbox,1)
end)
test("postage that would dip below the reserve leaves draft unsent",function()
    local f=alt(); f.item(1,2589); f.wallet=10001; f.M.review("materials"); f.M.dispatch(); f.advance(1)
    eq(#f.outbox,0); assert(f.attachments[1])
end)
test("stopping, mailbox closure and combat cancel the delayed sweep",function()
    for _,event in ipairs({"stop","MAIL_CLOSED","PLAYER_REGEN_DISABLED"}) do
        local f=alt(); if event=="stop" then f.M.cancel() else f.M.event(event) end
        f.advance(12); eq(#f.outbox,0)
    end
end)
test("unconfirmed, failed and interrupted sends remain on hold across reopen",function()
    for _,event in ipairs({"timeout","MAIL_FAILED","MAIL_CLOSED"}) do
        local f,p=alt(); f.advance(9); if event=="timeout" then f.advance(31) else f.M.event(event) end
        assert(p.pending); f.M.event("MAIL_CLOSED"); f.M.event("MAIL_SHOW"); f.advance(12); eq(#f.outbox,1)
    end
end)
test("disabled automatic return and a main with a profession never auto-sweep",function()
    local f=fixture(); f.guid="char-tailor"; local _,p=f.M.context(); p.auto=false
    f.M.event("MAIL_SHOW"); f.advance(12); eq(#f.outbox,0)
    f=fixture(); f.M.enroll(f.scope,"char-main","cook","Juniper Silver"); f.M.event("MAIL_SHOW"); f.advance(12); eq(#f.outbox,0)
end)
test("a concurrent wallet decrease is observed immediately before transfer",function()
    local f=alt(true); f.item(1,2589); f.advance(8.01); f.wallet=10029; f.advance(2); eq(#f.outbox,0)
end)
test("unknown postage and unavailable mail APIs fail closed",function()
    local f=alt(); f.env.GetSendMailPrice=function() end; f.advance(10); eq(#f.outbox,0)
    f=main(); f.env.GetSendMailItemLink=nil; eq(f.M.review("route"),nil)
end)
test("native surname enrollment is read-only and handles a temporarily missing separator",function()
    local f=fixture(); eq(f.M.currentName(),"Juniper Silver")
    f.env.NameUtil=nil; f.env.UnitNameUnmodified=function() return "Juniper","Silver" end
    eq(f.M.currentName(),nil)
    f.env.Constants={CharacterNameSeparatorConsts={CHARACTERNAME_SURNAME_SEPARATOR="-"}}
    eq(f.M.currentName(),"Juniper-Silver")
end)
test("exact-build recipes cover new reagents and shared-reagent overrides",function()
    local f=main(); f.item(1,213371,{class=15}); f.item(2,211422,{class=7})
    assert(f.M.enroll(f.scope,"char-potion","alchemist","Flask Gold"))
    assert(f.M.enroll(f.scope,"char-smith","smith","Anvil Green"))
    local p=f.M.review("route"); eq(p.stacks,1); eq(p.parcels[1].name,"Flask Gold"); eq(#p.held,1)
    f.scope.rules[211422]="smith"; eq(f.M.review("route").stacks,2)
    local count=0; for _ in pairs(f.M.recipeOwners) do count=count+1 end; eq(count,589)
end)
test("a price change after attaching money cannot break the reserve",function()
    local f,p=alt(); f.env.GetSendMailPrice=function() return f.charged>0 and 60 or 30 end
    f.advance(9); eq(#f.outbox,0); eq(f.nativeMoney,0); eq(f.charged,0); eq(p.pending,nil)
end)
test("normal mailbox launcher, dispatch, review, send and slash settings are wired",function()
    local f=fixture(); f.item(1,2589)
    f.listener.scripts.OnEvent(f.listener,"MAIL_SHOW"); f.advance(0)
    f.click("Goblin Mailer"); f.click("Goblin Mailer"); f.click("Route my bags")
    eq(#f.outbox,0); f.click("Send reviewed parcels"); f.advance(1); eq(#f.outbox,1); f.ack()
    f.env.SlashCmdList.FOREVERGOBLINMAILER(); f.click("Register"); f.click("Register")
    eq(f.scope.roles.main.name,"Juniper Silver")
end)
print(("%d scenarios passed"):format(passed))
