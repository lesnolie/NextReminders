local _, NR = ...
NR.UI = {}
local UI = NR.UI

local button, label, edit, check = NR.Theme.Button, NR.Theme.Label, NR.Theme.Edit, NR.Theme.Check

function UI:Message(text) self.message:SetText(text) end

function UI:Refresh()
    self.dataVersion:SetText("v" .. NR.version .. "  ·  数据 " .. NR.BossData.dataVersion)
    local s = NR.db.settings
    self.lead:SetText(tostring(s.lead)); self.window:SetText(tostring(s.window)); self.glow:SetText(s.glow)
    for key, control in pairs(self.checks) do control:SetChecked(s[key]) end
    self.volume:SetText(tostring(s.volume))
    self.soundValues = {}
    for key in pairs(self.soundPicks) do self:SetSoundChoice(key,s[key]) end
    self:PaintEnable(); self:ShowMemory()
    self:Message(self:PageHint())
end

function UI:PageHint()
    if self.page == "settings" then return "修改后点击“保存设置”；战斗中不能保存。" end
    return "大秘境粘贴网站整副本方案；团本粘贴 Lorrgs MRT／NSRT，动态阶段需核对绑定。"
end

function UI:Parse()
    if InCombatLockdown() then self:Message("请脱战后导入") return end
    local targetDifficulty = self.difficulty ~= "source" and self.difficulty or nil
    local text=self.note:GetText()
    local plan,err
    if text:match("^%s*NRDungeon:") or text:match("\n%s*NRDungeon:") then plan,err=NR.EventPlans.ParseDungeon(text)
    elseif text:match("^%s*NRPlan:3;") or text:match("\n%s*NRPlan:3;") then plan,err=NR.TimelinePlans.Parse(text)
    elseif text:match("^%s*NRPlan:") or text:match("\n%s*NRPlan:") then plan,err=NR.EventPlans.Parse(text)
    else plan, err = NR.ParseNote(text, { personal = self.personal:GetChecked(),
        encounterID = tonumber(self.encounter:GetText()), difficulty = targetDifficulty or "mythic",
        targetDifficulty = targetDifficulty }) end
    for _, control in ipairs(self.binders or {}) do control:Hide() end
    self.binders, self.preview = self.binders or {}, plan
    if not plan then self:Message(err); self.summary:SetText(""); self.bindingScroll:Hide(); self.bindingTitle:Hide(); return end
    if plan.kind=="dungeon" then
        local d=NR.DungeonData.dungeons[plan.dungeonID]
        local names={}
        for _,p in ipairs(plan.plans) do names[#names+1]="#"..p.encounterID.."（"..#p.rows.."条）" end
        self.summary:SetText(d.name.."\n专精 "..plan.specID.." · 大秘境 · "..#plan.plans.."/"..#d.bosses.." 只首领\n"..table.concat(names," / ").."\n保存会更新此副本全部首领规则；未配置的旧规则清除，可整包回滚。")
        self.bindingScroll:Hide();self.bindingTitle:Hide()
        self.lastParsedText,self.lastPersonal,self.lastEncounterText,self.lastDifficulty=text,self.personal:GetChecked(),self.encounter:GetText(),self.difficulty
        self:Message("整副本检查通过；预览可切换首领。事件识别仍需游戏核对。")
        return
    end
    if plan.kind=="events" or plan.kind=="timeline3" then
        local boss=NR.BossData.encounters[plan.encounterID]
        self.summary:SetText((boss and boss.name or plan.name).."\n专精 "..plan.specID.." · "..plan.difficulty.." · "..#plan.rows.." 条规则\n含事件条件、次数和等待提示。")
        self.bindingScroll:Hide(); self.bindingTitle:Hide()
        self.lastParsedText,self.lastPersonal,self.lastEncounterText,self.lastDifficulty=text,self.personal:GetChecked(),self.encounter:GetText(),self.difficulty
        self:Message("检查通过，点击保存启用；事件识别准确性仍需游戏验证。")
        return
    end
    local phases, seen = {}, {}
    for _, row in ipairs(plan.rows) do if row.phase > 1 and not seen[row.phase] then phases[#phases + 1] = row.phase; seen[row.phase] = true end end
    table.sort(phases)
    local definition = NR.BossData.encounters[plan.encounterID]
    local anchors = {}
    for anchor in pairs(plan.difficulty == "mythic" and definition and definition.anchors or {}) do anchors[#anchors + 1] = anchor end
    table.sort(anchors)
    table.insert(anchors, 1, "pull")
    local function anchorLabel(anchor)
        if anchor == "pull" then return "开打（确认此来源阶段从开打开始）" end
        if anchor == "stage" then return "BigWigs 阶段（自动）" end
        if anchor == "time" then return "按右侧时间（开打后）" end
        return definition.anchors[anchor]
    end
    self.fallbacks = self.fallbacks or {}
    for _, control in ipairs(self.fallbacks) do control:Hide() end
    for index, phase in ipairs(phases) do
        local sourcePhase = phase
        local choices = { unpack(anchors) }
        if NR.Stages.Supports(plan.encounterID, sourcePhase) then table.insert(choices, 2, "stage") end
        choices[#choices + 1] = "time"
        local choice = 0
        for position, anchor in ipairs(choices) do if plan.phaseBindings[sourcePhase] == anchor then choice = position end end
        local control, timeBox = self.binders[index], self.fallbacks[index]
        if not control then
            control = button(self.bindingContent, "", 272, 0, -(index - 1) * 40, function() end, "field")
            self.binders[index] = control
        end
        if not timeBox then
            timeBox = edit(self.bindingContent, 92, 284, -(index - 1) * 40)
            self.fallbacks[index] = timeBox
        end
        local function show()
            local bound = choices[choice]
            control:SetText("P" .. sourcePhase .. " → " .. (bound and anchorLabel(bound) or "未绑定，点击选择"))
        end
        show()
        control:SetScript("OnClick", function()
            choice = choice + 1
            if choice > #choices then choice = 0 end
            plan.phaseBindings[sourcePhase] = choices[choice] or false
            show()
        end)
        -- Transition time from the pull: used by "time", and by "stage" when BigWigs is absent.
        timeBox:SetScript("OnTextChanged", nil)
        timeBox:SetText("m:ss")
        timeBox:SetScript("OnTextChanged", function()
            local seconds = NR.ParseClock(timeBox:GetText())
            plan.phaseFallback[sourcePhase] = seconds
            if seconds and not plan.phaseBindings[sourcePhase] then
                for position, anchor in ipairs(choices) do if anchor == "time" then choice = position end end
                plan.phaseBindings[sourcePhase] = "time"; show()
            end
        end)
        control:Show(); timeBox:Show()
    end
    self.bindingContent:SetHeight(math.max(112,#phases*40))
    if #phases>0 then self.bindingScroll:Show(); self.bindingTitle:Show()
    else self.bindingScroll:Hide(); self.bindingTitle:Hide() end
    local difficultyLabels = {normal="普通",heroic="英雄",mythic="史诗／大秘境"}
    local origin = plan.sourceDifficulty and "（来源：" .. difficultyLabels[plan.sourceDifficulty] .. "）" or ""
    local summary = { (definition and definition.name or plan.name) .. "　用于：" .. difficultyLabels[plan.difficulty] .. origin .. "　" .. #plan.rows .. " 条提醒" }
    local fixed = definition and definition.fixed and definition.fixed[1]
    local times = fixed and (plan.difficulty == "heroic" and fixed.timesHeroic or plan.difficulty == "mythic" and (fixed.timesMythic or fixed.times))
    if times then
        local reference = {}
        for index = 1, math.min(3, #times) do reference[#reference+1] = string.format("%.1f",times[index]) end
        summary[#summary+1] = fixed.name .. "：开打后 " .. table.concat(reference," / ") .. " 秒（预报参考）"
    end
    for index = 1, math.min(2 - (times and 1 or 0), #plan.rows) do
        local row = plan.rows[index]
        summary[#summary + 1] = string.format("P%s + %.1f 秒　%s", NR.PhaseLabel(row.phase), row.time, NR.Theme.SpellName(row.spellID))
    end
    self.summary:SetText(table.concat(summary, "\n"))
    local stages = NR.BossData.stages[plan.encounterID]
    self:Message(#phases > 0 and "核对每个来源阶段：BigWigs 自动需要装 BigWigs；右侧填开打后几秒转阶段（如 2:15）作为备用。"
        .. (stages and stages.note and " " .. stages.note or "") or "预览成功。保存会启用此方案，并备份此首领原方案。")
    if definition and definition.warning then self:Message(self.message:GetText() .. " " .. definition.warning) end
    if plan.sourceDifficulty and plan.sourceDifficulty ~= plan.difficulty then
        self:Message(self.message:GetText() .. " 跨难度复用：原施法秒数保留，请核对实际机制时点。")
    end
    self.lastParsedText = self.note:GetText()
    self.lastPersonal = self.personal:GetChecked()
    self.lastEncounterText = self.encounter:GetText()
    self.lastDifficulty = self.difficulty
end

function UI:CurrentPlan()
    if not self.preview or self.lastParsedText ~= self.note:GetText() or self.lastPersonal ~= self.personal:GetChecked() then
        return nil, "文本或个人／团队选项已变化，请重新预览"
    end
    if self.lastDifficulty ~= self.difficulty or (self.preview.format == "MRT" and self.lastEncounterText ~= self.encounter:GetText()) then
        return nil, "首领或使用难度已变化，请重新预览"
    end
    return self.preview
end

function UI:Play()
    local plan, err = self:CurrentPlan()
    if not plan then self:Message(err); return end
    local ok
    ok,err = NR.PreviewUI:Open(plan)
    if not ok then self:Message(err) end
end

function UI:Save()
    if InCombatLockdown() then self:Message("请脱战后保存") return end
    local input, err = self:CurrentPlan()
    if not input then self:Message(err); return end
    local ok
    if input.kind=="timeline3" then
        ok,err=NR.TimelinePlans.Save(input)
        if not ok then self:Message(err); return end
        NR.db.lastPlanKind="timeline3"
        self:Message("已保存时间轴方案；本专精同首领优先使用，旧方案保留。固定兜底不是实测。")
        return
    end
    if input.kind=="dungeon" then
        ok,err=NR.EventPlans.SaveDungeon(input)
        if not ok then self:Message(err);return end
        NR.db.lastPlanKind="dungeon"
        self:Message("已导入整副本方案；按专精和首领自动匹配，原规则已整包备份。")
        return
    end
    if input.kind=="events" then
        ok,err=NR.EventPlans.Save(input)
        if not ok then self:Message(err); return end
        NR.db.lastEventPlan={specID=input.specID,encounterID=input.encounterID,difficulty=input.difficulty}
        NR.db.lastPlanKind="events"
        self:Message("已导入网站规则；本专精、首领和难度自动匹配。")
        return
    end
    ok, err = NR.ValidateBindings(input)
    if not ok then self:Message(err) return end
    local key = self.preview.encounterID .. ":" .. self.preview.difficulty
    local old = NR.db.plans[key]
    if old then NR.db.previousPlans[key] = NR.Copy(old) end
    local plan = NR.Copy(self.preview)
    plan.enabled, plan.importedAt, plan.dataVersion = true, time(), NR.BossData.dataVersion
    NR.db.plans[key] = plan
    NR.db.lastPlan = key
    NR.db.lastPlanKind="timeline"
    self:Message("已保存并启用 " .. #plan.rows .. " 条提醒。" .. (old and "原方案已备份，可回滚。" or ""))
end

function UI:SaveSettings()
    if InCombatLockdown() then self:Message("请脱战后修改设置") return end
    local lead, window, volume = tonumber(self.lead:GetText()), tonumber(self.window:GetText()), tonumber(self.volume:GetText())
    if not NR.Number(lead, 0, 60) or not NR.Number(window, 0, 60) or not NR.Number(volume, 0, 100) then
        self:Message("提前量／保留时间需为 0～60 秒，音量需为 0～100") return
    end
    local settings = NR.Copy(NR.db.settings)
    settings.lead, settings.window, settings.volume, settings.glow = lead, window, volume, self.glow:GetText()
    for key,value in pairs(self.soundValues or {}) do settings[key] = value end
    for key, control in pairs(self.checks) do settings[key] = control:GetChecked() and true or false end
    NR.db.settings = NR.Settings(settings)
    self:Message("设置已保存。团框发光填写 player 或玩家名字，用逗号分开；支持暴雪原生团框。")
end

-- Dropdown of our voice clips, opening upward (there is no room below the card); picking one previews it.
function UI:OpenSoundMenu(slot,owner)
    NR.Theme.Menu(owner,NR.Sounds.List(),self.soundValues[slot],function(entry)
        self:SetSoundChoice(slot,entry.key)
        NR.Sounds.Play(entry.key)
    end,true)
end

function UI:SetSoundChoice(slot,key)
    local entry=NR.Sounds.Find(key,NR.defaults[slot])
    self.soundValues[slot]=entry.key
    self.soundPicks[slot]:SetText(entry.name)
end

function UI:SetPage(name)
    self.page = name
    self.importPage:Hide(); self.settingsPage:Hide()
    if name == "settings" then self.settingsPage:Show()
    else self.importPage:Show() end
    self.importTab:SetSelected(name == "import"); self.settingsTab:SetSelected(name == "settings")
    self.railImport:SetSelected(name == "import"); self.railSettings:SetSelected(name == "settings")
    if self.note then self.note:ClearFocus() end
    -- The status line is shared by both pages; don't leave one page's hint on the other.
    if self.message then self:Message(self:PageHint()) end
end

function UI:PaintEnable()
    local on=NR.db.enabled~=false
    self.enableButton:SetText(on and "提醒已开启" or "提醒已停用")
    self.enableButton.themeStyle=on and "primary" or "outline"; self.enableButton:Paint()
end

function UI:ShowMemory(before)
    local now=NR.MemoryKB()
    if not now then self.memoryLabel:SetText("插件占用：游戏未提供"); return end
    self.memoryLabel:SetText(before and string.format("%.0f KB → %.0f KB",before,now) or string.format("插件占用 %.0f KB",now))
end

-- Layout: icon rail on the left, brand + page tabs + switch + close along the top, white cards on a grey canvas.
local W, H, X, CW = 1040, 700, 104, 912

function UI:Create()
    local T = NR.Theme
    local frame = T.Window("NextRemindersWindow",W,H,"NextReminders")
    self.frame = frame
    local header = frame.header
    frame.brand:ClearAllPoints(); frame.brand:SetPoint("TOPLEFT",X,-22); frame.brand:SetWidth(200)
    self.dataVersion = label(header,"",X,-52,260,"tiny")
    local rail = T.Panel(frame,16,-16,72,H-32,"panel",{radius=36,shadow=false})
    local logo = rail:CreateTexture(nil,"ARTWORK"); logo:SetTexture(T.media.."ui_logo.tga"); logo:SetSize(44,44); logo:SetPoint("TOP",0,-14)
    self.railImport = T.IconButton(rail,"import",44,14,-92,function() self:SetPage("import") end,"方案导入")
    self.railSettings = T.IconButton(rail,"settings",44,14,-148,function() self:SetPage("settings") end,"提醒设置")
    self.railPreview = T.IconButton(rail,"play",44,14,-204,function() SlashCmdList.NEXTREMINDERS("preview") end,"播放最近方案")
    local tabs = T.Panel(header,404,-14,232,48,"panel",{radius=24,shadow=false})
    self.importTab = button(tabs,"方案导入",108,6,-6,function() self:SetPage("import") end,"ghost")
    self.settingsTab = button(tabs,"提醒设置",108,118,-6,function() self:SetPage("settings") end,"ghost")
    self.enableButton=button(header,"提醒已开启",140,W-60-12-140,-20,function()
        if InCombatLockdown() then self:Message("请脱战后切换提醒总开关"); return end
        NR.db.enabled=NR.db.enabled==false
        self:PaintEnable()
    end,"primary","power")
    self.importPage = CreateFrame("Frame",nil,frame); self.importPage:SetAllPoints(frame)
    self.settingsPage = CreateFrame("Frame",nil,frame); self.settingsPage:SetAllPoints(frame)

    local page = self.importPage
    label(page,"导入提醒方案",X,-88,600,"title")
    label(page,"大秘境粘贴网站生成的整副本方案；团本粘贴 Lorrgs MRT／NSRT 文本。先检查，再保存启用。",X,-124,CW,"muted")
    local options = T.Panel(page,X,-160,CW,72)
    label(options,"首领编号（MRT）",20,-27,120,"small")
    self.encounter = edit(options,120,136,-18)
    label(options,"使用难度",284,-27,70,"small")
    self.difficulty = "source"
    self.difficultyButton = button(options,"随导出",180,350,-18,function()
        local order = { source="heroic",heroic="normal",normal="mythic",mythic="source" }
        self.difficulty = order[self.difficulty]
        self.difficultyButton:SetText(({source="随导出",heroic="英雄",normal="普通",mythic="史诗／大秘境"})[self.difficulty])
        self.preview = nil
    end,"field")
    self.personal = check(options,"作为我的个人方案",560,-24); self.personal:SetChecked(true)

    local noteCard = T.Panel(page,X,-248,448,340)
    label(noteCard,"方案文本",20,-18,200,"heading")
    self.noteFocus = label(noteCard,"点击输入",340,-21,88,"small"); self.noteFocus:SetJustifyH("RIGHT")
    local notePanel = T.Panel(noteCard,16,-52,416,272,"input",{radius=14})
    self.notePanel = notePanel
    self.noteHint = label(notePanel,"点击这里，按 Ctrl+V 粘贴方案",16,-16,380,"muted")
    local scroll = T.Scroll(page,X+24,-308,384,256)
    self.note = CreateFrame("EditBox",nil,scroll)
    self.note:SetMultiLine(true); self.note:SetFontObject(GameFontHighlight); T.Font(self.note,"body"); self.note:SetWidth(376)
    self.note:SetHeight(255); self.note:SetMaxLetters(200000); self.note:SetAutoFocus(false)
    self.note:SetTextColor(unpack(T.colors.text))
    self.note:EnableMouse(true); self.note:SetTextInsets(4,4,4,4)
    self.note:SetJustifyH("LEFT"); self.note:SetJustifyV("TOP"); self.note:SetBlinkSpeed(0.5)
    -- Draw a high-contrast insertion caret, using native layout coordinates rather
    -- than estimating text widths (which fails for Chinese text and wrapped lines).
    local caret = self.note:CreateTexture(nil,"OVERLAY",nil,7)
    self.noteCaret = caret
    caret:SetColorTexture(unpack(T.colors.ink)); caret:Hide()
    local caretPosition, blinkElapsed
    local function stopCaret()
        caret:Hide(); self.note:SetScript("OnUpdate",nil)
    end
    local function refreshCaret()
        if not self.note:HasFocus() then stopCaret(); return end
        local position = self.note:GetText()=="" and {x=4,y=-4,height=16} or caretPosition
        if not position then stopCaret(); return end
        caret:ClearAllPoints(); caret:SetPoint("TOPLEFT",self.note,"TOPLEFT",position.x,position.y)
        caret:SetSize(2,position.height); blinkElapsed=0; caret:Show()
        self.note:SetScript("OnUpdate",function(_,elapsed)
            blinkElapsed=(blinkElapsed+elapsed)%1
            if blinkElapsed<0.5 then caret:Show() else caret:Hide() end
        end)
    end
    local function focusNote(_,mouseButton)
        if mouseButton=="LeftButton" then self.note:SetFocus() end
    end
    for _,area in ipairs({noteCard,notePanel,scroll}) do area:EnableMouse(true); area:SetScript("OnMouseDown",focusNote) end
    self.note:SetScript("OnMouseDown",focusNote)
    local function paintFocus(focused)
        T.Paint(notePanel,focused and "panel" or "input",focused and "ink" or "border")
        self.noteFocus:SetText(focused and "正在输入" or "点击输入")
        self.noteFocus:SetTextColor(unpack(T.colors[focused and "positive" or "muted"]))
        if focused or self.note:GetText()~="" then self.noteHint:Hide() else self.noteHint:Show() end
        refreshCaret()
    end
    self.note:SetScript("OnEditFocusGained",function() paintFocus(true) end)
    self.note:SetScript("OnEditFocusLost",function() paintFocus(false) end)
    self.note:SetScript("OnCursorChanged",function(editor,x,y,_,cursorHeight)
        if not NR.Number(x,0,editor:GetWidth()) or not NR.Number(y,-3200000,3200000)
            or not NR.Number(cursorHeight,1,200) then
            caretPosition=nil; refreshCaret(); return
        end
        caretPosition={x=x,y=y,height=cursorHeight}
        local top=math.max(0,-y)
        local requiredHeight=top+cursorHeight+8
        if requiredHeight>editor:GetHeight() then editor:SetHeight(requiredHeight) end
        local offset=scroll:GetVerticalScroll()
        if top<offset then scroll:SetVerticalScroll(top)
        elseif top+cursorHeight>offset+scroll:GetHeight() then
            scroll:SetVerticalScroll(top+cursorHeight-scroll:GetHeight())
        end
        refreshCaret()
    end)
    self.note:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    self.note:SetScript("OnTextChanged",function(editor)
        -- Keep the last native layout: cursor callbacks may precede text callbacks.
        local _,lines=editor:GetText():gsub("\n","")
        editor:SetHeight(math.max(255,(lines+2)*16))
        paintFocus(editor:HasFocus())
    end)
    scroll:SetScrollChild(self.note)
    self.note:SetScript("OnHide",function(editor) editor:ClearFocus(); stopCaret() end)
    self.note:SetText(""); self.note:SetCursorPosition(0)
    page:SetScript("OnHide",function() self.note:ClearFocus() end)
    paintFocus(false)

    local checkPanel = T.Panel(page,X+464,-248,448,340)
    label(checkPanel,"方案检查",20,-18,300,"heading")
    self.summary = label(checkPanel,"粘贴文本后，点击“检查导入”。",20,-56,408,"muted")
    self.summary:SetHeight(120)
    self.bindingTitle=label(checkPanel,"阶段绑定",20,-188,408,"small")
    self.bindingScroll=T.Scroll(page,X+484,-460,400,112)
    self.bindingContent=CreateFrame("Frame",nil,self.bindingScroll); self.bindingContent:SetSize(380,112)
    self.bindingScroll:SetScrollChild(self.bindingContent)
    self.bindingTitle:Hide(); self.bindingScroll:Hide()

    button(page,"检查导入",112,X,-606,function() self:Parse() end,nil,"check")
    self.saveButton = button(page,"保存并启用",132,X+124,-606,function() self:Save() end,"primary")
    self.playPreview = button(page,"播放预览",128,X+268,-606,function() self:Play() end,nil,"play")
    self.pausePlan = button(page,"暂停方案",120,X+408,-606,function()
        if InCombatLockdown() then self:Message("请脱战后操作") return end
        if NR.db.lastPlanKind=="timeline3" then
            local ok,err=NR.TimelinePlans.Pause(NR.db.lastTimelinePlan)
            self:Message(ok and "时间轴已暂停；旧方案仍保留" or err); return
        end
        if NR.db.lastPlanKind=="dungeon" then
            local ok,err=NR.EventPlans.PauseDungeon(NR.db.lastDungeon)
            self:Message(ok and "最近导入的整副本方案已暂停" or err);return
        end
        if NR.db.lastPlanKind=="events" and NR.db.lastEventPlan then
            local last=NR.db.lastEventPlan
            local plan=NR.EventPlans.Find(last.specID,last.encounterID,last.difficulty)
            if plan then plan.enabled=false; self:Message("最近保存的事件方案已暂停") end
            return
        end
        local key=NR.db.lastPlan
        if key and NR.db.plans[key] then NR.db.plans[key].enabled=false; self:Message("最近保存的方案已暂停") end
    end,nil,"pause")
    self.rollback = button(page,"回滚",88,X+540,-606,function()
        if InCombatLockdown() then self:Message("请脱战后操作") return end
        if NR.db.lastPlanKind=="timeline3" then
            local ok,err=NR.TimelinePlans.Rollback(NR.db.lastTimelinePlan)
            self:Message(ok and "已交换时间轴方案与备份" or err); return
        end
        if NR.db.lastPlanKind=="dungeon" then
            local ok,err=NR.EventPlans.RollbackDungeon(NR.db.lastDungeon)
            self:Message(ok and "已交换整副本规则和备份" or err);return
        end
        if NR.db.lastPlanKind=="events" then
            local ok,err=NR.EventPlans.Rollback(NR.db.lastEventPlan)
            self:Message(ok and "已交换当前事件方案和备份" or err); return
        end
        local key=NR.db.lastPlan
        if key and NR.db.previousPlans[key] then
            NR.db.plans[key],NR.db.previousPlans[key]=NR.db.previousPlans[key],NR.db.plans[key]
            self:Message("已交换当前方案和备份方案")
        else self:Message("没有可回滚的方案") end
    end)

    page = self.settingsPage
    label(page,"提醒与声音",X,-88,600,"title")
    label(page,"调整显示时机、声音和指定玩家的团框发光。修改后点“保存设置”。",X,-124,CW,"muted")
    -- Text belongs to the card it sits on: a child frame's textures cover its parent's own font strings.
    local function figure(x,title,unit,hint)
        local card=T.Panel(page,x,-160,296,132)
        label(card,title,20,-18,200,"small")
        local box=edit(card,120,20,-44,"number")
        label(card,unit,152,-60,120,"muted")
        label(card,hint,20,-102,256,"tiny")
        return box
    end
    self.lead=figure(X,"提前显示","秒","技能时点前多久出现提醒")
    self.window=figure(X+308,"时点后保留","秒","到点后没按，提醒再留多久")
    self.volume=figure(X+616,"语音音量","0～100","技能语音和倒数的音量")

    local toggles = T.Panel(page,X,-308,448,168)
    label(toggles,"提醒开关",20,-18,300,"heading")
    self.checks = {
        hideOnUse=check(toggles,"用过撤提醒",20,-56), tts=check(toggles,"技能语音",232,-56),
        countdown=check(toggles,"3 秒倒数",20,-92), sound=check(toggles,"提示音效",232,-92),
    }
    self.checks.autoBurst=check(toggles,"大秘境没配置的首领：开打和每次爆发好了都提醒",20,-128)
    for _,control in pairs(self.checks) do control.text:SetWidth(150) end
    self.checks.autoBurst.text:SetWidth(370)

    local sounds = T.Panel(page,X+464,-308,448,168)
    label(sounds,"提示音效",20,-18,300,"heading")
    self.soundPicks = {}
    local pick
    pick = button(sounds,"",300,20,-52,function() self:OpenSoundMenu("soundChoice",pick) end,"field")
    self.soundPicks.soundChoice=pick
    button(sounds,"试听",96,332,-52,function()
        if not NR.Sounds.Play(self.soundValues.soundChoice) then self:Message("当前选的是「不播放」。") end
    end,nil,"sound")
    label(sounds,"到点时播放一次（先 3、2、1 倒数）；几条同时到点只放一次。",20,-104,408,"tiny"):SetHeight(40)

    local glow = T.Panel(page,X,-492,600,96)
    label(glow,"团框发光",20,-18,200,"heading")
    self.glow=edit(glow,300,20,-46)
    label(glow,"填 player 或玩家名字，多个名字用逗号分隔；支持暴雪原生队伍／团队框。",336,-48,244,"tiny"):SetHeight(34)
    local memory = T.Panel(page,X+616,-492,296,96)
    label(memory,"内存",20,-18,120,"heading")
    self.memoryLabel = label(memory,"",20,-56,140,"small")
    self.cleanButton = button(memory,"清理内存",116,160,-46,function()
        local before=NR.MemoryKB()
        local ok,err=NR.Cleanup("manual")
        if not ok then self:Message(err); return end
        self:ShowMemory(before)
        self:Message("已停止播放中的语音，释放插件用完的数据。")
    end,nil,"clean")

    self.saveSettings = button(page,"保存设置",140,W-24-140,-606,function() self:SaveSettings() end,"primary","check")
    self.message=label(frame,"",X,-652,CW,"small"); self.message:SetHeight(36)
    -- Personal policy is authored on the website; no in-game rule editor is created.
    self:SetPage("import")
    frame:Hide(); frame:SetScript("OnShow",function() self:Refresh() end)
    -- Closing the window is "done for now": free what the session left behind.
    frame:SetScript("OnHide",function() NR.Cleanup("close") end)
end

function UI:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end
