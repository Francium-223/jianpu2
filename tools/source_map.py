# -*- coding: utf-8 -*-
"""给语料建"来源档案": 每份谱子来自哪个站、哪个 id、本地图在哪。

为什么要它: 谱子是第三方扫描件, 一旦有人来问出处/要求下架, 必须能立刻说出:
站点 + 站点 id + 本地图片目录。目录名里已经带了站点和 id(如 `浮夸__jianpucn-133666`),
这里把它整理成一张表, 不改动任何谱子文件本身(避免破坏下游解析)。

用法: py -3.13 tools/source_map.py
产物: train-work/source_map.tsv   （曲名/站点/站点ID/图片目录/是否已转写/检索URL）
"""
import glob
import html
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

SITE_URL = {
    "jianpucn": "http://www.jianpu.cn/search/?q={q}",      # jianpu.cn(按 id 的页址不统一, 给检索页)
    "qupu123": "https://www.qupu123.com/Search?keys={q}",
    "jianpujia": "https://www.jianpujia.com/search?q={q}",
}


def unescape_all(s):
    """反复解 HTML 实体直到不动 —— 源站有**双重转义**(`&amp;nbsp;`), 只解一次会剩下 `&nbsp;` ✗。"""
    for _ in range(5):
        t = html.unescape(s)
        if t == s:
            break
        s = t
    return s.replace("\u00a0", " ").strip()


# **mojibake 必须一起修** —— 爬虫把 UTF-8 文件名按 Latin-1 存了, jianpujia 整包名字都是
# `ä¸åé±...` 这种。谱子本体(to_jianpu_db)早就修过, 但档案里漏了这一步 -> HTML 上一片乱码,
# 这种名字**不能交付**。复用同一份修复函数, 不另写一份(免得两边行为不一致)。
sys.path.insert(0, "tools")
try:
    from to_jianpu_db import fix_mojibake, title_of
except Exception:                     # 兜底: 拿不到就原样返回
    def fix_mojibake(s):
        return s

    def title_of(s):
        return s


def clean_name(s):
    # 零宽字符也要去掉: 肉眼看不见, 但显示/匹配都会被它坑(U+200B 实测 63 个目录名里有)
    return re.sub(r"[\u200b-\u200f\u202a-\u202e\u2060\ufeff]", "", unescape_all(fix_mojibake(s)))


# 文本模型洗过的曲名(train-work/title_clean.tsv): 目录名 -> 清名。
# 交付/展示以它为准(用户口径: 除了必要的曲名没有多余的; 书名号也不要)。
try:
    from to_jianpu_db import load_clean_titles_soft
    CLEAN = load_clean_titles_soft()
except Exception:
    CLEAN = {}
print(f"曲名清洗表: {len(CLEAN)} 条", flush=True)

RESULT_DIRS = ["batch-out", "batch-out-dup", "batch-out-bad", "batch-out-empty", "batch-out-suspect"]

done = {}
for d in RESULT_DIRS:
    for f in glob.glob(f"{d}/*.txt"):
        done.setdefault(os.path.basename(f)[:-4], d)

# ---- 第一遍: 收集, 并识别"mojibake 且丢过字节"的副本 ----
recs = []
for d in sorted(glob.glob("images-prep/*/*")):
    if not os.path.isdir(d):
        continue
    full = os.path.basename(d)
    m = re.match(r"^(.*?)__([a-z0-9]+)-(\d+)$", full)
    title_part, site, sid = (m.group(1), m.group(2), m.group(3)) if m else (full, "", "")
    was_moji = fix_mojibake(title_part) != title_part
    # 曲名优先级: ① 文本模型洗过的清名(train-work/title_clean.tsv, 用户口径"除了曲名没有多余的")
    #             ② title_of(去爬虫后缀)
    #             ③ 只修 mojibake
    shown = CLEAN.get(full) or title_of(full) or clean_name(title_part)
    # `_` + 曾经是 mojibake = 有字节在爬虫保存前就被毁掉换成下划线了(如 `康定_歌`) ✗
    lossy = was_moji and "_" in shown
    recs.append({"dir": d, "full": full, "shown": shown, "site": site, "sid": sid,
                 "lossy": lossy, "was_moji": was_moji, "imgs": len(glob.glob(os.path.join(d, "*")))})

# ---- 同站点+同 id 的干净孪生: 坏副本显示时借用它的名字 ----
clean_by_key = {}
for r in recs:
    if r["site"] and r["sid"] and not r["lossy"]:
        k = (r["site"], r["sid"])
        if k not in clean_by_key or (r["was_moji"] and not clean_by_key[k]["was_moji"]):
            clean_by_key[k] = r

rows = []
n_borrowed = 0
for r in recs:
    title_out, note = r["shown"], ""
    if r["lossy"] and (r["site"], r["sid"]) in clean_by_key:
        twin = clean_by_key[(r["site"], r["sid"])]
        title_out = twin["shown"]
        note = "duplicate-of=" + twin["full"]
        n_borrowed += 1
    rows.append((title_out, r["site"], r["sid"], r["dir"].replace("\\", "/"), r["imgs"],
                 done.get(r["full"], ""),
                 SITE_URL.get(r["site"], "").format(q=title_out) if r["site"] else "", note))

with open("train-work/source_map.tsv", "w", encoding="utf-8") as f:
    f.write("曲名\t站点\t站点ID\t图片目录\t图片数\t转写结果目录\t检索URL\t备注\n")
    for r in rows:
        f.write("\t".join(str(x) for x in r) + "\n")
print(f"坏副本({n_borrowed} 个)借用干净孪生的名字")

by_site = {}
for r in rows:
    by_site[r[1] or "(无标记)"] = by_site.get(r[1] or "(无标记)", 0) + 1
print(f"谱目录 {len(rows)} 个 -> train-work/source_map.tsv")
for k, v in sorted(by_site.items(), key=lambda x: -x[1]):
    print(f"  {k:<12} {v:>6}")
print(f"其中已有转写结果的: {sum(1 for r in rows if r[5])}")
