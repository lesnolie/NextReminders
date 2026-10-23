local _, NR = ...
NR.Preview = {}

-- A separate engine and virtual clock: rehearsal never changes live plans or encounter state.
function NR.Preview.New(emit, clear, blocked)
    local p = { running = false, playing = false, position = 0, speed = 1, actions = {}, status = "未开始" }
    clear = clear or function() end
    blocked = blocked or function() return false end

    function p:Stop(status)
        local active = self.running
        self.running, self.playing = false, false
        if self.engine then self.engine:Stop() end
        if active then clear() end
        self.status = status or "已停止"
    end

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
                    groups[key] = {key=key,order=known and binding or phase,label=known or (binding == "stage" and "BigWigs 阶段 → " or "") .. "来源 P" .. phase .. "（手动演练）"}
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
        return plan, { anchors = labels, rules = {}, guard = 0 }
    end

    function p:Start(input, settings, identity, now)
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
        else self.plan, self.definition = prepare(input) end
        self.settings, self.identity = NR.Settings(settings), NR.Copy(identity or {})
        self.position, self.speed, self.actions, self.wallTime = 0, 1, {}, now
        self.eventCounts={}
        self.running, self.playing, self.status = true, true, "播放中"
        self.engine = NR.Engine.New(function(kind, row, value)
            if type(row) == "table" then row.preview = true end
            if not self.rebuilding then emit(kind, row, value) end
        end, self.definition, function() return nil end)
        self:BeginEngine()
        if #self.engine.rows == 0 then self:Stop(); return nil, "没有匹配自己的提醒，请检查个人模式或来源标签" end
        return true
    end

    function p:BeginEngine()
        local identity=NR.Copy(self.identity)
        if self.eventMode or self.timelineMode then identity.specID=self.plan.specID end
        self.engine:Begin(self.plan.encounterID,self.plan.difficulty,
            not self.eventMode and not self.timelineMode and self.plan or nil,self.settings,0,identity,
            self.eventMode and self.plan or nil,self.timelineMode and self.plan or nil)
    end

    function p:ApplyEvent(action)
        self.eventCounts[action.key]=(self.eventCounts[action.key] or 0)+1
        self.engine:BossEvent({key=action.key,count=self.eventCounts[action.key],at=action.time+action.delay,
            token=action.token,predicted=action.delay>0},action.time)
    end

    function p:Event(key,now)
        if not self.running or not self.eventMode then return nil,"请先预览首领规则" end
        local definition=NR.EventPlans.Definition(self.plan.encounterID,self.plan.difficulty)[key]
        if not definition then return nil,"没有这个事件" end
        self:Tick(now); if not self.running then return nil,"预览已结束" end
        local delay=definition.warning and definition.delay or definition.bar and definition.bar.duration or 0
        local action={kind="event",key=key,time=self.position,delay=delay,token="preview:"..(#self.actions+1)}
        self.actions[#self.actions+1]=action; self:ApplyEvent(action)
        return true
    end

    function p:Tick(now)
        if not self.running then return end
        if blocked() then self:Stop("进入战斗，预览已停止"); return end
        local delta = math.max(0, now - self.wallTime)
        self.wallTime = now
        if not self.playing then return end
        self.position = math.min(7200, self.position + delta * self.speed)
        self.engine:Tick(self.position)
        local pending = false
        for _, row in ipairs(self.engine.rows) do if not row.done then pending = true; break end end
        if (not pending and not next(self.engine.readyWatches)) or self.position >= 7200 then self:Stop("播放结束") end
    end

    function p:Pause(now)
        self:Tick(now)
        if not self.running then return end
        self.playing, self.status = false, "已暂停"
    end

    function p:Resume(now)
        if not self.running then return nil, "请先开始播放" end
        if blocked() then self:Stop(); return nil, "请脱战后预览" end
        self.wallTime, self.playing, self.status = now, true, "播放中"
        return true
    end

    function p:SetSpeed(speed, now)
        if speed ~= 1 and speed ~= 2 and speed ~= 4 then return nil, "仅支持 1、2、4 倍速" end
        self:Tick(now); self.speed = speed
        return true
    end

    function p:Seek(seconds, now)
        if not self.running then return nil, "请先开始播放" end
        if blocked() then self:Stop(); return nil, "请脱战后预览" end
        if not NR.Number(seconds, 0, 7200) then return nil, "跳转时间应为 0～7200 秒" end
        clear(); self.rebuilding = true
        self.eventCounts={}; self:BeginEngine()
        local retained = {}
        for _, action in ipairs(self.actions) do
            if action.time <= seconds then
                self.engine:Tick(action.time)
                if action.kind == "phase" then self.engine:Transition(action.time)
                elseif action.kind=="event" then self:ApplyEvent(action)
                elseif action.kind=="use" then self.engine:UseRow(action.id,action.time)
                elseif action.kind=="ready" then self.engine:CooldownReady(action.id,action.time)
                else self.engine:Cast(action.spellID, action.time) end
                retained[#retained+1] = action
            end
        end
        self.actions, self.position, self.wallTime = retained, seconds, now
        self.engine:Tick(seconds); self.rebuilding = false
        for _, row in ipairs(self.engine.rows) do
            if row.held then emit("hold",row)
            elseif row.shown then
                row.lastCountdown = nil
                emit("show", row, row.target - seconds)
                emit("update", row, row.target - seconds)
            end
        end
        self.engine:Tick(seconds)
        return true
    end

    function p:UseRow(id,now)
        if not self.running then return end
        self:Tick(now); if not self.running then return end
        self.actions[#self.actions+1]={kind="use",time=self.position,id=id}
        self.engine:UseRow(id,self.position)
    end

    function p:Ready(now)
        if not self.running then return nil,"请先开始播放" end
        self:Tick(now);if not self.running then return nil,"预览已结束" end
        local count=0
        for id in pairs(self.engine.readyWatches) do
            if self.engine.readyWatches[id].row.used then
                self.actions[#self.actions+1]={kind="ready",time=self.position,id=id}
                if self.engine:CooldownReady(id,self.position) then count=count+1 end
            end
        end
        return count>0 or nil,count==0 and "请先在第一次提醒里点已用，才开始后续就绪监听" or nil
    end

    function p:NextPhase(now)
        if not self.running then return nil, "请先开始播放" end
        self:Tick(now)
        if not self.running then return nil, "预览已结束" end
        if not self.definition.anchors[self.engine.sequence+1] then return nil, "没有下一预览阶段" end
        self.actions[#self.actions+1] = {kind="phase", time=self.position}
        self.engine:Transition(self.position)
        return true
    end

    function p:Cast(spellID, now)
        if not self.running or not NR.Number(spellID,1,10000000) then return end
        self:Tick(now)
        if not self.running then return end
        self.actions[#self.actions+1] = {kind="cast", time=self.position, spellID=spellID}
        self.engine:Cast(spellID, self.position)
    end

    return p
end
