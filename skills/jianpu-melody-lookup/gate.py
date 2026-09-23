# -*- coding: utf-8 -*-
"""自检门的一次性入口 —— 所有检索/评测脚本开头调用 `gate.gate(DATA)`。

过不了就直接退出, 不允许"带着坏口径继续跑出好看的数字"。
结果在同进程内缓存, 只算一次。
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_checked = {}


def gate(data_path=None, quiet=False):
    key = data_path or ""
    if key in _checked:
        return _checked[key]
    sys.path.insert(0, os.path.join(HERE, "selfcheck"))
    import selfcheck
    ok, rep = selfcheck.check(data_path)
    _checked[key] = ok
    if not quiet:
        print("[自检] " + " | ".join(rep))
    if not ok:
        print("[自检] **未通过** —— 本脚本结果不可信, 已中止。")
        sys.exit(3)
    return ok
