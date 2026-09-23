# -*- coding: utf-8 -*-
"""验收 OCR 那批谱的标签: 与打标前的备份逐行 diff(只允许 usertag= / todo= 变), 并报覆盖率。

用法: py -3.13 tools/verify_ocr_tags.py
"""
import difflib
import glob
import io
import os
import re
import sys
from collections import Counter

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
A, B = "jianpu-db-out/scores-before-tag", "jianpu-db-out/scores"


def main():
    files = sorted(os.path.basename(x) for x in glob.glob(B + "/*.txt"))
    tagchg = todoins = todomod = 0
    other = []
    for n in files:
        a = io.open(A + "/" + n, encoding="utf-8", errors="replace", newline="").read() if os.path.exists(A + "/" + n) else ""
        b = io.open(B + "/" + n, encoding="utf-8", errors="replace", newline="").read()
        if a == b:
            continue
        for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a.splitlines(True), b.splitlines(True)).get_opcodes():
            if op == "equal":
                continue
            old = "".join(a.splitlines(True)[i1:i2]).strip()
            new = "".join(b.splitlines(True)[j1:j2]).replace("\r", "").replace("\n", "")
            if old.startswith("usertag=") and new.startswith("usertag="):
                tagchg += 1
            elif op == "insert" and new == "todo=add tags":
                todoins += 1
            elif old.startswith("todo=") and new.startswith("todo="):
                todomod += 1
            else:
                other.append((n, repr(old[:70]), repr(new[:70])))
    tagged = todo = 0
    tags = Counter()
    for n in files:
        t = io.open(B + "/" + n, encoding="utf-8", errors="replace").read()
        m = re.search(r"(?m)^usertag=(.*)$", t)
        if m and m.group(1).strip():
            tagged += 1
            for x in m.group(1).split(","):
                tags[x.strip()] += 1
        if re.search(r"(?m)^todo=add tags$", t):
            todo += 1
    print(f"谱 {len(files)} 份")
    print(f"  usertag 改写 {tagchg} / todo 新增 {todoins} / todo 改写 {todomod} / 其它差异 {len(other)}")
    for x in other[:10]:
        print("     OTHER", x)
    print(f"  带标签 {tagged} ({tagged / len(files) * 100:.1f}%) / todo=add tags {todo} / 合计 {tagged + todo}")
    artist = {k: v for k, v in tags.items() if not k.startswith("分类/")}
    cat = {k: v for k, v in tags.items() if k.startswith("分类/")}
    print(f"  歌手/人名标签 {len(artist)} 个; 分类标签 {len(cat)} 个")
    print("   top 人名: " + " | ".join(f"{k}{v}" for k, v in Counter(artist).most_common(15)))
    print("   top 分类: " + " | ".join(f"{k}{v}" for k, v in Counter(cat).most_common(15)))


if __name__ == "__main__":
    main()
