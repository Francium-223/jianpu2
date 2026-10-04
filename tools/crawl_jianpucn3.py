# -*- coding: utf-8 -*-
"""爬 jianpu.cn 曲谱图(补充流行歌)。不做类型过滤 —— 五线谱/吉他谱转不出简谱音符,
会被管线自然筛掉。标题取 <h1>(干净, 不含站点后缀)。
用法: py -3.13 tools/crawl_jianpucn3.py [目标数] [每类页数]
"""
import os, re, sys, time, urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

TARGET = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 400
PAGES = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 10
OUT = "images-prep/jianpucn-pop"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
os.makedirs(OUT, exist_ok=True)
CATS = ["sanzigepu", "sizigepu", "wuzigepu", "liuzigepu", "qizigepu",
        "bazigepu", "jiuzigepu", "shizijiyishang", "erzigepu"]

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")

def safe(s):
    s = re.sub(r"&nbsp;|\s+", " ", s).strip()
    s = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", s)
    return re.sub(r"_{2,}", "_", s)[:60] or "untitled"


# 本文件所在目录(tools/) —— 取共用模块 `corpus_index` 用(不依赖 cwd)
_TOOLS = os.path.dirname(os.path.abspath(__file__))


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。

    本脚本原来只按"图目录在不在"判已抓过, 而图目录与语料是两套账: 从别的源抓回来的同一首歌、
    或者转过写之后目录被挪过的, 都会再抓一遍再进一次转写队列(2026-10-04 实测那一轮 1764 条
    队列几乎全是重复, 净增 1 首)。导入失败照常抓 —— 宁可多下, 不要因为索引坏了整轮空转。
    """
    try:
        if _TOOLS not in sys.path:
            sys.path.insert(0, _TOOLS)
        import corpus_index
        return corpus_index
    except Exception as e:
        print(f"  [语料索引不可用, 按老办法抓] {type(e).__name__}: {e}", flush=True)
        return None

urls = []
for cat in CATS:
    for p in range(1, PAGES + 1):
        u = f"http://www.jianpu.cn/{cat}" + ("" if p == 1 else f"/{p}.htm")
        try:
            html = fetch(u)
        except Exception:
            continue
        urls += re.findall(r"href='(/pu/\d+/\d+\.htm)'", html)
        time.sleep(0.2)
    urls = list(dict.fromkeys(urls))
    print(f"  {cat}: 候选 {len(urls)}", flush=True)
    if len(urls) >= TARGET * 2:
        break

print(f"候选 {len(urls)}, 开始下载 {TARGET}")
done = fail = 0
_ci = _corpus_index()
skipped = _ci.SkipCounter() if _ci is not None else None
for u in urls:
    if done >= TARGET:
        break
    sid = re.search(r"/(\d+)\.htm", u).group(1)
    # 语料里已有 -> 跳过(站内 id 或曲名), 不去请求曲谱页 —— 省一次抓站, 也免得白下几张图
    if _ci is not None:
        r = _ci.skip_reason("jianpucn", sid, "")
        if r:
            skipped.count(r)
            done += 1                 # 已抓过的也算"这一轮不用再管的", 免得为了凑 TARGET 无限往后扫
            continue
    try:
        html = fetch("http://www.jianpu.cn" + u)
    except Exception:
        continue
    m1 = re.search(r"<h1[^>]*>(.*?)</h1>", html, re.S)
    title = safe(m1.group(1)) if m1 else safe(u)
    if _ci is not None:
        r = _ci.skip_reason("", "", title)
        if r:
            skipped.count(r)
            skipped.note_title_skip(title[:44])
            done += 1                 # 同上: 已抓过的计入"这一轮不用再管", 否则会一直往后扫凑数
            continue
    d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    if os.path.isdir(d) and any(f.endswith(".jpg") for f in os.listdir(d)):
        done += 1; continue
    imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", html, re.I)
            if "logo" not in x.lower()]
    if not imgs:
        fail += 1; continue
    os.makedirs(d, exist_ok=True)
    ok = 0
    for i, iu in enumerate(imgs[:2]):
        try:
            req = urllib.request.Request("http://www.jianpu.cn" + iu, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=25) as r, open(os.path.join(d, f"00{i+1}.jpg"), "wb") as g:
                g.write(r.read())
            ok += 1
        except Exception:
            pass
        time.sleep(0.2)
    if ok:
        done += 1
        if done % 25 == 0:
            print(f"[{done}/{TARGET}] {title[:36]}", flush=True)
    time.sleep(0.25)

print(f"\n完成: {done} 个 (无图 {fail}) -> {OUT}")
if skipped is not None:
    print(skipped.summary())
