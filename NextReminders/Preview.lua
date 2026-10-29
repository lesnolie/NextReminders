local _, NR = ...
NR.Preview = {}

-- Auto-use presses a reminder this long after its countdown reaches zero, so "现在" is visible first.
local AUTO_DELAY = 0.5
local SPEEDS = { [1] = true, [2] = true, [4] = true, [8] = true }

-- A separate engine and virtual clock: rehearsal never changes live plans or encounter state.
-- Started with options.video it plays like a recording: a script of the fight (phase starts, timed boss mechanics)
-- runs on the clock, it pauses at the end, and with auto-use on each reminder is pressed as a player following the
-- plan would. Without it (the /nr test demo) phases are advanced by hand and it stops once every reminder is done.
function NR.Preview.New(emit, clear, blocked)
    local p = { running = false, playing = false, position = 0, speed = 1, actions = {}, status = "未开始",
        script = {}, chapters = {}, expected = {}, duration = 60, autoUse = false }
    clear = clear or function() end
    blocked = blocked or function() return false end

    function p:Stop(status)
        local active = self.running
        self.running, self.playing = false, false
        if self.engine then self.engine:Stop() end
        if active then clear() end
        self.status = status or "已停止"
    end

    -- Static plans: source phases become sequential preview anchors. Each anchor starts at the transition time
    -- entered on import, else at an estimate (the previous phase's last reminder + 15 s). Rehearsal only:
    -- live fights never use the estimate.
    local function prepare(input)
        local plan, labels, groups, ordered = NR.Copy(input), {}, {}, {}
        local phases, seen = {}, {}
        for _, row in ipairs(plan.rows) do
            if not seen[row.phase] then phases[#phases+1] = row.phase; seen[row.phase] = true end
        end
        table.sort(phases)
        local definition = input.difficulty == "mythic" and NR.BossData.encounters[input.encounterID]
        for _, phase in ipairs(phases) do
            local binding = input.phaseBindings[phase]
            if phase == 1 or binding == "pull" then
                plan.phaseBindings[phase] = "pull"
            elseif binding == "time" then
                plan.phaseBindings[phase] = "time"
            else
                local known = type(binding) == "number" and definition and definition.anchors[binding]
                local key = known and "node"..binding or "source"..phase
                if not groups[key] then
                    groups[key] = {key=key,order=known and binding or phase,phase=phase,label=known or "P"..NR.PhaseLabel(phase)}
                    ordered[#ordered+1] = groups[key]
                end
                plan.phaseBindings[phase] = key
            end
        end
        table.sort(ordered,function(a,b) if a.order==b.order then return a.key<b.key end return a.order<b.order end)
        for index, group in ipairs(ordered) do group.anchor=index+1; labels[index+1]=group.label end
        for phase,binding in pairs(plan.phaseBindings) do
            if binding ~= "pull" and groups[binding] then plan.phaseBindings[phase]=groups[binding].anchor end
        end
        plan.enabled = true
        local function lastRow(binding)
            local last = 0
            for _, row in ipairs(plan.rows) do
                if plan.phaseBindings[row.phase] == binding then last = math.max(last, row.time) end
            end
            return last
        end
        local script, start, previous = {}, 0, "pull"
        for _, group in ipairs(ordered) do
            local entered = input.phaseFallback and input.phaseFallback[group.phase]
            local at = math.max(entered or start + lastRow(previous) + 15, start + 1)
            script[#script+1] = {kind="phase",time=at,label=group.label,estimated=not entered}
            start, previous = at, group.anchor
        end
        return plan, { anchors = labels, rules = {}, guard = 0 }, script
    end

    -- NRPlan:3: mechanics with a maintained fixed time fire on schedule; signal-only stages start at the shared
    -- rule's start, else where a row's fixed fallback puts them.
    local function timelineScript(plan)
        local B, script, seenMechanic, stageAt = NR.BossRules, {}, {}, {}
        for _, row in ipairs(plan.rows) do
            local kind, id = B.ParseAnchor(row.anchor)
            if kind == "mechanic" and not seenMechanic[id] then
                seenMechanic[id] = true
                local mechanic = B.FindMechanic(plan.encounterID, plan.difficulty, id)
                for _, occurrence in ipairs(mechanic and type(mechanic.occurrences)=="table" and mechanic.occurrences or {}) do
                    if NR.Number(occurrence.at, 0, 3600) and NR.Number(occurrence.index, 1, 20) then
                        script[#script+1] = {kind="mechanic",id=id,occurrence=occurrence.index,time=occurrence.at,
                            label=(mechanic.label or id).." #"..occurrence.index}
                    end
                end
            elseif kind == "stage" then
                local stage = B.FindStage(plan.encounterID, plan.difficulty, id)
                local signal = stage and stage.signal
                if stage and not (type(signal)=="table" and signal.kind=="pull") then
                    local entry = stageAt[id] or {label=stage.label or id}
                    stageAt[id] = entry
                    if NR.Number(stage.start, 0, 3600) then entry.time, entry.estimated = stage.start, false
                    elseif entry.estimated ~= false and row.fallback and row.fallback - row.offset >= 0 then
                        entry.time, entry.estimated = row.fallback - row.offset, true
                    end
                end
            end
        end
        for id, entry in pairs(stageAt) do
            if entry.time then
                script[#script+1] = {kind="stage",id=id,time=entry.time,label=entry.label,estimated=entry.estimated}
            end
        end
        table.sort(script, function(a,b) if a.time==b.time then return a.kind<b.kind end return a.time<b.time end)
        return script
    end

    function p:Start(input, settings, identity, now, options)
        options = type(options) == "table" and options or {}
        if blocked() then return nil, "请脱战并结束实际首领战后预览" end
        local eventMode=type(input)=="table" and input.kind=="events"
        local timelineMode=type(input)=="table" and input.kind=="timeline3"
        local valid, err
        if timelineMode then valid,err=NR.TimelinePlans.Validate(input)
        elseif eventMode then valid,err=NR.EventPlans.Validate(input) else valid,err=NR.ValidatePlan(input) end
        if not valid then return nil, err end
        self:Stop()
        self.eventMode=eventMode
        self.timelineMode=timelineMode
        if eventMode or timelineMode then
            self.plan=NR.Copy(input); self.plan.enabled=true
            self.definition={anchors={},rules={},guard=0}
            self.script=timelineMode and timelineScript(self.plan) or {}
        else self.plan, self.definition, self.script = prepare(input) end
        self.video = options.video == true
        self.referenceEvents = self.video and eventMode and options.referenceEvents ~= false
        if self.referenceEvents then
            local reference = NR.BossData.previewEvents[self.plan.encounterID]
            reference = reference and reference[self.plan.difficulty] or {}
            local needed = {}
            for _, row in ipairs(self.plan.rows) do
                if row.anchor ~= "start" then
                    needed[row.anchor] = math.max(needed[row.anchor] or 0, row.every and 20 or row.occurrence)
                end
            end
            for key, count in pairs(needed) do
                for index, at in ipairs(reference[key] or {}) do
                    if index <= count then
                        self.script[#self.script+1] = {kind="event",key=key,time=at,delay=0,
                            token="reference:"..key..":"..index,label=NR.EventPlans.Definition(self.plan.encounterID,self.plan.difficulty)[key].label,
                            estimated=true}
                    end
                end
            end
            table.sort(self.script,function(a,b) if a.time==b.time then return a.key<b.key end return a.time<b.time end)
        end
        if not self.video then self.script = {} end
        self.chapters={{time=0,label="开战"}}
        for _, action in ipairs(self.script) do
            if action.kind=="phase" or action.kind=="stage" or action.kind=="event" then self.chapters[#self.chapters+1]=action end
        end
        self.settings, self.identity = NR.Settings(settings), NR.Copy(identity or {})
        self.speed, self.actions, self.wallTime = 1, {}, now
        self.running = true
        self.engine = NR.Engine.New(function(kind, row, value)
            if type(row) == "table" then row.preview = true end
            if not self.rebuilding then emit(kind, row, value) end
        end, self.definition, function() return "ready" end)
        if self.video then self:Simulate() else self.expected, self.duration = {}, 7200 end
        self:Reset()
        if #self.engine.rows == 0 then self:Stop(); return nil, "没有匹配自己的提醒，请检查个人模式或来源标签" end
        self.playing, self.status = not options.paused, options.paused and "已就绪" or "播放中"
        return true
    end

    function p:BeginEngine()
        local identity=NR.Copy(self.identity)
        if self.eventMode or self.timelineMode then identity.specID=self.plan.specID end
        self.engine:Begin(self.plan.encounterID,self.plan.difficulty,
            not self.eventMode and not self.timelineMode and self.plan or nil,self.settings,0,identity,
            self.eventMode and self.plan or nil,self.timelineMode and self.plan or nil)
    end

    function p:Reset()
        self.eventCounts, self.scriptIndex, self.position, self.actionIndex = {}, 1, 0, 1
        self:BeginEngine()
    end

    -- A silent full run with auto-use: when each reminder is due, and how long the recording is.
    function p:Simulate()
        local auto = self.autoUse
        self.rebuilding, self.autoUse, self.expected, self.duration = true, true, {}, 3600
        self:Reset()
        self.recording = true
        self:Advance(3600)
        self.recording = false
        local last = 0
        for _, at in pairs(self.expected) do last = math.max(last, at) end
        for _, action in ipairs(self.script) do last = math.max(last, action.time) end
        local unknown = false
        for _, row in ipairs(self.engine.rows) do if self.expected[row.id] == nil then unknown = true end end
        self.duration = math.min(3600, math.max(60, math.ceil(last + 15) + (unknown and 90 or 0)))
        self.autoUse, self.rebuilding = auto, false
    end

    function p:Apply(action)
        if action.kind == "phase" then self.engine:Transition(action.time)
        elseif action.kind == "event" then self:ApplyEvent(action)
        elseif action.kind == "use" then self.engine:UseRow(action.id, action.time)
        elseif action.kind == "ready" then self.engine:CooldownReady(action.id, action.time)
        elseif action.kind == "stage" then self.engine:StageRule(action.id, action.time, action.time)
        elseif action.kind == "mechanic" then
            self.engine:MechanicEvent(action.id, action.occurrence, action.time, action.time, false, "preview")
        else self.engine:Cast(action.spellID, action.time) end
    end

    function p:AutoUse(row, at)
        row.autoHandled = row.target
        if not row.shown or row.done then return end
        local spellID = row.useSpellID or row.spellID
        if spellID then self.engine:Cast(spellID, at) else self.engine:UseRow(row.id, at) end
    end

    -- Moves the virtual clock forward to `target`, firing scripted fight events and auto-uses in time order.
    function p:Advance(target)
        for _ = 1, 5000 do
            self.engine:Tick(self.position)
            local at, item, scripted, recorded = target, nil, false, false
            local action = self.script[self.scriptIndex]
            if action and action.time <= at then at, item, scripted = action.time, action, true end
            local manual = self.actions[self.actionIndex]
            if manual and manual.time <= at then at, item, scripted, recorded = manual.time, manual, false, true end
            if self.autoUse and self.video then
                for _, row in ipairs(self.engine.rows) do
                    local when = row.target and not row.done and not row.used and row.autoHandled ~= row.target
                        and row.target + AUTO_DELAY
                    if when and (when < at or (when == at and not scripted)) then at, item, scripted, recorded = when, row, false, false end
                end
            end
            self.position = math.max(self.position, at)
            self.engine:Tick(self.position)
            if self.recording then
                for _, row in ipairs(self.engine.rows) do
                    if row.target and self.expected[row.id] == nil then self.expected[row.id] = row.target end
                end
            end
            if not item then return end
            if recorded then self.actionIndex = self.actionIndex + 1; self:Apply(item)
            elseif scripted then self.scriptIndex = self.scriptIndex + 1; self:Apply(item)
            else self:AutoUse(item, self.position) end
        end
    end

    function p:ApplyEvent(action)
        self.eventCounts[action.key]=(self.eventCounts[action.key] or 0)+1
        self.engine:BossEvent({key=action.key,count=self.eventCounts[action.key],at=action.time+action.delay,
            token=action.token,predicted=action.delay>0},action.time)
    end

    -- Boss events without a known time are triggered by hand; they stay in the recording for seeking.
    function p:Event(key,now)
        if not self.running or not self.eventMode then return nil,"请先预览首领规则" end
        if self.referenceEvents then
            for _, action in ipairs(self.script) do
                if action.key == key then return nil,"自动演练按参考时间触发；关闭「自动演练事件」后可手动触发" end
            end
        end
        local definition=NR.EventPlans.Definition(self.plan.encounterID,self.plan.difficulty)[key]
        if not definition then return nil,"没有这个事件" end
        self:Tick(now); if not self.running then return nil,"预览已结束" end
        local delay=definition.warning and definition.delay or definition.bar and definition.bar.duration or 0
        local action={kind="event",key=key,time=self.position,delay=delay,token="preview:"..(#self.actions+1)}
        self:Record(action); self:ApplyEvent(action)
        if self.video then self.duration=math.min(3600,math.max(self.duration,self.position+delay+60)); self:Finished() end
        return true
    end

    function p:Finished()
        if not self.video then
            local pending = false
            for _, row in ipairs(self.engine.rows) do if not row.done then pending = true; break end end
            if (not pending and not next(self.engine.readyWatches)) or self.position >= self.duration then self:Stop("播放结束") end
            return
        end
        if self.position >= self.duration then
            self.playing, self.status = false, "播放结束"
        elseif self.status == "播放结束" then
            self.status = self.playing and "播放中" or "已暂停"
        end
    end

    function p:Tick(now)
        if not self.running then return end
        if blocked() then self:Stop("进入战斗，预览已停止"); return end
        local delta = math.max(0, now - self.wallTime)
        self.wallTime = now
        if not self.playing then return end
        self:Advance(math.min(self.duration, self.position + delta * self.speed))
        self:Finished()
    end

    function p:Pause(now)
        self:Tick(now)
        if not self.running or not self.playing then return end
        self.playing, self.status = false, "已暂停"
    end

    function p:Resume(now)
        if not self.running then return nil, "请先开始播放" end
        if blocked() then self:Stop(); return nil, "请脱战后预览" end
        if self.video and self.position >= self.duration then
            local ok, err = self:Seek(0, now)
            if not ok then return nil, err end
        end
        self.wallTime, self.playing, self.status = now, true, "播放中"
        return true
    end

    function p:SetSpeed(speed, now)
        if not SPEEDS[speed] then return nil, "仅支持 1、2、4、8 倍速" end
        self:Tick(now); self.speed = speed
        return true
    end

    function p:SetAutoUse(enabled, now)
        self.autoUse = enabled and true or false
        if self.running then return self:Seek(self.position, now) end
        return true
    end

    function p:SetReferenceEvents(enabled, now)
        if not self.running or not self.eventMode then return nil,"请先选择首领事件方案" end
        local position, speed, paused = self.position, self.speed, not self.playing
        local ok, err = self:Start(self.plan,self.settings,self.identity,now,{video=true,paused=paused,referenceEvents=enabled})
        if not ok then return nil,err end
        self.speed = speed
        return self:Seek(position,now)
    end

    function p:Seek(seconds, now)
        if not self.running then return nil, "请先开始播放" end
        if blocked() then self:Stop(); return nil, "请脱战后预览" end
        if not NR.Number(seconds, 0, 7200) then return nil, "跳转时间应为 0～7200 秒" end
        seconds = math.min(seconds, self.duration)
        clear(); self.rebuilding = true
        if not self.video then
            local retained = {}
            for _, action in ipairs(self.actions) do
                if action.time <= seconds then retained[#retained + 1] = action end
            end
            self.actions = retained
        end
        self:Reset()
        self:Advance(seconds)
        self.wallTime = now
        self.rebuilding = false
        for _, row in ipairs(self.engine.rows) do
            if row.held then emit("hold",row)
            elseif row.shown then
                row.lastCountdown = nil
                emit("show", row, row.target - seconds)
                emit("update", row, row.target - seconds)
            end
        end
        self.engine:Tick(seconds)
        if self.video then self:Finished() end
        return true
    end

    -- Seeking preserves the recording. A new manual action after rewinding replaces the future branch.
    function p:Record(action)
        for i = #self.actions, self.actionIndex, -1 do self.actions[i] = nil end
        self.actions[#self.actions + 1] = action
        self.actionIndex = #self.actions + 1
    end

    function p:UseRow(id,now)
        if not self.running then return end
        self:Tick(now); if not self.running then return end
        self:Record({kind="use",time=self.position,id=id})
        self.engine:UseRow(id,self.position)
    end

    function p:Ready(now)
        if not self.running then return nil,"请先开始播放" end
        self:Tick(now);if not self.running then return nil,"预览已结束" end
        local count=0
        for id in pairs(self.engine.readyWatches) do
            if self.engine.readyWatches[id].row.used then
                self:Record({kind="ready",time=self.position,id=id})
                if self.engine:CooldownReady(id,self.position) then count=count+1 end
            end
        end
        return count>0 or nil,count==0 and "请先在第一次提醒里点已用，才开始后续就绪监听" or nil
    end

    -- In a recording "next phase" jumps to the next scripted phase start; otherwise it enters the phase now.
    function p:NextPhase(now)
        if not self.running then return nil, "请先开始播放" end
        self:Tick(now)
        if not self.running then return nil, "预览已结束" end
        if not self.video then
            if not self.definition.anchors[self.engine.sequence+1] then return nil, "没有下一预览阶段" end
            self:Record({kind="phase", time=self.position})
            self.engine:Transition(self.position)
            return true
        end
        for _, chapter in ipairs(self.chapters) do
            if chapter.time > self.position + 0.05 then return self:Seek(chapter.time, now) end
        end
        return nil, "没有下一阶段"
    end

    -- Jump to just before the next reminder appears.
    function p:NextReminder(now)
        if not self.running then return nil, "请先开始播放" end
        self:Tick(now)
        local lead, best = self.settings.lead
        for _, at in pairs(self.expected) do
            local show = math.max(0, at - lead - 1)
            if show > self.position + 0.05 and (not best or show < best) then best = show end
        end
        if not best then return nil, "后面没有提醒了" end
        return self:Seek(best, now)
    end

    function p:Cast(spellID, now)
        if not self.running or not NR.Number(spellID,1,10000000) then return end
        self:Tick(now)
        if not self.running then return end
        self:Record({kind="cast", time=self.position, spellID=spellID})
        self.engine:Cast(spellID, self.position)
    end

    return p
end
