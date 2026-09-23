# -*- coding: utf-8 -*-
"""Qwen 特征推理: 真实音符图 → Qwen visual 特征 → 分类头 → 组装 jianpu-ly token。
用法: py -3.13 tools/predict_qwen.py <图或目录>
"""
import json, os, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch
import torch.nn as nn
from PIL import Image
from note_prep import _crop_content
from qwen_loader import load_qwen_visual, get_processor

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DIM_N = {"digit": 9, "beam": 5, "low": 4, "voice": 4, "dotted": 2, "accidental": 3}
BEAM_PRE = {0: "", 1: "q", 2: "s", 3: "d", 4: "h"}
DIGIT = ["1", "2", "3", "4", "5", "6", "7", "0", "x"]
ACC = ["", "#", "b"]

MODEL_DIR = "models/qwen-mt-v1"


def to_token(res):
    digit_val = DIGIT[res["digit"]] if 0 <= res["digit"] < len(DIGIT) else ""
    # 杠不靠 digit 判(真实"1"的 digit=0 是 class0="1", 合法), 杠由独立检测处理
    if not digit_val:
        return "-"
    return BEAM_PRE[res["beam"]] + ACC[res["accidental"]] + "," * res["low"] + "'" * res["voice"] + digit_val + "." * res["dotted"]


def main():
    proc = get_processor()
    visual = load_qwen_visual()
    device = "cuda" if torch.cuda.is_available() else "cpu"
    heads = nn.ModuleDict({k: nn.Linear(2048, n) for k, n in DIM_N.items()})
    heads.load_state_dict(torch.load(os.path.join(MODEL_DIR, "heads.pt"), map_location="cpu"))
    heads.eval()
    if device != "cpu":
        heads = heads.to(device)

    def predict_one(img_path):
        img = _crop_content(Image.open(img_path).convert("RGB"))
        enc = proc(img, return_tensors="pt")
        pixel, grid = enc["pixel_values"], enc["image_grid_thw"]
        if device != "cpu":
            pixel = pixel.to(device); grid = grid.to(device)
        with torch.no_grad():
            feats = visual(pixel, grid).mean(dim=0).float()
            out = {k: heads[k](feats.unsqueeze(0)) for k in DIM_N}
        return {k: int(out[k].argmax(dim=1).item()) for k in DIM_N}

    for arg in sys.argv[1:]:
        if os.path.isdir(arg):
            files = sorted(glob.glob(os.path.join(arg, "*.png")) + glob.glob(os.path.join(arg, "*.jpg")))
            toks = [to_token(predict_one(f)) for f in files]
            print(f"{arg}: {len(toks)} 音符")
            print("  ", " ".join(toks))
        else:
            r = predict_one(arg)
            print(f"{os.path.basename(arg)} -> {json.dumps(r)} -> {to_token(r)}")


if __name__ == "__main__":
    main()
