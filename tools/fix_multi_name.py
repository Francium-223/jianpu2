# -*- coding: utf-8 -*-
"""一次性修补: melody_retrieval_holdout.py 里 `M = int(opt("--multi",1))` 覆盖了
`import melody_oct as M` 的模块别名 -> `M.enc()` 抛异常被吞 -> 索引 0 首。
把那个变量改名成 MULTI(保留模块别名 M 给 melody_oct)。"""
import io
import re

p = "tools/melody_retrieval_holdout.py"
s = io.open(p, encoding="utf-8").read()
s = s.replace('M = int(opt("--multi", 1))', 'MULTI = int(opt("--multi", 1))')
s = s.replace("for _m in range(M):", "for _m in range(MULTI):")
s = s.replace("score_multi(qs, A) if M > 1 else score_q(q, A)",
              "score_multi(qs, A) if MULTI > 1 else score_q(q, A)")
s = s.replace("f\"每首 {N} 次(M={M} 段投票)\"", "f\"每首 {N} 次(M={MULTI} 段投票)\"")
s = s.replace("f\"{L}\\t{E}\\t{ERRMODE}\\t{M}\\t", "f\"{L}\\t{E}\\t{ERRMODE}\\t{MULTI}\\t")
io.open(p, "w", encoding="utf-8").write(s)
n = len(re.findall(r"\bMULTI\b", s))
print(f"MULTI 出现 {n} 次, 模块别名 M 保留")
