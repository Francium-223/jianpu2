# -*- coding: utf-8 -*-
"""量"整份重转抢名"造成的实际损失: 有多少新谱转了出来却**没进语料**, 有多少老谱被**拷了两份**。

背景(实测): 2026-09-28 07:16 有一次整份 `to_jianpu_db.py` 重转(8569 份成品在两分钟内被重写),
它给现成成品改名(见 tools/check_convert_rename_drift.py)。而 `import_finished_scores.py` 只拷不覆盖,
于是那批"抢到旧名"的新谱在导入时被跳过 —— 转出来了, 却永远进不了 `data.jsonl`。

本工具只读, 做两件事:
  A) **丢失**: 用命名模拟找出"抢名"的新谱, 把它的旋律(音级+时值, 忽略八度)在 data.jsonl 里查一遍,
     查不到 = 这首白转了。结果写到 `_analysis/lost_batches.txt`(每行一个 batch 名, 可直接喂给转换工具)。
  B) **重复**: 对"被迫改名"的老谱(旧名 X -> 新名 X_2), 看 db 里 X 与 X_2 是否都存在且旋律相同。

用法:
    py -3.13 tools/check_convert_damage.py [--days 0] [--data D:\\Documents_D\\jianpu-db\\data.jsonl]
"""
import argparse
import collections
import glob
import hashlib
import io
import json
import os
import re
import sys

J2 = r"D:\Documents_D\jianpu2"
sys.path.insert(0, os.path.join(J2, "tools"))
os.chdir(J2)

from guard import guard_help        # noqa: E402
guard_help(__doc__)
import check_convert_rename_drift as D      # noqa: E402 复用它的命名模拟(唯一实现)

NOTE = re.compile(r"^[,']*[qsdh]*[,']*[1-7x0][.,'qsdh-]*$")
_CONV = None


def _conv():
    global _CONV
    if _CONV is None:
        _CONV = D.load_conv()
    return _CONV


def melody_hash(tokens):
    """只取有音高的音级+时值(忽略八度)做指纹 —— 与检索口径一致: 八度不参与。"""
    conv = _conv()
    h = hashlib.sha1()
    for t in tokens:
        if not conv.NOTE_RE.match(t):
            continue
        if not re.search(r"[1-7]", t):
            continue
        h.update(t.replace(",", "").replace("'", "").encode("utf-8"))
        h.update(b" ")
    return h.hexdigest()


def db_hashes(data_path):
    idx = collections.defaultdict(list)
    n = 0
    for line in io.open(data_path, encoding="utf-8"):
        if not line.strip():
            continue
        r = json.loads(line)
        n += 1
        sc = (r.get("score") or "").replace(" | ", " ")
        idx[melody_hash(sc.split())].append(r.get("file"))
    return idx, n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=float, default=0.0)
    ap.add_argument("--data", default=r"D:\Documents_D\jianpu-db\data.jsonl")
    ap.add_argument("--out", default=r"D:\Documents_D\_analysis\lost_batches.txt")
    ap.add_argument("--fin", default=os.path.join(J2, "jianpu-db-out", "scores"))
    ap.add_argument("--db", default=r"D:\Documents_D\jianpu-db\scores")
    a = ap.parse_args()

    conv = _conv()
    CLEAN = conv.load_clean_titles_soft()
    files = sorted(glob.glob(os.path.join(J2, "batch-out", "*.txt")))
    old = [f for f in files if os.path.getmtime(f) < (D.datetime.datetime.now().replace(
        hour=0, minute=0, second=0, microsecond=0).timestamp() if a.days == 0
        else D.datetime.datetime.now().timestamp() - a.days * 86400)]
    A, _sA = D.simulate(conv, CLEAN, files)
    B, _sB = D.simulate(conv, CLEAN, old)
    oldnames = set(B.values())

    steal = [(n, A[n]) for n in A if n not in B and A[n] in oldnames]
    drift = [(n, B[n], A[n]) for n in B if n in A and B[n] != A[n]]
    print(f"命名模拟: A(全部) {len(A)} 名 · B(只旧谱) {len(B)} 名")
    print(f"抢名的新谱 {len(steal)} 首 · 被迫改名的老谱 {len(drift)} 首")

    print("读 data.jsonl ...")
    idx, nrows = db_hashes(a.data)
    print(f"   {nrows} 行, {len(idx)} 种旋律指纹")

    by_name = {os.path.splitext(os.path.basename(p))[0]: p for p in files}
    lost, present = [], []
    for name, got in steal:
        p = by_name.get(name)
        if not p:
            continue
        tk = conv.clean_tokens(io.open(p, encoding="utf-8", errors="replace").read())
        h = melody_hash(tk)
        (present if h in idx else lost).append((name, got, len(tk)))
    print()
    print(f"A) 抢名新谱里, 旋律**已在语料中** {len(present)} 首 · **不在语料里(=白转)** {len(lost)} 首")
    for name, got, ntk in lost[:10]:
        print(f"   丢了: {got}.txt  <- {name}  ({ntk} token)")
    with io.open(a.out, "w", encoding="utf-8") as g:
        g.write("\n".join(n for n, _g, _t in lost) + ("\n" if lost else ""))

    dup = []
    for name, was, now in drift:
        f1, f2 = os.path.join(a.db, was + ".txt"), os.path.join(a.db, now + ".txt")
        if os.path.isfile(f1) and os.path.isfile(f2):
            b1 = " ".join(conv.clean_tokens(io.open(f1, encoding="utf-8", errors="replace").read()))
            b2 = " ".join(conv.clean_tokens(io.open(f2, encoding="utf-8", errors="replace").read()))
            if melody_hash(b1.split()) == melody_hash(b2.split()):
                dup.append((was, now, name))
    print()
    print(f"B) 被迫改名的老谱里, db 里**同名两份旋律相同(=重复)** {len(dup)} 组")
    for was, now, name in dup[:10]:
        print(f"   {was}.txt == {now}.txt   ({name})")
    print()
    print(f"丢失名单 -> {a.out}   (喂给 tools/convert_new_batches.py 的 --also 就能补转)")


if __name__ == "__main__":
    main()
