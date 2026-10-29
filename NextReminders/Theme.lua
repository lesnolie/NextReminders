local _, NR = ...
NR.Theme = {}
local T = NR.Theme
-- Light dashboard look: grey canvas, white rounded cards with soft shadows, ink text, lime for the main action.
T.colors = {
    window={0.929,0.941,0.953,1}, header={1,1,1,1}, panel={1,1,1,1}, soft={0.965,0.969,0.976,1},
    input={0.957,0.965,0.973,1}, border={0.886,0.898,0.914,1}, accent={0.776,0.945,0.290,1},
    ink={0.082,0.094,0.110,1}, text={0.067,0.078,0.094,1}, muted={0.471,0.506,0.553,1},
    hover={0.918,0.929,0.941,1}, positive={0.243,0.553,0.075,1}, warning={0.871,0.451,0.067,1},
    success={0.196,0.639,0.310,1}, white={1,1,1,1}, track={0.847,0.863,0.882,1},
}
local MEDIA = "Interface\\AddOns\\NextReminders\\Media\\"
T.media = MEDIA
local FONT = STANDARD_TEXT_FONT or "Fonts\\ARKai_T.ttf"
local SIZES = { display=28, title=24, heading=15, body=13, small=12, muted=13, tiny=11 }

local function color(name) return T.colors[name] or name end

-- Draw textures at fractional positions without snapping, so scaled edges stay smooth instead of stair-stepped.
local function smooth(tex)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    return tex
end
T.Smooth = smooth

-- Rounded squares exist for these radii (tools/make_ui_textures.py), each drawn at 2x so the client only halves them.
local RADII = {2,3,11,12,13,14,15,16,17,18,19,20,21,22,23,24,27,28,35,36}
local function roundFile(radius)
    local best = RADII[1]
    for _, r in ipairs(RADII) do if math.abs(r - radius) < math.abs(best - radius) then best = r end end
    local size = 8
    while size < 4 * best do size = size * 2 end
    return "ui_round_" .. best .. ".tga", 2 * best / size
end
T.RoundFile = roundFile

-- Smallest circle texture at least 1.4x the drawn size.
function T.CircleFile(size)
    for _, n in ipairs({32,64,128}) do if n >= size * 1.4 then return "ui_circle_" .. n .. ".tga" end end
    return "ui_circle_128.tga"
end

-- Nine textures cut from one square source: corners keep their shape (radius `corner`), edges and centre stretch.
-- `outset` grows the shape past the frame (shadows); `margin` is the corner share of the source texture.
function T.Slice(frame,file,corner,outset,layer,sublevel,margin)
    local m,o,c=margin or 0.25,outset or 0,corner
    local s={}
    local cut={tl={0,m,0,m},tr={1-m,1,0,m},bl={0,m,1-m,1},br={1-m,1,1-m,1},t={m,1-m,0,m},b={m,1-m,1-m,1},l={0,m,m,1-m},r={1-m,1,m,1-m},c={m,1-m,m,1-m}}
    for key,coords in pairs(cut) do
        local tex=smooth(frame:CreateTexture(nil,layer or "BACKGROUND",nil,sublevel or 0))
        tex:SetTexture(MEDIA..file); tex:SetTexCoord(unpack(coords)); s[key]=tex
    end
    s.tl:SetPoint("TOPLEFT",frame,"TOPLEFT",-o,o); s.tl:SetSize(c,c)
    s.tr:SetPoint("TOPRIGHT",frame,"TOPRIGHT",o,o); s.tr:SetSize(c,c)
    s.bl:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",-o,-o); s.bl:SetSize(c,c)
    s.br:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",o,-o); s.br:SetSize(c,c)
    s.t:SetPoint("TOPLEFT",s.tl,"TOPRIGHT"); s.t:SetPoint("BOTTOMRIGHT",s.tr,"BOTTOMLEFT")
    s.b:SetPoint("TOPLEFT",s.bl,"TOPRIGHT"); s.b:SetPoint("BOTTOMRIGHT",s.br,"BOTTOMLEFT")
    s.l:SetPoint("TOPLEFT",s.tl,"BOTTOMLEFT"); s.l:SetPoint("BOTTOMRIGHT",s.bl,"TOPRIGHT")
    s.r:SetPoint("TOPLEFT",s.tr,"BOTTOMLEFT"); s.r:SetPoint("BOTTOMRIGHT",s.br,"TOPRIGHT")
    s.c:SetPoint("TOPLEFT",s.tl,"BOTTOMRIGHT"); s.c:SetPoint("BOTTOMRIGHT",s.br,"TOPLEFT")
    function s:SetColor(r,g,b,a) for _,tex in pairs(self) do if type(tex)=="table" then tex:SetVertexColor(r,g,b,a or 1) end end end
    return s
