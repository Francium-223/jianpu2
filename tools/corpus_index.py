# -*- coding: utf-8 -*-
"""语料索引 —— 爬虫"避抓"的**唯一口径**(按 `scores/*.txt` 判, 不再只看 images/ 目录)。

为什么要有它(2026-10-04 实测): 一轮 1764 条的转写队列里几乎全是语料里**早就有的曲子**,
净增只有 1 首。根因是爬虫侧判"抓过没有"用的是"图目录在不在"(见各爬虫的 `os.path.isdir` 分支),
而图目录跟语料是两套账 —— 从别的源抓回来的同一首歌、或者转过写但目录被挪过的, 都会再抓一遍,
再进一次转写队列。断点续跑的口径本来就在 `tools/batch_transcribe_queue.py: existing_sources()`,
本模块把它抽出来, 让爬虫与队列**用同一份判据**。

对外:
    existing_sources()      -> set  形如 {"qupu123-268596", ...}
    existing_score_names()  -> set  曲名与文件名主干(都过文件名归一化)
    source_of_name(name)    -> "" 或 "<站>-<id>"
    title_in_corpus(name)   -> bool
    skip_reason(site, sid, title) -> "" / "source" / "title"

两个读取函数都**带缓存**(一次进程只扫一遍 `scores/`), 语料目录不存在时**安静返回空集**
(不抛异常 —— 否则 `--help` 冒烟自检会把爬虫判成失败)。

标题判重用**包含**关系, 条件照抄 `skills/jianpu-melody-lookup/eval_golden.py: same()`
(一方含另一方、被含的一方 >=4 字、且占长串一半以上), 不是"必须完全相等" —— 站点标题常带
`简谱`、`(粤语)` 这类后缀, 只认相等会漏判(实测 `蜗牛与黄鹂鸟简谱_儿歌` 该被语料里那首
`蜗牛与黄鹂鸟` 拦住)。为了别把 12000 个曲名逐个去比, 语料侧按**头两字**分桶
(被包含的一方开头就是它的开头, 所以只在同一桶里比), 每桶几十个。

⚠ 别指望标题判重能兜住"短曲名 + 歌手续尾": 语料里是《爱错》(2 字)时, 站点标题
`爱错简谱_林俊杰` 归一化后是 `爱错林俊杰`, 按 `same()` 的 >=4 字那条**不算命中** ——
这是照抄 `eval_golden` 的保守口径(否则《红》《爱情》这种短名会到处蹭), 别自己放宽。

语料目录定位沿用仓库里已有的写法: 环境变量优先, 再看 `<工作区>/jianpu-db` 这个约定位置。
用法(爬虫侧):
    from corpus_index import skip_reason, SkipCounter
    if skip_reason("qupu123", sid, title):        # 语料里已有 -> 跳过
        ...
"""
import glob
import io
import os
import re
import sys

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2
WS = os.path.dirname(ROOT)                         # 工作区

# 站点后缀: `爱错简谱_林俊杰` 与 `爱错` 得算同一首, 否则标题判重形同虚设。
_SITE_SUFFIX = re.compile(r"(简谱|歌谱|五线谱|正谱|完整版|弹唱|吉他谱|钢琴谱|歌曲类)")
# 括号补充说明: `红茶馆(粤语)` -> `红茶馆`
_PAREN = re.compile(r"[（(【\[《][^）)】\]》]*[）)】\]》]")
# 纯标点/空白: 全角与半角都要收, 站点标题里两种都出现过
_DROP = re.compile(r"[\s\-_·、,，。.!！?？:：;；'\"“”‘’/\\|&～~]+")
_ZW = dict.fromkeys(map(ord, "\u200b-\u200f\u202a-\u202e\u2060\ufeff"), None)
# 文件名主干里的 `__站-id` 后缀(与 to_jianpu_db.py 的提取口径同形)
_SUFFIX = re.compile(r"__(?P<site>[a-z0-9]+)-(?P<sid>[0-9a-z_]+)$")
# 站点 id 来自 `source=站-id`。id 允许字母下划线: to_jianpu_db.py 的拼音别名页就是这种。
_SOURCE = re.compile(r"^(?P<site>[a-z0-9]+)-(?P<sid>[0-9a-z_]+)$")


def db_root():
    """语料仓库 jianpu-db 的位置。

    优先级与仓库里既有的写法一致:
      ① 环境变量 `JIANPU_DB`(`tools/batch_transcribe_queue.py` / `check_tools.sh` 都用它);
      ② 环境变量 `JP_JIANPU_DB`(`tools/db_to_jsonl.py` 用的别名, 一起认, 免得两个口径打架);
      ③ `pipeline.toml` 的 `[external] jianpu_db`;
      ④ 约定位置 `<工作区>/jianpu-db`。
    """
    for k in ("JIANPU_DB", "JP_JIANPU_DB"):
        v = os.environ.get(k)
        if v:
            return v
    try:
        if HERE not in sys.path:
            sys.path.insert(0, HERE)
        from jp_root import cfg
        v = cfg("external", "jianpu_db", default="")
    except Exception:
        v = ""
    if v:
        return v if os.path.isabs(v) else os.path.join(ROOT, v)
    return os.path.join(WS, "jianpu-db")


def scores_dir():
    return os.path.join(db_root(), "scores")


