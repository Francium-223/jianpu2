# -*- coding: utf-8 -*-
"""版本择优: 同一首歌常有多个版本(简谱/钢琴谱/吉他谱/不同分辨率), 只保留最优的一个。

打分(依次比较):
  1. 纯简谱优先(nline < 5)                 —— 非纯版本混着六线谱数字, 是污染源
  2. 标题里带"简谱"优先                     —— 站点的类型标注
  3. 分辨率大优先(w*h)                      —— 小图放大后发虚, 识别差(实测《十年》)
  4. **已转出音符数多优先**                 —— 只看几何会选中"图大但转不出东西"的版本
                                              (实测《童年》选中了只转出 53 音符的那版)
  5. nline 越小越纯   6. 标题短优先
输出: train-work/pick_best.tsv (title, 选中dir, 落选数) + train-work/drop_dup.txt(落选dir列表)
用法: py tools/pick_best.py
"""
import csv, glob, re, sys
sys.path.insert(0, "tools")
import os
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

rows = list(csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
for r in rows:
    r["nline"] = int(r["nline"]); r["pure"] = int(r["pure"])
    r["w"] = int(r["w"]); r["h"] = int(r["h"])
    r["wide"] = int(r.get("wide") or 0)

def norm_title(d):
    """把目录名规整成"歌名", 用于判重。"""
    t = re.sub(r"__(qupu123|jianpujia|jianpucn|qpcxw|gita)-\d+$", "", d)
    # 括号: 只剥"编配类"注释(调号/指法/乐器); 含词/曲/演唱等**区分信息**的要保留 ——
    # 否则 `童年`(罗大佑) 会和 `童年（晨枫词_陈雄曲）` 被并成一首, 丢歌(实测)。
    def _br(m):
        inner = m.group(1)
        if re.search(r"[词曲唱]|作词|作曲|演唱|原唱|佚名|词_|曲_", inner):
            return "(" + inner + ")"
        return ""
    t = re.sub(r"[（(【\[](.*?)[)）】\]]", _br, t)
    t = re.sub(r"[（(【\[].*$", "", t)                  # 未闭合的括号尾巴
    # 注意: 不能砍破折号后缀 —— `田光歌曲选-380放学的铃声响了` 这种"合集-编号+歌名"
    # 会被砍成合集名, 把 92 首不同的歌并成一首(实测)。
    t = re.sub(r"(简谱|钢琴谱|钢琴|吉他谱|吉他|正谱|双谱|总谱|弹唱谱|指弹谱|尤克里里谱|五线谱|歌词|伴奏谱|"
               r"原版编配|指法|C调|G调|F调|D调|A调|E调|B调|合唱谱|独奏|弹唱|扫描版|不同版本)", "", t)
    # 站点分类后缀: "童年 歌曲类 简谱" / "童年 吉他类 流行" -> 去掉"XX类 YY"
    t = re.sub(r"[\s　]*\S*类[\s　]+\S*$", "", t)
    t = re.sub(r"[\s　]*\S*类$", "", t)
    t = re.sub(r"[\s_·.,，。、:：;；!！?？'\"“”‘’/\\|+*#@&$%^~`<>\[\]{}]+", "", t)
    return t.lower().strip()

groups = {}
# **先按目录去重**(2026-09-22 修): 多页谱在 kind2.tsv 里是**每页一行**, 同一个谱目录会有 2-3 行
# (实测 16113 行 / 15270 个目录, 678 个目录有多行)。不去重的话, 同一个目录会同时出现在
# `kept` 和 `dropped` 里 —— 落选那行会把**刚选中的胜出者**搬进 batch-out-dup。
# 实测代价: 260 首歌的"择优胜出版"就这么从 scores 里消失了(如《铁血丹心》《千千阙歌》)。
# 去重规则: 取最纯(nline 小)、面积大的那一行代表该目录。
_best_row = {}
for r in rows:
    prev = _best_row.get(r["dir"])
    if prev is None or (r["nline"], -r["w"] * r["h"]) < (prev["nline"], -prev["w"] * prev["h"]):
        _best_row[r["dir"]] = r
if len(_best_row) != len(rows):
    print(f"按目录去重: {len(rows)} 行 -> {len(_best_row)} 个目录")
rows = list(_best_row.values())

for r in rows:
    k = norm_title(r["dir"])
    if len(k) < 2:              # 标题太短/空的, 不参与去重(避免误并)
        continue
    groups.setdefault(k, []).append(r)

SELECTED = {}
for line in glob.glob("batch-out/*.txt"):
    SELECTED[os.path.basename(line)[:-4]] = None
import batch_transcribe as _BT
_NOTES = {}

def notes_of(d):
    """该目录已转出的音符数(没转过返回 -1)。"""
    if d in _NOTES:
        return _NOTES[d]
    nm = _BT.safe_name(d)
    f = f"batch-out/{nm}.txt"
    if not os.path.exists(f):
        g = glob.glob("batch-out/*" + d[-10:] + ".txt")
        f = g[0] if g else None
    v = -1
    if f and os.path.exists(f):
        t = open(f, encoding="utf-8", errors="replace").read().split()
        v = sum(1 for x in t if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")
    _NOTES[d] = v
    return v

def score(r):
    # 关键: 也要看**转写结果的质量** —— 只看几何会选中"图大但转不出东西"的版本
    # (实测《童年》选中了只转出 53 音符的那版)。纯简谱之间, 音符多的通常更完整。
    return (
        1 if r["pure"] else 0,                       # 1. 纯简谱
        1 if "简谱" in r["dir"] else 0,               # 2. 标题带"简谱"
        r["w"] * r["h"],                              # 3. 分辨率(大图识别更准)
        notes_of(r["dir"]),                           # 4. 已转出音符数(多=更完整)
        -r["nline"],                                  # 5. 越纯越好
        -len(r["dir"]),                               # 6. 标题短
    )

kept, dropped = [], []
for k, g in groups.items():
    g.sort(key=score, reverse=True)
    kept.append(g[0])
    dropped += g[1:]

# 双保险: 胜出者绝不能出现在落选名单里(上面已按目录去重, 这里是防御性的 ——
# finalize 第 4 步会照着 drop_dup.txt 把文件搬进 batch-out-dup, 错一行就丢一首歌)。
_kept_dirs = {r["dir"] for r in kept}
_before = len(dropped)
dropped = [r for r in dropped if r["dir"] not in _kept_dirs]
if len(dropped) != _before:
    print(f"[防御] 落选名单里剔除了 {_before - len(dropped)} 个胜出者目录")

print(f"目录 {len(rows)} 个 -> 归并成 {len(groups)} 首歌; 选中 {len(kept)}, 落选 {len(dropped)}")
with open("train-work/pick_best.tsv", "w", encoding="utf-8", newline="") as f:
    w = csv.writer(f, delimiter="\t")
    w.writerow(["title", "dir", "nline", "w", "h", "others"])
    for g in sorted(groups.values(), key=lambda x: x[0]["dir"]):
        b = g[0]
        w.writerow([norm_title(b["dir"]), b["dir"], b["nline"], b["w"], b["h"], len(g) - 1])
with open("train-work/drop_dup.txt", "w", encoding="utf-8") as f:
    for r in dropped:
        f.write(r["dir"] + "\n")
print("选中 -> train-work/pick_best.tsv ; 落选 -> train-work/drop_dup.txt")
print("\n多版本例子(前 10):")
for g in sorted([g for g in groups.values() if len(g) > 1], key=lambda x: -len(x))[:10]:
    print(f"  [{len(g)} 版] {norm_title(g[0]['dir'])[:24]}")
    for r in g[:3]:
        mark = " <-选中" if r is g[0] else ""
        print(f"        nline={r['nline']:3d} {r['w']}x{r['h']:<5d} {r['dir'][:40]}{mark}")
