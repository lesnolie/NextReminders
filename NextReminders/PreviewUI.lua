local _, NR = ...
NR.PreviewUI = { rows = {}, entries = {}, entryButtons = {}, marks = {}, bands = {}, ticks = {}, autoUse = true, referenceEvents = true }
local UI = NR.PreviewUI

local T=NR.Theme
local label=T.Label
local function button(parent,text,x,y,width,action,style,icon) return T.Button(parent,text,width,x,y,action,style,icon) end
-- Library on the left, player on the right.
local W, H, LIB, X0 = 1180, 740, 320, 360
local RW = W - X0 - 24
local TRACK = RW - 48
local ROW = 44
local KIND = { note = "NSRT／MRT", events = "网站方案", timeline3 = "网站时间轴" }
local DIFFICULTY = { normal = "普通", heroic = "英雄", mythic = "史诗" }

local function clock(seconds)
    seconds = math.max(0, seconds or 0)
    return string.format("%02d:%04.1f", math.floor(seconds / 60), seconds % 60)
end

local function dungeonOf(encounterID)
    for id, d in pairs(NR.DungeonData.dungeons) do
        for index, boss in ipairs(d.bosses) do if boss == encounterID then return id, d, index end end
    end
end

local function bossName(plan)
    if type(plan.name) == "string" and plan.name ~= "" and plan.name ~= "Lorrgs" and plan.name ~= "网站方案"
        and plan.name ~= "网站时间轴方案" then return plan.name end
    local rules = NR.BossRules.encounters[tostring(plan.encounterID)]
    local data = NR.BossData.encounters[plan.encounterID]
    local _, d, index = dungeonOf(plan.encounterID)
    return rules and rules.name or data and data.name or d and (d.name .. " 第 " .. index .. " 只首领")
        or "首领 " .. plan.encounterID
end

-- One library entry per saved plan of this spec, paused plans included. Entries hold copies: looking at or
-- rehearsing a plan never changes the saved configuration.
local function entry(plan, kind, key, unsaved)
    local dungeonID, d, index = dungeonOf(plan.encounterID)
    local keystone = plan.difficulty == "mythic" and (plan.dungeonID or dungeonID) and kind ~= "note"
    local difficulty = keystone and "史诗钥石" or DIFFICULTY[plan.difficulty] or plan.difficulty
    local state = unsaved and "未保存" or plan.enabled == false and "已暂停" or "已启用"
    return { key = kind .. ":" .. key, storageKey = key, kind = kind, plan = NR.Copy(plan), name = bossName(plan),
        detail = difficulty .. " · " .. KIND[kind] .. " · " .. #plan.rows .. " 条 · " .. state,
        group = keystone and d and d.name or "团本", order = index or plan.encounterID, unsaved = unsaved }
end

