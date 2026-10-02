# -*- coding: utf-8 -*-
"""低密度碎片守卫：把"页数够、却只转出几个音"的谱**移出语料**（只移不删）。

## 依据（实测，不要凭感觉改阈值）
* 全库密度普查（`tools/fragment_census.py`）：每页 <15 音的 **133 份 = 1.2%**。
* 把这 133 份按**页数**切开（普查自带这一列）：
    只 1 页  **18 份** —— 短曲/单页谱都在这里，**守卫不该动**；
    ≥2 页    **115 份** —— 页数够却只出这么点音 = 全库 **1.00%**，就是模型真失败的那批。
* 看图抽样（3 张，都是 ≥2 页的）：《宫廷宴舞》2 页民乐合奏 10 行 → 9 音；
  《剩下的盛夏》钢琴双手谱 → 11 音；《爱错（简和谱）》5 行带词带和弦 → 6 音。
  机制是**模型读不动就填休止**，而且**重转结果一样**（确定性失败）—— 所以修法不是重转，是守卫。
* 为什么不能用标题筛：133 份里只有 7 份标题带"钢琴/合唱"这类线索（126 份无线索）。

## 判据（本工具用的就是这一条，且**只读普查的结论**，不另算一套）
    每页音数 < THRESH 且 页数 >= MINPAGES
  —— 阈值与普查共用，所以"清单"与"普查报告"永远一致（单真源）。

## 用法
    py -3.13 tools/quarantine_lowdensity.py                 # 只列清单（默认 dry-run）
    py -3.13 tools/quarantine_lowdensity.py --per-page 10   # 换个阈值看会命中多少
    py -3.13 tools/quarantine_lowdensity.py --apply         # 真移（移进 ../jianpu-db/scores-lowdensity/）
    py -3.13 tools/quarantine_lowdensity.py --restore       # 按 manifest 原样移回（可逆）
产物：../jianpu-db/scores-lowdensity/manifest.tsv（文件名/曲名/出处/音节数/页数/密度/移动时间）

⚠ **本工具没有被任何流水线调用**（临时计划任务、`lowdigits_cleanup.ps1`、`finalize.py` 都不调它）：
   开不开、阈值取 10 还是 15，由人决定；`--apply` 不打就等于什么都没发生。
"""
import csv
import glob
import io
import os
import shutil
import subprocess
import sys
import time
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
guard_help(__doc__)

sys.stdout.reconfigure(encoding="utf-8")
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # jianpu2
CORPUS = os.path.join(os.path.dirname(ROOT), "jianpu-db")   # 兄弟仓库 jianpu-db
SCORES = os.path.join(CORPUS, "scores")
QUAR = os.path.join(CORPUS, "scores-lowdensity")
MANIFEST = os.path.join(QUAR, "manifest.tsv")


