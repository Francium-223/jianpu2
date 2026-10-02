# -*- coding: utf-8 -*-
"""把 jianpu-db/README.md 里指向**已不存在**的 `scores/th*.txt` 的链接降级成纯文本，
并修掉 `parse_score.py`（真实文件名是 `parse_scores.py`）。只改 README，只动这两类。

依据（2026-10-03 实测）：README 引用 530 个唯一的 `th*.txt`，`scores/` 里只有 512 个 ——
差的 25 个**全仓库都没有**（整理语料时按曲名重命名/合并掉了），所以链接必然 404；
这些条目的信息（曲名与编号）保留，只把点击目标去掉，并加一行说明。
"""
import io
import os
import re
import sys
from guard import guard_help        # noqa: E402
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.join(os.path.dirname(ROOT), "jianpu-db")
README = os.path.join(REPO, "README.md")
SCORES = os.path.join(REPO, "scores")

txt = io.open(README, encoding="utf-8").read()
have = {f[:-4] for f in os.listdir(SCORES) if f.startswith("th") and f.endswith(".txt")}
refs = sorted({m.group(1)[:-4] for m in re.finditer(r"\(scores/(th[0-9_a-z]+\.txt)\)", txt)})
missing = [r for r in refs if r not in have]
print("README 引用 %d 个唯一 th 名，scores/ 缺 %d 个" % (len(refs), len(missing)))

n = 0
for name in missing:
    # 真实写法是 <abbr title="th02_16.txt">[🟥](scores/th02_16.txt)</abbr> —— 方括号里是各专辑不同的色块 emoji，
    # 所以用正则按名字匹配，保留 title= 里的编号信息，只把链接降级成纯 emoji。
    pat = re.compile(r"\[([^\]\[]*)\]\(scores/" + re.escape(name) + r"\.txt\)")
    txt, k = pat.subn(r"\1", txt)
    n += k
print("把 %d 个死链降级成纯文本 emoji" % n)

if "[parse_score.py](parse_score.py)" in txt:
    txt = txt.replace("[parse_score.py](parse_score.py)", "[parse_scores.py](parse_scores.py)")
    print("修正 parse_score.py -> parse_scores.py")

note = ("> 说明（2026-10-03）：上面东方系列的编号里，有 25 个文件已按曲名重命名/合并"
        "（**全仓库都不存在**），因此不再做链接；曲名与编号信息保留。当前文件列表见 [`scores/`](scores)。\n\n")
if "已按曲名重命名/合并" not in txt:
    # 插在东方系列那一块之前（找它出现的那一行）
    m = re.search(r"^.*东方封魔录.*$", txt, flags=re.M)
    if m:
        txt = txt[:m.start()] + note + txt[m.start():]
        print("已在东方系列前加一行说明")

io.open(README, "w", encoding="utf-8", newline="").write(txt)
print("已写回 " + README)
