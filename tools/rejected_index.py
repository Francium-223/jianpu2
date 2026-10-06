# -*- coding: utf-8 -*-
"""**拒绝名单** —— 把"这首已经判过不合格"记在案上, 让下一轮队列别再为它空转。

为什么要有它(实测 2026-10-05): 转写队列一轮 3412 条净增 +1、一轮 1764 条净增 0。队列里的
大半不是"新歌", 而是**已经被判过不合格**的图目录 —— 纯度门(非纯简谱)、0 音符/解析失败、
择优落选、被隔离的改编谱。这些判定**散在流水线各处、判完不留档**: 纯度门是**当场不写产物**
(`scan_backlog.py` 的注释原话: "挡掉时不写 txt, 所以看着像'没转'"), 于是下一次建队列
它们又变成"从没处理过的新目录"被拉进去重转一遍, 转完再被挡一次。净增自然恒等于 0。

判定必须**可复核**, 所以每一行都写清 `依据`(哪份证据文件 / 哪条规则名) —— 光有结论没法追责。

对外:
    is_rejected(dirname) -> bool     队列构建方用(带缓存, 名单缺失时安静返回 False)
    reason_of(dirname)   -> str      判定名, 没在名单里返回 ""
    main()               --rebuild / --census

`--rebuild` 是**只增不改**的: 先把文件里已有的条目原样收下, 只补新证据能证明的行,
既不删也不改任何已存在的判定(要翻案得手工改那一行, 那才是"改", 留痕)。重跑同一份证据
不会产生新行 —— 文件是稳定的, 不是"每次重建都换一批时间戳"。

判定口径**只认已有的证据**, 算不出来就**留空**并注明, 不猜:
    非纯简谱           kind2.tsv 里 pure=0 / batch-out-bad/ 里的隔离结果 / backlog_impure.txt
    解析失败           batch-out-empty/ 里的隔离结果(quarantine_empty.py: 0 音符)
    重复内容           batch-out-dup/ 里的隔离结果(finalize.py 第 4 步: 择优落选)
    隔离区-原因未留档   batch-out-suspect/ 里的隔离结果(**没有脚本判据**, 是人工挪的, 别替它编理由)
    无可用图片         图目录一层内没有扩展名匹配且字节 > 0 的图
    已在语料           `scores/*.txt` 里有同 `source=站-id`

用法:
    python3 tools/rejected_index.py --rebuild     # 从现有证据重算/补齐名单
    python3 tools/rejected_index.py --census      # 打印规模与分类统计
    python3 tools/rejected_index.py --rebuild --no-images   # 跳过图库普查(快, 但"无可用图片/已在语料"会留空)
"""
import argparse
import collections
import glob
import io
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2
WS = os.path.dirname(ROOT)                         # 工作区
WORK = os.path.join(ROOT, "train-work")

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

if HERE not in sys.path:
    sys.path.insert(0, HERE)
import corpus_index                                                 # noqa: E402

# 名单文件: 环境变量可换(自检要用), 默认 train-work/rejected.tsv
ENV_PATH = "JIANPU_REJECTED"
COLS = ("目录名", "站点", "站内id", "判定", "依据", "时间")

# `曲名__站-id` 后缀。口径与 corpus_index._SUFFIX 同形, 但这里**允许曲名为空**
# (隔离区文件名被 safe_name 洗过, 只剩后缀可靠)。
_SUFFIX = re.compile(r"__(?P<site>[a-z0-9]+)-(?P<sid>[0-9a-z_]+)$")
# 判定名(写进 TSV 的取值集合, 别随手加 —— 加之前先想清楚有没有证据)
V_IMPURE = "非纯简谱"
V_PARSE = "解析失败"
V_DUP = "重复内容"
V_ISO = "隔离区-原因未留档"
V_NOIMG = "无可用图片"
V_CORPUS = "已在语料"
VERDICTS = (V_IMPURE, V_PARSE, V_DUP, V_ISO, V_NOIMG, V_CORPUS)
# 同一目录被多条证据判过时, **判定取优先级最高的一条**(数字小的优先), 其余依据仍保留在 `依据` 里。
# 为什么 `已在语料` 排第一(实测 2026-10-05): `kind2.tsv` 是全库纯度扫描, 覆盖 **2.8 万个**图目录,
# 其中一大批**早就在语料里了** —— 那些目录既"已在语料"又"pure=0"。若让 `非纯简谱` 抢先,
# 名单读数会变成"7630 首被判非纯", 而真相是"多半已经有了、纯度判定只是对旧图目录的副产物"。
# 先报"已在语料"才是这个目录**当下**的真实状态, 也才配得上"下次别再拉进队列"这条用途。
PRIORITY = {V_CORPUS: 0, V_NOIMG: 1, V_IMPURE: 2, V_PARSE: 3, V_DUP: 4, V_ISO: 5}


