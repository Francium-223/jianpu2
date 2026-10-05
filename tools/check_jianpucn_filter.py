# -*- coding: utf-8 -*-
"""**只读**自检: jianpu.cn 这一族爬虫的判据还收得到东西吗。

背景(2026-10-06 实测): jianpu.cn 改版之后, 那些"看页面文字/看老路径"的判据会**静静收 0**,
而退出码仍然是 0 —— 看起来跑成功了, 其实一张图都没下:
  * 列表页方括号里装的从 `[简谱]` 换成了**歌手/词曲作者**(`[邓紫棋] 画`) ⇒ `[简谱]` 判据 0 命中;
  * 谱图地址从 `/img/...` 改成 `/img9/...`(2025 起的新页) ⇒ `/img/` 判据对新页**一张都取不到**;
  * 详情页 `<title>` 从 2025 起把**歌手**追在曲名后面(`推车歌 焦阳  歌谱简谱网`) ⇒ 拿它当曲名;
  * 相关曲谱锚点的方括号从 `[简谱]` 换成了**分类名**(`[三字歌谱]推车歌  焦洋`) ⇒ `"简谱" in txt` 0 命中;
  * 站内 id -> 页址的目录是 id 的**前两位**, "去掉末四位"这种写法对 5 位 id 一律 404
    (图库里 5 位 id 有 4056/10410 ≈ 39%)。
这几条判据在这一族爬虫里是**互相抄**的(同一个 `/img/` 抄了 5 份, 同一个 `"简谱" in` 抄了 3 处),
所以自检也按"一族"覆盖, 而不是只盯一两个文件 —— 否则修完一个, 明天新加的又没人管。

本自检做四件事, **全部只读**(只 GET 列表页/详情页, 不下载图、不写任何文件):
  ① 自动找出**同类爬虫**(tools/ 下提到 `jianpu.cn` **且**用一条正则取谱图地址的脚本)并打印清单;
  ② 用 `ast` 从**每个爬虫的源码**里把"真在用的判据"抠出来(不 import —— 它们是模块级脚本,
     import 就会真的开跑)。两种写法都认: 模块级 `IMG_RE = re.compile(...)` 与直接内联的
     `re.findall(r"...", html)`。**注释不算判据**(ast 里根本没有注释), 所以留下的旧写法做对照不会误判;
  ③ 离线断言(不联网也能跑, `--offline` 只跑这一段):
       * 每条谱图判据都必须匹配 `/img9/` 形态(新页全在这里), 同时仍匹配老的 `/img/` 形态;
       * 不许再用 `sid[:len(sid) - 4]` 这条实测 404 的 id -> 页址写法;
       * 扫分类的爬虫, 分类清单里必须有 `hechangpu`(实测合唱谱只有这个分类里才有);
       * 不许再用 `"简谱" in <锚点正文>` 这种文本类型判据(实测 0 命中);
  ④ 联网复核: 列表页上"按分类判简谱"(新) vs `[简谱]`(旧)各收多少条; 再到详情页上, 拿
     **新页(/img9/)与老页(/img/)** 各跑一遍每个爬虫的谱图判据 —— 新页必须**条条命中**。

用法:
    py -3.13 tools/check_jianpucn_filter.py                  # 默认查 3 个分类
    py -3.13 tools/check_jianpucn_filter.py --cats erzigepu,sizigepu,hechangpu
    py -3.13 tools/check_jianpucn_filter.py --pages 1,2      # 多看几页, 结论更稳
    py -3.13 tools/check_jianpucn_filter.py --offline        # 只跑 ①②③, 不联网
退出码: 0 = 全部断言通过; 1 = 断言失败(判据又过期了); 2 = 网络取不到, 无法判定。
"""
import argparse
import ast
import glob
import os
import re
import sys
import time
import urllib.error
import urllib.request

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import tlsfetch                     # noqa: E402  取页 + 证书过期兜底(与这一族爬虫同口径)

