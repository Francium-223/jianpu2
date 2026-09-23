# -*- coding: utf-8 -*-
"""把 OCR 那批谱的"标签素材"从本地缓存里抠出来, 落成一张可复核的映射表。

上游事实(实测, 不猜):
  * OCR 输出 7296 份(jianpu-db-out/scores/), **usertag 非空 0 份** —— 见 to_jianpu_db.py:230 的
    `"tag=",  # TODO: 标签(人工补; 也可从爬取来源的歌手名自动带出)`。
  * 其中 7292/7296 = 99.9% 能按 `source=<site>-<id>` 回连到 images-prep 里那个原始下载目录。
  * 回连上的目录分 153 个"爬取批次", 批次名本身就是**当时爬的是谁的页面**:
      jianpucn-<拼音歌手> / qupu123-<拼音歌手>  -> 拼音可反查中文
      jianpujia-art<id>                        -> train-work/jianpujia_artists.tsv(id->中文名)
    这类批次名 = 可用的标签素材。
  * qupu123-crawl / jianpujia-<数字> / ready* / *-title 是**清单页/分类页**, 批次名不含歌手
    -> 只有目录名里的"(XXX演唱)"能救, 实测全库仅 13.3% 目录带这类标记, 噪声大, 这里**不当真源**,
       只输出"待定"。

输出(给人看/给下游用):
  train-work/ocr_tag_map.tsv    批次 -> 标签  (键 = 批次名)
  train-work/ocr_tag_plan.tsv   每份谱 -> 拟写 usertag (或空 = 待定)
"""
import glob, io, os, re, sys
from collections import Counter, defaultdict

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")

# ---- ① 目录 -> 批次(site-id 为键, 与 source= 同构) ----
batch_of = {}
for d in glob.glob("images-prep/*/*"):
    if not os.path.isdir(d):
        continue
    n, b = os.path.basename(d), os.path.basename(os.path.dirname(d))
    m = re.search(r"__([a-z0-9]+)-([0-9a-z_]+)$", n)
    if m:
        batch_of.setdefault(m.group(1) + "-" + m.group(2), b)

# ---- ② 拼音 -> 中文(歌手名以 jianpu-db 里已有的写法为准) ----
PINYIN = {
    "beyond": "Beyond", "caiyilin": "蔡依林", "caiqin": "蔡琴", "chenyixun": "陈奕迅",
    "denglijun": "邓丽君", "dengziqi": "邓紫棋", "dongwenhua": "董文华", "feiyuqing": "费玉清",
    "fenghuangchuanqi": "凤凰传奇", "gaoshengmei": "高胜美", "hanhong": "韩红", "hanlei": "韩磊",
    "huachenyu": "华晨宇", "jiangdawei": "蒋大为", "jiangyangzhuoma": "降央卓玛",
    "jiangyuheng": "姜育恒", "liangjingru": "梁静茹", "liguyi": "李谷一", "lijian": "李健",
    "linjunjie": "林俊杰", "lironghao": "李荣浩", "liudehua": "刘德华", "liuhuan": "刘欢",
    "liuruoying": "刘若英", "lizongsheng": "李宗盛", "luodayou": "罗大佑", "maobuyi": "毛不易",
    "mengtingwei": "孟庭苇", "mowenwei": "莫文蔚", "naying": "那英", "panmeichen": "潘美辰",
    "pushu": "朴树", "qiqin": "齐秦", "qiyu": "齐豫", "renxianqi": "任贤齐", "shaniu": "沙妞",
    "songzuying": "宋祖英", "sunyanzi": "孙燕姿", "suxiaoming": "苏小明", "tenggeer": "腾格尔",
    "tianzhen": "田震", "tongange": "童安格", "twins": "Twins", "wangfei": "王菲",
    "wangfeng": "汪峰", "wulantuya": "乌兰图雅", "wuyuetian": "五月天", "xuezhiqian": "薛之谦",
    "xumeijing": "徐美静", "xuwei": "许巍", "yanweiwen": "阎维文", "zhanghuimei": "张惠妹",
    "zhangmingmin": "张明敏", "zhangxinzhe": "张信哲", "zhangxueyou": "张学友", "zhangye": "张也",
    "zhangyusheng": "张雨生", "zhangzuoying": "张左影", "zhouchuanxiong": "周传雄",
    "zhouhuajian": "周华健", "zhoujielun": "周杰伦", "zhoushen": "周深",
}

