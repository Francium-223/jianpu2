# -*- coding: utf-8 -*-
"""把最新实测数字同步进文档 —— 只做**确定性替换**(旧串在则换, 不在则跳过并说明), 绝不猜写。

覆盖:
  SKILL.md              索引"X 首歌 / Y 份谱"
  醒来汇报_v10.md        成品曲谱/语料/JSONL/索引 一行
  train-work/DELIVERY.md 成品谱数、source= 覆盖、转写队列、索引规模
另外给每份文档**追加**一节"本次自动同步", 里面是覆盖率三口径与最近一次评测数字
(追加而不是改写表格, 避免把没重跑的旧指标伪造成新指标)。

用法: py -3.13 tools/sync_docs.py [--dry]
"""
import glob
import io
import json
import os
import re
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
DRY = "--dry" in sys.argv

# ---------- 采数 ----------
scores = glob.glob("jianpu-db-out/scores/*.txt")
n_scores = len(scores)
n_src = sum(1 for f in scores if any(l.startswith("source=") for l in
                                     io.open(f, encoding="utf-8", errors="replace")))
q = {k: len(glob.glob(f"batch-out{k}/*.txt")) for k in ("", "-dup", "-bad", "-empty", "-suspect")}
jsonl = "train-work/jpdbtest/out.jsonl"
n_song = n_note = 0
if os.path.exists(jsonl):
    for line in io.open(jsonl, encoding="utf-8", errors="replace"):
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        n_song += 1
        n_note += int(d.get("n_notes") or 0)

# 索引规模(与 melody_query 同口径: batch-out + batch-out-dup, 按曲名分组)
sys.path.insert(0, "tools")
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
_groups = {}
for pat in ("batch-out/*.txt", "batch-out-dup/*.txt"):
    for f in glob.glob(pat):
        b = os.path.basename(f)[:-4]
        base = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", b.split("__")[0])
        key = re.split(r"[（(\s　【\[《]", base)[0].strip() or base.strip()
        _groups.setdefault(key, []).append(b)
n_idx_song = len(_groups)
n_idx_score = sum(len(v) for v in _groups.values())

print(f"采数: scores={n_scores} source={n_src} JSONL={n_song}首/{n_note:,}音符 "
      f"索引={n_idx_song}首/{n_idx_score}份 队列={q}")

# ---------- 替换 ----------
EDITS = [
    ("SKILL.md",
     r"索引：全库已转写曲谱 \*\*\d+ 首歌 / \d+ 份谱\*\*",
     f"索引：全库已转写曲谱 **{n_idx_song} 首歌 / {n_idx_score} 份谱**"),
    ("醒来汇报_v10.md",
     r"\*\*成品曲谱 \d+ 份 / 语料 \d+ 份 / `source=` 覆盖 [\d.]+% / JSONL \d+ 首 [\d.]+ 万音符 /\s*\n?检索索引 \d+ 首歌 / 基准集 100/100 全覆盖。\*\*",
     f"**成品曲谱 {n_scores} 份 / 语料 {n_scores + q['']} 份 / `source=` 覆盖 "
     f"{n_src/max(1,n_scores)*100:.1f}% / JSONL {n_song} 首 {n_note/10000:.1f} 万音符 /\n"
     f"检索索引 {n_idx_song} 首歌 / 基准集 100/100 全覆盖。**"),
    ("train-work/DELIVERY.md",
     r"- 成品谱: \*\*\d+\*\* 份",
     f"- 成品谱: **{n_scores}** 份"),
    ("train-work/DELIVERY.md",
     r"- 带 `source=` 出处的: \d+ \([\d.]+%\)，缺 \d+ 份",
     f"- 带 `source=` 出处的: {n_src} ({n_src/max(1,n_scores)*100:.1f}%)，缺 {n_scores-n_src} 份"),
    ("train-work/DELIVERY.md",
     r"- 转写队列: batch-out \d+ / -dup \d+ / -bad \d+ / -empty \d+ / -suspect \d+",
     f"- 转写队列: batch-out {q['']} / -dup {q['-dup']} / -bad {q['-bad']} / "
     f"-empty {q['-empty']} / -suspect {q['-suspect']}"),
    ("train-work/DELIVERY.md",
     r"索引 = \d+ 首歌 / \d+ 份谱",
     f"索引 = {n_idx_song} 首歌 / {n_idx_score} 份谱"),
]

done, skipped = [], []
for path, pat, rep in EDITS:
    if not os.path.exists(path):
        skipped.append((path, "文件不存在"))
        continue
    s = io.open(path, encoding="utf-8").read()
    m = re.search(pat, s, re.S)
    if not m:
        skipped.append((path, "旧串未匹配(可能已同步)"))
        continue
    if m.group(0) == rep:
        skipped.append((path, "已经是新值"))
        continue
    s2 = re.sub(pat, rep, s, count=1, flags=re.S)
    if not DRY:
        io.open(path, "w", encoding="utf-8").write(s2)
    done.append((path, m.group(0)[:60].replace("\n", " ")))

print(f"\n替换 {len(done)} 处{'（空跑）' if DRY else ''}:")
for p, old in done:
    print(f"   {p}: {old}")
print(f"跳过 {len(skipped)} 处:")
for p, why in skipped:
    print(f"   {p}: {why}")

# ---------- 追加"本次自动同步" ----------
cov = ""
if os.path.exists("train-work/coverage_report.md"):
    for l in io.open("train-work/coverage_report.md", encoding="utf-8"):
        if l.startswith("| ①") or l.startswith("| ②") or l.startswith("| ③"):
            cov += "  " + l.strip() + "\n"
ev = []
for lab, p in (("同版自匹配(neighbor)", "train-work/retrieval_eval_neighbor.tsv"),
               ("留一版本(holdout)", "train-work/retrieval_holdout.tsv"),
               ("漏音(indel)", "train-work/retrieval_indel.tsv"),
               ("轮廓(contour)", "train-work/retrieval_contour.tsv")):
    if os.path.exists(p):
        ls = [l.strip() for l in io.open(p, encoding="utf-8", errors="replace") if l.strip()]
        ev.append(f"  - {lab}: `{ls[-1][:100]}`  ({os.path.getmtime(p):.0f})")

block = (f"\n\n---\n\n## 本次自动同步（tools/sync_docs.py，{__import__('datetime').datetime.now():%Y-%m-%d %H:%M}）\n\n"
         f"- 成品谱 **{n_scores}** / `source=` **{n_src}** / JSONL **{n_song} 首 {n_note:,} 音符** / "
         f"索引 **{n_idx_song} 首歌 {n_idx_score} 份谱**\n"
         f"- 覆盖率（`train-work/coverage_report.md`）：\n{cov}"
         f"- 最近一次评测末行：\n" + ("\n".join(ev) if ev else "  (无)") + "\n"
         f"- 已知问题：见 `train-work/qa_head_artifact.md`（页眉标题被读成音符）与 "
         f"`train-work/frag_ambiguity.log`（短片段判别力）。\n")
for path in ("SKILL.md", "train-work/DELIVERY.md"):
    if not os.path.exists(path):
        continue
    s = io.open(path, encoding="utf-8").read()
    if "## 本次自动同步" in s:                 # 幂等: 去掉上一节再追加
        s = s.split("\n\n---\n\n## 本次自动同步")[0]
    if not DRY:
        io.open(path, "w", encoding="utf-8").write(s + block)
print(f"\n已追加'本次自动同步'到 SKILL.md / train-work/DELIVERY.md{'（空跑未写）' if DRY else ''}")
