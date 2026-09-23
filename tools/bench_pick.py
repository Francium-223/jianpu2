# -*- coding: utf-8 -*-
"""给"华流金曲 100"基准集挑要转写的谱目录 -> train-work/bench_todo.txt。

为什么要挑而不是全转: 100 首在本地有 980 个谱目录, 全转要十几小时 GPU; 检索评测只需要
**每首至少 1 份能用的转写**(查询片段就取自它自己那份谱)。所以缺谱的歌各挑 K 个最优目录。

"已经转过"必须看**五个结果目录**(batch-out/-dup/-bad/-empty/-suspect) —— 只看 batch-out
会把 finalize 移走的 84% 重新排队(之前白烧 10 小时 GPU 的那个坑)。

选的顺序(能过纯度门 + 便宜 + 清晰):
  ① 站点: qupu123(通俗简谱, A4 300dpi, ~84% 单声部) > jianpucn > jianpujia
  ② 名字里带 吉他/五线谱/双谱/钢琴/总谱/器乐 的排最后(多半被纯度门挡掉, 省 GPU)
  ③ 页数少的优先(便宜)
  ④ 已经试过且失败(-bad/-empty)的排最后(除非没别的)

用法: py -3.13 tools/bench_pick.py [K=3] [--list train-work/bench_final100.txt]
产物: train-work/bench_todo.txt (目录名, 每行一个) + train-work/bench_pick.tsv (挑谱说明)
"""
import glob
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, "tools")
import batch_transcribe as BT

ARGS = sys.argv[1:]
K = int(ARGS[0]) if ARGS and ARGS[0].isdigit() else 3
LIST = ARGS[ARGS.index("--list") + 1] if "--list" in ARGS else "train-work/bench_final100.txt"

RESULT_DIRS = ["batch-out", "batch-out-dup", "batch-out-bad", "batch-out-empty", "batch-out-suspect"]
BAD_DIRS = {"batch-out-bad", "batch-out-empty"}
SITE_RANK = {"qupu123": 0, "jianpucn": 1, "jianpujia": 2}
HARD = re.compile(r"吉他|五线谱|双谱|钢琴|总谱|器乐|简线")

done_by = {}
for rd in RESULT_DIRS:
    for f in glob.glob(f"{rd}/*.txt"):
        done_by[os.path.basename(f)[:-4]] = rd

dirs = [d for d in glob.glob("images-prep/*/*") if os.path.isdir(d)]


def head(x):
    # 零宽字符先去掉(源站标题里有 U+200B), 否则 `算什么男人` 匹配不上
    x = re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", x)
    h = re.split(r"[（(\s　【\[《]", x.split("__")[0])[0]
    return h or x.split("__")[0]        # 空键会让以《 开头的谱全部塌成同一首


idx = {}
for d in dirs:
    idx.setdefault(head(os.path.basename(d)), []).append(d)

songs = [l.strip() for l in open(LIST, encoding="utf-8") if l.strip() and not l.startswith("#")]
todo, rep, have, missing = [], [], 0, []
for s in songs:
    cands = idx.get(s, [])
    results = [(c, done_by.get(BT.safe_name(os.path.basename(c)))) for c in cands]
    ok = [c for c, r in results if r and r not in BAD_DIRS]
    if ok:
        have += 1
        rep.append((s, len(cands), "已有: " + (done_by.get(BT.safe_name(os.path.basename(ok[0]))) or "?"), "", ""))
        continue
    if not cands:
        missing.append(s)
        rep.append((s, 0, "本地无谱目录", "", ""))
        continue

    def score(c):
        base = os.path.basename(c)
        site = base.split("__")[-1].split("-")[0] if "__" in base else "?"
        nimg = len([f for f in glob.glob(os.path.join(c, "*.jpg")) if "__pg" not in f])
        tried_bad = 1 if done_by.get(BT.safe_name(base)) in BAD_DIRS else 0
        return (SITE_RANK.get(site, 3), tried_bad, HARD.search(base) is not None, nimg)

    cands = sorted(cands, key=score)[:K]
    for c in cands:
        todo.append(os.path.basename(c))
    picked = "、".join(os.path.basename(c) for c in cands)
    rep.append((s, len(results), "挑 %d 个" % len(cands), picked, ""))

with open("train-work/bench_todo.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(todo) + ("\n" if todo else ""))
with open("train-work/bench_pick.tsv", "w", encoding="utf-8") as f:
    f.write("标题\t本地谱目录\t状态\t选中目录\t备注\n")
    for r in rep:
        f.write("\t".join(str(x) for x in r) + "\n")

print(f"基准集 {len(songs)} 首: 已有可用转写 {have}, 本地无谱目录 {len(missing)}, "
      f"本次挑 {len(todo)} 个目录要转")
if missing:
    print(f"本地无谱目录的 {len(missing)} 首(需联网抓): {'、'.join(missing)}")
print("-> train-work/bench_todo.txt / bench_pick.tsv")