def rejected_path():
    """名单文件路径(环境变量优先, 便于自检用临时文件)。"""
    return os.environ.get(ENV_PATH) or os.path.join(WORK, "rejected.tsv")


def split_name(name):
    """目录名/文件名 -> (站点, 站内id)。取不到返回 ("", "")。

    ⚠ **先拿原文去匹配, 匹配不上才去扩展名**(实测 2026-10-05 踩过):
    `os.path.splitext` 会把**曲名里的点**当成扩展名分隔符 —— `想你0.01秒__jianpucn-10204`
    被切成 `想你0` + `.01秒__jianpucn-10204`, 后缀就这么没了, 于是这首在名单里"不存在"
    (审计实测: 3097 条里有 3 条是这么漏的)。图目录**没有扩展名**, 不该走 splitext;
    只有隔离区那种 `...__站-id.txt` 才需要先去扩展名再试一次。
    """
    b = os.path.basename((name or "").strip())
    m = _SUFFIX.search(b)
    if m:
        return m.group("site"), m.group("sid")
    stem = os.path.splitext(b)[0]
    if stem != b:
        m = _SUFFIX.search(stem)
        if m:
            return m.group("site"), m.group("sid")
    return "", ""


def dir_key(name):
    """名单主键 —— **优先用 `站-id`**, 没有 `__站-id` 后缀时才退回目录名本身。

    为什么不用目录名当主键(实测 2026-10-05 踩过): 同一首歌的证据来自两侧 ——
      * `kind2.tsv` / `backlog_impure.txt` 给的是**完整图目录名**(带 `__站-id` 后缀);
      * `batch-out-bad/` 等隔离区给的是**被 `safe_name` 洗过的文件名**, 原目录名不可考,
        只能靠后缀 + 图库索引回填; `--no-images` 时连图库索引都没有, 回填不了。
    若拿目录名当主键, 这两侧会各写一行(同一首歌两笔账); 更糟的是加不加 `--no-images`
    会让同一侧**换成另一个键**, 于是"重跑一遍名单"就翻倍 —— 这是我自己踩出来的坑, 记在这里。
    用 `站-id` 当主键: 与 `is_rejected()` 的匹配口径一致, 天然去重, 也与图库索引在不在无关。
    """
    b = os.path.basename((name or "").strip())
    if not b:
        return ""
    site, sid = split_name(b)
    if site and sid:
        return "%s-%s" % (site, sid)
    return b


def row_key(row):
    """证据行/名单行 -> 主键。**只从 `站-id` 出**; 站点或站内id 缺一个就退回目录名。

    ⚠ 为什么不写 `dir_key("%s-%s" % (站点, 站内id))` 就完事: 两个都为空时会拼出一个 `"-"`,
    那是个**真非空字符串**, 于是所有"解析不出站-id"的行会一起塌进同一个键(实测踩过)。
    这里显式挡住。
    """
    site = (row.get("站点") or "").strip()
    sid = (row.get("站内id") or "").strip()
    if site and sid:
        return "%s-%s" % (site, sid)
    return dir_key(row.get("目录名") or "")


# ---------------------------------------------------------------- 读名单
_cache = {}


