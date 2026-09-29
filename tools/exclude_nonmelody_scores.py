# -*- coding: utf-8 -*-
"""把语料里"名字像非旋律谱"的成品**移出**（只移不删），并清掉它们留下的悬空链接。

为什么备着这个脚本：2026-09-30 实测语料里有 **46 首**名字带 贝斯/鼓谱/六线/指弹/吉他谱
（占 10,892 的 0.42%，音符数中位 333，其中 5 首 >1000 音）—— 它们是**贝斯谱/鼓谱/六线谱**，
数字长得像简谱但内容不是旋律，进了旋律语料只会当噪声。用户当时说"要不要清出去等你定"，
所以这里**默认只报告**，加 `--apply` 才动；动的时候也是**移**到 `scores-parked-nonmelody/`
（跟 `scores/` 平级，不进语料），不是删。

顺带清链接：`by_*` 那些 `by_artist/…/<文件名>` 是指向 `scores/<文件名>` 的**符号链接**，
文件一移走它们就成悬空链接 —— 本脚本**只针对被移走的那几个文件名**逐个 unlink（不做全库扫描）。

用法:
  py -3.13 tools/exclude_nonmelody_scores.py            # 只报告(默认)
  py -3.13 tools/exclude_nonmelody_scores.py --apply    # 真移 + 清链接 + 重建 data.json(l)
  py -3.13 tools/exclude_nonmelody_scores.py --skip parse   # 移完不自动重建(自己手动跑)
"""
import argparse
import io
import os
import re
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

DB = r"D:\Documents_D\jianpu-db"
SCORES = os.path.join(DB, "scores")
PARK = os.path.join(DB, "scores-parked-nonmelody")
JUNK = re.compile(r"贝斯|鼓谱|架子鼓|打击乐|六线|指弹谱|吉他谱")


def note_count(path):
    try:
        txt = io.open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return -1
    body = txt.split("%--", 1)[-1]
    return len([t for t in body.split() if re.search(r"[1-7]", t)])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="真移(默认只报告)")
    ap.add_argument("--skip", default="", help="逗号分隔要跳过的步骤: parse")
    a = ap.parse_args()

    hits = []
    for f in sorted(os.listdir(SCORES)):
        if f.endswith(".txt") and JUNK.search(f):
            hits.append((note_count(os.path.join(SCORES, f)), f))
    hits.sort(reverse=True)
    total = len([f for f in os.listdir(SCORES) if f.endswith(".txt")])
    print(f"语料 {total} 份成品; 名字像非旋律谱的 **{len(hits)}** 份"
          f"（占 {len(hits) / max(1, total) * 100:.2f}%）")
    for n, f in hits:
        print(f"   {n:>5} 音  {f}")
    if not hits:
        return 0
    if not a.apply:
        print("\n（只报告；加 --apply 才真移 —— 移到 scores-parked-nonmelody/，不删）")
        return 0

    os.makedirs(PARK, exist_ok=True)
    moved, links = 0, 0
    for _n, f in hits:
        src = os.path.join(SCORES, f)
        dst = os.path.join(PARK, f)
        if os.path.exists(src):
            shutil.move(src, dst)
            moved += 1
        # 只针对这个文件名清链接(不做全库扫描)
        for root in sorted(os.listdir(DB)):
            d = os.path.join(DB, root)
            if not root.startswith("by_") or not os.path.isdir(d):
                continue
            for dirpath, _dirs, files in os.walk(d):
                if f in files:
                    p = os.path.join(dirpath, f)
                    try:
                        if os.path.islink(p):
                            os.unlink(p)
                            links += 1
                    except OSError:
                        pass
    print(f"\n已移出 {moved} 份 -> {PARK}；清掉悬空链接 {links} 个")
    if "parse" not in [s.strip() for s in a.skip.split(",")]:
        print("重建 data.json / data.jsonl ...")
        rc = subprocess.run([sys.executable, "-u", os.path.join(DB, "parse_scores.py")], cwd=DB)
        print(f"parse_scores 退出码 {rc.returncode}")
    print("提醒: 这是**移出**不是删除 —— 想放回去, 把文件从 "
          f"{PARK} 移回 {SCORES} 再跑一次 parse_scores 即可。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
