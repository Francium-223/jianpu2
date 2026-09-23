# -*- coding: utf-8 -*-
"""最小验证: tag=<来源站> 能否流到 data.jsonl 的 tags 字段。纯 CPU, 不动用户仓库。"""
import json, os, shutil, subprocess, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")

T = "train-work/tagtest"
shutil.rmtree(T, ignore_errors=True)
os.makedirs(f"{T}/scores", exist_ok=True)
for f in ("parse_scores.py", "score.py", "tag_equality.json", "tag_implications.json"):
    src = f"D:/Documents_D/jianpu-db/{f}"
    if os.path.exists(src):
        shutil.copy(src, T)
# 把 db_to_jsonl 的 DB 路径指向本测试目录, 否则会去读用户的真实仓库
s = open("tools/db_to_jsonl.py", encoding="utf-8").read()
s = s.replace('DB = "D:/Documents_D/jianpu-db"', 'DB = "."')
open(f"{T}/db_to_jsonl.py", "w", encoding="utf-8").write(s)

from to_jianpu_db import to_score
for nm, dirn in (("测试歌A", "测试歌A__jianpucn-1"), ("测试歌B", "测试歌B__qupu123-2")):
    open(f"{T}/scores/{nm}.txt", "w", encoding="utf-8").write(
        to_score(dirn, ["1", "2", "3", "4", "5", "6", "7", "1"] * 3, "jianpu2-auto", meter="4/4"))
print("score 头:")
for n in ("测试歌A", "测试歌B"):
    ls = open(f"{T}/scores/{n}.txt", encoding="utf-8").read().splitlines()
    print(f"  {n}: tag={[l for l in ls if l.startswith('tag=')][0]}")

subprocess.run([sys.executable, "parse_scores.py"], cwd=T, capture_output=True, text=True,
               encoding="utf-8", errors="replace")
r = subprocess.run([sys.executable, "db_to_jsonl.py", "out.jsonl"], cwd=T, capture_output=True,
                   text=True, encoding="utf-8", errors="replace")
p = f"{T}/out.jsonl"
print("\nJSONL:")
if os.path.exists(p):
    for l in open(p, encoding="utf-8"):
        d = json.loads(l)
        print(f"  tags={d.get('tags')}  title={d.get('title')}  n_notes={d.get('n_notes')}")
else:
    print("  未生成:", (r.stdout or "")[-200:], (r.stderr or "")[-200:])