end

-- Rounded fill with a 1px border (and an optional soft shadow). Colors are names from T.colors or {r,g,b,a}.
function T.Surface(frame,fill,opts)
    opts=opts or {}
    local radius=opts.radius or 16
    if opts.shadow then
        -- The source shadow sits 64 texels inside a 96-texel corner, so the outset is two thirds of the corner.
        local corner=radius+12
        frame.nrShadow=T.Slice(frame,"ui_shadow.tga",corner,corner*2/3,"BACKGROUND",-8,0.375)
        frame.nrShadow:SetColor(0.08,0.1,0.14,opts.shadowAlpha or 0.10)
    end
    local file,margin=roundFile(radius)
    frame.nrBorder=T.Slice(frame,file,radius,0,"BACKGROUND",-6,margin)
    file,margin=roundFile(radius-1)
    frame.nrFill=T.Slice(frame,file,radius-1,-1,"BACKGROUND",-5,margin)
    T.Paint(frame,fill or "panel",opts.border or "border")
end

function T.Paint(frame,fill,border)
    if fill then frame.fillColor=color(fill); frame.nrFill:SetColor(unpack(frame.fillColor)) end
    if border then frame.borderColor=color(border); frame.nrBorder:SetColor(unpack(frame.borderColor)) end
end

function T.Panel(parent,x,y,width,height,fill,opts)
    local frame=CreateFrame("Frame",nil,parent)
    frame:SetPoint("TOPLEFT",x,y); frame:SetSize(width,height)
    frame.isSurface=true
    opts=opts or {}
    if opts.shadow==nil then opts.shadow=(fill or "panel")=="panel" end
    T.Surface(frame,fill or "panel",opts)
    return frame
end

function T.Font(fontString,style)
    local size=SIZES[style] or SIZES.body
    if fontString.SetFont then fontString:SetFont(FONT,size,"") end
    if fontString.SetShadowOffset then fontString:SetShadowOffset(0,0) end
end

function T.Label(parent,text,x,y,width,style)
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    T.Font(label,style)
    local heights={display=36,title=32,heading=22}
    label:SetPoint("TOPLEFT",x,y); label:SetWidth(width or 540); label:SetHeight(heights[style] or 20)
    label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
    label:SetTextColor(unpack(T.colors[(style=="muted" or style=="small" or style=="tiny") and "muted" or "text"]))
    label:SetText(text)
    return label
end

function T.Icon(parent,name,size,layer)
    local icon=smooth(parent:CreateTexture(nil,layer or "ARTWORK"))
    icon:SetTexture(MEDIA.."ui_icon_"..name..".tga"); icon:SetSize(size,size)
    return icon
end

