# -*- coding: utf-8 -*-
"""修"曲名被截断成单字/前缀"的谱：把 batch-out 里**乱码名**的转录稿改回**干净目录名**。

## 病根（2026-09-30 查出来的）

图库目录名是干净的（`两只老虎简谱_儿歌_…__jianpujia-15847`），但**早期一批 batch-out 文件名是
mojibake**（UTF-8 被按 latin-1 解，坏字节用下划线顶替，形如
`ä¸¤å_ªè__è__ç®_è°±_…__jianpujia-15847.txt`）。转换器按**文件名**取曲名，
`fix_mojibake()` 只能救回没坏掉的那几个字节 → 曲名被截断成 `两`、`丽`、`亲`、`以`…
（实测语料里 **97 首单字标题**、3 首纯数字标题，另有若干"只剩前缀"的。）

## 修法（只移不删）

对每个受影响的 source：把 `batch-out/<乱码名>.txt`（与同名 `.json` 边车）**改名**成
`batch-out/<干净目录名>.txt` —— 之后转换/重建就会取到完整曲名。**不删任何东西**，也不直接改语料里的
`title=`（那会被下一次重建冲掉；改输入才是根治）。加 `--apply` 才动，默认只报告。

用法:
  py -3.13 tools/repair_truncated_titles.py              # 只报告
  py -3.13 tools/repair_truncated_titles.py --apply      # 改名(只移不删)
"""
import argparse
import glob
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guard import guard_help        # noqa: E402  `--help` 守卫(唯一实现见 tools/guard.py)
import to_jianpu_db as T            # noqa: E402  曲名口径**只有一份**: title_of()

ROOT = r"D:\Documents_D\jianpu2"
BOUT = os.path.join(ROOT, "batch-out")
DB = r"D:\Documents_D\jianpu-db"
MOJI = re.compile(r"[ÃÂÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ]")


def looks_mojibake(base):
    return bool(MOJI.search(base)) or base.count("_") >= 3


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    # 1) 语料里"可疑"的曲名
    #   三类(2026-09-30 实测):
    #     ① 单字 / 纯数字        —— 乱码名只救回一两个字节(`两`、`17`)
    #     ② 名字里带 `_` 连串    —— 未命名/下划线顶替坏字节(`中__年`、`乡__路_谱`)
    #     ③ `未命名-<站点>-<id>` —— 抓取时就没拿到标题
    def dirty(t):
        return (len(t) <= 1 or bool(re.match(r"^[\d\s\-_.]+$", t))
                or "__" in t or t.count("_") >= 2 or t.startswith("未命名")
                or bool(re.search(r"(jianpu\.cn|qupu123|jianpujia|jianpucn)", t)))

    sus = {}
    for line in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        t = (d.get("title") or "")
        s = (d.get("source") or [""])[0]
        if s and dirty(t):
            sus[s] = t
    print(f"语料里可疑曲名(单字/纯数字/下划线/未命名) {len(sus)} 个 source")

    # 2) batch-out 索引: source -> [文件名]
    idx = {}
    for p in glob.glob(os.path.join(BOUT, "*.txt")):
        b = os.path.basename(p)[:-4]
        m = re.search(r"__([A-Za-z0-9_]+-\d+)$", b)
        if m:
            idx.setdefault(m.group(1), []).append(b)

    # 3) 干净目录名(图库) -> 候选曲名
    plans = []
    for s, t in sorted(sus.items()):
        dirs = [os.path.basename(d) for d in
                glob.glob(os.path.join(ROOT, "images-prep", "*", "*__" + s)) +
                glob.glob(os.path.join(ROOT, "images", "*", "*__" + s))]
        cand = ""
        for d in dirs:
            c = T.title_of(d)
            if len(c) > len(cand):
                cand = c
        cur_names = idx.get(s, [])
        bad = [n for n in cur_names if looks_mojibake(n.split("__")[0])]
        if len(cand) > len(t) and bad and dirs:
            plans.append((s, t, cand, bad[0], dirs[0]))
    print(f"能修(干净目录名给出的曲名更长 且 batch-out 里确实有乱码名) **{len(plans)}** 份\n")
    for s, t, cand, bad, good in plans[:20]:
        print(f"   {s:<22} {t!r:<10} -> {cand!r}")
    if len(plans) > 20:
        print(f"   … 其余 {len(plans) - 20} 份见报告")
    with io.open(os.path.join(ROOT, "train-work", "repair_truncated_titles.tsv"),
                 "w", encoding="utf-8", newline="\n") as g:
        g.write("source\t现在(截断)\t应为\t乱码稿\t干净目录\n")
        for row in plans:
            g.write("\t".join(row) + "\n")
    print(f"\n明细 -> train-work/repair_truncated_titles.tsv")
    if not a.apply:
        print("（只报告；加 --apply 才改名 —— 只移不删）")
        return 0
    done = 0
    for s, _t, _cand, bad, good in plans:
        for ext in (".txt", ".json"):
            src = os.path.join(BOUT, bad + ext)
            dst = os.path.join(BOUT, good + ext)
            if os.path.exists(src) and not os.path.exists(dst):
                os.rename(src, dst)
                done += 1
    print(f"\n已改名 {done} 个文件（乱码名 -> 干净目录名）")
    print("下一步：跑一次转换/重建，语料里的曲名与文件名就会跟着变正 "
          "(`tools/rebuild_when_idle.py --convert --rescue --import --site …`)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
