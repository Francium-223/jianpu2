# -*- coding: utf-8 -*-
"""一次性修补: 把 to_jianpu_db.py 里 `lines.insert(len(lines), ...)` 改成
插到 `%--` 之前(否则 source=/注释 会落到正文区, 破坏"拍号行"位置)。"""
import io

p = "tools/to_jianpu_db.py"
s = io.open(p, encoding="utf-8").read()
n = s.count("lines.insert(len(lines), ")
s = s.replace("lines.insert(len(lines), ", "lines.insert(len(lines) - 1, ")
io.open(p, "w", encoding="utf-8").write(s)
print(f"替换 {n} 处 -> 插到 %-- 之前")