BASE = "http://www.jianpu.cn"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
# 列表页的一条记录(各爬虫用的是同一条正则的形态, 这里照抄, 只用于"数条数")
ITEM_RE = re.compile(r"href='(/pu/\d+/\d+\.htm)'[^>]*>([^<]{1,70})<")
OLD_TAG = "[简谱]"                  # 作废的旧判据: 标题以它开头
# 实测(2026-10-06, 站点首页一级导航): 简谱类 = 一~九字歌谱/十字及以上/合唱谱/英文歌谱, 共 12 个
JIANPU_CATS = ("yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
               "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "hechangpu", "yingwengepu")
# 专用谱类(吉他谱/钢琴谱/总谱…): 实测转不出简谱音符, 不该混进简谱清单
SPECIAL_CATS = ("jitapu", "gangqinpu", "erhupu", "hulusipu", "sakesipu", "xiaotiqinpu",
                "shoufengqinpu", "dianziqinpu", "guzuoyangqinpu", "zuopipapu", "dizuopu",
                "zuonapu", "huangmeixiqupu", "jingjuqupu", "yuejuqupu", "zongpu", "qita", "qitalepu")
# 造两个 HTML 片段来"离线试判据": 只有真能认出 `/img9/` 的判据才算合格
NEW_IMG_SAMPLE = '<img src="/img9/2/kv/2ammoh36lcdob2hbw3n2vakqkv.jpg" border="0">'
OLD_IMG_SAMPLE = '<img src="/img/b1/5a/b15a0978645840ce98e74d350f415530.gif" border="0">'
# 实测(2026-10-06)的详情页样本: 前者是新页(谱图 `/img9/…jpg`), 后者是老页(谱图 `/img/…gif`)
NEW_PAGE_FALLBACK = "/pu/47/475917.htm"
OLD_PAGE_FALLBACK = "/pu/90/90797.htm"
# 2026-10-06 这一族有哪些(自动发现的结果)。写在这里是为了"新加了一个爬虫"或"某个被删/改名"
# 能被看见 —— 清单对不上只打警告(不算失败), 因为新增同类本来就要人来复核。
EXPECTED_FAMILY = {"crawl_artist.py", "crawl_jianpucn.py", "crawl_jianpucn2.py",
                   "crawl_jianpucn3.py", "crawl_jianpucn_by_title.py", "crawl_pop.py",
                   "get_yequ.py"}

# ---- jianpujia 那一族(2026-10-06 纳入) ----------------------------------------
# 同一类毛病: **判据要求属性值带引号, 而页面把它写成没有引号**。实测页面真身
# (`/jianpu/157673.html`, 大东北我的家乡):
#     <p style="text-align: center;"><img alt="…" width="760" border=0
#         src=https://image.jianpujia.com/jianpudq/jianpu30/<hash>.png></p>
# 老判据 `<img[^>]+src="((?:https?:)?//image\.jianpujia\.com/[^"]+)"` 对这种页 **0 命中**
# ⇒ 每首都静默 `continue`, 跑完"完成: 0 首"而退出码仍是 0。实测: 老判据 0 条 / 新判据 1 条。
JIANPUJIA_UNQUOTED = ('<p style="text-align: center;"><img alt="大东北我的家乡简谱" width="760" border=0 '
                      'src=https://image.jianpujia.com/jianpudq/jianpu30/'
                      'e9bd539773757e49ae2b3ce257b6a88d.png></p>')
JIANPUJIA_QUOTED_ABS = '<img src="https://image.jianpujia.com/jianpudq/jianpu40/abc.png">'
JIANPUJIA_QUOTED_REL = '<img src="//image.jianpujia.com/jianpudq/jianpu40/abc.png">'
# 这一族有哪些(自动发现的结果; 对不上只警告, 因为新增同类本来就要人复核)
EXPECTED_JIANPUJIA_FAMILY = {"crawl_jianpujia.py", "crawl_jianpujia_search.py",
                             "crawl_jianpujia_by_artist.py", "crawl_jianpujia_category.py"}


def _urls(rx, html):
    """把一条判据在一段 HTML 上匹配到的东西取出来(有捕获组就取第一个非空组, 否则取整段匹配)。

    为什么不能用 `findall` 判断: 新判据是**三个引号形态的交替**, `findall` 会返回三元组,
    "有没有命中"不能只看返回值真假。
    """
    out = []
    for m in rx.finditer(html):
        gs = [g for g in m.groups() if g]
        out.append(gs[0] if gs else m.group(0))
    return out


def jianpujia_img_judges(path):
    """jianpujia 那族**认谱图地址**的正则(`image.jianpujia.com` 图床, 或通用的 `<img … src=…>`)。

    注意域名在正则里通常写成 `image\\.jianpujia\\.com`(点号转义), 所以判"是不是图床判据"不能直接
    做子串匹配 —— 这里只要求"提到 jianpujia"**或**是 `<img …>` 形态, 且带图片后缀。
    """
    out = []
    for ln, p in re_literals(path):
        low = p.lower()
        if not ("jianpujia" in low or "<img" in low):
            continue
        if not ("<img" in low or "png" in low or "jpg" in low or "gif" in low):
            continue
        out.append((ln, p))
    return out


def jianpujia_family():
    """jianpujia 那族爬虫 = tools/ 下 (a) 源码提到 `jianpujia.com` **且** (b) 用一条正则取谱图的脚本。"""
    me = os.path.basename(__file__)
    found = []
    for p in sorted(glob.glob(os.path.join(HERE, "crawl_*.py")) + glob.glob(os.path.join(HERE, "get_*.py"))):
        base = os.path.basename(p)
        if base == me:
            continue
        try:
            src = open(p, encoding="utf-8").read()
        except OSError:
            continue
        if "jianpujia.com" not in src:
            continue
        try:
            if jianpujia_img_judges(p):
                found.append(base)
        except SyntaxError:
            print("   ⚠ %s 语法都过不了, 跳过" % base)
    return found


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with tlsfetch.urlopen(req, timeout=30) as r:
        return r.read().decode("gbk", "replace")


# ---------------------------------------------------------------- 从源码里抠判据
RE_METHODS = {"compile", "findall", "finditer", "search", "match", "fullmatch", "sub", "split"}


def _module_values(tree):
    """模块级 `NAME = <表达式>` 的映射(用来把 `IMG_RE.findall(...)` 还原成它背后的正则)。"""
    out = {}
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name):
                    out[t.id] = node.value
    return out


