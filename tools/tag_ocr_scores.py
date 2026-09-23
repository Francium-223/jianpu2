# -*- coding: utf-8 -*-
"""给 OCR 那批谱**尽可能**打上标签; 实在打不出的写 `todo=add tags`。

用户口径(2026-09-23):
  「不是, 所以能打tag的都打tag。尽可能的。」「没有tag就写个todo=add tags。」
  「西方的你就不用动! 我让你标的是OCR那堆大批量的!!!」「我说的西方是seihou。western还是要照例的。」

所以:
  * 作用域**只有** jianpu-db-out/scores/*.txt(OCR 那 7296 份)。jianpu-db/scores 里的西方谱不动。
  * 依据(离线为主, 页面元数据可选):
      ① 批次名           = 当时爬的是谁的页面(images-prep/<批次>/<目录>__<站点>-<id>)
           - `jianpucn-<拼音>` / `qupu123-<拼音>` -> train-work/artist_pages{,2}.txt 的 拼音->中文
           - `jianpujia-art<id>` / `jianpujia-<id>` -> train-work/{jianpujia_artists,
             jianpujia_list_titles}.tsv 的 id->名字
      ② 目录名(mojibake 还原)= 源站原标题, 里面还留着 `[日]` `XXX演唱` `钢琴/吉他/口琴…`
      ③ title= 里的题材词   = 电影/电视剧/主题曲/儿歌/民歌/合唱/进行曲…
      ④ train-work/page_meta.tsv = 逐页抓来的**源站页面**元数据(tools/harvest_page_meta.py):
           歌手(jianpu.cn/jianpujia 页 title 里带) / 曲谱大类(qupu123: 通俗·民歌·少儿…)
  * 标出来的分两类写: 歌手(人名)与 `分类/…`(题材/语种/编配/曲谱大类)。分类带前缀,
    免得跟"某个人名恰好也是题材词"撞车。
  * 空标签的**才**写, 已经有 usertag 的不动(幂等, 可反复跑)。

用法:
  py -3.13 tools/tag_ocr_scores.py            # 只报告
  py -3.13 tools/tag_ocr_scores.py --apply    # 落盘
"""
import glob, io, os, re, sys
from collections import Counter

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
APPLY = "--apply" in sys.argv
SCORES = "jianpu-db-out/scores"
REPORT = "train-work/ocr_tag_plan.tsv"
PAGEMETA = "train-work/page_meta.tsv"


# ---------------- 缓存读取 ----------------
def fix_mojibake(s):
    """爬虫把 UTF-8 字节当 Latin-1 存过 -> 还原(同 tools/to_jianpu_db.py)。"""
    try:
        s.encode("latin-1")
    except UnicodeEncodeError:
        return s
    b = s.encode("latin-1")
    try:
        r = b.decode("utf-8")
        return r if r else s
    except Exception:
        pass
    r = re.sub(r"[\x00-\x1f\x7f-\x9f]", "", b.decode("utf-8", errors="ignore")).strip()
    return r if re.search(r"[\u4e00-\u9fff]", r) else s


def load_slug_names():
    """train-work/artist_pages{,2}.txt: 中文名 <tab> http://www.jianpu.cn/g/xx/<slug>.htm"""
    m = {}
    for p in ("train-work/artist_pages.txt", "train-work/artist_pages2.txt"):
        if not os.path.exists(p):
            continue
        for ln in io.open(p, encoding="utf-8", errors="replace"):
            c = ln.rstrip("\n").split("\t")
            if len(c) < 2:
                continue
            g = re.search(r"/g/[a-z]+/([a-z0-9]+)\.htm", c[1])
            if g:
                m[g.group(1)] = c[0].strip()
    # 缓存里缺的、与其它语料口径不一致的, 人工订正(都是现成事实, 不是猜)
    m.update({"beyond": "Beyond", "twins": "Twins",
              "chenyixun": "陈奕迅", "wangfei": "王菲", "shaniu": "沙妞",
              "zhangzuoying": "张靓颖"})
    return m


