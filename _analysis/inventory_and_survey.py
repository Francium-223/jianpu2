# -*- coding: utf-8 -*-
"""算账用的**实测**: ①各站"每首真实图数"抽样 ②jianpu.cn 12 类可达规模 ③qupu123 音符。

为什么必须重测图数: images-prep 里的目录是**被截断过的**(imgs[:2]/[:3]/[:6]),
直接拿"平均 2.04 / 1.35 张"当真实值会**低估**剩余需求 —— 那正是要修的那个 bug 造成的偏差。

只读, 不写任何文件。全程 >=1 秒/请求。
"""
import random
import re
import sys
import time
import urllib.error
import urllib.request

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, "tools")
import tlsfetch  # noqa: E402

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
Q = "https://www.qupu123.com"
J = "http://www.jianpu.cn"
JIMG = re.compile(r"<img[^>]+src=['\"](/img\d*/[^'\"]+\.(?:jpg|gif|png))['\"]", re.I)
QIMG = re.compile(r'<img[^>]+src="([^"]+?\.(?:jpg|jpeg|png|gif))"', re.I)


def qget(u):
    req = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": Q + "/"})
    with tlsfetch.urlopen(req, timeout=35) as r:
        return r.read().decode("utf-8", "replace")


def jget(u):
    req = urllib.request.Request(u, headers={"User-Agent": UA, "Referer": J + "/"})
    with urllib.request.urlopen(req, timeout=35) as r:
        return r.read().decode("gbk", errors="replace")


def size_of(u, kind):
    req = urllib.request.Request(u, headers={"User-Agent": UA,
                                             "Referer": (Q if kind == "q" else J) + "/"})
    with tlsfetch.urlopen(req, timeout=60) as r:
        n = 0
        while True:
            b = r.read(1 << 16)
            if not b:
                break
            n += len(b)
        return n


print("############ A) jianpu.cn 12 类: 末页与可达规模 ############", flush=True)
CATS = ["yizigepu", "erzigepu", "sanzigepu", "sizigepu", "wuzigepu", "liuzigepu",
        "qizigepu", "bazigepu", "jiuzigepu", "shizijiyishang", "hechangpu", "yingwengepu"]
grand = 0
PER = 30


def page_ok(cat, p):
    u = "%s/%s" % (J, cat) if p == 1 else "%s/%s/%d.htm" % (J, cat, p)
    try:
        h = jget(u)
    except urllib.error.HTTPError as e:
        return (False, 0) if e.code == 404 else (None, 0)
    except Exception:
        return (None, 0)
    n = len(re.findall(r"href='(/pu/\d+/\d+\.htm)'", h))
    return (True, n)


for cat in CATS:
    time.sleep(1.0)
    ok, n1 = page_ok(cat, 1)
    if not ok:
        print("  %-16s 首页取不到" % cat, flush=True)
        continue
    # 末页: 先**指数扩张**找一个已知的失败上界, 再在 (lo 好, hi 坏) 之间二分。
    # ⚠ 第一版把失败页丢掉了(hi 没跟着更新), 于是 lo==hi, 二分退化成"最后一个 2 的幂" ——
    #   sizigepu 报 1024、wuzigepu 报 1024 就是这么来的(全是**下界**, 不是末页)。
    lo, hi = 1, 2
    while True:
        time.sleep(1.0)
        ok2, _ = page_ok(cat, hi)
        if not ok2:
            break
        lo = hi
        hi *= 2
        if hi > 8192:
            break
    while lo + 1 < hi:
        mid = (lo + hi) // 2
        time.sleep(1.0)
        ok3, _ = page_ok(cat, mid)
        if ok3:
            lo = mid
        else:
            hi = mid
    time.sleep(1.0)
    okl, nl = page_ok(cat, lo)
    est = (lo - 1) * PER + (nl if okl else PER)
    grand += est
    print("  %-16s 末页 %-5d 首页条目 %d 末页条目 %d -> 估 %d 首" % (cat, lo, n1, nl, est), flush=True)
