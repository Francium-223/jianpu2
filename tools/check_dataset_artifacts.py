# -*- coding: utf-8 -*-
"""数据集附带件的体检（只读）：`source_pages.json` / `data.json` / `data.jsonl` 对不对得上。

为什么查这三个:
  * `source_pages.json` —— HF 卡片写着"原谱站那一页可由 source 的站点+id 推出"，
    所以要量**语料里每个 source 都能查到页面吗**；
  * `data.json` —— 按**曲谱文件**为键（11991 条），`data.jsonl` 是**白名单语料**（11495 条），
    两个数本来就不同；要确认它们**同一批构建**（时间戳一致）而不是一个过期。
用法: py -3.13 tools/check_dataset_artifacts.py
"""
import io
import json
import os
import sys
from guard import guard_help        # noqa: E402
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(os.path.dirname(ROOT), "jianpu-db")


def mtime(p):
    return os.path.getmtime(p)


sp = json.load(io.open(os.path.join(DB, "source_pages.json"), encoding="utf-8"))
dj = json.load(io.open(os.path.join(DB, "data.json"), encoding="utf-8"))

srcs = []
n_rows = 0
for line in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
    if not line.strip():
        continue
    n_rows += 1
    s = json.loads(line).get("source")
    if isinstance(s, list):
        srcs.extend(s)
    elif s:
        srcs.append(s)
uniq = [s for s in dict.fromkeys(srcs) if s]
hit = [s for s in uniq if s in sp]

print("data.jsonl      %5d 行（白名单语料）" % n_rows)
print("data.json       %5d 条（按曲谱文件为键）" % len(dj))
print("source_pages    %5d 条" % len(sp))
print()
print("语料里唯一 source 值 %d 个 -> 能在 source_pages.json 查到页面的 %d 个（%.1f%%）"
      % (len(uniq), len(hit), len(hit) * 100.0 / max(1, len(uniq))))
miss = [s for s in uniq if s not in sp]
if miss:
    print("  查不到的 %d 个，样例: %s" % (len(miss), miss[:5]))
print()
same = abs(mtime(os.path.join(DB, "data.json")) - mtime(os.path.join(DB, "data.jsonl"))) < 600
print("data.json 与 data.jsonl 是同一批构建（时间戳相差 <10 分钟）: %s" % ("✓" if same else "✗ 有一个可能过期"))
