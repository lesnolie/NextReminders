local _, NR = ...
NR.PreviewUI = { rows = {} }
local UI = NR.PreviewUI

local T=NR.Theme
local label=T.Label
local function button(parent,text,x,y,width,action,style,icon) return T.Button(parent,text,width,x,y,action,style,icon) end
local W, TRACK = 1040, 944

function UI:Result(ok, err)
    if not ok and err then self.message:SetText(err) end
    self.lastUpdate = nil; self:Update()
end

function UI:Open(plan, dungeonChoice)
    local dungeon
    if type(plan)=="table" and plan.kind=="dungeon" then
        local ok,err=NR.EventPlans.ValidateDungeon(plan);if not ok then return nil,err end
        dungeon=NR.Copy(plan);dungeonChoice=math.max(1,math.min(dungeonChoice or 1,#dungeon.plans))
        plan=dungeon.plans[dungeonChoice]
    end
    local ok,err
    if type(plan)=="table" and plan.kind=="timeline3" then ok,err=NR.TimelinePlans.Validate(plan)
    elseif type(plan)=="table" and plan.kind=="events" then ok,err=NR.EventPlans.Validate(plan)
    else ok,err=NR.ValidatePlan(plan) end
    if not ok then return nil, err end
    if InCombatLockdown() or NR.engine.active then return nil, "请脱战并结束实际首领战后预览" end
    NR.Display:CacheFrames()
    ok, err = NR.preview:Start(plan,NR.db.settings,NR.GetIdentity(),GetTime())
    if not ok then return nil, err end
    self.selectedDungeon,self.dungeonChoice=dungeon,dungeonChoice
    self.boss:SetText(dungeon and "下一只首领（"..dungeonChoice.."/"..#dungeon.plans.."）" or "单首领方案")
    if dungeon then self.boss:Show() else self.boss:Hide() end
    self.selectedPlan = NR.Copy(plan)
    local definition=NR.BossData.encounters[plan.encounterID]
    self.title:SetText((definition and definition.name or plan.name or tostring(plan.encounterID)) .. "  ·  脱战演练，原方案保持不变")
    self.message:SetText(plan.kind=="events" and "手动事件仅演练提醒，不证明识别准确；触发按钮按预警提前量倒数。" or "手动阶段仅用于演练，实战仍需完成绑定；团框发光使用当前已有框体。")
    NR.UI.frame:Hide(); self.frame:Show()
    self.lastUpdate = nil; self:Update()
    return true
end

function UI:Update()
    if not self.frame or not self.frame:IsShown() or not NR.preview.plan then return end
    local p = NR.preview
    local signature = math.floor(p.position*5)..":"..p.status..":"..p.engine.sequence..":"..#p.actions
    if self.lastUpdate == signature then return end
    self.lastUpdate = signature
    self.clock:SetText(string.format("%02d:%04.1f  ·  %s",math.floor(p.position/60),p.position%60,p.status))
    self.play:SetText(p.running and (p.playing and "暂停" or "继续") or "重新播放")
    self.play.nrIcon:SetTexture(T.media.."ui_icon_"..(p.running and p.playing and "pause" or "play")..".tga")
    self.speed:SetText("倍速 ×"..p.speed)
    local nextPhase = p.definition.anchors[p.engine.sequence+1]
    if p.eventMode then
        self.eventOptions=NR.EventPlans.Options(p.plan.encounterID,p.plan.difficulty)
        self.eventChoice=math.max(2,math.min(self.eventChoice or 2,#self.eventOptions))
        local o=self.eventOptions[self.eventChoice]
        self.phase:SetText(o and "触发："..o.label or "只有开战事件")
        self.phase:SetEnabled(p.running and o~=nil)
        self.eventSelect:Show()
        self.ready:Show()
    else
        self.phase:SetText(nextPhase and "进入："..nextPhase or "开战相对方案 · 无需手动切阶段")
        self.phase:SetEnabled(p.running and nextPhase ~= nil); self.eventSelect:Hide(); self.ready:Hide()
    end
    local current = {}
    for _, row in ipairs(p.engine.rows) do current[row.id] = row end
    local span=math.max(60,p.position)
    for _,row in ipairs(p.engine.rows) do if row.target then span=math.max(span,row.target+10) end end
    self.span=span
    self.progress:SetWidth(math.max(4,TRACK*math.min(1,p.position/span)))
    self.cursor:ClearAllPoints(); self.cursor:SetPoint("TOPLEFT",self.timeline,"TOPLEFT",23+TRACK*math.min(1,p.position/span),-20)
    self.total:SetText(string.format("%02d:%02d",math.floor(span/60),math.floor(span%60)))
    self.markers=self.markers or {}
    for index, row in ipairs(p.plan.rows) do
        local frame=self.rows[index]
        if not frame then
            local fill=index%2==0 and "panel" or "soft"
            frame=T.Panel(self.content,0,-(index-1)*48,TRACK,44,fill,{radius=12,border=fill})
            frame.time=label(frame,"",16,-13,90)
            frame.icon=frame:CreateTexture(nil,"ARTWORK"); frame.icon:SetPoint("TOPLEFT",110,-8); frame.icon:SetSize(28,28)
            frame.icon:SetTexCoord(0.08,0.92,0.08,0.92)
            frame.text=label(frame,"",150,-13,340)
            frame.phase=label(frame,"",500,-13,190,"small")
            frame.state=label(frame,"",700,-13,140,"small")
            for _,field in ipairs({frame.text,frame.phase,frame.state}) do field:SetWordWrap(false); field:SetNonSpaceWrap(false) end
            frame.use=button(frame,"已用",852,-4,80,function() end)
            self.rows[index]=frame
        end
        local name,icon=NR.SpellCatalog.Info(row.spellID)
        frame.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local live=current[p.timelineMode and "timeline:"..row.id or p.eventMode and "event:"..row.id or row.id]
        if p.eventMode then name,icon=NR.EventPlans.Action(row); frame.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark") end
        local binding=not p.eventMode and not p.timelineMode and p.plan.phaseBindings[row.phase]
        local anchorTime=binding and p.engine.anchorTimes[binding]
        local target=live and live.target or not p.eventMode and anchorTime and anchorTime+row.time
        frame.time:SetText(target and string.format("%02d:%04.1f",math.floor(target/60),target%60) or "+"..(row.time or row.offset).."s")
        frame.text:SetText(name)
        frame.phase:SetText(p.timelineMode and row.anchor.." / "..row.timing or p.eventMode and row.anchor..(row.every and " · 每次" or " · 第"..row.occurrence.."次") or "P"..(row.phase or 1)..((binding=="pull" or binding=="time") and " · 开打" or " · 阶段"))
        local status=not p.running and p.status or not live and "未启用 / 不匹配" or not target and (p.eventMode and "等待事件" or "等待阶段") or live.done and "已结束" or live.shown and "提醒中" or "待提醒"
        frame.state:SetText(status); frame.state:SetTextColor(unpack(T.colors[live and live.shown and "positive" or "muted"]))
        local spellID=row.spellID
        local rowID=live and live.id
        frame.use:SetScript("OnClick",function()
            if p.eventMode then NR.preview:UseRow(rowID,GetTime()) else NR.preview:Cast(spellID,GetTime()) end
            self.lastUpdate=nil; self:Update()
        end)
        frame.use:SetEnabled(p.running and live and live.shown or false); frame:Show()
        local marker=self.markers[index]
        if not marker then marker=self.timeline:CreateTexture(nil,"ARTWORK"); marker:SetSize(4,16); self.markers[index]=marker end
        if target then
            marker:ClearAllPoints(); marker:SetPoint("TOPLEFT",self.timeline,"TOPLEFT",22+TRACK*math.min(1,target/span),-22)
            marker:SetColorTexture(unpack(T.colors[live and live.shown and "positive" or "ink"])); marker:Show()
        else marker:Hide() end
    end
    for index=#p.plan.rows+1,#self.rows do self.rows[index]:Hide() end
    for index=#p.plan.rows+1,#self.markers do self.markers[index]:Hide() end
    self.content:SetHeight(math.max(174,#p.plan.rows*48))

end

function UI:Create()
    local frame=T.Window("NextRemindersPreview",W,660,"方案播放")
    self.frame=frame
    self.title=label(frame,"脱战演练 · 原方案保持不变",24,-80,700,"muted")
    self.boss=button(frame.header,"下一只首领",W-60-12-220,-20,220,function()
        local d=self.selectedDungeon;if not d then return end
        self:Result(self:Open(d,(self.dungeonChoice or 1)%#d.plans+1))
    end)
    self.boss:Hide()
    local hero=T.Panel(frame,24,-112,W-48,96)
    self.clock=label(hero,"00:00.0 · 未开始",24,-30,370,"title")
    self.play=button(hero,"暂停",400,-30,104,function()
        if not NR.preview.running then
            self:Result(NR.preview:Start(self.selectedPlan,NR.db.settings,NR.GetIdentity(),GetTime()))
        elseif NR.preview.playing then NR.preview:Pause(GetTime()); self:Result(true)
        else self:Result(NR.preview:Resume(GetTime())) end
    end,"primary","pause")
    self.stop=button(hero,"停止",516,-30,92,function() NR.preview:Stop(); self:Result(true) end,nil,"stop")
    self.speed=button(hero,"倍速 ×1",620,-30,100,function()
        local speed=({[1]=2,[2]=4,[4]=1})[NR.preview.speed]
        local ok,err=NR.preview:SetSpeed(speed,GetTime()); self:Result(ok,err)
    end)
    label(hero,"跳到秒数",732,-39,64,"small")
    self.seek=T.Edit(hero,72,796,-30); self.seek:SetText("0")
    self.jump=button(hero,"跳转",880,-30,88,function() self:Result(NR.preview:Seek(tonumber(self.seek:GetText()),GetTime())) end)
    self.phase=button(frame,"进入下一阶段",24,-222,600,function()
        if NR.preview.eventMode then
            local o=self.eventOptions and self.eventOptions[self.eventChoice]
            if o then self:Result(NR.preview:Event(o.key,GetTime())) end
        else self:Result(NR.preview:NextPhase(GetTime())) end
    end)
    self.eventSelect=button(frame,"切换事件",636,-222,160,function()
        self.eventChoice=(self.eventChoice or 2)+1
        if self.eventChoice>#self.eventOptions then self.eventChoice=2 end
        self.lastUpdate=nil; self:Update()
    end,"field")
    self.eventSelect:Hide()
    self.ready=button(frame,"模拟冷却结束",808,-222,208,function() self:Result(NR.preview:Ready(GetTime())) end)
    self.ready:Hide()
    self.timeline=T.Panel(frame,24,-272,W-48,84)
    local track=T.Panel(self.timeline,24,-30,TRACK,6,"track",{radius=3,border="track"})
    self.progress=T.Panel(track,0,0,4,6,"accent",{radius=3,border="accent"})
    self.cursor=self.timeline:CreateTexture(nil,"OVERLAY"); self.cursor:SetSize(2,24); self.cursor:SetColorTexture(unpack(T.colors.ink))
    label(self.timeline,"00:00",24,-52,100,"small")
    -- Click anywhere on the timeline to jump there (starts playback first when stopped).
    self.timeline:EnableMouse(true)
    self.timeline:SetScript("OnMouseDown",function(timeline)
        local left,scale=timeline:GetLeft(),timeline:GetEffectiveScale()
        if not (self.span and NR.Number(left,-100000,100000) and NR.Number(scale,0.01,100)) then return end
        local ratio=math.max(0,math.min(1,(GetCursorPosition()/scale-left-24)/TRACK))
        if not NR.preview.running then
            local ok,err=NR.preview:Start(self.selectedPlan,NR.db.settings,NR.GetIdentity(),GetTime())
            if not ok then return self:Result(ok,err) end
        end
        self:Result(NR.preview:Seek(math.floor(ratio*self.span*10+0.5)/10,GetTime()))
    end)
    self.total=label(self.timeline,"",W-48-128,-52,104,"small"); self.total:SetJustifyH("RIGHT")
    local list=T.Panel(frame,24,-370,W-48,232)
    label(list,"时点",32,-16,86,"small"); label(list,"技能",166,-16,280,"small")
    label(list,"阶段",516,-16,160,"small"); label(list,"状态",716,-16,120,"small")
    local scroll=T.Scroll(frame,40,-408,TRACK,180)
    self.content=CreateFrame("Frame",nil,scroll); self.content:SetSize(TRACK,180); scroll:SetScrollChild(self.content)
    self.message=label(frame,"",24,-618,W-48,"small"); self.message:SetHeight(30)
    frame:Hide(); frame:SetScript("OnHide",function() NR.preview:Stop(); NR.Cleanup("close") end)
end
