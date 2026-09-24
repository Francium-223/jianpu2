# -*- coding: utf-8 -*-
"""按**转写队列**批量转写并入库 —— 可断点续跑, 分两个阶段(转写 / 入库)。

队列从哪来: `tools/queue_from_crawl.py --with-images` 出来的 TSV
(`曲名 站 页面id 页数 类型 目录 首图`) —— 里面已经是"库里没有 + 非器乐改编"的新歌。

两个阶段为什么要分开:
  * **转写**要 VLM(jianpu-atom = `models/jianpu-lora-v15`) —— 本机**跑不了**
    (没 GPU; 内存 6.9GB < 4bit 3B 建议的 8GB; 缺 7GB 基座), 得在 GPU 机上跑;
  * **入库**只写文本, 在哪跑都行 —— 所以拆开后, 转写产物(纯 token 文本)可以搬来搬去。

    python3 tools/batch_transcribe_queue.py --stage transcribe --queue <tsv> --work train-work/txq --limit 20
    python3 tools/batch_transcribe_queue.py --stage import     --queue <tsv> --work train-work/txq

⚠ **诚实说明**: `--stage transcribe` 这条**没在本机端到端验过**(本机没有 VLM 环境),
   它拼出的命令形状与 `tools/transcribe.py` 的 CLI 一致(`<image> --out <txt>`), 第一次真跑请先 `--dry-run`。
   `--stage import` 是**验过的**(用一个合成 token 文本跑通: 写出 -> parse_scores.py -> data.jsonl -> 自检)。

写进语料的每个文件都标 `transcriber=`(带模型版本与队列批次) 与 `status=ocr`, 便于日后回溯质量。
"""
import argparse
import glob
import io
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                       # jianpu2
WS = os.path.dirname(ROOT)
DB = os.environ.get("JIANPU_DB") or os.path.join(WS, "jianpu-db")
SCORES = os.path.join(DB, "scores")
IMG = re.compile(r"\.(jpg|jpeg|png|gif|webp)$", re.I)
TRANS = "jianpu-vlm(v15)+crawl2026-09-25"


def read_queue(path):
    rows = []
    with io.open(path, encoding="utf-8") as f:
        head = f.readline().rstrip("\n").split("\t")
        for ln in f:
            if not ln.strip():
                continue
            c = ln.rstrip("\n").split("\t")
            rows.append(dict(zip(head, c)))
    return rows


def safe(name, n=60):
    name = re.sub(r"[\\/:*?\"<>|\x00-\x1f\x7f-\x9f]", "_", name or "")
    return re.sub(r"\s+", " ", name).strip()[:n] or "untitled"


def existing_sources():
    """scores/ 里已经有的 `source=站-id` —— 用来断点续跑(做过的不再做)。"""
    out = set()
    for p in glob.glob(os.path.join(SCORES, "*.txt")):
        try:
            for ln in io.open(p, encoding="utf-8", errors="replace"):
                if ln.startswith("source="):
                    out.add(ln.split("=", 1)[1].strip())
        except OSError:
            pass
    return out


def pages_of(row):
    d = row.get("目录", "")
    root = os.path.join(WS, "images-prep")
    # ⚠ 只 escape **目录名本身**, 不能把 `**` 也 escape 了(那样递归通配就失效, 一个都找不到 —— 实测踩过)。
    #   目录名里有 `【】[]《》` 这类字符, 不 escape 也会匹配错。
    found = [x for x in glob.glob(os.path.join(root, "**", glob.escape(d)), recursive=True)
             if os.path.isdir(x)]
    if not found:
        return []
    imgs = sorted(x for x in glob.glob(os.path.join(found[0], "*")) if IMG.search(x))
    return imgs


