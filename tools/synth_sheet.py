# -*- coding: utf-8 -*-
"""PIL 简谱渲染器: 画整页简谱(数字+时值下划线+低/高八度点+附点+小节线+多行),
并精确记录每个音符的 bounding box. 用于生成'切分检测'训练数据(图+精确框GT).
"""
import os, sys, json, random
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from PIL import Image, ImageDraw, ImageFont

# 字体: 用系统等宽/默认, 能画数字即可
def _font(size):
    for p in ["C:/Windows/Fonts/consola.ttf","C:/Windows/Fonts/arial.ttf"]:
        try: return ImageFont.truetype(p, size)
        except Exception: pass
    return ImageFont.load_default()

class SheetRenderer:
    def __init__(self, W=1000, H=600, digit_size=48, note_w=60, note_h=90):
        self.W=W; self.H=H
        self.digit_size=digit_size; self.note_w=note_w; self.note_h=note_h
        self.font=_font(digit_size); self.small=_font(int(digit_size*0.5))
        self.img=Image.new("RGB",(W,H),"white"); self.d=ImageDraw.Draw(self.img)
        self.boxes=[]  # 每音符 [x0,y0,x1,y1]

    def draw_note(self, cx, cy, digit, beam=0, low=0, voice=0, dotted=0):
        """画一个音符在中心(cx,cy). beam=下划线条数(0/1/2); low=低八点; voice=高八点; dotted=附点.
        记录该音符的完整框(数字+符号). 返回框. """
        d=self.d; fs=self.digit_size
        # 数字
        tw,th=d.textbbox((0,0),digit,font=self.font)[2:4]  # 宽高
        dx0=cx-tw//2; dy0=cy-th//2
        d.text((dx0,dy0),digit,font=self.font,fill=(0,0,0))
        x0=dx0; y0=dy0; x1=dx0+tw; y1=dy0+th
        # 时值下划线(数字下方)
        for i in range(beam):
            ly=y1+4+i*5
            d.line([dx0-2,ly,dx0+tw+2,ly],fill=(0,0,0),width=3)
            y1=max(y1,ly+3)
        # 低八度点(数字正下方, 下划线下)
        for i in range(low):
            py=y1+6+i*6
            d.ellipse([cx-3,py,cx+3,py+6],fill=(0,0,0)); y1=max(y1,py+6)
        # 高八度点(数字正上方)
        for i in range(voice):
            py=y0-8-i*6
            d.ellipse([cx-3,py,cx+3,py+6],fill=(0,0,0)); y0=min(y0,py)
        # 附点(数字右侧)
        if dotted:
            d.ellipse([x1+3,dy0+th-8,x1+9,dy0+th-2],fill=(0,0,0)); x1=x1+9
        box=(int(x0-3),int(y0-3),int(x1+3),int(y1+3))
        self.boxes.append(box)
        return box

    def draw_barline(self, x, y0, y1):
        self.d.line([x,y0,x,y1],fill=(0,0,0),width=2)

    def render_row(self, notes, row_y, bar_every=4):
        """一行音符. notes=[(digit,beam,low,voice,dotted),...]; bar_every 每几个音画小节线."""
        cx=40
        self.draw_barline(cx, row_y-20, row_y+70)
        for i,(digit,beam,low,voice,dotted) in enumerate(notes):
            cx+=self.note_w//2
            self.draw_note(cx, row_y, digit, beam, low, voice, dotted)
            cx+=self.note_w//2
            if (i+1)%bar_every==0:
                cx+=15; self.draw_barline(cx, row_y-20, row_y+70); cx+=15
        self.draw_barline(cx, row_y-20, row_y+70)

    def save(self, out_png, out_json):
        self.img.save(out_png)
        json.dump({"boxes":self.boxes,"W":self.W,"H":self.H}, open(out_json,"w"))

def random_note(rng):
    d=str(rng.choice(["1","2","3","4","5","6","7"]))
    beam=rng.choice([0,0,0,1,1,2])          # 0/1/2 下划线
    low=rng.choice([0,0,0,1])               # 低八点 0/1
    voice=rng.choice([0,0,0,1])             # 高八点 0/1
    dotted=rng.choice([0,0,1])              # 附点
    return (d,beam,low,voice,dotted)

def gen_one(idx, outdir):
    rng=random.Random(idx)
    sr=SheetRenderer()
    rows=rng.randint(2,4)
    for r in range(rows):
        n=rng.randint(4,12)
        notes=[random_note(rng) for _ in range(n)]
        sr.render_row(notes, 70+r*150)
    png=f"{outdir}/sheet_{idx:04d}.png"; js=f"{outdir}/sheet_{idx:04d}.json"
    sr.save(png,js)
    return len(sr.boxes)

if __name__=="__main__":
    os.makedirs("train-work/synth_sheets",exist_ok=True)
    n=int(sys.argv[1]) if len(sys.argv)>1 else 10
    tot=0
    for i in range(n): tot+=gen_one(i,"train-work/synth_sheets")
    print(f"生成 {n} 张, 共 {tot} 音符框")
