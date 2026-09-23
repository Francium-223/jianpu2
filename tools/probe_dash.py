# -*- coding: utf-8 -*-
"""探针: 延音杠 `-` 为什么被读成重复音?

做法: 在 GT 图上转一遍, 把 token 与其切块坐标对齐, 找出"GT 是 `-` 而输出是数字"的位置,
把那一带的 块坐标 + 原始图像局部 都导出来看。

用法: py -3.13 tools/probe_dash.py [曲名] [区间起] [区间长]
"""
import os
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import jp_transcribe as JP
from eval_gt import load_gt
from PIL import Image

NAME = sys.argv[1] if len(sys.argv) > 1 else "兄弟抱一下"
I0 = int(sys.argv[2]) if len(sys.argv) > 2 else 8
N = int(sys.argv[3]) if len(sys.argv) > 3 else 10

out_png = "train-work/gt_eval/_probe.png"
toks, meta = JP.render(f"train-work/gt/{NAME}.jpg", out_png)
GT = load_gt(f"train-work/gt/{NAME}.txt")

print(f"{NAME}: 输出 {len(toks)} token  GT {len(GT)} token")
print(f"\n输出 token[{I0}:{I0+N}] 及其切块:")
print(f"{'i':>4} {'tok':>8} {'btype':>6} {'band':>10} {'x0':>5}{'x1':>5} {'ny0':>5}{'y1':>5}  宽x高")
for i in range(I0, min(I0 + N, len(toks))):
    m = meta[i]
    ay0 = int(m.get("s")) + int(m.get("ny0"))      # render 的口径: 绝对 y = s + ny0 (见 render 里画框那行)
    ay1 = int(m.get("s")) + int(m.get("y1"))
    print(f"{i:>4} {str(toks[i]):>8} {str(m.get('btype')):>6} "
          f"{str(m.get('s'))+'-'+str(m.get('e')):>10} "
          f"{m.get('x0'):>5}{m.get('x1'):>5} {ay0:>5}{ay1:>5}  "
          f"{int(m.get('x1',0))-int(m.get('x0',0))}x{ay1-ay0}")

print(f"\nGT 前 40 token: {' '.join(GT[:40])}")

# 导出该区间的原始图像局部(按坐标)
xs = [meta[i]["x0"] for i in range(I0, min(I0 + N, len(toks)))]
xe = [meta[i]["x1"] for i in range(I0, min(I0 + N, len(toks)))]
ys = [int(meta[i]["s"]) + int(meta[i]["ny0"]) for i in range(I0, min(I0 + N, len(toks)))]
ye = [int(meta[i]["s"]) + int(meta[i]["y1"]) for i in range(I0, min(I0 + N, len(toks)))]
im = Image.open(f"train-work/gt/{NAME}.jpg").convert("L")
pad = 12
box = (max(0, min(xs) - pad), max(0, min(ys) - pad),
       min(im.width, max(xe) + pad), min(im.height, max(ye) + pad))
crop = im.crop(box)
z = 4
crop = crop.resize((crop.width * z, crop.height * z), Image.LANCZOS)
f = "train-work/gt_eval/_probe_局部.png"
crop.save(f)
print(f"\n局部图已存 {f}  box={box}  放大 {z}x  -> {crop.size}")
print("（从上到下依次是这 10 个 token 所在的行带；看 `-` 那格到底长什么样）")