# ---- ③ 歌手 id -> 中文(jianpu-db 上游给的缓存) ----
art = {}
for ln in io.open("train-work/jianpujia_artists.tsv", encoding="utf-8"):
    c = ln.rstrip("\n").split("\t")
    if len(c) == 2 and c[1].isdigit():
        art[c[1]] = c[0]

GENERIC = re.compile(r"^(mp\d+|crawl|sweep|ready\d*|title|bench|nb|west|yequ|hot-crawl|pop|test-.*|\d+)$")


def tag_of(batch):
    """批次名 -> (标签, 依据)。认不出歌手就返回 ('', 原因)。"""
    if not batch:
        return "", "无批次"
    tail = batch.split("-", 1)[1] if "-" in batch else batch
    if batch.startswith("jianpujia-art"):
        nm = art.get(tail)
        return (nm, "jianpujia 歌手页 id=" + tail) if nm else ("", "jianpujia 歌手页 id 未收录:" + tail)
    if batch.startswith("jianpujia-cat"):
        return "", "jianpujia 分类页#" + tail + "(分类名未随页存下)"
    if GENERIC.match(tail):
        return "", "清单页/分类页:" + tail
    if tail in PINYIN:
        return PINYIN[tail], "批次拼音 -> 歌手"
    if re.fullmatch(r"\d+", tail):
        nm = art.get(tail)
        return (nm, "jianpujia 数字 id=" + tail) if nm else ("", "数字 id 未收录:" + tail)
    return "", "批次名认不出歌手:" + tail


FS = sorted(glob.glob("jianpu-db-out/scores/*.txt"))
plan = []
tagged = 0
for f in FS:
    t = io.open(f, encoding="utf-8", errors="replace").read()
    m = re.search(r"(?m)^source=(\S+)$", t)
    s = m.group(1) if m else ""
    b = batch_of.get(s, "")
    tg, why = tag_of(b)
    if tg:
        tagged += 1
    plan.append((os.path.basename(f)[:-4], s, b, tg, why))

with io.open("train-work/ocr_tag_plan.tsv", "w", encoding="utf-8", newline="\n") as g:
    g.write("谱文件\tsource\t批次\t拟写usertag\t依据\n")
    for r in plan:
        g.write("\t".join(r) + "\n")

by_batch = defaultdict(lambda: [0, "", ""])
for _, _, b, tg, why in plan:
    k = b or "?未回连"
    by_batch[k][0] += 1
    by_batch[k][1] = tg or by_batch[k][1]
    by_batch[k][2] = why
with io.open("train-work/ocr_tag_map.tsv", "w", encoding="utf-8", newline="\n") as g:
    g.write("批次\t谱数\t标签\t依据\n")
    for k, (c, tg, why) in sorted(by_batch.items(), key=lambda x: -x[1][0]):
        g.write(f"{k}\t{c}\t{tg}\t{why}\n")

N = len(plan)
print(f"OCR 谱 {N} 份 -> train-work/ocr_tag_plan.tsv / ocr_tag_map.tsv")
print(f"  能从本地缓存自动定标签: {tagged}/{N} = {tagged/N*100:.1f}%  (待定 {N-tagged} 份 = {(N-tagged)/N*100:.1f}%)")
print(f"  涉及的歌手标签 {len(set(r[3] for r in plan if r[3]))} 个:")
cnt = Counter(r[3] for r in plan if r[3])
print("     " + " | ".join(f"{k} {v}" for k, v in cnt.most_common()))
print("\n  待定的批次(按份数):")
for k, (c, tg, why) in sorted(by_batch.items(), key=lambda x: -x[1][0]):
    if not tg:
        print(f"     {k:<26} {c:>5}  {why}")