def _literal(node, vals, depth=0):
    """把字面量 / `re.compile(r"...")` / 指向它们的模块级名字还原成字符串(最多追三层)。"""
    if depth > 3 or node is None:
        return None
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    if isinstance(node, ast.Name):
        return _literal(vals.get(node.id), vals, depth + 1)
    if (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
            and node.func.attr == "compile" and node.args):
        return _literal(node.args[0], vals, depth + 1)
    return None


def re_literals(path):
    """抠出源码里所有**正则字面量**: `re.xxx(r"...")` 与 `CONST = re.compile(r"...")` 之后的
    `CONST.xxx(...)`。注释与文档字符串都不算(ast 里没有注释), 所以"作废的旧写法只留在注释里"
    不会被误当成判据。返回 [(行号, 模式串)], 同一模式只留第一次出现。
    """
    tree = ast.parse(open(path, encoding="utf-8").read())
    vals = _module_values(tree)
    found, seen = [], set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        f = node.func
        if not (isinstance(f, ast.Attribute) and f.attr in RE_METHODS):
            continue
        pat = None
        if isinstance(f.value, ast.Name):
            if f.value.id == "re":                    # re.findall(r"...", html)
                pat = _literal(node.args[0], vals) if node.args else None
            elif f.value.id in vals:                  # IMG_RE.findall(html)
                pat = _literal(vals[f.value.id], vals)
        if pat and pat not in seen:
            seen.add(pat)
            found.append((node.lineno, pat))
    return found


