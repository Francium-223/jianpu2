# -*- coding: utf-8 -*-
"""检查缺失谱的 pick_page 结果。"""
import glob, os, sys
sys.path.insert(0, "tools"); os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
import batch_transcribe as BT

for kid in ["qupu123-326095", "qupu123-1398", "qupu123-370547", "qupu123-333896"]:
    hits = [p for p in glob.glob("images-prep/*/*") if os.path.basename(p).endswith(kid)]
    if not hits:
        print(kid, "目录不存在"); continue
    d = hits[0]
    print(f"## {os.path.basename(d)[:40]}")
    for f in sorted(glob.glob(os.path.join(d, "*.jpg"))):
        try:
            w, h = Image.open(f).size
            print(f"   {os.path.basename(f):14s} {w}x{h} {os.path.getsize(f)//1024}KB")
        except Exception as e:
            print(f"   {os.path.basename(f):14s} FAIL")
    print(f"   pick_page -> {BT.pick_page(d)}")
