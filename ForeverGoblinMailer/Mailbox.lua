local _, M = ...
local B = {}
M.box = B

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

function B.limit()
    local limit = ATTACHMENTS_MAX_SEND
    if type(limit) == "number" and limit >= 1 and limit <= 100 then return math.floor(limit) end
end

function B.available()
    return MailFrame and MailFrame:IsVisible() and not InCombatLockdown()
        and SendMailFrame and SendMailNameEditBox and SendMailSubjectEditBox and SendMailBodyEditBox
        and SendMailMoney and SendMailCODButton and SendMailSendMoneyButton
        and MoneyInputFrame_GetCopper and MoneyInputFrame_SetCopper and GetSendMailPrice
        and HasSendMailItem and GetSendMailItem and GetSendMailItemLink and GetCursorInfo
        and SendMail and B.limit()
        and C_Mail and C_Mail.IsCommandPending and C_Container and C_Item and ItemLocation
        and C_Timer and C_Timer.After and MailFrameTab_OnClick and ClickSendMailItemButton
end

function B.compose()
    if not B.available() then return nil, "Open a mailbox outside combat on WoW Forever." end
    if C_Mail.IsCommandPending() or GetCursorInfo() then return nil, "Finish the current mail or cursor action." end
    if (OpenMailFrame and OpenMailFrame:IsShown()) or SendMailFrame.sendMode == "reply" then
        return nil, "Finish your open letter or reply first."
    end
    if SendMailNameEditBox:GetText() ~= "" or SendMailSubjectEditBox:GetText() ~= ""
        or SendMailBodyEditBox:GetText() ~= "" or MoneyInputFrame_GetCopper(SendMailMoney) ~= 0
        or SendMailCODButton:GetChecked() then return nil, "Your current draft is in use." end
    for i = 1, B.limit() do
        if HasSendMailItem(i) then return nil, "There are already attachments in your draft." end
    end
    return true
end

local function copperValue(fn)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn)
    if ok and not secret(value) and type(value) == "number" and value >= 0
        and value < math.huge and value == math.floor(value) then return value end
end

-- Read a gold-only estimate from an empty native draft. Nil is an unknown quote,
-- while zero is a known balance that cannot send any gold.
function B.goldQuote(reserve)
    local wallet = copperValue(GetMoney)
    local clean, reason
    if M.open then clean, reason = B.compose() end
    if not clean then return nil, reason or "Visit a mailbox for a postage quote.", wallet end
    local postage = copperValue(GetSendMailPrice)
    if not wallet or not postage then return nil, "Waiting for a wallet balance and postage quote.", wallet, postage end
    local amount = M.payment(wallet, postage, true, true, reserve) or 0
    return amount, amount == 0 and "No surplus after postage and your reserve." or nil, wallet, postage
end

local function itemKey(link)
    return type(link) == "string" and link:match("|H(item:[^|]+)|h") or nil
end

function B.read(bag, slot)
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info then return end
    local item = {bag = bag, slot = slot, name = "Bag " .. bag .. ", slot " .. slot}
    if secret(info) or secret(info.itemID) or secret(info.hyperlink) or secret(info.stackCount)
        or secret(info.isLocked) or secret(info.isBound) or secret(info.hasLoot) then
        item.block = "Restricted item"
        return item
    end
    item.id, item.link, item.count = info.itemID, info.hyperlink, info.stackCount
    if not secret(info.iconFileID) then item.icon = info.iconFileID end
    item.key = itemKey(item.link)
    if info.isLocked ~= false or info.isBound ~= false or info.hasLoot then
        item.block = "Locked, bound or contains loot"
    end
    if not item.key or not item.id or not item.count then item.block = item.block or "Item data pending"; return item end
    local details = {C_Item.GetItemInfo(item.link)}
    if not details[1] or not details[12] or not details[13] then item.block = item.block or "Item data pending"; return item end
    item.name, item.quality, item.class, item.sub, item.reagent = details[1], details[3], details[12], details[13], details[17]
    if item.block then return item end
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
    item.guid = C_Item.GetItemGUID(loc)
    if secret(item.guid) or not item.guid then item.block = "Stack identity unavailable"
    elseif not quest or quest.isQuestItem ~= false or (quest.questID or 0) > 0 or quest.isActive or item.class == 12 then item.block = "Quest item"
    elseif details[14] ~= 0 and details[14] ~= 2 and details[14] ~= 3 then item.block = "Restricted binding"
    elseif C_Item.CanBeRefunded(loc) then item.block = "Refundable item"
    elseif C_Container.GetContainerItemEquipmentSetInfo(bag, slot) then item.block = "Saved equipment set"
    end
    return item
end

