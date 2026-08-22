# -*- coding: utf-8 -*-
"""给通过"补猜拍号"校验的草稿实际写入拍号行。用法: python tools/fix_timesig.py"""
import os
import re
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from tools.validate_drafts import DIRS, JIANPU_LY, VENDOR, extract_body

env = dict(os.environ)
env["PYTHONPATH"] = VENDOR + os.pathsep + env.get("PYTHONPATH", "")

TIME_SIGS = ["4/4", "3/4", "2/4", "6/8", "3/8", "4/8"]


def check(body):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".txt",
                                     delete=False, dir="tools") as f:
        f.write(body)
        tmp = f.name
    try:
        r = subprocess.run([sys.executable, JIANPU_LY, tmp],
                           capture_output=True, text=True, timeout=60, env=env)
        return r.returncode == 0
    finally:
        os.unlink(tmp)


def main():
    fixed = 0
    for d in DIRS:
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith(".txt"):
                continue
            path = os.path.join(d, name)
            text = open(path, encoding="utf-8").read()
            body = extract_body(path)
            if not body or re.search(r"(?m)^\d+/\d+\s*$", body):
                continue
            if check(body):  # 原样已通过
                continue
            for ts in TIME_SIGS:
                if check(ts + "\n" + body):
                    # 把拍号行插到 %-- 之后
                    idx = text.find("%--")
                    if idx >= 0:
                        pos = idx + 3
                        text = text[:pos] + "\n" + ts + text[pos:]
                    else:
                        text = ts + "\n" + text
                    open(path, "w", encoding="utf-8").write(text)
                    print(f"  补拍号 {ts}: {d}/{name}")
                    fixed += 1
                    break
    print(f"共修正 {fixed} 首")


if __name__ == "__main__":
    main()
