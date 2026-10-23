"""Draw the addon's windows from the real Lua layout code, for checking layout without the game.

Runs Theme/UI/PreviewUI through the test mock, records every frame, texture and font string, then paints them
with Pillow at 2x. Rounded surfaces, icons and text are approximated from what the code set (colors, sizes,
anchors); the game's own font rendering and the exact nine-slice edges will differ slightly.
    python tools/render_ui.py [out_dir]
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
import check  # noqa: E402

MEDIA = ROOT / "NextReminders" / "Media"
SCALE = 2
FONT_FILE = "C:/Windows/Fonts/msyh.ttc"

RECORDER = r'''
local baseObject=object
function object()
 local o=baseObject()
 local mt=getmetatable(o)
 local index=mt.__index
 mt.__index=function(self,k)
  if k=="SetPoint" then return function(_,...) self.point={...}; local l=rawget(self,"points") or {}; l[#l+1]={...}; self.points=l end end
  if k=="ClearAllPoints" then return function() self.points={} end end
  if k=="SetAllPoints" then return function(_,rel) self.allPoints=rel or true end end
  if k=="Hide" then return function() local was=self.shown; self.shown=false; self.hidden=true; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end end
  if k=="Show" then return function() self.shown=true; self.hidden=false; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
  if k=="IsShown" then return function() return not rawget(self,"hidden") end end
  local f=index(self,k)
  local known={SetText=1,GetText=1,SetChecked=1,GetChecked=1,IsVisible=1,IsForbidden=1,GetHeight=1,GetWidth=1,SetSize=1,SetWidth=1,SetHeight=1,
   SetJustifyH=1,SetJustifyV=1,SetBlinkSpeed=1,EnableMouse=1,SetTextInsets=1,SetAutoFocus=1,HasFocus=1,SetFocus=1,ClearFocus=1,GetVerticalScroll=1,
   SetVerticalScroll=1,SetEnabled=1,SetAlpha=1,CreateTexture=1,CreateFontString=1,SetScript=1}
  if known[k] or k=="unit" or k=="displayedUnit" then return f end
  if k:match("^[A-Z]") then return function(_,...) self["_"..k]={...} end end
  return f
 end
 return o
end
'''


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)] if t else []


class Scene:
    def __init__(self, lua):
        self.lua = lua
        g = lua.globals()
        self.frames = lua_list(g.created)
        self.fonts = lua_list(g.fontStrings)
        self.rects = {}
        self.tostring = lua.eval("tostring")

    def get(self, obj, key):
        return self.lua.eval("rawget")(obj, key)

    def size(self, obj):
        return self.get(obj, "width") or 0, self.get(obj, "height") or 0

    def parent(self, obj):
        return self.get(obj, "parent") or self.get(obj, "owner")

    def rect(self, obj):
        key = self.tostring(obj)
        if key in self.rects:
            return self.rects[key]
        self.rects[key] = (0, 0, 0, 0)
        parent = self.parent(obj)
        prect = self.rect(parent) if parent is not None else (0, 0, 1040, 700)
        w, h = self.size(obj)
        if self.get(obj, "allPoints"):
            r = prect
        else:
            points = lua_list(self.get(obj, "points"))
            if not points:
                r = (prect[0], prect[1], w, h)
            else:
                p = lua_list(points[0])
                anchor = p[0]
                rel = prect
                rest = p[1:]
                if rest and not isinstance(rest[0], (int, float, str)):
                    rel = self.rect(rest[0])
                    rest = rest[1:]
                relpoint = anchor
                if rest and isinstance(rest[0], str):
                    relpoint, rest = rest[0], rest[1:]
                x = rest[0] if len(rest) > 0 else 0
                y = rest[1] if len(rest) > 1 else 0
                ax, ay = spot(rel, relpoint)
                ax, ay = ax + x, ay - y
                fx, fy = {"LEFT": (0, 0.5), "RIGHT": (1, 0.5), "CENTER": (0.5, 0.5), "TOP": (0.5, 0), "BOTTOM": (0.5, 1),
                          "TOPLEFT": (0, 0), "TOPRIGHT": (1, 0), "BOTTOMLEFT": (0, 1), "BOTTOMRIGHT": (1, 1)}[anchor]
                r = (ax - fx * w, ay - fy * h, w, h)
        self.rects[key] = r
        return r


def spot(r, point):
    x, y, w, h = r
    fx, fy = {"LEFT": (0, 0.5), "RIGHT": (1, 0.5), "CENTER": (0.5, 0.5), "TOP": (0.5, 0), "BOTTOM": (0.5, 1),
              "TOPLEFT": (0, 0), "TOPRIGHT": (1, 0), "BOTTOMLEFT": (0, 1), "BOTTOMRIGHT": (1, 1)}[point]
    return x + fx * w, y + fy * h


def rgba(c, alpha=1.0):
    c = lua_list(c) if c is not None and not isinstance(c, (list, tuple)) else (c or [1, 1, 1, 1])
    a = (c[3] if len(c) > 3 else 1) * alpha
    return tuple(int(round(v * 255)) for v in c[:3]) + (int(round(a * 255)),)


def visible(scene, obj):
    while obj is not None:
        if scene.get(obj, "hidden"):
            return False
        obj = scene.parent(obj)
    return True


def render(scene, root, path, canvas):
    W, H = canvas
    img = Image.new("RGBA", (W * SCALE, H * SCALE), (60, 66, 76, 255))
    ox, oy = 0, 0
    rx, ry, rw, rh = scene.rect(root)
    ox, oy = (W - rw) / 2 - rx, (H - rh) / 2 - ry

    def box(r):
        x, y, w, h = r
        return [(x + ox) * SCALE, (y + oy) * SCALE, (x + w + ox) * SCALE, (y + h + oy) * SCALE]

    children = {}
    for f in scene.frames:
        children.setdefault(scene.tostring(scene.parent(f)), []).append(f)
    textures = {}
    fontmap = {}
    for f in scene.fonts:
        fontmap.setdefault(scene.tostring(scene.get(f, "owner")), []).append(f)

    def piece_color(slice_tbl):
        tl = scene.get(slice_tbl, "tl")
        if tl is None:  # a whole-circle disc (round icon buttons)
            tex = scene.get(slice_tbl, "tex")
            c = scene.get(tex, "_SetVertexColor")
            return rgba(c) if c is not None else None, 999
        c = scene.get(tl, "_SetVertexColor")
        return rgba(c) if c is not None else None, scene.get(tl, "width") or 0

    def draw_surface(f):
        r = box(scene.rect(f))
        if r[2] - r[0] < 1 or r[3] - r[1] < 1:
            return
        alpha = (scene.get(f, "alpha") if scene.get(f, "alpha") is not None else 1)
        shadow = scene.get(f, "nrShadow")
        if shadow is not None:
            col, _ = piece_color(shadow)
            layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
            radius = (piece_color(scene.get(f, "nrBorder"))[1]) * SCALE
            ImageDraw.Draw(layer).rounded_rectangle([r[0], r[1] + 6 * SCALE, r[2], r[3] + 6 * SCALE], radius=radius, fill=col)
            img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(10 * SCALE)))
        for key, inset in (("nrBorder", 0), ("nrFill", 1)):
            s = scene.get(f, key)
            if s is None:
                continue
            col, corner = piece_color(s)
            if col is None:
                continue
            col = col[:3] + (int(col[3] * alpha),)
            rr = [r[0] + inset * SCALE, r[1] + inset * SCALE, r[2] - inset * SCALE, r[3] - inset * SCALE]
            layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
            radius = min(corner * SCALE, (rr[2] - rr[0]) / 2, (rr[3] - rr[1]) / 2)
            ImageDraw.Draw(layer).rounded_rectangle(rr, radius=max(0, radius), fill=col)
            img.alpha_composite(layer)
        track = scene.get(f, "track")
        if track is not None:
            col, corner = piece_color(track)
            ImageDraw.Draw(img).rounded_rectangle(r, radius=corner * SCALE, fill=col)

    def draw_texture(t):
        if scene.get(t, "hidden"):
            return
        tex = scene.get(t, "_SetTexture")
        color = scene.get(t, "_SetColorTexture")
        r = box(scene.rect(t))
        if r[2] - r[0] < 1 or r[3] - r[1] < 1:
            return
        if color is not None:
            ImageDraw.Draw(img).rectangle(r, fill=rgba(color))
            return
        if tex is None:
            return
        name = lua_list(tex)[0]
        if not isinstance(name, str):
            return
        if "NextReminders\\Media\\" in name:
            file = MEDIA / name.split("\\")[-1]
            if file.name.startswith("ui_round") or file.name == "ui_shadow.tga":
                return
            src = Image.open(file).convert("RGBA").resize((int(r[2] - r[0]), int(r[3] - r[1])), Image.LANCZOS)
            vc = scene.get(t, "_SetVertexColor")
            if vc is not None and file.name != "ui_logo.tga":
                c = rgba(vc)
                tint = Image.new("RGBA", src.size, c[:3] + (0,))
                tint.putalpha(src.getchannel("A").point(lambda a: a * c[3] // 255))
                src = tint
            img.alpha_composite(src, (int(r[0]), int(r[1])))
        else:
            ImageDraw.Draw(img).rounded_rectangle(r, radius=4 * SCALE, fill=(70, 110, 160, 255))

    def draw_font(fs):
        text = scene.get(fs, "text")
        if not text or scene.get(fs, "hidden") or not visible(scene, scene.get(fs, "owner")):
            return
        font = scene.get(fs, "_SetFont")
        size = lua_list(font)[1] if font is not None else 13
        col = rgba(scene.get(fs, "_SetTextColor") or [1, 1, 1, 1])
        x, y, w, h = scene.rect(fs)
        pil = ImageFont.truetype(FONT_FILE, int(size * SCALE))
        just = scene.get(fs, "justifyH") or "CENTER"
        d = ImageDraw.Draw(img)
        lines = []
        for para in str(text).split("\n"):
            line = ""
            for ch in para:
                if w and d.textlength(line + ch, font=pil) > w * SCALE and line:
                    lines.append(line)
                    line = ch
                else:
                    line += ch
            lines.append(line)
        lh = size * 1.35 * SCALE
        total = lh * len(lines)
        top = (y + oy) * SCALE
        if (scene.get(fs, "justifyV") or "MIDDLE") == "MIDDLE" and h:
            top += (h * SCALE - total) / 2
        for i, line in enumerate(lines):
            lw = d.textlength(line, font=pil)
            lx = (x + ox) * SCALE
            if just == "CENTER":
                lx += (w * SCALE - lw) / 2
            elif just == "RIGHT":
                lx += w * SCALE - lw
            d.text((lx, top + i * lh), line, font=pil, fill=col)

    def draw_edit_text(f):
        text = scene.get(f, "text")
        if not text or scene.get(f, "template") is not None:
            return
        font = scene.get(f, "_SetFont")
        if font is None:
            return
        size = lua_list(font)[1]
        x, y, w, h = scene.rect(f)
        pil = ImageFont.truetype(FONT_FILE, int(size * SCALE))
        inset = lua_list(scene.get(f, "textInsets") or [12])[0]
        top = scene.get(f, "justifyV") == "TOP"
        ImageDraw.Draw(img).multiline_text(((x + ox + inset) * SCALE, (y + oy + (inset if top else h / 2)) * SCALE), str(text),
                                           font=pil, fill=rgba(scene.get(f, "_SetTextColor") or [0, 0, 0, 1]),
                                           anchor="la" if top else "lm", spacing=6 * SCALE)

    owned = {}
    for t in scene.lua.eval("textures") and lua_list(scene.lua.globals().textures):
        owned.setdefault(scene.tostring(scene.get(t, "owner")), []).append(t)

    def walk(f):
        if not visible(scene, f):
            return
        draw_surface(f)
        for t in owned.get(scene.tostring(f), []):
            draw_texture(t)
        draw_edit_text(f)
        for fs in fontmap.get(scene.tostring(f), []):
            draw_font(fs)
        for c in children.get(scene.tostring(f), []):
            walk(c)

    walk(root)
    img.save(path)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "docs"
    from lupa.lua51 import LuaRuntime
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(check.MOCK)
    lua.execute(RECORDER)
    lua.execute('''textures={}
local baseObject=object
function object()
 local o=baseObject(); local mt=getmetatable(o); local index=mt.__index
 mt.__index=function(self,k)
  if k=="CreateTexture" then return function() local t=object(); t.owner=self; textures[#textures+1]=t; return t end end
  return index(self,k)
 end
 return o
end
STANDARD_TEXT_FONT="Fonts\\\\ARKai_T.ttf"''')
    nr = lua.table()
    names = ["Core.lua", "SpellCatalog.lua", "Theme.lua", "BossData.lua", "DungeonData.lua", "Import.lua", "EventPlans.lua",
             "BossEvents.lua", "Ready.lua", "Engine.lua", "Preview.lua", "Sounds.lua", "Display.lua", "PreviewUI.lua", "UI.lua", "Main.lua"]
    for name in names:
        lua.execute("return assert(loadstring(...))", (ROOT / "NextReminders" / name).read_text(encoding="utf-8"))("NextReminders", nr)
    lua.globals().NR = nr
    lua.execute('''created[1].scripts.OnEvent(created[1],"ADDON_LOADED","NextReminders")
NR.db.settings=NR.Settings({sound=true,tts=true,countdown=true,hideOnUse=true,glow="player"})''')
    ui = nr.UI
    lua.execute('NR.UI.frame:Show(); NR.UI:SetPage("import")')
    scene = Scene(lua)
    render(scene, ui.frame, out / "ui-import.png", (1100, 760))
    lua.execute('''local text="EncounterID:3492;Difficulty:Heroic;\\nph:1;time:10;spellid:51271;\\nph:2;time:3;spellid:51271;"
NR.UI.note:SetText(text);NR.UI.note.scripts.OnTextChanged(NR.UI.note);NR.UI:Parse()''')
    scene = Scene(lua)
    render(scene, ui.frame, out / "ui-import-checked.png", (1100, 760))
    lua.execute('NR.UI:SetPage("settings"); NR.UI:Refresh()')
    scene = Scene(lua)
    render(scene, ui.frame, out / "ui-settings.png", (1100, 760))
    lua.execute('''local pick=NR.UI.soundPicks.soundChoice;pick.scripts.OnClick(pick)
NR.Theme.menuFrame.parent=NR.UI.frame  -- in game its strata puts it above every card''')
    scene = Scene(lua)
    render(scene, ui.frame, out / "ui-settings-menu.png", (1100, 760))
    lua.execute("NR.Theme.menuFrame:Hide()")
    lua.execute('''local plan=NR.ParseNote("EncounterID:3492;Difficulty:Heroic;\\nph:1;time:5;spellid:51271;\\nph:1;time:40;spellid:47568;\\nph:1;time:95;spellid:51271;")
assert(NR.PreviewUI:Open(plan)); now=8; NR.preview:Tick(8); NR.PreviewUI.lastUpdate=nil; NR.PreviewUI:Update()''')
    scene = Scene(lua)
    render(scene, nr.PreviewUI.frame, out / "ui-playback.png", (1100, 720))
    print("rendered to", out)


if __name__ == "__main__":
    main()
