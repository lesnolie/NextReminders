local _, NR = ...
NR.UI = {}
local UI = NR.UI

local button, label, edit, check = NR.Theme.Button, NR.Theme.Label, NR.Theme.Edit, NR.Theme.Check

function UI:Message(text) self.message:SetText(text) end

function UI:Refresh()
    self.dataVersion:SetText(self:SpecLine())
    self:PaintBursts(); self:PaintImport()
    if self.returning then self.returning=nil; self:PaintEnable(); self:Message(self:PageHint()); return end
    local s = NR.db.settings
    self.lead:SetText(tostring(s.lead)); self.window:SetText(tostring(s.window))
    for key, control in pairs(self.checks) do control:SetChecked(s[key]) end
    self.soundValues = {}
    for key in pairs(self.soundPicks) do self:SetSoundChoice(key,s[key]) end
    self.settingsDirty=nil
    self:PaintEnable()
    self:Message(self:PageHint())
end

-- Brand subtitle on every window: version and the spec whose plans and bursts are shown.
function UI:SpecLine()
    local spec=NR.GetIdentity().specID
    return "v" .. NR.version .. " · " .. (spec and NR.SpecName(spec) or "未选择专精")
end

function UI:PageHint()
    if self.page == "settings" then
        if self.settingsDirty then return "有未保存的修改：点“保存设置”后生效。" end
        return "声音与显示修改后点“保存设置”；爆发技能在编辑页即时保存。战斗中不能修改。"
    end
    return "粘贴网站或 Lorrgs 方案 → 检查方案 → 保存并启用。检查和预览都不会改动已保存的方案。"
end

local FORMAT = { dungeon="网站整副本方案", timeline3="网站时间轴方案", events="网站首领方案", note="Lorrgs MRT／NSRT" }

-- Which importer a pasted text goes to; nil for an empty box.
local function formatOf(text)
    local function has(prefix) return text:match("^%s*" .. prefix) or text:match("\n%s*" .. prefix) end
    if has("NRDungeon:") then return "dungeon" end
    if has("NRPlan:3;") then return "timeline3" end
    if has("NRPlan:") then return "events" end
    if text:match("%S") then return "note" end
end

local function burstSignature(specID)
    local ids, custom = NR.BurstSpells.Get(specID)
    table.sort(ids)
    return (custom and "custom:" or "default:") .. table.concat(ids, ",")
end

