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

**定常成本**(2026-10-07 改): 本步原来要 54 分钟, 全部花在"给 4.7 万个目录找它在 batch-out 的
输出文件"上 —— 每个目录一次 `glob.glob("batch-out/*" + d[-10:] + ".txt")`, 每次都要把
2.6 万个文件的目录枚举一遍 ✗。现在把 `batch-out`、`kind2.tsv` 的读取各自**做一次**
(`batch-out` 索引 + 逐目录结果缓存), 之后全是内存里的字典查询。排序口径一个字没动。
"""
import csv, glob, os, re, sys, time
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

T0 = time.time()

rows = list(csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"))
for r in rows:
    r["nline"] = int(r["nline"]); r["pure"] = int(r["pure"])
    r["w"] = int(r["w"]); r["h"] = int(r["h"])
    r["wide"] = int(r.get("wide") or 0)
DIRS = len(rows)

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

# `batch-out` 索引(一次枚举, 替代原来每个目录一次的 glob)。
# **旧 glob 的语义**: 旧代码是 `glob.glob("batch-out/*" + d[-10:] + ".txt")`。
# glob 的通配符匹配**整个文件名**(不是子串搜索), 所以它要的是"文件名**以目录名后 10 个字符
# 结尾**" —— 等价于"文件名的末 10 字符 == d[-10:]"。实测反例: 目录
# `月亮代表我的心__jianpucn-100`(q='anpucn-100') 不会命中 `...__jianpucn-1001999.txt`
# (它的末 10 字符是 'cn-1001999'), 也不会命中 `...__jianpucn-1001.txt`(末 10 是 'npucn-1001')。
# 曾经按"任意 10 字符窗口"建索引, 把这两种文件都算成了命中 -> 音符数不同 -> 会换胜出版本 ✗。
# 所以索引键 = 文件名的**末 10 字符**; 不足 10 字符的文件名另立一张表(那时查询串就是整个目录名)。
# glob 的返回顺序 = 目录枚举顺序, 取列表第一个即与旧代码取 g[0] 相同。
BY_WIN10 = {}
BY_SHORT = {}
for _f in glob.glob("batch-out/*.txt"):
    _b = os.path.basename(_f)[:-4]
    if len(_b) >= 10:
        BY_WIN10.setdefault(_b[-10:], []).append(_f)
    else:
        BY_SHORT.setdefault(_b, []).append(_f)

def _count_notes(f):
    """读一个 txt 数音符。读不到就返回 -1(与旧代码"文件不在就算没转过"一致)。"""
    try:
        t = open(f, encoding="utf-8", errors="replace").read().split()
    except OSError:
        return -1
    n = 0
    for x in t:
        y = x.lstrip("qsdh,").rstrip("'.")
        if y and y[-1] in "1234567":
            n += 1
    return n

# 缓存按**查询串** d[-10:] 记账(不是按目录): 命中与否只取决于这 10 个字符, 同一查询串的结果
# 对所有目录都一样 —— 与旧代码"按目录缓存"给出的值相同, 只是更省读盘。
_NOTES = {}


def notes_of(d):
    """该目录已转出的音符数(没转过返回 -1)。"""
    q = d[-10:] if len(d) >= 10 else d
    if q in _NOTES:
        return _NOTES[q]
    g = BY_WIN10.get(q) if len(q) >= 10 else BY_SHORT.get(q)
    _NOTES[q] = _count_notes(g[0]) if g else -1
    return _NOTES[q]

# 打分口径一个字没改(仍是那 6 个字段、从优到劣依次比较), 只是**按需**算第 4 项(要读盘的那个):
# 只有前 3 项与对手打平才需要比"音符数"。旧版把 4.7 万行全部先算完 -> 每行一次读盘。
# ⚠ `functools.cmp_to_key` 不能配 `reverse=True` 用: reverse 会把比较器的返回值**取反**,
# 于是整个排序口径颠倒(实测: 会选中音符最少的版本)。这里比较器直接给出"谁在前", 不再用 reverse;
# 相等返回 0 -> 稳定排序保持 kind2.tsv 里的先后, 与旧版元组相等的处理一致 ✓。
def score(a, b):
    pa, pb = (1 if a["pure"] else 0), (1 if b["pure"] else 0)
    if pa != pb:
        return -1 if pa > pb else 1
    ja, jb = (1 if "简谱" in a["dir"] else 0), (1 if "简谱" in b["dir"] else 0)
    if ja != jb:
        return -1 if ja > jb else 1
    aa, ab = a["w"] * a["h"], b["w"] * b["h"]
    if aa != ab:
        return -1 if aa > ab else 1
    na, nb = notes_of(a["dir"]), notes_of(b["dir"])
    if na != nb:
        return -1 if na > nb else 1
    if a["nline"] != b["nline"]:
        return -1 if a["nline"] < b["nline"] else 1
    la, lb = len(a["dir"]), len(b["dir"])
    if la != lb:
        return -1 if la < lb else 1
    return 0

import functools                       # noqa: E402
_cmp = functools.cmp_to_key(score)

kept, dropped = [], []
for k, g in groups.items():
    g.sort(key=_cmp)          # 比较器已给出"谁在前"; **不能**再加 reverse=True(会把口径颠倒)
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
print(f"[耗时] {time.time()-T0:.1f}s (kind2 行 {DIRS}, 读过的 batch-out 文件 {len(_NOTES)})")
# 调试钩子: 把"每个目录数到的音符数"原样倒出来, 供新旧实现逐项对照(默认关, 不影响产线)。
_dp = os.environ.get("JP_PICK_NOTES_DUMP")
if _dp:
    with open(_dp, "w", encoding="utf-8", newline="") as _f:
        _w = csv.writer(_f, delimiter="\t")
        for _d in sorted({r["dir"] for r in rows}):
            _w.writerow([_d, notes_of(_d)])
    print(f"[dump] 每目录音符数 -> {_dp}")
print("\n多版本例子(前 10):")
for g in sorted([g for g in groups.values() if len(g) > 1], key=lambda x: -len(x))[:10]:
    print(f"  [{len(g)} 版] {norm_title(g[0]['dir'])[:24]}")
    for r in g[:3]:
        mark = " <-选中" if r is g[0] else ""
        print(f"        nline={r['nline']:3d} {r['w']}x{r['h']:<5d} {r['dir'][:40]}{mark}")
