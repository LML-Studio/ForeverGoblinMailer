local _, M = ...
M.roles = {
    {"main", "Main"}, {"auction", "Auction alt"}, {"tailor", "Tailoring"},
    {"enchanter", "Enchanting"}, {"alchemist", "Alchemy"}, {"smith", "Blacksmithing"},
    {"engineer", "Engineering"}, {"leatherworker", "Leatherworking"}, {"cook", "Cooking"},
    {"miner", "Mining"}, {"herbalist", "Herbalism"}, {"skinner", "Skinning"},
    {"fisher", "Fishing"}, {"firstaid", "First Aid"},
}
M.labels = {keep = "Keep in bags"}
for _, entry in ipairs(M.roles) do M.labels[entry[1]] = entry[2] end

function M.trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

function M.address(value)
    local s = M.trim(value)
    if #s > 100 or s:gsub("[ '%-]", ""):find("[%c%d%p]") then
        return nil
    end
    if not s:match("[A-Za-z\128-\255]") then return nil end
    return s
end

function M.currentName()
    if InCombatLockdown() then return end
    local name
    if NameUtil and NameUtil.GetUnmodifiedUnitFullName then
        local ok, value = pcall(NameUtil.GetUnmodifiedUnitFullName,"player")
        if ok then name=value end
    elseif UnitNameUnmodified then
        local first, last = UnitNameUnmodified("player")
        if issecretvalue and (issecretvalue(first) or issecretvalue(last)) then return end
        local constants = Constants and Constants.CharacterNameSeparatorConsts
        if last and last ~= "" then
            if not first or not constants or not constants.CHARACTERNAME_SURNAME_SEPARATOR then return end
            name = first .. constants.CHARACTERNAME_SURNAME_SEPARATOR .. last
        else name = first end
    end
    if issecretvalue and issecretvalue(name) then return end
    return M.address(name)
end

local function tableField(parent, key)
    if type(parent[key]) ~= "table" then parent[key] = {} end
    return parent[key]
end

local function nativeString(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn,...)
    if ok and not (issecretvalue and issecretvalue(value)) and type(value)=="string" and value~="" then return value end
end

local function realmNumber(read)
    if type(read) ~= "function" then return end
    local ok, n = pcall(read)
    if ok and not (issecretvalue and issecretvalue(n)) and type(n) == "number"
        and n > 0 and n < 2147483648 and n == math.floor(n) then return n end
end

local function guidRealm(guid)
    local n = type(guid) == "string" and tonumber(guid:match("^Player%-(%d+)%-%x+$") or "")
    if n and n > 0 and n < 2147483648 then return n end
end

local function hasLegacyRealm(scope, id, guid)
    local owned = false
    for who in pairs(type(scope.characters) == "table" and scope.characters or {}) do
        local home = guidRealm(who)
        if home and id and home ~= id then return false, true end
        if who == guid or (id and home == id) then owned = true end
    end
    return owned
end

-- Keep the original table and key. A numeric realm can reclaim a named address
-- book even when Forever has stopped returning its display name.
local function realmScope(realms, id, name, faction, guid)
    local suffix = "/" .. faction
    local key = (id and ("#" .. id) or name) .. suffix
    local found, ambiguous
    local normalized = name and name:lower():gsub("%s+", "")
    for savedKey, scope in pairs(realms) do
        if type(savedKey) == "string" and savedKey:sub(-#suffix) == suffix and type(scope) == "table" then
            local oldName = scope.realmName or savedKey:sub(1, -#suffix - 1)
            local named = normalized and type(oldName) == "string" and oldName:lower():gsub("%s+", "") == normalized
            local matches
            if id and scope.realmID then
                matches = scope.realmID == id
            elseif named then
                local _, conflicting = hasLegacyRealm(scope, id, guid)
                matches = not conflicting
            elseif not name then
                matches = hasLegacyRealm(scope, id, guid)
            end
            if matches then
                if found and found ~= scope then ambiguous = true end
                found = scope
            end
        end
    end
    if ambiguous then return nil, "Multiple saved address books match this realm. No route has been selected." end
    if not found then
        if realms[key] ~= nil then return nil, "The saved address book has a different realm identity." end
        found = tableField(realms, key)
    end
    if id then found.realmID = id end
    if name then found.realmName = name end
    return found
end

function M.context()
    if InCombatLockdown() then return nil,nil,nil,"Character settings are available after combat." end
    local guid=nativeString(UnitGUID,"player")
    if not guid then return nil,nil,nil,"Waiting for the client's character identity." end
    local realm = M.trim(nativeString(GetRealmName))
    if realm == "" then realm = M.trim(nativeString(GetNormalizedRealmName)) end
    if realm == "" then realm = nil end
    local id = realmNumber(GetRealmID) or realmNumber(GetNativeRealmID) or guidRealm(guid)
    if not id and not realm then return nil,nil,nil,"Waiting for a realm ID or name from the client." end
    local faction=nativeString(UnitFactionGroup,"player")
    if not faction then return nil,nil,nil,"Waiting for the client's faction." end
    if type(ForeverGoblinMailerDB) ~= "table" then ForeverGoblinMailerDB = {} end
    local scope, problem = realmScope(tableField(ForeverGoblinMailerDB, "realms"), id, realm, faction, guid)
    if not scope then return nil,nil,nil,problem end
    tableField(scope, "roles")
    tableField(scope, "rules")
    local prefs = tableField(tableField(scope, "characters"), guid)
    local network = scope.realmName or ("Realm ID " .. tostring(scope.realmID))
    return scope, prefs, guid, nil, network .. " / " .. faction
end

function M.member(scope, role)
    local entry = scope.roles[role]
    if type(entry) == "table" and type(entry.guid) == "string" and M.address(entry.name) then return entry end
end

function M.isProfession(scope, guid)
    for index = 3, #M.roles do
        local entry = M.member(scope, M.roles[index][1])
        if entry and entry.guid == guid then return true end
    end
    return false
end

function M.enroll(scope, guid, role, name)
    name = M.address(name)
    if not name then return nil, "Enter the full address you use in the native mailbox." end
    if not guid or not M.labels[role] or role == "keep" then return nil, "Invalid character or role." end
    for _, r in ipairs(M.roles) do
        local entry = M.member(scope, r[1])
        if entry and entry.guid ~= guid and entry.name:lower() == name:lower() then
            return nil, "That address belongs to another enrolled character."
        end
    end
    -- One verified spelling per character, even when the character holds two professions.
    for _, r in ipairs(M.roles) do
        local entry = M.member(scope, r[1])
        if entry and entry.guid == guid then entry.name = name end
    end
    scope.roles[role] = {guid = guid, name = name}
    return true
end

function M.threshold(scope)
    local value = scope.floorGold
    if type(value) ~= "number" or value ~= math.floor(value) or value < 1 or value > 1000000 then return 5 end
    return value
end

function M.reserve(prefs)
    local n = prefs and prefs.reserveGold
    if type(n) ~= "number" or n < 1 or n > 1000000 or n ~= math.floor(n) then return 10000 end
    return n * 10000
end

function M.delay(prefs)
    local n = prefs and prefs.delaySeconds
    return (n == 15 or n == 30) and n or 8
end

function M.display()
    return tableField(ForeverGoblinMailerDB, "display")
end

function M.money(copper)
    return ("%dg %02ds %02dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end
