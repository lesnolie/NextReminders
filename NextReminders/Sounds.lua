local _, NR = ...
NR.Sounds = {}
local S = NR.Sounds

local MEDIA = "Interface\\AddOns\\NextReminders\\Media\\"
-- voice = the clip speaks for itself ("该放爆发了"), so the spell-name TTS and countdown stay quiet while it plays.
local BUILTIN = {
    { key = "off", name = "不播放" },
    -- Voice pack; any clip can be the reminder sound.
    { key = "meow", name = "噔噔噔！该放爆发了哟！~喵~", file = MEDIA .. "burst_meow.ogg", length = 2.9, voice = true },
    { key = "lyl_fire_1", name = "李云龙：开炮！开！炮！（一）", file = MEDIA .. "lyl_fire_1.ogg", length = 3.6, voice = true },
    { key = "lyl_fire_2", name = "李云龙：开炮！开！炮！（二）", file = MEDIA .. "lyl_fire_2.ogg", length = 3.6, voice = true },
    { key = "molly_fire_1", name = "御女茉莉：哥哥！该放大招了哦！喵喵（一）", file = MEDIA .. "molly_fire_1.ogg", length = 4.3, voice = true },
    { key = "molly_fire_2", name = "御女茉莉：哥哥！该放大招了哦！喵喵（二）", file = MEDIA .. "molly_fire_2.ogg", length = 4.5, voice = true },
    { key = "promo_fire_1", name = "宣传片：该放大招了（一）", file = MEDIA .. "promo_fire_1.ogg", length = 2.7, voice = true },
    { key = "promo_fire_2", name = "宣传片：该放大招了（二）", file = MEDIA .. "promo_fire_2.ogg", length = 2, voice = true },
    { key = "rita_ready", name = "丽塔：大招好了", file = MEDIA .. "rita_ready.ogg", length = 1.1, voice = true },
    { key = "molly_miss_1", name = "御女茉莉：好舍不得你的大招哦！哥哥！（一）", file = MEDIA .. "molly_miss_1.ogg", length = 4.1, voice = true },
    { key = "molly_miss_2", name = "御女茉莉：好舍不得你的大招哦！哥哥！（二）", file = MEDIA .. "molly_miss_2.ogg", length = 4.7, voice = true },
}

-- Only the bundled voice pack (plus "off"): no client or LibSharedMedia sounds, so nothing else is listed or loaded.
function S.List()
    return BUILTIN
end

function S.Find(key, fallback)
    for _, entry in ipairs(BUILTIN) do if entry.key == key then return entry end end
    for _, entry in ipairs(BUILTIN) do if entry.key == fallback then return entry end end
    return BUILTIN[1]
end

-- Returns the entry that played (plus the client's sound handle, when it gives one), or nil when nothing could be played.
function S.Play(key)
    local entry = S.Find(key)
    if entry.key ~= key or not entry.file or not PlaySoundFile then return nil end
    local willPlay, handle = PlaySoundFile(entry.file, "Master")
    if willPlay ~= false then return entry, handle end
end
