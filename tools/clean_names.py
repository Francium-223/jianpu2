# -*- coding: utf-8 -*-
"""清洗 jianpu-db-out/scores 的文件名与 title=（爬虫留下的 HTML 实体等垃圾）。

典型垃圾: `苹果香&nbsp;&nbsp;.txt`、`中秋情_&nbsp;&nbsp;.txt` —— `&nbsp;` 是爬虫从 HTML 取
标题时**没做实体解码**留下的; 同类还有 `&amp; &quot; &#39; &hellip;` 和数字实体 `&# 123;`。

处理:
  * `html.unescape` 解全部实体（含数字实体）
  * 文件名里 Windows 非法字符 \\/:*?"<>| -> `_`；空白压成一个、首尾清理
  * 连续下划线/下划线夹空格收敛为单个 `_`
  * 同时在文件内同步 `%<名字>.txt` 与 `title=`
用法: py -3.13 tools/clean_names.py [--apply]     （默认只报告）
"""
import html
import os
import re
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

APPLY = "--apply" in sys.argv
DIR = "jianpu-db-out/scores"
BAD = re.compile(r'[\\/:*?"<>|\x00-\x1f]')


def clean_text(s):
    """标题用: 反复解实体(源站有双重转义 &amp;nbsp;) + 压空白(标题里可以有引号等)。"""
    for _ in range(5):
        t = html.unescape(s)
        if t == s:
            break
        s = t
    s = s.replace("\u00a0", " ")
    s = re.sub(r"\s+", " ", s)
    return s.strip()


def clean_fname(s):
    """文件名用: 与 to_jianpu_db 的命名约定**保持一致**（空白写成 `_`），再去掉 Windows 非法字符。
    注意别图好看改成空格 —— 管线写文件时用 `_`, 改过一次就会被下次重建改回去 ✗。"""
    s = clean_text(s)
    s = BAD.sub("_", s)
    s = re.sub(r"\s+", "_", s)
    s = re.sub(r"_{2,}", "_", s)
    return s.strip(" ._") or "untitled"


def main():
    files = [f for f in sorted(os.listdir(DIR)) if f.endswith(".txt")]
    plan, collide, unchanged = [], [], 0
    for fn in files:
        p = os.path.join(DIR, fn)
        try:
            txt = open(p, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        m = re.search(r"^title=(.*)$", txt, re.M)
        if not m:
            continue
        old = m.group(1)
        new = clean_text(old)
        new_fn = clean_fname(old) + ".txt"
        if new == old and new_fn == fn:
            unchanged += 1
            continue
        tgt = os.path.join(DIR, new_fn)
        if new_fn != fn and os.path.exists(tgt):
            # 撞车 = **同名但不同来源**的另一份谱（如 `一分钱` 与 `一分钱&nbsp;` 来自不同站点）。
            # 不该跳过(跳过就永远留着脏名字), 而应保留消歧后缀: 找下一个空位 _2/_3…
            # 注意: 判断"被占"时要排除**文件自己** —— 否则 `X_2.txt` 会因为自己占着 `X_2` 而
            # 一路让到 `X_3`, 白改一次名(实测踩过)。
            base = new_fn[:-4]
            k = 2
            cand = f"{base}_{k}.txt"
            while cand != fn and os.path.exists(os.path.join(DIR, cand)):
                k += 1
                cand = f"{base}_{k}.txt"
            new_fn = cand
            tgt = os.path.join(DIR, new_fn)
        plan.append((fn, new_fn, old, new, txt))

    print(f"scores {len(files)} 份：需改名 {len(plan)}，名字撞车跳过 {len(collide)}，本来干净 {unchanged}")
    for fn, new_fn, old, new, _t in plan[:12]:
        print(f"  {fn}   ->   {new_fn}" + (f"    (title: {old!r} -> {new!r})" if old != new else ""))
    if len(plan) > 12:
        print(f"  … 还有 {len(plan)-12} 份")
    for a, b in collide[:5]:
        print(f"  [撞车] {a} 与 {b} 冲突 -> 跳过")

    if not APPLY:
        print("（只报告；加 --apply 才真改）")
        return
    n = 0
    for fn, new_fn, old, new, txt in plan:
        p, tgt = os.path.join(DIR, fn), os.path.join(DIR, new_fn)
        if old != new:
            txt = re.sub(r"^title=.*$", "title=" + new, txt, count=1, flags=re.M)
        if new_fn != fn:
            txt = re.sub(r"^%.*$", "%" + new_fn, txt, count=1, flags=re.M)
        open(tgt, "w", encoding="utf-8").write(txt)
        if tgt != p:
            os.remove(p)
        n += 1
    print(f"已处理 {n} 份")


if __name__ == "__main__":
    main()
