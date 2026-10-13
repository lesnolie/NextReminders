local _, NR = ...
_G.NextReminders = NR
NR.version = "0.3.5-dev"
NR.defaults = { lead = 5, window = 10, hideOnUse = true, tts = true,
    countdown = true, sound = false, glow = "", volume = 80, scale = 1 }

function NR.Public(value)
    return not (issecretvalue and issecretvalue(value))
end

function NR.Number(value, minimum, maximum)
    return NR.Public(value) and type(value) == "number" and value == value
        and value >= (minimum or 0) and value <= (maximum or 3600)
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
    for _, key in ipairs({"lead", "window", "volume", "scale"}) do
        local bounds = key == "scale" and {0.5, 2} or key == "volume" and {0, 100} or {0, 60}
        if NR.Number(input[key], bounds[1], bounds[2]) then result[key] = input[key] end
    end
    for _, key in ipairs({"hideOnUse", "tts", "countdown", "sound"}) do
        if type(input[key]) == "boolean" then result[key] = input[key] end
    end
    if type(input.glow) == "string" and #input.glow <= 500 then result.glow = input.glow end
    if NR.Number(input.voice, 0, 100000) then result.voice = input.voice end
    return result
end
