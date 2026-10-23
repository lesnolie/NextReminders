local _, NR = ...
NR.Display = { rows = {}, frameCache = {}, glows = {} }
local D = NR.Display

local function timeLabel(remaining)
    if type(remaining) ~= "number" then return "" end
    return remaining > 0 and (math.ceil(remaining) .. "秒") or "现在"
end

-- The voice list is read once per session (each call builds a new table); Cleanup drops it.
local ttsVoices
local function speak(text)
    if not C_VoiceChat or not C_VoiceChat.GetTtsVoices or not C_VoiceChat.SpeakText then return end
    ttsVoices = ttsVoices or C_VoiceChat.GetTtsVoices() or {}
    local voices = ttsVoices
    local voice = voices[1] and voices[1].voiceID
    for _, entry in ipairs(voices) do if entry.voiceID == NR.db.settings.voice then voice = entry.voiceID end end
    if not voice then return end
    C_VoiceChat.SpeakText(voice, text, 0, NR.db.settings.volume, true)
end

function D:Create()
    self.container = CreateFrame("Frame", "NextRemindersAnchor", UIParent)
    self.container:SetSize(420, 50)
    self.container:SetFrameStrata("FULLSCREEN_DIALOG")
    local position = NR.db.position
    self.container:SetPoint("CENTER", UIParent, "CENTER", position and position.x or 0, position and position.y or 160)
    self.container:SetScale(NR.db.settings.scale)
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

function D:SetGlow(rowID, enabled)
    if not enabled then
        for _, record in pairs(self.glows) do record.users[rowID] = nil end
        self:RefreshGlows()
        return
    end
    local names = NR.db.settings.glow or ""
    for name in names:gsub("，", ","):gmatch("[^,%s]+") do
        for _, record in ipairs(self.frameCache[name:lower()] or {}) do
            record.users[rowID] = true
        end
    end
    self:RefreshGlows()
end

function D:RefreshGlows()
    for _, record in pairs(self.glows) do
        local visible = record.frame:IsVisible()
        record.overlay:SetAlpha(next(record.users) and NR.Public(visible) and visible and 1 or 0)
    end
end

function D:Emit(kind, row, value)
    if kind == "phase" then
        if value then NR.Print("识别节点：" .. value) end
        return
    end
    if kind == "show" or kind=="hold" then
        if row.preview and not self.previewMode then
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
        frame:Show(); self:Layout(); self:SetGlow(row.id, kind~="hold")
        if kind=="show" then
            local s,now=NR.db.settings,GetTime()
            -- The clip marks the moment itself: shown early, it waits for the countdown and plays when time is up.
            -- Several reminders due together share one sound; a playing clip replaces the spell-name TTS.
            frame.due=not (value and value>0)
            if frame.due then self:PlaySound(s.soundChoice) end
            local quiet=self.voiceUntil and now<self.voiceUntil
            if s.tts and not quiet then speak(name..(row.postReady and "好了" or "")) end
        end
    elseif kind == "hide" then
        local frame = self.rows[row.id]
        if frame then frame.active = false; frame:Hide(); self:Layout() end
        self:SetGlow(row.id, false)
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
            speak(tostring(value)); self.lastNumber, self.lastNumberTime = value, now
        end
    end
end

-- One sound at a time: reminders shown together share it, and a voice clip quiets TTS until it ends.
function D:PlaySound(key)
    local s,now=NR.db.settings,GetTime()
    if not s.sound or now<(self.soundUntil or 0) then return end
    local played,handle=NR.Sounds.Play(key)
    if played then self.soundUntil=now+(played.length or 1); self.voiceUntil=played.voice and self.soundUntil or nil; self.soundHandle=handle end
end

-- Stop a clip or spoken text that is still playing and forget cached lists.
function D:Silence()
    if self.soundHandle and StopSound then StopSound(self.soundHandle) end
    if C_VoiceChat and C_VoiceChat.StopSpeakingText then C_VoiceChat.StopSpeakingText() end
    self.soundHandle, self.soundUntil, self.voiceUntil, ttsVoices = nil, nil, nil, nil
end

function D:Clear()
    for _, frame in pairs(self.rows) do frame.active = false; frame:Hide() end
    for _, record in pairs(self.glows) do record.users = {}; record.overlay:SetAlpha(0) end
    self.lastNumber, self.lastNumberTime, self.soundUntil, self.voiceUntil = nil, nil, nil, nil
    if self.previewMode then
        self.previewMode=false
        local position=NR.db.position
        self.container:ClearAllPoints()
        self.container:SetPoint("CENTER",UIParent,"CENTER",position and position.x or 0,position and position.y or 160)
    end
end

local function makeOverlay(frame)
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetAllPoints(frame); overlay:SetFrameStrata("HIGH")
    local specs = { {"TOPLEFT","TOPRIGHT",true}, {"BOTTOMLEFT","BOTTOMRIGHT",true}, {"TOPLEFT","BOTTOMLEFT",false}, {"TOPRIGHT","BOTTOMRIGHT",false} }
    for _, spec in ipairs(specs) do
        local texture = overlay:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(0.15, 0.85, 1, 1)
        texture:SetPoint(spec[1], overlay, spec[1]); texture:SetPoint(spec[2], overlay, spec[2])
        if spec[3] then texture:SetHeight(3) else texture:SetWidth(3) end
    end
    overlay:SetAlpha(0)
    return overlay
end

-- Native Blizzard party/raid frames only. Create/anchor our overlays outside combat.
function D:CacheFrames()
    if InCombatLockdown() then return end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return end
    self.frameCache = {}
    for _, record in pairs(self.glows) do record.users = {}; record.overlay:SetAlpha(0) end
    local frames = { PlayerFrame }
    for i = 1, 40 do frames[#frames + 1] = _G["CompactRaidFrame" .. i] end
    for group = 1, 8 do
        for member = 1, 5 do frames[#frames + 1] = _G["CompactRaidGroup" .. group .. "Member" .. member] end
    end
    for i = 1, 5 do frames[#frames + 1] = _G["CompactPartyFrameMember" .. i] end
    for i = 1, 4 do frames[#frames + 1] = PartyFrame and PartyFrame["MemberFrame" .. i] end
    local function cache(key, record)
        local records = self.frameCache[key] or {}
        for _, existing in ipairs(records) do if existing == record then return end end
        records[#records + 1] = record
        self.frameCache[key] = records
    end
    for _, frame in ipairs(frames) do
        if frame and not frame:IsForbidden() then
            local unit = frame.displayedUnit
            if NR.Public(unit) and unit == nil then unit = frame.unit end
            if frame == PlayerFrame then unit = "player" end
            if NR.Public(unit) and type(unit) == "string" then
                local name, realm = UnitName(unit)
                if NR.Public(name) and type(name) == "string" then
                    local record = self.glows[frame]
                    if not record then record = { frame = frame, overlay = makeOverlay(frame), users = {} }; self.glows[frame] = record end
                    cache(name:lower(), record)
                    cache(unit:lower(), record)
                    if NR.Public(realm) and type(realm) == "string" and realm ~= "" then cache((name .. "-" .. realm):lower(), record) end
                end
            end
        end
    end
    for id, frame in pairs(self.rows) do if frame.active then self:SetGlow(id, true) end end
end
