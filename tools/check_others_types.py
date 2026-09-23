# -*- coding: utf-8 -*-
"""实证: write_buf 的那个 for 循环里, others 的值到底有没有非列表的?

parse() 的调用顺序是 read -> process_others -> write_buf -> ... , 每个 Score 对象
只 write_buf 一次。所以在那个循环处, others 里放的只有 read/process_others 写入的东西。
本脚本直接检查那一刻的类型, 覆盖全部曲谱。
"""
import glob
import os
import sys
import types
import collections

sys.path.insert(0, r"D:\Documents_D\jianpu-db")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(r"D:\Documents_D\jianpu-db")
# score.py 现在 import schema, 而 schema.py 还在写(语法不完整) -> 用 stub 顶上,
# 只做类型统计, 不碰用户的文件
_stub = types.ModuleType("schema")
_stub.schema = {}
sys.modules["schema"] = _stub
import score as S

fs = [f for f in glob.glob("scores/*.txt")
      if not f.endswith(("_expand.txt", "_buf.txt"))]
print(f"检查 {len(fs)} 份曲谱在 write_buf 之前的 others 类型")

types = collections.Counter()
nonlist = collections.Counter()
for f in fs:
    sc = S.Score(f)
    try:
        sc.read()
        sc.process_others()
    except Exception as e:
        print(f"  {os.path.basename(f)}: {type(e).__name__}")
        continue
    for k, v in sc.others.items():
        t = type(v).__name__
        types[t] += 1
        if not isinstance(v, list):
            nonlist[f"{k}:{t}"] += 1

print(f"\n值类型分布: {dict(types)}")
if nonlist:
    print(f"非列表的值: {dict(nonlist)}")
else:
    print("非列表的值: 无 —— 那个 isinstance(_v, list) 分支走不到 ✓")