-- Pill buttons. style: nil outline, "primary" lime, "dark" ink, "field" input-like with a dropdown chevron.
-- Selected (tabs) paints ink with white text.
local PAINT = {
    primary={fill="accent",hover={0.729,0.906,0.235,1},border="accent",text="ink"},
    dark={fill="ink",hover={0.2,0.216,0.235,1},border="ink",text="white"},
    field={fill="input",hover="hover",border="border",text="text"},
    outline={fill="panel",hover="hover",border="border",text="text"},
    ghost={fill="panel",hover="hover",border="panel",text="muted"},
}
function T.Button(parent,text,width,x,y,action,style,icon)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",x,y); b:SetSize(width,36)
    T.Surface(b,"panel",{radius=18})
    b.caption=b:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    T.Font(b.caption,"body")
    b.caption:SetHeight(20); b.caption:SetWordWrap(false)
    -- Explicit false (not nil) so optional parts read the same everywhere.
    b.nrIcon=icon and T.Icon(b,icon,16,"OVERLAY") or false
    b.nrChevron=style=="field" and T.Icon(b,"chevron",16,"OVERLAY") or false
    if b.nrChevron then b.nrChevron:SetPoint("RIGHT",-14,0) end
    -- Icon and text are centred together as one group; fields keep left-aligned text.
    function b:Layout()
        local w=self:GetWidth()
        self.caption:ClearAllPoints()
        if self.themeStyle=="field" then
            self.caption:SetPoint("LEFT",16,0); self.caption:SetWidth(w-52); self.caption:SetJustifyH("LEFT")
        elseif self.nrIcon then
            local measured=self.caption:GetStringWidth()
            local text=self.caption:GetText() or ""
            local textWidth=NR.Number(measured,1,2000) and measured or select(2,text:gsub("[^\128-\191]",""))*13
            textWidth=math.min(textWidth,w-54)
            local left=math.floor((w-(textWidth+24))/2+0.5)
            self.nrIcon:ClearAllPoints(); self.nrIcon:SetPoint("LEFT",left,0)
            self.caption:SetPoint("LEFT",left+24,0); self.caption:SetWidth(textWidth+2); self.caption:SetJustifyH("LEFT")
        else
            self.caption:SetPoint("CENTER"); self.caption:SetWidth(w-24); self.caption:SetJustifyH("CENTER")
        end
    end
    b.themeEnabled,b.themeSelected,b.themeStyle=true,false,style
    local nativeEnabled,nativeHeight=b.SetEnabled,b.SetHeight
    function b:Paint(hover)
        local p=PAINT[self.themeStyle or "outline"] or PAINT.outline
        local fill,border,ink=p.fill,p.border,p.text
        if self.themeSelected then fill,border,ink="ink","ink","white"
        elseif hover and self.themeEnabled then fill=p.hover end
        T.Paint(self,fill,border)
        local textColor=self.themeEnabled and color(ink) or T.colors.muted
        self.caption:SetTextColor(unpack(textColor))
        if self.nrIcon then self.nrIcon:SetVertexColor(unpack(textColor)) end
        if self.nrChevron then self.nrChevron:SetVertexColor(unpack(T.colors.muted)) end
        if not self.themeEnabled then self:SetAlpha(0.55) else self:SetAlpha(1) end
    end
    function b:SetText(value) self.caption:SetText(value); if self.Layout then self:Layout() end end
    function b:GetText() return self.caption:GetText() end
    function b:SetEnabled(enabled) nativeEnabled(self,enabled); self.themeEnabled=enabled and true or false; self:Paint() end
    function b:SetSelected(selected) self.themeSelected=selected; self:Paint() end
    function b:SetHeight(height) nativeHeight(self,height) end
    b:SetScript("OnEnter",function(self) self:Paint(true) end)
    b:SetScript("OnLeave",function(self) self:Paint(false) end)
    b:SetScript("OnClick",action)
    b:SetText(text); b:Paint()
    return b
end

-- One whole circle texture (not nine pieces) so the outline stays round; SetColor matches the Slice interface.
local function disc(frame,size,inset,sublevel)
    local tex=smooth(frame:CreateTexture(nil,"BACKGROUND",nil,sublevel))
    tex:SetTexture(MEDIA..T.CircleFile(size)); tex:SetPoint("TOPLEFT",inset,-inset); tex:SetPoint("BOTTOMRIGHT",-inset,inset)
    return {tex=tex,SetColor=function(self,r,g,b,a) self.tex:SetVertexColor(r,g,b,a or 1) end}
end