def img_judges(path):
    """这个爬虫里**认谱图地址**的正则 —— 一族爬虫共用一种形态(`<img ... src='/img…'>`)。"""
    return [(ln, p) for ln, p in re_literals(path) if "/img" in p]


def source_tuple(path, *names):
    """抠出 `NAME = ("a", "b", …)` 这样的字面量元组/列表(分类清单就是这种)。"""
    src = open(path, encoding="utf-8").read()
    tree = ast.parse(src)
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id in names:
                    try:
                        return tuple(ast.literal_eval(node.value))
                    except Exception:
                        return None
    return None


def bad_id_exprs(path):
    """找 `sid[:len(sid) - 4]` 这类"去掉末四位"的页址写法。

    为什么用 ast 而不是搜文本: `crawl_jianpucn.py: sid_url()` 的注释里要写清"旧写法长什么样",
    搜文本会把那段说明自己判红。**代码里**才算数 —— 注释与文档字符串在 ast 里只是常量。
    返回行号列表。
    """
    out = []
    for node in ast.walk(ast.parse(open(path, encoding="utf-8").read())):
        if not (isinstance(node, ast.BinOp) and isinstance(node.op, ast.Sub)):
            continue
        r, l = node.right, node.left
        if (isinstance(r, ast.Constant) and r.value == 4
                and isinstance(l, ast.Call) and isinstance(l.func, ast.Name) and l.func.id == "len"
                and l.args and isinstance(l.args[0], ast.Name) and l.args[0].id == "sid"):
            out.append(node.lineno)
    return out


def text_in_judges(path):
    """找 `"简谱" in <锚点正文>` 这种**文本类型判据** —— 实测改版后锚点正文里没有 `[简谱]` 了
    (方括号里装的是歌手或分类名), 这类判据会静静收 0。返回 [(行号, 那一行源码)]。"""
    src = open(path, encoding="utf-8").read()
    lines = src.splitlines()
    out = []
    for node in ast.walk(ast.parse(src)):
        if not (isinstance(node, ast.Compare)
                and any(isinstance(op, (ast.In, ast.NotIn)) for op in node.ops)):
            continue
        cands = [node.left] + list(node.comparators)
        if any(isinstance(c, ast.Constant) and isinstance(c.value, str) and "简谱" in c.value
               for c in cands):
            out.append((node.lineno, lines[node.lineno - 1].strip() if node.lineno <= len(lines) else ""))
    return out


