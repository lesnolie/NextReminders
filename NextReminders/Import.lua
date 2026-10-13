local _, NR = ...
local difficultyNames = { heroic = "heroic", mythic = "mythic", normal = "normal", keystone = "mythic" }

local function fields(line)
    local result = {}
    for segment in (line .. ";"):gmatch("([^;]*);") do
        segment = NR.Trim(segment)
        if segment ~= "" then
            local key, value = segment:match("^([%a][%w_]*):(.*)$")
            if not key then return nil, "无效字段 " .. segment end
            key = key:lower()
            if result[key] then return nil, "重复字段 " .. key end
            result[key] = NR.Trim(value)
        end
    end
    return result
end

-- Parse data only. Never evaluate imported Lua or guess a missing phase mapping.
function NR.ParseNote(text, options)
    options = options or {}
    if type(text) ~= "string" or #text == 0 or #text > 200000 then return nil, "请输入不超过 200 KB 的导出文本" end
    local plan = { name = "Lorrgs", rows = {}, source = "Lorrgs note", phaseBindings = {} }
    local seen, headers = {}, 0
    local lineNumber = 0
    local mode
    for raw in (text:gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n") do
        lineNumber = lineNumber + 1
        local line = NR.Trim(raw)
        if line ~= "" and not line:match("^#") then
            local row
            if line:match("^EncounterID:") then
                local f, err = fields(line)
                if not f then return nil, "第 " .. lineNumber .. " 行：" .. err end
                for key in pairs(f) do
                    if key ~= "encounterid" and key ~= "difficulty" and key ~= "name" then
                        return nil, "第 " .. lineNumber .. " 行：暂不支持头部字段 " .. key
                    end
                end
                headers = headers + 1
                if headers > 1 then return nil, "一次只导入一只首领的一份方案" end
                plan.encounterID = tonumber(f.encounterid)
                plan.difficulty = f.difficulty and difficultyNames[f.difficulty:lower()]
                plan.sourceDifficulty = plan.difficulty
                plan.name = f.name or "Lorrgs"
                mode = "NSRT"
                if not plan.difficulty then return nil, "首领头部缺少或不支持 Difficulty" end
            elseif line:match("^ph:") or line:match("^time:") then
                if not plan.encounterID or mode == "MRT" then return nil, "NSRT 文本需要 EncounterID／Difficulty 头部" end
                local f, err = fields(line)
                if not f then return nil, "第 " .. lineNumber .. " 行：" .. err end
                for key in pairs(f) do
                    if key ~= "ph" and key ~= "time" and key ~= "tag" and key ~= "spellid" then
                        return nil, "第 " .. lineNumber .. " 行：暂不支持字段 " .. key
                    end
                end
                local phase = f.ph == nil and 1 or tonumber(f.ph)
                row = { phase = phase, time = tonumber(f.time), spellID = tonumber(f.spellid), tag = f.tag or "everyone" }
                mode = "NSRT"
            elseif line:match("^%{time:") then
                if mode == "NSRT" then return nil, "请勿混用两种导出格式" end
                local trigger, rest = line:match("^%{time:([^}]+)%}%s*%-%s*(.*)$")
                if not trigger then return nil, "第 " .. lineNumber .. " 行：无效 MRT 格式" end
                local minute, second, phase = trigger:match("^(%d+):(%d+%.?%d*),p(%d+)$")
                if not minute then minute, second = trigger:match("^(%d+):(%d+%.?%d*)$") end
                if not minute or tonumber(second) >= 60 then return nil, "第 " .. lineNumber .. " 行：仅支持开打或阶段相对时间" end
                local tag, spellID = rest:match("^(.-)%s*%{spell:(%d+)%}%s*$")
                if not spellID or tag:find("{", 1, true) then return nil, "第 " .. lineNumber .. " 行：一行需包含一个技能" end
                row = { phase = tonumber(phase) or 1, time = tonumber(minute) * 60 + tonumber(second), spellID = tonumber(spellID), tag = NR.Trim(tag) }
                mode = "MRT"
                plan.encounterID = tonumber(options.encounterID)
                plan.difficulty = difficultyNames[options.difficulty or "mythic"]
            else
                return nil, "第 " .. lineNumber .. " 行无法识别；请使用 Lorrgs 的 NSRT／MRT 导出"
            end
            if row then
                if not NR.Number(row.time, 0, 3600) or not NR.Number(row.spellID, 1, 10000000)
                    or row.spellID % 1 ~= 0 or not NR.Number(row.phase, 1, 100) or row.phase % 1 ~= 0 then
                    return nil, "第 " .. lineNumber .. " 行的技能、阶段或时间无效"
                end
                local key = row.phase .. ":" .. row.time .. ":" .. row.spellID .. ":" .. row.tag
                if not seen[key] then
                    seen[key] = true
                    row.id = #plan.rows + 1
                    plan.rows[#plan.rows + 1] = row
                end
            end
        end
    end
    if not NR.Number(plan.encounterID, 1, 1000000) or plan.encounterID % 1 ~= 0 then return nil, "请填写正确的首领 EncounterID" end
    if not plan.difficulty then return nil, "导出或使用难度无效" end
    if options.targetDifficulty ~= nil then
        local target = difficultyNames[options.targetDifficulty]
        if not target then return nil, "使用难度无效" end
        plan.difficulty = target
    end
    if #plan.rows == 0 or #plan.rows > 500 then return nil, "需要 1～500 条有效提醒" end
    plan.personal = options.personal ~= false
    plan.format = mode
    table.sort(plan.rows, function(a,b) if a.phase ~= b.phase then return a.phase < b.phase end return a.time < b.time end)
    -- Import phase IDs describe the source fight. Bind them explicitly to local anchors.
    for _, row in ipairs(plan.rows) do plan.phaseBindings[row.phase] = row.phase == 1 and "pull" or false end
    return plan
end

function NR.ValidatePlan(plan)
    if type(plan) ~= "table" or not NR.Number(plan.encounterID, 1, 1000000) or plan.encounterID % 1 ~= 0
        or not difficultyNames[plan.difficulty] or type(plan.rows) ~= "table" or #plan.rows == 0 or #plan.rows > 500
        or type(plan.phaseBindings) ~= "table" or (plan.sourceDifficulty ~= nil and not difficultyNames[plan.sourceDifficulty]) then
        return nil, "方案结构无效，请重新导入"
    end
    local ids = {}
    for _, row in ipairs(plan.rows) do
        if type(row) ~= "table" or not NR.Number(row.phase, 1, 100) or row.phase % 1 ~= 0
            or not NR.Number(row.id, 1, 1000000) or row.id % 1 ~= 0 or ids[row.id]
            or not NR.Number(row.time, 0, 3600) or not NR.Number(row.spellID, 1, 10000000) or row.spellID % 1 ~= 0
            or type(row.tag) ~= "string" then return nil, "方案提醒无效，请重新导入" end
        ids[row.id] = true
    end
    return true
end

function NR.ValidateBindings(plan)
    local valid, err = NR.ValidatePlan(plan)
    if not valid then return nil, err end
    local definition = NR.BossData.encounters[plan.encounterID]
    for _, row in ipairs(plan.rows) do
        local binding = plan.phaseBindings[row.phase]
        if row.phase == 1 and binding ~= "pull" then return nil, "阶段 1 必须相对开打" end
        if row.phase > 1 and binding ~= "pull" and (plan.difficulty ~= "mythic" or type(binding) ~= "number"
            or not definition or not definition.anchors[binding]) then
            return nil, "阶段 " .. row.phase .. " 尚未绑定到游戏识别节点；固定时间可改用 MRT 静态导出"
        end
    end
    return true
end
