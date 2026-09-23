# -*- coding: utf-8 -*-
"""语料指纹 / 批量写回的安全网 —— 任何"批量改 scores/*.txt"的工具跑完都该过一遍。

背景（为什么需要它）: 2026-09-23 `expand_keep_length` 把**元数据**也当正文处理,
`todo=add tags` 被写成 `dtodo=ad stag` —— 元数据**键**变了, 1678 个 `_expand.txt` 被写坏,
当时没人立刻发现。这类事故的特征是"键集合变了", 而正常的批量作业只会改**值**
(补 tag/usertag/link/title) 或**正文**(修音)。

指纹 = 每份曲谱的: 元数据**键集合(有序)** + 几个关键键的值 + 正文 token 的 sha1 + 音高音数。

用法:
    python3 tools/corpus_fingerprint.py --save                  # 存 misc/records/fingerprint_<日期>.json
    python3 tools/corpus_fingerprint.py --save /tmp/before.json # 存到指定路径
    python3 tools/corpus_fingerprint.py --check /tmp/before.json
        -> 退出码 0 = 只有"预期内的值/正文变化"; 1 = 有**键集合变化**或文件消失(几乎必然是写坏了)

    # 典型用法: 跑批量工具**前后**各存一次, 然后对比
    python3 tools/corpus_fingerprint.py --save /tmp/before.json
    ...(propose_tags.py --apply / refine_titles_from_pages.py --apply / add_link.py ...)...
    python3 tools/corpus_fingerprint.py --check /tmp/before.json
"""
import argparse
import glob
import hashlib
import io
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                      # jianpu2/
DB = os.environ.get("JIANPU_DB") or os.path.join(os.path.dirname(ROOT), "jianpu-db")
SKILL = os.path.join(ROOT, "skills", "jianpu-melody-lookup")
JTOK_DIR = os.environ.get("JIANPU_JTOK") or SKILL
if os.path.isdir(JTOK_DIR) and JTOK_DIR not in sys.path:
    sys.path.insert(0, JTOK_DIR)
try:
    import jptok
except ImportError:                               # 与 score.py 同态度: 不静默换口径
    sys.exit(f"找不到 jptok.py(唯一实现): {JTOK_DIR}\n  设 JIANPU_JTOK=<skill 目录> 再跑。")

SKIP = re.compile(r"(?:_expand|_buf)\.txt$")
KEY_LINE = re.compile(r"^([0-9A-Za-z_]+)=(.*)$")
KEEP = ("title", "tag", "usertag", "tagroute", "link", "todo", "status", "source",
        "transcriber", "alias", "MBID", "id", "id-type")


def fingerprint_one(path):
    raw = io.open(path, encoding="utf-8", errors="replace").read()
    head, sep, body = raw.partition("%--")
    keys, vals = [], {}
    for ln in head.splitlines():
        m = KEY_LINE.match(ln.strip())
        if not m:
            continue
        k = m.group(1)
        if k not in keys:
            keys.append(k)
        if k in KEEP:
            vals[k] = m.group(2).strip()
    toks = [t for t in body.split() if t not in ("%END",)]
    pitches = 0
    for t in toks:
        if jptok.is_note(t) and not t.startswith(("0", "x")):
            pitches += 1
    return {
        "keys": keys,
        "vals": vals,
        "body_sha1": hashlib.sha1(" ".join(toks).encode("utf-8")).hexdigest()[:16],
        "n_pitch": pitches,
        "bytes": len(raw.encode("utf-8")),
    }


def scan(score_dir):
    out = {}
    for p in sorted(glob.glob(os.path.join(score_dir, "*.txt"))):
        name = os.path.basename(p)
        if SKIP.search(name):
            continue
        out[name] = fingerprint_one(p)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--save", nargs="?", const="", help="存指纹(不给路径则存 misc/records/)")
    ap.add_argument("--check", help="与某个指纹文件比对")
    ap.add_argument("--scores", default=os.path.join(DB, "scores"), help=f"曲谱目录(默认 {DB}/scores)")
    a = ap.parse_args()

    if not os.path.isdir(a.scores):
        sys.exit(f"没有这个目录: {a.scores}(用 JIANPU_DB 或 --scores 指一下)")

    t0 = time.time()
    now = scan(a.scores)
    dt = time.time() - t0
    print(f"扫描 {len(now)} 份曲谱, 用时 {dt:.1f}s  ({a.scores})")

    if a.save is not None:
        path = a.save or os.path.join(DB, "misc", "records", f"fingerprint_{time.strftime('%Y%m%d-%H%M')}.json")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with io.open(path, "w", encoding="utf-8", newline="\n") as g:
            json.dump({"scores_dir": a.scores, "time": time.strftime("%F %T"), "files": now}, g,
                      ensure_ascii=False, indent=0)
        print(f"已存 {path}")
        return 0

    if a.check:
        with io.open(a.check, encoding="utf-8") as g:
            old = json.load(g)["files"]
        gone = sorted(set(old) - set(now))
        added = sorted(set(now) - set(old))
        keybad, valbad, bodybad = [], [], []
        for n in sorted(set(old) & set(now)):
            o, w = old[n], now[n]
            if o["keys"] != w["keys"]:
                keybad.append((n, o["keys"], w["keys"]))
            elif o["vals"] != w["vals"]:
                valbad.append((n, o["vals"], w["vals"]))
            elif o["body_sha1"] != w["body_sha1"] or o["n_pitch"] != w["n_pitch"]:
                bodybad.append((n, o["n_pitch"], w["n_pitch"]))
        print(f"\n=== 与 {a.check} 比对 ===")
        print(f"新增 {len(added)} 份, 消失 {len(gone)} 份, "
              f"**元数据键变了 {len(keybad)} 份**, 值变了 {len(valbad)} 份, 正文变了 {len(bodybad)} 份")
        if added:
            print("\n新增(前 10): " + ", ".join(added[:10]))
        if gone:
            print("消失(前 10): " + ", ".join(gone[:10]) + "   ← 若没搬进 scores-suspect/ 就是丢了")
        if keybad:
            print("\n!! 元数据**键**变了(几乎必然是写坏了, 例如 todo= 被写成 dtodo=):")
            for n, o, w in keybad[:15]:
                print(f"   {n}\n      旧 {o}\n      新 {w}")
        if valbad:
            print("\n值变了(补标签/改名/补链接属正常, 前 15 条):")
            for n, o, w in valbad[:15]:
                diff = {k: (o.get(k), w.get(k)) for k in set(o) | set(w) if o.get(k) != w.get(k)}
                print(f"   {n}: {diff}")
        if bodybad:
            print("\n正文变了(修音属正常, 前 15 条):")
            for n, a1, b1 in bodybad:
                if a1 == b1:
                    print(f"   {n}: 音高音数没变({a1}), 但正文文本变了(记号/小节线/时值?)")
                else:
                    print(f"   {n}: 音高音 {a1} -> {b1}")
        bad = bool(keybad) or bool(gone)
        print("\n结论: " + ("有问题, 见上面 !!" if bad else "没有异常(键集合与文件集合都没变)"))
        return 1 if bad else 0
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
