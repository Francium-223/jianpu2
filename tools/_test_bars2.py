# -*- coding: utf-8 -*-
"""验证 score.py 已改用 jptok 的小节线实现(且结果与并库前一致)。"""
import io
import os
import sys

os.chdir(r"D:\Documents_D\jianpu-db")
sys.path.insert(0, r"D:\Documents_D\jianpu-db")
sys.stdout.reconfigure(encoding="utf-8")
from score import Score, jptok  # noqa: E402

print("jptok 来源:", getattr(jptok, "__file__", "(内置兜底)"))
exp = {"义勇军进行曲.txt": 57, "东方红.txt": 17, "th10_06.txt": 57}
for f, want in exp.items():
    p = "scores/" + f
    s = Score(p)
    s.read()
    s.raw2 = io.open(p, encoding="utf-8", errors="replace").read()
    s.expand()
    r = s.to_record()
    got = len(r["bars"])
    flag = "OK" if got == want else f"**期望 {want}**"
    print(f"{f:<20} 每小节={r['beats_per_bar']:<5} 音符={r['n_notes']:<5} 小节线={got:<4} {flag}")
