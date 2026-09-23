# -*- coding: utf-8 -*-
"""测小节线恢复(**走完整 parse 路径**, 因为 to_record 依赖 expand 填好的内容)。"""
import io
import os
import sys

os.chdir(r"D:\Documents_D\jianpu-db")
sys.path.insert(0, r"D:\Documents_D\jianpu-db")
sys.stdout.reconfigure(encoding="utf-8")
from score import Score  # noqa: E402

for f in ("scores/th10_06.txt", "scores/上春山.txt", "scores/义勇军进行曲.txt",
          "scores/东方红.txt", "scores/邓丽君_2.txt"):
    if not os.path.exists(f):
        print(f, "(不存在)")
        continue
    s = Score(f)
    s.read()
    s.expand()
    if not s.raw_expanded:                 # read() 不填 raw2 -> 手动补(仅测试用, 不写盘)
        s.raw2 = io.open(f, encoding="utf-8", errors="replace").read()
        s.expand()
    r = s.to_record()
    print(f"{os.path.basename(f):<20} 每小节={r['beats_per_bar']:<5} 音符={r['n_notes']:<5} 小节线={len(r['bars'])}")
    print(f"    bars: {r['bars'][:16]}")
