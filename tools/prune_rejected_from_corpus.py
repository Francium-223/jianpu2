# -*- coding: utf-8 -*-
"""把语料里**流水线已经不再生产**的曲谱移出去（只移不删，默认只报告）。

## 实测（2026-09-30）

语料 **11,388** 份，而流水线当前的成品（`jianpu-db-out/scores`，finalize 刚重建过）只有 **8,718** 份。
两边对齐后，语料里 **2,709 份的名字在成品里已经没有了**：

| 类别 | 份数 | 含义 |
|---|---|---|
| 同 source 在成品里还在（换了名字） | **815** | 旧版本/落选版残留 —— `dedupe_by_source.py` 覆盖的就是这批 |
| source 在成品里彻底没了 | **1,360** | 被流水线**整条判废**（非纯简谱 / 高念白 / 0 音符 / 版本择优落选） |
| source 为空（判不了） | 534 | 老数据没有 `source=`，不硬动 |

为什么语料会留着这些：语料是**只增不删**的（`import_finished_scores.py` 只拷不覆盖/不删，
为的是保护人工修改），而 finalize 把不合口径的稿子移去 `batch-out-dup/`、成品重建时也不再产出它们
—— **没人负责把语料里对应那份撤掉**。本工具补的就是这一步。

## 口径（保守）

* 判据：**语料这份的 `source=` 在成品里找不到任何一个文件** ⇒ 认为流水线不再生产它。
* **跳过 `status=ok`**（人工校对过的，哪怕流水线不产了也留着）。
* **跳过没有 `source=` 的**（无从判断，不硬动）。
* 其余**移**到 `scores-parked-rejected/`（与 `scores/` 平级，不进语料，可原样放回），
  并只针对被移走的文件名清掉 `by_*` 里的悬空链接。
* 默认 dry-run。

用法:
  py -3.13 tools/prune_rejected_from_corpus.py            # 只报告
  py -3.13 tools/prune_rejected_from_corpus.py --apply    # 真移 + 重建 data.json(l)
"""
import argparse
import glob
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
ROOT = r"D:\Documents_D\jianpu2"
SCORES = os.path.join(DB, "scores")
PARK = os.path.join(DB, "scores-parked-rejected")
STAGING = os.path.join(ROOT, "jianpu-db-out", "scores")


def meta(p):
    t = io.open(p, encoding="utf-8", errors="replace").read()
    s = re.search(r"(?m)^source=(\S+)$", t)
    st = re.search(r"(?m)^status=(\S+)$", t)
    return (s.group(1) if s else ""), (st.group(1) if st else "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    live = set()
    for p in glob.glob(os.path.join(STAGING, "*.txt")):
        s, _st = meta(p)
        if s:
            live.add(s)
    print(f"成品里活着的 source: {len(live)} 个")

    plans, skipped_ok, no_src = [], 0, 0
    for p in sorted(glob.glob(os.path.join(SCORES, "*.txt"))):
        b = os.path.basename(p)
        if b.endswith("_buf.txt") or b.endswith("_expand.txt"):
            continue
        try:
            s, st = meta(p)
        except OSError:
            continue
        if st == "ok":
            skipped_ok += 1
            continue
        if not s:
            no_src += 1
            continue
        if s not in live:
            plans.append((b, s))
    print(f"语料里'流水线已不再生产'的: **{len(plans)}** 份"
          f"（另有 status=ok 跳过 {skipped_ok} 份、无 source 跳过 {no_src} 份）")
    for b, s in plans[:12]:
        print(f"   {b[:40]:<42} source={s}")
    with io.open(os.path.join(ROOT, "train-work", "prune_rejected.tsv"), "w",
                 encoding="utf-8", newline="\n") as g:
        g.write("文件\tsource\n")
        for b, s in plans:
            g.write(f"{b}\t{s}\n")
    print("   明细 -> train-work/prune_rejected.tsv")
    if not a.apply:
        print(f"\n(dry-run；加 --apply 才移 —— 移到 {PARK}，不删)")
        return 0

    os.makedirs(PARK, exist_ok=True)
    moved = links = 0
    for b, _s in plans:
        src = os.path.join(SCORES, b)
        if os.path.exists(src):
            shutil.move(src, os.path.join(PARK, b))
            moved += 1
        for root in sorted(os.listdir(DB)):
            d = os.path.join(DB, root)
            if not root.startswith("by_") or not os.path.isdir(d):
                continue
            for dirpath, _dirs, files in os.walk(d):
                if b in files:
                    q = os.path.join(dirpath, b)
                    try:
                        if os.path.islink(q):
                            os.unlink(q)
                            links += 1
                    except OSError:
                        pass
    print(f"\n已移出 {moved} 份 -> {PARK}；清掉悬空链接 {links} 个")
    rc = subprocess.run([sys.executable, "-u", os.path.join(DB, "parse_scores.py")], cwd=DB)
    print(f"parse_scores 退出码 {rc.returncode}")
    print("想放回去：把文件从 parked 目录移回 scores/ 再跑一次 parse_scores。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
