local _, NR = ...
-- Personal policy is separate from the boss signal definitions. No upstream addon is read.
NR.EventPlans = { schema = 2, dataVersion = "2026.10.12.3" }
local P = NR.EventPlans
local function integer(v, lo, hi) return NR.Number(v,lo,hi) and v%1==0 end

function P.Definition(encounterID, difficulty)
    local boss=NR.BossData.encounters[encounterID]
    return boss and boss.events and boss.events[difficulty] or {}
end

function P.Options(encounterID, difficulty)
    local out={{key="start",label="开战"}}
    local keys={}
    for key in pairs(P.Definition(encounterID,difficulty)) do keys[#keys+1]=key end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local d=P.Definition(encounterID,difficulty)[key]
        out[#out+1]={key=key,label=d.label.."（待游戏核对）"}
    end
    return out
end

function P.Validate(plan)
    if type(plan)~="table" or plan.kind~="events" or not integer(plan.specID,1,10000)
        or not integer(plan.encounterID,1,1000000) or not ({normal=true,heroic=true,mythic=true})[plan.difficulty]
        or type(plan.rows)~="table" or #plan.rows>100 then return nil,"首领规则结构无效" end
    local ids,readySpells={},{}
    for _,r in ipairs(plan.rows) do
        if type(r)~="table" or not integer(r.id,1,10000) or ids[r.id]
            or (r.anchor~="start" and not P.Definition(plan.encounterID,plan.difficulty)[r.anchor])
            or not NR.Number(r.time,0,3600) or math.abs(r.time*10-math.floor(r.time*10+0.5))>1e-6
            or not NR.Number(r.window,0.1,60) or r.time+r.window>3660
            or (r.every~=true and not integer(r.occurrence,1,20))
            or (r.anchor=="start" and (r.every or r.occurrence~=1))
            or (r.enabled~=nil and type(r.enabled)~="boolean")
            or (r.hold~=nil and (type(r.hold)~="string" or #r.hold>200)) then return nil,"事件、次数或提醒窗口无效" end
        local kind=r.actionType or "spell"
        if r.after~=nil then
            if r.after~="ready" or kind~="spell" or r.every or r.occurrence~=1 or not integer(r.spellID,1,10000000) or readySpells[r.spellID] then
                return nil,"后续就绪仅支持第一次的技能行，同一技能只能设置一处"
            end
            readySpells[r.spellID]=true
        end
        if kind=="spell" then
            if not integer(r.spellID,1,10000000) then return nil,"技能编号无效" end
        elseif kind=="item" then
            if not integer(r.itemID,1,10000000) then return nil,"物品编号无效" end
        elseif kind=="slot" then
            if r.slot~=13 and r.slot~=14 then return nil,"饰品槽只能是13或14" end
        elseif kind=="text" then
            if type(r.label)~="string" or #r.label==0 or #r.label>120 then return nil,"文字提醒需填写内容" end
        else return nil,"提醒类型无效" end
        ids[r.id]=true
    end
    if #plan.rows==0 then return nil,"至少需要一条首领规则" end
    return true
end

local function fields(line)
    local out={}
    for segment in (line..";"):gmatch("([^;]*);") do
        if segment~="" then
            local key,value=segment:match("^([%a][%w_]*):(.*)$")
            if not key or out[key:lower()]~=nil then return nil,"无效或重复字段" end
            out[key:lower()]=value
        end
    end
    return out
end
local function decode(value)
    if not value then return nil end
    if value:gsub("%%[%x][%x]",""):find("%%") then return nil end
    return (value:gsub("%%([%x][%x])",function(pair) return string.char(tonumber(pair,16)) end))
end
function P.Parse(text)
    if type(text)~="string" or #text>200000 then return nil,"导出文本过大或无效" end
    local p={kind="events",enabled=true,rows={},format="NextReminders",dataVersion=P.dataVersion}
    local header=false
    local version
    for raw in (text:gsub("\r","").."\n"):gmatch("([^\n]*)\n") do
        local line=NR.Trim(raw)
        if line~="" and not line:match("^#") then
            local f,err=fields(line); if not f then return nil,err end
            if f.nrplan then
                if header or (f.nrplan~="1" and f.nrplan~="2") then return nil,"不支持的方案版本或重复头部" end
                version=f.nrplan
                for k in pairs(f) do if not ({nrplan=true,encounterid=true,difficulty=true,specid=true,name=true})[k] then return nil,"未知头部字段："..k end end
                p.encounterID,p.specID=tonumber(f.encounterid),tonumber(f.specid)
                p.difficulty=f.difficulty and f.difficulty:lower(); p.name=decode(f.name) or "网站方案"
                if f.name and not decode(f.name) then return nil,"方案名字编码无效" end
                header=true
            else
                if not header then return nil,"缺少NRPlan头部" end
                for k in pairs(f) do
                    if not ({anchor=true,occurrence=true,time=true,window=true,spellid=true,itemid=true,slot=true,text=true,hold=true,after=version=="2"})[k] then return nil,"未知规则字段："..k end
                end
                local actions=(f.spellid and 1 or 0)+(f.itemid and 1 or 0)+(f.slot and 1 or 0)+(f.text and 1 or 0)
                if actions~=1 then return nil,"每行必须指定一种提醒动作" end
                local r={id=#p.rows+1,anchor=f.anchor,time=tonumber(f.time),window=tonumber(f.window),
                    every=f.occurrence=="every" or nil,occurrence=tonumber(f.occurrence),hold=decode(f.hold),after=f.after,enabled=true}
                if f.hold and not r.hold then return nil,"等待文字编码无效" end
                if f.spellid then r.spellID=tonumber(f.spellid)
                elseif f.itemid then r.actionType,r.itemID="item",tonumber(f.itemid)
                elseif f.slot then r.actionType,r.slot="slot",tonumber(f.slot)
                else r.actionType,r.label="text",decode(f.text) end
                p.rows[#p.rows+1]=r
                if #p.rows>100 then return nil,"最多100条首领规则" end
            end
        end
    end
    local ok,err=P.Validate(p); if not ok then return nil,err end
    return p
end

local function dungeonKey(specID,dungeonID) return specID..":"..dungeonID end
function P.ValidateDungeon(bundle)
    if type(bundle)~="table" or bundle.kind~="dungeon" or not integer(bundle.specID,1,10000)
        or not integer(bundle.dungeonID,1,1000000) or bundle.difficulty~="mythic"
        or type(bundle.plans)~="table" then return nil,"副本方案结构无效" end
    local d=NR.DungeonData.dungeons[bundle.dungeonID]
    if not d or #bundle.plans<1 or #bundle.plans>#d.bosses then return nil,"副本目录或首领数量无效" end
    local allowed,seen={},{}
    for _,id in ipairs(d.bosses) do allowed[id]=true end
    for _,p in ipairs(bundle.plans) do
        local ok,err=P.Validate(p)
        if not ok then return nil,err end
        if p.specID~=bundle.specID or p.difficulty~=bundle.difficulty or not allowed[p.encounterID] or seen[p.encounterID] then
            return nil,"副本内首领、专精或难度不一致"
        end
        seen[p.encounterID]=true
    end
    return true
end

function P.ParseDungeon(text)
    if type(text)~="string" or #text>200000 then return nil,"导出文本过大或无效" end
    local bundle={kind="dungeon",plans={},enabled=true,format="NextRemindersDungeon"}
    local header,block=false,{}
    local function finish()
        if #block==0 then return true end
        local p,err=P.Parse(table.concat(block,"\n")); if not p then return nil,err end
        bundle.plans[#bundle.plans+1]=p;block={}
        return true
    end
    for raw in (text:gsub("\r","").."\n"):gmatch("([^\n]*)\n") do
        local line=NR.Trim(raw)
        if line~="" and not line:match("^#") then
            local f,err=fields(line);if not f then return nil,err end
            if not header then
                if f.nrdungeon~="1" then return nil,"缺少或不支持NRDungeon头部" end
                for k in pairs(f) do if not ({nrdungeon=true,dungeonid=true,difficulty=true,specid=true,name=true})[k] then return nil,"未知副本字段："..k end end
                bundle.dungeonID,bundle.specID=tonumber(f.dungeonid),tonumber(f.specid)
                bundle.difficulty=f.difficulty and f.difficulty:lower();bundle.name=decode(f.name)
                if f.name and not bundle.name then return nil,"副本名字编码无效" end
                header=true
            else
                if f.nrdungeon then return nil,"重复副本头部" end
                if f.nrplan then local ok,e=finish();if not ok then return nil,e end
                elseif #block==0 then return nil,"缺少首领方案头部" end
                block[#block+1]=line
            end
        end
    end
    local ok,err=finish();if not ok then return nil,err end
    ok,err=P.ValidateDungeon(bundle);if not ok then return nil,err end
    return bundle
end

function P.SaveDungeon(bundle)
    if InCombatLockdown() then return nil,"请脱战后保存副本方案" end
    local ok,err=P.ValidateDungeon(bundle);if not ok then return nil,err end
    local specs=type(NR.db.eventPlans)=="table" and NR.db.eventPlans or {}
    local current=type(specs[bundle.specID])=="table" and specs[bundle.specID] or {}
    local nextPlans=NR.Copy(current)
    local scopes=type(NR.db.dungeonScopes)=="table" and NR.db.dungeonScopes or {}
    local scopeKey=dungeonKey(bundle.specID,bundle.dungeonID)
    local backup={specID=bundle.specID,dungeonID=bundle.dungeonID,difficulty="mythic",entries={},scope=scopes[scopeKey]==true}
    -- A bundle is a complete replacement of this dungeon's event policies for one spec.
    -- Validate the whole input before touching storage, and keep absent old entries as false.
    for _,id in ipairs(NR.DungeonData.dungeons[bundle.dungeonID].bosses) do
        local key=id..":mythic";backup.entries[key]=current[key] and NR.Copy(current[key]) or false;nextPlans[key]=nil
    end
    for _,p in ipairs(bundle.plans) do local saved=NR.Copy(p);saved.enabled=true;saved.dungeonID=bundle.dungeonID;nextPlans[p.encounterID..":mythic"]=saved end
    NR.db.previousDungeons=type(NR.db.previousDungeons)=="table" and NR.db.previousDungeons or {}
    NR.db.previousDungeons[dungeonKey(bundle.specID,bundle.dungeonID)]=backup
    NR.db.eventPlans=specs;specs[bundle.specID]=nextPlans
    NR.db.dungeonScopes=scopes;scopes[scopeKey]=true
    NR.db.lastDungeon={specID=bundle.specID,dungeonID=bundle.dungeonID,difficulty="mythic",name=bundle.name}
    return true
end

function P.LastDungeon(last)
    if type(last)~="table" or not integer(last.specID,1,10000) or not integer(last.dungeonID,1,1000000) then return end
    local d=NR.DungeonData.dungeons[last.dungeonID];if not d then return end
    local bundle={kind="dungeon",specID=last.specID,dungeonID=last.dungeonID,difficulty="mythic",name=d.name,plans={}}
    for _,id in ipairs(d.bosses) do local p=P.Find(last.specID,id,"mythic");if p then bundle.plans[#bundle.plans+1]=NR.Copy(p) end end
    if P.ValidateDungeon(bundle) then return bundle end
end

function P.OwnsDungeonEncounter(specID,encounterID)
    if not integer(specID,1,10000) or not integer(encounterID,1,1000000) then return false end
    local scopes=NR.db.dungeonScopes
    for id,d in pairs(NR.DungeonData.dungeons) do
        if type(scopes)=="table" and scopes[dungeonKey(specID,id)]==true then
            for _,boss in ipairs(d.bosses) do if boss==encounterID then return true end end
        end
    end
    return false
end

function P.PauseDungeon(last)
    if InCombatLockdown() then return nil,"请脱战后暂停" end
    local bundle=P.LastDungeon(last);if not bundle then return nil,"没有有效的副本方案" end
    for _,p in ipairs(bundle.plans) do NR.db.eventPlans[p.specID][p.encounterID..":mythic"].enabled=false end
    return true
end

function P.RollbackDungeon(last)
    if InCombatLockdown() then return nil,"请脱战后回滚" end
    if type(last)~="table" or not integer(last.specID,1,10000) or not integer(last.dungeonID,1,1000000) then return nil,"没有可回滚的副本方案" end
    local d=NR.DungeonData.dungeons[last.dungeonID]
    local backups=NR.db.previousDungeons
    local old=type(backups)=="table" and backups[dungeonKey(last.specID,last.dungeonID)]
    if not d or type(old)~="table" or old.specID~=last.specID or old.dungeonID~=last.dungeonID or old.difficulty~="mythic" or type(old.entries)~="table" then return nil,"没有有效的副本备份" end
    local specs=NR.db.eventPlans;local current=type(specs)=="table" and specs[last.specID]
    current=type(current)=="table" and current or {}
    local scopes=type(NR.db.dungeonScopes)=="table" and NR.db.dungeonScopes or {}
    local scopeKey=dungeonKey(last.specID,last.dungeonID)
    if type(old.scope)~="boolean" then return nil,"副本备份范围无效" end
    local nextPlans=NR.Copy(current);local replacement={specID=last.specID,dungeonID=last.dungeonID,difficulty="mythic",entries={},scope=scopes[scopeKey]==true}
    for _,id in ipairs(d.bosses) do
        local key=id..":mythic";local p=old.entries[key]
        if p~=false and (not P.Validate(p) or p.specID~=last.specID or p.encounterID~=id or p.difficulty~="mythic") then return nil,"副本备份包含无效首领规则" end
        replacement.entries[key]=current[key] and NR.Copy(current[key]) or false
        nextPlans[key]=p and NR.Copy(p) or nil
    end
    NR.db.eventPlans=type(specs)=="table" and specs or {};NR.db.eventPlans[last.specID]=nextPlans
    backups[dungeonKey(last.specID,last.dungeonID)]=replacement
    NR.db.dungeonScopes=scopes;scopes[scopeKey]=old.scope
    return true
end

function P.New(specID, encounterID, difficulty)
    local p={kind="events",specID=specID,encounterID=encounterID,difficulty=difficulty or "mythic",enabled=true,rows={},dataVersion=P.dataVersion}
    -- This preset expresses the user's requested policy, not a universal rotation recommendation.
    if specID==252 and encounterID==3101 and p.difficulty=="mythic" then
        p.rows={
            {id=1,spellID=1233448,anchor="start",occurrence=1,time=0,window=10},
            {id=2,spellID=42650,anchor="vuln",occurrence=1,time=0,window=10,hold="亡者大军：留着，等第一次易伤",after="ready"},
            {id=3,spellID=1233448,anchor="vuln",occurrence=1,time=0,window=10,after="ready"},
            {id=4,actionType="text",label="药水与主动饰品",anchor="vuln",occurrence=1,time=0,window=10},
        }
    end
    return p
end

function P.Find(specID, encounterID, difficulty)
    if not integer(specID,1,10000) or not integer(encounterID,1,1000000) or type(difficulty)~="string" then return end
    local specs=NR.db and NR.db.eventPlans
    local plans=type(specs)=="table" and specs[specID]
    local p=type(plans)=="table" and plans[encounterID..":"..difficulty]
    if P.Validate(p) and p.specID==specID and p.encounterID==encounterID and p.difficulty==difficulty then return p end
end
function P.Get(specID, encounterID, difficulty)
    local p=P.Find(specID,encounterID,difficulty)
    if p and p.enabled then return p end
end

function P.Save(plan)
    if InCombatLockdown() then return nil,"请脱战后保存首领规则" end
    local ok,err=P.Validate(plan); if not ok then return nil,err end
    NR.db.eventPlans=type(NR.db.eventPlans)=="table" and NR.db.eventPlans or {}
    local specs=NR.db.eventPlans
    specs[plan.specID]=type(specs[plan.specID])=="table" and specs[plan.specID] or {}
    local key=plan.encounterID..":"..plan.difficulty
    local old=specs[plan.specID][key]
    if old then
        NR.db.previousEventPlans=type(NR.db.previousEventPlans)=="table" and NR.db.previousEventPlans or {}
        NR.db.previousEventPlans[plan.specID]=type(NR.db.previousEventPlans[plan.specID])=="table" and NR.db.previousEventPlans[plan.specID] or {}
        NR.db.previousEventPlans[plan.specID][key]=NR.Copy(old)
    end
    specs[plan.specID][key]=NR.Copy(plan)
    return true
end

function P.Rollback(last)
    if InCombatLockdown() then return nil,"请脱战后回滚" end
    if type(last)~="table" then return nil,"没有可回滚的事件方案" end
    local p=P.Find(last.specID,last.encounterID,last.difficulty)
    local backups=NR.db.previousEventPlans
    local bucket=type(backups)=="table" and backups[last.specID]
    local key=p and last.encounterID..":"..last.difficulty
    local old=key and type(bucket)=="table" and bucket[key]
    if not p or not P.Validate(old) or old.specID~=last.specID or old.encounterID~=last.encounterID or old.difficulty~=last.difficulty then return nil,"没有有效的备份" end
    NR.db.eventPlans[last.specID][key],bucket[key]=NR.Copy(old),NR.Copy(p)
    return true
end

function P.Action(row)
    local kind=row.actionType or "spell"
    if kind=="text" then return row.label,nil,nil end
    if kind=="spell" then
        local name,icon=NR.SpellCatalog.Info(row.spellID)
        return name,icon,row.spellID
    end
    local itemID=row.itemID
    if kind=="slot" then
        itemID=GetInventoryItemID and GetInventoryItemID("player",row.slot)
        if not NR.Number(itemID,1,10000000) then return "饰品槽 "..row.slot,nil,nil end
    end
    local name,_,_,_,_,_,_,_,_,icon
    if C_Item and C_Item.GetItemInfo then name,_,_,_,_,_,_,_,_,icon=C_Item.GetItemInfo(itemID) end
    local _,useSpellID
    if C_Item and C_Item.GetItemSpell then _,useSpellID=C_Item.GetItemSpell(itemID) end
    return NR.Public(name) and type(name)=="string" and name or "物品 "..itemID,
        NR.Number(icon,1,100000000) and icon or nil,NR.Number(useSpellID,1,10000000) and useSpellID or nil
end
