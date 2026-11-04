local _, NR = ...
_G.NextReminders = NR
NR.version = "0.3.13-dev"
NR.defaults = { lead = 10, window = 5, hideOnUse = true,
    countdown = true, sound = true, soundChoice = "noel_press", scale = 1, autoBurst = true }

-- Voice countdown: "准备爆发" at 6.4s (the 1.2s clip ends before "5"), then 5, 4, 3, 2, 1.
-- The lead is exactly what the player entered; below ~7s there is no room for "准备爆发".
NR.COUNT_FROM, NR.PREPARE_AT = 5, 6.4
function NR.ShowLead(settings)
    return settings.lead
end

function NR.Public(value)
    return not (issecretvalue and issecretvalue(value))
end

function NR.Number(value, minimum, maximum)
    return NR.Public(value) and type(value) == "number" and value == value
        and value >= (minimum or 0) and value <= (maximum or 3600)
end

-- Lorrgs numbers intermissions as 1.5 / 1.75 / 2.5; at most two decimals.
function NR.Phase(value)
    return NR.Number(value, 1, 100) and math.abs(value * 100 - math.floor(value * 100 + 0.5)) < 1e-6
end

function NR.PhaseLabel(phase)
    return string.format("%g", phase)
end

-- "135", "135.5", "2:15" or "2:15.5" -> seconds within 0..3600.
function NR.ParseClock(text)
    if type(text) ~= "string" then return nil end
    text = NR.Trim(text)
    local minute, second = text:match("^(%d+):(%d%d%.?%d*)$")
    local value = minute and tonumber(minute) * 60 + tonumber(second) or text:match("^%d+%.?%d*$") and tonumber(text)
    if minute and tonumber(second) >= 60 then return nil end
    return NR.Number(value, 0, 3600) and value or nil
end

function NR.Trim(value)
    return value:match("^%s*(.-)%s*$")
end

function NR.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = NR.Copy(child) end
    return result
end

function NR.Print(text)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff55c9ffNextReminders|r: " .. text) end
end

function NR.Settings(input)
    local result = NR.Copy(NR.defaults)
    input = type(input) == "table" and input or {}
    for _, key in ipairs({"lead", "window", "scale"}) do
        local bounds = key == "scale" and {0.5, 2} or {0, 60}
        if NR.Number(input[key], bounds[1], bounds[2]) then result[key] = input[key] end
    end
    for _, key in ipairs({"hideOnUse", "countdown", "sound", "autoBurst"}) do
        if type(input[key]) == "boolean" then result[key] = input[key] end
    end
    if type(input.soundChoice) == "string" and #input.soundChoice <= 200 then result.soundChoice = input.soundChoice end
    return result
end

-- The client's name for a specialization; "专精 <id>" when the client cannot say.
function NR.SpecName(specID)
    if GetSpecializationInfoByID and NR.Number(specID, 1, 10000) then
        local ok, _, name = pcall(GetSpecializationInfoByID, specID)
        if ok and NR.Public(name) and type(name) == "string" and name ~= "" then return name end
    end
    return "专精 " .. tostring(specID)
end
