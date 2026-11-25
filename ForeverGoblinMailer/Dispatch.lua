local _, M = ...
local B = M.box
local run, countdown
M.status = "Visit the address book to register your characters."
M.receipts = {}

local function say(message)
    M.status = message
    if M.refresh then M.refresh() end
end
M.say = say

function M.cancelAuto()
    countdown = nil
end

function M.activity()
    return run, countdown and math.max(0, math.ceil(countdown.deadline - GetTime()))
end

local function stop(message)
    run, M.preview = nil, nil
    M.cancelAuto()
    say(message)
end

function M.cancel()
    local pending = run and run.phase == "sending"
    stop(pending and "Queue stopped. The submitted parcel may still arrive. Check delivery before clearing the hold."
        or "Stopped. Any unsent attachments are in the native draft.")
end

function M.busy() return run ~= nil end

local function contextFor(mode)
    if not M.open or not B.available() then return nil, "Open the mailbox outside combat." end
    local scope, prefs, guid, problem = M.context()
    if not scope then return nil, problem end
    if prefs.pending then return nil, "A previous send is unconfirmed. Check the recipient, then open Activity." end
    local main = M.member(scope, "main")
    if not main then return nil, "Register your main in the address book first." end
    local alt = main.guid ~= guid
    if mode == "route" or mode == "auction" then
        if alt then return nil, "This action is for the enrolled main." end
    elseif mode == "gold" or mode == "materials" then
        if not alt or not M.isProfession(scope, guid) then return nil, "This action is for an enrolled profession alt." end
    else return nil, "Unknown mail action." end
    return {scope=scope, prefs=prefs, guid=guid, main=main, alt=alt}
end

local function quoteGoldLetter(plan)
    local amount, reason = B.goldQuote(plan.reserve)
    plan.goldAmount, plan.goldReason = amount, reason
    plan.parcels[1] = amount and amount > 0 and plan.goldLetter or nil
end

local function build(mode, sweep)
    M.preview = nil
    local ctx, why = contextFor(mode)
    if not ctx then return nil, why end
    local clean, reason = B.compose()
    if not clean then return nil, reason end
    local plan
    if mode == "gold" then plan = {parcels={}, held={}, stacks=0, mode=mode}
    else plan = M.plan(B.scan(), mode, ctx.scope, ctx.guid, B.limit(), B.price) end
    plan.sweep = ctx.alt and (mode == "gold" or sweep == true)
    plan.alt, plan.guid, plan.prefs, plan.scope = ctx.alt, ctx.guid, ctx.prefs, ctx.scope
    plan.reserve = M.reserve(ctx.prefs)
    if #plan.parcels == 0 and plan.sweep then
        plan.goldLetter = {guid=ctx.main.guid, name=ctx.main.name, roles={main=true}, items={}}
        quoteGoldLetter(plan)
    end
    M.preview = plan
    return plan
end

