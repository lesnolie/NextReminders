local _, NR = ...
NR.BurstUI = {}
local U = NR.BurstUI
local T = NR.Theme

function U:Message(text) self.message:SetText(text) end

function U:Back()
    self.input:ClearFocus()
    self.frame:Hide()
    NR.UI:SetPage("settings")
end

function U:CheckSpec()
    if InCombatLockdown() then self:Message("请脱战后修改爆发技能"); return false end
    if NR.GetIdentity().specID ~= self.specID then
        self:Open(); self:Message("专精已切换，已显示当前专精，请重新操作")
        return false
    end
    return true
end

function U:Add(id)
    if not self:CheckSpec() then return end
    local resolved, err = NR.BurstSpells.Resolve(tostring(id or self.input:GetText()))
    if not resolved then self:Message(err); return end
    local ids = NR.BurstSpells.Get(self.specID)
    for _, existing in ipairs(ids) do
        if existing == resolved then self:Message("这个技能已经在名单中"); return end
    end
    ids[#ids+1] = resolved
    local ok; ok, err = NR.BurstSpells.Save(self.specID, ids)
    if not ok then self:Message(err); return end
    self.input:SetText(""); self.input:ClearFocus(); self:Refresh()
    self:Message("已添加「"..NR.SpellCatalog.Info(resolved).."」。下次未配置的大秘境首领生效。")
end

function U:Remove(id)
    if not self:CheckSpec() then return end
    local ids, out = NR.BurstSpells.Get(self.specID), {}
    for _, existing in ipairs(ids) do if existing ~= id then out[#out+1] = existing end end
    local ok, err = NR.BurstSpells.Save(self.specID, out)
    if not ok then self:Message(err); return end
    self:Refresh(); self:Message("已删除「"..NR.SpellCatalog.Info(id).."」。可从右侧或输入编号重新添加。")
end

function U:Reset()
    if not self:CheckSpec() then return end
    local ok, err = NR.BurstSpells.Reset(self.specID)
    if not ok then self:Message(err); return end
    self:Refresh(); self:Message("已恢复当前专精的内置默认名单")
end

local ROW, LIST = 52, 526

local function paintList(list, ids, action, actionText)
    for i, id in ipairs(ids) do
        local row = list.rows[i]
        if not row then
            row = CreateFrame("Frame", nil, list.child); row:SetSize(LIST, ROW)
            row:SetPoint("TOPLEFT", 0, -(i-1)*ROW)
            row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(32,32); row.icon:SetPoint("LEFT", 2, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.name = T.Label(row, "", 46, -8, 360, "body"); row.name:SetWordWrap(false)
            row.number = T.Label(row, "", 46, -28, 200, "tiny")
            row.button = T.Button(row, actionText, 76, LIST-80, -8, function() action(row.spellID) end)
            row.line = row:CreateTexture(nil, "BACKGROUND"); row.line:SetHeight(1)
            row.line:SetPoint("BOTTOMLEFT"); row.line:SetPoint("BOTTOMRIGHT"); row.line:SetColorTexture(unpack(T.colors.border))
            list.rows[i] = row
        end
        row.spellID = id
        local name, icon = NR.SpellCatalog.Info(id)
        row.name:SetText(name); row.number:SetText(tostring(id)); row.icon:SetTexture(icon)
        if i == #ids then row.line:Hide() else row.line:Show() end
        row:Show()
    end
    for i = #ids+1, #list.rows do list.rows[i]:Hide() end
    list.child:SetHeight(math.max(1, #ids*ROW))
    list.scroll:SetVerticalScroll(0)
    list.empty:SetText(#ids == 0 and (actionText == "删除" and "名单为空：不自动提醒任何技能" or "目录里的技能都已添加") or "")
end

function U:Refresh()
    local ids, custom = NR.BurstSpells.Get(self.specID)
    self.sub:SetText(NR.SpecName(self.specID).." · 用于默认提醒和新方案导入过滤，已保存方案不变。")
    self.state:SetText((custom and "我的名单" or "内置默认").." · 即时保存")
    local selected, available = {}, {}
    for _, id in ipairs(ids) do selected[id] = true end
    for _, entry in ipairs(NR.SpellCatalog.ForSpec(self.specID)) do
        if not selected[entry.id] then available[#available+1] = entry.id end
    end
    self.selected.title:SetText("当前提醒名单 · "..#ids)
    paintList(self.selected, ids, function(id) self:Remove(id) end, "删除")
    paintList(self.available, available, function(id) self:Add(id) end, "添加")
end

-- A sub page of the main window (settings → bursts): the top bar swaps its tabs for a back button.
function U:Create()
    local main = NR.UI
    local W = main.W
    local frame = CreateFrame("Frame", nil, main.frame)
    frame:SetAllPoints(main.frame); frame:SetFrameLevel(main.frame:GetFrameLevel()+20)
    self.frame = frame
    self.backButton = T.Button(frame,"返回提醒设置",200,(W-200)/2,-18,function() self:Back() end,"outline")
    -- Closing the window on this page reopens it on the settings page, not on a page with nothing shown.
    main.frame:HookScript("OnHide", function() if frame:IsShown() then frame:Hide(); main:SetPage("settings") end end)
    T.Label(frame, "提醒设置 / 大秘境默认爆发", 24, -84, 600, "small")
    self.heading = T.Label(frame, "我的爆发技能", 24, -104, 600, "title")
    self.sub = T.Label(frame, "", 24, -138, 860, "muted")
    self.state = T.Pill(frame, -24, -108)
    self.input = T.Edit(frame, W-48-172, 24, -172)
    self.input:SetMaxLetters(500)
    self.input:SetScript("OnEnterPressed", function() self:Add() end)
    self.inputHint = T.Label(self.input, "输入技能编号或粘贴技能链接，例如 279302", 12, -9, 600, "muted")
    self.input:HookScript("OnEditFocusGained", function() self.inputHint:Hide() end)
    self.input:HookScript("OnEditFocusLost", function(box) if box:GetText() == "" then self.inputHint:Show() end end)
    self.addButton = T.Button(frame, "添加技能", 160, W-24-160, -172, function() self:Add() end, "primary")
    local function list(x, title)
        local panel = T.Panel(frame, x, -224, 558, 380)
        local heading = T.Label(panel, title, 16, -18, 400, "heading")
        local scroll = T.Scroll(panel, 16, -52, LIST, 312)
        local child = CreateFrame("Frame", nil, scroll); child:SetSize(LIST, 1); scroll:SetScrollChild(child)
        return {scroll=scroll,child=child,rows={},title=heading,empty=T.Label(panel,"",16,-56,500,"small")}
    end
    self.selected = list(24, "当前提醒名单")
    self.available = list(598, "从本专精目录添加")
    self.resetButton = T.Button(frame, "恢复内置默认", 160, 24, -620, function() self:Reset() end)
    local note = T.Label(frame, "添加和删除立即保存，无需再点“保存设置”。未学会的技能不会提醒；删光可停用本专精自动技能。", W-24-700, -630, 700, "tiny")
    note:SetJustifyH("RIGHT")
    self.message = T.Label(frame, "", 24, -684, W-48, "small"); self.message:SetHeight(36)
    frame:Hide()
end

function U:Open()
    if InCombatLockdown() then NR.UI:Message("请脱战后编辑爆发技能"); return end
    local specID = NR.GetIdentity().specID
    if not NR.Number(specID, 1, 10000) then NR.UI:Message("当前专精不可用，请选择专精后重试"); return end
    if not self.frame then self:Create() end
    local main = NR.UI
    main.importPage:Hide(); main.settingsPage:Hide(); main.tabs:Hide(); main:Message("")
    self.specID = specID; self.input:SetText(""); self.inputHint:Show(); self:Refresh()
    self:Message("可从右侧添加，也可输入技能编号或粘贴技能链接；不修改已保存的首领方案。")
    self.frame:Show()
end
