local _, NR = ...
-- NRPlan:3 is a separate format and storage bucket. It never rewrites legacy plans.
NR.TimelinePlans = { schema = 3 }
local P = NR.TimelinePlans
local B = NR.BossRules

local function integer(value, minimum, maximum)
    return NR.Number(value, minimum, maximum) and value % 1 == 0
end

local function oneDecimal(value, minimum, maximum)
    return NR.Number(value, minimum, maximum)
        and math.abs(value * 10 - math.floor(value * 10 + 0.5)) < 1e-6
end

local function fields(line)
    local result = {}
    for segment in (line .. ";"):gmatch("([^;]*);") do
        if segment ~= "" then
            local key, value = segment:match("^([%a][%w_]*):(.*)$")
            if not key then return nil, "无效字段 " .. segment end
            key = key:lower()
            if result[key] ~= nil then return nil, "重复字段 " .. key end
            result[key] = value
        end
    end
    return result
end

local function decode(value)
    if value == nil then return nil end
    if value:gsub("%%[%x][%x]", ""):find("%", 1, true) then return nil end
    return (value:gsub("%%([%x][%x])", function(pair)
        return string.char(tonumber(pair, 16))
    end))
end

local function actionCount(f)
    return (f.spellid and 1 or 0) + (f.itemid and 1 or 0)
        + (f.slot and 1 or 0) + (f.text and 1 or 0)
end

local headerFields = {
    nrplan = true, encounterid = true, difficulty = true, specid = true,
    name = true, ruleversion = true,
}
local rowFields = {
    anchor = true, occurrence = true, offset = true, window = true,
    timing = true, fallback = true, spellid = true, itemid = true,
    slot = true, text = true, hold = true, after = true,
    sourceformat = true, sourcephase = true, sourcetime = true,
    sourcespellid = true, sourcetag = true, sourceraw = true,
}

