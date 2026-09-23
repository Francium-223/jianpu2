# -*- coding: utf-8 -*-
"""量"缺口补捞"的产出率: 每首缺口歌从 抓到图 -> 转写成功 -> 过纯度门(进 batch-out) 各剩多少。

为什么单独量: 覆盖率要涨, 靠的是"最终进 scores", 中间任何一环(站点没有/图是五线谱/纯度门拦/
转写失败)都会把收益吃掉。上一轮的教训是只报"抓到了多少首"会高估。

用法: py -3.13 tools/mandopop_yield.py
输出: train-work/mandopop_yield.tsv
"""
import glob
import io
import os
import re
import sys

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
DROP = re.compile(r"[\s《》〈〉（）()\[\]【】、，,。.!！？:：;；·・\-—_…~～'\"“”‘’/\\|&]+")


def norm(s):
    return DROP.sub("", re.sub(r"\[[^\]]*\]", "", s).translate(ZW)).casefold()


# 1) 目标名单 = 爬取日志里去重后的曲名(含 redo 追加的记录)
targets = []
for line in io.open("train-work/mandopop_crawl.tsv", encoding="utf-8"):
    c = line.rstrip("\n").split("\t")
    if c and c[0] and c[0] not in targets:
        targets.append(c[0])
seen_pairs = {}
for line in io.open("train-work/mandopop_crawl.tsv", encoding="utf-8"):
    c = line.rstrip("\n").split("\t")
    if len(c) >= 3 and c[2].lstrip("-").isdigit():
        seen_pairs[c[0]] = max(seen_pairs.get(c[0], 0), int(c[2]))

# 2) 各产物目录里的文件名
def names(root):
    return [os.path.basename(f)[:-4] for f in glob.glob(os.path.join(root, "*.txt"))]


OUT = {r: names(f"batch-out{r}") for r in ("", "-dup", "-bad", "-empty", "-suspect")}
# 3) 图片目录(抓到图没有)
imgs = {}
for d in glob.glob("images-prep/qupu123-mp*") + glob.glob("images-prep/qupu123-title*") \
        + glob.glob("images-prep/jianpucn-title*") + glob.glob("images-prep/jianpujia-art*"):
    for sub in glob.glob(os.path.join(d, "*")):
        if os.path.isdir(sub) and any(x.lower().endswith((".jpg", ".png", ".jpeg", ".gif"))
                                      for x in os.listdir(sub)):
            imgs.setdefault(os.path.basename(sub), d)

rows = []
for t in targets:
    tn = norm(t)
    got = [k for k in imgs if tn in norm(k)]
    ok = [n for n in OUT[""] if tn in norm(n)]
    dup = [n for n in OUT["-dup"] if tn in norm(n)]
    bad = [n for n in OUT["-bad"] if tn in norm(n)]
    emp = [n for n in OUT["-empty"] if tn in norm(n)]
    sus = [n for n in OUT["-suspect"] if tn in norm(n)]
    rows.append((t, seen_pairs.get(t, 0), len(got), len(ok), len(dup), len(bad), len(emp), len(sus)))

n = len(rows)
s = lambda i: sum(1 for r in rows if r[i] > 0)
print(f"缺口目标 {n} 首\n")
print(f"{'阶段':<34}{'首数':>6}{'占比':>8}")
print(f"{'① 爬取日志记到图(>0 张)':<30}{s(1):>6}{s(1)/n*100:>7.1f}%")
print(f"{'② 图片目录真有图':<30}{s(2):>6}{s(2)/n*100:>7.1f}%")
print(f"{'③ 转写出结果(含被拦)':<30}"
      f"{sum(1 for r in rows if r[3]+r[4]+r[5]+r[6]+r[7] > 0):>6}"
      f"{sum(1 for r in rows if r[3]+r[4]+r[5]+r[6]+r[7] > 0)/n*100:>7.1f}%")
print(f"{'④ 过门进 batch-out(可用)':<30}{s(3):>6}{s(3)/n*100:>7.1f}%")
print(f"{'   (其中落选版本 -dup)':<30}{s(4):>6}")
print(f"{'   (被纯度门拦 -bad)':<30}{s(5):>6}")
print(f"{'   (0 音符 -empty)':<30}{s(6):>6}")
print(f"{'   (高念白 -suspect)':<30}{s(7):>6}")

with io.open("train-work/mandopop_yield.tsv", "w", encoding="utf-8") as f:
    f.write("曲名\t日志张数\t图片目录\t进语料\t落选\t纯度拦\t0音符\t高念白\n")
    for r in rows:
        f.write("\t".join(str(x) for x in r) + "\n")
print("\n写出 train-work/mandopop_yield.tsv")
miss = [r[0] for r in rows if r[3] == 0]
if miss:
    print(f"\n仍未进语料的 {len(miss)} 首: " + " / ".join(miss))
