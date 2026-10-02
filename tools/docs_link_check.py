# -*- coding: utf-8 -*-
"""三个仓库的 markdown 内部链接体检（只读）。

只查**相对路径**链接（`[文字](路径)` 与 `![图](路径)`）：
  * 带 `#` 锚点的只看文件是否存在（锚点大多不在 md 里，误报太多）；
  * 跳过 http(s)/mailto/绝对站内路径（那些是运行时路由，不是仓库文件）；
  * 跳过 node_modules / .git / dist* / by_* / scores / misc / images* / _analysis / train-work。
输出: 每个仓库的断链清单（0 就是干净）。
"""
import io
import os
import re
import sys

ROOTS = [r"D:\Documents_D\jianpu2", r"D:\Documents_D\jianpu-db", r"D:\Documents_D\jianpu-db.github.io"]
SKIP = re.compile(r"(node_modules|\\\.git\\|\\dist|by_|\\scores|\\misc|images|_analysis|train-work|__pycache__|\\.venv|hf\\)")
# **上游 vendored 文档**：整份是从别人的仓库拿来的，里面的相对链接按人家的目录结构写，
# 本仓库里当然找不到（实测 `transformers_multimodal.md` -> `./transformers.md`，全仓库没有这个文件）。
# 不是我们的文档，就别让检查器报它 —— 但名字写在这里，不藏。
VENDOR = {"transformers_multimodal.md"}
LINK = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)\)")
total_bad = 0
for root in ROOTS:
    if not os.path.isdir(root):
        continue
    bad = []
    n = 0
    for dirpath, dirnames, filenames in os.walk(root):
        if SKIP.search(dirpath + os.sep):
            continue
        for fn in filenames:
            if not fn.lower().endswith(".md") or fn in VENDOR:
                continue
            p = os.path.join(dirpath, fn)
            n += 1
            txt = io.open(p, encoding="utf-8", errors="replace").read()
            for m in LINK.finditer(txt):
                t = m.group(1).strip()
                if t.startswith(("http://", "https://", "mailto:", "#", "/", "<")):
                    continue
                t = t.split("#")[0].split("?")[0]
                if not t:
                    continue
                tgt = os.path.normpath(os.path.join(dirpath, t.replace("/", os.sep)))
                if not os.path.exists(tgt):
                    bad.append((os.path.relpath(p, root), t))
    total_bad += len(bad)
    print("%-24s 扫 %d 个 md，断链 %d 条" % (os.path.basename(root), n, len(bad)))
    for f, t in bad[:12]:
        print("    %s  ->  %s" % (f, t))
    if len(bad) > 12:
        print("    （还有 %d 条）" % (len(bad) - 12))
print()
print("三仓库合计断链: %d 条" % total_bad)
sys.exit(0)
