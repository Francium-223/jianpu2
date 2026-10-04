# -*- coding: utf-8 -*-
"""爬 jianpu.cn(歌谱简谱网) 的**简谱**曲谱图, 用于补充流行歌。

站点 GBK 编码; 列表页 /<cat>/<page>.htm, 条目形如:
    <a href='/pu/47/475332.htm' > [杨丞琳] 雨爱&nbsp;&nbsp;</a>
分类(按标题字数): yizigepu..jiuzigepu, shizijiyishang, hechangpu, yingwengepu

只收 [简谱] 类型(跳过吉他谱/钢琴谱/五线谱 —— 那些转不出简谱音符)。
用法: py -3.13 tools/crawl_jianpucn2.py [目标数] [每类页数]
输出: images-prep/jianpucn-pop/<标题>__jianpucn-<id>/001.jpg
"""
import os, re, sys, time, urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

TARGET = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 400
PAGES = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 12
OUT = "images-prep/jianpucn-pop"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
os.makedirs(OUT, exist_ok=True)
CATS = ["yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
        "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "yingwengepu"]

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")

def safe(name):
    name = re.sub(r"&nbsp;|\s+", " ", name).strip()
    name = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", name)
    return re.sub(r"_{2,}", "_", name)[:60] or "untitled"


# 本文件所在目录(tools/) —— 取共用模块 `corpus_index` 用(不依赖 cwd)
_TOOLS = os.path.dirname(os.path.abspath(__file__))


def _corpus_index():
    """语料索引(避抓判据) —— 见 `tools/corpus_index.py`。

    本脚本原来只按"图目录里有没有 .jpg"判已抓过, 而图目录与语料是两套账(2026-10-04 实测那一轮
    1764 条转写队列几乎全是重复, 净增 1 首)。导入失败照常抓 —— 宁可多下, 别因为索引坏了空转。
    """
    try:
        if _TOOLS not in sys.path:
            sys.path.insert(0, _TOOLS)
        import corpus_index
        return corpus_index
    except Exception as e:
        print(f"  [语料索引不可用, 按老办法抓] {type(e).__name__}: {e}", flush=True)
        return None

# 1) 收集 [简谱] 条目
items = {}
for cat in CATS:
    for p in range(1, PAGES + 1):
        u = f"http://www.jianpu.cn/{cat}" + ("" if p == 1 else f"/{p}.htm")
        try:
            html = fetch(u)
        except Exception as e:
            print("  列表失败", u, e); continue
        for m in re.finditer(r"href='(/pu/\d+/\d+\.htm)'\s*>\s*([^<]{1,60})</a>", html):
            url, txt = m.group(1), m.group(2)
            txt = txt.replace("&nbsp;", " ").strip()
            if not txt.startswith("[简谱]"):
                continue
            t = safe(txt[len("[简谱]"):])
            items[url] = t
        time.sleep(0.25)
    print(f"  {cat}: 累计简谱条目 {len(items)}", flush=True)
    if len(items) >= TARGET * 3:
        break

print(f"共收集 {len(items)} 条简谱链接, 开始下载前 {TARGET} 个")
done = 0
_ci = _corpus_index()
skipped = _ci.SkipCounter() if _ci is not None else None
for url, title in items.items():
    if done >= TARGET:
        break
    sid = re.search(r"/(\d+)\.htm", url).group(1)
    # 语料里已有 -> 跳过(站内 id 或曲名), 连曲谱页都不请求
    if _ci is not None:
        r = _ci.skip_reason("jianpucn", sid, title)
        if r:
            skipped.count(r)
            if r == "title":
                skipped.note_title_skip(title[:44])
            done += 1                 # 已抓过的也算"这一轮不用再管", 否则会一直往后扫凑数
            continue
    d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    if os.path.isdir(d) and any(f.endswith(".jpg") for f in os.listdir(d)):
        done += 1
        continue
    try:
        html = fetch("http://www.jianpu.cn" + url)
    except Exception:
        continue
    imgs = [x for x in re.findall(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", html, re.I)
            if "logo" not in x.lower()]
    if not imgs:
        continue
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
        time.sleep(0.25)
    if ok:
        done += 1
        if done % 25 == 0:
            print(f"[{done}/{TARGET}] {title[:38]}", flush=True)
    time.sleep(0.3)

print(f"\n完成: {done} 个曲谱 -> {OUT}")
if skipped is not None:
    print(skipped.summary())