def argv(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return default


# 三个可注入项 —— 为了**能在临时副本上把 --apply / --restore 真跑一遍**（默认仍是真路径）。
# 给了 --scores 就认为是"演练模式"：跳过"流水线在跑就别动"的检查（那条是保护**真语料**的）。
SCORES_IN = argv("--scores", "")
SCORES = SCORES_IN or SCORES
QUAR = argv("--quarantine", QUAR)
MANIFEST = os.path.join(QUAR, "manifest.tsv")
CENSUS_IN = argv("--census", "")      # 给了就直接读这份普查 TSV, 不再现场跑 fragment_census.py
DRILL = bool(SCORES_IN)
APPLY = "--apply" in sys.argv
RESTORE = "--restore" in sys.argv
PER_PAGE = float(argv("--per-page", 15))
MINPAGES = int(argv("--min-pages", 2))
THRESH = float(argv("--thresh", PER_PAGE))


def census_rows():
    """跑普查拿清单（**同一个判据**，不另写一套密度算法）；`--census` 给了就直接读。"""
    if CENSUS_IN:
        src = CENSUS_IN
        print("读现成普查清单: " + src)
    else:
        out = os.path.join(ROOT, "_analysis", "lowdensity_census.tsv")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        cmd = [sys.executable, os.path.join(HERE, "fragment_census.py"),
               "--per-page", str(PER_PAGE), "--out", out]
        print("跑普查: " + " ".join(os.path.basename(c) for c in cmd))
        r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
        if r.returncode != 0:
            sys.exit("普查失败:\n" + (r.stderr or r.stdout or "")[-800:])
        src = out
    rows = []
    for line in io.open(src, encoding="utf-8"):
        if line.startswith("#") or not line.strip():
            continue
        p = line.rstrip("\n").split("\t")
        if len(p) < 6:
            continue
        rows.append(dict(ratio=float(p[0]), notes=int(p[1]), pages=int(p[2]),
                         title=p[3], stem=p[4], source=p[5]))
    return rows


def files_of(stem):
    got = []
    for ext in (".txt", ".json"):
        f = os.path.join(SCORES, stem + ext)
        if os.path.exists(f):
            got.append(f)
    return got


def do_restore():
    if not os.path.exists(MANIFEST):
        sys.exit("没有 manifest: " + MANIFEST)
    n = 0
    for row in csv.DictReader(io.open(MANIFEST, encoding="utf-8"), delimiter="\t"):
        for name in (row["file"].strip(),):
            src = os.path.join(QUAR, name)
            dst = os.path.join(SCORES, name)
            if os.path.exists(src):
                if os.path.exists(dst):
                    print("  跳过（语料里已有同名）: " + name)
                    continue
                shutil.move(src, dst)
                n += 1
    print("已移回 %d 个文件 -> %s" % (n, SCORES))
    print("（manifest 留着不动；确认无误后再手工清）")


def main() -> int:
    if RESTORE:
        do_restore()
        return 0

    busy = [p for p in subprocess.run(
        ["powershell", "-NoProfile", "-Command",
         "(Get-CimInstance Win32_Process -Filter \"name like '%python%'\").CommandLine"],
        capture_output=True, text=True).stdout.splitlines()
        if any(k in p for k in ("finalize.py", "to_jianpu_db", "transcribe_source"))]
    if busy and APPLY and not DRILL:
        sys.exit("语料流水线在跑（%d 个进程），先等它结束再 --apply" % len(busy))

    rows = census_rows()
    hit = [r for r in rows if r["ratio"] < THRESH and r["pages"] >= MINPAGES]
    miss = [r for r in rows if r not in hit]
    nofile = [r for r in hit if not files_of(r["stem"])]
    # 全库行数**实测**（读 data.jsonl 数行），不靠推算
    total = 0
    dj = os.path.join(CORPUS, "data.jsonl")
    if os.path.exists(dj):
        with io.open(dj, "rb") as f:
            for _ in f:
                total += 1
    print()
    print("普查可疑 %d 份 → 命中判据（每页 <%.0f 音 且 页数 ≥%d）: **%d 份**"
          % (len(rows), THRESH, MINPAGES, len(hit)))
    print("  没命中的 %d 份（其中只 1 页的 %d 份 —— 短曲在这里，守卫不碰）"
          % (len(miss), sum(1 for r in miss if r["pages"] < MINPAGES)))
    print("  命中但语料里找不到文件: %d 份%s" % (len(nofile), "（⚠ 不该有，先查）" if nofile else ""))
    if total:
        print("  命中占全库: %.2f%%（全库 data.jsonl 实测 %d 行）" % (len(hit) * 100.0 / total, total))
    print()
    print("最极端的 8 份:")
    for r in sorted(hit, key=lambda x: x["ratio"])[:8]:
        print("  %5.1f 音/页 · %3d 音 / %2d 页 · %-20s [%s]" % (r["ratio"], r["notes"], r["pages"], r["title"][:20], r["source"]))

    if not APPLY:
        print()
        print("(没加 --apply：只列清单，语料一个字节都没动)")
        print("清单在 _analysis/lowdensity_census.tsv（普查原样输出）")
        return 0

    os.makedirs(QUAR, exist_ok=True)
    moved = 0
    with io.open(MANIFEST, "w", encoding="utf-8", newline="") as mf:
        w = csv.writer(mf, delimiter="\t")
        w.writerow(["file", "title", "source", "notes", "pages", "notes_per_page", "moved_at"])
        for r in sorted(hit, key=lambda x: x["ratio"]):
            for f in files_of(r["stem"]):
                name = os.path.basename(f)
                shutil.move(f, os.path.join(QUAR, name))
                moved += 1
                w.writerow([name, r["title"], r["source"], r["notes"], r["pages"],
                            "%.2f" % r["ratio"], time.strftime("%Y-%m-%d %H:%M:%S")])
    print()
    print("已移出 %d 个文件（%d 份）-> %s" % (moved, len(hit), QUAR))
    print("可逆清单: " + MANIFEST + "   （移回: --restore）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
