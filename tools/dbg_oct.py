# -*- coding: utf-8 -*-
"""调试: 为什么 melody_oct 这次没命中 59113。"""
import os, sys, re
os.chdir(r"D:\Documents_D\jianpu2")
sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")

p = "batch-out/一起走过的日子(粤语)__jianpucn-59113.txt"
raw = open(p, "rb").read()
print("字节数:", len(raw))
print("前 40 字节:", raw[:40])
txt = raw.decode("utf-8", errors="replace")
print("首行:", repr(txt.splitlines()[0][:60]))

import melody_oct as M
e, raws = M.enc(txt)
print("解析出音符数:", len(e))
print("前 20 个编码:", e[:20])
print("前 20 个原 token:", raws[:20])
q = M.parse_query(",6 3 2 3 1 3 ,7 3")
print("查询编码:", q)
print("LCS:", M.lcs_pos(q, e))

import glob
files = glob.glob("batch-out/*.txt")
print("glob 到 batch-out 文件数:", len(files))
hit = [f for f in files if "59113" in f]
print("其中含 59113 的:", hit)
