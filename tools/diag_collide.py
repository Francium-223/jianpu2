# -*- coding: utf-8 -*-
"""诊断: to_jianpu_db 转换时, 哪些源文件因"清洗后标题重名"互相覆盖。"""
import glob, os, re, sys
from collections import defaultdict
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from to_jianpu_db import title_of, clean_tokens

groups = defaultdict(list)
for f in glob.glob("batch-out/*.txt"):
    name = os.path.splitext(os.path.basename(f))[0]
    if name in ("progress", "skipped"):
        continue
    toks = clean_tokens(open(f, encoding="utf-8").read())
    if len(toks) < 10:
        continue
    title = title_of(name)
    safe = re.sub(r'[\\/:*?"<>|\s]+', "_", title).strip("_")[:60] or name
    groups[safe].append((name, len(toks)))

collide = {k: v for k, v in groups.items() if len(v) > 1}
print(f"源文件(有效): {sum(len(v) for v in groups.values())}")
print(f"唯一输出名:   {len(groups)}")
print(f"撞名组:       {len(collide)}   丢失文件: {sum(len(v)-1 for v in collide.values())}")
print()
for k, v in sorted(collide.items(), key=lambda x: -len(x[1])):
    print(f"[{len(v)} 个 -> {k}]")
    for name, n in v:
        print(f"    {n:5d}音  {name[:70]}")
