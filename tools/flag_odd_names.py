#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""揪出"不像正常曲名"的 title, 并在文件里打 `todo=refine the filename`（**字段**, 不是注释）。

用户口径(2026-09-22): 正常名字 = **除了必要的曲名, 没有多余的**。反例:
  `夜的草原海的深_又名：夜的草原，海的深_夜的草原_海的`   重复 + 碎片
  `小白_白又白钢琴` / `幸福_庄_汉语版`                     混进了乐器/语言版本
  `康定_歌`  ← 应该是《康定情歌》, 中间的"情"被替换成了下划线(丢字)

判据(每条都能说清理由; 命中只打标记, 不自动改, 误报可由人工复核后清掉):
  ① 含下划线          —— 爬虫把空格/斜杠替换成 `_`, 常伴随丢字(`康定_歌`)
  ② 元信息词          —— 词/曲/演唱/记谱/编配/又名/版本/汉语版/粤语版…
  ③ 乐器/编配         —— 钢琴/吉他/尤克里里/指弹/弹唱/伴奏/纯音乐/和弦…
  ④ 调号或速度        —— C调/G调/4-4/♩=…
  ⑤ 疑似整段重复      —— 归一化后两半相同且断点无空白
  ⑥ 过长(>24 字)      —— 正常曲名很少这么长
  ⑦ 占位名            —— `未命名-*`
  ⑧ 首尾余留符号      —— 开头/结尾还有 `_` `-` `·` 空格

用法:
  py -3.13 tools/flag_odd_names.py            # 只报告
  py -3.13 tools/flag_odd_names.py --apply    # 在 scores 里写 todo=refine the filename
