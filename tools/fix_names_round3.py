# -*- coding: utf-8 -*-
"""第三轮: 手工修掉最后几条"署名残留"的清名(逐条看过原文)。

  `小小周杰伦词方文山曲`      -> 小小          (歌名后面直接接了词曲署名)
  `啊，草原李良词李炫春曲`    -> 啊，草原      (同上, 两个目录)
  `MV_藏在浓雾里的朴家人`     -> 藏在浓雾里的朴家人   (MV_ 是站点/版式前缀)
  `总有爱国语版`              -> 总有爱        ("国语版"是版本说明)
用法: py -3.13 tools/fix_names_round3.py [--dry]
"""
import csv
import os
import sys

sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DRY = "--dry" in sys.argv
CLEAN = "train-work/title_clean.tsv"
# 键 = 清名表里的"原始名"(目录名去掉 __站点-id 后的部分)
FIX = {
    "小小周杰伦词方文山曲小小周杰伦词_方文山曲简谱": "小小",
    "啊，草原李良词李炫春曲啊，草原李良词_李炫春曲简谱_枫桥": "啊，草原",
    "啊，草原李良词李炫春曲啊，草原李良词_李炫春曲简谱_枫桥2": "啊，草原",
    "MV_藏在浓雾里的朴家人": "藏在浓雾里的朴家人",
    "总有爱国语版-一辈子陪你走": "总有爱",
}

rows = {}
with open(CLEAN, encoding="utf-8") as f:
    for r in csv.DictReader(f, delimiter="\t"):
        rows[r["目录名"]] = dict(r)

n = 0
for d, r in rows.items():
    orig = r.get("原始名", "")
    for k, v in FIX.items():
        # 原始名是"前缀/包含"关系都算命中(实际原始名可能带站点壳子)
        if orig.startswith(k) or k.startswith(orig) or k in orig or orig in k:
            if r.get("模型曲名") != v:
                print(f"  {orig[:44]:<46} -> {v}")
                r["模型曲名"] = v
                r["有变化"] = "1"
                r["原文输出"] = "round3-manual"
                n += 1
            break
print(f"修正 {n} 条")
if DRY:
    sys.exit(0)
with open(CLEAN, "w", encoding="utf-8") as f:
    f.write("目录名\t原始名\t模型曲名\t有变化\t原文输出\n")
    for r in rows.values():
        f.write("\t".join(str(r.get(c, "")).replace("\t", " ") for c in
                          ("目录名", "原始名", "模型曲名", "有变化", "原文输出")) + "\n")
print(f"-> {CLEAN}")
