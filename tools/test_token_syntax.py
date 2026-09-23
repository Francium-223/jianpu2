# -*- coding: utf-8 -*-
"""验证 token_json 是否同时认"前置时值"(q3)与"后置时值"(3q)两种写法。
jianpu-ly 官方说明: 字符顺序无所谓, s1 与 1s 等价。
若只认前置, 那么 GT 评测就会把 GT 的八分音符当成四分 -> 匹配率虚低。
"""
import io, os, sys
sys.path.insert(0, "tools")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from token_json import token_to_json as t2j

print("--- 前置写法(我的输出) ---")
for t in ["q3", "q'1", "3", "s7", "q,5.", "'1"]:
    print(f"  {t:6s} -> {t2j(t)}")
print("--- 后置写法(GT 文件里用的) ---")
for t in ["3q", "'1q", "3", "7s", ",5q.", "1'"]:
    print(f"  {t:6s} -> {t2j(t)}")
