# -*- coding: utf-8 -*-
"""只读统计: title_of 新增"整段重复检测"后, 有多少目录名的显示名被修好。
用法: py -3.13 tools/measure_title_fix.py
"""
import glob
import os
import re
import sys

sys.path.insert(0, "tools")
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import to_jianpu_db as T


def old_title_of(name):
    """新增重复检测之前的旧逻辑(照抄, **含 mojibake 兜底**), 用来公平对比。
    上一版对比脚本漏了兜底 -> 把 `17`/`1874` 这类记成"被我改坏", 其实那是旧行为 ✗。"""
    base = T.fix_mojibake(name.split("__")[0]).strip()
    base = re.sub(r"简谱.*$", "", base)
    base = re.sub(r"[_-]?[（(][^（）()]*[)）]", "", base)
    base = re.sub(r"^\d{1,3}(?=[\u4e00-\u9fff])", "", base)
    base = base.strip("_- ")
    _cjk = len(re.findall(r"[\u4e00-\u9fff]", base))
    _has_moji = bool(re.search(r"[\u00c0-\u00ff]", base))
    if (not re.search(r"[\u4e00-\u9fffA-Za-z]", base)) or (_has_moji and _cjk < 2):
        sid = re.search(r"([A-Za-z]+\d*-\d+)$", name)
        base = f"未命名-{sid.group(1)}" if sid else "未命名"
    return base or name


dirs = [os.path.basename(d) for d in glob.glob("images-prep/*/*") if os.path.isdir(d)]
changed = []
for n in dirs:
    a, b = old_title_of(n), T.title_of(n)
    if a != b:
        changed.append((a, b))
print(f"目录名 {len(dirs)} 个; 显示名被修好的: {len(changed)} 个")
for a, b in changed[:14]:
    print(f"  {a[:58]:60s} -> {b[:40]}")
if len(changed) > 14:
    print(f"  … 还有 {len(changed)-14} 个")
