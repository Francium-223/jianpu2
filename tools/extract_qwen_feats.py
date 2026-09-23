# -*- coding: utf-8 -*-
"""用 Qwen visual 预提取所有原子图的 2048 维特征, 存缓存。
之后训/推理只用特征+分类头(快, 不用每图跑Qwen vision)。
输出: train-data-atoms-v4-json/features.pkl  [{feat, label}]
用法: py -3.13 tools/extract_qwen_feats.py [--data onehot.jsonl] [--out features.pkl]
"""
import argparse, json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch, pickle
from PIL import Image
from note_prep import _crop_content
from qwen_loader import load_qwen_visual, get_processor

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="train-data-atoms-v4-json/onehot.jsonl")
    ap.add_argument("--out", default="train-data-atoms-v4-json/features.pkl")
    a = ap.parse_args()
    data = [json.loads(l) for l in open(a.data, encoding="utf-8")]
    print(f"样本 {len(data)}")
    proc = get_processor()
    visual = load_qwen_visual()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    out = []
    dev = next(visual.parameters()).device
    for i, r in enumerate(data):
        img = _crop_content(Image.open(r["image"]).convert("RGB"))
        enc = proc(img, return_tensors="pt")
        pixel = enc["pixel_values"]; grid = enc["image_grid_thw"]
        pixel = pixel.to(dev); grid = grid.to(dev)
        with torch.no_grad():
            feats = visual(pixel, grid)
            if isinstance(feats, (tuple, list)):
                feats = feats[0]
            h = feats.mean(dim=0).float().cpu().numpy()
        out.append({"feat": h.tolist(), "label": r["label"]})
        if (i + 1) % 50 == 0:
            print(f"  {i+1}/{len(data)}")
    with open(a.out, "wb") as f:
        pickle.dump(out, f)
    print(f"特征 -> {a.out} ({len(out)} 个, 2048维)")


if __name__ == "__main__":
    main()