function B.scan()
    local items = {}
    local function scanBag(bag)
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local item = B.read(bag, slot)
            if item then items[#items + 1] = item end
        end
    end
    for bag = 0, NUM_BAG_SLOTS do scanBag(bag) end
    if (NUM_REAGENTBAG_SLOTS or 0) > 0 and Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
        and Enum.BagIndex.ReagentBag > NUM_BAG_SLOTS then scanBag(Enum.BagIndex.ReagentBag) end
    return items
end

function B.price(item)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.GetAuctionPriceByItemLink then
        local ok, amount = pcall(api.GetAuctionPriceByItemLink, "ForeverGoblinMailer", item.link)
        if ok and type(amount) == "number" then return amount end
    end
end

function B.attach(expected, index)
    if GetCursorInfo() or HasSendMailItem(index) then return nil, "Cursor or attachment slot is occupied." end
    local now = B.read(expected.bag, expected.slot)
    if not now or now.block or now.guid ~= expected.guid or now.key ~= expected.key or now.count ~= expected.count then
        return nil, "A reviewed stack changed. Review your bags again."
    end
    C_Container.PickupContainerItem(now.bag, now.slot)
    local kind, id, link = GetCursorInfo()
    if kind ~= "item" or id ~= expected.id or itemKey(link) ~= expected.key then
        return nil, "Pickup could not be verified. Check your cursor."
    end
    ClickSendMailItemButton(index)
    if GetCursorInfo() then return nil, "Attachment was refused. Check your cursor and native draft." end
    return true
end

function B.matches(parcel, count)
    for index = 1, B.limit() do
        local occupied = HasSendMailItem(index)
        if index <= count then
            if not occupied then return false end
            local _, id, _, quantity = GetSendMailItem(index)
            local expected = parcel.items[index]
            if id ~= expected.id or quantity ~= expected.count or itemKey(GetSendMailItemLink(index)) ~= expected.key then return false end
        elseif occupied then return false end
    end
    return true
end

function B.draftMatches(parcel, subject, copper, body, allowPending)
    return B.available() and SendMailFrame:IsVisible() and SendMailFrame.sendMode ~= "reply"
        and not (SendMailFrameLockSendMail and SendMailFrameLockSendMail:IsShown())
        and (allowPending or not C_Mail.IsCommandPending()) and not GetCursorInfo()
        and SendMailNameEditBox:GetText() == parcel.name and SendMailSubjectEditBox:GetText() == subject
        and SendMailBodyEditBox:GetText() == (body or "") and MoneyInputFrame_GetCopper(SendMailMoney) == copper
        and not SendMailCODButton:GetChecked() and SendMailSendMoneyButton:GetChecked()
end

function B.begin(parcel, subject, body)
    local ok, reason = B.compose()
    if not ok then return nil, reason end
    if not SendMailFrame:IsVisible() then MailFrameTab_OnClick(nil, 2) end
    ok, reason = B.compose()
    if not ok then return nil, reason end
    SendMailNameEditBox:SetText(parcel.name)
    SendMailSubjectEditBox:SetText(subject)
    if body ~= "" and body then SendMailBodyEditBox:SetText(body) end
    return true
end

function B.affords(copper, postage, reserve)
    local price, wallet = copperValue(GetSendMailPrice), copperValue(GetMoney)
    return price == postage and wallet and wallet >= copper + postage + reserve
end

-- Use the same visible money editor that Blizzard's own Send button reads.
-- Only the player's native click commits positive money or opens a secure prompt.
function B.fillGold(copper)
    local ok = pcall(MoneyInputFrame_SetCopper, SendMailMoney, copper)
    if not ok then return end
    if MoneyInputFrame_GetCopper(SendMailMoney) == copper then return true end
    local frame = SendMailMoney
    if frame.goldOnly or not (frame.gold and frame.silver and frame.copper) then return end
    local values = {math.floor(copper/10000), math.floor(copper/100)%100, copper%100}
    local boxes = {frame.gold, frame.silver, frame.copper}
    for _, box in ipairs(boxes) do
        if not box:IsVisible() or not box.SetNumber then return end
    end
    for i, box in ipairs(boxes) do box:SetNumber(values[i]) end
    return MoneyInputFrame_GetCopper(frame) == copper
end

function B.submitItems(r)
    if not B.draftMatches(r.parcel, r.subject, 0, r.body) or not B.matches(r.parcel, #r.parcel.items)
        or not B.affords(0, r.postage, r.plan.alt and r.plan.reserve or 0) then
        return nil, "Draft, postage or wallet changed. Review the material parcel again."
    end
    if (GetSendMailMoney and copperValue(GetSendMailMoney) ~= 0) or (GetSendMailCOD and copperValue(GetSendMailCOD) ~= 0) then
        return nil, "The native draft has a money or COD amount. Inspect it before sending."
    end
    SendMail(r.parcel.name, r.subject, r.body)
    return true
end
