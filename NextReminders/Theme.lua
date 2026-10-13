local _, NR = ...
NR.Theme = {}
local T = NR.Theme
T.colors = {
    window={0.043,0.063,0.094,1}, header={0.055,0.082,0.122,1}, panel={0.067,0.094,0.137,1},
    input={0.035,0.055,0.086,1}, border={0.153,0.208,0.286,1}, accent={0.310,0.831,1,1},
    text={0.906,0.937,0.980,1}, muted={0.533,0.620,0.729,1}, hover={0.102,0.165,0.235,1},
    warning={1,0.757,0.416,1}, success={0.412,0.863,0.702,1},
}

function T.Surface(frame, color)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    frame:SetBackdropColor(unpack(T.colors[color or "panel"]))
    frame:SetBackdropBorderColor(unpack(T.colors.border))
end

function T.Panel(parent,x,y,width,height,color)
    local frame=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    frame:SetPoint("TOPLEFT",x,y); frame:SetSize(width,height); T.Surface(frame,color)
    return frame
end

function T.Label(parent,text,x,y,width,style)
    local font=style=="title" and "GameFontNormalLarge" or style=="small" and "GameFontHighlightSmall" or "GameFontHighlight"
    local label=parent:CreateFontString(nil,"OVERLAY",font)
    label:SetPoint("TOPLEFT",x,y); label:SetWidth(width or 540); label:SetHeight(style=="title" and 28 or 22)
    label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
    label:SetTextColor(unpack(T.colors[(style=="muted" or style=="small") and "muted" or "text"]))
    label:SetText(text)
    return label
end

function T.Button(parent,text,width,x,y,action,style)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(width,34); T.Surface(b,style=="primary" and "accent" or "panel")
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    b.caption:SetPoint("CENTER"); b.caption:SetWidth(width-12); b.caption:SetHeight(20)
    b.caption:SetWordWrap(false); b.caption:SetJustifyH("CENTER")
    b.themeEnabled=true; b.themeStyle=style
    local nativeEnabled=b.SetEnabled
    function b:Paint(hover)
        local color=self.themeSelected and "hover" or self.themeStyle=="primary" and "accent" or hover and "hover" or "panel"
        self:SetBackdropColor(unpack(T.colors[color]))
        self:SetBackdropBorderColor(unpack(T.colors[self.themeSelected and "accent" or "border"]))
        if not self.themeEnabled then self.caption:SetTextColor(unpack(T.colors.muted))
        elseif self.themeStyle=="primary" then self.caption:SetTextColor(0.035,0.063,0.086,1)
        else self.caption:SetTextColor(unpack(T.colors.text)) end
    end
    function b:SetText(value) self.caption:SetText(value) end
    function b:GetText() return self.caption:GetText() end
    function b:SetEnabled(enabled) nativeEnabled(self,enabled); self.themeEnabled=enabled and true or false; self:Paint() end
    function b:SetSelected(selected) self.themeSelected=selected; self:Paint() end
    b:SetScript("OnEnter",function(self) self:Paint(true) end)
    b:SetScript("OnLeave",function(self) self:Paint(false) end)
    b:SetScript("OnClick",action)
    b:SetText(text); b:Paint()
    return b
end

function T.SpellName(spellID)
    local info=C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    local name=NR.Public(info) and type(info)=="table" and info.name
    if NR.Public(name) and type(name)=="string" then return name end
    return "技能 "..spellID
end

function T.Edit(parent,width,x,y)
    local f=CreateFrame("EditBox",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",x,y); f:SetSize(width,34); T.Surface(f,"input")
    f:SetFontObject(GameFontHighlight); f:SetTextColor(unpack(T.colors.text)); f:SetTextInsets(10,10,5,5)
    f:SetAutoFocus(false); f:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    return f
end

function T.Check(parent,text,x,y)
    local f=CreateFrame("CheckButton",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",x,y); f:SetSize(24,24); T.Surface(f,"input")
    local mark=f:CreateTexture(nil,"ARTWORK")
    mark:SetSize(12,12); mark:SetPoint("CENTER"); mark:SetColorTexture(unpack(T.colors.accent))
    f:SetCheckedTexture(mark)
    f.text=T.Label(f,text,36,-2,330)
    return f
end

function T.Scroll(parent,x,y,width,height)
    local scroll=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",x,y); scroll:SetSize(width,height)
    local bar=scroll.ScrollBar
    if type(bar)=="table" and bar.SetThumbTexture then
        bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        local thumb=bar:GetThumbTexture()
        if thumb then thumb:SetVertexColor(unpack(T.colors.border)) end
    end
    return scroll
end

function T.Window(name,width,height,title,subtitle)
    local frame=CreateFrame("Frame",name,UIParent,"BackdropTemplate")
    frame:SetSize(width,height); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); T.Surface(frame,"window")
    frame:SetScale(math.min(1,math.max(0.4,math.min((UIParent:GetHeight()-40)/height,(UIParent:GetWidth()-40)/width))))
    local header=T.Panel(frame,0,0,width,58,"header")
    T.Label(header,title,24,-15,width-90,"title")
    if subtitle then T.Label(frame,subtitle,24,-70,width-48,"muted") end
    T.Button(header,"×",34,width-48,-12,function() frame:Hide() end)
    frame:SetMovable(true); header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() if not InCombatLockdown() then frame:StartMoving() end end)
    header:SetScript("OnDragStop",function() frame:StopMovingOrSizing() end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=name end
    return frame
end