def load_id_names():
    """jianpujia 的 id -> 名字(两张缓存合起来)。"""
    m = {}
    for p in ("train-work/jianpujia_artists.tsv", "train-work/jianpujia_list_titles.tsv"):
        if not os.path.exists(p):
            continue
        for ln in io.open(p, encoding="utf-8", errors="replace"):
            c = ln.rstrip("\n").split("\t")
            if len(c) == 2 and c[0].isdigit() and c[1] and not c[1].startswith("ERR:"):
                if c[1] != "信息提示":
                    m[c[0]] = c[1]
    return m


def load_page_meta():
    """source -> (歌手, 曲谱大类)。tools/harvest_page_meta.py 的产出。"""
    m = {}
    if not os.path.exists(PAGEMETA):
        return m
    for ln in io.open(PAGEMETA, encoding="utf-8", errors="replace"):
        c = ln.rstrip("\n").split("\t")
        if len(c) >= 5:
            m[c[0]] = (c[3].strip(), c[4].strip())
    return m


SLUG = load_slug_names()
IDNAME = load_id_names()
PMETA = load_page_meta()

# 批次名里"本来就不是歌手页"的尾巴
GENERIC = re.compile(r"^(mp\d+|crawl|sweep|ready\d*|title|bench|nb|west|yequ|hot-crawl|pop|hk|kw|shuishou|test-.*)$")
# 分类(题材/来源), 与歌手区分: 写 `分类/xxx`
CATEGORY_BATCH = {"6223": "草原", "3462": "儿歌", "21436": "影视", "388": "主题曲",
                  "20961": "游戏", "21159": "世界名曲", "3094": "C调", "3098": "G调",
                  "3218": "D调", "3364": "A调", "102197": "E调"}
LANG = {"日": "日语", "英": "英语", "意": "意大利语", "法": "法语", "德": "德语",
        "俄": "俄语", "韩": "韩语", "粤": "粤语"}
INSTR = ["钢琴", "吉他", "古筝", "二胡", "琵琶", "葫芦丝", "萨克斯", "手风琴",
         "电子琴", "尤克里里", "口琴", "笛", "提琴", "陶笛"]
KIND = {"儿歌": r"儿歌|童谣|摇篮曲", "民歌": r"民歌|民谣|山歌|小调",
        "影视": r"电影|影片|电视剧|连续剧|主题曲|主题歌|插曲|片头|片尾|TVB",
        "合唱": r"合唱|重唱|齐唱|童声", "进行曲": r"进行曲|军歌|战歌|国歌",
        "器乐": r"独奏|协奏|练习曲|奏鸣曲|圆舞曲|前奏曲|变奏曲"}
# qupu123 页面 title 里的曲谱大类 -> 标签(它把"大类"写得很明确: _通俗曲谱_)
Q123_CAT = {"通俗": "通俗歌曲", "民歌": "民歌", "少儿": "儿歌", "美声": "美声",
            "合唱": "合唱", "外国": "外国歌曲", "戏曲": "戏曲", "流行": "通俗歌曲"}


def tag_of_batch(batch):
    """批次名 -> (歌手名, 分类名, 依据)"""
    if not batch:
        return "", "", "未回连到下载目录"
    tail = batch.split("-", 1)[1] if "-" in batch else batch
    if batch.startswith("jianpujia-art"):
        i = tail.replace("art", "", 1)
        if i in CATEGORY_BATCH:
            return "", CATEGORY_BATCH[i], f"jianpujia 列表页#{i}"
        return IDNAME.get(i, ""), "", (f"jianpujia 列表页#{i}" if i in IDNAME else f"jianpujia 列表页#{i} 查不到名字")
    if batch.startswith("jianpujia-cat"):
        i = tail.replace("cat", "", 1)
        return "", CATEGORY_BATCH.get(i, ""), f"jianpujia 分类页#{i}"
    if batch.startswith("jianpujia-") and tail.isdigit():
        if tail in CATEGORY_BATCH:
            return "", CATEGORY_BATCH[tail], f"jianpujia 列表页#{tail}"
        return IDNAME.get(tail, ""), "", (f"jianpujia 列表页#{tail}" if tail in IDNAME else f"jianpujia 列表页#{tail} 查不到名字")
    if GENERIC.match(tail):
        return "", "", "清单页/分类页(批次名不含歌手):" + tail
    if tail in SLUG:
        return SLUG[tail], "", "批次拼音 -> 歌手"
    return "", "", "批次名认不出:" + tail


