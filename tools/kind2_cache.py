# -*- coding: utf-8 -*-
"""kind_detect2 的增量判定缓存(唯一实现)。

**为什么需要**: `kind_detect2` 每轮把**全库**图目录重扫一遍(实测 81 分钟 / 46,890 页)。
其中 `measure()`(读图+缩放+逐行数暗段+谱线证据)占 73 分钟, 而且**同一张图的结论永远不变** ——
图不重新抓, nline/wide/staff 就不会变。重扫的大部分时间是在重算已知答案 ✗。

**增量判据(两级, 缺一不可, 合起来等价于全量重扫)**
  1. `dir_mtime` —— 目录自身的 mtime。NTFS 上**新增/删除**目录里的文件会改它
     (实测: 建文件 True / 删文件 True / **改文件内容 False**), 所以它能抓到
     "多了一页/少了一页" -> 必须重挑谱页。
  2. `page_path + page_size + page_mtime` —— 被挑中的那页的身份。抓"同一路径的图被换掉了"
     (dir_mtime 抓不到这种, 见上)。
  命中(两者都没变)时连 `pick_page` 都不用做 —— 它要逐图 `PIL.open` 读文件头拿尺寸,
  实测平均 4.6 ms/目录、中位 1.2 ms, 18 万个目录就是十几分钟; 快路径只花 2 次 stat。

**关键取舍: 图不在了怎么办**
滑窗会删旧图。若某目录的图已被删, 全量重扫会**静默丢掉这一行**(`pick_page` 返回 None -> continue),
于是 `kind2.tsv` 里那首歌的判定消失 -> `pick_best` 的分组少一个候选 -> 可能改选版本 ✗。
所以: **`dir_mtime` 变化/取不到时, 只要缓存里有这个目录的既有判据, 就复用既有判据**
(理由: 判据的唯一输入是那张图的像素; 像素没了不等于判据失效, 而重算已不可能 ✓)。
反过来, 缓存里**没有**记录的目录(含"从来没挑到过谱页"的), 照旧走全量逻辑 —— 绝不能凭空造行 ✗。

**参数也是判据的一部分**: `JP_BADLINE/JP_PURITY2/JP_STAFFMAX/JP_STAFFHARD/JP_THINMAXW/JP_WIDELINE`
变了就整份缓存作废(存进每一行的 `pkey` 列), 否则会拿旧口径的判定冒充新口径的 ✗。

缓存文件: `train-work/kind2_cache.tsv`(**可安全删除**: 删了就是退回全量重扫, 结论不变)。
"""
import csv, os, sys

# 缓存文件路径。默认 train-work/kind2_cache.tsv; `JP_KIND2_CACHE` 只给基准测试/离线复核改
# (线上固定用默认值)。
CACHE = os.environ.get("JP_KIND2_CACHE") or "train-work/kind2_cache.tsv"

# 第 1 列固定是 pkey(参数指纹); 之后分别是"目录态"与"上一次的测量结论"
COLS = ["pkey", "dir", "dir_mtime", "page_path", "page_size", "page_mtime",
        "nline", "wide", "pure", "w", "h", "staff"]


def params_key():
    """会把 measure/impure_from 的结果改掉的环境变量 -> 参数指纹。"""
    from jp_transcribe import _purity2_on
    return "|".join([
        "BADLINE=" + os.environ.get("JP_BADLINE", "5"),
        "WIDELINE=" + os.environ.get("JP_WIDELINE", "45"),
        "THINMAXW=" + os.environ.get("JP_THINMAXW", "8"),
        "STAFFMAX=" + os.environ.get("JP_STAFFMAX", "4"),
        "STAFFHARD=" + os.environ.get("JP_STAFFHARD", "5"),
        "PURITY2=" + ("1" if _purity2_on() else "0"),
    ])


def _mtime_int(path):
    """整秒级 mtime -> 字符串(空串 = 取不到)。整秒是为了避开 csv/浮点格式化的不确定性。"""
    try:
        return str(int(os.path.getmtime(path)))
    except OSError:
        return ""


def load(pkey, path=None):
    """读缓存 -> {dir: 行 dict}。pkey 对不上的行整行丢弃(口径变了, 旧判定不能复用)。"""
    path = path or CACHE
    out = {}
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f, delimiter="\t"):
            if r.get("pkey") != pkey:
                continue
            out[r["dir"]] = r
    return out


def row(pkey, d, dir_mtime, page, vals):
    """组装一行。page=None 表示"这个目录现在挑不出谱页"; vals=None 表示"没量过, 只有目录态"。"""
    if page:
        page_path = os.path.relpath(page, "images-prep").replace("\\", "/")
        page_size, page_mtime = str(os.path.getsize(page)), _mtime_int(page)
    else:
        page_path = page_size = page_mtime = ""
    r = dict(pkey=pkey, dir=d, dir_mtime=dir_mtime, page_path=page_path,
             page_size=page_size, page_mtime=page_mtime,
             nline="", wide="", pure="", w="", h="", staff="")
    if vals:
        r.update(dict(zip(("nline", "wide", "pure", "w", "h", "staff"), (str(v) for v in vals))))
    return r


def same_state(cached, dir_mtime, page_path, page_size, page_mtime):
    """目录态与谱页身份都没变 -> 上一轮的结论可以直接复用(这是快路径)。"""
    if not cached or cached.get("pure", "") == "":
        return False
    if cached.get("dir_mtime", "") != dir_mtime:
        return False
    return (cached.get("page_path", "") == page_path
            and cached.get("page_size", "") == page_size
            and cached.get("page_mtime", "") == page_mtime)


def save(rows, path=None):
    """整份重写(顺带收掉不再存在的目录 —— 缓存要能自己收敛, 不能只涨不缩)。"""
    path = path or CACHE
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter="\t")
        w.writerow(COLS)
        for r in rows.values():
            w.writerow([r.get(c, "") for c in COLS])
    os.replace(tmp, path)
    return len(rows)
