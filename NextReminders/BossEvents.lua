local _, NR = ...
NR.BossEvents = {}
-- Per-fight observations/predictions. Timeline instance IDs are never mechanism IDs.
function NR.BossEvents.New(definitions, publish, log)
    local s={definitions=definitions,counts={},records={},pending={}}
    function s:Fire(key,at,now,predicted,token)
        local d=self.definitions[key]
        if key~="start" and not d then return end
        local old=self.records[key]
        if old and token and old.token==token then return end
        if old and now-old.observed<(d and d.guard or 5) then return end
        local count=(self.counts[key] or 0)+1
        if d and count>(d.maxCount or 20) then return end
        self.counts[key]=count
        local r={key=key,at=at,count=count,predicted=predicted,token=token,observed=now}
        self.records[key]=r
        log("boss-event",key.." #"..count.." at="..at..(predicted and " predicted" or " signal"),now)
        publish(r,now)
        return r
    end
    function s:Warning(severity,now)
        if not NR.Number(severity,0,10) then return end
        for key,d in pairs(self.definitions) do
            if d.warning and severity==d.warning.severity then self:Fire(key,now+d.delay,now,true) end
        end
    end
    function s:BigWigsMessage(spellID,now)
        if not NR.Number(spellID,1,10000000) then return end
        for key,d in pairs(self.definitions) do
            if d.bigWigsMessage == spellID then
                -- Same warning as the native event. Fire's guard deduplicates either arrival order.
                self:Fire(key,now+(d.delay or 0),now,true)
            end
        end
    end
    function s:Batch(entries,matches,now)
        for key,d in pairs(self.definitions) do
            if d.batch and matches(d.batch) then self:Fire(key,now,now,false,entries[1] and entries[1].id)
            elseif d.bar and matches(d.bar.batch) and not self.pending[key] then
                local candidates={}
                for _,e in ipairs(entries) do
                    if math.abs(e.duration-d.bar.duration)<=0.1 then candidates[#candidates+1]=e end
                end
                -- Ambiguous duration matches are not assigned a mechanism identity.
                if #candidates==1 then
                    local e=candidates[1]
                    local r=self:Fire(key,e.time+e.duration,now,true,e.id)
                    if r then self.pending[key]=r end
                end
            end
        end
    end
    function s:State(id,kind,now)
        for key,r in pairs(self.pending) do
            if r.token==id then
                if kind=="finished" then
                    r.at,r.predicted,r.withdrawn=now,false,false
                    publish(r,now); self.pending[key]=nil
                elseif kind=="paused" or kind=="canceled" or kind=="removed" then
                    -- Never allow a paused/removed timer to fire at its obsolete expected end.
                    r.withdrawn=true; publish(r,now)
                    if kind~="paused" then
                        self.pending[key]=nil
                        self.counts[key]=math.max(0,self.counts[key]-1)
                        self.records[key]=nil
                    end
                end
                log("boss-timer",key.." "..kind,now)
            end
        end
    end
    function s:Get(key) return self.records[key] end
    -- Same public semantics as the reference condition: latest occurrence, [from,to), count>=N.
    function s:Check(key,now,from,to,count)
        local r=self:Get(key)
        if not r or r.withdrawn then return false end
        if count then return r.count>=count end
        return now>=r.at+(from or 0) and now<r.at+(to or 10)
    end
    return s
end