print("  jianpu.cn 12 简谱类合计(估): %d" % grand, flush=True)

print("\n############ B) jianpucn 每首真实图数(抽样) ############", flush=True)
ids = []
for cat in CATS:
    for p in (1, 3, 9, 25):
        time.sleep(1.0)
        ok, _ = page_ok(cat, p)
        if not ok:
            continue
        u = "%s/%s" % (J, cat) if p == 1 else "%s/%s/%d.htm" % (J, cat, p)
        try:
            h = jget(u)
        except Exception:
            continue
        for x in re.findall(r"href='(/pu/\d+/\d+\.htm)'", h):
            ids.append(x)
ids = list(dict.fromkeys(ids))
print("  候选详情页 %d 个" % len(ids), flush=True)
random.seed(20261006)
random.shuffle(ids)
jhist = []
for x in ids[:40]:
    u = J + x
    try:
        h = jget(u)
    except Exception as e:
        print("    %s 失败 %s" % (u, type(e).__name__), flush=True)
        time.sleep(1.0)
        continue
    imgs = [z for z in dict.fromkeys(JIMG.findall(h)) if "logo" not in z.lower()]
    jhist.append(len(imgs))
    print("    %-34s 图 %d" % (x, len(imgs)), flush=True)
    time.sleep(1.0)
if jhist:
    print("  jianpucn 抽样 %d 首: 均值 %.3f 张 · 中位 %d · max %d · 分布 %s"
          % (len(jhist), sum(jhist) / len(jhist), sorted(jhist)[len(jhist) // 2],
             max(jhist), {k: jhist.count(k) for k in sorted(set(jhist))}), flush=True)

print("\n############ C) qupu123 每首真实图数(抽样) + 单图字节 ############", flush=True)
qs = []
for p in (1, 40, 150, 400, 700):
    u = "%s/tongsu/" % Q if p == 1 else "%s/tongsu/%d.html" % (Q, p)
    try:
        h = qget(u)
    except Exception as e:
        print("   列表第%d页失败 %s" % (p, type(e).__name__), flush=True)
        time.sleep(1.2)
        continue
    it = re.findall(r'href="(/tongsu/[a-z]+/(?:p\d+|[a-z0-9_]+)\.html)"', h)
    qs += it[:12]
    print("   列表第%d页 -> 取 %d 个详情页" % (p, len(it[:12])), flush=True)
    time.sleep(1.2)
qs = list(dict.fromkeys(qs))
random.shuffle(qs)
qhist = []
qbytes = []
for x in qs[:30]:
    try:
        h = qget(Q + x)
    except Exception as e:
        print("    %s 失败 %s" % (x, type(e).__name__), flush=True)
        time.sleep(1.2)
        continue
    imgs = re.findall(QIMG, h)
    imgs = [urllib.parse.urljoin(Q + "/", z) for z in dict.fromkeys(imgs)]
    imgs = [z for z in imgs if "/Public/Uploads/" in z or "/data2/uploads/" in z]
    qhist.append(len(imgs))
    print("    %-40s 谱图 %d 张" % (x, len(imgs)), flush=True)
    for z in imgs[:1]:
        try:
            qbytes.append(size_of(z, "q"))
        except Exception:
            pass
        time.sleep(1.0)
    time.sleep(1.2)
if qhist:
    print("  qupu123 抽样 %d 首: 均值 %.3f 张 · 中位 %d · max %d · 分布 %s"
          % (len(qhist), sum(qhist) / len(qhist), sorted(qhist)[len(qhist) // 2],
             max(qhist), {k: qhist.count(k) for k in sorted(set(qhist))}), flush=True)
if qbytes:
    print("  qupu123 单图字节抽样 %d 张: 均值 %.0f KB · 中位 %.0f KB"
          % (len(qbytes), sum(qbytes) / len(qbytes) / 1024,
             sorted(qbytes)[len(qbytes) // 2] / 1024), flush=True)
print("\nDONE", flush=True)
