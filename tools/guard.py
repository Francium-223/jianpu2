# -*- coding: utf-8 -*-
"""`--help` 守卫的**唯一实现** —— 给没有 argparse 的工具一行就能变安全。

为什么需要: 项目自带的冒烟约定是"对每个 tools/*.py 跑一次 `--help`, 能 import 就算过"。
但**没有 argparse 的工具会把 `--help` 当正常参数** —— 于是那个探测动作会真的把它们跑起来。
2026-09-28 实测后果: `autopilot.py` 空等一小时、`add_copyright.py` 改写 266 个草稿、
`bench_batch.py` 开始加载模型重转写。全库 `tools/*.py` 里这样的工具有 **494 个**。

用法(库里只有这一份, 别复制):

    from guard import guard_help
    guard_help(__doc__)        # 放在 **import 之后、任何有副作用的模块级代码之前**

之后 `py tools/xxx.py --help` 会立刻打用法退出, 冒烟自检就能安全地探测所有工具。
"""
import sys

_SENTINEL = "JIANPU_GUARDED"


def guard_help(doc=None):
    """`-h/--help/--dry-help` -> 打用法并退出 0; 否则原样返回, 什么都不做。"""
    if any(a in ("-h", "--help") for a in sys.argv[1:]):
        text = (doc or "").strip()
        print(text if text else "(这个工具没有写 docstring)")
        print("\n[guard] 这是 --help 守卫打出来的用法; 没有执行任何实际动作。")
        raise SystemExit(0)
    return None
