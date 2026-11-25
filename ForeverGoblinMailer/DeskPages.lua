local _, M = ...
local U = M.desk
U.pages = {}
U.nav = {
    {"desk","Mail desk","Review and send"},
    {"book","Address book","Characters and roles"},
    {"rules","Routing rules","Items and auction floor"},
    {"returns","Gold returns","Balance and timing"},
    {"activity","Activity","Receipts and holds"},
    {"look","Appearance","Style and placement"},
}
local purpose = {
    main="Receives gold and returned materials from profession alts.",
    auction="Receives valuable sale stock and items assigned to auction.",
    tailor="Receives cloth and tailoring ingredients.", enchanter="Receives dust, essences and enchanting supplies.",
    alchemist="Receives herbs and alchemy ingredients.", smith="Receives bars and smithing ingredients.",
    engineer="Receives engineering parts and recipe ingredients.", leatherworker="Receives leather, hides and other working materials.",
    cook="Receives meat, fish and cooking ingredients.", miner="Receives recognized ores for smelting.",
    herbalist="Available for herb overrides and applicable recipe ingredients.", skinner="Available for your hide and leather overrides.",
    fisher="Receives applicable fishing ingredients and explicit item rules.", firstaid="Receives applicable first-aid ingredients and cloth overrides.",
}
local modes = {{"route","Route my bags","Sort profession materials and auction stock by recipient."},
    {"auction","Auction stock only","Review eligible stock for your auction character."},
    {"materials","Materials to main","Review transferable ingredients for your main."},
    {"gold","Gold to main","Review the surplus after postage and your reserve."}}
local function member(role)
    return U.scope and M.member(U.scope,role)
end
local function address(role)
    if not U.scope then return "Waiting for character identity" end
    local who=member(role)
    return who and who.name or "Unassigned"
end
local function named()
    return M.currentName() or "Full name unavailable"
end
local function option(title,desc,action,icon,block,selected,tag)
    return {title=title,desc=desc,action=action,icon=icon,block=block,selected=selected,tag=tag}
end
local function modeReason(mode)
    local main=member("main")
    if not U.scope then return U.identityProblem end
    if M.busy() then return "A parcel queue is active." end
    if U.prefs.pending then return "Check the delivery hold in Activity." end
    if not main then return "Register Main in the address book." end
    if mode=="route" or mode=="auction" then
        if main.guid~=U.guid then return "Available on "..main.name.."." end
        if mode=="auction" and not member("auction") then return "Assign an Auction alt in the address book." end
    elseif main.guid==U.guid or not M.isProfession(U.scope,U.guid) then return "Available on an enrolled profession alt." end
    if not M.open then return "Visit a mailbox to review your bags." end
end

local function openItem(item)
    U.state.itemText=tostring(item.id)
    U.state.ruleID=item.id
    U.state.chosenRule=(U.scope and U.scope.rules[item.id]) or "default"
    U.navigate("rules",true)
end

local function itemTile(it,why)
    local icon=it.icon
    if not icon and it.id then local _,i=U.item(it.id); icon=i end
    local desc=why or "Route chosen in this review"
    if it.quote then desc=desc.."  •  "..M.money(it.quote).." each" end
    local opt=option((it.name or "Unknown stack")..(it.count and ("  ×"..it.count) or ""),desc,
        it.id and function() openItem(it) end,icon or U.icons.missing)
    opt.small,opt.iconSize=true,26
    opt.tip=desc..(it.id and ("\nItem #"..it.id.." in bag "..(it.bag or "?")..", slot "..(it.slot or "?")..". Click to inspect or change its routing rule.") or "")
    return opt
end

