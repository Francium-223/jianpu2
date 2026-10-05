# -*- coding: utf-8 -*-
"""抓取**硬止损**闸门 —— 空闲空间低于阈值就拒绝启动/立即收工(唯一实现)。

为什么必须有它(2026-10-06 实测): 本机只有**一块物理盘**(C: 350GiB + D: 602.6GiB 是同一块
NVMe 的两个卷), 所以"搬到别的盘"根本不释放空间。而盘上同时跑着一条**转写流水线**在写同一个
分区 —— 抓取一旦把盘写满, 流水线会一起死。因此抓取侧的纪律不是"尽量别写满", 而是
**留够余量并硬停**: 空闲空间 < `JIANPU_MIN_FREE_GIB`(默认 25 GiB) 就拒绝启动 + 立即收工。

对外:
    free_gib(path)      -> 该卷空闲 GiB
    check(path)         -> (ok, free_gib, msg)  ok=False 表示必须停
    guard(path, log)    -> 不 ok 就打日志并 raise SystemExit(3) —— 给启动器用
    worst_of(paths)     -> 一组路径里**最紧**的那个卷

用法(启动器里):
    from crawl_disk_guard import guard, free_gib
    guard(images_root())            # 空间不够直接退出, 不会开始抓
    ...抓完一轮...
    if not check(images_root())[0]:
        break                       # 每轮之间再查一次
"""
import os
import shutil
import sys

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

# 硬止损线: 空闲空间低于它就停。用户口径 "空闲空间低于 25 GiB 就立刻停"。
DEFAULT_MIN_FREE_GIB = 25.0
EXIT_DISK = 3                       # 专用退出码: 磁盘止损(与"抓完了"区分开)


def min_free_gib():
    """止损线(GiB)。`JIANPU_MIN_FREE_GIB` 可覆盖, 但**只允许往上调**(往下调等于放松纪律)。"""
    v = os.environ.get("JIANPU_MIN_FREE_GIB", "").strip()
    try:
        x = float(v)
    except ValueError:
        x = DEFAULT_MIN_FREE_GIB
    return x if x > DEFAULT_MIN_FREE_GIB else DEFAULT_MIN_FREE_GIB


def free_gib(path):
    """`path` 所在卷的空闲 GiB。路径不存在时向上找到最近的已存在祖先再问。"""
    p = os.path.abspath(path)
    while p and not os.path.exists(p):
        parent = os.path.dirname(p)
        if parent == p:
            break
        p = parent
    try:
        return shutil.disk_usage(p).free / (1024.0 ** 3)
    except OSError:
        return float("nan")


def check(path):
    """返回 (ok, free_gib, 说明)。ok=False 表示**必须停**。"""
    f = free_gib(path)
    lim = min_free_gib()
    if f != f:                       # NaN: 问不到就把"问不到"当不安全, 不赌
        return False, f, "空闲空间问不到(%s) -> 按不安全处理" % path
    ok = f >= lim
    return ok, f, ("空闲 %.2f GiB %s 止损线 %.2f GiB" % (f, ">=" if ok else "<", lim))


def worst_of(paths):
    """一组路径里**最紧**的那个卷 —— 多目标(图库 + 日志盘)时用它。"""
    worst = None
    for p in paths:
        f = free_gib(p)
        if worst is None or f < worst[1]:
            worst = (p, f)
    return worst or ("", float("nan"))


def guard(path, log=None, tag=""):
    """启动前的闸门: 不够就记日志 + SystemExit(EXIT_DISK)。返回空闲 GiB。"""
    ok, f, msg = check(path)
    line = "[disk-guard]%s %s (路径 %s)" % ((" " + tag) if tag else "", msg, path)
    print(line, flush=True)
    if log:
        try:
            with open(log, "a", encoding="utf-8") as g:
                g.write(line + "\n")
        except OSError:
            pass
    if not ok:
        raise SystemExit(EXIT_DISK)
    return f


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    for p in (sys.argv[1:] or [r"D:\Documents_D\jianpu2\images-prep", r"D:\Documents_D\_analysis"]):
        ok, f, msg = check(p)
        print("%-46s %-6s %.2f GiB  %s" % (p, "OK" if ok else "STOP", f, msg))