def build_backlink():
    """source= 的**完整值**(站点-id) -> 下载目录。

    **必须带站点**: 站点 id 是各自站内的编号, 会**跨站撞号** ——
    实测 `jianpujia-149796`(Beyond_My_Beloved_Horizon) 与 `jianpucn-149796`(贝格的新春)
    同号; 只按 id 回连会把后者错配给前者, 标签就贴错了 ✗。
    """
    bl = {}
    for d in glob.glob("images-prep/*/*"):
        if not os.path.isdir(d):
            continue
        n, b = os.path.basename(d), os.path.basename(os.path.dirname(d))
        m = re.search(r"__([a-z0-9]+)-([0-9a-z_]+)$", n)
        if m:
            bl.setdefault(m.group(1) + "-" + m.group(2), (b, fix_mojibake(n)))
    return bl


BL = build_backlink()


def tags_for(src, batch, nm, title):
    """一份谱 -> (歌手, [分类…], [依据…])。"""
    tags, bases = [], []
    artist, cat, why = tag_of_batch(batch)
    pg_artist, pg_cat = PMETA.get(src, ("", ""))
    # 页面上的歌手最可信(页面自己写的 `XXX演唱`), 优先
    if pg_artist and pg_artist != artist:
        artist, why = pg_artist, "源站页面 title 带歌手"
    if artist:
        bases.append(why)
    # ② 目录名里的语种/编配
    for k, v in LANG.items():
        if f"[{k}]" in nm:
            c = "分类/" + v
            if c not in tags:
                tags.append(c)
                bases.append("目录名 [%s]" % k)
    for ins in INSTR:
        if ins in nm:
            c = "分类/" + ins + "谱"
            if c not in tags:
                tags.append(c)
                bases.append("目录名含" + ins)
    # 页面上的曲谱大类(qupu123: 通俗/民歌/少儿…)
    if pg_cat:
        c = "分类/" + Q123_CAT.get(pg_cat, pg_cat)
        if c not in tags:
            tags.append(c)
            bases.append("源站页面曲谱大类:" + pg_cat)
    if cat:
        c = "分类/" + cat
        if c not in tags:
            tags.append(c)
            bases.append(why)
    # ③ 曲名题材
    for k, rx in KIND.items():
        if re.search(rx, title):
            c = "分类/" + k
            if c not in tags:
                tags.append(c)
                bases.append("曲名含" + k + "词")
    return artist, tags, bases


