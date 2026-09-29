# -*- coding: utf-8 -*-
"""同一个 `source=`（同一次抓取的那一页谱）在语料里有**多份成品**时，只留最好的一份，其余**移出**。

## 实测规模（2026-09-30）

语料 9,908 个 source 里 **888 个有不止一份**成品，共 **1,835 份**（多出来 **947 份** ≈ 语料的 8.7%）：
* **447 组内容完全相同**（纯重复：同一页被转过两遍）；
* **441 组内容有差异**（同一页被两代管线各转了一遍，音符数常常差很多：

  例 `jianpujia-7161`《你还要我怎样》 7 音 vs **1,783 音** —— 前者是"多页谱只转了一页"时代的残稿）。

不清理的代价：① 语料曲数虚高；② **并列时的"版本多优先"被灌水**（已单独修成按 source 去重）；
③ 同一首歌在库里出现两次、名字还不一样（`两.txt` vs `两只老虎_2.txt`）。

## 留哪一份（规则写在前面，透明可查）

按这个顺序挑：**① `status=ok`（人工校对过）优先；② 音符数多者优先，但 >2500 音的"织体"不算数
（用 2500 封顶，免得贝斯谱那种长稿赢过真旋律）；③ `confidence` 高者优先；④ 文件新者优先。**
其余**移**到 `scores-parked-dupsource/`（与 `scores/` 平级，不进语料，可原样放回），
并只针对被移走的文件名清掉 `by_*` 里的悬空链接。

用法:
  py -3.13 tools/dedupe_by_source.py            # 只报告(默认)
  py -3.13 tools/dedupe_by_source.py --apply    # 真移 + 重建 data.json(l)
"""
import argparse
import glob
import io
import json
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
PARK = os.path.join(DB, "scores-parked-dupsource")
NOTES_CAP = 2500            # 超过这个音数不算"更完整", 算"织体"(见上面规则)


def read_meta(p):
    t = io.open(p, encoding="utf-8", errors="replace").read()
    g = re.search(r"(?m)^source=(\S+)$", t)
    st = re.search(r"(?m)^status=(\S+)$", t)
    cf = re.search(r"(?m)^confidence=([\d.]+)$", t)
    ti = re.search(r"(?m)^title=(.*)$", t)
    body = t.split("%--", 1)[-1]
    n = len([x for x in body.split() if re.search(r"[1-7]", x)])
    try:
        c = float(cf.group(1)) if cf else 0.5
    except ValueError:
        c = 0.5
    return {"src": g.group(1) if g else "", "status": st.group(1) if st else "",
            "conf": c, "title": ti.group(1) if ti else "", "notes": n}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--cap", type=int, default=NOTES_CAP)
    a = ap.parse_args()

    groups = {}
    for p in glob.glob(os.path.join(SCORES, "*.txt")):
        # 跳过 `score.py` 解析时**瞬时**写出来的 `_buf.txt`/`_expand.txt`
        # (2026-09-30 实测: 另一个进程正在解析时 glob 会抓到它, 一读就 FileNotFound)
        b = os.path.basename(p)
        if b.endswith("_buf.txt") or b.endswith("_expand.txt"):
            continue
        try:
            m = read_meta(p)
        except FileNotFoundError:
            continue
        if m["src"]:
            groups.setdefault(m["src"], []).append((p, m))
    multi = {s: v for s, v in groups.items() if len(v) > 1}
    extra = sum(len(v) - 1 for v in multi.values())
    print(f"语料 {len(groups)} 个 source; 同源多份 {len(multi)} 组, 共多出 **{extra}** 份")

    def title_ok(t):
        """曲名"像话"吗 —— 单字/纯数字/带下划线(乱码稿的痕迹)都算不像话。"""
        return not (len(t) <= 1 or re.match(r"^[\d\s\-_.]+$", t) or t.count("_") >= 2)

    def rank(item):
        p, m = item
        capped = m["notes"] if m["notes"] <= a.cap else -1     # 织体封顶
        # **曲名质量排在音符数前面**: 同一页的两份稿, 名字被截断/乱码的那份多半是早期产物,
        # 而且留下的名字会被写进语料(实测 `谱.txt` 会赢过 `虫儿飞_2.txt` —— 那是反的)。
        return (0 if m["status"] == "ok" else 1, 0 if title_ok(m["title"]) else 1,
                -capped, -m["conf"], -os.path.getmtime(p))

    plans, ident = [], 0
    for s, v in sorted(multi.items()):
        v = sorted(v, key=rank)
        keep, drop = v[0], v[1:]
        if len({read_meta(p)["notes"] for p, _ in v}) == 1:
            ident += 1
        for p, m in drop:
            plans.append((s, os.path.basename(keep[0]), keep[1]["notes"], os.path.basename(p),
                          m["notes"], m["status"], m["conf"]))
    print(f"  其中内容完全相同的组 {ident}; 有差异的 {len(multi) - ident}")
    print(f"  将**移出** {len(plans)} 份(每组留 1 份) -> {PARK}")
    print("  例(留 | 移):")
    for s, kf, kn, df, dn, ds, dc in sorted(plans, key=lambda x: -(x[2] - x[4]))[:10]:
        print(f"    {s:<22} 留 {kf[:22]}({kn}音) | 移 {df[:22]}({dn}音,{ds})")
    with io.open(os.path.join(r"D:\Documents_D\jianpu2", "train-work", "dedupe_by_source.tsv"),
                 "w", encoding="utf-8", newline="\n") as g:
        g.write("source\t留\t留音数\t移出\t移出音数\t移出status\t移出confidence\n")
        for row in plans:
            g.write("\t".join(str(x) for x in row) + "\n")
    print("  明细 -> train-work/dedupe_by_source.tsv")
    if not a.apply:
        print("\n（只报告；加 --apply 才移 —— 移到 scores-parked-dupsource/，不删）")
        return 0

    os.makedirs(PARK, exist_ok=True)
    moved = links = 0
    for _s, _kf, _kn, df, _dn, _ds, _dc in plans:
        src = os.path.join(SCORES, df)
        if os.path.exists(src):
            shutil.move(src, os.path.join(PARK, df))
            moved += 1
        for root in sorted(os.listdir(DB)):
            d = os.path.join(DB, root)
            if not root.startswith("by_") or not os.path.isdir(d):
                continue
            for dirpath, _dirs, files in os.walk(d):
                if df in files:
                    p = os.path.join(dirpath, df)
                    try:
                        if os.path.islink(p):
                            os.unlink(p)
                            links += 1
                    except OSError:
                        pass
    print(f"\n已移出 {moved} 份 -> {PARK}; 清掉悬空链接 {links} 个")
    rc = subprocess.run([sys.executable, "-u", os.path.join(DB, "parse_scores.py")], cwd=DB)
    print(f"parse_scores 退出码 {rc.returncode}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
