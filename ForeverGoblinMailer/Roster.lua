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
        name = NameUtil.GetUnmodifiedUnitFullName("player")
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

function M.context()
    if InCombatLockdown() then return end
    local guid, realm, faction = UnitGUID("player"), GetRealmName(), UnitFactionGroup("player")
    if type(guid) ~= "string" or guid == "" or not realm or realm == "" or not faction then return end
    if type(ForeverGoblinMailerDB) ~= "table" then ForeverGoblinMailerDB = {} end
    local scope = tableField(tableField(ForeverGoblinMailerDB, "realms"), realm .. "/" .. faction)
    tableField(scope, "roles")
    tableField(scope, "rules")
    local prefs = tableField(tableField(scope, "characters"), guid)
    return scope, prefs, guid
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

function M.money(copper)
    return ("%dg %02ds %02dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end
