# -*- coding: utf-8 -*-
"""用磁盘真实目录名测 safe_name。"""
import glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

bad = []
for d in glob.glob("images-prep/*/*"):
    n = os.path.basename(d)
    if re.search(r"[\x00-\x1f\x7f-\x9f]", n):
        bad.append(n)
print(f"磁盘上含控制字符的目录名: {len(bad)} 个")
for n in bad[:6]:
    s = BT.safe_name(n)
    ok = not re.search(r"[\x00-\x1f\x7f-\x9f]", s)
    print(f"  原 {n[:36]!r}")
    print(f"  新 {s[:36]!r}  非法字符已清除={ok}")
