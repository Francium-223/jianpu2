# -*- coding: utf-8 -*-
"""把要写进文档的数字一次算齐(交付谱数/出处覆盖/JSONL/索引规模/覆盖率/评测), 避免手抄出错。

用法: py -3.13 tools/numbers_digest.py
"""
import glob
import io
import json
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")

print("=" * 74)
print("交付物数字摘要  " + __import__("datetime").datetime.now().strftime("%Y-%m-%d %H:%M"))
print("=" * 74)

scores = glob.glob("jianpu-db-out/scores/*.txt")
print(f"\n[交付谱]    jianpu-db-out/scores/*.txt = {len(scores)}")
src = sum(1 for f in scores if any(l.startswith("source=") for l in
                                   io.open(f, encoding="utf-8", errors="replace")))
print(f"[出处]      有 source= 的 = {src} ({src/max(1,len(scores))*100:.1f}%)  缺 {len(scores)-src}")

for p in ("train-work/jpdbtest/out.jsonl", "jpdbtest/out.jsonl", "out.jsonl"):
    if os.path.exists(p):
        n = notes = 0
        for line in io.open(p, encoding="utf-8", errors="replace"):
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            n += 1
            notes += int(d.get("n_notes") or 0)          # 该 JSONL 的字段名是 n_notes(不是 notes)
        print(f"[JSONL]     {p}: {n} 首 / {notes:,} 音符")
        break

for d, lab in (("batch-out", "batch-out"), ("batch-out-dup", "-dup"), ("batch-out-bad", "-bad"),
               ("batch-out-empty", "-empty"), ("batch-out-suspect", "-suspect")):
    c = len(glob.glob(d + "/*.txt"))
    print(f"[队列]      {lab:<9} {c}")

print("\n[覆盖率] 见 train-work/coverage_report.md（跑 tools/coverage_report.py 生成）")
if os.path.exists("train-work/coverage_report.md"):
    for l in io.open("train-work/coverage_report.md", encoding="utf-8"):
        if l.startswith("| ①") or l.startswith("| ②") or l.startswith("| ③") or "严格覆盖" in l:
            print("   " + l.strip())

print("\n[检索评测] 最近一次落盘:")
for lab, p in (("同版自匹配 neighbor", "train-work/retrieval_eval_neighbor.tsv"),
               ("同版自匹配 rand", "train-work/retrieval_eval_rand.tsv"),
               ("留一版本 holdout", "train-work/retrieval_holdout.tsv"),
               ("漏音 indel", "train-work/retrieval_indel.tsv"),
               ("轮廓 contour", "train-work/retrieval_contour.tsv")):
    if not os.path.exists(p):
        print(f"   {lab}: (无 {p})")
        continue
    ls = [l.strip() for l in io.open(p, encoding="utf-8", errors="replace") if l.strip()]
    print(f"   {lab} ({os.path.getmtime(p):.0f}): {len(ls)} 行; 末行 = {ls[-1][:96] if ls else ''}")

print("\n[抽检]")
for p in ("train-work/qa_corpus.txt", "train-work/qa_stray_tokens.txt"):
    if os.path.exists(p):
        ls = [l.strip() for l in io.open(p, encoding="utf-8", errors="replace") if l.strip()]
        print(f"   {p}: {len(ls)} 行; 末 3 行: {ls[-3:]}")
