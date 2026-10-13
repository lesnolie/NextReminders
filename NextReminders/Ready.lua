local _, NR = ...
NR.Ready = {}
-- Only public booleans cross this boundary. Never inspect startTime/duration or a duration object.
function NR.Ready.State(spellID,fromCooldownEvent)
    if not NR.Number(spellID,1,10000000) or not C_Spell or type(C_Spell.GetSpellCooldown)~="function" then return nil end
    local ok,info=pcall(C_Spell.GetSpellCooldown,spellID)
    if not ok or not NR.Public(info) or type(info)~="table" then return nil end
    local enabled,active=info.isEnabled,info.isActive
    if not NR.Public(enabled) or not NR.Public(active)
        or type(enabled)~="boolean" or type(active)~="boolean" or not enabled then return nil end
    if C_Spell.GetSpellCharges then
        local chargesOK,charges=pcall(C_Spell.GetSpellCharges,spellID)
        if not chargesOK then return nil end
        if charges~=nil then
            if not NR.Public(charges) or type(charges)~="table" then return nil end
            local max,recharging=charges.maxCharges,charges.isActive
            if not NR.Number(max,1,100) then return nil end
            if max>1 then
                if not NR.Public(recharging) or type(recharging)~="boolean" then return nil end
                return recharging and "cooling" or "ready"
            end
        end
    end
    if not active then return "ready" end
    -- Blizzard documents isOnGCD as trustworthy only while handling SPELL_UPDATE_COOLDOWN.
    if not fromCooldownEvent then return nil end
    local gcd=info.isOnGCD
    if not NR.Public(gcd) or type(gcd)~="boolean" then return nil end
    return not gcd and "cooling" or "ready"
end