def _load():
    """读名单 -> {"by_dir": set, "by_src": set, "reason": {key: 判定}}。缺失/读不动就安静返回空。"""
    p = rejected_path()
    key = os.path.abspath(p)
    hit = _cache.get(key)
    # stat 变了就重读: 一个进程里名单被重算过也不会读到旧账
    try:
        st = os.stat(p)
        stamp = (st.st_mtime_ns, st.st_size)
    except OSError:
        stamp = None
    if hit and hit[0] == stamp:
        return hit[1]
    idx = {"by_dir": set(), "by_src": set(), "reason": {}, "reason_src": {}}
    if stamp is not None:
        try:
            f = io.open(p, encoding="utf-8", errors="replace")
        except OSError:
            f = None
        if f is not None:
            with f:
                head = f.readline().rstrip("\n").split("\t")
                try:
                    i_name = head.index("目录名")
                except ValueError:
                    i_name = 0
                try:
                    i_site = head.index("站点")
                except ValueError:
                    i_site = 1
                try:
                    i_sid = head.index("站内id")
                except ValueError:
                    i_sid = 2
                try:
                    i_reason = head.index("判定")
                except ValueError:
                    i_reason = 3
                for ln in f:
                    if not ln.strip():
                        continue
                    c = ln.rstrip("\n").split("\t")
                    if len(c) <= max(i_name, i_site, i_sid, i_reason):
                        continue
                    nm = c[i_name].strip()
                    site = c[i_site].strip()
                    sid = c[i_sid].strip()
                    # 目录名不可考的行(隔离区文件名被 safe_name 洗过)只留 `站-id`。
                    # ⚠ 这里**必须**照样收进索引 —— 早先的版本把空目录名直接 skip 掉,
                    #   于是"只有站-id 可靠"的行在名单里形同不存在(自检第 3 项就是这么红的)。
                    if not nm:
                        nm = "%s-%s" % (site, sid) if (site and sid) else ""
                    if not nm:
                        continue
                    idx["by_dir"].add(nm)
                    idx["reason"][nm] = c[i_reason].strip()
                    if not (site and sid):
                        site, sid = split_name(nm)
                    if site and sid:
                        # ⚠ **别叫 `key`** (2026-10-06 实测的缓存失效 bug): 函数开头 `key` 是
                        #   **名单文件的绝对路径**(缓存的主键), 这里若复用同名变量, 循环结束时
                        #   `key` 已经是**最后一行**的 `站-id`, 于是 `_cache[key] = ...` 把索引挂到
                        #   `qupu123-xihuanni` 这种键上 -> 用 **文件路径** 去取永远不命中,
                        #   **每一次 `is_rejected()` 都重读一遍 3.3 MB 名单**(实测 200 次调用 12.5 秒
                        #   = 62 ms/次; 队列 17,870 行判一遍要 ~18 分钟, 而它本该是内存查表)。
                        kk = "%s-%s" % (site, sid)
                        idx["by_src"].add(kk)
                        # ⚠ 判定名也要**按 `站-id` 存一份**: `is_rejected()` 是靠 `站-id` 命中的,
                        #   而 `reason` 的键是完整目录名 —— 队列那行的目录名与名单里记的目录名
                        #   只要差一个字符(改名/同名多目录), 就会变成"跳过了但说不出理由"(实测 6 条)。
                        #   `reason_src.setdefault` 而不是覆盖: 同一 `站-id` 多条证据时保留先到的判定,
                        #   与 `resolve_and_merge` 的优先级口径一致。
                        idx["reason_src"].setdefault(kk, c[i_reason].strip())
    _cache[key] = (stamp, idx)
    return idx


def is_rejected(dirname):
    """这个图目录在拒绝名单里吗。**带缓存**; 名单文件不存在时安静返回 False(不抛异常)。

    为什么要**同时**认目录名与 `站-id`: `batch-out-bad/` 这类隔离区的文件名被 `safe_name`
    洗过(空格变下划线), 原目录名已经不可考 —— 名单里那些行 `目录名` 留空, 只能靠后缀认。
    队列行的 `目录` 列带的正是原目录名, 两者都能对上。
    """
    idx = _load()
    b = os.path.basename((dirname or "").strip())
    if not b:
        return False
    if b in idx["by_dir"]:
        return True
    site, sid = split_name(b)
    if site and sid and ("%s-%s" % (site, sid)) in idx["by_src"]:
        return True
    return False


def reason_of(dirname):
    """判定名(没在名单里返回空串)。"""
    idx = _load()
    b = os.path.basename((dirname or "").strip())
    if b in idx["reason"]:
        return idx["reason"][b]
    site, sid = split_name(b)
    if site and sid:
        k = "%s-%s" % (site, sid)
        if k in idx["reason_src"]:
            return idx["reason_src"][k]
    return ""


