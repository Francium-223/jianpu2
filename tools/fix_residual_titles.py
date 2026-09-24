# -*- coding: utf-8 -*-
"""落地「旋律克隆审计」里那 9 条**标题-残名**提案（2026-09-25 夜）。

背景: `audit_melody_clones.py` 只出提案(只读)。这 9 条的性质是"同一份/同一首的另一个转写,
挂了被截断的曲名" —— 于是**搜不到**: 曲名是「谱」「讲」「亲」「丽」这种, 谁也不会去搜。
逐对看内容后分两类处理:

  * **音高序列完全相同** -> 残名那份是纯重复: 移出 `scores/`(进 `scores-suspect/`, 不删, 可回滚);
  * **序列略有差异**(同一首的不同转写) -> 保留, 但**改名 + 改回真曲名**(`曲名_2.txt`), 让它归到同一组。

用法:
    python3 tools/fix_residual_titles.py            # 只打印计划(dry-run)
    python3 tools/fix_residual_titles.py --apply    # 真做(移动/改名 + 写 title=)
"""
import argparse
import io
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
SCORES = os.path.join(DB, "scores")
SUSPECT = os.path.join(DB, "scores-suspect")
sys.path.insert(0, os.path.join(ROOT, "skills", "jianpu-melody-lookup"))
import jptok                                       # noqa: E402

# (残名文件, 对侧完整曲名) —— 来自 _analysis/旋律克隆提案.tsv 的"标题-残名/未命名"那 10 条
PAIRS = [
    ("谱.txt", "祝福"),
    ("讲.txt", "听妈妈讲那过去的事情"),
    ("亲.txt", "母亲草原刘志毅词夏宝森曲"),
    ("丽_3.txt", "美丽的草原谢淑清词雷晓峰曲"),
    ("两.txt", "两只老虎"),
    ("画（邓紫棋.txt", "画（邓紫棋）"),
    ("未命名-jianpujia-394083.txt", "草原海陈世慧词张艺军曲"),
]


def digits(path):
    body = []
    for ln in io.open(path, encoding="utf-8", errors="replace"):
        t = ln.strip()
        if not t or t.startswith("%"):
            continue
        if t.startswith("%END"):
            break
        if "=" in t and not t[0].isdigit() and not t.startswith("subtitle"):
            continue
        body.append(t)
    return "".join(str(jptok.parse_token(x)[0]) for x in " ".join(body).split() if jptok.is_pitch(x))


def free_name(base):
    """曲名_2.txt -> 曲名_3.txt ...(避开已存在的)"""
    for i in range(2, 50):
        p = os.path.join(SCORES, "%s_%d.txt" % (base, i))
        if not os.path.exists(p):
            return p
    raise SystemExit("!! 同名文件太多: " + base)


def retitle(path, title):
    out, done = [], False
    for ln in io.open(path, encoding="utf-8", errors="replace"):
        if not done and ln.startswith("title="):
            out.append("title=%s\n" % title)
            done = True
        else:
            out.append(ln)
    if not done:                                    # 没有 title= 就在第一行注释后插
        out.insert(1, "title=%s\n" % title)
    io.open(path, "w", encoding="utf-8", newline="\n").write("".join(out))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    os.makedirs(SUSPECT, exist_ok=True)

    for name, full in PAIRS:
        src = os.path.join(SCORES, name)
        if not os.path.isfile(src):
            print(f"  跳过(不在): {name}")
            continue
        d_src = digits(src)
        d_full = None
        for cand in (full + ".txt", full + "_2.txt"):
            p = os.path.join(SCORES, cand)
            if os.path.isfile(p):
                d_full = digits(p)
                break
        same = bool(d_full) and d_src == d_full
        print(f"  {name[:26]:<28} {len(d_src):>4} 音 -> "
              + ("**完全相同 -> 隔离**" if same else f"改名 + title={full}"))
        if not a.apply:
            continue
        if same:
            shutil.move(src, os.path.join(SUSPECT, name))
        else:
            dst = free_name(full)
            shutil.move(src, dst)
            retitle(dst, full)
    if a.apply:
        io.open(os.path.join(SUSPECT, "README_residual_titles.md"), "w", encoding="utf-8").write(
            "# 隔离出来的「残名」重复谱（2026-09-25）\n\n"
            "这些文件的**音高序列**与同目录里名字完整的那份逐字相同，只是文件名/曲名被截断\n"
            "（如「谱」=《祝福》、「讲」=《听妈妈讲那过去的事情》）。移到这里不删，随时可移回 `scores/`。\n"
            "依据: `_analysis/旋律克隆提案.tsv`（`tools/audit_melody_clones.py` 出的提案）。\n")
        print("\n已落地。记得: python3 %s 然后跑自检" % os.path.join(DB, "parse_scores.py"))
    else:
        print("\n(dry-run，没动任何文件；加 --apply 才真做)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
