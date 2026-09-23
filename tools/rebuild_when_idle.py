# -*- coding: utf-8 -*-
"""守候: 等到**没有任何写库进程** -> 干净重建一次 -> 立刻验证 -> 出报告。

为什么必须"等": 实测有定时任务(finalize / to_jianpu_db / parse_scores)在后台写 scores/,
我这边一边重建一边被覆盖, 导致 data.jsonl 与磁盘文件对不上(同一文件名两次读出不同内容)。
判据: 任何命令行含 finalize / to_jianpu_db / parse_scores / transcribe / absorb 的 python 进程。

用法: py -3.13 tools/rebuild_when_idle.py [最多等多少分钟=180]
"""
import io
import json
import os
import random
import re
import subprocess
import sys
import time

sys.stdout.reconfigure(encoding="utf-8")
DB = r"D:\Documents_D\jianpu-db"
PAT = re.compile(r"finalize|to_jianpu_db|parse_scores|transcribe|absorb|kugou_pipeline")
WAIT_MIN = int(sys.argv[1]) if len(sys.argv) > 1 else 180


def say(m):
    line = f"{time.strftime('%H:%M:%S')}  {m}"
    print(line, flush=True)
    with io.open(r"D:\Documents_D\jianpu2\train-work\rebuild_when_idle.log", "a", encoding="utf-8") as g:
        g.write(line + "\n")


def writers():
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | "
                        "ForEach-Object { $_.ProcessId.ToString() + ' ' + $_.CommandLine }"],
                       capture_output=True, text=True)
    out = []
    for ln in (r.stdout or "").splitlines():
        if PAT.search(ln) and "http.server" not in ln:
            out.append(ln.strip()[:110])
    return out


say("=== 守候: 等写者清空 ===")
t0 = time.time()
while time.time() - t0 < WAIT_MIN * 60:
    w = writers()
    if not w:
        break
    say(f"  还有 {len(w)} 个写者, 等 60s: {w[0]}")
    time.sleep(60)
else:
    say("超时, 放弃"); sys.exit(1)

say("写者已清空, 开始重建")
r = subprocess.run([sys.executable, "-u", "parse_scores.py"], cwd=DB,
                   stdout=open(r"D:\Documents_D\jianpu2\train-work\parse_idle.log", "w", encoding="utf-8"),
                   stderr=subprocess.STDOUT, text=True)
say(f"重建退出码 {r.returncode}")
time.sleep(10)
if writers():
    say(f"!! 重建后又出现写者: {writers()}  —— 结果可能仍不同步")

# 验证: data.jsonl 的 note 数与 scores/<file> 原文一致
TOK = re.compile(r"^[,']*[qsdh]*[,']*[0-9x]")
rows = [json.loads(l) for l in io.open(os.path.join(DB, "data.jsonl"), encoding="utf-8") if l.strip()]
bad = 0
for row in random.Random(7).sample(rows, 10):
    f = os.path.join(DB, "scores", row["file"][0])
    if not os.path.exists(f):
        bad += 1; continue
    raw = io.open(f, encoding="utf-8", errors="replace").read()
    n1 = len([t for t in raw.split() if TOK.match(t)])
    n2 = len([t for t in (row.get("score") or "").replace(" | ", " ").split() if TOK.match(t)])
    if n1 != n2:
        bad += 1
        say(f"  不一致 {row['file'][0]}: 文件 {n1} vs jsonl {n2}")
say(f"验证: {len(rows)} 行, 抽查 10 首, 不一致 {bad}")
say("完成")