"""
import html
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

APPLY = "--apply" in sys.argv
DIR = "jianpu-db-out/scores"
TODO = "todo=refine the filename"

# 元信息判据要**收紧**: 只认"标签式"词(演唱/记谱/编配/版本…), 以及 `X词Y曲` 这种署名格式。
# 不能直接匹配单个 `词`/`曲` —— 《一曲相思》《词不达意》这类正常歌名会被误判 ✗
# (实测放宽版一次标了 612 份, 假阳性一堆)。
META = re.compile(r"(作词|作曲|词曲|记谱|编配|演唱|原唱|又名|选自|专辑|版本|汉语版|粤语版|国语版|"
                  r"普通话|闽南语|日语版|英文版|女声版|男声版|独唱版|童声版|翻唱|改编)")
CREDIT = re.compile(r"[\u4e00-\u9fff]{2,4}词[\u4e00-\u9fff]{0,4}曲")     # 李良词李炫春曲
INSTR = re.compile(r"(钢琴|吉他|尤克里里|乌克丽丽|指弹|弹唱|扫弦|架子鼓|爵士鼓|萨克斯|小提琴|大提琴|"
                   r"古筝|琵琶|二胡|竹笛|笛子|葫芦丝|陶笛|口琴|手风琴|电子琴|竖琴|卡林巴|拇指琴|"
                   r"伴奏|纯音乐|和弦|简和谱|双谱|五线谱|六线谱)")
KEYSIG = re.compile(r"([A-G][#b]?\s*调|\d\s*/\s*\d\s*拍|♩|BPM)")
EDGE = re.compile(r"^[\s_\-·、,，.]+|[\s_\-·、,，]+$")


def norm(x):
    return re.sub(r"[^0-9A-Za-z\u4e00-\u9fff]", "", x).lower()


def doubled(t):
    n = len(t)
    for i in range(max(1, n // 3), n - max(1, n // 3) + 1):
        if t[i - 1].isspace() or t[i].isspace():
            continue
        a, b = norm(t[:i]), norm(t[i:])
        if len(a) >= 3 and a == b:
            return True
    return False


def verdict(title):
    """-> 命中的判据列表(空 = 看着正常)"""
    t = html.unescape(title)
    why = []
    # ① 下划线: 中文名里的 `_` 基本是"爬虫丢字"的记号(`康定_歌`), 要人看;
    # 但**纯英文/数字名里的 `_` 是本管线的空格约定**(`Because_of_You` 就是文件名里的空格),
    # 判它可疑是误报 ✗ —— 实测 9 条这样的假警报。
    if "_" in t and re.search(r"[\u4e00-\u9fff]", t):
        why.append("①下划线(疑似丢字)")
    if META.search(t) or CREDIT.search(t):
        why.append("②元信息")
    if INSTR.search(t):
        why.append("③乐器/编配")
    if KEYSIG.search(t):
        why.append("④调号速度")
    if doubled(t):
        why.append("⑤整段重复")
    if len(t) > 24:
        why.append("⑥过长")
    if t.startswith("未命名"):
        why.append("⑦占位名")
    if EDGE.search(t):
        why.append("⑧首尾余留符号")
    # ⑨ 站点噪声: 曲名后面跟着 >=6 位连续数字(站点/用户 ID), 如 `青花瓷 完美05895464`。
    # 阈值为 6 是为了放过 `1874`(陈奕迅的歌, 4 位)这类真·数字歌名 ✓
    if re.search(r"\d{6,}", t):
        why.append("⑨站点ID噪声")
    return why


rows = []
for fn in sorted(os.listdir(DIR)):
    if not fn.endswith(".txt"):
        continue
    p = os.path.join(DIR, fn)
    txt = open(p, encoding="utf-8", errors="replace").read()
    m = re.search(r"^title=(.*)$", txt, re.M)
    if not m:
        continue
    title = m.group(1).strip()
    why = verdict(title)
    if why:
        rows.append((fn, title, "、".join(why), bool(re.search(r"^todo=", txt, re.M))))

from collections import Counter
cnt = Counter()
for _fn, _t, w, _has in rows:
    for k in w.split("、"):
        cnt[k] += 1
print(f"scores {len(os.listdir(DIR))} 份; 名字可疑的 **{len(rows)}** 份 "
      f"(其中已有 todo= 的 {sum(1 for r in rows if r[3])})")
for k, v in sorted(cnt.items()):
    print(f"   {k:<18} {v}")
print("\n按判据数排序的前 16 个例子：")
for fn, title, why, has in sorted(rows, key=lambda r: -len(r[2].split("、")))[:16]:
    print(f"   [{why}] {title[:52]}")
print("\n用户点名的名字，逐个看（含**目录名派生**的显示名 —— scores 里可能压根没有它）：")
sys.path.insert(0, "tools")
try:
    from to_jianpu_db import title_of
except Exception:
    def title_of(x):
        return x
scored_titles = {r[1] for r in rows}
all_titles = set()
for fn in os.listdir(DIR):
    if fn.endswith(".txt"):
        m = re.search(r"^title=(.*)$", open(os.path.join(DIR, fn), encoding="utf-8",
                                            errors="replace").read(800), re.M)
        if m:
            all_titles.add(m.group(1).strip())
for probe in ("夜的草原海的深_又名：夜的草原，海的深_夜的草原_海的", "小白_白又白钢琴",
              "幸福_庄_汉语版", "康定_歌", "月亮代表我的心", "一分钱", "世上只有妈妈好"):
    if probe in scored_titles:
        hit = [r for r in rows if r[1] == probe][0]
        print(f"   {probe[:34]:36s} -> 可疑[{hit[2]}]")
    elif probe in all_titles:
        print(f"   {probe[:34]:36s} -> 看着正常 ✓")
    else:
        print(f"   {probe[:34]:36s} -> **scores 里没有这个名字**（来自目录名/HTML 显示名）")

if APPLY:
    n = 0
    for fn, title, why, has in rows:
        if has:
            continue
        p = os.path.join(DIR, fn)
        txt = open(p, encoding="utf-8", errors="replace").read()
        if re.search(r"^source=", txt, re.M):
            txt = re.sub(r"^(source=.*)$", r"\1\n" + TODO, txt, count=1, flags=re.M)
        else:
            txt = txt.replace("%--", TODO + "\n%--", 1)
        open(p, "w", encoding="utf-8").write(txt)
        n += 1
    print(f"\n已写入 {TODO}: {n} 份")
else:
    print(f"\n（只报告；加 --apply 才写 {TODO}）")

# ---------------- 目录名(HTML 显示的那批)也一起检测 ----------------
# scores 里的 title= 已经被 title_of 洗过一轮, 用户在 HTML 上看到的是**目录名派生**的显示名,
# 两者不是一套东西(实测用户点名的 4 个名字在 scores 里压根没有 ✗)。这里把显示名也扫一遍,
# 结果写成 TSV 供 HTML/来源档案显示, 避免两个脚本各写一套判据。
import glob
try:
    from to_jianpu_db import title_of as _title_of
except Exception:
    def _title_of(x):
        return x
dir_rows = []
for d in sorted(glob.glob("images-prep/*/*")):
    if not os.path.isdir(d):
        continue
    full = os.path.basename(d)
    shown = _title_of(full) or full
    why = verdict(shown)
    if why:
        dir_rows.append((full, shown, "、".join(why)))
with open("train-work/odd_names.tsv", "w", encoding="utf-8") as f:
    f.write("目录名\t显示名\t判据\n")
    for r in dir_rows:
        f.write("\t".join(r) + "\n")
dcnt = Counter()
for _d, _s, w in dir_rows:
    for k in w.split("、"):
        dcnt[k] += 1
print(f"\n目录名(HTML 显示名) {len(glob.glob('images-prep/*/*'))} 个; 可疑 **{len(dir_rows)}** 个 "
      f"-> train-work/odd_names.tsv")
for k, v in sorted(dcnt.items()):
    print(f"   {k:<18} {v}")
print("   例：")
for _d, _s, w in dir_rows[:6]:
    print(f"     [{w}] {_s[:52]}")
