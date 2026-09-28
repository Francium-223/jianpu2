# -*- coding: utf-8 -*-
"""刷新 HuggingFace 交付物(`jianpu-db/hf/`)与技能自带语料里的**实测数字**。

为什么需要单开一个: `hf/data.jsonl` 与 `hf/README.md` 是**手工**维护的, 语料涨到 10,277 首
时它们还写着 10,170 首 / 1,813,155 音符 —— 这种"文档里的数比实际少"最容易被当成"数据没进去"。
本工具只做**确定性替换**(旧串在则换, 不在则跳过并说明), 数字全部现算:

  * 首数 / status 分布 / 音符总数(音符用唯一口径 `jptok.pitched(score, merge_ties=True)`)
  * `hf/data.jsonl` = `jianpu-db/data.jsonl` 的原样副本
  * 技能副本 `jianpu2/skills/jianpu-melody-lookup/data.jsonl`

用法: py -3.13 tools/hf_refresh.py [--dry]
"""
import argparse
import io
import json
import os
import re
import shutil
import sys

ROOT = r"D:\Documents_D\jianpu2"
DB = r"D:\Documents_D\jianpu-db"
DATA = os.path.join(DB, "data.jsonl")
HF = os.path.join(DB, "hf")

sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
import jptok        # noqa: E402  唯一 token 口径


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    n_song = n_note = 0
    st = {}
    for line in io.open(DATA, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        n_song += 1
        n_note += len(jptok.pitched(d.get("score") or "", merge_ties=True))
        s = (d.get("status") or "").strip() or "?"
        st[s] = st.get(s, 0) + 1
    print(f"语料 {n_song} 首 / {n_note:,} 音符 / status {st}")

    rd = os.path.join(HF, "README.md")
    if os.path.exists(rd):
        s = io.open(rd, encoding="utf-8").read()
        subs = [
            (r"简谱\(jianpu\)\*\*旋律语料: \d+ 首", f"简谱(jianpu)**旋律语料: {n_song} 首"),
            (r"在全部 \d+ 首里找出", f"在全部 {n_song} 首里找出"),
            (r"音符总数: [\d,]+", f"音符总数: {n_note:,}"),
            (r"`status`: `ocr` \d+ 首\(由图片机器转写\) / `ok` \d+ 首\(人工校对过\)",
             f"`status`: `ocr` {st.get('ocr', 0)} 首(由图片机器转写) / "
             f"`ok` {st.get('ok', 0)} 首(人工校对过)"),
        ]
        hits = 0
        for pat, rep in subs:
            if re.search(pat, s):
                s = re.sub(pat, rep, s, count=1)
                hits += 1
            else:
                print(f"  跳过(旧串不在): {pat[:40]}")
        if not a.dry:
            io.open(rd, "w", encoding="utf-8").write(s)
        print(f"README 替换 {hits} 处{'（空跑）' if a.dry else ''}")

    if not a.dry:
        shutil.copyfile(DATA, os.path.join(HF, "data.jsonl"))
        shutil.copyfile(DATA, os.path.join(ROOT, "skills", "jianpu-melody-lookup", "data.jsonl"))
        print("已同步 hf/data.jsonl 与技能副本")
    else:
        print("（空跑：未复制 data.jsonl）")


if __name__ == "__main__":
    main()
