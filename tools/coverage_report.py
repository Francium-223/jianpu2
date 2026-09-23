# -*- coding: utf-8 -*-
"""一键出"覆盖率报告"(markdown): 三口径严格覆盖 + 质量分层 + 缺口名单 + 检索评测数字。

用法: py -3.13 tools/coverage_report.py   -> train-work/coverage_report.md
"""
import glob
import io
import os
import re
import sys

sys.path.insert(0, "tools")
os.chdir(r"D:\Documents_D\jianpu2")
sys.stdout.reconfigure(encoding="utf-8")
import title_match as TM

DIG = "1234567"
SOURCES = [
    ("① 已交付 `jianpu-db-out/scores`", ["jianpu-db-out/scores/*.txt"]),
    ("② + `batch-out`(待入库)", ["jianpu-db-out/scores/*.txt", "batch-out/*.txt"]),
    ("③ + `batch-out-dup`(乐观上界)", ["jianpu-db-out/scores/*.txt", "batch-out/*.txt",
                                      "batch-out-dup/*.txt"]),
]


def notes_of(f):
    try:
        toks = [t for t in io.open(f, encoding="utf-8", errors="replace").read().split()
                if t and not t.startswith("%") and "=" not in t]
    except Exception:
        return 0
    return sum(1 for t in toks if t.rstrip(".'-") and t.rstrip(".'-")[-1] in DIG)


LIST = []
for line in io.open("train-work/mandopop_list.txt", encoding="utf-8"):
    line = line.rstrip("\n")
    if not line.strip() or line.startswith("#"):
        continue
    p = line.split("\t")
    LIST.append((p[0].strip(), p[1].strip() if len(p) > 1 else ""))
n = len(LIST)

out = []
out.append("# 华语流行金曲 · 语料覆盖率报告")
out.append("")
out.append(f"- 清单: `train-work/mandopop_list.txt`，**{n} 首**（自拟清单，非官方榜单；"
           f"选取标准见文件头注释）")
out.append(f"- 匹配规则: `tools/title_match.py`（剥类型后缀/编号前缀后**精确相等**才算命中；"
           f"子串包含只作为待人工复核的'宽松'项，**不计入**覆盖）")
out.append(f"- 生成: `py -3.13 tools/coverage_report.py`")
out.append("")
out.append("## 1. 三口径严格覆盖率")
out.append("")
out.append("| 口径 | 严格命中 | 覆盖率 |")
out.append("|---|---|---|")
detail = {}
for lab, pats in SOURCES:
    keys = {}
    for pat in pats:
        for f in glob.glob(pat):
            nm = os.path.basename(f)[:-4]
            for k in (TM.head_of(nm), nm.split("__")[0]):
                if k.strip():
                    keys[k] = max(keys.get(k, 0), notes_of(f))
    rows = []
    for t, a in LIST:
        verdict, who, nn = "缺", "", 0
        for k in keys:
            v = TM.match(k, t)
            if v == "严格":
                # **空谱不算覆盖**: 实测有 `爱很简单`/`剪爱` 命中的谱是 0 音符(转写失败),
                # 只看"标题在不在库里"会把这种情况算成覆盖, 是虚高。
                verdict, who, nn = ("严格" if keys[k] >= 1 else "空谱"), k, keys[k]
                if verdict == "严格":
                    break
            if v == "宽松" and verdict == "缺":
                verdict, who, nn = "宽松", k, keys[k]
        rows.append((t, a, verdict, who, nn))
    ok = sum(1 for r in rows if r[2] == "严格")
    empty = sum(1 for r in rows if r[2] == "空谱")
    out.append(f"| {lab} | {ok}/{n} | **{ok/n*100:.1f}%** |" + (f"  另 {empty} 首只有空谱" if empty else ""))
    detail[lab] = rows

rows = detail[SOURCES[1][0]]
st = [r for r in rows if r[2] == "严格"]
out.append("")
out.append("## 2. 命中的谱够不够用（质量分层，口径②）")
out.append("")
out.append("| 门槛 | 首数 | 占比 |")
out.append("|---|---|---|")
for th in (1, 30, 50, 100, 200):
    k = sum(1 for r in st if r[4] >= th)
    out.append(f"| ≥ {th} 音符 | {k} | {k/n*100:.1f}% |")
weak = sorted([r for r in st if r[4] < 50], key=lambda r: r[4])
if weak:
    out.append("")
    out.append("**覆盖了但转写过短（<50 音符，检索价值低）**：" +
               "、".join(f"{r[0]}({r[4]})" for r in weak))

miss = [r[0] for r in detail[SOURCES[0][0]] if r[2] in ("缺", "空谱")]
loose_only = [r[0] for r in detail[SOURCES[0][0]] if r[2] == "宽松"]
out.append("")
out.append(f"## 3. 已交付口径的缺口（{len(miss)+len(loose_only)} 首 = 真缺 {len(miss)} + 仅宽松撞名 {len(loose_only)}）")
out.append("")
out.append("**真缺/空谱**：" + (" / ".join(miss) if miss else "(无)"))
out.append("")
out.append("**只有子串撞名（宽松档）—— 实测绝大多数是假阳性，按'缺'处理**：" +
           (" / ".join(loose_only) if loose_only else "(无)"))
out.append("")

# 检索评测(如果已经跑过)
out.append("## 4. 检索评测（最近一次落盘的数字）")
out.append("")
found_any = False
for lab, path, key in (
        ("同版自匹配(Top-1)", "train-work/retrieval_eval_neighbor.tsv", None),
        ("留一版本(凭记忆哼)", "train-work/retrieval_holdout.tsv", None),
        ("容忍漏音(indel)", "train-work/retrieval_indel.tsv", None),
        ("轮廓(contour)", "train-work/retrieval_contour.tsv", None)):
    if not os.path.exists(path):
        continue
    found_any = True
    lines = [l for l in io.open(path, encoding="utf-8", errors="replace").read().splitlines() if l.strip()]
    out.append(f"- **{lab}** (`{path}`, {len(lines)} 行): 见文件；尾部 3 行：")
    for l in lines[-3:]:
        out.append(f"    - `{l[:110]}`")
if not found_any:
    out.append("(尚未跑)"
             )

out.append("")
out.append("## 5. 已知问题（不要只看覆盖率数字）")
out.append("")
out.append("- **转写伪影**：页眉大字标题被读成一排音符（开头 ≥4 同音占 9.80%，串内 3.66%，2.7 倍）。"
           "证据与建议修法见 `train-work/qa_head_artifact.md`。")
out.append("- **短片段判别力有限**：见 `train-work/frag_ambiguity.log`（L=13 丢八度口径不唯一 14.8%）。")
out.append("- **宽松命中大量假阳性**，本报告不计入覆盖。")

with io.open("train-work/coverage_report.md", "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
print("\n".join(out[:14]))
print(f"\n... 完整报告 -> train-work/coverage_report.md ({len(out)} 行)")