# ---------------------------------------------------------------- 造名单
def _img_index():
    """**一次**遍历图库, 同时给出两样东西:

        dirs   [{目录名, 站点, 站内id, 可用图数}]   —— 无可用图片 / 已在语料 要用
        by_src {站-id: [目录名, ...]}              —— 隔离区回填目录名要用

    为什么合成一次: 图库有 2.9 万个目录, 走两遍要两分钟(实测), 而且两遍之间图库可能变,
    两次看到的账会不一致。用 `census_images_prep` 里的两支函数取目录与可用图,
    保证"可用图片"的定义与那次普查**逐字一致**(扩展名匹配 + 字节 > 0 + 只算目录一层)。
    """
    import census_images_prep as C
    root = C.images_root()
    if not os.path.isdir(root):
        return [], {}
    dirs, by_src = [], {}
    for name, path, _depth in C.walk_song_dirs(root):
        site, sid = split_name(name)
        if not (site and sid):
            got = C.parse_dir(name)
            site, sid = (got[1], got[2]) if got else ("", "")
        dirs.append({"目录名": name, "站点": site, "站内id": sid,
                     "可用图数": len(C.usable_images(path))})
        if site and sid:
            by_src.setdefault("%s-%s" % (site, sid), []).append(name)
    return dirs, by_src


def _rows_from_quarantine(sub, verdict, rule):
    """隔离区目录 -> 名单行。**只认后缀**, 原目录名不可考时留空(不瞎猜)。"""
    rows = []
    for p in sorted(glob.glob(os.path.join(ROOT, sub, "*.txt"))):
        base = os.path.basename(p)
        site, sid = split_name(base)
        rows.append({"目录名": "", "站点": site, "站内id": sid,
                     "判定": verdict, "依据": "%s/%s" % (sub, base)})
    return rows


def build_evidence(no_images=False):
    """把现有证据全部翻译成名单行。返回 (rows, notes, by_src)。**不猜**: 缺证据就少出数。"""
    rows, notes = [], []
    by_src = {}
    now = time.strftime("%Y-%m-%d %H:%M:%S")

    # R1 kind2.tsv: 全库纯度扫描的正式结论(pure=0 = 非纯简谱)。这是"非纯"最权威的一份账。
    p = os.path.join(WORK, "kind2.tsv")
    n = 0
    if os.path.isfile(p):
        with io.open(p, encoding="utf-8", errors="replace") as f:
            head = f.readline().rstrip("\n").split("\t")
            try:
                i_dir, i_pure = head.index("dir"), head.index("pure")
            except ValueError:
                i_dir, i_pure = 0, 3
            for ln in f:
                if not ln.strip():
                    continue
                c = ln.rstrip("\n").split("\t")
                if len(c) <= max(i_dir, i_pure) or c[i_pure].strip() != "0":
                    continue
                site, sid = split_name(c[i_dir])
                rows.append({"目录名": c[i_dir].strip(), "站点": site, "站内id": sid,
                             "判定": V_IMPURE, "依据": "kind2.tsv:pure=0"})
                n += 1
    else:
        notes.append("⚠ 缺 train-work/kind2.tsv -> 非纯简谱(全库口径)整类算不出来, 留空")
    notes.append("kind2.tsv pure=0 -> 非纯简谱 %d 条" % n)

    # R2/R4/R5/R6 四个隔离区。每个隔离区是**哪个脚本**挪的, 决定了判定名 —— 别混。
    for sub, verdict, rule in (("batch-out-bad", V_IMPURE, "apply_kind_filter.py(非纯简谱隔离区)"),
                               ("batch-out-empty", V_PARSE, "quarantine_empty.py(0 音符隔离区)"),
                               ("batch-out-dup", V_DUP, "finalize.py 第4步(择优落选隔离区)"),
                               ("batch-out-suspect", V_ISO, "batch-out-suspect(人工挪入, 无脚本判据)")):
        r = _rows_from_quarantine(sub, verdict, rule)
        for x in r:
            x["依据"] = "%s [%s]" % (x["依据"], rule)
        rows.extend(r)
        notes.append("%s -> %s %d 条" % (sub, verdict, len(r)))

    # R3 scan_backlog.py 当场挡下的非纯(这些**从来没写过产物**, 只有清单)
    p = os.path.join(WORK, "backlog_impure.txt")
    n = 0
    if os.path.isfile(p):
        with io.open(p, encoding="utf-8", errors="replace") as f:
            for ln in f:
                d = ln.strip()
                if not d:
                    continue
                site, sid = split_name(d)
                rows.append({"目录名": d, "站点": site, "站内id": sid,
                             "判定": V_IMPURE, "依据": "backlog_impure.txt(scan_backlog.py 纯度门当场挡下)"})
                n += 1
    else:
        notes.append("⚠ 缺 train-work/backlog_impure.txt -> 纯度门当场挡下的那批算不出来")
    notes.append("backlog_impure.txt -> 非纯简谱 %d 条" % n)

    # R7/R8 图库普查: 无可用图片 / 已在语料。这两类**必须**看图库, 跳过就整类留空。
    if no_images:
        notes.append("⚠ --no-images: 无可用图片 / 已在语料 两类**留空**(没看图库, 不猜)")
    else:
        srcs = corpus_index.existing_sources()
        ds, by_src = _img_index()
        n_no = n_cp = 0
        for d in ds:
            if d["可用图数"] == 0:
                rows.append({"目录名": d["目录名"], "站点": d["站点"], "站内id": d["站内id"],
                             "判定": V_NOIMG, "依据": "census_images_prep.py:目录一层可用图=0"})
                n_no += 1
            key = "%s-%s" % (d["站点"], d["站内id"])
            if d["站点"] and d["站内id"] and key in srcs:
                rows.append({"目录名": d["目录名"], "站点": d["站点"], "站内id": d["站内id"],
                             "判定": V_CORPUS, "依据": "scores/*.txt:source=%s (corpus_index)" % key})
                n_cp += 1
        notes.append("图库 %d 个目录 -> 无可用图片 %d 条 · 已在语料 %d 条" % (len(ds), n_no, n_cp))

    for r in rows:
        r["时间"] = now
    return rows, notes, by_src


