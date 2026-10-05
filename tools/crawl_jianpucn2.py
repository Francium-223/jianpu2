# -*- coding: utf-8 -*-
"""爬 jianpu.cn(歌谱简谱网) 的**简谱**曲谱图, 用于补充流行歌。

站点 GBK 编码; 列表页 /<cat>/<page>.htm, 条目形如:
    <a href='/pu/47/475332.htm' > [杨丞琳] 雨爱&nbsp;&nbsp;</a>
分类(按标题字数): yizigepu..jiuzigepu, shizijiyishang, hechangpu, yingwengepu

判据(2026-10-06 实测改版后重写) —— 见本文件 `JIANPU_CATS` 与 `IMG_RE` 两处注释:
  * 谱种**按分类判**: 站点分类本身就分两类, 一~九字歌谱/十字及以上/合唱谱/英文歌谱都是简谱,
    而 jitapu(吉他谱)/gangqinpu(钢琴谱)/erhupu(二胡谱)/zongpu(总谱) 等是专用谱, 不在收录范围。
    旧判据 `txt.startswith("[简谱]")` 已作废 —— 方括号里现在装的是**歌手/词曲作者**
    (实测六个简谱类分类首页各 30 条, 旧判据命中 **0/180**)。
  * 谱图地址老页是 `/img/...`, **新页改成了 `/img9/...`**(实测 60 条样本旧判据只中 30 条,
    新页 0 命中)。这是个同样"悄悄收 0"的判据, 一并改掉。

用法: py -3.13 tools/crawl_jianpucn2.py [目标数] [每类页数]
输出: images-prep/jianpucn-pop/<标题>__jianpucn-<id>/001.jpg
"""
import os, re, sys, time, urllib.request
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from crawl_limits import pages       # noqa: E402  谱图页数上限: 默认不截断(见 tools/crawl_limits.py)
sys.stdout.reconfigure(encoding="utf-8")

TARGET = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 400
PAGES = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 12
OUT = "images-prep/jianpucn-pop"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
os.makedirs(OUT, exist_ok=True)
CATS = ["yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
        "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "hechangpu", "yingwengepu"]

# 判据(2026-10-06 实测): 谱种**按分类判简谱** —— 站点分类就是这么分的(首页一级路径实测):
#   简谱类(本脚本只扫这些): yizigepu..jiuzigepu(一~九字歌谱) / shizijiyishang(十字及以上)
#                           / hechangpu(合唱谱, 本身就是简谱) / yingwengepu(英文歌谱)
#   专用谱类(**一律不碰**): jitapu gangqinpu erhupu hulusipu sakesipu xiaotiqinpu
#                           shoufengqinpu dianziqinpu guzuoyangqinpu zuopipapu dizuopu
#                           zuonapu huangmeixiqupu jingjuqupu yuejuqupu zongpu qita qitalepu
# 为什么不再看标题文字: 改版后方括号里装的是**歌手/词曲作者**(实测 `[卢家彬] 郑州`、
# `[朱 海 词 子 山 曲 弦声编配] 丰收中国年`), `[简谱]` 字样一条都没有。
JIANPU_CATS = ("yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
               "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "hechangpu", "yingwengepu")
# 谱图地址(2026-10-06 实测): 老页 `/img/xx/yy/<hash>.jpg|gif`, 2025 起的新页 `/img9/N/xx/<hash>.jpg|png`。
# 旧写法 `/img/` 匹配不到 `/img9/` —— 60 条样本里只中 30 条(全是老页), 新页一张都取不到。
IMG_RE = re.compile(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read().decode("gbk", errors="replace")

def safe(name):
    name = re.sub(r"&nbsp;|\s+", " ", name).strip()
    name = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f-\x9f]', "_", name)
    return re.sub(r"_{2,}", "_", name)[:60] or "untitled"


def strip_tag(txt):
    """砍掉标题开头的方括号 —— 改版后里面是**歌手/词曲作者**(实测 `[明月听松] 童年的家`)。

    不砍就会被写进图目录名再漏进转写队列的"曲名"列。没有方括号的(实测 `小小的暖`)原样返回。
    """
    return re.sub(r"^\s*\[[^\]]*\]\s*", "", (txt or "").replace("&nbsp;", " ")).strip()


def ext_of(data):
    """按**魔数**定扩展名 —— 老代码一律写 `.jpg`, 把站点上的 gif/png 谱图存成了假 jpg。"""
    if data[:4] == b"\x89PNG":
        return ".png"
    if data[:3] == b"GIF":
        return ".gif"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return ".webp"
    return ".jpg"


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

# 1) 收集条目 —— 判据从"看标题里的 [简谱]"改成"**按分类判简谱**"(见 JIANPU_CATS 的注释)
items = {}
for cat in CATS:
    if cat not in JIANPU_CATS:      # 只扫简谱类分类; 专用谱类(jitapu/gangqinpu/zongpu…)不进这条链
        continue
    for p in range(1, PAGES + 1):
        u = f"http://www.jianpu.cn/{cat}" + ("" if p == 1 else f"/{p}.htm")
        try:
            html = fetch(u)
        except Exception as e:
            print("  列表失败", u, e); continue
        for m in re.finditer(r"href='(/pu/\d+/\d+\.htm)'\s*>\s*([^<]{1,60})</a>", html):
            url, txt = m.group(1), m.group(2)
            txt = txt.replace("&nbsp;", " ").strip()
            t = safe(strip_tag(txt))
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
    # 目录在不在的判据也要认 gif/png —— 老写法只看 `.jpg`, 而站点上不少谱图是 .gif/.png
    if os.path.isdir(d) and any(re.search(r"\.(jpg|jpeg|png|gif|webp)$", f, re.I) for f in os.listdir(d)):
        done += 1
        continue
    try:
        html = fetch("http://www.jianpu.cn" + url)
    except Exception:
        continue
    imgs = [x for x in IMG_RE.findall(html) if "logo" not in x.lower()]
    if not imgs:
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
            # 原子落盘(.part -> os.replace): 抓取可能被磁盘硬止损直接杀进程, 直接写目标名会留一张
            # 截断图, 而续爬只按"文件名在不在"判 ⇒ 半张图被当成品收下、永不重下。口径同 crawl_jianpucn.py。
            fn = os.path.join(d, f"00{i+1}{ext_of(data)}")
            part = fn + ".part"
            with open(part, "wb") as g:
                g.write(data)
            os.replace(part, fn)
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
