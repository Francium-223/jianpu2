# -*- coding: utf-8 -*-
"""实验: 把页眉(标题/署名)区域涂白后再转写, 能否消掉"开头一长串同音"的伪影。

背景: train-work/qa_head_artifact.md —— 开头出现 >=4 同音的比例 9.80%, 串内 3.66%(2.7 倍),
极端例《关山望月》开头 41 个 `1`(实际第一个音是 3)。成因是顶部大字标题的黑体笔画被当音符。

做法: 对同一张谱, 原图 vs 涂白顶部 X% 各转一次, 比较:
  * 开头连续同音长度(应显著下降)
  * 转出音符总数(不应显著下降 —— 下降说明把乐谱也涂掉了)
用法: py -3.13 tools/test_headmask.py [样本数=8] [涂白比例=0.15]
"""
import glob
import io
import os
import shutil
import sys
import tempfile

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import jp_transcribe as JP
import melody_oct as M

N = int(sys.argv[1]) if len(sys.argv) > 1 else 8
FRAC = float(sys.argv[2]) if len(sys.argv) > 2 else 0.15
DIG = "1234567"


def headrun(pitch):
    if not pitch:
        return 0
    k = 1
    while k < len(pitch) and pitch[k] == pitch[0]:
        k += 1
    return k


def pitch_of(tokens):
    """JP.transcribe 返回的是 token 串(如 `q1`/`5`/`-`), 要用与全库一致的解析口径取音高。"""
    e, _ = M.enc(" ".join(tokens))
    return "".join(x[0] for x in e if x[0] not in "0x")


# 挑"开头长同音"的谱当样本
cands = []
for f in glob.glob("batch-out/*.txt"):
    toks = io.open(f, encoding="utf-8", errors="replace").read().split()
    s = "".join(t[0] for t in toks if t and t[0] in DIG)
    if s and headrun(s) >= 6 and len(s) >= 40:
        cands.append((headrun(s), os.path.basename(f)[:-4], s[:14]))
cands.sort(reverse=True)
print(f"候选(开头同音>=6) {len(cands)} 份, 取前 {N} 份做实验, 涂白比例 {FRAC:.0%}\n")

if not os.path.exists("train-work/_headmask"):
    os.makedirs("train-work/_headmask", exist_ok=True)

for hr, base, head in cands[:N]:
    d = None
    for g in glob.glob("images-prep/*/" + glob.escape(base)):
        d = g
        break
    if not d:
        continue
    imgs = [x for x in glob.glob(os.path.join(d, "*"))
            if x.lower().endswith((".jpg", ".jpeg", ".png", ".gif")) and os.path.getsize(x) > 20000]
    if not imgs:
        continue
    src = max(imgs, key=os.path.getsize)
    try:
        t0 = JP.transcribe(src)
    except Exception as e:
        print(f"  {base[:40]} 原图转写失败 {type(e).__name__}")
        continue
    s0 = pitch_of(t0[0] if isinstance(t0, tuple) else t0)

    # 涂白顶部
    im = Image.open(src).convert("RGB")
    w, h = im.size
    im.paste((255, 255, 255), (0, 0, w, int(h * FRAC)))
    tmp = os.path.join("train-work/_headmask", "m_" + os.path.basename(src).rsplit(".", 1)[0] + ".png")
    im.save(tmp)
    try:
        t1 = JP.transcribe(tmp)
    except Exception as e:
        print(f"  {base[:40]} 涂白后转写失败 {type(e).__name__}")
        continue
    s1 = pitch_of(t1[0] if isinstance(t1, tuple) else t1)

    print(f"  {base[:38]:<40} 原: 开头同音 {headrun(s0):>2} 音符 {len(s0):>4} | "
          f"涂白: 开头同音 {headrun(s1):>2} 音符 {len(s1):>4}  "
          f"({len(s1)-len(s0):+d})")