if __name__ == "__main__":
    files = sorted(glob.glob(SCORES + "/*.txt"))
    rows, stat = [], Counter()
    tagged = todo = already = 0
    artist_cnt, cat_cnt = Counter(), Counter()

    for f in files:
        t = io.open(f, encoding="utf-8", errors="replace").read()
        base = os.path.basename(f)
        g = re.search(r"(?m)^source=(\S+)$", t)
        src = g.group(1) if g else ""
        if re.search(r"(?m)^usertag=[^\s]", t):
            already += 1
            stat["已有标签(不动)"] += 1
            continue
        batch, nm = BL.get(src, ("", ""))
        ti = re.search(r"(?m)^title=(.*)$", t)
        ti = ti.group(1) if ti else ""
        artist, cats, bases = tags_for(src, batch, nm, ti)
        alltags = ([artist] if artist else []) + cats
        rows.append((base, src, batch, "|".join(alltags), " / ".join(bases)))
        if alltags:
            tagged += 1
            stat["能打标签"] += 1
            if artist:
                artist_cnt[artist] += 1
            for x in cats:
                cat_cnt[x] += 1
        else:
            todo += 1
            stat["打不出 -> todo=add tags"] += 1

    N = len(files)
    print(f"OCR 谱 {N} 份  (页面元数据 {len(PMETA)} 条)")
    for k, v in stat.items():
        print(f"   {k:<26} {v:>5}")
    print(f"\n  能打标签 {tagged}/{N - already} = {tagged / max(1, N - already) * 100:.1f}%  (在未标的那批里)")
    print(f"  首位标签(歌手为主) {len(artist_cnt)} 个; 分类标签 {len(cat_cnt)} 个")
    print("   top 标签: " + " | ".join(f"{k}{v}" for k, v in artist_cnt.most_common(15)))
    print("   top 分类: " + " | ".join(f"{k}{v}" for k, v in cat_cnt.most_common(15)))

    with io.open(REPORT, "w", encoding="utf-8", newline="\n") as g:
        g.write("谱文件\tsource\t批次\t标签\t依据\n")
        for r in rows:
            g.write("\t".join(r) + "\n")
    print(f"\n  明细 -> {REPORT}")

    if APPLY:
        n_tag = n_todo = n_clean = 0
        for base, src, batch, tagcell, _ in rows:
            # 标签在这一行里是 `A|B` 的字符串(见上面 rows.append)。**必须再切开**:
            # `",".join("毛不易")` = `"毛,不,易"` —— 字符串会被当字符序列逐字加逗号,
            # 写进 usertag= 后 default_parse 按逗号一切就成了三个单字标签(实测踩过: 全批 3308 份都这样)。
            tags = [x for x in tagcell.split("|") if x]
            p = SCORES + "/" + base
            raw = io.open(p, encoding="utf-8", errors="replace", newline="").read()
            nl = "\r\n" if "\r\n" in raw else "\n"
            out, done_ut, done_todo = [], False, False
            for ln in raw.split(nl):
                s = ln.strip()
                if tags and s == "todo=add tags":
                    # 已经拿到标签了 -> **摘掉** todo(否则文件里同时留着"有标签"和"待补标签")
                    continue
                if tags and s.startswith("usertag=") and not done_ut and s == "usertag=":
                    out.append("usertag=" + ",".join(tags))
                    done_ut = True
                    continue
                if not tags and s.startswith("todo=") and not done_todo:
                    out.append("todo=add tags")
                    done_todo = True
                    continue
                out.append(ln)
            txt = nl.join(out)
            if tags and not done_ut:
                txt = txt.replace("usertag=\n" if nl == "\n" else "usertag=\r\n",
                                  "usertag=" + ",".join(tags) + nl, 1)
                if not re.search(r"(?m)^usertag=" + re.escape(",".join(tags)) + r"$", txt):
                    txt = txt.replace("%--", "usertag=" + ",".join(tags) + nl + "%--", 1)
            if not tags and not done_todo and "todo=add tags" not in txt:
                txt = txt.replace("%--", "todo=add tags" + nl + "%--", 1)
            io.open(p, "w", encoding="utf-8", newline="").write(txt)
            if tags:
                n_tag += 1
            else:
                n_todo += 1
        # 收尾: 上一轮"打不出"留下的 `todo=add tags`, 这一轮已经有标签了 -> 摘掉
        # (否则文件里同时写着"有标签"和"待补标签"; 实测 2685 份都这样)
        for f in files:
            raw = io.open(f, encoding="utf-8", errors="replace", newline="").read()
            if "todo=add tags" not in raw:
                continue
            if not re.search(r"(?m)^usertag=[^\s]", raw):
                continue
            nl = "\r\n" if "\r\n" in raw else "\n"
            out = [ln for ln in raw.split(nl) if ln.strip() != "todo=add tags"]
            io.open(f, "w", encoding="utf-8", newline="").write(nl.join(out))
            n_clean += 1
        print(f"\n  已落盘: 写了标签 {n_tag} 份, 写了 todo {n_todo} 份, 摘掉多余 todo {n_clean} 份 -> {SCORES}/")
    else:
        print("\n  (未落盘; 加 --apply 才写)")