def norm_title(s):
    """曲名归一化 —— 与 `skills/jianpu-melody-lookup/eval_golden.py: norm()` **同口径**。

    为什么要同口径: `tools/queue_from_crawl.py` 判"库里已有"用的就是 `eval_golden.norm`,
    爬虫这边若用另一套归一化, 会出现"爬虫觉得是新的、队列觉得是旧的"这种自相矛盾。
    """
    t = (s or "").translate(_ZW)
    t = _PAREN.sub("", t)
    t = _SITE_SUFFIX.sub("", t)
    t = _DROP.sub("", t).casefold()
    if not t:
        # 整个标题都在括号里时(_PAREN 会把它删空), 退一步只删括号字符, 保留正文
        t = re.sub(r"[（(【\[《）)】\]》]", "", (s or "").translate(_ZW))
        t = _DROP.sub("", t).casefold()
    return t


def stem_of_name(name):
    """文件名主干 —— 去掉 `__站-id` 后缀与扩展名。非文件名(纯曲名)会原样返回。"""
    b = os.path.basename(name or "")
    b = os.path.splitext(b)[0]
    return _SUFFIX.sub("", b)


def source_of_name(name):
    """从文件名主干里取 `站-id`。取不到(没有 `__站-id` 后缀)返回空串。"""
    m = _SUFFIX.search(os.path.splitext(os.path.basename(name or ""))[0])
    return "%s-%s" % (m.group("site"), m.group("sid")) if m else ""


_cache = {}


def _scan():
    """扫一遍 `scores/*.txt`, 一次进程只做一次。返回 (sources, names, by2)。"""
    d = scores_dir()
    key = os.path.abspath(d)
    if key in _cache:
        return _cache[key]
    sources, names = set(), set()
    try:
        files = glob.glob(os.path.join(d, "*.txt"))
    except OSError:
        files = []
    for p in files:
        base = os.path.basename(p)
        stem = stem_of_name(base)
        if stem:
            names.add(norm_title(stem))
        try:
            fh = io.open(p, encoding="utf-8", errors="replace")
        except OSError:
            # 目录不存在 / 文件读不动都算"这一份索引没有", 不往上抛 —— 爬虫的 --help 会 import 本模块
            continue
        with fh:
            for ln in fh:
                if ln.startswith("source="):
                    v = ln.split("=", 1)[1].strip()
                    if v:
                        sources.add(v)
                elif ln.startswith("title="):
                    nm = norm_title(ln.split("=", 1)[1].strip())
                    if nm:
                        names.add(nm)
    # 包含关系只可能发生在"头两字一样"的名字之间(被包含的一方开头就是它的开头), 所以按头两字分桶,
    # 候选只需跟自己那一桶比 —— 12000 个名字摊下来每桶几十个, 比全量扫快两个数量级。
    # 只有 >=4 字的名字可能充当"被包含的一方"(`same()` 的硬条件), 更短的只能靠相等判定。
    by2 = {}
    for nm in names:
        if len(nm) >= 4:
            by2.setdefault(nm[:2], []).append(nm)
    _cache[key] = (sources, names, by2)
    return _cache[key]


def existing_sources():
    """语料里已有的 **source=站-id** 集合。语料目录不存在时返回空集(不抛异常)。"""
    return set(_scan()[0])


def existing_score_names():
    """语料里已有的**曲名 / 文件名主干**集合(都过 `norm_title`)。

    两样都收的原因: 语料文件既可能是 `曲名.txt`, 也可能是 `<曲名>__站-id.txt`,
    而 `title=` 偶尔与文件名不一致(改过名的旧文件), 只认一边就会漏判。
    """
    return set(_scan()[1])


def _same(a, b):
    """与 `eval_golden.same()` 同一条规则(两个数字条件都是用来挡"短词蹭长名"的)。"""
    if not a or not b:
        return False
    if a == b:
        return True
    if a in b:
        short, long_ = a, b
    elif b in a:
        short, long_ = b, a
    else:
        return False
    return len(short) >= 4 and len(short) * 2 >= len(long_)


def title_in_corpus(name):
    """这个曲名(或文件名)在语料里吗 —— 相等或按 `_same()` 规则互相包含都算。"""
    nm = norm_title(stem_of_name(name))
    if not nm:
        return False
    sources, names, by2 = _scan()
    if nm in names:
        return True
    if len(nm) < 4:
        return False          # "被包含的一方 >=4 字"是 `_same()` 的硬条件, 短曲名只能靠相等判定
    for c in by2.get(nm[:2], ()):
        if _same(nm, c):
            return True
    return False


def skip_reason(site, sid, title):
    """爬虫"该不该跳过"的判据 —— 返回 "" (要抓) / "source" (站内 id 已在语料) / "title" (曲名已在语料)。

    只按 id 与曲名判, **不看图目录**: 图目录是下载侧的账, 跟语料是两套账(那正是漏判的根因)。
    """
    if site and sid:
        key = "%s-%s" % (site, str(sid))
        if _SOURCE.match(key) and key in existing_sources():
            return "source"
    if title and title_in_corpus(title):
        return "title"
    return ""


class SkipCounter:
    """跳过计数 —— 跑完打一行汇总, 免得"跳了多少"只能靠猜。"""

    def __init__(self):
        self.source = 0
        self.title = 0

    def count(self, reason, label=""):
        if reason == "source":
            self.source += 1
        elif reason == "title":
            self.title += 1
        return reason

    def note_title_skip(self, label):
        """打一行"按标题跳过"的提示 —— 事后核对时能看出是不是误判。"""
        print("   = 按标题跳过(语料里已有同名): %s" % label, flush=True)

    @property
    def total(self):
        return self.source + self.title

    def summary(self, extra=""):
        s = "跳过 %d 条(语料里已有: 站内 id %d + 曲名 %d)" % (self.total, self.source, self.title)
        return s + ("  " + extra if extra else "")
