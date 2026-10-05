# -*- coding: utf-8 -*-
"""爬虫共用的两条纪律 —— **谱图页数上限**与**请求限速**(唯一实现, 别再各写一份)。

为什么要它(2026-10-06 实测复核):
  ① **硬截断会缺页**: 各爬虫原来把图数写死成 `imgs[:2]` / `imgs[:3]` / `imgs[:6]`, 而详情页的
     真实图数远不止 —— 实测 `http://www.jianpu.cn/pu/19/194129.htm`(《93海阔天空》)有 **6 张**,
     老写法只存 2 张, 其余 4 页**永远不会被下**, 谱子到手就是残的(而且退出码还是 0)。
     现在默认**不截断**; 真要限流时用环境变量 `JIANPU_MAX_PAGES=<n>` 给一个上限(n<=0 或非法 = 全部)。
  ② **族内限速不统一**: `crawl_jianpucn*.py` 是 1.0 秒/请求, 而 `crawl_qupu123*.py` 只有
     0.1~0.3 秒 —— 同一个站点被两套节奏打。统一走 `throttle()`, 默认 `JIANPU_RATE=1.0` 秒/请求,
     可用环境变量调大(调小无效 —— 纪律是"不低于 1 秒")。

对外:
    pages(imgs)   -> 该下哪些图(默认全部, 受 JIANPU_MAX_PAGES 约束)
    page_cap(n)   -> 只问上限(不切片), 供需要自己 enumerate 的调用方
    rate()        -> 当前限速(秒/请求)
    throttle()    -> 睡够"距上次请求 >= rate() 秒", 在每个网络请求**之前**调
    reset()       -> 清掉时间戳(测试用)

用法:
    from crawl_limits import pages, throttle
    for iu in pages(imgs):
        throttle()
        data = fetch(iu)
"""
import os
import sys
import time

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

# 纪律下限: 任何情况下不慢于 1 秒/请求(用户口径 "限速 >=1 秒/请求")。
FLOOR = 1.0
_last = [0.0]


def rate():
    """当前限速(秒/请求)。`JIANPU_RATE` 只能把节奏**放慢**; 填小了按 `FLOOR` 兜底。"""
    v = os.environ.get("JIANPU_RATE", "").strip()
    try:
        r = float(v)
    except ValueError:
        r = FLOOR
    return r if r > FLOOR else FLOOR


def throttle():
    """睡够"距上次请求 >= rate() 秒"。在每个网络请求**之前**调用。

    与"每个请求后面 `time.sleep(1)`"等价, 但不会把请求本身的耗时也算进去 —— 后者会让
    实际节奏慢一倍(之前 `crawl_jianpucn*.py` 就是这个毛病: sleep 1 秒 + 请求 0.4 秒 ≈ 1.4 秒/请求)。
    """
    r = rate()
    dt = time.monotonic() - _last[0]
    if dt < r:
        time.sleep(r - dt)
    _last[0] = time.monotonic()


def reset():
    """清掉时间戳 —— 只给测试用, 正常爬虫不该调。"""
    _last[0] = 0.0


def page_cap(n):
    """图数上限。默认**不截断**(返回 n); `JIANPU_MAX_PAGES=<k>`(k>0) 时返回 min(n, k)。"""
    v = os.environ.get("JIANPU_MAX_PAGES", "").strip()
    try:
        k = int(v)
    except ValueError:
        k = 0
    return n if k <= 0 else min(n, k)


def pages(imgs):
    """该下哪些图 —— 默认全部。返回 list, 顺序不变。"""
    lst = list(imgs)
    return lst[:page_cap(len(lst))]


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    print("rate()      = %.2f 秒/请求 (JIANPU_RATE=%r)" % (rate(), os.environ.get("JIANPU_RATE")))
    print("page_cap(6) = %d (JIANPU_MAX_PAGES=%r)" % (page_cap(6), os.environ.get("JIANPU_MAX_PAGES")))