def resolve_and_merge(rows, by_src=None):
    """把只有 `站-id` 的行尽力补回目录名(**唯一命中才补**, 多个候选就留空), 再按主键去重。

    为什么不去猜: `batch-out-bad` 里 `吻别` 有三个版本(不同站内 id), 靠曲名反推目录名
    必然张冠李戴。唯一才补、否则留空 + 靠 `站-id` 兜底匹配, 这条纪律不能松。
    """
    amb = collections.Counter()
    if by_src is None and not os.environ.get("JIANPU_REJECTED_SKIP_MAP"):
        try:
            _d, by_src = _img_index()
        except Exception as e:                                  # 图库读不动不该让造名单失败
            print("[rejected] 回填目录名跳过: %s" % e, file=sys.stderr)
            by_src = {}
    for r in rows:
        if r["目录名"] or not (r["站点"] and r["站内id"]):
            continue
        cand = (by_src or {}).get("%s-%s" % (r["站点"], r["站内id"]), [])
        if len(cand) == 1:
            r["目录名"] = cand[0]
        elif len(cand) > 1:
            amb["%s-%s" % (r["站点"], r["站内id"])] += 1

    merged = {}
    for r in rows:
        # 主键统一从 `站-id` 出(与 `_load()`/旧行读回用的是同一个函数), 目录名只作兜底
        k = row_key(r)
        if not k:
            continue
        if k in merged:
            old = merged[k]
            # 判定取优先级最高的(小者优先); 依据**只追加不去重地丢**, 便于事后复核"当初还判过什么"
            if PRIORITY.get(r["判定"], 99) < PRIORITY.get(old["判定"], 99):
                old["判定"] = r["判定"]
            if r["依据"] and r["依据"] not in old["依据"]:
                old["依据"] = old["依据"] + " ; " + r["依据"]
            continue
        merged[k] = dict(r)
    return merged, amb


