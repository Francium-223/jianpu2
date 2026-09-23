# -*- coding: utf-8 -*-
"""检查 scores 标题里的 mojibake 残留(包括单个 å/æ 这种, 之前 qa_titles 的 {2,} 漏了)。"""
import glob, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

fs = glob.glob("jianpu-db-out/scores/*.txt")
bad = []
for f in fs:
    b = os.path.basename(f)[:-4]
    # 拉丁补充区字符 + 常见 mojibake 特征, 单个也算
    if re.search(r"[\u00c0-\u00ff\u0080-\u00bf]", b) or "_" in b and re.search(r"[\u00c0-\u00ff]", b):
        bad.append(b)
print(f"scores {len(fs)}; 标题含 mojibake 的 {len(bad)}")
for b in bad[:15]:
    print(f"   {b[:60]}")
# 也看 subtitle
print("\n(参考: 干净的标题长这样)")
for b in sorted(os.path.basename(x)[:-4] for x in fs)[:5]:
    print(f"   {b[:50]}")
