# -*- coding: utf-8 -*-
"""普查曲谱里的 subtitle= 段落名 —— 用于给"段落权重"定标。
搜 jianpu-db 仓库(人工校对) + 我转换的 scores。
"""
import collections, glob, io, os, re, sys
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def sections_in(path):
    out = []
    for l in io.open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"^\s*subtitle\s*=\s*(.*)$", l.strip(), re.I)
        if m:
            out.append(m.group(1).strip() or "(空)")
    return out

for label, pat in (("用户仓库", "D:/Documents_D/jianpu-db/scores/*.txt"),
                   ("我转换的", "jianpu-db-out/scores/*.txt")):
    c = collections.Counter()
    files = 0
    for f in glob.glob(pat):
        s = sections_in(f)
        if s:
            files += 1
            c.update(s)
    print(f"=== {label} ===  含 subtitle 的文件 {files}")
    for k, v in c.most_common(25):
        print(f"   {v:6d}  {k}")
    print()

# 多段落的谱有多少
multi = 0
tot = 0
for f in glob.glob("D:/Documents_D/jianpu-db/scores/*.txt"):
    s = sections_in(f)
    if not s:
        continue
    tot += 1
    if len(s) > 1:
        multi += 1
print(f"用户仓库: 有 subtitle 的 {tot} 份, 其中多段落 {multi} 份 ({100*multi/max(tot,1):.0f}%)")
