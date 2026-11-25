local _, M = ...
local A = {}
M.check = A
local recent

local function public(value, kind)
    if not (issecretvalue and issecretvalue(value)) and type(value) == kind then return value end
end

function A.active(check)
    return type(check)=="table" and check.recording and type(check.letters)=="table"
        and type(check.untilTime)=="number" and type(check.token)=="string" and GetServerTime
        and GetServerTime() < check.untilTime and #check.letters < 8
end

function A.start()
    local scope, _, _, why = M.context()
    if not scope or M.busy() then return M.say(why or "Finish the current delivery first.") end
    if not GetServerTime then return M.say("The client clock is unavailable.") end
    if A.active(scope.deliveryCheck) then return M.say("Delivery check is recording. Use your normal mail actions.") end
    local now = GetServerTime()
    scope.checkSerial = (scope.checkSerial or 0) + 1
    local _, build = GetBuildInfo()
    scope.deliveryCheck = {recording=true, untilTime=now+7200, started=now, build=build,
        token=now.."-"..scope.checkSerial, letters={}}
    recent = nil
    M.say("Recording the next eight parcels for up to two hours. Check the receiving inbox before collecting them.")
end

function A.stop()
    local scope = M.context()
    if scope and scope.deliveryCheck then scope.deliveryCheck.recording = false end
    M.say("Recording ended. Previously marked letters can still be checked in the receiving inbox.")
end

-- A unique subject identifies just this opted-in letter after a character switch.
-- The observer never submits mail, accepts a prompt or collects an attachment.
function A.prepare(run, subject)
    run.checkLetter = nil
    local check = run.plan.scope.deliveryCheck
    if not A.active(check) then return subject end
    local sender = M.currentName()
    if not sender then return subject end
    subject = subject.." [FGM "..check.token.."."..(#check.letters+1).."]"
    local letter = {subject=subject, sender=sender, recipient=run.parcel.guid, mode=run.plan.mode,
        reserve=run.plan.alt and run.plan.reserve or 0, items={}}
    for _, item in ipairs(run.parcel.items) do
        letter.items[#letter.items+1] = item.id.."x"..item.count
    end
    table.sort(letter.items)
    check.letters[#check.letters+1] = letter
    run.checkLetter = letter
    return subject
end

function A.submitting(run, gold, postage)
    local letter = run.checkLetter
    if letter then
        letter.before = public(GetMoney(), "number")
        letter.gold, letter.postage = gold, postage
    end
end

function A.accepted(run)
    recent = nil
    local letter = run.checkLetter
    if letter then
        letter.accepted = GetServerTime()
        letter.afterAck = public(GetMoney(), "number")
        recent = letter
    end
end

function A.walletChanged()
    if not recent then return end
    if GetServerTime() <= recent.accepted + 5 then
        recent.afterUpdate = public(GetMoney(), "number")
    end
    recent = nil
end

local function inspect(index, letter, sender, money, cod, count, returned)
    if not public(sender,"string") or sender ~= letter.sender or not public(money,"number")
        or money ~= letter.gold or not public(cod,"number") or cod ~= 0
        or (issecretvalue and issecretvalue(returned)) or returned then return end
    if issecretvalue and issecretvalue(count) then return end
    count = count or 0
    if count ~= #letter.items then return end
    local items = {}
    if count > 0 then
        local limit = ATTACHMENTS_MAX_RECEIVE or M.box.limit()
        if not limit then return end
        for slot = 1, limit do
            local _, id, _, quantity = GetInboxItem(index, slot)
            if public(id,"number") and public(quantity,"number") then items[#items+1] = id.."x"..quantity end
        end
    end
    table.sort(items)
    if table.concat(items,",") == table.concat(letter.items,",") then
        letter.inboxMatched = GetServerTime()
    end
end

function A.observeInbox()
    if not M.open or InCombatLockdown() or not GetInboxNumItems or not GetInboxHeaderInfo or not GetInboxItem then return end
    local scope, _, guid = M.context()
    local check = scope and scope.deliveryCheck
    if type(check) ~= "table" or type(check.letters) ~= "table" then return end
    local pending = {}
    for _, letter in ipairs(check.letters) do
        if letter.gold and letter.recipient == guid and not letter.inboxMatched then pending[letter.subject] = letter end
    end
    if not next(pending) then return end
    local loaded = public(GetInboxNumItems(), "number")
    for index = 1, loaded or 0 do
        local _, _, sender, subject, money, cod, _, count, _, returned = GetInboxHeaderInfo(index)
        local letter = public(subject,"string") and pending[subject]
        if letter then inspect(index,letter,sender,money,cod,count,returned) end
    end
end
