# -*- coding: utf-8 -*-
"""统计 data.jsonl 的 `score` 里"有符号但没音高"的碎片(以及调号漏进正文)。

⚠ 2026-09-28 更正: 这个脚本原来写着"`c~` 很可能是**那里丢了一个音高的音**" —— **是假警报**。
    实测(四方印证) `c~`/`q~`/`s~` 是 **jianpu-ly 的连音线**(源码第 137 行 `Ties: 1 ~ 1`):
      ① jianpu-ly 源码里 `~` 就是 tie, 且明说"写在短横后 = 从数字起连";
      ② manifest 里同一处是压缩形 `'1q 6 3 … 1 - - - ~`;
      ③ 生成的 .ly 里是 `\\note-mod "–" c''4` + `\\once \\override Tie` 组成 `\\=JianpuTie(`;
      ④ 渲染出的 PNG 上就是一条连音弧。
    它没有音高也**不占拍**(recover_bars 走"不是 token"分支 -> 0 拍), 正是 tie 该有的样子;
    191 个全在手工录入/jianpu-ly 转出的 status=ok 谱里, OCR 谱 0 个。
    `1=C` 是**调号** —— 语料没有调号字段, 而前端逐 token 原样渲染, 写在正文里正好把它显示出来。
    所以本脚本现在只当**报数**用, 不再是"疑似损坏"清单; 真报警请用
    tools/check_corpus_invariants.py(它已把这两类归为"良性记号")。
只读。
"""
import collections
import io
import json
import os
import re
import sys

DB = r"D:\Documents_D\jianpu-db"
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                               "skills", "jianpu-melody-lookup"))
import jptok  # noqa: E402

FRAG = re.compile(r"^[cqsdh]+[~\[\]]*$")          # 时值 + 连音线/括号, 没有数字
KEY = re.compile(r"^\d+=[A-Ga-g]")                # 调号行漏进正文

frag = collections.Counter()
per_file = collections.Counter()
key_leak = []
for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
    if not l.strip():
        continue
    r = json.loads(l)
    f = r["file"][0]
    for t in (r.get("score") or "").split():
        if t == "|" or jptok.is_note(t):
            continue
        if FRAG.match(t):
            frag[t] += 1
            per_file[f] += 1
        elif KEY.match(t):
            frag[t] += 1
            per_file[f] += 1
            if f not in key_leak:
                key_leak.append(f)

print("音符碎片(有符号没音高): %d 个, 分布在 %d 首" % (sum(frag.values()), len(per_file)))
print("最常见:", frag.most_common(8))
print("调号漏进正文的谱: %d %s" % (len(key_leak), key_leak[:6]))
print()
print("受影响最多的 10 首:")
for f, n in per_file.most_common(10):
    print("   %-30s %d 个" % (f, n))
