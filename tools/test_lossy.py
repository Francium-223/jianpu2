# -*- coding: utf-8 -*-
"""测"有损解码"能救回多少 mojibake 标题: 丢无效字节, 保留能解出的中文片段。
对比三种策略在 152 个坏标题上的效果。
"""
import glob, os, re, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")


def strict(s):
    """现有逻辑(解不出就原样返回)。"""
    try:
        s.encode("latin-1")
    except UnicodeEncodeError:
        return s
    try:
        r = s.encode("latin-1").decode("utf-8")
        return r if r else s
    except Exception:
        return s


def lossy(s):
    """有损: 丢无效字节, 保留能解出的部分; 结果里没有中文就仍返回原串。"""
    try:
        b = s.encode("latin-1")
    except UnicodeEncodeError:
        return s
    r = b.decode("utf-8", errors="ignore")
    r = re.sub(r"[\x00-\x1f\x7f-\x9f]", "", r).strip()
    return r if re.search(r"[\u4e00-\u9fff]", r) else s


def ratio(s):
    """解出来的中文占比。"""
    if not s:
        return 0.0
    return sum(1 for c in s if "\u4e00" <= c <= "\u9fff") / len(s)


bad = [os.path.basename(f)[:-4] for f in glob.glob("jianpu-db-out/scores/*.txt")]
bad = [b for b in bad if re.search(r"[\u00c0-\u00ff]", b)]
print(f"坏标题 {len(bad)} 个\n")
print(f"{'原样(现有逻辑)':<28} {'有损解码':<28} 中文占比")
print("-" * 74)
better = same = 0
for b in bad[:20]:
    a, c = strict(b), lossy(b)
    ra, rc = ratio(a), ratio(c)
    if rc > ra:
        better += 1
    else:
        same += 1
    print(f"{a[:26]:<28} {c[:26]:<28} {ra:.2f} -> {rc:.2f}")
# 全量统计
B = S = 0
for b in bad:
    if ratio(lossy(b)) > ratio(strict(b)):
        B += 1
    else:
        S += 1
print(f"\n全量 {len(bad)} 个: 有损解码更好 {B} 个, 无改善 {S} 个")