local function manifest(plan)
    U.section("Parcel manifest",("%d parcel(s)  •  %d stack(s) for mailing  •  %d held in bags"):format(#plan.parcels,plan.stacks,#plan.held))
    if plan.goldLetter then
        U.text(plan.goldReason or ("Gold for "..plan.goldLetter.name.."  •  "..M.money(plan.goldAmount)),14,plan.goldReason and "warn" or "ink",8,true)
    end
    for i,p in ipairs(plan.parcels) do
        local roles={}
        for _,r in ipairs(M.roles) do if p.roles[r[1]] then roles[#roles+1]=r[2] end end
        U.grid({{title=p.name,desc=("Parcel %d of %d   •   %s"):format(i,#plan.parcels,table.concat(roles,", ")),
            icon=U.icons.parcel,selected=true,tag=(plan.sweep and i==#plan.parcels) and ("Any surplus goes on this letter after postage and a "..M.money(plan.reserve).." reserve.") or nil}})
        local rows={}
        for _,it in ipairs(p.items) do rows[#rows+1]=itemTile(it,(it.routeBasis or "Route").."  /  "..(M.labels[it.routeRole] or "Main")) end
        U.grid(rows,2)
    end
    if #plan.held>0 then
        U.section("Held in bags","Each reason comes from this bag scan. Select an identified item to inspect its rule.")
        local rows={}
        for _,held in ipairs(plan.held) do rows[#rows+1]=itemTile(held.item,held.reason) end
        U.grid(rows,2)
    end
end

U.pages.desk=function()
    local r=M.activity()
    local plan=M.preview or (r and r.plan)
    if not member("main") then
        U.grid({option("Register your main","Open the address book on your main to give return parcels a destination.",
            function() U.navigate("book",true) end,U.icons.main)})
    end
    if plan then
        manifest(plan)
        U.section("Other dispatch actions","Selecting another review replaces the current manifest.")
    else U.section("Prepare a dispatch","Choose a review. The Send button becomes available when a parcel is ready.") end
    local rows={}
    for _,entry in ipairs(modes) do
        local mode=entry[1]
        local desc=entry[3]
        if mode=="materials" and U.prefs.auto~=false then desc=desc.." Surplus gold rides in the final parcel." end
        rows[#rows+1]=option(entry[2],desc,function()
            U.offsets.desk=0
            U.scroll:SetVerticalScroll(0)
            M.review(mode,mode=="materials" and U.prefs.auto~=false)
        end,U.icons[mode],modeReason(mode),plan and plan.mode==mode)
    end
    U.grid(rows,2)
    if not plan then
        U.section("Delivery addresses","These assignments apply on this realm and faction. Select one to inspect it.")
        local destinations={}
        for _,entry in ipairs(M.roles) do
            local role=entry[1]
            if role=="main" or role=="auction" or member(role) then
                destinations[#destinations+1]=option(entry[2],address(role),function()
                    U.state.role=role; U.navigate("book",true)
                end,U.icons[role])
            end
        end
        U.grid(destinations,2)
    end
end

local function register(role, remove)
    local who=member(role)
    local name=M.currentName()
    if not name or U.locked() then return end
    local key=(remove and "remove/" or "enroll/")..role.."/"..name.."/"..(who and who.guid or "")
    local message=remove and ("Remove "..name.." from "..M.labels[role].."?") or ("Assign "..M.labels[role].." to "..name.."?")
    U.confirmAction(key,message,function()
        if remove then
            if who and who.guid==U.guid then U.scope.roles[role]=nil; U.change("Removed "..name.." from "..M.labels[role]..".") end
        else
            local ok,why=M.enroll(U.scope,U.guid,role,name)
            if ok then U.change("Registered "..name.." for "..M.labels[role]..".") else M.say(why) end
        end
    end)
end

U.pages.book=function()
    local role=U.state.role or "main"
    local who=member(role)
    local canRemove=who and who.guid==U.guid
    local name=M.currentName()
    local key=role.."/"..(name or "").."/"..(who and who.guid or "")
    U.section(M.labels[role].." assignment",purpose[role])
    U.text(U.network and ("Mail network  •  "..U.network) or U.identityProblem,12,"sub",6)
    U.grid({{title=address(role),desc="Current recipient  •  Your character is "..named(),icon=U.icons[role],selected=true}})
    local block=U.locked() or (not name and "The native full name is unavailable. Try again after login.")
    local enroll=option(U.confirm=="enroll/"..key and "Confirm assignment" or "Register this character",
            (who and who.guid~=U.guid) and ("Replace "..who.name.." with "..named()..".") or ("Assign "..named().." as "..M.labels[role].."."),
            function() register(role,false) end,nil,block)
    enroll.primary=true
    U.grid({enroll,
        option(U.confirm=="remove/"..key and "Confirm removal" or "Remove assignment","Release this role from the current character.",
            function() register(role,true) end,nil,block or (not canRemove and "Only its enrolled character can remove it.")),
    },2)
    U.section("All roles","Select a role to inspect its recipient. A character can hold several professions.")
    local rows={}
    for _,entry in ipairs(M.roles) do
        local k=entry[1]
        local row=option(entry[2],address(k),function() U.state.role=k; U.confirm=nil; U.top() end,U.icons[k],nil,k==role)
        row.small,row.iconSize,row.tip=true,26,purpose[k].." Current recipient: "..address(k)..". Click to inspect this assignment."
        rows[#rows+1]=row
    end
    U.grid(rows,U.innerWidth>=590 and 3 or 2)
end

local function lookup()
    local text=M.trim(U.state.itemText)
    local id=tonumber(text:match("^%d+$") or text:match("item:(%d+)"))
    if not id or id<1 or id>2147483647 then return M.say("Enter a positive item ID or paste an item link.") end
    U.state.ruleID=id; U.state.chosenRule=U.scope and U.scope.rules[id] or "default"
    U.confirm=nil; U.top()
end
local function saveFloor()
    if U.locked() then return end
    local n=tonumber(U.state.floorText or M.threshold(U.scope))
    if not n or n<1 or n>1000000 or n~=math.floor(n) then return M.say("Enter a whole auction floor from 1 to 1,000,000 gold per unit.") end
    U.scope.floorGold=n; U.state.floorText=nil; U.change("Auction floor saved at "..n.."g per unit.")
end
local function chooseRule(role)
    U.state.chosenRule=role
    U.confirm=nil
    M.refresh()
end
local function saveRule()
    local id,role=U.state.ruleID,U.state.chosenRule
    if U.locked() or not id or (role~="default" and not M.labels[role]) then return end
    local input=M.trim(U.state.itemText)
    if tonumber(input:match("^%d+$") or input:match("item:(%d+)"))~=id then
        return M.say("Inspect the newly entered item before saving its rule.")
    end
    U.scope.rules[id]=role~="default" and role or nil
    U.change("Saved item #"..id.." as "..(M.labels[role] or "Automatic")..".")
end
U.saveRule=saveRule

U.pages.rules=function()
    local id=U.state.ruleID
    U.section("Inspect an item","See its current rule and recipe uses. Select an item from a manifest or enter its ID here.")
    U.edit("itemText","Item ID or item link","Press Enter or select Inspect item to load its routing details.","",lookup)
    U.grid({option("Inspect item","Load the item and its saved destination.",lookup,U.icons.rules)})
    if id then
        local name,icon=U.item(id)
        local sel=U.state.chosenRule or "default"
        local current=U.scope and U.scope.rules[id]
        local users={}
        for _,k in ipairs(M.recipeOwners[id] or {}) do users[#users+1]=M.labels[k] end
        U.section(name.."  /  #"..id,"Saved rule: "..(M.labels[current] or "Automatic").."   •   Recipe uses: "..(#users>0 and table.concat(users,", ") or "No indexed profession")..".")
        local detail={C_Item.GetItemInfo(id)}
        if detail[12] and U.scope then
            local probe={id=id,link=detail[2],quality=detail[3],class=detail[12],sub=detail[13],reagent=detail[17]}
            local role,reason,basis,price=M.destination(probe,"route",U.scope,M.box.price)
            local target=role and (M.labels[role].."  /  "..address(role)) or "Held in bags"
            U.grid({{title=target,desc=(basis or reason or "Automatic")..(price and ("  •  "..M.money(price).." each") or ""),
                tag="For an eligible stack on your main. The bag scan checks binding and physical state.",icon=icon,selected=true}})
        else U.text("Item details are pending. The current saved rule is shown above.",12,"sub") end
        local row={option("Automatic","Use family, recipe and price rules.",function() chooseRule("default") end,icon,nil,sel=="default"),
            option("Keep in bags","Hold this item on every route.",function() chooseRule("keep") end,U.icons.keep,nil,sel=="keep")}
        for i=2,#M.roles do
            local k=M.roles[i][1]
            row[#row+1]=option(M.labels[k],address(k),function() chooseRule(k) end,U.icons[k],nil,sel==k)
        end
        for _,v in ipairs(row) do v.small=true; v.iconSize=23; v.tip="Select "..v.title.." for item #"..id..". Choose Save item rule to apply." end
        U.grid({option("Save item rule","Apply "..(M.labels[sel] or "Automatic").." to item #"..id.." throughout this realm and faction.",saveRule,nil,U.locked())})
        U.grid(row,U.innerWidth>=590 and 3 or 2)
    end
    local assigned={}
    for key,value in pairs((U.scope and U.scope.rules) or {}) do
        if type(key)=="number" and M.labels[value] then assigned[#assigned+1]=key end
    end
    table.sort(assigned)
    U.section("Saved item rules",#assigned.." explicit rule(s). Select a saved item to edit or return it to Automatic.")
    local saved={}
    for _,key in ipairs(assigned) do
        local rid=key
        local name,icon=U.item(rid)
        local rule=U.scope.rules[rid]
        saved[#saved+1]=option(name,M.labels[rule].."  •  #"..rid,function() openItem({id=rid}) end,icon)
    end
    U.grid(saved,2)
    U.section("Auction pricing","Eligible unbound sale stock uses Auctionator's cached unit price. An explicit Auction rule works without a quote.")
    U.edit("floorText","Minimum gold per unit","Current floor: "..M.threshold(U.scope or {}).."g. Enter a whole number, then save.",M.threshold(U.scope or {}),saveFloor)
    U.grid({option("Save auction floor","Apply the new minimum to future bag reviews.",saveFloor,U.icons.auction,U.locked())})
    U.section("Automatic routing order","1. Check binding, quest, lock and refund status.   2. Apply your item rule.   3. Match material families or recipes.   4. Test the auction floor. Conflicts stay in bags.")
    local families={}
    for _,e in ipairs({{"Cloth","tailor",2589},{"Dust and essences","enchanter",10940},{"Raw herbs","alchemist",765},
        {"Leather and hides","leatherworker",2318},{"Ore","miner",2770},{"Metal bars","smith",2840},
        {"Engineering parts","engineer",4359},{"Cooking ingredients","cook",2672}}) do
        local role,id=e[2],e[3]
        families[#families+1]=option(e[1],M.labels[role].."  /  "..address(role),function() openItem({id=id}) end,U.icons[role])
        families[#families].tip="Default material family. Click to inspect a representative item and any override."
    end
    U.grid(families,2)
end

local function saveReserve()
    if U.locked() then return end
    local n=tonumber(U.state.reserveText or M.reserve(U.prefs)/10000)
    if not n or n~=math.floor(n) or n<1 or n>1000000 then return M.say("The reserve must be a whole amount of at least 1g, up to 1,000,000g.") end
    U.prefs.reserveGold=n; U.state.reserveText=nil; U.change("This character will keep "..n.."g after postage.")
end
U.pages.returns=function()
    local reserve=M.reserve(U.prefs)
    local amount,_,wallet,quote=M.box.goldQuote(reserve)
    local main=member("main")
    local active=main and main.guid~=U.guid and U.scope and M.isProfession(U.scope,U.guid)
    local usable=not U.locked()
    U.section("Gold ledger","Return destination: "..address("main")..". The sender keeps the reserve after paying actual native postage.")
    U.grid({{title=wallet and M.money(wallet) or "Unavailable",desc="Current wallet",icon=U.icons.gold},
        {title=M.money(reserve),desc="Kept by this character",icon=U.icons.keep},
        {title=quote and M.money(quote) or "At the mailbox",desc="Empty-draft postage",icon=U.icons.desk},
        {title=amount and M.money(amount) or "Awaiting a quote",desc="Gold-only return at this quote",icon=U.icons.main}},2)
    U.section("On mailbox open",active and "This character is an enrolled profession alt." or "These choices activate on a profession alt with a different enrolled main.")
    local function toggle(key,value,msg)
        if not usable then return end
        U.prefs[key]=value; U.change(msg)
    end
    local auto,mats=U.prefs.auto~=false,U.prefs.withMats==true
    U.grid({option("Automatic gold  /  "..(auto and "ON" or "OFF"),"Toggle the timed return of surplus gold on this character.",
            function() toggle("auto",not auto,auto and "Automatic gold is off." or "Automatic gold is on for the next visit.") end,U.icons.gold,U.locked(),auto),
        option("Include materials  /  "..(mats and "ON" or "OFF"),"Add eligible bag materials to the automatic return. Gold travels in the final parcel.",
            function() toggle("withMats",not mats,mats and "Automatic trips return gold only." or "Automatic trips include materials.") end,U.icons.materials,U.locked(),mats)},2)
    U.section("Countdown","Choose the time available to cancel before an automatic return.")
    local delays={}
    for _,value in ipairs({8,15,30}) do
        local n=value
        delays[#delays+1]=option(n.." seconds",M.delay(U.prefs)==n and "Current delay" or "Use this delay",
            function() U.prefs.delaySeconds=n; U.change("Countdown set to "..n.." seconds.") end,nil,U.locked(),M.delay(U.prefs)==n)
    end
    U.grid(delays,3)
    U.edit("reserveText","Gold to keep","Personal reserve after postage. Minimum 1g. This also protects material-only trips.",reserve/10000,saveReserve)
    U.grid({option("Save reserve","Apply this gold reserve to future shipments from this character.",saveReserve,U.icons.keep,U.locked())})
end

U.pages.activity=function()
    local pending=U.prefs.pending
    local r=M.activity()
    U.section("Delivery status",M.status or "Ready.")
    if type(pending)=="table" then
        U.grid({{title="Awaiting reconciliation",desc=(pending.recipient or "Unknown recipient").."  •  "..(pending.stacks or 0).." stack(s)  •  "..M.money(pending.gold or 0),
            icon=U.icons.activity,tag=r and "An outgoing parcel is waiting for the server." or "Check the native draft and the receiving inbox before clearing this hold."}})
    end
    local block=U.locked() or (not pending and "There is no delivery hold to clear.")
    U.grid({option(U.confirm=="clear" and "Confirm checked delivery" or "Clear delivery hold","After checking the receipt or inbox, unlock a fresh review.",
        function() U.confirmAction("clear","Confirm only after checking delivery.",function() U.prefs.pending=nil; U.change("Delivery hold cleared.") end) end,nil,block)})
    local check=U.scope and U.scope.deliveryCheck
    local active=M.check.active(check)
    U.section("Two-character delivery check","Optional local record. A marked subject lets the receiving character compare gold and stacks before collecting the letter.")
    U.grid({option(active and "End delivery check" or "Start delivery check",
        active and "Stop marking new letters. Recorded letters can still be matched." or "Mark up to eight outgoing parcels for two hours. Starting a check sends nothing.",
        active and M.check.stop or M.check.start,U.icons.activity,U.locked())})
    if type(check)=="table" and type(check.letters)=="table" then
        local accepted,matched=0,0
        for _,letter in ipairs(check.letters) do
            if letter.accepted then accepted=accepted+1 end
            if letter.inboxMatched then matched=matched+1 end
        end
        U.text(("Marked %d  •  Server accepted %d  •  Inbox matched %d"):format(#check.letters,accepted,matched),13,"ink",8)
    end
    U.section("Accepted parcels","The last 20 server acknowledgements from this login. Each entry shows its destination, postage and contents.")
    if #M.receipts==0 then U.text("No parcels have been acknowledged during this login.",13,"sub") end
    for _,receipt in ipairs(M.receipts) do
        local contents={}
        for _,it in ipairs(receipt.items or {}) do contents[#contents+1]=(it.name or "Item").." ×"..(it.count or 0) end
        U.grid({{title=receipt.recipient,desc=(#contents>0 and table.concat(contents,", ") or "Gold-only letter"),
            tag=("Accepted  •  %s enclosed  •  %s postage"):format(M.money(receipt.gold or 0),M.money(receipt.postage or 0)),icon=U.icons.parcel}})
    end
end

U.pages.look=function()
    local o=U.options()
    local function apply(key,value,info)
        if not U.scope then return end
        o[key]=value
        U.layout(true)
        M.say(info)
    end
    local function choices(key,default,entries)
        local list={}
        for _,e in ipairs(entries) do
            local val,title,help=e[1],e[2],e[3]
            list[#list+1]=option(title,help,function() apply(key,val,title.." applied.") end,nil,
                U.identityProblem,(o[key] or default)==val,(o[key] or default)==val and "Selected" or nil)
            if key=="theme" then list[#list].swatch=val end
        end
        U.grid(list,#list)
    end
    U.section("Desk finish","Your appearance choices apply to every character on this account.")
    choices("theme","parchment",{{"parchment","Parchment","Warm paper and green ink."},{"midnight","Midnight","Pine panels with ivory text."},
        {"contrast","High contrast","Bright text and strong outlines."}})
    U.section("Window size","The desk fits the available screen space at every setting.")
    choices("scale",100,{{85,"85%","Smaller footprint."},{100,"100%","Original size."},{115,"115%","Larger text and controls."}})
    U.section("Row spacing","Choose how much room to leave around icons and descriptions.")
    choices("density","roomy",{{"roomy","Comfortable","More room between actions."},{"compact","Compact","More rows per screen."}})
    U.section("Window position","Drag the illustrated header to save a floating position. Auto-dock keeps the native mailbox beside the desk when space allows.")
    U.grid({option("Dock beside mailbox","Clear the saved floating position and restore automatic placement.",
        function() o.x,o.y=nil,nil; U.layout(true); M.say("Automatic docking restored.") end,U.icons.desk,U.identityProblem,
        o.x==nil and o.y==nil)})
    U.text("Made with <3 by Mini Il - Forever - PvE",12,"sub")
end
