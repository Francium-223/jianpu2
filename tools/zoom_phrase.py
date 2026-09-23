# -*- coding: utf-8 -*-
"""放大"某个乐句所在的那一行": 调真 render(会加载模型)拿 meta 的行带坐标, 再裁剪标注图。
用法: py tools/zoom_phrase.py <页面图> <短语音高串> [输出png] [上下留白px]
例:   py tools/zoom_phrase.py images-prep/jianpucn-pop/浮夸__jianpucn-133666/001.jpg 1117637
"""
import os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import jp_transcribe as JP
from PIL import Image

page = sys.argv[1]
phrase = sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else "train-work/_zoom.png"
pad = int(sys.argv[4]) if len(sys.argv) > 4 else 22
TMP = "train-work/_zoom_annot.png"

toks, meta = JP.render(page, TMP)
# **必须用 meta 建串**, 不能拿 toks 建 —— 弧线 '~'/')' 只 extend 进 toks、不进 meta,
# 用 toks 的下标去索引 meta 会整体错位(实测裁出 x1<x0 直接崩)。
clean = []
for m in meta:
    mm = re.match(r"^[qsdh]*[,']*([0-9x])", m["tok"])
    clean.append(mm.group(1) if mm else "?")
d = "".join(c for c in clean if c not in "0x")
keep = [i for i, c in enumerate(clean) if c not in "0x"]
pos = d.find(phrase)
print(f"token {len(toks)}  meta {len(meta)}   短语 {phrase} " + (f"在位置 {pos}" if pos >= 0 else "没找到"))
if pos < 0:
    sys.exit(1)
i0, i1 = keep[pos], keep[pos + len(phrase) - 1]
b0, b1 = meta[i0], meta[i1]
bands = sorted({meta[k]["band"] for k in keep[pos:pos + len(phrase)]})
print(f"该句落在行带 {bands}  "
      f"(句首 x={b0['x0']} 行 {b0['band']}, 句尾 x={b1['x1']} 行 {b1['band']})")
print("识别结果:", " ".join(m["tok"] for m in meta[max(0, i0 - 3):i1 + 6]))

im = Image.open(TMP).convert("RGB")
# **乐句可能跨换行** —— 只按单行裁会得到 x1<x0 直接崩(实测《浮夸》这句就是从上一行末尾
# 接到下一行开头)。所以按"涉及到的所有行带"裁整条(整幅宽度), 保证句首句尾都在图里。
top = min(bands)
bot = max(meta[k]["s"] + meta[k]["y1"] for k in keep[pos:pos + len(phrase)])
x0, x1 = 0, im.width
y0 = max(0, top - pad)
y1 = min(im.height, bot + pad)
c = im.crop((x0, y0, x1, y1))
sc = max(1.0, min(3.0, 1600.0 / max(1, c.width)))
c = c.resize((int(c.width * sc), int(c.height * sc)), Image.LANCZOS)
c.save(out)
print(f"裁剪 ({x0},{y0})-({x1},{y1}) 放大 {sc:.1f}x -> {out}  {c.size}")