function P.Parse(text)
    if type(text) ~= "string" or #text == 0 or #text > 200000 then
        return nil, "请输入不超过 200 KB 的 NRPlan:3 文本"
    end
    local plan = {
        kind = "timeline3", schema = 3, enabled = true, rows = {},
        format = "NextRemindersTimeline", ruleVersion = B.dataVersion,
    }
    local header
    local lineNumber = 0
    for raw in (text:gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n") do
        lineNumber = lineNumber + 1
        local line = NR.Trim(raw)
        if line ~= "" and not line:match("^#") then
            local f, err = fields(line)
            if not f then return nil, "第 " .. lineNumber .. " 行：" .. err end
            if f.nrplan then
                if header then return nil, "重复或混用了方案头部" end
                if f.nrplan ~= "3" then return nil, "TimelinePlans 只接收 NRPlan:3" end
                for key in pairs(f) do
                    if not headerFields[key] then return nil, "未知头部字段：" .. key end
                end
                plan.encounterID, plan.specID = tonumber(f.encounterid), tonumber(f.specid)
                plan.difficulty = f.difficulty and f.difficulty:lower()
                plan.name = "网站时间轴方案"
                if f.name then plan.name = decode(f.name) end
                plan.ruleVersion = f.ruleversion or B.dataVersion
                if f.name and not plan.name then return nil, "方案名字编码无效" end
                header = true
            else
                if not header then return nil, "缺少 NRPlan:3 头部" end
                for key in pairs(f) do
                    if not rowFields[key] then return nil, "未知规则字段：" .. key end
                end
                if actionCount(f) ~= 1 then return nil, "每行必须指定一种提醒动作" end
                for _, key in ipairs({"fallback", "sourcephase", "sourcetime", "sourcespellid"}) do
                    if f[key] ~= nil and not tonumber(f[key]) then return nil, "数值字段无效：" .. key end
                end
                local row = {
                    id = #plan.rows + 1,
                    anchor = f.anchor,
                    occurrence = f.occurrence == "every" and "every" or tonumber(f.occurrence),
                    offset = tonumber(f.offset),
                    window = tonumber(f.window),
                    timing = f.timing or "auto",
                    fallback = tonumber(f.fallback),
                    hold = decode(f.hold),
                    after = f.after,
                    enabled = true,
                }
                if f.hold and not row.hold then return nil, "等待文字编码无效" end
                if f.spellid then
                    row.spellID = tonumber(f.spellid)
                elseif f.itemid then
                    row.actionType, row.itemID = "item", tonumber(f.itemid)
                elseif f.slot then
                    row.actionType, row.slot = "slot", tonumber(f.slot)
                else
                    row.actionType, row.label = "text", decode(f.text)
                    if not row.label then return nil, "提醒文字编码无效" end
                end
                if f.sourceformat or f.sourcephase or f.sourcetime
                    or f.sourcespellid or f.sourcetag or f.sourceraw then
                    row.source = {
                        format = f.sourceformat,
                        phase = tonumber(f.sourcephase),
                        time = tonumber(f.sourcetime),
                        spellID = tonumber(f.sourcespellid),
                        tag = decode(f.sourcetag),
                        raw = decode(f.sourceraw),
                    }
                    if (f.sourcetag and not row.source.tag) or (f.sourceraw and not row.source.raw) then
                        return nil, "来源字段编码无效"
                    end
                end
                plan.rows[#plan.rows + 1] = row
                if #plan.rows > 100 then return nil, "最多 100 条时间轴提醒" end
            end
        end
    end
    local ok, err = P.Validate(plan)
    if not ok then return nil, err end
    return plan
end

local function stageSignalSupported(encounterID, difficulty, stageID)
    local stage = B.FindStage(encounterID, difficulty, stageID)
    local signal = stage and stage.signal
    return type(signal) == "table" and signal.enabled == true and signal.kind ~= "none"
end

local function signalSupported(encounterID, difficulty, anchor)
    local kind, id = B.ParseAnchor(anchor)
    if kind == "start" then return true end
    if kind == "stage" then return stageSignalSupported(encounterID, difficulty, id) end
    if kind == "mechanic" then return B.SignalSupported(encounterID, difficulty, id) end
    return false
end

function P.Validate(plan)
    if type(plan) ~= "table" or plan.kind ~= "timeline3" or plan.schema ~= 3
        or not integer(plan.encounterID, 1, 1000000)
        or not integer(plan.specID, 1, 10000)
        or not ({normal = true, heroic = true, mythic = true})[plan.difficulty]
        or type(plan.rows) ~= "table" or #plan.rows == 0 or #plan.rows > 100
        or type(plan.ruleVersion) ~= "string" or #plan.ruleVersion == 0 or #plan.ruleVersion > 40 then
        return nil, "时间轴方案结构无效"
    end
    local encounter, rules = B.For(plan.encounterID, plan.difficulty)
    if not encounter or not rules then return nil, "共享首领规则中没有此首领或难度" end
    if plan.encounterID ~= 3492 then return nil, "NRPlan:3 首个闭环仅开放乌拉特克，其他首领待接入验证" end
    if plan.ruleVersion ~= B.dataVersion then return nil, "首领规则版本不同，请重新导出方案" end
    local ids = {}
    for _, row in ipairs(plan.rows) do
        if type(row) ~= "table" or not integer(row.id, 1, 10000) or ids[row.id]
            or type(row.anchor) ~= "string" or not B.ValidateAnchor(plan.encounterID, plan.difficulty, row.anchor)
            or not oneDecimal(row.offset, -3600, 3600)
            or not NR.Number(row.window, 0.1, 60)
            or not ({auto = true, signal = true, fixed = true, predicted = true})[row.timing]
            or (row.every ~= true and row.occurrence ~= "every" and not integer(row.occurrence, 1, 20))
            or (row.enabled ~= nil and type(row.enabled) ~= "boolean")
            or (row.hold ~= nil and (type(row.hold) ~= "string" or #row.hold > 200)) then
            return nil, "时间轴锚点、次数、偏移或窗口无效"
        end
        local kind, id = B.ParseAnchor(row.anchor)
        if kind == "start" then
            if row.occurrence ~= 1 or row.offset < 0 or row.timing == "fixed" then
                return nil, "开战锚点只能发生一次，且偏移不得为负"
            end
        end
        if row.timing == "fixed" then
            if not oneDecimal(row.fallback, 0, 3600) then
                return nil, "固定兜底必须填写 0～3600 秒的开打后时间"
            end
            if row.occurrence == "every" then
                return nil, "固定兜底只支持明确的第几次，不支持每次"
            end
        elseif row.fallback ~= nil and not oneDecimal(row.fallback, 0, 3600) then
            return nil, "兜底时间无效"
        end
        if row.offset < 0 and row.timing == "signal" then
            return nil, "负偏移不能用仅在实际机制时触发的信号，请选择预测或固定兜底"
        end
        if row.timing == "signal" and not signalSupported(plan.encounterID, plan.difficulty, row.anchor) then
            return nil, "此锚点尚未接入实时信号"
        end
        if row.occurrence == "every" and row.fallback ~= nil then
            return nil, "每次机制不能共用一个固定兜底时间"
        end
        if row.timing == "predicted" and not B.PredictionSupported(plan.encounterID, plan.difficulty, id) then
            return nil, "该机制没有已接入的预测源"
        end
        if row.timing == "auto" and kind ~= "start" then
            local predicted = kind == "mechanic" and B.PredictionSupported(plan.encounterID, plan.difficulty, id)
            if row.offset < 0 and not predicted and row.fallback == nil then
                return nil, "机制前负偏移需要预测源，或填写明确固定时间兜底"
            end
            if row.offset >= 0 and not signalSupported(plan.encounterID, plan.difficulty, row.anchor)
                and row.fallback == nil then
                return nil, "该锚点没有已启用的实时信号，请填写固定时间兜底"
            end
        end
        local action = (row.spellID and 1 or 0) + (row.itemID and 1 or 0)
            + (row.slot and 1 or 0) + (row.label and 1 or 0)
        if action ~= 1 then return nil, "每行必须指定一种提醒动作" end
        if row.spellID and not integer(row.spellID, 1, 10000000) then return nil, "技能编号无效" end
        if row.itemID and not integer(row.itemID, 1, 10000000) then return nil, "物品编号无效" end
        if row.slot and row.slot ~= 13 and row.slot ~= 14 then return nil, "饰品槽只能是 13 或 14" end
        if row.label and (type(row.label) ~= "string" or #row.label == 0 or #row.label > 120) then
            return nil, "文字提醒无效"
        end
        if row.after ~= nil then
            return nil, "NRPlan:3 暂不支持后续就绪提醒"
        end
        if row.source then
            local source = row.source
            if type(source) ~= "table" then return nil, "来源结构无效" end
            if source.phase ~= nil and not NR.Phase(source.phase) then return nil, "来源阶段无效" end
            if source.time ~= nil and not NR.Number(source.time, 0, 3600) then return nil, "来源时间无效" end
            if source.spellID ~= nil and not integer(source.spellID, 1, 10000000) then return nil, "来源技能无效" end
            if source.tag ~= nil and type(source.tag) ~= "string" then return nil, "来源标签无效" end
            if source.raw ~= nil and (type(source.raw) ~= "string" or #source.raw > 500) then return nil, "来源原文无效" end
        end
        ids[row.id] = true
    end
    return true
end

function P.Find(specID, encounterID, difficulty)
    if not integer(specID, 1, 10000) or not integer(encounterID, 1, 1000000)
        or type(difficulty) ~= "string" then return end
    local specs = NR.db and NR.db.timelinePlans
    local plans = type(specs) == "table" and specs[specID]
    local plan = type(plans) == "table" and plans[encounterID .. ":" .. difficulty]
    if P.Validate(plan) and plan.specID == specID and plan.encounterID == encounterID
        and plan.difficulty == difficulty then return plan end
end

function P.Get(specID, encounterID, difficulty)
    local plan = P.Find(specID, encounterID, difficulty)
    if plan and plan.enabled ~= false then return plan end
end

function P.Save(plan)
    if InCombatLockdown() then return nil, "请脱战后保存时间轴方案" end
    local ok, err = P.Validate(plan)
    if not ok then return nil, err end
    NR.db.timelinePlans = type(NR.db.timelinePlans) == "table" and NR.db.timelinePlans or {}
    local specs = NR.db.timelinePlans
    specs[plan.specID] = type(specs[plan.specID]) == "table" and specs[plan.specID] or {}
    local key = plan.encounterID .. ":" .. plan.difficulty
    local old = specs[plan.specID][key]
    if old then
        NR.db.previousTimelinePlans = type(NR.db.previousTimelinePlans) == "table"
            and NR.db.previousTimelinePlans or {}
        NR.db.previousTimelinePlans[plan.specID] = type(NR.db.previousTimelinePlans[plan.specID]) == "table"
            and NR.db.previousTimelinePlans[plan.specID] or {}
        NR.db.previousTimelinePlans[plan.specID][key] = NR.Copy(old)
    end
    specs[plan.specID][key] = NR.Copy(plan)
    NR.db.lastTimelinePlan = {
        specID = plan.specID, encounterID = plan.encounterID, difficulty = plan.difficulty,
    }
    return true
end

function P.Pause(last)
    if InCombatLockdown() then return nil, "请脱战后暂停" end
    local plan = type(last) == "table" and P.Find(last.specID, last.encounterID, last.difficulty)
    if not plan then return nil, "没有有效的时间轴方案" end
    plan.enabled = false
    return true
end

function P.Rollback(last)
    if InCombatLockdown() then return nil, "请脱战后回滚" end
    if type(last) ~= "table" then return nil, "没有可回滚的时间轴方案" end
    local plan = P.Find(last.specID, last.encounterID, last.difficulty)
    local backups = NR.db.previousTimelinePlans
    local bucket = type(backups) == "table" and backups[last.specID]
    local key = plan and last.encounterID .. ":" .. last.difficulty
    local old = key and type(bucket) == "table" and bucket[key]
    if not plan or not P.Validate(old) or old.specID ~= last.specID
        or old.encounterID ~= last.encounterID or old.difficulty ~= last.difficulty then
        return nil, "没有有效的时间轴备份"
    end
    NR.db.timelinePlans[last.specID][key], bucket[key] = NR.Copy(old), NR.Copy(plan)
    return true
end
