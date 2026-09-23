# -*- coding: utf-8 -*-
"""端到端: 简谱图片 → 拆分音符 → CNN8头预测 → 组装 jianpu-ly 序列。"""
import os, sys, glob
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
import torch
from torchvision import transforms
from PIL import Image
import numpy as np
import transcribe as T
from infer_multitask import predict, to_token, model

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def transcribe(image_arg, out=None):
    im = Image.open(image_arg).convert("L")
    arr = np.asarray(im); content = arr < T.TOL
    toks = []
    for i, (s, e) in enumerate(T.fine_rows(content, T.ROW_GAP)):
        sub = content[s:e + 1]
        if T.count_bars(sub, e - s + 1) < T.BAR_THR:
            continue
        row_gray = arr[s:e + 1]
        for (nx0, nx1, ny0, ny1) in T.crop_note_regions(sub):
            crop = row_gray[max(0, ny0 - T.PAD):ny1 + T.PAD, max(0, nx0 - T.PAD):nx1 + T.PAD]
            if crop.size == 0:
                continue
            img = Image.fromarray(crop).convert("RGB")
            res = predict(img)
            tok = to_token(res)
            if tok:
                toks.append(tok)
    seq = " ".join(toks)
    print(f"转写 {len(toks)} 音:")
    print(seq)
    if out:
        open(out, "w", encoding="utf-8").write(seq + "\n")
    return seq


if __name__ == "__main__":
    img = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else None
    transcribe(img, out)
