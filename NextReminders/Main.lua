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
            local id, specName = GetSpecializationInfo(index)
            if NR.Number(id,1,10000) then result.specID=id end
            if NR.Public(specName) and type(specName)=="string" then result.specName=specName end
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

-- Static plans moved to per-spec storage in 0.3.8; the move waits until the client reports a spec.
local function migratePlans()
    local moved = NR.MigrateNotePlans(identity().specID)
    if moved and moved > 0 then NR.Print("旧的团本方案已按专精分开保存（"..moved.." 个）；切换专精只看到各自的方案。") end
end

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

-- BigWigs supplies optional public stage and boss-warning messages; no private state is read.
local function bigWigsEncounter(module)
    if type(module) ~= "table" or type(module.GetEncounterID) ~= "function" then return nil end
    local ok, id = pcall(module.GetEncounterID, module)
    return ok and NR.Number(id, 1, 1000000) and id or nil
end

local function hookBigWigs()
    local loader = rawget(_G, "BigWigsLoader")
    if NR.bigWigsHooked or type(loader) ~= "table" or type(loader.RegisterMessage) ~= "function" then return end
    NR.bigWigsHooked = true
    local owner = {}
    loader.RegisterMessage(owner, "BigWigs_OnBossEngage", function(_, module)
        local id, now = bigWigsEncounter(module), GetTime()
        if not id then return end
        NR.bigWigsEngage = { id = id, at = now }
        if NR.engine.active and NR.engine.encounterID == id then NR.engine:StageReady(now) end
    end)
    loader.RegisterMessage(owner, "BigWigs_SetStage", function(_, module, stage)
        local id = bigWigsEncounter(module)
        if id and NR.engine.active and NR.engine.encounterID == id then NR.engine:Stage(stage, GetTime()) end
    end)
    loader.RegisterMessage(owner, "BigWigs_Message", function(_, module, spellID)
        local id = bigWigsEncounter(module)
        if id and NR.engine.active and NR.engine.encounterID == id and NR.engine.bossEvents then
            NR.engine.bossEvents:BigWigsMessage(spellID, GetTime())
        end
    end)
end

local function initialize()
    NextRemindersDB = type(NextRemindersDB)=="table" and NextRemindersDB or {}
    NR.db = NextRemindersDB
    NR.db.schema = 1
    NR.db.enabled=NR.db.enabled~=false
    NR.db.eventPlans = type(NR.db.eventPlans)=="table" and NR.db.eventPlans or {}
    NR.db.settings = NR.Settings(NR.db.settings)
    NR.Display:Create()
    NR.engine = NR.Engine.New(function(kind,row,value) NR.Display:Emit(kind,row,value) end)
    NR.preview = NR.Preview.New(function(kind,row,value)
        if kind == "phase" then if value then NR.Print("预览节点："..value) end
        else NR.Display:Emit(kind,row,value) end
    end, function() NR.Display:Clear() end, function() return InCombatLockdown() or NR.engine.active end)
    NR.UI:Create(); NR.PreviewUI:Create()
    migratePlans()
    hookBigWigs()
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
        elseif args == "plans" or args == "preview" then
            local ok,err = NR.PreviewUI:OpenLibrary(nil, args == "preview")
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
    driver:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED","player")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    if C_EncounterTimeline then
        driver:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_ADDED")
        driver:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED")
        driver:RegisterEvent("ENCOUNTER_TIMELINE_EVENT_REMOVED")
    end
end

-- Stop leftover playback and release encounter state; let Lua reclaim unused data normally.
-- Defer state cleanup while combat or an encounter is still active.
function NR.Cleanup(reason)
    if InCombatLockdown() or NR.engine.active or (IsEncounterInProgress and IsEncounterInProgress()) then
        NR.cleanupPending = true
        return nil, "战斗中不清理，脱战后自动清理"
    end
    if NR.preview.running then return nil, "正在播放预览，停止后再清理" end
    NR.cleanupPending = nil
    NR.Display:Silence(); NR.Display:Clear()
    NR.engine:Stop(); NR.preview:Stop()
    if not NR.PreviewUI.frame:IsShown() then NR.PreviewUI.selectedPlan, NR.PreviewUI.selectedDungeon = nil, nil end
    NR.lastCleanup = reason
    return true
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
        hookBigWigs()
        NR.preview:Stop(); NR.PreviewUI.frame:Hide(); NR.Display:Clear(); NR.UI.frame:Hide()
        local difficultyName = difficultyNames[difficulty]
        if not difficultyName then NR.engine:Stop(); return end
        local player=identity()
        local notes=player.specID and NR.NotePlans(player.specID)
        local plan = notes and notes.plans[encounterID..":"..difficultyName]
        -- SavedVariables can outlive data updates; revalidate every binding at encounter start.
        if plan and not NR.ValidateBindings(plan) then NR.Print("方案阶段绑定已失效，本场不加载提醒"); plan=nil end
        local eventPlan=player.specID and NR.EventPlans.Get(player.specID,encounterID,difficultyName)
        local timelinePlan=player.specID and NR.TimelinePlans.Get(player.specID,encounterID,difficultyName)
        if player.specID and NR.TimelinePlans.Find(player.specID,encounterID,difficultyName) then
            plan,eventPlan=nil,nil
        end
        -- A complete M+ bundle supersedes legacy static notes for this spec/dungeon.
        -- Keep those notes stored, so another spec and rollback still use their own context.
        if difficulty==8 and NR.EventPlans.OwnsDungeonEncounter(player.specID,encounterID) then plan=nil end
        if eventPlan and eventPlan.dungeonID and difficulty~=8 then eventPlan=nil end
        if difficulty==8 and not plan and not eventPlan and player.specID and NR.Settings(NR.db.settings).autoBurst then
            eventPlan=NR.EventPlans.Default(player.specID,encounterID)
        end
        if not NR.db.enabled then plan,eventPlan,timelinePlan=nil,nil,nil end
        NR.engine:Begin(encounterID,difficultyName,plan,NR.db.settings,now,player,
            eventPlan,timelinePlan)
        -- BigWigs may have engaged on this same ENCOUNTER_START before our handler ran.
        local engaged = NR.bigWigsEngage
        if engaged and engaged.id == encounterID and now - engaged.at <= 5 then NR.engine:StageReady(now) end
        snapshotTimeline(now)
    elseif event=="ENCOUNTER_WARNING" then
        local info=...
        if NR.Public(info) and type(info)=="table" then NR.engine:Warning(info.severity,now) end
    elseif event=="SPELL_UPDATE_COOLDOWN" then
        -- Scan configured public spell IDs; event payload IDs may be secret.
        NR.engine:CooldownUpdate(now)
    elseif event == "ENCOUNTER_END" then NR.engine:Stop(); NR.Display:Clear(); NR.Cleanup("encounter")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if NR.Public(unit) and unit == "player" then
            if NR.preview.running then NR.preview:Cast(spellID,now) else NR.engine:Cast(spellID,now) end
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        migratePlans()
        if NR.PreviewUI.frame:IsShown() then NR.PreviewUI:OpenLibrary() end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ENTERING_WORLD" then
        if event=="PLAYER_ENTERING_WORLD" then migratePlans() end
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
    else
        NR.Display:CacheFrames()
        if event == "PLAYER_REGEN_ENABLED" and NR.cleanupPending then NR.Cleanup("combat") end
    end
end)
