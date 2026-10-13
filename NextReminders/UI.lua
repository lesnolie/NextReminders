local _, NR = ...
NR.UI = {}
local UI = NR.UI

local button, label, edit, check = NR.Theme.Button, NR.Theme.Label, NR.Theme.Edit, NR.Theme.Check

function UI:Message(text) self.message:SetText(text) end

function UI:Refresh()
    self.dataVersion:SetText("v" .. NR.version .. "\n\n数据 " .. NR.BossData.dataVersion)
    local s = NR.db.settings
    self.lead:SetText(tostring(s.lead)); self.window:SetText(tostring(s.window)); self.glow:SetText(s.glow)
    for key, control in pairs(self.checks) do control:SetChecked(s[key]) end
    self.volume:SetText(tostring(s.volume))
    self.enableButton:SetText(NR.db.enabled~=false and "提醒已开启" or "提醒已停用")
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
    if plan.kind=="events" then
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
        return anchor == "pull" and "开打（确认此来源阶段从开打开始）" or definition.anchors[anchor]
    end
    for index, phase in ipairs(phases) do
        local sourcePhase = phase
        local choice = 0
        local control = self.binders[index]
        if not control then
            control = button(self.bindingContent, "", 360, 0, -(index - 1) * 34, function() end)
            control:SetHeight(28)
            self.binders[index] = control
        end
        control:SetText("来源 P" .. sourcePhase .. " → 点击选择游戏节点")
        control:SetScript("OnClick", function()
            choice = choice + 1
            if choice > #anchors then choice = 0 end
            plan.phaseBindings[sourcePhase] = anchors[choice] or false
            control:SetText("P" .. sourcePhase .. " → " .. (choice == 0 and "未绑定" or anchorLabel(anchors[choice])))
        end)
        control:Show()
    end
    self.bindingContent:SetHeight(math.max(98,#phases*34))
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
        summary[#summary + 1] = string.format("P%d + %.1f 秒　%s", row.phase, row.time, NR.Theme.SpellName(row.spellID))
    end
    self.summary:SetText(table.concat(summary, "\n"))
    self:Message(#phases > 0 and "逐行点击绑定来源阶段。编号相同不代表节点相同，请核对含义。" or "预览成功。保存会启用此方案，并备份此首领原方案。")
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
    for key, control in pairs(self.checks) do settings[key] = control:GetChecked() and true or false end
    NR.db.settings = NR.Settings(settings)
    self:Message("设置已保存。团框发光填写 player 或玩家名字，用逗号分开；支持暴雪原生团框。")
end

function UI:SetPage(name)
    self.page = name
    self.importPage:Hide(); self.settingsPage:Hide()
    if name == "settings" then self.settingsPage:Show()
    else self.importPage:Show() end
    self.importTab:SetSelected(name == "import"); self.settingsTab:SetSelected(name == "settings")
    if self.note then self.note:ClearFocus() end
    -- The status line is shared by both pages; don't leave one page's hint on the other.
    if self.message then self:Message(self:PageHint()) end
end

function UI:Create()
    local T = NR.Theme
    local frame = T.Window("NextRemindersWindow",960,680,"NextReminders")
    self.frame = frame
    local side = T.Panel(frame,0,-58,152,622,"header")
    self.importTab = button(frame,"方案导入",120,16,-92,function() self:SetPage("import") end)
    self.settingsTab = button(frame,"提醒设置",120,16,-138,function() self:SetPage("settings") end)
    self.dataVersion = label(side,"",16,-512,122,"small"); self.dataVersion:SetHeight(92)
    self.importPage = CreateFrame("Frame",nil,frame); self.importPage:SetAllPoints(frame)
    self.settingsPage = CreateFrame("Frame",nil,frame); self.settingsPage:SetAllPoints(frame)
    local page = self.importPage
    label(page,"导入提醒方案",176,-88,650,"title")
    label(page,"从 Lorrgs 复制，粘贴后即可检查和播放。",176,-121,650,"muted")
    label(page,"首领编号（MRT）",176,-154,150,"small")
    self.encounter = edit(page,140,176,-177)
    label(page,"使用难度",334,-154,180,"small")
    self.difficulty = "source"
    self.difficultyButton = button(page,"随导出",180,334,-177,function()
        local order = { source="heroic",heroic="normal",normal="mythic",mythic="source" }
        self.difficulty = order[self.difficulty]
        self.difficultyButton:SetText(({source="随导出",heroic="英雄",normal="普通",mythic="史诗／大秘境"})[self.difficulty])
        self.preview = nil
    end)
    self.personal = check(page,"作为我的个人方案",538,-182); self.personal:SetChecked(true)
    local notePanel = T.Panel(page,176,-230,330,322)
    self.notePanel = notePanel
    label(notePanel,"网站方案 / Lorrgs 导出文本",16,-16,200)
    self.noteFocus = label(notePanel,"点击输入",222,-16,92,"small")
    self.noteHint = label(notePanel,"点击这里，按 Ctrl+V 粘贴方案",20,-55,280,"muted")
    local scroll = T.Scroll(page,192,-281,288,251)
    self.note = CreateFrame("EditBox",nil,scroll)
    self.note:SetMultiLine(true); self.note:SetFontObject(GameFontHighlight); self.note:SetWidth(280)
    self.note:SetHeight(255); self.note:SetMaxLetters(200000); self.note:SetAutoFocus(false)
    self.note:SetTextColor(unpack(T.colors.text))
    self.note:EnableMouse(true); self.note:SetTextInsets(4,4,4,4)
    self.note:SetJustifyH("LEFT"); self.note:SetJustifyV("TOP"); self.note:SetBlinkSpeed(0.5)
    -- Draw a high-contrast insertion caret, using native layout coordinates rather
    -- than estimating text widths (which fails for Chinese text and wrapped lines).
    local caret = self.note:CreateTexture(nil,"OVERLAY",nil,7)
    self.noteCaret = caret
    caret:SetColorTexture(unpack(T.colors.accent)); caret:Hide()
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
    notePanel:EnableMouse(true); notePanel:SetScript("OnMouseDown",focusNote)
    scroll:EnableMouse(true); scroll:SetScript("OnMouseDown",focusNote)
    self.note:SetScript("OnMouseDown",focusNote)
    local function paintFocus(focused)
        notePanel:SetBackdropBorderColor(unpack(T.colors[focused and "accent" or "border"]))
        self.noteFocus:SetText(focused and "正在输入" or "点击输入")
        self.noteFocus:SetTextColor(unpack(T.colors[focused and "accent" or "muted"]))
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
    local checkPanel = T.Panel(page,522,-230,414,322)
    label(checkPanel,"方案检查",16,-16,382)
    self.summary = label(checkPanel,"粘贴文本后，点击“检查导入”。",16,-50,382,"muted")
    self.summary:SetHeight(110)
    self.bindingTitle=label(checkPanel,"阶段绑定",16,-174,382,"small")
    self.bindingScroll=T.Scroll(page,538,-434,362,98)
    self.bindingContent=CreateFrame("Frame",nil,self.bindingScroll); self.bindingContent:SetSize(360,98)
    self.bindingScroll:SetScrollChild(self.bindingContent)
    self.bindingTitle:Hide(); self.bindingScroll:Hide()
    button(page,"检查导入",100,176,-576,function() self:Parse() end)
    self.saveButton = button(page,"保存并启用",128,288,-576,function() self:Save() end,"primary")
    self.playPreview = button(page,"播放预览",128,428,-576,function() self:Play() end)
    self.pausePlan = button(page,"暂停方案",92,568,-576,function()
        if InCombatLockdown() then self:Message("请脱战后操作") return end
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
    end)
    self.rollback = button(page,"回滚",72,672,-576,function()
        if InCombatLockdown() then self:Message("请脱战后操作") return end
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
    self.enableButton=button(page,"提醒已开启",180,756,-576,function()
        if InCombatLockdown() then self:Message("请脱战后切换提醒总开关"); return end
        NR.db.enabled=NR.db.enabled==false
        self.enableButton:SetText(NR.db.enabled and "提醒已开启" or "提醒已停用")
    end)
    page = self.settingsPage
    label(page,"提醒与声音",176,-88,650,"title")
    label(page,"调整显示时机、声音和指定玩家的团框发光。",176,-121,650,"muted")
    -- Text belongs to the panel it sits on: a child frame's backdrop covers its parent's own font strings.
    local timing = T.Panel(page,176,-164,760,174)
    label(timing,"显示时间",16,-16,400)
    label(timing,"提前显示 · 秒",16,-62,136,"small"); self.lead=edit(timing,100,16,-88)
    label(timing,"时点后保留 · 秒",178,-62,142,"small"); self.window=edit(timing,100,178,-88)
    label(timing,"语音音量 · 0～100",340,-62,170,"small"); self.volume=edit(timing,100,340,-88)
    label(timing,"例：提前 5 秒显示，技能用过后自动撤掉提醒。",498,-61,244,"muted"):SetHeight(74)
    local toggles = T.Panel(page,176,-356,760,116)
    self.checks = {
        hideOnUse=check(toggles,"用过撤提醒",16,-26), tts=check(toggles,"技能语音",198,-26),
        countdown=check(toggles,"3 秒倒数",380,-26), sound=check(toggles,"提示音效",562,-26),
    }
    for _,control in pairs(self.checks) do control.text:SetWidth(126) end
    label(toggles,"技能语音与倒数可以分别开关。",16,-76,696,"small")
    local glow = T.Panel(page,176,-490,760,102)
    label(glow,"团框发光",16,-16,200)
    self.glow=edit(glow,414,16,-50)
    label(glow,"填 player 或玩家名字\n多个名字用逗号分隔",452,-47,288,"small"):SetHeight(44)
    self.saveSettings = button(page,"保存设置",132,804,-616,function() self:SaveSettings() end,"primary")
    self.message=label(frame,"",176,-628,610,"small"); self.message:SetHeight(40)
    -- Personal policy is authored on the website; no in-game rule editor is created.
    self:SetPage("import")
    frame:Hide(); frame:SetScript("OnShow",function() self:Refresh() end)
end

function UI:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end
