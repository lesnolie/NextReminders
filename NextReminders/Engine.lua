local _, NR = ...
NR.Engine = {}

function NR.Engine.New(emit, previewDefinition, readyReader)
    local engine = { emit = emit or function() end, active = false, trace = {} }

    function engine:Log(kind, detail, now)
        self.trace[#self.trace + 1] = { kind = kind, detail = detail, time = now - (self.startTime or now) }
        if #self.trace > 500 then table.remove(self.trace, 1) end
    end

    function engine:Stop()
        for _, row in ipairs(self.rows or {}) do if row.shown or row.held then self.emit("hide", row) end end
        self.active, self.rows = false, {}
        self.added, self.canceled, self.events = {}, {}, {}
        self.bossEvents=nil
        self.readyWatches,self.readyObservations={},{}
    end

    function engine:Begin(encounterID, difficulty, plan, settings, now, identity, eventPlan)
        self:Stop()
        self.trace, self.startTime, self.encounterID, self.difficulty = {}, now, encounterID, difficulty
        self.settings, self.identity = NR.Settings(settings), identity or {}
        self.definition = previewDefinition or (difficulty == "mythic" and NR.BossData.encounters[encounterID] or nil)
        self.anchorTimes = { pull = now }
        self.rows, self.added, self.canceled, self.events = {}, {}, {}, {}
        self.sequence, self.logicalPhase, self.lastTransition = 1, 1, now
        self.active = true
        self.readyWatches,self.readyObservations={},{}; self.lastReadyPoll=nil
        self.bossEvents=NR.BossEvents.New(NR.EventPlans.Definition(encounterID,difficulty),
            function(record,at) self:BossEvent(record,at) end,
            function(kind,detail,at) self:Log(kind,detail,at) end)
        local valid = plan and (previewDefinition and NR.ValidatePlan(plan) or NR.ValidateBindings(plan))
        if plan and plan.enabled and plan.encounterID == encounterID and plan.difficulty == difficulty and valid then
            for _, input in ipairs(plan.rows) do
                local binding = plan.phaseBindings[input.phase]
                local allowed = plan.personal or self:TagMatches(input.tag)
                if allowed and (binding == "pull" or (self.definition and self.definition.anchors[binding])) then
                    local row = NR.Copy(input)
                    row.anchor = binding
                    self.rows[#self.rows + 1] = row
                end
            end
        end
        if eventPlan and NR.EventPlans.Validate(eventPlan) and eventPlan.enabled and eventPlan.encounterID==encounterID
            and eventPlan.difficulty==difficulty and eventPlan.specID==self.identity.specID then
            for _,input in ipairs(eventPlan.rows) do
                if input.enabled~=false then
                    local row=NR.Copy(input)
                    row.id="event:"..input.id; row.eventRow=true
                    row.actionName,row.actionIcon,row.useSpellID=NR.EventPlans.Action(row)
                    self.rows[#self.rows+1]=row
                    if row.hold and row.anchor~="start" then row.held=true; self.emit("hold",row) end
                end
            end
        end
        self.bossEvents:Fire("start",now,now,false)
        self:Log("start", encounterID, now)
        self:Tick(now)
    end

    function engine:TagMatches(tag)
        if type(tag) ~= "string" then return false end
        if tag == "" then return true end
        local identity = self.identity
        for word in tag:lower():gmatch("%S+") do
            if word == "everyone" or word == "player" or word == identity.name or word == identity.fullName
                or word == identity.class or word == identity.role or word == tostring(identity.specID)
                or word == "spec:" .. tostring(identity.class) .. ":" .. tostring(identity.specIndex)
                or word == "group" .. tostring(identity.group) then return true end
        end
        return false
    end

    function engine:Tick(now)
        if not self.active then return end
        if not self.lastReadyPoll or now-self.lastReadyPoll>=0.15 then
            self.lastReadyPoll=now
            for id,watch in pairs(self.readyWatches) do
                local state=(readyReader or NR.Ready.State)(watch.row.spellID)
                if state=="cooling" then watch.armed=true
                elseif state=="ready" and watch.armed then self:CooldownReady(id,now) end
            end
        end
        for _, row in ipairs(self.rows) do
            local anchor = not row.eventRow and self.anchorTimes[row.anchor]
            local target=row.eventRow and row.target or anchor and anchor+row.time
            if target and not row.done then
                row.target = target
                if (row.eventRow and now>=row.target+row.window) or (not row.eventRow and now>row.target+self.settings.window) then
                    row.done = true
                    if row.shown then row.shown = false; self.emit("hide", row) end
                elseif now >= row.target - self.settings.lead then
                    if not row.shown then
                        row.shown = true
                        self.emit("show", row, row.target - now)
                        self:Log("reminder", row.spellID or row.actionName, now)
                    end
                    local remaining = row.target - now
                    if remaining > 0 and remaining <= 3 and self.settings.countdown then
                        local second = math.ceil(remaining)
                        if row.lastCountdown ~= second then row.lastCountdown = second; self.emit("countdown", row, second) end
                    end
                    self.emit("update", row, remaining)
                end
            end
        end
    end

    function engine:Cast(spellID, now)
        if not self.active or not NR.Number(spellID, 1, 10000000) then return end
        for _, row in ipairs(self.rows) do
            if row.shown and not row.done and (row.useSpellID or row.spellID) == spellID then
                self:WatchReady(row,now)
                row.used=true
                if self.settings.hideOnUse then row.done,row.shown=true,false;self.emit("hide",row) end
                self:Log("used", spellID, now)
            end
        end
    end

    function engine:WatchReady(row,now)
        if row.after=="ready" and row.eventCount==1 and row.target then
            local observed=self.readyObservations[row.spellID]
            local armed=observed and observed.state=="cooling" and now-observed.time<=0.5
            self.readyWatches[row.id]={row=row,armed=armed and true or false}
            self:Log("ready-watch",row.spellID,now)
        end
    end

    function engine:CooldownUpdate(now)
        if not self.active then return end
        local seen={}
        for _,row in ipairs(self.rows) do
            if row.after=="ready" and not seen[row.spellID] then
                seen[row.spellID]=true
                local state=(readyReader or NR.Ready.State)(row.spellID,true)
                self.readyObservations[row.spellID]={state=state,time=now}
                local watch=self.readyWatches[row.id]
                if watch then
                    if state=="cooling" then watch.armed=true
                    elseif state=="ready" and watch.armed then self:CooldownReady(row.id,now) end
                end
            end
        end
    end

    function engine:CooldownReady(id,now)
        local watch=self.readyWatches[id]
        if not self.active or not watch then return false end
        watch.armed=false
        local row=watch.row
        if row.shown then self.emit("hide",row) end
        row.target,row.done,row.shown,row.used,row.lastCountdown=now,false,false,false,nil
        row.postReady=true
        self:Log("cooldown-ready",row.spellID,now)
        row.shown=true;self.emit("show",row,0);self.emit("update",row,0)
        return true
    end

    function engine:BossEvent(record,now)
        for _,row in ipairs(self.rows) do
            if row.eventRow and row.anchor==record.key and (row.every or row.occurrence==record.count) then
                local same=row.eventCount==record.count and row.eventToken==record.token
                if not same then
                    self.readyWatches[row.id]=nil
                    if row.shown or row.held then self.emit("hide",row) end
                    row.done,row.used,row.shown,row.held,row.lastCountdown=false,false,false,false,nil
                elseif row.held then self.emit("hide",row); row.held=false end
                row.eventCount,row.eventToken=record.count,record.token
                if record.withdrawn then
                    self.readyWatches[row.id]=nil
                    if row.shown then self.emit("hide",row); row.shown=false end
                    row.target=nil
                    if row.hold and not row.used then row.held=true; self.emit("hold",row) end
                elseif not row.used and not self.readyWatches[row.id] then
                    row.target,row.done,row.predicted=record.at+row.time,false,record.predicted
                end
            end
        end
        self:Tick(now)
    end

    function engine:Warning(severity,now)
        if self.active and self.bossEvents then self.bossEvents:Warning(severity,now) end
    end

    function engine:UseRow(id,now)
        for _,row in ipairs(self.rows) do
            if row.id==id and row.shown and not row.done then
                self:WatchReady(row,now)
                row.done,row.shown,row.used=true,false,true; self.emit("hide",row)
                self:Log("used",row.actionName or row.spellID,now)
            end
        end
    end

    function engine:Transition(now, logicalPhase)
        self.sequence = self.sequence + 1
        self.logicalPhase = logicalPhase or self.logicalPhase
        self.lastTransition = now
        self.anchorTimes[self.sequence] = now
        -- Past phase-relative reminders are retired; pull-relative reminders retain their own clock.
        for _, row in ipairs(self.rows) do
            if type(row.anchor) == "number" and row.anchor < self.sequence and not row.done then
                row.done = true
                if row.shown then row.shown = false; self.emit("hide", row) end
            end
        end
        self:Log("phase", self.sequence, now)
        self.emit("phase", self.sequence, self.definition and self.definition.anchors[self.sequence])
        self:Tick(now)
    end

    local function recent(entries, now)
        local result = {}
        for _, entry in ipairs(entries) do if now - entry.time <= 0.3 then result[#result + 1] = entry end end
        return result
    end

    function engine:MatchesDurations(durations)
        local used = {}
        for _, duration in ipairs(durations) do
            local match
            for index, event in ipairs(self.added) do
                if not used[index] and math.abs(event.duration - duration) <= 0.1 then used[index] = true; match = true; break end
            end
            if not match then return false end
        end
        return true
    end

    -- Only the public fields reach this interface. IDs are instance IDs, never spell IDs.
    function engine:Timeline(kind, info, now)
        if not self.active or type(info) ~= "table" or not NR.Public(info) or not NR.Number(info.id, 1, 1000000000)
            or info.id % 1 ~= 0 then return end
        self.added, self.canceled = recent(self.added, now), recent(self.canceled, now)
        if kind == "added" or kind == "snapshot" then
            if not NR.Number(info.source, 0, 100) then return end
            if self.events[info.id] then return end
            local record = { source = info.source, canceled = false }
            self.events[info.id] = record
            -- Existing timers establish provenance only; they are not a new phase signal.
            if kind == "snapshot" then return end
            if info.source ~= 0 or not NR.Number(info.duration, 0, 3600) then return end
            self.added[#self.added + 1] = { id=info.id, time = now, duration = info.duration }
        elseif kind == "canceled" then
            local record = self.events[info.id]
            if not record or record.source ~= 0 or record.canceled then return end
            record.canceled = true
            self.canceled[#self.canceled + 1] = { time = now }
        elseif kind == "removed" then
            if self.bossEvents then self.bossEvents:State(info.id,kind,now) end
            self.events[info.id] = nil
            return
        elseif kind=="finished" or kind=="paused" then
            local record=self.events[info.id]
            if record and record.source==0 and self.bossEvents then self.bossEvents:State(info.id,kind,now) end
            return
        else return end
        self:Log(kind, kind == "added" and (info.id .. " duration=" .. info.duration) or info.id, now)
        if self.bossEvents then
            if kind=="canceled" then self.bossEvents:State(info.id,kind,now)
            else self.bossEvents:Batch(self.added,function(d) return self:MatchesDurations(d) end,now) end
        end
        local definition = self.definition
        if not definition or now - self.lastTransition < definition.guard then return end
        for _, rule in ipairs(definition.rules) do
            if (not rule.logicalPhase or rule.logicalPhase == self.logicalPhase)
                and (not rule.added or #self.added >= rule.added)
                and (not rule.canceled or #self.canceled >= rule.canceled)
                and (not rule.durations or self:MatchesDurations(rule.durations)) then
                self:Transition(now, rule.nextLogicalPhase)
                self.added, self.canceled = {}, {}
                break
            end
        end
    end
    return engine
end