def rebuild(no_images=False):
    path = rejected_path()
    rows, notes, by_src = build_evidence(no_images=no_images)
    fresh, amb = resolve_and_merge(rows, by_src)
    for n in notes:
        print("  " + n)
    if amb:
        print("  ⚠ 有 %d 个 `站-id` 对应多个图目录, 无法唯一定位 -> 那些行目录名留空(靠站-id 匹配)"
              % len(amb))

    old = {}
    if os.path.isfile(path):
        with io.open(path, encoding="utf-8", errors="replace") as f:
            head = f.readline().rstrip("\n").split("\t")
            for ln in f:
                if not ln.strip():
                    continue
                c = ln.rstrip("\n").split("\t")
                if len(c) < len(COLS):
                    c = c + [""] * (len(COLS) - len(c))
                r = dict(zip(head if len(head) == len(COLS) else COLS, c))
                # 旧行也走**同一个主键函数**: 先认 `站-id` 列, 没有才退回目录名。
                # 这样"上一版用目录名当键写下的账"不会在读回来时变成另一个键(否则会重复补一遍)。
                k = row_key(r)
                if k:
                    old[k] = r

    # **只增不改**: 旧条目原样收下, 新证据只补缺的键
    merged = dict(old)
    added = 0
    for k, r in fresh.items():
        if k in merged:
            continue
        merged[k] = r
        added += 1

    # 一条新证据都没补上、文件又已经在了 -> **一个字都不写**(连 mtime 都不动)。
    # 这样"重跑同一份证据"是真的空操作, 而不是"每次重建都换一遍时间戳"的假幂等。
    if added == 0 and os.path.isfile(path):
        print("名单 %s (无新增, 未改动)" % path)
        print("证据 %d 条 · 原有 %d 条 · **新增 0 条** · 合计 %d 条(只增不改)"
              % (len(fresh), len(old), len(merged)))
        return 0

    d = os.path.dirname(os.path.abspath(path))
    if d:
        os.makedirs(d, exist_ok=True)
    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\t".join(COLS) + "\n")
        for k in sorted(merged):
            r = merged[k]
            f.write("\t".join((r.get("目录名", ""), r.get("站点", ""), r.get("站内id", ""),
                               r.get("判定", ""), r.get("依据", ""), r.get("时间", ""))) + "\n")
    _cache.pop(os.path.abspath(path), None)
    print("名单 %s" % path)
    print("证据 %d 条 · 原有 %d 条 · **新增 %d 条** · 合计 %d 条(只增不改)"
          % (len(fresh), len(old), added, len(merged)))
    return 0


# ---------------------------------------------------------------- 统计
def read_rows(path=None):
    path = path or rejected_path()
    out = []
    if not os.path.isfile(path):
        return out
    with io.open(path, encoding="utf-8", errors="replace") as f:
        head = f.readline().rstrip("\n").split("\t")
        for ln in f:
            if not ln.strip():
                continue
            c = ln.rstrip("\n").split("\t")
            if len(c) < len(COLS):
                c = c + [""] * (len(COLS) - len(c))
            out.append(dict(zip(head if len(head) == len(COLS) else COLS, c)))
    return out


def census():
    path = rejected_path()
    rows = read_rows(path)
    print("名单 %s" % path)
    if not rows:
        print("  名单不存在或为空(不是错误 —— 队列会安静照跑)")
        return 0
    print("  规模 %d 条" % len(rows))
    print("\n  按判定:")
    for k, v in collections.Counter(r["判定"] for r in rows).most_common():
        print("    %-16s %5d (%.1f%%)" % (k, v, 100.0 * v / len(rows)))
    print("\n  按站点:")
    for k, v in collections.Counter((r["站点"] or "(未知)") for r in rows).most_common():
        print("    %-16s %5d" % (k, v))
    print("\n  按依据(规则名; 前 12):")
    def rule_of(s):
        # `依据` 形如 `scores/*.txt:source=qupu123-1 (corpus_index)` 或 `batch-out-bad/xxx.txt [apply_kind_filter.py]`
        # 统计时只取**规则名**, 具体到某一首的细节留在文件里供复核
        t = (s or "").split(" ; ")[0]
        if t.startswith("scores/*.txt"):
            return "scores/*.txt:source= (corpus_index)"
        if t.startswith("batch-out-"):
            return t.split(" [")[-1].rstrip("]") if " [" in t else t.split("/")[0]
        return t.split(":")[0] if ":" in t else t.split("(")[0].strip()
    for k, v in collections.Counter(rule_of(r["依据"]) for r in rows).most_common(12):
        print("    %5d  %s" % (v, k[:96]))
    blank = sum(1 for r in rows if not r["目录名"])
    print("\n  目录名留空 %d 条(只有站-id 可靠, 靠后缀兜底匹配)" % blank)
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rebuild", action="store_true", help="从现有证据重算/补齐名单(只增不改)")
    ap.add_argument("--census", action="store_true", help="打印名单规模与分类统计")
    ap.add_argument("--no-images", action="store_true", help="跳过图库普查(快, 两类留空)")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    if a.rebuild:
        return rebuild(no_images=a.no_images)
    if a.census:
        return census()
    ap.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
