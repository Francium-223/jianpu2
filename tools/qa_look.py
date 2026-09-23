# -*- coding: utf-8 -*-
"""按名字渲染某张谱的带框图(顶部若干比例), 供肉眼比对。qa_batch 的配套工具。"""
import glob
import os
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import jp_transcribe as JP
import batch_transcribe as BT
from PIL import Image

NAME = sys.argv[1]
FRAC = float(sys.argv[2]) if len(sys.argv) > 2 else 0.45
WIDTH = int(sys.argv[3]) if len(sys.argv) > 3 else 1100

d = [x for x in glob.glob("images-prep/*/*")
     if os.path.isdir(x) and BT.safe_name(os.path.basename(x)) == NAME]
if not d:
    print("找不到目录:", NAME)
    sys.exit(1)
p = BT.pick_page(d[0])
out = f"train-work/qa_batch/_look_{NAME[:28]}.png"
toks, _meta = JP.render(p, out)
im = Image.open(out).convert("L")
c = im.crop((0, 0, im.width, max(60, int(im.height * FRAC))))
c = c.resize((WIDTH, int(c.height * WIDTH / c.width)), Image.LANCZOS)
c.save(out)
nx = sum(1 for t in toks if "x" in t)
print(f"{NAME}")
print(f"  源图 {im.size}  token {len(toks)}  x {nx} ({100*nx/max(len(toks),1):.0f}%)")
print(f"  带框图 -> {out}  {c.size}")
print("  前 80 token: " + " ".join(toks[:80]))