function UI:Library(specID)
    local result = {}
    local function add(plan, kind, key)
        local valid
        if kind == "events" then valid = NR.EventPlans.Validate(plan)
        elseif kind == "timeline3" then valid = NR.TimelinePlans.Validate(plan)
        else valid = NR.ValidatePlan(plan) end
        if valid then result[#result + 1] = entry(plan, kind, tostring(key)) end
    end
    local notes = NR.NotePlans(specID)
    for key, plan in pairs(notes and notes.plans or {}) do add(plan, "note", key) end
    for _, kind in ipairs({ "events", "timeline3" }) do
        local buckets = kind == "events" and NR.db.eventPlans or NR.db.timelinePlans
        local plans = type(buckets) == "table" and buckets[specID]
        for key, plan in pairs(type(plans) == "table" and plans or {}) do add(plan, kind, key) end
    end
    table.sort(result, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        if a.order ~= b.order then return a.order < b.order end
        return a.key < b.key
    end)
    return result
end

-- The library opens on the plan saved last for this spec.
function UI:Remember(plan)
    if type(plan) ~= "table" or not NR.Number(plan.specID, 1, 10000) then return end
    local kind = (plan.kind == "events" or plan.kind == "timeline3") and plan.kind or "note"
    NR.db.recentPlans = type(NR.db.recentPlans) == "table" and NR.db.recentPlans or {}
    NR.db.recentPlans[plan.specID] = kind .. ":" .. plan.encounterID .. ":" .. plan.difficulty
    NR.db.lastBySpec = type(NR.db.lastBySpec) == "table" and NR.db.lastBySpec or {}
    local last = {}
    for _, key in ipairs({"lastPlanKind", "lastPlan", "lastDungeon", "lastEventPlan", "lastTimelinePlan"}) do
        last[key] = NR.Copy(NR.db[key])
    end
    NR.db.lastBySpec[plan.specID] = last
end

-- Opens the library of the current spec. `select` is an entry key; `play` starts that plan at once.
function UI:OpenLibrary(select, play, unsaved)
    if InCombatLockdown() or NR.engine.active then return nil, "请脱战并结束实际首领战后预览" end
    local specID = NR.GetIdentity().specID
    if not specID then return nil, "还没有专精：方案按专精分开保存，请先选择专精" end
    self.specID = specID
    self.entries = {}
    local saved = self:Library(specID)
    local function equal(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end
    local drafts = {}
    for _, item in ipairs(unsaved or {}) do
        local scope = item.kind .. ":" .. item.plan.encounterID .. ":" .. item.plan.difficulty
        for _, existing in ipairs(saved) do
            if existing.key == scope then
                local same = true
                for _, field in ipairs({"rows", "phaseBindings", "phaseFallback", "personal"}) do
                    if not equal(item.plan[field], existing.plan[field]) then same = false end
                end
                if same then
                    if select == item.key then select = existing.key end
                    item = existing
                end
                break
            end
        end
        self.entries[#self.entries + 1] = item
        drafts[scope] = true
    end
    for _, item in ipairs(saved) do
        if not drafts[item.key] then self.entries[#self.entries + 1] = item end
    end
    self.deletePending = nil
    self.deletePlan:SetText("删除所选方案")
    self.undoDelete:SetEnabled(type(NR.db.deletedPlan) == "table" and NR.db.deletedPlan.specID == specID)
    local recent = type(NR.db.recentPlans) == "table" and NR.db.recentPlans[specID]
    local choice
    for index, item in ipairs(self.entries) do
        if item.key == select or (not choice and item.key == recent) then choice = index end
    end
    choice = choice or (#self.entries > 0 and 1 or nil)
    self.specLabel:SetText("方案回放 / " .. NR.SpecName(specID) .. " · 只列出这个专精导入的方案")
    self.specLine:SetText(NR.UI:SpecLine()); NR.UI:PaintEnable()
    if not self.frame:IsShown() then
        self.returnPage = NR.UI.page == "settings" and "settings" or "import"
        self.preserveDraft = NR.UI.frame:IsShown()
        if self.preserveDraft then T.Follow(self.frame, NR.UI.frame) end
    end
    self.backButton:SetText(self.returnPage == "settings" and "返回提醒设置" or "返回方案导入")
    NR.UI.frame:Hide(); self.frame:Show()
    self:RenderLibrary()
    if not choice then
        NR.preview:Stop(); self.choice = nil; self:ShowEmpty()
        return true
    end
    return self:Select(choice, play)
end

-- An unsaved plan from the import page: a whole-dungeon bundle lists each of its bosses.
function UI:Open(plan, choice)
    local items = {}
    if type(plan) == "table" and plan.kind == "dungeon" then
        local ok, err = NR.EventPlans.ValidateDungeon(plan)
        if not ok then return nil, err end
        for _, boss in ipairs(plan.plans) do items[#items + 1] = entry(boss, "events", "unsaved:" .. boss.encounterID, true) end
    elseif type(plan) == "table" then
        local kind = (plan.kind == "events" or plan.kind == "timeline3") and plan.kind or "note"
        local ok, err
        if kind == "events" then ok, err = NR.EventPlans.Validate(plan)
        elseif kind == "timeline3" then ok, err = NR.TimelinePlans.Validate(plan)
        else ok, err = NR.ValidatePlan(plan) end
        if not ok then return nil, err end
        items[1] = entry(plan, kind, "unsaved:" .. plan.encounterID, true)
    else return nil, "没有可播放的方案" end
    if InCombatLockdown() or NR.engine.active then return nil, "请脱战并结束实际首领战后预览" end
    local index = math.max(1, math.min(choice or 1, #items))
    local ok, err = self:OpenLibrary(items[index].key, true, items)
    if not ok then return nil, err end
    if not NR.preview.running then return nil, self.message:GetText() end
    return true
end

function UI:RenderLibrary()
    for index, item in ipairs(self.entries) do
        local row = self.entryButtons[index]
        if not row then
            row = button(self.libraryContent, "", 0, -(index - 1) * 72, 288, function() end)
            row:SetHeight(64); row.caption:SetHeight(48); row.caption:SetWordWrap(true)
            row.caption:ClearAllPoints(); row.caption:SetPoint("LEFT", 16, 0); row.caption:SetWidth(256)
            row.caption:SetJustifyH("LEFT")
            row.Layout = nil
            self.entryButtons[index] = row
        end
        local choice = index
        row:SetText((item.unsaved and "（未保存）" or "") .. item.name .. "\n" .. item.group .. " · " .. item.detail)
        row:SetScript("OnClick", function() self:Select(choice, false) end)
        row:SetSelected(index == self.choice); row:Show()
    end
    for index = #self.entries + 1, #self.entryButtons do self.entryButtons[index]:Hide() end
    self.libraryContent:SetHeight(math.max(456, #self.entries * 72))
    self.libraryCount:SetText(#self.entries .. " 个")
    self.empty:SetShown(#self.entries == 0)
end

function UI:ShowEmpty()
    self.selectedPlan = nil
    self.deletePlan:SetEnabled(false)
    self.title:SetText("还没有方案")
    self.detail:SetText("在导入页粘贴网站或 Lorrgs 的方案，保存后会出现在左边。")
    self.clock:SetText("00:00.0 / 00:00.0")
    for _, list in ipairs({ self.rows, self.marks, self.bands, self.ticks }) do
        for _, item in pairs(list) do item:Hide() end
    end
    self.playhead:Hide(); self.progress:SetWidth(1); self.order = nil
    self.trigger:Hide(); self.eventSelect:Hide(); self.ready:Hide()
    self.referenceCheck:Hide()
    for _, control in ipairs({ self.play, self.restart, self.speed, self.next, self.phase }) do control:SetEnabled(false) end
    self.message:SetText("")
end

-- Load one entry into the player. Selecting from the list loads it ready to play; `play` starts it.
function UI:Select(index, play)
    local item = self.entries[index]
    if not item then return nil, "没有这个方案" end
    self.choice = index
    self.deletePending = nil
    self.deletePlan:SetText("删除所选方案")
    self.deletePlan:SetEnabled(not item.unsaved)
    for i, row in ipairs(self.entryButtons) do row:SetSelected(i == index) end
    self.title:SetText(item.name)
    self.detail:SetText(item.group .. " · " .. item.detail)
    NR.Display:CacheFrames()
    NR.preview.autoUse = self.autoUse
    local ok, err = NR.preview:Start(item.plan, NR.db.settings, NR.GetIdentity(), GetTime(), { paused = not play, video = true, referenceEvents = self.referenceEvents })
    self.selectedPlan = item.plan
    if not ok then
        self:ShowEmpty(); self.title:SetText(item.name); self.detail:SetText(item.group .. " · " .. item.detail)
        self.message:SetText(err)
        return nil, err
    end
    for _, control in ipairs({ self.play, self.restart, self.speed, self.next, self.phase }) do control:SetEnabled(true) end
    self:Build()
    self.message:SetText(self:Hint())
    self.lastUpdate = nil; self:Update()
    return true
end

-- Delete only the selected saved format/scope. A single undo slot keeps deletion reversible.
function UI:DeleteSelected()
    if InCombatLockdown() or NR.engine.active then self.message:SetText("请脱战后删除方案"); return end
    local item = self.entries[self.choice]
    if not item or item.unsaved or self.specID ~= NR.GetIdentity().specID then return end
    if self.deletePending ~= item.key then
        self.deletePending = item.key
        self.deletePlan:SetText("再次点击确认删除")
        self.message:SetText("删除「" .. item.name .. "」的" .. KIND[item.kind] .. "方案；仅影响当前专精，可撤销删除。")
        return
    end
    local notes = NR.NotePlans(self.specID)
    local buckets = item.kind == "events" and NR.db.eventPlans or NR.db.timelinePlans
    local plans = item.kind == "note" and notes.plans or type(buckets) == "table" and buckets[self.specID]
    local plan = type(plans) == "table" and plans[item.storageKey]
    if not plan then self:OpenLibrary(); return end
    NR.db.deletedPlan = {specID=self.specID, kind=item.kind, key=item.storageKey, plan=NR.Copy(plan)}
    plans[item.storageKey] = nil
    NR.preview:Stop()
    self:OpenLibrary()
    self.undoDelete:SetEnabled(true)
    self.message:SetText("已删除「" .. item.name .. "」。可点「撤销删除」恢复；其他格式方案不受影响。")
end

function UI:UndoDelete()
    if InCombatLockdown() or NR.engine.active then self.message:SetText("请脱战后操作"); return end
    local old = NR.db.deletedPlan
    if type(old) ~= "table" or old.specID ~= NR.GetIdentity().specID then return end
    local plans
    if old.kind == "note" then plans = NR.NotePlans(old.specID).plans
    else
        local field = old.kind == "events" and "eventPlans" or "timelinePlans"
        NR.db[field] = type(NR.db[field]) == "table" and NR.db[field] or {}
        NR.db[field][old.specID] = NR.db[field][old.specID] or {}
        plans = NR.db[field][old.specID]
    end
    if plans[old.key] then self.message:SetText("已有新导入的同类方案，不能用撤销覆盖。请先检查新方案。"); return end
    plans[old.key] = NR.Copy(old.plan)
    NR.db.deletedPlan = nil
    self:OpenLibrary(old.kind .. ":" .. old.key)
    self.message:SetText("已恢复删除的方案。")
end

function UI:Hint()
    local p = NR.preview
    if p.eventMode and p.referenceEvents and #p.script > 0 then
        return "自动演练：事件按网页参考时间触发（估计），实战仍按游戏信号。关闭自动演练事件可手动触发；总时长是演练范围，不是击杀时间。"
    end
    if p.eventMode then
        for _, row in ipairs(p.engine.rows) do
            if p.expected[row.id] == nil then return "这套方案有跟首领事件走的提醒；事件时间未知，播到相应时刻点「触发」。" end
        end
    end
    for _, chapter in ipairs(p.chapters) do
        if chapter.estimated then
            return "带「估计」的阶段是按前一阶段最后一条提醒推算的；实战以 BigWigs 阶段或你填的转阶段时间为准。"
        end
    end
    return "像看录像一样：拖动时间轴跳到任意时刻，提醒会照实战的样子出现。演练不修改已保存方案。"
end

-- Static parts of the recording: chapter bands, a spell icon per reminder, time ticks and the list order.
function UI:Build()
    local p = NR.preview
    local span = p.duration
    self.span = span
    local function x(at) return TRACK * math.max(0, math.min(1, at / span)) end
    for index, chapter in ipairs(p.chapters) do
        local band = self.bands[index]
        if not band then
            band = { fill = self.track:CreateTexture(nil, "ARTWORK"), text = label(self.timeline, "", 0, 0, 120, "tiny") }
            band.fill:SetHeight(10); band.text:SetHeight(16)
            band.Hide = function(b) b.fill:Hide(); b.text:Hide() end
            self.bands[index] = band
        end
        local stop = p.chapters[index + 1] and p.chapters[index + 1].time or span
        band.fill:ClearAllPoints(); band.fill:SetPoint("TOPLEFT", self.track, "TOPLEFT", x(chapter.time), 0)
        band.fill:SetWidth(math.max(2, x(stop) - x(chapter.time)))
        band.fill:SetColorTexture(unpack(T.colors[index % 2 == 1 and "track" or "border"]))
        band.text:ClearAllPoints(); band.text:SetPoint("TOPLEFT", self.timeline, "TOPLEFT", 24 + x(chapter.time), -10)
        band.text:SetWidth(math.max(40, math.min(160, x(stop) - x(chapter.time))))
        band.text:SetText(chapter.label .. (chapter.estimated and "（估计）" or ""))
        band.fill:Show(); band.text:Show()
    end
    for index = #p.chapters + 1, #self.bands do self.bands[index]:Hide() end
    -- List and icons follow the expected order of the reminders.
    local order = {}
    for index in ipairs(p.plan.rows) do order[#order + 1] = index end
    local targets = {}
    for _, row in ipairs(p.engine.rows) do targets[row.id] = row.target end
    local function expected(index)
        local key = self:LiveKey(p.plan.rows[index])
        return targets[key] or p.expected[key]
    end
    table.sort(order, function(a, b)
        local ea, eb = expected(a), expected(b)
        if ea and eb and ea ~= eb then return ea < eb end
        if (ea == nil) ~= (eb == nil) then return ea ~= nil end
        return a < b
    end)
    self.order = order
    local lanes = { -1000, -1000 }
    for position, index in ipairs(order) do
        local row, at = p.plan.rows[index], expected(order[position])
        local mark = self.marks[position]
        if not mark then
            mark = self.timeline:CreateTexture(nil, "OVERLAY"); mark:SetSize(20, 20); mark:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            self.marks[position] = mark
        end
        if at then
            local left = x(at) - 10
            local lane = left - lanes[1] >= 22 and 1 or left - lanes[2] >= 22 and 2 or 1
            lanes[lane] = left
            local _, icon = self:Action(row)
            mark:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            mark:ClearAllPoints(); mark:SetPoint("TOPLEFT", self.timeline, "TOPLEFT", 24 + left, lane == 1 and -48 or -70)
            mark:Show()
        else mark:Hide() end
    end
    for index = #order + 1, #self.marks do self.marks[index]:Hide() end
    local step = 15
    for _, candidate in ipairs({ 15, 30, 60, 120, 300, 600 }) do step = candidate; if span / candidate <= 8 then break end end
    local count = math.floor(span / step) + 1
    for index = 1, count do
        local tick = self.ticks[index]
        if not tick then tick = label(self.timeline, "", 0, 0, 60, "tiny"); self.ticks[index] = tick end
        local at = (index - 1) * step
        tick:ClearAllPoints(); tick:SetPoint("TOPLEFT", self.timeline, "TOPLEFT", 24 + x(at) - (index == 1 and 0 or 18), -96)
        tick:SetText(string.format("%d:%02d", math.floor(at / 60), at % 60)); tick:Show()
    end
    for index = count + 1, #self.ticks do self.ticks[index]:Hide() end
    self.listScroll:SetVerticalScroll(0); self.followRow = nil
end

function UI:LiveKey(row)
    local p = NR.preview
    return p.timelineMode and "timeline:" .. row.id or p.eventMode and "event:" .. row.id or row.id
end

function UI:Action(row)
    local p = NR.preview
    if p.eventMode or p.timelineMode then return NR.EventPlans.Action(row) end
    return NR.SpellCatalog.Info(row.spellID)
end

function UI:Anchor(row)
    local p = NR.preview
    if p.timelineMode then
        return NR.BossRules.AnchorLabel(p.plan.encounterID, p.plan.difficulty, row.anchor)
            .. (row.anchor ~= "start" and (row.occurrence == "every" and " · 每次" or " · 第 " .. row.occurrence .. " 次") or "")
    elseif p.eventMode then
        local name = "开战"
        for _, option in ipairs(NR.EventPlans.Options(p.plan.encounterID, p.plan.difficulty)) do
            if option.key == row.anchor then name = option.label end
        end
        return name .. (row.anchor ~= "start" and (row.every and " · 每次" or " · 第 " .. row.occurrence .. " 次") or "")
    end
    local binding = p.plan.phaseBindings[row.phase]
    return "P" .. NR.PhaseLabel(row.phase) .. ((binding == "pull" or binding == "time") and " · 按开打" or " · 按阶段")
end

function UI:State(live, row)
    local p = NR.preview
    if not live then return "不匹配", "muted" end
    if live.shown then return "提醒中", "positive" end
    if live.done then return live.used and "已按" or "已过", "muted" end
    if live.held then return "等待：" .. (row.hold or ""), "warning" end
    if live.target then return "待提醒", "text" end
    return p.eventMode and "等待事件" or "等待阶段", "muted"
end

function UI:SeekCursor()
    local timeline = self.timeline
    local left, scale = timeline:GetLeft(), timeline:GetEffectiveScale()
    if not (self.span and NR.Number(left, -100000, 100000) and NR.Number(scale, 0.01, 100)) then return end
    local ratio = math.max(0, math.min(1, (GetCursorPosition() / scale - left - 24) / TRACK))
    local at = math.floor(ratio * self.span * 10 + 0.5) / 10
    if self.lastDrag == at then return end
    self.lastDrag = at
    if not NR.preview.running and self.selectedPlan then
        local ok, err = NR.preview:Start(self.selectedPlan, NR.db.settings, NR.GetIdentity(), GetTime(), { paused = true, video = true, referenceEvents = self.referenceEvents })
        if not ok then return self:Result(ok, err) end
    end
    self:Result(NR.preview:Seek(at, GetTime()))
end

function UI:Result(ok, err)
    if not ok and err then self.message:SetText(err) end
    self.lastUpdate = nil; self:Update()
end

function UI:Update()
    if not self.frame or not self.frame:IsShown() or not NR.preview.plan or not self.order then return end
    if self.dragging then self:SeekCursor() end
    local p = NR.preview
    local targetParts = {}
    for _, row in ipairs(p.engine.rows) do targetParts[#targetParts+1] = tostring(row.id)..":"..tostring(row.target) end
    local targetSignature = table.concat(targetParts,";")
    if self.span ~= p.duration or self.targetSignature ~= targetSignature then
        self.targetSignature = targetSignature; self:Build(); self.lastUpdate = nil
    end
    local signature = math.floor(p.position * 10) .. ":" .. p.status .. ":" .. tostring(p.playing) .. ":" .. p.speed
        .. ":" .. tostring(p.autoUse) .. ":" .. #p.actions .. ":" .. tostring(p.running)
    if self.lastUpdate == signature then return end
    self.lastUpdate = signature
    local span = self.span or p.duration
    self.clock:SetText(clock(p.position) .. " / " .. clock(span) .. "  ·  " .. p.status)
    local playing = p.running and p.playing
    self.play:SetText(playing and "暂停" or p.status == "播放结束" and "重播" or "播放")
    if self.play.nrIcon then self.play.nrIcon:SetTexture(T.media .. "ui_icon_" .. (playing and "pause" or "play") .. ".tga") end
    self.speed:SetText("倍速 ×" .. p.speed)
    local ratio = math.max(0, math.min(1, p.position / span))
    self.progress:SetWidth(math.max(1, TRACK * ratio))
    self.playhead:ClearAllPoints(); self.playhead:SetPoint("TOPLEFT", self.timeline, "TOPLEFT", 23 + TRACK * ratio, -28)
    self.playhead:Show()
    -- Event plans without timed events: manual triggers.
    if p.eventMode then
        self.eventOptions = NR.EventPlans.Options(p.plan.encounterID, p.plan.difficulty)
        self.eventChoice = math.max(2, math.min(self.eventChoice or 2, #self.eventOptions))
        local option = self.eventOptions[self.eventChoice]
        self.trigger:SetText(option and "触发：" .. option.label or "只有开战事件")
        local scripted = false
        for _, action in ipairs(p.script) do if action.key == (option and option.key) then scripted = true end end
        self.trigger:SetText(scripted and "自动："..option.label or option and "触发："..option.label or "只有开战事件")
        self.trigger:SetEnabled(p.running and option ~= nil and not scripted)
        self.referenceCheck:Show(); self.referenceCheck:SetChecked(p.referenceEvents)
        self.trigger:Show(); self.eventSelect:Show(); self.ready:Show(); self.phase:Hide()
    else
        self.referenceCheck:Hide()
        self.trigger:Hide(); self.eventSelect:Hide(); self.ready:Hide(); self.phase:Show()
        local nextChapter
        for _, chapter in ipairs(p.chapters) do
            if chapter.time > p.position + 0.05 then nextChapter = chapter; break end
        end
        self.phase:SetText(nextChapter and "跳到：" .. nextChapter.label or "没有后续阶段")
        self.phase:SetEnabled(p.running and nextChapter ~= nil)
    end
    local current = {}
    for _, row in ipairs(p.engine.rows) do current[row.id] = row end
    local follow
    for position, index in ipairs(self.order) do
        local row = p.plan.rows[index]
        local frame = self.rows[position]
        if not frame then
            frame = T.Panel(self.listContent, 0, -(position - 1) * ROW, TRACK, ROW - 4, "soft", { radius = 12, border = "soft" })
            frame.time = label(frame, "", 14, -11, 70)
            frame.icon = frame:CreateTexture(nil, "ARTWORK"); frame.icon:SetPoint("TOPLEFT", 92, -6); frame.icon:SetSize(28, 28)
            frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            frame.text = label(frame, "", 130, -11, 250)
            frame.anchor = label(frame, "", 390, -12, 170, "small")
            frame.state = label(frame, "", 568, -12, 90, "small")
            for _, field in ipairs({ frame.text, frame.anchor, frame.state }) do field:SetWordWrap(false); field:SetNonSpaceWrap(false) end
            frame.use = button(frame, "已用", 664, -2, 72, function() end)
            frame.use:SetHeight(36)
            self.rows[position] = frame
        end
        local live = current[self:LiveKey(row)]
        local name, icon = self:Action(row)
        frame.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        frame.text:SetText(name)
        local target = live and live.target or p.expected[self:LiveKey(row)]
        frame.time:SetText(target and clock(target) or "—")
        frame.anchor:SetText(self:Anchor(row))
        local state, color = self:State(live, row)
        frame.state:SetText(state); frame.state:SetTextColor(unpack(T.colors[color]))
        T.Paint(frame, live and live.shown and "accent" or "soft", live and live.shown and "accent" or "soft")
        local rowID = live and live.id
        frame.use:SetScript("OnClick", function()
            if p.eventMode or p.timelineMode or not row.spellID then NR.preview:UseRow(rowID, GetTime())
            else NR.preview:Cast(row.spellID, GetTime()) end
            self.lastUpdate = nil; self:Update()
        end)
        local manual = p.running and not p.autoUse and live and live.shown and not live.done
        frame.use:SetShown(manual or false); frame.use:SetEnabled(manual or false)
        if not follow and live and not live.done then follow = position end
        frame:Show()
    end
    for index = #self.order + 1, #self.rows do self.rows[index]:Hide() end
    self.listContent:SetHeight(math.max(self.listScroll:GetHeight(), #self.order * ROW))
    -- While playing, keep the next reminder in view, like subtitles following the video.
    if playing and follow and follow ~= self.followRow then
        self.followRow = follow
        self.listScroll:SetVerticalScroll(math.max(0, math.min((follow - 1) * ROW, #self.order * ROW - self.listScroll:GetHeight())))
    end
end

function UI:Back(page)
    self.frame:Hide()
    NR.UI.returning = self.preserveDraft
    T.Follow(NR.UI.frame, self.frame)
    NR.UI.frame:Show()
    NR.UI:SetPage(page or self.returnPage or "import")
end

function UI:Create()
    -- Same size and top bar as the main window; the centre holds the way back instead of the tabs.
    local frame = T.Window("NextRemindersPreview", W, H, "NextReminders")
    self.frame = frame
    self.specLine = NR.UI:Chrome(frame)
    self.backButton = button(frame.header,"返回方案导入",(W-200)/2,-18,200,function() self:Back() end,"outline")
    self.specLabel = label(frame, "", 24, -82, W - 48, "small")

    local library = T.Panel(frame, 24, -108, LIB, H - 132)
    label(library, "已导入方案", 20, -16, 160, "heading")
    self.libraryCount = label(library, "", LIB - 100, -18, 80, "small"); self.libraryCount:SetJustifyH("RIGHT")
    local scroll = T.Scroll(library, 16, -52, 288, H - 304)
    self.libraryContent = CreateFrame("Frame", nil, scroll); self.libraryContent:SetSize(288, H - 252)
    scroll:SetScrollChild(self.libraryContent)
    self.empty = label(self.libraryContent, "这个专精还没有导入方案。\n在导入页粘贴网站或 Lorrgs 的方案，保存后出现在这里。", 4, -8, 280, "muted")
    self.empty:SetHeight(80)
    self.deletePlan = button(library, "删除所选方案", 20, -(H - 240), 168, function() self:DeleteSelected() end)
    self.undoDelete = button(library, "撤销删除", 196, -(H - 240), 104, function() self:UndoDelete() end)
    button(library, "导入新方案", 20, -(H - 188), LIB - 40, function()
        self:Back("import")
    end, nil, "import")

    self.title = label(frame, "", X0, -108, RW, "title")
    self.detail = label(frame, "", X0, -142, RW, "muted")

    local hero = T.Panel(frame, X0, -172, RW, 76)
    self.clock = label(hero, "00:00.0 / 00:00.0", 20, -24, 300, "heading")
    self.restart = button(hero, "从头", 328, -20, 84, function()
        if not NR.preview.running and self.selectedPlan then
            return self:Result(NR.preview:Start(self.selectedPlan, NR.db.settings, NR.GetIdentity(), GetTime(), { video = true, referenceEvents = self.referenceEvents }))
        end
        self:Result(NR.preview:Seek(0, GetTime()))
    end, nil, "stop")
    self.play = button(hero, "播放", 424, -20, 104, function()
        local p = NR.preview
        if not p.running then
            if self.selectedPlan then self:Result(p:Start(self.selectedPlan, NR.db.settings, NR.GetIdentity(), GetTime(), { video = true, referenceEvents = self.referenceEvents })) end
        elseif p.playing then p:Pause(GetTime()); self:Result(true)
        else self:Result(p:Resume(GetTime())) end
    end, "primary", "play")
    self.speed = button(hero, "倍速 ×1", 540, -20, 100, function()
        local speed = ({ [1] = 2, [2] = 4, [4] = 8, [8] = 1 })[NR.preview.speed] or 1
        self:Result(NR.preview:SetSpeed(speed, GetTime()))
    end)
    self.next = button(hero, "下一个提醒", 652, -20, RW - 672, function() self:Result(NR.preview:NextReminder(GetTime())) end)

    self.timeline = T.Panel(frame, X0, -260, RW, 120)
    self.track = T.Panel(self.timeline, 24, -30, TRACK, 10, "track", { radius = 3, border = "track" })
    self.progress = self.track:CreateTexture(nil, "OVERLAY"); self.progress:SetPoint("TOPLEFT"); self.progress:SetHeight(10)
    local accent = T.colors.accent
    self.progress:SetColorTexture(accent[1], accent[2], accent[3], 0.6); self.progress:SetWidth(1)
    self.playhead = self.timeline:CreateTexture(nil, "OVERLAY"); self.playhead:SetSize(2, 64)
    self.playhead:SetColorTexture(unpack(T.colors.ink))
    -- Click or drag anywhere on the timeline to scrub.
    self.timeline:EnableMouse(true)
    self.timeline:SetScript("OnMouseDown", function() self.dragging, self.lastDrag = true, nil; self:SeekCursor() end)
    self.timeline:SetScript("OnMouseUp", function() self.dragging = false end)
    self.timeline:SetScript("OnHide", function() self.dragging = false end)

    self.autoCheck = T.Check(frame, "自动按技能（像看录像）", X0, -396)
    self.autoCheck.text:SetWidth(200)
    self.autoCheck:SetChecked(self.autoUse)
    self.autoCheck:SetScript("OnClick", function(check)
        check:Paint()
        self.autoUse = check:GetChecked() and true or false
        self:Result(NR.preview:SetAutoUse(self.autoUse, GetTime()))
    end)
    self.referenceCheck = T.Check(frame, "自动演练事件（网页参考时间）", X0, -420)
    self.referenceCheck.text:SetWidth(260)
    self.referenceCheck:SetChecked(self.referenceEvents)
    self.referenceCheck:SetScript("OnClick", function(check)
        check:Paint(); self.referenceEvents = check:GetChecked() and true or false
        self.targetSignature = nil
        self:Result(NR.preview:SetReferenceEvents(self.referenceEvents,GetTime()))
        self.message:SetText(self:Hint())
    end)
    self.phase = button(frame, "跳到下一阶段", X0 + 270, -390, 220, function() self:Result(NR.preview:NextPhase(GetTime())) end)
    self.trigger = button(frame, "触发事件", X0 + 270, -390, 230, function()
        local option = self.eventOptions and self.eventOptions[self.eventChoice]
        if option then self:Result(NR.preview:Event(option.key, GetTime())) end
    end)
    self.eventSelect = button(frame, "切换事件", X0 + 512, -390, 112, function()
        self.eventChoice = (self.eventChoice or 2) + 1
        if self.eventChoice > #self.eventOptions then self.eventChoice = 2 end
        self.lastUpdate = nil; self:Update()
    end, "field")
    self.ready = button(frame, "模拟冷却结束", X0 + 636, -390, RW - 636, function() self:Result(NR.preview:Ready(GetTime())) end)
    self.trigger:Hide(); self.eventSelect:Hide(); self.ready:Hide()

    local list = T.Panel(frame, X0, -450, RW, H - 510)
    label(list, "时点", 30, -14, 70, "small"); label(list, "技能", 146, -14, 200, "small")
    label(list, "阶段／锚点", 406, -14, 160, "small"); label(list, "状态", 584, -14, 90, "small")
    self.listScroll = T.Scroll(list, 16, -38, TRACK + 8, H - 562)
    self.listContent = CreateFrame("Frame", nil, self.listScroll); self.listContent:SetSize(TRACK, H - 562)
    self.listScroll:SetScrollChild(self.listContent)
    self.message = label(frame, "", X0, -(H - 52), RW, "small"); self.message:SetHeight(30)
    frame:Hide(); frame:SetScript("OnHide", function() self.dragging = false; NR.preview:Stop(); NR.Cleanup("close") end)
end
