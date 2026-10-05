# -*- coding: utf-8 -*-
"""抓取**硬止损**闸门 —— 空闲空间低于阈值就拒绝启动/立即收工(唯一实现)。

为什么必须有它(2026-10-06 实测): 本机只有**一块物理盘**(C: 350GiB + D: 602.6GiB 是同一块
NVMe 的两个卷), 所以"搬到别的盘"根本不释放空间。而盘上同时跑着一条**转写流水线**在写同一个
分区 —— 抓取一旦把盘写满, 流水线会一起死。因此抓取侧的纪律不是"尽量别写满", 而是
**留够余量并硬停**: 空闲空间 < `JIANPU_MIN_FREE_GIB`(默认 25 GiB) 就拒绝启动 + 立即收工。

对外:
    free_gib(path)      -> 该卷空闲 GiB
    check(path)         -> (ok, free_gib, msg)  ok=False 表示必须停
    reclaim(path, log)  -> 低于止损线时先跑图片滑动窗口腾空间; 返回腾完后的空闲 GiB
    guard(path, log)    -> 不 ok 就先 reclaim, 仍不 ok 再打日志并 raise SystemExit(3) —— 给启动器用
    worst_of(paths)     -> 一组路径里**最紧**的那个卷

**2026-10-06 更新(接上图片滑动窗口)**: 光"拒绝启动"只是把问题推给用户。现在低于止损线时,
    guard() 会**先调 tools/image_window.py --apply** 回收"已经转写进语料"的图目录, 腾出空间后
    再判一次; 还是不够才退出。窗口只删 `images-prep/**/<曲名>__<站>-<id>` 且 `source=<站>-<id>`
    已在 `jianpu-db/scores/*.txt` 里的目录; 保留区(qa_lists 点名 / 最近 7 天落盘 / 正在被进程
    读写 / 语料里查不到 source=)一律不碰 —— 判定口径的唯一实现在 tools/image_window.py。

开关(环境变量):
    JIANPU_MIN_FREE_GIB=30       止损线(只允许往 25 以上调)
    JIANPU_WINDOW_MARGIN_GIB=20  腾空间的目标 = 止损线 + 这个余量(默认 20)
    JIANPU_IMAGE_WINDOW=0        关掉自动腾空间(只判不删)

用法(启动器里):
    from crawl_disk_guard import guard, free_gib
    guard(images_root())            # 空间不够先自动腾, 还不行才退出, 不会开始抓
    ...抓完一轮...
    if not check(images_root())[0]:
        break                       # 每轮之间再查一次
"""
import os
import shutil
import subprocess
import sys

from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

# 硬止损线: 空闲空间低于它就停。用户口径 "空闲空间低于 25 GiB 就立刻停"。
DEFAULT_MIN_FREE_GIB = 25.0
DEFAULT_WINDOW_MARGIN_GIB = 20.0    # 腾空间的目标 = 止损线 + 这个余量
EXIT_DISK = 3                       # 专用退出码: 磁盘止损(与"抓完了"区分开)
WINDOW_TOOL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "image_window.py")


def window_margin_gib():
    """腾空间留多少余量(GiB)。`JIANPU_WINDOW_MARGIN_GIB` 可覆盖, 但不允许小于 5。"""
    v = os.environ.get("JIANPU_WINDOW_MARGIN_GIB", "").strip()
    try:
        x = float(v)
    except ValueError:
        x = DEFAULT_WINDOW_MARGIN_GIB
    return x if x >= 5.0 else DEFAULT_WINDOW_MARGIN_GIB


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


def _emit(log, line):
    """一行结果: 打印 + (可选)追加日志。日志写不进去也不能影响闸门。"""
    print(line, flush=True)
    if log:
        try:
            with open(log, "a", encoding="utf-8") as g:
                g.write(line + "\n")
        except OSError:
            pass


def reclaim(path, log=None, tag=""):
    """低于止损线时**先腾空间**: 跑 tools/image_window.py 回收已转写的图目录。

    回收口径的唯一实现在 tools/image_window.py(只删 `source=` 已在语料里的图目录,
    保留区不碰)。这里只负责"调它 + 把关键几行记进日志"。返回腾完后的空闲 GiB;
    没跑成 / 被关掉返回 NaN(闸门随后自己再判一次, 该停还是停, 不赌)。
    """
    pre = "[disk-guard]%s" % ((" " + tag) if tag else "")
    if os.environ.get("JIANPU_IMAGE_WINDOW", "1").strip() == "0":
        _emit(log, pre + " 图片滑动窗口已被 JIANPU_IMAGE_WINDOW=0 关掉, 不腾空间")
        return float("nan")
    if not os.path.exists(WINDOW_TOOL):
        _emit(log, pre + " 找不到 %s, 无法腾空间" % WINDOW_TOOL)
        return float("nan")
    target = min_free_gib() + window_margin_gib()
    cmd = [sys.executable, WINDOW_TOOL, "--apply", "--no-dry-run",
           "--target-free-gib", "%.1f" % target]
    _emit(log, pre + " 低于止损线 -> 先跑图片滑动窗口腾空间(目标空闲 %.1f GiB): %s"
          % (target, " ".join(cmd)))
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
        tail = [l for l in (r.stdout or "").splitlines() if "[image-window]" in l]
        for l in tail[-5:]:
            _emit(log, pre + "   " + l)
        if r.returncode != 0:
            _emit(log, pre + "   腾空间退出码 %d: %s" % (r.returncode, (r.stderr or "").strip()[-200:]))
    except Exception as e:                       # 腾空间失败不是闸门失败 —— 下面还会再判一次
        _emit(log, pre + "   腾空间没跑成: %s" % e)
    return free_gib(path)


def guard(path, log=None, tag=""):
    """启动前的闸门: 不够就**先腾空间**, 还不行才记日志 + SystemExit(EXIT_DISK)。返回空闲 GiB。"""
    ok, f, msg = check(path)
    if not ok:
        _emit(log, "[disk-guard]%s %s (路径 %s)" % ((" " + tag) if tag else "", msg, path))
        reclaim(path, log, tag)
        ok, f, msg = check(path)                 # 腾完再判一次: 只有这一步过了才放行
    _emit(log, "[disk-guard]%s %s (路径 %s)" % ((" " + tag) if tag else "", msg, path))
    if not ok:
        raise SystemExit(EXIT_DISK)
    return f


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    paths = sys.argv[1:] or [r"D:\Documents_D\jianpu2\images-prep", r"D:\Documents_D\_analysis"]
    log = os.environ.get("JIANPU_DISK_LOG") or None
    bad = []
    for p in paths:
        ok, f, msg = check(p)
        print("%-46s %-6s %.2f GiB  %s" % (p, "OK" if ok else "STOP", f, msg))
        if not ok:
            bad.append(p)
    if bad:
        # 启动器(crawl_stock_round.ps1 的 Test-Disk)靠**退出码**判断能不能抓: 低于止损线就先腾空间。
        seen = set()                     # 同一卷只腾一次(图库与日志盘常常同卷)
        for p in bad:
            drv = os.path.splitdrive(os.path.abspath(p))[0].lower()
            if drv in seen:
                continue
            seen.add(drv)
            reclaim(p, log)
        still = []
        for p in paths:
            ok, f, msg = check(p)
            print("%-46s %-6s %.2f GiB  %s(腾空间后)" % (p, "OK" if ok else "STOP", f, msg))
            if not ok:
                still.append(p)
        if still:
            sys.exit(EXIT_DISK)
    sys.exit(0)