function M.review(mode, sweep)
    M.cancelAuto()
    if run then return say("Finish or stop the current queue first.") end
    local ok, plan, reason = pcall(build, mode, sweep)
    if not ok then M.preview = nil; return say("The client could not read the mail or bag state. Retry the review.") end
    if not plan then return say(reason) end
    say(plan.goldReason or ("%d parcel(s), %d stack(s), %d held."):format(#plan.parcels, plan.stacks, #plan.held))
    return plan
end

local function schedule(r, delay, action)
    C_Timer.After(delay, function()
        if run ~= r then return end
        local ok = pcall(action, r)
        if not ok then stop("The client interrupted this action. Inspect the native draft and delivery status.") end
    end)
end

local function stillRouted(r)
    local ctx = contextFor(r.plan.mode)
    if not ctx or ctx.guid ~= r.plan.guid then return false end
    for role in pairs(r.parcel.roles) do
        local member = M.member(ctx.scope, role)
        if not member or member.guid ~= r.parcel.guid or member.name ~= r.parcel.name then return false end
    end
    return true
end

local function send(r)
    if not stillRouted(r) or not B.draftMatches(r.parcel, r.subject, 0) or not B.matches(r.parcel, #r.parcel.items) then
        return stop("The address, draft or attachments changed. Inspect the native draft.")
    end
    local postage = GetSendMailPrice()
    local wallet = math.min(r.budget, GetMoney())
    local copper = M.payment(wallet, postage, r.plan.alt, r.plan.sweep and r.index == #r.plan.parcels, r.plan.reserve)
    if not copper then return stop("The postage quote or available balance cannot cover this parcel and its reserve.") end
    if r.plan.goldLetter and copper ~= r.plan.goldAmount then return stop("The gold amount changed. Review the new total before sending.") end
    if #r.parcel.items == 0 and copper == 0 then return stop("No surplus after postage and your reserve.") end
    r.cost, r.phase = postage + copper, "sending"
    r.plan.prefs.pending = {recipient=r.parcel.name, gold=copper, stacks=#r.parcel.items, postage=postage}
    say(("Awaiting confirmation for parcel %d/%d to %s."):format(r.index, #r.plan.parcels, r.parcel.name))
    M.check.submitting(r, copper, postage)
    local ok, reason = B.submit(r.parcel, r.subject, copper, postage, r.plan.alt, r.plan.reserve)
    if not ok then r.plan.prefs.pending = nil; return stop(reason) end
    local sentIndex = r.index
    schedule(r, 30, function()
        if r.phase == "sending" and r.index == sentIndex then
            stop("No send confirmation. Check delivery before clearing the hold in Activity.")
        end
    end)
end

local function attachNext(r)
    if not stillRouted(r) or not B.draftMatches(r.parcel, r.subject, 0) then
        return stop("The draft changed or the client requires attention. Inspect the native mail window.")
    end
    if not B.matches(r.parcel, r.attached) then
        if r.waitUntil and GetTime() < r.waitUntil then return schedule(r, .1, attachNext) end
        return stop("Native attachments did not match the review. Inspect the draft.")
    end
    r.waitUntil = nil
    if r.attached == #r.parcel.items then return send(r) end
    local nextIndex = r.attached + 1
    local ok, reason = B.attach(r.parcel.items[nextIndex], nextIndex)
    if not ok then return stop(reason) end
    r.attached, r.waitUntil = nextIndex, GetTime() + 3
    schedule(r, .12, attachNext)
end

local function beginParcel(r)
    r.parcel = r.plan.parcels[r.index]
    if not stillRouted(r) then return stop("The enrolled recipient changed. Review again.") end
    if #r.parcel.items == 0 then
        local amount = M.payment(math.min(r.budget, GetMoney()), GetSendMailPrice(), true, true, r.plan.reserve)
        if not amount or amount == 0 then return stop("No surplus after postage and your reserve.") end
    end
    r.subject = ("Goblin Mail / %s %d of %d"):format(r.plan.mode, r.index, #r.plan.parcels)
    r.subject = M.check.prepare(r, r.subject)
    local ok, reason = B.begin(r.parcel, r.subject)
    if not ok then return stop(reason) end
    r.phase, r.attached, r.waitUntil = "attaching", 0, nil
    attachNext(r)
end

function M.dispatch()
    local plan = M.preview
    if run or not plan then return end
    if plan.goldLetter then
        local previous = plan.goldAmount
        quoteGoldLetter(plan)
        if plan.goldReason then return say(plan.goldReason) end
        if plan.goldAmount ~= previous then return say("The gold amount changed. Check the new total before sending.") end
    end
    if #plan.parcels == 0 then return end
    M.cancelAuto()
    run = {plan=plan, index=1, budget=GetMoney()}
    M.preview = nil
    if not pcall(beginParcel, run) then stop("The client interrupted preparation. Inspect the native draft.") end
end

function M.event(event)
    if event == "MAIL_SHOW" then
        if M.open then return end
        M.open = true
        say("Choose a route to review your bags.")
        local scope, prefs, guid = M.context()
        local main = scope and M.member(scope, "main")
        if not main or guid == main.guid or not M.isProfession(scope, guid) or prefs.auto == false then return end
        if prefs.pending then return say("Previous send unconfirmed. Check delivery and open Activity.") end
        local delay = M.delay(prefs)
        local ticket = {deadline=GetTime() + delay}
        countdown = ticket
        say(("Return to %s in %d seconds. Select Stop to cancel."):format(main.name, delay))
        C_Timer.After(delay, function()
            if countdown ~= ticket or not M.open or run then return end
            local mode = prefs.withMats and "materials" or "gold"
            if M.review(mode, true) then M.dispatch() end
        end)
    elseif (event == "PLAYER_MONEY" or event == "MAIL_SEND_INFO_UPDATE") and M.preview and M.preview.goldLetter and not run then
        quoteGoldLetter(M.preview)
        say(M.preview.goldReason or "Check the current gold amount before sending.")
    elseif event == "MAIL_SEND_SUCCESS" and run and run.phase == "sending" then
        local r = run
        M.check.accepted(r)
        local receipt = r.plan.prefs.pending
        if type(receipt) == "table" then
            receipt.mode, receipt.items = r.plan.mode, r.parcel.items
            table.insert(M.receipts, 1, receipt)
            if #M.receipts > 20 then table.remove(M.receipts) end
        end
        r.plan.prefs.pending = nil
        r.budget, r.index = r.budget - r.cost, r.index + 1
        if r.index > #r.plan.parcels then return stop(("%d parcel(s) accepted by the mail server."):format(r.index - 1)) end
        r.phase = "between"
        say(("Parcel %d accepted. Preparing the next parcel."):format(r.index - 1))
        schedule(r, .5, beginParcel)
    elseif event == "MAIL_FAILED" and run then
        -- This general event also covers inbox actions. Preserve an in-flight hold.
        stop("Mail failed. Check the native draft and delivery status before trying again.")
    elseif event == "MAIL_LOCK_SEND_ITEMS" and run then
        stop("The client requires item confirmation. Inspect the native draft.")
    elseif event == "MAIL_CLOSED" or event == "PLAYER_REGEN_DISABLED" then
        if event == "MAIL_CLOSED" then M.open = false end
        if run or M.preview or countdown then M.cancel() end
    end
end
