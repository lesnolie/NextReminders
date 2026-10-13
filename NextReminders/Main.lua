local addonName, NR = ...
local driver = CreateFrame("Frame")
local elapsedTick = 0
local difficultyNames = { [1]="normal",[2]="heroic",[8]="mythic",[23]="mythic",[14]="normal",[15]="heroic",[16]="mythic",[233]="mythic" }

local function identity()
    local name, realm = UnitName("player")
    local result = {}
    if NR.Public(name) and type(name) == "string" then
        result.name = name:lower()
        result.fullName = NR.Public(realm) and type(realm)=="string" and realm~="" and (name.."-"..realm):lower() or result.name
    end
    local _, class = UnitClass("player")
    if NR.Public(class) and type(class)=="string" then result.class = class:lower() end
    local role = UnitGroupRolesAssigned("player")
    if NR.Public(role) and type(role)=="string" then result.role = role:lower() end
    if GetSpecialization and GetSpecializationInfo then
        local index = GetSpecialization()
        if NR.Number(index,1,4) then
            result.specIndex = index
            local id = GetSpecializationInfo(index)
            if NR.Number(id,1,10000) then result.specID=id end
        end
    end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local sameUnit = UnitIsUnit("raid"..i,"player")
            if NR.Public(sameUnit) and sameUnit then
                local _, _, group = GetRaidRosterInfo(i)
                if NR.Number(group,1,8) then result.group=group end
                break
            end
        end
    end
    return result
end

NR.GetIdentity = identity

local function snapshotTimeline(now)
    if not C_EncounterTimeline or not C_EncounterTimeline.GetEventList or not C_EncounterTimeline.GetEventInfo
        or not C_EncounterTimeline.GetEventState then return end
    local events = C_EncounterTimeline.GetEventList()
    if not NR.Public(events) or type(events) ~= "table" then return end
    for _, id in ipairs(events) do
        if NR.Number(id,1,1000000000) then
            local info = C_EncounterTimeline.GetEventInfo(id)
            local state = C_EncounterTimeline.GetEventState(id)
            if NR.Public(info) and type(info) == "table" and NR.Public(state)
                and state ~= Enum.EncounterTimelineEventState.Canceled and state ~= Enum.EncounterTimelineEventState.Finished then
                NR.engine:Timeline("snapshot",{id=id,source=info.source},now)
            end
        end
    end
end

local function initialize()
    NextRemindersDB = type(NextRemindersDB)=="table" and NextRemindersDB or {}
    NR.db = NextRemindersDB
    NR.db.schema = 1
    NR.db.enabled=NR.db.enabled~=false
    NR.db.plans = type(NR.db.plans)=="table" and NR.db.plans or {}
    NR.db.previousPlans = type(NR.db.previousPlans)=="table" and NR.db.previousPlans or {}
    NR.db.eventPlans = type(NR.db.eventPlans)=="table" and NR.db.eventPlans or {}
    NR.db.settings = NR.Settings(NR.db.settings)
    NR.Display:Create()
    NR.engine = NR.Engine.New(function(kind,row,value) NR.Display:Emit(kind,row,value) end)
    NR.preview = NR.Preview.New(function(kind,row,value)
        if kind == "phase" then if value then NR.Print("预览节点："..value) end
        else NR.Display:Emit(kind,row,value) end
    end, function() NR.Display:Clear() end, function() return InCombatLockdown() or NR.engine.active end)
    NR.UI:Create(); NR.PreviewUI:Create()
    SLASH_NEXTREMINDERS1 = "/nr"
    SlashCmdList.NEXTREMINDERS = function(args)
        args = NR.Trim(args):lower()
        if args == "log" then
            for _, entry in ipairs(NR.engine.trace) do NR.Print(string.format("%.2f 秒　%s　%s", entry.time,entry.kind,tostring(entry.detail))) end
        elseif args == "spells" then
            local entries=NR.SpellCatalog.ForSpec(identity().specID)
            NR.Print("本专精内置爆发技能（含可选天赋；提醒时点在网页设置）：")
            for _,entry in ipairs(entries) do
                local name=NR.SpellCatalog.Info(entry.id)
                NR.Print(name.." · "..entry.id..(entry.talent and " · 可选天赋" or ""))
            end
            if #entries==0 then NR.Print("请先切换到已选择的专精。") end
        elseif args == "test" then
            if InCombatLockdown() or NR.engine.active then NR.Print("请脱战后测试") return end
            -- A synthetic, valid encounter keeps the demo on the real validation/scheduling path.
            NR.Display:CacheFrames()
            NR.preview:Start({enabled=true,encounterID=999999,difficulty="mythic",personal=true,phaseBindings={[1]="pull"},
                rows={{id=1,spellID=51271,phase=1,time=5,tag="player"}}},NR.db.settings,identity(),GetTime())
            NR.Print("测试冰霜之柱提醒；用过隐藏，或输入 /nr stop 停止。")
        elseif args == "preview" then
            local plan = NR.db.lastPlan and NR.db.plans[NR.db.lastPlan]
            if NR.db.lastPlanKind=="dungeon" then plan=NR.EventPlans.LastDungeon(NR.db.lastDungeon)
            elseif NR.db.lastPlanKind=="events" and NR.db.lastEventPlan then
                local last=NR.db.lastEventPlan
                plan=NR.EventPlans.Find(last.specID,last.encounterID,last.difficulty)
            end
            local ok,err = NR.PreviewUI:Open(plan)
            if not ok then NR.Print(err) end
        elseif args == "stop" then NR.preview:Stop(); NR.engine:Stop(); NR.Display:Clear()
        else NR.UI:Toggle() end
    end
    driver:SetScript("OnUpdate", function(_, elapsed)
        elapsedTick = elapsedTick + elapsed
        if elapsedTick < 0.05 then return end
        elapsedTick = 0
        local now = GetTime()
        NR.preview:Tick(now)
        NR.engine:Tick(now)
        NR.Display:RefreshGlows()
        NR.PreviewUI:Update()
    end)
    driver:RegisterEvent("ENCOUNTER_START"); driver:RegisterEvent("ENCOUNTER_END")
    driver:RegisterEvent("ENCOUNTER_WARNING")
    driver:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    driver:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED","player")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED"); driver:RegisterEvent("GROUP_ROSTER_UPDATE")
    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    if C_EncounterTimeline then
        driver:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
        driver:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
        driver:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
    end
