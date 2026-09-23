# -*- coding: utf-8 -*-
"""金曲清单的**覆盖缺口**分析 —— "检索不准"到底是不在库里, 还是名字对不上?

**只读**, 不改语料。产出一张 TSV + 一段结论:
  * `命中`      —— 用 eval_golden 的口径(norm/same 对 title/group)就能定位到;
  * `别名命中`  —— title 对不上, 但库里某首的 `alias=` 对得上(说明**库里有, 只是名字不同**);
  * `模糊候选`  —— 两边都差一点(相似度高/一方包含另一方) -> 需要人眼判一句;
  * `库里没有`  —— 连模糊候选都没有 -> 这是**真缺口**(要么转写, 要么这首本来就不在清单该覆盖的范围)。

用法:
    python3 tools/coverage_gap.py                       # 四个榜单, 输出到 _analysis/
    python3 tools/coverage_gap.py --out /tmp/gap.tsv
"""
import argparse
import difflib
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2/
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SKILL = os.path.join(ROOT, "skills", "jianpu-melody-lookup")
WORK = os.path.join(ROOT, "train-work")
for p in (SKILL,):
    if p not in sys.path:
        sys.path.insert(0, p)
from eval_golden import norm, same            # noqa: E402  **复用同一份口径**, 不另写
from lookup import group_of, pitch_and_oct    # noqa: E402


def read_list(path):
    """清单两种列数: `歌名<TAB>歌手` 与 `名次<TAB>歌名<TAB>歌手`(与 eval_golden 同一读法)。"""
    out = []
    for ln in io.open(path, encoding="utf-8"):
        s = ln.strip()
        if not s or s.startswith("#"):
            continue
        c = [x.strip() for x in s.split("\t")]
        if len(c) >= 3 and c[0].isdigit():
            out.append((c[1], c[2] if len(c) > 2 else ""))
        else:
            out.append((c[0], c[1] if len(c) > 1 else ""))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=os.path.join(DB, "data.jsonl"))
    ap.add_argument("--lists", nargs="*", default=sorted(
        os.path.join(WORK, f) for f in os.listdir(WORK) if f.startswith("eval_set_") and f.endswith(".tsv")))
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    rows = [json.loads(l) for l in io.open(a.data, encoding="utf-8") if l.strip()]
    corpus = []
    empty_titles = []
    for r in rows:
        title = group_of(r.get("title"))
        aliases = r.get("alias") or []
        if isinstance(aliases, str):
            aliases = [aliases]
        nt = norm(title)
        if not nt:
            # ⚠ norm() 会把整个名字都在括号里的曲名(如 `《NeW BOY》`)削成空串;
            #   空串用 `in` 做子串判定会**匹配一切**(实测: 76 个"模糊候选"里绝大多数
            #   都是被这个空串吸过去的假命中)。空名字直接不进候选池。
            empty_titles.append(title)
            continue
        n_pitch = len(pitch_and_oct(r.get("score"))[0])
        corpus.append({"file": (r.get("file") or [""])[0] if isinstance(r.get("file"), list) else r.get("file"),
                       "title": title, "nt": nt, "np": n_pitch,
                       "aliases": aliases, "na": [x for x in (norm(y) for y in aliases) if x]})

    out_lines = ["榜单\t曲名\t歌手\t判定\t库里曲名\t库里文件\t证据"]
    tot = {k: 0 for k in ("命中", "命中但太短", "别名命中", "模糊候选", "库里没有")}
    per_list = {}
    for path in a.lists:
        name = os.path.basename(path)[:-4]
        stat = {k: 0 for k in tot}
        for title, artist in read_list(path):
            n = norm(title)
            hit = next((c for c in corpus if same(c["nt"], n)), None)
            verdict, cf, ev = "库里没有", "", ""
            if hit:
                # eval_golden 只把 **>=11 音** 的谱算作检索目标 -> 太短的单独标出来,
                # 免得我的覆盖率和榜单口径对不上(实测差的那 1 首就是 <11 音)。
                if hit["np"] >= 11:
                    verdict, cf, ev = "命中", hit["title"], "title 相等/包含"
                else:
                    verdict, cf, ev = "命中但太短", hit["title"], f"只有 {hit['np']} 个音(检索下限 11, 榜单不算)" 
            else:
                ah = None
                for c in corpus:
                    for al, nal in zip(c["aliases"], c["na"]):
                        if nal and same(nal, n):
                            ah = (c, al); break
                    if ah:
                        break
                if ah:
                    verdict, cf, ev = "别名命中", ah[0]["title"], f"alias={ah[1]}"
                else:
                    best = None
                    for c in corpus:
                        r1 = difflib.SequenceMatcher(None, n, c["nt"]).ratio()
                        # 子串判定: **两边都要够长**(>=3), 且只在真的互相包含时给加成
                        if len(n) >= 3 and len(c["nt"]) >= 3 and (n in c["nt"] or c["nt"] in n):
                            r1 = max(r1, 0.75)
                        for nal in c["na"]:
                            if nal:
                                r1 = max(r1, difflib.SequenceMatcher(None, n, nal).ratio())
                        if best is None or r1 > best[0]:
                            best = (r1, c)
                    if best and best[0] >= 0.60:
                        verdict, cf = "模糊候选", best[1]["title"]
                        ev = f"相似度 {best[0]:.2f}"
            stat[verdict] += 1
            tot[verdict] += 1
            out_lines.append(f"{name}\t{title}\t{artist}\t{verdict}\t{cf}\t{cf and hit and hit['file'] or ''}\t{ev}")
        per_list[name] = stat

    print(f"库: {len(rows)} 首 (其中 {len(empty_titles)} 首规范化后是空名, 不进候选池: "
          f"{', '.join(empty_titles[:6])}{' …' if len(empty_titles) > 6 else ''})")
    for name, st in per_list.items():
        n = sum(st.values())
        print(f"\n{name}  共 {n} 首")
        for k in ("命中", "命中但太短", "别名命中", "模糊候选", "库里没有"):
            if st[k]:
                print(f"    {k:6s} {st[k]:3d}  ({st[k]/n*100:.1f}%)")
        print(f"    —— 与 eval_golden 同口径的覆盖率: {st['命中']}/{n} = {st['命中']/n*100:.1f}%")
    n = sum(tot.values())
    print(f"\n合计 {n} 首: 命中 {tot['命中']} ({tot['命中']/n*100:.1f}%) · "
          f"命中但太短 {tot['命中但太短']} · 别名命中 {tot['别名命中']} · "
          f"模糊候选 {tot['模糊候选']} · 真缺口 {tot['库里没有']}")

    out = a.out or os.path.join(os.path.dirname(ROOT), "_analysis", "金曲缺口清单.tsv")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    io.open(out, "w", encoding="utf-8", newline="\n").write("\n".join(out_lines) + "\n")
    print(f"\n明细 -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