local function filterImported(plan, specID)
    local removed, count = NR.BurstSpells.Removed(specID), 0
    local plans = plan.kind == "dungeon" and plan.plans or {plan}
    for _, entry in ipairs(plans) do
        local rows = {}
        for _, row in ipairs(entry.rows) do
            if (row.actionType or "spell") == "spell" and removed[row.spellID] then
                count = count + 1
            else
                rows[#rows + 1] = row
            end
        end
        entry.rows = rows
    end
    local ok, err
    if plan.kind == "dungeon" then ok, err = NR.EventPlans.ValidateDungeon(plan)
    elseif plan.kind == "events" then ok, err = NR.EventPlans.Validate(plan)
    elseif plan.kind == "timeline3" then ok, err = NR.TimelinePlans.Validate(plan)
    else ok, err = NR.ValidatePlan(plan) end
    if not ok then return nil, err end
    return count
end

local function skippedText(count)
    return count and count > 0 and (" 已按你的爆发名单跳过 " .. count .. " 条提醒。") or ""
end

function UI:Parse()
    self:ParseText(); self:PaintImport()
end

function UI:ParseText()
    if InCombatLockdown() then self:Message("请脱战后导入") return end
    local targetDifficulty = self.difficulty ~= "source" and self.difficulty or nil
    local text=self.note:GetText()
    local plan,err
    local format=formatOf(text)
    self.parseError, self.checkedText = nil, text
    if format=="dungeon" then plan,err=NR.EventPlans.ParseDungeon(text)
    elseif format=="timeline3" then plan,err=NR.TimelinePlans.Parse(text)
    elseif format=="events" then plan,err=NR.EventPlans.Parse(text)
    else plan, err = NR.ParseNote(text, { personal = self.personal:GetChecked(),
        encounterID = tonumber(self.encounter:GetText()), difficulty = targetDifficulty or "mythic",
        targetDifficulty = targetDifficulty }) end
    self.importSpec = plan and (plan.specID or NR.GetIdentity().specID) or nil
    self.importSignature = plan and burstSignature(self.importSpec) or nil
    self.skipped = nil
    if plan then
        self.skipped, err = filterImported(plan, self.importSpec)
        if not self.skipped then plan = nil end
    end
    for _, control in ipairs(self.binders or {}) do control:Hide() end
    self.binders, self.preview = self.binders or {}, plan
    if not plan then
        self.parseError=err or "无法识别这段文本"
        self:Message(self.parseError); self.summary:SetText(self.parseError)
        self.bindingScroll:Hide(); self.bindingTitle:Hide(); return
    end
    if plan.kind=="dungeon" then
        local d=NR.DungeonData.dungeons[plan.dungeonID]
        local names={}
        for _,p in ipairs(plan.plans) do names[#names+1]="#"..p.encounterID.."（"..#p.rows.."条）" end
        self.summary:SetText(d.name.."\n"..NR.SpecName(plan.specID).." · 史诗钥石 · "..#plan.plans.."/"..#d.bosses.." 只首领\n"..table.concat(names," / ").."\n保存会更新此副本全部首领规则；未配置的旧规则清除，可整包回滚。")
        self.bindingScroll:Hide();self.bindingTitle:Hide()
        self.lastParsedText,self.lastPersonal,self.lastEncounterText,self.lastDifficulty=text,self.personal:GetChecked(),self.encounter:GetText(),self.difficulty
        self:Message("整副本检查通过；预览可切换首领。事件识别仍需游戏核对。" .. skippedText(self.skipped))
        return
    end
    if plan.kind=="events" or plan.kind=="timeline3" then
        local boss=NR.BossData.encounters[plan.encounterID]
        self.summary:SetText((boss and boss.name or plan.name).."\n"..NR.SpecName(plan.specID).." · "..plan.difficulty.." · "..#plan.rows.." 条规则\n含事件条件、次数和等待提示。")
        self.bindingScroll:Hide(); self.bindingTitle:Hide()
        self.lastParsedText,self.lastPersonal,self.lastEncounterText,self.lastDifficulty=text,self.personal:GetChecked(),self.encounter:GetText(),self.difficulty
        self:Message("检查通过，点击保存启用；事件识别准确性仍需游戏验证。" .. skippedText(self.skipped))
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
    local difficultyLabels = {normal="普通",heroic="英雄",mythic="史诗／史诗钥石"}
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
    self:Message(self.message:GetText() .. skippedText(self.skipped))
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
    if (not self.preview.specID and self.importSpec ~= NR.GetIdentity().specID)
        or self.importSignature ~= burstSignature(self.importSpec) then
        return nil, "专精或爆发技能名单已变化，请重新检查"
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
    if self:Store() then self.saved=self.preview end
    self:PaintImport()
end

-- Saves the checked plan; true only when it was stored and enabled.
function UI:Store()
    if InCombatLockdown() then self:Message("请脱战后保存") return end
    local input, err = self:CurrentPlan()
    if not input then self:Message(err); return end
    local ok
    if input.kind=="timeline3" then
        ok,err=NR.TimelinePlans.Save(input)
        if not ok then self:Message(err); return end
        NR.db.lastPlanKind="timeline3"
        NR.PreviewUI:Remember(input)
        self:Message("已保存时间轴方案；本专精同首领优先使用，旧方案保留。固定兜底不是实测。" .. skippedText(self.skipped))
        return true
    end
    if input.kind=="dungeon" then
        ok,err=NR.EventPlans.SaveDungeon(input)
        if not ok then self:Message(err);return end
        NR.db.lastPlanKind="dungeon"
        NR.PreviewUI:Remember(input.plans[1])
        self:Message("已导入整副本方案；按专精和首领自动匹配，原规则已整包备份。" .. skippedText(self.skipped))
        return true
    end
    if input.kind=="events" then
        ok,err=NR.EventPlans.Save(input)
        if not ok then self:Message(err); return end
        NR.db.lastEventPlan={specID=input.specID,encounterID=input.encounterID,difficulty=input.difficulty}
        NR.db.lastPlanKind="events"
        NR.PreviewUI:Remember(input)
        self:Message("已导入网站规则；本专精、首领和难度自动匹配。" .. skippedText(self.skipped))
        return true
    end
    ok, err = NR.ValidateBindings(input)
    if not ok then self:Message(err) return end
    local player = NR.GetIdentity()
    local notes = NR.NotePlans(player.specID)
    if not notes then self:Message("还没有专精：方案按专精分开保存，请先选择专精") return end
    local key = self.preview.encounterID .. ":" .. self.preview.difficulty
    local old = notes.plans[key]
    if old then notes.previous[key] = NR.Copy(old) end
    local plan = NR.Copy(self.preview)
    plan.enabled, plan.importedAt, plan.dataVersion, plan.specID = true, time(), NR.BossData.dataVersion, player.specID
    notes.plans[key] = plan
    NR.db.lastPlan = { specID = player.specID, key = key }
    NR.db.lastPlanKind="timeline"
    NR.PreviewUI:Remember(plan)
    self:Message("已保存到当前专精（" .. NR.SpecName(player.specID) .. "）并启用 " .. #plan.rows .. " 条提醒。"
        .. (old and "原方案已备份，可回滚。" or "") .. skippedText(self.skipped))
    return true
end

-- Pause/rollback always address this specialization's last saved plan.
function UI:LastSaved()
    local spec = NR.GetIdentity().specID
    local saved = type(NR.db.lastBySpec) == "table" and NR.db.lastBySpec[spec]
    if saved then return saved end
    local kind = NR.db.lastPlanKind
    local last = kind == "dungeon" and NR.db.lastDungeon or kind == "events" and NR.db.lastEventPlan
        or kind == "timeline3" and NR.db.lastTimelinePlan or NR.db.lastPlan
    if type(last) == "table" and last.specID == spec then return NR.db end
    self:Message("这个专精没有最近保存的方案")
end

function UI:SaveSettings()
    if InCombatLockdown() then self:Message("请脱战后修改设置") return end
    local lead, window = tonumber(self.lead:GetText()), tonumber(self.window:GetText())
    if not NR.Number(lead, 0, 60) or not NR.Number(window, 0, 60) then
        self:Message("提前量／保留时间需为 0～60 秒") return
    end
    local settings = NR.Copy(NR.db.settings)
    settings.lead, settings.window = lead, window
    for key,value in pairs(self.soundValues or {}) do settings[key] = value end
    for key, control in pairs(self.checks) do settings[key] = control:GetChecked() and true or false end
    NR.db.settings = NR.Settings(settings)
    self.settingsDirty = nil
    self:Message("设置已保存。")
end

-- A setting changed by hand but not saved yet: say so, rather than losing it silently.
function UI:MarkDirty()
    self.settingsDirty = true
    if self.page == "settings" then self:Message(self:PageHint()) end
end

-- Dropdown of our voice clips, opening upward (there is no room below the card); picking one previews it.
-- The list deletes clips on the spot (x on each row) and offers a restore row when any are deleted.
function UI:OpenSoundMenu(slot,owner)
    local items={}
    for _,entry in ipairs(NR.Sounds.List()) do
        items[#items+1]=setmetatable({removable=entry.file~=nil},{__index=entry})
    end
    local deleted=NR.Sounds.HiddenCount()
    if deleted>0 then items[#items+1]={key="__restore",name="恢复已删除的语音（"..deleted.."）"} end
    local function reopen() local menu=NR.Theme.menuFrame; if menu then menu:Hide() end; self:OpenSoundMenu(slot,owner) end
    NR.Theme.Menu(owner,items,self.soundValues[slot],function(entry)
        if entry.key=="__restore" then NR.Sounds.RestoreAll(); self:SetSoundChoice(slot,self.soundValues[slot]); reopen(); return end
        self:SetSoundChoice(slot,entry.key)
        NR.Sounds.Play(entry.key)
        self:MarkDirty()
    end,true,function(entry)
        NR.Sounds.Remove(entry.key)
        -- Deleting the clip in use moves the choice (and the saved setting) to the next one still listed.
        if self.soundValues[slot]==entry.key then
            self:SetSoundChoice(slot,entry.key)
            NR.db.settings[slot]=self.soundValues[slot]
        end
        reopen()
    end)
end

function UI:SetSoundChoice(slot,key)
    local entry=NR.Sounds.Find(key,NR.defaults[slot])
    self.soundValues[slot]=entry.key
    self.soundPicks[slot]:SetText(entry.name)
end

-- Settings card summary; the list itself is edited, and saved at once, on its own page.
function UI:PaintBursts()
    local spec = NR.GetIdentity().specID
    if not spec then self.burstSummary:SetText("选择专精后可编辑"); return end
    local ids, custom = NR.BurstSpells.Get(spec)
    self.burstSummary:SetText(NR.SpecName(spec) .. " · " .. #ids .. " 个技能 · " .. (custom and "我的名单" or "内置默认")
        .. "\n用于未配置首领的默认提醒和新方案导入过滤")
end

local GUIDE = "① 左侧粘贴方案文本\n② 点“检查方案”，这里会列出首领、提醒条数和需要你确认的阶段\n③ 确认无误后“保存并启用”；想先看效果可“播放预览”"

-- The import card follows the text: Lorrgs options only for Lorrgs text, save and preview only for
-- exactly the text (and options) that passed the check.
function UI:PaintImport()
    if not self.saveButton then return end
    local text = self.note:GetText() or ""
    local format = formatOf(text)
    local plan = self:CurrentPlan()
    self.formatLabel:SetText(format and "识别为：" .. FORMAT[format] or "粘贴后自动识别格式")
    if format == "note" then self.noteOptions:Show() else self.noteOptions:Hide() end
    self.summary:ClearAllPoints(); self.summary:SetPoint("TOPLEFT", 20, format == "note" and -148 or -64)
    self.summary:SetHeight(format == "note" and 84 or 280)
    local status, tone = "待检查", "muted"
    if plan then status, tone = self.saved == plan and "已保存并启用" or "检查通过", "positive"
    elseif format and self.checkedText then
        status, tone = self.parseError and self.checkedText == text and "未通过" or "需重新检查", "warning"
    end
    self.status:SetText(status, tone)
    if not format then
        self.summary:SetText(GUIDE); self.bindingScroll:Hide(); self.bindingTitle:Hide()
    end
    self.saveButton:SetEnabled(plan ~= nil and self.saved ~= plan)
    self.playPreview:SetEnabled(plan ~= nil)
    self.checkButton.themeStyle = plan and "outline" or "primary"; self.checkButton:Paint()
end

function UI:OpenLibrary()
    local ok, err = NR.PreviewUI:OpenLibrary()
    if not ok then self:Message(err) end
end

function UI:SetPage(name)
    if NR.BurstUI and NR.BurstUI.frame then NR.BurstUI.frame:Hide() end
    self.page = name
    self.tabs:Show()
    self.importPage:Hide(); self.settingsPage:Hide()
    if name == "settings" then self.settingsPage:Show(); self:PaintBursts()
    else self.importPage:Show(); self:PaintImport() end
    self.importTab:SetSelected(name == "import"); self.settingsTab:SetSelected(name == "settings")
    if self.note then self.note:ClearFocus() end
    -- The status line is shared by both pages; don't leave one page's hint on the other.
    if self.message then self:Message(self:PageHint()) end
end

function UI:ToggleEnabled()
    if InCombatLockdown() then self:Message("请脱战后切换提醒总开关"); return end
    NR.db.enabled = NR.db.enabled == false
    self:PaintEnable()
end

function UI:PaintEnable()
    local on=NR.db.enabled~=false
    for _, switch in ipairs(self.switches) do
        switch:SetText(on and "提醒已开启" or "提醒已停用")
        switch.themeStyle=on and "primary" or "outline"; switch:Paint()
    end
end

-- Every window (main, playback) is the same size and shares one top bar: brand and spec on the left,
-- the master switch on the right; the centre holds the page tabs or a back button.
local W, H, X, CW = 1180, 740, 24, 1132
UI.W, UI.H = W, H

function UI:Chrome(frame)
    frame.brand:SetWidth(320)
    local sub = label(frame.header,"",24,-58,360,"tiny")
    local switch = button(frame.header,"提醒已开启",140,W-72-148,-18,function() self:ToggleEnabled() end,"primary","power")
    self.switches[#self.switches+1] = switch
    return sub, switch
end

function UI:Create()
    local T = NR.Theme
    local frame = T.Window("NextRemindersWindow",W,H,"NextReminders")
    self.frame = frame
    self.switches = {}
    self.dataVersion, self.enableButton = self:Chrome(frame)
    local tabs = T.Panel(frame.header,(W-232)/2,-14,232,48,"panel",{radius=24,shadow=false})
    self.tabs = tabs
    self.importTab = button(tabs,"方案导入",108,6,-6,function() self:SetPage("import") end,"ghost")
    self.settingsTab = button(tabs,"提醒设置",108,118,-6,function() self:SetPage("settings") end,"ghost")
    self.importPage = CreateFrame("Frame",nil,frame); self.importPage:SetAllPoints(frame)
    self.settingsPage = CreateFrame("Frame",nil,frame); self.settingsPage:SetAllPoints(frame)

    -- Import: paste on the left; the check result, and the actions it unlocks, on the right.
    local page = self.importPage
    label(page,"导入提醒方案",X,-92,600,"title")
    label(page,"史诗钥石粘贴网站生成的方案；团本粘贴 Lorrgs 的 MRT／NSRT 文本。",X,-128,760,"muted")
    self.libraryButton = button(page,"已导入方案 / 回放",200,W-X-200,-96,function() self:OpenLibrary() end,nil,"play")

    local noteCard = T.Panel(page,X,-164,660,476)
    label(noteCard,"方案文本",20,-18,200,"heading")
    self.noteFocus = label(noteCard,"点击输入",552,-21,88,"small"); self.noteFocus:SetJustifyH("RIGHT")
    local notePanel = T.Panel(noteCard,16,-52,628,352,"input",{radius=14})
    self.notePanel = notePanel
    self.noteHint = label(notePanel,"点击这里，按 Ctrl+V 粘贴方案",16,-16,560,"muted")
    -- Keep the viewport above the input surface. A sibling of noteCard inherits
    -- a lower frame level and can put the editor/caret behind notePanel.
    local scroll = T.Scroll(notePanel,8,-8,596,336)
    self.note = CreateFrame("EditBox",nil,scroll)
    self.note:SetPoint("TOPLEFT",scroll,"TOPLEFT",0,0)
    self.note:SetMultiLine(true); self.note:SetFontObject(GameFontHighlight); T.Font(self.note,"body"); self.note:SetWidth(588)
    self.note:SetHeight(335); self.note:SetMaxLetters(200000); self.note:SetAutoFocus(false)
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
        editor:SetHeight(math.max(335,(lines+2)*16))
        paintFocus(editor:HasFocus())
        self:PaintImport()
    end)
    scroll:SetScrollChild(self.note)
    self.note:SetScript("OnHide",function(editor) editor:ClearFocus(); stopCaret() end)
    self.note:SetText(""); self.note:SetCursorPosition(0)
    page:SetScript("OnHide",function() self.note:ClearFocus() end)
    paintFocus(false)
    self.formatLabel = label(noteCard,"",20,-428,460,"small")
    self.checkButton = button(noteCard,"检查方案",140,504,-418,function() self:Parse() end,"primary","check")

    local checkCard = T.Panel(page,X+676,-164,456,476)
    label(checkCard,"检查结果",20,-18,240,"heading")
    self.status = T.Pill(checkCard,-16,-14)
    -- Only Lorrgs text needs these: MRT carries no boss, and either may be reused on another difficulty.
    local options = CreateFrame("Frame",nil,checkCard)
    options:SetPoint("TOPLEFT",0,-52); options:SetSize(456,88)
    self.noteOptions = options
    label(options,"首领编号",20,-10,80,"small")
    self.encounter = edit(options,100,92,-2)
    self.encounter:SetScript("OnTextChanged",function() self:PaintImport() end)
    label(options,"使用难度",212,-10,70,"small")
    self.difficulty = "source"
    self.difficultyButton = button(options,"随导出",156,280,-2,function()
        local order = { source="heroic",heroic="normal",normal="mythic",mythic="source" }
        self.difficulty = order[self.difficulty]
        self.difficultyButton:SetText(({source="随导出",heroic="英雄",normal="普通",mythic="史诗／史诗钥石"})[self.difficulty])
        self.preview = nil
        self:PaintImport()
    end,"field")
    self.personal = check(options,"作为我的个人方案",20,-50); self.personal:SetChecked(true)
    self.personal:HookScript("OnClick",function() self:PaintImport() end)
    self.summary = label(checkCard,"",20,-64,416,"muted")
    self.bindingTitle=label(checkCard,"阶段绑定：点击切换；右侧可填开打后转阶段时间（如 2:15）",20,-240,416,"small")
    self.bindingScroll=T.Scroll(checkCard,20,-262,400,92)
    self.bindingContent=CreateFrame("Frame",nil,self.bindingScroll); self.bindingContent:SetSize(380,92)
    self.bindingScroll:SetScrollChild(self.bindingContent)
    self.bindingTitle:Hide(); self.bindingScroll:Hide()

    self.saveButton = button(checkCard,"保存并启用",200,20,-368,function() self:Save() end,"primary","check")
    self.playPreview = button(checkCard,"播放预览",204,232,-368,function() self:Play() end,nil,"play")
    -- Pause and rollback act on the plan this spec saved last, whatever the box holds now.
    label(checkCard,"最近导入",20,-428,70,"small")
    self.pausePlan = button(checkCard,"暂停",156,96,-418,function()
        if InCombatLockdown() then self:Message("请脱战后操作") return end
        local saved=self:LastSaved(); if not saved then return end
        if saved.lastPlanKind=="timeline3" then
            local ok,err=NR.TimelinePlans.Pause(saved.lastTimelinePlan)
            self:Message(ok and "时间轴已暂停；旧方案仍保留" or err); return
        end
        if saved.lastPlanKind=="dungeon" then
            local ok,err=NR.EventPlans.PauseDungeon(saved.lastDungeon)
            self:Message(ok and "最近导入的整副本方案已暂停" or err);return
        end
        if saved.lastPlanKind=="events" and saved.lastEventPlan then
            local last=saved.lastEventPlan
            local plan=NR.EventPlans.Find(last.specID,last.encounterID,last.difficulty)
            if plan then plan.enabled=false; self:Message("最近保存的事件方案已暂停") end
            return
        end
        local last=saved.lastPlan
        local notes=type(last)=="table" and NR.NotePlans(last.specID)
        local plan=notes and notes.plans[last.key]
        if plan then plan.enabled=false; self:Message("最近保存的方案已暂停") end
    end,nil,"pause")
    self.rollback = button(checkCard,"回滚到旧版",172,264,-418,function()
        if InCombatLockdown() then self:Message("请脱战后操作") return end
        local saved=self:LastSaved(); if not saved then return end
        if saved.lastPlanKind=="timeline3" then
            local ok,err=NR.TimelinePlans.Rollback(saved.lastTimelinePlan)
            self:Message(ok and "已交换时间轴方案与备份" or err); return
        end
        if saved.lastPlanKind=="dungeon" then
            local ok,err=NR.EventPlans.RollbackDungeon(saved.lastDungeon)
            self:Message(ok and "已交换整副本规则和备份" or err);return
        end
        if saved.lastPlanKind=="events" then
            local ok,err=NR.EventPlans.Rollback(saved.lastEventPlan)
            self:Message(ok and "已交换当前事件方案和备份" or err); return
        end
        local last=saved.lastPlan
        local notes=type(last)=="table" and NR.NotePlans(last.specID)
        local key=notes and last.key
        if key and notes.previous[key] then
            notes.plans[key],notes.previous[key]=notes.previous[key],notes.plans[key]
            self:Message("已交换当前方案和备份方案")
        else self:Message("没有可回滚的方案") end
    end)

    page = self.settingsPage
    label(page,"提醒与声音",X,-92,600,"title")
    label(page,"调整显示时机和声音。修改后点“保存设置”；爆发技能在编辑页即时保存。",X,-128,CW,"muted")
    local function dirty(_,userInput) if userInput then self:MarkDirty() end end
    -- Text belongs to the card it sits on: a child frame's textures cover its parent's own font strings.
    local function figure(x,title,unit,hint)
        local card=T.Panel(page,x,-164,558,132)
        label(card,title,20,-18,200,"small")
        local box=edit(card,120,20,-44,"number")
        box:SetScript("OnTextChanged",dirty)
        label(card,unit,152,-60,120,"muted")
        label(card,hint,20,-102,518,"tiny")
        return box
    end
    self.lead=figure(X,"提前显示","秒","技能时点前多久出现提醒；7 秒以上才念「准备爆发」")
    self.window=figure(X+574,"时点后保留","秒","到点后没按，提醒再留多久")

    local toggles = T.Panel(page,X,-312,558,168)
    label(toggles,"提醒开关",20,-18,300,"heading")
    self.checks = {
        hideOnUse=check(toggles,"用过撤提醒",20,-56), sound=check(toggles,"提示音效",290,-56),
        countdown=check(toggles,"语音倒数（准备爆发 5…1）",20,-92),
    }
    self.checks.autoBurst=check(toggles,"未配置的大秘境首领：开打和每次爆发好了都提醒",20,-128)
    for _,control in pairs(self.checks) do
        control.text:SetWidth(200); control:HookScript("OnClick",function() self:MarkDirty() end)
    end
    self.checks.autoBurst.text:SetWidth(470)

    local sounds = T.Panel(page,X+574,-312,558,168)
    label(sounds,"提示音效",20,-18,300,"heading")
    self.soundPicks = {}
    local pick
    pick = button(sounds,"",400,20,-52,function() self:OpenSoundMenu("soundChoice",pick) end,"field")
    self.soundPicks.soundChoice=pick
    button(sounds,"试听",106,432,-52,function()
        if not NR.Sounds.Play(self.soundValues.soundChoice) then self:Message("当前选的是「不播放」。") end
    end,nil,"sound")
    label(sounds,"到点时播放一次（先「准备爆发，5、4、3、2、1」）；几条同时到点只放一次。列表里点 × 删除不要的语音。",20,-104,518,"tiny"):SetHeight(40)

    local bursts = T.Panel(page,X,-496,CW,112)
    label(bursts,"大秘境默认爆发",20,-18,256,"heading")
    T.Pill(bursts,-16,-14):SetText("即时保存")
    self.burstSummary = label(bursts,"",20,-52,340,"small"); self.burstSummary:SetHeight(40)
    self.burstButton = button(bursts,"编辑技能",160,CW-180,-58,function() NR.BurstUI:Open() end,"primary")

    button(page,"查看方案回放",160,X,-626,function() self:OpenLibrary() end,nil,"play")
    self.saveSettings = button(page,"保存设置",160,W-X-160,-626,function() self:SaveSettings() end,"primary","check")
    self.message=label(frame,"",X,-684,CW,"small"); self.message:SetHeight(36)
    -- Boss timelines remain separate from the per-spec automatic spell list.
    self:SetPage("import")
    frame:Hide(); frame:SetScript("OnShow",function() self:Refresh() end)
    -- Closing the window stops leftover playback and clears temporary reminder state.
    frame:SetScript("OnHide",function() NR.Cleanup("close") end)
end

function UI:Toggle()
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end
