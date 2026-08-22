# -*- coding: utf-8 -*-
"""用本地 jianpu-ly.py 批量验证草稿格式。用法: python tools/validate_drafts.py [输出目录...]"""
import os
import re
import subprocess
import sys
import tempfile

JIANPU_LY = r"D:\Documents_D\jianpu-ly\jianpu-ly.py"
VENDOR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "vendor")

DIRS = sys.argv[1:] or [
    "scores-draft", "scores-draft2", "scores-draft3", "scores-draft4",
    "scores-draft5", "scores-draft-pucn", "scores-draft-pujia",
]

env = dict(os.environ)
env["PYTHONPATH"] = VENDOR + os.pathsep + env.get("PYTHONPATH", "")


def extract_body(path):
    """取 %-- 之后的正文 (去掉 %END 和元数据)。"""
    text = open(path, encoding="utf-8").read()
    idx = text.find("%--")
    body = text[idx + 3:] if idx >= 0 else text
    body = body.replace("%END", "").strip()
    return body


TIME_SIGS = ["4/4", "3/4", "2/4", "6/8", "3/8", "4/8"]


def validate(body):
    """先按原样验证; 若失败且无拍号, 依次尝试常见拍号。返回 (是否通过, 说明)。"""
    base_err = None
    r = _run(body)
    if r[0]:
        return True, "原样通过"
    base_err = r[1]
    if re.search(r"(?m)^\d+/\d+\s*$", body):
        return False, base_err
    for ts in TIME_SIGS:
        r = _run(ts + "\n" + body)
        if r[0]:
            return True, f"补拍号 {ts} 后通过"
    return False, base_err


def _run(body):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".txt",
                                     delete=False, dir="tools") as f:
        f.write(body)
        tmp = f.name
    try:
        r = subprocess.run([sys.executable, JIANPU_LY, tmp],
                           capture_output=True, text=True, timeout=60, env=env)
        return r.returncode == 0, r.stderr.strip()[:150]
    except Exception as e:
        return False, str(e)
    finally:
        os.unlink(tmp)


def main():
    total = ok = 0
    results = []
    for d in DIRS:
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if not name.endswith(".txt"):
                continue
            path = os.path.join(d, name)
            body = extract_body(path)
            if not body:
                continue
            total += 1
            passed, err = validate(body)
            if passed:
                ok += 1
            results.append((passed, d, name, err))
    print(f"验证完成: {ok}/{total} 通过, {total - ok} 失败")
    for passed, d, name, err in results:
        if not passed:
            print(f"  [FAIL] {d}/{name}: {err}")
    with open("validation_report.txt", "w", encoding="utf-8") as f:
        f.write(f"通过 {ok}/{total}\n\n")
        for passed, d, name, err in results:
            f.write(f"{'OK  ' if passed else 'FAIL'} {d}/{name} {err}\n")


if __name__ == "__main__":
    main()