def family():
    """同类爬虫 = tools/ 下 (a) 源码里提到 `jianpu.cn` **且** (b) 用一条正则取谱图地址的脚本。

    自动发现而不是写死清单: 写死的话, 明天新加一个爬虫就又没人管了 —— 那正是这次要防的事。
    排除本文件自己(这里**故意**留着一份旧的 `/img/` 判据做对照, 不该被判成过期爬虫)。
    """
    me = os.path.basename(__file__)
    found = []
    for p in sorted(glob.glob(os.path.join(HERE, "crawl_*.py"))
                    + glob.glob(os.path.join(HERE, "get_*.py"))):
        base = os.path.basename(p)
        if base == me:
            continue
        try:
            src = open(p, encoding="utf-8").read()
        except OSError:
            continue
        if "jianpu.cn" not in src:
            continue
        try:
            if img_judges(p):
                found.append(base)
        except SyntaxError:
            print("   ⚠ %s 语法都过不了, 跳过" % base)
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cats", default="erzigepu,sizigepu,hechangpu",
                    help="要查的简谱类分类(逗号分隔), 默认三个")
    ap.add_argument("--pages", default="1", help="看第几页(逗号分隔), 默认第 1 页")
    ap.add_argument("--detail", default="", help="额外对照谱图判据的详情页, 默认从列表页取第一条")
    ap.add_argument("--offline", action="store_true", help="只跑 ①②③(静态断言), 不联网")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    cats = [c.strip() for c in a.cats.split(",") if c.strip()]
    pages = [int(p) for p in a.pages.split(",") if p.strip()]
    bad = [c for c in cats if c not in JIANPU_CATS]
    if bad:
        print("⚠ 这些分类不在**简谱类**清单里, 查它们没有意义: %s" % bad)

    # ---- ① 找出这一族爬虫 ----
    print("=== ① 同类爬虫(自动发现: 提到 jianpu.cn 且用正则取谱图地址的脚本) ===")
    fam = family()
    if not fam:
        print("   ⚠ 一个都没找到 —— 要么爬虫都没了, 要么它们改得连自检都认不出来了")
        return 1
    for name in fam:
        print("   %s" % name)
    if set(fam) != EXPECTED_FAMILY:
        print("   ⚠ 与 2026-10-06 的清单不一致: 新增 %s / 消失 %s"
              % (sorted(set(fam) - EXPECTED_FAMILY), sorted(EXPECTED_FAMILY - set(fam))))
    jfam = jianpujia_family()
    print("   —— jianpujia 那一族(提到 jianpujia.com 且用正则取谱图的): %s"
          % (("、".join(jfam)) if jfam else "⚠ 一个都没找到"))
    if set(jfam) != EXPECTED_JIANPUJIA_FAMILY:
        print("   ⚠ 与 2026-10-06 的 jianpujia 清单不一致: 新增 %s / 消失 %s"
              % (sorted(set(jfam) - EXPECTED_JIANPUJIA_FAMILY),
                 sorted(EXPECTED_JIANPUJIA_FAMILY - set(jfam))))

    # ---- ② 每个爬虫真在用的判据(静态读源码) + ③ 离线断言 ----
    print("\n=== ② 每个爬虫真在用的谱图判据(ast 静态读源码, 不 import) ===")
    judges = {}
    for name in fam:
        p = os.path.join(HERE, name)
        js = img_judges(p)
        judges[name] = js
        for ln, pat in js:
            print("   %-28s L%-4d %s" % (name, ln, pat))
        cs = source_tuple(p, "JIANPU_CATS", "CATS")
        if cs:
            print("   %-28s 分类清单 %d 个, 含 hechangpu=%s"
                  % ("", len(cs), "hechangpu" in cs))
    jjudges = {}
    for name in jfam:
        for ln, pat in jianpujia_img_judges(os.path.join(HERE, name)):
            jjudges.setdefault(name, []).append((ln, pat))
            print("   %-28s L%-4d %s" % (name, ln, pat))

    print("\n=== ③ 离线断言(不联网) ===")
    bad_new, bad_old = [], []
    for name in fam:
        for ln, pat in judges[name]:
            rx = re.compile(pat, re.I)
            if not rx.findall(NEW_IMG_SAMPLE):
                bad_new.append("%s:%d %s" % (name, ln, pat))
            if not rx.findall(OLD_IMG_SAMPLE):
                bad_old.append("%s:%d %s" % (name, ln, pat))
    for name in fam:
        p = os.path.join(HERE, name)
        for ln in bad_id_exprs(p):
            print("   ✗ %s:%d 还在用实测会 404 的 id->页址写法(`len(sid) - 4`)" % (name, ln))
    assert not bad_new, (
        "**图地址判据匹配不了 `/img9/` 形态** —— 2025 起的新页谱图全在那儿, 这类判据会静静收 0 张:\n     "
        + "\n     ".join(bad_new))
    print("   ✓ 断言通过: %d 个爬虫共 %d 条谱图判据, 条条匹配 `/img9/` 形态"
          % (len(fam), sum(len(v) for v in judges.values())))
    if bad_old:
        print("   ⚠ 这些判据不再匹配老的 `/img/` 形态(网页可能已整体迁移到新图床, 先观察): %s" % bad_old)
    else:
        print("   ✓ 断言通过: 它们同时也还认老的 `/img/` 形态")

    bad_id = ["%s:%d" % (n, ln) for n in fam for ln in bad_id_exprs(os.path.join(HERE, n))]
    assert not bad_id, ("**还在用 `len(sid) - 4` 这条实测 404 的 id -> 页址写法** —— "
                        "5 位 id(占图库约 39%)会整条被静默丢掉: %s" % bad_id)
    print("   ✓ 断言通过: 没人再用 `len(sid) - 4` 拼页址(目录应取 id 前两位)")

    for name in fam:
        cs = source_tuple(os.path.join(HERE, name), "JIANPU_CATS", "CATS")
        if cs and any(c.endswith("gepu") for c in cs):
            assert "hechangpu" in cs, (
                "%s 的分类清单里没有 `hechangpu` —— 实测合唱谱只有这个分类里有, 整类会被漏扫" % name)
            spec = [c for c in cs if c in SPECIAL_CATS]
            if spec:
                print("   ⚠ %s 的分类清单里混进了专用谱类 %s(实测转不出简谱音符)" % (name, spec))
    print("   ✓ 断言通过: 扫分类的爬虫都收了 `hechangpu`")

    lint = [(n, ln, s) for n in fam for ln, s in text_in_judges(os.path.join(HERE, n))]
    for n, ln, s in lint:
        print("   ✗ %s:%d 还在用文本类型判据: %s" % (n, ln, s))
    assert not lint, ("**还在用 `\"简谱\" in <锚点正文>` 这种判据** —— 实测方括号里装的是歌手/分类名, "
                      "`[简谱]` 字样一条都没有, 这类判据会静静收 0")
    print("   ✓ 断言通过: 没人再用 `\"简谱\" in …` 这种文本判据")

    for name in fam:
        pats = [p for _ln, p in re_literals(os.path.join(HERE, name))]
        if any("<title" in p for p in pats) and not any("<h1" in p for p in pats):
            print("   ⚠ %s 拿 `<title>` 当曲名且没用 `<h1>` —— 实测 `<title>` 从 2025 起把歌手"
                  "追在曲名后面(`推车歌 焦阳  歌谱简谱网`), 会污染目录名/语料判重" % name)

    # ---- ③-jianpujia: 谱图判据必须认得**没有引号的 `src=`**(页面真身) ----
    print("\n=== ③-jianpujia 离线断言: 判据认得没有引号的 `src=` 吗(实测页面真身) ===")
    jbad = []
    for name in jfam:
        for ln, pat in jjudges.get(name, []):
            rx = re.compile(pat, re.I)
            if not any("image.jianpujia.com" in u.lower() for u in _urls(rx, JIANPUJIA_UNQUOTED)):
                jbad.append("%s:%d %s" % (name, ln, pat))
            elif not _urls(rx, JIANPUJIA_QUOTED_ABS):
                print("   ⚠ %s:%d 认不出带引号的绝对地址(老页/别处写法)" % (name, ln))
            if not _urls(rx, JIANPUJIA_QUOTED_REL):
                print("   ⚠ %s:%d 不认 `//image.jianpujia.com/…` 这种协议相对写法"
                      "(若老页还在用就是漏收)" % (name, ln))
    assert not jbad, (
        "**jianpujia 的谱图判据认不出没有引号的 `src=`** —— 页面真身就是\n"
        "     `<img … border=0 src=https://image.jianpujia.com/jianpudq/jianpu30/<hash>.png>`,\n"
        "     只认带引号的老判据会静静收 0 张(`完成: 0 首`而退出码 0):\n     " + "\n     ".join(jbad))
    print("   ✓ 断言通过: jianpujia %d 个爬虫共 %d 条谱图判据, 条条认得**无引号 src**"
          % (len(jfam), sum(len(v) for v in jjudges.values())))

    if a.offline:
        print("\n(--offline: 只跑了 ①②③, 没联网)")
        print("\n结论: 这一族 %d 个爬虫的**静态判据**都还合格。" % len(fam))
        return 0
    # ---- ④ 联网复核 ----
    print("\n=== ④-1 列表页: 按分类判简谱(新) vs 标题 startswith('[简谱]')(旧) ===")
    old_tot = new_tot = 0
    list_paths = []
    for cat in cats:
        for p in pages:
            u = "%s/%s%s" % (BASE, cat, "" if p == 1 else "/%d.htm" % p)
            try:
                h = get(u)
            except Exception as e:
                print("   %-46s 取不到: %s: %s" % (u, type(e).__name__, e))
                return 2
            items = ITEM_RE.findall(h)
            if cat in JIANPU_CATS:
                list_paths += [x[0] for x in items]
            old = [t for _, t in items if t.replace("&nbsp;", " ").strip().startswith(OLD_TAG)]
            new = [(path, t) for path, t in items if cat in JIANPU_CATS]
            old_tot += len(old)
            new_tot += len(new)
            print("   %-46s 旧判据 %2d 条 / 新判据 %2d 条   %s"
                  % (u, len(old), len(new),
                     ("样例: %r" % new[0][1].replace("&nbsp;", " ").strip()[:30]) if new else ""))
            time.sleep(1.1)
    print("   合计: 旧判据 %d 条 / 新判据 %d 条" % (old_tot, new_tot))
    assert new_tot > 0, "**新判据在简谱类分类上也收 0 条** —— 页面结构又变了, 得重新看"
    print("   ✓ 断言通过: 新判据(按分类判简谱) > 0 条")

    print("\n=== ④-2 详情页: 每个爬虫的谱图判据在**新页(/img9/)**与**老页(/img/)**上的命中数 ===")
    new_path = a.detail or NEW_PAGE_FALLBACK
    new_html = ""
    # 尽量从**最新的列表页**里现挑一条新页, 别只靠写死的样本(样本页哪天被迁移就失效了)
    for path in list_paths[:4]:
        try:
            h = get(BASE + path)
        except Exception:
            continue
        if "/img9/" in h:
            new_path, new_html = path, h
            break
        time.sleep(1.1)
    if not new_html:
        try:
            new_html = get(BASE + new_path)
        except Exception as e:
            print("   %s 取不到: %s: %s" % (new_path, type(e).__name__, e))
            return 2
    old_path = OLD_PAGE_FALLBACK
    try:
        old_html = get(BASE + old_path)
    except Exception as e:
        print("   %s(老页样本)取不到: %s: %s" % (old_path, type(e).__name__, e))
        old_html = ""
    oldre = re.compile(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)
    print("   新页 %s%s: /img9/ 出现 %d 次;  老页 %s: 旧判据 `/img/` 命中 %d 张"
          % (BASE, new_path, new_html.count("/img9/"), old_path, len(oldre.findall(old_html))))
    zero_new = []
    for name in fam:
        for ln, pat in judges[name]:
            rx = re.compile(pat, re.I)
            n_new = len(rx.findall(new_html))
            n_old = len(rx.findall(old_html)) if old_html else -1
            print("   %-28s L%-4d 新页 %2d 张 / 老页 %2d 张  %s"
                  % (name, ln, n_new, n_old, rx.findall(new_html)[:1]))
            if n_new <= 0:
                zero_new.append("%s:%d" % (name, ln))
            if n_old == 0:
                print("       ⚠ 这条判据对老页 0 命中 —— 若老页谱图确实还在 `/img/`, 就是漏收")
    assert not zero_new, (
        "**这些判据在真实的新页上收 0 张** —— 图床路径又变了(或页面结构变了): %s" % zero_new)
    print("   ✓ 断言通过: 每个爬虫的每条谱图判据在真实新页上都 > 0 张")

    print("\n结论: 这一族 %d 个爬虫的判据都是**当前有效**的(旧 `[简谱]` 文本判据实测 %d 条, "
          "已被按分类/按分类名的判据取代)。" % (len(fam), old_tot))
    return 0


if __name__ == "__main__":
    sys.exit(main())
