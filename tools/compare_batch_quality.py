# -*- coding: utf-8 -*-
"""对比"新吸收的谱" 与 "原有语料" 的质量分布 —— 这是吸收决定的后验检查。

只看名字不够, 要看**数字占比**(音符 token / 全部 token)、0 率、x 率:
  * 数字占比过低 = 页面里混了大量非音符内容(文字/五线谱线被读成 token), 是"混排页"的特征;
  * x 率高 = 念白/打击记号多(可能是五线谱被读成 x)。
用法: py -3.13 tools/compare_batch_quality.py [名单=train-work/purity2_admit.txt]
"""
import glob
import os
import statistics
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

LIST = sys.argv[1] if len(sys.argv) > 1 else "train-work/purity2_admit.txt"
WANT = {l.strip() for l in open(LIST, encoding="utf-8") if l.strip()} if os.path.exists(LIST) else set()
# 名单是**目录名**, 结果文件名是 safe_name(目录名) —— 但吸收后仍带同样的 __站点-id 后缀,
# 所以直接按"结果名前缀匹配"即可(去掉 -简谱 之类的差异用站点 id 对齐)
import re


def sid(n):
    m = re.search(r"__([a-z0-9]+-\d+)$", n)
    return m.group(1) if m else ""


WANT_SIDS = {sid(x) for x in WANT if sid(x)}


def stats(names):
    rows = []
    for b in names:
        f = f"batch-out/{b}.txt"
        try:
            t = open(f, encoding="utf-8", errors="replace").read().split()
        except Exception:
            continue
        if not t:
            rows.append((b, 0, 0.0, 0.0, 0.0))
            continue
        dig = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
        zero = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.").endswith("0"))
        xs = sum(1 for x in t if "x" in x)
        rows.append((b, len(t), dig / len(t), zero / len(t), xs / len(t)))
    return rows


allb = [os.path.basename(f)[:-4] for f in glob.glob("batch-out/*.txt")
        if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
new = [b for b in allb if sid(b) in WANT_SIDS] if WANT_SIDS else []
old = [b for b in allb if b not in set(new)]
print(f"新吸收(按站点id对上) {len(new)} 份 / 原有语料 {len(old)} 份")


def show(tag, rows):
    if not rows:
        print(f"{tag}: 无")
        return
    r = [x[2] for x in rows]
    z = [x[3] for x in rows]
    x_ = [x[4] for x in rows]
    low = sum(1 for v in r if v < 0.5)
    print(f"{tag}  n={len(rows)}")
    print(f"   数字占比: 中位 {statistics.median(r):.1%}  均值 {statistics.mean(r):.1%}   "
          f"<50% 的占 {100.0*low/len(r):.1f}%")
    print(f"   0 率 中位 {statistics.median(z):.1%}   x 率 中位 {statistics.median(x_):.1%}")


show("新吸收", stats(new))
show("原有  ", stats(old))
print("\n(判断标准: 新吸收这组的数字占比中位不应明显低于原有语料; 明显低就说明收进了混排页)")
