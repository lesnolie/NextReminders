local _, NR = ...
NR.Display = { rows = {} }
local D = NR.Display

local function timeLabel(remaining)
    if type(remaining) ~= "number" then return "" end
    return remaining > 0 and (math.ceil(remaining) .. "秒") or "现在"
end

-- Upper middle of the screen: the first row's top sits 16% down from the top edge.
D.TOP_SHARE = 0.16
function D:Anchor()
    local c, position = self.container, NR.db.position
    c:ClearAllPoints()
    if position then c:SetPoint("CENTER", UIParent, "CENTER", position.x or 0, position.y or 0); return end
    local height = UIParent.GetHeight and UIParent:GetHeight()
    local scale = c.GetScale and c:GetScale() or 1
    local y = NR.Number(height, 1, 100000) and -height * self.TOP_SHARE / (scale > 0 and scale or 1) or -170
    c:SetPoint("TOP", UIParent, "TOP", 0, y)
end

function D:Create()
    self.container = CreateFrame("Frame", "NextRemindersAnchor", UIParent)
    self.container:SetSize(420, 50)
    self.container:SetFrameStrata("FULLSCREEN_DIALOG")
    self.container:SetScale(NR.db.settings.scale)
    self:Anchor()
end

function D:Layout()
    local visible = {}
    for _, frame in pairs(self.rows) do if frame.active then visible[#visible + 1] = frame end end
    table.sort(visible, function(a,b) if a.target ~= b.target then return a.target < b.target end return tostring(a.rowID)<tostring(b.rowID) end)
    for index, frame in ipairs(visible) do
        frame:ClearAllPoints()
        frame:SetPoint("TOP", self.container, "TOP", 0, -(index - 1) * 52)
    end
end

function D:Row(id)
    if self.rows[id] then return self.rows[id] end
    local frame = CreateFrame("Frame", nil, self.container, "BackdropTemplate")
    frame:SetSize(420, 48)
    -- Plain see-through bar (not the settings window's light cards): the game stays visible, text and icon keep full alpha.
    frame:SetBackdrop({bgFile="Interface\Buttons\WHITE8X8",edgeFile="Interface\Buttons\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(0.035, 0.055, 0.086, 0.18)
    frame:SetBackdropBorderColor(0.153, 0.208, 0.286, 0.25)
    local stripe=frame:CreateTexture(nil,"ARTWORK")
    stripe:SetPoint("TOPLEFT"); stripe:SetPoint("BOTTOMLEFT"); stripe:SetWidth(3)
    stripe:SetColorTexture(0.310, 0.831, 1, 1)
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(40, 40); frame.icon:SetPoint("LEFT", 4, 0)
    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.label:SetPoint("LEFT", frame.icon, "RIGHT", 10, 0); frame.label:SetWidth(270); frame.label:SetJustifyH("LEFT")
    frame.label:SetShadowColor(0, 0, 0, 1); frame.label:SetShadowOffset(1, -1)
    frame.time = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.time:SetPoint("RIGHT", -10, 0)
    frame.time:SetShadowColor(0, 0, 0, 1); frame.time:SetShadowOffset(1, -1)
    frame:Hide()
    self.rows[id] = frame
    return frame
end

function D:Emit(kind, row, value)
    if kind == "phase" then
        if value then NR.Print("识别节点：" .. value) end
        return
    end
    if kind == "show" or kind=="hold" then
        -- The preview player window covers the middle of the screen; only then do rows move to the top edge.
        local window = NR.PreviewUI and NR.PreviewUI.frame
        if row.preview and not self.previewMode and window and window:IsShown() then
            self.previewMode=true
            self.container:ClearAllPoints()
            self.container:SetPoint("TOP",UIParent,"TOP",0,-12)
        end
        local frame = self:Row(row.id)
        local name,icon = NR.SpellCatalog.Info(row.spellID)
        name=row.actionName or name
        frame.icon:SetTexture(row.actionIcon or icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        frame.label:SetText((row.preview and "预览 · " or "") .. (kind=="hold" and row.hold or name))
        frame.active, frame.target, frame.rowID = true, row.target or math.huge, row.id
        frame.time:SetText(kind=="hold" and "等待" or timeLabel(value))
        frame:Show(); self:Layout()
        if kind=="show" then
            local s=NR.db.settings
            -- The clip marks the moment itself: shown early, it waits for the countdown and plays when time is up.
            -- Several reminders due together share one sound.
            frame.due=not (value and value>0)
            if frame.due then self:PlaySound(s.soundChoice) end
        end
    elseif kind == "hide" then
        local frame = self.rows[row.id]
        if frame then frame.active = false; frame:Hide(); self:Layout() end
    elseif kind == "update" then
        local frame = self.rows[row.id]
        if frame then
            frame.time:SetText(timeLabel(value))
            if frame.active and not frame.due and value<=0 then frame.due=true; self:PlaySound(NR.db.settings.soundChoice) end
        end
    elseif kind == "countdown" then
        local now = GetTime()
        if self.voiceUntil and now < self.voiceUntil then return end
        if self.lastNumber ~= value or not self.lastNumberTime or now - self.lastNumberTime > 0.7 then
            NR.Sounds.PlayCue(value)
            self.lastNumber, self.lastNumberTime = value, now
        end
    end
end

-- One sound at a time: reminders shown together share it, and the countdown stays quiet until it ends.
function D:PlaySound(key)
    local s,now=NR.db.settings,GetTime()
    if not s.sound or now<(self.soundUntil or 0) then return end
    local played,handle=NR.Sounds.Play(key)
    if played then self.soundUntil=now+(played.length or 1); self.voiceUntil=played.voice and self.soundUntil or nil; self.soundHandle=handle end
end

-- Stop a clip that is still playing.
function D:Silence()
    if self.soundHandle and StopSound then StopSound(self.soundHandle) end
    self.soundHandle, self.soundUntil, self.voiceUntil = nil, nil, nil
end

function D:Clear()
    for _, frame in pairs(self.rows) do frame.active = false; frame:Hide() end
    self.lastNumber, self.lastNumberTime, self.soundUntil, self.voiceUntil = nil, nil, nil, nil
    if self.previewMode then
        self.previewMode=false
        self:Anchor()
    end
end
