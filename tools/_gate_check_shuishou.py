# -*- coding: utf-8 -*-
"""《水手》3 版能不能进语料: 过纯度门(nline/staff) + 过念白率安全网(x 占比)。"""
import glob
import os
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import kind_detect2 as K
import jp_transcribe as JP

DIG = set("01234567")


def stats(f):
    toks = [t for t in open(f, encoding="utf-8").read().split()
            if t and not t.startswith("%") and "=" not in t]
    n = len(toks)
    if not n:
        return None
    nx = sum(1 for t in toks if "x" in t)
    nd = sum(1 for t in toks if t[-1] in DIG or (len(t) > 1 and t[-1] == "."))
    nz = sum(1 for t in toks if t.startswith("0") or t.endswith("0"))
    return n, nx / n, nd / n, nz / n


print(f"{'文件':<34}{'token':>6}{'x率':>8}{'数字率':>9}{'0率':>8}   nline staff  判定")
for f in sorted(glob.glob("batch-out/水手*.txt")) + sorted(glob.glob("batch-out/每天爱你多一些*.txt")):
    s = stats(f)
    png = None
    for ext in (".png", ".jpg", ".jpeg"):
        p = f[:-4] + ext
        if os.path.exists(p):
            png = p
            break
    nl = st = -1
    verd = "无图"
    if png:
        try:
            nl, _w, _W, _h, st = K.measure(png)
            imp = JP.impure_from(nl, st)
            verd = "非纯(拦)" if imp else "纯简谱(放行)"
        except Exception as e:
            verd = f"测量失败 {type(e).__name__}"
    nm = os.path.basename(f)[:32]
    if s:
        print(f"{nm:<34}{s[0]:>6}{s[1]*100:>7.1f}%{s[2]*100:>8.1f}%{s[3]*100:>7.1f}%"
              f"{nl:>7}{st:>6}  {verd}")
print("\n参考: 全库 x 率 3.4%;  quarantine_highx 拦 x>=30% 且 x>=10 个")
print("      quarantine_empty 拦 0 音符;  参考语料数字率中位 77.9%")