end

driver:RegisterEvent("ADDON_LOADED")
driver:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then initialize(); driver:UnregisterEvent("ADDON_LOADED") end
        return
    end
    if not NR.engine then return end
    local now = GetTime()
    if event == "ENCOUNTER_START" then
        local encounterID, _, difficulty = ...
        if not NR.Number(encounterID,1,1000000) or not NR.Number(difficulty,0,1000) then return end
        NR.preview:Stop(); NR.PreviewUI.frame:Hide(); NR.Display:Clear(); NR.UI.frame:Hide()
        local difficultyName = difficultyNames[difficulty]
        if not difficultyName then NR.engine:Stop(); return end
        local plan = NR.db.plans[encounterID..":"..difficultyName]
        -- SavedVariables can outlive data updates; revalidate every binding at encounter start.
        if plan and not NR.ValidateBindings(plan) then NR.Print("方案阶段绑定已失效，本场不加载提醒"); plan=nil end
        local player=identity()
        local eventPlan=player.specID and NR.EventPlans.Get(player.specID,encounterID,difficultyName)
        -- A complete M+ bundle supersedes legacy static notes for this spec/dungeon.
        -- Keep those notes stored, so another spec and rollback still use their own context.
        if difficulty==8 and NR.EventPlans.OwnsDungeonEncounter(player.specID,encounterID) then plan=nil end
        if eventPlan and eventPlan.dungeonID and difficulty~=8 then eventPlan=nil end
        if not NR.db.enabled then plan,eventPlan=nil,nil end
        NR.engine:Begin(encounterID,difficultyName,plan,NR.db.settings,now,player,
            eventPlan)
        snapshotTimeline(now)
    elseif event=="ENCOUNTER_WARNING" then
        local info=...
        if NR.Public(info) and type(info)=="table" then NR.engine:Warning(info.severity,now) end
    elseif event=="SPELL_UPDATE_COOLDOWN" then
        -- Scan configured public spell IDs; event payload IDs may be secret.
        NR.engine:CooldownUpdate(now)
    elseif event == "ENCOUNTER_END" then NR.engine:Stop(); NR.Display:Clear()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if NR.Public(unit) and unit == "player" then
            if NR.preview.running then NR.preview:Cast(spellID,now) else NR.engine:Cast(spellID,now) end
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ENTERING_WORLD" then
        NR.preview:Stop(); NR.PreviewUI.frame:Hide()
        if event=="PLAYER_ENTERING_WORLD" then NR.engine:Stop();NR.Display:Clear() end
        NR.Display:CacheFrames()
    elseif event == "ENCOUNTER_TIMELINE_EVENT_ADDED" then
        local info = ...
        if NR.Public(info) and type(info)=="table" then NR.engine:Timeline("added",{id=info.id,source=info.source,duration=info.duration},now) end
    elseif event == "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED" then
        local id = ...
        if NR.Number(id,1,1000000000) then
            local state = C_EncounterTimeline.GetEventState(id)
            if NR.Public(state) then
                local states=Enum.EncounterTimelineEventState
                local kind=state==states.Canceled and "canceled" or state==states.Finished and "finished" or state==states.Paused and "paused"
                if kind then NR.engine:Timeline(kind,{id=id},now) end
            end
        end
    elseif event == "ENCOUNTER_TIMELINE_EVENT_REMOVED" then NR.engine:Timeline("removed",{id=(...)},now)
    else NR.Display:CacheFrames() end
end)
