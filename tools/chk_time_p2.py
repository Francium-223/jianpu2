# -*- coding: utf-8 -*-
import sys; sys.path.insert(0,"tools"); import os; os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pipeline as P
toks,meta=P.transcribe("train-work/gt/时间都去哪了.jpg")
open("train-work/time_pipe.txt","w",encoding="utf-8").write(" ".join(toks))
print("音",len(toks))
# 检查 b(降号) 是否还有
if any("b" in t for t in toks): print("仍有含b:", [t for t in toks if "b" in t][:5])
else: print("无b了(降号修好)")
# 检查 s6 类(十六分6) 分布
print("s6:", [t for t in toks if "s6" in t])
print("含s:", [t for t in toks if "s" in t][:12])
