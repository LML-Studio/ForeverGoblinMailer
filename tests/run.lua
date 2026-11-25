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
    eq(#f.outbox,0); f.click("Send 1 parcel"); f.advance(1); eq(#f.outbox,1); f.ack()
    f.env.SlashCmdList.FOREVERGOBLINMAILER(); f.click("Register this character"); f.click("Confirm assignment")
    eq(f.scope.roles.main.name,"Juniper Silver")
end)
local function openDesk(f)
    f.listener.scripts.OnEvent(f.listener,"MAIL_SHOW")
    f.advance(0)
end
test("all six pages expose descriptions and hover help on live and unavailable actions",function()
    local f=fixture(); openDesk(f)
    for _,name in ipairs({"Mail desk","Address book","Routing rules","Gold returns","Activity","Appearance"}) do
        f.click(name)
        for _,w in ipairs(f.widgets) do
            if w:IsVisible() and w.action then
                assert(w.caption and #w.caption>0 and w.help and #w.help>0)
                w.scripts.OnEnter(w); assert(f.env.GameTooltip:IsOwned(w)); w.scripts.OnLeave(w)
            end
        end
    end
    f.click("Mail desk"); local b=f.button("Gold to main"); assert(b.block)
    b.scripts.OnEnter(b); assert(f.env.GameTooltip.text:find("profession alt",1,true)); f.click("Gold to main"); eq(#f.outbox,0)
end)
test("missing identity stays visible and settings cannot mutate the address book",function()
    local f=fixture(); f.env.UnitGUID=function() end
    f.env.SlashCmdList.FOREVERGOBLINMAILER()
    assert(f.M.desk.identityProblem:find("character identity",1,true))
    assert(f.button("Register this character").block)
    for _,page in ipairs({"Routing rules","Gold returns","Appearance","Activity"}) do f.click(page) end
    f.click("Clear delivery hold"); eq(#f.outbox,0)
end)
test("registration names the replacement and requires a separate confirmation",function()
    local f=fixture(); f.env.SlashCmdList.FOREVERGOBLINMAILER(); f.click("Tailoring"); f.click("Register this character")
    eq(f.scope.roles.tailor.guid,"char-tailor"); f.click("Confirm assignment"); eq(f.scope.roles.tailor.guid,"char-main")
    f.click("Remove assignment"); assert(f.scope.roles.tailor); f.click("Confirm removal"); eq(f.scope.roles.tailor,nil)
end)
test("manifest keeps routing evidence and opens an identified stack in the rule editor",function()
    local f=fixture(); f.item(1,2589,{itemName="Linen Cloth",stackCount=20}); openDesk(f)
    f.click("Route my bags"); eq(f.M.preview.parcels[1].items[1].routeBasis,"Material family")
    f.click("Linen Cloth  ×20"); eq(f.M.desk.page,"rules"); eq(f.M.desk.state.ruleID,2589)
    f.click("Keep in bags"); f.click("Apply item rule"); eq(f.scope.rules[2589],"keep"); eq(f.M.preview,nil)
    f.click("Automatic"); f.click("Save item rule"); eq(f.scope.rules[2589],nil)
end)
test("typing a different item needs inspection before saving any override",function()
    local f=fixture(); openDesk(f); f.click("Routing rules")
    f.M.desk.state.itemText="2589"; f.click("Inspect item"); f.click("Keep in bags")
    f.M.desk.state.itemText="10940"; f.click("Save item rule"); eq(f.scope.rules[2589],nil); eq(f.scope.rules[10940],nil)
end)
test("auction and keep rules identify the held or priced physical stack",function()
    local f=main(); f.item(1,701,{class=4,quality=2})
    f.env.Auctionator={API={v1={GetAuctionPriceByItemLink=function() return 64123 end}}}
    local p=f.M.review("route"); eq(p.parcels[1].items[1].quote,64123); eq(p.parcels[1].items[1].routeBasis,"Auction quote per unit")
    f.scope.rules[701]="keep"; p=f.M.review("route"); eq(p.held[1].reason,"Keep rule")
end)
test("per-alt reserve applies to final readback and invalid saved reserves fall back to one gold",function()
    local f=fixture(); f.guid="char-tailor"; local _,p=f.M.context(); p.reserveGold=2; p.delaySeconds=15
    openDesk(f); local _,t=f.M.activity(); eq(t,15); f.advance(14); eq(#f.outbox,0); f.advance(1.1); eq(f.outbox[1].gold,19970)
    f.ack(); eq(f.wallet,20000); eq(f.M.receipts[1].postage,30); eq(f.M.receipts[1].recipient,"Juniper Silver")
    p.reserveGold=0; eq(f.M.reserve(p),10000); p.reserveGold="bad"; eq(f.M.reserve(p),10000)
end)
test("browsing settings cancels an automatic return and appearance preserves addresses",function()
    local f=fixture(); f.guid="char-tailor"; openDesk(f); f.click("Appearance")
    f.click("Midnight"); eq(f.M.display().theme,"midnight"); f.click("Compact"); f.click("115%")
    eq(f.M.display().scale,115); eq(f.M.display().density,"compact"); f.advance(35); eq(#f.outbox,0)
    eq(f.scope.roles.tailor.guid,"char-tailor")
end)
test("numeric settings enforce floors and in-flight queues lock rule edits",function()
    local f=fixture(); openDesk(f); f.click("Gold returns"); f.M.desk.state.reserveText="0"; f.click("Save reserve")
    eq(f.M.reserve(f.M.desk.prefs),10000); f.M.desk.state.reserveText="3"; f.click("Save reserve"); eq(f.M.reserve(f.M.desk.prefs),30000)
    f.click("Routing rules"); f.M.desk.state.floorText="14"; f.click("Save auction floor"); eq(f.scope.floorGold,14)
    f.item(1,2589); f.click("Mail desk"); f.click("Route my bags"); f.click("Send 1 parcel")
    f.click("Routing rules"); assert(f.button("Save auction floor").block); f.advance(1); eq(#f.outbox,1)
end)
test("accepted receipts display separately from uncertain deliveries",function()
    local f=fixture(); f.guid="char-tailor"; openDesk(f); f.advance(9); f.M.event("MAIL_SUCCESS"); eq(#f.M.receipts,0)
    f.advance(31); f.click("Activity"); f.click("Clear delivery hold"); assert(f.M.desk.prefs.pending)
    f.click("Confirm checked delivery"); eq(f.M.desk.prefs.pending,nil); eq(#f.M.receipts,0)
end)
test("a narrow screen fits the desk and repeated navigation reuses frame pools",function()
    local f=fixture(); f.env.UIParent:SetSize(610,510); openDesk(f); f.click("Appearance"); f.click("115%")
    local u=f.M.desk
    assert(u.width*u.window.scale<=610 and u.height*u.window.scale<=510)
    for _,page in ipairs({"Address book","Routing rules","Gold returns","Activity","Appearance"}) do f.click(page) end
    local size=#f.widgets
    for _,page in ipairs({"Address book","Routing rules","Gold returns","Activity","Appearance"}) do f.click(page) end
    eq(#f.widgets,size)
end)
local function goldDesk(balance, reserve)
    local f=fixture()
    f.guid, f.wallet, f.postage="char-tailor", balance, 30
    local _,prefs=f.M.context(); prefs.auto=false; prefs.reserveGold=reserve or 1
    openDesk(f)
    f.click("Gold to main")
    return f
end

test("zero and negative surplus disable the actual Send control before a click",function()
    for _,case in ipairs({{10000,1},{10030,1},{20030,2}}) do
        local f=goldDesk(case[1],case[2])
        eq(#f.M.preview.parcels,0); eq(f.M.preview.goldAmount,0)
        assert(f.button("No gold to send").block:find("No surplus",1,true))
        f.click("No gold to send"); eq(#f.outbox,0); eq(f.wallet,case[1])
    end
end)
test("one copper survives review, native submission, acknowledgement and wallet debit",function()
    local f=goldDesk(10031)
    eq(#f.M.preview.parcels,1); eq(f.M.preview.goldAmount,1)
    f.click("Send 1 parcel"); eq(#f.outbox,1); eq(f.outbox[1].gold,1); eq(f.outbox[1].fee,30)
    f.ack(); eq(f.wallet,10000); eq(f.M.receipts[1].gold,1)
end)
test("unknown postage stays distinct from a known zero and native updates refresh the offer",function()
    local f=goldDesk(10031); f.env.GetSendMailPrice=function() end
    f.listener.scripts.OnEvent(f.listener,"MAIL_SEND_INFO_UPDATE")
    eq(f.M.preview.goldAmount,nil); assert(f.button("Quote unavailable").block); eq(#f.outbox,0)
    f.env.GetSendMailPrice=function() return 30 end
    f.wallet=10030; f.listener.scripts.OnEvent(f.listener,"PLAYER_MONEY"); eq(f.M.preview.goldAmount,0)
    f.wallet=10031; f.listener.scripts.OnEvent(f.listener,"PLAYER_MONEY"); eq(f.M.preview.goldAmount,1)
    f.click("Send 1 parcel"); eq(f.outbox[1].gold,1)
end)
test("a changed quote or balance before approval requires the displayed amount again",function()
    local f=goldDesk(20031,2); f.wallet=20030; f.click("Send 1 parcel")
    eq(#f.outbox,0); assert(f.button("No gold to send").block)
    f.wallet=20035; f.listener.scripts.OnEvent(f.listener,"PLAYER_MONEY"); eq(f.M.preview.goldAmount,5)
    f.postage=31; f.click("Send 1 parcel"); eq(#f.outbox,0); eq(f.M.preview.goldAmount,4)
    f.click("Send 1 parcel"); eq(f.outbox[1].gold,4); f.ack(); eq(f.wallet,20000)
end)
test("zero gold permits a real material letter exactly at the postage boundary",function()
    local f=fixture(); f.guid="char-tailor"; f.wallet=10030; f.item(1,2589)
    openDesk(f); f.click("Materials to main")
    eq(#f.M.preview.parcels,1); eq(f.M.preview.goldLetter,nil); f.click("Send 1 parcel"); f.advance(1)
    eq(f.outbox[1].gold,0); eq(f.outbox[1].stacks,1); f.ack(); eq(f.wallet,10000)
end)
test("automatic gold and empty material sweeps share the one-copper boundary",function()
    for _,mats in ipairs({false,true}) do
        for _,balance in ipairs({10030,10031}) do
            local f=alt(mats); f.wallet=balance; f.advance(9)
            eq(#f.outbox,balance==10031 and 1 or 0)
            if #f.outbox==1 then eq(f.outbox[1].gold,1); f.ack(); eq(f.wallet,10000) end
        end
    end
end)
test("Forever realm ID unlocks named roles on two characters with no realm name",function()
    local f=fixture(); f.env.ForeverGoblinMailerDB=nil; f.env.GetRealmName=nil
    f.env.GetRealmID=function() return 74 end
    f.env.SlashCmdList.FOREVERGOBLINMAILER("")
    eq(f.M.desk.network,"Realm ID 74 / Alliance"); assert(not f.button("Register this character").block)
    f.click("Register this character"); f.click("Confirm assignment")
    local scope=f.M.context(); eq(scope.roles.main.name,"Juniper Silver")
    f.guid="char-tailor"; f.player="Thimble Blue"; eq(f.M.context(),scope)
    f.env.SlashCmdList.FOREVERGOBLINMAILER(""); f.click("Tailoring"); f.click("Register this character"); f.click("Confirm assignment")
    eq(scope.roles.tailor.name,"Thimble Blue")
    f.env.GetRealmID=function() return 75 end; assert(f.M.context()~=scope)
    f.env.GetRealmID=function() return 74 end; f.faction="Horde"; assert(f.M.context()~=scope)
end)
test("name-only address books retain roles, rules, holds and preferences when IDs appear",function()
    local f=fixture(); local old,prefs=f.M.context()
    old.roles.main.name="Existing Main"; old.rules[2592]="keep"; prefs.reserveGold=4; prefs.pending={gold=12}
    f.env.GetNormalizedRealmName=function() return "Fixture" end
    f.env.GetRealmName=function() return " " end; f.env.GetRealmID=function() return 74 end
    local now,after=f.M.context(); eq(now,old); eq(after,prefs); eq(after.pending.gold,12)
    f.env.GetNormalizedRealmName=nil; f.guid="other-alt"
    eq(f.M.context(),old); eq(old.rules[2592],"keep"); eq(old.roles.main.name,"Existing Main")
end)
test("public GUID and native realm ID fallbacks never use player surnames or restricted results",function()
    local f=fixture(); f.env.GetRealmName=nil; f.env.GetNormalizedRealmName=nil
    f.env.GetRealmID=function() error("unavailable") end; f.env.GetNativeRealmID=function() return 80 end
    local saved=f.M.context(); eq(saved.realmID,80)
    f.env.GetNativeRealmID=function() return -1 end; f.guid="Player-80-00ABCD"
    eq(f.M.context(),saved)
    local hidden={}; f.env.issecretvalue=function(v) return v==hidden end
    f.env.GetRealmID=function() return hidden end; f.env.GetRealmName=function() return hidden end
    f.guid="invalid"; local scope,_,_,why=f.M.context(); eq(scope,nil); assert(why:find("realm ID",1,true))
    f.env.GetNormalizedRealmName=function() return "NamedRealm" end; assert(f.M.context())
end)
test("an ID-only login recovers a uniquely owned legacy table and leaves ambiguous data intact",function()
    local f=fixture(); f.guid="Player-79-A1"; local old=f.M.context()
    f.guid="Player-79-B2"; f.env.GetRealmName=nil
    eq(f.M.context(),old); eq(old.realmID,79)
    old.realmID=nil
    local realms=f.env.ForeverGoblinMailerDB.realms
    local duplicate={characters={["Player-79-C3"]={}},roles={},rules={}}
    realms["Other/Alliance"]=duplicate
    local selected,_,_,why=f.M.context(); eq(selected,nil); assert(why:find("Multiple saved",1,true))
    eq(realms["Fixture/Alliance"],old); eq(realms["Other/Alliance"],duplicate)
end)
test("later player identity updates recover an open desk without a reload",function()
    local f=fixture(); f.env.ForeverGoblinMailerDB=nil; f.env.GetRealmName=nil
    f.env.SlashCmdList.FOREVERGOBLINMAILER("")
    assert(f.button("Register this character").block)
    f.env.GetNativeRealmID=function() return 42 end
    f.listener.scripts.OnEvent(f.listener,"UNIT_NAME_UPDATE","player")
    eq(f.M.desk.network,"Realm ID 42 / Alliance"); assert(not f.button("Register this character").block)
end)
test("the opt-in evidence matches an acknowledged physical stack in a second character's inbox",function()
    local f=fixture(); f.env.SlashCmdList.FOREVERGOBLINMAILER("check"); local check=f.scope.deliveryCheck
    eq(#f.outbox,0); eq(#check.letters,0); f.item(1,2589,{stackCount=4}); openDesk(f)
    f.click("Route my bags"); f.click("Send 1 parcel"); f.advance(1)
    local letter=check.letters[1]; eq(letter.before,40000); eq(letter.gold,0); eq(letter.postage,30)
    eq(letter.accepted,nil); assert(f.outbox[1].subject:find("[FGM ",1,true)); f.ack(); assert(letter.accepted)
    eq(letter.afterAck,39970); eq(letter.inboxMatched,nil)
    local receiver=fixture(); receiver.env.ForeverGoblinMailerDB=f.env.ForeverGoblinMailerDB
    receiver.guid="char-tailor"; receiver.player="Thimble Blue"; receiver.env.GetInboxNumItems=function() return 2,2 end
    receiver.env.GetInboxHeaderInfo=function(i) return nil,nil,"Juniper Silver",i==1 and "unrelated" or letter.subject,0,0,30,1,false,false end
    local count=3; receiver.env.GetInboxItem=function(i,slot) assert(i==2); if slot==1 then return "Cloth",2589,0,count end end
    openDesk(receiver); eq(letter.inboxMatched,nil)
    count=4; receiver.listener.scripts.OnEvent(receiver.listener,"MAIL_INBOX_UPDATE"); assert(letter.inboxMatched)
    eq(#receiver.outbox,0); eq(#receiver.M.receipts,0)
end)
test("the evidence recorder is opt-in, scoped, bounded and never accepts a returned or COD letter",function()
    local f=goldDesk(10031); f.click("Send 1 parcel"); assert(not f.outbox[1].subject:find("FGM",1,true))
    f.ack(); f.M.check.start(); local check=f.scope.deliveryCheck; f.wallet=10031
    f.M.review("gold"); f.M.dispatch(); local l=check.letters[1]; f.ack()
    eq(l.gold,1); eq(l.afterAck,10000); f.M.check.stop(); eq(f.M.check.active(check),false)
    f.guid="char-main"; f.player="Juniper Silver"
    f.env.GetInboxNumItems=function() return 1 end; f.env.GetInboxItem=function() end
    local cod,returned=1,false
    f.env.GetInboxHeaderInfo=function() return nil,nil,l.sender,l.subject,1,cod,30,nil,false,returned end
    f.M.check.observeInbox(); eq(l.inboxMatched,nil)
    cod,returned=0,true; f.M.check.observeInbox(); eq(l.inboxMatched,nil)
    returned=false; f.M.check.observeInbox(); assert(l.inboxMatched)
    f.M.check.start(); check=f.scope.deliveryCheck
    for i=1,8 do check.letters[i]={} end
    assert(not f.M.check.active(check)); f.M.check.start(); f.advance(7201); assert(not f.M.check.active(f.scope.deliveryCheck))
end)
print(("%d scenarios passed"):format(passed))
