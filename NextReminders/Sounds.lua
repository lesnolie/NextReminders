local _, NR = ...
NR.Sounds = {}
local S = NR.Sounds

local MEDIA = "Interface\\AddOns\\NextReminders\\Media\\"
-- voice = the clip speaks for itself ("该放爆发了"), so the countdown stays quiet while it plays.
local BUILTIN = {
    { key = "off", name = "不播放" },
    -- Voice pack; any clip can be the reminder sound.
    { key = "noel_press", name = "诺艾尔：快按爆发", file = MEDIA .. "noel_press.ogg", length = 0.9, voice = true },
    { key = "lyl_fire_1", name = "李云龙：开炮！开！炮！", file = MEDIA .. "lyl_fire_1.ogg", length = 3.6, voice = true },
    { key = "molly_fire_1", name = "御女茉莉：哥哥！该放大招了哦！喵喵", file = MEDIA .. "molly_fire_1.ogg", length = 4.3, voice = true },
    { key = "promo_fire_1", name = "宣传片：该放大招了（一）", file = MEDIA .. "promo_fire_1.ogg", length = 2.7, voice = true },
    { key = "promo_fire_2", name = "宣传片：该放大招了（二）", file = MEDIA .. "promo_fire_2.ogg", length = 2, voice = true },
    { key = "rita_ready", name = "丽塔：大招好了", file = MEDIA .. "rita_ready.ogg", length = 1.1, voice = true },
    { key = "molly_miss_1", name = "御女茉莉：好舍不得你的大招哦！哥哥！", file = MEDIA .. "molly_miss_1.ogg", length = 4.1, voice = true },
}

-- Countdown cues (诺艾尔): not selectable, played by the voice countdown before the reminder sound.
local CUES = { prepare = MEDIA .. "prep_burst.ogg" }
for n = 1, 5 do CUES[n] = MEDIA .. "count_" .. n .. ".ogg" end

function S.PlayCue(key)
    local file = CUES[key]
    if not file or not PlaySoundFile then return false end
    return PlaySoundFile(file, "Master") ~= false
end

-- Clips the player deleted from the list (NR.db.hiddenSounds[key]=true). The files stay in the
-- addon; a deleted clip is not listed and never plays until restored. "off" cannot be deleted.
local function hidden()
    local db = NR.db
    if not db then return {} end
    if type(db.hiddenSounds) ~= "table" then db.hiddenSounds = {} end
    return db.hiddenSounds
end
function S.Exists(key)
    for _, entry in ipairs(BUILTIN) do if entry.key == key then return true end end
    return false
end
function S.IsHidden(key) return key ~= "off" and hidden()[key] == true end
function S.Remove(key)
    if key == "off" then return false end
    for _, entry in ipairs(BUILTIN) do if entry.key == key then hidden()[key] = true; return true end end
    return false
end
function S.HiddenCount()
    local count = 0
    for _, entry in ipairs(BUILTIN) do if S.IsHidden(entry.key) then count = count + 1 end end
    return count
end
function S.RestoreAll() if NR.db then NR.db.hiddenSounds = {} end end

-- Only the bundled voice pack (plus "off"): no client or LibSharedMedia sounds, so nothing else is listed or loaded.
function S.List()
    local list = {}
    for _, entry in ipairs(BUILTIN) do if not S.IsHidden(entry.key) then list[#list + 1] = entry end end
    return list
end

-- A deleted clip falls back to the fallback, then the first clip still listed, then "off".
function S.Find(key, fallback)
    for _, entry in ipairs(BUILTIN) do if entry.key == key and not S.IsHidden(key) then return entry end end
    for _, entry in ipairs(BUILTIN) do if entry.key == fallback and not S.IsHidden(fallback) then return entry end end
    local list = S.List()
    return list[2] or list[1]
end

-- Returns the entry that played (plus the client's sound handle, when it gives one), or nil when nothing could be played.
function S.Play(key)
    local entry = S.Find(key)
    if entry.key ~= key or not entry.file or not PlaySoundFile or S.IsHidden(key) then return nil end
    local willPlay, handle = PlaySoundFile(entry.file, "Master")
    if willPlay ~= false then return entry, handle end
end