def score_text(row, body):
    """按 jianpu-db 的 scores/*.txt 格式组装(与语料里既有文件的键顺序一致)。"""
    site, sid = row.get("站", ""), row.get("页面id", "")
    title = row.get("曲名") or ""
    lines = [
        "%%%s" % (safe(title) + ".txt"),
        "title=%s" % title,
        "usertag=",
        "tagroute=",
        "transcriber=%s" % TRANS,
        "status=ocr",
        "source=%s-%s" % (site, sid),
        "%--",
    ]
    body = (body or "").strip()
    if not body:
        return ""
    lines.append(body if body.startswith("%") else "subtitle=score\n" + body)
    lines.append("%END")
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--queue", required=True, help="queue_from_crawl.py --with-images 出来的 TSV")
    ap.add_argument("--work", default=os.path.join(ROOT, "train-work", "txq"),
                    help="转写产物目录(每首一个 <站>-<id>.txt)")
    ap.add_argument("--stage", choices=["transcribe", "import", "all"], default="all")
    ap.add_argument("--limit", type=int, default=0, help="最多处理多少首(0=全部)")
    ap.add_argument("--only", default="", help="只处理曲名包含这个字串的")
    ap.add_argument("--python", default=sys.executable, help="跑 transcribe.py 的解释器(GPU 机上可能是别的)")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)

    rows = read_queue(a.queue)
    have = existing_sources()
    os.makedirs(a.work, exist_ok=True)
    print(f"队列 {len(rows)} 首 · 已入库 source {len(have)} 个 · 产物目录 {a.work}")

    todo = []
    for r in rows:
        key = "%s-%s" % (r.get("站", ""), r.get("页面id", ""))
        if key in have:
            continue
        if a.only and a.only not in (r.get("曲名") or ""):
            continue
        todo.append(r)
    if a.limit:
        todo = todo[:a.limit]
    print(f"待处理 {len(todo)} 首" + (" (dry-run)" if a.dry_run else ""))

    n_tx = n_im = 0
    for i, r in enumerate(todo, 1):
        key = "%s-%s" % (r.get("站", ""), r.get("页面id", ""))
        wf = os.path.join(a.work, key + ".txt")
        if a.stage in ("transcribe", "all"):
            imgs = pages_of(r)
            if not imgs:
                print(f"  [{i}] {r.get('曲名','')[:20]}: 找不到图, 跳过"); continue
            if os.path.isfile(wf) and os.path.getsize(wf) > 0:
                print(f"  [{i}] {key}: 已有转写产物, 跳过转写")
            else:
                parts = []
                for k, im in enumerate(imgs):
                    out = os.path.join(a.work, f"{key}.pg{k}.txt")
                    cmd = [a.python, os.path.join(HERE, "transcribe.py"), im, "--out", out]
                    print("   $", " ".join(cmd))
                    if not a.dry_run:
                        subprocess.run(cmd, check=False)
                    parts.append(out)
                if not a.dry_run:
                    body = ""
                    for p in parts:
                        if os.path.isfile(p):
                            body += io.open(p, encoding="utf-8", errors="replace").read().strip() + "\n"
                    if body.strip():
                        io.open(wf, "w", encoding="utf-8").write(body)
                        n_tx += 1
        if a.stage in ("import", "all"):
            if not os.path.isfile(wf):
                continue
            body = io.open(wf, encoding="utf-8", errors="replace").read()
            text = score_text(r, body)
            if not text:
                print(f"  [{i}] {key}: 转写产物是空的, 不入库"); continue
            dst = os.path.join(SCORES, safe(r.get("曲名") or "") + ".txt")
            if os.path.exists(dst):
                dst = os.path.join(SCORES, safe(r.get("曲名") or "") + "_%s.txt" % key)
            print("   ->", os.path.relpath(dst, WS))
            if not a.dry_run:
                io.open(dst, "w", encoding="utf-8", newline="\n").write(text)
                n_im += 1
    print(f"\n完成: 转写 {n_tx} 首, 入库 {n_im} 首" + (" (dry-run 没写任何东西)" if a.dry_run else ""))
    if not a.dry_run and n_im:
        print("下一步(必须): python3 %s  然后跑自检" % os.path.join(DB, "parse_scores.py"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
