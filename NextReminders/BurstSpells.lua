local _, NR = ...
NR.BurstSpells = {}
local B = NR.BurstSpells

local function integer(id, max)
    return NR.Number(id, 1, max) and id % 1 == 0
end

local function validList(ids)
    if type(ids) ~= "table" then return false end
    local count, seen = 0, {}
    for key, id in pairs(ids) do
        if not integer(key, 100) or not integer(id, 10000000) or seen[id] then return false end
        count = count + 1; seen[id] = true
    end
    for i = 1, count do if ids[i] == nil then return false end end
    return true
end

function B.Default(specID)
    local out = {}
    for _, entry in ipairs(NR.SpellCatalog.ForSpec(specID)) do
        for _, id in ipairs(entry.primarySpecs) do
            if id == specID then out[#out+1] = entry.id; break end
        end
    end
    return out
end

-- nil means follow future built-in updates; an explicit empty list means no automatic spells.
function B.Get(specID)
    if not integer(specID, 10000) then return {}, false end
    local custom = NR.db and NR.db.burstSpells
    local ids = type(custom) == "table" and custom[specID]
    if validList(ids) then return NR.Copy(ids), true end
    return B.Default(specID), false
end

function B.Removed(specID)
    local ids, custom = B.Get(specID)
    local kept, removed = {}, {}
    if custom then
        for _, id in ipairs(ids) do kept[id] = true end
        for _, id in ipairs(B.Default(specID)) do if not kept[id] then removed[id] = true end end
    end
    return removed
end

function B.Save(specID, ids)
    if InCombatLockdown() then return nil, "请脱战后修改爆发技能" end
    if not integer(specID, 10000) or not validList(ids) then return nil, "技能名单无效：最多 100 个，不可重复" end
    if type(NR.db) ~= "table" then return nil, "插件尚未初始化" end
    NR.db.burstSpells = type(NR.db.burstSpells) == "table" and NR.db.burstSpells or {}
    NR.db.burstSpells[specID] = NR.Copy(ids)
    return true
end

function B.Reset(specID)
    if InCombatLockdown() then return nil, "请脱战后修改爆发技能" end
    if not integer(specID, 10000) then return nil, "当前专精不可用" end
    if NR.db and type(NR.db.burstSpells) == "table" then NR.db.burstSpells[specID] = nil end
    return true
end

function B.Resolve(text)
    if type(text) ~= "string" then return nil, "请输入技能编号或技能链接" end
    text = NR.Trim(text)
    local id = tonumber(text:match("^%d+$") or text:match("|Hspell:(%d+)[:|]"))
    if not integer(id, 10000000) then return nil, "请输入有效技能编号或完整技能链接" end
    local entry = NR.SpellCatalog.Get(id)
    local info
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local ok, value = pcall(C_Spell.GetSpellInfo, id)
        if ok and NR.Public(value) and type(value) == "table" then info = value end
    end
    local name = info and info.name
    if not entry and not (NR.Public(name) and type(name) == "string" and name ~= "") then
        return nil, "找不到这个技能，请核对编号后重试"
    end
    return id
end
