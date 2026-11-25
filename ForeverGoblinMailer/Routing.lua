local _, M = ...
-- The Forever client also has legacy materials with a generic trade-goods subclass.
-- Numeric IDs are locale independent. Shared resources can be reassigned by item ID.
local families = {}
local function group(role, ids)
    for _, id in ipairs(ids) do families[id] = role end
end
group("tailor", {2589,2592,4306,4338,14047,14256,14342,3182})
group("enchanter", {10940,10938,10939,10978,10998,11082,11083,11084,11134,11135,11137,
    11138,11139,11174,11175,11176,11177,11178,14343,14344,16202,16203,16204,20725})
group("leatherworker", {783,2318,2319,4232,4234,4235,4304,8169,8170,8171,15412,15414,15415,15416,15417,15419})
group("alchemist", {765,785,2447,2449,2450,2452,2453,3355,3356,3357,3358,3369,
    3818,3819,3820,3821,4625,8831,8836,8838,8839,8845,8846,13463,13464,13465,13466,13467,13468})
group("miner", {2770,2771,2772,2775,2776,3858,7911,10620})
group("smith", {2840,2841,2842,3575,3576,3577,3859,3860,6037,12359,12360,12655})
group("engineer", {4357,4359,4361,4363,4364,4371,4375,4377,4382,4387,4389,10505,10558,10559,10560,15992})
group("cook", {2672,2673,2674,2675,2677,2886,3172,3173,3174,3667,3685,3730,3731,4603,4655,
    5465,5466,5467,5468,5469,5470,5471,5503,5504,6289,6291,6303,6308,6317,6361,6362,7974,
    12037,12184,12202,12203,12204,12205,12206,12207,12208})
local subclass = {[1]="engineer", [5]="tailor", [6]="leatherworker", [8]="cook", [9]="alchemist", [12]="enchanter"}
local auctionClasses = {[2]=true, [4]=true, [9]=true, [15]=true}
local ingredientClasses = {[0]=true, [3]=true, [5]=true, [7]=true, [15]=true}

local function recipeRole(owners, scope)
    if #owners == 1 then return owners[1] end
    local selected, guid
    for _, role in ipairs(owners) do
        local member = M.member(scope, role)
        if member then
            if guid and guid ~= member.guid then return end
            selected, guid = role, member.guid
        end
    end
    return selected
end

local function ruleFor(scope, id)
    local value = scope.rules[id]
    return type(value) == "string" and M.labels[value] and value or nil
end

function M.destination(item, mode, scope, price)
    local manual = ruleFor(scope, item.id)
    if manual == "keep" then return nil, "Keep rule" end
    local family = families[item.id] or (item.class == 7 and subclass[item.sub])
    local owners = (ingredientClasses[item.class] or item.reagent) and M.recipeOwners[item.id]
    local material = family or owners or item.class == 5 or item.class == 7 or item.reagent
    if mode == "materials" then
        if manual == "auction" then return nil, "Reserved for auction" end
        if material or (manual and manual ~= "main") then return "main", nil, "Material return to main" end
        return nil, "Outside material return"
    end
    if manual then
        if mode ~= "auction" or manual == "auction" then return manual, nil, "Your item rule" end
        return nil, "Profession rule"
    end
    local basis = family and "Material family" or "Profession recipe"
    family = family or (owners and recipeRole(owners, scope))
    if family then
        if mode == "route" then return family, nil, basis end
        return nil, "Profession material"
    end
    if material then return nil, "Choose a profession rule" end
    if auctionClasses[item.class] and item.quality and item.quality >= 1 then
        local unitPrice = price and price(item)
        if type(unitPrice) ~= "number" or unitPrice <= 0 then return nil, "No auction quote" end
        if unitPrice >= M.threshold(scope) * 10000 then return "auction", nil, "Auction quote per unit", unitPrice end
        return nil, "Below auction floor", nil, unitPrice
    end
    return nil, "Outside routing rules"
end

function M.plan(items, mode, scope, guid, limit, price)
    local plan = {parcels = {}, held = {}, stacks = 0, mode = mode}
    local groups, order = {}, {}
    for _, item in ipairs(items) do
        local role, reason, basis, quote
        if item.block then reason = item.block else role, reason, basis, quote = M.destination(item, mode, scope, price) end
        item.routeRole, item.routeBasis, item.quote = role, basis, quote
        local member = role and M.member(scope, role)
        if role and not member then reason = "No " .. M.labels[role] .. " address"
        elseif member and member.guid == guid then reason = "Already on destination character"
        elseif member then
            local key = member.guid
            if not groups[key] then groups[key] = {}; order[#order + 1] = key end
            local group = groups[key]
            local parcel = group[#group]
            if not parcel or #parcel.items >= limit then
                parcel = {name = member.name, guid = key, items = {}, roles = {}}
                group[#group + 1] = parcel
            end
            parcel.items[#parcel.items + 1] = item
            parcel.roles[role] = true
            plan.stacks = plan.stacks + 1
        end
        if reason then plan.held[#plan.held + 1] = {item = item, reason = reason} end
    end
    for _, key in ipairs(order) do
        for _, p in ipairs(groups[key]) do plan.parcels[#plan.parcels + 1] = p end
    end
    return plan
end

function M.payment(wallet, postage, alt, sweep, reserve)
    if type(wallet) ~= "number" or type(postage) ~= "number" or postage < 0 then return end
    local spendable = wallet - postage - (alt and math.max(10000, reserve or 10000) or 0)
    if spendable < 0 then return end
    return sweep and spendable or 0
end
