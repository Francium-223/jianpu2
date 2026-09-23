# -*- coding: utf-8 -*-
"""提取 harvest 数据集的 Qwen 2048 特征(带类标签 0/1), 存 features.pkl。
用法: py -3.13 tools/extract_note_lyric_feats.py
"""
import os, sys, json, pickle
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch
from PIL import Image
from note_prep import _crop_content
from qwen_loader import load_qwen_visual, get_processor

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = "train-data-note-lyric/features.pkl"
data = [json.loads(l) for l in open("train-data-note-lyric/manifest.jsonl", encoding="utf-8")]
print(f"样本 {len(data)}")
proc = get_processor()
visual = load_qwen_visual()
dev = next(visual.parameters()).device
out = []
for i, r in enumerate(data):
    img = _crop_content(Image.open(r["image"]).convert("RGB"))
    enc = proc(img, return_tensors="pt")
    pixel, grid = enc["pixel_values"], enc["image_grid_thw"]
    pixel = pixel.to(dev); grid = grid.to(dev)
    with torch.no_grad():
        feats = visual(pixel, grid)
        h = feats.mean(dim=0).float().cpu().numpy()
    out.append({"feat": h.tolist(), "label": 1 if r["label"] == "pos" else 0})
    if (i + 1) % 200 == 0:
        print(f"  {i+1}/{len(data)}")
pickle.dump(out, open(OUT, "wb"))
pos = sum(1 for x in out if x["label"] == 1)
print(f"特征 -> {OUT}  {len(out)} 个 (pos {pos}, neg {len(out)-pos})")
