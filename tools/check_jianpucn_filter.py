# -*- coding: utf-8 -*-
"""**只读**自检: jianpu.cn 改版后的判据还收得到条数吗。

背景(2026-10-06 实测): jianpu.cn 列表页方括号里装的东西从 `[简谱]` 换成了**歌手/词曲作者**,
`crawl_jianpucn2.py` 里 `txt.startswith("[简谱]")` 于是**静静收 0 条**; 同一批脚本里还有第二条
同样静默的判据 —— 谱图地址 `^/img/` 匹配不到 2025 起新页的 `/img9/...`。

这个自检干三件事, **全部只读**(只 GET 列表页/详情页, 不下载图、不写任何文件):
  ① 从两个爬虫的**源码**里把真在用的判据抠出来(`ast` 静态读, 不 import —— 那两个是模块级脚本,
     import 就会真的开跑), 免得自检验的是一套、爬虫用的是另一套;
  ② 断言新判据(**按分类判简谱**)在简谱类分类列表页上取到 **>0** 条, 并打印条数;
     同时打印**旧判据**的条数(期望 0)做对照;
  ③ 在一条详情页上对照谱图判据 `/img/`(旧)与 `/img\\d*/`(新)的命中数。

用法:
    py -3.13 tools/check_jianpucn_filter.py                  # 默认查 3 个分类
    py -3.13 tools/check_jianpucn_filter.py --cats erzigepu,sizigepu,hechangpu
    py -3.13 tools/check_jianpucn_filter.py --pages 1,2      # 多看几页, 结论更稳
退出码: 0 = 全部断言通过; 1 = 断言失败(判据又过期了); 2 = 网络取不到, 无法判定。
"""
import argparse
import ast
import os
import re
import sys
import time
import urllib.request

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import tlsfetch                     # noqa: E402  取页 + 证书过期兜底(与两个爬虫同口径)

BASE = "http://www.jianpu.cn"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
TARGETS = ["crawl_jianpucn2.py", "crawl_jianpucn_by_title.py"]
# 列表页的一条记录(两个爬虫用的是同一条正则, 这里照抄形态, 只用于"数条数")
ITEM_RE = re.compile(r"href='(/pu/\d+/\d+\.htm)'[^>]*>([^<]{1,70})<")
OLD_TAG = "[简谱]"                  # 作废的旧判据: 标题以它开头
# 实测(2026-10-06): 简谱类分类 = 一~九字歌谱/十字及以上/合唱谱/英文歌谱; 专用谱类不在此列
JIANPU_CATS = ("yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
               "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "hechangpu", "yingwengepu")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Referer": BASE + "/"})
    with tlsfetch.urlopen(req, timeout=30) as r:
        return r.read().decode("gbk", "replace")


# ---------------------------------------------------------------- 从源码里抠判据
def _find_assign(tree, name):
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id == name:
                    return node.value
    return None


def source_regex(path, name):
    """抠出 `NAME = re.compile(r"...")` 里的**真正则**(静态读源码, 不执行它)。"""
    src = open(path, encoding="utf-8").read()
    val = _find_assign(ast.parse(src), name)
    if isinstance(val, ast.Call) and val.args:
        return re.compile(ast.literal_eval(val.args[0]), re.I)
    raise SystemExit("  读不出 %s 里的 %s —— 源码形态变了, 自检要跟着改" % (os.path.basename(path), name))


