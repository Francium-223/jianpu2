# -*- coding: utf-8 -*-
"""按名单重转指定谱: 删掉它们的 txt/png, 再让 batch 增量补跑(它自行跳过已存在的)。
用法: py -3.13 tools/retranscribe_list.py <名单文件>
名单每行 = 目录名(batch-out 的 txt 名 = 该目录名经 safe_name 规范化)。
"""
import glob, os, re, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
import batch_transcribe as BT

lst = sys.argv[1] if len(sys.argv) > 1 else "train-work/boundfix_sheets.txt"
names = [l.strip() for l in open(lst, encoding="utf-8") if l.strip()]
print(f"名单 {len(names)} 个")
n_del = 0
for raw in names:
    nm = BT.safe_name(raw)
    hit = glob.glob(f"batch-out/{glob.escape(nm)}.txt")
    if not hit:
        # 名字可能有 mojibake 差异: 退回按 ID 后缀匹配
        m = re.search(r"([A-Za-z]+\d*-\d+)$", raw)
        if m:
            hit = glob.glob(f"batch-out/*{glob.escape(m.group(1))}.txt")
    for h in hit:
        os.remove(h); n_del += 1
        png = h[:-4] + ".png"
        if os.path.exists(png):
            os.remove(png)
print(f"已删除 {n_del} 个旧结果 -> 现在跑 batch 即可增量补转")
