# -*- coding: utf-8 -*-
"""校验打包好的 zip: 文件名是否还含 Kaggle 禁字符。"""
import os, re, sys, zipfile
sys.stdout.reconfigure(encoding="utf-8")
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

BAD = re.compile(r"""['"()\[\]{}<>|:*?]""")
for name in ["deploy/kaggle-images.zip", "deploy/kaggle-tools.zip"]:
    if not os.path.exists(name):
        print(f"{name}: 不存在")
        continue
    z = zipfile.ZipFile(name)
    names = z.namelist()
    bad = [n for n in names if BAD.search(n)]
    print(f"{name}")
    print(f"  大小: {os.path.getsize(name)/1024/1024:.1f} MB   文件数: {len(names)}")
    print(f"  含禁字符: {len(bad)}")
    for b in bad[:5]:
        print(f"    {b}")
    # 抽样看路径结构
    print(f"  样例: {names[0] if names else '(空)'}")