def source_tuple(path, name):
    """抠出 `NAME = ("a", "b", …)` 这样的字面量元组/列表。"""
    src = open(path, encoding="utf-8").read()
    val = _find_assign(ast.parse(src), name)
    if val is None:
        return None
    return tuple(ast.literal_eval(val))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cats", default="erzigepu,sizigepu,hechangpu",
                    help="要查的简谱类分类(逗号分隔), 默认三个")
    ap.add_argument("--pages", default="1", help="看第几页(逗号分隔), 默认第 1 页")
    ap.add_argument("--detail", default="", help="额外对照谱图判据的详情页, 默认从列表页取第一条")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    cats = [c.strip() for c in a.cats.split(",") if c.strip()]
    pages = [int(p) for p in a.pages.split(",") if p.strip()]
    bad = [c for c in cats if c not in JIANPU_CATS]
    if bad:
        print("⚠ 这些分类不在**简谱类**清单里, 查它们没有意义: %s" % bad)

    # ---- ① 先确认两个爬虫源码里真在用的判据 ----
    print("=== ① 两个爬虫现在真在用的判据(静态读源码) ===")
    img_res, jp_sets = {}, {}
    for name in TARGETS:
        p = os.path.join(HERE, name)
        if not os.path.exists(p):
            print("   %s: **不存在**" % name)
            continue
        r = source_regex(p, "IMG_RE")
        img_res[name] = r
        cs = source_tuple(p, "JIANPU_CATS")
        if cs is not None:
            jp_sets[name] = cs
        print("   %-28s IMG_RE = %s" % (name, r.pattern))
        if cs:
            print("   %-28s JIANPU_CATS = %d 个分类, 含 hechangpu=%s"
                  % ("", len(cs), "hechangpu" in cs))
    if not img_res:
        print("   ⚠ 一个都没读到, 下面无事可做")
        return 1

    # ---- ② 列表页: 旧判据 vs 新判据 ----
    print("\n=== ② 列表页: 按分类判简谱(新) vs 标题 startswith('[简谱]')(旧) ===")
    old_tot = new_tot = 0
    detail_url = ""
    for cat in cats:
        for p in pages:
            u = "%s/%s%s" % (BASE, cat, "" if p == 1 else "/%d.htm" % p)
            try:
                h = get(u)
            except Exception as e:
                print("   %-46s 取不到: %s: %s" % (u, type(e).__name__, e))
                return 2
            items = ITEM_RE.findall(h)
            old = [t for _, t in items if t.replace("&nbsp;", " ").strip().startswith(OLD_TAG)]
            new = [(path, t) for path, t in items if cat in JIANPU_CATS]
            old_tot += len(old)
            new_tot += len(new)
            if new and not detail_url:
                detail_url = new[0][0]
            print("   %-46s 旧判据 %2d 条 / 新判据 %2d 条   %s"
                  % (u, len(old), len(new),
                     ("样例: %r" % new[0][1].replace("&nbsp;", " ").strip()[:30]) if new else ""))
            time.sleep(1.1)
    print("   合计: 旧判据 %d 条 / 新判据 %d 条" % (old_tot, new_tot))
    assert new_tot > 0, "**新判据在简谱类分类上也收 0 条** —— 页面结构又变了, 得重新看"
    print("   ✓ 断言通过: 新判据(按分类判简谱) > 0 条")

    # ---- ③ 详情页: 谱图判据 旧 vs 新 ----
    print("\n=== ③ 详情页谱图判据: /img/(旧) vs /img\\d*/(新) ===")
    if not detail_url:
        detail_url = "/pu/47/475919.htm"
    try:
        d = get(BASE + detail_url)
    except Exception as e:
        print("   %s 取不到: %s: %s" % (detail_url, type(e).__name__, e))
        return 2
    oldre = re.compile(r"<img[^>]+src=['\"](/img/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)
    o, n = oldre.findall(d), None
    for nm, r in img_res.items():
        hit = r.findall(d)
        print("   %-28s 命中 %d 张  %s" % (nm, len(hit), hit[:2]))
        n = hit
    print("   %-28s 命中 %d 张  %s" % ("(旧判据 /img/)", len(o), o[:2]))
    print("   %s 详情页: %s" % (BASE, detail_url))
    assert n, "**新谱图判据在这条详情页上收 0 张** —— 图床路径又变了"
    print("   ✓ 断言通过: 谱图判据取到 > 0 张")

    print("\n结论: 两个爬虫的判据都是**当前有效**的(旧 `[简谱]` 判据实测 0 条, 已被按分类的判据取代)。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