-- Round icon button (side rail, close). Selected: lime disc with an ink icon.
function T.IconButton(parent,icon,size,x,y,action,tooltip)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",x,y); b:SetSize(size,size)
    b.nrBorder=disc(b,size,0,-6); b.nrFill=disc(b,size,1,-5)
    b.icon=T.Icon(b,icon,16,"OVERLAY"); b.icon:SetPoint("CENTER")
    b.themeSelected=false
    function b:Paint(hover)
        if self.themeSelected then T.Paint(self,"accent","accent"); self.icon:SetVertexColor(unpack(T.colors.ink))
        else T.Paint(self,hover and "hover" or "panel",hover and "hover" or "border"); self.icon:SetVertexColor(unpack(T.colors.text)) end
    end
    function b:SetSelected(selected) self.themeSelected=selected; self:Paint() end
    b:SetScript("OnEnter",function(self)
        self:Paint(true)
        if tooltip and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(tooltip); GameTooltip:Show() end
    end)
    b:SetScript("OnLeave",function(self) self:Paint(false); if tooltip and GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnClick",action)
    b:Paint()
    return b
end

function T.SpellName(spellID)
    local info=C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
    local name=NR.Public(info) and type(info)=="table" and info.name
    if NR.Public(name) and type(name)=="string" then return name end
    return "技能 "..spellID
end

-- style "number": a large figure, for the timing cards.
function T.Edit(parent,width,x,y,style)
    local f=CreateFrame("EditBox",nil,parent)
    local big=style=="number"
    f:SetPoint("TOPLEFT",x,y); f:SetSize(width,big and 48 or 36)
    T.Surface(f,"input",{radius=big and 14 or 12})
    f:SetFontObject(GameFontHighlight); T.Font(f,big and "display" or "body")
    f:SetTextColor(unpack(T.colors.text)); f:SetTextInsets(big and 14 or 12,12,4,4)
    f:SetAutoFocus(false); f:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    f:HookScript("OnEditFocusGained",function(self) T.Paint(self,"panel","ink") end)
    f:HookScript("OnEditFocusLost",function(self) T.Paint(self,"input","border") end)
    return f
end

-- Toggle switch with a label. Keeps the CheckButton interface (SetChecked/GetChecked).
function T.Check(parent,text,x,y)
    local f=CreateFrame("CheckButton",nil,parent)
    f:SetPoint("TOPLEFT",x,y); f:SetSize(40,24)
    local file,margin=roundFile(12)
    f.track=T.Slice(f,file,12,0,"ARTWORK",0,margin)
    f.knob=smooth(f:CreateTexture(nil,"OVERLAY")); f.knob:SetTexture(MEDIA..T.CircleFile(18)); f.knob:SetSize(18,18)
    f.text=T.Label(f,text,52,-2,330)
    local native=f.SetChecked
    function f:Paint()
        local on=self:GetChecked() and true or false
        self.track:SetColor(unpack(T.colors[on and "accent" or "track"]))
        self.knob:SetVertexColor(unpack(T.colors.white))
        self.knob:ClearAllPoints(); self.knob:SetPoint("LEFT",on and 19 or 3,0)
    end
    function f:SetChecked(value) native(self,value); self:Paint() end
    f:SetScript("OnClick",function(self) self:Paint() end)
    f:Paint()
    return f
end

function T.Scroll(parent,x,y,width,height)
    local scroll=CreateFrame("ScrollFrame",nil,parent,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",x,y); scroll:SetSize(width,height)
    local bar=scroll.ScrollBar
    if type(bar)=="table" and bar.SetThumbTexture then
        bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
        local thumb=bar:GetThumbTexture()
        if thumb then thumb:SetVertexColor(unpack(T.colors.track)); thumb:SetWidth(6) end
        for _,key in ipairs({"ScrollUpButton","ScrollDownButton"}) do if bar[key] then bar[key]:SetAlpha(0) end end
    end
    return scroll
end

-- Window: grey rounded canvas, brand at top left, round close button at top right, drag anywhere on the top strip.
function T.Window(name,width,height,title,subtitle)
    local frame=CreateFrame("Frame",name,UIParent)
    frame:SetSize(width,height); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG"); frame:EnableMouse(true)
    T.Surface(frame,"window",{radius=28,shadow=true,shadowAlpha=0.35,border="border"})
    frame:SetScale(math.min(1,math.max(0.4,math.min((UIParent:GetHeight()-40)/height,(UIParent:GetWidth()-40)/width))))
    local header=CreateFrame("Frame",nil,frame)
    header:SetPoint("TOPLEFT",0,0); header:SetSize(width,72)
    frame.header=header
    frame.brand=T.Label(header,title,24,-24,width-140,"title")
    if subtitle then T.Label(frame,subtitle,24,-70,width-48,"muted") end
    frame.close=T.IconButton(header,"close",40,width-60,-18,function() frame:Hide() end,"关闭")
    frame:SetMovable(true); frame:SetClampedToScreen(true); header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart",function() if not InCombatLockdown() then frame:StartMoving() end end)
    header:SetScript("OnDragStop",function() frame:StopMovingOrSizing() end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]=name end
    return frame
end

-- Put `frame` where `source` is, so moving between same-sized windows doesn't make the panel jump.
function T.Follow(frame,source)
    local x,y=source:GetCenter()
    if not (NR.Number(x,-100000,100000) and NR.Number(y,-100000,100000)) then return end
    frame:ClearAllPoints(); frame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x,y)
end

-- Small status tag pinned by its top right corner (e.g. "即时保存", "检查通过").
function T.Pill(parent,x,y)
    local pill=CreateFrame("Frame",nil,parent)
    pill:SetPoint("TOPRIGHT",x,y); pill:SetSize(80,26)
    T.Surface(pill,"soft",{radius=13,border="soft"})
    pill.text=T.Label(pill,"",0,-6,200,"tiny"); pill.text:ClearAllPoints(); pill.text:SetPoint("CENTER")
    pill.text:SetHeight(14); pill.text:SetJustifyH("CENTER")
    function pill:SetText(value,tone)
        self.text:SetText(value)
        local measured=self.text:GetStringWidth()
        local width=NR.Number(measured,1,1000) and measured or select(2,value:gsub("[^\128-\191]",""))*11
        self.text:SetWidth(width+4); self:SetWidth(width+28)
        self.text:SetTextColor(unpack(T.colors[tone or "muted"]))
    end
    return pill
end

-- Light dropdown list beside a field button (below it, or above when `above`). One shared frame; items are {key,name};
-- onPick(item) runs on a click.
-- Closes on a pick, on a click anywhere else, or when its window hides.
local MENU_ROW = 28
function T.Menu(owner,items,current,onPick,above)
    local menu=T.menuFrame
    if not menu then
        menu=CreateFrame("Frame",nil,UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetToplevel(true); menu:EnableMouse(true)
        T.Surface(menu,"panel",{radius=14,shadow=true,shadowAlpha=0.18})
        menu.rows={}
        menu:RegisterEvent("GLOBAL_MOUSE_DOWN")
        menu:SetScript("OnEvent",function(self)
            if self:IsShown() and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
        end)
        T.menuFrame=menu
    end
    if menu:IsShown() and menu.owner==owner then menu:Hide(); return menu end
    menu.owner=owner
    menu:SetParent(owner:GetParent() or UIParent); menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:ClearAllPoints()
    if above then menu:SetPoint("BOTTOMLEFT",owner,"TOPLEFT",0,6) else menu:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-6) end
    menu:SetSize(owner:GetWidth(),#items*MENU_ROW+12)
    for index,item in ipairs(items) do
        local row=menu.rows[index]
        if not row then
            row=CreateFrame("Button",nil,menu)
            row:SetHeight(MENU_ROW)
            row.hover=row:CreateTexture(nil,"BACKGROUND"); row.hover:SetAllPoints(); row.hover:SetColorTexture(unpack(T.colors.hover)); row.hover:Hide()
            row.mark=T.Icon(row,"check",14,"OVERLAY"); row.mark:SetPoint("RIGHT",-14,0); row.mark:SetVertexColor(unpack(T.colors.positive))
            row.caption=row:CreateFontString(nil,"OVERLAY","GameFontHighlight"); T.Font(row.caption,"body")
            row.caption:SetPoint("LEFT",14,0); row.caption:SetPoint("RIGHT",-36,0); row.caption:SetJustifyH("LEFT"); row.caption:SetWordWrap(false)
            row:SetScript("OnEnter",function(self) self.hover:Show() end)
            row:SetScript("OnLeave",function(self) self.hover:Hide() end)
            row:SetScript("OnClick",function(self) menu:Hide(); if menu.onPick then menu.onPick(self.item) end end)
            menu.rows[index]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",menu,"TOPLEFT",6,-6-(index-1)*MENU_ROW); row:SetPoint("RIGHT",menu,"RIGHT",-6,0)
        row.item=item
        row.caption:SetText(item.name)
        local selected=item.key==current
        row.caption:SetTextColor(unpack(T.colors[selected and "text" or "muted"]))
        if selected then row.mark:Show() else row.mark:Hide() end
        row:Show()
    end
    for index=#items+1,#menu.rows do menu.rows[index]:Hide() end
    menu.onPick=onPick
    menu:Show()
    return menu
end
