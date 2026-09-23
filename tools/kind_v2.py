# -*- coding: utf-8 -*-
"""纯简谱检测 v2: 找"5-6 条等距长横线成组"(五线谱/六线谱的谱线组)。
纯简谱页只有零星长横线(不成组), 谱表页每组 5~6 条 -> staff_groups 明显 >0。
用法: py tools/kind_v2.py [限制数]   输出 train-work/kind_v2.tsv
"""
import csv, glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import numpy as np
from PIL import Image
import transcribe as T
import batch_transcribe as BT

def staff_groups_of(c):
    H, W = c.shape
    rs = c.sum(axis=1)
    ys = [y for y in range(H) if rs[y] > 0.5 * W]
    if not ys:
        return 0, 0, len(ys)
    groups, cur = [], [ys[0]]
    for y in ys[1:]:
        if y - cur[-1] <= 22:
            cur.append(y)
        else:
            groups.append(cur); cur = [y]
    groups.append(cur)
    # 谱表组: >=4 条线, 且首尾跨度 <= 6*平均间距*2 (排除"整页半黑"的伪影)
    st = 0
    for g in groups:
        if len(g) >= 4:
            span = g[-1] - g[0]
            if span <= 90:
                st += 1
    return st, len(groups), len(ys)

def one(path):
    im = Image.open(path).convert("L")
    iw, ih = im.size
    tw = 1200 if iw < 700 else (2000 if iw > 2000 else iw)
    if tw != iw:
        im = im.resize((tw, max(1, int(round(ih * tw / iw)))), Image.LANCZOS)
    c = np.asarray(im) < T.TOL
    return staff_groups_of(c)

if __name__ == "__main__":
    LIM = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 0
    dirs = sorted(d for d in glob.glob("images-prep/*/*") if os.path.isdir(d))
    if LIM:
        dirs = dirs[:LIM]
    print(f"检查 {len(dirs)} 个目录", flush=True)
    out = open("train-work/kind_v2.tsv", "w", encoding="utf-8", newline="")
    w = csv.writer(out, delimiter="\t")
    w.writerow(["dir", "staff_groups", "groups", "long_rows", "w", "h"])
    n = 0
    for i, d in enumerate(dirs):
        p = BT.pick_page(d)
        if not p:
            continue
        try:
            st, g, lr = one(p)
            im = Image.open(p).size
            w.writerow([os.path.basename(d.rstrip("/\\")), st, g, lr, im[0], im[1]])
            n += 1
        except Exception:
            pass
        if (i + 1) % 500 == 0:
            print(f"  {i+1}/{len(dirs)}", flush=True)
    out.close()
    print(f"完成 {n} -> train-work/kind_v2.tsv")
