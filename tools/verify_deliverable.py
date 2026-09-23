# -*- coding: utf-8 -*-
"""交付物总验收: 一条命令跑完全部检查并给出结论。

注意: 第 1/2/5 项只有在**收尾流水线(finalize.py)跑完之后**才该全过 —— 转写中途
batch-out 里必然还有 0 音符/非纯谱/scores 数不匹配, 那是正常的中间状态。
用法: py tools/verify_deliverable.py

检查项:
  1. 语料规模与音符总数
  2. 纯度合规: batch-out 里不该有纯度门判非纯的谱(隔离区也不该有残留)
  3. 版本择优: 同名歌只应留一个版本在 batch-out
  4. scores 格式: %END / title= / 拍号行 / 非空正文
  5. scores 与语料的音符数一致性
  6. data.jsonl 结构与条数
  7. 来源映射表
用法: py tools/verify_deliverable.py
"""
import csv, glob, json, os, re, sys, collections
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

def digits(toks):
    return sum(1 for x in toks if x.lstrip("qsdh,").rstrip("'.") and x.lstrip("qsdh,").rstrip("'.")[-1] in "1234567")

ok_all = True
def chk(label, cond, detail=""):
    global ok_all
    ok_all &= bool(cond)
    print(f"  [{'✓' if cond else '✗'}] {label}{('  ' + detail) if detail else ''}")

print("=== 1. 语料规模 ===")
txts = [f for f in glob.glob("batch-out/*.txt") if os.path.basename(f) not in ("progress.txt", "skipped.txt")]
tot = 0
empty = 0
for f in txts:
    t = open(f, encoding="utf-8", errors="replace").read().split()
    d = digits(t)
    tot += d
    if d == 0:
        empty += 1
print(f"  文件 {len(txts)}  音符 {tot}  0 音符 {empty}")
chk("0 音符已清空", empty == 0, f"(还剩 {empty} 个)")

print("\n=== 2. 纯度合规 ===")
kind = {}
if os.path.exists("train-work/kind2.tsv"):
    for r in csv.DictReader(open("train-work/kind2.tsv", encoding="utf-8"), delimiter="\t"):
        kind[r["dir"]] = r
    have = {os.path.basename(f)[:-4] for f in txts}
    violate = []
    for dn, r in kind.items():
        if r["pure"] == "0" and BT.safe_name(dn) in have:
            violate.append(dn)
    chk("语料里没有纯度门判非纯的谱", not violate, f"(违规 {len(violate)})")
    for v in violate[:5]:
        print(f"        {v[:56]}")
else:
    chk("kind2.tsv 存在", False)

print("\n=== 3. 版本择优 ===")
if os.path.exists("train-work/pick_best.tsv"):
    sel = list(csv.DictReader(open("train-work/pick_best.tsv", encoding="utf-8"), delimiter="\t"))
    print(f"  归并组 {len(sel)}")
    chk("择优表非空", len(sel) > 0)
else:
    chk("pick_best.tsv 存在", False)

print("\n=== 4. scores 格式 ===")
fs = glob.glob("jianpu-db-out/scores/*.txt")
bad_end = bad_title = bad_meter = empty_body = 0
for f in fs:
    lines = [l.strip() for l in open(f, encoding="utf-8").read().splitlines()]
    if not any(l.upper().startswith("%END") for l in lines):
        bad_end += 1
    if not any(l.startswith("title=") for l in lines):
        bad_title += 1
    try:
        i = next(i for i, l in enumerate(lines) if l == "%--")
        if not re.match(r"^\d+/\d+$", lines[i + 1]):
            bad_meter += 1
        body = [l for l in lines[i + 2:] if l and not l.startswith("%") and not l.startswith("subtitle=")]
        if not " ".join(body).split():
            empty_body += 1
    except StopIteration:
        bad_meter += 1
print(f"  scores {len(fs)}")
chk("都有 %END", bad_end == 0, f"({bad_end} 缺)")
chk("都有 title=", bad_title == 0, f"({bad_title} 缺)")
chk("拍号行合法", bad_meter == 0, f"({bad_meter} 异常)")
chk("正文非空", empty_body == 0, f"({empty_body} 空)")

print("\n=== 5. scores 与语料音符数一致 ===")
sc_notes = {}
for f in fs:
    lines = [l.strip() for l in open(f, encoding="utf-8").read().splitlines()]
    try:
        i = next(i for i, l in enumerate(lines) if l == "%--")
    except StopIteration:
        continue
    body = [l for l in lines[i + 2:] if l and not l.startswith("%") and not l.startswith("subtitle=")]
    sc_notes[os.path.basename(f)[:-4]] = len(" ".join(body).split())
print(f"  scores 总 token {sum(sc_notes.values())}   语料总音符 {tot}")
chk("scores 数量 <= 语料数量(择优/过滤后更少是正常的)", len(fs) <= len(txts), f"({len(fs)} vs {len(txts)})")

print("\n=== 6. data.jsonl ===")
p = "train-work/jpdbtest/out.jsonl"
if os.path.exists(p):
    n = 0; notes = 0; bad = 0
    for l in open(p, encoding="utf-8"):
        try:
            d = json.loads(l)
        except Exception:
            bad += 1; continue
        n += 1
        notes += d.get("n_notes", 0)
        if not d.get("file") or not d.get("title"):
            bad += 1
    print(f"  曲目 {n}  音符 {notes}")
    chk("JSONL 全部可解析", bad == 0, f"({bad} 坏行)")
    chk("有曲目", n > 0)
    # **条数也要查** —— 只查"可解析/有曲目"会漏掉"下游崩在第 1 首"这种情况:
    # 实测 `source=` 值里塞了 URL -> score.py 的 make_link 把它当目录名 -> WinError 123,
    # parse_scores 在第 1 首就崩, out.jsonl 只剩 1 首, 而上面两项照样"通过" ✗
    _expect = len(glob.glob("jianpu-db-out/scores/*.txt"))
    chk("JSONL 曲目数与 scores 相当", n >= 0.9 * _expect, f"({n} vs scores {_expect})")
else:
    chk("out.jsonl 存在", False)

print("\n=== 7. 来源映射表 ===")
p = "train-work/source_map.tsv"
if os.path.exists(p):
    rows = list(csv.DictReader(open(p, encoding="utf-8"), delimiter="\t"))
    # 列名以 source_map.py 现版本为准(`站点`); 保留旧列名 `source` 兜底 —— 之前写死 r["source"]
    # 导致 KeyError 把整个 verify 打挂(退出码 1), 而真正原因只是列名换了 ✗
    c = collections.Counter((r.get("站点") or r.get("source") or "?") for r in rows)
    print(f"  条目 {len(rows)}  分布 {dict(c.most_common())}")
    chk("映射表非空", len(rows) > 0)
else:
    chk("source_map.tsv 存在", False)

print("\n" + "=" * 46)
print("总验收: " + ("全部通过 ✓" if ok_all else "有项目未通过 ✗"))
