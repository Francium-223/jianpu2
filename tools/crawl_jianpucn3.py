# -*- coding: utf-8 -*-
"""爬 jianpu.cn 曲谱图(补充流行歌)。不做更细的类型过滤 —— 五线谱/吉他谱转不出简谱音符,
会被管线自然筛掉。标题取 <h1>(干净, 不含站点后缀)。

判据(2026-10-06 实测复核, 每条的"为什么"写在各处注释里):
  * 谱图地址: 老页 `/img/...`, 2025 起新页 `/img9/...` —— 旧写法 `^/img/` 对新页 **0 命中**,
    于是每首歌都"页面里没图"地 `fail += 1` 跳过, 跑完是"完成 0 个"而退出码仍是 0(见 `IMG_RE`);
  * 谱图后缀: 站点上 `.gif`/`.jpg` 都有 ⇒ 按**魔数**定扩展名, 原写法一律写 `001.jpg`(假后缀);
  * 分类清单: 原来只有 9 个, 漏了 `yizigepu`(一字歌谱)/`hechangpu`(合唱谱)/`yingwengepu`(英文歌谱)
    —— 站点的**简谱类**是 12 个(首页一级导航实测), 合唱谱只存在于 `hechangpu`。

用法: py -3.13 tools/crawl_jianpucn3.py [目标数] [每类页数]
"""
import os, re, sys, time, urllib.error, urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from crawl_limits import pages       # noqa: E402  谱图页数上限: 默认不截断(见 tools/crawl_limits.py)
sys.stdout.reconfigure(encoding="utf-8")

TARGET = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 400
PAGES = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 10
OUT = "images-prep/jianpucn-pop"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
os.makedirs(OUT, exist_ok=True)

# 分类清单(2026-10-06 实测: 站点首页一级导航里就这 12 个是**简谱类**, 中文名由它自己给出):
#   一字歌谱..九字歌谱(shizijiyishang 之前的九个) / 十字及以上 / 合唱谱 / 英文歌谱
# 原清单漏了 yizigepu(一字歌谱)、hechangpu(合唱谱, 实测首页 30 条全是合唱简谱)、
# yingwengepu(英文歌谱); 而 jitapu(吉他谱)/gangqinpu(钢琴谱)/zongpu(总谱) 这些**专用谱类**
# 仍然一个都不在清单里 —— 它们确实转不出简谱。
CATS = ["yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
        "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "hechangpu", "yingwengepu"]

# 谱图地址(2026-10-06 实测): 老页 `/img/8f/bc/<hash>.gif`、`/img/9/da/<hash>.jpg`, 2025 起的新页
# `/img9/2/kv/<hash>.jpg`。`\d*` 两种都认 —— 只写 `/img/` 时新页 **0 命中**(静默失败)。
# 口径与 `crawl_jianpucn2.py` / `crawl_jianpucn_by_title.py` 一致; `tools/check_jianpucn_filter.py`
# 会用 ast 从本文件抠出这条正则, 并断言它能匹配 `/img9/` 形态。
IMG_RE = re.compile(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")


def safe(s):
    s = re.sub(r"&nbsp;|\s+", " ", s).strip()
    s = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", s)
    return re.sub(r"_{2,}", "_", s)[:60] or "untitled"


def ext_of(data):
    """按**魔数**定扩展名 —— 站点上的谱图既有 .jpg 也有 .gif, 一律写 `.jpg` 会存出假后缀。

    与 `crawl_jianpucn2.py` / `crawl_jianpucn_by_title.py` 的 `ext_of` 同一口径。
    """
    if data[:4] == b"\x89PNG":
        return ".png"
    if data[:3] == b"GIF":
        return ".gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    return ".jpg"


_IMG_EXT = re.compile(r"\.(jpg|jpeg|png|gif|webp)$", re.I)


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
        except urllib.error.HTTPError as e:
            # 实测: 页号超过末页返回 404(`/erzigepu/999.htm` -> 404)—— 那就是"没有下一页了",
            # 原写法 `except Exception: continue` 会一路把 p+1..PAGES 全请求一遍(全是 404)。
            if e.code == 404:
                break
            continue
        except Exception:
            continue
        urls += re.findall(r"href='(/pu/\d+/\d+\.htm)'", html)
        time.sleep(1.0)              # 本次纪律: 限速 >=1 秒/请求(原来 0.2 秒)
    urls = list(dict.fromkeys(urls))
    print(f"  {cat}: 候选 {len(urls)}", flush=True)
    if len(urls) >= TARGET * 2:
        break

print(f"候选 {len(urls)}, 开始下载 {TARGET}")
done = fail = 0
fails = {}                             # 空手/失败原因 -> 次数(别再"完成 0 个"却不说为什么)
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
    except Exception as e:
        fails["曲谱页取不到: " + type(e).__name__] = fails.get("曲谱页取不到: " + type(e).__name__, 0) + 1
        continue
    m1 = re.search(r"<h1[^>]*>(.*?)</h1>", html, re.S)
    title = safe(re.sub(r"<[^>]+>", "", m1.group(1))) if m1 else safe(u)
    if _ci is not None:
        r = _ci.skip_reason("", "", title)
        if r:
            skipped.count(r)
            skipped.note_title_skip(title[:44])
            done += 1                 # 同上: 已抓过的计入"这一轮不用再管", 否则会一直往后扫凑数
            continue
    d = os.path.join(OUT, f"{title}__jianpucn-{sid}")
    # 目录在不在的判据也要认 gif/png —— 原来只看 `.jpg`, 而站点上不少谱图是 .gif/.png
    if os.path.isdir(d) and any(_IMG_EXT.search(f) for f in os.listdir(d)):
        done += 1; continue
    imgs = [x for x in IMG_RE.findall(html) if "logo" not in x.lower()]
    if not imgs:
        fail += 1
        fails["页面里没匹配到谱图(/img\\d*/)"] = fails.get("页面里没匹配到谱图(/img\\d*/)", 0) + 1
        continue
    os.makedirs(d, exist_ok=True)
    ok = 0
    # 2026-10-06 修: 原来写死 `imgs[:2]` —— 实测详情页最多有 6 张(《93海阔天空》), 只存 2 张
    # 会让后面几页**永远下不到**。默认全部(可用 `JIANPU_MAX_PAGES` 给上限)。
    for i, iu in enumerate(pages(imgs)):
        try:
            req = urllib.request.Request("http://www.jianpu.cn" + iu, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=25) as r:
                data = r.read()
            # 后缀按魔数定(不抄 URL 后缀): 站点上老页多是 .gif, 新页是 .jpg
            with open(os.path.join(d, f"00{i+1}{ext_of(data)}"), "wb") as g:
                g.write(data)
            ok += 1
        except Exception as e:
            fails["图片下载失败: " + type(e).__name__] = fails.get("图片下载失败: " + type(e).__name__, 0) + 1
        time.sleep(1.0)              # 本次纪律: 限速 >=1 秒/请求(原来 0.2 秒)
    if ok:
        done += 1
        if done % 25 == 0:
            print(f"[{done}/{TARGET}] {title[:36]}", flush=True)
    time.sleep(1.0)                  # 本次纪律: 限速 >=1 秒/请求(原来 0.25 秒)

print(f"\n完成: {done} 个 (无图 {fail}) -> {OUT}")
if fails:
    print("空手/失败统计(以前这些是静默 `except: continue`, 所以只会看到\"完成 0 个\"):")
    for k, v in sorted(fails.items(), key=lambda kv: -kv[1]):
        print("   %-34s %d" % (k, v))
if skipped is not None:
    print(skipped.summary())
