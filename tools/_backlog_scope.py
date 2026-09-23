# -*- coding: utf-8 -*-
"""量清楚: 被卡住的转写到底压着多少"还没转"的谱。

`transcribe_source.py` 的幂等键 = `batch-out/<safe_name>.txt` 是否存在(存在就跳过),
所以"还没转"= 目录名 safe 化之后在 batch-out 里找不到同名 .txt。
"""
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
have = {os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")}


def backlog(pats, label):
    per, tot, miss = {}, 0, 0
    for pat in pats:
        for d in glob.glob("images-prep/" + pat):
            if not os.path.isdir(d):
                continue
            m = n = 0
            for s in glob.glob(d + "/*"):
                if not os.path.isdir(s):
                    continue
                m += 1
                base = re.sub(r'[\\/:*?"<>|]', "_", os.path.basename(s))
                if base not in have:
                    n += 1
            per[os.path.basename(d)] = (m, n)
            tot += m
            miss += n
    print(f"{label}: 谱 {tot}, 其中 batch-out 里还没有的 {miss}")
    for k, v in sorted(per.items(), key=lambda x: -x[1][1])[:10]:
        if v[1]:
            print(f"    {k:<24} 待转写 {v[1]:>4} / {v[0]}")
    print()


backlog(["qupu123-mp9*", "qupu123-title*", "jianpujia-art*", "jianpucn-title*"], "absorb2 名单")
backlog(["jianpujia-art*", "jianpujia-cat*", "qupu123-title*", "jianpucn-title*",
         "qupu123-sweep*", "qupu123-hk*", "qupu123-kw*", "qupu123-crawl*"], "absorb3 名单")
