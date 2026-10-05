# -*- coding: utf-8 -*-
"""qupu123「通俗唱法」整片扫描入库 —— 断点续爬, 每次推进一段。

为什么: 用户指出"我揪出一首歌, 你要补的是一片, 不是补那一张"。
实测 qupu123 的 /tongsu/ = **17819 条 / 713 页, 全是简谱**(全库目前总共才 7296 份) —— 这是
单站单分类就有的 2.4 倍扩库空间。所以做法不是逐个歌名打补丁, 而是**顺序把这一整片扫进来**:
每跑一次推进 CAP 张, 把"下一页从哪儿开始"写进状态文件, 下次接着来(可反复调度)。

页号方向(2026-10-06 实测): **第 1 页是最新的**, 页号越大越老。所以默认从第 1 页起 —— 优先吃
新 id 段(新页命中率低, 净增概率高), 老 id 段排在后面。

抗限流: qupu123 约在每类第 80-190 页开始限流, 所以失败要退避重试, 连续 6 页失败才收工。

2026-10-06 三处修:
  * **谱图页数不再截断**: 原来写死 `imgs[:6]`, 而硬截断会**缺页**(实测 jianpu.cn 的
    `pu/19/194129.htm` 有 6 张; 本族目录里也见到过 >6 张)。改成 `crawl_limits.pages()`,
    默认全部, 可用 `JIANPU_MAX_PAGES` 给上限。
  * **限速收敛到 >=1 秒/请求**: 原来图与图之间只 sleep 0.1 秒、每首 0.18 秒、每页 0.3 秒 ——
    本族(jianpucn 是 1.0 秒)两套节奏。现在一律走 `crawl_limits.throttle()`。
  * **接上语料避抓判据**(`corpus_index.skip_reason`): 原来只按"图目录在不在"判, 而图目录与
    语料是两套账 —— 从别的源抓回来的同一首歌会再抓一遍再进一次转写队列。现在站内 id 或曲名
    命中语料就跳过, 并**分账打出来**(跳过 / 已存在 / 新下), 不再"闷头抓"。

用法: py -3.13 tools/crawl_qupu123_sweep.py [本次最多几张=400] [起始页=自动]
"""
import io
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
from crawl_limits import pages, throttle     # noqa: E402  谱图页数上限 + 统一限速(>=1 秒/请求)

os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")

_TOOLS = os.path.dirname(os.path.abspath(__file__))
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
BASE = "https://www.qupu123.com"
OUT = "images-prep/qupu123-sweep"
STATE = "train-work/qupu123_sweep_state.tsv"
os.makedirs(OUT, exist_ok=True)

CAP = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 400
START = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else None
if START is None:
    START = 1
    if os.path.exists(STATE):
        try:
            START = int(io.open(STATE, encoding="utf-8").read().split("\t")[0]) + 1
        except Exception:
            START = 1


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。取不到就照常抓(不因索引坏了空转)。"""
    try:
        if _TOOLS not in sys.path:
            sys.path.insert(0, _TOOLS)
        import corpus_index
        return corpus_index
    except Exception as e:
        print(f"  [语料索引不可用, 按老办法抓] {type(e).__name__}: {e}", flush=True)
        return None


def get(u, binary=False):
    throttle()                   # 统一限速: >=1 秒/请求(见 tools/crawl_limits.py)
    req = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with urllib.request.urlopen(req, timeout=35) as r:
        raw = r.read()
    return raw if binary else raw.decode("utf-8", "replace")


def safe(s):
    s = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", s)
    return re.sub(r"\s+", " ", s).strip()[:60] or "untitled"


print(f"整片扫描 /tongsu/  本次上限 {CAP} 张, 从第 {START} 页起", flush=True)
_ci = _corpus_index()
skipped = _ci.SkipCounter() if _ci is not None else None
got = seen_state = 0
fail_streak = 0
page = START
while got < CAP and fail_streak < 6:
    u = f"{BASE}/tongsu/" + ("" if page == 1 else f"{page}.html")
    h = None
    for t in range(4):
        try:
            h = get(u)
            break
        except Exception:
            time.sleep(2.0 * (t + 1))
    if h is None:
        fail_streak += 1
        print(f"   第 {page} 页失败(第 {fail_streak} 次连续)", flush=True)
        page += 1
        continue
    fail_streak = 0
    items = re.findall(r'href="(/tongsu/[a-z]+/(?:p\d+|[a-z0-9_]+)\.html)"[^>]*>([^<]{2,90})<', h)
    if not items:
        print(f"   第 {page} 页无条目, 收工", flush=True)
        break
    for path, title in items:
        if got >= CAP:
            break
        sid = re.search(r"/p(\d+)\.html$", path)
        sid = sid.group(1) if sid else os.path.basename(path)[:-5]
        d = os.path.join(OUT, f"{safe(title)}__qupu123-{sid}")
        if os.path.isdir(d) and os.listdir(d):
            seen_state += 1
            continue
        # 语料里已有 -> 跳过(站内 id 或曲名), 连曲谱页都不请求(省一次抓站 + 免得白下几张图)
        if _ci is not None:
            r = _ci.skip_reason("qupu123", sid, title)
            if r:
                skipped.count(r)
                if r == "title":
                    skipped.note_title_skip(title[:44])
                continue
        try:
            ph = get(BASE + path)
        except Exception:
            continue
        imgs = re.findall(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', ph, re.I)
        imgs = [urllib.parse.urljoin(BASE + "/", x) for x in dict.fromkeys(imgs)]
        imgs = [x for x in imgs if "/Public/Uploads/" in x or "/data2/uploads/" in x]
        if not imgs:
            continue
        os.makedirs(d, exist_ok=True)
        n = 0
        # 2026-10-06 修: 原来写死 `imgs[:6]` —— 硬截断会**缺页**。默认全部。
        for iu in pages(imgs):
            try:
                data = get(iu, binary=True)
            except Exception:
                continue
            if len(data) < 8000:
                continue
            try:
                from PIL import Image as _I
                import io as _io
                if min(_I.open(_io.BytesIO(data)).size) < 400:
                    continue
            except Exception:
                pass
            ext = ".png" if data[:4] == b"\x89PNG" else ".jpg"
            with open(os.path.join(d, f"00{n+1}{ext}"), "wb") as g:
                g.write(data)
            n += 1
        if n:
            got += 1
            if got % 25 == 0:
                print(f"   [{got}/{CAP}] 第{page}页 {title[:40]}", flush=True)
    io.open(STATE, "w", encoding="utf-8").write(f"{page}\t{got}\n")
    page += 1

print(f"\n本次新增 {got} 张 (跳过已存在 {seen_state}), 已到第 {page-1} 页 -> {OUT}")
if skipped is not None:
    print(skipped.summary("(这些连曲谱页都没请求)"))
print(f"下次从第 {page} 页继续(状态写在 {STATE})")
